#!/usr/bin/env python3
"""Run MicroPython's perf_bench suite on the simulator and check it against the oracle.

Each program is wrapped the way run-perfbench.py wraps it: pick the largest
parameter set with 10*n <= 12*N and m <= M, call bm_setup, then time run()
alone. The device times it with the measurement builtin bench_ticks (the
native cycle counter, as in runtime_profile.py); the oracle runs the same
source with bench_ticks stubbed out and supplies the expected result().

Status per run:
  PASS          result() matches the oracle
  WRONG         it runs, but result() differs
  ERROR         uncaught exception or crash (stderr tail kept)
  TIMEOUT       cycle budget exhausted
  SKIP          the program skips itself on both sides (bm_pidigits)
  ORACLE_ERROR  the oracle itself cannot run it; nothing to compare

Examples (from the repository root):
  python3 upycore/tools/perf_inventory.py
  python3 upycore/tools/perf_inventory.py --points 100x100,50x25 --modes all
  python3 upycore/tools/perf_inventory.py --only bm_float,bm_fft
"""
from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mpy_build as b  # noqa: E402
from bench import CONFIGS  # noqa: E402

SUITE = b.ROOT / "vendor/micropython/tests/perf_bench"
# viper_* need the native emitter; benchrun.py is upstream's harness.
EXCLUDED = {"benchrun"}

HARNESS = '''
def __perf_main(__perf_n, __perf_m):
    __perf_sel = (0, 0)
    __perf_p = None
    for __perf_nm, __perf_v in bm_params.items():
        if 10 * __perf_nm[0] <= 12 * __perf_n and __perf_nm[1] <= __perf_m and __perf_nm > __perf_sel:
            __perf_sel = __perf_nm
            __perf_p = __perf_v
    if __perf_p is None:
        print('NOPARAMS')
        return
    __perf_run, __perf_result = bm_setup(__perf_p)
    __perf_t0 = bench_ticks()
    __perf_run()
    __perf_t1 = bench_ticks()
    print('CYCLES', (__perf_t1 - __perf_t0) & 0x7FFFFFFF)
    print('RESULT', __perf_result())


__perf_main({n}, {m})
'''
ORACLE_STUB = "def bench_ticks():\n    return 0\n"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def programs(only: list[str] | None) -> list[Path]:
    out = []
    for p in sorted(SUITE.glob("*.py")):
        if p.stem in EXCLUDED or p.stem.startswith("viper_"):
            continue
        if only and p.stem not in only:
            continue
        out.append(p)
    return out


def oracle(src: Path, timeout: float, executable: str) -> tuple[str, str, int]:
    r = subprocess.run([executable, src.name], cwd=src.parent, capture_output=True, timeout=timeout)
    return r.stdout.decode(errors="replace"), r.stderr.decode(errors="replace"), r.returncode


def tagged(text: str, tag: str) -> list[str]:
    return [line[len(tag) + 1:] for line in text.splitlines() if line.startswith(tag + " ")]


