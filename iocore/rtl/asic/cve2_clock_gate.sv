// CVE2's clock gate for the ASIC flow: the library's integrated clock gate
// (sky130_fd_sc_hd__dlclkp, a latch on GATE while CLK is low and an AND,
// the cell the vendored behavioral model describes). upycore/tools/
// mpy_dc_unit.py puts this file in the generated unit in place of
// vendor/cve2/rtl/cve2_clock_gate.sv, so Genus maps no latch of its own.
// Simulation keeps the vendored model; the open timing flow reads
// iocore/rtl/sta/cve2_clock_gate.sv. Spec: upycore/docs/mpy_io_core.md (Synthesis)
module cve2_clock_gate (
    input  logic clk_i,
    input  logic en_i,
    input  logic scan_cg_en_i,
    output logic clk_o
);
    sky130_fd_sc_hd__dlclkp_1 u_icg (.CLK(clk_i), .GATE(en_i | scan_cg_en_i), .GCLK(clk_o));
endmodule
