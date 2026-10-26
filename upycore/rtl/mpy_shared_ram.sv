// The shared SRAM between the hart and the coprocessor: WORDS 32-bit words,
// a true dual-port memory with one port on each clock. Spec:
// upycore/docs/mpy_coproc.md.
//
// Port A is the hart's (word stores only, as for all MMIO); port B is the
// coprocessor's, with byte enables. Reads are registered: the word comes
// out after the clock that takes the address. Both ports writing one word
// on overlapping clocks leave either value; software owns that protocol.
module mpy_shared_ram #(
    parameter int WORDS = 1024,
    parameter int AW = $clog2(WORDS)
) (
    input  logic          a_clk,
    input  logic          a_en,
    input  logic          a_we,
    input  logic [AW-1:0] a_addr,
    input  logic [31:0]   a_wdata,
    output logic [31:0]   a_rdata,

    input  logic          b_clk,
    input  logic          b_en,
    input  logic [3:0]    b_be,
    input  logic [AW-1:0] b_addr,
    input  logic [31:0]   b_wdata,
    output logic [31:0]   b_rdata
);
    logic [31:0] mem [0:WORDS-1];

`ifndef SYNTHESIS
    initial for (int i = 0; i < WORDS; i++) mem[i] = 32'h0;
`endif

    always_ff @(posedge a_clk) begin
        if (a_en) begin
            if (a_we) mem[a_addr] <= a_wdata;
            a_rdata <= mem[a_addr];
        end
    end

    always_ff @(posedge b_clk) begin
        if (b_en) begin
            for (int k = 0; k < 4; k++)
                if (b_be[k]) mem[b_addr][8*k +: 8] <= b_wdata[8*k +: 8];
            b_rdata <= mem[b_addr];
        end
    end
endmodule
