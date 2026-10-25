# Bytecode completion plan

Status: **the plan of record.** Implement from this file. The three
proposals on this branch (`ubytecode_eval.md`, `ubytecode_eval_b.md`,
`ubytecode_eval_c.md`) are the inputs. Where one of them disagrees with
this file, this file wins.

The pin is MicroPython **v1.29.0** (`0fd6c573`). The oracle is the unix
port built from `variants/upycore` (ROM level extra features, normal
error reporting, binary32, long long). "Full" means the hart plus its
existing firmware hook matches that oracle. Moving a correct hook into
Verilog does not finish an opcode, and it is out of scope here.

This review checked the proposals against the tree and against the pin
sources under `vendor/micropython/py/`. The unix oracle binary was not
executed (the i686 toolchain is not installed in this environment).
Every new `oracle = true` program still takes its golden from
`make regen-goldens`. If a printed message differs from a string below,
the oracle wins.

## Locks

These bounds are the point of the pass. A change that breaks one of
them does not land, even if a proposal asked for it.

- No new opcode, no new SRAM, no wider argument buffer, no second
  power unit in the FPU, no filesystem walker in the FSM. A star call
  that does not fit ARGBUF allocates a heap tuple (W7). ARGBUF stays
  256 words.
- The integer and ASCII subscript fast path stays in `S_LSUB` /
  `S_LS_S`. The list, tuple, dict, set, range, bytes, and ASCII-str
  arms of `S_GI` stay in the hart. `S_JT` and `ABI_CONT_TRUTH` stay
  the jump truth path.
- Locals and globals probes in `S_LN_L` (`i2 == 0` and `i2 == 1`) do
  not grow a memory operation. The builtins probe (`i2 == 2`) does not
  grow one either while the override slot is empty.
- `fflags` is not the override flag. It is packed into the frame header
  and replaced on call entry (`FF_FW`, `FF_GEN`, `FF_YFAST`, `FF_NOTB`).
  A bit there disappears across a call.
- Do not renumber `ABI_CONT_*` or `HOOKS`. Append a continuation only
  if the `with` descriptor resume needs one. `ABI_CONT_WITH_TRUTH`
  (id 10) is already reserved and is currently a halt in `S_CONT`.
- Firmware that is already correct stays firmware. Do not port
  `_unpack`, `_dictop`, `_bind`, or the generator resume path into
  the core as part of this work.

## Decisions

A finding raised by one proposal can be right. Stepped slice assignment
was raised by two and is wrong for this pin.

| Topic | Raised by | Decision |
| --- | --- | --- |
| `IMPORT_NAME`, `IMPORT_FROM`, `IMPORT_STAR` as one loader, no VFS | A, B, C | **Do.** Firmware only. Dispatch stays `S_QOP`. |
| Relative import reads `__name__`, and a package drops one level | A, B, C | **Do.** Stop reading `__package__`. |
| Failed module body is removed from `sys.modules` | A, B, C | **Do.** Delete only the key this import inserted. |
| `usys`, `builtins`, and a builtins override dict | A, B, C | **Do**, with the shape in W4. Do not copy the ROM dict. Do not plant a NULL that hides a ROM entry. |
| Module `__dict__` and module `__getattr__` | A, B, C | **Do.** Firmware miss path only. `S_AT_MOD` hit path stays. |
| `IMPORT_STAR` honors `__all__` | A, B, C | **Do.** |
| Non-ASCII `str` slice, step `None` or 1, is a character span | A, B, C | **Do.** Drop the `slice_str_unicode` xfail. |
| Stepped slice **store** writes the elements in place | A, B | **Do not.** `list_subscr` raises `NotImplementedError` with no argument when `mp_seq_get_fast_slice_indexes` returns false (`py/objlist.c`). |
| Stepped `str` / `tuple` / `bytes` / `bytearray` **load** | C | **Do.** Raise the pin's `NotImplementedError`. A and B leave the copy in place. The pin rejects it (`py/objstrunicode.c`, `py/objtuple.c`, `py/objarray.c`). |
| List load with a step, and range slices | C (list), all three leave range | **Leave the copy.** `list_subscr` calls `mp_seq_extract_slice` for a non-unit step. |
| `SETUP_WITH` kind 3 is a real descriptor | A, B, C | **Do.** Resolve with `ABI_HOOK_GETATTR`. Do not treat kind 3 as a miss. |
| `WITH_CLEANUP` treats `tr_x` as true | A, B, C | **Do.** Wire the existing `ABI_CONT_WITH_TRUTH`. Do not reuse `ABI_CONT_TRUTH`. |
| `GET_ITER` / `GET_ITER_STACK` `__getitem__` fallback | B, C | **Do.** Firmware only. A called `GET_ITER` full; `mp_getiter` still has this arm (`py/runtime.c`). |
| Depth-first MRO instead of C3 | C | **Do**, as a firmware tuple rewrite. A and B missed it. `py/objtype.c` says the lookup is depth-first left-to-right, not Python 3 C3. Do not add a recursive search on the attribute hit path. |
| `c == c` is true for a complex NaN | C | **Do.** One tag compare in `S_EQ`. `_equal` already has the right answer and is skipped by the identity shortcut. |
| Replace `_flog` / `_fexp` / `_fatan2` / `_fsin` / `_fcos` with libm | A, C (C says measure first) | **Do not land.** B is right that this is the shared float formatter, not a missing opcode. The negative-base case already reaches `_cpow`. A libm import grows ROM and changes formatting. |
| `RAISE_FROM` chains exceptions | none (all three say leave) | **Leave.** `py/vm.c` warns and drops the cause. The hart already warns. |
| `CALL_*_VAR_KW` past the argument buffer | none of the three; added after review | **Do, as a heap tuple.** Do not widen ARGBUF. Calls that fit stay on the SRAM path. See W7. |
| Host directory importer | none | **Leave.** `MICROPY_VFS_POSIX` is 0. `'.'` and `'.frozen'` are `_FROZEN`. |

