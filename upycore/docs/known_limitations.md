# Known runtime limitations

These are the known differences from the pinned oracle. They are not hidden behind
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
