# SRAM shrink cycle counts

Same programs on two simulators. **Before** is `27bd955` (main before the shrink). **After** is `c78c790` (16-entry stack, exception top cache, ARGBUF, scratch images, and the compiler qstr table). Per-item figures are `(cycles at the larger N − cycles at the smaller N) / (N1 − N0)`, so boot and definition cancel. Stdout matched the expected integer on every run. Opcode counts matched across both RTLs. No run collected during the measured gap (`gc` delta 0, halt `CLEAN`).

The fraction of a cycle per item is the larger integer taking a few more cycles to print. The table rounds to the nearest cycle.

| Loop | N | Before, cycles/item | After, cycles/item | Speedup |
| --- | --- | ---: | ---: | ---: |
| `while` adding globals | 400 → 800 | 962 | 501 | 1.92× |
| `for` over `range` | 400 → 800 | 579 | 323 | 1.79× |
| call, one argument | 200 → 400 | 1096 | 756 | 1.45× |
| call, four arguments | 200 → 400 | 1386 | 967 | 1.43× |
| call, fourteen arguments | 80 → 160 | 2100 | 1566 | 1.34× |
| `try` that does not raise | 200 → 400 | 984 | 525 | 1.87× |
| nested `try` | 150 → 300 | 1020 | 587 | 1.74× |
| `raise` / `except` of one instance | 80 → 160 | 1434 | 890 | 1.61× |
| dict, five int keys | 200 → 400 | 1849 | 1296 | 1.43× |
| dict, five str keys | 150 → 300 | 1983 | 1383 | 1.43× |
| three attribute loads | 150 → 300 | 1774 | 1240 | 1.43× |
| global load | 400 → 800 | 1063 | 524 | 2.03× |
| `for` over a generator | 40 → 80 | 1330 | 990 | 1.34× |
| `yield from`, depth 10 | 20 → 40 | 5526 | 5022 | 1.10× |
| `tuple` + `set` of a 6-wide genexp | 4 → 8 | 151038 | 144202 | 1.05× |

Median speedup is 1.43×. All fifteen loops are faster. The biggest gains are name loads and a quiet `try`. The smallest are depth-10 `yield from` and the allocating genexp.

A plain `while` that only loads and stores globals dropped from 80 cycles/op to 42. The fourteen-argument call now spills (the register file spills at 12 slots; the old file spilled at 61) and is still 1.34× the old unspilled call. The second `try` of the nested pair, which is the push that writes the old handler into the frame, costs about 62 cycles on the new core and about 36 on the old one. That extra SRAM traffic is real, and the rest of the iteration more than pays for it.

`range` at 323 and a generator `for` at 990 are not the 238 and 896 recorded in `generators_fast_path_review.md`. Those figures were taken on the fast-path branch before it merged with later main. Against the parent of this shrink, the generator `for` moved from 1330 to 990.
