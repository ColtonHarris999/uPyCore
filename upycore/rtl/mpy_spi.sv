// SPI controller, MMIO offset 0x300. Modes 0-3, 8-bit frames MSB first,
// full duplex. Spec: upycore/docs/mpy_peripherals.md (SPI controller)
//
// Each byte from the TX FIFO is shifted out while one is shifted in; the
// received byte joins the RX FIFO, or sets sticky overrun when it is full.
// SCK holds each level for DIV + 1 clocks and idles at CPOL. With CPHA 0
// MOSI is set before the leading edge, which samples; with CPHA 1 the
// leading edge sets MOSI and the trailing edge samples. Chip select is a
// GPIO. Offsets outside 0x300..0x3FF read 0.
module mpy_spi #(
    parameter int SPI_FIFO_DEPTH = 8
) (
    input  logic        clk_i,
    input  logic        rst_n_i,

    input  logic        req_i,
    input  logic        we_i,
    input  logic [11:0] off_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    output logic        sck_o,
    output logic        mosi_o,
    input  logic        miso_i,
    output logic        irq_o
);
    localparam int FD = SPI_FIFO_DEPTH;
    localparam int FPW = (FD > 1) ? $clog2(FD) : 1;
    localparam int FCW = $clog2(FD + 1);
    localparam logic [11:0] SPI_CTRL   = 12'h300;
    localparam logic [11:0] SPI_DATA   = 12'h304;
    localparam logic [11:0] SPI_STATUS = 12'h308;
    localparam logic [11:0] SPI_IRQEN  = 12'h30C;

    logic        en_r, cpol_r, cpha_r;
    logic [15:0] div_r;
    logic [1:0]  irqen_r;
    logic [7:0]  txq [0:FD-1];
    logic [7:0]  rxq [0:FD-1];
    logic [FPW-1:0] tx_rd_r, tx_wr_r, rx_rd_r, rx_wr_r;
    logic [FCW-1:0] tx_cnt_r, rx_cnt_r;
    logic        ovr_r;
    logic        busy_r, half_r;
    logic [2:0]  bit_r;
    logic [15:0] hcnt_r;
    logic [7:0]  tx_sh_r, rx_sh_r;
    logic        sck_r, mosi_r;

    logic tx_full, tx_empty, rx_full, rx_empty;
    logic wr_data, rd_data, tx_push, tx_pop, rx_push, rx_pop;
    logic half_end, byte_done;

    function automatic logic [FPW-1:0] fnext(input logic [FPW-1:0] p);
        fnext = (32'(p) == FD - 1) ? '0 : p + 1'b1;
    endfunction

    assign tx_full  = (32'(tx_cnt_r) == FD);
    assign tx_empty = (tx_cnt_r == '0);
    assign rx_full  = (32'(rx_cnt_r) == FD);
    assign rx_empty = (rx_cnt_r == '0);

    assign wr_data = req_i && we_i && (off_i == SPI_DATA);
    assign rd_data = req_i && !we_i && (off_i == SPI_DATA);
    assign tx_push = wr_data && !tx_full;
    assign tx_pop  = en_r && !busy_r && !tx_empty;
    assign rx_pop  = rd_data && !rx_empty;
    assign half_end = busy_r && (hcnt_r == div_r);
    assign byte_done = half_end && half_r && (bit_r == 3'd7);
    assign rx_push = byte_done && !rx_full;

    // Idle SCK is CPOL itself, so a mode change never makes an edge late.
    assign sck_o  = busy_r ? sck_r : cpol_r;
    assign mosi_o = mosi_r;
    assign irq_o  = (irqen_r[0] && tx_empty && !busy_r) || (irqen_r[1] && !rx_empty);

    always_comb begin
        rdata_o = 32'h0;
        if (req_i && !we_i) begin
            case (off_i)
                SPI_CTRL:   rdata_o = {8'h0, div_r, 5'h0, cpha_r, cpol_r, en_r};
                SPI_DATA:   rdata_o = {!rx_empty, 23'h0, rx_empty ? 8'h0 : rxq[rx_rd_r]};
                SPI_STATUS: rdata_o = {12'h0, ovr_r, !rx_empty, tx_empty, busy_r || !tx_empty,
                                       3'h0, 5'(rx_cnt_r), 3'h0, 5'(tx_cnt_r)};
                SPI_IRQEN:  rdata_o = {30'h0, irqen_r};
                default:    rdata_o = 32'h0;
            endcase
        end
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            en_r <= 1'b0; cpol_r <= 1'b0; cpha_r <= 1'b0; div_r <= 16'h0; irqen_r <= 2'b0;
            tx_rd_r <= '0; tx_wr_r <= '0; tx_cnt_r <= '0;
            rx_rd_r <= '0; rx_wr_r <= '0; rx_cnt_r <= '0;
            ovr_r <= 1'b0;
            busy_r <= 1'b0; half_r <= 1'b0; bit_r <= 3'h0; hcnt_r <= 16'h0;
            tx_sh_r <= 8'h0; rx_sh_r <= 8'h0;
            sck_r <= 1'b0; mosi_r <= 1'b0;
        end else begin
            if (req_i && we_i && off_i == SPI_CTRL) begin
                en_r <= wdata_i[0]; cpol_r <= wdata_i[1]; cpha_r <= wdata_i[2];
                div_r <= wdata_i[23:8];
            end
            if (req_i && we_i && off_i == SPI_IRQEN)
                irqen_r <= wdata_i[1:0];
            if (req_i && we_i && off_i == SPI_STATUS && wdata_i[19])
                ovr_r <= 1'b0;
            if (byte_done && rx_full)
                ovr_r <= 1'b1;
            if (!busy_r)
                sck_r <= cpol_r;

            if (tx_push) begin
                txq[tx_wr_r] <= wdata_i[7:0];
                tx_wr_r <= fnext(tx_wr_r);
            end
            if (tx_pop)
                tx_rd_r <= fnext(tx_rd_r);
            if (tx_push && !tx_pop)
                tx_cnt_r <= tx_cnt_r + 1'b1;
            else if (tx_pop && !tx_push)
                tx_cnt_r <= tx_cnt_r - 1'b1;

            if (rx_push) begin
                // CPHA 1 takes its eighth sample on this trailing edge.
                rxq[rx_wr_r] <= cpha_r ? {rx_sh_r[6:0], miso_i} : rx_sh_r;
                rx_wr_r <= fnext(rx_wr_r);
            end
            if (rx_pop)
                rx_rd_r <= fnext(rx_rd_r);
            if (rx_push && !rx_pop)
                rx_cnt_r <= rx_cnt_r + 1'b1;
            else if (rx_pop && !rx_push)
                rx_cnt_r <= rx_cnt_r - 1'b1;

            if (tx_pop) begin
                busy_r  <= 1'b1;
                half_r  <= 1'b0;
                bit_r   <= 3'd0;
                hcnt_r  <= 16'h0;
                tx_sh_r <= txq[tx_rd_r];
                sck_r   <= cpol_r;
                if (!cpha_r)
                    mosi_r <= txq[tx_rd_r][7];
            end else if (busy_r) begin
                if (!half_end)
                    hcnt_r <= hcnt_r + 16'd1;
                else begin
                    hcnt_r <= 16'h0;
                    sck_r  <= !sck_r;
                    if (!half_r) begin
                        // Leading edge.
                        half_r <= 1'b1;
                        if (!cpha_r)
                            rx_sh_r <= {rx_sh_r[6:0], miso_i};
                        else
                            mosi_r <= tx_sh_r[3'd7 - bit_r];
                    end else begin
                        // Trailing edge.
                        half_r <= 1'b0;
                        if (cpha_r)
                            rx_sh_r <= {rx_sh_r[6:0], miso_i};
                        if (bit_r == 3'd7)
                            busy_r <= 1'b0;
                        else begin
                            bit_r <= bit_r + 3'd1;
                            if (!cpha_r)
                                mosi_r <= tx_sh_r[3'd6 - bit_r];
                        end
                    end
                end
            end
        end
    end
endmodule
