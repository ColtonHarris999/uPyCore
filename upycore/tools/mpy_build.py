#!/usr/bin/env python3
"""Build and run MicroPython programs on the uPyCore mpy_soc simulation.

The flow is: firmware sources (upycore/firmware/*.py) are joined into
one module and compiled with mpy-cross; the program is compiled the same
way; mpy_link.py joins both into a flash image; the Verilator build of
tb_mpy_soc runs it and writes stdout and stderr to files.

Usage::

    mpy_build.py sim                 build the simulator
    mpy_build.py fw                  build the firmware .mpy
    mpy_build.py run prog.py [-v]    build and run one program
    mpy_build.py run prog.py --sim-arg +AALU=0   pass a plusarg to the simulator
    mpy_build.py oracle prog.py      run the program on the MicroPython oracle

``run`` prints the program's stdout and stderr and exits with its exit
status, like the oracle's unix port does.
"""

from __future__ import annotations

import argparse
import ast
import os
import re
import shutil
import subprocess
import sys
import threading
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "upycore" / "tools"))

import mpy_abi as abi  # noqa: E402
import mpy_nand  # noqa: E402

BUILD = ROOT / "build" / "mpy"
FW_SRC = ROOT / "upycore" / "firmware"
ORACLE_SRC = ROOT / "build" / "oracle" / "src"
MPY_CROSS = Path(os.environ.get("MPY_CROSS", ORACLE_SRC / "mpy-cross" / "build" / "mpy-cross"))
ORACLE = Path(os.environ.get("MPY_ORACLE", ORACLE_SRC / "ports" / "unix" / "build-upycore" / "micropython"))
SIM_DIR = ROOT / "build" / "mpy_soc"
SIM = SIM_DIR / "obj" / "Vtb_mpy_soc"
MPY_CROSS_FLAGS = ["-msmall-int-bits=31", "-O0"]

# Firmware modules in link order. _abi.py comes first so its const() names
# fold into every later module.
FW_ORDER = [
    "_abi.py", "base.py", "errors.py", "fmt.py", "floatfmt.py", "ops.py",
    "attrs.py", "calls.py", "iters.py", "strs.py", "seqs.py", "dicts.py",
    "memview.py", "builtins.py", "modules.py", "boot.py", "load.py",
]

# Board I/O firmware (upycore/firmware/io), appended after FW_ORDER only for
# images that use board I/O (io_imports). Its own order, by file name.
IO_FW_ORDER = ["io.py"]
IO_FW_SRC = FW_SRC / "io"
# The I/O core's firmware (make -C iocore/sw), loaded from the boot stream's
# IOCB section for those images.
IOCORE_SW = ROOT / "iocore" / "sw"
IOCORE_FW = ROOT / "build" / "iocore" / "fw"

RTL = [
    "upycore/rtl/upycore_umul_seq.sv", "upycore/rtl/upycore_udiv_seq.sv", "upycore/rtl/upycore_umod_seq.sv",
    "upycore/rtl/upycore_int_alu.sv", "upycore/rtl/upycore_mul.sv", "upycore/rtl/upycore_div.sv",
    "upycore/rtl/upycore_ipow.sv", "upycore/rtl/upycore_fp_add.sv", "upycore/rtl/upycore_fp_mul.sv",
    "upycore/rtl/upycore_fp_divrem.sv", "upycore/rtl/upycore_fp_pow.sv", "upycore/rtl/upycore_fpu.sv",
    "upycore/rtl/mpy_alu.sv", "upycore/rtl/mpy_decode.sv", "upycore/rtl/mpy_fetch.sv", "upycore/rtl/mpy_core.sv",
    "upycore/rtl/mpy_hash.sv", "upycore/rtl/mpy_hash_slot.sv", "upycore/rtl/mpy_rehash_stream.sv", "upycore/rtl/mpy_key_equal.sv", "upycore/rtl/mpy_map_engine.sv", "upycore/rtl/mpy_bulk.sv", "upycore/rtl/mpy_bytecopy.sv", "upycore/rtl/mpy_shortlist.sv", "upycore/rtl/mpy_collection.sv",
    "upycore/rtl/mpy_gc.sv", "upycore/rtl/mpy_ca.sv", "upycore/rtl/bsg_mem_1rw_sync_mask_write_bit.sv",
    "upycore/rtl/mpy_mem.sv", "upycore/rtl/mpy_boot.sv", "upycore/rtl/mpy_async_fifo.sv",
    "upycore/rtl/mpy_iobr.sv", "upycore/rtl/mpy_soc.sv",
    "upycore/tb/tb_spi_nand.sv", "iocore/tb/tb_uart_line.sv", "upycore/tb/tb_mpy_soc.sv",
]
# The I/O island (the I/O core, CVE2, and its peripherals): iocore/tools.
sys.path.insert(0, str(ROOT / "iocore" / "tools"))
import iocore_files  # noqa: E402

