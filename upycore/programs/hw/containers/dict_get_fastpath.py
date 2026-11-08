# Exercise custom hash/equality fallback and ensure neither is replayed.
log = []
class Key:
    def __hash__(self):
        log.append('hash')
        return 7
    def __eq__(self, other):
        log.append('eq')
        return isinstance(other, Key)

d = {Key(): None}
log.clear()
print(d.get(Key(), 3), log)
d = {'x': None, b'y': 4, 3: 5}
print(d.get('x', 8), d.get(b'y'), d.get(3), d.get('z'), d.get('z', 8))
del d['x']
print(d.get('x', 8))
