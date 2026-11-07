"""Shared SRAM layout and boot-stream capacity checks."""
import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import mpy_abi as abi
import mpy_nand


class MemoryLayoutTest(unittest.TestCase):
    def test_capacity_follows_image_size(self):
        for image in (65, 32 * 1024, 256 * 1024 + 32):
            aligned, data, heap = abi.memory_layout(image)
            self.assertEqual(aligned % 32, 0)
            self.assertEqual(aligned + data, abi.SRAM_BYTES)
            # The heap fills the data region up to the GC table's capacity.
            self.assertEqual(heap, min(data - (abi.GC_POOL_BASE - abi.SRAM_BASE), abi.GC_TABLE_BYTES))
        self.assertEqual(abi.memory_layout(65)[0], 96)

    def test_gc_table_covers_the_largest_real_heap(self):
        # Every image carries the firmware; an empty program links to
        # 191,016 bytes today, which leaves the largest heap a real image
        # can have. The table must hold it (and not much more).
        heap = abi.memory_layout(191016)[2]
        self.assertEqual(heap, 299200)
        self.assertLessEqual(heap, abi.GC_TABLE_BYTES)
        self.assertLess(abi.GC_TABLE_BYTES - heap, 16 * 1024)
        self.assertEqual(abi.memory_layout(1024)[2], abi.GC_TABLE_BYTES)
        with self.assertRaises(ValueError):
            abi.memory_layout(1024, abi.GC_TABLE_BYTES + 16)

    def test_last_heap_block_and_first_oversized_image(self):
        largest = abi.SRAM_BYTES - (abi.GC_POOL_BASE - abi.SRAM_BASE) - 32
        self.assertEqual(abi.memory_layout(largest)[2], 32)
        with self.assertRaisesRegex(ValueError, "shared SRAM"):
            abi.memory_layout(largest + 1)

    def test_explicit_heap_cap_is_checked(self):
        self.assertEqual(abi.memory_layout(1024, 16)[2], 16)
        for heap in (-16, 1, abi.GC_POOL_BYTES):
            with self.assertRaises(ValueError):
                abi.memory_layout(1024, heap)

    def test_stream_accepts_image_above_old_image_cap(self):
        n = (256 * 1024 + 32) // 4
        words = [0] * n
        words[abi.HDR["IMAGE_BYTES"]] = n * 4
        words[abi.HDR["POOL_BYTES"]] = abi.memory_layout(n * 4)[2]
        with tempfile.TemporaryDirectory() as tmp:
            image = Path(tmp) / "image"
            Path(f"{image}.hex").write_text("".join(f"{x:08x}\n" for x in words))
            Path(f"{image}.tags.hex").write_text("00000000\n" * (n // 8))
            packed = mpy_nand.pack(image)
            self.assertEqual(struct.unpack_from("<II", packed), (mpy_nand.BOOT_MAGIC, n))
            words[abi.HDR["POOL_BYTES"]] = abi.GC_POOL_BYTES
            Path(f"{image}.hex").write_text("".join(f"{x:08x}\n" for x in words))
            with self.assertRaises(ValueError):
                mpy_nand.pack(image)


if __name__ == "__main__":
    unittest.main()
