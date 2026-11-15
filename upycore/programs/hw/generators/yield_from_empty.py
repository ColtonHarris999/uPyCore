def run():
    print((yield from f))


f = zip()
try:
    next(run())
except StopIteration:
    print("StopIteration")
print("end")


def gen():
    return 1
    yield


f = gen()


def run2():
    print((yield from f))


try:
    print("got", next(run2()))
except StopIteration:
    print("StopIteration2")


def run3():
    print((yield from iter(())))


try:
    next(run3())
except StopIteration:
    print("StopIteration3")
print("end3")
