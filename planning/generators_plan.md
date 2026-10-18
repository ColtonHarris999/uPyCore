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

The suspended copy is a frame block hung off a fixed generator object,
the same shape as a list header and its item array. While the body runs
it occupies one ordinary frame, the same as any other call. On `yield`,
return, or an exception that escapes the body, the hart writes the
registers back to the frame block and fills the caller. Nested calls
the body makes use the existing spill. They do not write the block.
The block is updated only when the generator stops being the live frame.

Creation reuses the binder. `S_CF_CHK` stops raising on the flag. The
call still spills the caller, installs a frame, and runs `S_BF` / `S_BS`
/ `S_CELLS`. Argument errors propagate and no object is returned. After
the cells exist, `pc` is the first opcode and `sp` is 0. Allocate the
header and the frame block, copy the frame into the block, fill the
caller, and deliver the header. Do not fetch.

### Where it sits in the tables

Object kinds, type ids, and the frame header are one table each.
`upycore/tools/mpy_abi.py` is the source. Regenerate with
`python3 upycore/tools/mpy_abi.py --sv`. Do not hand-edit
`upycore/rtl/mpy_abi.svh` or `upycore/firmware/_abi.py`. Kind numbers
are internal. Call sites use the names. Rewrite the lists below in
full so the groups stay dense. `NOTIMPL` stays the last object kind.
`NotImplementedType` stays the last type before the exceptions.

`OB_ITEROBJ` is kind 20 today, declared as a stray `const` in
`upycore/firmware/base.py`, past `NOTIMPL`. That is the same hole this
change has to close. Move it into `OB` and delete the stray const.

```python
OB = {
    # Instances.
    "INSTANCE": 1,
    "TYPE": 2,
    "EXCEPTION": 3,
    # Code. A generator is the suspended frame of a function.
    "CELL": 4,
    "FUNCTION": 5,
    "GENERATOR": 6,
    "BOUND_METHOD": 7,
    "BUILTIN": 8,
    # Namespaces and descriptors.
    "MODULE": 9,
    "SUPER": 10,
    "PROPERTY": 11,
    "STATICMETHOD": 12,
    "CLASSMETHOD": 13,
    # Views and the iterator objects firmware builds
    # (enumerate, zip, map, filter, reversed, str iterators).
    "SLICE": 14,
    "DICT_VIEW": 15,
    "ITEROBJ": 16,
    # Singletons. A new kind is inserted above this pair.
    "ELLIPSIS": 17,
    "NOTIMPL": 18,
}
```

`OBJ_WORDS["GENERATOR"]` is 6, the same kind of fixed header every
other object has. The frame image is a second allocation, the way a
list's items are a second allocation. It is not a tail hanging off
the header.

The non-exception prefix of `TYPES` becomes:

```text
object, type,
NoneType, bool, int, float, complex,
str, bytes, bytearray,
tuple, list, dict, set, frozenset,
range, slice,
iterator, enumerate, zip, map, filter, reversed,
function, generator, bound_method, builtin_function,
closure, cell,
module,
property, staticmethod, classmethod,
dict_view, super,
ellipsis, NotImplementedType
```

The exception names stay in their current order after that.
`generator` stays out of `PUBLIC_TYPES`. Nothing constructs it except
a call of a generator function. `FIRST_EXC_TYPE` follows the new
index. `_gresume` goes in `NATIVES` immediately after `_inext`.
`_yfrom` goes in `HOOKS` immediately after `_getiter`. The four oracle
messages go in `MSGS` immediately after `STOP_ITER`.

### Object layout

| Word | Contents |
| --- | --- |
| 0 | `OB_GENERATOR` |
| 1 | the `generator` type |
| 2 | the function object |
| 3 | status integer. Bit 0 set means running. Clear otherwise |
| 4 | `pend_exc`. `None`, or the exception `pend_throw` stored |
| 5 | the frame image, a `CONT` pointer |

The image is `FRAME_HDR_WORDS + n_state + FRAME_EXC_WORDS * n_exc_stack`
tagged words. The linker already refuses `n_state > 64` and
`n_exc_stack > 16`, so the copy fits the register file and the
exception arrays. Its header is the `FR` record. Its state words are
the register file. Its exception records are the three-word blocks the
spill already writes.

`FR["GEN"]` is header word 14. It holds this generator object, or
`VNULL` on an ordinary frame. `FRAME_HDR_WORDS` stays 16, so the state
still starts at byte 64. Word 15 stays unused. Extend spill and fill
through `FR_GEN`. Initialize the register at reset and in `S_CF_SW`.

Saved `pc == 0` means finished. Flash code is never at address 0. Set
that word when the body returns or an exception escapes. A later resume
does not run the body again.

