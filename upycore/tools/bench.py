#!/usr/bin/env python3
"""Cycle counts for the accelerator switches (upycore/docs/mpy_ca.md).

Each program under upycore/programs/bench is built once and run four
times: with the container accelerator and the async ALU off, each one on
its own, and both on. Every run must print the same output. The firmware
is the same in all four, so the "off" column already has the firmware's
bulk copies; they just run on the core instead of mpy_ca.

Usage::

    python3 upycore/tools/bench.py               # every benchmark
    python3 upycore/tools/bench.py float dict    # some of them
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "upycore" / "tools"))

import mpy_build as build  # noqa: E402

BENCH = ROOT / "upycore" / "programs" / "bench"
CONFIGS = [
    ("off", ["+CA=0", "+AALU=0"]),
    ("CA", ["+CA=1", "+AALU=0"]),
    ("AALU", ["+CA=0", "+AALU=1"]),
    ("both", ["+CA=1", "+AALU=1"]),
]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("names", nargs="*", help="benchmark names (default: all)")
    ap.add_argument("--max-cycles", type=int, default=400_000_000)
    args = ap.parse_args()
    progs = sorted(BENCH.glob("*.py"))
    if args.names:
        progs = [p for p in progs if p.stem in args.names]
    try:
        build.build_sim()
    except build.BuildError as exc:
        print(exc, file=sys.stderr)
        return 2
    print(f"{'program':12}" + "".join(f"{name:>12}" for name, _ in CONFIGS) + "   both vs off")
    bad = 0
    for prog in progs:
        try:
            image = build.build_program(prog, build.BUILD / "bench" / prog.stem, prog.name)
        except build.BuildError as exc:
            print(f"{prog.stem:12} build failed: {exc}")
            bad += 1
            continue
        cycles = []
        outputs = set()
        for _, plus in CONFIGS:
            res = build.run_image(image, args.max_cycles, sim_args=plus)
            if res.exit_code != 0:
                print(f"{prog.stem:12} {res.halt} under {' '.join(plus)}")
                bad += 1
                break
            cycles.append(res.cycles)
            outputs.add((res.stdout, res.stderr))
        else:
            if len(outputs) != 1:
                print(f"{prog.stem:12} outputs differ between configurations")
                bad += 1
                continue
            row = "".join(f"{c:>12,}" for c in cycles)
            print(f"{prog.stem:12}{row}   {cycles[-1] / cycles[0] - 1:+.1%}")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
