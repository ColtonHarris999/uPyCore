`include "mpy_defs.svh"

// Boot loader. Out of reset it copies the linked image from an SPI NAND
// flash into the image SRAM through mpy_mem's ld_* port, then raises done_o
// and mpy_soc lets the hart, the collector and the accelerator out of reset.
//
// The NAND holds a boot stream from page FIRST_PAGE on (upycore/docs/
// mpy_boot.md, written by upycore/tools/mpy_nand.py), little-endian words:
//
//   MPY_BOOT_MAGIC, image word count n, then ceil(n/8) groups of
//   { packed tag word (nibble i = tag of word i), eight image words }
//
// so every image word is written once, payload and tag together. A bad
// magic, n == 0, or n beyond the image SRAM raises err_o and the hart stays
// in reset.
//
// SPI mode 0, one data line each way, standard SPI NAND commands (W25N,
// GD5F, MT29F): FFh reset, then per page 13h page read to the cache, 0Fh/C0h
// status polls until OIP clears, 03h read from cache at column 0. SCK runs
// at clk / (2 * SPI_DIV). MOSI changes after SCK falls; MISO is sampled on
// the core clock edge that raises SCK, half an SCK period after the flash
// drove it. POWERUP_CYCLES waits before the first command for the flash's
// power-up time.
//
// Simulation can skip SPI: with +IMAGE=<hex> (+TAGS=<hex>) and no +NAND, the
// same word stream is built from the linked image files and fed one word per
// cycle, so every run still goes through the stream decoder and the load
// port. +NAND (the testbench's SPI NAND model) boots over SPI.
module mpy_boot #(
    parameter int          SPI_DIV        = 2,
    parameter int          PAGE_BYTES     = 2048,
    parameter logic [15:0] FIRST_PAGE     = 16'd0,
    parameter int          POWERUP_CYCLES = 0
) (
    input  logic        clk_i,
    input  logic        rst_n_i,

    output logic        sck_o,
    output logic        cs_n_o,
    output logic        mosi_o,
    input  logic        miso_i,

    output logic                       ld_we_o,
    output logic [MPY_FLASH_IDX_W-1:0] ld_idx_o,
    output logic [31:0]                ld_wdata_o,
    output logic [3:0]                 ld_wtag_o,

    output logic [31:0] image_words_o,
    output logic [31:0] pool_bytes_o, // optional image-requested heap cap (0: all remaining)
    output logic        done_o,
    output logic        err_o
);

    // ------------------------------------------------------- word source
    logic        src_v;     // one stream word this cycle
    logic [31:0] src_w;
    logic        use_fast;  // simulation stream instead of SPI
    logic        fast_v;
    logic [31:0] fast_w;
    logic        spi_v;
    logic [31:0] spi_w;
    logic        stop;      // the decoder has finished (done or error)

    assign src_v = use_fast ? fast_v : spi_v;
    assign src_w = use_fast ? fast_w : spi_w;

    // ------------------------------------------------------ stream decoder
    typedef enum logic [2:0] { C_MAGIC, C_COUNT, C_TAG, C_DATA, C_DONE, C_ERR } cst_e;
    cst_e        cst;
    logic [31:0] nwords;
    logic [31:0] tagw;
    logic [2:0]  k;
    logic [MPY_FLASH_IDX_W:0] widx;

    assign image_words_o = (nwords + 32'd7) & 32'hfffffff8;
    assign stop  = (cst == C_DONE) || (cst == C_ERR);
    assign err_o = (cst == C_ERR);

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            cst        <= C_MAGIC;
            nwords     <= '0;
            pool_bytes_o <= '0;
            tagw       <= '0;
            k          <= '0;
            widx       <= '0;
            ld_we_o    <= 1'b0;
            ld_idx_o   <= '0;
            ld_wdata_o <= '0;
            ld_wtag_o  <= '0;
            done_o     <= 1'b0;
        end else begin
            ld_we_o <= 1'b0;
            // done_o rises once the last load write has gone out.
            if (cst == C_DONE && !ld_we_o) done_o <= 1'b1;
            if (src_v) begin
                unique case (cst)
                    C_MAGIC: cst <= (src_w == MPY_BOOT_MAGIC) ? C_COUNT : C_ERR;
                    C_COUNT: begin
                        nwords <= src_w;
                        cst <= (src_w < 32'd16 || src_w > 32'((MPY_MEM_BYTES - (MPY_GC_POOL_BASE - MPY_SRAM_BASE) - 16) / 32 * 8)) ? C_ERR : C_TAG;
                    end
                    C_TAG: begin
                        tagw <= src_w;
                        k    <= '0;
                        cst  <= C_DATA;
                    end
                    C_DATA: begin
                        if (widx == 14) pool_bytes_o <= src_w;
                        ld_we_o    <= 1'b1;
                        ld_idx_o   <= widx[MPY_FLASH_IDX_W-1:0];
                        ld_wdata_o <= src_w;
                        ld_wtag_o  <= tagw[4*k +: 4];
                        widx       <= widx + 1'b1;
                        k          <= k + 3'd1;
                        if (k == 3'd7)
                            cst <= (32'(widx) + 32'd1 >= nwords) ? C_DONE : C_TAG;
                    end
                    default: ;
                endcase
            end
        end
    end

    // ------------------------------------------------------- SPI byte engine
    // start (one cycle) shifts tx out MSB first while shifting MISO into
    // rx_sr; byte_done pulses when the eighth bit's SCK low phase is over.
    localparam int DW = (SPI_DIV > 1) ? $clog2(SPI_DIV) : 1;
    logic          start;
    logic [7:0]    tx;
    logic          busy;
    logic          byte_done;
    logic [2:0]    bit_i;
    logic [7:0]    tx_sr, rx_sr;
    logic [DW-1:0] div;
    logic          tick;

    assign tick = (div == '0);

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            busy      <= 1'b0;
            byte_done <= 1'b0;
            bit_i     <= '0;
            tx_sr     <= '0;
            rx_sr     <= '0;
            div       <= '0;
            sck_o     <= 1'b0;
            mosi_o    <= 1'b0;
        end else begin
            byte_done <= 1'b0;
            div <= tick ? DW'(SPI_DIV - 1) : div - 1'b1;
            if (start) begin
                busy   <= 1'b1;
                tx_sr  <= tx;
                mosi_o <= tx[7];
                bit_i  <= '0;
                sck_o  <= 1'b0;
                div    <= DW'(SPI_DIV - 1);
            end else if (busy && tick) begin
                if (!sck_o) begin
                    sck_o <= 1'b1;
                    rx_sr <= {rx_sr[6:0], miso_i};
                end else begin
                    sck_o <= 1'b0;
                    if (bit_i == 3'd7) begin
                        busy      <= 1'b0;
                        byte_done <= 1'b1;
                    end else begin
                        bit_i  <= bit_i + 3'd1;
                        tx_sr  <= {tx_sr[6:0], 1'b0};
                        mosi_o <= tx_sr[6];
                    end
                end
            end
        end
    end

    // ---------------------------------------------------------- SPI commands
    typedef enum logic [2:0] { S_WAIT, S_GAP, S_RESET, S_POLL, S_PAGE, S_READ, S_IDLE } sst_e;
    localparam int GAP_CYCLES = 4 * SPI_DIV;
    localparam int RD_HDR     = 4;   // 03h, column high, column low, dummy
    localparam int BI_W       = $clog2(PAGE_BYTES + RD_HDR + 1);

    sst_e        sst, nxt, poll_ret;
    logic        pend;               // a byte is in flight for this state
    logic [BI_W-1:0] bi;             // byte of the current command
    logic [31:0] wait_cnt;
    logic [15:0] page;
    logic [1:0]  bsel;               // byte lane of the word being assembled
    logic [23:0] wlo;

    always_comb begin
        unique case (sst)
            S_RESET: tx = 8'hFF;
            S_POLL:  tx = (bi == '0) ? 8'h0F : (bi == BI_W'(1)) ? 8'hC0 : 8'h00;
            S_PAGE:  tx = (bi == '0) ? 8'h13 : (bi == BI_W'(1)) ? 8'h00 :
                          (bi == BI_W'(2)) ? page[15:8] : page[7:0];
            S_READ:  tx = (bi == '0) ? 8'h03 : 8'h00;
            default: tx = 8'h00;
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            sst      <= S_WAIT;
            nxt      <= S_RESET;
            poll_ret <= S_PAGE;
            pend     <= 1'b0;
            start    <= 1'b0;
            bi       <= '0;
            wait_cnt <= 32'(POWERUP_CYCLES);
            page     <= FIRST_PAGE;
            bsel     <= '0;
            wlo      <= '0;
            cs_n_o   <= 1'b1;
            spi_v    <= 1'b0;
            spi_w    <= '0;
        end else begin
            start <= 1'b0;
            spi_v <= 1'b0;
            if (use_fast) begin
                sst <= S_IDLE;
            end else unique case (sst)
                S_WAIT, S_GAP: begin
                    cs_n_o <= 1'b1;
                    if (stop) sst <= S_IDLE;
                    else if (wait_cnt == 32'd0) begin
                        sst <= nxt;
                        bi  <= '0;
                    end else wait_cnt <= wait_cnt - 32'd1;
                end
                S_RESET, S_POLL, S_PAGE, S_READ: begin
                    cs_n_o <= 1'b0;
                    if (!pend && !busy && !byte_done) begin
                        start <= 1'b1;
                        pend  <= 1'b1;
                    end else if (byte_done) begin
                        pend <= 1'b0;
                        bi   <= bi + 1'b1;
                        unique case (sst)
                            S_RESET: begin
                                sst <= S_GAP; nxt <= S_POLL; poll_ret <= S_PAGE;
                                wait_cnt <= 32'(GAP_CYCLES);
                            end
                            S_POLL: if (bi == BI_W'(2)) begin
                                sst <= S_GAP;
                                nxt <= rx_sr[0] ? S_POLL : poll_ret;
                                wait_cnt <= 32'(GAP_CYCLES);
                            end
                            S_PAGE: if (bi == BI_W'(3)) begin
                                sst <= S_GAP; nxt <= S_POLL; poll_ret <= S_READ;
                                wait_cnt <= 32'(GAP_CYCLES);
                            end
                            S_READ: if (bi >= BI_W'(RD_HDR)) begin
                                // Little-endian: the first byte is bits 7:0.
                                bsel <= bsel + 2'd1;
                                if (bsel == 2'd3) begin
                                    spi_v <= 1'b1;
                                    spi_w <= {rx_sr, wlo};
                                end else begin
                                    wlo <= {rx_sr, wlo[23:8]};
                                end
                                if (bi == BI_W'(RD_HDR + PAGE_BYTES - 1)) begin
                                    sst  <= S_GAP; nxt <= S_PAGE;
                                    page <= page + 16'd1;
                                    wait_cnt <= 32'(GAP_CYCLES);
                                end
                            end
                            default: ;
                        endcase
                    end
                    // The decoder needs no more words: stop mid-page.
                    if (stop && !busy && !start) begin
                        sst    <= S_IDLE;
                        cs_n_o <= 1'b1;
                        pend   <= 1'b0;
                        start  <= 1'b0;
                    end
                end
                default: cs_n_o <= 1'b1;   // S_IDLE
            endcase
        end
    end

    // ------------------------------------------------- simulation stream
`ifdef SYNTHESIS
    assign use_fast = 1'b0;
    assign fast_v   = 1'b0;
    assign fast_w   = '0;