def run_case(prog: Path, n: int, m: int, out: Path, modes: list, max_cycles: int, timeout: float, bigint: bool) -> dict:
    text = prog.read_text()
    if "__perf_" in text:
        raise ValueError(f"{prog.stem}: harness names collide")
    harness = HARNESS.format(n=n, m=m)
    work = out / f"{prog.stem}-{n}x{m}"
    work.mkdir(parents=True, exist_ok=True)
    dev_src = work / f"{prog.stem}.py"
    dev_src.write_text(text + harness)
    ora_dir = work / "oracle"
    ora_dir.mkdir(exist_ok=True)
    ora_src = ora_dir / f"{prog.stem}.py"
    ora_src.write_text(ORACLE_STUB + text + harness)
    row = {"name": prog.stem, "point": f"{n}x{m}", "source_sha256": sha(prog.read_bytes()),
           "harness_sha256": sha(dev_src.read_bytes()), "runs": []}

    if bigint and b.MPZ_ORACLE.is_file():
        reference, reference_name = str(b.MPZ_ORACLE), "MicroPython MPZ"
    elif bigint and prog.stem == "bm_pidigits":
        reference, reference_name = sys.executable, "CPython"
    else:
        reference, reference_name = str(b.ORACLE), "MicroPython"
    o_out, o_err, o_rc = oracle(ora_src, timeout, reference)
    row["reference"] = reference_name
    row["oracle"] = {"rc": o_rc, "stdout_tail": o_out[-400:], "stderr_tail": o_err[-400:]}
    o_results = tagged(o_out, "RESULT")
    o_skip = o_out.startswith("SKIP") or "NOPARAMS" in o_out
    row["expected"] = o_results[0] if o_results else None

    try:
        image = b.build_program(dev_src, work, source_name=dev_src.name, bigint=bigint)
    except Exception as e:  # noqa: BLE001 - recorded, not hidden
        row["runs"].append({"mode": "build", "status": "ERROR", "detail": f"{type(e).__name__}: {str(e)[-300:]}"})
        return row
    row["image_sha256"] = {s: sha(Path(f"{image}{s}").read_bytes()) for s in (".hex", ".tags.hex")}

    for mode, flags in modes:
        r = b.run_image(image, max_cycles=max_cycles, timeout=timeout, sim_args=flags)
        (work / f"{mode}.stdout").write_bytes(r.stdout)
        (work / f"{mode}.stderr").write_bytes(r.stderr)
        (work / f"{mode}.log").write_text(r.log)
        d_out = r.stdout.decode(errors="replace")
        d_err = r.stderr.decode(errors="replace")
        cyc = tagged(d_out, "CYCLES")
        res = tagged(d_out, "RESULT")
        run = {"mode": mode, "flags": flags, "halt": r.halt, "total_cycles": r.cycles, "ops": r.ops,
               "gc": r.gc, "kernel_cycles": int(cyc[0]) if cyc else None, "result": res[0] if res else None}
        if o_skip:
            ok = d_out.startswith("SKIP") or "NOPARAMS" in d_out
            run["status"] = "SKIP" if ok else "WRONG"
            run["detail"] = (o_out.strip().splitlines() or [""])[0]
        elif not o_results:
            run["status"] = "ORACLE_ERROR"
            run["detail"] = (o_err.strip().splitlines() or ["no output"])[-1]
        elif r.halt == "TIMEOUT":
            run["status"] = "TIMEOUT"
        elif r.exit_code != 0 or not res:
            run["status"] = "ERROR"
            run["detail"] = (d_err.strip().splitlines() or [r.halt])[-1]
        elif res[0] != o_results[0]:
            run["status"] = "WRONG"
            run["detail"] = f"device {res[0]!r} oracle {o_results[0]!r}"
        else:
            run["status"] = "PASS"
        row["runs"].append(run)
    return row


