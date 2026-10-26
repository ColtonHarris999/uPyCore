# errno and the OSError text: [Errno N] NAME for a known code, the plain
# args otherwise.
import errno
print(errno.ENODEV, errno.ETIMEDOUT, errno.errorcode[19], len(errno.errorcode))
for a in [(19,), (19, 'x'), (999,), (999, 'y'), ('s',), (19, 'a', 'b'), ()]:
    e = OSError(*a)
    print(repr(str(e)), repr(e), e.args)
try:
    raise OSError(errno.ETIMEDOUT)
except OSError as e:
    print(e, e.errno, e.args[0] == errno.ETIMEDOUT)


class E(OSError):
    pass


print(str(E(19)), repr(E(19)))
print(type(errno), errno.__name__)
import uerrno
print(uerrno is errno)
print(sorted(errno.errorcode.items()))
print(str(OSError(-1)), str(OSError(True)))
# A builtin module is read-only, as on the unix port.
for m in (errno,):
    try:
        m.EXTRA = 1
    except AttributeError as e:
        print('AttributeError', e)
import errno as again
print(again is errno, hasattr(again, 'EXTRA'))
try:
    raise OSError(errno.EIO)
except Exception as e:
    print('caught', e)
