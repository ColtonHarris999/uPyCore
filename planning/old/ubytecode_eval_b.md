# Bytecode support decisions

Proposal for the reviewer. The other writeup on this branch is
`planning/ubytecode_eval.md`. This one uses the same pin (MicroPython
v1.29.0, `py/vm.c`, `py/runtime.c`, `py/builtinimport.c`,
`py/objmodule.c`) and the same unix oracle (`variants/upycore`, extra
features, normal errors, long long, binary32).

An opcode is **full** when the hart plus its firmware hook matches that
`ENTRY` for every value the oracle accepts. A hook that matches is
full. Moving it into Verilog does not finish the opcode. An opcode is
**partial** when some accepted value still diverges. The `phase` column
in `upycore/targets/upycore.json` is the old schedule, not this split.

## Approve

| Opcode | Divergence |
| --- | --- |
| `IMPORT_NAME` | Relative imports pop the wrong number of components, a failed body stays in `sys.modules`, `usys` / `builtins` are absent, and a replaced `__import__` cannot run |
| `IMPORT_FROM` | A name missing from a non-package still tries a submodule import; module `__getattr__` never runs |
| `IMPORT_STAR` | `__all__` is ignored |
| `LOAD_ATTR`, `LOAD_METHOD` | A module has no `__dict__` and no module-level `__getattr__` |
| `LOAD_SUBSCR` | A non-ASCII `str` slice is indexed in bytes. `slice_str_unicode` is `xfail` for this |
| `STORE_SUBSCR` | List and bytearray assignment with `step != 1` raises `NotImplementedError` |
| `SETUP_WITH` | `S_AT` kind 3 (`property`, `classmethod`, `staticmethod`, other descriptor) is treated as a missing `__enter__` / `__exit__` |
| `WITH_CLEANUP` | `S_WC_TR` treats `tr_x` as true, so an `__exit__` result whose truth needs `_truth` swallows the exception. `0j` and a `__bool__` of `False` are both false on the oracle |
| `GET_ITER`, `GET_ITER_STACK` | `mp_getiter`'s `__getitem__` arm is missing. A class with `__getitem__` and no `__iter__` is iterable on the oracle |

Imports first. The three import opcodes are one loader.

## Leave

`RAISE_FROM` already matches v1.29.0: a cause other than `None` prints
`Warning: exception chaining not supported` and the value is raised.
Chaining would disagree with the oracle.

`UNPACK_EX`, `BUILD_SET`, `GET_ITER` on list/tuple/str/range, and the
keyword half of `CALL_*` already match through `_unpack`, `_dictop`,
`_getiter`, and `_bind`. A hart copy of those functions would not
change a result. The star-call argument-buffer ceiling (more than 224
positional words plus keyword pairs) is a map limit, not a missing
rule.

`BINARY_OP` `__pow__` / `__ipow__` already follow the pin: the ALU
returns `AE_COMPLEX` for a negative base and a non-integral exponent,
and `_cpow` is `exp(z2 * ln(z1))` from `py/objcomplex.c`. The printed
value can differ because `_flog`, `_fexp`, `_fatan2`, `_fsin`, and
`_fcos` are short series shared with formatting. Replacing them with
libm is a float-library change, not a bytecode one. Leave the opcode.

Every other named opcode, and the five folded windows, match. The
list is at the bottom. `BUILD_SLICE` always allocates; the pin's peek
at the next opcode is a speed path and the subscript still sees a slice.

Do not add a filesystem importer. This variant turns the POSIX VFS off,
and pivot decision D5 leaves the on-device compiler out. Frozen image
modules are the device's `mp_import_stat`. A missing name raises
`ImportError: no module named '<name>'`.

## Imports

Dispatch stays in `S_QOP`. `IMPORT_NAME` (`0x1b`) passes the qstr, the
top of stack (fromlist), the value under it (level), and the caller's
`glb`. `IMPORT_FROM` (`0x1c`) and `IMPORT_STAR` (`0x69`) stay their own
hooks. The policy stays in `upycore/firmware/modules.py`.

### Who runs

The builtins dict is ROM (`emit_dict` defaults `rom=True`), so a store
into it fails in `_setattr` and the user cannot replace `__import__`
today. The pin allocates `mp_module_builtins_override_dict` on the first
such store and `mp_import_name` calls that entry when it is present.

