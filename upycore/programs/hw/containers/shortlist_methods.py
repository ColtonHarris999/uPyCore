# Validate the newly native copy dispatch and its ordinary error fallback.
for call in (lambda: list.copy(),
             lambda: list.copy(123),
             lambda: list.copy([1, 2], 3),
             lambda: [1, 2].copy(3),
             lambda: [1, 2].copy(unused=3)):
    try:
        call()
    except TypeError:
        pass
    else:
        raise AssertionError('copy accepted invalid arguments')

for n in (0, 2, 8, 16, 17):
    a = list(range(n))
    b = list.copy(a)
    assert b == a and b is not a
    b.append(99)
    assert len(a) == n

class Override(list):
    def copy(self):
        return 'override'

assert Override([1, 2]).copy() == 'override'
a = [1, 2]
a.insert(True, 9)
assert a == [1, 9, 2]
assert a.pop(False) == 1
print('shortlist methods passed')
