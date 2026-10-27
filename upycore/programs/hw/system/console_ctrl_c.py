# On the UART console Ctrl-C is armed from boot: a 0x03 byte stops a loop
# with KeyboardInterrupt, and the traceback goes over the UART. A long
# line at 3 Mbaud fills the TX FIFO, so its stores wait on the UART.
import machine

machine.UART(0, baudrate=3_000_000)
print('0123456789' * 8)
n = 0
while True:
    n += 1