Park the shadow dict in a free sysroot slot, empty until the first
store into the builtins module. A store writes the shadow. A load
checks the shadow, then the ROM dict. A shadow value of `NULL` hides
the ROM entry so a delete stays deleted. `LOAD_NAME`'s builtins step
(`S_LN_L` when `i2 == 2`) uses the same two-step lookup, or a replaced
builtin is visible to `import` and invisible to a bare name.

The hook wrapper keeps the name `_import`. Rename the current body to
`_load_import`. The wrapper calls the shadow `__import__` when it is
not the original function, as
`__import__(name, globs, None, fromlist, level)`. Otherwise it calls
`_load_import`. `builtins.__import__` calls `_load_import`, not the
wrapper, so an override that calls the builtin does not recurse.

### Relative name

`_rel_name` prefers `__package__` and always pops `level` components.
`evaluate_relative_import` reads `__name__` only. A globals dict that
contains `__path__` is a package and drops one level before the walk,
so `from . import x` inside package `pkg.sub` stays in `pkg.sub`.
Walking off the front of `__name__` raises
`ImportError: can't perform relative import`. Level below 0, or an
empty name after resolution, raises `ValueError`.

```python
def _resolve_relative(name, level, globs):
    if level < 0:
        raise ValueError()
    if level == 0:
        if name is None or _slen(name) == 0:
            raise ValueError()
        return name
    cur = _dget(globs, '__name__')
    if cur is NULL or not _isstr(cur):
        raise ImportError("can't perform relative import")
    if _streq(cur, '__main__'):
        alt = _dget(globs, '__main__')
        if alt is not NULL and _isstr(alt):
            cur = alt
    n = _slen(cur)
    p = n
    left = level - 1 if _dget(globs, '__path__') is not NULL else level
    while left and p > 0:
        p -= 1
        if _byte(cur, p) == 46:
            left -= 1
    if p == 0:
        raise ImportError("can't perform relative import")
    base = _substr(cur, 0, p, TAG_STR)
    if name is None or _slen(name) == 0:
        return base
    return _cat(_cat(base, '.'), name)
```

`p == 0` is the pin's `p == start` test. `from . import x` in the entry
module (`__name__` is `__main__`, no `__path__`) hits it. The `__main__`
key is the pin's `-m` compat; nothing on the device sets it, and the
branch is a no-op until something does.

### Search

Keep the dotted walk. A parent without `__path__` raises
`ImportError: no module named '<full>'`. `fromlist is None` returns the
top package. Any other fromlist, including `()` and `True`, returns the
leaf. `mp_import_from` passes `True` for that reason.

For one component:

1. Non-extensible builtins, before the cache and before frozen modules:
   `sys`, `gc`, `micropython`, `usys` (the same module as `sys`), and
   `builtins`. The `builtins` module's globals are the ROM builtins
   dict, not a copy.
2. `sys.modules`, unless `sys.path` is empty. An empty path is how the
   pin forces a builtin and ignores a cached module of the same name.
   The device path is `['.', '.frozen']`, so this is the empty-path
   case only.
3. Frozen image (`_FROZEN`), for path entries `'.'` and `'.frozen'`.
   Any other path entry is a miss. There is no host directory.
4. Native `mod_*` modules (`_NATIVE_MODULES`), after frozen. The pin
   tries the filesystem before an extensible builtin. A top-level name
   `ufoo` that is not itself a module retries `foo` in this table; that
   is the pin's `u`-prefix alias for extensible builtins.

Register the module in `sys.modules` before `_callns`, so a cycle
observes the partial module. If the body raises, delete that name and
reraise. Today the failed module stays cached and the next import
returns it. A package sets `__path__` to `.frozen/<dotted>` before the
body, so a relative import inside the body sees a package. `__name__`
stays the dotted name. Submodule lookup uses `__name__`, not the path
string.

### `IMPORT_FROM` and `IMPORT_STAR`

Attribute load is the module rule in the next section, not a bare
`_dget`. A bound method comes back bound.

```python
def _import_from(mod, name):
    hit = _module_attr(mod, name)
    if hit is not NULL:
        return hit
    g = _ld(mod, 2)
    if _dget(g, '__path__') is NULL:
        raise ImportError(_s("can't import name ", name))
    return _load_import(_cat(_cat(_ld(mod, 3), '.'), name), True, 0, NULL)
```

