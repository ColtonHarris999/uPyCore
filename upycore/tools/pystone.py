#!/usr/bin/env python3
"""Cycles per pystone on mpy_soc (upycore/programs/bench/pystone.py).

The program is built with LOOPS set to two counts and booted once per
count. The cycle counter runs from reset to halt, so each run also pays
for boot, the firmware's start-up, and Setup(). Those are the same in
both runs, and the difference over the extra loops is the cost of one
pystone. That is the part a board's ticks_us() brackets in MicroPython's
perf_bench. Each run's last line must match CPython's.

With --mhz, the clock from the backend flow turns that into pystones per
second. The simulated memories are the ones in mpy_defs.svh (SRAM one
cycle, flash MPY_FLASH_WAIT_STATES on top). If the target's SRAM or flash
needs more cycles at that clock, the counts here are low.

Usage::

    python3 upycore/tools/pystone.py
    python3 upycore/tools/pystone.py --mhz 100
    python3 upycore/tools/pystone.py --loops 200 1000 --sim-arg +CA=0
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "upycore" / "tools"))

import mpy_build as build  # noqa: E402

SRC = ROOT / "upycore" / "programs" / "bench" / "pystone.py"
_LOOPS_RE = re.compile(r"^LOOPS = \d+$", re.M)


def run(loops: int, args: argparse.Namespace) -> int:
    work = build.BUILD / "pystone" / str(loops)
    work.mkdir(parents=True, exist_ok=True)
    src = work / "pystone.py"
    src.write_text(_LOOPS_RE.sub(f"LOOPS = {loops}", SRC.read_text(), count=1))
    want = subprocess.run([sys.executable, "-I", str(src)], capture_output=True, check=True).stdout
    image = build.build_program(src, work, "pystone.py", compiler=args.compiler)
    res = build.run_image(image, args.max_cycles, sim_args=args.sim_arg)
    if res.exit_code != 0:
        raise build.BuildError(f"{loops} loops: {res.halt}\n{res.stderr.decode(errors='replace')}")
    if res.stdout != want:
        raise build.BuildError(f"{loops} loops: printed {res.stdout!r}, CPython printed {want!r}")
    print(f"{loops:>8} loops {res.cycles:>14,} cycles {res.gc:>5} collections")
    return res.cycles


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--loops", type=int, nargs=2, default=(100, 500), metavar=("SHORT", "LONG"))
    ap.add_argument("--mhz", type=float, help="clock from the backend flow")
    ap.add_argument("--compiler", choices=("mpy-cross", "mpyc"), default="mpy-cross")
    ap.add_argument("--max-cycles", type=int, default=2_000_000_000)
    ap.add_argument("--sim-arg", action="append", default=[], help="plusarg for the simulator, e.g. +CA=0")
    args = ap.parse_args()
    short, long_ = sorted(args.loops)
    if short == long_:
        ap.error("--loops needs two different counts")
    try:
        build.build_sim()
        c_short = run(short, args)
        c_long = run(long_, args)
    except (build.BuildError, subprocess.CalledProcessError) as exc:
        print(exc, file=sys.stderr)
        return 1
    # The core counter is 32 bits and wraps.
    if c_long <= c_short:
        print("the long run wrapped the 32-bit cycle counter; use fewer loops", file=sys.stderr)
        return 1
    per = (c_long - c_short) / (long_ - short)
    print(f"cycles per pystone {per:,.1f}")
    print(f"start-up and Setup() {c_short - per * short:,.0f} cycles")
    print(f"pystones per MHz {1e6 / per:,.2f}")
    if args.mhz:
        print(f"pystones/s at {args.mhz:g} MHz {args.mhz * 1e6 / per:,.0f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
