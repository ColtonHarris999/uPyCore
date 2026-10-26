# Container accelerator, scoreboard, and async ALU

Status: `upycore/rtl/mpy_ca.sv` is the container accelerator (CA). It
sits beside `mpy_core` and `mpy_gc` on the `mpy_soc` memory port. The
async ALU is part of `mpy_core` and reuses `mpy_alu` unchanged. Both are
on by default. `+CA=0` and `+AALU=0` switch them off in simulation, and
the `CA_EN` and `AALU` parameters of `mpy_core` do the same in synthesis.

## What runs in the background

The core ships a command, marks the data it touches busy, and goes on to
the next instruction. A later access to busy data waits until that data
is ready. Two kinds of work go this way:

| Work | Shipped by | Busy data |
| --- | --- | --- |
| Copy `n` tagged words (`_wcopy`) | the `_wcopy` native (`S_NAT_WCA`) | destination words not written yet; source words not read yet |
| A list's grow copy | list append when the item array is full (`S_LA_CA`) | the new array's first `len` words; the old array |
| A binary op that cannot fail | `S_NUM_GO` | the register that will hold the result |

The firmware sends every bulk list and tuple copy through `_wcopy`:
`a + b`, `a * n`, `a[i:j]`, `list(x)` and `extend` of a list or tuple,
`tuple(list)`, `copy()`, `insert`, `pop`, `del a[i]`, slice assignment,
and the dict and set copies. A list or tuple `extend` of one item stays an
append, which is cheaper than a copy.

## Container accelerator

A command is "copy `n` words from `src` to `dst`", tags included. Commands
queue `QDEPTH` deep (2) and run in issue order. When `dst` is above `src`
the copy runs from the top word down, so a shift inside one item array
behaves like `memmove`. The engine issues a word's write in the cycle the
read's ack arrives, and the next read in the cycle the write's ack
arrives. On an idle port that is four cycles a word. The core's own loop
takes eight.

The core keeps three rules:

1. It allocates the destination before it ships. A failed allocation and
   its `MemoryError` stay on the instruction that caused them.
2. Its stores that a command reads have completed before it ships.
3. It waits for the CA to drain before it starts a collection (`S_GC_T`).
   No copy is in flight while the collector marks, and no source block is
   freed under the engine.

A faulting CA access (unaligned, flash store, bus) drops its command and
sets a sticky fault. The core halts with the matching code at its next
fetch.

## Scoreboard

Each queued command holds two byte ranges: the destination words it has
not written yet and the source words it has not read yet. The running
command shrinks both as each word lands, so the front of a forward copy is
readable before the copy ends. A core access is busy when it is

- a load or a store of a destination word still owed, or
- a store to a source word still owed.

The check is at the memory port, not in the microcode. `mpy_soc` holds a
busy core access in the arbiter, and the core only sees a longer wait for
its ack. Every heap access the core makes goes through that port, from
microcode or from firmware natives, so whatever touches a copy in flight
waits for exactly the words it needs. With `QDEPTH = 2` the scoreboard is
eight 32-bit compares.

## Port arbitration

`mpy_mem` takes one request at a time and ignores a request that arrives
while it is busy. The arbiter in `mpy_soc` therefore holds a request until
the memory is free, then grants the collector, the core, and the CA in
that order. The CA uses the cycles the core leaves idle. Before this
change the collector owned the port while busy and the core had it
otherwise. With the CA idle the core's timing is unchanged: `+CA=0
+AALU=0` gives the old cycle counts. A core access that arrives while a CA
access is in flight waits one cycle at most.

## Async ALU

`S_NUM_GO` starts the ALU as before. When the op cannot fail and cannot
need a boxed int64, the core writes nothing yet: it marks the result's
register busy (`aalu_pend`, `aalu_slot`), drops the stack by one, and
fetches the next instruction. The result waits in `mpy_alu`'s output
register, which holds it because no other op can start. When a state that
must not run past it is reached and the ALU is done, `S_AALU_WB` writes
the register and returns to that state. That one state is the only place
the result is written, so the register file keeps a single write
structure inside the sequencer's `case`.

An op goes this way when its operands decide everything at issue:

- float operands: compares, `+`, `-`, `*`, and `/`, `//`, `%` with a
  nonzero divisor;
- two small ints (31-bit): compares, `+`, `-`, `&`, `|`, `^`, `/`, `//`,
  `%` with a nonzero divisor, and `*` when both fit in 16 bits.

Everything else (unary ops, shifts, `**`, int64 operands, a zero
divisor) waits in `S_NUM_W` as before, so `ZeroDivisionError`,
`OverflowError`, and the firmware fallbacks are raised on the right
instruction.

While a result is pending, `S_EXEC` runs only instructions that never read
the stack: `LOAD_FAST`, the `LOAD_CONST_*` forms, and `JUMP`. Anything else
waits. That includes every container instruction, so no container work
can consume a value the ALU has not produced. A register spill or reload
(which moves the register ring), a raise, and a collection also wait.
Each of those states enters `S_AALU_WB` once the result is ready.

## Measurements

`python3 upycore/tools/bench.py` runs `upycore/programs/bench` with both
features off, each on alone, and both on. Every configuration must print
the same output.

Cycles, firmware of this change in every column:

