# machine.disable_irq / enable_irq (extmod/modmachine.c): events wait while
# disabled and run once enabled; disable_irq returns the state to restore.
# Hand-written golden.
import machine
import micropython

out = []
s = machine.disable_irq()
micropython.schedule(out.append, 1)
for i in range(5):
    pass
print("disabled", out)
machine.enable_irq(s)
for i in range(5):
    pass
print("enabled", out)
