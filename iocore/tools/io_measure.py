#!/usr/bin/env python3
"""Board I/O measurements (plan phase 6): run upycore/programs/meas/*.py on
the simulator with the bench's measurement hooks and print a table.

    io_measure.py [gpio irq timer uart_tx uart_rx] [--io-clk-ns 20] [--json out.json]

The bench (tb_mpy_soc +MEAS_FILE) logs pad changes, the edges it drives
(+PULSE), the times the core runs one opcode (+MEAS_PC: the first opcode
of the program's function `cb`, from the link map) and the UART bytes its
line model decodes, all in ps. The hart runs at 100 MHz (10 ns a cycle).
Spec: upycore/docs/mpy_io_core.md (Measurements).
"""

from __future__ import annotations

import argparse
import json
import re
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "upycore" / "tools"))
import mpy_build as build  # noqa: E402

MEAS = ROOT / "upycore" / "programs" / "meas"
WORK = ROOT / "build" / "meas"
HART_NS = 10.0


def _program(name: str, subst: dict[str, str] | None = None, tag: str = "") -> Path:
    """Build meas/<name>.py (with `NAME = value` lines replaced); returns the image prefix."""
    src = (MEAS / f"{name}.py").read_text()
    for k, v in (subst or {}).items():
        lines = src.splitlines()
        for i, ln in enumerate(lines):
            if ln.startswith(f"{k} = "):
                lines[i] = f"{k} = {v}"
        src = "\n".join(lines) + "\n"
    work = WORK / f"{name}{tag}"
    work.mkdir(parents=True, exist_ok=True)
    path = work / f"{name}.py"
    path.write_text(src)
    return build.build_program(path, work, f"{name}.py")


