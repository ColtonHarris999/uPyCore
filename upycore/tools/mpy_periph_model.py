#!/usr/bin/env python3
"""Host register model for the v1 peripheral block.

This is the oracle for GPIO edge traces and for the UART echo bytes.
The unix ``machine`` module is a different map and is not consulted.
The rules live in ``upycore/docs/mpy_peripherals.md``.
"""

from __future__ import annotations

import sys

SCHED_DEPTH = 8
NSRC = 8
SRC = {"TIMER": 0, "UART": 1, "GPIO": 2, "SOFT": 3, "GC_REQ": 4, "SIM": 5, "KBD": 6, "MBOX": 7}
UART_FIFO_DEPTH = 16
BLINK_PERIOD = 4
BLINK_TICKS = 20
HOLD_COMPARE = 5
HOLD_STEPS = 3
HOLD_IDLE_STEPS = 5


class Timer:
    """Compare 0 disables the counter. A match reloads the counter to 0."""

    def __init__(self) -> None:
        self.compare = 0
        self.count = 0

    def set_compare(self, period: int) -> None:
        self.compare = period & 0xFFFFFFFF

    def step(self) -> bool:
        if self.compare == 0:
            return False
        nxt = self.count + 1
        if nxt >= self.compare:
            self.count = 0
            return True
        self.count = nxt & 0xFFFFFFFF
        return False


class Prescaler:
    """One tick every ``div`` system clocks. 0 is off."""

    def __init__(self, div: int = 0) -> None:
        self.div = div
        self.count = 0

    def clock(self) -> bool:
        if self.div == 0:
            return False
        self.count += 1
        if self.count >= self.div:
            self.count = 0
            return True
        return False


class UartFifo:
    """RX FIFO of ``depth`` bytes. A byte that arrives full sticks overrun bit 30.

    Depth 1 is the v1 single-byte buffer, which the unit bench checks.
    """

    def __init__(self, depth: int = UART_FIFO_DEPTH, kbd: int | None = None) -> None:
        self.depth = depth
        self.q: list[int] = []
        self.overrun = False
        self.kbd = kbd
        self.kbd_hits = 0

    def push(self, byte: int) -> str:
        if self.kbd is not None and (byte & 0xFF) == self.kbd:
            self.kbd_hits += 1
            return "kbd"
        if len(self.q) >= self.depth:
            self.overrun = True
            return "drop"
        self.q.append(byte & 0xFF)
        return "take"

    @property
    def valid(self) -> bool:
        return bool(self.q)

    @property
    def data(self) -> int:
        return self.q[0] if self.q else 0

    def read(self) -> int:
        value = (
            ((1 if self.q else 0) << 31)
            | ((1 if self.overrun else 0) << 30)
            | (self.q[0] if self.q else 0)
        )
        if self.q:
            self.q.pop(0)
        return value

    def clear_overrun(self) -> None:
        self.overrun = False


class UartRx(UartFifo):
    """One byte. A second byte while valid sticks overrun bit 30 and is dropped."""

    def __init__(self) -> None:
        super().__init__(depth=1)


def uart_frame(byte: int, clocks_per_bit: int) -> list[int]:
    """Line levels, one per system clock, for one 8N1 frame (start, LSB first, stop)."""
    bits = [0] + [(byte >> i) & 1 for i in range(8)] + [1]
    out: list[int] = []
    for b in bits:
        out.extend([b] * max(4, clocks_per_bit))
    return out


