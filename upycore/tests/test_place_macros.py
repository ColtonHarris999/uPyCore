"""place_macros.py: the 32-macro floorplan from stand-in LEFs (no class files)."""

import argparse
import sys
import unittest
from pathlib import Path

HAMMER = Path(__file__).resolve().parents[1] / "synth" / "hammer"
sys.path.insert(0, str(HAMMER))
import place_macros as pm  # noqa: E402

BANK = (3952.32, 157.76, "left")     # fakeram_d4096_w36, measured on the lab machine
GC = (648.14, 212.16, "left")        # fakeram_d600_w64
CODE = (3947.26, 133.28, "left")     # fakeram_d4096_w32, the I/O island's code SRAM
DATA = (1881.40, 116.96, "left")     # fakeram_d1920_w32, its data SRAM


def args(**kw):
    base = dict(logic_area=2.0e6, island_area=0.3e6, usb_flop_area=1.4e6, util=0.45, stack_gap=21.76, margin=100.0, spacing=60.0)
    base.update(kw)
    return argparse.Namespace(**base)


class Layout(unittest.TestCase):
    def setUp(self):
        self.die_w, self.die_h, self.place, self.blocks = pm.layout(BANK, GC, args())
        self.mem = [p for p in self.place if "/u_mem/" in p[0]]

    def rect(self, p):
        w, h = (GC if "/u_gc/" in p[0] else BANK)[:2]
        return p[1], p[2], p[1] + w, p[2] + h

    def test_every_macro_once(self):
        names = [p[0] for p in self.mem]
        self.assertEqual(names, [pm.BANK_PATH.format(b=i) for i in range(32)])
        self.assertEqual(len(self.place), 33)

    def test_inside_die_and_no_overlap(self):
        rects = [self.rect(p) for p in self.place]
        for x0, y0, x1, y1 in rects:
            self.assertTrue(0 < x0 and 0 < y0 and x1 < self.die_w and y1 < self.die_h)
        for i, a in enumerate(rects):
            for b in rects[i + 1:]:
                apart = a[2] <= b[0] or b[2] <= a[0] or a[3] <= b[1] or b[3] <= a[1]
                self.assertTrue(apart, (a, b))

    def test_on_grid(self):
        for _, x, y, _ in self.place:
            self.assertAlmostEqual(x / pm.SITE_W, round(x / pm.SITE_W), places=6)
            self.assertAlmostEqual(y / pm.ROW_H, round(y / pm.ROW_H), places=6)

    def test_pins_face_the_channel(self):
        for i, (_, x, _, o) in enumerate(self.mem):
            left = (i // 8) % 2 == 0          # banks 0 and 2
            self.assertEqual(x < self.die_w / 2, left)
            # Pins are on the LEF's left edge: mirror the left column.
            self.assertEqual(o, "my" if left else "r0")

    def test_bank_is_a_quadrant(self):
        for b in range(4):
            ys = [p[2] for p in self.mem[8 * b:8 * b + 8]]
            self.assertEqual(ys, sorted(ys))
            self.assertEqual(min(ys) > self.die_h / 2, b >= 2)

    def test_blockages_leave_only_the_channel(self):
        (ax, _, aw, ah), (bx, _, bw, bh) = self.blocks
        self.assertEqual((ax, ah, bh), (0, self.die_h, self.die_h))
        self.assertAlmostEqual(bx + bw, self.die_w, places=2)
        for p in self.mem:
            x0, _, x1, _ = self.rect(p)
            self.assertTrue(x1 <= ax + aw or x0 >= bx)
        free = (bx - (ax + aw)) * (self.die_h - 200)
        self.assertGreater(free, 2.0e6 / 0.45 * 0.98)
        gx0, _, gx1, _ = self.rect(self.place[-1])
        self.assertTrue(ax + aw < gx0 and gx1 < bx)

    def test_route_blockages_stop_short_of_the_pins(self):
        (ax, _, aw, _), (bx, _, bw, _) = pm.route_blocks(self.blocks, 15.0)
        left_pins = max(self.rect(p)[2] for p in self.mem[:8])
        right_pins = min(self.rect(p)[0] for p in self.mem[8:16])
        self.assertEqual(ax, 0)
        self.assertAlmostEqual(bx + bw, self.die_w, places=2)
        self.assertTrue(0 < left_pins - (ax + aw) <= 10)
        self.assertTrue(0 < bx - right_pins <= 10)

    def test_die_size(self):
        self.assertLess(self.die_w * self.die_h, 31e6)
        self.assertLess(self.die_w, 10000)


class Pins(unittest.TestCase):
    def test_ports_and_plan(self):
        bits = pm.top_ports(HAMMER / "converted" / "mpy_soc.v")
        self.assertEqual(len(bits), len(set(bits)))
        for name in ("clk_i", "rst_n_i", "nand_miso_i", "boot_err_o", r"cycles_o\[31\]", r"trace_sp_o\[0\]"):
            self.assertIn(name, bits)
        self.assertNotIn("cycles_o", bits)
        plan = pm.pin_plan(bits, 4100.0, 5600.0, 3032.8)
        self.assertEqual(sorted(q["pins"] for q in plan), sorted(bits))
        xs = [q["location"][0] for q in plan]
        self.assertEqual(xs, sorted(xs))
        self.assertTrue(all(4100 < x < 5600 for x in xs))
        self.assertGreaterEqual(min(b - a for a, b in zip(xs, xs[1:])), 4 * pm.MET2_PITCH - 1e-6)
        for q in plan:
            n = (q["location"][0] - pm.MET2_OFFSET) / pm.MET2_PITCH
            self.assertAlmostEqual(n, round(n), places=6)
            self.assertEqual((q["side"], q["layers"], q["location"][1]), ("top", ["met2"], 3032.8))
        clk = [i for i, q in enumerate(plan) if q["pins"] == "clk_i"][0]
        self.assertLessEqual(abs(clk - len(plan) // 2), 1)


class Island(unittest.TestCase):
    """With the I/O island: its two SRAMs on top of the columns."""

    def setUp(self):
        self.base = pm.layout(BANK, GC, args(util=0.25))
        self.die_w, self.die_h, self.place, self.blocks = pm.layout(BANK, GC, args(util=0.25), (CODE, DATA))
        self.code = next(p for p in self.place if p[0] == pm.CODE_PATH)
        self.data = next(p for p in self.place if p[0] == pm.DATA_PATH)

    def test_thirty_five_macros_and_the_memory_unmoved_in_y(self):
        self.assertEqual(len(self.place), 35)
        self.assertEqual([p[2] for p in self.place[:32]], [p[2] for p in self.base[2][:32]])

    def test_on_top_of_the_columns_inside_the_die(self):
        top = max(p[2] for p in self.place if "/u_mem/" in p[0]) + BANK[1]
        for p, shape in ((self.code, CODE), (self.data, DATA)):
            self.assertGreaterEqual(p[2], top + 21.76 - pm.ROW_H)
            self.assertLess(p[2] + shape[1], self.die_h - 99)
            self.assertAlmostEqual(p[1] / pm.SITE_W, round(p[1] / pm.SITE_W), places=6)
            self.assertAlmostEqual(p[2] / pm.ROW_H, round(p[2] / pm.ROW_H), places=6)

    def test_pin_edges_on_the_channel(self):
        left_edge = max(p[1] + BANK[0] for p in self.place if "/u_mem/" in p[0] and p[1] < self.die_w / 2)
        right_edge = min(p[1] for p in self.place if "/u_mem/" in p[0] and p[1] > self.die_w / 2)
        # Code SRAM on the right column, pins (LEF left edge) on the channel.
        self.assertEqual(self.code[3], "r0")
        self.assertAlmostEqual(self.code[1], right_edge, delta=pm.SITE_W)
        # Data SRAM mirrored on the left column, its pin edge flush with the column's.
        self.assertEqual(self.data[3], "my")
        self.assertAlmostEqual(self.data[1] + DATA[0], left_edge, delta=pm.SITE_W)

    def test_die_grows_for_the_row_and_the_island_logic(self):
        self.assertGreater(self.die_h, self.base[1] + CODE[1])
        self.assertLess(self.die_h, self.base[1] + CODE[1] + 21.76 + 2 * pm.ROW_H)
        self.assertGreater(self.die_w, self.base[0] + 1000)

    def test_macros_are_under_the_blockages(self):
        for p, shape in ((self.code, CODE), (self.data, DATA)):
            inside = any(x <= p[1] and p[1] + shape[0] <= x + w + 10.01 for x, _, w, _ in self.blocks)
            self.assertTrue(inside, p)


class UsbMacros(unittest.TestCase):
    """The nine USB RAM macros on the channel floor."""

    USB = (120.52, 81.6, "left")     # a stand-in shape; the real one comes from the LEF

    def setUp(self):
        self.flops = pm.layout(BANK, GC, args(util=0.25), (CODE, DATA))
        self.die_w, self.die_h, self.place, self.blocks = pm.layout(BANK, GC, args(util=0.25), (CODE, DATA), self.USB)
        self.usb = [p for p in self.place if p[0] in pm.USB_PATHS]

    def test_nine_named_macros(self):
        self.assertEqual([p[0] for p in self.usb], pm.USB_PATHS)
        self.assertEqual(len(self.usb), 9)
        self.assertEqual(len(self.place), 44)
        self.assertTrue(all("\\[" in p for p in pm.USB_PATHS[:8]))

    def test_no_flop_area_with_macros(self):
        self.assertLess(self.die_w, self.flops[0] - 1000)

    def test_in_the_channel_clear_of_everything(self):
        x0 = self.blocks[0][0] + self.blocks[0][2]
        x1 = self.blocks[1][0]
        shapes = {pm.GC_PATH: GC, pm.CODE_PATH: CODE, pm.DATA_PATH: DATA}
        rects = []
        for path, x, y, _ in self.place:
            w, h = (self.USB if path in pm.USB_PATHS else shapes.get(path, BANK))[:2]
            rects.append((path, x, y, x + w, y + h))
        for path, ax0, ay0, ax1, ay1 in rects:
            if path in pm.USB_PATHS:
                self.assertTrue(x0 + 50 <= ax0 and ax1 <= x1 - 50, path)
                self.assertTrue(ay1 < self.die_h - 100)
        for i, a in enumerate(rects):
            for b in rects[i + 1:]:
                if a[0] in pm.USB_PATHS or b[0] in pm.USB_PATHS:
                    gap_x = max(b[1] - a[3], a[1] - b[3])
                    gap_y = max(b[2] - a[4], a[2] - b[4])
                    self.assertTrue(gap_x >= 59 or gap_y >= 59, (a, b))

    def test_narrow_channel_wraps_rows(self):
        slots = pm.usb_slots(9, 0, 1300, 100, 326, 648, 212, 120, 80, 60)
        self.assertEqual(len(set(slots)), 9)
        self.assertGreater(len({y for _, y in slots}), 1)


if __name__ == "__main__":
    unittest.main()
