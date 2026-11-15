# Known runtime limitations

These are the known differences from the pinned oracle. They are not hidden behind
expected-failure or disabled entries in the acceptance suite.

## Integer text parsing (review finding 4)

The default signed-64-bit profile's `_parse_int` differs from the pinned
MicroPython parser in these cases:

| Expression | Current device behavior | Pinned oracle behavior |
| --- | --- | --- |
| `int('0xff', 16)` | `ValueError` | `255` |
| `int('010', 0)` | `10` | `ValueError` |
| `int('-9223372036854775808')` | `OverflowError` | signed 64-bit minimum |

Prefixes are consumed only for base zero, base zero does not reject unprefixed
nonzero leading-zero numbers, and positive accumulation cannot represent the
magnitude of the signed minimum. A future fix should follow the vendored
`py/parsenumbase.c` and `py/parsenum.c`, including overflow boundaries.

## Dictionary update entries

A tuple or a list used as a dict-update pair must have length 2.
`dict(((1,),))`, `dict(((1, 2, 3),))` and `dict([[1]])` raise
`ValueError('dict update sequence has wrong length')`, as in `py/objdict.c`.

A pair that is not a tuple or a list is still read with `[0]` and `[1]`.
The oracle walks that pair with an iterator and raises the same `ValueError`
unless the walk yields exactly two values. A custom iterator of the wrong
length can still be stored, or can raise from the subscript, instead of that
`ValueError`. The length test is only the one word a tuple or a list already
stores, so a dict-to-dict update does not take it.

## `str()` of a string returns the same object (deliberate)

`str(s)` with one argument that is already a `str` returns `s` itself, in the
core (`S_CALL_STR`) and in the firmware fallback (`fmt.py::_str`). The pinned
oracle always builds a new string (`py/objstr.c`: `mp_obj_str_make_new` prints
the argument into a buffer, `mp_obj_new_str_type_from_vstr` searches the
interned strings with `qstr_find_strn` and returns the qstr when the text is
interned, else a new copy). Values are always equal; only identity differs:

| Expression (`s` a non-interned `str`) | Device | Pinned oracle | CPython |
| --- | --- | --- | --- |
| `str(s) == s` | `True` | `True` | `True` |
| `str(s) is s` | `True` | `False` | `True` |

Python does not specify whether `str(s)` is a new object; the device follows
CPython and skips the copy, the search and the allocation. More generally the
device never interns a string built at run time (concatenation, formatting,
`str()` of other objects), where MicroPython returns the interned qstr when
one with the same text exists, so `is` between such a string and an equal
literal can differ the same way.

Benchmarks: perf_bench `core_qstr` times exactly this call
(`str("a string that shouldn't be interned")`, 400 times) to measure
`qstr_find_strn` when the string is not found. On the device it does no
search, so its ratio against the boards (29x to 52x) compares different work;
`docs/paper/README.md` says how it is reported.

## Standard-library modules in Python (perf_bench coverage)

`math`, `cmath`, `random` and `io` are frozen Python modules in
`upycore/runtime/`, linked only into programs that import them. They differ
from the pinned unix oracle in these documented ways:

| Area | Device | Oracle | Why |
| --- | --- | --- | --- |
| `math.sin`, `cos`, `tan`, `exp`, `log`, `log2`, `log10` | Ports of the pinned `lib/libm` binary32 routines (what bare-metal MicroPython ports use); within 1 ulp of the oracle, bit-identical for about 90–99% of arguments | The host's glibc functions | Matching glibc to the last bit would need extended precision on every call. `math.sqrt` is correctly rounded and bit-identical |
| `math` and `cmath` additional numerical routines | All functions exported by the pinned port are available. Binary32 evaluation of composed formulas, especially `gamma`, `lgamma`, and `erfc`, can differ from the oracle by more than one ulp | The host's glibc functions | The firmware rounds intermediate operations to binary32. |
| `random.seed()` with no argument | `ValueError('no default seed')`; unseeded state is the fixed yasmarang start | Seeds from urandom on import | The device has no entropy source; MicroPython raises the same error on such ports. Seeded sequences are bit-identical |
| `io.IOBase` | A plain base class | Hooks the C stream protocol | The device has no C stream protocol |

## memoryview

`memoryview` is a native type implemented in firmware (`upycore/firmware/memview.py`).
Views over `array.array` share the packed backing storage and index by
element. All documented numeric array formats are available. As on the
pinned long-long port, reading an unsigned 64-bit element outside the signed
integer range raises `OverflowError`. The `d` format uses binary64 storage
and exposes values as binary32 Python floats. The optional unsafe object
and pointer formats are omitted.

