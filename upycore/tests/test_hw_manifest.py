"""Manifest and output-mask checks. These do not boot the simulator."""

from __future__ import annotations

import sys
import unittest
from types import SimpleNamespace
from unittest.mock import patch
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "upycore" / "tools"))

import hw_tests  # noqa: E402


class MaskTest(unittest.TestCase):
    def test_masks_object_and_function_addresses(self) -> None:
        raw = b"<Foo object at 0x2000abcd> <Foo object at 2000abcd> <function f at 0x10> <cell ab>\n"
        masked = hw_tests.mask_output(raw)
        self.assertNotIn(b"2000abcd", masked)
        self.assertNotIn(b"0x10", masked)
        self.assertIn(b"object at PTR", masked)
        self.assertIn(b"at PTR", masked)
        self.assertIn(b"<cell PTR>", masked)

    def test_masks_generator_address_without_0x(self) -> None:
        raw = b"<generator object 'named' at f7b5e180>\n"
        other = b"<generator object 'named' at abcd1234>\n"
        self.assertEqual(hw_tests.mask_output(raw), b"<generator object 'named' at PTR>\n")
        self.assertEqual(hw_tests.mask_output(raw), hw_tests.mask_output(other))
        self.assertEqual(
            hw_tests.compare_streams(raw, b"", 0, b"<generator object 'named' at 0x10>\n", b"", 0),
            "",
        )

    def test_leaves_program_text(self) -> None:
        raw = b"hello\n0xff\nadd 5\n"
        self.assertEqual(hw_tests.mask_output(raw), raw)


class ManifestTest(unittest.TestCase):
    def test_oracle_heap_option_is_two_arguments(self) -> None:
        t = hw_tests.Test(name="heap", area="memory", file="hw/memory/alloc_size_bounds.py",
                          heapsize=228096)
        with patch.object(hw_tests, "oracle_ready", return_value=True), patch.object(
            hw_tests.subprocess, "run", return_value=SimpleNamespace(stdout=b"", stderr=b"", returncode=0)
        ) as run:
            hw_tests.run_oracle(t)
        self.assertEqual(run.call_args.args[0][1:3], ["-X", "heapsize=228096"])

    def test_suite_has_no_expected_failures_or_disabled_programs(self) -> None:
        for t in hw_tests.load_manifest():
            self.assertIsNone(t.xfail, t.name)
            self.assertIsNone(t.disabled, t.name)

    def test_every_program_exists_and_names_are_unique(self) -> None:
        tests = hw_tests.load_manifest()
        self.assertGreaterEqual(len(tests), 30)
        names = [t.name for t in tests]
        self.assertEqual(len(names), len(set(names)))
        for t in tests:
            self.assertTrue(t.source.is_file(), t.file)
            for path in t.golden():
                self.assertTrue(path.is_file(), path)
            for spec in t.modules:
                _name, rel = spec.split("=", 1)
                rel = rel.removesuffix(":package")
                self.assertTrue((hw_tests.PROGRAMS / rel).is_file(), spec)

    def test_select_by_area_and_glob(self) -> None:
        tests = hw_tests.load_manifest()
        alu = hw_tests.select(tests, ["alu"], [])
        self.assertTrue(alu)
        self.assertTrue(all(t.area == "alu" for t in alu))
        picked = hw_tests.select(tests, [], ["use_*"])
        self.assertEqual(sorted(t.name for t in picked), ["use_helper", "use_pkg", "use_rel"])

    def test_area_matches_the_program_directory(self) -> None:
        for t in hw_tests.load_manifest():
            self.assertEqual(Path(t.file).parts[1], t.area, t.name)

    def test_compiler_area_is_enabled_with_a_long_budget(self) -> None:
        tests = hw_tests.load_manifest()
        compiler = [t for t in tests if t.area == "compiler"]
        self.assertGreater(len(compiler), 10)
        self.assertTrue(all(not t.disabled for t in compiler))
        self.assertTrue(all(t.cycles >= 1_000_000_000 for t in compiler))
        self.assertTrue(all(t.timeout >= 1800 for t in compiler))
        booted = {t.name for t in hw_tests.for_device(tests)}
        self.assertTrue(all(t.name in booted for t in compiler))

    def test_disabled_entries_stay_off_the_device(self) -> None:
        sample = hw_tests.Test(
            name="x", area="compiler", file="hw/compiler/compile_eval_expr.py",
            disabled="later",
        )
        self.assertEqual(hw_tests.for_device([sample]), [])

    def test_generator_programs_are_in_the_byte_compare(self) -> None:
        import compiler_suite

        tests = hw_tests.load_manifest()
        gens = [t for t in tests if t.area == "generators"]
        self.assertTrue(gens)
        self.assertTrue(all(t.mpyc and not t.disabled for t in gens))
        compiled = {name for name, _path in compiler_suite.suite_sources()}
        for t in gens:
            self.assertIn(t.source.name, compiled)

    def test_mpyc_false_stays_on_the_device(self) -> None:
        sample = hw_tests.Test(
            name="skip_me", area="generators", file="hw/generators/gen_yield.py",
            mpyc=False,
        )
        self.assertEqual(hw_tests.for_device([sample]), [sample])
        self.assertFalse(any(not t.mpyc for t in hw_tests.load_manifest()))

    def test_compare_ignores_addresses_only(self) -> None:
        detail = hw_tests.compare_streams(
            b"<Foo object at 10>\n", b"", 0,
            b"<Foo object at 0x20>\n", b"", 0,
        )
        self.assertEqual(detail, "")
        detail = hw_tests.compare_streams(b"1\n", b"", 0, b"2\n", b"", 0)
        self.assertIn("expected.stdout", detail)
        detail = hw_tests.compare_streams(b"", b"", 1, b"", b"", 0)
        self.assertIn("exit 1", detail)


if __name__ == "__main__":
    unittest.main()
