class Box:
    def __init__(self, swallow):
        self.swallow = swallow

    @property
    def __enter__(self):
        def enter():
            print("enter")
            return "v"

        return enter

    @property
    def __exit__(self):
        flag = self.swallow

        def exit(et, ev, tb):
            print("exit", None if et is None else et.__name__)
            return flag

        return exit


class BoolFalse:
    def __bool__(self):
        return False


def attempt(flag):
    try:
        with Box(flag):
            print("body")
            raise ValueError("x")
        print("swallowed")
    except ValueError:
        print("propagated")


with Box(False):
    print("body")

attempt(False)
attempt(0)
attempt(0j)
attempt(True)
attempt(1)
attempt(BoolFalse())


class Miss:
    @property
    def __exit__(self):
        def exit(et, ev, tb):
            return False

        return exit


try:
    with Miss():
        print("ran")
except AttributeError:
    print("missing")


class PlainMiss:
    def __exit__(self, et, ev, tb):
        return False


try:
    with PlainMiss():
        print("ran")
except AttributeError:
    print("plain missing")
