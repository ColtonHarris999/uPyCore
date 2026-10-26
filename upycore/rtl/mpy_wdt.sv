// Watchdog at MMIO offset 0x500. Spec: upycore/docs/mpy_peripherals.md (WDT)
//
// WDT_CTRL bit 0 starts the counter from WDT_LOAD; nothing stops it. Each
// tick decrements it, a WDT_KICK store of the key reloads it (before a
// tick on the same clock counts), and the tick that takes it to 0 pulses
// wdt_reset_o for one clock. WDT_LOAD is read-only once started. Offsets
// outside 0x500..0x5FF read 0.
module mpy_wdt (
    input  logic        clk_i,
    input  logic        rst_n_i,

    input  logic        req_i,
    input  logic        we_i,
    input  logic [11:0] off_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    input  logic        tick_i,
    output logic        wdt_reset_o
);
    localparam logic [11:0] WDT_LOAD  = 12'h500;
    localparam logic [11:0] WDT_CTRL  = 12'h504;
    localparam logic [11:0] WDT_KICK  = 12'h508;
    localparam logic [11:0] WDT_COUNT = 12'h50C;
    localparam logic [31:0] KEY = 32'h6B1D_F00D;

    logic [31:0] load_r, count_r;
    logic        started_r;
    logic        wr;

    assign wr = req_i && we_i;
    // A kick reloads first; a tick on the same clock then counts from LOAD.
    logic [31:0] cur;
    assign cur = (wr && off_i == WDT_KICK && wdata_i == KEY) ? load_r : count_r;

    always_comb begin
        rdata_o = 32'h0;
        if (req_i && !we_i) begin
            case (off_i)
                WDT_LOAD:  rdata_o = load_r;
                WDT_CTRL:  rdata_o = {31'h0, started_r};
                WDT_COUNT: rdata_o = count_r;
                default:   rdata_o = 32'h0;
            endcase
        end
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            load_r <= 32'h0; count_r <= 32'h0; started_r <= 1'b0; wdt_reset_o <= 1'b0;
        end else begin
            wdt_reset_o <= 1'b0;
            if (wr && off_i == WDT_LOAD && !started_r)
                load_r <= wdata_i;
            if (!started_r) begin
                if (wr && off_i == WDT_CTRL && wdata_i[0]) begin
                    started_r <= 1'b1;
                    count_r <= load_r;
                end
            end else if (tick_i) begin
                if (cur <= 32'd1) begin
                    count_r <= 32'h0;
                    wdt_reset_o <= 1'b1;
                end else
                    count_r <= cur - 32'd1;
            end else
                count_r <= cur;
        end
    end
endmodule
