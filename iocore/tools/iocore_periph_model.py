#!/usr/bin/env python3
"""Expected values for the I/O core's peripheral benches (iocore/tb/tb_iocore_*).

Ported from the epic branch's upycore/tools/mpy_periph_model.py (the PWM,
ADC and watchdog parts); the watchdog model has the island's two changes
(an expiry stops it, and the stop key). Spec: upycore/docs/mpy_io_core.md.

    iocore_periph_model.py --pwm-plusargs | --adc-plusargs | --wdt-plusargs
"""

from __future__ import annotations

import argparse


def pwm_wave(presc: int, top: int, duty: int) -> tuple[int, int]:
    """(high clocks, period clocks) of one channel."""
    period = (top + 1) * (presc + 1)
    high = min(duty, top + 1) * (presc + 1)
    return high, period


PWM_BENCH = ((1, 9, (3, 0, 10, 5)),)


def pwm_plusargs() -> str:
    presc, top, duties = PWM_BENCH[0]
    parts = [f"+PRESC={presc} +TOP={top}"]
    for ch, d in enumerate(duties):
        high, _ = pwm_wave(presc, top, d)
        parts.append(f"+DUTY{ch}={d} +HIGH{ch}={high}")
    parts.append(f"+PERIOD={pwm_wave(presc, top, 0)[1]}")
    return " ".join(parts)


ADC_LATENCY = 48       # tb_adc_model: clocks from adc_start to adc_done


def adc_code(ch: int) -> int:
    """The testbench converter's 12-bit answer for channel ch."""
    return (273 * ch + 100) & 0xFFF


def adc_read_u16(ch: int) -> int:
    """ADC(ch).read_u16(): ADC_DATA bits 15:0, the code left-aligned."""
    return adc_code(ch) << 4


def adc_plusargs() -> str:
    return " ".join([f"+ADC_LATENCY={ADC_LATENCY}"] + [f"+ADC_U16_{ch}={adc_read_u16(ch)}" for ch in (0, 5, 15)])


WDT_KEY = 0x6B1D_F00D
WDT_STOP_KEY = 0x5709_DEAD


class Wdt:
    """WDT_LOAD, WDT_CTRL, WDT_KICK, WDT_COUNT. step() is one tick; True on the expiry."""

    def __init__(self) -> None:
        self.load = 0
        self.started = False
        self.count = 0

    def write_load(self, v: int) -> None:
        if not self.started:
            self.load = v & 0xFFFF_FFFF

    def start(self) -> None:
        if not self.started:
            self.started = True
            self.count = self.load

    def kick(self, key: int) -> None:
        if self.started and key == WDT_KEY:
            self.count = self.load
        elif self.started and key == WDT_STOP_KEY:
            self.started = False
            self.count = 0

    def step(self) -> bool:
        if not self.started:
            return False
        if self.count <= 1:
            self.count = 0
            self.started = False
            return True
        self.count -= 1
        return False


def wdt_reset_tick(load: int, kicks: tuple[int, ...], ticks: int = 1000) -> int:
    """The tick (1-based, counted from the start) whose step expires; kicks land before a step."""
    w = Wdt()
    w.write_load(load)
    w.start()
    for t in range(1, ticks + 1):
        if t - 1 in kicks:
            w.kick(WDT_KEY)
        if w.step():
            return t
    return -1


WDT_BENCH = (7, (3, 9))


def wdt_plusargs() -> str:
    load, kicks = WDT_BENCH
    return (f"+WDT_LOAD={load} +WDT_KICK0={kicks[0]} +WDT_KICK1={kicks[1]} "
            f"+WDT_RESET_AT={wdt_reset_tick(load, kicks)} +WDT_ZERO_AT={wdt_reset_tick(0, ())}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--pwm-plusargs", action="store_true")
    g.add_argument("--adc-plusargs", action="store_true")
    g.add_argument("--wdt-plusargs", action="store_true")
    a = ap.parse_args()
    print(pwm_plusargs() if a.pwm_plusargs else adc_plusargs() if a.adc_plusargs else wdt_plusargs())


if __name__ == "__main__":
    main()
