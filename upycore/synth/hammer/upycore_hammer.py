#!/usr/bin/env python3
"""The class Hammer driver plus one place-and-route hook for uPyCore.

The class flow runs Hammer through ee477-hammer-cad/hammer_run, a driver
whose hooks are fixed. This file loads that driver unchanged and adds two
hooks: the Tcl in the design folder's cfg/par_settings.tcl runs in Innovus
just before place_opt_design, after the class and sky130 settings, so its
set_db lines win; cfg/syn_settings.tcl runs in Genus just before
syn_generic, with the design elaborated. (The class driver replaces the
syn_generic step with its own genus_syn_with_preserve, so that is the name
the hook targets.) make_hammer_design.py --par-tcl/--cts writes that file
and a hammer_run_upycore wrapper next to the Makefile, and points the
Makefile's HAMMER_EXEC at the wrapper. Without the Tcl file this is the
class driver.

Environment (set by the wrapper):
  UPYCORE_CLASS_HAMMER_RUN   the class hammer_run
  UPYCORE_PAR_TCL            the Tcl file to insert in Innovus
  UPYCORE_SYN_TCL            the Tcl file to insert in Genus
  UPYCORE_EXTRA_LIBS         a Hammer config (JSON) with extra libraries, passed
                             as one more -p after the Makefile's: the USB
                             RAM macro's views from usb_ram_macro.py, which
                             the class SRAM generator (one-port only) does
                             not make. Not passed to `build` and `sram-generator`;
                             required for the syn and par actions.
"""

import importlib.machinery
import importlib.util
import os
import sys
from pathlib import Path


def load_class_driver():
    path = Path(os.environ.get("UPYCORE_CLASS_HAMMER_RUN",
                               Path.home() / "ee477/ee477-hammer-cad/hammer_run")).resolve()
    if not path.is_file():
        sys.exit(f"upycore_hammer.py: no class hammer_run at {path}")
    # hammer_run imports its hook modules relative to its own folder.
    sys.path.insert(0, str(path.parent))
    loader = importlib.machinery.SourceFileLoader("ee477_hammer_run", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod.ProjectHammerDriver


def _append_tcl(tool, var: str) -> bool:
    path = os.environ.get(var, "")
    if path and os.path.isfile(path):
        tool.append(f"# uPyCore settings from {path}")
        with open(path) as f:
            for line in f.read().splitlines():
                if line.strip() and not line.lstrip().startswith("#"):
                    tool.append(line)
    return True


def par_settings(tool: "HammerTool") -> bool:  # noqa: F821
    """Hammer hook: append the design's cfg/par_settings.tcl to the Innovus script.

    Hammer checks a hook's signature: the argument must be annotated
    HammerTool (the name as a string is accepted) and the result bool."""
    return _append_tcl(tool, "UPYCORE_PAR_TCL")


def syn_settings(tool: "HammerTool") -> bool:  # noqa: F821
    """Hammer hook: append the design's cfg/syn_settings.tcl to the Genus script."""
    return _append_tcl(tool, "UPYCORE_SYN_TCL")


def add_extra_libs(argv: list) -> list:
    """argv with `-p $UPYCORE_EXTRA_LIBS` after the last -p (a later project
    config adds to the earlier ones: the file's extra_libraries are meta
    append)."""
    path = os.environ.get("UPYCORE_EXTRA_LIBS", "")
    if not path:
        return argv
    # make runs the `build` action (it writes build/hammer.d) and then
    # `sram-generator` before the macro exists: those never take the file.
    # Synthesis and place and route cannot run without it.
    action = argv[-1] if len(argv) > 1 else ""
    if action == "build" or action.startswith("sram"):
        return argv
    if not os.path.isfile(path):
        if not action.startswith(("syn", "par")):
            return argv
        sys.exit(f"upycore_hammer.py: no {path}: run usb_ram_macro.py in the design folder "
                 "after `make sram` (the USB RAM macro's library)")
    at = max((i for i, a in enumerate(argv) if a in ("-p", "--project_config")), default=None)
    at = 1 if at is None else at + 2
    return argv[:at] + ["-p", path] + argv[at:]


def main() -> None:
    sys.argv = add_extra_libs(sys.argv)
    base = load_class_driver()
    import hammer_vlsi

    class UpycoreHammerDriver(base):
        def get_extra_par_hooks(self):
            hooks = list(super().get_extra_par_hooks())
            hooks.append(hammer_vlsi.HammerTool.make_pre_insertion_hook("place_opt_design", par_settings))
            return hooks

        def get_extra_synthesis_hooks(self):
            hooks = list(super().get_extra_synthesis_hooks())
            hooks.append(hammer_vlsi.HammerTool.make_pre_insertion_hook("genus_syn_with_preserve", syn_settings))
            return hooks

    UpycoreHammerDriver().main()


if __name__ == "__main__":
    main()
