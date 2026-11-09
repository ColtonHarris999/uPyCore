#!/usr/bin/env python3
"""Build and run the RTL unit testbenches in ``upycore/tb``.

Each bench is verilated on its own with the RTL it needs, then run with the
arguments it expects: the decoder bench gets vectors from
``upycore/tb/mpy_decode_oracle.py`` (which needs the pinned mpy-cross), the
peripheral bench gets its plusargs from ``upycore/tools/mpy_periph_model.py``.
A bench passes when it exits 0 and prints its pass line.

Usage::

    python3 upycore/tools/unit_tests.py            # every bench
    python3 upycore/tools/unit_tests.py alu gc     # some of them
    python3 upycore/tools/unit_tests.py --list
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parents[2]
RTL = ROOT / "upycore" / "rtl"
TB = ROOT / "upycore" / "tb"
BUILD = ROOT / "build" / "unit"
ORACLE_SRC = ROOT / "build" / "oracle" / "src"

sys.path.insert(0, str(ROOT / "upycore" / "tools"))
sys.path.insert(0, str(ROOT / "iocore" / "tools"))
import mpy_synth  # noqa: E402  (ALU_FILES: the ALU's RTL list)
import iocore_files  # noqa: E402  (the I/O island's file lists)

FLAGS = [
    "--binary", "--timing", "-Wno-fatal", "-Wno-WIDTH", "-Wno-UNUSED",
    "-Wno-CASEINCOMPLETE", "-Wno-BLKSEQ", "-Wno-TIMESCALEMOD",
]
# Vendored cores (CVE2, Hazard3) lint differently from our RTL.
IOCORE_FLAGS = ["-Wno-lint", "-Wno-style", "-Wno-MULTIDRIVEN", "-Wno-UNOPTFLAT", "--timescale", "1ns/1ps"]


def _iocore_fw(app: str) -> None:
    """Build an I/O core firmware image (make -C iocore/sw APP=...)."""

    r = subprocess.run(["make", "-s", "-C", str(ROOT / "iocore" / "sw"), f"APP={app}"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"iocore firmware {app} failed:\n" + r.stdout[-2000:] + r.stderr[-2000:])


def _iocore_app(app: str, *extra: str) -> Callable[[Path], list[str]]:
    def args(work: Path) -> list[str]:
        _iocore_fw(app)
        d = ROOT / "build" / "iocore" / app
        out = [f"+CODE={d / 'code.hex'}", f"+DATA={d / 'data.hex'}"]
        exp = ROOT / "iocore" / "tb" / "expect" / f"{app}.txt"
        if exp.exists():
            out.append(f"+EXPECT={exp}")
        return out + list(extra)
    return args


def _decode_args(work: Path) -> list[str]:
    vectors = work / "vectors.txt"
    r = subprocess.run(
        [sys.executable, str(TB / "mpy_decode_oracle.py"), "--root", str(ORACLE_SRC),
         "--out", str(vectors), "--xd-dir", str(work / "xd")],
        cwd=ROOT, capture_output=True, text=True,
    )
    if r.returncode != 0:
        raise RuntimeError("mpy_decode_oracle.py failed:\n" + r.stdout[-2000:] + r.stderr[-2000:])
    return [f"+VECTOR={vectors}"]


def _periph_args(work: Path) -> list[str]:
    r = subprocess.run(
        [sys.executable, str(ROOT / "upycore" / "tools" / "mpy_periph_model.py"), "--plusargs"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    return r.stdout.split()


def _hash_args(work: Path) -> list[str]:
    subprocess.run([sys.executable, str(TB / "mpy_hash_oracle.py"), str(work)],
                   cwd=ROOT, check=True)
    return [f"+VECTORS={work / 'vectors.txt'}"]


@dataclass
class Bench:
    name: str
    rtl: list[str]
    passed: str                      # regex on the bench's output
    args: Callable[[Path], list[str]] = field(default=lambda work: [])
    top: str | None = None
    parameters: dict[str, int] = field(default_factory=dict)
    cpp: list[str] = field(default_factory=list)
    # Paths with a '/' are from the repository root (rtl and tb entries).
    tb: str | None = None
    incdirs: list[str] = field(default_factory=list)
    flags: list[str] = field(default_factory=list)


def _island(core: str) -> tuple[list[str], list[str]]:
    files, inc = iocore_files.island(core)
    return files + ["iocore/tb/tb_uart_line.sv"], inc


BENCHES = [
    Bench("mpy_shortlist", ["mpy_shortlist.sv"], r"^PASS mpy_shortlist "),
    Bench("mpy_shortlist8", ["mpy_shortlist.sv"], r"^PASS mpy_shortlist ", top="tb_mpy_shortlist", parameters={"MAX_ELEMS": 8}),
    Bench("mpy_bytecopy", ["mpy_bytecopy.sv"], r"^PASS mpy_bytecopy "),
    Bench("mpy_key_equal", ["mpy_key_equal.sv"], r"^PASS mpy_key_equal "),
    Bench("mpy_rehash_stream", ["mpy_hash.sv", "mpy_hash_slot.sv", "upycore_umod_seq.sv", "mpy_key_equal.sv", "mpy_map_engine.sv", "mpy_rehash_stream.sv"], r"^PASS mpy_rehash_stream "),
    Bench("mpy_collection", ["mpy_hash.sv", "upycore_umod_seq.sv", "mpy_key_equal.sv", "mpy_map_engine.sv", "mpy_bulk.sv", "mpy_hash_slot.sv", "mpy_rehash_stream.sv", "mpy_ca.sv", "mpy_bytecopy.sv", "mpy_shortlist.sv", "mpy_collection.sv"], r"^PASS mpy_collection "),
    Bench("mpy_bulk", ["mpy_hash.sv", "upycore_umod_seq.sv", "mpy_key_equal.sv", "mpy_map_engine.sv", "mpy_bulk.sv", "mpy_hash_slot.sv", "mpy_rehash_stream.sv"], r"^PASS mpy_bulk "),
    Bench("mpy_map_engine", ["mpy_hash.sv", "upycore_umod_seq.sv", "mpy_key_equal.sv", "mpy_map_engine.sv"], r"^PASS mpy_map_engine "),
    Bench("mpy_map_cache", ["mpy_hash.sv", "upycore_umod_seq.sv", "mpy_key_equal.sv", "mpy_map_engine.sv"], r"^PASS mpy_map_engine ", top="tb_mpy_map_engine", parameters={"TYPE_CACHE": 1}),
    Bench("mpy_hash4", ["mpy_hash.sv"], r"^PASS mpy_hash", _hash_args,
          top="tb_mpy_hash", parameters={"BYTES_PER_CYCLE": 4}),
    Bench("mpy_hash_slot4", ["mpy_hash.sv", "upycore_umod_seq.sv", "mpy_hash_slot.sv"],
          r"^PASS mpy_hash_slot", _hash_args, top="tb_mpy_hash_slot",
          parameters={"BYTES_PER_CYCLE": 4}),
    Bench("mpy_hash_slot", ["mpy_hash.sv", "upycore_umod_seq.sv", "mpy_hash_slot.sv"], r"^PASS mpy_hash_slot", _hash_args),
    Bench("mpy_hash", ["mpy_hash.sv"], r"^PASS mpy_hash", _hash_args),
    Bench("upycore_mul", ["upycore_mul.sv"], r"^PASS upycore_mul "),
    Bench("upycore_mul8", ["upycore_mul.sv"], r"^PASS upycore_mul ", top="tb_upycore_mul", parameters={"STEP":8}),
    Bench("upycore_mul64", ["upycore_mul.sv"], r"^PASS upycore_mul ", top="tb_upycore_mul", parameters={"STEP":64}),
    Bench("mpy_numeric", list(mpy_synth.ALU_FILES), r"^PASS mpy_numeric ", cpp=["mpy_numeric_oracle.cpp"]),
    Bench("mpy_alu", list(mpy_synth.ALU_FILES), r"^PASS mpy_alu "),
    Bench("mpy_boot", ["mpy_boot.sv", "../tb/tb_spi_nand.sv"], r"^PASS mpy_boot "),
    Bench("mpy_ca", ["mpy_ca.sv", "bsg_mem_1rw_sync_mask_write_bit.sv", "mpy_mem.sv"], r"^PASS mpy_ca "),
    Bench("mpy_decode", ["mpy_decode.sv"], r"^mpy_decode checks: \d+ ok", _decode_args),
    Bench("mpy_fetch", ["bsg_mem_1rw_sync_mask_write_bit.sv", "mpy_mem.sv", "mpy_fetch.sv"],
          r"^PASS mpy_fetch "),
    Bench("mpy_shared_mem", ["bsg_mem_1rw_sync_mask_write_bit.sv", "mpy_mem.sv"], r"^PASS mpy_shared_mem "),
    Bench("mpy_gc", ["bsg_mem_1rw_sync_mask_write_bit.sv", "mpy_gc.sv"], r"^PASS mpy_gc "),
    Bench("mpy_periph", ["mpy_mmio_pkg.sv", "mpy_irq.sv", "mpy_periph.sv"], r"^PASS: mpy periph",
          _periph_args),
    Bench("mpy_value", ["mpy_regfile.sv", "bsg_mem_1rw_sync_mask_write_bit.sv", "mpy_mem.sv"], r"^MPY value encoding: ok"),
    Bench("upycore_umod_seq", ["upycore_umod_seq.sv"], r"^PASS upycore_umod_seq "),
    Bench("iocore_cve2", _island("cve2")[0], r"^PASS tb_iocore ", _iocore_app("hello", "+UART_IN=AB"),
          top="tb_iocore", tb="iocore/tb/tb_iocore.sv", incdirs=_island("cve2")[1],
          parameters={"CORE": 0}, flags=IOCORE_FLAGS),
    Bench("iocore_hazard3", _island("hazard3")[0], r"^PASS tb_iocore ", _iocore_app("hello", "+UART_IN=AB"),
          top="tb_iocore", tb="iocore/tb/tb_iocore.sv", incdirs=_island("hazard3")[1],
          parameters={"CORE": 1}, flags=IOCORE_FLAGS),
    Bench("upycore_fp_subnormal", ["upycore_fp_add.sv", "upycore_umul_seq.sv", "upycore_fp_mul.sv",
                                   "upycore_udiv_seq.sv", "upycore_fp_divrem.sv"],
          r"^PASS upycore_fp_subnormal "),
]


def run_bench(b: Bench) -> tuple[bool, str]:
    work = BUILD / b.name
    work.mkdir(parents=True, exist_ok=True)
    top = b.top or f"tb_{b.name}"
    def path(f: str, base: Path) -> str:
        return str(ROOT / f) if "/" in f and not f.startswith("../") else str(base / f)
    cmd = [os.environ.get("VERILATOR", "verilator"), *FLAGS, *b.flags, f"-I{RTL}",
           *[f"-I{ROOT / d}" for d in b.incdirs], "--Mdir", str(work / "obj"),
           *[path(f, RTL) for f in b.rtl], path(b.tb, TB) if b.tb else str(TB / f"{top}.sv"),
           "--top-module", top,
           *[f"-G{k}={v}" for k, v in b.parameters.items()],
           *[str(TB / f) for f in b.cpp]]
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if r.returncode != 0:
        return False, "verilator failed:\n" + (r.stdout + r.stderr)[-3000:]
    try:
        args = b.args(work)
    except (RuntimeError, subprocess.CalledProcessError) as exc:
        return False, str(exc)
    r = subprocess.run([str(work / "obj" / f"V{top}"), *args], cwd=work, capture_output=True,
                       text=True, timeout=1800)
    out = r.stdout + r.stderr
    if r.returncode != 0 or not re.search(b.passed, out, re.M):
        return False, out[-3000:]
    line = next(l for l in out.splitlines() if re.search(b.passed, l))
    return True, line


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("names", nargs="*", help="benches to run (tb_ prefix optional)")
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args(argv)
    if args.list:
        for b in BENCHES:
            print(f"{b.name:18} {' '.join(b.rtl)}")
        return 0
    want = {n.removeprefix("tb_") for n in args.names}
    picked = [b for b in BENCHES if not want or b.name in want]
    unknown = want - {b.name for b in BENCHES}
    if unknown:
        print(f"unit_tests: unknown bench {', '.join(sorted(unknown))}", file=sys.stderr)
        return 2
    failed = []
    for b in picked:
        ok, detail = run_bench(b)
        print(f"{'PASS' if ok else 'FAIL':5} {b.name:18} {detail if ok else ''}".rstrip(), flush=True)
        if not ok:
            print(detail, flush=True)
            failed.append(b.name)
    print(f"unit_tests: {len(picked) - len(failed)} of {len(picked)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
