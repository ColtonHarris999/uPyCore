#!/usr/bin/env python3
"""Open-flow area and timing of the I/O island (decision D1, gate G5).

    island_measure.py --core cve2|hazard3 [--mul 0|1] --lib build/lib/tt.lib [--top iocore_top]

Area: slang reads the island, `synth -flatten`, flops onto sky130_fd_sc_hd
with dfflibmap, logic with ABC (`abc -liberty`, its default area-oriented
script), then `stat -liberty`. The SRAM macros (bsg_mem_1rw_sync_mask_
write_bit) are black boxes, so their area is not counted; their bytes are
reported beside it. Timing: upycore/tools/sta/run.py on the same top
(unmapped, deterministic; the numbers compare designs, they are not Genus
ns). Results go to build/iocore/measure/<core>_m<mul>/ and a JSON summary.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import iocore_files as F  # noqa: E402

BLACKBOX = """(* blackbox *)
module bsg_mem_1rw_sync_mask_write_bit #(parameter int width_p = 1, parameter int els_p = 1,
    parameter int latch_last_read_p = 0, parameter int enable_clock_gating_p = 0,
    parameter int addr_width_lp = (els_p > 1) ? $clog2(els_p) : 1) (
    input logic clk_i, input logic reset_i, input logic [width_p-1:0] data_i,
    input logic [addr_width_lp-1:0] addr_i, input logic v_i, input logic [width_p-1:0] w_mask_i,
    input logic w_i, output logic [width_p-1:0] data_o);
endmodule
(* blackbox *)
module bsg_mem_1r1w_sync_mask_write_bit #(parameter int width_p = 1, parameter int els_p = 1,
    parameter int read_write_same_addr_p = 0,
    parameter int addr_width_lp = (els_p > 1) ? $clog2(els_p) : 1) (
    input logic clk_i, input logic reset_i, input logic w_v_i, input logic [width_p-1:0] w_mask_i,
    input logic [addr_width_lp-1:0] w_addr_i, input logic [width_p-1:0] w_data_i, input logic r_v_i,
    input logic [addr_width_lp-1:0] r_addr_i, output logic [width_p-1:0] r_data_o);
