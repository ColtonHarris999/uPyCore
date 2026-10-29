#!/usr/bin/env python3
"""Rank register endpoints by logic depth in a flat gate-level netlist.

Reads the JSON that ``yosys write_json`` produces after ``synth -flatten``
(generic gates, ABC-mapped). Every combinational gate counts one level;
flip-flop outputs and module inputs are level 0. Each flip-flop data or
enable input, and each module output, is an endpoint. The report lists the
deepest endpoints grouped by register name, with the register the deepest
path to each starts from.

The levels compare designs; they are not nanoseconds. Yosys's ``ltp`` finds
the same longest path but reports only one; this lists all of them.

Usage::

    python3 upycore/tools/depth_report.py netlist.json [--min 150] [--top 40]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict

CLOCKISH = {"C", "CLK", "R", "S", "AD", "L"}   # clock and async set/reset/load pins


def is_ff(ctype: str) -> bool:
    return bool(re.match(r"\$_(S?DFF|DFFE|SDFFE|SDFFCE|ALDFF|DFFSR|DLATCH|SR)", ctype)) or ctype in (
        "$dff", "$adff", "$dffe", "$adffe", "$sdff", "$sdffe", "$aldff", "$dffsr")


def base_name(name: str) -> str:
    """Register name without the bit index or yosys slice suffix."""
    name = name.lstrip("\\")
    return re.sub(r"\s*\[\d+\]$", "", name)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("netlist")
    ap.add_argument("--top-module")
    ap.add_argument("--min", type=int, default=0, help="only endpoints at least this deep")
    ap.add_argument("--top", type=int, default=40, help="register groups to list")
    args = ap.parse_args(argv)

    with open(args.netlist) as f:
        mods = json.load(f)["modules"]
    top = args.top_module or next(iter(mods))
    mod = mods[top]

    # Name each net bit by its most readable name: RTL names over $-names.
    bitname: dict[int, str] = {}
    for name, info in mod["netnames"].items():
        hidden = name.startswith("$") or info.get("hide_name", 0)
        for i, b in enumerate(info["bits"]):
            if not isinstance(b, int):
                continue
            label = f"{name}[{i}]" if len(info["bits"]) > 1 else name
            if b not in bitname or (not hidden and bitname[b].startswith("$")):
                bitname[b] = label

    driver: dict[int, str] = {}           # bit -> combinational cell name
    cells = mod["cells"]
    comb_inputs: dict[str, list[int]] = {}
    endpoints: list[tuple[str, int]] = []  # (label, bit)
    for cname, c in cells.items():
        dirs = c.get("port_directions", {})
        conns = c["connections"]
        if is_ff(c["type"]):
            q = [b for p, bits in conns.items() if dirs.get(p) == "output" for b in bits]
            qname = bitname.get(q[0], cname) if q and isinstance(q[0], int) else cname
            for p, bits in conns.items():
                if dirs.get(p) == "input" and p not in CLOCKISH:
                    for b in bits:
                        if isinstance(b, int):
                            endpoints.append((f"{qname} <-{p}", b))
            continue
        ins = []
        for p, bits in conns.items():
            if dirs.get(p) == "output":
                for b in bits:
                    if isinstance(b, int):
                        driver[b] = cname
            else:
                ins.extend(b for b in bits if isinstance(b, int))
        comb_inputs[cname] = ins
    for pname, p in mod["ports"].items():
        if p["direction"] == "output":
            for i, b in enumerate(p["bits"]):
                if isinstance(b, int):
                    endpoints.append((f"{pname}[{i}] (output)", b))

    sys.setrecursionlimit(1_000_000)
    level: dict[int, int] = {}
    pred: dict[int, int] = {}

    def lvl(bit: int) -> int:
        # Iterative DFS: arrival level of a net bit.
        if bit in level:
            return level[bit]
        stack = [bit]
        while stack:
            b = stack[-1]
            if b in level:
                stack.pop()
                continue
            cn = driver.get(b)
            if cn is None:
                level[b] = 0
                stack.pop()
                continue
            pending = [i for i in comb_inputs[cn] if i not in level]
            if pending:
                stack.extend(pending)
                continue
            best, arg = -1, None
            for i in comb_inputs[cn]:
                if level[i] > best:
                    best, arg = level[i], i
            level[b] = best + 1
            if arg is not None:
                pred[b] = arg
            stack.pop()
        return level[bit]

    groups: dict[str, tuple[int, str, int]] = {}
    hist = defaultdict(int)
    for label, b in endpoints:
        d = lvl(b)
        hist[d // 10 * 10] += 1
        g = base_name(label.split(" <-")[0]) + (" <-" + label.split(" <-")[1] if " <-" in label else "")
        if g not in groups or d > groups[g][0]:
            groups[g] = (d, label, b)

    ranked = sorted(groups.items(), key=lambda kv: -kv[1][0])
    print(f"{top}: {len(endpoints)} endpoint bits, {len(groups)} register groups, deepest {ranked[0][1][0]}")
    over = [g for g in ranked if g[1][0] >= args.min]
    print(f"groups at >= {args.min} levels: {len(over)}")
    for g, (d, label, b) in over[: args.top]:
        # Walk back to the start of the path; note the named nets on the way.
        names, cur = [], b
        while cur in pred:
            cur = pred[cur]
            n = bitname.get(cur, "")
            if n and not n.startswith("$") and (not names or base_name(names[-1]) != base_name(n)):
                names.append(n)
        start = names[-1] if names else bitname.get(cur, "?")
        via = [base_name(n) for n in names[:-1]][::-1]
        via_s = (" via " + " > ".join(dict.fromkeys(via))) if via else ""
        print(f"{d:5d}  {g:<48} from {base_name(start)}{via_s}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
