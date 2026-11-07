#!/usr/bin/env python3
"""Plot captured short-list microbenchmarks; raw loop/call overhead is included."""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results", type=Path)
    parser.add_argument("--out", type=Path, required=True, help="output stem")
    args = parser.parse_args()
    data = json.loads(args.results.read_text())
    rows = {row["name"]: row for row in data["rows"]}
    fig, axes = plt.subplots(1, 3, figsize=(11.4, 3.7), sharey=True)
    colors = ["#666666", "#2475b0", "#d66b18"]
    labels = ["Legacy", "Native core", "Native engine (16)"]
    for ax, (kind, title) in zip(axes, [("list_copy", "Shallow copy"),
                                      ("reverse_slice", "Reverse slice"),
                                      ("slice_assign", "Equal-length replacement")]):
        lengths = sorted(int(name.split("_")[-2]) for name in rows
                         if name.startswith(kind + "_") and name.endswith("_int")
                         and int(name.split("_")[-2]) <= 17)
        for mode, (color, label) in enumerate(zip(colors, labels)):
            cycles = []
            for n in lengths:
                run = next(r for r in rows[f"{kind}_{n}_int"]["runs"] if r["mode"] == mode)
                if not run["ok"]:
                    raise ValueError(f"Unvalidated input: {kind}, length {n}, mode {mode}")
                cycles.append(run["cycles"])
            ax.plot(lengths, cycles, marker="o", markersize=3.5,
                    linewidth=1.5, color=color, label=label)
        ax.axvline(16.5, color="#aaaaaa", linewidth=0.8, linestyle=":")
        ax.set(title=title, xlabel="List length", xlim=(-0.5, 17.5), yscale="log")
        ax.set_xticks([0, 4, 8, 12, 16])
        ax.set_yticks([4_000, 10_000, 40_000, 80_000])
        ax.set_ylim(3_500, 95_000)
        ax.grid(axis="y", which="major", color="#dddddd", linewidth=0.6)
        ax.spines[["top", "right"]].set_visible(False)
    axes[0].set_ylabel(f"Cycles for {data['loops']} repetitions")
    axes[0].yaxis.set_major_formatter(FuncFormatter(lambda x, _: f"{x:,.0f}"))
    fig.legend(*axes[0].get_legend_handles_labels(), loc="upper center", ncol=3,
               frameon=False, bbox_to_anchor=(0.5, 1.01))
    fig.text(0.5, 0.015, "Loop/call overhead included; no control subtraction. "
             "Length 17 uses fallback. Integer elements.", ha="center", fontsize=9)
    fig.tight_layout(rect=(0, 0.055, 1, 0.92))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    for suffix in (".svg", ".png"):
        fig.savefig(args.out.with_suffix(suffix), dpi=180, facecolor="white",
                    metadata={"Creator": "shortlist_plot.py"} if suffix == ".svg" else None)
    plt.close(fig)


if __name__ == "__main__":
    main()
