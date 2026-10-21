#!/usr/bin/env python3
"""Build a Hammer design folder for a uPyCore top from a class example.

The EE 477 flow runs every design through Hammer: a folder with a Makefile
that includes the shared ee477-hammer-cad makefile, a v/ folder of RTL, and
cfg/<name>_cfg.yml, <name>_src.yml and <name>_tb.yml. Rather than guess the
class's exact file formats, this script copies a working example (for
instance ee477-designs-module1/clk_gen_ds), renames it, and changes only
what differs for uPyCore:

  * v/ holds one generated file per top (mpy_dc_unit.py): every module of
    the top plus its inlined `include headers, with SYNTHESIS defined, so
    the tool compiles it as one unit.
  * synthesis.inputs.top_module is the uPyCore top.
  * synthesis.inputs.input_files lists that file, in the example's path style.
  * vlsi.inputs.clocks[0] gets the uPyCore clock port and the period you ask for.
  * The testbench and trace lists are emptied: run synthesis only.

Everything else (placement constraints, tool and tech settings) stays as
the example has it.

Usage (on the lab machine, from the uPyCore repo root)::

    python3 upycore/synth/hammer/make_hammer_design.py \\
        ~/ee477-designs-module1/clk_gen_ds ~/ee477-designs-module1/upycore_ds

    # other options: --top mpy_alu --period 15
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "tools"))
from mpy_dc_unit import write_unit  # noqa: E402

try:
    import yaml
except ImportError:  # Hammer's own environment always has a YAML library.
    yaml = None

CLOCK_PORT = "clk_i"


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
    unit = write_unit(args.top, vdir)

    cfg_dir = dest / "cfg"
    cfg = _find_cfg(cfg_dir, "_cfg.yml") or _find_cfg(cfg_dir, "cfg.yml")
    src = _find_cfg(cfg_dir, "_src.yml")
    tb = _find_cfg(cfg_dir, "_tb.yml")
    note = f"Edited by make_hammer_design.py from {old} for uPyCore top {args.top}."
    warnings: list[str] = []

    if cfg is None:
        sys.exit("no *_cfg.yml in the example's cfg/; set the keys by hand (README.md)")
    doc = _load(cfg)
    old_top = _get(doc, "synthesis.inputs.top_module")
    if isinstance(old_top, str) and old_top:
        doc = _replace_strings(doc, old_top, args.top)
    _set(doc, "synthesis.inputs.top_module", args.top)
    clocks = _get(doc, "vlsi.inputs.clocks")
    if isinstance(clocks, list) and clocks and isinstance(clocks[0], dict):
        clk = dict(clocks[0])
        clk["name"] = CLOCK_PORT
        unit_m = re.search(r"[a-zA-Z]+\s*$", str(clk.get("period", "")))
        clk["period"] = f"{args.period} {unit_m.group(0).strip() if unit_m else 'ns'}"
        _set(doc, "vlsi.inputs.clocks", [clk] + list(clocks[1:]))
    else:
        _set(doc, "vlsi.inputs.clocks",
             [{"name": CLOCK_PORT, "period": f"{args.period} ns", "uncertainty": "0.1 ns"}])
        warnings.append("example had no vlsi.inputs.clocks; added one, check its format")
    _dump(cfg, doc, note)

    src_doc = _load(src) if src else {}
    old_files = _get(src_doc, "synthesis.inputs.input_files") or []
    # The example's own RTL (not basejump_stl files) shows the path style.
    own = [str(f) for f in old_files if "v/" in str(f) and "bsg_root" not in str(f)]
    if own:
        files = [_swap_basename(own[0], unit.name)]
    else:
        files = [f"v/{unit.name}"]
        warnings.append("example had no input_files; used v/<file>, check the path style")
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

    print(f"Created {dest}")
    print(f"  top        {args.top}")
    print(f"  RTL        {unit.relative_to(dest)} ({sum(1 for _ in unit.open())} lines)")
    print(f"  clock      {CLOCK_PORT} @ {args.period} ns")
    print(f"  input file {files[0]}")
    for w in warnings:
        print(f"  WARNING: {w}")
    print("Next: cd into it and run the same synthesis make target you used for the example.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
