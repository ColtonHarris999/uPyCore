#!/usr/bin/env python3
"""Generate paper figures from the MicroPython benchmark captures and board timings."""

import argparse
import csv
import json
import math
from pathlib import Path
from statistics import geometric_mean

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter, MaxNLocator, NullLocator

REFERENCE = Path(__file__).resolve().parents[2] / "docs/paper/benchmark-board-ms.csv"
CORE = "µPyCore (projected)"
BASELINE = "Pico RP2040"
PYSTONE = "misc_pystone"
PIDIGITS = "bm_pidigits"
FLAGS = ["+CA=1", "+AALU=1"]
STYLES = {
    CORE: ("#172b4d", "D", ""),
    BASELINE: ("#0072b2", "o", "//"),
    "Pico 2 Arm": ("#c94c00", "^", "xx"),
    "Pico 2 RISC-V": ("#008268", "v", ".."),
    "ESP32-C3": ("#963b72", "s", "++"),
    "Pyboard v1.0": ("#866200", "P", "oo"),
    "Pyboard v1.1": ("#595959", "X", "\\\\"),
}


def load_cycles(shortlist, pidigits):
    data = json.loads(shortlist.read_text())
    if data["boundary"] != "bench_ticks around run(), N=100 M=100" or data["flags"] != FLAGS:
        raise ValueError("Expected shortlist results at N=100, M=100 with CA and AALU enabled")

    cycles = {}
    for row in data["rows"]:
        if row["ok"] is not True or row["halt"] != "CLEAN":
            raise ValueError(f"Unvalidated shortlist result for {row['name']}")
        cycles[row["name"]] = row["cycles"]

    pi_data = json.loads(pidigits.read_text())
    if data["commit"] != pi_data["commit"] or data["simulator_sha256"] != pi_data["simulator_sha256"]:
        raise ValueError("Use the same commit and simulator for the shortlist and Pi digits")
    (pi_case,) = [row for row in pi_data["rows"] if row["name"] == PIDIGITS and row["point"] == "100x100"]
    (pi_run,) = [run for run in pi_case["runs"] if run["mode"] == "both"]
    if pi_run["status"] != "PASS" or pi_run["halt"] != "CLEAN" or pi_run["flags"] != FLAGS:
        raise ValueError("Expected a passing Pi digits run at N=100, M=100 with CA and AALU enabled")
    cycles[PIDIGITS] = pi_run["kernel_cycles"]
    if any(type(count) is not int or count <= 0 for count in cycles.values()):
        raise ValueError("Cycle counts must be positive integers")
    return cycles


def load_runtimes(path, cycles, clock_ns):
    runtimes = {}
    with path.open(newline="", encoding="utf-8") as source:
        for row in csv.DictReader(source):
            name = row.pop("benchmark")
            label = row.pop("label")
            times = {board: float(ms) for board, ms in row.items() if ms}
            if not times or any(not math.isfinite(ms) or ms <= 0 for ms in times.values()):
                raise ValueError(f"Invalid board timings for {name}")
            runtimes[name] = (label, {CORE: cycles[name] * clock_ns / 1e6, **times})
    return runtimes


def style_axis(ax):
    ax.set_axisbelow(True)
    ax.grid(axis="x", color="#dddddd", linewidth=0.55)
    ax.spines[["top", "right", "left"]].set_visible(False)
    ax.tick_params(axis="y", length=0)


def device_bars(values, xlabel, annotate, baseline=None):
    fig, ax = plt.subplots(figsize=(3.45, 2.25), layout="constrained")
    for index, (device, value) in enumerate(values.items()):
        color, _, hatch = STYLES[device]
        ax.barh(index, value, height=0.64, color=color if device == CORE else "white",
                edgecolor=color, linewidth=0.65, hatch=hatch)
        ax.annotate(annotate(value), (value, index), xytext=(3, 0),
                    textcoords="offset points", va="center")
    ax.set_yticks(range(len(values)), list(values))
    ax.invert_yaxis()
    ax.set(xlim=(0, 1.22 * max(values.values())), xlabel=xlabel)
    if baseline is not None:
        ax.axvline(baseline, color="#555555", linestyle="--", linewidth=0.7, zorder=1.5)
    style_axis(ax)
    return fig, ax


