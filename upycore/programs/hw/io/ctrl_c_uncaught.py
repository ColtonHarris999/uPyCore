# An uncaught KeyboardInterrupt ends the program with the traceback.
import micropython

micropython.kbd_intr(3)
while True:
    pass
