// Timing stand-in for the USB SIE's one-read-one-write SRAM macros (as
// upycore/tools/sta/sram_stub.sv is for the one-port ones): every pin is a
// flop, as a macro's pins are setup/clock-to-q endpoints. Same name,
// parameters and ports as iocore/rtl/usb/bsg_mem_1r1w_sync_mask_write_bit.sv;
// iocore/tools/island_measure.py reads it for timing only.
module bsg_mem_1r1w_sync_mask_write_bit #(
    parameter int width_p = 1,
    parameter int els_p = 1,
    parameter int read_write_same_addr_p = 0,
    parameter int addr_width_lp = (els_p > 1) ? $clog2(els_p) : 1
) (
    input  logic                     clk_i,
    input  logic                     reset_i,
    input  logic                     w_v_i,
    input  logic [width_p-1:0]       w_mask_i,
    input  logic [addr_width_lp-1:0] w_addr_i,
    input  logic [width_p-1:0]       w_data_i,
    input  logic                     r_v_i,
    input  logic [addr_width_lp-1:0] r_addr_i,
    output logic [width_p-1:0]       r_data_o
);
    (* keep *) logic [width_p-1:0] q_d, q_m, q_o;
    (* keep *) logic [addr_width_lp-1:0] q_wa, q_ra;
    (* keep *) logic q_wv, q_rv;
    always_ff @(posedge clk_i) begin
        q_d <= w_data_i; q_m <= w_mask_i; q_wa <= w_addr_i; q_wv <= w_v_i;
        q_ra <= r_addr_i; q_rv <= r_v_i;
    end
    // The macro's read data: a flop output (its own source).
    always_ff @(posedge clk_i) q_o <= q_o + 1'b1;
    assign r_data_o = q_o;
endmodule
