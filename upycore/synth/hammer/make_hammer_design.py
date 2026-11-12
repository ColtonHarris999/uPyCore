#!/usr/bin/env python3
"""Build a Hammer design folder for a uPyCore top from a class example.

The EE 477 flow runs every design through Hammer: a folder with a Makefile
that includes the shared ee477-hammer-cad makefile, a v/ folder of RTL, and
cfg/<name>_cfg.yml, <name>_src.yml and <name>_tb.yml. Rather than guess the
class's exact file formats, this script copies a working example (pow2 is
the best one: an ordinary clocked design; clk_gen_ds is a ring oscillator
with unusual constraints), renames it, and changes only what differs for
uPyCore:

  * v/ holds one generated file per top (mpy_dc_unit.py): every module of
    the top plus its inlined `include headers, with SYNTHESIS defined, so
    the tool compiles it as one unit.
  * synthesis.inputs.top_module is the uPyCore top.
  * synthesis.inputs.input_files lists that file, in the example's path style.
  * cfg/constraints.tcl is rewritten for uPyCore (the class flow sets the
    clock with create_clock there, not in YAML). The example's file is kept
    as constraints.tcl.orig. vlsi.inputs.clocks is updated only if the
    example already sets it.
  * The testbench and trace lists are emptied: run synthesis only.

Everything else (placement constraints, tool and tech settings) stays as
the example has it.

Usage (on the lab machine, from the uPyCore repo root)::

    python3 upycore/synth/hammer/make_hammer_design.py \\
        ~/ee477-designs-module1/pow2 ~/ee477-designs-module1/upycore_ds

    # other options: --top mpy_alu --period 15 --io-frac 0.3
    # any other design, pre-flattened: --rtl hazard3.sv --top hazard3_cpu_1port \
    #     --clock clk --reset rst_n
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "tools"))
from mpy_dc_unit import write_unit  # noqa: E402
from mpy_synth import (CORE_FILES, GC_SRAM_MACRO, IOCORE_CODE_SRAM_MACRO, IOCORE_DATA_SRAM_MACRO,  # noqa: E402
                       ISLAND_FILES, SRAM_MACRO, SRAM_MACROS, SRAM_MODEL, TOPS, USB_SRAM_BLOCKS, USB_SRAM_MACRO,
                       USB_SRAM_MODEL)

# BaseJump STL sources for the SRAM wrapper, in the class src.yml style.
# The fakeram hook swaps each 4096 x 36 bsg_mem_1rw_sync_mask_write_bit
# for the generated macro; the other files are what its synth model and
# options name.
BSG_SRAM_FILES = [
    "${bsg_root}/bsg_misc/bsg_defines.v",
    "${bsg_root}/bsg_misc/bsg_dff.v",
    "${bsg_root}/bsg_misc/bsg_dff_en_bypass.v",
    "${bsg_root}/bsg_misc/bsg_clkgate_optional.v",
    "${bsg_root}/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v",
    "${bsg_root}/bsg_mem/bsg_mem_1rw_sync_mask_write_bit_synth.v",
]
# The one-read-one-write wrapper the USB SIE's RAMs use.
BSG_SRAM_1R1W_FILES = [
    "${bsg_root}/bsg_mem/bsg_mem_1r1w_sync_mask_write_bit.v",
    "${bsg_root}/bsg_mem/bsg_mem_1r1w_sync_mask_write_bit_synth.v",
]

try:
    import yaml
except ImportError:  # Hammer's own environment always has a YAML library.
    yaml = None

CONSTRAINTS = """\
# Written by make_hammer_design.py for top {top}. The example's file is
# constraints.tcl.orig: if it uses a different form for a line below (for
# instance the I/O delays), copy that form.
set core_clk_period {period}
set io_frac {io_frac}

create_clock -period $core_clk_period -name core_clk [get_ports {clock}]
{also_clocks}set_clock_uncertainty {uncertainty} [all_clocks]

# Data I/O: the class recommends max delay = half the period, min = 0.
# uPyCore's outputs all come from flops. If the worst path in the timing
# report runs from an input straight to an output, lower io_frac (and use
# the same value for every core you compare).
set data_in [remove_from_collection [all_inputs] [get_ports {{{clock} {reset}{also_ports}{io_in_ports}}}]]
set data_out {data_out}
set_input_delay  -max [expr {{$io_frac * $core_clk_period}}] -clock core_clk $data_in
set_input_delay  -min 0 -clock core_clk $data_in
set_output_delay -max [expr {{$io_frac * $core_clk_period}}] -clock core_clk $data_out
set_output_delay -min 0 -clock core_clk $data_out

