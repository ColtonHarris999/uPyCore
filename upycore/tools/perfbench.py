#!/usr/bin/env python3
"""Offline perf_bench for the uPyCore hart.

``run-perfbench.py`` sends a target source on stdin: ``import sys`` /
``sys.path.remove('')``, the benchmark, ``benchrun.py``, and ``bm_run(N, M)``.
This tool builds that same text, compiles it with ``mpy-cross`` at the hart's
small-int width, and runs the image. ``time.ticks_us`` reads the cycle
counter, so the printed elapsed count is cycles and

    score per MHz = 1e6 * norm / cycles

with no clock in the formula. The result string is checked against CPython
on the same script, which is what ``run-perfbench.py`` uses as truth.
``None`` is not checked, matching the upstream runner.

The default (N, M) is the smallest pair that selects each file's smallest
``bm_params`` key. Scores from different keys are different workloads.

    python3 upycore/tools/perfbench.py list
    python3 upycore/tools/perfbench.py truth
    python3 upycore/tools/perfbench.py run
    python3 upycore/tools/perfbench.py run bm_fannkuch --max-cycles 20000000
    python3 upycore/tools/perfbench.py internal loop_count --iters 1000
"""

from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "upycore" / "tools"))

import mpy_abi as abi  # noqa: E402
import mpy_build as build  # noqa: E402

PERF = ROOT / "vendor" / "micropython" / "tests" / "perf_bench"
INTERNAL = ROOT / "vendor" / "micropython" / "tests" / "internal_bench"
DEFS = ROOT / "upycore" / "rtl" / "mpy_defs.svh"
OUT_DIR = ROOT / "build" / "perfbench"

# Same prologue and trailer as tests/run-perfbench.py.
PROLOGUE = b"import sys\nsys.path.remove('')\n\n"
EMIT = ("-X", "emit=bytecode")

# Ten integer programs. bm_pidigits needs MPZ; the pin's oracle is LONGLONG
# and the script prints SKIP. bm_nqueens and core_yield_from need generators.
TIER_A = (
    "misc_pystone",
    "misc_aes",
    "bm_fannkuch",
    "bm_nqueens",
    "bm_wordcount",
    "core_locals",
    "core_str",
    "core_qstr",
    "core_yield_from",
    "bm_pidigits",
)

# The other bytecode programs. viper_* and core_import_mpy_* are not in this
# list: viper needs the native emitter, and the import pair needs a VFS.
TIER_B = ("bm_float", "bm_fft", "bm_chaos", "misc_mandel", "misc_raytrace")
TIER_C = ("bm_hexiom",)

_LINE = re.compile(r"^(-?\d+) (-?\d+) (.*)$")
_DIV10K = re.compile(r"//\s*10000")


def _localparam(name: str) -> int:
    text = DEFS.read_text(encoding="utf-8")
    match = re.search(rf"{name}\s*=\s*(\d+)", text)
    if match is None:
        raise SystemExit(f"perfbench: {name} not found in {DEFS.name}")
    return int(match.group(1))


def min_n(n_key: int) -> int:
    """Smallest integer N with ``10 * n_key <= 12 * N`` (benchrun's test)."""

    return (10 * n_key + 11) // 12


def load_params(name: str) -> dict[tuple[int, int], tuple]:
    path = PERF / f"{name}.py"
    if not path.is_file():
        raise SystemExit(f"perfbench: no benchmark {name}")
    namespace: dict = {}
    exec(compile(path.read_text(encoding="utf-8"), str(path), "exec"), namespace)
    params = namespace.get("bm_params")
    if not isinstance(params, dict) or not params:
        raise SystemExit(f"perfbench: {name} has no bm_params")
    return params


def select_param(params: dict[tuple[int, int], tuple], n: int, m: int):
    """benchrun.py's choice: the greatest key with 10*N' <= 12*N and M' <= M."""

    chosen = (0, 0)
    param = None
    for key, value in params.items():
        if 10 * key[0] <= 12 * n and key[1] <= m and key > chosen:
            chosen = key
            param = value
    if param is None:
        return None, None
    return chosen, param


