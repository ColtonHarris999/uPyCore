**matches**

Reviewed `48ed7c4` (oracle cases) on top of `a55dfdc` (resume from `FOR_ITER` and simple `YIELD_FROM` in `upycore/rtl/mpy_core.sv`). No RTL was changed for this review.

`FOR_ITER` of an `OB_GENERATOR` enters `S_GR0` with send `None` and throw `None`. `YIELD_FROM` enters `S_GR0` only when `inj` is `None`, the send value is `None`, and the child is an `OB_GENERATOR`. `FF_YFAST` (`fflags` `8'h04`) marks that parent so the yielded value, the return value, and an escaping exception come back without a `_yfrom` tuple. `throw`, `close`, `send` of a non-`None`, and any other child still call `_yfrom`. There is no new object kind and no new continuation id: `ABI_OB_GENERATOR` is still 6, `ABI_CONT_FOR_NEXT` is still 12, and `ABI_CONT_YFROM` is still 16.

## Suite

```
hw_tests: 26 test(s), 4 job(s), compiler mpy-cross
  generators    26 passed    0 failed
hw_tests: 26 of 26 passed in 3s
```

```
hw_tests: 0 of 26 passed, 26 skipped
```

Every generators entry printed `SKIP ... mpyc = false`. `upycore/programs/hw_tests.toml` sets `mpyc = false` on all 26.

```
compiler_suite: 369 file(s), 367 byte-exact, 2 float spelling, 0 differ, 0 rejected by both
```

```
mpy-abi: ok
```

```
hw_tests: 131 test(s), 4 job(s), compiler mpy-cross
  calls         41 passed    0 failed  2 known
  exceptions    29 passed    0 failed
  gc            59 passed    0 failed
hw_tests: 129 of 131 passed, 2 failed as expected in 131s
```

Every command exited 0. The two known `calls` failures are still the TypeError text xfails:

`bad_argc` device stdout is `TypeError` / `('function missing required positional argument #1',)`. The oracle golden is `TypeError` / `('function takes 2 positional arguments but 1 were given',)`.

`default_arg_argc_trap` device stdout is `TypeError` / `('function missing required positional argument #0',)`. The oracle golden is `TypeError` / `('function takes 1 positional arguments but 0 were given',)`.

Stderr is empty and the exit status is 0 on both sides. That is the same text mismatch the xfail strings describe.

## Extra programs

`python3 upycore/tools/mpy_build.py oracle` and `python3 upycore/tools/mpy_build.py run -v`. Oracle stderr was empty and the exit status was 0. Device exit status was 0. Stdout matched. These are not under `upycore/programs/`.

### 1. `send(None)` on a fresh generator, then `throw` of a `StopIteration` subclass, then `next`, then `for` over a second fresh generator

```python
class MyStop(StopIteration):
    pass


def show(label, fn):
    try:
        print(label, fn())
    except StopIteration as exc:
        print(label, type(exc).__name__, exc, exc.value)
    except BaseException as exc:
        print(label, type(exc).__name__, exc)


def gen():
    x = yield 1
    print("x", x)
    yield 2


g = gen()
show("send", lambda: g.send(None))
show("throw", lambda: g.throw(MyStop("z")))
show("next", lambda: next(g))

seen = []
for v in gen():
    seen.append(v)
print("for", seen)
```

Oracle stdout:

```
send 1
throw RuntimeError generator raised StopIteration
next StopIteration  None
x None
for [1, 2]
```

Oracle stderr: empty.

Device stdout:

```
send 1
throw RuntimeError generator raised StopIteration
next StopIteration  None
x None
for [1, 2]
```

Device stderr:

```
[CLEAN value=0x0 cycles=128220 ops=3841 gc=0]
```

### 2. `yield from` a generator that `yield from`s a third, `send(2)` and `close` from the outside, `finally` on the middle

```python
def show(label, fn):
    try:
        print(label, fn())
    except StopIteration as exc:
        print(label, type(exc).__name__, exc, exc.value)
    except BaseException as exc:
        print(label, type(exc).__name__, exc)


def inner():
    x = yield 1
    print("inner", x)
    yield 3


def mid():
    try:
        v = yield from inner()
        print("mid", v)
    finally:
        print("mid-fin")


def outer():
    yield from mid()


g = outer()
show("n", lambda: next(g))
show("s", lambda: g.send(2))
show("c", g.close)
```

