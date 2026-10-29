# Bytecode completion decisions (proposal C)

The other writeups on this branch are `planning/ubytecode_eval.md` and
`planning/ubytecode_eval_b.md`. This one uses the same pin.

Pin: MicroPython **v1.29.0** (`0fd6c573`). The oracle is the unix port
with `variants/upycore`: ROM level extra features, so
`MICROPY_CPYTHON_COMPAT`, `MICROPY_MODULE_GETATTR`,
`MICROPY_MODULE___ALL__`, `MICROPY_ENABLE_EXTERNAL_IMPORT`, and
`MICROPY_CAN_OVERRIDE_BUILTINS` are on, and `str` is Unicode. "Full"
means the same value, or the same exception type and message, as that
oracle. A core fast path plus its firmware hook is full when the hook
covers the rest.

`upycore/rtl/mpy_decode.sv` accepts every opcode in `py/bc0.h`.
Execution is `upycore/rtl/mpy_core.sv`. Hooks are `HOOKS` in
`upycore/tools/mpy_abi.py`. Each multi-opcode window is one row.

This proposal disagrees with `planning/ubytecode_eval.md` on stepped
slice stores. `py/objlist.c` `list_subscr` calls
`mp_seq_get_fast_slice_indexes`, which returns true only when
`step == 1`, and otherwise raises `NotImplementedError`. Tuple, `str`,
`bytes`, and `bytearray` do the same on a load. The work is the
message and the Unicode bounds, not an assignment the pin refuses.

## Decisions

| Opcode | Decision | What is still short |
| --- | --- | --- |
| `IMPORT_NAME` | Approve | Relative import, failed-body rollback, `usys`, `builtins`, override dict |
| `IMPORT_FROM` | Approve | Same load as `LOAD_ATTR`, then a package submodule |
| `IMPORT_STAR` | Approve | `__all__` |
| `LOAD_ATTR`, `LOAD_METHOD` | Approve | Module `__dict__` and module `__getattr__`; depth-first MRO |
| `LOAD_SUPER_METHOD`, `LOAD_BUILD_CLASS` | Approve | Same depth-first order |
| `LOAD_SUBSCR` | Approve | Non-ASCII `str` bounds; stepped `str` / `tuple` / `bytes` must raise |
| `STORE_SUBSCR` | Approve | The pin's `NotImplementedError` text. Do not assign a stepped slice |
| `SETUP_WITH` | Approve | A property `__enter__` / `__exit__` is reported missing |
| `WITH_CLEANUP` | Approve | An undecided `__exit__` result is treated as true |
| `BINARY_OP` `==` / `!=` | Approve | `c == c` is true for a complex NaN |
| `BINARY_OP` `**` / `**=` | Approve | Negative base, non-integral exponent, after a repr check |
| `GET_ITER`, `GET_ITER_STACK` | Approve | A class with `__getitem__` and no `__iter__` is not iterable |
| `RAISE_FROM` | Leave | Warn, then raise. The pin does not chain |
| `CALL_*_VAR_KW` | Leave | Argument-buffer ceiling |
| Every other named opcode | Leave | No remaining divergence from the pin |

Land imports first. The three opcodes share one loader.

## Approved

### `GET_ITER` (`0x5e`) and `GET_ITER_STACK` (`0x5f`)

`_getiter` in `upycore/firmware/iters.py` handles the built-in
containers, then `__iter__`, then an object that already has
`__next__`. `mp_getiter` in `py/runtime.c` does one more thing: if
`__iter__` is missing and `__getitem__` is present, it returns the
iterator from `py/objgetitemiter.c`. That iterator calls
`__getitem__` with 0, 1, 2, ... and turns `IndexError` or
`StopIteration` into the end of iteration. Any other exception
propagates. A class that is only subscriptable is iterable on the
oracle and a `TypeError` here. `S_GI` already falls through to this
hook when the type has no `__iter__`.

**How.** After the `__iter__` / `__next__` checks, load `__getitem__`.
If it exists, return an `OB_ITEROBJ` whose `__next__` calls it with the
stored index and then increments that index. Catch `IndexError` and
`StopIteration` and raise `StopIteration`. `FOR_ITER` already ends the
loop on that exception. Do not build a second iterator in the core.