def markdown(data: dict) -> str:
    lines = ["# perf_bench inventory", "",
             f"Commit `{data['commit'][:10]}`, MicroPython `{data['micropython'][:10]}`. "
             "Kernel cycles are run() alone, timed on the device; time at 18 ns is "
             "the optimization plan's assumed period.", "",
             "| Program | Point | Mode | Reference | Status | Kernel cycles | ms at 18 ns | GC | Detail |",
             "| --- | --- | --- | --- | --- | ---: | ---: | ---: | --- |"]
    for row in data["rows"]:
        for run in row["runs"]:
            kc = run.get("kernel_cycles")
            ms = f"{kc * 0.000018:.1f}" if kc and run.get("status") == "PASS" else ""
            detail = str(run.get("detail", "")).replace("|", "\\|")[:90]
            lines.append(f"| `{row['name']}` | {row['point']} | {run['mode']} | {row['reference']} | {run['status']} | "
                         f"{kc if kc is not None else ''} | {ms} | {run.get('gc', '')} | {detail} |")
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=b.ROOT / "build/perf_inventory")
    ap.add_argument("--points", default="100x100", help="comma-separated NxM points (default 100x100)")
    ap.add_argument("--modes", default="both", help="'both' (CA and AALU on), 'all' (four configurations), or names")
    ap.add_argument("--only", default="", help="comma-separated program names")
    ap.add_argument("--bigint", action="store_true", help="enable wide integers and prefer the MicroPython MPZ oracle")
    ap.add_argument("--max-cycles", type=int, default=400_000_000)
    ap.add_argument("--timeout", type=float, default=3600)
    ap.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    args = ap.parse_args()

    if not b.ORACLE.exists() and not (args.bigint and (b.MPZ_ORACLE.is_file() or args.only == "bm_pidigits")):
        raise SystemExit(f"oracle missing at {b.ORACLE} (make oracle-variant)")
    if not b.SIM.exists():
        raise SystemExit(f"simulator missing at {b.SIM} (python3 upycore/tools/mpy_build.py sim)")
    if args.modes == "all":
        modes = CONFIGS
    else:
        names = args.modes.split(",")
        modes = [c for c in CONFIGS if c[0] in names]
    points = [tuple(int(v) for v in p.split("x")) for p in args.points.split(",")]
    progs = programs([s for s in args.only.split(",") if s] or None)

    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    # Measurement firmware: production firmware plus bench_ticks, the same
    # wrapper runtime_profile.py and timing_bench.py use.
    fw_src = out / "bench_fw.py"
    fw_mpy = out / "bench_fw.mpy"
    fw_src.write_text(b.firmware_source(bigint=args.bigint) + "\ndef bench_ticks():\n    return _ticks()\n")
    b.mpy_cross(fw_src, fw_mpy, "_fw.py")
    b.build_firmware = lambda *_args, **_kwargs: fw_mpy
    b.frozen_runtime_specs(compiler=False, runtime=sorted(b.RUNTIME_MODULES))

    git = lambda *a: subprocess.check_output(["git", *a], cwd=b.ROOT, text=True).strip()  # noqa: E731
    data = {"commit": git("rev-parse", "HEAD"),
            "working_tree_diff_sha256": sha(git("diff", "--", "upycore").encode()),
            "micropython": git("-C", "vendor/micropython", "rev-parse", "HEAD"),
            "compiler_sha256": sha(b.MPY_CROSS.read_bytes()), "compiler_flags": b.MPY_CROSS_FLAGS,
            "measurement_firmware_sha256": sha(fw_mpy.read_bytes()),
            "simulator_sha256": sha(b.SIM.read_bytes()),
            "verilator": subprocess.run(["verilator", "--version"], capture_output=True, text=True).stdout.strip(),
            "max_cycles": args.max_cycles, "boundary": "bench_ticks() around run(); 31-bit counter",
            "rows": []}
    cases = [(p, n, m) for p in progs for (n, m) in points]
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        futs = {pool.submit(run_case, p, n, m, out, modes, args.max_cycles, args.timeout, args.bigint): (p, n, m) for p, n, m in cases}
        for fut in concurrent.futures.as_completed(futs):
            p, n, m = futs[fut]
            row = fut.result()
            data["rows"].append(row)
            data["rows"].sort(key=lambda r: (r["name"], r["point"]))
            for run in row["runs"]:
                print(f"{row['name']:24} {row['point']:8} {run['mode']:5} {run['status']:12} "
                      f"{run.get('kernel_cycles') or '':>11} {run.get('detail', '')}"[:200], flush=True)
            (out / "results.json").write_text(json.dumps(data, indent=2) + "\n")
            (out / "results.md").write_text(markdown(data))
    bad = [r for row in data["rows"] for r in row["runs"] if r["status"] not in ("PASS", "SKIP", "ORACLE_ERROR")]
    print(f"perf_inventory: {sum(len(r['runs']) for r in data['rows'])} runs, {len(bad)} not passing; {out / 'results.md'}")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
