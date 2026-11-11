// Stand-in for BaseJump STL's bsg_mem_1r1w_sync_mask_write_bit, for this
// repo's simulator and Yosys flows (as upycore/rtl/bsg_mem_1rw_sync_mask_
// write_bit.sv is for the one-port wrapper). The USB SIE's 256 x 16 RAMs
// (iocore/rtl/usb/ice40_cells.sv) instantiate it, so the class flow can read
// BaseJump's file and swap each instance for a one-read-one-write fakeram
// macro of that shape. The EE 477 flow must not read this file.
//
// One write port (w_v_i writes the bits w_mask_i selects) and one read port
// (r_v_i reads; r_data_o is the word read on the previous clock edge), one
// clock. A read of the address written on the same edge is not defined, as
// in BaseJump's model with read_write_same_addr_p = 0.
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
    logic [width_p-1:0] mem [0:els_p-1];
`ifndef SYNTHESIS
    initial for (int i = 0; i < els_p; i++) mem[i] = '0;
`endif
    always_ff @(posedge clk_i) begin
        if (w_v_i)
            for (int i = 0; i < width_p; i++)
                if (w_mask_i[i]) mem[w_addr_i][i] <= w_data_i[i];
        if (r_v_i) r_data_o <= mem[r_addr_i];
    end
    logic unused;
    assign unused = reset_i;
endmodule