### `IMPORT_NAME` (`0x1b`)

`S_QOP` already calls `_import(name, fromlist, level, globals)` in
`upycore/firmware/modules.py`. The stack is level, then fromlist, which
is the pin's order. Keep that call.

`_rel_name` prefers `__package__`, which nothing sets, then pops
`level` components. `from .sub import x` inside a package `__init__`
(`__name__ == 'pkg'`, `__path__` set) becomes the top-level name
`sub`. `from ..other import x` inside `pkg.mod` becomes a top-level
import of `other`. The non-package case `from .b import value` in
`pkg.mod` happens to match, which is why `use_rel.py` passes.
`_load_mod` inserts into `sys.modules` and then runs the body, so a
raised body stays cached. It never looks at `sys.path`, and it tries
native modules before frozen ones.

The variant turns the VFS off. There is no host directory to stat.
`sys.path` is `['.', '.frozen']`, and both of those roots are the
linker's `_FROZEN` table. Any other root is a miss. That is this
device's `mp_import_stat`.

**How.** Rewrite `_import`, `_rel_name`, and `_load_mod`. Leave the
hook signature alone.

1. The builtins dict is ROM (`emit_dict` defaults `rom=True`), so a
   store raises today. On the first store into that dict, copy it to a
   mutable override and write there. Later loads check the override
   first. `IMPORT_NAME` calls `builtins.__import__` from that map when
   the entry is not the firmware function, as
   `(name, globals, None, fromlist, level)`. The firmware function
   stays the default and keeps calling `_import`, so the default path
   does not recurse. Change the builtin default to `fromlist=None`.
   An omitted fromlist is `None` in the pin; `()` is a real fromlist
   and returns the leaf.
2. `level < 0` raises `ValueError` with no message. A positive level
   follows `evaluate_relative_import`: read `__name__`; if it is
   `__main__` and the dict also has `__main__`, use that; if `__path__`
   is present, subtract one from the level first; walk back that many
   dots; running off the front raises
   `ImportError: can't perform relative import`. An empty tail keeps
   the chopped package name. An empty absolute name raises `ValueError`.
3. Walk the dotted name. Unless `sys.path` is empty, a `sys.modules`
   hit returns immediately. A top-level component checks non-extensible
   builtins before the path: `sys`, `gc`, `micropython`, `usys` (the
   same object as `sys`), and `builtins` (a module whose globals dict
   is the builtins dict, not a copy). Then each `sys.path` entry.
   `'.'` and `'.frozen'` look up `_FROZEN` by the full dotted name; a
   descriptor with `_MD_FLAG_PACKAGE` is a package. Any other root
   misses. After the path, try `_NATIVE_MODULES`. A leading `u` that
   missed as a non-extensible name retries the remainder against that
   native map (`uarray` forces `array`).
4. Publish the module in `sys.modules` before the body. If the body
   raises, delete the name this import inserted and leave a name that
   was already there. Attach the submodule to its parent only after
   the body returns. Set `__name__` to the dotted name and `__path__`
   to `root + '/' + dotted` for a package (`.frozen/pkg`). `fromlist
   is None` returns the first component. Any other fromlist returns
   the leaf. Do not walk the fromlist names; the compiler emits
   `IMPORT_FROM` for them.

Acceptance, plus the existing `use_pkg`, `use_rel`, `use_helper`, and
`import_missing` programs: `from . import sub` and
`from .sub import name` from a frozen package `__init__`; a body that
raises is absent from `sys.modules` and the next import runs it again;
`import usys` is `sys`; assigning `builtins.__import__` changes the
next import; a relative import above the top package raises
`ImportError: can't perform relative import`.

### `IMPORT_FROM` (`0x1c`)

`_import_from` reads the module globals with `_dget` and, on a miss,
imports `module.__name__ + '.' + name`. The pin's `mp_import_from`
uses the normal attribute load, so a descriptor becomes a bound
method, and it only tries a submodule when `__path__` is present.

