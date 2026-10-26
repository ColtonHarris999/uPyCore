// System block at MMIO offset 0x600: clock frequency and boot straps.
// Spec: upycore/docs/mpy_peripherals.md (SYS block)
//
// The straps are sampled at reset. Offsets outside 0x600..0x6FF read 0 and
// ignore stores, so the SoC can OR this block's read data with the others.
module mpy_sys #(
    parameter logic [31:0] SYS_FREQ_HZ = 32'd48_000_000
) (
    input  logic        clk_i,
    input  logic        rst_n_i,

    input  logic        req_i,
    input  logic        we_i,
    input  logic [11:0] off_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    input  logic [7:0]  strap_i
);
    localparam logic [11:0] SYS_FREQ  = 12'h600;
    localparam logic [11:0] SYS_STRAP = 12'h604;

    logic [7:0] strap_r;
    logic       rst_seen_r;

    always_comb begin
        rdata_o = 32'h0;
        if (req_i && !we_i) begin
            case (off_i)
                SYS_FREQ:  rdata_o = SYS_FREQ_HZ;
                SYS_STRAP: rdata_o = {24'h0, strap_r};
                default:   rdata_o = 32'h0;
            endcase
        end
    end

    // Latch the straps on the first clock out of reset.
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            strap_r    <= 8'h0;
            rst_seen_r <= 1'b0;
        end else if (!rst_seen_r) begin
            strap_r    <= strap_i;
            rst_seen_r <= 1'b1;
        end
    end

    logic unused;
    assign unused = ^{wdata_i};
endmodule