- `hash(m)` raises `TypeError` as in MicroPython, but a view used as a dict or
  set key gets an identity hash from the RTL hash engine instead of raising.
- `{}[:] = {}` succeeds. `hash(slice(None))` raises `TypeError` (a slice is
  unhashable) and the oracle raises `TypeError` from the store. Dict lookup
  hashes an object key in `mpy_hash.sv` with an identity hash and does not
  read the object kind, so the slice is stored under that hash. Rejecting it
  would add a kind check to every object-key insert. `hash()` of a slice
  still raises. This is the same identity-hash path as a memoryview key.
- `str == memoryview` is `False`; the oracle compares the bytes. A view on
  the left, or `bytes`/`bytearray` on the left, compares like the oracle.
- After a bytearray reallocates, a view keeps the old block, like
  MicroPython's raw pointer, but the device's old block stays valid while the
  view lives, where MicroPython's may already be reused.

## Float constants folded by the host compiler

`mpy-cross` (and host uPy2, which matches it byte for byte) folds constant
float expressions in binary64 and writes the result's text into the `.mpy`;
the device reads that text as binary32. The oracle folds in binary32. So a
folded expression can land one ulp away: `1/3` is `0.3333333` on the device
and `0.33333334` on the oracle, and `1/3 == 1.0/3.0` is `False` on the
device. Computing at run time (`one / 3.0` with `one = 1.0` in a variable)
gives the oracle's value. Fixing it means folding in binary32 in both
compilers: building `mpy-cross` with `MICROPY_FLOAT_IMPL_FLOAT` alone breaks
uPy2's byte-exact contract with `mpy-cross`.

## MicroPython MPZ profile

The default firmware follows the pinned signed-64-bit MicroPython profile.
`mpy_build.py run --bigint` enables the arbitrary-precision profile. The
core promotes overflowing integer arithmetic to firmware. Wide values are
`int` objects with packed 30-bit limbs under the existing `OBJECT` tag.
The RTL runs common wide add, subtract, and scalar multiply bytecodes
directly through the existing limb datapath. For same-sign division it
can certify the quotient from the leading limbs. Cases outside these
fast paths use the general firmware arithmetic.

The profile covers signed arithmetic, comparisons, shifts, bitwise
operations, two- and three-argument `pow`, `divmod`, integer formatting,
hashing, full-width byte conversions, and float and complex interoperation.
Machine-word arguments follow the 32-bit oracle's bounds. The general
runtime and binary32 formatting limitations documented here also apply to
the MPZ profile.

Build the matching 32-bit MicroPython MPZ oracle and run the unmodified
vendored benchmark:

```sh
make oracle-mpz
python3 upycore/tools/mpy_build.py sim
python3 upycore/tools/hw_tests.py --check-goldens bigint
python3 upycore/tools/perf_inventory.py --bigint --only bm_pidigits \
    --points 32x10,50x25,100x100
```

## Complex power

`complex ** x` and a negative float to a fractional power follow
`py/objcomplex.c` with the binary32 `lib/libm` kernels (`logf`, `expf`,
`sinf`, `cosf`, `atan2f`); the oracle uses its host libm. Results agree to
within a few ulp, not always to the last bit. `abs(complex)`, complex `+`,
`-`, `*`, `/` and `==` match the oracle exactly.

## Modules

Built in: `array`, `gc`, `micropython`, `sys`, plus the frozen `math`,
`cmath`, `random` and `io` above. Not available (the oracle has them):
`struct`, `collections`, `time`, `json`, `re`, `errno`, `heapq`,
`binascii`, `hashlib`, `os`, `machine`.

The frozen runtime modules are linked only into programs whose source
imports them with a plain `import` or `from ... import`
(`upycore/tools/mpy_build.py`, `runtime_imports`). `__import__('math')`,
`exec('import math')` or an on-device `compile` of an import raise
`ImportError` unless the program also imports the module itself.

## Integers

`divmod` of two ints outside the 31-bit small-int range returns the
quotient and remainder; the oracle's long-long build raises
`TypeError: unsupported types for __divmod__`.

## System

- The heap is at most `GC_TABLE_BYTES` (19,200 16-byte blocks, 300 KiB),
  the largest heap a real image leaves; a smaller image does not raise it.
- There is no UART, GPIO, timer or interrupt: `mpy_periph` is unit-tested
  but not part of `mpy_soc`. Output is the console byte port.
- The collector is conservative over its root windows (frames, the
  scheduler/handler/system words and `ARGBUF`). A stale word there can keep
  an unreachable block alive until it is overwritten.

