#!/usr/bin/env python3
"""Place mpy_soc's SRAM macros and size the die, for place and route.

Run in an mpy_soc design folder after `make sram` (it reads the generated
LEFs) and before `make syn`, so the config does not change under a finished
synthesis. It rewrites cfg/*cfg.yml: the toplevel width and height, and one
`hardmacro` entry per macro (Module 2 Task 3 does the same by hand):

  * mpy_mem's 32 macros, mpy_soc/u_mem/g_mac[0..31].ram/macro.mem (macro
    8 * bank + k is the k-th eighth of a bank). Every bank holds a quarter
    of memory (interleaved by word), so the logic should be close to all of
    them.
  * mpy_gc's table, mpy_soc/u_gc/u_atb/macro.mem, in the logic area.
  * With the I/O island (its LEFs are in the folder): the island's code
    SRAM, mpy_soc/u_ioc/u_code/macro.mem (as long as a memory macro), as a
    17th row on top of the right column, and its data SRAM, .../u_data/
    macro.mem, opposite on top of the left column, both with their pins on
    the channel. The nine USB RAM macros (usb_ram_macro.py, when their
    LEF is in the folder) are a grid of three per row in the channel
    under those, spread over its width so every pin edge faces open
    channel (--usb-top, --usb-gap-y); as flops (make_hammer_design.py --usb-flops) they take
    --usb-flop-area more room in the channel instead.

Layout. fakeram puts every signal pin on one side edge, and a 4096 x 36
macro is 3.95 mm x 0.16 mm. Two columns of 16 face each other across a
logic channel, the left column mirrored so every pin edge faces the
channel; a bank is one quadrant (bank 0 bottom left, 1 bottom right, 2 top
left, 3 top right). Standard cells are kept out of everything but the
channel, and the chip's I/O pins sit on the top edge across the channel
only, clk_i in the middle: left to Hammer they fill a whole die edge and
pull the logic out along the macros. Signal routing on met1 to met3 is
blocked outside the channel too: the router otherwise takes nets whose
pins are 1 mm apart at a channel edge on an 8 mm met1 detour through the
gaps between stacked macros and round the die margin (-15 ns at 12 ns). The channel gets --logic-area / --util
of room (default 45% full), 100 um from the die edge.

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
from mpy_synth import (GC_SRAM_MACRO, IOCORE_CODE_SRAM_MACRO, IOCORE_DATA_SRAM_MACRO, SRAM_BLOCKS,  # noqa: E402
                       SRAM_MACRO, SRAM_MACROS, SRAM_MACROS_PER_BLOCK, USB_SRAM_INSTS, USB_SRAM_MACRO)

SITE_W, ROW_H = 0.46, 2.72      # sky130 hd placement site
TOP = "mpy_soc"
# Hammer writes `place_inst <path> ...` into Tcl without quoting, so the
# brackets of the generate-block names are escaped here.
BANK_PATH = TOP + "/u_mem/g_mac\\[{b}\\].ram/macro.mem"
MET2_PITCH, MET2_OFFSET = 0.46, 0.23   # sky130 met2 tracks (vertical)
GC_PATH = TOP + "/u_gc/u_atb/macro.mem"
CODE_PATH = TOP + "/u_ioc/u_code/macro.mem"
DATA_PATH = TOP + "/u_ioc/u_data/macro.mem"
USB_PATHS = [TOP + "/u_ioc/" + p.replace("[", "\\[").replace("]", "\\]") + "/macro.mem" for p in USB_SRAM_INSTS]


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


def find_lef(folder: Path, name: str, optional: bool = False) -> Path | None:
    hits = sorted((folder / "build").rglob(f"{name}.lef"))
    if not hits:
        if optional:
            return None
        sys.exit(f"no {name}.lef under {folder}/build: run `make sram` first")
    return hits[0]


def usb_slots(n, x0, x1, y_top, uw, uh, gap_y, min_gap=150.0, cols=3):
    """n (x, y) places for the USB RAM macros in the channel x0..x1: a grid
    of up to `cols` per row, the rows going down from y_top, gap_y apart.

    Every macro has its pins on one side edge, so the macros of a row are
    spread evenly over the channel width: each pin edge then faces open
    channel (at least min_gap of it) and not the back of the next macro.
    Packed 60 um apart on the channel floor beside the GC table, they made
    the worst routing hotspots of the chip."""
    while cols > 1 and (x1 - x0 - cols * uw) / (cols + 1) < min_gap:
        cols -= 1
    gap = (x1 - x0 - cols * uw) / (cols + 1)
    if gap < min_gap:
        sys.exit("the channel is too narrow for one USB RAM macro")
    slots = []
    for i in range(n):
        r, c = divmod(i, cols)
        slots.append((x0 + gap + c * (uw + gap), y_top - uh - r * (uh + gap_y)))
    if slots[-1][1] < 0:
        sys.exit("the channel is too short for the USB RAM macros")
    return slots


def layout(bank, gc, args, island=None, usb=None):
    """Return (die_w, die_h, [(path, x, y, orient)], [(x, y, w, h) place blockages]).

    island is (code, data) LEF shapes when the run has the I/O island, usb
    the USB RAM macro's shape when those are macros."""
    bw, bh, bside = bank
    gw, gh, _ = gc
    m, s = args.margin, args.spacing
    logic = args.logic_area
    if island:
        # As macros the USB RAMs take channel room too: their own area and
        # a 20 um ring the placer keeps clear around each.
        usb_room = len(USB_PATHS) * (usb[0] + 40) * (usb[1] + 40) * args.util if usb else args.usb_flop_area
        logic += args.island_area + usb_room
    logic /= args.util
    place, blocks = [], []
    # Orientation that puts the pin edge on the given side.
    face = {"right": "r0" if bside == "right" else "my",
            "left": "r0" if bside == "left" else "my"}
    if SRAM_MACROS > SRAM_BLOCKS:
        # Two columns of macros, pin edges on the channel between them.
        per_col = SRAM_MACROS // 2
        g = args.stack_gap
        col_h = per_col * bh + (per_col - 1) * g
        # The island's two SRAMs are one more row, on top of each column.
        top_row = max(island[0][1], island[1][1]) + g if island else 0.0
        die_h = snap(col_h + top_row + 2 * m, ROW_H, up=True)
        halo = 10.0                      # clear of the macro pins
        chan = max(logic / col_h, gw + 2 * s) + 2 * halo
        die_w = snap(2 * m + 2 * bw + chan, SITE_W, up=True)
        x_left, x_right = m, die_w - m - bw
        for b in range(SRAM_BLOCKS):
            x, o = (x_left, face["right"]) if b % 2 == 0 else (x_right, face["left"])
            for k in range(SRAM_MACROS_PER_BLOCK):
                slot = (b // 2) * SRAM_MACROS_PER_BLOCK + k
                place.append((BANK_PATH.format(b=b * SRAM_MACROS_PER_BLOCK + k), x, m + slot * (bh + g), o))
        place.append((GC_PATH, x_left + bw + (chan - gw) / 2, m, "r0"))
        if island:
            (cw, _, cside), (dw, _, dside) = island
            if cw > bw or dw > bw:
                sys.exit("an island SRAM is wider than a memory macro: no room on top of a column")
            y = m + col_h + g
            # Pin edge on the channel: flush with the column's channel side.
            place.append((CODE_PATH, x_right, y, "r0" if cside == "left" else "my"))
            place.append((DATA_PATH, x_left + bw - dw, y, "r0" if dside == "right" else "my"))
        if usb:
            if not island:
                sys.exit("USB RAM macros without the island's SRAMs")
            uw, uh, _ = usb
            # Under the island's SRAMs, clear of the chip pins on the top
            # edge and of the GC table on the floor.
            slots = usb_slots(len(USB_PATHS), x_left + bw + halo, x_right - halo, die_h - m - args.usb_top,
                              uw, uh, args.usb_gap_y)
            if slots[-1][1] < m + gh + args.usb_gap_y:
                sys.exit("the USB RAM macros reach down to the GC table")
            for path, (x, y) in zip(USB_PATHS, slots):
                place.append((path, x, y, "r0"))
        # No standard cells outside the channel: the die margins and the
        # gaps between stacked macros would otherwise take logic.
        edge = x_left + bw + halo
        blocks.append((0, 0, edge, die_h))
        blocks.append((die_w - edge, 0, edge, die_h))
    elif bw > 4 * bh:
        # One column of banks, pins facing the logic on their pin side.
        col_h = SRAM_BLOCKS * bh + (SRAM_BLOCKS - 1) * s
        die_h = snap(max(col_h, gh) + 2 * m, ROW_H, up=True)
        logic_w = max(logic / (die_h - 2 * m), gw + 2 * s)
        die_w = snap(m + logic_w + s + bw + m, SITE_W, up=True)
        x_bank = die_w - m - bw          # banks on the right, logic on the left
        for b in range(SRAM_BLOCKS):
            place.append((BANK_PATH.format(b=b), x_bank, m + b * (bh + s), face["left"]))
        place.append((GC_PATH, m, m, "r0"))
        # Keep standard cells out of the strips around the 31 mm banks (the
        # die edge and the gaps between banks): without this the placer
        # spreads the logic along the whole die and the wires run for mm.
        bx = x_bank + 20
        blocks.append((bx, 0, die_w - bx, die_h))
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
    return (die_w, die_h, [(p, snap(x, SITE_W), snap(y, ROW_H), o) for p, x, y, o in place],
            [(snap(x, SITE_W), y, snap(w, SITE_W), h) for x, y, w, h in blocks])


def route_blocks(blocks, inset: float):
    """The place blockages, pulled `inset` back from the channel, for routing."""
    out = []
    for x, y, w, h in blocks:
        out.append((x, y, round(w - inset, 3), h) if x == 0 else (round(x + inset, 3), y, round(w - inset, 3), h))
    return out


def top_ports(path: Path) -> list[str]:
    """Port bits of mpy_soc, from the sv2v file (numeric ranges), clk_i first."""
    text = path.read_text()
    m = re.search(r"^module %s\b.*?^endmodule" % TOP, text, re.S | re.M)
    if not m:
        sys.exit(f"{path}: no module {TOP}")
    head = set(re.findall(r"\w+", m.group(0).split(");", 1)[0])[2:])
    bits = []
    for d in re.finditer(r"^\s*(?:input|output|inout)\s+(?:wire|reg)\s*(?:\[(\d+):(\d+)\])?\s*(\w+)\s*;", m.group(0), re.M):
        hi, lo, name = d.group(1), d.group(2), d.group(3)
        if name not in head:
            continue
        if hi is None:
            bits.append(name)
        else:
            bits += [f"{name}\\[{i}\\]" for i in range(int(lo), int(hi) + 1)]
    return bits


def pin_plan(bits: list[str], x0: float, x1: float, y: float) -> list[dict]:
    """One met2 location per port bit on the top edge between x0 and x1."""
    others = [b for b in bits if b != "clk_i"]
    order = others[:len(others) // 2] + ["clk_i"] + others[len(others) // 2:]
    step = (x1 - x0) / (len(order) + 1)
    if step < 4 * MET2_PITCH:
        sys.exit(f"{len(order)} pins do not fit on {x1 - x0:.0f} um of edge")
    out = []
    for i, b in enumerate(order):
        x = round(round((x0 + (i + 1) * step - MET2_OFFSET) / MET2_PITCH) * MET2_PITCH + MET2_OFFSET, 3)
        out.append({"pins": b, "side": "top", "layers": ["met2"], "location": [x, y]})
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder", nargs="?", default=".", type=Path, help="mpy_soc design folder")
    ap.add_argument("--logic-area", type=float, default=2.0e6,
                    help="standard-cell area in um^2 (mpy_soc synthesis: about 1.9e6 without macros)")
    ap.add_argument("--island-area", type=float, default=0.3e6,
                    help="standard-cell area the I/O island adds, um^2, when its SRAM LEFs are in "
                         "the folder (an estimate for CVE2, the peripherals and the USB core)")
    ap.add_argument("--usb-flop-area", type=float, default=1.4e6,
                    help="more standard-cell area when the USB RAMs are flops (no USB RAM macro LEF "
                         "in the folder): 36,864 bits with their read muxes, an estimate")
    ap.add_argument("--usb-top", type=float, default=300.0,
                    help="from the top macro edge down to the first row of USB RAM macros, um")
    ap.add_argument("--usb-gap-y", type=float, default=200.0, help="between rows of USB RAM macros, um")
    ap.add_argument("--util", type=float, default=0.45, help="target utilization of the logic area")
    ap.add_argument("--stack-gap", type=float, default=21.76, help="between stacked memory macros, um (whole rows)")
    ap.add_argument("--ports", type=Path, default=HERE / "converted" / (TOP + ".v"),
                    help="Verilog file with the top's port list (for the pin plan)")
    ap.add_argument("--margin", type=float, default=100.0, help="die edge to macro, um")
    ap.add_argument("--spacing", type=float, default=60.0, help="between macros, um")
    ap.add_argument("--dry-run", action="store_true", help="print, do not write the config")
    args = ap.parse_args()
    if yaml is None:
        sys.exit("PyYAML is missing; run this with the same python3 Hammer uses.")

    folder = args.folder.resolve()
    bank = read_lef(find_lef(folder, SRAM_MACRO["name"]))
    gc = read_lef(find_lef(folder, GC_SRAM_MACRO["name"]))
    isl = [find_lef(folder, m["name"], optional=True) for m in (IOCORE_CODE_SRAM_MACRO, IOCORE_DATA_SRAM_MACRO)]
    if any(isl) and not all(isl):
        sys.exit("only one of the island's two SRAM LEFs is in the folder")
    island = tuple(read_lef(p) for p in isl) if all(isl) else None
    if island and SRAM_MACROS <= SRAM_BLOCKS:
        sys.exit("the island's SRAMs are placed in the two-column layout only")
    usb_lef = find_lef(folder, USB_SRAM_MACRO["name"], optional=True)
    want_usb = (folder / "cfg" / "usb_ram_macro.json").is_file()
    if want_usb and not usb_lef:
        sys.exit(f"cfg/usb_ram_macro.json asks for {USB_SRAM_MACRO['name']} but its LEF is not under build/: "
                 "run usb_ram_macro.py first")
    usb = read_lef(usb_lef) if usb_lef else None
    die_w, die_h, place, blocks = layout(bank, gc, args, island, usb)
    # Chip I/O on the edge next to the logic. Left as the class has it, the
    # ~250 ports spread along the whole 36 mm bottom edge of the strip die
    # and drag the logic out after them.
    split = SRAM_MACROS > SRAM_BLOCKS
    strip = not split and bank[0] > 4 * bank[1]
    pins = [{"pins": "*", "side": "left", "layers": ["met3"]}] if strip else None
    if split:
        x0 = args.margin + bank[0]
        pins = pin_plan(top_ports(args.ports), x0 + 30, die_w - x0 - 30, die_h)

    print(f"{SRAM_MACRO['name']}: {bank[0]} x {bank[1]} um, pins on the {bank[2]}")
    print(f"{GC_SRAM_MACRO['name']}: {gc[0]} x {gc[1]} um, pins on the {gc[2]}")
    if island:
        for m, shape in zip((IOCORE_CODE_SRAM_MACRO, IOCORE_DATA_SRAM_MACRO), island):
            print(f"{m['name']}: {shape[0]} x {shape[1]} um, pins on the {shape[2]} (I/O island)")
    if usb:
        print(f"{USB_SRAM_MACRO['name']}: {usb[0]} x {usb[1]} um, pins on the {usb[2]} (USB, {len(USB_PATHS)} macros)")
    print(f"die {die_w} x {die_h} um ({die_w * die_h / 1e6:.1f} mm^2)")
    for p, x, y, o in place:
        print(f"  {p:45s} x {x:10.2f}  y {y:8.2f}  {o}")
    for x, y, w, h in blocks:
        print(f"  no standard cells in x {x:.2f}..{x + w:.2f}, y {y:.2f}..{y + h:.2f}")
    # Keep signal routes out of the macro columns (stay clear of the macro
    # pins on the channel side).
    rblocks = route_blocks(blocks, 15.0) if split else []
    for x, y, w, h in rblocks:
        print(f"  no met1-met3 routing in x {x:.2f}..{x + w:.2f}, y {y:.2f}..{y + h:.2f}")
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
    pcs[:] = [c for c in pcs if not (isinstance(c, dict) and str(c.get("path", "")).startswith(TOP + "/mpy_blk"))]
    for i, (x, y, w, h) in enumerate(blocks):
        pcs.append({"path": f"{TOP}/mpy_blk{i}", "type": "obstruction", "obs_types": ["place"],
                    "x": x, "y": y, "width": w, "height": h})
    for i, (x, y, w, h) in enumerate(rblocks):
        pcs.append({"path": f"{TOP}/mpy_blk_route{i}", "type": "obstruction", "obs_types": ["route"],
                    "layers": ["met1", "met2", "met3"], "x": x, "y": y, "width": w, "height": h})
    if pins:
        for k in [k for k in doc if k.startswith("vlsi.inputs.pin")]:
            del doc[k]
        vin = doc.get("vlsi.inputs")
        if isinstance(vin, dict):
            vin.pop("pin_mode", None)
            vin.pop("pin", None)
        doc["vlsi.inputs.pin_mode"] = "generated"
        doc["vlsi.inputs.pin.generate_mode"] = "semi_auto"
        doc["vlsi.inputs.pin.assignments"] = pins
        if split:
            xs = [q["location"][0] for q in pins]
            print(f"  {len(pins)} chip I/O pins on the top edge (met2), x {min(xs):.2f}..{max(xs):.2f}, "
                  "clk_i in the middle")
        else:
            print("  all chip I/O pins on the left edge (met3), next to the logic")
    text = yaml.safe_dump(doc, sort_keys=False, default_flow_style=False, width=100)
    cfg.write_text("\n".join(head + ["# Macro placement and die size by place_macros.py."]) + "\n" + text)
    print(f"wrote {cfg}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
