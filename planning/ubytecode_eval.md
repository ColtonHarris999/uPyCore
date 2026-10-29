# Bytecode completion decisions

Status: **proposal for review.** This file is the decision record for
which MicroPython v1.29.0 opcodes (`0fd6c573`) are already complete in
upycore, and which partial ones should be finished. It does not change
the core. The pin's behaviour is `py/vm.c`, `py/runtime.c`,
`py/builtinimport.c`, and `py/objmodule.c` at that commit, as executed
by the unix oracle in `variants/upycore` (ROM level extra features,
`MICROPY_FLOAT_IMPL_FLOAT`).

"Full" means the opcode matches that oracle for every value the oracle
accepts. A firmware hook is full when the hook matches. "Partial" means
a concrete case still diverges. The catalog `phase` column in
`upycore/targets/upycore.json` is the original schedule, not this
classification: phase 4 opcodes such as `YIELD_VALUE` and
`MAKE_CLOSURE` already match the oracle and are listed as full below.

Multi-opcode ranges (`LOAD_CONST_SMALL_INT`, `LOAD_FAST`, `STORE_FAST`,
`UNARY_OP`, `BINARY_OP`) share the row of the operation they fold into.

## Decisions

| Opcode | Decision | What is still short |
| --- | --- | --- |
| `IMPORT_NAME` | **Approve** | Relative imports inside a package, failed-body rollback, `usys`, builtin override |
| `IMPORT_FROM` | **Approve** | Package attribute load should use the same module attribute rules as `LOAD_ATTR` |
| `IMPORT_STAR` | **Approve** | `__all__` is ignored |
| `LOAD_ATTR` | **Approve** | Module `__dict__` and module `__getattr__` |
| `LOAD_METHOD` | **Approve** | Same module lookup, then the existing method bind |
| `LOAD_SUBSCR` | **Approve** | Non-ASCII `str` slice uses byte indexes |
| `STORE_SUBSCR` | **Approve** | List and bytearray slice assignment with `step != 1` raises `NotImplementedError` |
| `SETUP_WITH` | **Approve** | `__enter__` / `__exit__` stored as a property or other descriptor is treated as missing |
| `WITH_CLEANUP` | **Approve** | An `__exit__` return whose truth is not decided in `S_TR` is swallowed |
| `BINARY_OP` `__pow__` / `__ipow__` | **Approve** | Negative base to a non-integral power is a documented approximation |
| `RAISE_FROM` | **Leave** | Already the pin: warn, then raise the exception. Do not add chaining |
| `CALL_FUNCTION_VAR_KW`, `CALL_METHOD_VAR_KW` | **Leave** | Argument-buffer ceiling, not a missing language rule |
| Every other named opcode | **Leave** | Review against the pin found no remaining divergence |

Imports are the first group to land. The three import opcodes share one
loader; finishing `IMPORT_NAME` without `IMPORT_FROM` and `IMPORT_STAR`
still leaves `from` and `import *` wrong.

## Approved: imports

The opcode dispatch stays in `S_QOP` (`mpy_core.sv`). `IMPORT_NAME`
calls `ABI_HOOK_IMPORT`, `IMPORT_FROM` calls `ABI_HOOK_IMPORT_FROM`,
`IMPORT_STAR` calls `ABI_HOOK_IMPORT_STAR`. The search stays in
`upycore/firmware/modules.py`. A filesystem walker in the FSM would
duplicate `_load_mod` and still need the firmware for module bodies.

There is no POSIX reader on the device. `variants/upycore` turns the
VFS off. Host tests already freeze the imported files into the image
(`_FROZEN` in `mpy_link.py`). A `sys.path` entry other than `'.'` or
`'.frozen'` stats as missing. That is the device's answer to
`mp_import_stat`, not a second loader.

### `IMPORT_NAME`

Stack today, and in the pin: `level`, then `fromlist` on top. The hook
is `_import(name, fromlist, level, globals)`.

Replace the body of `_import` / `_rel_name` / `_load_mod` so it follows
`mp_import_name` and `mp_builtin___import___default` in the pin:

