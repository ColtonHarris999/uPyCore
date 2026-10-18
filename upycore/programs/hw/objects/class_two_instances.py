# Ported from pycore pycore/programs/img_class_two_instances.py.
"""M4: two instances have independent __dict__ values."""


class Box:
    def set(self, v):
        self.v = v

    def get(self):
        return self.v


def managed_entry():
    a = Box()
    b = Box()
    a.set(10)
    b.set(20)
    return a.get() + b.get()

try:
    entry_result = managed_entry()
except Exception as entry_exc:
    print(type(entry_exc).__name__)
    print(entry_exc.args)
else:
    print(entry_result)
