`include "mpy_defs.svh"

// Byte-addressed image ("flash") and data SRAM, with one port per master.
//
// Storage: four interleaved 16384 x 36 single-port SRAM banks. Physical
// words [0, image_words_i rounded to 8) hold the image; the remainder holds
// mutable data. Bank = physical word[1:0], row = physical word >> 2.
// image_words_i is fixed before masters leave reset. All SRAM is cleared
// before boot writes begin; init_done_o is the clear completion signal.
//
// Ports. Port p is one master (mpy_soc: 0 collector, 1 core, 2 accelerator).
// A master holds req_i[p] and its fields until gnt_o[p]. Each block takes
// one access per cycle; when two ports want the same block, the lower port
// number wins and the other waits. Ports that want different blocks are
// granted in the same cycle, so up to four accesses run at once. An access
// that faults (an image store, an unaligned word, an address outside both
// regions) needs no block and is granted on its own; it never reaches an
// SRAM. be_i picks the bytes a store writes and tag_we_i also writes the tag,
// through the write mask, so a store is one SRAM write.
//
// Each port is pipelined one deep. A request can be granted while the
// unit is idle or in the last cycle of that port's previous access, and
// ack_o[p] pulses SRAM_LATENCY + 1 cycles after the grant (plus
// FLASH_WAIT_STATES for the image), with the word on rdata_o / rtag_o. A
// store's ack carries zero data. The SRAM sees an access in the cycle it is
// granted, so an access granted later, on any port, sees it.
//
module mpy_mem #(
    parameter int NP = 3,
    parameter int FLASH_WAIT_STATES = MPY_FLASH_WAIT_STATES,
    parameter int SRAM_LATENCY = MPY_SRAM_LATENCY
) (
    input  logic                 clk_i,
    input  logic                 rst_n_i,
    input  logic [31:0]          image_words_i,

    input  logic [NP-1:0]        req_i,
    input  logic [NP-1:0]        we_i,
    input  logic [NP-1:0]        tag_we_i,
    input  logic [NP-1:0][3:0]   be_i,
    input  logic [NP-1:0][31:0]  addr_i,
    input  logic [NP-1:0][31:0]  wdata_i,
    input  logic [NP-1:0][3:0]   wtag_i,
    output logic [NP-1:0]        gnt_o,
    output logic [NP-1:0]        ack_o,
    output logic [NP-1:0][31:0]  rdata_o,
    output logic [NP-1:0][3:0]   rtag_o,
    output logic [NP-1:0]        fault_o,
    output logic [NP-1:0][3:0]   fault_reason_o,

    // Image load (mpy_boot): word ld_idx_i of the image window.
    input  logic                       ld_we_i,
    input  logic [MPY_FLASH_IDX_W-1:0] ld_idx_i,
    input  logic [31:0]                ld_wdata_i,
    input  logic [3:0]                 ld_wtag_i,

    output logic                 init_done_o
);

    localparam int AW = MPY_MEM_BLOCK_AW;     // row address bits
    localparam int W  = MPY_MEM_WIDTH;
    localparam int NB = MPY_MEM_BLOCKS;       // 4, interleaved by word
    localparam int BS = $clog2(NB);
    localparam int SROWS = MPY_MEM_BLOCK_WORDS; // clear every physical row
    localparam int CW = $clog2(SROWS);

    logic [31:0] image_words, data_words;
    assign image_words = (image_words_i + 32'd7) & 32'hfffffff8;
    assign data_words = (image_words <= MPY_MEM_WORDS) ? MPY_MEM_WORDS - image_words : 0;

    // ---------------------------------------------------------------- blocks
    logic          blk_v    [0:NB-1];
    logic          blk_w    [0:NB-1];
    logic [AW-1:0] blk_addr [0:NB-1];
    logic [W-1:0]  blk_data [0:NB-1];
    logic [W-1:0]  blk_mask [0:NB-1];
    logic [W-1:0]  blk_q    [0:NB-1];

    for (genvar b = 0; b < NB; b++) begin : g_blk
        bsg_mem_1rw_sync_mask_write_bit #(
            .width_p(W),
            .els_p(MPY_MEM_BLOCK_WORDS)
        ) ram (
            .clk_i(clk_i),
            .reset_i(!rst_n_i),
            .data_i(blk_data[b]),
            .addr_i(blk_addr[b]),
            .v_i(blk_v[b]),
            .w_mask_i(blk_mask[b]),
            .w_i(blk_w[b]),
            .data_o(blk_q[b])
        );
    end

    // ------------------------------------------------------- post-reset clear
    logic        clr_busy;
    logic [CW:0] clr_idx;
    assign init_done_o = !clr_busy;

    // --------------------------------------------------- per-port decode
    logic [NP-1:0][7:0]    phase_r;
    logic [NP-1:0][3:0]    fault_r;    // the fault this access answers with
    logic [NP-1:0]         rd_r;       // the access read a block
    logic [NP-1:0][BS-1:0] rblk_r;     // which block
    logic [NP-1:0]         fresh_r;    // block output is this access's word
    logic [NP-1:0][W-1:0]  hold_r;     // the word, kept for the image wait state

    logic [NP-1:0]         ready;      // port can start an access this cycle
    logic [NP-1:0][3:0]    p_fault;
    logic [NP-1:0]         p_mem;      // needs a block
    logic [NP-1:0]         p_img;
    logic [NP-1:0][BS-1:0] p_blk;
    logic [NP-1:0][AW-1:0] p_row;
    logic [NP-1:0][W-1:0]  p_mask;

    always_comb begin
        for (int p = 0; p < NP; p++) begin
            logic [2:0]  region;
            logic [15:0] sw;
            logic [MPY_FLASH_IDX_W-1:0] iw;
            region = mpy_region_of(addr_i[p]);
            sw = mpy_sram_word_index(addr_i[p]);
            iw = MPY_FLASH_IDX_W'(mpy_flash_word_index(addr_i[p]));
            ready[p] = !clr_busy && (phase_r[p] <= 8'd1);
            if (addr_i[p][1:0] != 2'b00)
                p_fault[p] = MPY_FAULT_UNALIGNED;
            else if (region == MPY_REGION_FLASH)
                p_fault[p] = (32'(iw) >= image_words) ? MPY_FAULT_BUS :
                             we_i[p] ? MPY_FAULT_FLASH_STORE : MPY_FAULT_NONE;
            else if (region == MPY_REGION_SRAM)
                p_fault[p] = (32'(sw) >= data_words) ? MPY_FAULT_BUS : MPY_FAULT_NONE;
            else
                p_fault[p] = MPY_FAULT_BUS;
            p_mem[p] = (p_fault[p] == MPY_FAULT_NONE);
            p_img[p] = (region == MPY_REGION_FLASH);
            if (p_img[p]) begin
                p_blk[p] = iw[BS-1:0];
                p_row[p] = AW'(32'(iw) >> BS);
            end else begin
                p_blk[p] = BS'(32'(sw) + image_words);
                p_row[p] = AW'((32'(sw) + image_words) >> BS);
            end
            for (int k = 0; k < 4; k++)
                p_mask[p][8*k +: 8] = {8{be_i[p][k]}};
            p_mask[p][35:32] = {4{tag_we_i[p]}};
        end
    end

    // ------------------------------------------------------ block arbitration
    logic [BS-1:0] ld_blk;
    logic [AW-1:0] ld_row;
    assign ld_blk = ld_idx_i[BS-1:0];
    assign ld_row = AW'(32'(ld_idx_i) >> BS);

    always_comb begin
        logic [NB-1:0] taken;
        gnt_o = '0;
        taken = '0;
        for (int b = 0; b < NB; b++) begin
            blk_v[b]    = 1'b0;
            blk_w[b]    = 1'b0;
            blk_addr[b] = '0;
            blk_data[b] = '0;
            blk_mask[b] = '0;
            if (clr_busy) begin
                blk_v[b]    = 1'b1;
                blk_w[b]    = 1'b1;
                blk_addr[b] = AW'(clr_idx[CW-1:0]);
                blk_mask[b] = '1;
                taken[b]    = 1'b1;
            end
            if (ld_we_i && (ld_blk == BS'(b))) begin
                blk_v[b]    = 1'b1;
                blk_w[b]    = 1'b1;
                blk_addr[b] = ld_row;
                blk_data[b] = {ld_wtag_i, ld_wdata_i};
                blk_mask[b] = '1;
                taken[b]    = 1'b1;
            end
        end
        // Lowest port number first; each block serves one port.
        for (int p = 0; p < NP; p++) begin
            if (req_i[p] && ready[p]) begin
                if (!p_mem[p]) begin
                    gnt_o[p] = 1'b1;
                end else if (!taken[p_blk[p]]) begin
                    gnt_o[p] = 1'b1;
                    taken[p_blk[p]] = 1'b1;
                    blk_v[p_blk[p]]    = 1'b1;
                    blk_w[p_blk[p]]    = we_i[p];
                    blk_addr[p_blk[p]] = p_row[p];
                    blk_data[p_blk[p]] = {wtag_i[p], wdata_i[p]};
                    blk_mask[p_blk[p]] = p_mask[p];
                end
            end
        end
    end

    // ------------------------------------------------------------ responses
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            clr_busy       <= 1'b1;
            clr_idx        <= '0;
            phase_r        <= '0;
            fault_r        <= '0;
            rd_r           <= '0;
            rblk_r         <= '0;
            fresh_r        <= '0;
            hold_r         <= '0;
            ack_o          <= '0;
            rdata_o        <= '0;
            rtag_o         <= '0;
            fault_o        <= '0;
            fault_reason_o <= '0;
        end else begin
            // A load write takes its block's clear slot, so the row is
            // cleared again next cycle in every block.
            if (clr_busy && !ld_we_i) begin
                clr_idx <= clr_idx + 1'b1;
                if (clr_idx == (CW+1)'(SROWS - 1)) clr_busy <= 1'b0;
            end
            for (int p = 0; p < NP; p++) begin
                logic [W-1:0] word;
                word = fresh_r[p] ? blk_q[rblk_r[p]] : hold_r[p];
                ack_o[p]          <= 1'b0;
                fault_o[p]        <= 1'b0;
                fault_reason_o[p] <= MPY_FAULT_NONE;
                if (fresh_r[p]) begin
                    fresh_r[p] <= 1'b0;
                    hold_r[p]  <= blk_q[rblk_r[p]];
                end
                if (phase_r[p] == 8'd1) begin
                    phase_r[p] <= '0;
                    ack_o[p]   <= 1'b1;
                    rdata_o[p] <= rd_r[p] ? word[31:0] : 32'd0;
                    rtag_o[p]  <= rd_r[p] ? word[35:32] : 4'd0;
                    if (fault_r[p] != MPY_FAULT_NONE) begin
                        fault_o[p]        <= 1'b1;
                        fault_reason_o[p] <= fault_r[p];
                    end
                end else if (phase_r[p] != 8'd0) begin
                    phase_r[p] <= phase_r[p] - 8'd1;
                end
                // Granted in the last cycle of the port's previous access,
                // a request replaces that access's fields only after it has
                // used them.
                if (gnt_o[p]) begin
                    fault_r[p] <= p_fault[p];
                    rd_r[p]    <= p_mem[p] && !we_i[p];
                    rblk_r[p]  <= p_blk[p];
                    fresh_r[p] <= p_mem[p] && !we_i[p];
                    phase_r[p] <= p_img[p] ? 8'(SRAM_LATENCY + FLASH_WAIT_STATES)
                                           : 8'(SRAM_LATENCY);
                end
            end
        end
    end

endmodule
