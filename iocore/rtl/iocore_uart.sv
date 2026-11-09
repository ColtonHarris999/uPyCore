// The I/O core's UART: 8N1, a TX and an RX FIFO, a baud divider.
// Register rules: upycore/docs/mpy_io_core.md (UART). Ported from the epic
// branch's mpy_periph UART (serializer, receiver, FIFO rules) onto the I/O
// bus; its byte-strobe mode is gone, since the island has no strobe port.
//
// Bus: a slave access is taken on a clock with sel_i high (the island's
// decoder has already checked ready_o); rdata_o is the value for that
// access, read on that clock (the decoder registers it). A DATA load pops
// the RX FIFO on that clock. A DATA store while the TX FIFO is full is not
// taken: ready_o is low and the core waits.
module iocore_uart #(
    parameter int FIFO_DEPTH = 16,
    parameter logic [15:0] BAUD_RESET = 16'd0
) (
    input  logic        clk_i,
    input  logic        rst_n_i,

    input  logic        sel_i,
    input  logic        we_i,
    input  logic [7:0]  off_i,       // byte offset in the block
    input  logic [31:0] wdata_i,
    output logic        ready_o,
    output logic [31:0] rdata_o,

    input  logic        rxd_i,
    output logic        txd_o,
    output logic        irq_o,
    // A byte arrived (one clock), for the firmware's console and KBD check.
    output logic        rx_byte_o
);
    localparam int FD  = FIFO_DEPTH;
    localparam int FPW = (FD > 1) ? $clog2(FD) : 1;
    localparam int FCW = $clog2(FD + 1);

    localparam logic [7:0] O_DATA = 8'h00, O_STATUS = 8'h04, O_BAUD = 8'h08,
                           O_IRQEN = 8'h0C, O_CLR = 8'h10;

    logic [15:0] baud_r, baud;
    logic [1:0]  irqen_r;
    logic        overrun_r, ferr_r;
    logic [7:0]  rxq [0:FD-1];
    logic [7:0]  txq [0:FD-1];
    logic [FPW-1:0] rx_rd_r, rx_wr_r, tx_rd_r, tx_wr_r;
    logic [FCW-1:0] rx_cnt_r, tx_cnt_r;
    logic        rx_full, tx_full, rx_empty, tx_empty;
    logic        txd_r, tx_busy_r;
    logic [8:0]  tx_sh_r;
    logic [3:0]  tx_bit_r;
    logic [15:0] tx_clk_r;
    logic        rxd_s1_r, rxd_s2_r, rxd_d_r;
    logic        rx_busy_r;
    logic [3:0]  rx_bit_r;
    logic [15:0] rx_clk_r;
    logic [7:0]  rx_sh_r;
    logic        ser_valid, ser_ferr;
    logic        take, drop, rx_pop, tx_push, tx_pop;

    function automatic logic [FPW-1:0] fnext(input logic [FPW-1:0] p);
        fnext = (32'(p) == FD - 1) ? '0 : p + 1'b1;
    endfunction

    // A divider below 4 cannot sample mid-bit, so it is raised to 4.
    assign baud     = (baud_r < 16'd4) ? 16'd4 : baud_r;
    assign rx_full  = (32'(rx_cnt_r) == FD);
    assign rx_empty = (rx_cnt_r == '0);
    assign tx_full  = (32'(tx_cnt_r) == FD);
    assign tx_empty = (tx_cnt_r == '0);

    assign ready_o = !(we_i && off_i == O_DATA && tx_full);
    assign tx_push = sel_i && we_i && off_i == O_DATA;
    assign rx_pop  = sel_i && !we_i && off_i == O_DATA && !rx_empty;
    assign tx_pop  = !tx_busy_r && !tx_empty;

    // Stop bit sampled this clock.
    assign ser_valid = rx_busy_r && rx_bit_r == 4'd9 && rx_clk_r == 16'h0 && rxd_s2_r;
    assign ser_ferr  = rx_busy_r && rx_bit_r == 4'd9 && rx_clk_r == 16'h0 && !rxd_s2_r;
    // An arrival is judged against the level before this clock's pop.
    assign take = ser_valid && !rx_full;
    assign drop = ser_valid && rx_full;
    assign rx_byte_o = take;

    assign txd_o = txd_r;
    assign irq_o = (irqen_r[0] && !rx_empty) || (irqen_r[1] && tx_empty && !tx_busy_r);

    always_comb begin
        case (off_i)
            O_DATA:   rdata_o = {!rx_empty, overrun_r, ferr_r, 21'h0, rx_empty ? 8'h0 : rxq[rx_rd_r]};
            O_STATUS: rdata_o = {12'h0, !rx_empty, tx_full, rx_full, tx_busy_r || !tx_empty,
                                 8'(tx_cnt_r), 8'(rx_cnt_r)};
            O_BAUD:   rdata_o = {16'h0, baud_r};
            O_IRQEN:  rdata_o = {30'h0, irqen_r};
            O_CLR:    rdata_o = {1'b0, overrun_r, ferr_r, 29'h0};
            default:  rdata_o = 32'h0;
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            baud_r <= BAUD_RESET; irqen_r <= 2'b00; overrun_r <= 1'b0; ferr_r <= 1'b0;
            rx_rd_r <= '0; rx_wr_r <= '0; rx_cnt_r <= '0;
            tx_rd_r <= '0; tx_wr_r <= '0; tx_cnt_r <= '0;
            txd_r <= 1'b1; tx_busy_r <= 1'b0; tx_sh_r <= 9'h1FF; tx_bit_r <= 4'h0; tx_clk_r <= 16'h0;
            rxd_s1_r <= 1'b1; rxd_s2_r <= 1'b1; rxd_d_r <= 1'b1;
            rx_busy_r <= 1'b0; rx_bit_r <= 4'h0; rx_clk_r <= 16'h0; rx_sh_r <= 8'h0;
        end else begin
            if (sel_i && we_i) begin
                if (off_i == O_BAUD)  baud_r  <= wdata_i[15:0];
                if (off_i == O_IRQEN) irqen_r <= wdata_i[1:0];
            end
            if (sel_i && we_i && off_i == O_CLR && wdata_i[30]) overrun_r <= 1'b0;
            if (sel_i && we_i && off_i == O_CLR && wdata_i[29]) ferr_r <= 1'b0;
            if (drop)     overrun_r <= 1'b1;
            if (ser_ferr) ferr_r <= 1'b1;

            // RX FIFO.
            if (take) begin
                rxq[rx_wr_r] <= rx_sh_r;
                rx_wr_r <= fnext(rx_wr_r);
            end
            if (rx_pop) rx_rd_r <= fnext(rx_rd_r);
            if (take && !rx_pop)      rx_cnt_r <= rx_cnt_r + 1'b1;
            else if (rx_pop && !take) rx_cnt_r <= rx_cnt_r - 1'b1;

            // TX FIFO.
            if (tx_push) begin
                txq[tx_wr_r] <= wdata_i[7:0];
                tx_wr_r <= fnext(tx_wr_r);
            end
            if (tx_pop) tx_rd_r <= fnext(tx_rd_r);
            if (tx_push && !tx_pop)      tx_cnt_r <= tx_cnt_r + 1'b1;
            else if (tx_pop && !tx_push) tx_cnt_r <= tx_cnt_r - 1'b1;

            // Serializer: start bit, eight data bits LSB first, stop bit.
            if (tx_pop) begin
                tx_busy_r <= 1'b1;
                txd_r     <= 1'b0;
                tx_sh_r   <= {1'b1, txq[tx_rd_r]};
                tx_bit_r  <= 4'd0;
                tx_clk_r  <= baud - 16'd1;
            end else if (tx_busy_r) begin
                if (tx_clk_r != 16'h0)
                    tx_clk_r <= tx_clk_r - 16'd1;
                else if (tx_bit_r == 4'd9) begin
                    tx_busy_r <= 1'b0;
                    txd_r     <= 1'b1;
                end else begin
                    txd_r    <= tx_sh_r[0];
                    tx_sh_r  <= {1'b1, tx_sh_r[8:1]};
                    tx_bit_r <= tx_bit_r + 4'd1;
                    tx_clk_r <= baud - 16'd1;
                end
            end

            // Receiver: start edge, mid-bit check, eight data bits, stop.
            rxd_s1_r <= rxd_i;
            rxd_s2_r <= rxd_s1_r;
            rxd_d_r  <= rxd_s2_r;
            if (!rx_busy_r) begin
                if (rxd_d_r && !rxd_s2_r) begin
                    rx_busy_r <= 1'b1;
                    rx_bit_r  <= 4'd0;
                    rx_clk_r  <= (baud >> 1) - 16'd1;
                end
            end else if (rx_clk_r != 16'h0) begin
                rx_clk_r <= rx_clk_r - 16'd1;
            end else begin
                rx_clk_r <= baud - 16'd1;
                if (rx_bit_r == 4'd0) begin
                    if (rxd_s2_r) rx_busy_r <= 1'b0;   // a glitch, not a start bit
                    else          rx_bit_r <= 4'd1;
                end else if (rx_bit_r == 4'd9) begin
                    rx_busy_r <= 1'b0;
                end else begin
                    rx_sh_r  <= {rxd_s2_r, rx_sh_r[7:1]};
                    rx_bit_r <= rx_bit_r + 4'd1;
                end
            end
        end
    end
endmodule
