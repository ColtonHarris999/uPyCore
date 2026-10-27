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

# Each top is one slang --single-unit so file-scope includes share one $unit.
TOPS: dict[str, list[str]] = {
    "mpy_decode": ["mpy_decode.sv"],
    "mpy_regfile": ["mpy_regfile.sv"],
    "mpy_irq": ["mpy_mmio_pkg.sv", "mpy_irq.sv"],
    "mpy_periph": ["mpy_mmio_pkg.sv", "mpy_irq.sv", "mpy_periph.sv"],
    "mpy_container": ["mpy_container.sv"],
    "mpy_alu": ALU_FILES,
    "mpy_gc": ["mpy_gc.sv"],
    "mpy_mem": ["mpy_mem.sv"],
    "mpy_core": ALU_FILES + ["mpy_decode.sv", "mpy_core.sv"],
    "mpy_soc": ALU_FILES
    + ["mpy_decode.sv", "mpy_core.sv", "mpy_gc.sv", "mpy_mem.sv", "mpy_mmio_pkg.sv",
       "mpy_irq.sv", "mpy_periph.sv", "mpy_sys.sv", "mpy_pwm.sv", "mpy_pinmux.sv",
       "mpy_spi.sv", "mpy_i2c.sv", "mpy_wdt.sv", "mpy_adc.sv", "mpy_soc.sv"]
    # The USB coprocessor (upycore/docs/mpy_coproc.md), paths from RTL.
    + [os.path.relpath(ROOT / p, RTL) for p in (
        ["vendor/cve2/vendor/lowrisc_ip/ip/prim/rtl/prim_ram_1p_pkg.sv"]
        + [f"vendor/cve2/rtl/{n}.sv" for n in (
            "cve2_pkg", "cve2_alu", "cve2_compressed_decoder", "cve2_controller",
            "cve2_cs_registers", "cve2_csr", "cve2_counter", "cve2_decoder", "cve2_ex_block",
            "cve2_fetch_fifo", "cve2_id_stage", "cve2_if_stage", "cve2_load_store_unit",
            "cve2_multdiv_fast", "cve2_multdiv_slow", "cve2_prefetch_buffer", "cve2_pmp",
            "cve2_register_file_ff", "cve2_wb", "cve2_core", "cve2_clock_gate", "cve2_top")]
        + ["upycore/rtl/mpy_async_fifo.sv", "upycore/rtl/mpy_shared_ram.sv",
           "upycore/rtl/mpy_mbox.sv", "coproc/rtl/coproc_top.sv", "coproc/rtl/ice40_sim.sv"]
        + [f"vendor/no2usb/rtl/{n}.v" for n in (
            "usb", "usb_crc", "usb_ep_buf", "usb_ep_status", "usb_phy", "usb_rx_ll",
            "usb_rx_pkt", "usb_trans", "usb_tx_ll", "usb_tx_pkt")])],
}

# Include directories a top needs past upycore/rtl.
INCDIRS: dict[str, list[str]] = {
    "mpy_soc": ["vendor/cve2/rtl", "vendor/cve2/vendor/lowrisc_ip/ip/prim/rtl",
                "vendor/cve2/vendor/lowrisc_ip/dv/sv/dv_utils", "vendor/no2usb/rtl"],
}

# Gate mapping of full-size flash/SRAM/GC tables is a long memory job.
# Default ``--synth`` covers the logic tops; name gc/mem/soc explicitly.
GATES_DEFAULT = [
    "mpy_decode",
    "mpy_regfile",
    "mpy_irq",
    "mpy_periph",
    "mpy_container",
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
    paths = [RTL / name for name in TOPS[top]]
    missing = [p for p in paths if not p.is_file()]
    if missing:
        raise SynthError("missing RTL:\n  " + "\n  ".join(str(p) for p in missing))
    return paths


def _write_script(
    top: str,
    do_synth: bool,
    out_dir: Path,
    slang_extra: list[str],
) -> Path:
    sources = _files(top)
    ys = out_dir / f"{top}.ys"
    slang_extra = [f"-I {(ROOT / d).as_posix()}" for d in INCDIRS.get(top, [])] + list(slang_extra)
    extra = (" " + " ".join(slang_extra)) if slang_extra else ""
    lines = [
        "plugin -i slang",
        # One compilation unit: headers included before modules share $unit.
        # SYNTHESIS strips sim-only $readmemh / plusargs / giant initial loops.
        "read_slang --single-unit --top {top} -DSYNTHESIS -I {inc}{extra} {srcs}".format(
            top=top,
            inc=RTL.as_posix(),
            extra=extra,
            srcs=" ".join(p.as_posix() for p in sources),
        ),
        f"hierarchy -check -top {top}",
        "stat -hierarchy",
    ]
    if do_synth:
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
) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    ys = _write_script(top, do_synth, out_dir, slang_extra or [])
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
    elif args.synth:
        tops = list(GATES_DEFAULT)
    else:
        tops = list(TOPS.keys())

    failed: list[str] = []
    for top in tops:
        mode = "synth" if args.synth else "elaborate"
        print(f"== {mode} {top} ==")
        extra: list[str] = []
        if args.gc_pool_bytes is not None and top in ("mpy_gc", "mpy_soc"):
            extra.append(f"-G POOL_BYTES={args.gc_pool_bytes}")
        try:
            log = run_top(top, args.synth, args.out, extra)
        except SynthError as exc:
            print(exc, file=sys.stderr)
            failed.append(top)
            continue
        _print_stat_tail(log)
        print(f"log: {log.relative_to(ROOT)}")

    if failed:
        print("FAILED: " + ", ".join(failed), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