Counts and saved program counters in the image are `INT` or `CONTROL`.
Python values keep their tags. The collector follows word 5 the way it
follows a list's item pointer, then the tagged words of that block.
Add the generator row to the kind table in `upycore/docs/mpy_gc.md`
with these six fields, and name the frame block next to the list item
array. A local lives because it is a tagged word in that block.

`pend_throw` is firmware over words 3 and 4 (`_ld` / `_st`). If word 3
bit 0 is set, raise `ValueError: generator already executing`. Otherwise
store the new exception and return the previous word 4. Match
`gen_instance_pend_throw`: a finished generator still accepts the store.
The next resume notices `pc == 0` first and raises `StopIteration`
without injecting the pending exception. The repr case in
`upycore/firmware/fmt.py` sits with the `OB_FUNCTION` case.

### Resume

One native, `_gresume(gen, send, throw)`, implements
`mp_obj_gen_resume`. It sits next to `_inext`. Firmware methods on the
type are thin wrappers.
The linker binds `generator____next__`, `generator__send`,
`generator__throw`, and `generator__close` the same way it binds
`enumerate____next__`.

Check order, which is the oracle's order:

1. `pc == 0`: finished. The native raises `StopIteration`. The value is
   `None`. The original `return` value is not raised again.
2. Status bit 0 set: `ValueError: generator already executing`.
3. If word 4 is not `None`, that object is the throw value for this
   attempt. Leave word 4 in place until execution actually starts.
4. `sp == 0` and `send` is not `None`: the `TypeError` above. Do not set
   the running bit, do not move `pc`, and do not clear word 4. `gen_pend`
   does this: `pend_throw` then `send(1)` raises, and the following
   `next` still injects the pending exception. A later `next` with no
   pending exception still starts the body.
5. Otherwise, if `sp != 0`, store `send` at the top of the value stack.
   `YIELD_VALUE` has stack effect 0 in `upycore/targets/upycore.json`.
   The yielded value is still sitting there. Resume replaces it. The
   next opcode (`STORE_FAST`, `POP_TOP`, or another use) sees the sent
   value. With `MICROPY_PY_GENERATOR_PEND_THROW`, the snapshot taken at
   yield stores `None` in that slot after the yielded value has been
   captured. The next resume overwrites it.
6. Clear word 4, then set the running bit. Spill the caller, install the
   image as the live frame, set `FR_GEN` to the object.
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
        _gresume(self, None, GeneratorExit())
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

- A generator object goes through `_gresume`.
- Anything else with `send is None` and no throw uses the iterator
  protocol (`__next__`, or the native `ITER` step the `for` loop uses).
- A non-`None` send with no throw loads `send` and calls it.
- `GeneratorExit` loads `close` if it exists and treats a return as
  completion. A missing `close` propagates the exception.
- Any other throw loads `throw` if it exists.
- A missing `throw` / `close` propagates the exception.
  `StopIteration` in that position becomes
  `RuntimeError: generator raised StopIteration`.

Implement that policy once, as the `_yfrom` hook next to `_getiter`,
and call it from the opcode the way `GET_ITER` calls `_getiter`. The generator
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
`<generator object 'name' at f7b5e180>`. There is no `0x`. The name is
the raw code's simple name, the same string `_rc_name` uses for
functions. The address is the object's address in hex. The hardware
runner masks both `at 0x...` and a bare 8-digit hex address after `at`.

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
| `upycore/tools/mpy_abi.py` | Rewritten `OB` and the `TYPES` prefix, `FR_GEN`, `_gresume`, `_yfrom`, messages |
| `upycore/firmware/iters.py` | `__next__`, `send`, `throw`, `close`, the `_yfrom` hook. `OB_ITEROBJ` comes from the ABI |
| `upycore/firmware/fmt.py` | repr |
| `upycore/firmware/base.py` | Delete the stray `OB_ITEROBJ` const |
| `upycore/firmware/errors.py` | The old `ERR_GENERATOR` text remains the guard for a `yield` in a frame whose `FR_GEN` is `VNULL` |
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
  `pend_throw` before the just-started `TypeError`. The pending
  exception is cleared only when the body actually starts. Clearing it
  on the `TypeError` path makes `gen_pend`'s `early-next` line run the
  body instead of raising `ValueError kept`.
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
- **The frame block.** The header is six words. Locals live in the
  block word 5 points at. A scanner that follows the header and stops,
  or a pointer tagged as an integer, collects a local the next `yield`
  still needs. `gen_gc` is the test.
- **Spill of `FR_GEN`.** Forgetting to fill it on an ordinary call
  drops a nested generator's identity, or leaves a stale value on a
  normal frame so a stray path thinks it is a generator.
- **`mpyc`.** Landing the programs without `mpyc = false` turns
  `make test` red for a compiler that is supposed to reject `yield`.
