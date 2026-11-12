#!/usr/bin/env python3
"""Build the USB core's one-read-one-write SRAM macro views for a design folder.

    usb_ram_macro.py <design folder>

Reads <folder>/cfg/usb_ram_macro.json:
    {"name": "fakeram_d256_w16", "depth": 256, "width": 16, "count": 9}

Runs the 1r1w-patched copy of bsg_fakeram ($FAKERAM_1R1W, default
~/upycore-lab/fakeram-1r1w) with the same process settings the class SRAM
generator used for this folder (build/sram_generator-rundir/fakeram.cfg), and
writes:
    build/fakeram_1r1w/<name>/<name>.lef, .lib, .v, .bb.v
    build/fakeram_1r1w/libs.json   vlsi.technology.extra_libraries (meta append),
                                   one entry per corner, cloned from the class
                                   generator's 1rw entries for this folder with
                                   the name and the file paths replaced
Run it after `make sram`. It is re-runnable (it replaces its own outputs) and
stops with a message and exit status 1 if anything is missing or wrong.

The class flow's own generator makes one-port macros only and is not
touched: the patched copy lives outside the class tree, and its one-port
output is byte-identical to the class tool's.
"""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

PROCESS_KEYS = ["tech_nm", "voltage", "metalPrefix", "flipPins", "pinWidth_nm",
                "pinHeight_nm", "pinPitch_nm", "snapWidth_nm", "snapHeight_nm",
                "latch_last_read", "vlogTimingCheckSignalExpansion"]
PINS = ["clk", "we_in", "re_in"]          # scalar pins every 1r1w macro has
BUSES = ["w_addr_in", "r_addr_in", "wd_in", "w_mask_in", "rd_out"]


def die(msg: str) -> None:
    sys.exit(f"usb_ram_macro.py: {msg}")


def main() -> None:
    if len(sys.argv) != 2:
        die("usage: usb_ram_macro.py <design folder>")
    folder = Path(sys.argv[1]).resolve()
    spec_path = folder / "cfg" / "usb_ram_macro.json"
    sram_dir = folder / "build" / "sram_generator-rundir"
    class_cfg = sram_dir / "fakeram.cfg"
    class_out = sram_dir / "sram_generator-output.json"
    for p in (spec_path, class_cfg, class_out):
        if not p.is_file():
            die(f"missing {p} (run `make sram` first)")

    spec = json.loads(spec_path.read_text())
    for k in ("name", "depth", "width", "count"):
        if k not in spec:
            die(f"{spec_path}: missing key {k!r}")
    name, depth, width = str(spec["name"]), int(spec["depth"]), int(spec["width"])
    if depth < 2 or width < 1 or int(spec["count"]) < 1:
        die(f"{spec_path}: depth, width and count must be positive (depth >= 2)")

    tool = Path(os.environ.get("FAKERAM_1R1W", Path.home() / "upycore-lab" / "fakeram-1r1w")).resolve()
    run_py = tool / "scripts" / "run.py"
    cacti = tool / "tools" / "cacti"
    if not run_py.is_file() or not (tool / "scripts" / "utils" / "gen_1r1w.py").is_file():
        die(f"{tool} is not the 1r1w-patched bsg_fakeram (no scripts/utils/gen_1r1w.py)")
    if not (cacti / "cacti").is_file():
        die(f"no cacti binary in {cacti}")

    # Same process settings as the class generator used for this folder.
    base = json.loads(class_cfg.read_text())
    missing = [k for k in PROCESS_KEYS if k not in base]
    if missing:
        die(f"{class_cfg}: missing process keys {missing}")
    cfg = {k: base[k] for k in PROCESS_KEYS}
    cfg["srams"] = [{"name": name, "width": width, "depth": depth, "banks": 1,
                     "type": "ram", "ports": "1r1w"}]

    out = folder / "build" / "fakeram_1r1w"
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    cfg_path = out / "fakeram_1r1w.cfg"
    cfg_path.write_text(json.dumps(cfg, indent=2) + "\n")

    env = dict(os.environ, CACTI_BUILD_DIR=str(cacti))
    log = out / "fakeram_1r1w.log"
    with open(log, "w") as f:
        r = subprocess.run([sys.executable, str(run_py), str(cfg_path), "--output_dir", str(out)],
                           cwd=str(tool), env=env, stdout=f, stderr=subprocess.STDOUT)
    text = log.read_text()
    if r.returncode != 0 or "ERROR" in text or "Traceback" in text:
        die(f"the generator failed (exit {r.returncode}); see {log}")

    mdir = out / name
    views = {e: mdir / f"{name}.{e}" for e in ("lef", "lib", "v", "bb.v")}
    for e, p in views.items():
        if not p.is_file() or p.stat().st_size == 0:
            die(f"the generator wrote no {p}")
    lef, lib = views["lef"].read_text(), views["lib"].read_text()
    for pin in PINS + BUSES:
        if f"pin({pin})" not in lib and f"bus({pin})" not in lib:
            die(f"{views['lib']}: no {pin}")
    for pin in PINS:
        if f"PIN {pin}\n" not in lef:
            die(f"{views['lef']}: no PIN {pin}")
    for bus in BUSES:
        if f"PIN {bus}[0]\n" not in lef:
            die(f"{views['lef']}: no PIN {bus}[0]")
    if "ce_in" in lef or "addr_in[" in lef.replace("w_addr_in[", "").replace("r_addr_in[", ""):
        die(f"{views['lef']}: has 1rw pins; the patched generator was not used")

    # Hammer extra libraries: clone each corner's entry of one 1rw macro.
    hammer = json.loads(class_out.read_text())
    entries = hammer.get("vlsi.technology.extra_libraries") or []
    rw = [e for e in entries if "corner" in e.get("library", {}) and "nldm liberty file" in e["library"]]
    if not rw:
        die(f"{class_out}: no 1rw SRAM library entry to clone")
    first = rw[0]["library"]["name"]
    libs = []
    for e in rw:
        if e["library"]["name"] != first:
            continue
        lib_entry = json.loads(json.dumps(e["library"]))
        lib_entry["name"] = name
        lib_entry["lef file"] = str(views["lef"])
        lib_entry["nldm liberty file"] = str(views["lib"])
        lib_entry["verilog sim"] = str(views["v"])
        unknown = set(lib_entry) - {"name", "corner", "lef file", "nldm liberty file",
                                    "provides", "supplies", "verilog sim"}
        if unknown:
            die(f"{class_out}: unexpected library fields {sorted(unknown)}; update this script")
        libs.append({"library": lib_entry})
    if not libs:
        die(f"{class_out}: no corners for {first}")
    doc = {"vlsi.technology.extra_libraries": libs,
           "vlsi.technology.extra_libraries_meta": "append"}
    (out / "libs.json").write_text(json.dumps(doc, indent=2) + "\n")

    size = next((line.split() for line in lef.splitlines() if line.strip().startswith("SIZE")), None)
    npins = lef.count("USE SIGNAL")
    print(f"{name}: 1r1w {depth} x {width}, SIZE {size[1]} x {size[3]} um, {npins} signal pins, "
          f"{len(libs)} corner entries -> {out / 'libs.json'}")


if __name__ == "__main__":
    main()
