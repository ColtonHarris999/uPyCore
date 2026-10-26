#!/usr/bin/env python3
"""Write a flat binary as $readmemh words: one 32-bit little-endian word a line."""

import sys
from pathlib import Path


def main(argv: list[str]) -> int:
    data = Path(argv[1]).read_bytes()
    data += b"\0" * (-len(data) % 4)
    words = [int.from_bytes(data[i:i + 4], "little") for i in range(0, len(data), 4)]
    Path(argv[2]).write_text("".join(f"{w:08x}\n" for w in words))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