## Work items

Land W1, W2, and W5 in any order. They do not share files. W4 starts
once `_module_attr` exists. W6 and W7 both edit `mpy_core.sv`. W7
touches only `S_CVK_*`. Land it after W6, or in the same RTL change
with the W6 cycle numbers already recorded. Do not edit `S_CVK_*` and
`S_LN_L` / `S_EQ` / `S_SW_*` in two branches at once.

| Id | Files | RTL |
| --- | --- | --- |
| W1 | `upycore/firmware/attrs.py`, `upycore/firmware/strs.py` | no |
| W2 | `upycore/firmware/iters.py` | no |
| W3 | `_module_attr` in `upycore/firmware/attrs.py` (same owner as W1) | no |
| W4 | `upycore/firmware/modules.py` | no |
| W5 | `upycore/firmware/calls.py` (`_c3` only) | no |
| W6 | `upycore/rtl/mpy_core.sv`, `upycore/rtl/mpy_abi.svh` | yes |
| W7 | `upycore/rtl/mpy_core.sv` (`S_CVK_*` only) | yes |

### W1 — slices

`_getslice` is the firmware side of `LOAD_SUBSCR`. Integer indexes
never reach it: `S_LSUB` handles a list or tuple index, and `S_LS_S`
handles an ASCII `str` or `bytes` index. A non-ASCII `str` index
already bails to `_ustr_at` when `si_na` is set. Leave those states
alone.

In `_getslice`:

1. `str`, `tuple`, `bytes`, and `bytearray`, when the step is neither
   `None` nor 1: raise
   `NotImplementedError('only slices with step=1 (aka None) are supported')`.
   Do this before any copy. `_slice_range` already turns a missing step
   into 1, so the test after it is `s != 1` (a negative step fails it
   too). ASCII `str` is included. The existing step-1 byte copy for
   ASCII `str` and `bytes` stays the byte copy. Do not call `_utf8_len`
   on an ASCII string.
2. Non-ASCII `str`, step `None` or 1: `n` is `_utf8_len`, not `_slen`.
   Map the character bounds through `_utf8_at` and copy the byte span
   those code points cover. The result's length is that byte count.
   `"h\u00e9llo"[1:2]` is `"\u00e9"`.
3. List, any step: keep the stepped copy that is already there.
4. Range: keep `_range_slice`.
5. Tuple step 1: keep the existing copy. Tuple any other step: the
   error in step 1.

`_list_setslice`: keep the step-1 resize. For any other step, whether
the value is present or `NULL`, raise `NotImplementedError()` with no
argument. Do not write, grow, shrink, or delete the selected indexes.
The pin converts a delete into an empty assignment and then fails the
same `step == 1` test (`py/objlist.c`).

`_barr_setslice`: keep the step-1 rebuild, including the current
`NULL`-as-empty treatment. For a non-NULL value with any other step,
raise the same sentence as the load. Do not implement an extended
assignment. Bytearray **delete** is a separate pin divergence
(`array_subscr` returns "op not supported" for every delete, before it
looks at the step). Leave it. Do not "fix" it in this item.

`str` and `tuple` item assignment stays `TypeError`.

Exit: `slice_str_unicode` is no longer `xfail` and prints `11111`.
`slice_str_scan`, `slice_damerau`, `slice_str_clamp`, `slice_str_empty`,
`slice_str_long`, and `text` keep their current stdout. New programs
below.

### W2 — `__getitem__` iteration

`_getiter` returns before it looks at the type for list, tuple, bytes,
bytearray, dict, set, range, str, and an object that already has
`__iter__` or `__next__`. Do not add a `__getitem__` probe in front of
those arms, and do not add one in `S_GI`.