def suite_plot(suite, devices):
    fig, ax = plt.subplots(figsize=(7.05, 4.55), layout="constrained")
    for index in range(0, len(suite), 2):
        ax.axhspan(index - 0.5, index + 0.5, color="#f4f4f4", zorder=0)
    for index, device in enumerate(devices):
        color, marker, _ = STYLES[device]
        offset = (index - (len(devices) - 1) / 2) * 0.11
        positions = [(row, times[device]) for row, (_, times) in enumerate(suite.values())
                     if device in times]
        rows, times = zip(*positions)
        ax.scatter(times, [row + offset for row in rows], label=device, marker=marker,
                   s=16, color=color, linewidths=0, zorder=3)
    ax.set(xscale="log", xlabel="Kernel runtime (ms, log scale)  ←  lower is better",
           ylim=(len(suite) - 0.5, -0.5))
    ax.set_yticks(range(len(suite)), [label for label, _ in suite.values()])
    ax.set_xticks([1, 2, 5, 10, 20, 50, 100, 200, 500])
    ax.xaxis.set_major_formatter(FuncFormatter(lambda x, _: f"{x:g}"))
    ax.xaxis.set_minor_locator(NullLocator())
    style_axis(ax)
    ax.legend(loc="lower left", bbox_to_anchor=(0, 1.01, 1, 0), mode="expand",
              frameon=False, ncol=4, borderaxespad=0, handletextpad=0.25)
    return fig


def save(fig, directory, stem):
    fig.savefig(directory / f"{stem}.pdf", metadata={"Creator": Path(__file__).name})
    fig.savefig(directory / f"{stem}.png", dpi=300)
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("shortlist", type=Path, help="results.json from shortlist_bench.py")
    parser.add_argument("--pidigits", type=Path, required=True,
                        help="Pi digits MPZ results.json from perf_inventory.py")
    parser.add_argument("--clock-ns", type=float, required=True, help="assumed or estimated clock period")
    parser.add_argument("--board-ms", type=Path, default=REFERENCE, help="board runtime table (CSV)")
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    if not math.isfinite(args.clock_ns) or args.clock_ns <= 0:
        parser.error("--clock-ns must be positive and finite")

    cycles = load_cycles(args.shortlist, args.pidigits)
    runtimes = load_runtimes(args.board_ms, cycles, args.clock_ns)
    _, pystone = runtimes.pop(PYSTONE)
    devices = list(pystone)
    shared = [name for name, (_, times) in runtimes.items() if all(device in times for device in devices)]
    if not shared:
        parser.error("the board table has no non-Pystone kernel shared by all devices")
    geo = {device: geometric_mean(runtimes[name][1][BASELINE] / runtimes[name][1][device]
                                  for name in shared) for device in devices}
    rates = {device: 300_000 / ms for device, ms in pystone.items()}

    plt.rcParams.update({
        "font.family": "serif", "font.serif": ["STIXGeneral"], "font.size": 8,
        "axes.labelsize": 8.5, "axes.linewidth": 0.6, "pdf.fonttype": 42,
        "hatch.linewidth": 0.45, "axes.unicode_minus": False,
    })
    args.out_dir.mkdir(parents=True, exist_ok=True)
    fig, ax = device_bars(rates, "Pystone iterations per second  →  higher is better", lambda x: f"{x:,.0f}")
    ax.xaxis.set_major_locator(MaxNLocator(5))
    ax.xaxis.set_major_formatter(FuncFormatter(lambda x, _: f"{x:,.0f}"))
    save(fig, args.out_dir, "upycore-pystone")
    save(suite_plot(runtimes, devices), args.out_dir, "upycore-benchmark-suite")
    fig, _ = device_bars(geo, f"Geomean speedup over {BASELINE} ({len(shared)} kernels)",
                         lambda x: f"{x:.2f}×", baseline=1)
    save(fig, args.out_dir, "upycore-benchmark-geomean")

    print("Geomean kernels:", ", ".join(shared))
    for device in devices:
        print(f"{device:22} {rates[device]:9,.1f} pystones/s   {geo[device]:.4f}× geomean speedup")


if __name__ == "__main__":
    main()
