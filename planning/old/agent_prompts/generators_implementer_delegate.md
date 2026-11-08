# Implement `yield from`

You are implementing slice 2 of `planning/generators_plan.md`. Read that
file first. Slice 1 has already landed: generator objects, `YIELD_VALUE`,
`send`, `throw`, `close`, and `pend_throw`. Work on a new branch from
that branch. Do not commit on `main`.

## Done when

`python3 upycore/tools/hw_tests.py --area generators` prints `PASS` for
every test in the area. Remove the remaining `xfail` markers in the same
change. An `XPASS` fails the suite.

Then run:

```
python3 upycore/tools/hw_tests.py --compiler mpyc --area generators
python3 upycore/tools/compiler_suite.py
python3 upycore/tools/mpy_abi.py --check
python3 upycore/tools/hw_tests.py --area calls exceptions objects gc containers builtins
```

The mpyc command skips the area and exits 0. The other commands exit 0.

## What to build

Opcode `0x68`. Disassemble `gen_yield_from` with
`vendor/micropython/tools/mpy-tool.py -d` and use that stack. The usual
shape is the sub-iterator, then a send value, then `YIELD_FROM`.

Pop the send value. The top of stack is the sub-iterator. Step it with
the `_yfrom` hook, which the yield work placed in `HOOKS` immediately
after `_getiter`. The hook follows `mp_resume` in MicroPython v1.29.0
`py/runtime.c`:

- a generator goes through `_gresume`
- `send is None` and no throw uses `__next__` or the native iterator step
- a non-`None` send loads `send` and calls it
- `GeneratorExit` loads `close` when the object has one
- any other throw loads `throw` when the object has one
- a missing method propagates the exception, and a `StopIteration` in
  that position becomes `RuntimeError: generator raised StopIteration`

The hook returns either "yielded this value" or "finished with this
value". The opcode then does one of three things:

- Yielded: push the value, save `pc` as `op_pc` (the `YIELD_FROM` byte),
  and suspend on the slice 1 yield path. The outer generator stays
  marked running until that suspend completes.
- Finished: replace the sub-iterator with the value. If this resume had
  injected `GeneratorExit` and the sub-iterator swallowed it, raise
  `GeneratorExit` again. Otherwise continue at the next instruction.
- A `StopIteration` raised by the sub-iterator's `__next__` is the
  finished case. Its `.value` replaces the sub-iterator. That is not
  PEP 479. PEP 479 is a `StopIteration` raised by the outer body.

`async def` and `await` need no new opcode. `async for` and the `with`
tests use the methods and unwinder that already exist.

## Rules

- Do not edit goldens or the programs.
- Do not clear the outer running bit while the sub-iterator is inside
  `_gresume`.
- Do not freeze `uasyncio`.
- Do not archive `planning/generators_plan.md`.
- If the disassembly and the spec's "usual shape" sentence disagree,
  follow the disassembly and say so in the pull request.