def qualifying(params: dict[tuple[int, int], tuple]) -> tuple[int, int]:
    """(N, M) that selects the smallest key and no larger one."""

    n_key, m_key = min(params)
    return min_n(n_key), m_key


def build_script(name: str, n: int, m: int) -> bytes:
    body = (PERF / f"{name}.py").read_bytes()
    harness = (PERF / "benchrun.py").read_bytes()
    tail = f"bm_run({n}, {m})\n".encode("ascii")
    return PROLOGUE + body + harness + tail


def score_per_mhz(norm: int, cycles: int) -> float:
    """1e6 * norm / cycles. Cycles in, score per MHz out."""

    return 1e6 * norm / cycles


def geomean(values: list[float]) -> float | None:
    if not values:
        return None
    return math.exp(sum(math.log(v) for v in values) / len(values))


def parse_bench_output(text: str) -> tuple[str, int | None, int | None, str | None]:
    """Return (status, elapsed, norm, result). status is ok, skip, or crash."""

    stripped = text.strip()
    if stripped == "SKIP" or stripped.startswith("SKIP"):
        return "skip", None, None, stripped
    elapsed = norm = None
    result = None
    for line in stripped.splitlines():
        match = _LINE.match(line.strip())
        if match:
            elapsed = int(match.group(1))
            norm = int(match.group(2))
            result = match.group(3)
    if result is None:
        return "crash", None, None, stripped or None
    return "ok", elapsed, norm, result


def cpython_truth(script: bytes, timeout: float) -> tuple[str, int | None, int | None, str | None, str]:
    proc = subprocess.run(
        [sys.executable, "-B"],
        input=script,
        capture_output=True,
        timeout=timeout,
    )
    out = proc.stdout.decode("utf-8", "replace")
    err = proc.stderr.decode("utf-8", "replace")
    status, _elapsed, norm, result = parse_bench_output(out)
    if proc.returncode != 0 and status == "ok":
        status = "crash"
    note = err.strip()
    return status, None, norm, result, note


def tier_of(name: str) -> str:
    if name in TIER_A:
        return "A"
    if name in TIER_B:
        return "B"
    if name in TIER_C:
        return "C"
    if name.startswith("viper_"):
        return "viper"
    if name.startswith("core_import_mpy"):
        return "import"
    return "?"


def benchmark_names() -> list[str]:
    return sorted(
        path.stem
        for path in PERF.glob("*.py")
        if path.name != "benchrun.py"
    )


def resolve_names(names: list[str], tier: str | None) -> list[str]:
    if names:
        return names
    if tier == "B":
        return list(TIER_B)
    if tier == "C":
        return list(TIER_C)
    if tier == "all":
        return [n for n in benchmark_names() if tier_of(n) in ("A", "B", "C")]
    return list(TIER_A)


@dataclass
class Row:
    name: str
    tier: str
    n: int
    m: int
    key: tuple[int, int] | None = None
    param: list | None = None
    status: str = "crash"
    elapsed: int | None = None
    norm: int | None = None
    result: str | None = None
    truth_norm: int | None = None
    truth_result: str | None = None
    agree: bool | None = None
    score_per_mhz: float | None = None
    cycles_per_norm: float | None = None
    sim_cycles: int | None = None
    ops: int | None = None
    gc: int | None = None
    halt: str | None = None
    note: str = ""

    def as_dict(self) -> dict:
        data = {
            "name": self.name,
            "tier": self.tier,
            "N": self.n,
            "M": self.m,
            "key": list(self.key) if self.key else None,
            "param": self.param,
            "status": self.status,
            "elapsed_cycles": self.elapsed,
            "norm": self.norm,
            "result": self.result,
            "truth_norm": self.truth_norm,
            "truth_result": self.truth_result,
            "agree": self.agree,
            "score_per_mhz": self.score_per_mhz,
            "cycles_per_norm": self.cycles_per_norm,
            "sim_cycles": self.sim_cycles,
            "ops": self.ops,
            "gc": self.gc,
            "halt": self.halt,
            "note": self.note,
        }
        return data


