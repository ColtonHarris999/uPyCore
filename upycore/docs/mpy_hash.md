# Hash engine and slot pipeline

`mpy_hash.sv` accepts the linked-image ABI's 4-bit tag and 32-bit payload
and returns a signed 31-bit hash, sign extended to 32 bits. This is the ABI
in `mpy_abi.py`, including boxed INT64 and COMPLEX values; it is not the
expanded register format described in older planning documents.
`mpy_hash_slot.sv` overlaps this engine with `upycore_umod_seq` and returns
the unsigned slot `uint32_t(hash) % alloc`. These blocks are standalone
building blocks for a future rehash accelerator. They are not connected to
the SoC or substituted for the existing core/firmware hash paths yet.

## MicroPython behavior

The reference is vendored MicroPython commit
`0fd6c573ea815774668bbb16b8e197c8822368b2`, configured by
`variants/upycore`: REPR_A, 32-bit words, long-long integers, binary32,
and 16-bit qstr hashes. CPython's hash function is not an oracle for this
configuration. In particular, there is no `-1` to `-2` substitution.

| Value | Hash | Memory reads |
| --- | --- | --- |
| INT | Sign-extend the low 31 payload bits | 0 |
| INT64 | Same reduction of the boxed integer's low word | 1 |
| FLOAT | Truncate binary32 toward zero to signed int32, then reduce to 31 bits | 0 |
| COMPLEX | XOR the two component float hashes | 2 |
| None / False / True | 6 / 0 / 1 | 0 |
| QSTR | Low 16 bits of the qstr descriptor, including the extension table | 1 |
| STR / BYTES, cached | Low 16 bits at object offset 4 | 1 |
| STR / BYTES, uncached | DJB2: start 5381, update `(h * 33) ^ byte`, keep 16 bits, replace zero with 1 | 3 header reads plus the aligned data words |
| TUPLE | Seed plus the hashes of its elements, reduced to 31 bits | Length, tagged elements, recursive reads |
| Frozen SET subtype | Seed plus hashes of occupied table entries; skip empty/tombstone entries | Flags, alloc, table pointer, all table slots, recursive reads |
| RANGE / ITER / OBJECT | Payload address shifted right by one, then reduced to 31 bits | 0 |

The pinned i686 interpreter returns INT_MIN for invalid/out-of-range float
casts; 31-bit wrapping makes the hash zero. This includes NaN, infinities,
and magnitudes outside signed int32. `hash_float` implements that result
with integer bit logic rather than another FPU.

Upstream tuple and frozenset seeds are **addresses**: respectively
`mp_const_empty_tuple` and `&mp_type_frozenset`. Absolute hashes therefore
depend on the image. `TUPLE_SEED` and `FROZEN_SEED`, exposed on both modules,
allow those reference addresses to be supplied. Defaults 12345 and 54321
match the current uPyCore firmware. The core test compares element deltas
for these two types, since an independently linked interpreter has different
addresses. Exact cross-image pointer-seeded hash equality is not promised.

OBJECT always means identity hashing here, including objects reached inside
tuples or frozensets. The unit does not inspect types or execute `__hash__`.
The future caller must resolve custom hashing separately before using this
path. Mutable containers, internal sentinels, reserved tags, and SHORT_STR
(not emitted by the current image ABI) return an error. `DEPTH` bounds
aggregate nesting (default 8); overflow also returns an error so the caller
can fall back to software. Scalars do not consume stack frames.

## Interface and memory ownership

A request is accepted on `valid_i && ready_o`; tag/payload need only be held
through that edge. Qstr configuration is image-wide and must stay stable
until the transaction retires. `valid_o`, result and error hold until
`ready_i`. An immediate scalar result is registered at acceptance; scalar
hashes can sustain one per clock. A consumed hash response can be replaced
with the next scalar response at the same edge.

There is one outstanding memory transaction. `mem_req_o` and byte address
hold until `mem_ack_i`; an acknowledgement can be immediate or delayed.
Only an acknowledged `mem_fault_i` terminates the request with an error.
Reset cancels requests and responses. The memory supplies a 32-bit payload
and 4-bit tag; tags matter for aggregate elements. Unaligned string pointers
are handled with aligned word reads and a byte buffer. Reading four bytes
per cycle never crosses a word boundary.

