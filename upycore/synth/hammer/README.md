# uPyCore in the EE 477 Hammer flow

`make_hammer_design.py` turns a working class design folder (for example
`ee477-designs-module1/clk_gen_ds`) into a uPyCore design folder. It copies
the example rather than guessing the class's file formats, so the Makefile,
the tool choice (Genus or DC) and the sky130 setup stay exactly as the class
has them.

## Steps (on a lab machine)

```sh
git clone https://github.com/coltonharris999/upycore.git ~/upycore
cd ~/upycore
git checkout claude/project-thread-rwlapg      # until it is merged

# Start with the ALU: smaller, so tool problems show up fast.
python3 upycore/synth/hammer/make_hammer_design.py \
    ~/ee477-designs-module1/clk_gen_ds ~/ee477-designs-module1/upycore_alu_ds \
    --top mpy_alu --period 20

# Then the core.
python3 upycore/synth/hammer/make_hammer_design.py \
    ~/ee477-designs-module1/clk_gen_ds ~/ee477-designs-module1/upycore_ds \
    --top mpy_core --period 20
```

Put the new folder next to `clk_gen_ds`, because the Makefile includes the
shared makefile by a relative path. Then `cd` into it and run the same
synthesis target you ran for the example (only synthesis, not place and
route).

## What the script changes

| File | Change |
|---|---|
| `Makefile`, `cfg/*.yml` names | example name replaced with the new folder name |
| `v/` | replaced by one generated file, `v/<top>.sv` (all modules plus inlined headers, `SYNTHESIS` defined) |
| `<name>_cfg.yml` | `synthesis.inputs.top_module`, placement path renamed to the new top, `vlsi.inputs.clocks[0]` set to `clk_i` at `--period` ns |
| `<name>_src.yml` | `synthesis.inputs.input_files` set to the generated file, in the example's path style |
| `<name>_tb.yml` | testbench and trace lists emptied (synthesis only) |

Everything else, including placement width and height, is the example's.
The script prints a WARNING if the example didn't have a key it expected.

## Finding Fmax

Re-run the script with a smaller `--period` (pass `--force` to overwrite
the folder, or give it a new name) and synthesize again, until the timing
report shows negative slack. The last period that passes is Fmax.

## What to synthesize

- `mpy_core`: the processor, with the ALU, FPU and decoder inside it. This
  is the main number.
- `mpy_alu`: a sub-block of the core. Use it first to shake out problems.
- `mpy_gc`: part of the SoC, but its allocation table (about 28k bits)
  powers up as zero instead of being an SRAM, so a straight synthesis
  turns it into flip-flops. Report it later, with the table counted as
  memory.
- Not `mpy_container`: no other module instantiates it (only its own
  testbench does), so it isn't part of the current design.
- Not `mpy_mem` or `mpy_soc`: 768 KiB of memory arrays.

## If the tool rejects the SystemVerilog

The generated file elaborates cleanly in slang. If Genus or DC still
rejects a construct, send the error message; it can be fixed in the RTL
or worked around by converting the file with sv2v.
