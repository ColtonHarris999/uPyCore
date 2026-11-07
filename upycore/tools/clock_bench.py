#!/usr/bin/env python3
"""Matched-image cycle cost of an RTL timing change, and its net effect.

Runs the same linked images on two tb_mpy_soc executables (``--before`` and
``--after``) and reports, per workload, the cycle counts and the ratio. With
``--before-ns`` and ``--after-ns`` (clock periods) it also reports execution
time, cycles x period, so a change that adds cycles but shortens the period
can be judged as a whole.

Workloads:
  * the AES and Fannkuch kernels from the pinned MicroPython perf_bench
    (the same harness and measurement boundary as runtime_profile.py);
  * every program in upycore/programs/bench, whole-program cycles, in the
    default (CA and AALU on) configuration;
  * the timing_bench.py arithmetic loops and pystone.

Firmware and images are identical for both executables, so the comparison is
of the RTL alone. Output must match between the two runs.

Usage::

    python3 upycore/tools/clock_bench.py --before OLD/Vtb_mpy_soc \\
        --after build/mpy_soc/obj/Vtb_mpy_soc --before-ns 18 --after-ns 10 \\
        --out build/clock_bench.json
"""
from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mpy_build as b  # noqa: E402
import runtime_profile as rp  # noqa: E402
import timing_bench as tb  # noqa: E402


def _cycles(stdout: bytes) -> int | None:
    for line in stdout.decode(errors="replace").splitlines():
        if line.startswith("CYCLES ") or line.startswith("BENCH "):
            return int(line.split()[1])
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--before", type=Path, required=True)
    ap.add_argument("--after", type=Path, required=True)
    ap.add_argument("--before-ns", type=float)
    ap.add_argument("--after-ns", type=float)
    ap.add_argument("--loops", type=int, default=1000)
    ap.add_argument("--pystone-loops", type=int, default=300)
    ap.add_argument("--max-cycles", type=int, default=400_000_000)
    ap.add_argument("--out", type=Path)
    args = ap.parse_args()

    work = Path(tempfile.mkdtemp(prefix="clock_bench_"))
    fwsrc = work / "bench_fw.py"
    fwmpy = work / "bench_fw.mpy"
    fwsrc.write_text(b.firmware_source() + "\ndef bench_ticks():\n    return _ticks()\n")
    b.mpy_cross(fwsrc, fwmpy, "_fw.py")
    real_fw = b.build_firmware
    rows = []

    def run_pair(name: str, image: Path, kernel: bool) -> None:
        res = {}
        outs = {}
        for label, exe in (("before", args.before), ("after", args.after)):
            r = b.run_image(image, max_cycles=args.max_cycles, timeout=3600, sim_executable=exe.resolve())
            if r.exit_code:
                raise SystemExit(f"{name} {label}: {r.halt}: {r.stderr[-500:]!r}")
            res[label] = _cycles(r.stdout) if kernel else r.cycles
            outs[label] = (r.stdout if not kernel else
                           b"\n".join(l for l in r.stdout.splitlines()
                                     if not l.startswith((b"CYCLES ", b"BENCH "))), r.stderr)
        if outs["before"] != outs["after"]:
            raise SystemExit(f"{name}: output differs between the two executables")
        row = {"name": name, "kind": "kernel" if kernel else "program",
               "before_cycles": res["before"], "after_cycles": res["after"],
               "cycle_ratio": res["after"] / res["before"]}
        if args.before_ns and args.after_ns:
            row["time_ratio"] = row["cycle_ratio"] * args.after_ns / args.before_ns
        rows.append(row)
        print(f"{name:22} {res['before']:>12} {res['after']:>12} {100 * (row['cycle_ratio'] - 1):+8.3f}%"
              + (f"   time x{row['time_ratio']:.3f}" if "time_ratio" in row else ""), flush=True)

    # Kernels with the measurement builtin.
    b.build_firmware = lambda: fwmpy
    for kname in ("misc_aes", "bm_fannkuch"):
        p = b.ROOT / "vendor/micropython/tests/perf_bench" / f"{kname}.py"
        d = work / kname
        d.mkdir()
        src = d / f"{kname}.py"
        src.write_text(rp.kernel_source(kname))
        run_pair(kname, b.build_program(src, d, source_name=f"{kname}.py"), True)
    for name in [*tb.CASES, "pystone"]:
        d = work / name
        d.mkdir()
        src = d / f"{name}.py"
        src.write_text(tb.source(name, args.loops, args.pystone_loops))
        run_pair(name, b.build_program(src, d, source_name=f"{name}.py"), True)

    # Whole programs on the production firmware.
    b.build_firmware = real_fw
    for src in sorted((b.ROOT / "upycore/programs/bench").glob("*.py")):
        d = work / ("prog_" + src.stem)
        d.mkdir()
        run_pair(src.stem, b.build_program(src, d, source_name=src.name), False)

    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps({"before": str(args.before), "after": str(args.after),
                                        "before_ns": args.before_ns, "after_ns": args.after_ns,
                                        "rows": rows}, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
