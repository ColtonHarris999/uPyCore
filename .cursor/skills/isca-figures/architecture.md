# uPyCore machine, for figures

Draw from this file. When it conflicts with a draft sentence, a comment in `mpy_container.sv`, or `mpy_defs.svh` object-kind numbers, this file wins. Sources are `upycore/rtl/mpy_core.sv`, `upycore/rtl/mpy_defs.svh`, `upycore/rtl/mpy_abi.svh`, `upycore/firmware/`, and `upycore/rtl/mpy_container.sv` only where this file says so.

The draft name RFSF is a spill chunk. The draft name $sb$ is RTL `rf_base`. Figures use $sp$, $sb$, and `RF_LINK`.

## Do not draw

- A spill of 12 values, 12 packed tags, and 12 payloads. A growth spill copies 8. A spill after a pop copies 4.
- The whole register file copied into the callee. `CALL` snapshots the resident ring at the end of the caller. The callee ring starts empty.
- A list header of two words, or a capacity word at `pointer-4`. The live list header is three words.
- `tp_hash` at byte offset 20. Live type word 5 (offset 20) is the MRO tuple. `mpy_container.sv` still loads offset 20 under that stale name.
- Object-kind numbers from `MPY_OB_*` in `mpy_defs.svh`. Those disagree with `ABI_OB_*`. Use the ABI numbers below.
- A scoreboard, rename, or a second memory master inside `mpy_soc`. The core, the collector, and (in the design) the container accelerator take turns on one port. String walks are core microcode, not a separate module.
- A fixed 190-frame stack. The frame reserve is 32 KB. Frames grow up from `0x2000_0000`. Chunks grow down from `0x2000_7E00`. Meeting in the middle raises recursion.
- `False` and `True` as their own tags. They are `CONTROL` kinds 4 and 5.

## Value

36 bits. Tag is [35:32]. Payload is [31:0]. The register file is 16 entries and holds the operand stack only. Locals live in the frame.

| Tag | Name | Registers | Payload |
| --- | --- | --- | --- |
| `0000` | `CONTROL` | 1 | Kind in [3:0] |
| `0001` | `INT` | 1 | Signed 32-bit |
| `0010` | `INT64` | 2 | Low 32, then `CONT` high 32 |
| `0011` | `FLOAT` | 1 | IEEE binary32 |
| `0100` | `COMPLEX` | 2 | Real binary32, then `CONT` imaginary |
| `0101` | reserved | 0 | Unassigned |
| `0110` | `QSTR` | 1 | Interned-string id |
| `0111` | `SHORT_STR` | 4 | Always four registers, at most 15 bytes |
| `1000` | `STR` | 1 | Pointer to a 3-word header |
| `1001` | `TUPLE` | 1 | Pointer. Length, then inline elements |
| `1010` | `MUT_COLLEC` | 1 | Kind in [1:0]. Address is [31:2] with [1:0] cleared |
| `1011` | `RANGE` | 1 | Pointer to start, stop, step |
| `1100` | `ITER` | 1 | Pointer to the 4-word iterator record |
| `1101` | `BYTES` | 1 | Pointer. Same 3-word header as `STR` |
| `1110` | `OBJECT` | 1 | Pointer. Word 0 is the kind |
| `1111` | `CONT` | 1 | Continuation only. Not a value |