1. Call `__import__` with `(name, globals, None, fromlist, level)`.
   Locals stay `None`, matching the pin's `mp_import_name` (its own
   comment still leaves locals as a follow-up). The callee is the
   `__import__` stored for the builtins module. That map is ROM
   (`emit_dict` defaults `rom=True`), and `STORE_ATTR` on a ROM dict
   raises `AttributeError`, so a user cannot replace `__import__`
   today. The pin handles a fixed builtins map by allocating
   `mp_module_builtins_override_dict` on the first store and looking
   there from `mp_import_name`. Do the same: the first store into
   `builtins` writes the override dict, later loads check it before
   the ROM map, and this opcode calls the override entry when present.
   The default entry remains the helper below. `import builtins`
   itself is part of step 5.
2. Relative names follow `evaluate_relative_import`. Read `__name__`
   from the globals dict. If that name is `__main__` and the dict has
   `__main__`, use that stored name (the pin's `-m` compat). If the
   dict has `__path__`, subtract one from `level` before walking
   dots, because the search starts inside the package. Walk back
   `level` dots. Running out of components raises
   `ImportError: can't perform relative import`. `from . import name`
   inside a package therefore resolves to the package itself, and
   `from .sub import name` inside `__init__` resolves to
   `package.sub`. The current `_rel_name` always pops `level`
   components and prefers `__package__`, so both of those cases
   become `sub` or `''`.
3. An empty name after that resolution raises `ValueError`, as the
   pin does. A negative level raises `ValueError`.
4. Split the absolute name on `.` and load each component.
   `sys.modules` (`SR_MODULES`) hits return immediately, except when
   `sys.path` is empty: the pin ignores the cache in that case so an
   empty path forces a builtin.
5. Order for a top-level component, matching
   `process_import_at_level`: non-extensible builtins first, then each
   `sys.path` entry, then native modules in `_NATIVE_MODULES`
   (extensible builtins). The non-extensible set is `sys`, `gc`,
   `micropython`, `usys` as an alias of `sys`, and `builtins`.
   `builtins` is a module whose globals are the existing builtins
   dict, not a copy. A leading `u` that is not itself a module retries
   the remainder against `_NATIVE_MODULES`, which is the pin's old
   `ufoo` alias for an extensible `foo`.
6. Path stat, for an entry `root` and a component `comp`:
   - `'.frozen'` and `'.'` both consult `_FROZEN`, keyed by the full
     dotted name. The `'.'` root is the modules linked into this
     image; there is no host directory.
   - A frozen descriptor whose flags word has bit 1
     (`_MD_FLAG_PACKAGE`) is a package. Anything else found is a
     module file.
   - Any other root is a miss.
7. Register the new module in `sys.modules` before running its body.
   If the body raises, delete that name before the exception
   propagates. The pin does this with an NLR callback around
   `do_load`. Today `_load_mod` stores the module and then calls
   `_callns`, so a failed body stays cached and the next import
   returns the half-built module.
8. On a package, set `__path__` to `root + '/' + dotted` (so a frozen
   package records `.frozen/pkg`). Keep `__name__` as the dotted name.
   Submodule lookup uses `__name__`, not the path string. `fromlist
   is None` returns the first component; any other fromlist returns
   the leaf. Do not special-case the pin's `fromtuple == False`
   sentinel. Nothing on this device loads a module via `-m`.

Acceptance, against the unix oracle, in addition to the existing
`use_pkg`, `use_rel`, `use_helper`, and `import_missing` programs:

- `from . import sub` and `from .sub import name` executed from a
  frozen package `__init__`.
- A module body that raises is absent from `sys.modules`, and a later
  import runs the body again.
- `import usys` is `sys`. `import builtins` is a module whose
  globals are the builtins dict, and assigning
  `builtins.__import__` changes the next import.
- `from . import x` above the top package raises
  `ImportError: can't perform relative import`.

### `IMPORT_FROM`

`_import_from` already re-enters `_import` for a missing attribute of
a package. Keep that. Change the attribute load so it is
`mp_import_from`:

1. Load the name with the module attribute rule in the `LOAD_ATTR`
   section (globals, then `__dict__`, then `__getattr__`). A bound
   method result is returned as the bound method. The pin's
   `mp_load_method_maybe` uses `dest[1]` for that case.
2. If the load misses and the module globals contain `__path__`,
   import `module.__name__ + '.' + name` with a non-`None` fromlist
   and level 0, store it on the parent, and return the leaf.
3. Otherwise raise `ImportError: can't import name <name>` (the pin's
   text has no quotes around the name).

### `IMPORT_STAR`

`_import_star` currently copies every global whose first byte is not
`_`. The pin's `mp_import_all` (`MICROPY_MODULE___ALL__`, on from
basic features upward) does this first:

1. Load `__all__` with the same module attribute rule, so a module
   `__getattr__('__all__')` runs.
2. If that value exists, require a list or tuple. For each item, load
   that name the same way (so `__getattr__` runs per name) and store
   it with the current name-store rule. A non-string item raises the
   same error `mp_obj_str_get_qstr` raises on the oracle.
3. If `__all__` is absent, keep the current scan: module globals,
   skip a leading `_`.
4. Keep writing through the dict the opcode already passes (`loc` when
   the frame has one, otherwise the globals). At module level that is
   the module dict. `import *` inside a function is a syntax error, so
   there is no second store path to build.

Acceptance: a frozen module with `__all__ = ('a',)` exports `a` and
does not export a public `b`, and a module with no `__all__` still
exports public names and hides `_c`.

## Approved: module attributes

`LOAD_ATTR` and `LOAD_METHOD` share `S_AT`. A module hit returns the
globals entry (`S_AT_MOD`). A miss falls into `_getattr`, and the
`OB_MODULE` arm of `_getattr` does nothing and then raises
`AttributeError`.

The pin's `module_attr` in `py/objmodule.c`, with `MICROPY_CPYTHON_COMPAT`
and `MICROPY_MODULE_GETATTR` both enabled at this ROM level, is:

1. Globals hit: return the value. `LOAD_METHOD` already pushes `NULL`
   as self for a plain value (`S_LA_R` kind 1). Leave that.
2. Missing `__dict__`: return the module globals object itself, not a
   copy. Type objects copy their dict; modules must not.
3. Any other missing name except `__getattr__` itself: if the globals
   contain `__getattr__`, call it with the name string. The call's
   exceptions propagate. `LOAD_METHOD` then applies the existing
   method-bind rule to whatever came back.
4. Built-in attribute delegation (`MP_REGISTER_MODULE_DELEGATION`) has
   no entries on this device. Skip it.

`STORE_ATTR` on a module already writes the globals dict and rejects a
ROM dict. Leave it.

Acceptance: a frozen module whose globals define
`__getattr__(name)` answers `mod.missing` and `from mod import missing`
with that function's result, and `mod.__dict__ is` the globals dict.

## Approved: slices

### `LOAD_SUBSCR`

Integer indexes of non-ASCII strings already go through `_ustr_at`
(character indexes). `_getslice` does not. It takes `n = _slen(obj)`,
which is the byte length, and copies one byte per step. `"h\u00e9llo"[1:2]`
therefore cuts the middle of U+00E9. ASCII strings and `bytes` are
byte-indexed in the oracle too; leave those, and leave the RTL
`S_LS_S` path that bails to this hook when `si_na` is set.

In `_getslice`, when the object is a non-ASCII `str`:

- Measure `n` with `_utf8_len`.
- Walk code points with `_utf8_at` to turn the character start and the
  slice length into a byte span. The output size is that byte count,
  not the character count.
- Copy whole code points. A step other than 1 still counts characters.

`slice_str_unicode` in `hw_tests.toml` is the acceptance test. It is
marked `xfail` today. Removing that marker is part of the change. The
program must print `11111`.

### `STORE_SUBSCR`

`_list_setslice` and `_barr_setslice` raise
`NotImplementedError: extended slice assignment` when the step is not
1. The pin assigns those slices in place and does not resize them.

For `step != 1` on a list or a bytearray:

- Compute the index sequence with the existing `_slice_range`.
- The right-hand side must have exactly `_slice_len` items. Otherwise
  raise `ValueError: attempt to assign sequence of size <got> to extended slice of size <n>`.