After `__iter__` and `__next__` miss, and after the existing `_subobj`
fallback misses, load `__getitem__` the same way `__iter__` is loaded
(`_tlookup` plus `_call_member`). If it is present, return an
`OB_ITEROBJ` of type `_ntype(T_ITERATOR)` so `iterator____next__` runs.
Do not add a type id.

Word layout, matching `_str_iter`: word 0 is `OB_ITEROBJ`, word 1 is
the iterator type, word 2 is the object, word 3 is the index starting
at 0, word 4 is `2`. Word 4 is `0` for the UTF-8 walker and `1` for the
sentinel iterator. Test `2` first in `iterator____next__`, then `1`,
then the UTF-8 path. Do not change the UTF-8 path.

Mode 2 calls `__getitem__` with the stored index, then stores the next
index. `IndexError` or `StopIteration` becomes `StopIteration` (the pin's
`it_iternext` in `py/objgetitemiter.c` treats both as the end). Any
other exception propagates. `FOR_ITER` already ends the loop on
`StopIteration`. No new hart state. Both opcodes already reach
`_getiter` (`GET_ITER` directly, `GET_ITER_STACK` from `S_GI_FB`).

### W3 — module attributes

`S_AT_MOD` returns a globals hit as kind 1 and a miss as kind 0. Leave
that. The miss already falls into `_getattr`, whose `OB_MODULE` arm is
empty and then raises `AttributeError`.

Add `_module_attr(mod, name)`. It does not raise on a miss. It returns
the value, or `NULL`.

1. Globals hit: return that value. A stored `__dict__` wins over the
   special case below.
2. The name `__dict__`: return the module globals object, not a copy.
3. Any other miss except the name `__getattr__`: if the globals contain
   `__getattr__`, call it as a function of one argument (the name
   string). Not a method. The pin is `mp_call_function_1` in
   `module_attr`. Exceptions propagate.
4. There is no `MP_REGISTER_MODULE_DELEGATION` table on this device.
   Do not add one.

`_getattr` for `OB_MODULE` calls `_module_attr` and raises
`AttributeError` on `NULL`. `LOAD_METHOD` then uses the bind it already
uses for whatever came back. `IMPORT_FROM` and `IMPORT_STAR` call
`_module_attr` directly so a miss is not an exception.

`STORE_ATTR` on an ordinary module already writes the globals and
rejects a ROM dict. Leave that path. The builtins override in W4 is the
only ROM dict that becomes writable, and only for the builtins dict.

### W4 — imports

`S_QOP` already calls `_import(name, fromlist, level, globals)`,
`_import_from`, and `_import_star`. Keep those signatures. The policy
stays in `modules.py`. There is no POSIX reader. `sys.path` is
`['.', '.frozen']`. Both of those roots consult `_FROZEN`, keyed by the
full dotted name. Any other root is a miss. That is this device's
`mp_import_stat`.

#### Who runs

The builtins dict is ROM (`emit_dict` defaults `rom=True`), so
`_setattr` rejects a store today. On the first store or delete aimed
at that dict, allocate an empty override dict and park it in sysroot
slot `SR_FW7` (27). Nothing else uses that slot. Do not copy the ROM
dict into it.

- A store writes the override.
- A delete removes the key from the override. It does not write `NULL`.
  `mp_obj_dict_delete` raises `KeyError` when the key is absent
  (`py/objdict.c`), and the ROM entry stays. `del builtins.len` without
  a prior override therefore raises `KeyError` and `len` still works.
- `LOAD_ATTR` / `S_AT_MOD` on the builtins module still hits the ROM
  dict first. `builtins.len` after `builtins.len = f` is still the ROM
  `len`. Do not "fix" that. The pin's `module_attr` returns the ROM
  hit before it ever looks at `mp_module_builtins_override_dict`.
- Bare `LOAD_NAME` / `LOAD_GLOBAL` see the override. That probe is W6.
  Until W6 lands, a replaced builtin is visible to `IMPORT_NAME` and
  not yet to a bare name. W4's tests for the bare name are marked as
  waiting on W6 rather than papered over in firmware on the name path.
- `IMPORT_NAME` calls the override's `__import__` when that key is
  present, as `(name, globals, None, fromlist, level)`. Otherwise it
  calls the loader below. The function installed in the ROM builtins
  dict as `__import__` is the loader, not the hook, so an override that
  calls the original builtin does not recurse.

#### Relative name

Follow `evaluate_relative_import` (`py/builtinimport.c`). Do not read
`__package__`.

- `level < 0` raises `ValueError` with no argument.
- `level == 0` and an empty name raises `ValueError` with no argument.
- Otherwise read `__name__` from the globals dict. If it is missing or
  not a str, raise `ImportError("can't perform relative import")`.
