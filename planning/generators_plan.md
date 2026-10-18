# Generators

Status: **not started.** The unix oracle (MicroPython v1.29.0, the
`variants/upycore` port) already runs `yield`, `yield from`, `send`,
`throw`, `close`, and `pend_throw`. This hart rejects the call.

Calling a function whose raw code has `RC_FLAG_GENERATOR` raises
`NotImplementedError: generators aren't supported` from `S_CF_CHK` in
`upycore/rtl/mpy_core.sv`. Opcodes `0x67` (`YIELD_VALUE`) and `0x68`
(`YIELD_FROM`) raise the same error. The linker already accepts both
opcodes and sets the flag from prelude scope bit `SCOPE_GENERATOR`
(`upycore/tools/mpy_link.py`). Decode already names them
(`upycore/rtl/mpy_decode.sv`).

The oracle sources for the behavior below are `py/objgenerator.c`,
`py/vm.c` (`MP_BC_YIELD_VALUE`, `MP_BC_YIELD_FROM`, and the
`StopIteration` arm of the exception loop), and `mp_resume` in
`py/runtime.c`, at tag v1.29.0. The port sets
`MICROPY_CONFIG_ROM_LEVEL` to extra features, so
`MICROPY_PY_GENERATOR_PEND_THROW` is on. `pend_throw` is part of this
work. Native and viper generators are not: the image tool already
rejects `@micropython.native`.

Agent prompts:

| Role | File |
| --- | --- |
| Tester | [`agent_prompts/generators_tester.md`](agent_prompts/generators_tester.md) |
| Implementer, yield | [`agent_prompts/generators_implementer_yield.md`](agent_prompts/generators_implementer_yield.md) |
| Implementer, delegation | [`agent_prompts/generators_implementer_delegate.md`](agent_prompts/generators_implementer_delegate.md) |
| Critic | [`agent_prompts/generators_critic.md`](agent_prompts/generators_critic.md) |

The tester lands first. The yield implementer branches from that and
clears the first slice of `xfail` markers. The delegation implementer
branches from the yield work and clears the rest. The critic reads the
resulting diff against this file and the oracle.

## Outcome

A generator function returns a generator object. The body runs on
`next`, `send`, `for`, or `yield from`, and suspends at `yield` with
its locals, value stack, and exception stack intact. Resuming continues
after that `yield`. The object is the iterator: `iter(g) is g`.

`return x` inside the body completes the generator. `next` and `send`
then raise `StopIteration` whose `.value` is `x` (or `None` when the
body falls off the end). A `for` loop ends without printing that value.
A later `next` raises `StopIteration` whose `.value` is `None`.

These four strings match the oracle exactly:

| Situation | Exception |
| --- | --- |
| `send` of a non-`None` value before the first `yield` | `TypeError: can't send non-None value to a just-started generator` |
| `next` / `send` / `throw` / `close` while this generator is already running | `ValueError: generator already executing` |
| `close` and the body `yield`s again | `RuntimeError: generator ignored GeneratorExit` |
| a `StopIteration` (or subclass) escapes the body | `RuntimeError: generator raised StopIteration` |

`throw` and `close` inject an exception at the saved program counter.
`finally` and `with` run if execution passes through them.
`GeneratorExit` from `close` is swallowed. Any other exception from
`close` propagates. `throw` does not swallow.

`yield from` delegates `send`, `throw`, and `close` the way `mp_resume`
does. `async def` / `await` are that same pair of opcodes. `uasyncio`
stays out of the image.

## Design

One live frame already sits in the register file (`rf`, `sp`, `xsp`,
`pc`, the exception stack). A call spills that frame into the 16 KB
reserve and installs the callee. A return fills the caller. A suspended
generator cannot stay in the reserve: the caller keeps running and will
reuse the slot.

The generator object is the suspended copy. While the body runs it
occupies one ordinary frame, the same as any other call. On `yield`,
return, or an exception that escapes the body, the hart writes the
registers back to the object and fills the caller. Nested calls the
body makes use the existing spill. They do not write the heap object.
The heap copy is updated only when the generator stops being the live
frame.