- Write those items onto the existing indexes, in order. Do not grow
  or shrink the container.
- Bytearray values are bytes, as the step-1 path already requires.

The step-1 path stays the resize path that is already there. `str` and
`tuple` stay `TypeError` on item assignment. `del a[i:j:k]` is the
same opcode with a null value; a null value on a step other than 1
deletes those indexes from the end of the index list so the earlier
indexes stay valid.

## Approved: `with`

### `SETUP_WITH`

`S_SW_X` handles `S_AT` kinds 1 (value) and 2 (method). Kind 3 is a
property, staticmethod, classmethod, or other object found on the
class. The state raises `AttributeError` for that kind, so a context
manager whose `__enter__` or `__exit__` is a property never runs.

On kind 3, resolve the attribute with the existing `ABI_HOOK_GETATTR`
path that `LOAD_ATTR` uses (that hook already calls `_desc_get`). On
return, continue at `S_SW_E` with the resolved callable in the same
place a kind-1/2 result occupies. Kind 0 stays a miss: `_getattr`
raises `AttributeError`, which is what `mp_load_method` does when the
name is absent. Do not treat kind 3 as a miss.

### `WITH_CLEANUP`

`S_WC_TR` pushes `None` when `tr_x` is set, which swallows the
exception. `tr_x` means `S_TR` could not decide: a complex, a range, a
user object with `TF_TRUTH`, and the other tags in the `default` arm.
`0j` is false in the oracle, and a `__bool__` that returns `False`
must not swallow. `S_JT` already calls `ABI_HOOK_TRUTH` for this case.
`WITH_CLEANUP` must not reuse `ABI_CONT_TRUTH`, because that
continuation re-fetches the opcode.

Add a continuation used only here. From `S_WC_TR`, if `tr_x` is clear,
keep the current choice (`None` when `tr_r`, otherwise the saved
exception in `aux`). If `tr_x` is set, call `_truth` and on return push
`None` only when the hook result is `True`. `_truth` already reduces
`__bool__` / `__len__` to a bool.

Acceptance: `__exit__` returning `0j`, `0`, or a `__bool__` of `False`
does not swallow; returning `True` or `1` does. A property `__enter__`
runs.

## Approved: `BINARY_OP` `__pow__` and `__ipow__`

Integer and float powers that the ALU accepts are done. The FPU header
in `upycore_fpu.sv` names the remaining case: a negative base with a
non-integral exponent, which is a complex result. `S_NUM_W` sends that
case to `_binop`, and `_num_binop` calls `_cpow`. `_cpow` is the
`exp(z2 * ln(z1))` formula from the pin's complex power, but
`_flog` / `_fexp` / `_fatan2` / `_fcos` / `_fsin` are documented as
approximate. Printed results are not required to match the oracle.

Replace those helpers with the pin's `libm` routines that the unix
float build actually calls (binary32, `MICROPY_FLOAT_IMPL_FLOAT`),
compiled into the firmware as ordinary functions. Keep the formula in
`_cpow`. Do not add a second power algorithm in the FPU: the positive
real path stays `upycore_fp_pow`, and this case stays the firmware
fallback that already detects it. The acceptance check is the oracle's
`repr` of `(-2.0) ** 0.5`, `(-8) ** (1.0 / 3.0)`, and `1j ** 1j`.

In-place power is the same operation. The pin rewrites `__ipow__` to
`__pow__` before the complex case. `_binop` already does that rewrite.
Leave the rewrite where it is.

## Left as they are

### `RAISE_FROM`

`S_EXEC` for opcode `0x66` calls `_warn` when the cause is not `None`,
then re-dispatches as `RAISE_OBJ`. `_warn` prints
`Warning: exception chaining not supported`. That string is the pin's
`mp_warning` in `MP_BC_RAISE_FROM`. Chaining would make
`raise E from C` disagree with the unix oracle. Leave the warning.

### Star-call opcodes

