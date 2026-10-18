# Generator acceleration

Status: **review.** The three proposals below were weighed against the
generator path that is already in `upycore/rtl/mpy_core.sv`, the one-cycle
SRAM handshake, and the v1.29.0 sources of `bm_nqueens` and
`core_yield_from`. This file does not change that path.

## Verdict

Build two small opcode changes, and leave the new register files off the chip.

| Proposal | Decision |
| --- | --- |
| 1. `FOR_ITER` enters resume itself | **Build.** A few states. Every `for`, `tuple()`, and `set()` over a generator loses a Python call per item. |
| 2. One shadow register file for the suspended frame | **Skip.** It speeds only an undisplaced ping-pong, and the same copies get cheaper by issuing the existing spill back-to-back. |
| 3a. `YIELD_FROM` forwards a generator child with no tuple and no `_yfrom` | **Build.** This is the 18,000-cycle path. |
| 3b. A stack of ten on-chip frame slots under that opcode | **Skip.** The parked parents never become the live frame. |
| Recycle frames that die inside `tuple()` / `set()` | **Later, and only from the collector.** Resume runs once per yielded item; allocation runs once per generator. |

The 0.3× figure and the 18,000-cycle figure are two different machines.
A single-level `for` over a generator is a few times slower than a
`range` loop because each item pays `__next__` plus two frame copies.
`core_yield_from` does that ten times per integer, through firmware, and
allocates a tuple on every hop. Closing 0.3× does not close 18,000, and
a register file sized for the chain does not close 0.3×.

## What one item costs today

SRAM latency is 1 (`MPY_SRAM_LATENCY` in `upycore/rtl/mpy_defs.svh`).
The core still spends four cycles per word. `wr` / `rd` enter `S_MWAIT`
on the issue edge; `mpy_mem` accepts on the next edge and pulses `ack_o`
one edge after that; the core samples the ack on the edge after that and
only then runs the following state. A spill of `n_state` words is the
15 header words plus the state words:

```text
spill(N) ≈ 64 + 4N cycles
fill(N)  ≈ 64 + 4N cycles
```

`S_SPILL` / `S_SP_H` / `S_SP_R` in `mpy_core.sv` are that loop. A
generator image is the same record written to the heap block hanging off
word 5, via `S_GSAVE`.

`FOR_ITER` (`0x4b`) does not look at the object kind. A four-slot
iterator whose kind is `IT_PYOBJ`, and the null-slot form a generator
expression emits, both take `S_AT` for `__next__` and then `S_CALL`.
`generator____next__` is firmware and its only job is `_gresume`.
`_gresume` (`S_GR0` .. `S_GR_GO`) spills that firmware frame and fills
the generator from the heap. `YIELD_VALUE` writes the image back and
fills the firmware frame, which returns, which fills the `for` frame.

For a caller with `n_state = 12`, a `__next__` frame of 6, and a
generator of 8, the overhead with an empty body is about **800 cycles**:

| Piece | Cycles |
| --- | ---: |
| `__next__` lookup, call, and the firmware bytecode | 210 |
| Spill and fill of the caller and of the `__next__` frame | 400 |
| Fill the generator image and write it back at `yield` | 192 |

An inline `range` step is the `ABI_IT_RANGE` arm of `S_IT`: a compare, an
add, and a push. No SRAM. Under 15 cycles. The 0.3× result is what that
gap looks like once the loop body itself is a few hundred cycles. It is
the single-level `for`. It is not `core_yield_from`.

`YIELD_FROM` (`0x68`) always hooks `_yfrom`. For a generator child,
`_yfrom` calls `_gresume`, catches `StopIteration`, and returns a fresh
`(True, value)` or `(False, value)` tuple. `S_YF_V` then pushes the
value and suspends through `S_YLD` with `pc` still on this opcode. No
user bytecode runs between the child's yield and the parent's yield.
That fact is the whole of proposal 3.

## Proposal 1 — resume from `FOR_ITER`

Worth building. Area is a kind compare and a branch into the resume
states that `_gresume` already has. Power falls, because the attribute
walk, the firmware call, and two of the five frame copies stop touching
SRAM. The win applies to every `for` over a generator, including
`_list_of_iter` and `_set_add_iter`, which is how `tuple()` and `set()`
consume the generator expressions in `bm_nqueens`.