Creation reuses the binder. `S_CF_CHK` stops raising on the flag. The
call still spills the caller, installs a frame, and runs `S_BF` / `S_BS`
/ `S_CELLS`. Argument errors propagate and no object is returned. After
the cells exist, `pc` is the first opcode and `sp` is 0. Allocate the
object, copy the frame into it, fill the caller, and deliver the
object. Do not fetch.

### Object layout

`OB_GENERATOR` is kind 20, the next free kind after `NOTIMPL`. Edit
`upycore/tools/mpy_abi.py` and regenerate with
`python3 upycore/tools/mpy_abi.py --sv`. Do not hand-edit
`upycore/rtl/mpy_abi.svh` or `upycore/firmware/_abi.py`. Do not add an
`OBJ_WORDS` entry. The size depends on the function.

The type id `generator` already exists (`T_GENERATOR`). It stays out of
`PUBLIC_TYPES`. Nothing constructs it except a call of a generator
function.

Word count is `8 + 16 + n_state + 3 * n_exc_stack`. The linker already
refuses `n_state > 64` and `n_exc_stack > 16`, so the copy fits the
register file and the exception arrays.

| Word | Contents |
| --- | --- |
| 0 | `OB_GENERATOR` |
| 1 | the `generator` type |
| 2 | the function object |
| 3 | status integer. Bit 0 set means running. Clear otherwise |
| 4 | `pend_exc`. `None`, or the exception `pend_throw` stored |
| 5–7 | zero |
| 8–23 | frame-header image, 16 words. Words 0–13 match today's `hdr_word`. Word 14 is this object. Word 15 is zero |
| 24 … | `n_state` tagged values, the register file |
| after that | exception records, three words each, capacity `n_exc_stack` |

Header word 14 of every frame, which today is padding inside the 16-word
reservation (`(16 + n_state + 3 * n_exc) << 2` bytes, state at byte 64),
holds the generator object, or `VNULL` for an ordinary frame. Extend the
spill and fill loops from 14 words to 15. Initialize the register at
reset and in `S_CF_SW`. Word 15 stays padding so the state does not move.

Saved `pc == 0` means finished. Flash code is never at address 0. Set
that word when the body returns or an exception escapes. A later resume
does not run the body again.

Counts and saved program counters are `INT` or `CONTROL`. Python values
keep their tags. `mpy_gc.sv` follows every pointer-tagged word of the
allocation (`G_OBJ`). That is what keeps locals alive. Do not switch the
scanner to the fixed field list in `upycore/docs/mpy_gc.md` as part of
this work. Do add a generator row to that doc that describes this
object, so the next person does not "complete" the doc by dropping the
tail.

`pend_throw` is firmware over words 3 and 4 (`_ld` / `_st`). If word 3
bit 0 is set, raise `ValueError: generator already executing`. Otherwise
store the new exception and return the previous word 4. Match
`gen_instance_pend_throw`: a finished generator still accepts the store.
The next resume notices `pc == 0` first and raises `StopIteration`
without injecting the pending exception.

### Resume

One native, `_gen_resume(gen, send, throw)`, implements
`mp_obj_gen_resume`. Firmware methods on the type are thin wrappers.
The linker binds `generator____next__`, `generator__send`,
`generator__throw`, and `generator__close` the same way it binds
`enumerate____next__`.

Check order, which is the oracle's order:

1. `pc == 0`: finished. The native raises `StopIteration`. The value is
   `None`. The original `return` value is not raised again.
2. Status bit 0 set: `ValueError: generator already executing`.
3. If word 4 is not `None`, that object is the throw value for this
   resume, then word 4 becomes `None`. This is `pend_throw`.
4. `sp == 0` and `send` is not `None`: the `TypeError` above. Do not set
   the running bit and do not move `pc`. A later `next` still starts the
   body.
5. Otherwise, if `sp != 0`, store `send` at the top of the value stack.
   `YIELD_VALUE` has stack effect 0 in `upycore/targets/upycore.json`.
   The yielded value is still sitting there. Resume replaces it. The
   next opcode (`STORE_FAST`, `POP_TOP`, or another use) sees the sent
   value. With `MICROPY_PY_GENERATOR_PEND_THROW`, the snapshot taken at
   yield stores `None` in that slot after the yielded value has been
   captured. The next resume overwrites it.
