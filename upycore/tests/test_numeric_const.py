"""Linker decode of float and complex constants.

The hardware suite used to print only a handful of short decimals. Scientific
notation, subnormals, signed zero, underscores, and a complex with a real
part are checked here against the unix oracle's binary32 bits. ``make test``
runs this without booting the simulator. The same spellings also run on the
device as ``alu/floatparse``.
"""

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "upycore" / "tools"))

import mpy_build as build  # noqa: E402
import mpy_link as link  # noqa: E402
from mpy_catalog import Catalog  # noqa: E402
from mpy_file import ComplexConst, FloatConst, read_mpy  # noqa: E402

# Bits are the 32-bit unix oracle (MICROPY_FLOAT_IMPL_FLOAT), not host float64.
FLOAT_BITS = {
    "0.1": 0x3DCCCCCD,
    "0.3": 0x3E99999A,
    "0.15": 0x3E19999A,
    "100.0": 0x42C80000,
    "1e+39": 0x7F800000,
    "1e-45": 0x00000001,
    "1e-46": 0x00000000,
    "-0.0": 0x80000000,
    "1.0000000000000002": 0x3F800000,
    "6.02214076e+23": 0x66FF0C2E,
    "1.1754944e-38": 0x00800000,
    "123456789.0": 0x4CEB79A3,
    "1000.5": 0x447A2000,
    "0.5": 0x3F000000,
    "1.0": 0x3F800000,
    "25.0": 0x41C80000,
    "1.25": 0x3FA00000,
    "-25.0": 0xC1C80000,
    "1.5": 0x3FC00000,
    "9.999999999999999e+38": 0x7F800000,
    "1_000.5": 0x447A2000,
    "1e_2": 0x42C80000,
    "_1.5": 0x3FC00000,
    "1e309": 0x7F800000,
    "1e-400": 0x00000000,
    "Inf": 0x7F800000,
    "infinity": 0x7F800000,
    "-INFINITY": 0xFF800000,
    "nan": 0x7FC00000,
    "NaN": 0x7FC00000,
    "nAn": 0x7FC00000,
    "-nan": 0xFFC00000,
    "  1.5e-1  ": 0x3E19999A,
    "+1.5": 0x3FC00000,
}

COMPLEX_BITS = {
    "1j": (0x00000000, 0x3F800000),
    "1.5j": (0x00000000, 0x3FC00000),
    "100j": (0x00000000, 0x42C80000),
    "0.15j": (0x00000000, 0x3E19999A),
    "1e-45j": (0x00000000, 0x00000001),
    "0j": (0x00000000, 0x00000000),
    "3.5j": (0x00000000, 0x40600000),
    "2j": (0x00000000, 0x40000000),
    "3j": (0x00000000, 0x40400000),
    "j": (0x00000000, 0x3F800000),
    "-j": (0x00000000, 0xBF800000),
    "J": (0x00000000, 0x3F800000),
    "1.25+3.5j": (0x3FA00000, 0x40600000),
    "-2.5e1+3j": (0xC1C80000, 0x40400000),
    "1.5-2j": (0x3FC00000, 0xC0000000),
    "  1+2j  ": (0x3F800000, 0x40000000),
    "infj": (0x00000000, 0x7F800000),
    "inf+nanj": (0x7F800000, 0x7FC00000),
    "1e_2j": (0x00000000, 0x42C80000),
    # PRINT_REPR parenthesizes a non-zero real. complex() rejects that form.
    "(1.25+3.5j)": (0x3FA00000, 0x40600000),
    "(-25+3j)": (0xC1C80000, 0x40400000),
    "(1.5-2j)": (0x3FC00000, 0xC0000000),
}

PAREN_REPR = {"(1.25+3.5j)", "(-25+3j)", "(1.5-2j)"}

REJECT = ("", "1e", "1e+", "1.2.3", "++1", "nanx", ".", "+")
REJECT_COMPLEX = ("1+2", "1+2jj", "(1+2j", "1+", "++1j")

SUITE = ROOT / "upycore" / "programs" / "hw" / "alu" / "floatparse.py"


def _float_bits(text: str) -> int:
    return link.f32_bits(link.mp_parse_float(text))


def _complex_bits(text: str) -> tuple[int, int]:
    real, imag = link.mp_parse_complex(text)
    return link.f32_bits(real), link.f32_bits(imag)