This is a transaction interface, not a direct connection to the SoC's
grant/ack port. Its future adapter must submit a held request once, remember
the grant, and return the eventual ack/fault without issuing duplicate
reads. Bounds/fault checking, key immutability, scoreboard hazards and GC
exclusion belong to the caller/memory adapter. The hash engine performs no
writes and does not populate missing cached string hashes.

The slot pipeline has three storage positions: hash, modulo, and output.
It can hold up to three accepted keys. Allocation metadata follows the hash
stage, while the modulo unit latches its own divisor. Completion is retained
if the output stalls, and the next division can launch on the edge retiring
the preceding division. Hash faults and `alloc == 0` travel in order through
the same pipeline and produce `error_o` with slot zero. A future rehasher
needs a matching in-order key/value metadata FIFO, not just these hashes.

## Measurements

Run `python3 upycore/tools/mpy_hash_bench.py --synth` with Verilator and
Yosys/slang available. `VERILATOR` and `YOSYS` select tools; `--work` selects
the output directory. The script writes `cycles.json`, `hash_cycles.json`,
`ppa.json` and synthesis logs. Results below used Verilator 5.032 and
yowasp-Yosys 0.66, `synth -noabc -flatten`, and `ltp -noff`.
The recorded numeric results are in
[`mpy_hash_measurements.json`](mpy_hash_measurements.json).

These are generic bit-cell counts and combinational logic levels, **not**
technology-mapped area, clock period, routed timing or power. No physical
PPA or activity-based power result is claimed.

| Block | Parameters | Bit cells | Logic levels |
| --- | --- | ---: | ---: |
| Hash | DEPTH=1, bytes/cycle=1 | 6796 | 61 |
| Hash | DEPTH=4, bytes/cycle=1 | 7674 | 61 |
| Hash | DEPTH=8, bytes/cycle=1 | 8746 | 61 |
| Hash | DEPTH=8, bytes/cycle=4 | 9075 | 71 |
| Modulo | BPC=1 | 1652 | 52 |
| Modulo | BPC=2 | 1866 | 51 |
| Modulo | BPC=4 | 2361 | 76 |
| Hash + modulo | DEPTH=8, bytes/cycle=1, BPC=4 | 11251 | 76 |
| Hash + modulo | DEPTH=8, bytes/cycle=4, BPC=4 | 11580 | 76 |

The recursion stack stores four 32-bit words and one flag per frame:
1032 bits at DEPTH=8, implemented as flops/muxes in this synthesis.
Four-byte hashing adds 329 bit cells (3.8% of the hash engine; 2.9% of the
combined pipeline). Its 71-level path remains below the BPC=4 modulo path
in this proxy. BPC=2 is the option to investigate when clock timing is
more constrained than per-key cycle count.

Average cycles per key below use two memory wait cycles per transaction,
no random stalls, and table allocations cycling through 17, 127, 1021 and
65521. The standalone hash column measures acceptance to result; pipeline
columns measure total stream time divided by key count, including fill/drain.
There are 96 cached and 96 cold string/byte cases. The mixed stream has
5178 supported cases and is dominated by float patterns (many hash to zero),
so it is a reproducible stress vector mix rather than an application profile.

| Keys | Hash alone, 1 byte/cycle | Pipelined BPC=1 | Pipelined BPC=2 | Pipelined BPC=4 | Pipelined BPC=4, 4 bytes/cycle | Serialized BPC=4, 1 byte/cycle |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| INT | 1.00 | 22.85 | 12.19 | 6.84 | 6.84 | 9.83 |
| FLOAT | 1.00 | 3.00 | 2.03 | 1.54 | 1.54 | 4.54 |
| INT64 | 6.00 | 22.92 | 12.26 | 7.03 | 7.03 | 14.83 |
| COMPLEX | 9.00 | 11.24 | 9.54 | 9.01 | 9.01 | 12.97 |
| Cached STR/BYTES | 6.00 | 8.43 | 6.18 | 6.03 | 6.03 | 10.69 |
| Cold STR/BYTES | 47.25 | 47.28 | 47.28 | 47.28 | 31.03 | 51.94 |
| Mixed | 2.78 | 6.86 | 4.67 | 3.63 | 3.32 | 7.03 |

