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

There is no DRAM. There is no L1 and no L2. SRAM is one cycle. Flash adds
`MPY_FLASH_WAIT_STATES` (default 1) on top of that cycle. The 12-byte
fetch window is instruction bytes only. It is not part of this data map.

## Tag table

Locked by the pivot plan. Tag `0101` is reserved.

| Tag | Name | Registers | Payload |
| --- | --- | --- | --- |
| `0000` | CONTROL | 1 | `[3:0]` kind: `0` empty, `1` `None`, `2` null / end of iteration, `3` dict tombstone, `4` `False`, `5` `True` |
| `0001` | INT | 1 | Signed 32-bit. Bytecode small-ints stay in the 31-bit range |
| `0010` | INT64 | 2 | Low 32 bits, then a `CONT` register with the high 32 bits |
| `0011` | FLOAT | 1 | IEEE binary32 |
| `0100` | COMPLEX | 2 | Real binary32, then a `CONT` register with the imaginary binary32 |
| `0101` | reserved | — | Not assigned |
| `0110` | QSTR | 1 | Interned-string id |
| `0111` | SHORT_STR | 4 | Length in the first payload's low byte, then up to 15 bytes across this register and three `CONT` registers |
| `1000` | STR | 1 | Pointer. Length, hash, and bytes live in the object |
| `1001` | TUPLE | 1 | Pointer |
| `1010` | MUT_COLLEC | 1 | Pointer. Low 2 bits are `0` list, `1` dict, `2` set, `3` bytearray. The address clears those bits |
| `1011` | RANGE | 1 | Pointer to start, stop, step |
| `1100` | ITER | 1 | Pointer to the iterable and the index |
| `1101` | BYTES | 1 | Pointer to an immutable `bytes` |
| `1110` | OBJECT | 1 | Pointer. Word 0 is the kind |
| `1111` | CONT | 1 | Extra entry of INT64, COMPLEX, or SHORT_STR |

`False` and `True` are CONTROL kinds 4 and 5. Kind 6 is `RF_LINK`, a
pointer to a spilled register chunk; the collector follows it, and
arithmetic does not. Arithmetic and dict hashing use `False` and `True`
as int 0 and int 1. They are not pointers. CONTROL, INT, INT64,
FLOAT, COMPLEX, QSTR, SHORT_STR, CONT, and the reserved code are not
pointers. STR, TUPLE, MUT_COLLEC, RANGE, ITER, BYTES, and OBJECT are.

A `MUT_COLLEC` address is the payload with bits `[1:0]` cleared. Objects
are 4-byte aligned, so those bits are otherwise zero. Other pointers use
all 32 payload bits. The tag says what the pointer is.

`n_state` counts Python values. Call setup expands INT64 and COMPLEX to two
physical registers and SHORT_STR to four. The compiler emits stock bytecode
and does not encode that expansion.

SHORT_STR bytes sit after the length. The head word is
`{byte2, byte1, byte0, length}`. Each `CONT` word holds the next four bytes,
low byte first. A length above 15 is rejected.

OBJECT kinds in word 0:

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
| Flash | `0x0000_0000` | 512 KB | Linked image. First 8 bytes reserved |
| SRAM | `0x2000_0000` | 256 KB | Frame reserve, schedule ring, handler table, system roots, argument buffer, GC pool |
| MMIO | `0x4000_0000` | 4 KB | UART, GPIO, timers, IRQ, and the blocks in `mpy_peripherals.md` |
| Sim control | `0xE000_0000` | 256 B | Halt reason, cycle counter. Simulation only |

An address outside these windows is a bus fault. `0x00F4_0000` is outside
them: the old 256 KB register spill does not move into this map. A store to
flash faults. An unaligned word faults. A load of flash byte 0 or 4 returns
zero; those bytes stay reserved so a pointer payload is never 0 or 4.

`-X heapsize` names the GC pool only.

### SRAM

The header in `upycore/tools/mpy_abi.py` is the map; `mpy_abi.svh` and the
firmware's `_abi.py` are generated from it.

| Region | Base | Window | Used |
| --- | --- | ---: | --- |
| Frame reserve | `0x2000_0000` | 32 KB | Frame records back to back, and register chunks growing down from the end |
| Schedule ring | `0x2000_8000` | 64 B | 8 entries of function, argument |
| Handler table | `0x2000_8040` | 64 B | 8 sources, function and argument each |
| System roots | `0x2000_8080` | 128 B | 32 tagged words (`SR` in `mpy_abi.py`) |
| Argument buffer | `0x2000_8100` | 1 KB | 256 tagged words; slot 0 the callable, arguments from slot 32 |
| GC pool | `0x2000_8500` | 228096 B (`0x37B00`) | The rest of the 256 KB |

