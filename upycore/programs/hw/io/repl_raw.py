# The raw REPL as mpremote drives it: Ctrl-A, a program and Ctrl-D (OK,
# output, 0x04, 0x04), an error (its traceback between the 0x04s), the
# raw-paste probe (answered R\x00), and Ctrl-D on empty input, a soft
# reset that SYS_KEEP brings back to the raw REPL without __main__.
print('main ran')