6. Set the running bit. Spill the caller, install the image as the live
   frame, set header word 14 to the object.
7. If there is a throw value and the byte at `pc` is not `YIELD_FROM`,
   raise it inside the generator as `RAISE_OBJ` would, including
   `mp_make_raise_obj` (a type is instantiated, a non-exception becomes
   `TypeError: exceptions must derive from BaseException`). `throw`'s
   third argument is ignored. If the second argument is not `None`, it
   is the object used and the first is not.
8. Fetch.

On `YIELD_VALUE`: capture the top of stack as the result, store `None`
there, clear the running bit, write the image, fill the caller, deliver
the captured value.

On `RETURN_VALUE`, and on an exception that unwinds past the generator
frame: set `pc` to 0, clear the running bit, write that much of the
image, then take the existing return or raise path. Traceback lines are
recorded while the generator frame is still live (`S_RX_TB` already
does this before the pop). A `StopIteration` that escapes is replaced
with `RuntimeError: generator raised StopIteration` before it reaches
the caller. A normal `return` is not that case. It is
`StopIteration(value)` raised by the native as it delivers to
`__next__` or `send`.

`__next__` and `send` both want that raise. `close` is the wrapper that
distinguishes the three outcomes:

```python
def generator__close(self):
    try:
        _gen_resume(self, None, GeneratorExit())
    except GeneratorExit:
        return None
    except StopIteration:
        return None
    raise RuntimeError("generator ignored GeneratorExit")
```

A yield returns a value, so execution reaches the `raise RuntimeError`.
A normal return becomes `StopIteration` and is success. `GeneratorExit`
is success. Any other exception propagates because it is not caught.
`GeneratorExit()` here has empty args. The oracle uses one constant
instance for `close`; behavior matches, object identity does not need
to. `throw(GeneratorExit)` is not `close`: the exception propagates.

`for` and `iter` need no new iterator kind. `iter` is `_getiter`. An
object whose type has `__next__` and no `__iter__` is returned as
itself (`upycore/firmware/iters.py`). `for` compiles to `GET_ITER_STACK`
/ `FOR_ITER`. `GET_ITER_STACK` misses in the type, takes the existing
`GETITER` hook, and that hook returns the same object. The continuation
sets `ABI_OVR_PYOBJ` and re-dispatches. `FOR_ITER` calls `__next__`.
`StopIteration` already ends the loop (`S_RX_SI`). `list(g)` and
`next(g, default)` use that same `__next__`.

`LOAD_GLOBAL` uses the frame's `glb`, saved in the image at creation
from the function. There is no separate globals swap.

### `yield from`

Disassemble a real fixture with `mpy-tool.py -d` before writing the
opcode. The shape `mpy-cross` emits is the spec for the stack. The
usual shape is the delegated iterable, then `None`, then `YIELD_FROM`.

`YIELD_FROM` pops the send value. The top of stack is the sub-iterator.
It calls the same rules as `mp_resume`:

- A generator object goes through `_gen_resume`.
- Anything else with `send is None` and no throw uses the iterator
  protocol (`__next__`, or the native `ITER` step the `for` loop uses).
- A non-`None` send with no throw loads `send` and calls it.
- `GeneratorExit` loads `close` if it exists and treats a return as
  completion. A missing `close` propagates the exception.
- Any other throw loads `throw` if it exists.
- A missing `throw` / `close` propagates the exception.
  `StopIteration` in that position becomes
  `RuntimeError: generator raised StopIteration`.

Implement that policy once, in firmware (`_yield_from_step`), and call
it from the opcode the way `GET_ITER` calls its hook. The generator
frame is spilled to the reserve for the call and filled on return. The
heap image is written only if this opcode then yields.

Outcomes:

| Sub-iterator | This opcode |
| --- | --- |
| Yields `v` | Push `v`. Save `pc` as the address of the `YIELD_FROM` byte (`op_pc`), not the next instruction. Suspend, the same path as `YIELD_VALUE`, including the store of `None` at top of stack. The next resume executes `YIELD_FROM` again and pops the sent value |
| Finishes with value `r` | Replace the sub-iterator with `r`. If this resume injected `GeneratorExit` and the sub-iterator swallowed it, raise `GeneratorExit` again. Otherwise dispatch the next instruction |
| Raises | Drop the sub-iterator and raise. A `StopIteration` raised by the sub-iterator's `__next__` is completion: its `.value` replaces the sub-iterator and `pc` moves past the opcode. That is the `MP_BC_YIELD_FROM` arm in `vm.c`, distinct from PEP 479 |

