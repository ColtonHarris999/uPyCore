"""Host model for the peripheral map.

Edge masks come from this model. The unix ``machine`` module is not used.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

from mpy_periph_model import (  # noqa: E402
    blink_edge_mask,
    debounce_count,
    echo_fifo_result,
    i2c_byte_clocks,
    i2c_config,
    echo_result,
    io_plusargs,
    plusargs,
    schedule_raise_at,
    self_check,
    soc_expect,
    uart_burst_overruns,
    wdt_plusargs,
    wdt_reset_tick,
    Wdt,
)


class MpyPeriphModelTest(unittest.TestCase):
    def test_self_check(self) -> None:
        self_check()

    def test_plusargs_match_the_model(self) -> None:
        text = plusargs()
        mask = blink_edge_mask(4, 20)
        tx_word, tx_n, overrun = echo_result()
        self.assertIn(f"+EXPECT_EDGE_MASK={mask}", text)
        self.assertIn("+EXPECT_OFF_MASK=0", text)
        self.assertIn(f"+EXPECT_TX_WORD={tx_word}", text)
        self.assertIn(f"+EXPECT_TXN={tx_n}", text)
        self.assertIn(f"+EXPECT_OVERRUN={overrun}", text)
        self.assertIn(f"+EXPECT_SCHED_RAISE_AT={schedule_raise_at()}", text)
        self.assertEqual(overrun, 1)
        self.assertEqual(tx_n, 3)


    def test_fifo_echo_and_overrun(self) -> None:
        tx, ovr = echo_fifo_result()
        self.assertEqual(tx, [0x41, 0x42, 0x43, 0x44])
        self.assertEqual(ovr, 0)
        tx, ovr = echo_fifo_result(extra=15)
        self.assertEqual(len(tx), 18)
        self.assertEqual(ovr, 1)

    def test_burst_and_io_plusargs(self) -> None:
        self.assertEqual(uart_burst_overruns(64, 80, 1240, 16), (64, -1))
        self.assertEqual(uart_burst_overruns(64, 80, 1640, 16), (60, 16))
        self.assertIn("+FIFO_DEPTH=16", io_plusargs())

    def test_i2c_config(self) -> None:
        self.assertEqual(i2c_config(48_000_000, 400_000, 50_000), (29, 400_000, 2_400_000))
        self.assertEqual(i2c_config(48_000_000, 100_000, 10), (119, 100_000, 480))
        self.assertEqual(i2c_config(48_000_000, 10, 100_000_000)[0::2], (0xFFFF, 0xFFFF_FFFF))
        self.assertEqual(i2c_config(48_000_000, 48_000_000, 1)[:2], (0, 12_000_000))
        self.assertEqual(i2c_byte_clocks(29), 1080)

    def test_wdt(self) -> None:
        self.assertEqual(wdt_reset_tick(7, ()), 7)
        self.assertEqual(wdt_reset_tick(7, (3, 9)), 16)
        self.assertEqual(wdt_reset_tick(0, ()), 1)
        w = Wdt()
        w.write_load(4)
        w.start()
        w.write_load(100)
        w.kick(0x1234)
        self.assertEqual((w.load, w.count), (4, 4))
        self.assertIn("+WDT_RESET_AT=16", wdt_plusargs())

    def test_soc_expectations(self) -> None:
        self.assertEqual(soc_expect("blink", ("+MAX_TICKS=20",))["gmask"], "00088888")
        self.assertEqual(soc_expect("blink_off", ("+MAX_TICKS=20",))["edges"], "0")
        self.assertEqual(soc_expect("echo_fifo")["tx"], "41424344")
        edges = [(1, 1000), (0, 1300), (1, 1600), (0, 9000), (1, 20000)]
        self.assertEqual(debounce_count(edges, 1000), 2)


if __name__ == "__main__":
    unittest.main()