def uart_burst_overruns(n_bytes: int, byte_clocks: int, stall_clocks: int, depth: int) -> tuple[int, int]:
    """Bytes kept and the index of the first dropped byte (-1 if none).

    ``n_bytes`` arrive back to back, one every ``byte_clocks``. The reader
    is stalled (a collection) for the first ``stall_clocks`` and then
    drains faster than the line fills, so only the stall can overrun.
    """
    arrived_during_stall = min(n_bytes, stall_clocks // byte_clocks)
    if arrived_during_stall <= depth:
        return n_bytes, -1
    return n_bytes - (arrived_during_stall - depth), depth


class Schedule:
    """Depth 8. The push that does not fit raises RuntimeError."""

    def __init__(self) -> None:
        self.q: list[tuple[int, int]] = []

    def push(self, fn: int, arg: int) -> None:
        if len(self.q) >= SCHED_DEPTH:
            raise RuntimeError("schedule queue full")
        self.q.append((fn, arg))

    def pop(self) -> tuple[int, int]:
        return self.q.pop(0)

    @property
    def count(self) -> int:
        return len(self.q)


def gpio_edge_pins(edge_cfg: int, old: int, new: int) -> int:
    """Pins 0..15 whose mode matches the change, as a GPIO_STATUS mask."""
    hit = 0
    for pin in range(16):
        mode = (edge_cfg >> (2 * pin)) & 0x3
        rose = ((old >> pin) & 1) == 0 and ((new >> pin) & 1) == 1
        fell = ((old >> pin) & 1) == 1 and ((new >> pin) & 1) == 0
        if (mode == 1 and rose) or (mode == 2 and fell) or (mode == 3 and (rose or fell)):
            hit |= 1 << pin
    return hit


def gpio_edge_hit(edge_cfg: int, old: int, new: int) -> bool:
    """Pins 0..15. Two bits each: off, rising, falling, both."""
    return gpio_edge_pins(edge_cfg, old, new) != 0


def blink_edge_mask(period: int, ticks: int) -> int:
    """Edges of GPIO_OUT bit 0.

    The testbench does one timer step, a non-jump bytecode boundary, then
    one jump. The soft timer callback runs at that jump and toggles the
    pin. Idle clocks between steps are not timer ticks, so they are not
    arguments here.
    """
    timer = Timer()
    timer.set_compare(period)
    pending = False
    mask = 0
    for tick in range(1, ticks + 1):
        if timer.step():
            pending = True
        if pending:
            pending = False
            mask |= 1 << (tick - 1)
    return mask


def hold_count() -> int:
    """A partial count stays put after compare is written to 0."""
    timer = Timer()
    timer.set_compare(HOLD_COMPARE)
    for _ in range(HOLD_STEPS):
        timer.step()
    if timer.count != HOLD_STEPS:
        raise AssertionError(f"count {timer.count} after {HOLD_STEPS} steps")
    timer.set_compare(0)
    for _ in range(HOLD_IDLE_STEPS):
        if timer.step():
            raise AssertionError("disabled timer matched")
    return timer.count


def echo_result() -> tuple[int, int, int]:
    """Bytes that fit are transmitted. One overrun sticks, and 0x43 stays."""
    uart = UartRx()
    tx: list[int] = []
    overruns = 0

    def deliver() -> None:
        nonlocal overruns
        value = uart.read()
        if (value & (1 << 31)) == 0:
            raise AssertionError("echo delivered an empty buffer")
        if value & (1 << 30):
            overruns += 1
        tx.append(value & 0xFF)

    if uart.push(0x41) != "take":
        raise AssertionError("0x41 should fit")
    deliver()
    if uart.push(0x42) != "take":
        raise AssertionError("0x42 should fit")
    deliver()
    if uart.push(0x43) != "take":
        raise AssertionError("0x43 should fit")
    if uart.push(0x44) != "drop":
        raise AssertionError("0x44 should drop")
    deliver()
    follow = uart.read()
    if follow & (1 << 31):
        raise AssertionError("buffer should be empty after the echo")
    if (follow & (1 << 30)) == 0:
        raise AssertionError("overrun should stick across the pop")
    uart.clear_overrun()
    if uart.overrun:
        raise AssertionError("writing bit 30 clears overrun")
    word = 0
    for index, byte in enumerate(tx):
        word |= byte << (8 * index)
    return word, len(tx), overruns


def echo_fifo_result(depth: int = UART_FIFO_DEPTH, extra: int = 0) -> tuple[list[int], int]:
    """The SoC echo with a FIFO: 0x41 and 0x42 one at a time, then a burst.

    The burst is 0x43, 0x44, and ``extra`` more bytes while the reader is
    held off. Returns the echoed bytes in order and the overrun count
    seen by the reader (bit 30 on any pop).
    """
    uart = UartFifo(depth)
    tx: list[int] = []
    overruns = 0
    for b in (0x41, 0x42):
        uart.push(b)
        v = uart.read()
        tx.append(v & 0xFF)
    for b in [0x43, 0x44] + [0x45 + i for i in range(extra)]:
        uart.push(b)
    saw = False
    while uart.valid:
        v = uart.read()
        if v & (1 << 30):
            saw = True
        tx.append(v & 0xFF)
    if saw:
        overruns = 1
    return tx, overruns


def ticks_after(steps: int, presc: int = 0, clocks: int = 0) -> int:
    """TICKS after ``steps`` timer_step pulses and ``clocks`` prescaler clocks."""
    p = Prescaler(presc)
    ticks = steps
    for _ in range(clocks):
        if p.clock():
            ticks += 1
    return ticks & 0xFFFFFFFF


def schedule_raise_at() -> int:
    """Eight pushes fit. The next one is the ninth and raises."""
    sched = Schedule()
    for fn in range(1, SCHED_DEPTH + 1):
        sched.push(fn, 0)
    try:
        sched.push(SCHED_DEPTH + 1, 0)
    except RuntimeError as exc:
        if str(exc) != "schedule queue full":
            raise AssertionError(str(exc)) from exc
        if sched.count != SCHED_DEPTH:
            raise AssertionError("a refused push must leave the ring full")
        first = sched.pop()
        second = sched.pop()
        if first != (1, 0) or second != (2, 0):
            raise AssertionError(f"fifo pop order {(first, second)}")
        if sched.count != SCHED_DEPTH - 2:
            raise AssertionError("two jumps run two callbacks")
        return SCHED_DEPTH + 1
    raise AssertionError("the ninth schedule must raise")


def plusargs() -> str:
    """Numbers the RTL testbench compares against this model."""
    edge_mask = blink_edge_mask(BLINK_PERIOD, BLINK_TICKS)
    off_mask = blink_edge_mask(0, BLINK_TICKS)
    tx_word, tx_n, overrun = echo_result()
    raise_at = schedule_raise_at()
    held = hold_count()
    return (
        f"+BLINK_PERIOD={BLINK_PERIOD} +BLINK_TICKS={BLINK_TICKS} "
        f"+EXPECT_EDGE_MASK={edge_mask} +EXPECT_EDGES={edge_mask.bit_count()} "
        f"+EXPECT_OFF_MASK={off_mask} "
        f"+HOLD_COMPARE={HOLD_COMPARE} +HOLD_STEPS={HOLD_STEPS} "
        f"+HOLD_IDLE_STEPS={HOLD_IDLE_STEPS} +HOLD_COUNT={held} "
        f"+EXPECT_TX_WORD={tx_word} +EXPECT_TXN={tx_n} "
        f"+EXPECT_OVERRUN={overrun} +EXPECT_SCHED_RAISE_AT={raise_at}"
    )


IO_BAUD = 8
IO_BURST = 64
IO_STALLS = (15.5, 20.5)   # reader stall, in byte times
IO_PRESC = 10
IO_PRESC_CLOCKS = 95


def io_plusargs() -> str:
    """Numbers tb_mpy_periph_io compares against this model (depth 16)."""
    tx, ovr = echo_fifo_result()
    tx17, ovr17 = echo_fifo_result(extra=15)
    byte_clocks = 10 * IO_BAUD
    parts = [
        f"+FIFO_DEPTH={UART_FIFO_DEPTH} +BAUD={IO_BAUD} +BURST={IO_BURST}",
        f"+ECHO_N={len(tx)} +ECHO_SUM={sum(tx)} +ECHO_OVR={ovr}",
        f"+ECHO17_N={len(tx17)} +ECHO17_SUM={sum(tx17)} +ECHO17_OVR={ovr17}",
        f"+PRESC={IO_PRESC} +PRESC_CLOCKS={IO_PRESC_CLOCKS} +PRESC_TICKS={ticks_after(0, IO_PRESC, IO_PRESC_CLOCKS)}",
    ]
    for i, stall in enumerate(IO_STALLS):
        kept, first = uart_burst_overruns(IO_BURST, byte_clocks, int(stall * byte_clocks), UART_FIFO_DEPTH)
        parts.append(f"+STALL{i}={int(stall * byte_clocks)} +KEPT{i}={kept} +DROP{i}={first}")
    return " ".join(parts)


# SoC trace expectations for the io area of hw_tests.toml. Each entry
# returns the MPY_IO fields tb_mpy_soc must print for that program.
SOC_EXPECT: dict[str, object] = {}


def soc_expect(name: str) -> dict[str, str]:
    if name not in SOC_EXPECT:
        raise KeyError(f"no SoC expectation named {name!r}")
    return SOC_EXPECT[name]()  # type: ignore[operator]


def self_check() -> None:
    mask = blink_edge_mask(BLINK_PERIOD, BLINK_TICKS)
    if mask != 0x88888 or mask.bit_count() != 5:
        raise AssertionError(f"blink mask {mask:#x}")
    if blink_edge_mask(0, BLINK_TICKS) != 0:
        raise AssertionError("compare 0 produced edges")
    if hold_count() != HOLD_STEPS:
        raise AssertionError("disabled timer moved the counter")
    tx_word, tx_n, overrun = echo_result()
    if (tx_word, tx_n, overrun) != (0x434241, 3, 1):
        raise AssertionError(f"echo {(tx_word, tx_n, overrun)}")
    if schedule_raise_at() != 9:
        raise AssertionError("schedule depth drifted")
    if not gpio_edge_hit(0x1, 0x0, 0x1):
        raise AssertionError("rising edge")
    if gpio_edge_hit(0x1, 0x1, 0x0):
        raise AssertionError("rising mode ignored a fall")
    if not gpio_edge_hit(0x2, 0x1, 0x0):
        raise AssertionError("falling edge")
    if not gpio_edge_hit(0x3, 0x0, 0x1) or not gpio_edge_hit(0x3, 0x1, 0x0):
        raise AssertionError("both-edges mode")
    if gpio_edge_hit(0x0, 0x0, 0x1):
        raise AssertionError("off mode")
    if gpio_edge_pins(0x5, 0x0, 0x3) != 0x3 or gpio_edge_pins(0x9, 0x3, 0x0) != 0x2:
        raise AssertionError("per-pin edge status")
    tx, ovr = echo_fifo_result()
    if tx != [0x41, 0x42, 0x43, 0x44] or ovr:
        raise AssertionError(f"fifo echo {tx} {ovr}")
    tx, ovr = echo_fifo_result(extra=15)
    if len(tx) != 2 + 16 or ovr != 1 or tx[-1] != 0x45 + 13:
        raise AssertionError(f"17th unread byte overruns: {tx} {ovr}")
    if uart_burst_overruns(64, 1000, 15000, 16) != (64, -1):
        raise AssertionError("a 15-byte stall fits a 16-entry FIFO")
    if uart_burst_overruns(64, 1000, 20000, 16) != (60, 16):
        raise AssertionError("a 20-byte stall overruns at the 17th byte")
    if ticks_after(3, presc=10, clocks=25) != 5:
        raise AssertionError("prescaler ticks")
    if uart_frame(0x41, 4)[:4] != [0, 0, 0, 0] or uart_frame(0x41, 4)[4:8] != [1] * 4:
        raise AssertionError("8N1 frame starts low, LSB first")
    kb = UartFifo(16, kbd=0x03)
    if kb.push(0x03) != "kbd" or kb.valid:
        raise AssertionError("the interrupt character is not queued")
    # A second byte does not replace the first.
    uart = UartRx()
    uart.push(0x11)
    uart.push(0x22)
    peeked = ((1 << 31) | (1 << 30) | 0x11)
    if uart.read() != peeked:
        raise AssertionError("overrun must keep the first byte")


def main(argv: list[str]) -> int:
    if "--self-check" in argv:
        self_check()
        print("mpy_periph_model self-check ok")
        return 0
    if "--plusargs" in argv:
        print(plusargs())
        return 0
    if "--io-plusargs" in argv:
        print(io_plusargs())
        return 0
    self_check()
    print(plusargs())
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