def _cb_pc(image: Path) -> int:
    """The byte address of the first opcode of the program's function cb."""
    info = json.loads(Path(f"{image}.map.json").read_text())
    addrs = [int(a, 16) for a, n in info["rc"].items() if n.endswith(":cb")]
    if len(addrs) != 1:
        raise SystemExit(f"{image}: expected one function cb, found {len(addrs)}")
    words = Path(f"{image}.hex").read_text().split()
    return int(words[addrs[0] // 4], 16)


def _run(image: Path, args: list[str], io_clk_ns: float, cycles: int = 200_000_000,
         sim: Path | None = None) -> tuple[dict, str]:
    log = Path(f"{image}.meas")
    res = build.run_image(image, max_cycles=cycles, timeout=7200, sim_executable=sim,
                          sim_args=[f"+MEAS_FILE={log}", f"+IO_CLK_NS={io_clk_ns}", *args])
    if res.halt != "CLEAN":
        raise SystemExit(f"{image}: {res.halt}\n{res.log[-2000:]}")
    ev: dict = {"pad": {}, "edge": [], "hit": [], "rx": [], "evt": [], "saif": []}
    for ln in log.read_text().splitlines():
        f = ln.split()
        if f[0] == "pad":
            ev["pad"].setdefault(int(f[1]), []).append((int(f[2]) / 1000.0, int(f[3])))
        else:
            ev[f[0]].append(int(f[1]) / 1000.0)
    return ev, res.stdout.decode()


def _stats(xs: list[float]) -> dict:
    return {"n": len(xs), "min": min(xs), "mean": statistics.fmean(xs), "max": max(xs),
            "stdev": statistics.pstdev(xs) if len(xs) > 1 else 0.0}


def _phases(ev: dict, times: list[float], marker: int = 4) -> list[int]:
    """The phase of each time: the number of marker-pad changes before it."""
    marks = [t for t, _ in ev["pad"].get(marker, [])]
    return [sum(1 for m in marks if m <= t) for t in times]


def gpio(io: float) -> dict:
    ev, _ = _run(_program("gpio_toggle"), [], io)
    out = {}
    for pad, what in ((0, "toggle()"), (1, "value(v)"), (2, "on()/off()")):
        ts = [t for t, _ in ev["pad"][pad]]
        gaps = [b - a for a, b in zip(ts, ts[1:])]
        out[what] = {"changes": len(ts), "rate_per_s": (len(ts) - 1) / ((ts[-1] - ts[0]) * 1e-9),
                     "interval_ns": _stats(gaps)}
    return out


def irq(io: float) -> dict:
    image = _program("irq_latency")
    pc = _cb_pc(image)
    ev, stdout = _run(image, [f"+MEAS_PC={pc:x}", "+PULSE=3,10000,200,1000"], io)
    edges, hits, evts = ev["edge"], ev["hit"], ev["evt"]
    lat: dict[int, list[float]] = {}
    to_evt: dict[int, list[float]] = {}
    missed = 0
    j = k = 0
    for i, e in enumerate(edges):
        nxt = edges[i + 1] if i + 1 < len(edges) else float("inf")
        while j < len(hits) and hits[j] < e:
            j += 1
        while k < len(evts) and evts[k] < e:
            k += 1
        if j < len(hits) and hits[j] < nxt:
            ph = _phases(ev, [e])[0]
            lat.setdefault(ph, []).append(hits[j] - e)
            if k < len(evts) and evts[k] < hits[j]:
                to_evt.setdefault(ph, []).append(evts[k] - e)
        else:
            missed += 1
    names = ["soft, main in time.sleep_ms", "soft, main in a loop",
             "hard=True, main in time.sleep_ms", "hard=True, main in a loop"]
    return {"stdout": stdout.strip(), "edges": len(edges), "missed": missed,
            "latency_ns": {names[k]: _stats(v) for k, v in sorted(lat.items()) if k < 4},
            "edge_to_evt_pend_ns": {names[k]: _stats(v) for k, v in sorted(to_evt.items()) if k < 4}}


def timer(io: float) -> dict:
    image = _program("timer_jitter")
    ev, stdout = _run(image, [f"+MEAS_PC={_cb_pc(image):x}"], io)
    hits = ev["hit"]
    ph = _phases(ev, hits)
    out = {"stdout": stdout.strip()}
    for k, name in ((0, "main in time.sleep_ms"), (1, "main in a loop")):
        ts = [t for t, p in zip(hits, ph) if p == k]
        gaps = [b - a for a, b in zip(ts, ts[1:])]
        if gaps:
            st = _stats(gaps)
            out[name] = {"period_ns": st, "jitter_ns": max(abs(st["min"] - 1e6), abs(st["max"] - 1e6))}
    return out


def uart_tx(io: float, bauds=(115200, 1_000_000, 3_000_000)) -> dict:
    out = {}
    for baud in bauds:
        image = _program("uart_tx", {"BAUD": str(baud)}, f"_{baud}")
        ev, stdout = _run(image, [f"+UART_BPS={baud}"], io)
        rx = ev["rx"]
        rate = (len(rx) - 1) / ((rx[-1] - rx[0]) * 1e-9)
        out[str(baud)] = {"bytes": len(rx), "bytes_per_s": rate, "line_bytes_per_s": baud / 10,
                          "efficiency": rate / (baud / 10), "stdout": stdout.strip()}
    return out


def uart_rx(io: float, bauds=(115200, 460800, 1_000_000), count: int = 2048) -> dict:
    out = {}
    for baud in bauds:
        image = _program("uart_rx", {"BAUD": str(baud), "COUNT": str(count)}, f"_{baud}")
        ev, stdout = _run(image, [f"+UART_BPS={baud}", f"+UART_IN_PATTERN={count}",
                                  "+UART_IN_US=8000"], io)
        f = stdout.split()
        got, bad, us = int(f[1]), int(f[3]), int(f[5])
        out[str(baud)] = {"sent": count, "got": got, "bad": bad,
                          "bytes_per_s": got / (us * 1e-6) if us else 0.0, "line_bytes_per_s": baud / 10}
    return out


def _saif_activity(path: Path, io_clk_ns: float) -> dict:
    """Toggle totals from a Verilator SAIF of the island: every bit's TC
    (toggle count), the duration, and the mean toggles per bit per io_clk."""
    text = path.read_text()
    scale = re.search(r"\(TIMESCALE\s+(\d+)\s*(\w+)\)", text)
    unit = {"s": 1e9, "ms": 1e6, "us": 1e3, "ns": 1.0, "ps": 1e-3, "fs": 1e-6}[scale.group(2)] * int(scale.group(1))
    duration_ns = int(re.search(r"\(DURATION\s+(\d+)\)", text).group(1)) * unit
    tcs = [int(x) for x in re.findall(r"\(TC\s+(\d+)\)", text)]
    cycles = duration_ns / io_clk_ns
    return {"bits": len(tcs), "toggles": sum(tcs), "duration_ns": duration_ns,
            "io_clk_cycles": cycles, "toggles_per_bit_per_cycle": sum(tcs) / (len(tcs) * cycles)}


def power(io: float) -> dict:
    """The island's switching activity, idle and busy, as SAIF for Genus
    (upycore/synth/hammer/README.md); this flow has no power engine."""
    sim = build.build_sim(saif=True)
    out = {}
    for name, start_us in (("island_idle", 7000), ("island_active", 7000)):
        image = _program(name)
        saif = Path(f"{image}.island.saif")
        _, stdout = _run(image, [f"+SAIF_ISLAND={saif}", f"+SAIF_START_US={start_us}",
                                 "+UART_BPS=1000000"], io, sim=sim)
        out[name] = {"saif": str(saif.relative_to(ROOT)), "stdout": stdout.strip(),
                     **_saif_activity(saif, io)}
    return out


KINDS = {"gpio": gpio, "irq": irq, "timer": timer, "uart_tx": uart_tx, "uart_rx": uart_rx,
         "power": power}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("kinds", nargs="*", default=list(KINDS))
    ap.add_argument("--io-clk-ns", type=float, default=20.0)
    ap.add_argument("--json", type=Path)
    args = ap.parse_args()
    build.build_sim()
    results = {}
    for k in args.kinds:
        results[k] = KINDS[k](args.io_clk_ns)
        print(k, json.dumps(results[k], indent=1))
    if args.json:
        args.json.write_text(json.dumps({"io_clk_ns": args.io_clk_ns, **results}, indent=1) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