## Programs the default profile does not link

The default firmware is the pinned signed-64-bit profile. A literal outside
that range is rejected at link time, before the core runs. These programs
link on the MPZ profile (`mpy_build.py run --bigint`) and do not link here:

`basics/int_big1.py`, `int_big_and.py`, `int_big_and2.py`, `int_big_and3.py`,
`int_big_cmp.py`, `int_big_div.py`, `int_big_error.py`, `int_big_lshift.py`,
`int_big_mod.py`, `int_big_or.py`, `int_big_or2.py`, `int_big_or3.py`,
`int_big_pow.py`, `int_big_rshift.py`, `int_big_to_small.py`,
`int_big_to_small_int29.py`, `int_big_unary.py`, `int_big_xor.py`,
`int_big_xor2.py`, `int_big_xor3.py`, `int_big_zeroone.py`,
`float/int_big_float.py`.

`basics/try_except_break.py` nests 22 exception blocks. A frame holds 16,
so the link fails. The oracle runs it.

## Programs that do not finish

`basics/builtin_pow3_intbig.py` is still running at the 400,000,000 cycle
limit on the MPZ profile. It reached the same limit before these fixes.
The non-bigint `builtin_pow3.py` matches the oracle.

## Tracebacks

An uncaught exception is printed on stderr, with the same text the oracle
prints on stdout. `upycore/docs/mpy_io_core.md` and the hardware goldens
follow that split. A comparison that requires the traceback on stdout
disagrees for every program that ends in an uncaught exception, including
programs whose exception type and message match.

`basics/async_await2.py`, `async_for2.py` and `async_with2.py` are that
case and nothing else. `sys.implementation.name` is not `'micropython'`,
so each one imports `types`, and both the device and the oracle raise
`ImportError: no module named 'types'`. The device writes that traceback
on stderr. The image has no `types` module.

## Modules and names the image does not provide

On top of the modules listed above, these imports fail. The oracle has them.

| Missing name | Programs |
| --- | --- |
| `collections.deque` | `basics/deque1.py`, `deque2.py`, `deque_micropython.py`, `deque_slice.py` |
| `collections.OrderedDict` | `basics/ordereddict1.py`, `ordereddict_eq.py`, `class_ordereddict.py`, `slice_optimise.py` |
| `collections.namedtuple` | `basics/namedtuple1.py`, `class_store_class.py`, `tuple_subclass.py` |
| `errno` | `basics/errno1.py`, `dict_fixed.py` |
| `struct` | `basics/struct1.py`, `struct1_intbig.py`, `struct2.py`, `struct_endian.py`, `struct_micropython.py`, `float/float_struct.py`, `float_struct_e.py`, `float_struct_e_doubleprec.py`, `float_struct_e_fp30.py`, `float2int_intbig.py`, `float2int_fp30_intbig.py`, `float2int_doubleprec_intbig.py` |
| `re` | `basics/class_setname_hazard_rand.py` |
| `machine` | `basics/subclass_native_call.py` |
| `uctypes` | `basics/memoryview_slice_size.py` |
| `string.templatelib` | `basics/string_module_tstring.py`, `string_tstring_basic.py`, `string_tstring_constructor.py`, `string_tstring_constructor1.py`, `string_tstring_errors1.py`, `string_tstring_operations.py`, `string_tstring_parser1.py` |
| `traceback` | `basics/sys_tracebacklimit.py` |

The same missing template-string type is why
`basics/string_tstring_basic1.py`, `string_tstring_format1.py` and
`string_tstring_interpolation1.py` disagree.

Two attributes are missing on types the image does have:

- `slice.indices` (`basics/slice_indices.py`). `slice` itself exists.
  `slice_op.py` is the identity-hash case in the memoryview section.
- A function's `__globals__` (`basics/fun_globals.py`). `hasattr` is false,
  so the rest of that program does not run. The oracle exposes the dict.

## Integer parsing and formatting

The three parser cases in the table above are what `basics/int_parse.py`,
`int1.py`, `int_64_basics.py` and `python36.py` still trip on. `python36.py`
also parses a leading-zero octal literal differently, the same base-zero
rule as `int('010', 0)`.

`basics/builtin_str_hex.py` and `int_big_mul.py` still disagree on integer
text. `int_big_mul.py` multiplies into the range the default profile cannot
represent the way the long-long oracle does; the product and its text differ.
`divmod` of two ints outside the 31-bit small-int range is the case in the
Integers section above.

## Strings, bytes and formatting

