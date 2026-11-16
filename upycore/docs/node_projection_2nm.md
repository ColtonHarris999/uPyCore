# Projecting uPyCore from SkyWater 130 nm to a 2 nm-class node

No 2 nm design kit is public, so this projection has two steps. A
measured step goes from sky130 to ASAP7, the open predictive 7 nm FinFET
kit [1], using the same synthesis and timer on both libraries. A
literature step goes from 7 nm to 2 nm using the foundry's published
node-to-node figures [4–7]. Everything here is an estimate. Only the
130 nm number is post-route sign-off.

## Starting point (measured, 130 nm)

The P8 run on the lab flow (Genus + Innovus, `sky130_fd_sc_hd`,
ss_100C_1v60, routed with SI) passes at **12.12 ns, about 82.5 MHz**.

## Step 1: sky130 → ASAP7, measured with the same flow

Flow: `upycore/tools/sta/run.py mpy_core --mapped --signoff` maps
`mpy_core` (slang into Yosys 0.71, ABC `&nf` delay mapping with
buffering) onto each library. `sta_lite.py` then times the logic alone
(clock-to-Q and setup set to 0) at each library's typical corner: sky130
`tt_025C_1v80` and ASAP7 RVT TT at 0.7 V. The ASAP7 RVT TT libraries
come from OpenROAD-flow-scripts [2]. `upycore/tools/sta/lib_merge_scale.py`
merges them and converts ps/fF to ns/pF. The timer counts no wires and
no clock tree.

| Measure | sky130 (TT) | ASAP7 (TT) | Ratio |
| --- | ---: | ---: | ---: |
| FO4 inverter delay (from the liberty tables) | 80.5 ps (137.4 ps at ss_100C_1v60) | 19.6 ps | 4.1× |
| Worst logic path of `mpy_core` (same netlist source) | 8.73 ns | 1.33 ns | 6.5× |
| Core cell area, 20,593 flops included | 3.04 mm² | 0.037 mm² | 82× |
| Inverter input capacitance | 2.30 fF | 0.62 fF | 3.7× |
| Supply | 1.8 V | 0.7 V | |

The area ratio agrees with published densities. sky130 HD is about
266 k NAND2 gates/mm² [3], about 1 MTr/mm². N7 is about 91 MTr/mm² [8].
That is about 86×, against the 82× measured here.

At 130 nm the 12.12 ns cycle is about 88 FO4 (12.12 ns / 137.4 ps), a
deep pipeline stage compared with a high-performance CPU. Two estimates
at 7 nm, typical corner:

- FO4-limited (cells only, the conservative case): 88 × 19.6 ps =
  1.73 ns, **about 580 MHz**.
- Synthesis-measured (the design's own 6.5× logic-path ratio applied to
  the 12.12 ns sign-off result, rescaled to TT): **about 920 MHz**.
  ASAP7's complex AOI/OAI cells and drive strengths shorten this
  design's paths more than a lone inverter chain shows.

## Step 2: 7 nm → 2 nm, from published foundry figures

TSMC's iso-power speed gains compound to 1.49–1.56× from N7 to N2: N5
+15 % over N7 [4], N3E +18 % over N5 [5], N2 +10–15 % over N3E [6, 7].
The iso-speed power factors are 0.70 (N5), 0.66 (N3E) and 0.70–0.75
(N2). Logic density scales 1.84× claimed (about 1.5× measured [9]),
then 1.6× and 1.15×.

## Projection

| | sky130 (measured) | 7 nm (ASAP7, estimated) | 2 nm class (projected) |
| --- | ---: | ---: | ---: |
| Clock | 82.5 MHz | 0.58–0.92 GHz | **0.86–1.44 GHz** |
| Core logic + flop area | 3.04 mm² (open-flow cells) | 0.037 mm² | 0.011–0.014 mm² |
| Dynamic energy per cycle | 1× | about 1/25 (C × V²) | about 1/70–1/76 |
| Power at the projected clock | 1× (at 82.5 MHz) | | about 0.15–0.25× at 11–17× the clock |

## Caveats

- **Corner.** The 2 nm clock assumes typical-corner timing. A sign-off at
  a slow corner at 2 nm would land lower, and ASAP7 does not represent
  any one foundry [1, 10].
- **Wires.** Interconnect RC scales worse than gates. Our design is
  logic-bound (P8: 0.2–0.7 ns of wire on 11.8 ns paths), which favours
  the projection, but long nets will take a larger share at 2 nm.
- **Leakage.** At advanced nodes leakage is a much larger share of
  power. The energy figures cover switching only.
- **SRAM.** The 512 KiB SRAM and other macros scale separately. N2 HD
  bit cells are 0.0175 µm², about 38 Mb/mm² [7], so about 0.11 mm² of
  bit cells before periphery.

## Sources

1. L. T. Clark et al., "ASAP7: A 7-nm finFET predictive process design kit," Microelectronics Journal 53 (2016) 105–115. https://asu.elsevierpure.com/en/publications/asap7-a-7-nm-finfet-predictive-process-design-kit/
2. ASAP7 libraries in OpenROAD-flow-scripts, `flow/platforms/asap7/lib/NLDM`. https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts
3. SkyWater foundry-provided standard cell libraries (sky130_fd_sc_hd, 266 kGates/mm²). https://skywater-pdk.readthedocs.io/en/main/contents/libraries/foundry-provided.html
4. TSMC N5 vs N7 (15 % speed at iso-power, 30 % power at iso-speed). https://www.tomshardware.com/news/tsmc-5nm-4nm-3nm-process-node-introduces-3dfabric-technology
5. TSMC N3E vs N5 (18 % speed, 34 % power, 1.6× logic density). https://www.anandtech.com/show/17452
6. TSMC N2 vs N3E (10–15 % speed, 25–30 % power, 1.15× density). https://www.anandtech.com/show/17453
7. TSMC N2 SRAM bit cell 0.0175 µm². https://www.tomshardware.com/tech-industry/sram-scaling-isnt-dead-after-all-tsmcs-2nm-process-tech-claims-major-improvements
8. WikiChip, TSMC N7 (91.2 MTr/mm² dense cells). https://en.wikichip.org/wiki/N7
9. Angstronomics, "The truth of TSMC 5nm" (measured N5 density). https://www.angstronomics.com/p/the-truth-of-tsmc-5nm
10. ASAP7 tutorial (numbers are relative, not predictions of a real 7 nm chip). https://vlsida.github.io/chip-tutorials/asap7.html