After it lands, the empty-body item is about **450 cycles**: spill the
caller, fill the image, run the body, write the image, fill the caller.
That is roughly 1.8× off the 800, so a benchmark that is 0.3× of a
`range` loop moves toward about 0.5×. It does not meet a `range` loop.
The remaining copies are the memory handshake, and proposal 2 is the
expensive way to delete them.

The fast path is `next` of a `OB_GENERATOR` with an implicit `None`
send. Both iterator shapes have to hit it: `IT_PYOBJ` in slot 0, and the
null slot whose object sits in slot 1. A user iterator that only has
`__next__` stays on the call. `StopIteration` has to land in the exhaust
check `S_RX_SI` already uses for `FOR_ITER`, including a finished
generator and a `return` whose `.value` the `for` loop drops. Resume
order stays finished, then running, then `pend_throw`. The running bit
is still set for the body and cleared at the yield.

`send`, `throw`, and `close` stay firmware. They are not the 0.3×.

## Proposal 2 — one shadow register file

Skip it. The ping-pong it describes is real, and one slot does cover
`for x in gen` while that generator is the only one suspended. It does
not cover the benchmark people reach for next.

A full shadow of the live frame is the register file (64 × 36), the
exception stack (16 × handler, value-pointer, finally bit, and a tagged
word), and the header registers `spill` already writes. That is about
**4,100 flip-flops**, plus a bank mux on every operand read. The live
file is already the sequential bulk of the core; SRAM is 256 KB and
dwarfs 4k flops on area, so this is not an area emergency. It is a
critical-path and coherence tax for a win the spill loop can give you
on every call, generators included.

Implementing the "swap" as a bank select, with the idle bank clock-gated,
keeps the data from toggling and keeps the leakage to one extra file.
The mux is still in the operand cone of every instruction, including
`bm_fannkuch` and pystone. A data-path swap that assigns all 4k bits
both ways on every yield is the version that burns power; do not build
that one either.

Correctness is the larger cost. The collector scans two SRAM root ranges
and the heap image on word 5. A frame that lives only in the shadow file
is invisible, and the heap image is stale while the slot holds it. Every
collection has to spill the slot first or the scanner has to grow a third
root. `yield from`, and any generator whose body iterates a second
generator, displaces the slot on the way in and again on the way out, so
the common nested case pays the heap copy plus the tag check. The
proposal already grants that a 10-deep chain thrashes. `bm_nqueens` is
the same shape one level down: `permutations` is suspended across
`tuple(genexp)` and `set(genexp)`, so the slot holds the inner expression
and the outer generator still comes from the heap once per permutation.

