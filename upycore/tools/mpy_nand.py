#!/usr/bin/env python3
"""Pack a linked image into the boot stream mpy_boot reads from SPI NAND.

The stream (upycore/docs/mpy_boot.md) is little-endian 32-bit words from
the first byte of NAND page 0:

    MPY_BOOT_MAGIC ("UPYB"), image word count n,
    then ceil(n / 8) groups: one packed tag word (nibble i is the tag of
    word i of the group), then eight image words (zero past the end)

so the loader writes each image word together with its tag in one SRAM
write. A board I/O image is followed by the I/O core's section:

    MPY_IOCB_MAGIC ("IOCB"), code word count nc, data word count nd,
    nc code words, nd data words

from the I/O core's build (``code.hex`` and ``data.hex``, one word a line). The input is the pair mpy_link.py writes: ``<prefix>.hex`` (one image
word per line) and ``<prefix>.tags.hex`` (eight tag nibbles per line).

Usage::

    mpy_nand.py build/mpy/run/hello/image          # writes image.nand.bin and image.nand.hex

Program ``.nand.bin`` at page 0 of the flash. ``.nand.hex`` (one byte per
line) is what the testbench's SPI NAND model loads with ``+NAND=``.
"""

from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

BOOT_MAGIC = 0x4259_5055  # "UPYB", MPY_BOOT_MAGIC in upycore/rtl/mpy_defs.svh
IOCB_MAGIC = 0x4243_4F49  # "IOCB", MPY_IOCB_MAGIC
import mpy_abi as abi


def _words(path: Path) -> list[int]:
    return [int(ln, 16) for ln in path.read_text().split()]


def pack(image: Path, iocore: Path | None = None) -> bytes:
    """Boot stream for the linked image whose files start with ``image``,
    with the I/O core's section from the folder ``iocore`` when given."""

    data = _words(Path(f"{image}.hex"))
    tags = _words(Path(f"{image}.tags.hex"))
    n = len(data)
    if n <= max(abi.HDR.values()):
        raise ValueError(f"{image}: truncated image header")
    abi.memory_layout(n * 4, data[abi.HDR["POOL_BYTES"]])
    if (data[abi.HDR["IMAGE_BYTES"]] + 31) // 32 * 8 != n:
        raise ValueError(f"{image}: image size header disagrees with padded word count")
    groups = (n + 7) // 8
    data += [0] * (8 * groups - n)
    tags += [0] * (groups - len(tags))
    out = [BOOT_MAGIC, n]
    for g in range(groups):
        out.append(tags[g])
        out.extend(data[8 * g:8 * g + 8])
    if iocore is not None:
        code = _words(iocore / "code.hex")
        dwords = _words(iocore / "data.hex") if (iocore / "data.hex").exists() else []
        out += [IOCB_MAGIC, len(code), len(dwords), *code, *dwords]
    return struct.pack(f"<{len(out)}I", *out)


def write_files(image: Path, iocore: Path | None = None) -> tuple[Path, Path]:
    """Write ``<image>.nand.bin`` and ``<image>.nand.hex``; return both paths."""

    blob = pack(image, iocore)
    bin_path = Path(f"{image}.nand.bin")
    hex_path = Path(f"{image}.nand.hex")
    bin_path.write_bytes(blob)
    hex_path.write_text("".join(f"{b:02x}\n" for b in blob))
    return bin_path, hex_path


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("image", type=Path, help="image prefix (the path before .hex)")
    ap.add_argument("--iocore", type=Path, help="the I/O core's build folder (code.hex, data.hex)")
    args = ap.parse_args(argv)
    try:
        bin_path, hex_path = write_files(args.image, args.iocore)
    except (OSError, ValueError) as exc:
        print(f"mpy_nand: {exc}", file=sys.stderr)
        return 1
    print(f"{bin_path} ({bin_path.stat().st_size} bytes)")
    print(hex_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
