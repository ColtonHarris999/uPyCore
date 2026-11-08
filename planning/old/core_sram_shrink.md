# Shrink mpy_core data structures into SRAM

The ALU and the FPU stay as they are. This plan moves the wide core arrays into SRAM the machine already has, and shrinks the operand stack to a 16-entry register file. Four tasks own disjoint symbols so they can land on separate branches and be merged in the order below.

Out of scope: `mpy_alu`, `upycore_fpu`, `upycore_fp_*`, integer multiply/divide, power, firmware bytecode, the GC pool size, the frame-header layout, and the spill-chunk wire format.

## Locked constants

These are the numbers every task codes against. Do not pick different ones.

| Name | Value | Meaning |
| --- | --- | --- |
| `MPY_RF_DEPTH` | 16 | Operand-stack register file. Was 64 |
| `MPY_RF_ADDR_W` | 4 | Index width |
| `MPY_RF_CHUNK_MIN` | 4 | Shrink spill, and the smallest legal chunk |
| `MPY_RF_CHUNK_MAX` | 8 | Grow spill, and the largest legal chunk |
| `GROW_CHUNK` | 8 | Default of the existing parameter. `GROW=` stays clamped to min/max |
| `RF_SPILL_AT` | 12 | `S_FETCH` spills when `sp >= 12`, leaving 4 free slots (a SHORT_STR) |
| `RF_RELOAD_AT` | 4 | Reload when `has_link && sp <= 4` |
| `RF_LEAVE_SP` | 5 | After a spill, `sp >= 5`, which is one above the reload line |
| `MPY_CORE_SCRATCH_BYTES` | 512 | Microcode working images, at the top of the frame reserve |
| `MPY_CORE_SCRATCH_BASE` | `FRAME_END - 512` | `0x2000_7E00` |

Frame-header words 0..16 do not move. `rf_base` stays in header word 16 bits `[5:0]`; only `[3:0]` are used, and the upper bits stay 0. `sp` stays 7 bits in word 4. Chunk word 0 stays `{count[5:4] in the tag, prev[31:4], count[3:0]}`.

`ABI_ARGBUF_BASE` (`0x2000_8100`, 256 tagged words) stays the argument buffer. It is already inside the GC root window `SCHED_BASE .. GC_POOL_BASE`.

The 512-byte scratch reservation is inside the 32 KB frame reserve, so the GC pool base does not move. Reset sets `spill_hp` to `MPY_CORE_SCRATCH_BASE`, not `ABI_FRAME_END`, so register-stack chunks grow down and stop at the scratch images.

## Hysteresis

A 16-entry ring cannot spill 16 values. The old thresholds (spill at 61, reload at 16, chunks of 16..48) exist so a spill does not bounce straight into a reload.

- First spill (no link): `sp_new = sp - n + 1`. Choose `n <= sp - 4` so `sp_new >= 5`.
- Later spill (link in slot 0): `sp_new = sp - n`. Choose `n <= sp - 5`.
- At `sp == 12` with no link, the grow chunk of 8 fits and leaves `sp == 5`.
- Reload of a minimum chunk at `sp == 4` ends at `sp == 8` (with a previous link) or `sp == 7` (oldest chunk). Both are below `RF_SPILL_AT`, so fetch does not spill again on the next cycle.
- Reload rejects a chunk whose resulting occupancy would exceed `MPY_RF_DEPTH`. Replace the literal `32'd64` in that check.

`S_UR` uses the same reload predicate as `S_FETCH`. `S_UR_SLOW` needs two free slots, so it spills when `sp >= MPY_RF_DEPTH - 2`. `push` and the `rf_pend` path spill when `sp >= MPY_RF_DEPTH`.

## Task 1 — 16-entry stack, stream the reload

Branch: `cursor/sram-rf-16-19d1`

Owns: `MPY_RF_*` in `upycore/rtl/mpy_defs.svh`, the `` `define SX `` macro, `rf`, `rld`, `S_RF_SPILL*`, `S_RF_RELOAD*`, the spill/reload predicates, `GROW_CHUNK`, `upycore/rtl/mpy_regfile.sv` comments, `upycore/tb/tb_mpy_value.sv` depth check, and the ring/chunk paragraphs of `upycore/docs/mpy_memory_map.md` and the one sentence in `upycore/docs/mpy_image.md`.

Does not own: `ab`, `xh`/`xv`/`xf`/`xp`, subroutine scratch, the ALU.

`rf` becomes `val_t rf [0:15]`. `` SX(L) `` is `4'(rf_base[3:0] + 4'(L))`. Every `for` that walks `0..63` over `rf` walks `MPY_RF_DEPTH`. The one-cycle clear on reset and on call entry stays a loop of 16, which a 16-entry flop file can do.

Delete `rld`. A reload already reads the chunk header, skips the packed tag words, and then reads payloads whose tags come back in `mv`. Write each payload into the physical slot the old code assigned from `rld[i]`:

- physical index `4'(rf_base - spill_n + i + 1)` for payload `i`
- those slots sit behind `rf_base` and are not part of the live window, because the occupancy check passed
- when the last payload has been stored, update `rf_base` and `sp` with today's formulas, including the restored link when `spill_prev != 0`

