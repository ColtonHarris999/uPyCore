// Generic replacements for the two iCE40 primitives the vendored no2usb SIE
// instantiates (vendor/no2usb/rtl, TARGET "ICE40"), so it simulates and
// synthesizes for an ASIC. Ported by hand from the epic branch's
// coproc/rtl/ice40_sim.sv. Spec: upycore/docs/mpy_io_core.md (USB).
//
// SB_RAM40_4K: 4 Kbit as 256 words of 16 bits (iocore_usb_ram256x16: one
// clock, a bit-write mask, BaseJump's bsg_mem_1r1w_sync_mask_write_bit, the
// SRAM macro boundary). WRITE_MODE and
// READ_MODE 0..3 are 256x16, 512x8, 1024x4 and 2048x2; in the narrow modes
// the data sits on the bits the primitive uses (8 bits on 14, 12, .., 0; 4
// on 13, 9, 5, 1; 2 on 11, 3) and the address bits above 7 pick which of
// the 16 physical bits, the layout no2usb's buffers rely on. MASK (mode 0)
// is 1 for a bit not written. Reads are registered. The SIE runs every
// instance on one clock (iocore_usb), so RCLK and WCLK are the same net and
// the macro has one clock port (it takes RCLK). INIT_FILE
// "usb_trans_mc.hex", the transaction microcode, is a ROM of constants
// (usb_trans_mc.svh, from no2usb's utils/microcode.py; WE is 0 there), so
// it synthesizes to logic; no other INIT_FILE is used without SIM.
//
// SB_IO with PIN_TYPE 6'b110100 (the one no2usb's PHY uses): registered
// output and output enable on OUTPUT_CLK, D_IN_0 sampled on the rising
// edge of INPUT_CLK, D_IN_1 on the falling edge, as generic flops; the
// tristate pin is iocore_usb_pad, the pad cell's place.
`include "usb_trans_mc.svh"

module iocore_usb_ram256x16 (
    input  logic        clk_i,
    input  logic        we_i,
    input  logic [7:0]  waddr_i,
    input  logic [15:0] wmask_i,    // 1: write this bit
    input  logic [15:0] wdata_i,
    input  logic        re_i,
    input  logic [7:0]  raddr_i,
    output logic [15:0] rdata_o
);
    // The macro boundary: BaseJump's one-read-one-write wrapper.
    bsg_mem_1r1w_sync_mask_write_bit #(.width_p(16), .els_p(256)) u_mem (
        .clk_i, .reset_i(1'b0), .w_v_i(we_i), .w_mask_i(wmask_i), .w_addr_i(waddr_i),
        .w_data_i(wdata_i), .r_v_i(re_i), .r_addr_i(raddr_i), .r_data_o(rdata_o)
    );
endmodule

module SB_RAM40_4K #(
    parameter integer WRITE_MODE = 0,
    parameter integer READ_MODE = 0,
    parameter INIT_FILE = "",
    parameter [255:0] INIT_0 = 256'h0, parameter [255:0] INIT_1 = 256'h0,
    parameter [255:0] INIT_2 = 256'h0, parameter [255:0] INIT_3 = 256'h0,
    parameter [255:0] INIT_4 = 256'h0, parameter [255:0] INIT_5 = 256'h0,
    parameter [255:0] INIT_6 = 256'h0, parameter [255:0] INIT_7 = 256'h0,
    parameter [255:0] INIT_8 = 256'h0, parameter [255:0] INIT_9 = 256'h0,
    parameter [255:0] INIT_A = 256'h0, parameter [255:0] INIT_B = 256'h0,
    parameter [255:0] INIT_C = 256'h0, parameter [255:0] INIT_D = 256'h0,
    parameter [255:0] INIT_E = 256'h0, parameter [255:0] INIT_F = 256'h0
) (
    output wire [15:0] RDATA,
    input  wire        RCLK,
    input  wire        RCLKE,
    input  wire        RE,
    input  wire [10:0] RADDR,
    input  wire        WCLK,
    input  wire        WCLKE,
    input  wire        WE,
    input  wire [10:0] WADDR,
    input  wire [15:0] MASK,
    input  wire [15:0] WDATA
);
    // A 1 in a mask is a bit this access does not touch.
    function automatic [15:0] lane_mask(input integer mode, input [10:0] a, input [15:0] m0);
        case (mode)
            0: lane_mask = m0;
            1: lane_mask = ~(16'b0101_0101_0101_0101 << a[8]);
            2: lane_mask = ~(16'b0001_0001_0001_0001 << a[9:8]);
            default: lane_mask = ~(16'b0000_0001_0000_0001 << a[10:8]);
        endcase
    endfunction

    wire [15:0] wmask = lane_mask(WRITE_MODE, WADDR, MASK);
    wire [15:0] rmask = lane_mask(READ_MODE, RADDR, 16'h0);

    // The data bits a narrow write uses, copied to every lane.
    wire [15:0] wd = (WRITE_MODE == 0) ? WDATA :
                     (WRITE_MODE == 1) ? {{2{WDATA[14]}}, {2{WDATA[12]}}, {2{WDATA[10]}}, {2{WDATA[8]}},
                                          {2{WDATA[6]}}, {2{WDATA[4]}}, {2{WDATA[2]}}, {2{WDATA[0]}}} :
                     (WRITE_MODE == 2) ? {{4{WDATA[13]}}, {4{WDATA[9]}}, {4{WDATA[5]}}, {4{WDATA[1]}}} :
                                         {{8{WDATA[11]}}, {8{WDATA[3]}}};

    reg  [15:0] rq;
    // The read mask applies to the word read; keep the address bits that
    // chose the lane for the clock the data comes out.
    reg  [15:0] rmask_q;
    wire [15:0] word;

    generate
        if (INIT_FILE == "usb_trans_mc.hex") begin : g_rom
            reg [15:0] rom_q;
            always @(posedge RCLK) if (RE && RCLKE) rom_q <= usb_trans_mc(RADDR[7:0]);
            assign word = rom_q;
        end else begin : g_ram
            iocore_usb_ram256x16 u_ram (
                .clk_i(RCLK), .we_i(WE && WCLKE), .waddr_i(WADDR[7:0]), .wmask_i(~wmask),
                .wdata_i(wd), .re_i(RE && RCLKE), .raddr_i(RADDR[7:0]), .rdata_o(word)
            );
        end
    endgenerate

    always @(posedge RCLK) if (RE && RCLKE) rmask_q <= rmask;
    always @(*) rq = word & ~rmask_q;

    // The lane that survived the mask, back onto the mode's data bits.
    assign RDATA = (READ_MODE == 0) ? rq :
                   (READ_MODE == 1) ? {1'b0, |rq[15:14], 1'b0, |rq[13:12], 1'b0, |rq[11:10], 1'b0, |rq[9:8],
                                       1'b0, |rq[7:6], 1'b0, |rq[5:4], 1'b0, |rq[3:2], 1'b0, |rq[1:0]} :
                   (READ_MODE == 2) ? {2'b0, |rq[15:12], 3'b0, |rq[11:8], 3'b0, |rq[7:4], 3'b0, |rq[3:0], 1'b0} :
                                      {4'b0, |rq[15:8], 7'b0, |rq[7:0], 3'b0};

    wire unused = WCLK ^ (|INIT_0) ^ (|INIT_F);
endmodule

// The tristate pin: in silicon the pad cell's driver and receiver.
module iocore_usb_pad (
    inout  wire  pad_io,
    input  logic oe_i,
    input  logic out_i,
    output logic in_o
);
    assign pad_io = oe_i ? out_i : 1'bz;
    assign in_o = pad_io;
endmodule

module SB_IO #(
    parameter [5:0] PIN_TYPE = 6'b110100,
    parameter [0:0] PULLUP = 1'b0,
    parameter [0:0] NEG_TRIGGER = 1'b0,
    parameter IO_STANDARD = "SB_LVCMOS"
) (
    inout  wire PACKAGE_PIN,
    input  wire LATCH_INPUT_VALUE,
    input  wire CLOCK_ENABLE,
    input  wire INPUT_CLK,
    input  wire OUTPUT_CLK,
    input  wire OUTPUT_ENABLE,
    input  wire D_OUT_0,
    input  wire D_OUT_1,
    output wire D_IN_0,
    output wire D_IN_1
);
    reg din0, din1, dout0, oe;
    wire pin_in;

`ifndef SYNTHESIS
    initial begin
        din0 = 1'b0; din1 = 1'b0; dout0 = 1'b0; oe = 1'b0;
        if (PIN_TYPE != 6'b110100) $fatal(1, "SB_IO: PIN_TYPE %b is not modeled", PIN_TYPE);
    end
`endif

    iocore_usb_pad u_pad (.pad_io(PACKAGE_PIN), .oe_i(oe), .out_i(dout0), .in_o(pin_in));

    always @(posedge INPUT_CLK) if (CLOCK_ENABLE) din0 <= pin_in;
    always @(negedge INPUT_CLK) if (CLOCK_ENABLE) din1 <= pin_in;
    always @(posedge OUTPUT_CLK)
        if (CLOCK_ENABLE) begin
            dout0 <= D_OUT_0;
            oe    <= OUTPUT_ENABLE;
        end

    assign D_IN_0 = din0;
    assign D_IN_1 = din1;
    wire unused = LATCH_INPUT_VALUE ^ D_OUT_1;
endmodule
