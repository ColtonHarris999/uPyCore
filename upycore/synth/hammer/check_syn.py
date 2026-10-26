#!/usr/bin/env python3
"""Check that a finished `make syn` run is healthy, not just finished.

Run from the design folder after `make syn` (or pass the folder):

    python3 ~/upycore/upycore/synth/hammer/check_syn.py [design_folder]

It reads build/syn-rundir/ and reports:

  * Errors in genus.log, with the ones from Hammer's placeholder clock
    (DEFAULT_CLOCK in clock_constraints_fragment.sdc) marked as expected.
  * Warnings grouped by message id, with the ones that can mean a broken
    netlist (latches, unresolved or undriven logic, loops) marked.
  * In the mapped netlist: latch cells, and instances of modules that are
    neither defined in the netlist nor sky130 cells (black boxes).
  * Flip-flop count against the count in the RTL, and worst slack.

Anything marked CHECK needs a look. The exit code is 1 if any check fails.
"""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

# Flip-flop bits in the RTL, counted with slang from the generated unit.
# Genus removes flops that are constant or duplicate another, so a few
# percent fewer is normal; far fewer means logic was optimized away.
RTL_FLOPS = {"mpy_alu": 5552, "mpy_decode": 461, "mpy_core": 12677}

BAD_WARNING = re.compile(
    r"latch|unresolved|black ?box|undriven|not driven|multiple driver|"
    r"combinational loop|timing loop|unconnected|no driver", re.I)
# Hammer's placeholder clock, and the set_clock_groups on it that then
# has no valid clocks (SDC-204 does not name the clock).
EXPECTED_ERROR = re.compile(r"DEFAULT_CLOCK|clock_constraints_fragment|"
                            r"All clocks passed to -group option are invalid")


def _blocks(lines: list[str], kind: str) -> list[tuple[str, str]]:
    """(message id, full text) for each Error/Warning message in a Genus log."""
    out = []
    for i, line in enumerate(lines):
        if not line.startswith(kind):
            continue
        text = [line]
        for nxt in lines[i + 1:i + 6]:
            if nxt.startswith((" ", "\t")):
                text.append(nxt)
            else:
                break
        m = re.search(r"\[([A-Z]+-\d+)\]", line)
        out.append((m.group(1) if m else "?", "".join(text)))
    return out


def main() -> int:
    folder = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    run = folder / "build" / "syn-rundir"
    log = run / "genus.log"
    if not log.is_file():
        sys.exit(f"no {log}; run make syn first (or pass the design folder)")
    failed = False
    lines = log.read_text(errors="replace").splitlines(keepends=True)

    print("== Errors in genus.log")
    errs = _blocks(lines, "Error")
    expected = [e for e in errs if EXPECTED_ERROR.search(e[1])]
    other = [e for e in errs if not EXPECTED_ERROR.search(e[1])]
    print(f"  {len(expected)} from Hammer's placeholder DEFAULT_CLOCK (expected, harmless)")
    if other:
        failed = True
        print(f"  CHECK: {len(other)} other errors. First ones:")
        for _, text in other[:3]:
            print("    " + text.rstrip().replace("\n", "\n    "))
    else:
        print("  no other errors")

    print("== Warnings by id (CHECK = can mean a broken netlist)")
    warns = _blocks(lines, "Warning")
    counts = Counter(w[0] for w in warns)
    first = {}
    for wid, text in warns:
        first.setdefault(wid, text)
    for wid, n in counts.most_common():
        head = first[wid].splitlines()[0].split(":", 1)[-1].strip()
        mark = "CHECK" if BAD_WARNING.search(first[wid]) else "     "
        print(f"  {mark} {n:6d}  {wid:10s} {head[:90]}")
    print("  (Genus prints at most 20 of each message, see MESG-11.)")
    removed = [t.splitlines()[1].split(":", 1)[-1].strip() for w, t in warns
               if w == "CDFG-508" and len(t.splitlines()) > 1]
    if removed:
        print("  Registers Genus removed as unused (check each is really unused):")
        for r in removed[:20]:
            print(f"    {r[:110]}")

    netlists = sorted(run.glob("*.mapped.v"))
    top = netlists[0].name[: -len(".mapped.v")] if netlists else None
    print(f"== Mapped netlist ({netlists[0].name if netlists else 'none found'})")
    if netlists:
        text = netlists[0].read_text(errors="replace")
        defined = set(re.findall(r"^\s*module\s+(\w+)", text, re.M))
        used = Counter(re.findall(r"^\s*(\w+)\s+(?:#\s*\(.*?\)\s*)?\\?[\w\[\].$]+\s*\(", text, re.M))
        keywords = {"module", "input", "output", "inout", "wire", "reg", "assign", "endmodule"}
        cells = {k: v for k, v in used.items() if k not in keywords}
        latches = sum(v for k, v in cells.items() if re.match(r"sky130_fd_sc_\w+__dl[xr]", k))
        unknown = {k: v for k, v in cells.items()
                   if k not in defined and not k.startswith("sky130_")}
        print(f"  latch cells: {latches}" + ("  CHECK: the RTL has no latches" if latches else ""))
        failed |= bool(latches)
        if unknown:
            failed = True
            print(f"  CHECK: instances of undefined modules (black boxes): {unknown}")
        else:
            print("  no black boxes: every instance is a sky130 cell or a module in the netlist")

    print("== Flops and timing (final_qor.rpt)")
    qor = run / "reports" / "final_qor.rpt"
    if qor.is_file():
        q = qor.read_text(errors="replace")
        m = re.search(r"Sequential Instance Count\s+(\d+)", q)
        seq = int(m.group(1)) if m else None
        rtl = RTL_FLOPS.get(top or "")
        if seq is not None and rtl:
            ratio = seq / rtl
            mark = "" if 0.85 <= ratio <= 1.02 else "  CHECK: far from the RTL count"
            failed |= bool(mark)
            print(f"  flops {seq} vs {rtl} in the RTL ({ratio:.0%}){mark}")
        elif seq is not None:
            print(f"  flops {seq} (no RTL count for {top})")
        # The timing table (one row per clock: period, slack) and the area.
        in_timing = False
        for line in q.splitlines():
            if line.startswith("Timing"):
                in_timing = True
            elif line.startswith("Area"):
                in_timing = False
            if (in_timing and line.strip()) or line.startswith("Cell Area"):
                print("  " + line.rstrip())
    else:
        print(f"  no {qor}")

    print("== Result: " + ("CHECK the items above" if failed else "healthy"))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
