# Ported from pycore pycore/programs/img_raise_syntaxerror_fatal.py.
"""An unhandled raise is fatal: PY_TRAP_RAISE (17).

The exception-table walk finds no handler, so the machine halts rather than
silently continuing.
"""


def managed_entry():
    raise SyntaxError

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