The spill's tag-pack loop (eight tag nibbles from `rf`) stays. It is eight narrow reads, not a 64-wide copy.

`mpy_gc.sv` already rejects chunks outside `MPY_RF_CHUNK_MIN..MAX`. No algorithm change there. Do not invent a second chunk format.

Update `tb_mpy_value.sv` so the depth check expects 16. The loops that already use `MPY_RF_DEPTH` stay. Fix address literals that no longer fit in `MPY_RF_ADDR_W`.

## Task 2 — argument buffer lives in ARGBUF

Branch: `cursor/sram-argbuf-19d1`

Owns: `val_t ab [0:255]` and every `ab[` site in `upycore/rtl/mpy_core.sv`, including `hook`, `raise_err`, `S_GC_AB`, and the star-call copies.

Does not own: `rf` depth, `rld`, exception arrays, scratch images. When a loop bound is 64 only because that was the ring depth, use the runtime count (`v0 + 2*v1`, or `x1`) instead of a depth literal, so the merge with task 1 does not care which depth is current.

Storage address is `ABI_ARGBUF_BASE + {22'd0, idx, 2'b00}`. `wr` / `rd` already carry the tag. Index space stays 0..255: slot 0 is the callable, positionals still start at 32 so a prepended `self` fits.

The memory port is one access per cycle. Replace the array with:

- `ab_q`, one `val_t` latch. A read state captures `mv` into `ab_q`. Later states use `ab_q`, not a second combinational read.
- `ab_s[0:3]`, four `val_t` flops. This is the only remnant of the array. `hook` and `raise_err` stage their four words here in one cycle, then a four-step write loop stores them before `S_HOOK`.

Every state that reads or writes two `ab` slots splits into two states. The star-call loops that copy up to 64 `rf` slots into `ab[32 + k]` in one cycle become one `wr` per cycle. `S_CC_ARG` is already one slot per cycle; point it at SRAM instead of the array.

`S_GC_AB` currently copies `ab` into ARGBUF before a collection. After this task the values already are ARGBUF, which the collector scans. Delete that copy and go on to the temporary spill. Do not skip the frame spill or the `t[]` / `xc` spill.

## Task 3 — exception stack caches the top entry

Branch: `cursor/sram-exc-top-19d1`

Owns: `xh[0:15]`, `xv[0:15]`, `xf[0:15]`, `xp[0:15]`, `exc_push`, `S_SP_X`, `S_FL_X`, and the opcode / unwind sites that read those arrays (`0x48`, `0x49`, `0x4a`, `0x5d`, `0x64`, `S_RX_H`, `S_UR`, `S_UJ`, `S_CONT` with-enter).

Does not own: `rf`, `ab`, scratch images.

Replace the arrays with one top entry: `xh` (32), `xv` (16), `xf` (1), `xp` (`val_t`), plus the existing `xsp`. Entries `[0, xsp-2]` always live in the frame record at the address the spill uses today:

```
fbase + 32'h44 + ({24'd0, nloc} << 2) + 12 * i
```

Word 0 is the handler with tag 0. Word 1 is `{xf, 15'd0, xv}` with tag 0. Word 2 is `xp`, tagged. `xsp` of them, capped at `nexc` (16). Entry `xsp-1` is the register top and is not in SRAM until it is flushed. A push writes the old top to slot `xsp-1`, then installs the new top and increments `xsp`. A pop discards the top (no write-back) and, when `xsp` is still nonzero, loads the new top. Leaving a block does not need the discarded slot.

`exc_push` cannot stay a single-cycle task. Add `S_XPUSH` / `S_XPOP` / `S_XFLUSH` / `S_XLOAD` and `gosub` to them. Push arguments travel in `x0` (handler), `b0` (finally), and the low 16 bits of `x1` (stack depth). Those three scratch registers are shared with the rest of the core; the sequence must not depend on them surviving a nested call.

Flush the top (three writes) at the start of a frame spill, before `S_SP_X` walks entries, and before a generator image is copied. Then `S_SP_X` does not read a 16-deep array. For `spill_to_img`, copy the `3 * xsp` exception words from the old frame (`x4`) to the image with one `rd`/`wr` pair per word. Fill loads only the top. `fl_img` copies the exception words from the heap image into the reserve frame, then loads the top.

Opcode `0x64` scans every entry for a non-null `xp`. The top comes from the register. Older entries are word 2 of each SRAM slot, one read per entry, highest index first, so the last non-null match still wins.

`S_RX_H` walks handlers with `xh <= op_pc` by popping. That walk is one pop per cycle, not a combinational scan of the array.

A collection spills the frame through `S_SPILL`. The flush at the start of that spill is what makes `xp` a GC root. Do not drop it.

## Task 4 — microcode working sets live in the scratch reservation

Branch: `cursor/sram-scratch-19d1`