Standalone four-byte cold hashing takes 31.00 cycles/key. Both widths read
exactly the same 896 data/header words for the cold stream: the byte buffer
reuses each fetched word. Extra byte lanes therefore reduce processing
cycles, not SRAM traffic. Cached strings and qstrs need no byte walk.

Modulo needs one accepting clock plus ceil(k/BPC) restoring clocks when
`hash >= alloc`, with `k = bits(hash) - bits(alloc) + 1` rounded up to BPC.
When `hash < alloc` it completes at acceptance. Negative hashes must be
treated as unsigned 32-bit values for slot calculation; they often require
many more steps than 16-bit string hashes. These results exclude reading
source table slots, collision probes, writes, and SRAM-bank contention.
They measure the hash/slot stages, not complete rehash speedup.

## Core verification and placement decision

The existing core's `S_HASH` covers small/boxed integers, cached strings,
qstrs, booleans, None and some identity objects. `firmware/ops.py::_hashv`
and `_fhash` handle floats, complex values, aggregates, instance identity
and custom `__hash__`. The new `builtins/hash_equivalence` program checks
both paths, including binary32 exponent/fraction boundaries, signed zeros,
NaN/Inf, signed 64-bit boundaries, Unicode/NUL strings, dynamically built
values, zero-to-one string hashes, aggregate deltas and unhashable values.
It passes on the pinned i686 interpreter and the SoC with both compilers.
No core hash mismatch was observed; no second full hash engine was added
to the core.

For the future accelerator, start with one engine next to its memory
adapter and the elastic modulo stage. Sweep bytes/cycle=1 versus 4 for
the actual key mix; the four-byte configuration has the best measured
cycle counts at a small generic area increase. Keep the existing local
core fast paths and firmware fallback until physical measurements justify
a change. Duplicating the full unit would add roughly another 8.7--9.1k
generic cells plus memory arbitration, even though most core fast hashes
are trivial. Sharing it with the core would add contention during rehash
and request/result arbitration; it saves little existing core hardware
while firmware still supplies custom hashing. A shared unit would also
route at least the tag/payload request and hash/error response between the
core and accelerator. Timing buffers and that routing capacitance can
erase nominal sharing savings. Put arbitration at the unit, register the
cross-block channels, and measure contention/routed timing/power if sharing
is later evaluated. No sharing benefit is assumed from cell counts alone.

Before SoC integration, retain original key/value metadata until slot
retirement, overlap source-table reads with compute when SRAM banks permit,
and drain all pending requests before GC. Key hashing is often cheaper
than loading keys and probing/writing destination slots; another compute
lane cannot improve throughput once those memory operations saturate the
port. These integration and routing costs are why this change leaves the
core and current copy accelerator wiring intact.

## Reproduce correctness checks

```sh
python3 upycore/tools/unit_tests.py mpy_hash mpy_hash4 mpy_hash_slot mpy_hash_slot4 upycore_umod_seq
python3 upycore/tools/hw_tests.py hash_equivalence
python3 upycore/tools/hw_tests.py hash_equivalence --compiler mpyc
python3 upycore/tools/mpy_hash_bench.py --synth
build/oracle/src/ports/unix/build-upycore/micropython build/hash_bench/micropython_check.py
build/oracle/src/ports/unix/build-upycore/micropython upycore/programs/hw/builtins/hash_equivalence.py
```

The unit tests run 5190 vectors per configuration, including 4049 binary32
patterns, random integers/complex values, cached/uncached and unaligned
byte streams, both qstr tables, aggregate nesting/overflow, faults, reset,
backpressure, and varying allocations including zero. The slot bench checks
request/output stability under stalls. The benchmark adds delayed memory
and BPC=1/2/4 runs. `mpy_hash_oracle.py` extracts the pinned float-hash C body
and emits `micropython_check.py` to independently verify numeric and byte
vectors using the complete interpreter. It does not use CPython hashes.

The broader builtins/containers/objects/strings run passes 167/167. Its copy
test releases completed large fixtures before growth checks so the test
fits the current 64 KB data SRAM; no copy checks or golden output were
removed.