- If that string is `__main__` and the dict also has a str under
  `__main__`, use the stored string. Nothing on the device sets it.
  The branch still has to exist.
- If the dict has `__path__`, subtract one from `level` before the walk.
- Walk back that many dots. Running off the front (the cursor lands on
  the first character) raises `ImportError("can't perform relative import")`.
- An empty tail keeps the chopped package name. A non-empty tail appends
  `'.' + name`.

`from . import sub` inside package `pkg` (`__name__ == 'pkg'`,
`__path__` set) resolves to `pkg`, and `IMPORT_FROM` then loads `sub`.
`from .sub import name` inside that package resolves to `pkg.sub`.
The current `_rel_name` pops `level` components and prefers
`__package__`, so the first of those becomes `sub`.

#### Search

Walk the dotted name. `fromlist is None` returns the top component.
Any other fromlist, including `()` and `True`, returns the leaf. Do not
special-case the pin's `fromtuple == False` sentinel. Do not walk the
fromlist names. The compiler emits `IMPORT_FROM`.

For a **top-level** component, in this order (`process_import_at_level`):

1. If `sys.path` is non-empty, a `sys.modules` hit returns immediately.
   An empty path skips the cache. This is how the pin forces a builtin.
   The device path is non-empty unless the user assigns one.
2. Non-extensible builtins, before `_FROZEN`: `sys`, `gc`,
   `micropython`, `usys` (the same object as `sys`), and `builtins`
   (a module whose globals dict is the ROM builtins dict, not a copy).
   Keep that builtins module in a firmware global and return the same
   object every time. Do not spend another sysroot slot on it.
   A longer name that starts with `u`, is not one of those five, and
   whose remainder is in `_NATIVE_MODULES`, returns that native module
   here. A one-character `u` does not. `import uarray` therefore beats
   a frozen module named `uarray`. `import array` does not: a frozen
   `array` is found in step 3. `usys` is the explicit alias, not this
   prefix rule.
3. Each `sys.path` entry. `'.'` then `'.frozen'`. A hit's path string
   is `root + '/' + component` when `root` is non-empty (`./pkg` for
   root `'.'`). A descriptor whose flags word has bit 1
   (`_MD_FLAG_PACKAGE`) is a package. Do not hard-code `.frozen` as the
   prefix. B's `.frozen/<dotted>` is the wrong root: `'.'` is searched
   first and hits the same table.
4. `_NATIVE_MODULES` for the plain name. A frozen module of the same
   name wins, because step 3 already returned.

A non-extensible hit returns the singleton and does not insert a new
`sys.modules` entry. The pin's early return does not either. Do not
pre-seed `sys.modules` in this item.

For a **child** component: do not repeat the non-extensible or `u`-prefix
tests. `MICROPY_MODULE_BUILTIN_SUBPACKAGES` is off at extra features
(it is `EVERYTHING` or `t-strings` only). Skip that ROM-subpackage
shortcut. If the parent's globals have no `__path__`, raise
`ImportError("no module named '<full>'")` with the quotes. Otherwise
stat `parent.__path__ + '/' + component`, still keyed in `_FROZEN` by
the full dotted name.

Publish a newly created module in `sys.modules` before the body, and
set a package's `__path__` to the path string above before the body, so
a relative import inside the body sees a package. `__name__` is the
dotted name. Keep the current `__file__` store. If the body raises,
delete the key this import inserted and reraise. A name that was already
in the cache was returned in step 1 and has no cleanup. If the body
replaces `sys.modules[name]`, the cleanup still removes that key: the
pin's NLR callback removes the qstr unconditionally.

Attach the submodule onto the parent only after the body returns, and
only when this call created the module. A cache hit does not write the
parent. The current `_import` attaches after `_load_mod` even on a hit.
Stop doing that.

#### `IMPORT_FROM` and `IMPORT_STAR`

```text
hit = _module_attr(mod, name)
if hit is not NULL: return it
if the module globals have no __path__:
    raise ImportError("can't import name " + name)   # name not quoted
return _load_import(module.__name__ + '.' + name, True, 0, NULL)
```

Pass `True`, not `()`. `mp_import_from` passes `mp_const_true` so the
leaf comes back, and an override of `__import__` can see that value.
Do not catch `ImportError` from the recursive load. B's rewrite to
`can't import name` drops the pin's `no module named 'pkg.missing'`.
The current `_import_from` catches it. Stop catching it.

