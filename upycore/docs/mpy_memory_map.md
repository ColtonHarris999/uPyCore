# uPyCore memory map

Value layout for the MicroPython hart. The CPython map in
[`architecture.md`](architecture.md) stays with that hart. This page is the
one later phases read for the GC pool size.

A value is a 4-bit tag beside a 32-bit payload. The register file is one
36-bit array, 16 entries, and it holds the operand stack only. Locals live
in the frame in SRAM, up to 255 of them. A read of a register returns the
tag and the payload together. SRAM and flash data words are 32 bits and
are byte-addressed. The tag does not sit in the word. Slot `i` of a region
is the word at `data_base + 4*i`, and nibble `i` of a side array. Eight
tags fill one 32-bit word. Lane 0 is bits `[3:0]`. A store that does not
ask for the tag leaves the nibble as it was.

The eight most recently used locals sit in a side cache next to the
register file. A hit reads or writes that register instead of SRAM. A
displaced line is written back, and every dirty line is written back
when the frame is spilled for a call or a collection.

The register file is a ring of the newest stack values. Logical slot 0 is
the oldest resident slot; the stack pointer is the count of resident
slots. Appending when 12 slots are resident copies the oldest values into a
block growing down from the end of the frame reserve (`0x2000_8000`).
While the stack has only been growing, that block holds 8 values. At 12
resident slots with no link, that chunk fits and leaves 5, which is above
the line where the next instruction would pull the chunk back. After a pop
the block holds 4, which is cheap to pull back. The block is 16-byte
aligned, so the link value can keep its kind in the low nibble: tag
`CONTROL`, kind `RF_LINK` (6), and `payload[31:4]` is the block address
shifted right by 4. That link is written into the resident slot just
after the copied values, which becomes logical slot 0.

| Offset | Size | Contents |
| --- | ---: | --- |
| `0` | 4 B | Previous chunk address in bits `[31:4]` (0 for the oldest chunk). The word tag holds count `[5:4]` and bits `[3:0]` hold count `[3:0]` |
| `4` | 4·ceil(count/8) B | Count tags, eight nibbles per word. Lane 0 is bits `[3:0]` |
| next | 4·count B | Payloads, oldest first |

The byte length is padded out to a multiple of 16. A 4-value chunk is
32 bytes. An 8-value chunk is 48, which is the most that still reloads
into the 16-entry ring. Every slot in the chunk is a value. The previous
link lives in the header, so a later spill frees one register per copied
value (the first spill of a chain frees one fewer, because the new link
occupies a freed slot). A walk reads one header word per chunk.

