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