ISLAND_RTL, ISLAND_INCDIRS = iocore_files.island("cve2")
RTL_INCLUDES = [
    "upycore/rtl/mpy_abi.svh", "upycore/rtl/mpy_defs.svh", "upycore/rtl/upycore_defs.svh",
    "upycore/rtl/upycore_fp_defs.svh", "upycore/rtl/upycore_fp_pow_rom.svh",
]

HALT_NAMES = {v: k for k, v in abi.HALT.items()}


class BuildError(Exception):
    pass


def _newer(target: Path, sources: list[Path]) -> bool:
    if not target.exists():
        return True
    t = target.stat().st_mtime
    return any(s.stat().st_mtime > t for s in sources)


def build_sim(force: bool = False, quiet: bool = True) -> Path:
    """Verilate tb_mpy_soc when any RTL source is newer than the binary."""

    sources = [ROOT / p for p in ISLAND_RTL + RTL + RTL_INCLUDES]
    if not force and not _newer(SIM, sources):
        return SIM
    (SIM_DIR / "obj").mkdir(parents=True, exist_ok=True)
    cmd = [
        os.environ.get("VERILATOR", "verilator"), "-sv", "--binary", "--timing",
        "--timescale", "1ns/1ps", "-O3", "--x-assign", "fast", "--x-initial", "fast",
        f"+incdir+{ROOT / 'upycore' / 'rtl'}", "-y", str(ROOT / "upycore" / "rtl"),
        *[f"+incdir+{ROOT / d}" for d in ISLAND_INCDIRS],
        "--top-module", "tb_mpy_soc",
        "--Mdir", str(SIM_DIR / "obj"), "-Wno-fatal", "-Wno-WIDTH", "-Wno-UNUSED",
        "-Wno-CASEINCOMPLETE", "-Wno-BLKSEQ", "-Wno-TIMESCALEMOD", "-Wno-lint", "-Wno-style",
        "-Wno-MULTIDRIVEN", "-Wno-UNOPTFLAT", "-j", str(os.cpu_count() or 4),
    ] + [str(s) for s in sources if s.suffix in (".sv", ".v")]
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if r.returncode != 0:
        raise BuildError("verilator failed:\n" + r.stdout[-4000:] + r.stderr[-4000:])
    if not quiet:
        print(f"built {SIM.relative_to(ROOT)}")
    return SIM


def mpy_cross(src: Path, out: Path, source_name: str) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    r = subprocess.run(
        [str(MPY_CROSS), *MPY_CROSS_FLAGS, "-s", source_name, "-o", str(out), str(src)],
        capture_output=True, text=True,
    )
    if r.returncode != 0:
        raise BuildError(f"mpy-cross {src}:\n{r.stdout}{r.stderr}")


def _ensure_mpyc() -> None:
    root = ROOT / "vendor" / "upy2"
    if not (root / "mpyc" / "compile.py").is_file():
        raise BuildError(
            f"uPy2 pin missing at {root} (git submodule update --init vendor/upy2)"
        )
    entry = str(root)
    if entry not in sys.path:
        sys.path.insert(0, entry)


def compile_mpyc(src: Path, out: Path, source_name: str) -> None:
    """Compile one program with the vendored uPy2 compiler."""

    _ensure_mpyc()
    from mpyc.compile import CompileError, compile_source
    from mpyc.parser import ParseError

    out.parent.mkdir(parents=True, exist_ok=True)
    try:
        data = compile_source(src.read_text(encoding="utf-8"), source_name, "exec", 0)
    except (CompileError, ParseError) as exc:
        raise BuildError(f"mpyc {src}: {exc}") from exc
    out.write_bytes(data)


def compile_user(src: Path, out: Path, source_name: str, compiler: str = "mpy-cross") -> None:
    if compiler == "mpy-cross":
        mpy_cross(src, out, source_name)
    elif compiler == "mpyc":
        compile_mpyc(src, out, source_name)
    else:
        raise BuildError(f"unknown compiler {compiler!r}")


_FW_IMPORT = re.compile(r"^\s*from\s+(\.?_abi|micropython)\s+import\s+")


