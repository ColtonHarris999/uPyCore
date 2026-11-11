# Phase 6 measurement: the I/O island with nothing to do. The I/O core runs
# its firmware loop (it polls; it does not sleep), and the hart waits in
# time.sleep_ms. io_measure.py power records the island's switching
# activity from 2 ms on (+SAIF_ISLAND).
import machine
import time

time.sleep_ms(12)
print("idle done")
