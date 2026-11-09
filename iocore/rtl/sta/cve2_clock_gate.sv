// Timing-flow stand-in for CVE2's clock gate (vendor/cve2/rtl/
// cve2_clock_gate.sv): an ideal gate, clk_o = clk_i. The real gate is a
// latch and an AND on the clock tree, which the backend replaces with the
// library's ICG cell; it is not a data path, and upycore/tools/sta has no
// clock-tree model, so the timing run (iocore/tools/island_measure.py)
// reads this file instead. The area run keeps the vendored gate.
module cve2_clock_gate (
    input  logic clk_i,
    input  logic en_i,
    input  logic scan_cg_en_i,
    output logic clk_o
);
    assign clk_o = clk_i;
    logic unused;
    assign unused = en_i ^ scan_cg_en_i;
endmodule
