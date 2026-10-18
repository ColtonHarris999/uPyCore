"""perf_bench script construction, parameter selection, and the score formula.

These checks do not boot the simulator. They pin the v1.29.0 inventory and
the arithmetic benchrun.py uses to pick a workload.
"""

from __future__ import annotations

import re
import unittest
from collections import defaultdict
from pathlib import Path

import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "upycore" / "tools"))

import perfbench  # noqa: E402

INTERNAL = ROOT / "vendor" / "micropython" / "tests" / "internal_bench"

# Smallest bm_params key, the value it maps to, and the (N, M) that selects it.
SMALLEST = {
    "misc_pystone": ((50, 10), (80,), 42, 10),
    "misc_aes": ((50, 25), (1, 16), 42, 25),
    "bm_fannkuch": ((32, 10), (3,), 27, 10),
    "bm_nqueens": ((32, 10), (1, 5), 27, 10),
    "bm_wordcount": ((32, 10), (2,), 27, 10),
    "core_locals": ((32, 10), (2,), 27, 10),
    "core_str": ((32, 10), (2,), 27, 10),
    "core_qstr": ((32, 10), (400,), 27, 10),
    "core_yield_from": ((100, 10), (2000,), 84, 10),
    "bm_pidigits": ((32, 10), (1, 20), 27, 10),
    "bm_float": ((50, 25), (1, 150), 42, 25),
    "bm_fft": ((50, 25), (2, 128), 42, 25),
    "bm_chaos": ((100, 50), (0.25, 100, 50, 50, 50, 1234), 84, 50),
    "misc_mandel": ((100, 100), (20, 20), 84, 100),
    "misc_raytrace": ((100, 100), (5, 5, 2), 84, 100),
    "bm_hexiom": ((100, 100), None, 84, 100),
}


def _c_ticks_diff(end: int, start: int) -> int:
    period = 1 << 30
    diff = (end - start) & (period - 1)
    if diff & (period >> 1):
        diff -= period
    return diff


def _c_ticks_add(ticks: int, delta: int) -> int:
    return (ticks + delta) & ((1 << 30) - 1)


