#!/bin/sh
# SAT proofs of the pure rewrites in the I/O work. Run from the repository root.
set -e
Y=${YOSYS:-yowasp-yosys}
$Y -q -p "read_slang -j 1 -I upycore/rtl iocore/tools/proofs/simpage_decode.sv; hierarchy -top simpage_decode; proc; flatten; opt; sat -prove eq 1 -verify -show-ports simpage_decode" | tail -5
echo "simpage_decode: proved"