The outer generator stays marked running while the sub-iterator runs.
Resuming the outer from inside the sub-iterator is
`generator already executing`.

### `async` and `with`

`async def` is a generator function. `await` is `yield from`. No new
opcode. `async for` and `async with` are method calls (`__aiter__`,
`__anext__`, `__aenter__`, `__aexit__`) plus `yield from` and the
exception matcher. The tests cover them. A missing method is the
ordinary `AttributeError`. Do not add a coroutine type.

An abandoned generator does not run `with`'s `__exit__`. There is no
finaliser. `close` does run it, because `close` injects `GeneratorExit`
and the existing `with` unwinder handles that exception. This is pivot
plan §1.3 row 18.

### Printing

`upycore/firmware/fmt.py` prints a generator as
`<generator object 'name' at 0x...>`. The name is the raw code's simple
name, the same string `_rc_name` uses for functions. The hardware
runner masks `at 0x...` before comparing.

### What this does not do

- Freeze or rewrite `uasyncio`. Its `.mpy` can be linked later. It is
  not a test of this change.
- `gi_running`, `gi_frame`, `gi_yieldfrom`, `gi_code`. The v1.29 oracle
  does not have them.
- A second register file, or a firmware interpreter for the body. The
  body executes on the existing fetch/decode path.
- Teaching `mpyc` to emit `yield`. `planning/upy2_compiler_plan.md`
  forbids that until this runtime exists, and the compiler lives in
  uPy2. Generator programs opt out of the `mpyc` pass (the tester's
  harness note).
- Changing frame capacity. `n_state > 64` is still a link error.

## Harness

`mpyc` rejects `yield`. `make test` and `make test-hw-<area>` compile
the suite with `mpyc`, and `compiler_suite.py` treats "mpy-cross
accepted, mpyc rejected" as a failure. The tester adds `mpyc = false`
to a manifest entry (default true). `hw_tests.py --compiler mpyc` skips
those entries and exits 0. `compiler_suite.py` skips them too. The
mpy-cross run boots them. Add `generators` to `HW_AREAS` in the
`Makefile` and to the area matrix in `.github/workflows/all-tests.yml`.

Goldens come from the unix oracle (`make regen-goldens` or
`hw_tests.py --regen` on the new area). The device compares masked
streams. Implementers do not edit goldens.

## Tests

Programs live in `upycore/programs/hw/generators/`. Each entry in
`upycore/programs/hw_tests.toml` is `xfail` until the slice that makes
it pass. An `XPASS` fails the suite, so the implementer removes the
marker in the same change as the fix.

Slice 1, yield. Cleared by the yield implementer.

| Test | What it prints or catches |
| --- | --- |
| `gen_yield` | several `yield`s, a `for` loop, two generators from one function, defaults, a keyword-only argument, `*args` |
| `gen_send` | `send` across `yield`, the just-started `TypeError`, `send` after completion |
| `gen_return` | `StopIteration.value` from `return`, a `for` loop that does not show it, a second `next` whose value is `None`, `next(g, default)` |
| `gen_throw` | throw a type, an instance, a caught throw, a third argument ignored, a non-exception |
| `gen_close` | `finally` on `close`, a yield after `GeneratorExit`, `close` on a finished generator, `close` before the first `yield` |
| `gen_pend` | `pend_throw` injected on the next resume, `pend_throw` on a finished generator, `next` of a running generator |
| `gen_state` | a local and a closure cell alive across `yield`, `finally` on a normal return, PEP 479 |
| `gen_repr` | the repr and `type(g).__name__` |
| `gen_gc` | a list reachable only from a suspended generator survives `gc.collect`; dropping the generator lets it be collected. Follow `upycore/programs/hw/gc/`. Do not pin an address or an append index |

Slice 2, delegation. Cleared by the delegation implementer.