**How.** Load the name with the module rule in the `LOAD_ATTR` section.
Return a bound method when the load produced one. On a miss with
`__path__`, call `_import` on the dotted name with fromlist `()` and
level 0, store it on the parent, and return the leaf. Otherwise raise
`ImportError: can't import name <name>` with the name unquoted.

### `IMPORT_STAR` (`0x69`)

`_import_star` copies every global whose first byte is not `_`. The
qstr `__all__` is reserved and unread. The pin loads `__all__` first.

**How.** If `__all__` loads through the module rule, require a list or
tuple and store each name with that same load (a missing name raises,
and a leading `_` is kept). A non-string item raises whatever
`mp_obj_str_get_qstr` raises on the oracle. If `__all__` is absent,
keep the current scan. Keep writing the dict the opcode already
passes. `import *` outside a module is a syntax error on this oracle,
so there is no second store path.

### `LOAD_ATTR` (`0x13`) and `LOAD_METHOD` (`0x14`): modules

`S_AT_MOD` looks only in the module globals. A miss becomes kind 0 and
`_getattr` then raises `AttributeError`. The pin, with the compat and
`MICROPY_MODULE_GETATTR` switches on, returns the globals dict for
`__dict__`, and otherwise calls the module global `__getattr__` as a
function of one argument (the name), not as a method. It does not call
that function for the name `__getattr__` itself. This device has no
`MP_REGISTER_MODULE_DELEGATION` entries.

**How.** In `_getattr`, for a module: globals hit, then `__dict__`
returns that same dict, then `__getattr__(name)` when the name is not
`__getattr__`. `LOAD_METHOD` binds whatever that returns, using the
bind it already uses for a method. `STORE_ATTR` on a module already
writes the globals and rejects a ROM dict; the override dict from
`IMPORT_NAME` is the one exception, and only for the builtins module.

Acceptance: a frozen module that defines `__getattr__` answers
`mod.missing` and `from mod import missing`, and `mod.__dict__` is the
globals dict.

### `LOAD_ATTR`, `LOAD_METHOD`, `LOAD_SUPER_METHOD` (`0x15`), `LOAD_BUILD_CLASS` (`0x54`): MRO

`_c3` in `upycore/firmware/calls.py` stores a C3 linearization.
`S_AT_MRO` and `_tlookup` walk that tuple. `_super_attr` walks it from
index 1. The pin does not. `mp_obj_class_lookup` in `py/objtype.c` is
depth-first and left to right, and the comment above it says so.
`super_attr` restarts that search at the parents of the class that was
passed, then searches `object`.

```python
class A:
    def f(self):
        return 1
class B(A):
    pass
class C(A):
    def f(self):
        return 2
class D(B, C):
    def f(self):
        return super().f()
print(D().f())
```

The pin prints `1`. C3 prints `2`. C3 also rejects `class C(A, B)`
when `B` is already a subclass of `A`. The pin accepts it.

Exception match stays as it is. Both orders contain the same bases,
and `S_ISSUB` only tests membership.

**How.** Replace `_c3` with that walk. The tuple is the new class,
then a depth-first left-to-right scan of the bases, dropping a class
already recorded, with `object` last. Do not raise on a repeated base.
Store it in the same word `_make_type` uses now. `S_AT`, `_tlookup`,
and `_super_attr` keep walking the tuple, so `super()` inside `D`
sees `B`, then `A`, then `C`, then `object`. Single inheritance order
does not change. No new core state.

### `LOAD_SUBSCR` (`0x55`)

Integer indexes of a non-ASCII `str` already use `_ustr_at`.
`_getslice` does not. It measures `_slen` (bytes) and copies one byte
per step, so `"h\u00e9llo"[1:2]` cuts the middle of U+00E9.
`slice_str_unicode` in `hw_tests.toml` is the xfail for that; the
program must print `11111`.

