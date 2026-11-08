# Testing

Every layer below runs from the repository root. `make test` runs all of
them in order; CI (`.github/workflows/all-tests.yml`) runs the host layer,
the RTL benches and one hardware job per suite area.

## Requirements

| Tool | Needed for | Notes |
| --- | --- | --- |
| Python 3.11 or newer | everything | `tomllib` |
| Verilator 5.032 or newer | RTL benches, hardware suite | Ubuntu's 5.020 rejects slices of function results in the RTL; `Dockerfile` installs 5.032 |
| A C compiler and `make` | `mpy-cross`, Verilator models | `make mpy-cross` builds the pinned `mpy-cross` |
| `gcc-i686-linux-gnu` and the i386 loader (`libc6-i386`, or `libc6:i386`) | the unix oracle (`make oracle`) | Without the loader the oracle links but cannot start, and runs fail with `FileNotFoundError` |
| Yosys with yosys-slang, sv2v | synthesis and depth reports only | not used by the tests |

`git clone --recurse-submodules` (or `git submodule update --init`) fetches
`vendor/micropython` and `vendor/upy2`.

## Layers

### 1. Host unit tests

```bash
make test-host
```

| Test | Covers |
| --- | --- |
| `upycore/tests/test_mpy_periph_model.py` | the peripheral register model |
| `upycore/tests/test_hw_manifest.py` | manifest rules: no xfail or disabled entries, every program has goldens |
| `upycore/tests/test_memory_layout.py` | image/heap split, NAND image format |
| `upycore/tests/test_numeric_const.py` | float and int constant texts the linker turns into binary32 / int64 |
| `upycore/tests/test_compiler_host.py` | the on-device copy of the uPy2 compiler |
| `upycore/tests/test_runtime_profile.py` | the cycle-attribution protocol of `runtime_profile.py` |
| `mpy_image.py --check upycore/programs/mpy/phase1` | `.mpy` reading and linking against `mpy-tool.py` disassembly |
| `upycore/tools/compiler_suite.py` | uPy2 against `mpy-cross` on every suite program: byte-exact, or a float constant spelled differently that gives the same binary32 on the device |

### 2. RTL unit benches

```bash
make test-unit                                 # every bench, about 7 minutes on 4 cores
python3 upycore/tools/unit_tests.py --list     # benches and their RTL
python3 upycore/tools/unit_tests.py mpy_alu mpy_gc
```

One bench per block, each verilated on its own: the ALU and its numeric
units (`mpy_alu`, `mpy_numeric`, `upycore_mul*`, `upycore_umod_seq`,
`upycore_fp_subnormal`), the decoder (vectors from `mpy-cross`), fetch,
shared memory and value encoding, boot over SPI NAND, the collector, the
container and collection accelerators (`mpy_ca`, `mpy_collection`,
`mpy_bytecopy`, `mpy_bulk`, `mpy_map_engine`, `mpy_key_equal`, the hash
units, `mpy_shortlist`), and the peripherals. A bench passes when it exits 0
and prints its pass line.

### 3. Hardware suite

```bash
python3 upycore/tools/mpy_build.py sim            # build the SoC model
python3 upycore/tools/hw_tests.py                 # every area, mpy-cross
python3 upycore/tools/hw_tests.py --compiler mpyc # every area, uPy2
python3 upycore/tools/hw_tests.py --area alu 'dict*'
```

Each entry of `upycore/programs/hw_tests.toml` is a MicroPython program
under `upycore/programs/hw/<area>/`. It is compiled, linked with the
firmware, booted on the Verilator model, and passes when stdout, stderr and
the exit status equal the golden files beside it (pointers in a `repr` are
masked).

- Goldens are the unix oracle's output (`make regen-goldens`, or
  `hw_tests.py --regen NAME` for one test). An entry with `oracle = false`
  has a hand-checked golden, because the unix port cannot import the frozen
  modules it uses.
- `mpyc = false` boots the program from `mpy-cross` only.
- There are no expected failures: the manifest test rejects them.
- The `compiler` area runs `compile`/`exec`/`eval` on the hart and takes
  minutes per program. The full suite takes about an hour at `-j 3`.

### 4. Goldens against the oracle

```bash
make oracle
python3 upycore/tools/hw_tests.py --check-goldens
```

Runs the oracle on every oracle-backed program and requires its output to
equal the golden, with pointers compared masked. `make test` runs this when
an oracle is built.

### 5. Benchmarks

None of these are pass/fail tests; they measure cycles on the simulator.

| Tool | Measures |
| --- | --- |
| `upycore/tools/perf_inventory.py` | MicroPython's `tests/perf_bench` programs, `run()` timed on the device, results checked against the oracle |
| `upycore/tools/timing_bench.py --before A --after B` | arithmetic loops and pystone on two simulators, same images |
| `upycore/tools/clock_bench.py --before A --after B` | AES, Fannkuch, the project benchmarks and pystone on two simulators, plus execution time at given clock periods |
| `upycore/tools/runtime_profile.py` | per-state and per-reason cycle attribution for AES and Fannkuch (a profiling build of the model) |
| `upycore/tools/bench.py`, `bulk_bench.py`, `shortlist_bench.py` | accelerator on/off comparisons |

## Adding a test

1. Write `upycore/programs/hw/<area>/<name>.py`. Print values; do not
   print pass/fail flags.
2. Add `<name> = { file = "hw/<area>/<name>.py" }` to the area in
   `hw_tests.toml`, with `cycles = …` if it needs more than 20 million.
3. `python3 upycore/tools/hw_tests.py --regen <name>` writes the goldens
   from the oracle.
4. `python3 upycore/tools/hw_tests.py <name>` and
   `python3 upycore/tools/hw_tests.py --compiler mpyc <name>` must pass.