def _const_texts(data: bytes) -> list[tuple[str, str]]:
    catalog = Catalog.load()
    module = read_mpy(data, "<numeric>", catalog, numeric=True)
    found: list[tuple[str, str]] = []
    for obj in module.objs:
        if isinstance(obj, FloatConst):
            found.append(("float", obj.text))
        elif isinstance(obj, ComplexConst):
            found.append(("complex", obj.text))
    return found


class NumericConstTest(unittest.TestCase):
    def test_float_spellings_match_oracle_bits(self) -> None:
        for text, bits in FLOAT_BITS.items():
            self.assertEqual(_float_bits(text), bits, text)

    def test_complex_spellings_keep_the_real_part(self) -> None:
        for text, bits in COMPLEX_BITS.items():
            self.assertEqual(_complex_bits(text), bits, text)
        # The old decoder kept only a trailing imag and stored real as 0.
        self.assertEqual(_complex_bits("(1.25+3.5j)")[0], 0x3FA00000)
        self.assertNotEqual(_complex_bits("1.25+3.5j"), (0, 0))

    def test_rejected_spellings(self) -> None:
        for text in REJECT:
            with self.assertRaises(ValueError, msg=text):
                link.mp_parse_float(text)
        for text in REJECT_COMPLEX:
            with self.assertRaises(ValueError, msg=text):
                link.mp_parse_complex(text)

    def test_encode_places_both_words(self) -> None:
        img = link.Image()
        value = ComplexConst(0j)
        value.text = "(1.25+3.5j)"
        tag, addr = link.encode_const(img, value)
        self.assertEqual(tag, link.T["COMPLEX"])
        self.assertEqual(img.words[addr // 4], 0x3FA00000)
        self.assertEqual(img.words[addr // 4 + 1], 0x40600000)

    def test_suite_const_texts_are_in_the_table(self) -> None:
        if not build.MPY_CROSS.is_file():
            self.skipTest("mpy-cross is not built")
        out = Path("/tmp/floatparse-cross.mpy")
        build.mpy_cross(SUITE, out, "floatparse.py")
        texts = _const_texts(out.read_bytes())
        self.assertGreaterEqual(len(texts), 20)
        self._assert_known(texts)
        mpyc_out = Path("/tmp/floatparse-mpyc.mpy")
        build.compile_mpyc(SUITE, mpyc_out, "floatparse.py")
        self._assert_known(_const_texts(mpyc_out.read_bytes()))

    def _assert_known(self, texts: list[tuple[str, str]]) -> None:
        for kind, text in texts:
            if kind == "float":
                self.assertIn(text, FLOAT_BITS, text)
                self.assertEqual(_float_bits(text), FLOAT_BITS[text], text)
            else:
                self.assertIn(text, COMPLEX_BITS, text)
                self.assertEqual(_complex_bits(text), COMPLEX_BITS[text], text)

    def test_table_matches_oracle_when_built(self) -> None:
        if not build.ORACLE.is_file():
            self.skipTest("unix oracle is not built")
        script = [
            "import struct",
            "def fb(x):",
            "    return struct.unpack('<I', struct.pack('<f', x))[0]",
        ]
        floats = list(FLOAT_BITS)
        complexes = [text for text in COMPLEX_BITS if text not in PAREN_REPR]
        for index, text in enumerate(floats):
            script.append(f"x=float({text!r}); print('F', {index}, '%08x' % fb(x))")
        for index, text in enumerate(complexes):
            script.append(
                f"z=complex({text!r}); print('C', {index}, '%08x' % fb(z.real), '%08x' % fb(z.imag))"
            )
        proc = subprocess.run(
            [str(build.ORACLE), "-c", "\n".join(script)],
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        lines = proc.stdout.splitlines()
        self.assertEqual(len(lines), len(floats) + len(complexes))
        for index, text in enumerate(floats):
            bits = int(lines[index].split()[2], 16)
            self.assertEqual(bits, FLOAT_BITS[text], text)
        base = len(floats)
        for index, text in enumerate(complexes):
            parts = lines[base + index].split()
            bits = (int(parts[2], 16), int(parts[3], 16))
            self.assertEqual(bits, COMPLEX_BITS[text], text)


if __name__ == "__main__":
    unittest.main()
