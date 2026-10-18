# Implement `yield`

You are implementing slice 1 of `planning/generators_plan.md`. Read that
file first. It is the spec: the object layout, the resume check order,
and the files to touch. Work on a new branch from the tester's branch
(the one that added `upycore/programs/hw/generators/`). Do not commit
on `main`.

Slice 2 (`yield from`, `async`, the abandoned `with`) is a later agent.
Leave opcode `0x68` on the existing `NotImplementedError` path.

## Done when

`python3 upycore/tools/hw_tests.py --area generators` prints `PASS` for
`gen_yield`, `gen_send`, `gen_return`, `gen_throw`, `gen_close`,
`gen_pend`, `gen_state`, `gen_repr`, and `gen_gc`. Remove the `xfail`
marker from each of those in the same change. An `XPASS` fails the
suite.

The slice 2 names still print `XFAIL`. Leave their markers.

Then run:

```
python3 upycore/tools/hw_tests.py --area calls
python3 upycore/tools/hw_tests.py --area exceptions
python3 upycore/tools/hw_tests.py --area gc
python3 upycore/tools/mpy_abi.py --check
```

All four exit 0.

## What to build

The call of a generator function binds arguments with the existing
`S_BF` / `S_BS` / `S_CELLS` path, writes that frame into the generator's
frame block, and returns the six-word object without fetching. `next`
and `send` copy the block back into the register file and run until
`YIELD_VALUE`, `RETURN_VALUE`, or an exception that leaves the frame.

Follow the spec's tables. Rewrite `OB` and the `TYPES` prefix in
`upycore/tools/mpy_abi.py` as that file shows. `NOTIMPL` stays the last
kind. `NotImplementedType` stays the last type before the exceptions.
Move `OB_ITEROBJ` out of `upycore/firmware/base.py`. The generator is a
six-word header plus a frame block, not a tail on the header. `FR_GEN`
is header word 14. Extend spill and fill through it so an ordinary call
still round-trips. `pc == 0` means finished.

Resume checks, in this order: finished, already running, take a pending
throw without clearing it, just-started `send`, store the sent value at
the top of stack, clear the pending throw, set running, install the
frame, then inject a throw if there is one. `send(1)` on a fresh
generator that already has a `pend_throw` raises the `TypeError` and
leaves the pending exception for the next `next`.
`YIELD_VALUE` captures the top of stack, stores `None` there, writes
the image, and returns the captured value. A normal `return` and an
escaping exception set `pc` to 0 before the frame is filled back. A
`StopIteration` that escapes the body becomes
`RuntimeError: generator raised StopIteration`. A `return` becomes
`StopIteration(value)` at `send` / `__next__`.

Firmware wrappers in `upycore/firmware/iters.py`:

- `generator____next__(self)`
- `generator__send(self, value)`
- `generator__throw(self, typ, val=None, tb=None)`
- `generator__close(self)`
- `generator__pend_throw(self, exc)`

`close` is the wrapper in the spec. It calls `_gresume`, the native
next to `_inext`. `pend_throw` reads and writes header words 3 and 4.
The repr case sits next to `OB_FUNCTION`.

`for` and `iter` go through `__next__`. Do not add an iterator kind.

Put the four oracle strings in the `MSGS` table in
`upycore/tools/mpy_abi.py` when the core raises them, and as the same
characters when firmware raises them. Append any new core qstr. Do not
insert one in the middle of `CORE_QSTRS`. Regenerate with
`python3 upycore/tools/mpy_abi.py --sv`.

Before writing the yield state, disassemble `gen_yield` with
`vendor/micropython/tools/mpy-tool.py -d` so the saved `pc` points at
the next opcode after `YIELD_VALUE`.

## Rules

- Do not edit goldens, the programs, or the slice 2 markers.
- Do not implement `YIELD_FROM`, `uasyncio`, or a firmware bytecode
  interpreter.
- If a sentence of the spec cannot be built as written, stop and report
  it. Do not invent a second frame model.
- Update `upycore/docs/mpy_bytecode.md` and `upycore/docs/mpy_gc.md` to
  describe the object you actually built.
- A `yield` in a frame whose `FR_GEN` is `VNULL` still raises the old
  `generators aren't supported` error.
