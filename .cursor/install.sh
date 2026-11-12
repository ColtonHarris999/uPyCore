#!/bin/bash
# Image tools come from the Dockerfile. This step fetches the pinned
# sources and builds mpy-cross, which every simulator run needs and which
# does not change when the RTL changes.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "verilator: $(verilator --version)"
echo "python: $(python3 --version)"
YOSYS_BIN="${YOSYS:-yowasp-yosys}"
echo "yosys: $("$YOSYS_BIN" -V 2>&1)"
LIB="${SKY130_LIB:-/opt/sky130/sky130_fd_sc_hd__tt_025C_1v80.lib}"
test -s "$LIB"
echo "liberty: $LIB"
"$YOSYS_BIN" -Q -T -p "help read_slang" > /tmp/read_slang_help.txt
grep -q "read_slang" /tmp/read_slang_help.txt

git submodule update --init
make mpy-cross
test -x build/oracle/src/mpy-cross/build/mpy-cross
echo "install ok"
