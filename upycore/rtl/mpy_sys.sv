// System block at MMIO offset 0x600: clock frequency, boot straps, reset
// cause, the system reset, and the unique id. Spec:
// upycore/docs/mpy_peripherals.md (SYS block)
//
// This block is the reset controller and runs on the power-on reset
// (rst_n_i). A SYS_RESET store of the key or a wdt_reset_i pulse records
// the cause, then holds sys_rst_n_o low while scrub_o walks scrub_idx_o
// over every SRAM word, one a clock, so the memory controller can zero it.
// sys_rst_n_o is rst_n_i ANDed with that hold, so power-on releases both on
// the same clock. The straps are sampled once after power-on and survive a
// system reset, as does the cause. SYS_CONSOLE (console_o) steers the
// sim page's stdout and stderr bytes in mpy_soc. Offsets outside 0x600..0x6FF read 0 and
// ignore stores, so the SoC can OR this block's read data with the others.
module mpy_sys #(
    parameter logic [31:0] SYS_FREQ_HZ = 32'd48_000_000,
    parameter logic [63:0] SYS_UID = 64'h7570_7963_6F72_6501,
    parameter int          SRAM_WORDS = 65536
) (
    input  logic        clk_i,
    input  logic        rst_n_i,

    input  logic        req_i,
    input  logic        we_i,
    input  logic [11:0] off_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    input  logic [7:0]  strap_i,

    output logic [1:0]  console_o,

    input  logic        wdt_reset_i,
    output logic        sys_rst_n_o,
    output logic        scrub_o,
    output logic [15:0] scrub_idx_o
);
    localparam logic [11:0] SYS_FREQ        = 12'h600;
    localparam logic [11:0] SYS_STRAP       = 12'h604;
    localparam logic [11:0] SYS_RESET_CAUSE = 12'h608;
    localparam logic [11:0] SYS_RESET       = 12'h60C;
    localparam logic [11:0] SYS_UID0        = 12'h610;
    localparam logic [11:0] SYS_UID1        = 12'h614;
    localparam logic [11:0] SYS_CONSOLE     = 12'h618;
    localparam logic [31:0] RESET_KEY       = 32'h0B00_7ED0;

    localparam logic [2:0] CAUSE_PWRON = 3'd1;
    localparam logic [2:0] CAUSE_HARD  = 3'd2;
    localparam logic [2:0] CAUSE_WDT   = 3'd3;
    localparam logic [2:0] CAUSE_SOFT  = 3'd5;

    logic [7:0]  strap_r;
    logic        rst_seen_r;
    logic [2:0]  cause_r;
    logic        hold_r;
    logic [15:0] idx_r;
    logic        sw_reset;
    logic [1:0]  console_r;

    assign sw_reset = req_i && we_i && (off_i == SYS_RESET) && (wdata_i[31:1] == RESET_KEY[31:1]);
    assign sys_rst_n_o = rst_n_i && !hold_r;
    assign scrub_o = hold_r;
    assign scrub_idx_o = idx_r;
    assign console_o = console_r;

    always_comb begin
        rdata_o = 32'h0;
        if (req_i && !we_i) begin
            case (off_i)
                SYS_FREQ:        rdata_o = SYS_FREQ_HZ;
                SYS_STRAP:       rdata_o = {24'h0, strap_r};
                SYS_RESET_CAUSE: rdata_o = {29'h0, cause_r};
                SYS_UID0:        rdata_o = SYS_UID[31:0];
                SYS_UID1:        rdata_o = SYS_UID[63:32];
                SYS_CONSOLE:     rdata_o = {30'h0, console_r};
                default:         rdata_o = 32'h0;
            endcase
        end
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            strap_r    <= 8'h0;
            rst_seen_r <= 1'b0;
            cause_r    <= CAUSE_PWRON;
            hold_r     <= 1'b0;
            idx_r      <= 16'h0;
            console_r  <= 2'd0;
        end else begin
            if (req_i && we_i && off_i == SYS_CONSOLE)
                console_r <= wdata_i[1:0];
            // Latch the straps on the first clock out of power-on reset.
            if (!rst_seen_r) begin
                strap_r    <= strap_i;
                rst_seen_r <= 1'b1;
            end
            if (hold_r) begin
                idx_r <= idx_r + 16'd1;
                if (32'(idx_r) == SRAM_WORDS - 1)
                    hold_r <= 1'b0;
            end else if (wdt_reset_i || sw_reset) begin
                cause_r <= wdt_reset_i ? CAUSE_WDT : (wdata_i[0] ? CAUSE_SOFT : CAUSE_HARD);
                hold_r  <= 1'b1;
                idx_r   <= 16'h0;
            end
        end
    end
endmodule
