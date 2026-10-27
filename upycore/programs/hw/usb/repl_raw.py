# The raw REPL over USB CDC, the way mpremote enters it: CR and two Ctrl-C
# at the friendly prompt, then Ctrl-A, a program, and Ctrl-D. __main__ runs
# before the host has enumerated, so its banner is not seen; the host's
# script (repl_raw.usb) starts at the prompt it asks for.
x = 1
