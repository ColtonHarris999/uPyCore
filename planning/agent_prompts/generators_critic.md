# Criticise the generator implementation

You are reviewing the generator work against `planning/generators_plan.md`
and the unix oracle. Read the plan, then the diff from `main` through
the delegation branch. Run the suite. Write the review to
`planning/generators_review.md` on a new branch from that tip. Do not
commit on `main`. Do not push fixes onto the implementers' branches.

A finding is a behavior the oracle exhibits and the device does not, or
a spec rule the diff breaks. Quote the program, the oracle output, and
the device output. "Looks risky" without a run is not a finding. A
style note goes in a separate list and does not block.

## Done when

`planning/generators_review.md` exists and starts with a verdict:
**matches** or **does not match**.

You ran:

```
python3 upycore/tools/hw_tests.py --area generators
python3 upycore/tools/hw_tests.py --compiler mpyc --area generators
python3 upycore/tools/compiler_suite.py
python3 upycore/tools/mpy_abi.py --check
python3 upycore/tools/hw_tests.py --area calls exceptions objects gc containers builtins
```

Paste the summary lines. If a command fails, that failure is a finding.

Also run three programs the suite may only cover in passing. Put them
under `upycore/programs/hw/generators/` only if they fail and you are
demonstrating the bug. Otherwise run them with
`python3 upycore/tools/mpy_build.py run` and
`python3 upycore/tools/mpy_build.py oracle` and paste both outputs into
the review. Do not regen goldens.

1. `send(None)` on a fresh generator, then `throw` of a `StopIteration`
   subclass, then `next`.
2. `yield from` a generator that `yield from`s a third generator, with
   `send` and `close` from the outside.
3. `gc.collect` while a generator is suspended inside `yield from`,
   holding the only reference to a list in the innermost local.

## What to check

Walk these in order. Each one that holds gets a one-line pass in the
review. Each one that does not gets a finding.

- Resume order is finished, then running, then `pend_throw`, then the
  just-started `TypeError`. `gen_pend` and `gen_send` are the witnesses.
- A finished generator's later `next` raises `StopIteration` with
  `.value is None`, including when the body `return`ed something else.
- `send(1)` on a fresh generator does not consume it. The following
  `next` still runs the body.
- `close` swallows `GeneratorExit` and a normal return, raises
  `RuntimeError: generator ignored GeneratorExit` when the body yields,
  and propagates any other exception. `throw(GeneratorExit)` propagates.
- `FR_GEN` is `VNULL` on an ordinary frame and is restored across a
  nested call. `calls` and `exceptions` passing is the witness. A
  generator that calls a normal function that calls back into a second
  generator is the case to run if those areas pass and you still doubt
  the spill.
- `OB` in `upycore/tools/mpy_abi.py` matches the groups in the plan.
  `NOTIMPL` is the last kind. `NotImplementedType` is the last type
  before the exceptions. `OB_ITEROBJ` is not a stray const in
  `upycore/firmware/base.py`. `generator` sits with `function` in
  `TYPES`.
- `pc` saved by `yield from` is the opcode byte. The instruction after
  it runs once, after the delegation finishes.
- `StopIteration` from a sub-iterator completes `yield from`.
  `StopIteration` from the outer body is
  `RuntimeError: generator raised StopIteration`.
- The outer running bit stays set while the sub-iterator runs. A
  sub-generator that `next`s the outer raises
  `ValueError: generator already executing`.
- An exception that escapes sets `pc` to 0 before the caller frame is
  filled. A later `next` is `StopIteration`, not a second run of the
  body.
- `gen_gc` still passes, and check 3 above keeps the innermost list.
  The generator header is six words. The locals live in the frame block
  word 5 points at, traced the way a list's item array is traced. A
  scanner that follows the header and stops is a finding.
- Repr matches `<generator object 'name' at 0x...>` aside from the
  address mask.
- `mpyc = false` is set on every generators entry. `compiler_suite.py`
  does not compile them. No `uasyncio` module was frozen. `mpyc` was
  not given a generator.
- `planning/generators_plan.md` was not archived or rewritten to match
  a different design. If the code and the plan disagree, the finding
  names both and the oracle decides. Do not "fix" the plan to describe
  the code.

## Rules

- Do not lower a test, delete an assertion, or mark a new `xfail` to
  make the suite green.
- Do not treat a passing area as proof of a check you did not run. The
  three extra programs are there because the named tests can pass while
  those cases fail.
- If you find a bug, describe the one-line cause you believe and the
  file. Leave the repair to an implementer.
