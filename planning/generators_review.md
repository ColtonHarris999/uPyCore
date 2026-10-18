**does not match**

Reviewed `05ba2b9` (Implement yield from on the generator resume path) against `planning/generators_plan.md` and the unix oracle (MicroPython v1.29.0, the `variants/upycore` port).

## Suite

```
hw_tests: 15 test(s), 4 job(s), compiler mpy-cross
  generators    15 passed    0 failed
hw_tests: 15 of 15 passed in 2s
```

```
SKIP  generators/gen_yield  mpyc = false
SKIP  generators/gen_send  mpyc = false
SKIP  generators/gen_return  mpyc = false
SKIP  generators/gen_throw  mpyc = false
SKIP  generators/gen_close  mpyc = false
SKIP  generators/gen_pend  mpyc = false
SKIP  generators/gen_state  mpyc = false
SKIP  generators/gen_repr  mpyc = false
SKIP  generators/gen_gc  mpyc = false
SKIP  generators/gen_yield_from  mpyc = false
SKIP  generators/gen_yield_from_iter  mpyc = false
SKIP  generators/gen_yield_from_throw  mpyc = false
SKIP  generators/gen_async  mpyc = false
SKIP  generators/gen_with  mpyc = false
SKIP  generators/gen_trace  mpyc = false
hw_tests: 0 of 15 passed, 15 skipped
```

```
compiler_suite: 369 file(s), 367 byte-exact, 2 float spelling, 0 differ, 0 rejected by both
```

```
mpy-abi: ok
```

```
  calls         41 passed    0 failed  2 known
hw_tests: 41 of 43 passed, 2 failed as expected in 3s
```

```
  exceptions    29 passed    0 failed
hw_tests: 29 of 29 passed in 2s
```

```
  objects       28 passed    0 failed
hw_tests: 28 of 28 passed in 2s
```

```
  gc            59 passed    0 failed
hw_tests: 59 of 59 passed in 125s
```

```
  containers    58 passed    0 failed
hw_tests: 58 of 58 passed in 4s
```

```
  builtins      40 passed    0 failed  2 known
hw_tests: 40 of 42 passed, 2 failed as expected in 3s
```

Every command exited 0. The two known failures in `calls` and the two in `builtins` are the xfail markers already on `main` (`bad_argc`, `default_arg_argc_trap`, `builtin_ord_type_trap`, `builtin_chr_range_trap`). This branch does not add an xfail.

## Extra programs

Run with `python3 upycore/tools/mpy_build.py oracle` and `python3 upycore/tools/mpy_build.py run`. Stderr was empty and the exit status was 0 on both sides. These three matched, so they are not under `upycore/programs/hw/generators/`.

### 1. `send(None)` on a fresh generator, then `throw` of a `StopIteration` subclass, then `next`

```python
def show(label, fn):
    try:
        print(label, fn())
    except StopIteration as exc:
        print(label, type(exc).__name__, exc, exc.value)
    except BaseException as exc:
        print(label, type(exc).__name__, exc)


class MyStop(StopIteration):
    pass


def body():
    yield "first"
    yield "second"


g = body()
print("send-none", g.send(None))
show("throw-sub", lambda: g.throw(MyStop(9)))
show("next", lambda: next(g))
```

Oracle and device:

```
send-none first
throw-sub RuntimeError generator raised StopIteration
next StopIteration  None
```

### 2. `yield from` a generator that `yield from`s a third, with `send` and `close`

```python
def show(label, fn):
    try:
        print(label, fn())
    except StopIteration as exc:
        print(label, type(exc).__name__, exc, exc.value)
    except BaseException as exc:
        print(label, type(exc).__name__, exc)


def inner():
    try:
        x = yield "i"
        yield x
    finally:
        print("inner-fin")


def mid():
    try:
        yield from inner()
    finally:
        print("mid-fin")


def outer():
    try:
        yield from mid()
    finally:
        print("outer-fin")


g = outer()
print("a", g.send(None))
print("b", g.send("s"))
show("close", g.close)
show("after", lambda: next(g))
```

Oracle and device:

```
a i
b s
inner-fin
mid-fin
outer-fin
close None
after StopIteration  None
```

### 3. `gc.collect` while suspended inside `yield from`, only reference to a list is the innermost local

```python
import gc


def deep(n, acc):
    a = [n, acc]
    b = (n, a)
    if n == 0:
        return acc
    return deep(n - 1, acc + len(b))


def inner():
    only = list(range(40))
    yield 0
    yield only[0]
    yield only[39]
    yield len(only)


def mid():
    yield from inner()


def outer():
    yield from mid()


def managed():
    g = outer()
    print("suspend", next(g))
    print("deep", deep(36, 0))
    gc.collect()
    print("survived", next(g), next(g), next(g))
    return g


g = managed()
gc.collect()
held = gc.mem_free()
g = None
gc.collect()
print("freed", gc.mem_free() > held)
```

Oracle and device:

```
suspend 0
deep 72
survived 0 39 40
freed True
```

## Checks