Catch `ImportError` from the recursive load and re-raise
`can't import name <name>`. The text has no quotes around the name.

`IMPORT_STAR`: if `_module_attr(mod, '__all__')` hits, the value must
be a list or tuple. Each entry is loaded with `_import_from` (so
`__getattr__` and submodules run) and stored into the dict the opcode
already passes. A non-string entry fails the way `mp_obj_str_get_qstr`
fails. If `__all__` is absent, keep the current scan of the globals and
skip a leading `_`. `import *` inside a function is a syntax error on
this bytecode, so there is no second store path.

### Tests

Extend the frozen-package programs, and keep `import_missing`:

- `from . import sub` and `from .sub import name` from a package
  `__init__`. `from . import x` in `__main__` raises
  `can't perform relative import`.
- A body that raises is gone from `sys.modules`, and a later import
  runs the body again.
- `import usys` is `sys`. `import builtins` then
  `builtins.__import__ = f` changes the next `IMPORT_NAME`, and `f`
  calling the original builtin returns.
- `__all__ = ('a',)` exports `a` and not a public `b`. No `__all__`
  still hides `_c`.

## Module attributes

`LOAD_ATTR` and `LOAD_METHOD` share `S_AT`. A module hit returns the
globals entry. A miss calls `_getattr`, and the `OB_MODULE` arm falls
through to `AttributeError`. `py/objmodule.c` `module_attr`, with
`MICROPY_CPYTHON_COMPAT` and `MICROPY_MODULE_GETATTR` (both on at this
ROM level), is the rule `_module_attr` should implement. `IMPORT_FROM`
and `IMPORT_STAR` call it too.

1. Globals hit: return the value. `LOAD_METHOD` already pushes `NULL`
   as self for a plain value. Leave that.
2. The name `__dict__` returns the module globals object, not a copy.
3. Any other miss except the name `__getattr__`: if the globals contain
   `__getattr__`, call it with the name. Exceptions propagate.
   `LOAD_METHOD` binds whatever came back with the existing rule.
4. There is no `MP_REGISTER_MODULE_DELEGATION` table on this device.
   Skip it.

`STORE_ATTR` on a module already writes the globals and rejects a ROM
dict. The builtins shadow above is the one exception. A frozen module
that defines `__getattr__` must answer `mod.missing` and
`from mod import missing`. `mod.__dict__` is the globals object.

## Slices

### `LOAD_SUBSCR`

Integer indexes of a non-ASCII `str` already take `_ustr_at` (the hart
bails when `si_na` is set). `_getslice` still uses `_slen`, which is
the byte length, and copies one byte per step. `"h\u00e9llo"[1:2]` cuts
the middle of U+00E9. ASCII `str` and `bytes` are byte-indexed on the
oracle too. Leave those, and leave the hart's integer path.

For a non-ASCII `str` in `_getslice`, measure the length with
`_utf8_len`, walk code points with `_utf8_at`, and copy whole code
points. The output size is the byte count of those code points. A step
other than 1 still counts characters. `slice_str_unicode` must print
`11111`, and the `xfail` marker comes off.

### `STORE_SUBSCR`

`_list_setslice` and `_barr_setslice` implement step 1. For any other
step, do what `list_subscr` and `array_subscr` do at this tag: the
right-hand side must have exactly `_slice_len` items, and those items
are written onto the existing indexes in order. The container does not
grow or shrink. A length mismatch raises the pin's
`ValueError: attempt to assign sequence of size <got> to extended slice of size <n>`.
Bytearray elements stay bytes. A null value deletes the selected
indexes from the high end so the earlier indexes stay put. `str` and
`tuple` stay `TypeError` on item assignment. The step-1 resize path
stays as it is.

## `with`

### `SETUP_WITH`

`S_SW_X` accepts `S_AT` kinds 1 and 2. Kind 3 is a descriptor. On kind
3, call `ABI_HOOK_GETATTR` (it already runs `_desc_get`) and continue
at `S_SW_E` with the resolved callable where a kind-1 result sits.
Kind 0 stays a miss. `_getattr` raises `AttributeError`, which is what
`mp_load_method` does for an absent name. Do not treat kind 3 as a miss.

### `WITH_CLEANUP`

`S_WC_TR` pushes `None` when `tr_x` or `tr_r` is set. `tr_x` means
`S_TR` could not decide. `S_JT` already calls `_truth` for that case
and must keep doing so for jumps. This site must not reuse
`ABI_CONT_TRUTH`: that continuation re-fetches the opcode.

