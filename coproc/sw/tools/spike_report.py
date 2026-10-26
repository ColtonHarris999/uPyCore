#!/usr/bin/env python3
"""Size and worst-case stack table for the Phase 0 spike builds.

Each argument is a build directory with ``spike.elf`` and the ``.ci``
call-graph files GCC writes for ``-fcallgraph-info=su``. Text, data, and
bss come from ``size``. The stack figure is the deepest path in the call
graph from ``main`` and from ``dcd_int_handler``, plus a trap frame.

Indirect calls are TinyUSB's class-driver table and the usbd control
callbacks. GCC records them as ``__indirect_call``; this script resolves
an indirect edge to every function whose name matches a class-driver or
callback pattern, which over-approximates the real target set.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

INDIRECT = re.compile(r"^(cdcd_|hidd_|dfu_rtd_|mscd_)|^tud_\w+_cb$")
TRAP_FRAME = 64  # ilp32e saves 15 GPRs plus mepc/mstatus, rounded up
ROOTS = ("main", "dcd_int_handler")

_NODE = re.compile(r'node: \{ title: "([^"]+)" label: "[^"]*\\n(\d+) bytes \((\w+)\)')
_EDGE = re.compile(r'edge: \{ sourcename: "([^"]+)" targetname: "([^"]+)"')


def read_graph(build: Path) -> tuple[dict[str, int], dict[str, set[str]], set[str]]:
    frame: dict[str, int] = {}
    calls: dict[str, set[str]] = {}
    dynamic: set[str] = set()
    for ci in sorted(build.glob("*.ci")):
        text = ci.read_text()
        for name, nbytes, kind in _NODE.findall(text):
            frame[name] = max(frame.get(name, 0), int(nbytes))
            if kind != "static":
                dynamic.add(name)
        for src, dst in _EDGE.findall(text):
            calls.setdefault(src, set()).add(dst)
    return frame, calls, dynamic


def worst_stack(frame: dict[str, int], calls: dict[str, set[str]], root: str) -> tuple[int, list[str]]:
    """Deepest acyclic path. A result is cached only when no cycle was cut
    below it, so the answer does not depend on visit order."""

    indirect = sorted(n for n in frame if INDIRECT.match(n))
    memo: dict[str, tuple[int, list[str]]] = {}
    active: set[str] = set()

    def walk(fn: str) -> tuple[int, list[str], bool]:
        if fn in memo:
            return (*memo[fn], False)
        if fn in active:
            return 0, [], True
        active.add(fn)
        best: tuple[int, list[str]] = (0, [])
        cut = False
        targets = set(calls.get(fn, ()))
        if "__indirect_call" in targets:
            targets.discard("__indirect_call")
            targets |= set(indirect) - {fn}
        for t in sorted(targets):
            depth, path, c = walk(t)
            cut = cut or c
            if depth > best[0]:
                best = (depth, path)
        active.discard(fn)
        out = (frame.get(fn, 0) + best[0], [fn] + best[1])
        if not cut:
            memo[fn] = out
        return (*out, cut)

    depth, path, _ = walk(root)
    return depth, path


def size_of(elf: Path) -> tuple[int, int, int]:
    out = subprocess.run(["riscv64-unknown-elf-size", str(elf)], capture_output=True, text=True,
                         check=True).stdout.splitlines()[1].split()
    return int(out[0]), int(out[1]), int(out[2])


def main(argv: list[str]) -> int:
    rows = []
    for arg in argv:
        build = Path(arg)
        text, data, bss = size_of(build / "spike.elf")
        frame, calls, dynamic = read_graph(build)
        stacks = {r: worst_stack(frame, calls, r) for r in ROOTS}
        main_depth = stacks["main"][0]
        isr_depth = stacks["dcd_int_handler"][0] + TRAP_FRAME
        rows.append((build.name, text, data, bss, main_depth, isr_depth, stacks, dynamic))
    print(f"{'build':<10} {'text':>7} {'data':>6} {'bss':>6} {'stack main':>11} {'stack isr':>10} {'total RAM':>10}")
    for name, text, data, bss, sm, si, _, _ in rows:
        ram = data + bss + sm + si
        print(f"{name:<10} {text:>7} {data:>6} {bss:>6} {sm:>11} {si:>10} {ram:>10}")
    for name, *_, stacks, dynamic in rows:
        for root, (depth, path) in stacks.items():
            print(f"{name} {root}: {depth} B via {' > '.join(path)}")
        if dynamic:
            print(f"{name} dynamic frames: {', '.join(sorted(dynamic))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
