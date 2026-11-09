#!/usr/bin/env python3
"""Place mpy_soc's SRAM macros and size the die, for place and route.

Run in an mpy_soc design folder after `make sram` (it reads the generated
LEFs) and before `make syn`, so the config does not change under a finished
synthesis. It rewrites cfg/*cfg.yml: the toplevel width and height, and one
`hardmacro` entry per macro (Module 2 Task 3 does the same by hand):

  * mpy_mem's four banks, mpy_soc/u_mem/g_blk[0..3].ram/macro.mem. Every bank
    holds a quarter of memory (interleaved by word), so the logic should be
    close to all four pins.
  * mpy_gc's table, mpy_soc/u_gc/u_atb/macro.mem, in the logic area.

Layout. fakeram puts every signal pin on one side edge. For a macro much
wider than tall (the 31 mm x 0.22 mm d32768_w36 at the default pin pitch)
the four banks are stacked in one column with the logic beside their pin
edge. Otherwise two columns of two face each other across a logic channel,
the left column mirrored so both pin edges face the channel. The logic
area gets --logic-area / --util of room (default 40% full), 100 um from the die edge
and 60 um between macros.

    python3 ~/upycore/upycore/synth/hammer/place_macros.py [design_folder]

sweep.sh par runs it for TOP=mpy_soc. Check the result in Innovus
(`make par-to-floorplan` or the final layout) before trusting the numbers.
"""

from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    yaml = None

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "tools"))
from mpy_synth import GC_SRAM_MACRO, SRAM_BLOCKS, SRAM_MACRO  # noqa: E402

SITE_W, ROW_H = 0.46, 2.72      # sky130 hd placement site
TOP = "mpy_soc"
# Hammer writes `place_inst <path> ...` into Tcl without quoting, so the
# brackets of the generate-block names are escaped here.
BANK_PATH = TOP + "/u_mem/g_blk\\[{b}\\].ram/macro.mem"
GC_PATH = TOP + "/u_gc/u_atb/macro.mem"


def snap(v: float, grid: float, up: bool = False) -> float:
    n = math.ceil(v / grid - 1e-9) if up else round(v / grid)
    return round(n * grid, 3)


def read_lef(path: Path) -> tuple[float, float, str]:
    """Width, height and pin side ('left' or 'right') of a fakeram LEF."""
    text = path.read_text()
    m = re.search(r"\bSIZE\s+([\d.]+)\s+BY\s+([\d.]+)", text)
    if not m:
        sys.exit(f"{path}: no SIZE line")
    w, h = float(m.group(1)), float(m.group(2))
    xs = []
    for pin in re.finditer(r"\bPIN\s+(\S+)(.*?)\bEND\s+\1\s", text, re.S):
        body = pin.group(2)
        if re.search(r"\bUSE\s+(POWER|GROUND)\b", body):
            continue
        for r in re.finditer(r"\bRECT\s+([-\d.]+)\s+[-\d.]+\s+([-\d.]+)\s+[-\d.]+", body):
            xs.append((float(r.group(1)) + float(r.group(2))) / 2)
    if not xs:
        sys.exit(f"{path}: no signal pins found")
    side = "left" if sum(xs) / len(xs) < w / 2 else "right"
    return w, h, side


def find_lef(folder: Path, name: str) -> Path:
    hits = sorted((folder / "build").rglob(f"{name}.lef"))
    if not hits:
        sys.exit(f"no {name}.lef under {folder}/build: run `make sram` first")
    return hits[0]