def firmware_source(io: bool = False) -> str:
    parts = []
    order = [FW_SRC / n for n in FW_ORDER] + ([IO_FW_SRC / n for n in IO_FW_ORDER] if io else [])
    for i, path in enumerate(order):
        name = path.relative_to(FW_SRC).as_posix()
        if not path.exists():
            continue
        lines = path.read_text().splitlines()
        if i > 0:
            lines = [ln for ln in lines if not _FW_IMPORT.match(ln)]
        parts.append(f"# ---- {name} ----")
        parts.extend(lines)
    return "\n".join(parts) + "\n"


def build_firmware(out_dir: Path | None = None, io: bool = False) -> Path:
    """Join and compile the firmware; returns the .mpy path. ``io`` appends
    the board I/O firmware (a separate build in ``build/mpy/fw_io``)."""

    out_dir = out_dir or BUILD / ("fw_io" if io else "fw")
    out_dir.mkdir(parents=True, exist_ok=True)
    src = out_dir / "fw.py"
    mpy = out_dir / "fw.mpy"
    text = firmware_source(io)
    if not src.exists() or src.read_text() != text:
        src.write_text(text)
    if _newer(mpy, [src, MPY_CROSS]):
        mpy_cross(src, mpy, "_fw.py")
    return mpy


def link(main_mpy: Path, fw_mpy: Path, out: Path, modules: list[str] | None = None) -> Path:
    cmd = [sys.executable, str(ROOT / "upycore" / "tools" / "mpy_link.py"),
           "--main", str(main_mpy), "--fw", str(fw_mpy), "-o", str(out)]
    for m in modules or []:
        cmd += ["--module", m]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise BuildError(f"link failed:\n{r.stdout}{r.stderr}")
    return out


@dataclass
class SimResult:
    stdout: bytes
    stderr: bytes
    halt: str            # CLEAN, SYSEXIT, UNCAUGHT, ..., or TIMEOUT
    value: int
    cycles: int
    ops: int
    gc: int
    log: str

    @property
    def exit_code(self) -> int | None:
        """The unix port's exit status, or None when the core crashed."""

        if self.halt == "CLEAN":
            return 0
        if self.halt == "SYSEXIT":
            return self.value & 0xFF
        return None


_HALT_RE = re.compile(r"MPY_HALT code=(\d+) value=([0-9a-f]+) cycles=(\d+) ops=(\d+) gc=(\d+)")
_TIMEOUT_RE = re.compile(r"MPY_TIMEOUT cycles=(\d+) ops=(\d+) gc=(\d+)")


def run_image(image: Path, max_cycles: int = 50_000_000, trace: bool = False,
              timeout: float | None = None, sim_args: list[str] | None = None,
              nand: bool = False, sim_executable: Path | None = None) -> SimResult:
    """Run one linked image. ``nand`` boots it over SPI from the testbench's
    NAND model instead of streaming the image files straight into mpy_boot."""

    out = Path(f"{image}.stdout")
    err = Path(f"{image}.stderr")
    # MPY_SIM picks another build of the testbench (for instance one made
    # with --trace-saif); MPY_SIM_ARGS adds plusargs (+SAIF=<path>).
    marker = Path(f"{image}.iocore")
    ioc = Path(marker.read_text().strip()) if marker.exists() else None
    if nand:
        boot = [f"+NAND={mpy_nand.write_files(image, ioc)[1]}"]
    else:
        boot = [f"+IMAGE={image}.hex", f"+TAGS={image}.tags.hex"]
        if ioc is not None:
            boot += [f"+IOC_CODE={ioc / 'code.hex'}", f"+IOC_DATA={ioc / 'data.hex'}"]
    cmd = [str(sim_executable) if sim_executable else os.environ.get("MPY_SIM", str(SIM)), *boot,
           f"+STDOUT={out}", f"+STDERR={err}", f"+MAX_CYCLES={max_cycles}"]
    cmd += os.environ.get("MPY_SIM_ARGS", "").split()
    if trace:
        cmd.append("+TRACE=1")
    cmd.extend(sim_args or [])
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    log = r.stdout + r.stderr
    stdout = out.read_bytes() if out.exists() else b""
    stderr = err.read_bytes() if err.exists() else b""
    m = _HALT_RE.search(log)
    if m:
        code = int(m.group(1))
        return SimResult(stdout, stderr, HALT_NAMES.get(code, str(code)), int(m.group(2), 16),
                         int(m.group(3)), int(m.group(4)), int(m.group(5)), log)
    m = _TIMEOUT_RE.search(log)
    if m:
        return SimResult(stdout, stderr, "TIMEOUT", 0, int(m.group(1)), int(m.group(2)), int(m.group(3)), log)
    return SimResult(stdout, stderr, "NO_RESULT", 0, 0, 0, 0, log)