`IMPORT_STAR`: if `_module_attr(mod, '__all__')` hits, the value must
be a list or tuple. Anything else raises
`TypeError("object '<type>' isn't a tuple or list")`, which is
`mp_obj_get_array` at normal error reporting. Each entry is loaded with
`_import_from` (so `__getattr__` and submodules run) and stored into the
dict the opcode already passes. A non-string entry raises
`TypeError("can't convert '<type>' object to str implicitly")`, from
`mp_obj_str_get_qstr`. A leading `_` in an `__all__` name is kept. If
`__all__` is absent, keep today's scan of the globals and skip a leading
`_`. `import *` inside a function is a syntax error on this bytecode.
There is no second store path.

### W5 — method resolution

`_c3` stores a C3 linearization on the type. `S_AT_MRO`, `_tlookup`,
and `_super_attr` walk that tuple. The pin does not. `mp_obj_class_lookup`
is depth-first and left to right, skips `object` until the end, and
does not reject a repeated base. `super_attr` restarts that search at
the parents of the class the compiler passed, then searches `object`.

`inherit.py` prints `DBA12` under both orders, because `B` defines `f`
and `B`'s own parents are just `A`. It is not evidence that C3 matches
the pin. This does:

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

The pin prints `1` (`super()` in `D` searches `B`, which finds `A.f`
and never reaches `C`). C3 prints `2`.

Replace `_c3` with a first-visit walk. The tuple is the new class, then
a depth-first left-to-right scan of the bases, dropping a class already
recorded, with `object` last and not in the middle. Do not raise on a
repeated base. Store it in the same word `_make_type` uses now. Do not
add a hart state, and do not walk the parent pointer at attribute time.
`S_AT_MRO` and `_super_attr` keep walking the tuple, so the lookup cost
stays one linear scan of one class per entry. Single inheritance order
does not change, so `inherit.stdout` stays:

```text
BA12 1 2
True True False
DBA12
('B', 'C')
('A',)
```

`S_ISSUB` is membership. Leave it. `_first_native` still walks the
tuple. `class C(list)` must still find `list` as the native base.
Deleting the C3 merge is the area change: the consistency search goes
away, and nothing replaces it on the hit path.

`class C(A, B)` with `B` already a subclass of `A` must succeed. The
current `_c3` raises `TypeError`. The pin accepts it.

### W6 — hart changes

Three edits, all in the existing state machine. Record the cycle gate
before editing.

#### Override probe

One `val_t` flop `bov`, reset to `VNULL`, not part of the frame image
and not a bit in `fflags`. The hart write that stores
`ABI_SYSROOT_BASE + 4 * ABI_SR_FW7` also assigns `bov`. Firmware
`_sysset(SR_FW7, dict)` is then enough. No second protocol.

In `S_LN_L`, when `i2 == 2` and `bov != VNULL`, `lookup` the override
dict first. A hit pushes and goes to `S_FETCH`. A miss falls into the
existing builtins lookup. When `bov == VNULL`, the address mux is the
one there today and no extra state runs. The test is combinational on
the flop. Do not read the sysroot slot on the name-load path. Do not
call firmware for a builtins hit.

After any store or delete on the builtins module the flop is live, and
every later builtins miss-then-hit pays one extra dict probe. That is
the pin (`mp_load_global` checks the override whenever the pointer is
non-NULL). Do not clear the flop when the dict is empty.

#### `with`

`S_SW_X` is the `__exit__` lookup (`ABI_Q_EXIT_D`). Kinds 1 and 2
already push the exit callable and then look up `__enter__` into
`S_SW_E`. Kind 3 currently raises `AttributeError`, so a property
`__exit__` never reaches `__enter__`. Kind 3 at `S_SW_E` is the same
raise for a property `__enter__`.

On kind 3 at either site, call `ABI_HOOK_GETATTR` (it already runs
`_desc_get` and raises `AttributeError` on a real miss). Resume with
the returned callable treated as kind 1: the descriptor has already
bound `self`. Do not jump from the `__exit__` site straight to the
`__enter__` call. The `__exit__` site still has to perform the
`__enter__` lookup. One appended continuation id may distinguish the
two resume points. Do not renumber `ABI_CONT_WITH_TRUTH` or
`ABI_CONT_TRUTH`. Kind 0 stays a miss.

`S_WC_TR` today pushes `None` when `tr_x` or `tr_r` is set. `tr_x`
means `S_TR` could not decide. `0j` takes the default arm of `S_TR` and
sets `tr_x`. It is false on the oracle.

When `tr_x` is clear, keep the current push (`None` when `tr_r`,
otherwise `aux`). When `tr_x` is set, call `ABI_HOOK_TRUTH` with
`fcont = ABI_CONT_WITH_TRUTH`. On return, push `None` only when the
result is `True`. Otherwise push `aux`. Add the arm in `S_CONT`. Today
id 10 hits `default` and halts. Do not send this site through
`ABI_CONT_TRUTH`: that arm re-fetches the opcode and would re-enter the
jump path.

`with_stmt.py` returns `False` and `True`. Both are decided in `S_TR`
with `tr_x` clear, and neither `__enter__` nor `__exit__` is kind 3.
Its stdout stays:

