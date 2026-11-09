#!/usr/bin/env python3
"""Performance gates G1-G4 of planning/rv_io_core_plan.md §8.

    gates.py g1 --base-sim BASE/Vtb_mpy_soc [--new-sim build/mpy_soc/obj/Vtb_mpy_soc]
    gates.py g2 BASE_HW_LOG NEW_HW_LOG
    gates.py g3 BASE_STA_DIR NEW_STA_DIR          (each holds mpy_core/ and mpy_soc/ sta.txt)
    gates.py g4 BASE_ROOT                          (both trees ran hw_tests.py, so build/hw/* exist)

G1: clock_bench.py on the same images, every workload at exactly 0 cycles
change. G2: every test passes on the new simulator, and each test that does
not use I/O has the baseline's exact `cycles=`. G3: no register group of
mpy_core or mpy_soc slower than the baseline by more than 0.1 in the
unmapped STA flow. G4: each hardware-suite image that does not use I/O is
byte-identical (image.hex and image.tags.hex). A test "uses I/O" when its
area is io, irq, system, console or usb, or mpy_build.io_imports() finds
I/O in its sources. Each command prints PASS or FAIL and exits 0 or 1.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "upycore" / "tools"))
import mpy_build as b  # noqa: E402
import hw_tests as hw  # noqa: E402

IO_AREAS = {"io", "irq", "system", "console", "usb"}


def uses_io(t: hw.Test) -> bool:
    if t.area in IO_AREAS:
        return True
    probe = getattr(b, "io_imports", None)
    if probe is None:
        return False
    try:
        srcs = [t.source, *hw._modules(t).values()]
    except RuntimeError:
        srcs = [t.source]
    return bool(probe(srcs))


def tests_by_name() -> dict[str, hw.Test]:
    return {t.name: t for t in hw.load_manifest()}


def g1(a) -> int:
    out = ROOT / "build" / "gates" / "clock_bench.json"
    r = subprocess.run([sys.executable, str(ROOT / "upycore/tools/clock_bench.py"), "--before",
                        str(a.base_sim), "--after", str(a.new_sim), "--out", str(out)], cwd=ROOT)
    if r.returncode:
        print("G1 FAIL: clock_bench failed")
        return 1
    rows = json.loads(out.read_text())["rows"]
    bad = [r for r in rows if r["before_cycles"] != r["after_cycles"]]
    for r in bad:
        print(f"  {r['name']}: {r['before_cycles']} -> {r['after_cycles']}")
    print(f"G1 {'FAIL' if bad else 'PASS'}: {len(rows) - len(bad)} of {len(rows)} workloads at 0.000%")
    return 1 if bad else 0


_LINE = re.compile(r"^(PASS|FAIL|XFAIL|XPASS)\s+(\S+)/(\S+)\s+(?:cycles=(\d+))?")


def parse_log(p: Path) -> dict[str, tuple[str, int | None]]:
    out = {}
    for ln in p.read_text().splitlines():
        m = _LINE.match(ln)
        if m:
            out[m.group(3)] = (m.group(1), int(m.group(4)) if m.group(4) else None)
    return out


def g2(a) -> int:
    base, new = parse_log(a.base_log), parse_log(a.new_log)
    tests = tests_by_name()
    fails = [n for n, (s, _) in new.items() if s not in ("PASS", "XFAIL")]
    missing = [n for n in base if n not in new]
    moved, io_moved = [], []
    for n, (s, c) in new.items():
        if n not in base or base[n][1] is None or c is None:
            continue
        if c != base[n][1]:
            (io_moved if n in tests and uses_io(tests[n]) else moved).append((n, base[n][1], c))
    added = [n for n in new if n not in base]
    for n in fails:
        print(f"  FAIL {n}")
    for n in missing:
        print(f"  missing from the new run: {n}")
    for n, x, y in moved:
        print(f"  cycles moved (no I/O): {n} {x} -> {y}")
    for n, x, y in io_moved:
        print(f"  cycles moved (I/O test, allowed): {n} {x} -> {y}")
    ok = not fails and not missing and not moved
    same = sum(1 for n in new if n in base and base[n][1] == new[n][1])
    print(f"G2 {'PASS' if ok else 'FAIL'}: {len(new)} run, {len(new) - len(fails)} pass, "
          f"{same} identical cycles, {len(io_moved)} I/O tests moved, {len(added)} new tests")
    return 0 if ok else 1


def g3(a) -> int:
    bad = 0
    for top in ("mpy_core", "mpy_soc"):
        bs, ns = a.base / top / "sta.txt", a.new / top / "sta.txt"
        base, new = load_sta(bs), load_sta(ns)
        worse = sorted(((new[g] - base[g], g, base[g], new[g]) for g in new if g in base and
                        new[g] > base[g] + 0.1), reverse=True)
        for d, g, x, y in worse[:20]:
            print(f"  {top}: {g} {x:.3f} -> {y:.3f} (+{d:.3f})")
        bw, nw = max(base.values()), max(new.values())
        print(f"  {top}: worst {bw:.3f} -> {nw:.3f}; {len(base)} groups in base, "
              f"{sum(1 for g in new if g in base)} matched, {len(worse)} slower by > 0.1")
        bad += len(worse)
    print(f"G3 {'FAIL' if bad else 'PASS'}")
    return 1 if bad else 0


def load_sta(p: Path) -> dict[str, float]:
    out = {}
    for ln in p.read_text().splitlines():
        m = re.match(r"\s+([\d.]+)\s+(\S+)\s+<- (\S+)", ln)
        if m:
            out[m.group(2)] = float(m.group(1))
    return out


def g4(a) -> int:
    tests = tests_by_name()
    same, diff, io_diff, absent = 0, [], [], 0
    for name, t in sorted(tests.items()):
        nb = ROOT / "build" / "hw" / name / "image.hex"
        bb = a.base_root / "build" / "hw" / name / "image.hex"
        if not nb.exists() or not bb.exists():
            absent += 1
            continue
        eq = all((ROOT / "build/hw" / name / f).read_bytes() == (a.base_root / "build/hw" / name / f).read_bytes()
                 for f in ("image.hex", "image.tags.hex"))
        if eq:
            same += 1
        elif uses_io(t):
            io_diff.append(name)
        else:
            diff.append(name)
    for n in diff:
        print(f"  image differs (no I/O): {n}")
    for n in io_diff:
        print(f"  image differs (I/O test, allowed): {n}")
    print(f"G4 {'FAIL' if diff else 'PASS'}: {same} identical, {len(io_diff)} I/O images differ, "
          f"{len(diff)} non-I/O differ, {absent} not built in both trees")
    return 1 if diff else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="g", required=True)
    p = sub.add_parser("g1")
    p.add_argument("--base-sim", type=Path, required=True)
    p.add_argument("--new-sim", type=Path, default=b.SIM)
    p = sub.add_parser("g2")
    p.add_argument("base_log", type=Path)
    p.add_argument("new_log", type=Path)
    p = sub.add_parser("g3")
    p.add_argument("base", type=Path)
    p.add_argument("new", type=Path)
    p = sub.add_parser("g4")
    p.add_argument("base_root", type=Path)
    a = ap.parse_args()
    return {"g1": g1, "g2": g2, "g3": g3, "g4": g4}[a.g](a)


if __name__ == "__main__":
    raise SystemExit(main())