| Test | What it prints or catches |
| --- | --- |
| `gen_yield_from` | `yield from` a generator, including the delegated `return` value |
| `gen_yield_from_iter` | `yield from` a list, and `send` of a non-`None` into that delegation |
| `gen_yield_from_throw` | `throw` and `close` through `yield from`, and a sub-generator that swallows `GeneratorExit` |
| `gen_async` | `async def` / `await`, and `async for` |
| `gen_with` | an abandoned `with` does not run `__exit__`; `close` does |
| `gen_trace` | an uncaught exception. `uncaught = true`. The line is inside the generator |

`genexpr` is slice 1 in behavior (it is a generator function). Cover it
inside `gen_yield` rather than as a second program.

## Files

| File | Change |
| --- | --- |
| `upycore/rtl/mpy_core.sv` | Stop rejecting the flag. Snapshot, resume, `YIELD_VALUE`, then `YIELD_FROM`. Finish on return and on an escaping exception |
| `upycore/tools/mpy_abi.py` | Kind, messages, native id, appended qstrs |
| `upycore/firmware/iters.py` | `__next__`, `send`, `throw`, `close`, `_yield_from_step` |
| `upycore/firmware/fmt.py` | repr |
| `upycore/firmware/errors.py` | The old `ERR_GENERATOR` text remains the guard for a `yield` in a frame whose header word 14 is `VNULL` |
| `upycore/targets/upycore.json` | Phase of the two opcodes, via `upycore/tools/mpy_gen_catalog.py` |
| `upycore/docs/mpy_bytecode.md`, `upycore/docs/mpy_gc.md` | The object and the two opcodes, after the code matches |
| `upycore/programs/hw/generators/` | The programs and goldens |
| `upycore/tools/hw_tests.py`, `upycore/tools/compiler_suite.py` | `mpyc = false` |
| `Makefile`, `.github/workflows/all-tests.yml` | The new area |

`mpy_link.py`'s comment on `0x67` / `0x68` is updated when the core
executes them. The flag it already writes stays the signal `S_CF_CHK`
reads.

## Exit

Slice 1: `python3 upycore/tools/hw_tests.py --area generators` shows
`PASS` for the slice 1 names and `XFAIL` for the slice 2 names. No
`XPASS`. `python3 upycore/tools/hw_tests.py --area calls` and `--area
exceptions` and `--area gc` still pass.

Slice 2: every generators entry is `PASS`, markers gone.
`python3 upycore/tools/hw_tests.py --compiler mpyc --area generators`
skips them and exits 0. `python3 upycore/tools/compiler_suite.py` exits
0. `python3 upycore/tools/mpy_abi.py --check` exits 0.

`python3 upycore/tools/hw_tests.py --area calls exceptions objects gc containers builtins`
passes after slice 2. Those areas are the ones whose frames, iterators,
and exception paths this change shares.

Do not archive this plan in an implementation PR. Archive it when that
exit is green.

## Risks

- **Check order.** Finished before running, running before `pend_throw`,
  `pend_throw` before the just-started `TypeError`. A different order
  fails `gen_pend` or `gen_send` in a way that looks like an off-by-one
  in the stack.
- **`pc` saved by `yield from`.** Saving the address after the opcode
  runs the following instruction twice or skips the delegation.
- **PEP 479 versus `yield from`.** A `StopIteration` from the
  sub-iterator completes the delegation. A `StopIteration` from the
  generator's own body becomes `RuntimeError`.
- **The running bit during delegation.** Clearing it before the
  sub-iterator returns lets the body resume itself.
- **Snapshot before the frame is reused.** An escaping exception that
  pops the frame without setting `pc` to 0 leaves a generator that can
  be resumed into a dead stack.
- **GC of the tail.** Header integers tagged as pointers, or a scanner
  that walks only known fixed sizes, collects a local that the next
  `yield` still needs. `gen_gc` is the test.
- **Spill of header word 14.** Forgetting to fill it on an ordinary
  call drops a nested generator's identity, or leaves `X` on a normal
  frame so a stray path thinks it is a generator.
- **`mpyc`.** Landing the programs without `mpyc = false` turns
  `make test` red for a compiler that is supposed to reject `yield`.
