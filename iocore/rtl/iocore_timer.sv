// The I/O core's time base: a cycle counter, a microsecond counter from a
// divider, a millisecond counter, and one compare on the microsecond count
// that drives the core's machine timer interrupt (mip.MTIP).
// Register rules: upycore/docs/mpy_io_core.md (Timer).
module iocore_timer #(
    parameter logic [15:0] US_DIV_RESET = 16'd49    // 50 MHz: 50 clocks a µs
) (
    input  logic        clk_i,
    input  logic        rst_n_i,

    input  logic        sel_i,
    input  logic        we_i,
    input  logic [7:0]  off_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    output logic        irq_o,       // compare matched and enabled (level)
    output logic        us_tick_o,   // one clock each microsecond
    output logic        ms_tick_o,   // one clock each millisecond
    output logic [31:0] us_o,
    output logic [31:0] ms_o
);
    localparam logic [7:0] O_CYCLES = 8'h00, O_DIV = 8'h04, O_US = 8'h08, O_MS = 8'h0C,
                           O_CMP = 8'h10, O_CTRL = 8'h14;

    logic [31:0] cycles_r, us_r, ms_r, cmp_r;
    logic [15:0] div_r, dcnt_r;
    logic [9:0]  ucnt_r;
    logic        en_r, pend_r;
    logic        us_tick, ms_tick;

    assign us_tick = (dcnt_r == div_r);
    assign ms_tick = us_tick && (ucnt_r == 10'd999);
    assign us_tick_o = us_tick;
    assign ms_tick_o = ms_tick;
    assign us_o = us_r;
    assign ms_o = ms_r;
    assign irq_o = en_r && pend_r;

    always_comb begin
        case (off_i)
            O_CYCLES: rdata_o = cycles_r;
            O_DIV:    rdata_o = {16'h0, div_r};
            O_US:     rdata_o = us_r;
            O_MS:     rdata_o = ms_r;
            O_CMP:    rdata_o = cmp_r;
            O_CTRL:   rdata_o = {30'h0, pend_r, en_r};
            default:  rdata_o = 32'h0;
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            cycles_r <= 32'h0; us_r <= 32'h0; ms_r <= 32'h0; cmp_r <= 32'h0;
            div_r <= US_DIV_RESET; dcnt_r <= 16'h0; ucnt_r <= 10'h0;
            en_r <= 1'b0; pend_r <= 1'b0;
        end else begin
            cycles_r <= cycles_r + 32'd1;
            if (sel_i && we_i && off_i == O_DIV) begin
                div_r  <= wdata_i[15:0];
                dcnt_r <= 16'h0;
            end else
                dcnt_r <= us_tick ? 16'h0 : dcnt_r + 16'd1;
            if (us_tick) begin
                us_r   <= us_r + 32'd1;
                ucnt_r <= ms_tick ? 10'd0 : ucnt_r + 10'd1;
            end
            if (ms_tick) ms_r <= ms_r + 32'd1;
            if (sel_i && we_i && off_i == O_CMP) cmp_r <= wdata_i;
            if (sel_i && we_i && off_i == O_CTRL) begin
                en_r <= wdata_i[0];
                if (wdata_i[1]) pend_r <= 1'b0;
            end
            // The match is the microsecond the count reaches the compare.
            if (us_tick && us_r + 32'd1 == cmp_r) pend_r <= 1'b1;
        end
    end
endmodule