The copies proposal 2 deletes are an artifact of four cycles per word.
Issuing the next spill word while the previous ack is in flight brings
`spill(N)` from `64 + 4N` toward `N + a few`. The 450-cycle plan-1
remainder falls to something near 150, and every ordinary call gets the
same speedup, which `set()` and `tuple()` need more than they need a
second file. If a later measurement still shows the single-level `for`
behind, one clock-gated bank sized to the `n_state` the perf suite
actually uses (a generator expression is far under the linker's 64) is
the fallback. Measure plan 1 first. A full 64-entry shadow is the wrong
size, and ten of them are proposal 3b.

## Proposal 3 — `yield from` in the opcode

Build the forward path. Leave the ten frame slots off the chip.

`core_yield_from` at v1.29.0 is:

```python
def recursive_yield_from(depth, iter_):
    if depth <= 0:
        for i in iter_:
            yield i
    else:
        yield from recursive_yield_from(depth - 1, iter_)
```

The leaf is `for` / `yield`, not `yield from range`. Each of the ten
parents is parked on `YIELD_FROM`. The stated 18,000 cycles per integer
is those ten hops: firmware `_yfrom`, `_gresume`, a `(True, value)`
tuple, and another yield. Plan 1 removes the outermost `__next__` and
shaves one call off 18,000. The chain stays.

`S_YF_V` already re-yields with no bytecode in between. While every
parent is parked on that opcode and the send value is `None`, the value
the leaf yields is the value the outermost `for` receives. The parents
do not need to become the live frame, so they do not need a slot.

The opcode path:

1. On resume of a generator whose saved `pc` is `YIELD_FROM`, with no
   throw and a `None` send, read the sub-iterator out of the saved stack.
2. If that child is a generator parked on the same opcode, follow it.
   Ten pointer chases are about a hundred cycles. Doing it every integer
   is fine; a single cached leaf pointer is optional and has to die on
   `throw`, `close`, and exhaustion.
3. Run the leaf. In this benchmark that is one `range` step and one
   `YIELD_VALUE`. Deliver that value to the frame that called `next` on
   the outermost generator.
4. When the leaf finishes, resume the innermost parent for the bytecode
   after `yield from` (a return, in this program) and let that complete
   the next parent. That walk happens once per chain, not once per integer.
5. Anything else — `send` of a non-`None`, `throw`, `close`, a child that
   is not a generator and not a range/list/tuple iterator — falls through
   to `_yfrom` unchanged.

A range or list child of `yield from` is the same arm: step the iterator
words, and on exhaustion push the finished value and continue. That
speeds `yield from range(n)`. It is not what `core_yield_from` does, and
it is worth having because the predicate is the same.

Steady state per integer becomes one leaf resume plus the deliver.
With today's spill that is a few hundred cycles, on the order of 50×
less than 18,000, with no extra flops. Pipelined spill makes the leaf
resume cheaper still. The running bits on the parents stay set, which is
what makes `next` on an outer generator raise `generator already
executing`. `pc` on each parent stays on the `YIELD_FROM` byte until that
parent actually completes.

### The ten-slot stack

About 4,100 flops times ten is about **41,000 flip-flops**, and an 11-way
mux in front of every operand read. A flop is far larger than an SRAM
bit; this is a real fraction of a 256 KB machine, and the mux is a power
and Fmax tax on every program that never yields. Clock-gating the idle
slots does not remove the mux.

The stack is the storage you need if each hop swaps the child in and
then swaps the parent back in to re-yield. The opcode does not have to
do that. Building the stack to make those swaps cheap preserves a control
flow the semantics allow you to delete. Area and power go up for every
benchmark so that one stretch benchmark can keep doing ten useless
resumes quickly.

## `bm_nqueens`

v1.29.0, parameter `(1000, 100)` → board size 7, one solve. The smaller
`(100, 25)` point is size 6. The body is:

```python
yield tuple(pool[i] for i in indices[:r])
# ...
if queen_count == len(set(vec[i] + i for i in cols)) == len(set(vec[i] - i for i in cols)):
    yield vec
```

Counted from that source:

| Board | Permutations | Generator expressions | Yields | Yields per object |
| ---: | ---: | ---: | ---: | ---: |
| 6 | 720 | 1,523 | 9,138 | 6 |
| 7 | 5,040 | 10,485 | 73,395 | 7 |
| 8 | 40,320 | 82,753 | 662,024 | 8 |

The second `set` runs only when the first diagonal is unique (405 of
5,040 permutations at n = 7; 40 of those are solutions). Every expression
yields once per column and is then dropped. Resume work is `n` times
allocation work. A freelist can matter only after proposal 1 has made a
yield cheap, and after a profile shows the collector. At n = 7 the
generator garbage is on the order of a megabyte and a half against a
~240 KB pool, so collections are real; they are still the second term
while each yield costs hundreds of cycles.

Recycling "at the end of `tuple()` or `set()`" is the wrong lifetime.
This collector is mark-sweep (`mpy_gc.sv`); it has no refcount, and it
learns death during the sweep. `g = (i for i in cols); tuple(g)` must
leave `g` finished and readable, because a later `next(g)` is
`StopIteration` with `.value is None`. Freeing the frame block when
`tuple()` returns makes that a dangling word 5. The header and the block
are two allocations either way.

The safe shape, if a profile justifies it, is a size-class of a few frame
blocks returned by the sweep when it frees an `OB_GENERATOR`, checked by
`alloc` before the first-fit scan. A handful of entries covers the
expression sizes in this benchmark. The class is cleared or treated as
allocated roots so a collection cannot hand the same block out twice, and
the blocks on it must not be traced as live Python values. That is a
small GC change. It is not part of making generators hit 1×.

## Order

1. `FOR_ITER` resumes an `OB_GENERATOR` directly. Re-measure a
   single-level `for` against the same loop over a `range`.
2. `YIELD_FROM` forwards parked generator parents and steps a
   range/list/tuple child, with `_yfrom` as the fallback. Re-measure
   `core_yield_from`; the per-integer number should leave the thousands.
3. If ordinary calls and the remaining generator copies still dominate,
   pipeline `S_SPILL` / `S_FILL` toward one word per cycle.
4. Profile `bm_nqueens`. Add the frame size-class only if the collector
   is then a large share.

The shadow file and the ten-slot stack are not on this list.