- Resume order is finished, then running, then `pend_throw`, then the just-started `TypeError`. `gen_pend` prints `early-send TypeError ...` and `early-next ValueError kept`, and `gen_send` prints `early TypeError ...` then `still started`.
- A finished generator's later `next` is `StopIteration` with `.value is None`, including after `return 5` (`gen_return` `again`) and after the subclass throw in extra program 1.
- `send(1)` on a fresh generator raises the `TypeError` and the following `next` still runs the body (`gen_send` `still started`).
- `close` swallows `GeneratorExit` and a normal return, raises `RuntimeError: generator ignored GeneratorExit` when the body yields, and propagates any other exception (`gen_close`, `gen_yield_from_throw`). `throw(GeneratorExit)` on a generator suspended at `yield` propagates `GeneratorExit`, and the following `next` is `StopIteration` with `.value is None`.
- `FR_GEN` is cleared in `S_CF_SW` and spilled and filled as header word 14. `calls` and `exceptions` passed.
- `OB` in `upycore/tools/mpy_abi.py` matches the plan's groups. `NOTIMPL` is 18, the last kind. `NotImplementedType` is the last type before `BaseException`. `generator` sits with `function` in `TYPES`. `OB_ITEROBJ` is kind 16 in that table. `upycore/firmware/base.py` has no stray `OB_ITEROBJ` const. `mpy_abi.py --check` passed.
- `yield from` saves `pc` as the opcode byte (`S_YF_V` assigns `op_pc` before suspend). After a normal finish the next instruction runs once: `gen_yield_from` prints `returned 5` once, and extra program 2 forwards one `send` and one `close`.
- `StopIteration` raised by a sub-iterator's `__next__` completes `yield from`. A custom iterator raising `StopIteration(7)`, `StopIteration()`, `StopIteration(1, 2)`, or a `StopIteration` subclass instance produced `val 7`, `empty None`, `multi 1`, and `subinst 8` on both sides, and the following yield ran once. `StopIteration` raised by the outer body is `RuntimeError: generator raised StopIteration` (`gen_state` `pep`), and the following `next` does not run the body.
- The outer running bit stays set during delegation. A sub-generator that `next`s the outer prints `caught generator already executing` and then yields `2`, on both sides.
- An escaping exception sets `pc` to 0 before the caller is filled. After `gen_state`'s `pep` line, `pep-after` is `StopIteration` with `.value is None`.
- `gen_gc` passed, and extra program 3 kept the innermost list (`survived 0 39 40`) then freed it. The header is six words (`OBJ_WORDS["GENERATOR"]` is 6). Word 5 is a `CONT` pointer. The collector follows `CONT` the way it follows any pointer tag, then scans the frame block.
- `gen_repr` passed. The golden is `<generator object 'named' at f7b5e180>`, and `fmt.py` prints that shape with no `0x`.
- Every generators manifest entry sets `mpyc = false`. `compiler_suite.py` skips those entries and exited 0. `--compiler mpyc --area generators` skipped all 15 and exited 0. No `uasyncio` module is frozen under `upycore/`.
- `planning/generators_plan.md` is still the plan, status **not started**, and it was not archived. The yield commit corrected two oracle details in it (a just-started `TypeError` leaves `pend_throw` in place, and the repr has no `0x`). The code follows that text.

## Finding

Throwing the `StopIteration` class, or a subclass of it, through `yield from` into an iterator with no `throw` method completes the delegation on the device. The oracle raises `RuntimeError: generator raised StopIteration` and does not run the statements after `yield from`.

The plan says a missing `throw` / `close` propagates the exception, and `StopIteration` in that position becomes `RuntimeError: generator raised StopIteration`. `mp_resume` decides that with `mp_obj_exception_match`, which is true for the class. `_yfrom` in `upycore/firmware/iters.py` uses `isinstance(throw, StopIteration)`, which is false for the class, then instantiates it and raises the instance. `S_YF_SI` then treats that `StopIteration` as completion.

The same class thrown at a plain `yield`, or through `yield from` of a generator, is `RuntimeError` on both sides. An instance (`throw(StopIteration(4))` or `throw(MyStop(4))`) through `yield from` of a list is `RuntimeError` on both sides. `throw(GeneratorExit)` the class, through `yield from` of a list, propagates `GeneratorExit` on both sides.

Program: `upycore/programs/hw/generators/gen_yield_from_stop_type.py`

```python
def show(label, fn):
    try:
        print(label, fn())
    except StopIteration as exc:
        print(label, type(exc).__name__, exc, exc.value)
    except BaseException as exc:
        print(label, type(exc).__name__, exc)


class MyStop(StopIteration):
    pass


def from_list():
    yield from [1, 2]
    print("after")
    return 3


g = from_list()
print("y", next(g))
show("throw", lambda: g.throw(StopIteration))
show("next", lambda: next(g))

g = from_list()
print("y2", next(g))
show("sub", lambda: g.throw(MyStop))
show("next2", lambda: next(g))
```

Oracle (stderr empty, exit 0):

```
y 1
throw RuntimeError generator raised StopIteration
next StopIteration  None
y2 1
sub RuntimeError generator raised StopIteration
next2 StopIteration  None
```

Device (stderr empty, exit 0):

```
y 1
after
throw StopIteration 3 3
next StopIteration  None
y2 1
after
sub StopIteration 3 3
next2 StopIteration  None
```

Cause: `_yfrom` does not treat a `StopIteration` class as `StopIteration`, so the missing-method path raises an instance and the yield-from opcode completes. File: `upycore/firmware/iters.py`.

## Style

- `upycore/tools/mpy_link.py` has empty `if` bodies on opcodes `0x67` and `0x68`. The comments say the core executes them. They do not change the link.