The pool ends at `0x2004_0000`. Sources, in order: timer, UART RX, GPIO,
soft, `GC_REQ`, sim, `KBD`, `MBOX`. The schedule depth is 8. The ring and
the table are tagged slots; their nibbles live in the SRAM side array.

The collector's second root span, `gc_root1`, is `[0x2000_8000,
0x2000_8500)`: the ring, the handler table, the system roots, and the
argument buffer. The live copy of the ring and the handler table is the
flop file in `mpy_irq`. The core mirrors it into these two windows at the
next bytecode boundary after a handler write, a push, or a pop, and
before any collection: ring slot `i` (mod 8) at `0x2000_8000 + 8*i`,
handler `src` at `0x2000_8040 + 8*src`, function word then argument word,
each with its tag. A ring slot outside `[head, tail)` and an empty
handler are the empty word (tag `CONTROL`, payload 0). An `INT` argument
is not a pointer, whatever its payload. `IRQ_TABLE` is not consulted.

### Frame record

Records are variable size and sit back to back from `0x2000_0000`. A
call that would cross the end of the reserve, or the lowest register
chunk, raises `RuntimeError: maximum recursion depth exceeded`.

| Word | Contents |
| --- | --- |
| 0–15 | Header (`FR` in `mpy_abi.py`): previous record, raw code, PC, opcode PC, stack and exception depths, return kind and continuation, globals, locals, function, three continuation words, qstr and const tables, generator |
| 16 | Register-ring metadata: chunk count, local count, ring base |
| 17 … | `n_state` locals, then 3 words per exception entry, then the resident operand stack when the frame is spilled |

Raw header words carry tag `CONTROL`, so the collector skips them. Tags
for every SRAM slot are the side array, which is not its own address
window and is not subtracted from the pool. A list slot is 4 bytes of
pool plus one nibble.

### MMIO offsets

Offsets from `0x4000_0000`. `mpy_soc` sends the window to `mpy_periph`
and the blocks below; `mpy_mem` never sees it. Word access only. The
register rules are `upycore/docs/mpy_peripherals.md`.

| Offset | Name |
| --- | --- |
| `0x00` | `UART_TX` |
| `0x04` | `UART_RX` |
| `0x08` | `GPIO_OUT` |
| `0x0C` | `TIMER_COUNT` |
| `0x10` | `IRQ_STATUS` |
| `0x14` | `IRQ_ENABLE` |
| `0x18` | `IRQ_HARD` |
| `0x1C` | `IRQ_GIE` |
| `0x20` | `IRQ_ACTIVE` |
| `0x24` | `IRQ_TABLE` |
| `0x28` | `SCHED_HEAD` |
| `0x2C` | `SCHED_TAIL` |
| `0x30` | `GPIO_IN` |
| `0x34` | `GPIO_EDGE` |
| `0x38` | `TICKS` |
| `0x3C` | `UART_BAUD` |
| `0x40` | `UART_STATUS` |
| `0x44` | `TIMER_PRESC` |
| `0x48` | `GPIO_OE` |
| `0x4C` | `GPIO_PULLUP` |
| `0x50` | `GPIO_PULLDOWN` |
| `0x54` | `GPIO_STATUS` |
| `0x58` | `UART_KBD` |

The blocks past the base registers, one 256-byte range each:

| Range | Block | RTL |
| --- | --- | --- |
| `0x100` | Mailbox | not built yet |
| `0x200` | PWM | `mpy_pwm.sv` |
| `0x300` | SPI controller | `mpy_spi.sv` |
| `0x400` | I2C controller | `mpy_i2c.sv` |
| `0x500` | WDT | `mpy_wdt.sv` |
| `0x600` | SYS (frequency, straps, reset controller, id) | `mpy_sys.sv` |
| `0x700` | TIMER1..3 | not built |
| `0x800` | ADC | `mpy_adc.sv` |
| `0x900` | Pin mux | `mpy_pinmux.sv` |

A system reset (`SYS_RESET`, or the watchdog) zeroes all of SRAM and its
tags before the hart boots again, so SRAM reads zero at every boot, as it
does at power-up.

The sim-control page is not a Cortex-M system-control block. Halt names
for that page: clean return, uncaught exception, unsupported opcode, bad
image, flash store, unaligned access, bus fault, stack overflow, step limit.

## Where the constants live

`upycore/rtl/mpy_defs.svh` holds the tag table, the widths, the register-file
depth (`MPY_RF_DEPTH` / `MPY_RF_ADDR_W`), and this map.
`upycore/rtl/mpy_regfile.sv` is the 16-entry array. `upycore/rtl/mpy_mem.sv`
is flash, SRAM, the frame spill, and the other two windows.
`upycore/rtl/upycore_defs.svh` holds the datapath opcodes.
`make synth` elaborates these modules with Yosys + yosys-slang.
