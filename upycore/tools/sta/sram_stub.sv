// Timing stand-in for the SRAM macros: every pin is a flop, as a macro's
// pins are setup/clock-to-q endpoints. Same name, parameters and ports.
module bsg_mem_1rw_sync_mask_write_bit #(
    parameter int width_p = 1,
    parameter int els_p = 1,
    parameter int latch_last_read_p = 0,
    parameter int enable_clock_gating_p = 0,
    parameter int addr_width_lp = (els_p > 1) ? $clog2(els_p) : 1
) (
    input  logic                     clk_i,
    input  logic                     reset_i,
    input  logic [width_p-1:0]       data_i,
    input  logic [addr_width_lp-1:0] addr_i,
    input  logic                     v_i,
    input  logic [width_p-1:0]       w_mask_i,
    input  logic                     w_i,
    output logic [width_p-1:0]       data_o
);
    (* keep *) logic [width_p-1:0] q_d, q_m;
    (* keep *) logic [addr_width_lp-1:0] q_a;
    (* keep *) logic q_v, q_w;
    (* keep *) logic [width_p-1:0] q_o;
    always_ff @(posedge clk_i) begin
        q_d <= data_i; q_m <= w_mask_i; q_a <= addr_i; q_v <= v_i; q_w <= w_i;
    end
    // The macro's read data: a flop output (its own source, not q_d).
    always_ff @(posedge clk_i) q_o <= q_o + 1'b1;
    assign data_o = q_o;
endmodule