Owns: the subroutine working registers listed below, `sV` / `sA`, and `MPY_CORE_SCRATCH_*` appended to `mpy_defs.svh`. Reset's `spill_hp <= ABI_FRAME_END` becomes `spill_hp <= MPY_CORE_SCRATCH_BASE`. Do not otherwise touch that reset, and do not edit `S_RF_*`, the `ab` array, or the `xh[0:15]` arrays. Other tasks own those, and this task has to merge with them.

The nested helpers cannot share one flop file. Attribute lookup calls dict lookup, dict lookup calls key compare, key compare calls string compare, string compare calls string info. Iterator `__next__` calls attribute lookup. A single 8-wide flop file aliases across that nest.

Each subsystem below gets its own image in the 512-byte reservation. Images do not overlap, so a nested call leaves the caller's image alone. Inside a subsystem the live copy sits in `sV[0:7]` (`val_t`) and `sA[0:7]` (32-bit). On entry, load the image into those flops only if this subsystem's image is not already loaded. Before a `gosub` into a different scratch subsystem, store the caller's image and mark it not loaded. On return, load it again. Leaf states that only read a result register do not need the image.

Result registers stay flops. Call sites already pass arguments through them, and both this task and the others read them:

`si_v`, `si_len`, `si_hash`, `si_addr`, `si_na`, `hk`, `hh`, `hok`, `ty_v`, `ty_t`, `tr_v`, `tr_r`, `tr_x`, `is_t`, `is_c`, `is_r`, `se_a`, `se_b`, `se_eq`, `ke_a`, `ke_b`, `ke_eq`, `ke_cx`, `lk_found`, `lk_res`, `lk_mode`, `lk_set`, `lk_cx`, `lk_ro`, `lk_hasav`, `at_q`, `at_v`, `at_kind`, `at_ty`, `at_objd`, `it_stop`, `it_py`, `it_h`, `it_val`.

Move the bulky cursors into images. Word offsets are from `MPY_CORE_SCRATCH_BASE`. Tagged words use `wr` / `rd`. Raw words use tag 0.

| Image | Words | Contents, in order |
| --- | --- | --- |
| LK at 0 | 8 | `lk_alloc`, `lk_tab`, `lk_pos`, `lk_start`, `lk_avail`, `lk_slot`, pad, pad |
| RH at 8 | 8 | `rh_alloc`, `rh_tab`, `rh_i`, `rh_p`, `rh_used`, pad, pad, `rh_k` tagged |
| SE at 16 | 8 | `se_len`, `se_hash`, `se_pa`, `se_pb`, `se_i`, `se_w`, pad, pad |
| AT at 24 | 8 | `at_m`, `at_n`, `at_i`, `at_k`, pad, pad, `at_t` tagged, pad |
| IT at 32 | 8 | `iv[0]`, `iv[1]`, `iv[2]`, `iv[3]` tagged, `it_i`, `it_alloc`, `it_tab`, pad |
| LA at 40 | 8 | `la_len`, `la_alloc`, `la_items`, `la_new`, `la_i`, pad, pad, pad |
| KE at 48 | 4 | `ke_w0`, `ke_w1`, pad, pad |

That is 52 words, 208 bytes, inside the 512-byte window. `sV` / `sA` are the only extra flops. Delete the moved declarations once every read and write goes through the image.

`al_*`, `t[0:7]`, `xc`, `x0`..`x4`, `i0`..`i2`, `s0`, `s1`, `b0`, `b1`, `c_*`, `cv_*`, `rx_*`, `tb_*`, `wb_*`, `sw_*`, `fl_*`, `srd_*`, `drop_*`, `ur_*`, and `gi` stay. They are live across the code the other tasks are editing.

## Merge order

1. Task 1, the register file. It changes widths that the other diffs should not mention.
2. Task 3, the exception top. Its spill/fill edits are next to task 1's spill states but use different state names.
3. Task 2, the argument buffer.
4. Task 4, the scratch images. It is the only one that changes `spill_hp`'s reset value.

While merging, keep task 1's chunk constants, task 3's single top entry, task 2's ARGBUF accesses, and task 4's scratch base. `spill_hp` resets to `MPY_CORE_SCRATCH_BASE`.

## Tests

Each task runs, from `/workspace`:

```
make test-hw-smoke
make test-hw-calls
make test-hw-exceptions
make test-hw-gc
```

Task 1 also runs `make test-hw-control`. Task 2 also runs `make test-hw-containers`. Task 4 also runs `make test-hw-objects` and `make test-hw-builtins`. A failure in an area the task did not touch gets reported, not papered over. Do not update goldens.

The integrated tree runs `make test-hw` before anything is considered done.

## After the four tasks

These are follow-ups on the integrated branch, not part of the four implementation branches.

- An optimization pass looks for further flop or port reductions that keep the bytecode behavior. It does not rewrite the ALU.
- A verification pass runs the hardware suite and reports failures.
- A PPA pass compares the four tasks and the integrated core: flip-flop arrays removed, extra SRAM cycles on calls, spills, exception push/pop, and dict/attribute helpers, and the area those trade.