class PerfBenchTests(unittest.TestCase):
    def test_min_n_thresholds(self) -> None:
        self.assertEqual(perfbench.min_n(32), 27)
        self.assertEqual(perfbench.min_n(50), 42)
        self.assertEqual(perfbench.min_n(100), 84)
        # 26 does not qualify a key of 32; 27 does.
        self.assertFalse(10 * 32 <= 12 * 26)
        self.assertTrue(10 * 32 <= 12 * 27)

    def test_sixteen_bytecode_programs(self) -> None:
        names = perfbench.benchmark_names()
        self.assertEqual(len(names), 24)
        kept = [n for n in names if perfbench.tier_of(n) in ("A", "B", "C")]
        self.assertEqual(len(kept), 16)
        self.assertEqual(len(perfbench.TIER_A), 10)
        dropped = [n for n in names if perfbench.tier_of(n) in ("viper", "import")]
        self.assertEqual(len(dropped), 8)

    def test_smallest_params(self) -> None:
        for name, (key, param, n, m) in SMALLEST.items():
            params = perfbench.load_params(name)
            self.assertEqual(min(params), key, name)
            got_n, got_m = perfbench.qualifying(params)
            self.assertEqual((got_n, got_m), (n, m), name)
            chosen, value = perfbench.select_param(params, n, m)
            self.assertEqual(chosen, key, name)
            if param is not None:
                self.assertEqual(value, param, name)
            # A larger published point must not be what this N selects.
            bigger = [k for k in params if k > key]
            if bigger:
                self.assertNotEqual(chosen, min(bigger), name)

    def test_pystone_at_100_is_a_different_workload(self) -> None:
        params = perfbench.load_params("misc_pystone")
        key, value = perfbench.select_param(params, 100, 100)
        self.assertEqual(key, (100, 10))
        self.assertEqual(value, (300,))

    def test_script_matches_run_perfbench(self) -> None:
        script = perfbench.build_script("bm_fannkuch", 27, 10)
        body = (perfbench.PERF / "bm_fannkuch.py").read_bytes()
        harness = (perfbench.PERF / "benchrun.py").read_bytes()
        self.assertEqual(
            script,
            b"import sys\nsys.path.remove('')\n\n" + body + harness + b"bm_run(27, 10)\n",
        )
        self.assertTrue(script.startswith(b"import sys\nsys.path.remove('')\n\n"))

    def test_score_is_per_mhz(self) -> None:
        # 80 pystone loops in 5_600_000 cycles.
        self.assertAlmostEqual(perfbench.score_per_mhz(80, 5_600_000), 1e6 * 80 / 5_600_000)
        self.assertAlmostEqual(perfbench.geomean([4.0, 9.0]), 6.0)

    def test_parse_line(self) -> None:
        status, elapsed, norm, result = perfbench.parse_bench_output("1200 3 (1, 2)\n")
        self.assertEqual((status, elapsed, norm, result), ("ok", 1200, 3, "(1, 2)"))
        status, _, _, result = perfbench.parse_bench_output("SKIP\n")
        self.assertEqual(status, "skip")
        self.assertEqual(result, "SKIP")

    def test_none_result_matches_upstream(self) -> None:
        self.assertTrue(perfbench._agree("None", "None"))
        self.assertTrue(perfbench._agree("None", None))
        self.assertFalse(perfbench._agree("None", "0"))
        self.assertFalse(perfbench._agree("(1, 2)", "(1, 3)"))

    def test_internal_bench_inventory(self) -> None:
        families: dict[str, list[str]] = defaultdict(list)
        for path in INTERNAL.glob("*.py"):
            match = re.match(r"(.+?)-(.+)\.py", path.name)
            if match:
                families[match.group(1)].append(path.name)
        self.assertEqual(sum(len(v) for v in families.values()), 86)
        self.assertEqual(len(families), 11)
        self.assertEqual(
            {name: len(files) for name, files in families.items()},
            {
                "arrayop": 4,
                "bytealloc": 2,
                "bytebuf": 3,
                "class_create": 18,
                "class_instance": 13,
                "from_iter": 8,
                "func_args": 5,
                "func_builtin": 2,
                "funcall": 3,
                "loop_count": 6,
                "var": 22,
            },
        )

    def test_tick_wrap_matches_utime(self) -> None:
        # The firmware uses this shape so it never builds a 2**30 small int.
        # The results are the masked add/sub from extmod/modutime.c.
        cases = [(5, 1), (1, 1073741823), (0, 1), (0, 0), (1073741823, 1073741823)]
        for end, start in cases:
            self.assertEqual(_firmware_diff(end, start), _c_ticks_diff(end, start), (end, start))
        adds = [(1073741822, 4), (3, -5), (0, 0), (1073741823, 1), (10, -10), (0, -1)]
        for ticks, delta in adds:
            self.assertEqual(_firmware_add(ticks, delta), _c_ticks_add(ticks, delta), (ticks, delta))


def _firmware_diff(end: int, start: int) -> int:
    mask = 1073741823
    sign = 536870912
    e = end & mask
    s = start & mask
    if e >= s:
        diff = e - s
    else:
        diff = e + (mask - s) + 1
    if diff >= sign:
        diff = diff - mask - 1
    return diff


def _firmware_add(ticks: int, delta: int) -> int:
    mask = 1073741823
    t = ticks & mask
    if delta < 0:
        n = -delta
        if n > mask:
            return t
        if t >= n:
            return t - n
        return t + (mask - n) + 1
    d = delta & mask
    if d <= mask - t:
        return t + d
    return d - (mask - t) - 1


if __name__ == "__main__":
    unittest.main()
