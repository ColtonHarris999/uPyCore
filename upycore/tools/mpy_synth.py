#!/usr/bin/env python3
"""Elaborate or synthesize uPyCore RTL with Yosys + yosys-slang.

The simulator Verilator flow accepts file-scope includes and sim-only
plusargs. This driver builds one slang compilation unit per top, defines
``SYNTHESIS``, and either stops after hierarchy/stat or runs ``synth``.

Requires Yosys with the slang frontend on PATH (OSS CAD Suite provides
``yosys -m slang`` / ``plugin -i slang``).

Usage::

    mpy_synth.py                  # elaborate every known top
    mpy_synth.py mpy_core         # one top
    mpy_synth.py --synth mpy_alu  # map to gates and write cell counts
    mpy_synth.py --depth 150 mpy_core  # flat gates; endpoints >= 150 levels deep
    mpy_synth.py --list
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RTL = ROOT / "upycore" / "rtl"
BUILD = ROOT / "build" / "synth"

# Shared FPU / integer datapath under mpy_alu.
ALU_FILES = [
    "upycore_add.sv",
    "upycore_smul.sv",
    "upycore_umul_seq.sv",
    "upycore_udiv_seq.sv",
    "upycore_int_alu.sv",
    "upycore_mul.sv",
    "upycore_div.sv",
    "upycore_ipow.sv",
    "upycore_fp_add.sv",
    "upycore_fp_mul.sv",
    "upycore_fp_divrem.sv",
    "upycore_fp_pow.sv",
    "upycore_fpu.sv",
    "mpy_alu.sv",
]

# The I/O island (iocore/tools/iocore_files.py): CVE2 and the island's RTL.
# Entries with a '/' are paths from the repository root.
sys.path.insert(0, str(ROOT / "iocore" / "tools"))
import iocore_files  # noqa: E402

_ISLAND, ISLAND_INCDIRS = iocore_files.island("cve2")
ISLAND_FILES = [f for f in _ISLAND if not f.endswith("bsg_mem_1rw_sync_mask_write_bit.sv")]

# Each top is one slang --single-unit so file-scope includes share one $unit.
TOPS: dict[str, list[str]] = {
    "mpy_decode": ["mpy_decode.sv"],
    "mpy_regfile": ["mpy_regfile.sv"],
    "mpy_irq": ["mpy_mmio_pkg.sv", "mpy_irq.sv"],
    "mpy_periph": ["mpy_mmio_pkg.sv", "mpy_irq.sv", "mpy_periph.sv"],
    "mpy_hash": ["upycore_add.sv", "mpy_hash.sv"],
    "mpy_hash_slot": ["upycore_add.sv", "mpy_hash.sv", "upycore_umod_seq.sv", "mpy_hash_slot.sv"],
    "mpy_shortlist": ["mpy_shortlist.sv"],
    "mpy_bytecopy": ["upycore_add.sv", "mpy_bytecopy.sv"],
    "mpy_ca": ["mpy_ca.sv"],
    "mpy_key_equal": ["upycore_add.sv", "mpy_key_equal.sv"],
    "mpy_map_engine": ["upycore_add.sv", "mpy_hash.sv", "upycore_umod_seq.sv", "mpy_key_equal.sv", "mpy_map_engine.sv"],
    "mpy_rehash_stream": ["upycore_add.sv", "mpy_hash.sv", "mpy_hash_slot.sv", "upycore_umod_seq.sv", "mpy_rehash_stream.sv"],
    "mpy_collection": ["upycore_add.sv", "mpy_hash.sv", "upycore_umod_seq.sv", "mpy_key_equal.sv", "mpy_map_engine.sv", "mpy_bulk.sv", "mpy_hash_slot.sv", "mpy_rehash_stream.sv", "mpy_ca.sv", "mpy_bytecopy.sv", "mpy_shortlist.sv", "mpy_collection.sv"],
    "mpy_bulk": ["upycore_add.sv", "mpy_hash.sv", "upycore_umod_seq.sv", "mpy_key_equal.sv", "mpy_map_engine.sv", "mpy_bulk.sv", "mpy_hash_slot.sv", "mpy_rehash_stream.sv"],
    "upycore_umod_seq": ["upycore_umod_seq.sv"],
    "mpy_alu": ALU_FILES,
    "mpy_gc": ["bsg_mem_1rw_sync_mask_write_bit.sv", "mpy_gc.sv"],
    "mpy_mem": ["bsg_mem_1rw_sync_mask_write_bit.sv", "mpy_mem.sv"],
    "mpy_boot": ["mpy_boot.sv"],
    "mpy_core": ALU_FILES + ["upycore_umod_seq.sv", "mpy_decode.sv", "mpy_fetch.sv", "mpy_core.sv"],
    "mpy_soc": ALU_FILES
    + ["upycore_umod_seq.sv", "mpy_decode.sv", "mpy_fetch.sv", "mpy_core.sv", "mpy_gc.sv", "mpy_ca.sv", "mpy_hash.sv", "mpy_key_equal.sv", "mpy_map_engine.sv", "mpy_bulk.sv", "mpy_hash_slot.sv", "mpy_rehash_stream.sv", "mpy_bytecopy.sv", "mpy_shortlist.sv", "mpy_collection.sv",
       "bsg_mem_1rw_sync_mask_write_bit.sv", "mpy_mem.sv", "mpy_boot.sv", "mpy_async_fifo.sv",
       "mpy_iobr.sv"] + ISLAND_FILES + ["mpy_soc.sv"],
    "mpy_iobr": ["mpy_async_fifo.sv", "mpy_iobr.sv"],
}
# Include directories a top needs beyond upycore/rtl (from the repository root).
INCDIRS: dict[str, list[str]] = {"mpy_soc": ISLAND_INCDIRS}

# mpy_core and everything under it (upycore/synth/hammer/converted/mpy_core.v).
CORE_FILES = TOPS["mpy_core"]

# Behavioral stand-in for BaseJump's SRAM wrapper. The EE 477 flow reads
# BaseJump's file instead and swaps each 4096 x 36 instance for this
# bsg_fakeram macro (MPY_MEM_MACRO_WORDS x MPY_MEM_WIDTH in mpy_defs.svh).
SRAM_MODEL = "bsg_mem_1rw_sync_mask_write_bit.sv"
SRAM_MACRO = {"name": "fakeram_d4096_w36", "family": "1rw", "depth": 4096, "width": 36,
              "mask": True, "mux": 1, "vt": ""}
SRAM_BLOCKS = 4   # MPY_MEM_BLOCKS: interleaved shared image/data SRAM banks
SRAM_MACROS_PER_BLOCK = 8   # MPY_MEM_MACROS_PER_BLOCK: macros in a bank, by row[14:12]
SRAM_MACROS = SRAM_BLOCKS * SRAM_MACROS_PER_BLOCK   # mpy_mem's g_mac[0..31]
# mpy_gc's allocation table: 600 words x 64 bits (32 two-bit entries per
# word, mpy_abi.GC_TABLE_BYTES / 16 blocks), the same wrapper and hook.
GC_SRAM_MACRO = {"name": "fakeram_d600_w64", "family": "1rw", "depth": 600, "width": 64,
                 "mask": True, "mux": 1, "vt": ""}
# The I/O island's code (16 KB) and data (7.5 KB) SRAMs: the same wrapper,
# 4096 x 32 and 1920 x 32 (iocore_top's CODE_WORDS and DATA_WORDS).
IOCORE_CODE_SRAM_MACRO = {"name": "fakeram_d4096_w32", "family": "1rw", "depth": 4096, "width": 32,
                          "mask": True, "mux": 1, "vt": ""}
IOCORE_DATA_SRAM_MACRO = {"name": "fakeram_d1920_w32", "family": "1rw", "depth": 1920, "width": 32,
                          "mask": True, "mux": 1, "vt": ""}
# The USB SIE's nine 256 x 16 RAMs (endpoint buffers and status; the
# microcode ROM is logic): BaseJump's bsg_mem_1r1w_sync_mask_write_bit,
# one read and one write port on usb_clk (iocore/rtl/usb/ice40_cells.sv).
USB_SRAM_MACRO = {"name": "fakeram_d256_w16", "family": "1r1w", "depth": 256, "width": 16,
                  "mask": True, "mux": 1, "vt": ""}
USB_SRAM_BLOCKS = 9
USB_SRAM_MODEL = "iocore/rtl/usb/bsg_mem_1r1w_sync_mask_write_bit.sv"
# Where the nine sit under iocore_top (u_ioc in mpy_soc), down to BaseJump's
# wrapper: no2usb's SB_RAM40_4K instances (four per endpoint buffer, one for
# the endpoint status) through iocore/rtl/usb/ice40_cells.sv.
USB_SRAM_INSTS = ([f"u_usb/u_usb/{buf}_buf_I/block[{i}].ram_I/g_ram.u_ram/u_mem" for buf in ("tx", "rx") for i in range(4)]
                  + ["u_usb/u_usb/ep_status_I/ebr_I/g_ram.u_ram/u_mem"])

# Gate mapping the SRAM blocks as flops is a long memory job (the class
# flow uses macros instead), so mem and soc stay elaborate-only here.
# Default ``--synth`` covers the logic tops; name gc/mem/soc explicitly.
GATES_DEFAULT = [
    "mpy_decode",
    "mpy_regfile",
    "mpy_irq",
    "mpy_periph",
    "mpy_hash",
    "mpy_hash_slot",
    "mpy_ca",
    "upycore_umod_seq",
    "mpy_alu",
    "mpy_core",
]


class SynthError(Exception):
    pass


def _yosys() -> str:
    return os.environ.get("YOSYS", "yosys")


def _files(top: str) -> list[Path]:
    if top not in TOPS:
        raise SynthError(f"unknown top {top!r}; choose from: {', '.join(TOPS)}")
    paths = [(ROOT / name if "/" in name else RTL / name) for name in TOPS[top]]
    missing = [p for p in paths if not p.is_file()]
    if missing:
        raise SynthError("missing RTL:\n  " + "\n  ".join(str(p) for p in missing))
    return paths


def _write_script(
    top: str,
    do_synth: bool,
    out_dir: Path,
    slang_extra: list[str],
    depth: bool = False,
) -> Path:
    sources = _files(top)
    ys = out_dir / f"{top}.ys"
    extra = (" " + " ".join(slang_extra)) if slang_extra else ""
    lines = [
        "plugin -i slang",
        # One compilation unit: headers included before modules share $unit.
        # SYNTHESIS strips sim-only $readmemh / plusargs / giant initial loops.
        "read_slang --single-unit --top {top} -DSYNTHESIS -I {inc}{extra} {srcs}".format(
            top=top,
            inc=" -I ".join([RTL.as_posix(), *[(ROOT / d).as_posix() for d in INCDIRS.get(top, [])]]),
            extra=extra,
            srcs=" ".join(p.as_posix() for p in sources),
        ),
        f"hierarchy -check -top {top}",
        "stat -hierarchy",
    ]
    if depth:
        # Flat, so a path is counted across module boundaries. No resource
        # sharing: after flattening, share can merge operators of different
        # units (say the integer divider's shifter and the FPU's) into one
        # cell, which wires up paths the RTL does not have. A hierarchical
        # backend run does not share across modules.
        lines += [
            f"synth -flatten -noshare -top {top}",
            f"write_json {out_dir.as_posix()}/{top}.json",
        ]
    elif do_synth:
        # Keep hierarchy for readable area; flatten only inside synth's own passes.
        lines += [
            f"synth -top {top}",
            "stat -hierarchy",
            f"write_verilog -norename {out_dir.as_posix()}/{top}.netlist.v",
        ]
    ys.write_text("\n".join(lines) + "\n")
    return ys


def run_top(
    top: str,
    do_synth: bool,
    out_dir: Path,
    slang_extra: list[str] | None = None,
    depth: bool = False,
) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    ys = _write_script(top, do_synth, out_dir, slang_extra or [], depth)
    log = out_dir / f"{top}.log"
    cmd = [_yosys(), "-s", str(ys)]
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    log.write_text(r.stdout + r.stderr)
    if r.returncode != 0:
        raise SynthError(
            f"yosys failed for {top} (log {log.relative_to(ROOT)}):\n"
            + (r.stdout + r.stderr)[-4000:]
        )
    return log


def _print_stat_tail(log: Path) -> None:
    text = log.read_text()
    # Last statistics block is the most relevant (post-synth when present).
    idx = text.rfind("Printing statistics.")
    if idx < 0:
        idx = text.rfind("=== ")
    print(text[idx:] if idx >= 0 else text[-2000:])


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "tops",
        nargs="*",
        help="tops to build (default: all). See --list.",
    )
    ap.add_argument("--list", action="store_true", help="print known tops and exit")
    ap.add_argument(
        "--synth",
        action="store_true",
        help="run synth (gate mapping) after elaboration; default is elaborate+stat only",
    )
    ap.add_argument(
        "--gc-pool-bytes",
        type=int,
        default=None,
        help="override mpy_gc POOL_BYTES (useful with --synth to shrink the ATB)",
    )
    ap.add_argument(
        "--depth",
        type=int,
        metavar="LEVELS",
        default=None,
        help="map flat to generic gates and rank register endpoints by logic depth "
        "(depth_report.py), listing those at least LEVELS deep",
    )
    ap.add_argument(
        "-o",
        "--out",
        type=Path,
        default=BUILD,
        help=f"output directory (default {BUILD.relative_to(ROOT)})",
    )
    args = ap.parse_args()

    if args.list:
        for name, files in TOPS.items():
            mark = " (gates default)" if name in GATES_DEFAULT else " (elaborate)"
            print(f"{name}{mark}: {' '.join(files)}")
        return 0

    if args.tops:
        tops = args.tops
    elif args.synth or args.depth is not None:
        tops = list(GATES_DEFAULT)
    else:
        tops = list(TOPS.keys())

    failed: list[str] = []
    for top in tops:
        mode = "depth" if args.depth is not None else "synth" if args.synth else "elaborate"
        print(f"== {mode} {top} ==")
        extra: list[str] = []
        if args.gc_pool_bytes is not None and top in ("mpy_gc", "mpy_soc"):
            extra.append(f"-G POOL_BYTES={args.gc_pool_bytes}")
        try:
            log = run_top(top, args.synth, args.out, extra, args.depth is not None)
        except SynthError as exc:
            print(exc, file=sys.stderr)
            failed.append(top)
            continue
        if args.depth is not None:
            import depth_report

            depth_report.main([str(args.out / f"{top}.json"), "--top-module", top, "--min", str(args.depth)])
        else:
            _print_stat_tail(log)
        print(f"log: {log.relative_to(ROOT)}")

    if failed:
        print("FAILED: " + ", ".join(failed), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
