# Ported from pycore pycore/programs/img_try_except_else.py.
"""try/except/else: fall through to else only when no exception is raised."""


def choose(should_raise):
    value = 0
    try:
        if should_raise:
            raise TypeError
    except TypeError:
        value += 10
    else:
        value += 1
    return value


def managed_entry():
    return choose(False) + choose(True)

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
