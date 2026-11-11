#!/usr/bin/env python3
"""The class Hammer driver plus one place-and-route hook for uPyCore.

The class flow runs Hammer through ee477-hammer-cad/hammer_run, a driver
whose hooks are fixed. This file loads that driver unchanged and adds one
hook: the Tcl in the design folder's cfg/par_settings.tcl runs in Innovus
just before place_opt_design, after the class and sky130 settings, so its
set_db lines win. make_hammer_design.py --par-tcl/--cts writes that file
and a hammer_run_upycore wrapper next to the Makefile, and points the
Makefile's HAMMER_EXEC at the wrapper. Without the Tcl file this is the
class driver.

Environment (set by the wrapper):
  UPYCORE_CLASS_HAMMER_RUN   the class hammer_run
  UPYCORE_PAR_TCL            the Tcl file to insert
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


def par_settings(tool: "HammerTool") -> bool:  # noqa: F821
    """Hammer hook: append the design's cfg/par_settings.tcl to the Innovus script.

    Hammer checks a hook's signature: the argument must be annotated
    HammerTool (the name as a string is accepted) and the result bool."""
    path = os.environ.get("UPYCORE_PAR_TCL", "")
    if path and os.path.isfile(path):
        tool.append(f"# uPyCore settings from {path}")
        with open(path) as f:
            for line in f.read().splitlines():
                if line.strip() and not line.lstrip().startswith("#"):
                    tool.append(line)
    return True


def main() -> None:
    base = load_class_driver()
    import hammer_vlsi

    class UpycoreHammerDriver(base):
        def get_extra_par_hooks(self):
            hooks = list(super().get_extra_par_hooks())
            hooks.append(hammer_vlsi.HammerTool.make_pre_insertion_hook("place_opt_design", par_settings))
            return hooks

    UpycoreHammerDriver().main()


if __name__ == "__main__":
    main()