`else
    logic [31:0] sim_img [0:MPY_FLASH_WORDS-1];
    logic [31:0] sim_tag [0:MPY_FLASH_WORDS/8-1];
    logic        sim_on;
    int unsigned sim_n;      // image words
    int          sim_len;    // stream words
    int          sim_k;

    initial begin
        string path;
        sim_on = 1'b0;
        sim_n = 0;
        sim_len = 0;
        for (int i = 0; i < MPY_FLASH_WORDS; i++) sim_img[i] = '0;
        for (int i = 0; i < MPY_FLASH_WORDS / 8; i++) sim_tag[i] = '0;
        if (!$test$plusargs("NAND") && $value$plusargs("IMAGE=%s", path)) begin
            $readmemh(path, sim_img);
            if ($value$plusargs("TAGS=%s", path)) $readmemh(path, sim_tag);
            // Image header word 2 is the image size in bytes.
            sim_n = 32'((64'(sim_img[2]) + 64'd3) >> 2);
            // Preserve an oversized count so simulation rejects it, just like SPI.
            sim_len = 2 + 9 * ((sim_n + 7) / 8);
            sim_on = 1'b1;
        end
    end

    function automatic logic [31:0] sim_word(input int i);
        int g, j;
        if (i == 0) return MPY_BOOT_MAGIC;
        if (i == 1) return 32'(sim_n);
        g = (i - 2) / 9;
        j = (i - 2) % 9;
        if (g >= MPY_FLASH_WORDS / 8) return 0;
        return (j == 0) ? sim_tag[g] : sim_img[8 * g + j - 1];
    endfunction

    assign use_fast = sim_on;
    assign fast_v   = sim_on && rst_n_i && (sim_k < sim_len);
    assign fast_w   = sim_word(sim_k);

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) sim_k <= 0;
        else if (fast_v) sim_k <= sim_k + 1;
    end
`endif

endmodule
