# Write the generator suite

You are adding the hardware tests for generators. The spec is
`planning/generators_plan.md`. Read it before you write a program. Work
on a new branch. Do not commit on `main`.

You do not change `upycore/rtl/`. The device raises
`NotImplementedError: generators aren't supported` today. Every new
test is marked `xfail` and must come out `XFAIL`, not `FAIL` and not
`XPASS`.

## Done when

`python3 upycore/tools/hw_tests.py --area generators` prints `XFAIL` for
every new test and exits 0.

`python3 upycore/tools/hw_tests.py --check-goldens --area generators`
exits 0. Goldens are the unix oracle's bytes. Build the oracle with
`make oracle` if `build/oracle/src/ports/unix/build-upycore/micropython`
is missing. Build `mpy-cross` with `variants/upycore/build.sh mpy-cross`
if it is missing.

`python3 upycore/tools/hw_tests.py --compiler mpyc --area generators`
prints a skip line and exits 0. `python3 upycore/tools/compiler_suite.py`
exits 0. `python3 upycore/tests/test_hw_manifest.py` exits 0.

`make test-hw-calls` still passes. You are not fixing calls.

## Programs

Put them in `upycore/programs/hw/generators/`. One manifest entry each,
area `generators`, with `xfail` set to a one-line reason and
`mpyc = false`. Catch exceptions and print `type(exc).__name__` and
`exc` (and `exc.value` when the spec mentions it) so the exit status is
0. The one exception is `gen_trace`, which is uncaught: set
`uncaught = true` and let the traceback be the golden.

Slice 1:

| Name | Cover |
| --- | --- |
| `gen_yield` | three yields, a `for` over the generator, two live generators from one function, a default, a keyword-only argument, `*args`, and a generator expression |
| `gen_send` | `x = yield ...` fed by `send`, `send(1)` on a fresh generator, `send` after the generator has returned |
| `gen_return` | `return 5` then `StopIteration.value`, a `for` that prints only the yielded values, the following `next` whose `.value` is `None`, and `next(g, "done")` |
| `gen_throw` | `throw(ValueError)`, `throw(ValueError("n"))`, a `throw` caught by `except ValueError` inside the body, a third argument, and `throw("no")` |
| `gen_close` | `finally` runs on `close` and prints, a body that yields after catching `GeneratorExit`, `close` on a finished generator, `close` before the first yield |
| `gen_pend` | `pend_throw` fires on the next `next`, `pend_throw` on a finished generator does not raise by itself, and a generator that calls `next` on itself |
| `gen_state` | a local incremented across yields, a closure cell, `finally` on a normal `return`, and `raise StopIteration` inside the body |
| `gen_repr` | `print(g)` and `type(g).__name__` and `iter(g) is g` |
| `gen_gc` | a list reachable only from a suspended generator's local is still there after `gc.collect()`. Dropping the generator and collecting frees it. Copy the shape of `upycore/programs/hw/gc/gc_root_heap_iter.py`. Do not print addresses |

Slice 2, same `xfail` rule:

| Name | Cover |
| --- | --- |
| `gen_yield_from` | `yield from` another generator, and the value that generator `return`s |
| `gen_yield_from_iter` | `yield from` a list, then `send` of a non-`None` value into a `yield from` of a list |
| `gen_yield_from_throw` | `throw` and `close` into a `yield from`, and a sub-generator whose `except GeneratorExit` swallows the exit |
| `gen_async` | `async def` that `await`s another async function, driven with `send` / `next`, plus an `async for` |
| `gen_with` | a generator that enters `with` and is then dropped, so `__exit__` does not run; a second generator that is `close`d, so `__exit__` does run |
| `gen_trace` | an uncaught `ValueError` raised on the line after a `yield`. `uncaught = true` |

Keep each program short enough that the golden is the behavior, not a
story. Print labels so a one-line diff names the case.

If the oracle and the spec disagree, keep the oracle's output, say so
in the pull request, and leave the spec sentence you disagreed with
unchanged.

## Harness

`mpyc` does not implement `yield`. `make test` compiles every booted
program with `mpyc`, and `upycore/tools/compiler_suite.py` fails when
`mpy-cross` accepts a file and `mpyc` rejects it.

Add `mpyc: bool = True` on the test record in `upycore/tools/hw_tests.py`.
A toml entry `mpyc = false` stores it. When the runner's compiler is
`mpyc`, skip those tests, print `SKIP`, and exit 0 if every selected
test was skipped. `compiler_suite.suite_sources` skips them too. Default
`true` so existing areas are unchanged.

Add `generators` to `HW_AREAS` in the `Makefile` and to the area list in
`.github/workflows/all-tests.yml`.

Extend `upycore/tests/test_hw_manifest.py` so a generators entry with
`mpyc = false` is booted on the device path and dropped from the mpyc
source list. The existing disabled-compiler-area assertion stays true.

## Rules

- Do not edit RTL, firmware, or goldens by hand. Generate goldens with
  `python3 upycore/tools/hw_tests.py --regen --area generators`.
- Do not remove an `xfail` marker. The implementers do that when the
  device matches.
- Do not import `asyncio`.