```text
enter
body
exit None
swallow ValueError
continued
```

Its cycle count is part of the gate below. A rewrite that always calls
`_truth`, or that always takes a new state for kind 1 and 2, fails it.

#### Complex equality

`numlike` is int, int64, and float. A complex is not, so two complexes
take `S_EQ`. The identity arm treats equal words as equal for every tag
other than `OBJECT`. A complex NaN compared with itself is therefore
`True`. The pin compares the parts (`py/objcomplex.c`), and a NaN part
makes it false. `_equal` already refuses that shortcut for
`TAG_COMPLEX` and compares the parts.

In the identity condition, also require `tg(t[0]) != ABI_TAG_COMPLEX`.
The existing fall-through to `S_BIN_FB` then calls `_binop`, which uses
`_equal` for `==` and `not _equal` for `!=`. Do not add a complex
comparator. Float equality stays on the ALU. Integer equality stays on
the identity arm.

### W7 — star calls that do not fit in ARGBUF

`CALL_FUNCTION_VAR_KW` (`0x35`) and `CALL_METHOD_VAR_KW` (`0x37`) expand
`*` sequences into ARGBUF. Slot 0 is the callable. A method with a real
`self` uses slot 31 and sets `ab_lo` to 31. Positionals are written at
`ab_pe`, which starts at 32. `S_CVK_L` raises `ABI_ERR_STAR_ARGS` when
`ab_pe >= 200`, so the positional span is slots 32..199. Keywords are
then written at `ab_pe + gi` with no ceiling. The index is 8 bits, so a
long keyword tail wraps into slot 0.

That SRAM buffer stays 256 words (`ABI_ARGBUF_WORDS`,
`ABI_ARGBUF_BASE`). Do not add slots. A wider ARGBUF is powered on
every call, including a call of two arguments. The pin does not have
this buffer. `mp_call_prepare_args_n_kw_var` in `py/runtime.c`
allocates a heap array and passes the pointer to the code state. The
heap tuple is that array.

Calls that fit do not allocate. The compare in `S_CVK_L` is already
there. When it is false, the next state is the one there today. Do not
add a check on `S_CALL`, `S_BF`, or plain `CALL_FUNCTION` /
`CALL_METHOD`. `call_wide.py` (70 explicit arguments, not a star call)
copies through `S_CC_FUN` and must keep its cycle count.

When the next positional would make `ab_pe >= 200`, or the last
keyword word would be stored past slot 255
(`ab_pe + 2 * cv_j > 256`), stop filling ARGBUF. Build two heap tuples
and hand them to `_bind`, which already walks a tuple of whatever
length the heap can hold (`calls.py` `_bind`: `n = len(args)`, then
`args[i]`).

1. Positional tuple. Include slot 31 when `ab_lo` is 31, then every
   positional already stored, then the rest of this star and any later
   positionals. By `S_CVK_L` a star is a tuple or a list: `S_CVK_P`
   has already run `ABI_HOOK_TUPLE` for anything else, and `S_CVK_N`
   has the length in `x4`. Allocate once (`alloc(1 + n)` and the same
   header `S_TUP` writes). Do not grow a list one append at a time, and
   do not call `S_TUP` for this tuple. `tb_n` is 8 bits, so `S_TUP`
   cannot hold the overflow that this path exists for.
2. Keyword tuple. The pairs `S_CVK_KW` would have copied, in the same
   order, including a null key that `_flat_kw` treats as a dict. One
   allocation, same header.
3. Park the tuples in ARGBUF slots 32 and 33, leave the callable in
   slot 0, and set a hart bit `ab_wide`. Then enter `S_CALL` as usual.
   Do not hook `_bind` from `S_CVK_*`. That hook would run in the
   caller's frame. `_bind` runs from `S_BS`, after `S_CF` has opened
   the callee frame, and `ABI_CONT_BIND` writes the locals into that
   frame. `ab_lo`, `ab_pe`, and `ab_nkw` are hart registers and already
   survive `S_CF_SW`. `ab_wide` is the same kind of register. It is not
   a bit in `fflags`.
4. `S_CF_CHK` is `c_fast <= !ab_wide &&` the condition already there.
   `ab_wide` is clear on every call that fits, so the fast binder does
   not gain a state. When the bit is set, `S_BS` reads slots 32 and 33
   and hooks `_bind` with those tuples, skipping `S_TUP`. Clear
   `ab_wide` before that hook. The firmware `_bind` makes its own
   calls, and those must see the bit clear.
5. `S_CALL_BS` prepends a bound-method `self` by writing `ab_lo - 1`.
   When `ab_wide` is set, that write is the wrong shape: `self` has to
   be the first item of the positional tuple. Allocate one new tuple,
   write `self` at index 0 and copy the old tuple after it, store it
   back in slot 32, then continue to the underlying function. The
   `ab_lo <= 2` raise on that arm stays for the non-wide path.