# {reset} is an asynchronous reset: keep it out of the timing paths.
set_false_path -from [get_ports {reset}]
{io_domain}{tie_low}{feedthrough}"""

# mpy_soc's second clock: the I/O island (upycore/docs/mpy_io_core.md,
# Clock domains). Its pads are timed against io_clk (the pin mux takes the
# GPIO pads straight into the SPI and I2C controllers); the pins that go
# through two-flop synchronizers first are not timed.
IO_IN_PORTS = "adc_done_i adc_code_i* gpio_i*"
IO_OUT_PORTS = ("uart0_txd_o gpio_o* gpio_oe_o* gpio_pu_o* gpio_pd_o* adc_start_o adc_chan_o* "
                "ioc_dbg_valid_o ioc_dbg_byte_o*")
IO_ASYNC_PORTS = "uart0_rxd_i console_sel_i*"
# The USB device's pads (iocore_usb, on usb_clk).
USB_PORTS = "usb_dp_io usb_dn_io usb_pu_o"
IO_DOMAIN = """
# The I/O island's clock, asynchronous to core_clk.
set io_clk_period {io_period}
create_clock -period $io_clk_period -name io_clk [get_ports {io_clock}]
set_clock_uncertainty {uncertainty} [get_clocks io_clk]

# Every path between core_clk and io_clk ends in a two-flop synchronizer or
# is a dual-clock FIFO's memory, read only after the gray-coded write
# pointer has crossed (mpy_async_fifo). Bounding them to the faster clock's
# period, instead of cutting them, keeps a gray pointer's bits within one
# period of each other at the synchronizer.
set cdc_max [expr {{min($core_clk_period, $io_clk_period)}}]
set_max_delay $cdc_max -from [get_clocks core_clk] -to [get_clocks io_clk]
set_max_delay $cdc_max -from [get_clocks io_clk] -to [get_clocks core_clk]

# The island's synchronous pads (the ADC interface, the GPIO pads, which
# the pin mux routes to the SPI and I2C controllers, the UART TX, the debug
# byte) are timed against io_clk.
set io_in  [get_ports {{{io_in}}}]
set io_out [get_ports {{{io_out}}}]
set_input_delay  -max [expr {{$io_frac * $io_clk_period}}] -clock io_clk $io_in
set_input_delay  -min 0 -clock io_clk $io_in
set_output_delay -max [expr {{$io_frac * $io_clk_period}}] -clock io_clk $io_out
set_output_delay -min 0 -clock io_clk $io_out

# The UART RX line and the console strap are asynchronous: each goes
# through two flops before any logic.
set_false_path -from [get_ports {{{io_async}}}]

# The USB SIE's 48 MHz clock, asynchronous to the others. The island's
# accesses cross to it behind a request toggle and come back behind an
# answer toggle (iocore_usb), each through two flops: bounded like the
# io_clk crossings. Nothing connects usb_clk and core_clk.
set usb_clk_period {usb_period}
create_clock -period $usb_clk_period -name usb_clk [get_ports {usb_clock}]
set_clock_uncertainty {uncertainty} [get_clocks usb_clk]
set usb_max [expr {{min($io_clk_period, $usb_clk_period)}}]
set_max_delay $usb_max -from [get_clocks io_clk] -to [get_clocks usb_clk]
set_max_delay $usb_max -from [get_clocks usb_clk] -to [get_clocks io_clk]
set_false_path -from [get_clocks core_clk] -to [get_clocks usb_clk]
set_false_path -from [get_clocks usb_clk] -to [get_clocks core_clk]