`CALL_FUNCTION_VAR_KW` and `CALL_METHOD_VAR_KW` expand a tuple and a
dict into the argument buffer. When that expansion is wider than the
register ring, more than 224 positional arguments plus keyword pairs
(each keyword is two words) raises `ABI_ERR_STAR_ARGS`. A call that
large is already past the 64-register window and the 32-frame stack.
Widening the buffer is a memory-map change, and it does not close a
gap the hardware suite can hit. Leave the ceiling.

### Already full

These match the pin, including where a hook covers the cases the RTL
fast path skips. Do not reopen them in order to move the hook into
Verilog.

Constants and stack: `LOAD_CONST_FALSE`, `LOAD_CONST_NONE`,
`LOAD_CONST_TRUE`, `LOAD_CONST_SMALL_INT` and its 64 immediate forms,
`LOAD_CONST_STRING`, `LOAD_CONST_OBJ`, `LOAD_NULL`, `DUP_TOP`,
`DUP_TOP_TWO`, `POP_TOP`, `ROT_TWO`, `ROT_THREE`.

Names and locals: `LOAD_FAST_N` and `LOAD_FAST` 0..15, `STORE_FAST_N`
and `STORE_FAST` 0..15, `DELETE_FAST`, `LOAD_DEREF`, `STORE_DEREF`,
`DELETE_DEREF`, `LOAD_NAME`, `LOAD_GLOBAL`, `STORE_NAME`,
`STORE_GLOBAL`, `DELETE_NAME`, `DELETE_GLOBAL`, `STORE_ATTR`.
`LOAD_NAME` walks locals, then globals, then the builtins dict
(`S_LN_L`). That is `mp_load_name`.

Calls and functions: `MAKE_FUNCTION`, `MAKE_FUNCTION_DEFARGS`,
`MAKE_CLOSURE`, `MAKE_CLOSURE_DEFARGS`, `CALL_FUNCTION`, `CALL_METHOD`,
`RETURN_VALUE`, `LOAD_BUILD_CLASS`, `LOAD_SUPER_METHOD`. Class creation
is `__build_class__`. `super().name` is `_super_method`, which walks
the MRO and binds through `_desc_get`. `inherit.py` covers it.

Containers and iteration: `BUILD_TUPLE`, `BUILD_LIST`, `BUILD_MAP`,
`STORE_MAP`, `BUILD_SET`, `BUILD_SLICE`, `STORE_COMP`,
`UNPACK_SEQUENCE`, `UNPACK_EX`, `GET_ITER`, `GET_ITER_STACK`,
`FOR_ITER`. `BUILD_SLICE` allocates the slice object. The pin's
peephole that skips the allocation when the next opcode is a subscript
is a speed path, and the subscript opcodes still see a slice either
way. `BUILD_SET` goes through `_dictop`, and `set_order` matches the
oracle's order.

Control and exceptions: `JUMP`, `POP_JUMP_IF_TRUE`,
`POP_JUMP_IF_FALSE`, `JUMP_IF_TRUE_OR_POP`, `JUMP_IF_FALSE_OR_POP`,
`SETUP_EXCEPT`, `SETUP_FINALLY`, `POP_EXCEPT_JUMP`, `END_FINALLY`,
`UNWIND_JUMP`, `RAISE_LAST`, `RAISE_OBJ`. Jumps whose truth `S_TR`
cannot decide already call `_truth` from `S_JT`. That is why the
`tr_x` bug is confined to `WITH_CLEANUP`.

Generators: `YIELD_VALUE`, `YIELD_FROM`. `await` is `yield from` in
this bytecode, and `gen_async` is in the suite. `YIELD_VALUE` with no
generator object raises `NotImplementedError: generators aren't supported`,
which is the guard in `S_EXEC` for a yield outside a generator frame.

Other binary and unary ops: comparisons, `is`, exception match, `in`,
the integer and float arithmetic the ALU accepts, and the unary
operators. `in` on a `str` or `bytes` is `_find_bytes` (a substring
search), which is what the pin does. Dict and set containment stays on
the lookup fast path.

`complex(1, 1j)` disagreeing with the oracle (`complex_type_trap` in
the suite) is the `complex` constructor, not a bytecode.
