#!/usr/bin/env python3
"""Verilate and run the peripheral unit benches.

Each bench drives one block on its own bus and compares against
``mpy_periph_model.py``. The model prints the plusargs a bench needs.

Usage::

    python3 upycore/tools/run_benches.py            # every bench
    python3 upycore/tools/run_benches.py periph_io  # one bench
    python3 upycore/tools/run_benches.py --list
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / "upycore" / "tools" / "mpy_periph_model.py"
BUILD = ROOT / "build" / "benches"


@dataclass
class Bench:
    name: str
    top: str
    sources: list[str]
    model_flag: str | None = None   # mpy_periph_model.py option that prints the plusargs


PERIPH = ["upycore/rtl/mpy_mmio_pkg.sv", "upycore/rtl/mpy_irq.sv", "upycore/rtl/mpy_periph.sv"]

BENCHES = [
    Bench("periph", "tb_mpy_periph", PERIPH + ["upycore/tb/tb_mpy_periph.sv"], "--plusargs"),
    Bench("periph_io", "tb_mpy_periph_io", PERIPH + ["upycore/tb/tb_mpy_periph_io.sv"], "--io-plusargs"),
    Bench("pwm", "tb_mpy_pwm", ["upycore/rtl/mpy_pwm.sv", "upycore/rtl/mpy_pinmux.sv",
                                "upycore/tb/tb_mpy_pwm.sv"], "--pwm-plusargs"),
    Bench("spi", "tb_mpy_spi", ["upycore/rtl/mpy_spi.sv", "upycore/tb/tb_spi_flash.sv",
                                "upycore/tb/tb_mpy_spi.sv"]),
]


def plusargs(b: Bench) -> list[str]:
    if not b.model_flag:
        return []
    out = subprocess.run([sys.executable, str(MODEL), b.model_flag], check=True,
                         capture_output=True, text=True).stdout
    return out.split()


def build(b: Bench) -> Path:
    obj = BUILD / b.name
    exe = obj / f"V{b.top}"
    srcs = [ROOT / s for s in b.sources]
    if exe.exists() and all(s.stat().st_mtime < exe.stat().st_mtime for s in srcs):
        return exe
    obj.mkdir(parents=True, exist_ok=True)
    cmd = [os.environ.get("VERILATOR", "verilator"), "-sv", "--binary", "--timing",
           "--timescale", "1ns/1ps", "-Wno-fatal", "-Wno-WIDTH", "-Wno-UNUSED",
           f"+incdir+{ROOT / 'upycore' / 'rtl'}", "--top-module", b.top, "--Mdir", str(obj),
           "-j", str(os.cpu_count() or 2)] + [str(s) for s in srcs]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit(f"{b.name}: verilator failed\n{r.stdout[-3000:]}{r.stderr[-3000:]}")
    return exe


def run(b: Bench) -> bool:
    exe = build(b)
    r = subprocess.run([str(exe)] + plusargs(b), capture_output=True, text=True)
    out = r.stdout + r.stderr
    ok = r.returncode == 0 and "PASS:" in out
    lines = [ln for ln in out.splitlines() if ln and not ln.startswith("- ")]
    print(f"{'PASS' if ok else 'FAIL'}  {b.name}")
    for ln in lines:
        print(f"      {ln}")
    return ok


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("names", nargs="*")
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args(argv)
    picked = [b for b in BENCHES if not args.names or b.name in args.names]
    if args.list:
        for b in BENCHES:
            print(f"{b.name:<12} {b.top}")
        return 0
    if not picked:
        print("run_benches: nothing selected", file=sys.stderr)
        return 1
    failed = [b.name for b in picked if not run(b)]
    print(f"run_benches: {len(picked) - len(failed)} of {len(picked)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