The pin's Unicode `str_subscr` indexes code points when the step is
`None` or 1, and raises
`NotImplementedError: only slices with step=1 (aka None) are supported`
otherwise. `objtuple.c` and `objarray.c` raise that same text for a
stepped tuple, `bytes`, or `bytearray` load. List loads with a step
are real: `list_subscr` calls `mp_seq_extract_slice` when the step is
not 1. `_getslice` already does that for lists, and it also returns a
stepped tuple, `str`, or `bytes`, which the pin rejects.

**How.** In `_getslice`:

- Non-ASCII `str`, step `None` or 1: measure with `_utf8_len`, map the
  character bounds through `_utf8_at`, and copy the byte span those
  code points cover. The result length is the byte count.
- `str`, `tuple`, `bytes`, and `bytearray` with any other step: raise
  the pin's `NotImplementedError` text above.
- List and range keep the stepped copy that is already there.
- ASCII `str` step 1 is the byte copy that is already there, because
  the indexes match.

Drop the xfail on `slice_str_unicode` in the same change. Add a
stepped `tuple` and a stepped `bytes` that expect that
`NotImplementedError`.

### `STORE_SUBSCR` (`0x56`)

`_list_setslice` and `_barr_setslice` raise
`NotImplementedError: extended slice assignment` when the step is not
1. The pin also refuses the store. It does not write the elements.
`list_subscr` raises `NotImplementedError` with no message.
`array_subscr` raises
`NotImplementedError: only slices with step=1 (aka None) are supported`.
A null value is a delete, and the list path treats that as assigning
an empty sequence before the same step check.

**How.** Keep the step-1 resize path. For any other step, raise
`NotImplementedError()` with no argument on a list, and the bytearray
sentence above on a bytearray. Do not grow, shrink, or overwrite the
stepped indexes. `str` and `tuple` stay `TypeError` on item
assignment.

### `SETUP_WITH` (`0x47`)

`S_SW_X` accepts attribute kinds 1 (value) and 2 (method). Kind 3 is a
property, staticmethod, classmethod, or other descriptor (`S_AT_VK`).
That kind takes the `else` and raises `AttributeError`, so a context
manager whose `__enter__` or `__exit__` is a property never runs. The
pin's `mp_load_method` resolves the descriptor.

**How.** On kind 3, call `ABI_HOOK_GETATTR`, which already runs
`_desc_get`. On return, continue at `S_SW_E` with the resolved
callable in the same place a kind-1 result occupies. Kind 0 stays a
miss and still raises `AttributeError`. Do not treat kind 3 as a miss.

### `WITH_CLEANUP` (`0x5c`)

`S_WC_TR` pushes `None` when `tr_x` is set:

```text
push((tr_x || tr_r) ? VNONE : aux)
```

`tr_x` means `S_TR` could not decide. `0j` is false in the oracle, and
a `__bool__` that returns `False` must not swallow. `S_JT` already
calls `ABI_HOOK_TRUTH` for this case. Reusing `ABI_CONT_TRUTH` would
re-fetch the opcode.

**How.** Add a continuation used only here. When `tr_x` is clear, keep
the current choice (`None` when `tr_r`, otherwise the saved exception
in `aux`). When `tr_x` is set, call `_truth` and push `None` only when
the hook returns `True`. `_truth` already reduces `__bool__` and
`__len__`.

Acceptance: `__exit__` returning `0j`, `0`, or a `__bool__` of `False`
does not swallow; `True` or `1` does. A property `__enter__` runs.

### `BINARY_OP` equality (`0xd7` + 2 and `0xd7` + 5)

Two complexes are not `numlike`, so they take `S_EQ`. The first test
there treats equal words as equal for every tag other than `OBJECT`.
A complex is its own object, so `c == c` is reported true. The pin
compares the parts, and a NaN part makes it false. `_equal` already
refuses that identity shortcut for `TAG_COMPLEX`. Floats do not use
it: two floats are `numlike` and go to the ALU first.

**How.** In `S_EQ`, send `TAG_COMPLEX` to `S_BIN_FB`.

### `BINARY_OP` power (`0xd7` + 21 and `0xd7` + 34)