`S_BF` does not learn a second representation. It stays an 8-bit walk
of a contiguous ARGBUF span.

A failure to allocate is `MemoryError`, from the existing allocator.
Delete the `RuntimeError("too many arguments")` result on this path.
The other `ABI_ERR_STAR_ARGS` sites stay: `ab_lo <= 2` while prepending
`self`, a closure cell, or `__new__` on the non-wide path, and the
`> 224` check on plain `CALL_FUNCTION` / `CALL_METHOD` in `S_EXEC`.
Those are not this opcode.

The tuple pointers are GC roots only while they sit in `t[]` or ARGBUF.
Do not leave one only in a scratch register across `alloc`.

Exit: a function `def f(*a): return len(a)` called with a star of 200
ones returns `200`. A method `def m(self, *a)` called the same way
returns `200` and sees the instance as `self`. `def f(**k): return len(k)`
with 113 explicit keyword pairs returns `113` (no positionals: the last
pair would be stored past slot 255). A bound method `obj.m(*star)` of
that length still receives `obj` as `self`. `call_function_ex`,
`call_function_ex_kw`, `varargs`, `print_star`, and `call_wide` keep
their stdout and their `cycles=` numbers.

## Tests

New programs live under `upycore/programs/hw/` and get a row in
`upycore/programs/hw_tests.toml`. Programs that only need builtins are
`oracle = true`. Their `.stdout`, `.stderr`, and `.exit` come from
`make regen-goldens` (or one
`python3 upycore/tools/hw_tests.py --regen <name>`), not from a
hand-copied guess. Frozen-module programs stay `oracle = false`, same
as `use_pkg` and `use_rel`: the unix port has no filesystem imports.
Write those goldens from the rules in W4 and do not regen them.

Firmware is always compiled with `mpy-cross`. Also run the touched
names with `--compiler mpyc`.

### Per item

W1. Remove the xfail on `slice_str_unicode`. Add:

- `slice_str_step`: `"ab"[::2]` and `b"ab"[::2]` and `(1, 2)[::2]` and
  `bytearray(b"ab")[::2]` raise `NotImplementedError` with
  `only slices with step=1 (aka None) are supported`.
- `slice_list_step`: `[1, 2, 3][::2]` stays `[1, 3]`.
  `a = [1, 2, 3]; a[::2] = [7, 8]` raises `NotImplementedError` with
  empty args, and `a` is still `[1, 2, 3]`. Same for `del a[::2]`.

```text
python3 upycore/tools/hw_tests.py slice_str_unicode slice_str_step slice_list_step slice_str_scan slice_damerau slice_str_clamp text
```

W2. `getitem_iter`: a class with `__getitem__` and no `__iter__` yields
`0, 1` and stops when index 2 raises `IndexError`. A `__getitem__` that
raises `ValueError` propagates `ValueError`. A class with `__iter__`
does not use the fallback. `for_iter` and `for_iter_nested` stay green.

W3 and W4. Frozen, `oracle = false`:

- `from . import sub` and `from .sub import name` from a package
  `__init__`. `__path__` on that package prints `./pkg` (root `'.'`,
  not `.frozen`).
- `from . import x` in `__main__` raises `ImportError: can't perform relative import`.
- A body that raises is absent from `sys.modules`, and a later import
  runs the body again.
- A module with `__all__ = ('a',)` exports `a` and not a public `b`.
  No `__all__` still hides `_c`.
- A module `__getattr__` answers `mod.missing` and
  `from mod import missing`. `mod.__dict__` is the globals dict.

Oracle, `oracle = true`:

- `import usys` is `sys`. `import builtins` is a module, and
  `builtins.len is len`.
- `builtins.__import__ = f` makes the next `import` call `f`.
  Reading `builtins.__import__` after the assignment is still the
  original function. `f` calling that original returns, and does not
  recurse.
- The bare-name half (`len` after `builtins.len = f`, then `del
  builtins.len` restores `len`) is part of the same program but is
  expected to fail until W6. Split it into `builtins_override_name` and
  do not mark the import half xfail to cover it.

Keep `import_missing`, `use_pkg`, and `use_rel` green.

```text
python3 upycore/tools/hw_tests.py import_missing use_pkg use_rel <new import names>
```

W5. `mro_diamond` is the `D(B, C)` program above and prints `1`.
`mro_repeat` is `class C(A, B)` with `B` a subclass of `A`, and
`C().f()` prints `A`. `inherit` stdout is unchanged.

```text
python3 upycore/tools/hw_tests.py inherit mro_diamond mro_repeat
```

