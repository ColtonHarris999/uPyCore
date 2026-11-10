#!/usr/bin/env python3
"""Generate paper figures from the MicroPython benchmark captures and board timings."""

import argparse
import csv
import json
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter, MaxNLocator

REFERENCE = Path(__file__).resolve().parents[2] / "docs/paper/benchmark-board-ms.csv"
CORE = "µPyCore (projected)"
PYSTONE = "misc_pystone"
PIDIGITS = "bm_pidigits"
FLAGS = ["+CA=1", "+AALU=1"]
STYLES = {
    CORE: ("#172b4d", ""),
    "Pico RP2040": ("#0072b2", "//"),
    "Pico 2 Arm": ("#c94c00", "xx"),
    "Pico 2 RISC-V": ("#008268", ".."),
    "ESP32-C3": ("#963b72", "++"),
    "Pyboard v1.0": ("#866200", "oo"),
    "Pyboard v1.1": ("#595959", "\\\\"),
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


def bar_style(device):
    color, hatch = STYLES[device]
    return {"color": color if device == CORE else "white",
            "edgecolor": color, "hatch": hatch}


def device_bars(values, xlabel, labels):
    fig, ax = plt.subplots(figsize=(3.45, 2.25), layout="constrained")
    for index, (device, value) in enumerate(values.items()):
        if value is not None:
            ax.barh(index, value, height=0.64, linewidth=0.65, **bar_style(device))
        ax.annotate(labels[device], (value or 0, index), xytext=(3, 0),
                    textcoords="offset points", va="center")
    ax.set_yticks(range(len(values)), list(values))
    ax.set(xlim=(0, 1.22 * max(value for value in values.values() if value is not None)),
           ylim=(len(values) - 0.5, -0.5), xlabel=xlabel)
    style_axis(ax)
    return fig, ax


def suite_plot(suite, devices):
    fig, ax = plt.subplots(figsize=(7.05, 6.6), layout="constrained")
    for index in range(0, len(suite), 2):
        ax.axhspan(index - 0.5, index + 0.5, color="#f4f4f4", zorder=0)
    spacing = 0.88 / len(devices)
    for index, device in enumerate(devices):
        offset = (index - (len(devices) - 1) / 2) * spacing
        positions = [(row, times[device]) for row, (_, times) in enumerate(suite.values())
                     if device in times]
        rows, times = zip(*positions)
        ax.barh([row + offset for row in rows], times, height=0.83 * spacing,
                label=device, linewidth=0.5, zorder=3, **bar_style(device))
    ax.set(xlim=(0, None), xlabel="Kernel runtime (ms)  ←  lower is better",
           ylim=(len(suite) - 0.5, -0.5))
    ax.set_yticks(range(len(suite)), [label for label, _ in suite.values()])
    ax.xaxis.set_major_locator(MaxNLocator(7))
    style_axis(ax)
    ax.legend(loc="lower left", bbox_to_anchor=(0, 1.01, 1, 0), mode="expand",
              frameon=False, ncol=4, borderaxespad=0, handletextpad=0.25)
    return fig


def suite_totals(suite, devices):
    totals = {}
    coverage = {}
    for device in devices:
        times = [times[device] for _, times in suite.values() if device in times]
        coverage[device] = len(times)
        totals[device] = math.fsum(times) if len(times) == len(suite) else None
    return totals, coverage


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
    devices = [device for device in STYLES
               if any(device in times for _, times in runtimes.values())]
    suite_size = len(runtimes)
    totals, coverage = suite_totals(runtimes, devices)
    means = {device: total / suite_size if total is not None else None
             for device, total in totals.items()}
    labels = {device: f"{mean:.1f}" if mean is not None else f"N/A ({coverage[device]}/{suite_size})"
              for device, mean in means.items()}
    rates = {device: 300_000 / ms for device, ms in pystone.items()}

    plt.rcParams.update({
        "font.family": "serif", "font.serif": ["STIXGeneral"], "font.size": 8,
        "axes.labelsize": 8.5, "axes.linewidth": 0.6, "pdf.fonttype": 42,
        "hatch.linewidth": 0.45, "axes.unicode_minus": False,
    })
    args.out_dir.mkdir(parents=True, exist_ok=True)
    fig, ax = device_bars(rates, "Pystone iterations per second  →  higher is better",
                          {device: f"{rate:,.0f}" for device, rate in rates.items()})
    ax.xaxis.set_major_locator(MaxNLocator(5))
    ax.xaxis.set_major_formatter(FuncFormatter(lambda x, _: f"{x:,.0f}"))
    save(fig, args.out_dir, "upycore-pystone")
    save(suite_plot(runtimes, devices), args.out_dir, "upycore-benchmark-suite")
    fig, ax = device_bars(means, f"Mean runtime (ms/kernel, {suite_size} non-Pystone kernels)", labels)
    ax.xaxis.set_major_locator(MaxNLocator(5))
    save(fig, args.out_dir, "upycore-benchmark-average-runtime")

    for device in devices:
        total = totals[device]
        summary = f"{total:.3f} ms total, {means[device]:.3f} ms/kernel" if total is not None else labels[device]
        print(f"{device:22} {summary}")


if __name__ == "__main__":
    main()