def layout(bank, gc, args):
    """Return (die_w, die_h, [(path, x, y, orient)])."""
    bw, bh, bside = bank
    gw, gh, _ = gc
    m, s = args.margin, args.spacing
    logic = args.logic_area / args.util
    place = []
    # Orientation that puts the pin edge on the given side.
    face = {"right": "r0" if bside == "right" else "my",
            "left": "r0" if bside == "left" else "my"}
    if bw > 4 * bh:
        # One column of banks, pins facing the logic on their pin side.
        col_h = SRAM_BLOCKS * bh + (SRAM_BLOCKS - 1) * s
        die_h = snap(max(col_h, gh) + 2 * m, ROW_H, up=True)
        logic_w = max(logic / (die_h - 2 * m), gw + 2 * s)
        die_w = snap(m + logic_w + s + bw + m, SITE_W, up=True)
        x_bank = die_w - m - bw          # banks on the right, logic on the left
        for b in range(SRAM_BLOCKS):
            place.append((BANK_PATH.format(b=b), x_bank, m + b * (bh + s), face["left"]))
        place.append((GC_PATH, m, m, "r0"))
    else:
        rows = math.ceil(SRAM_BLOCKS / 2)
        col_h = rows * bh + (rows - 1) * s
        die_h = snap(col_h + 2 * m, ROW_H, up=True)
        chan = max(logic / (die_h - 2 * m), gw + 2 * s)
        die_w = snap(2 * m + 2 * bw + 2 * s + chan, SITE_W, up=True)
        x_left, x_right = m, die_w - m - bw
        for b in range(SRAM_BLOCKS):
            r, c = divmod(b, 2)
            x, o = (x_left, face["right"]) if c == 0 else (x_right, face["left"])
            place.append((BANK_PATH.format(b=b), x, m + r * (bh + s), o))
        place.append((GC_PATH, x_left + bw + s + (chan - gw) / 2, m, "r0"))
    return die_w, die_h, [(p, snap(x, SITE_W), snap(y, ROW_H), o) for p, x, y, o in place]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder", nargs="?", default=".", type=Path, help="mpy_soc design folder")
    ap.add_argument("--logic-area", type=float, default=2.0e6,
                    help="standard-cell area in um^2 (mpy_soc synthesis: about 1.9e6 without macros)")
    ap.add_argument("--util", type=float, default=0.4, help="target utilization of the logic area")
    ap.add_argument("--margin", type=float, default=100.0, help="die edge to macro, um")
    ap.add_argument("--spacing", type=float, default=60.0, help="between macros, um")
    ap.add_argument("--dry-run", action="store_true", help="print, do not write the config")
    args = ap.parse_args()
    if yaml is None:
        sys.exit("PyYAML is missing; run this with the same python3 Hammer uses.")

    folder = args.folder.resolve()
    bank = read_lef(find_lef(folder, SRAM_MACRO["name"]))
    gc = read_lef(find_lef(folder, GC_SRAM_MACRO["name"]))
    die_w, die_h, place = layout(bank, gc, args)

    print(f"{SRAM_MACRO['name']}: {bank[0]} x {bank[1]} um, pins on the {bank[2]}")
    print(f"{GC_SRAM_MACRO['name']}: {gc[0]} x {gc[1]} um, pins on the {gc[2]}")
    print(f"die {die_w} x {die_h} um ({die_w * die_h / 1e6:.1f} mm^2)")
    for p, x, y, o in place:
        print(f"  {p:45s} x {x:10.2f}  y {y:8.2f}  {o}")
    if args.dry_run:
        return 0

    cfgs = sorted((folder / "cfg").glob("*cfg.yml"))
    if not cfgs:
        sys.exit(f"no cfg/*cfg.yml in {folder}")
    cfg = cfgs[0]
    lines = cfg.read_text().splitlines()
    head = [l for l in lines[:1] if l.startswith("#")]
    doc = yaml.safe_load(cfg.read_text()) or {}
    key = "vlsi.inputs.placement_constraints"
    if key in doc:
        pcs = doc[key]
    else:
        pcs = doc.setdefault("vlsi.inputs", {}).setdefault("placement_constraints", [])
    tops = [c for c in pcs if isinstance(c, dict) and c.get("type") == "toplevel"]
    if not tops:
        sys.exit(f"{cfg}: no toplevel placement constraint to resize")
    tops[0]["width"], tops[0]["height"] = die_w, die_h
    pcs[:] = [c for c in pcs if not (isinstance(c, dict) and c.get("type") == "hardmacro")]
    for p, x, y, o in place:
        pcs.append({"path": p, "type": "hardmacro", "x": x, "y": y, "orientation": o})
    text = yaml.safe_dump(doc, sort_keys=False, default_flow_style=False, width=100)
    cfg.write_text("\n".join(head + ["# Macro placement and die size by place_macros.py."]) + "\n" + text)
    print(f"wrote {cfg}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