| Program | off | CA | AALU | both | both vs off |
| --- | ---: | ---: | ---: | ---: | ---: |
| `dict` | 319,081 | 307,045 | 310,937 | 298,901 | −6.3% |
| `float` | 762,824 | 762,824 | 650,036 | 650,036 | −14.8% |
| `intmath` | 865,989 | 865,989 | 807,094 | 807,094 | −6.8% |
| `listbuild` | 1,511,984 | 1,464,632 | 1,492,598 | 1,445,258 | −4.4% |
| `listops` | 1,445,373 | 1,234,787 | 1,434,609 | 1,223,983 | −15.3% |
| `strings` | 6,974,022 | 6,972,282 | 6,928,644 | 6,926,904 | −0.7% |

Before the firmware routed bulk work through `_wcopy`, `listops` took
5,950,997 cycles; its "off" column is 1,445,373.

The firmware routing is most of the `listops` gain: its list and tuple
slices and `list(tuple)` used to loop item by item in firmware Python.
The CA's own share (`off` to `CA`, −14.6%) is the copy running behind the
next instructions, at twice the core's rate. In every benchmark the core
never stalled on the scoreboard: the copies finished before the core
touched their words. `ca_copy.py` does stall, on purpose.

On the hardware suite (417 programs, 276.5 M cycles before this change)
the whole change saves 1.8%. The suite is mostly firmware and interpreter
overhead: 54% of all cycles are the core waiting on memory, 88% are
inside firmware frames, the port is busy 23% of the time, and the ALU
1.2%.

A small `extend` pays for the type dispatch that picks the copy: compared
with the old item loop, an empty one costs about 210 cycles more, one item
345 (it stays an append), and two items 125. Four items are already 775
cycles faster, and sixteen run 1.9x faster.

## Area

Generic gates from `yowasp-yosys` (`read_slang`, `synth -noabc
-flatten`, no technology mapping), so the counts compare designs and are
not an area in µm². `mpy_core` includes `mpy_alu` and its FPU.

| Design | Cells | Flops | vs core without either |
| --- | ---: | ---: | ---: |
| `mpy_core`, CA hooks and async ALU off | 421,553 | 12,031 | — |
| `mpy_core`, CA hooks on | 421,582 | 12,031 | +29 |
| `mpy_core`, both on | 423,923 | 12,045 | +2,370 (+0.6%) |
| `mpy_ca` (`QDEPTH = 2`) | 5,933 | 405 | +1.4% |

64 of `mpy_ca`'s flops are the `words_o` and `cmds_o` counters. The
arbiter in `mpy_soc` adds two pending bits, an owner register and a
three-way mux on the port. Altogether the change is about 2% of the core's
gates.

A first async ALU wrote the result into the register file from outside
the sequencer's `case`, in the cycle the ALU finished. That cost 50,845
cells (+12%), because every register-file bit lost its clock-enable form,
and it was 4.8 points faster on `float`. Writing through `S_AALU_WB`
costs one cycle per stalled result and 2,341 cells.

Power follows the work. The CA moves each word once, as the core's loop
did, in fewer cycles. The scoreboard compares toggle on core memory
accesses only while a copy is queued. The async ALU runs the same
operations as before, sooner.

## Why the ALU part is in

The async ALU was the open question: whether it costs too much area and
power to be worth it. On instruction traces of the float and integer
benchmarks, an op that waits in `S_NUM_W` is followed by enough pushes and
loads to hide most of its latency. A model that lets only pushes run past
a busy result predicted 9.8% on `float`. Built, it gives 14.8%, because
the next instruction's fetch and decode also overlap the ALU even when
that instruction then waits. Letting the pending result move into a
local with `STORE_FAST` (register renaming) would add about one more
point and needs a second write path into the locals; it is not done.

The cost is a pending bit, a ready bit, a 4-bit register index, a return
state, the eligibility check, and a decode of the opcodes `S_EXEC` lets
through: 2,341 cells, 0.6% of the core. The risk was precise exceptions,
and the eligibility rule removes it: nothing that can raise is ever
pending.

## Compiler

Neither compiler changes. The overlap available to the async ALU after
this change is what is left in `S_EXEC` waiting for a result: 10.0% of
`float` and 7.9% of `intmath`. A scheduler could only win part of that.
It cannot move a load across anything that might call Python code
(`__mul__`, a property, a global rebound by a callee), and an untyped
bytecode compiler knows almost nothing about types. `make test` also
requires the vendored uPy2 compiler to emit the same bytes as `mpy-cross`.
The useful "compiler" change was in the firmware, which is the runtime
library the bytecode calls: routing bulk work through `_wcopy` is what
gives the CA something to do.

## Not done

- Dict and set rehash on the CA. Rehash is 19% of the `dict` benchmark.
  The hashes are simple (one read at most), but a key the hardware cannot
  hash (an instance) sends the whole insert to the firmware. The core
  would have to wait for a first pass over the keys before it could
  retire the insert, and the probe needs a second 32-bit modulo unit.
- Byte copies (`_bcopy`). They are 1.6% of the string benchmark, which is
  dominated by firmware call overhead.
- Scratch-image swaps (`S_SCR`) are 38% of `listbuild`: `FOR_ITER`,
  attribute lookup, and list append each swap an 8-word image through
  SRAM. That is a bigger win than any overlap here, and it is separate
  work.
- The ALU issue path itself costs four states plus a three-cycle wait
  even for a one-cycle add. Shortening it is a smaller, synchronous change
  that helps every arithmetic op.

## Tests

`upycore/programs/hw/containers/ca_copy.py` reads and writes copies
right after they are shipped, shifts in both directions, extends a list
with itself, collects right after a large copy, and copies from a flash
tuple. `upycore/tb/tb_mpy_ca.sv` is a randomized unit test: a core agent
interleaves copies, loads, and stores on one window, and every load must
match a model that applies each copy at once. The file says how to build
it.