`%` formatting of a `str` matches the oracle for `string_format_modulo.py`.
These do not:

- `%+d` and `% d` print the digits without the sign or the leading space.
  `%#x` raises `ValueError: unsupported format character` because the `#`
  flag is recognised only on the MPZ profile.
  Programs: `basics/string_format_modulo_int.py`,
  `float/string_format_modulo.py`, `float/string_format_modulo2_intbig.py`.
- A `bytes` format returns a `str`. `b'%'` is `'%'`, and `%r` of a string
  does not keep the `b` prefix. Program: `basics/bytes_format_modulo.py`.
- `str.format` width and alignment pad on the wrong side, and a float
  precision such as `{:10.4}` prints `123.456` where the oracle prints
  `123.5`. Programs: `basics/string_format.py`, `string_format2.py`,
  `string_format_cp310.py`, `string_format_error.py`,
  `string_format_intbig.py`, `string_format_sep.py`,
  `float/string_format.py`, `float/string_format2.py`.
- An f-string drops zero-padding (`00000001` prints as `       1`) and the
  debug form differs. Programs: `basics/string_fstring.py`,
  `string_fstring_debug.py`, `float/string_fstring.py`.

Other string and bytes methods that still disagree:

| Program | What differs |
| --- | --- |
| `basics/string_count.py`, `bytes_count.py` | The count does not match. The call returns. |
| `basics/string_split.py` | `MemoryError` on a split the oracle completes. |
| `basics/string_rsplit.py`, `bytes_split.py` | Split results differ. |
| `basics/string_startswith.py`, `string_endswith.py` | A tuple of prefixes, or a span, does not match. |
| `basics/string_partition.py`, `string_rpartition.py`, `bytes_partition.py` | The 3-tuple differs. |
| `basics/string_replace.py`, `bytes_replace.py` | The replacement count or the result differs. |
| `basics/string_strip.py`, `bytes_strip.py` | A custom character set does not strip the oracle's set. |
| `basics/string_repr.py` | `repr` of a non-ascii string differs. |
| `basics/bytes.py`, `bytes_construct.py` | Constructing `bytes` from an iterable or a mix of types differs. |
| `basics/bytearray1.py`, `bytearray_append.py`, `bytearray_byte_operations.py` | Bytearray ordering (`__le__` and the other orderings) is unsupported, so a comparison raises `TypeError` where the oracle orders the bytes. |
| `basics/bytearray_center.py`, `bytearray_partition.py` | Centering and partition results differ. |
| `basics/bytes_add_array.py`, `bytes_add_endian.py`, `bytes_compare_array.py` | Adding or comparing `bytes` and an `array` differs. `array` is present; the element conversion is not the oracle's. |

`find`, `rfind`, `index` and `rindex` accept `None` for a missing start or
end, treat `True` and `False` as `1` and `0`, and reject a byte needle
outside 0..255. `basics/string_find.py`, `string_rfind.py`, `string_index.py`,
`string_rindex.py`, `bytes_find.py` and `bytes_index.py` match the oracle.

## Floats and complex numbers

Signed zero is lost when a float is formatted. `float/float_divmod.py` prints
`0.00000000` where the oracle prints `-0.00000000`. `_format_float` records
the sign and then the negation of `-0.0` is `0.0`, so the sign does not
survive. The quotients and remainders are otherwise the same.

`float/float1.py`, `float_dunder.py` and `float_parse.py` still disagree on
float text, parsing, or a dunder result. `float_parse.py` is the float side
of the integer parser gap above. Constant folding is the separate case in
the compiler section above.

`float/complex1.py`, `complex_dunder.py` and `cmath_dunder.py` still disagree.
`complex **` and a negative float to a fractional power are the ulp gap in
the Complex power section. `cmath_fun.py`, `math_fun.py`, `math_domain.py`
and `math_domain_python311.py` are the binary32 `math` and `cmath` gap in
the standard-library section: a domain error's message, or a value more than
the test's tolerance from glibc, still fails the program.

## Arrays

`array` is built in. These programs still disagree with the oracle on element
width, an integer that does not fit the typecode, or `repr`:

`basics/array1.py`, `array_intbig.py`, `array_int_repr.py`,
`array_limits_intbig.py`, `array_micropython.py`.

`basics/memoryview_itemsize.py` reads `itemsize` of a view over an array and
does not match.

## Subclasses of a native type

A subclass of `tuple` or `list` does not take the native comparison or the
native constructor the way the oracle does.

- `basics/subclass_native_cmp.py`: `(1, 2, 3) == mytuple((1, 2, 3))` is
  `False`, and `(1, 2, 3) <= t` raises
  `TypeError: unsupported types for __le__: 'tuple', 'mytuple'`. The oracle
  compares the elements.
