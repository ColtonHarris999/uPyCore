# MicroPython peripherals

Board I/O is in [`mpy_io_core.md`](mpy_io_core.md): every peripheral
(GPIO, UART, timers, PWM, SPI, I2C, ADC, watchdog, pin mux) belongs to a
small RV32 core, the I/O core, in its own clock domain, and the hart talks
to it through one bridge window at `0x4000_0000`. `machine`, `time`, the
UART console, `Pin.irq` and timer callbacks, Ctrl-C and the REPL are
described there.

## History

This page was the register model of a first design that put the
peripherals in the hart's MMIO window: `upycore/rtl/mpy_periph.sv` (UART,
GPIO, timer, ticks) and `upycore/rtl/mpy_irq.sv` (an interrupt latch for
the hart), with `upycore/tools/mpy_periph_model.py` as the host model of
their edge and UART rules. They were verified by `tb_mpy_periph`
(`unit_tests.py mpy_periph`) but never instantiated in `mpy_soc`. The
I/O core design replaced them (`planning/rv_io_core_plan.md`): its UART,
GPIO and timer are those blocks' rules re-homed on the I/O core's bus
(`iocore/rtl/iocore_uart.sv`, `iocore_gpio.sv`, `iocore_timer.sv`), and
the hart has no peripheral registers and no per-opcode interrupt check.
The two files and their bench are kept, unconnected, as the reference
those blocks were ported from; the old register tables are in this
file's git history.
