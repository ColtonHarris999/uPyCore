# RTL changes for the 100 MHz backend target

This change targets a 10 ns **post-route** clock. Timing closure is pending
Genus/Innovus STA on this RTL; generic gate depth is not a frequency result.
No timing exceptions or clock constraints were relaxed to obtain these changes.

## What the supplied reports establish

The six November 2 reports are Genus 21.12 synthesis reports at
`sky130_fd_sc_hd__ss_100C_1v60`, with ideal clock latency and global
interconnect estimates. They are not post-route reports.

| Synthesis constraint | Worst setup slack | Violating paths |
| --- | ---: | ---: |
| 10 ns | -0.8499 ns | 438 |
| 12 ns | +0.0017 ns | 0 |
| 15 ns | +0.1926 ns | 0 |

All 50 reported paths at 10 ns pass through integer-to-binary32 conversion:
26 go from `nb` to `u_alu/fb`, and 24 from `na` to `u_alu/res_o`.
The 12/15 ns runs also expose the integer multiply-accumulate, binary64
narrowing, divider preparation, modulo, and core address/control paths.
Different constraints produce different netlists, so the slack values do
not describe a single fixed implementation's Fmax.

The implementation combines main `dc64a89` (queued collection accelerator,
shared image/runtime SRAM, four 128 KiB banks) with the RTL timing fixes from synth `b71cbfb`. Flow scripts and backend
documentation from that branch are excluded.
The reports used four `fakeram_d16384_w36` macros; current RTL needs four
`fakeram_d32768_w36` macros. Reusing the old memory models or floorplan would
invalidate a comparison. The synth branch's cache-selection, stack-address,
FP power-shifter and radix-4 probe-modulo improvements are retained.

## Datapath changes

| Path | Change | Cycle cost relative to previous RTL |
| --- | --- | --- |
| int64 to binary32 | Magnitude capture, registered normalization, then a 24-bit rounding carry chain; balanced CLZ64 | +2 for explicit conversion and mixed/converted float operations |
| signed 64x64 multiply | Register two signed limb products; carry-save merge with accumulator, then one carry-propagate add; overlap product and accumulation stages | +2 per multiply, including integer power's multiplies |
| binary64 to binary32 | Barrel shift with sticky bits instead of variable mask construction and subtraction | 0 |
| floating power decode | Classify integral/odd exponents from fraction bits; convert exponent magnitude directly, avoiding signed conversion followed by abs | 0 |

Integer-only one-cycle ALU operations and operations with two float operands
retain their existing latency. The signed multiplier still emits the full
128-bit product for overflow detection; level start, abort, done pulse and
result-hold behavior are unchanged. At STEP=16 its result is valid five
clocks after the accept edge. Integer conversion retains nearest-even
rounding, including INT64_MIN and rounding carry into the exponent.

## Validation

The numeric bench uses independent C++ integer-to-float and double-to-float
casts, plus host integral/odd classification. It covers 162,299 cases:
integer power-of-two and halfway boundaries of both signs, int64 limits,
every binary64 exponent, subnormal transitions, NaNs, infinities and random
patterns. Operands change after accept to detect accidental live-input use.

Three signed multiplier configurations (STEP=8/16/64) check more than 30,000
full signed 128-bit products, aborts in every pipeline phase, restart,
held-start behavior and reset while busy. The ALU bench checks mixed numeric
operations, conversion latency, exception behavior and integer/float power.

`numeric_equivalence.py` proves the narrowing, integral/odd classification
CLZ64 and exponent-magnitude rewrites against the pre-change converted RTL for **all 2^64 inputs**.
This is combinational equivalence of these helpers, not a sequential proof
of the whole CPU.

```sh
make mpy-cross
python3 upycore/tools/unit_tests.py
python3 upycore/tools/hw_tests.py
python3 upycore/tools/hw_tests.py --compiler mpyc
python3 upycore/tools/numeric_equivalence.py  # requires Yosys
```

Generic synthesis with Yosys 0.33 / ABC reduced the complete ALU from
89,951 to approximately 85,734 generic cells (4.7%) and its longest path
from 113 to 101 levels. With the execution subunits treated as boundaries,
the conversion path into `fb` fell from 112 levels to stages of 11
(magnitude), 27 (normalization) and 15 (rounding) levels. Gate counts and
levels are tool-specific structural comparisons, not silicon area or
post-route slack. The remaining deepest generic paths are in FPU
sequencing/normalization and need checking in the next physical run.

## Backend handoff

`converted/mpy_alu.v`, `converted/mpy_core.v`, `converted/mpy_soc.v` and
`converted/RTL_STAMP` are regenerated with sv2v v0.0.12. The SRAM behavioral
stand-in remains excluded from the converted SoC so the flow can substitute
its real macros. Use the updated sources in the team's established floorplan,
with the current 512 KiB memory geometry and the existing I/O constraints.
Do not reuse a generated design folder's old `v/` file.

Run the team's established synthesis, placement, clock-tree and routing
flow with a 10 ns clock. Preserve the existing timing constraints, I/O
requirements and macro placements, updating the memory geometry as needed.

Record the exact commit, library corner, memory macros and floorplan.
Require nonnegative setup and hold slack after extracted routing, with
propagated clocks and the team's actual uncertainty/I/O constraints.
Also inspect clock-gating checks, unconstrained paths, transition/capacitance
violations, DRC and SRAM access timing. Run netlist-to-RTL equivalence on the
regenerated source. Synthesis-only success cannot sign off 100 MHz.