- `basics/subclass_native_init.py`: a second `list.__init__` on the same
  subclass instance appends, so the list is `[0, 1, 2, 3, 4, 0, 1]` where
  the oracle has `[0, 1]`.
- `basics/subclass_native1.py` does not raise the two trailing `TypeError`s
  the oracle raises.
- `basics/subclass_native2_list.py`, `subclass_native2_tuple.py`,
  `subclass_native_buffer.py`, `subclass_native_iter.py` and
  `subclass_native_str.py` are the same gap on iteration, the buffer
  protocol, `str`, and the list and tuple constructors.

Reflected comparison of a native value against a user instance is the case
`special_comparisons.py` covers, and that program matches. These subclass
programs are the native method, not that reflected call.

## Classes, descriptors and built-ins

| Program | Device | Oracle |
| --- | --- | --- |
| `basics/class_descriptor.py` | `'str' object has no attribute '__class__'` while walking a descriptor | The descriptor runs |
| `basics/class_dict.py`, `class_delattr_setattr.py` | Attribute and dict updates on a class do not match | The oracle's class dict |
| `basics/class_bind_self.py` | Binding `self` on a method does not match | A bound method |
| `basics/class_staticclassmethod.py` | `staticmethod` / `classmethod` call or print differs | The oracle's wrappers |
| `basics/class_setname_hazard.py` | `__set_name__` during class creation differs | The oracle's order |
| `basics/builtin_dir.py` | `dir()` text differs | The oracle's listing |
| `basics/builtin_help.py` | `help()` text differs | The oracle's help |
| `basics/builtin_override.py` | Replacing a builtin does not hide the old one the way the oracle does | The override is visible |
| `basics/builtin_sorted.py` | Sort result or key handling differs | The oracle's order |
| `basics/builtin_property.py` | A property call raises or returns a different value | The property runs |
| `basics/builtin_compile.py`, `lexer.py`, `syntaxerror.py`, `try_error.py`, `fun_error.py` | The on-device compiler and lexer report `SyntaxError` with different text (`lexer.py` reports `byte 0`) | The host parser's message |
| `basics/builtin_eval_buffer.py`, `builtin_exec_buffer.py` | `eval` / `exec` of a buffer object differs | The oracle reads the buffer |
| `basics/special_methods2.py` | A later special-method case still differs. `__int__` returning a non-int raises, and that part of `special_methods.py` matches | The oracle's result |
| `basics/list_index.py` | The `ValueError` path of `list.index` differs | `ValueError` |
| `basics/gc1.py` | An `AssertionError` from a collection count | The oracle's counts. The heap limit in the System section bounds what this test can observe |

`super()` rejects a non-type first argument and a second argument that is
not an instance or a subtype of the first, and `str(super())` starts with
`<super: <class '...'`. `basics/builtin_super.py` and `class_super.py` match.

`hash({}.keys())` and `hash({}.items())` raise `TypeError`.
`hash({}.values())` is an int. `basics/dict_views.py` matches. The kind test
runs only while hashing an object, which is the same firmware hand-off
already used for a bound method.

## `sys`, modules and `io`

`sys` is a real module and it is not frozen read-only.

- `basics/sys1.py`: `sys` has no `__name__`.
- `basics/module2.py`: `sys.x = 1` stores the attribute. The oracle raises
  `AttributeError` because its `sys` dict is read-only.
- `basics/sys_stdio.py`, `sys_stdio_buffer.py`, `attrtuple1.py`:
  `sys.stdin`, `sys.stdout` and `sys.argv` are not the oracle's stream
  objects, and an attribute tuple does not print the same way.
- `basics/sys_exit.py`, `sys_path.py`, `module1.py`, `module_dict.py`,
  `import_instance_method.py`: exit status, `sys.path`, the `__main__`
  module and a module dict still differ.
- `basics/io_stringio1.py`, `io_stringio_base.py`, `io_write_ext.py`:
  the frozen `io` module's `StringIO` and stream base are Python classes.
  The oracle's `io` is the C stream protocol described in the
  standard-library section, so writes, `seek` and the base class differ.

## What this list is

The sections above are the remaining differences from `tests/basics` and
`tests/float` against the pinned MicroPython v1.29.0 unix oracle, plus the
deliberate choices earlier in this file. A program not named here matched
that oracle on stdout and exit status, with tracebacks on stderr as
described above. `special_comparisons.py` matches and finishes under
400,000,000 cycles.
