// Stand-in for BaseJump STL's bsg_mem_1rw_sync_mask_write_bit, for this
// repo's simulator and Yosys flows. Same name, parameters and ports,
// so mpy_mem instantiates the BaseJump module unchanged.
//
// The EE 477 Hammer flow must not read this file. It lists BaseJump's own
// bsg_mem_1rw_sync_mask_write_bit.v instead, and its fakeram hook swaps any
// instance whose els_p and width_p match a vlsi.inputs.sram_parameters entry
// for a fakeram_d<els>_w<width> macro (upycore/docs/mpy_boot.md).
//
// One port: v_i & w_i writes the bits w_mask_i selects, v_i & ~w_i reads.
// data_o is the word read on the previous clock edge. Like BaseJump's model
// (latch_last_read_p = 0), it is only defined in the cycle after a read.
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

    logic [width_p-1:0] mem [0:els_p-1];

`ifndef SYNTHESIS
    // A real SRAM powers up with arbitrary contents. mpy_mem clears the data
    // SRAM and mpy_boot fills the image SRAM, so nothing should read a word
    // before it was written; zero keeps a stray read deterministic.
    initial begin
        for (int i = 0; i < els_p; i++) mem[i] = '0;
    end
`endif

    always_ff @(posedge clk_i) begin
        if (v_i) begin
            if (w_i)
                mem[addr_i] <= (data_i & w_mask_i) | (mem[addr_i] & ~w_mask_i);
            else
                data_o <= mem[addr_i];
        end
    end

    logic unused;
    assign unused = reset_i;

endmodule
