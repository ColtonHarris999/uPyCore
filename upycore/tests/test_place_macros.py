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


def args(**kw):
    base = dict(logic_area=2.0e6, util=0.45, stack_gap=21.76, margin=100.0, spacing=60.0)
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


if __name__ == "__main__":
    unittest.main()