`CONTROL` kinds: 0 empty (the core's null slot; the ABI constant is named `ABI_CTL_NULL`), 1 `None`, 2 end of iteration (`ABI_CTL_STOP`), 3 tombstone, 4 `False`, 5 `True`, 6 `RF_LINK`.

`MUT_COLLEC` kinds: 0 list, 1 dict, 2 set, 3 bytearray.

Pointer tags: `STR`, `TUPLE`, `MUT_COLLEC`, `RANGE`, `ITER`, `BYTES`, `OBJECT`. Everything else is immediate, including `False`, `True`, and `RF_LINK`.

`SHORT_STR` head payload is `{byte2, byte1, byte0, length}`. Each `CONT` holds the next four bytes, low byte first. Length above 15 faults.

## Ring and spill

$sp$ is the number of resident slots. $sb$ (`rf_base`) is the physical index of logical slot 0. Physical index of logical $i$ is $(sb + i) \bmod 16$.

Fetch spills when $sp \ge 12$. Reload when $sp \le 4$ and logical 0 is an `RF_LINK`. A spill leaves $sp \ge 5$, so the next fetch does not reload.

Growth spill (`cfg_grow = 8`, the stack has only been growing): copy the 8 oldest values. Write the link at old logical slot 7. Advance $sb$ by 7. New $sp = old\ sp - 8 + 1$. From $sp = 12$ this yields $sp = 5$, with logical 0 = link and logical 1..4 = the values that were not copied.

Pop spill (`MPY_RF_CHUNK_MIN = 4`): copy 4 values. Same link rule.

Chunk for $n$ values, 16-byte aligned. $n$ is 4 or 8.

| Offset | Contents |
| --- | --- |
| 0 | Payload [31:4] = previous chunk address (0 if oldest). Payload [3:0] = count [3:0]. The side tag nibble holds count [5:4] |
| 4 | Tag nibbles, eight per word, lane 0 in bits [3:0], oldest first. One word when $n \le 8$ |
| next | $n$ payloads, oldest first |
| end | Pad so the byte length is a multiple of 16 |

An 8-value chunk is 48 bytes. A 4-value chunk is 32 bytes. `RF_LINK` payload [31:4] is the chunk address shifted right by 4. The address is 16-byte aligned, so kind 6 occupies [3:0].

The first spill of a chain frees $n-1$ registers because the link reuses one freed slot. A later spill moves the old link into the new chunk header and frees $n$ registers.

## Locals and the frame

Locals and parameters stay in the frame until `LOAD_FAST` / `STORE_FAST`. An 8-entry write-back cache sits beside the ring. It is flushed before a call or a collection.

Frame base is `fbase`. Seventeen header words, then locals at byte `0x44`, then `nexc` exception slots of 3 words, then `ftop`. `CALL` writes the resident ring at `ftop` in logical order ($sp$ words) and starts the callee at the following word with $sp = 0$, $sb = 0$, and a cleared ring.

Header words:

| Offset | Contents |
| --- | --- |
| `0x00` | Previous frame |
| `0x04` | Raw code |
| `0x08` | Return PC |
| `0x0C` | Opcode PC |
| `0x10` | Flags [31:24], $n_{\mathrm{loc}}$ [22:16], exception depth [12:8], $sp$ [6:0] |
| `0x14` | $n_{\mathrm{exc}}$ [20:16], continuation [15:8], return kind [3:0] |
| `0x18` | Globals |
| `0x1C` | `loc` (closure or module namespace) |
| `0x20` | Function |
| `0x24` | `aux`, `aux2`, `aux3` (three words) |
| `0x30` | Qstr window base |
| `0x34` | Const window base |
| `0x38` | Generator, or null |
| `0x3C` | Spill pointer. Chunks grow down from here |
| `0x40` | Spilled-value count [29:14], $n_{\mathrm{loc}}$ [13:6], $sb$ [5:0] |

Return copies the snapshot back. Chunks are not copied. The link inside the snapshot still names them.

Frame reserve: `0x2000_0000` for 32 KB, ending at `0x2000_8000`. Scratch occupies the top 512 bytes, so the spill pointer resets to `0x2000_7E00`.

## Memory windows

| Window | Base | Size |
| --- | --- | --- |
| Flash | `0x0000_0000` | 512 KB. Stores fault. Bytes 0 and 4 read as zero |
| SRAM | `0x2000_0000` | 256 KB |
| MMIO | `0x4000_0000` | 4 KB. UART, GPIO, timer, IRQ |
| Sim control | `0xE000_0000` | 256 B. Simulation only |

SRAM after the frame reserve: schedule ring `0x2000_8000` (64 B), handler table `0x2000_8040` (64 B), system roots `0x2000_8080`, argument buffer `0x2000_8100`, GC pool `0x2000_8500` through `0x2004_0000` (228096 B).

SRAM and flash data words are 32 bits. The tag is a side nibble, eight nibbles per word, lane 0 in [3:0]. One SRAM cycle. Flash adds one wait state. No DRAM, no L1, no L2.

## Collections

List, three words (`firmware/base.py` `_newlist`, core `S_BL_A` / `S_LA`):

| +0 | length |
| +4 | capacity. New lists use at least 4. Growth doubles |
| +8 | `CONT` pointer to item 0 |

Items are tagged words. `BUILD_LIST` may place them at header+12. Growth allocates a new array and updates word 2. The header object does not move.

Bytearray, three words (`firmware/strs.py` `_barr_from`):

| +0 | length in bytes |
| +4 | capacity in bytes |
| +8 | pointer to the raw buffer, or null |

The collector marks the buffer and does not scan it.

Dict and set, four words (`firmware/dicts.py`, core `S_BM_A`):

| +0 | used count in [30:0]. Bit 31 is the object indicator |
| +4 | allocated slots |
| +8 | `CONT` pointer to the entry table, or null |
| +12 | types-table pointer, or 0 |

Dict entries are a key then a value (8 bytes per slot). Set entries are one word. Empty is `CONTROL` kind 0. Tombstone is `CONTROL` kind 3. Tombstones are not copied on resize. Slot count grows through the MicroPython map-size table in `next_alloc`.

Bit 31 is the container accelerator's object indicator (`mpy_container.sv`, and the tests in `tb_mpy_container.sv`). It is set when an `OBJECT` is inserted and stays set. The core's own resize (`S_RH`) rewrites word 0 with `vint(used)` and does not implement this bit. Draw bit 31 on the dict/set header. Draw the type-table walk only in a figure whose caption says it is the container accelerator, not the core's `S_RH`.

## Accelerator resize

This is `mpy_container.sv`, not the path `mpy_soc` runs today. `mpy_soc` does not instantiate the module. The core grows lists in `S_LA` and rehashes dicts and sets in `S_RH`.

Accelerator contract, matching the design section:

- Bit 31 clear: the accelerator hashes every key, skips tombstones, and linear-probes `hash % alloc`.
- Bit 31 set: the core walks the types table. A custom `__hash__` is a function in that type's namespace dict (type word 2), not a dedicated header field.
- If no type defines `__hash__`, the common path runs.
- If one does, the core builds a computed-hash dict whose keys and values are `INT`. The key is the old slot number and the value is the hash. The accelerator uses that hash for those slots and hashes every other key itself. It does not call Python.

Hashes the accelerator computes itself: `None`, `True` and `False` as 1 and 0, ints, binary32 via a truncating cast, qstrs, the stored string or bytes hash, and tuples of those. An object with no custom hash is hashed by address.

List growth does not use this decision. It allocates a new item array, copies `length` items, and publishes the new pointer only after the copy.

## Objects

`ABI_OB_*` in `mpy_abi.svh`. Word 0 is the kind. Word 1 is the type pointer, or 0.

| Kind | Value | Words after the type pointer |
| --- | --- | --- |
| `INSTANCE` | 1 | `__dict__` or null. Three words total |
| `TYPE` | 2 | namespace dict, bases tuple, name, MRO tuple, reserved, flags, `__new__` or null. Nine words total (`firmware/calls.py` `_make_type`) |
| `EXCEPTION` | 3 | `args`, traceback, `__dict__`. Five words total |
| `CELL` | 4 | contents |
| `FUNCTION` | 5 | raw code (immediate), closure, defaults, keyword defaults, globals, root tuple. Eight words total (core `S_MF_A`) |
| `GENERATOR` | 6 | function, status, pending exception, `CONT` pointer to the saved frame. Six words total |
| `BOUND_METHOD` | 7 | function, `self`. Four words total (`firmware/attrs.py`) |
| `BUILTIN` | 8 | native id, fallback, name |
| `MODULE` | 9 | globals dict, name |
| `NOTIMPL` | 18 | |

## Strings

`QSTR` descriptor, two words in the image pool: word 0 is length in [31:16] and hash in [15:0]. Word 1 is the byte address in [30:0]. Bit 31 is set when the bytes are not ASCII.

`STR` and `BYTES`, three words: byte length, then hash in [15:0] with non-ASCII in bit 30, then a `CONT` pointer to the bytes. Equality compares length and hash before walking bytes. A non-ASCII string is indexed in firmware.

`SHORT_STR` is the register form above. It is not a heap object.

## Iterators

Tuple: word 0 is the length. Elements are the following words.

Range: start, stop, step, three integers.

`ITER`, four words (`firmware/iters.py` `_mk_riter`):

| +0 | the sequence, or the current range value |
| +4 | index, or range stop |
| +8 | extra, or range step |
| +12 | kind |

Kinds: 0 sequence (tuple, list, bytes, bytearray), 1 range, 2 dict, 3 set, 5 string. The core's `FOR_ITER` fast path keeps this same four-word record in the ring.

## What the overview is allowed to show

- Flash, a 12-byte fetch window, decode, control.
- The 16-by-36 ring with $sp$ and $sb$, the 8-entry local cache, the ALU (`INT`, `INT64`, binary32).
- String walks as a band inside the core.
- One memory port.
- The container accelerator as the growth engine, with the caption stating that the core waits while the accelerator owns the port.
- The collector, SRAM (frames up, chunks down, GC pool), and MMIO.

Do not draw an L1, an L2, DRAM, or a scoreboard.
