#!/bin/sh
# Regenerate converted/<top>.v (Verilog-2005, for Genus) after an RTL change.
# Needs sv2v (https://github.com/zachjs/sv2v) on a recent Linux; the EE 477
# lab machines' glibc is too old for the release binary, so run it elsewhere
# and commit the result.
set -e
cd "$(dirname "$0")/../../.."
SV2V=${SV2V:-sv2v}
tmp=$(mktemp -d)
for top in mpy_alu mpy_decode mpy_core; do
    python3 -c "import sys; sys.path.insert(0, 'upycore/tools')
from pathlib import Path; from mpy_dc_unit import write_unit
write_unit('$top', Path('$tmp'))"
    out=upycore/synth/hammer/converted/$top.v
    {
        echo "// Generated from the uPyCore RTL by mpy_dc_unit.py and $($SV2V --version)"
        echo "// (see ../README.md). Do not edit; regenerate with convert_rtl.sh."
        "$SV2V" "$tmp/$top.sv"
    } > "$out"
    echo "wrote $out"
done
rm -rf "$tmp"