def _cached_mpy(src: Path, source_name: str) -> Path:
    """Compile a frozen runtime module once. Later images reuse the .mpy."""

    cache = BUILD / "frozen"
    cache.mkdir(parents=True, exist_ok=True)
    out = cache / (source_name.replace("/", "_") + ".mpy")
    with _CACHE_LOCK:
        if _newer(out, [src, MPY_CROSS]):
            mpy_cross(src, out, source_name)
    return out


_CACHE_LOCK = threading.Lock()


# compile, exec and eval run the frozen uPy2 compiler. It is 167 KB of
# image. Freeze it only for programs that name one of them; the linker
# checks their combined image and runtime reservations against shared SRAM.
_COMPILER_NAMES = {"compile", "exec", "eval"}


def uses_compiler(sources: list[Path]) -> bool:
    """True when a source names compile, exec or eval (not in a string)."""

    for p in sources:
        text = p.read_bytes()
        try:
            tree = ast.parse(text)
        except (SyntaxError, ValueError):
            if re.search(rb"\b(compile|exec|eval)\b", text):
                return True
            continue
        for node in ast.walk(tree):
            if isinstance(node, ast.Name) and node.id in _COMPILER_NAMES:
                return True
            if isinstance(node, ast.Attribute) and node.attr in _COMPILER_NAMES:
                return True
            if isinstance(node, ast.alias) and node.name.split(".")[-1] in _COMPILER_NAMES:
                return True
    return False


# Standard-library modules written in Python (upycore/runtime). Each is frozen
# only into programs that import it, so other images stay byte-identical.
# A module's own imports of these are listed here too.
RUNTIME_MODULES = {"math": (), "cmath": ("math",), "random": (), "io": (), "machine": ()}

# Imports that mean a program uses board I/O: it gets the board I/O firmware
# (IO_FW_ORDER) and the I/O core's boot section. _io is the firmware's own
# native module (upycore/firmware/io/io.py).
IO_MODULES = {"machine", "_io"}


def io_imports(sources: list[Path]) -> list[str]:
    """The board I/O modules any source imports (empty: no board I/O)."""

    found: set[str] = set()
    for p in sources:
        try:
            tree = ast.parse(p.read_bytes())
        except (SyntaxError, ValueError):
            continue
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                names = [a.name for a in node.names]
            elif isinstance(node, ast.ImportFrom) and not node.level and node.module:
                names = [node.module]
            else:
                continue
            found.update(n.split(".")[0] for n in names if n.split(".")[0] in IO_MODULES)
    return sorted(found)


_IOC_LOCK = threading.Lock()


def build_iocore_fw() -> Path:
    """Build the I/O core's production firmware; returns its output folder.
    hw_tests.py builds images from several threads; make runs one at a time."""

    with _IOC_LOCK:
        r = subprocess.run(["make", "-s", "-C", str(IOCORE_SW), "APP=fw"], capture_output=True, text=True)
    if r.returncode != 0:
        raise BuildError("I/O core firmware failed:\n" + r.stdout[-3000:] + r.stderr[-3000:])
    return IOCORE_FW


def runtime_imports(sources: list[Path]) -> list[str]:
    """The RUNTIME_MODULES that any source imports, with their dependencies."""

    found: set[str] = set()
    for p in sources:
        try:
            tree = ast.parse(p.read_bytes())
        except (SyntaxError, ValueError):
            continue
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                names = [a.name for a in node.names]
            elif isinstance(node, ast.ImportFrom) and not node.level and node.module:
                names = [node.module]
            else:
                continue
            for n in names:
                top = n.split(".")[0]
                if top in RUNTIME_MODULES:
                    found.add(top)
    todo = list(found)
    while todo:
        for dep in RUNTIME_MODULES[todo.pop()]:
            if dep not in found:
                found.add(dep)
                todo.append(dep)
    return sorted(found)


def frozen_runtime_specs(compiler: bool = True, runtime: list[str] | tuple = ()) -> list[str]:
    """array, the ``runtime`` modules, plus (with ``compiler``) the patched uPy2 compiler."""

    comp = ROOT / "upycore" / "compiler"
    if str(comp) not in sys.path:
        sys.path.insert(0, str(comp))
    import prepare

    rows = [("array", ROOT / "upycore" / "runtime" / "array.py", False, "array.py")]
    for name in runtime:
        rows.append((name, ROOT / "upycore" / "runtime" / f"{name}.py", False, f"{name}.py"))
    if compiler:
        rows.extend(prepare.module_list(prepare.prepare()))
    specs = []
    for dotted, path, is_pkg, source_name in rows:
        mm = _cached_mpy(path, source_name)
        specs.append(f"{dotted}={mm}" + (":package" if is_pkg else ""))
    return specs