There is no DRAM. There is no L1 and no L2. SRAM is one cycle. The image
region is the same SRAM, so it adds no wait state
(`MPY_FLASH_WAIT_STATES` is 0; the parameter remains for an external image
memory). The fetch queue
([`mpy_boot.md`](mpy_boot.md#instruction-fetch)) holds instruction bytes
only. It is not part of this data map.

## Tag table

Each value occupies one 36-bit slot. The tag is bits 35:32 and the
payload is bits 31:0.

| Tag | Name | Payload |
| --- | --- | --- |
| `0000` | CONTROL | Kind in bits 3:0, with the spill address in the remaining bits for `RF_LINK` |
| `0001` | INT | Signed 32-bit. Bytecode small integers stay in the 31-bit range |
| `0010` | INT64 | Pointer to a two-word box, low word first |
| `0011` | FLOAT | IEEE binary32 |
| `0100` | COMPLEX | Pointer to a two-word box holding the real and imaginary binary32 values |
| `0101` | BUILTIN | Native ID in bits 31:24 and read-only image address in bits 23:0 |
| `0110` | QSTR | Interned-string ID |
| `0111` | FUNCTION | Pointer to a bytecode function object |
| `1000` | STR | Pointer to an immutable string header |
| `1001` | TUPLE | Pointer to the length and inline elements |
| `1010` | MUT_COLLEC | Address in bits 31:2 and kind in bits 1:0. Kind 0 is list, 1 dict, 2 set, and 3 bytearray |
| `1011` | RANGE | Pointer to start, stop, and step |
| `1100` | ITER | Pointer to the iterator record |
| `1101` | BYTES | Pointer to an immutable bytes header |
| `1110` | OBJECT | Pointer to an object whose word 0 gives its kind |
| `1111` | CONTINUE | Pointer to internal storage, including container backing arrays |

CONTROL kinds are 0 empty, 1 `None`, 2 end of iteration, 3 tombstone,
4 `False`, 5 `True`, and 6 `RF_LINK`. The collector follows the spill
link separately. It treats INT64, COMPLEX, FUNCTION, STR, TUPLE,
MUT_COLLEC, RANGE, ITER, BYTES, OBJECT and CONTINUE as pointer tags.
BUILTIN points into the static image. The core masks off its native
ID when accessing the object. MUT_COLLEC clears its kind bits to form
the address.

`n_state` counts Python values, one slot apiece. FUNCTION and BUILTIN
headers still carry their kind at word 0 for generic readers.

### Immutable string storage

STR and BYTES use a three-word header. Word 0 is byte length, word 1
contains the hash and non-ASCII flag, and word 2 stores the data
pointer. The bytes start at header address + 12, and word 2 always
holds that address. The core and collection engines can compute it in
place of the pointer read. List and bytearray backing storage can move.
QSTR byte addresses come from the qstr descriptor.

### Object header kinds in word 0

| Kind | Value |
| --- | ---: |
| INSTANCE | 1 |
| TYPE | 2 |
| EXCEPTION | 3 |
| CELL | 4 |
| FUNCTION | 5 |
| GENERATOR | 6 |
| BOUND_METHOD | 7 |
| BUILTIN | 8 |
| MODULE | 9 |
| NOTIMPL | 18 |

Word 1 is the type pointer, or 0. Fields start at word 2. Heap words are
32-bit payloads with a tag nibble each. There is no 32-byte stride.

## Windows

| Window | Base | Size | Contents |
| --- | --- | ---: | --- |
| Flash | `0x0000_0000` | `I = align_up(image_bytes, 32)` | Linked image, in the on-chip image SRAM that `mpy_boot` fills from SPI NAND ([`mpy_boot.md`](mpy_boot.md)). First 8 bytes reserved |
| SRAM | `0x2000_0000` | `524288 - I` | Frame reserve, schedule ring, handler table, roots, argument buffer, GC pool |
| MMIO | `0x4000_0000` | 4 KB | The I/O bridge (`mpy_iobr`): registers and the state page |
| Sim control | `0xE000_0000` | 256 B | Halt reason, cycle counter. Simulation only |

An address outside these windows is a bus fault. `0x00F4_0000` is outside
them: the old 256 KB register spill does not move into this map. A store to
flash faults. An unaligned word faults. A load of flash byte 0 or 4 returns
zero; those bytes stay reserved so a pointer payload is never 0 or 4.

`-X heapsize` names the GC pool only.

### SRAM

| Region | Base | Window | Used |
| --- | --- | ---: | --- |
| Frame reserve | `0x2000_0000` | 32 KB | Frame stack |
| Schedule ring | `0x2000_8000` | 64 B | 8 entries of function, argument |
| Handler table | `0x2000_8040` | 64 B | 48 B: 6 sources, function and argument each |
| System roots | `0x2000_8080` | 128 B | 32 tagged words |
| Argument buffer | `0x2000_8100` | 1 KB | 256 tagged words |
| GC pool | `0x2000_8500` | `min(524288 - I - 0x8500, 307200)` B | Remaining shared SRAM, up to the allocation table's capacity, optionally capped by image header |

`upycore/tools/mpy_abi.py` is the source for these bases. The pool ends at
`0x2000_0000 + 524288 - I` (or earlier with a heap cap). `mpy_gc`'s
allocation table holds `GC_TABLE_BYTES` = 307,200 bytes of heap (19,200
blocks, 2 bits each, in a 600 × 64 table SRAM): every image carries the firmware, and an empty program
(191,016 bytes today) leaves at most 299,200 bytes, so a real image never
reaches the cap; a smaller image would just leave SRAM unused. Both windows
share the same four SRAM banks; their logical bases do not imply separate
physical memories. See [`mpy_boot.md`](mpy_boot.md) for mapping and bounds.
Sources, in order: timer, UART RX, GPIO, soft, `GC_REQ`,
sim. The handler table is a GC root. The schedule depth is 8. The ring and
the table are tagged slots. Each SRAM word holds its own tag beside the
payload (36 bits), so there is no separate tag array.

### Frame record

Stride 512 bytes. Thirty-two records fill the 16 KB reserve.

| Offset | Size | Contents |
| --- | ---: | --- |
| `0x000` | 256 B | 64 payload words. Slot `i` at `+ 4*i` |
| `0x100` | 32 B | 8 packed tag words. Nibble `i` is lane `i % 8` of word `i / 8` |
| `0x120` | 16 B | Return PC, `n_state`, frame index, zero |
| `0x130` | 208 B | Padding inside the stride |

A spill writes every physical register. Payload bytes plus tag bytes plus
the header for 32 frames are 9728 bytes, inside the 16 KB. Tags for these
slots are the packed words in the record, not a second copy. Tags for every
other SRAM slot are the side array, which is not its own address window and
is not subtracted from the pool. A list slot is 4 bytes of pool plus one
nibble.

The call stack is 32 frames. A 33rd spill faults. Software reports
`RuntimeError: maximum recursion depth exceeded`.

### MMIO window

Offsets from `0x4000_0000`. The window is the hart's bridge to the I/O
core ([`mpy_io_core.md`](mpy_io_core.md#bridge)). `mpy_soc` answers the
implemented words itself, beside the simulator page; `mpy_mem` answers
every other address in the window with a bus fault (or the unaligned
fault). The words are untagged: never a GC root, never heap.

| Offset | Name |
| --- | --- |
| `0x000` | `CMD` |
| `0x004` | `RSP` |
| `0x008` | `STATUS` |
| `0x00C` | `EVT` |
| `0x010` | `EVT_EN` |
| `0x014` | `EVT_SET` |
| `0x018` | `EVT_MASK` |
| `0x01C` | `IOC_CTRL` |
| `0x020` | `CON_RX` |
| `0x024` | `CON_MODE` |
| `0x028` | `CMD_SENT` |
| `0x02C` | `RESET_CAUSE` |
| `0x030` | `SYS_RESET` |
| `0x034` | `KEEP` (survives a system reset) |
| `0x800`–`0x87C` | State page, 32 words the I/O core writes |
| `0xC00`–`0xC1C` | State page, 8 words the hart writes |

The register list the draft hart-side peripheral block (`mpy_periph`,
`mpy_mmio_pkg`) used at these offsets is not mapped: that block is not
instantiated, and board I/O goes through the I/O core.

The sim-control page is not a Cortex-M system-control block. Halt names
for that page: clean return, uncaught exception, unsupported opcode, bad
image, flash store, unaligned access, bus fault, stack overflow, step limit.

## Where the constants live

`upycore/rtl/mpy_defs.svh` holds the tag table, the widths, the register-file
depth (`MPY_RF_DEPTH` / `MPY_RF_ADDR_W`), and this map.
`upycore/rtl/mpy_core.sv` owns the 16-entry operand ring.
`upycore/rtl/upycore_defs.svh` holds the datapath opcodes.
`make synth` elaborates these modules with Yosys + yosys-slang.