The ALU handles the powers it accepts. A negative base with a
non-integral exponent is a complex result. `S_NUM_W` sends it to
`_binop`, and `_num_binop` calls `_cpow`. `_cpow` is the pin's
`exp(z * ln(z))` formula, but `_flog`, `_fexp`, `_fatan2`, `_fcos`,
and `_fsin` are the short series in `floatfmt.py`, commented as
accurate enough for the tests that print them. In-place power already
falls through to `__pow__` inside `_binop`.

**How.** Compare the oracle's `repr` of `(-2.0) ** 0.5`,
`(-8) ** (1.0 / 3.0)`, and `1j ** 1j` with this firmware before
editing. If they differ, replace those five helpers with the pin's
binary32 libm routines, and keep the formula and the fallback where
they are. Do not add a second power unit in the FPU.

## Left as they are

- `RAISE_FROM`. `py/vm.c` prints the chaining warning and drops the
  cause. The core does that.
- `CALL_FUNCTION_VAR_KW` and `CALL_METHOD_VAR_KW`. The star bitmap fits
  the small int the compiler emits. Past the argument buffer the core
  raises, the same way a deep call raises
  `RuntimeError: maximum recursion depth exceeded`.
- Stepped slice assignment. The pin raises. See `STORE_SUBSCR`.
- A host file reader. The variant has no VFS. `'.'` and `'.frozen'`
  are `_FROZEN`.
- Moving a full opcode's fast path into firmware, or its hook into the
  core.

## Full opcodes

| Opcode | Why it is full |
| --- | --- |
| `LOAD_CONST_*`, `LOAD_NULL`, the small-int window | The control word, the qstr, or the const word, including float and complex. |
| `LOAD_FAST_*`, `STORE_FAST_*`, `DELETE_FAST`, `*_DEREF` | Frame locals and cells, with the unbound `NameError`. |
| `LOAD_NAME`, `LOAD_GLOBAL`, `STORE_NAME`, `STORE_GLOBAL`, `DELETE_NAME`, `DELETE_GLOBAL` | Locals, then globals, then builtins. Delete of a missing name raises `NameError`. |
| `STORE_ATTR` | Instance, type, and module dicts, then `_setattr`. A `NULL` value is a delete. |
| `DUP_TOP`, `DUP_TOP_TWO`, `POP_TOP`, `ROT_TWO`, `ROT_THREE` | Stack shuffling. |
| Jumps `0x42`–`0x46`, `UNWIND_JUMP` | Offsets, truth, and `finally` / `with` unwinding. Pending callbacks run on jumps. |
| `SETUP_EXCEPT`, `SETUP_FINALLY`, `POP_EXCEPT_JUMP`, `END_FINALLY` | The pin's exception block. `END_FINALLY` pops `None`, continues an unwind, or reraises. |
| `FOR_ITER` | Steps the four-word iterator image. `StopIteration` from `__next__` ends the loop. The `__getitem__` fallback is the `GET_ITER` row above. |
| `BUILD_*`, `STORE_MAP`, `STORE_COMP` | Containers and comprehension stores. A slice object is real. Unhashable keys go to `_dictop`. |
| `UNPACK_SEQUENCE`, `UNPACK_EX` | Exact list and tuple in the core. Everything else, and every star, goes to `_unpack`. |
| `MAKE_FUNCTION*`, `MAKE_CLOSURE*` | Child raw code, defaults, and the closure tuple. Cells are filled when the call binds. |
| `CALL_FUNCTION`, `CALL_METHOD` | Positional and keyword binding, defaults, bound methods, natives, then `_bind` / `_call`. |
| `RETURN_VALUE` | Unwinds `finally` and `with`, then returns. |
| `RAISE_LAST`, `RAISE_OBJ` | Reraise, or raise an instance or a type. |
| `YIELD_VALUE`, `YIELD_FROM` | Generator `send` / `throw` / `close`, and `yield from` following `mp_resume`. |
| Unary window | `+`, `-`, `~` on ints, bools, and floats. Other types go to `_unop`. |
| The rest of the binary window | ALU for ints, bools, and floats. `in`, `is`, and exception match have their own paths. Sequences and dunders go to `_binop`. |
