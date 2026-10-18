"""The patched uPy2 compiler still emits an .mpy a host can decode.

This does not boot the simulator. It checks the hart adjustments
(no struct, binary32 const keys) and that an integer program matches
the unmodified pin.
"""

from __future__ import annotations

import importlib
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "upycore" / "compiler"))

import prepare  # noqa: E402


def _drop_mpyc() -> None:
    for name in list(sys.modules):
        if name == "mpyc" or name.startswith("mpyc."):
            del sys.modules[name]


def _load_stages():
    pkg = prepare.prepare()
    parent = str(pkg.parent)
    sys.path.insert(0, parent)
    _drop_mpyc()
    return importlib.import_module("mpyc.stages")


def _load_vendor():
    vendor = str(ROOT / "vendor" / "upy2")
    # The prepared tree is also named mpyc. Drop it before loading the pin.
    while str(prepare.prepare().parent) in sys.path:
        sys.path.remove(str(prepare.prepare().parent))
    sys.path.insert(0, vendor)
    _drop_mpyc()
    return importlib.import_module("mpyc.compile")


class HostCompilerTest(unittest.TestCase):
    def test_integer_program_matches_the_pin(self) -> None:
        source = "print(1 + 2)\n"
        vendor = _load_vendor()
        ref = vendor.compile_source(source, "<s>", "exec", 0)
        stages = _load_stages()
        stages.stage_begin()
        try:
            stages.stage_parse(source, "<s>", "exec")
            stages.stage_scope()
            stages.stage_layout()
            stages.stage_write()
            got = stages.stage_encode()
        finally:
            stages.stage_end()
        self.assertTrue(got.startswith(b"M\x06"))
        self.assertEqual(got, ref)

    def test_class_program_matches_the_pin(self) -> None:
        source = (
            "def f(n):\n"
            "    s = 0\n"
            "    for i in range(n):\n"
            "        s += i\n"
            "    return s\n"
            "class A:\n"
            "    def m(self, x):\n"
            "        try:\n"
            "            return x // self.d\n"
            "        except ZeroDivisionError:\n"
            "            return -1\n"
            "a = A()\n"
            "a.d = 2\n"
            "print(f(5), a.m(7))\n"
        )
        vendor = _load_vendor()
        ref = vendor.compile_source(source, "<m>", "exec", 0)
        stages = _load_stages()
        stages.stage_begin()
        try:
            stages.stage_parse(source, "<m>", "exec")
            stages.stage_scope()
            stages.stage_layout()
            stages.stage_write()
            got = stages.stage_encode()
        finally:
            stages.stage_end()
        self.assertEqual(got, ref)

    def test_float_key_is_binary32(self) -> None:
        pkg = prepare.prepare()
        text = (pkg / "parsetree.py").read_text(encoding="utf-8")
        self.assertNotIn("from struct import", text)
        self.assertIn("_f32bits", text)
        fmt = (pkg / "floatfmt.py").read_text(encoding="utf-8")
        self.assertIn("Binary32 repr round-trips", fmt)
        self.assertNotIn("def _decompose", fmt.split("def float_repr")[1].split("def _is_neg_zero")[0])


if __name__ == "__main__":
    unittest.main()