# D+ and D- come in through the PHY's two flops (the host's bit clock is
# not ours); their drive, enable and the pull-up switch leave usb_clk flops.
set_false_path -from [get_ports {{usb_dp_io usb_dn_io}}]
set_output_delay -max [expr {{$io_frac * $usb_clk_period}}] -clock usb_clk [get_ports {{{usb_ports}}}]
set_output_delay -min 0 -clock usb_clk [get_ports {{{usb_ports}}}]
"""


def island_stub() -> str:
    """iocore_top with its ports and nothing inside (--no-island).

    The hart side of the bridge (mpy_iobr and its dual-clock FIFOs) stays,
    so the 10 ns domain is complete; the island's end of each FIFO sees an
    idle island. The loader FIFO is drained so boot does not wait on it."""
    text = (HERE.parents[2] / "iocore" / "rtl" / "iocore_top.sv").read_text()
    m = re.search(r"^module iocore_top\b.*?^\);", text, re.S | re.M)
    if not m:
        sys.exit("iocore_top.sv: module header not found")
    head = m.group(0)
    outs = re.findall(r"^\s*output\s+logic\s*(?:\[[^\]]*\])?\s*(\w+)", head, re.M)
    body = ["    // Stub by make_hammer_design.py --no-island: the island is left out.\n"]
    for o in outs:
        body.append(f"    assign {o} = ld_valid_i;\n" if o == "ld_pop_o" else f"    assign {o} = '0;\n")
    return head + "\n" + "".join(body) + "endmodule\n"


def _get(doc: dict, dotted: str):
    """Read a Hammer key written flat ("a.b.c": v) or nested ({a: {b: {c: v}}})."""
    if dotted in doc:
        return doc[dotted]
    node = doc
    for part in dotted.split("."):
        if not isinstance(node, dict) or part not in node:
            return None
        node = node[part]
    return node


def _set(doc: dict, dotted: str, value) -> None:
    """Write a key in the same style the file already uses for it (flat by default)."""
    if dotted in doc:
        doc[dotted] = value
        return
    parts = dotted.split(".")
    node = doc
    for i, part in enumerate(parts[:-1]):
        if isinstance(node, dict) and isinstance(node.get(part), dict):
            node = node[part]
        else:
            # Not nested here; fall back to a flat key at the deepest match.
            node[".".join(parts[i:])] = value
            return
    node[parts[-1]] = value


def _load(path: Path) -> dict:
    return yaml.safe_load(path.read_text()) or {}


def _dump(path: Path, doc: dict, note: str) -> None:
    text = yaml.safe_dump(doc, sort_keys=False, default_flow_style=False, width=100)
    path.write_text(f"# {note}\n{text}")


def _find_cfg(cfg_dir: Path, suffix: str) -> Path | None:
    hits = sorted(cfg_dir.glob(f"*{suffix}"))
    return hits[0] if hits else None


def _replace_strings(node, old: str, new: str):
    """Rename the example's top wherever a value names it (placement paths)."""
    if isinstance(node, dict):
        return {k: _replace_strings(v, old, new) for k, v in node.items()}
    if isinstance(node, list):
        return [_replace_strings(v, old, new) for v in node]
    if isinstance(node, str) and (node == old or node.startswith(old + "/")):
        return new + node[len(old):]
    return node