def _agree(result: str | None, truth: str | None) -> bool | None:
    # run-perfbench.py does not truth-check a result of None. Treat that as
    # agreement when CPython also printed None, or when there is no truth.
    if result is None:
        return None
    if result == "None":
        return truth is None or truth == "None"
    if truth is None:
        return None
    return result == truth


def evaluate_one(name: str, n: int | None, m: int | None, run_sim: bool,
                 max_cycles: int, timeout: float) -> Row:
    params = load_params(name)
    if n is None or m is None:
        n, m = qualifying(params)
    row = Row(name=name, tier=tier_of(name), n=n, m=m)
    key, param = select_param(params, n, m)
    row.key = key
    row.param = list(param) if param is not None else None
    if param is None:
        row.status = "skip"
        row.note = "no matching params"
        return row

    script = build_script(name, n, m)
    try:
        t_status, _t_elapsed, t_norm, t_result, t_note = cpython_truth(script, timeout)
    except subprocess.TimeoutExpired:
        t_status, t_norm, t_result, t_note = "crash", None, None, "CPython timed out"
    row.truth_norm = t_norm
    row.truth_result = t_result
    if t_status != "ok":
        row.note = t_note
    if not run_sim:
        row.status = "truth"
        row.norm = t_norm
        row.result = t_result
        if t_status != "ok":
            row.status = t_status
        return row

    work = OUT_DIR / name
    work.mkdir(parents=True, exist_ok=True)
    src = work / "script.py"
    src.write_bytes(script)
    try:
        image = build.build_program(src, work, f"{name}.py", extra=EMIT)
        sim = build.run_image(image, max_cycles=max_cycles, timeout=timeout)
    except build.BuildError as exc:
        row.status = "build"
        row.note = str(exc).strip().splitlines()[-1]
        return row
    except subprocess.TimeoutExpired:
        row.status = "timeout"
        row.note = f"runner timeout after {timeout:.0f}s"
        return row

    row.sim_cycles = sim.cycles
    row.ops = sim.ops
    row.gc = sim.gc
    row.halt = sim.halt
    stdout = sim.stdout.decode("utf-8", "replace")
    stderr = sim.stderr.decode("utf-8", "replace").strip()
    status, elapsed, norm, result = parse_bench_output(stdout)
    row.elapsed = elapsed
    row.norm = norm
    row.result = result
    if status == "skip":
        row.status = "skip"
        row.note = result or "SKIP"
        return row
    if sim.halt == "TIMEOUT":
        row.status = "timeout"
        row.note = stderr or f"hit {max_cycles} cycles"
        return row
    if status != "ok" or sim.exit_code is None:
        row.status = "crash"
        row.note = stderr or (result or sim.halt)
        return row
    if elapsed is None or elapsed <= 0 or norm is None:
        row.status = "wrap" if elapsed is not None and elapsed <= 0 else "crash"
        row.note = "tick difference is not a positive cycle count"
        return row
    if row.truth_norm is not None and norm != row.truth_norm:
        row.status = "fail"
        row.note = f"norm {norm} != CPython {row.truth_norm}"
        return row
    row.agree = _agree(result, row.truth_result)
    if row.agree is False:
        row.status = "fail"
        row.note = "result != CPython"
        return row
    row.score_per_mhz = score_per_mhz(norm, elapsed)
    row.cycles_per_norm = elapsed / norm
    row.status = "pass"
    if sim.cycles >= (1 << 30):
        row.note = "total cycles crossed the 30-bit tick window"
    return row


