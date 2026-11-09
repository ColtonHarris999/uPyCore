#!/usr/bin/env python3
"""Open timing estimate of one top, for comparing two RTL versions.

No Genus or OpenSTA is needed: YoWASP Yosys (with yosys-slang) and the
sky130 typical-corner liberty. The flow:

1. slang reads the RTL as mpy_synth.py does; ``synth -flatten -noshare
   -noabc``. SRAM macros are replaced by ``sram_stub.sv`` (every pin a flop).
2. Async resets are dropped (``noarst.v``; the sign-off constraints false-path
   the reset), enables and sync resets become logic (``dffunmap``), and every
   flop becomes an ``FFBOX`` black box, so the logic is one network.
3. ``--mapped``: ABC maps it onto sky130 with a delay target and buffers
   high-fanout nets (``map.abc``). Without it, Yosys's simple gates are
   timed as the matching sky130 cells (deterministic, but no restructuring).
4. ``sta_lite.py`` times every flop input and output from the liberty's
   NLDM tables (fanout load, no wires) and lists the worst register groups.

The numbers are not Genus nanoseconds: compare a change against the same
flow on the baseline (``--compare A B``). ``INPUTS_ONLY=1`` in the
environment times only paths that start at module inputs (the class
constraints give those half the period).

Usage (from the repository root)::

    python3 upycore/tools/sta/run.py mpy_core --lib tt.lib [--mapped] [--out build/sta/core]
    python3 upycore/tools/sta/run.py --compare base/sta.txt new/sta.txt

The liberty is ``sky130_fd_sc_hd__tt_025C_1v80.lib`` (OpenROAD-flow-scripts,
flow/platforms/sky130hd/lib). Outputs must be inside the repository, since
YoWASP only sees the working directory. A flat mpy_soc needs about 15 minutes
and 6 GB.
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "upycore" / "tools"))


def load(path: Path) -> dict[str, tuple[float, str]]:
    out = {}
    for ln in open(path):
        m = re.match(r"\s+([\d.]+)\s+(\S+)\s+<- (\S+)", ln)
        if m:
            out[m.group(2)] = (float(m.group(1)), m.group(3))
    return out


def compare(a: Path, b: Path, top: int = 15) -> None:
    base, new = load(a), load(b)
    print(f"worst: base {max(v[0] for v in base.values()):.3f}  new {max(v[0] for v in new.values()):.3f}")
    print("register group                                     base      new")
    for d, g in sorted(((v[0], g) for g, v in new.items()), reverse=True)[:top]:
        o = base.get(g, (None,))[0]
        print(f"  {g:46s} {('%8.3f' % o) if o is not None else '     new'} {d:8.3f}")
    worse = [(d, g, base[g][0]) for g, (d, _) in new.items() if g in base and d > base[g][0] + 0.1]
    if worse:
        print("slower than base by more than 0.1:")
        for d, g, o in sorted(worse, reverse=True)[:top]:
            print(f"  {g:46s} {o:8.3f} {d:8.3f}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("top", nargs="?")
    ap.add_argument("--lib", type=Path, help="sky130_fd_sc_hd tt liberty")
    ap.add_argument("--mapped", action="store_true", help="map with ABC before timing")
    ap.add_argument("--out", type=Path, help="output folder inside the repository (default build/sta/<top>)")
    ap.add_argument("--groups", type=int, default=60, help="register groups to list")
    ap.add_argument("--compare", nargs=2, type=Path, metavar=("BASE", "NEW"))
    ap.add_argument("--rtl", nargs="+", help="files (from the repository root) instead of mpy_synth.TOPS[top]")
    ap.add_argument("--inc", action="append", default=[], help="extra include directory")
    ap.add_argument("--param", action="append", default=[], help="top parameter NAME=VALUE (slang -G)")
    ap.add_argument("--module", help="the top module when it differs from the top name")
    args = ap.parse_args()
    if args.compare:
        compare(*args.compare)
        return 0
    if not args.top or not args.lib:
        ap.error("give a top and --lib (or --compare)")
    import mpy_synth as m
    out = (args.out or ROOT / "build" / "sta" / args.top).resolve()
    out.mkdir(parents=True, exist_ok=True)
    rel = os.path.relpath(out, ROOT)
    for f in ("sram_stub.sv", "ffbox.v", "ffmap.v", "noarst.v", "map.abc"):
        shutil.copy(HERE / f, out / f)
    shutil.copy(args.lib, out / "tt.lib")
    def src(f: str) -> str:
        if Path(f).name == m.SRAM_MODEL:
            return f"{rel}/sram_stub.sv"
        return f if "/" in f else f"upycore/rtl/{f}"
    files = " ".join(src(f) for f in (args.rtl or m.TOPS[args.top]))
    module = args.module or args.top
    inc = " ".join(f"-I {d}" for d in ["upycore/rtl", *args.inc])
    params = " ".join(f"-G {p}" for p in args.param)
    lines = [
        f"read_slang -j 1 --single-unit --top {module} -DSYNTHESIS {inc} {params} {files}",
        f"read_verilog -lib {rel}/ffbox.v",
        f"hierarchy -check -top {module}",
        f"synth -flatten -noshare -noabc -top {module}",
        f"techmap -map {rel}/noarst.v",
        "async2sync",
        "dffunmap",
        f"techmap -map {rel}/ffmap.v",
        "opt_clean",
        "stat",
    ]
    if args.mapped:
        lines += [
            f"abc -liberty {rel}/tt.lib -D 1000 -script {rel}/map.abc",
            "opt_clean",
            f"read_liberty -lib {rel}/tt.lib",
        ]
    lines.append(f"write_json {rel}/netlist.json")
    (out / "flow.ys").write_text("\n".join(lines) + "\n")
    yosys = os.environ.get("YOSYS", "yowasp-yosys")
    r = subprocess.run([yosys, "-q", "-l", f"{rel}/yosys.log", "-s", f"{rel}/flow.ys"], cwd=ROOT,
                       stdout=subprocess.DEVNULL)
    if r.returncode:
        print(f"yosys failed; see {rel}/yosys.log")
        return 1
    with open(out / "sta.txt", "w") as f:
        r = subprocess.run([sys.executable, str(HERE / "sta_lite.py"), str(out / "netlist.json"),
                            str(out / "tt.lib"), str(args.groups)], stdout=f)
    print((out / "sta.txt").read_text().split("\n", 1)[0])
    print(f"report: {rel}/sta.txt")
    return r.returncode


if __name__ == "__main__":
    raise SystemExit(main())
