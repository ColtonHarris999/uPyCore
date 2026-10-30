#!/usr/bin/env python3
"""Build and run the RTL unit testbenches in ``upycore/tb``.

Each bench is verilated on its own with the RTL it needs, then run with the
arguments it expects: the decoder bench gets vectors from
``upycore/tb/mpy_decode_oracle.py`` (which needs the pinned mpy-cross), the
peripheral bench gets its plusargs from ``upycore/tools/mpy_periph_model.py``.
A bench passes when it exits 0 and prints its pass line.

Usage::

    python3 upycore/tools/unit_tests.py            # every bench
    python3 upycore/tools/unit_tests.py alu gc     # some of them
    python3 upycore/tools/unit_tests.py --list
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parents[2]
RTL = ROOT / "upycore" / "rtl"
TB = ROOT / "upycore" / "tb"
BUILD = ROOT / "build" / "unit"
ORACLE_SRC = ROOT / "build" / "oracle" / "src"

sys.path.insert(0, str(ROOT / "upycore" / "tools"))
import mpy_synth  # noqa: E402  (ALU_FILES: the ALU's RTL list)

FLAGS = [
    "--binary", "--timing", "-Wno-fatal", "-Wno-WIDTH", "-Wno-UNUSED",
    "-Wno-CASEINCOMPLETE", "-Wno-BLKSEQ", "-Wno-TIMESCALEMOD",
]


def _decode_args(work: Path) -> list[str]:
    vectors = work / "vectors.txt"
    r = subprocess.run(
        [sys.executable, str(TB / "mpy_decode_oracle.py"), "--root", str(ORACLE_SRC),
         "--out", str(vectors), "--xd-dir", str(work / "xd")],
        cwd=ROOT, capture_output=True, text=True,
    )
    if r.returncode != 0:
        raise RuntimeError("mpy_decode_oracle.py failed:\n" + r.stdout[-2000:] + r.stderr[-2000:])
    return [f"+VECTOR={vectors}"]


def _periph_args(work: Path) -> list[str]:
    r = subprocess.run(
        [sys.executable, str(ROOT / "upycore" / "tools" / "mpy_periph_model.py"), "--plusargs"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    return r.stdout.split()


@dataclass
class Bench:
    name: str
    rtl: list[str]
    passed: str                      # regex on the bench's output
    args: Callable[[Path], list[str]] = field(default=lambda work: [])


BENCHES = [
    Bench("mpy_alu", list(mpy_synth.ALU_FILES), r"^PASS mpy_alu "),
    Bench("mpy_boot", ["mpy_boot.sv", "../tb/tb_spi_nand.sv"], r"^PASS mpy_boot "),
    Bench("mpy_ca", ["mpy_ca.sv", "bsg_mem_1rw_sync_mask_write_bit.sv", "mpy_mem.sv"], r"^PASS mpy_ca "),
    Bench("mpy_container", ["mpy_container.sv"], r"^PASS mpy_container"),
    Bench("mpy_decode", ["mpy_decode.sv"], r"^mpy_decode checks: \d+ ok", _decode_args),
    Bench("mpy_fetch", ["bsg_mem_1rw_sync_mask_write_bit.sv", "mpy_mem.sv", "mpy_fetch.sv"],
          r"^PASS mpy_fetch "),
    Bench("mpy_shared_mem", ["bsg_mem_1rw_sync_mask_write_bit.sv", "mpy_mem.sv"], r"^PASS mpy_shared_mem "),
    Bench("mpy_gc", ["mpy_gc.sv"], r"^PASS mpy_gc "),
    Bench("mpy_periph", ["mpy_mmio_pkg.sv", "mpy_irq.sv", "mpy_periph.sv"], r"^PASS: mpy periph",
          _periph_args),
    Bench("mpy_value", ["mpy_regfile.sv", "bsg_mem_1rw_sync_mask_write_bit.sv", "mpy_mem.sv"], r"^MPY value encoding: ok"),
    Bench("upycore_umod_seq", ["upycore_umod_seq.sv"], r"^PASS upycore_umod_seq "),
]


def run_bench(b: Bench) -> tuple[bool, str]:
    work = BUILD / b.name
    work.mkdir(parents=True, exist_ok=True)
    top = f"tb_{b.name}"
    cmd = [os.environ.get("VERILATOR", "verilator"), *FLAGS, f"-I{RTL}", "--Mdir", str(work / "obj"),
           *[str(RTL / f) for f in b.rtl], str(TB / f"{top}.sv"), "--top-module", top]
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if r.returncode != 0:
        return False, "verilator failed:\n" + (r.stdout + r.stderr)[-3000:]
    try:
        args = b.args(work)
    except (RuntimeError, subprocess.CalledProcessError) as exc:
        return False, str(exc)
    r = subprocess.run([str(work / "obj" / f"V{top}"), *args], cwd=work, capture_output=True,
                       text=True, timeout=1800)
    out = r.stdout + r.stderr
    if r.returncode != 0 or not re.search(b.passed, out, re.M):
        return False, out[-3000:]
    line = next(l for l in out.splitlines() if re.search(b.passed, l))
    return True, line


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("names", nargs="*", help="benches to run (tb_ prefix optional)")
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args(argv)
    if args.list:
        for b in BENCHES:
            print(f"{b.name:18} {' '.join(b.rtl)}")
        return 0
    want = {n.removeprefix("tb_") for n in args.names}
    picked = [b for b in BENCHES if not want or b.name in want]
    unknown = want - {b.name for b in BENCHES}
    if unknown:
        print(f"unit_tests: unknown bench {', '.join(sorted(unknown))}", file=sys.stderr)
        return 2
    failed = []
    for b in picked:
        ok, detail = run_bench(b)
        print(f"{'PASS' if ok else 'FAIL':5} {b.name:18} {detail if ok else ''}".rstrip(), flush=True)
        if not ok:
            print(detail, flush=True)
            failed.append(b.name)
    print(f"unit_tests: {len(picked) - len(failed)} of {len(picked)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
