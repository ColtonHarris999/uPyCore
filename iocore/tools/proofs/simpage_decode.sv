// SAT check (iocore/tools/proofs/run.sh): mpy_soc's simulator-page decode,
// c_addr[31:8] == MPY_SIM_BASE[31:8], equals the original
// mpy_region_of(c_addr) == MPY_REGION_SIM for every 32-bit address.
`include "mpy_defs.svh"
module simpage_decode (input logic [31:0] a, output logic eq);
    assign eq = ((a[31:8] == MPY_SIM_BASE[31:8]) == (mpy_region_of(a) == MPY_REGION_SIM));
endmodule