endmodule
"""


def split_verilog(files: list[str]) -> tuple[list[str], list[str]]:
    """(Hazard3's .v files, the rest). Hazard3 is Verilog-2005 whose
    functions are static and called from several always blocks; yosys-slang
    reports conflicting drivers on their arguments, so Yosys's own Verilog
    frontend reads it and slang imports the modules."""

    v = [f for f in files if f.startswith("vendor/hazard3/")]
    return v, [f for f in files if f not in v]


# Tops that are not the island: the hart-side bridge (its FIFOs are the
# clock-domain crossing, counted in the I/O work's area budget).
OTHER_TOPS = {"mpy_iobr": (["upycore/rtl/mpy_async_fifo.sv", "upycore/rtl/mpy_iobr.sv"], []),
              # The USB device alone (it is also inside iocore_top).
              "iocore_usb": (F.USB_RTL, F.USB_INCDIRS)}


def _yosys_usb(files: list[str]) -> list[str]:
    """Copies of two no2usb files for the open flow, the vendored files
    unchanged (every simulator and the class flow read them as they are):
    usb.v wraps one asynchronously reset register block in `if (IRQ)`,
    which Yosys's flop inference rejects (the copy drops the wrapper, the
    same logic for IRQ = 1, iocore_usb's setting); usb_rx_ll.v gives one
    register an initial value "for simulation benefit only", which becomes
    a $initstate cell the timer cannot read (the copy drops it)."""
    edits = {
        "vendor/no2usb/rtl/usb.v": ("\talways @(posedge clk or posedge rst)\n\t\tif (IRQ) begin\n",
                                    "\talways @(posedge clk or posedge rst)\n\t\tbegin\n"),
        "vendor/no2usb/rtl/usb_rx_ll.v": ("reg  [1:0] dec_sym_1 = 2'b00;", "reg  [1:0] dec_sym_1;"),
    }
    out = []
    for f in files:
        if f in edits:
            old, new = edits[f]
            text = (ROOT / f).read_text()
            assert old in text, f"{f} changed: update _yosys_usb"
            dst = ROOT / "build" / "iocore" / "measure" / ("no2usb_" + Path(f).name)
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_text(text.replace(old, new))
            f = str(dst.relative_to(ROOT))
        out.append(f)
    return out


def sources(core: str, top: str) -> tuple[list[str], list[str]]:
    files, inc = OTHER_TOPS[top] if top in OTHER_TOPS else F.island(core)
    return _yosys_usb(list(files)), inc


def area(core: str, mul: int, lib: Path, top: str, out: Path, params: list[str]) -> dict:
    files, inc = sources(core, top)
    files = [f for f in files if not f.endswith(("bsg_mem_1rw_sync_mask_write_bit.sv",
                                                 "bsg_mem_1r1w_sync_mask_write_bit.sv"))]

    rel = os.path.relpath(out, ROOT)
    (out / "bb.sv").write_text(BLACKBOX)
    shutil.copy(lib, out / "tt.lib")
    incs = " ".join(f"-I {d}" for d in ["upycore/rtl", *inc])
    g = " ".join(f"-G {p}" for p in ([] if top in OTHER_TOPS else [f"CORE={F_CORE[core]}", f"MUL={mul}"]) + params)
    ys = [
        f"read_slang -j 1 --single-unit --top {top} -DSYNTHESIS {incs} {g} {rel}/bb.sv {' '.join(files)}",
        f"hierarchy -check -top {top}",
        f"synth -flatten -top {top}",
        f"dfflibmap -liberty {rel}/tt.lib -dont_use *lpflow*",
        f"abc -liberty {rel}/tt.lib -dont_use *lpflow*",
        "opt_clean",
        f"tee -o {rel}/area.txt stat -liberty {rel}/tt.lib",
    ]
    (out / "area.ys").write_text("\n".join(ys) + "\n")
    yosys = os.environ.get("YOSYS", "yowasp-yosys")
    r = subprocess.run([yosys, "-q", "-l", f"{rel}/area.log", "-s", f"{rel}/area.ys"], cwd=ROOT,
                       stdout=subprocess.DEVNULL)
    if r.returncode:
        raise SystemExit(f"yosys failed; see {rel}/area.log")
    text = (out / "area.txt").read_text()
    m = re.search(r"Chip area for (?:top )?module '\\?\S+':\s+([\d.]+)", text)
    cells = re.search(r"^\s*(\d+)\s+\S+\s+cells$", text, re.M)
    flops = sum(int(n) for n, c in re.findall(r"^\s*(\d+)\s+\S+\s+sky130_fd_sc_hd__((?:s|e)?df\w+)", text, re.M))
    seq = sum(float(a) for a in re.findall(r"^\s*\d+\s+(\S+)\s+sky130_fd_sc_hd__(?:(?:s|e)?df|dl)\w+", text, re.M))
    return {"area_um2": float(m.group(1)) if m else None,
            "cells": int(cells.group(1)) if cells else None, "flops": flops,
            "seq_area_um2": round(seq, 1)}


F_CORE = {"cve2": 0, "hazard3": 1}


def timing(core: str, mul: int, lib: Path, top: str, out: Path, params: list[str]) -> dict:
    files, inc = sources(core, top)
    usb = any("no2usb" in f for f in files)
    # The clock gate is a clock-tree cell, not a data path (see the stand-in).
    files = [("iocore/rtl/sta/cve2_clock_gate.sv" if f.endswith("cve2_clock_gate.sv") else
              "iocore/rtl/sta/bsg_mem_1r1w_sync_mask_write_bit.sv"
              if f.endswith("bsg_mem_1r1w_sync_mask_write_bit.sv") else f) for f in files]
    # The island's io_clk timing: the USB device is a pin-flop stand-in (its
    # SIE samples on both usb_clk edges, which this timer does not model).
    if top != "iocore_usb" and any("no2usb" in f for f in files):
        files = [f for f in files if "no2usb" not in f and not f.startswith(("iocore/rtl/usb/",
                 "build/iocore/measure/", "iocore/rtl/sta/bsg_mem_1r1w"))] + ["iocore/rtl/sta/iocore_usb.sv"]
    cmd = [sys.executable, str(ROOT / "upycore/tools/sta/run.py"), f"{top}_{core}_m{mul}",
           "--module", top, "--lib", str(lib), "--out", str(out / "sta"), "--groups", "60",
           *(["--techmap-async"] if usb else []),
           "--rtl", *files] + ([] if top in OTHER_TOPS else
                                ["--param", f"CORE={F_CORE[core]}", "--param", f"MUL={mul}"])
    for p in params:
        cmd += ["--param", p]
    for d in inc:
        cmd += ["--inc", d]
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if r.returncode:
        raise SystemExit(r.stdout + r.stderr)
    first = (out / "sta" / "sta.txt").read_text().split("\n", 1)[0]
    m = re.search(r"([\d.]+)", first)
    return {"worst_ns": float(m.group(1)) if m else None, "sta_head": first}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--core", choices=tuple(F_CORE), default="cve2")
    ap.add_argument("--mul", type=int, default=0)
    ap.add_argument("--lib", type=Path, default=ROOT / "build/lib/tt.lib")
    ap.add_argument("--top", default="iocore_top")
    ap.add_argument("--param", action="append", default=[])
    ap.add_argument("--no-timing", action="store_true")
    a = ap.parse_args()
    out = ROOT / "build" / "iocore" / "measure" / f"{a.top}_{a.core}_m{a.mul}"
    out.mkdir(parents=True, exist_ok=True)
    res = {"core": a.core, "mul": a.mul, "top": a.top, **area(a.core, a.mul, a.lib.resolve(), a.top, out, a.param)}
    if not a.no_timing:
        res.update(timing(a.core, a.mul, a.lib.resolve(), a.top, out, a.param))
    (out / "summary.json").write_text(json.dumps(res, indent=1) + "\n")
    print(json.dumps(res))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
