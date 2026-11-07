# A copied short list initially owns its items inline with its header. After
# growth, those obsolete slots must not retain a removed heap child forever.
# Keep the grown list headers alive, but none of the large child buffers.
def make_grown(i):
    child = bytearray(8192)
    source = [child, 0, 1, 2, 3]
    result = source[:]
    if i % 2:
        result.extend((None,) * 10)  # firmware reserve path
    else:
        result.append(None)        # native append/grow path
    result[0] = None
    return result

kept = []
for i in range(80):
    kept.append(make_grown(i))
print('grown roots', len(kept), sum(len(x) for x in kept))
