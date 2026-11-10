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
from mpy_synth import CORE_FILES, GC_SRAM_MACRO, SRAM_MACRO, SRAM_MACROS, SRAM_MODEL, TOPS  # noqa: E402

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
set data_in [remove_from_collection [all_inputs] [get_ports {{{clock} {reset}{also_ports}}}]]
set_input_delay  -max [expr {{$io_frac * $core_clk_period}}] -clock core_clk $data_in
set_input_delay  -min 0 -clock core_clk $data_in
set_output_delay -max [expr {{$io_frac * $core_clk_period}}] -clock core_clk [all_outputs]
set_output_delay -min 0 -clock core_clk [all_outputs]

# {reset} is an asynchronous reset: keep it out of the timing paths.
set_false_path -from [get_ports {reset}]
{tie_low}{feedthrough}"""


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
                         "much faster, leaving slack for routed wires (try 10-15%% of the period)")
    ap.add_argument("--par-effort", choices=["express", "standard", "extreme"],
                    help="Innovus design_flow_effort (Hammer default standard); extreme "
                         "optimizes timing harder and runs longer")
    ap.add_argument("--cts", action="store_true",
                    help="place and route with uPyCore's clock tree settings instead of the class "
                         "ones: skew target 0.15 ns (class 0.03), fanout 24 (class 10), and "
                         "clock-gate-aware optimization. Uses the upycore_hammer.py driver")
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
    extra_v: list[Path] = []
    if args.core_v:
        if args.rtl or args.top not in TOPS or not set(CORE_FILES) < set(TOPS[args.top]):
            sys.exit("--core-v needs a generated top that contains mpy_core (mpy_soc)")
        vdir.mkdir()
        core_v = vdir / args.core_v.name
        shutil.copy(args.core_v, core_v)
        extra_v.append(core_v)
        skip = tuple(CORE_FILES) + ((SRAM_MODEL,) if srams else ())
        unit = write_unit(args.top, vdir, skip=skip)
        write_unit(args.top, dest / "golden")
    elif args.rtl:
        vdir.mkdir()
        unit = vdir / args.rtl.name
        shutil.copy(args.rtl, unit)
        if args.top.startswith("mpy_") and unit.suffix == ".v":
            # A converted uPyCore file (converted/): keep the SystemVerilog
            # as the golden reference for equivalence checking.
            write_unit(args.top, dest / "golden")
    else:
        unit = write_unit(args.top, vdir, skip=(SRAM_MODEL,) if srams else ())
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
    sdc.write_text(CONSTRAINTS.format(top=args.top, period=args.period, io_frac=args.io_frac,
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
        # Genus and Innovus both read this file; Innovus reads it after the
        # SDC Genus wrote, so the plain uncertainty above wins there.
        with sdc.open("a") as f:
            f.write("\n# Synthesis margin (--syn-margin): Genus alone sees a tighter clock, so\n"
                    "# the netlist keeps slack for routed wires. Innovus gets the plain value.\n"
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
        files = BSG_SRAM_FILES + files
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
    if par_tcl:
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
        wrapper = dest / "hammer_run_upycore"
        wrapper.write_text(f"{shebang}\n"
                           "import os, runpy\n"
                           f"os.environ.setdefault('UPYCORE_CLASS_HAMMER_RUN', {str(run)!r})\n"
                           f"os.environ.setdefault('UPYCORE_PAR_TCL', {str(tcl)!r})\n"
                           f"runpy.run_path({str(HERE / 'upycore_hammer.py')!r}, run_name='__main__')\n")
        wrapper.chmod(0o755)
        mk = dest / "Makefile"
        mk.write_text(f"# uPyCore driver: the class one plus cfg/par_settings.tcl.\n"
                      f"HAMMER_EXEC := {wrapper}\n" + mk.read_text())

    print(f"Created {dest}")
    print(f"  top        {args.top}")
    print(f"  RTL        {unit.relative_to(dest)} ({sum(1 for _ in unit.open())} lines)")
    print(f"  clock      {args.clock} @ {args.period} ns (cfg/constraints.tcl)")
    for f in files:
        print(f"  input file {f}")
    if srams:
        for m in macros:
            n = SRAM_MACROS if m is SRAM_MACRO else 1
            print(f"  SRAM       {n} x {m['name']} (vlsi.inputs.sram_parameters)")
        print("             run `make sram`, then place them (README.md, SRAM macros)")
    for line in par_tcl:
        print(f"  Innovus    {line} (cfg/par_settings.tcl)")
    for w in warnings:
        print(f"  WARNING: {w}")
    print("Next: cd into it and run: make syn")
    return 0


if __name__ == "__main__":
    sys.exit(main())