Oracle stdout:

```
n 1
inner 2
s 3
mid-fin
c None
```

Oracle stderr: empty.

Device stdout:

```
n 1
inner 2
s 3
mid-fin
c None
```

Device stderr:

```
[CLEAN value=0x0 cycles=72259 ops=1790 gc=0]
```

### 3. `gc.collect` while suspended inside `yield from`, only reference to a list is the innermost local

`deep` allocates garbage that the collection reclaims before the next resume. After one more `next`, the generator is dropped and collected again.

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
    yield only[0]
    yield only[39]


def mid():
    yield from inner()


def outer():
    yield from mid()


def suspend():
    g = outer()
    print("a", next(g))
    print("deep", deep(36, 0))
    gc.collect()
    print("b", next(g))
    return g


def managed_entry():
    g = suspend()
    gc.collect()
    held = gc.mem_free()
    g = None
    gc.collect()
    print("freed", gc.mem_free() > held)


try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
```

Oracle stdout:

```
a 0
deep 72
b 39
freed True
None
```

Oracle stderr: empty.

Device stdout:

```
a 0
deep 72
b 39
freed True
None
```

Device stderr:

```
[CLEAN value=0x0 cycles=188021 ops=3511 gc=3]
```

## Checks

- `FOR_ITER` still honors finished, then running, then `pend_throw`. `gen_for_pend`, `gen_for_self`, and `gen_for_return` passed. A finished generator with `pend_throw(ValueError("later"))` then `for` prints `for-done` and does not inject the pending exception, on both sides.
- A `for` over a generator that `return`s a value does not leak that value. `gen_for_return` prints `for [1]` and `after StopIteration  None`. `tuple` of the same shape prints `tup (1,)`.
- A body `raise StopIteration` during `for` is `RuntimeError: generator raised StopIteration`, including the first resume. `gen_for_raise_stop` prints that for both `body` and `imm`.
- `yield from` of a list and of a range still yields every item (`gen_yield_from_range`: `list [1, 2, 3]`, `range [0, 1, 2]`). `send(1)` through `yield from` of a generator still reaches the inner yield (`gen_yield_from_send`: `got 1`, `s 1`).
- A `finally` around `yield from` runs when the child raises on `next`. `gen_yield_from_finally` prints `fin` then `n ValueError boom`. A child `raise StopIteration(9)` on the second resume, and a child `raise StopIteration(4)` on the first resume, also run the `finally` and then report `RuntimeError: generator raised StopIteration`.
- A user iterator's `__next__` is still called from `for` and from `yield from`. `gen_user_next` prints `call` before each value on both paths.
- `tuple` and `set` of a generator expression match the oracle. `gen_genexp_collect` prints `tup (0, 1, 2, 3)` and `set [0, 1, 2, 3]`.
- The outer generator stays running while the child runs. A child that `next`s the outer during `yield from` prints `re ValueError generator already executing` and then the outer `for` prints `saw 7`, on both sides.
- `FF_YFAST` is clear when `throw` or `close` enters `YIELD_FROM`. `gen_yield_from_throw` passed: `throw` of `ValueError` is caught in the child, `close` runs both `finally`s, a child that yields out of `GeneratorExit` becomes `RuntimeError: generator ignored GeneratorExit`, and a child that returns out of `GeneratorExit` re-raises it in the parent.
- `mpyc = false` on every generators entry. `compiler_suite.py` exited 0. `mpy_abi.py --check` exited 0. The diff adds `FF_YFAST` and the states `S_FI_GK` and `S_YF_K`. It does not add an object kind or a continuation id.

No findings.

## Style

- The non-generator `_yfrom` hook arguments are written twice: the `else` of opcode `8'h68`, and the `else` of `S_YF_K`.
- `S_GN_RET3` stores `8'h4b` into `op` so a bare `StopIteration` takes the `FOR_ITER` arm of `S_RAISE`. `aux` still holds the loop exit, which is why the return value is not built into the exception.
- `FF_YFAST` is a bit in the spilled `fflags` byte. Each early exit from `S_GR2`, `S_GR3`, and `S_GR6` clears it before raising, and `S_GN_ESC5` clears it before the parent sees the exception.