W6. `with_prop`: `__enter__` and `__exit__` are properties. The enter
property runs. `__exit__` returning `0j`, `0`, or a `__bool__` of
`False` does not swallow. Returning `True` or `1` does. A missing
`__enter__` still raises `AttributeError`.

`complex_nan_eq`: `complex(float('nan'), 1) ==` itself is `False`, and
`!=` is `True`. `complex(1, 2) == complex(1, 2)` stays `True`. Existing
`complex` and `complex_ops` stdout stays. Do not touch
`complex_type_trap`. That xfail is the `complex` constructor, not a
bytecode.

`with_stmt` stdout stays as quoted in W6.

W7. `star_wide` is the 200-ones function, the method, the bound
method, and the 113-keyword call, from the W7 exit. `oracle = true`.

```text
python3 upycore/tools/hw_tests.py star_wide call_function_ex call_function_ex_kw varargs print_star call_wide
```

The last five must print the same `cycles=` as they did before the
`S_CVK_*` edit.

### Cycle gate

Run this before editing `mpy_core.sv`, and again after W6. The
`cycles=` numbers must match. These programs do not assign to
`builtins`, do not take a property `__enter__`, and do not compare a
complex with itself. A builtins probe that reads SRAM on the empty
path, or a `with` rewrite that adds a state to the kind-1 path, shows
up here.

```text
python3 upycore/tools/hw_tests.py arith loops compare with_stmt
```

`inherit` and `complex` are stdout gates, not cycle gates. Class
creation changes when W5 replaces `_c3`. Complex identity equality
moves to `_equal` and is allowed to cost more. Integer and float
equality are not.

### Done

W6's cycle gate matches, and:

```text
python3 upycore/tools/hw_tests.py --area alu --area strings --area objects --area modules --area exceptions --area control
python3 upycore/tools/hw_tests.py --compiler mpyc --area alu --area strings --area objects --area modules --area exceptions --area control
make test-hw
```

`make test-hw` is required because W6 and W7 edit the core. The area runs
are the ones that contain the new programs. A failure outside those
areas, found by `make test-hw`, is a regression of a fast path and
blocks the RTL change.

## Left alone

- `RAISE_FROM`. The warning string is already `_warn` in `boot.py`.
- Plain `CALL_FUNCTION` and `CALL_METHOD` above 224 explicit words.
  That raise is in `S_EXEC`, not in the star expander. W7 does not move it.
- Positive and integral powers on the ALU, and `_cpow` for the
  negative-base fallback. Do not replace the five helpers in
  `floatfmt.py`. They are shared with formatting
  ("accurate enough for the values the arithmetic tests print").
- `BUILD_SLICE` always allocating. The pin's peek at the next opcode
  is a speed path. The subscript still sees a slice.
- Bytearray slice delete, as noted in W1.
- Every opcode the three proposals list as full, except the MRO walk
  behind `LOAD_ATTR`, `LOAD_METHOD`, `LOAD_SUPER_METHOD`, and
  `LOAD_BUILD_CLASS`, and the complex identity arm of `BINARY_OP`.
  Those four attribute opcodes do not grow hart states. Only the tuple
  they walk changes.

## Pin files

Read these before editing the matching work item. Do not copy opcode
numbers or bit masks out of them into a new table.

| Item | Pin | Device |
| --- | --- | --- |
| W1 | `py/objlist.c` `list_subscr`, `py/objarray.c` `array_subscr`, `py/objstrunicode.c` `str_subscr`, `py/objtuple.c`, `py/sequence.c` `mp_seq_get_fast_slice_indexes` | `_getslice`, `_list_setslice`, `_barr_setslice` |
| W2 | `py/runtime.c` `mp_getiter`, `py/objgetitemiter.c` | `_getiter`, `iterator____next__`, `S_GI_FB` |
| W3 | `py/objmodule.c` `module_attr` | `_getattr`, `S_AT_MOD` |
| W4 | `py/builtinimport.c` `evaluate_relative_import`, `process_import_at_level`; `py/runtime.c` `mp_import_name`, `mp_import_from`, `mp_import_all`, `mp_load_global`; `py/objmodule.c` `mp_module_get_builtin` | `_import`, `_rel_name`, `_load_mod`, `_import_from`, `_import_star` |
| W5 | `py/objtype.c` `mp_obj_class_lookup`, `super_attr` | `_c3`, `_super_attr`, `S_AT_MRO` |
| W6 | `py/objcomplex.c` `MP_BINARY_OP_EQUAL`; `py/vm.c` `MP_BC_RAISE_FROM` is the leave-alone check | `S_EQ`, `S_SW_X`, `S_SW_E`, `S_WC_TR`, `S_CONT`, `S_LN_L` |
| W7 | `py/runtime.c` `mp_call_prepare_args_n_kw_var` | `S_CVK_L`, `S_CVK_KW`, `_bind` |