def _swap_basename(path_str: str, new_name: str) -> str:
    """'${x}/v/clk_gen.v' -> '${x}/v/mpy_core.sv', keeping the example's prefix."""
    head, _, _ = path_str.rpartition("/")
    return f"{head}/{new_name}" if head else new_name


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("example", type=Path, help="a working class design folder, e.g. clk_gen_ds")
    ap.add_argument("dest", type=Path, help="new design folder to create, e.g. upycore_ds")
    ap.add_argument("--top", default="mpy_core", help="uPyCore top (default mpy_core)")
    ap.add_argument("--period", default="20", help="clock period in ns (default 20 = 50 MHz)")
    ap.add_argument("--io-frac", default="0.5",
                    help="I/O max delay as a fraction of the period (class default 0.5)")
    ap.add_argument("--uncertainty", default="0.1", help="clock uncertainty in ns")
    ap.add_argument("--rtl", type=Path,
                    help="use this single RTL file instead of generating one (e.g. Hazard3)")
    ap.add_argument("--clock", default="clk_i", help="clock port (default clk_i)")
    ap.add_argument("--reset", default="rst_n_i", help="async reset port (default rst_n_i)")
    ap.add_argument("--io-clock", default=None,
                    help="the I/O island's clock port, asynchronous to the core clock "
                         "(default io_clk_i for mpy_soc, none otherwise)")
    ap.add_argument("--io-period", default="20", help="io_clk period in ns (default 20 = 50 MHz)")
    ap.add_argument("--usb-period", default="20.833", help="usb_clk period in ns (default 48 MHz)")
    ap.add_argument("--also-clock", action="append", default=[],
                    help="another clock port at the same period (Hazard3: clk_always_on)")
    ap.add_argument("--sv2v", type=Path, metavar="SV2V",
                    help="convert the RTL to Verilog-2005 with this sv2v binary "
                         "(for SystemVerilog the tool's parser rejects)")
    ap.add_argument("--tie-low", action="append", default=[], metavar="PORT",
                    help="input held at 0 in the benchmarked system, so its paths are not "
                         "timed; may be a pattern (Hazard3: 'dbg_*', the unused debug ports)")
    ap.add_argument("--no-feedthrough", action="store_true",
                    help="do not time paths from an input straight to an output (bus "
                         "feedthroughs belong to the system's timing, not the core's)")
    ap.add_argument("--core-v", type=Path, metavar="FILE",
                    help="for mpy_soc: take mpy_core and its submodules from this converted "
                         "file (converted/mpy_core.v) and generate SystemVerilog for the rest")
    ap.add_argument("--die", nargs=2, type=float, metavar=("W", "H"),
                    help="die width and height in um (the TOP placement constraint); four "
                         "SRAM macros need far more than a logic-only example")
    ap.add_argument("--syn-margin", type=float, default=0.0, metavar="NS",
                    help="extra clock uncertainty in synthesis only: Genus targets a clock this "
                         "much faster, leaving slack for routed wires (try 10-15%% of the period). "
                         "Place and route then needs the upycore_hammer.py driver to undo it")
    ap.add_argument("--par-effort", choices=["express", "standard", "extreme"],
                    help="Innovus design_flow_effort (Hammer default standard); extreme "
                         "optimizes timing harder and runs longer")
    ap.add_argument("--cts", action="store_true",
                    help="place and route with uPyCore's clock tree settings instead of the class "
                         "ones: skew target 0.15 ns (class 0.03), fanout 24 (class 10), and "
                         "clock-gate-aware optimization. Uses the upycore_hammer.py driver")
    ap.add_argument("--diodes", action="store_true",
                    help="place and route with antenna diode insertion (sky130_fd_sc_hd__diode_2). "
                         "The class flow repairs antennas by rerouting only, which leaves "
                         "hundreds of violations and adds shorts. Uses the upycore_hammer.py driver")
    ap.add_argument("--target-slack", type=float, metavar="NS",
                    help="Innovus opt_setup_target_slack (class 0.10): the optimizer works every "
                         "path to this much positive slack, which leaves margin before routing for "
                         "what routed wires and crosstalk take away (3.5 ns in the first routed "
                         "10 ns run). Uses the upycore_hammer.py driver")
    ap.add_argument("--cg-max-flops", type=int, metavar="N",
                    help="Genus lp_clock_gating_max_flops: at most N flops behind one clock gate. "
                         "A gate with thousands of flops sits near the clock root, about 1 ns "
                         "before the flops that drive its enable, and that skew was the worst "
                         "violation of every routed whole-chip run. Uses the upycore_hammer.py driver")
    ap.add_argument("--no-clock-gate", action="append", default=[], metavar="PATTERN",
                    help="registers Genus must not clock-gate, as an instance pattern such as "
                         "'u_core/m_addr_reg*' (repeatable). Their enables become ordinary "
                         "data-path muxes. A clock gate gets its clock 0.4 to 1.2 ns before its "
                         "flops and has a 0.4 ns setup, so a late enable loses 1 to 1.6 ns "
                         "against a flop; the core's m_addr, m_wdata, rf and x registers failed "
                         "this way in every routed 10 ns run. Uses the upycore_hammer.py driver")
    ap.add_argument("--no-clock-gate-in", action="append", default=[], metavar="INSTANCE",
                    help="like --no-clock-gate for every flop that is a direct child of this "
                         "instance, not of its submodules (u_core: the interpreter's own state, "
                         "8,393 flops; a pattern cannot say this, since * crosses '/')")
    ap.add_argument("--no-island", action="store_true",
                    help="for mpy_soc with --core-v: leave the I/O island (iocore_top: CVE2, the "
                         "peripherals, USB and their 11 SRAM macros) out and put an empty "
                         "iocore_top in its place: a run of the 10 ns domain alone. The island "
                         "runs on its own 20 ns clock, off the 10 ns paths (with it, see "
                         "--usb-flops)")
    ap.add_argument("--usb-flops", action="store_true",
                    help="for mpy_soc with the island: build the USB core's nine 256 x 16 "
                         "one-read-one-write RAMs from flops (BaseJump's synth model, 36,864 "
                         "bits) and ask the SRAM generator for no macro for them. The class's "
                         "fakeram generator makes one-port macros only and refuses the 1r1w "
                         "shape; BaseJump itself has the two-port wrapper and its macro swap")
    ap.add_argument("--par-tcl", action="append", default=[], metavar="LINE",
                    help="an Innovus Tcl line to run before place_opt_design, after the class "
                         "settings (repeatable). Uses the upycore_hammer.py driver")
    ap.add_argument("--class-hammer-run", type=Path, metavar="FILE",
                    default=Path.home() / "ee477/ee477-hammer-cad/hammer_run",
                    help="the class Hammer driver that upycore_hammer.py extends")
    ap.add_argument("--set", action="append", default=[], metavar="KEY=VALUE", dest="sets",
                    help="set a Hammer key in cfg.yml (value parsed as YAML), e.g. "
                         "par.generate_power_straps_options.by_tracks.power_utilization_met4=0.2")
    ap.add_argument("--force", action="store_true", help="replace dest if it exists")
    args = ap.parse_args()

    if yaml is None:
        sys.exit("PyYAML is missing; run this with the same python3 Hammer uses.")
    example, dest = args.example.resolve(), args.dest.resolve()
    if not (example / "Makefile").is_file() or not (example / "cfg").is_dir():
        sys.exit(f"{example} does not look like a class design folder (no Makefile or cfg/)")
    if dest.exists():
        if not args.force:
            sys.exit(f"{dest} exists; pass --force to replace it")
        shutil.rmtree(dest)

    old, new = example.name, dest.name
    shutil.copytree(example, dest, symlinks=True,
                    ignore=shutil.ignore_patterns("build*", "*.log", "*rundir*", "obj_dir"))

    # Rename cfg files and replace the design name in text files, so the
    # Makefile's list of yml files still matches.
    cfg_old_stem = None
    cfg_file = _find_cfg(dest / "cfg", "_cfg.yml")
    if cfg_file is not None:
        cfg_old_stem = cfg_file.name[: -len("_cfg.yml")]
    names = {old: new}
    if cfg_old_stem and cfg_old_stem != old:
        names[cfg_old_stem] = new
    for path in sorted(dest.rglob("*"), reverse=True):
        if path.is_file() and not path.is_symlink() and path.parent != dest / "v":
            try:
                text = path.read_text()
            except UnicodeDecodeError:
                continue
            for a, b in names.items():
                # Underscores may border the name (cfg/clk_gen_ds_src.yml).
                text = re.sub(rf"(?<![A-Za-z0-9]){re.escape(a)}(?![A-Za-z0-9])", b, text)
            path.write_text(text)
        stem = path.name
        for a, b in names.items():
            stem = stem.replace(a, b)
        if stem != path.name:
            path.rename(path.with_name(stem))

    # RTL: one self-contained file.
    vdir = dest / "v"
    if vdir.exists():
        shutil.rmtree(vdir)
    srams = args.top in TOPS and SRAM_MODEL in TOPS[args.top]
    # Macro shapes this top instantiates: mpy_mem's banks and mpy_gc's table.
    macros = []
    if srams and "mpy_mem.sv" in TOPS[args.top]:
        macros.append(SRAM_MACRO)
    if srams and "mpy_gc.sv" in TOPS[args.top]:
        macros.append(GC_SRAM_MACRO)
    island = args.top in TOPS and "iocore/rtl/iocore_top.sv" in TOPS[args.top]
    if args.no_island and not (island and args.core_v):
        sys.exit("--no-island needs --top mpy_soc with --core-v")
    if srams and island and not args.no_island:
        macros += [IOCORE_CODE_SRAM_MACRO, IOCORE_DATA_SRAM_MACRO]
        if not args.usb_flops:
            macros.append(USB_SRAM_MACRO)
    if args.usb_flops and not (island and not args.no_island):
        sys.exit("--usb-flops needs --top mpy_soc with the island (no --no-island)")
    io_clock = args.io_clock or ("io_clk_i" if island else None)
    extra_v: list[Path] = []
    if args.core_v:
        if args.rtl or args.top not in TOPS or not set(CORE_FILES) < set(TOPS[args.top]):
            sys.exit("--core-v needs a generated top that contains mpy_core (mpy_soc)")
        vdir.mkdir()
        core_v = vdir / args.core_v.name
        shutil.copy(args.core_v, core_v)
        extra_v.append(core_v)
        skip = tuple(CORE_FILES) + ((SRAM_MODEL, USB_SRAM_MODEL) if srams else ())
        if args.no_island:
            skip += tuple(ISLAND_FILES)
            stub = vdir / "iocore_top_stub.sv"
            stub.write_text("// Generated by make_hammer_design.py --no-island. Do not edit.\n" + island_stub())
            extra_v.append(stub)
        unit = write_unit(args.top, vdir, skip=skip)
        # The golden copy for equivalence checking; without the island it
        # needs none of the island's vendor sources either.
        write_unit(args.top, dest / "golden", skip=tuple(ISLAND_FILES) if args.no_island else ())
    elif args.rtl:
        vdir.mkdir()
        unit = vdir / args.rtl.name
        shutil.copy(args.rtl, unit)
        if args.top.startswith("mpy_") and unit.suffix == ".v":
            # A converted uPyCore file (converted/): keep the SystemVerilog
            # as the golden reference for equivalence checking.
            write_unit(args.top, dest / "golden")
    else:
        unit = write_unit(args.top, vdir, skip=(SRAM_MODEL, USB_SRAM_MODEL) if srams else ())
    if args.sv2v:
        # Keep the .sv out of v/, so only the converted file is there. It is
        # the golden reference for equivalence checking (lec_dofile.py).
        (dest / "golden").mkdir()
        sv = dest / "golden" / unit.name
        unit.rename(sv)
        unit = unit.with_suffix(".v")
        r = subprocess.run([str(args.sv2v), str(sv), "-w", str(unit)],
                           capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit(f"sv2v failed:\n{r.stderr}")

    cfg_dir = dest / "cfg"
    cfg = _find_cfg(cfg_dir, "_cfg.yml") or _find_cfg(cfg_dir, "cfg.yml")
    src = _find_cfg(cfg_dir, "src.yml")
    tb = _find_cfg(cfg_dir, "tb.yml")
    note = f"Edited by make_hammer_design.py from {old} for uPyCore top {args.top}."
    warnings: list[str] = []

    if cfg is None:
        sys.exit("no *_cfg.yml in the example's cfg/; set the keys by hand (README.md)")
    doc = _load(cfg)
    old_top = _get(doc, "synthesis.inputs.top_module")
    if isinstance(old_top, str) and old_top:
        doc = _replace_strings(doc, old_top, args.top)
    _set(doc, "synthesis.inputs.top_module", args.top)
    if srams:
        # One shape for mpy_mem's 32 macros and one for mpy_gc's table:
        # `make sram` generates them and the hook swaps every matching
        # instance (docs/mpy_boot.md).
        _set(doc, "vlsi.inputs.sram_parameters", [dict(m) for m in macros])
    if args.par_effort:
        _set(doc, "par.innovus.design_flow_effort", args.par_effort)
    if args.die:
        pcs = _get(doc, "vlsi.inputs.placement_constraints")
        tops = [c for c in pcs or [] if isinstance(c, dict) and c.get("type") == "toplevel"]
        if tops:
            tops[0]["width"], tops[0]["height"] = args.die
        else:
            warnings.append("example has no toplevel placement constraint; set the die size by hand")
    for kv in args.sets:
        k, _, v = kv.partition("=")
        _set(doc, k.strip(), yaml.safe_load(v))
    clocks = _get(doc, "vlsi.inputs.clocks")
    if isinstance(clocks, list) and clocks and isinstance(clocks[0], dict):
        # Only if the example already uses it: keep it consistent with the SDC.
        clk = dict(clocks[0])
        clk["name"] = args.clock
        unit_m = re.search(r"[a-zA-Z]+\s*$", str(clk.get("period", "")))
        clk["period"] = f"{args.period} {unit_m.group(0).strip() if unit_m else 'ns'}"
        _set(doc, "vlsi.inputs.clocks", [clk] + list(clocks[1:]))
    _dump(cfg, doc, note)

    sdc = cfg_dir / "constraints.tcl"
    if sdc.exists():
        shutil.copy(sdc, cfg_dir / "constraints.tcl.orig")
    else:
        warnings.append("example had no cfg/constraints.tcl; wrote one, check that "
                        "cfg.yml lists it the way the class examples do")
    io_domain = ""
    if io_clock:
        io_domain = IO_DOMAIN.format(io_period=args.io_period, io_clock=io_clock,
                                     uncertainty=args.uncertainty, io_in=IO_IN_PORTS,
                                     io_out=IO_OUT_PORTS, io_async=IO_ASYNC_PORTS,
                                     usb_period=args.usb_period, usb_clock="usb_clk_i",
                                     usb_ports=USB_PORTS)
    sdc.write_text(CONSTRAINTS.format(top=args.top, period=args.period, io_frac=args.io_frac,
                                      io_domain=io_domain,
                                      io_in_ports=(f" {io_clock} usb_clk_i {IO_IN_PORTS} {IO_ASYNC_PORTS} "
                                                   f"usb_dp_io usb_dn_io" if io_clock else ""),
                                      data_out=(f"[remove_from_collection [all_outputs] [get_ports {{{IO_OUT_PORTS} {USB_PORTS}}}]]"
                                                if io_clock else "[all_outputs]"),
                                      uncertainty=args.uncertainty, clock=args.clock,
                                      reset=args.reset,
                                      also_clocks="".join(
                                          f"create_clock -period $core_clk_period -name {c} "
                                          f"[get_ports {c}]\n" for c in args.also_clock),
                                      also_ports="".join(f" {c}" for c in args.also_clock),
                                      tie_low="".join(
                                          f"\n# Held at 0 in the benchmarked system.\n"
                                          f"set_case_analysis 0 [remove_from_collection [get_ports {{{p}}}] [all_outputs]]\n"
                                          for p in args.tie_low),
                                      feedthrough=(
                                          "\n# Input-to-output feedthroughs are timed in the system.\n"
                                          "set_false_path -from $data_in -to [all_outputs]\n"
                                          if args.no_feedthrough else "")))
    if args.syn_margin:
        # Only Genus reads this file. Innovus takes the SDC Genus writes,
        # margin included, so par_settings.tcl below puts the plain value
        # back before place_opt_design.
        with sdc.open("a") as f:
            f.write("\n# Synthesis margin (--syn-margin): Genus alone sees a tighter clock, so\n"
                    "# the netlist keeps slack for routed wires. Innovus gets the plain value\n"
                    "# back from cfg/par_settings.tcl.\n"
                    "if {[string match -nocase *genus* [file tail [info nameofexecutable]]]} {\n"
                    f"    set_clock_uncertainty {float(args.uncertainty) + args.syn_margin:g} [all_clocks]\n"
                    "}\n")
    if "constraints.tcl" not in cfg.read_text() and not any(
            "constraints.tcl" in f.read_text() for f in cfg_dir.glob("*.yml")):
        warnings.append("no yml file names constraints.tcl; find how the example loads it")

    src_doc = _load(src) if src else {}
    old_files = _get(src_doc, "synthesis.inputs.input_files") or []
    # The example's own RTL (not basejump_stl files) shows the path style.
    own = [str(f) for f in old_files if "v/" in str(f) and "bsg_root" not in str(f)]
    vfiles = [*extra_v, unit]
    if own:
        files = [_swap_basename(own[0], f.name) for f in vfiles]
    else:
        files = [f"v/{f.name}" for f in vfiles]
        warnings.append("example had no input_files; used v/<file>, check the path style")
    if srams:
        files = BSG_SRAM_FILES + (BSG_SRAM_1R1W_FILES if island and not args.no_island else []) + files
        # ${bsg_root} needs Hammer's subst; keep the example's other meta.
        meta = _get(src_doc, "synthesis.inputs.input_files_meta") or []
        meta = [meta] if isinstance(meta, str) else list(meta)
        for m in ("append", "subst"):
            if m not in meta:
                meta.append(m)
        _set(src_doc, "synthesis.inputs.input_files_meta", meta)
    if src is None:
        src = cfg_dir / f"{new}_src.yml"
        warnings.append(f"created {src.name}; add it to the Makefile's yml list")
    _set(src_doc, "synthesis.inputs.input_files", files)
    _dump(src, src_doc, note)

    if tb is not None:
        tb_doc = _load(tb)
        for key in ("sim.inputs.tb_input_files", "sim.inputs.trace_files"):
            if _get(tb_doc, key) is not None:
                _set(tb_doc, key, [])
        _dump(tb, tb_doc, note + " Simulation lists emptied: synthesis only.")
    for d in (doc, src_doc):
        if _get(d, "sim.inputs.trace_files"):
            _set(d, "sim.inputs.trace_files", [])
    _dump(cfg, doc, note)

    par_tcl = list(args.par_tcl)
    if args.cts:
        par_tcl = ["set_db cts_target_skew 0.15", "set_db cts_max_fanout 24",
                   "set_db opt_clock_gate_aware true"] + par_tcl
    if args.syn_margin:
        par_tcl += ["set_interactive_constraint_modes [all_constraint_modes -active]",
                    f"set_clock_uncertainty -setup {float(args.uncertainty):g} [all_clocks]",
                    f"set_clock_uncertainty -hold {float(args.uncertainty):g} [all_clocks]"]
    if args.diodes:
        par_tcl += ["set_db route_design_antenna_diode_insertion true",
                    "set_db route_design_antenna_cell_name sky130_fd_sc_hd__diode_2"]
    if args.target_slack is not None:
        par_tcl.append(f"set_db opt_setup_target_slack {args.target_slack:g}")
    syn_tcl = []
    if args.cg_max_flops:
        syn_tcl.append(f"set_db [get_db designs] .lp_clock_gating_max_flops {args.cg_max_flops}")
    for pat in args.no_clock_gate:
        syn_tcl.append(f"set_db [get_db insts {{{pat}}}] .lp_clock_gating_exclude true")
    for inst in args.no_clock_gate_in:
        syn_tcl.append(f"set_db [get_db insts -if {{.is_sequential && .parent.name == {inst}}}] "
                       ".lp_clock_gating_exclude true")
    if par_tcl or syn_tcl:
        # Our driver in place of the class one (upycore_hammer.py). The
        # wrapper keeps the class driver's interpreter line.
        run = args.class_hammer_run.expanduser()
        shebang = "#!/usr/bin/env python3"
        if run.is_file():
            first = run.read_text(errors="replace").splitlines()[:1]
            if first and first[0].startswith("#!"):
                shebang = first[0]
        else:
            warnings.append(f"no class driver at {run}; pass --class-hammer-run")
        tcl = cfg_dir / "par_settings.tcl"
        tcl.write_text("# Run before place_opt_design (make_hammer_design.py --cts/--par-tcl).\n"
                       + "\n".join(par_tcl) + "\n")
        stcl = cfg_dir / "syn_settings.tcl"
        stcl.write_text("# Run before syn_generic (make_hammer_design.py --cg-max-flops/--no-clock-gate).\n"
                        + "\n".join(syn_tcl) + "\n")
        wrapper = dest / "hammer_run_upycore"
        wrapper.write_text(f"{shebang}\n"
                           "import os, runpy\n"
                           f"os.environ.setdefault('UPYCORE_CLASS_HAMMER_RUN', {str(run)!r})\n"
                           f"os.environ.setdefault('UPYCORE_PAR_TCL', {str(tcl)!r})\n"
                           f"os.environ.setdefault('UPYCORE_SYN_TCL', {str(stcl)!r})\n"
                           f"runpy.run_path({str(HERE / 'upycore_hammer.py')!r}, run_name='__main__')\n")
        wrapper.chmod(0o755)
        mk = dest / "Makefile"
        mk.write_text(f"# uPyCore driver: the class one plus cfg/par_settings.tcl.\n"
                      f"HAMMER_EXEC := {wrapper}\n" + mk.read_text())

    print(f"Created {dest}")
    print(f"  top        {args.top}")
    print(f"  RTL        {unit.relative_to(dest)} ({sum(1 for _ in unit.open())} lines)")
    print(f"  clock      {args.clock} @ {args.period} ns (cfg/constraints.tcl)")
    if io_clock:
        print(f"  clock      {io_clock} @ {args.io_period} ns, asynchronous (io_clk)")
        print(f"  clock      usb_clk_i @ {args.usb_period} ns, asynchronous (usb_clk)")
    for f in files:
        print(f"  input file {f}")
    if srams:
        for m in macros:
            n = SRAM_MACROS if m is SRAM_MACRO else USB_SRAM_BLOCKS if m is USB_SRAM_MACRO else 1
            print(f"  SRAM       {n} x {m['name']} (vlsi.inputs.sram_parameters)")
        print("             run `make sram`, then place them (README.md, SRAM macros)")
    for line in par_tcl:
        print(f"  Innovus    {line} (cfg/par_settings.tcl)")
    for line in syn_tcl:
        print(f"  Genus      {line} (cfg/syn_settings.tcl)")
    for w in warnings:
        print(f"  WARNING: {w}")
    print("Next: cd into it and run: make syn")
    return 0


if __name__ == "__main__":
    sys.exit(main())
