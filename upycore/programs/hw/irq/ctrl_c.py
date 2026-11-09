# Ctrl-C on the UART console: the I/O core turns the armed interrupt
# character (Ctrl-C from the start, as pyexec arms it for a script) into the
# KBD event, and the next soft point raises KeyboardInterrupt in the running
# loop (py/scheduler.c, mp_sched_keyboard_interrupt). The traceback is the
# loop's line; the exception prints as "KeyboardInterrupt: "
# (mp_obj_exception_print with no arguments). Hand-written golden.
import time

print("looping")
n = 0
while True:
    n += 1