`ABI_CONT_WITH_TRUTH` is already id 10 in `mpy_abi.svh`, with the
comment "swallow or re-raise AUX", and `S_CONT` does not handle it.
Wire that id. From `S_WC_TR`, if `tr_x` is clear, keep today's choice
(`None` when `tr_r`, otherwise `aux`). If `tr_x` is set, call `_truth`
with this continuation. On return, push `None` only when the result is
true; otherwise push `aux` so the exception propagates. `__exit__`
returning `0j`, `0`, or a `__bool__` of `False` does not swallow.
Returning `True` or `1` does. A property `__enter__` runs.

## `__getitem__` iteration

`_getiter` handles identity, native containers, `__iter__`, and
`__next__`, then raises. `mp_getiter` then builds a `__getitem__`
iterator. After `__iter__` and `__next__` miss, if the type has
`__getitem__`, return an `OB_ITEROBJ` whose `iterator____next__` calls
`__getitem__(i)` and turns `IndexError` into `StopIteration`. Any other
exception propagates. Word 4 of that object is 0 for the UTF-8 walker
and 1 for the sentinel iterator; use 2 for this mode, and keep the
index in word 3.

Both opcodes reach `_getiter` (`GET_ITER` always, `GET_ITER_STACK`
from `S_GI_FB`). `FOR_ITER` already calls `__next__` on a Python
iterator. No new hart state. Do not also special-case list and tuple
inside `GET_ITER`: `GET_ITER_STACK` already does, and `_getiter` already
returns a `TAG_ITER` the hart can step.

## Full

Constants and names: `LOAD_CONST_FALSE`, `LOAD_CONST_NONE`,
`LOAD_CONST_TRUE`, `LOAD_CONST_SMALL_INT` and the `0x70`–`0xaf` window,
`LOAD_CONST_STRING`, `LOAD_CONST_OBJ`, `LOAD_NULL`, `LOAD_FAST_N` and
`LOAD_FAST` 0–15, `LOAD_DEREF`, `LOAD_NAME`, `LOAD_GLOBAL`,
`STORE_FAST_N` and `STORE_FAST` 0–15, `STORE_DEREF`, `STORE_NAME`,
`STORE_GLOBAL`, `DELETE_FAST`, `DELETE_DEREF`, `DELETE_NAME`,
`DELETE_GLOBAL`, `LOAD_BUILD_CLASS`, `LOAD_SUPER_METHOD`, `STORE_ATTR`.
`LOAD_SUPER_METHOD` is `_super_method`: MRO walk plus `_desc_get`.

Stack and control: `DUP_TOP`, `DUP_TOP_TWO`, `POP_TOP`, `ROT_TWO`,
`ROT_THREE`, `JUMP`, `POP_JUMP_IF_TRUE`, `POP_JUMP_IF_FALSE`,
`JUMP_IF_TRUE_OR_POP`, `JUMP_IF_FALSE_OR_POP`, `UNWIND_JUMP`,
`RETURN_VALUE`, `FOR_ITER`, `SETUP_EXCEPT`, `SETUP_FINALLY`,
`POP_EXCEPT_JUMP`, `END_FINALLY`, `RAISE_LAST`, `RAISE_OBJ`,
`RAISE_FROM`, `YIELD_VALUE`, `YIELD_FROM`. Jumps whose truth `S_TR`
cannot decide already call `_truth`. That is why the `tr_x` bug is
only in `WITH_CLEANUP`.

Builders, calls, and the other operators: `BUILD_TUPLE`, `BUILD_LIST`,
`BUILD_MAP`, `BUILD_SET`, `BUILD_SLICE`, `STORE_MAP`, `STORE_COMP`,
`UNPACK_SEQUENCE`, `UNPACK_EX`, `MAKE_FUNCTION`,
`MAKE_FUNCTION_DEFARGS`, `MAKE_CLOSURE`, `MAKE_CLOSURE_DEFARGS`,
`CALL_FUNCTION`, `CALL_METHOD`, `CALL_FUNCTION_VAR_KW`,
`CALL_METHOD_VAR_KW`. Unary `+` `-` `~` `not`, and every binary op
except the pow tolerance noted above. `in` on `str` and `bytes` is
`_find_bytes`. Dict and set containment stays on the lookup fast path.
