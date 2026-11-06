# Known runtime limitations

These two review findings remain open by request. They are not hidden behind
expected-failure or disabled entries in the acceptance suite.

## Integer text parsing (review finding 4)

`upycore/firmware/builtins.py::_parse_int` differs from the pinned MicroPython
parser in these cases:

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

## Standard-library modules in Python (perf_bench coverage)

`math`, `cmath`, `random` and `io` are frozen Python modules in
`upycore/runtime/`, linked only into programs that import them. They differ
from the pinned unix oracle in these documented ways:

| Area | Device | Oracle | Why |
| --- | --- | --- | --- |
| `math.sin`, `cos`, `tan`, `exp`, `log`, `log2`, `log10` | Ports of the pinned `lib/libm` binary32 routines (what bare-metal MicroPython ports use); within 1 ulp of the oracle, bit-identical for about 90–99% of arguments | The host's glibc functions | Matching glibc to the last bit would need extended precision on every call. `math.sqrt` is correctly rounded and bit-identical |
| `math` coverage | No `acos`, `asin`, `atan`, `atan2`, `acosh`, `asinh`, `atanh`, `cosh`, `sinh`, `tanh`, `expm1`, `erf`, `erfc`, `gamma`, `lgamma`, `fmod` | Full | Not needed by perf_bench yet |
| `cmath` coverage | `pi`, `e`, `rect`, `exp` | Also `phase`, `polar`, `log`, `log10`, `sqrt`, `cos`, `sin` | These need `atan2` |
| `random.seed()` with no argument | `ValueError('no default seed')`; unseeded state is the fixed yasmarang start | Seeds from urandom on import | The device has no entropy source; MicroPython raises the same error on such ports. Seeded sequences are bit-identical |
| `random.uniform` | `a + (b - a) * f` in binary32 | The i686 build evaluates it in x87 extended precision | Can differ by 1 ulp; `random()` and the integer functions are exact |
| `io.IOBase` | A plain base class | Hooks the C stream protocol | The device has no C stream protocol |

## memoryview

`memoryview` is a native type implemented in firmware (`upycore/firmware/memview.py`).

- `hash(m)` raises `TypeError` as in MicroPython, but a view used as a dict or
  set key gets an identity hash from the RTL hash engine instead of raising.
- `str == memoryview` is `False`; the oracle compares the bytes. A view on
  the left, or `bytes`/`bytearray` on the left, compares like the oracle.
- After a bytearray reallocates, a view keeps the old block, like
  MicroPython's raw pointer, but the device's old block stays valid while the
  view lives, where MicroPython's may already be reused.
