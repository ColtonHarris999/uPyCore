// Behavioral iCE40 primitives for the vendored no2usb SIE, which targets
// iCE40 (upycore/docs/mpy_coproc.md, vendor/VENDORED.md). Only what no2usb
// instantiates is modeled, and the bit layout follows the iCE40 memory
// primitive, because no2usb's buffers shuffle their data bits to match it.
//
// SB_RAM40_4K: 4 Kbit, 256 words of 16 bits underneath. WRITE_MODE and
// READ_MODE 0..3 are 256x16, 512x8, 1024x4, and 2048x2. In the narrow modes
// the data sits on the bits the primitive uses (8 bits on 14, 12, .., 0;
// 4 on 13, 9, 5, 1; 2 on 11, 3) and the address bits above 7 pick which of
// the 16 physical bits. MASK (mode 0 only) is 1 for a bit that is not
// written. Reads are registered on RCLK. INIT_FILE names a $readmemh file
// of 16-bit words, found in the directory +NO2USB_DATA=<dir> gives.
//
// SB_IO: the registered-output, registered-enable, registered-input pin
// (PIN_TYPE 6'b110100) no2usb's PHY uses. D_IN_0 samples on the rising
// edge of INPUT_CLK, D_IN_1 on the falling edge.
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
    reg  [15:0] mem [0:255];
    reg  [15:0] rq;
    wire [15:0] wmask, rmask;
    wire [15:0] wd;

    initial begin : init
        string dir;
        for (int i = 0; i < 16; i++) begin
            logic [255:0] v;
            case (i)
                0: v = INIT_0;  1: v = INIT_1;  2: v = INIT_2;  3: v = INIT_3;
                4: v = INIT_4;  5: v = INIT_5;  6: v = INIT_6;  7: v = INIT_7;
                8: v = INIT_8;  9: v = INIT_9;  10: v = INIT_A; 11: v = INIT_B;
                12: v = INIT_C; 13: v = INIT_D; 14: v = INIT_E; default: v = INIT_F;
            endcase
            for (int j = 0; j < 16; j++) mem[16 * i + j] = v[16 * j +: 16];
        end
        if (INIT_FILE != "") begin
            if (!$value$plusargs("NO2USB_DATA=%s", dir)) dir = ".";
            $readmemh({dir, "/", INIT_FILE}, mem);
        end
        rq = 16'h0;
    end

    // A 1 in a mask is a bit this access does not touch.
    function automatic [15:0] lane_mask(input integer mode, input [10:0] a, input [15:0] m0);
        case (mode)
            0: lane_mask = m0;
            1: lane_mask = ~(16'b0101_0101_0101_0101 << a[8]);
            2: lane_mask = ~(16'b0001_0001_0001_0001 << a[9:8]);
            default: lane_mask = ~(16'b0000_0001_0000_0001 << a[10:8]);
        endcase
    endfunction

    assign wmask = lane_mask(WRITE_MODE, WADDR, MASK);
    assign rmask = lane_mask(READ_MODE, RADDR, 16'h0);

    // The data bits a narrow write uses, copied to every lane.
    assign wd = (WRITE_MODE == 0) ? WDATA :
                (WRITE_MODE == 1) ? {{2{WDATA[14]}}, {2{WDATA[12]}}, {2{WDATA[10]}}, {2{WDATA[8]}},
                                     {2{WDATA[6]}}, {2{WDATA[4]}}, {2{WDATA[2]}}, {2{WDATA[0]}}} :
                (WRITE_MODE == 2) ? {{4{WDATA[13]}}, {4{WDATA[9]}}, {4{WDATA[5]}}, {4{WDATA[1]}}} :
                                    {{8{WDATA[11]}}, {8{WDATA[3]}}};

    always @(posedge WCLK)
        if (WE && WCLKE)
            for (int i = 0; i < 16; i++)
                if (!wmask[i]) mem[WADDR[7:0]][i] <= wd[i];

    always @(posedge RCLK)
        if (RE && RCLKE) rq <= mem[RADDR[7:0]] & ~rmask;

    // The lane that survived the mask, back onto the mode's data bits.
    assign RDATA = (READ_MODE == 0) ? rq :
                   (READ_MODE == 1) ? {1'b0, |rq[15:14], 1'b0, |rq[13:12], 1'b0, |rq[11:10], 1'b0, |rq[9:8],
                                       1'b0, |rq[7:6], 1'b0, |rq[5:4], 1'b0, |rq[3:2], 1'b0, |rq[1:0]} :
                   (READ_MODE == 2) ? {2'b0, |rq[15:12], 3'b0, |rq[11:8], 3'b0, |rq[7:4], 3'b0, |rq[3:0], 1'b0} :
                                      {4'b0, |rq[15:8], 7'b0, |rq[7:0], 3'b0};
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
    reg din0 = 1'b0, din1 = 1'b0, dout0 = 1'b0, oe = 1'b0;

    initial if (PIN_TYPE != 6'b110100) $fatal(1, "SB_IO: PIN_TYPE %b is not modeled", PIN_TYPE);

    always @(posedge INPUT_CLK) if (CLOCK_ENABLE) din0 <= PACKAGE_PIN;
    always @(negedge INPUT_CLK) if (CLOCK_ENABLE) din1 <= PACKAGE_PIN;
    always @(posedge OUTPUT_CLK)
        if (CLOCK_ENABLE) begin
            dout0 <= D_OUT_0;
            oe    <= OUTPUT_ENABLE;
        end

    assign PACKAGE_PIN = oe ? dout0 : 1'bz;
    assign D_IN_0 = din0;
    assign D_IN_1 = din1;
endmodule
