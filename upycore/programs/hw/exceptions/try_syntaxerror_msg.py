# Ported from pycore pycore/programs/img_try_syntaxerror_msg.py.
"""Error reporting via SyntaxError args (F4). Expected: 2."""


def managed_entry():
    try:
        raise SyntaxError("hi")
    except SyntaxError as e:
        return len(e.args[0])

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
