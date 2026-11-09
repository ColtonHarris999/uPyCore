#!/usr/bin/env python3
"""Build and run tb_iocore, the I/O island's standalone bench.

    iocore_sim.py build [--core cve2|hazard3] [--mul 0|1]
    iocore_sim.py run APP [--core ...] [-- plusargs]   (APP built with make -C iocore/sw APP=...)

The bench prints the bytes its UART line model decodes and ends with
`IOC_HALT value=... us=...` (upycore/docs/mpy_io_core.md, Benches).
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import iocore_files as F  # noqa: E402

CORES = {"cve2": 0, "hazard3": 1}


def obj_dir(core: str, mul: int) -> Path:
    return ROOT / "build" / "iocore" / f"tb_{core}_m{mul}"


def build(core: str = "cve2", mul: int = 0) -> Path:
    files, inc = F.island(core)
    out = obj_dir(core, mul)
    exe = out / "Vtb_iocore"
    srcs = [ROOT / f for f in files + ["iocore/tb/tb_uart_line.sv", "iocore/tb/tb_iocore.sv"]]
    if exe.exists() and all(s.stat().st_mtime < exe.stat().st_mtime for s in srcs):
        return exe
    out.mkdir(parents=True, exist_ok=True)
    cmd = [os.environ.get("VERILATOR", "verilator"), "-sv", "--binary", "--timing",
           "--timescale", "1ns/1ps", "-O2", "--x-assign", "fast", "--x-initial", "fast",
           "--top-module", "tb_iocore", f"-GCORE={CORES[core]}", f"-GMUL={mul}",
           "--Mdir", str(out), "-Wno-fatal", "-Wno-lint", "-Wno-style", "-Wno-TIMESCALEMOD",
           "-Wno-MULTIDRIVEN", "-Wno-UNOPTFLAT", "-j", str(os.cpu_count() or 4)]
    cmd += [f"+incdir+{ROOT / d}" for d in inc]
    cmd += [str(s) for s in srcs]
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if r.returncode:
        sys.stderr.write(r.stdout[-6000:] + r.stderr[-6000:])
        raise SystemExit("verilator failed")
    return exe


def run(app: str, core: str = "cve2", mul: int = 0, args: list[str] | None = None,
        timeout: float = 600) -> subprocess.CompletedProcess:
    exe = build(core, mul)
    d = ROOT / "build" / "iocore" / app
    cmd = [str(exe), f"+CODE={d / 'code.hex'}", f"+DATA={d / 'data.hex'}", *(args or [])]
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=("build", "run"))
    ap.add_argument("app", nargs="?")
    ap.add_argument("--core", choices=tuple(CORES), default="cve2")
    ap.add_argument("--mul", type=int, default=0)
    ap.add_argument("plusargs", nargs="*")
    a = ap.parse_args()
    if a.cmd == "build":
        print(build(a.core, a.mul))
        return 0
    r = run(a.app, a.core, a.mul, a.plusargs)
    sys.stdout.write(r.stdout)
    sys.stderr.write(r.stderr)
    return 0 if "IOC_HALT value=00000000" in r.stdout else 1


if __name__ == "__main__":
    raise SystemExit(main())
