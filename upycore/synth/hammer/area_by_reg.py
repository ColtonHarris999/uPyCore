#!/usr/bin/env python3
"""Split the area of a mapped netlist by module and by register.

Run from the design folder after `make syn`:

    python3 ~/upycore/upycore/synth/hammer/area_by_reg.py [design_folder] [--top 25]

For each module in the netlist it prints the flop area and the
combinational area, then the registers with the most flop area, grouped by
RTL name (rf_reg[3][12] counts toward rf). Flop area is exact per register.
Combinational cells carry Genus names (g1234), so the logic around a
register, such as the read muxes of rf, cannot be told apart from the rest
of the module; it is reported only per module.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

LIB = ("/home/projects/ee477/cad/pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/"
       "sky130_fd_sc_hd__tt_025C_1v80.lib")
NAND2 = 3.7536  # sky130_fd_sc_hd__nand2_1, one gate equivalent


def read_lib(path: Path) -> tuple[dict[str, float], set[str]]:
    """Cell areas, and the cells that hold state (ff or latch groups)."""
    area, seq = {}, set()
    cell = None
    for line in path.read_text(errors="replace").splitlines():
        m = re.match(r'\s*cell\s*\(\s*"?([\w]+)"?\s*\)', line)
        if m:
            cell = m.group(1)
            continue
        if cell is None:
            continue
        m = re.match(r"\s*area\s*:\s*([\d.]+)", line)
        if m and cell not in area:
            area[cell] = float(m.group(1))
        elif re.match(r"\s*(ff|latch|ff_bank|latch_bank)\s*\(", line):
            seq.add(cell)
    return area, seq


def reg_name(inst: str) -> str:
    """rf_reg[3][12] -> rf; u_x/cnt_reg[4] -> u_x/cnt."""
    name = inst.lstrip("\\")
    name = re.sub(r"(\[\d+\])+$", "", name)
    return re.sub(r"_reg$", "", name)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder", nargs="?", default=".", type=Path)
    ap.add_argument("--lib", default=LIB, type=Path)
    ap.add_argument("--top", default=25, type=int, help="registers to list per module")
    args = ap.parse_args()

    netlists = sorted((args.folder.resolve() / "build" / "syn-rundir").glob("*.mapped.v"))
    if not netlists:
        sys.exit("no build/syn-rundir/*.mapped.v; run make syn first")
    area, seq = read_lib(args.lib)

    # Per module: flop and logic area of its own cells, register groups,
    # and the submodules it instantiates.
    flop = defaultdict(float)
    logic = defaultdict(float)
    regs = defaultdict(Counter)
    bits = defaultdict(Counter)
    subs = defaultdict(Counter)
    module = None
    inst = re.compile(r"^\s*(\w+)\s+(?:#\s*\(.*?\)\s*)?(\\\S+|\w+)\s*\(")
    for line in netlists[0].read_text(errors="replace").splitlines():
        m = re.match(r"\s*module\s+(\w+)", line)
        if m:
            module = m.group(1)
            continue
        m = inst.match(line)
        if not m or module is None:
            continue
        cell, name = m.groups()
        if cell in area:
            if cell in seq:
                flop[module] += area[cell]
                regs[module][reg_name(name)] += area[cell]
                bits[module][reg_name(name)] += 1
            else:
                logic[module] += area[cell]
        elif cell not in {"module", "input", "output", "inout", "wire", "reg", "assign"}:
            subs[module][cell] += 1

    def total(mod: str) -> float:
        return flop[mod] + logic[mod] + sum(n * total(s) for s, n in subs[mod].items())

    top = netlists[0].name[: -len(".mapped.v")]
    grand = total(top)
    print(f"{netlists[0].name}: {grand:,.0f} um^2 ({grand / NAND2:,.0f} GE), "
          f"cell areas from {args.lib.name}")
    print(f"\n{'module':28s} {'inst':>4s} {'flops um2':>11s} {'logic um2':>11s} "
          f"{'own total':>11s} {'% of top':>8s}")
    # Instance counts through the hierarchy.
    count = Counter({top: 1})
    order = [top]
    for mod in order:
        for s, n in subs[mod].items():
            count[s] += n * count[mod]
            if s not in order:
                order.append(s)
    for mod in order:
        own = flop[mod] + logic[mod]
        n = count[mod]
        print(f"{mod:28s} {n:4d} {flop[mod]:11,.0f} {logic[mod]:11,.0f} {own:11,.0f} "
              f"{100 * n * own / grand:7.1f}%")

    for mod in order:
        if not regs[mod]:
            continue
        print(f"\nRegisters in {mod} by flop area (flops {flop[mod]:,.0f} um^2 per instance):")
        for name, a in regs[mod].most_common(args.top):
            print(f"  {name:40s} {bits[mod][name]:6d} bits {a:10,.0f} um^2 "
                  f"{100 * a / flop[mod]:5.1f}% of flops {100 * count[mod] * a / grand:5.1f}% of top")
    return 0


if __name__ == "__main__":
    sys.exit(main())
