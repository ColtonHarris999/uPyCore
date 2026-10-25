try:
    from . import x
except ImportError as e:
    print(type(e).__name__, e)
