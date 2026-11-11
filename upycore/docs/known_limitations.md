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

## Dictionary update entries (review finding 7)

`upycore/firmware/dicts.py::dict__update` indexes each generic entry at 0 and 1
without checking its length. `dict([(1, 2, 3)])` currently returns `{1: 2}`;
the pinned oracle raises `ValueError('dict update sequence has wrong length')`.
Iterator-only pairs are also not handled like the reference implementation.

A future fix should consume exactly two values and require exhaustion before
inserting the pair, following the vendored `py/objdict.c`.

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