def build_program(src: Path, work: Path, source_name: str | None = None,
                  modules: dict[str, Path] | None = None,
                  compiler: str = "mpy-cross") -> Path:
    """Compile and link one program (plus frozen modules); returns the image prefix.

    ``compiler`` selects the user-program compiler. The firmware is always
    built with ``mpy-cross``. ``mpyc`` is the vendored uPy2 compiler.
    """

    work.mkdir(parents=True, exist_ok=True)
    sources = [src, *(modules or {}).values()]
    io = bool(io_imports(sources))
    # Without board I/O this is the call it always was (clock_bench.py
    # replaces build_firmware with a no-argument function).
    fw = build_firmware(io=True) if io else build_firmware()
    name = source_name or src.name
    main_mpy = work / "main.mpy"
    compile_user(src, main_mpy, name, compiler)
    # The compiler is frozen bytecode. It is not compiled by itself.
    # A test that supplies its own module of the same name keeps it.
    runtime = [m for m in runtime_imports(sources) if m not in (modules or {})]
    specs = frozen_runtime_specs(uses_compiler(sources), runtime)
    for mname, mpath in (modules or {}).items():
        mm = work / (mname.replace(".", "_") + ".mpy")
        mod_name = mpath.name if mpath.name != "__init__.py" else f"{mname.replace('.', '/')}/__init__.py"
        compile_user(mpath, mm, mod_name, compiler)
        kind = ":package" if mpath.name == "__init__.py" else ""
        specs.append(f"{mname}={mm}{kind}")
    image = link(main_mpy, fw, work / "image", specs)
    # A board I/O image boots with the I/O core's firmware (the IOCB section).
    marker = Path(f"{image}.iocore")
    if io:
        marker.write_text(str(build_iocore_fw()) + "\n")
    elif marker.exists():
        marker.unlink()
    return image


def run_oracle(src: Path, cwd: Path | None = None, timeout: float = 60) -> tuple[bytes, bytes, int]:
    r = subprocess.run([str(ORACLE), src.name], cwd=cwd or src.parent, capture_output=True, timeout=timeout)
    return r.stdout, r.stderr, r.returncode


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("sim")
    sub.add_parser("fw")
    rp = sub.add_parser("run")
    rp.add_argument("src", type=Path)
    rp.add_argument("--max-cycles", type=int, default=50_000_000)
    rp.add_argument("--trace", action="store_true")
    rp.add_argument("-v", "--verbose", action="store_true", help="print the halt line")
    rp.add_argument("--work", type=Path, default=None)
    rp.add_argument("--sim-arg", action="append", default=[],
                    help="simulator plusarg, e.g. +CA=0 or +AALU=0 (repeatable)")
    rp.add_argument("--nand", action="store_true",
                    help="boot over SPI from the testbench's NAND model (mpy_nand.py image)")
    op = sub.add_parser("oracle")
    op.add_argument("src", type=Path)
    args = ap.parse_args(argv)
    try:
        if args.cmd == "sim":
            build_sim(force=True, quiet=False)
            return 0
        if args.cmd == "fw":
            print(build_firmware())
            return 0
        if args.cmd == "oracle":
            out, err, rc = run_oracle(args.src.resolve())
            sys.stdout.buffer.write(out)
            sys.stderr.buffer.write(err)
            return rc
        build_sim()
        work = args.work or BUILD / "run" / args.src.stem
        image = build_program(args.src.resolve(), work)
        res = run_image(image, args.max_cycles, args.trace, sim_args=args.sim_arg, nand=args.nand)
    except BuildError as exc:
        print(exc, file=sys.stderr)
        return 2
    if args.trace:
        sys.stdout.write("\n".join(ln for ln in res.log.splitlines() if ln.startswith("TRACE")) + "\n")
    sys.stdout.buffer.write(res.stdout)
    sys.stdout.flush()
    sys.stderr.buffer.write(res.stderr)
    if args.verbose or res.exit_code is None:
        print(f"[{res.halt} value={res.value:#x} cycles={res.cycles} ops={res.ops} gc={res.gc}]", file=sys.stderr)
    return res.exit_code if res.exit_code is not None else 3


if __name__ == "__main__":
    raise SystemExit(main())