def memory_model() -> dict:
    return {
        "mpy": "v1.29.0",
        "small_int_bits": 31,
        "emit": "bytecode",
        "ticks": "cyc[29:0]",
        "tick_period": 1 << 30,
        "score": "1e6 * norm / cycles",
        "sram_latency_cycles": _localparam("MPY_SRAM_LATENCY"),
        "flash_wait_states": _localparam("MPY_FLASH_WAIT_STATES"),
        "heap_bytes": abi.GC_POOL_BYTES,
        "runs": 1,
    }


def write_report(rows: list[Row], path: Path) -> None:
    passed = [r.score_per_mhz for r in rows if r.status == "pass" and r.score_per_mhz]
    payload = {
        "model": memory_model(),
        "geomean_score_per_mhz": geomean(passed),
        "programs": [r.as_dict() for r in rows],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def format_table(rows: list[Row]) -> str:
    head = (
        f"{'program':<18} {'N':>4} {'M':>4} {'status':<8} "
        f"{'cycles':>12} {'norm':>8} {'per MHz':>10}  result"
    )
    lines = [head]
    for row in rows:
        cycles = "" if row.elapsed is None else f"{row.elapsed}"
        norm = "" if row.norm is None else f"{row.norm}"
        score = "" if row.score_per_mhz is None else f"{row.score_per_mhz:.4f}"
        if row.status == "pass":
            result = row.result or ""
        else:
            result = (row.note or row.result or "").strip().splitlines()[-1]
        if len(result) > 48:
            result = result[:45] + "..."
        lines.append(
            f"{row.name:<18} {row.n:4d} {row.m:4d} {row.status:<8} "
            f"{cycles:>12} {norm:>8} {score:>10}  {result}"
        )
    passed = [r.score_per_mhz for r in rows if r.status == "pass" and r.score_per_mhz]
    mean = geomean(passed)
    if mean is not None:
        lines.append(
            f"geomean of those scores: {mean:.4f} "
            "(each file at its own smallest workload; not a board comparison)"
        )
    lines.append("score/MHz = 1e6 * norm / cycles")
    return "\n".join(lines)


def cmd_list() -> int:
    print(f"{'program':<24} {'tier':<8} {'min key':<12} {'(N, M)':<12} param")
    for name in benchmark_names():
        if tier_of(name) in ("viper", "import"):
            print(f"{name:<24} {tier_of(name):<8} excluded")
            continue
        params = load_params(name)
        n, m = qualifying(params)
        key, param = select_param(params, n, m)
        print(f"{name:<24} {tier_of(name):<8} {key!s:<12} {(n, m)!s:<12} {param}")
    return 0


def cmd_eval(args: argparse.Namespace, run_sim: bool) -> int:
    names = resolve_names(args.names, args.tier)
    if run_sim:
        build.build_sim()
    rows = []
    for name in names:
        print(f"-- {name}", flush=True)
        row = evaluate_one(
            name, args.n, args.m, run_sim, args.max_cycles, args.timeout,
        )
        rows.append(row)
        print(format_table([row]), flush=True)
    print()
    print(format_table(rows))
    if args.json:
        write_report(rows, args.json)
        print(f"wrote {args.json}")
    failed = [r for r in rows if r.status in ("fail", "crash", "build", "timeout", "wrap")]
    return 1 if failed else 0


# Remote-target harness from run-internalbench.py, printing raw cycles.
_INTERNAL = """\
import time

class bench_class:
    ITERS = 20000000

    @staticmethod
    def run(test):
        t = time.ticks_us()
        test(bench_class.ITERS)
        print(time.ticks_diff(time.ticks_us(), t))

import sys
sys.modules['bench'] = bench_class
"""


def internal_files(family: str | None) -> list[Path]:
    files = sorted(INTERNAL.glob("*.py"))
    out = []
    for path in files:
        match = re.match(r"(.+?)-(.+)\.py", path.name)
        if not match:
            continue
        if family is None or match.group(1) == family:
            out.append(path)
    return out


def cmd_internal(args: argparse.Namespace) -> int:
    files = internal_files(args.family)
    if not files:
        print(f"perfbench: no internal_bench family {args.family!r}", file=sys.stderr)
        return 1
    build.build_sim()
    rows = []
    for path in files:
        iters = args.iters
        text = path.read_text(encoding="utf-8")
        note = ""
        if _DIV10K.search(text) and iters < 10000:
            iters = 10000
            note = "iters raised to 10000"
        script = (_INTERNAL + "\n" + text).replace("20000000", str(iters))
        work = OUT_DIR / "internal" / path.stem
        work.mkdir(parents=True, exist_ok=True)
        src = work / "script.py"
        src.write_text(script, encoding="utf-8")
        row = {
            "name": path.stem,
            "iters": iters,
            "note": note,
            "status": "crash",
            "cycles": None,
            "cycles_per_iter": None,
        }
        try:
            image = build.build_program(src, work, path.name, extra=EMIT)
            sim = build.run_image(image, max_cycles=args.max_cycles, timeout=args.timeout)
        except build.BuildError as exc:
            row["status"] = "build"
            row["note"] = str(exc).strip().splitlines()[-1]
            rows.append(row)
            print(f"{path.stem}: build {row['note']}")
            continue
        except subprocess.TimeoutExpired:
            row["status"] = "timeout"
            rows.append(row)
            print(f"{path.stem}: timeout")
            continue
        out = sim.stdout.decode("utf-8", "replace").strip()
        try:
            cycles = int(out.splitlines()[-1])
        except (ValueError, IndexError):
            row["status"] = sim.halt
            row["note"] = (sim.stderr.decode("utf-8", "replace").strip() or out)[:200]
            rows.append(row)
            print(f"{path.stem}: {row['status']} {row['note']}")
            continue
        row["status"] = "pass" if cycles > 0 else "wrap"
        row["cycles"] = cycles
        row["cycles_per_iter"] = cycles / iters
        row["sim_cycles"] = sim.cycles
        rows.append(row)
        print(f"{path.stem}: {cycles} cycles  {cycles / iters:.2f}/iter  {note}")
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps({"model": memory_model(), "programs": rows}, indent=2) + "\n")
        print(f"wrote {args.json}")
    return 0 if all(r["status"] == "pass" for r in rows) else 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list", help="show the 16 bytecode programs and their smallest (N, M)")

    def add_eval(name: str, help_text: str) -> argparse.ArgumentParser:
        cmd = sub.add_parser(name, help=help_text)
        cmd.add_argument("names", nargs="*")
        cmd.add_argument("--tier", choices=("A", "B", "C", "all"), default=None)
        cmd.add_argument("--n", type=int, default=None)
        cmd.add_argument("--m", type=int, default=None)
        cmd.add_argument("--json", type=Path, default=OUT_DIR / "report.json")
        return cmd

    add_eval("truth", "run the concatenated script on CPython and print norm/result")
    run = add_eval("run", "compile, simulate, and score the programs")
    run.add_argument("--max-cycles", type=int, default=80_000_000)
    run.add_argument("--timeout", type=float, default=300.0)

    internal = sub.add_parser("internal", help="one internal_bench family, cycles per iteration")
    internal.add_argument("family", nargs="?", default=None)
    internal.add_argument("--iters", type=int, default=1000)
    internal.add_argument("--max-cycles", type=int, default=80_000_000)
    internal.add_argument("--timeout", type=float, default=300.0)
    internal.add_argument("--json", type=Path, default=OUT_DIR / "internal.json")

    args = parser.parse_args(argv)
    if args.cmd == "list":
        return cmd_list()
    if args.cmd == "truth":
        args.max_cycles = 0
        args.timeout = 120.0
        return cmd_eval(args, run_sim=False)
    if args.cmd == "run":
        if (args.n is None) != (args.m is None):
            print("perfbench: pass both --n and --m, or neither", file=sys.stderr)
            return 2
        return cmd_eval(args, run_sim=True)
    if args.cmd == "internal":
        return cmd_internal(args)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
