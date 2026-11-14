# Step 0 baseline evidence

See the [progress report](../builtin_function_tags_progress.md) for the
baseline revision, the cycle and timing tables, and the gate results.

## Benchmark commands

Run from the detached `e12d6fe60528dcfecd7325df3a3dc690c678646e` worktree
with the verified toolchain sourced. `EVIDENCE` below points to this
directory in the `tags` checkout.

```bash
make mpy-cross sim
make oracle oracle-mpz
python3 upycore/tools/mpy_abi.py --check
python3 upycore/tools/hw_tests.py --check-goldens

python3 upycore/tools/shortlist_bench.py \
  --out build/step0/shortlist \
  --compare upycore/docs/benchmarks/shortlist/kernels.json
python3 upycore/tools/perf_inventory.py \
  --only bm_pidigits --points 100x100 --bigint --out build/step0/pidigits
python3 upycore/tools/bench.py
python3 upycore/tools/clock_bench.py \
  --before build/mpy_soc/obj/Vtb_mpy_soc \
  --after build/mpy_soc/obj/Vtb_mpy_soc --out build/step0/clock.json

PYTHONPATH=upycore/tools python3 - "$EVIDENCE/microbench" <<'PY'
from pathlib import Path
import sys
import bench

bench.BENCH = Path(sys.argv.pop()).resolve()
raise SystemExit(bench.main())
PY
```

The shortlist JSON preserves source, tool, image and simulator hashes,
result callbacks, and both kernel and whole-program cycle counts. Its
cycle deltas compare against the supplied historical callback reference.
Use its absolute cycle column for the tag project baseline. The shortlist
JSON's period field is runner metadata. The timing estimates come from
the separate STA reports. The clock harness uses the same baseline
simulator for both runs, allowing its output equality check to run.

## Timing commands

`YOSYS` points to YoWASP Yosys 0.70 with built-in slang.
`UPYCORE_SKY130_LIB` points to the
`sky130_fd_sc_hd__tt_025C_1v80` liberty with SHA-256
`ec0e1067a35c8bf20b11e58d1e8ac53326067e4dac84a125cc1b917a3518d0d9`.

```bash
for top in mpy_core mpy_gc mpy_collection mpy_hash mpy_key_equal; do
  python3 upycore/tools/sta/run.py "$top" --lib "$UPYCORE_SKY130_LIB" \
    --out "build/sta/step0-$top-unmapped"
  python3 upycore/tools/sta/run.py "$top" --lib "$UPYCORE_SKY130_LIB" \
    --out "build/sta/step0-$top-mapped" --mapped
done
UPYCORE_WASM_YOSYS="$YOSYS" YOSYS="$EVIDENCE/yowasp-slang-depth" \
  python3 upycore/tools/mpy_synth.py --depth 100 \
    mpy_core mpy_gc mpy_collection mpy_hash mpy_key_equal
```

The depth adapter uses the statically linked frontend and one frontend
thread. Use it for both revisions on YoWASP. For each branch report,
compare the matching mode and top with the same library and options:

```bash
python3 upycore/tools/sta/run.py --compare \
  "$EVIDENCE/sta-mpy_core-mapped.txt" build/sta/branch-mpy_core-mapped/sta.txt
```

The STA reports preserve the ranked groups used by `--compare`. Check
the first line of each report as well. It includes output endpoints,
which the current `--compare` parser omits. The
`flow-*.ys` files preserve the exact synthesis commands. Cell counts in
the progress report count instances in each tool's flattened JSON
netlist, including its treatment of flops and memory.
