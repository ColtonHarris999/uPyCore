`include "mpy_defs.svh"

// Byte-addressed image ("flash") and data SRAM. Every word is 36 bits in
// the SRAM: the 32-bit payload and its 4-bit tag side by side, so one access
// reads or writes both. Each memory is MPY_*_BLOCKS 64 KB blocks of
// bsg_mem_1rw_sync_mask_write_bit (16384 x 36, one read/write port, per-bit
// write mask); the EE 477 flow swaps each block for a fakeram_d16384_w36
// macro.
//
// A one-cycle req_i pulse starts an access and ack_o pulses when it
// completes, SRAM_LATENCY + 1 cycles later (plus FLASH_WAIT_STATES for the
// image). be_i picks the bytes a store writes; tag_we_i also writes the tag.
// The write mask does that in the SRAM, so a store is one write, not a read
// and a write. An image store, an unaligned word, or an address outside both
// regions answers with fault_o and never reaches an SRAM. A store's ack
// carries rdata_o = 0.
//
// The port is pipelined one deep: rdy_o is set while the unit is idle or
// in the last cycle of an access, and a request taken then starts while
// the previous one completes. With SRAM_LATENCY = 1 that is one SRAM
// access per cycle. The SRAM sees an access in the cycle it is taken, so a
// load taken after a store sees it, and accesses complete in order. id_i
// rides with the access and comes back on id_o with its ack, which is how
// mpy_soc routes the answer.
//
// After reset the unit writes zero (payload and tag) to every data SRAM
// word, one word per cycle in every block at once, and holds rdy_o low
// until init_done_o. The image SRAM is written only through the ld_* port,
// which mpy_boot drives while the masters are held in reset; a load write
// takes the image block even if a request is taken in the same cycle.
module mpy_mem #(
    parameter int FLASH_WAIT_STATES = MPY_FLASH_WAIT_STATES,
    parameter int SRAM_LATENCY = MPY_SRAM_LATENCY
) (
    input  logic        clk_i,
    input  logic        rst_n_i,

    input  logic        req_i,
    input  logic        we_i,
    input  logic        tag_we_i,
    input  logic [3:0]  be_i,
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic [3:0]  wtag_i,
    input  logic [1:0]  id_i,
    output logic        rdy_o,
    output logic        ack_o,
    output logic [1:0]  id_o,
    output logic [31:0] rdata_o,
    output logic [3:0]  rtag_o,
    output logic        fault_o,
    output logic [3:0]  fault_reason_o,

    // Image load (mpy_boot): word ld_idx_i of the image window.
    input  logic                       ld_we_i,
    input  logic [MPY_FLASH_IDX_W-1:0] ld_idx_i,
    input  logic [31:0]                ld_wdata_i,
    input  logic [3:0]                 ld_wtag_i,

    output logic        init_done_o
);

    localparam int AW = MPY_MEM_BLOCK_AW;
    localparam int W  = MPY_MEM_WIDTH;
    localparam int NB = MPY_MEM_BLOCKS;      // data blocks first, then image
    localparam int SB = $clog2(NB);

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

    // ------------------------------------------------------------- the port
    logic [7:0]    phase_r;
    logic [1:0]    id_r;
    logic [3:0]    fault_r;    // MPY_FAULT_NONE, or the fault this access answers with
    logic          rd_r;       // the access read a block
    logic [SB-1:0] rblk_r;     // which block
    logic          fresh_r;    // the block's output is this access's word (cycle after the access)
    logic [W-1:0]  hold_r;     // the word, kept for the image wait states

    logic        clr_busy;
    logic [AW:0] clr_idx;

    assign rdy_o = !clr_busy && (phase_r <= 8'd1);
    assign init_done_o = !clr_busy;

    // Decode of the request being taken this cycle.
    logic        take;
    logic [2:0]  a_region;
    logic        a_aligned;
    logic [3:0]  a_fault;
    logic        a_sram, a_img;
    logic [15:0] a_sw;                     // data SRAM word
    logic [MPY_FLASH_IDX_W-1:0] a_iw;      // image word
    logic [SB-1:0] a_blk;
    logic [W-1:0]  a_mask;

    assign take      = req_i && rdy_o;
    assign a_region  = mpy_region_of(addr_i);
    assign a_aligned = (addr_i[1:0] == 2'b00);
    assign a_sw      = mpy_sram_word_index(addr_i);
    assign a_iw      = MPY_FLASH_IDX_W'(mpy_flash_word_index(addr_i));
    always_comb begin
        if (!a_aligned)
            a_fault = MPY_FAULT_UNALIGNED;
        else if (a_region == MPY_REGION_FLASH)
            a_fault = we_i ? MPY_FAULT_FLASH_STORE : MPY_FAULT_NONE;
        else if (a_region == MPY_REGION_SRAM)
            a_fault = MPY_FAULT_NONE;
        else
            a_fault = MPY_FAULT_BUS;
        a_sram = take && (a_fault == MPY_FAULT_NONE) && (a_region == MPY_REGION_SRAM);
        a_img  = take && (a_fault == MPY_FAULT_NONE) && (a_region == MPY_REGION_FLASH);
        a_blk  = (a_region == MPY_REGION_SRAM)
               ? SB'(a_sw >> AW)
               : SB'(MPY_SRAM_BLOCKS + (32'(a_iw) >> AW));
        for (int k = 0; k < 4; k++)
            a_mask[8*k +: 8] = {8{be_i[k]}};
        a_mask[35:32] = {4{tag_we_i}};
    end

    logic [SB-1:0] ld_blk;
    assign ld_blk = SB'(MPY_SRAM_BLOCKS + (32'(ld_idx_i) >> AW));

    always_comb begin
        for (int b = 0; b < NB; b++) begin
            blk_v[b]    = 1'b0;
            blk_w[b]    = 1'b0;
            blk_addr[b] = (b < MPY_SRAM_BLOCKS) ? a_sw[AW-1:0] : a_iw[AW-1:0];
            blk_data[b] = {wtag_i, wdata_i};
            blk_mask[b] = a_mask;
            if (b < MPY_SRAM_BLOCKS) begin
                if (clr_busy) begin
                    blk_v[b]    = 1'b1;
                    blk_w[b]    = 1'b1;
                    blk_addr[b] = clr_idx[AW-1:0];
                    blk_data[b] = '0;
                    blk_mask[b] = '1;
                end else if (a_sram && (a_blk == SB'(b))) begin
                    blk_v[b] = 1'b1;
                    blk_w[b] = we_i;
                end
            end else begin
                if (ld_we_i && (ld_blk == SB'(b))) begin
                    blk_v[b]    = 1'b1;
                    blk_w[b]    = 1'b1;
                    blk_addr[b] = ld_idx_i[AW-1:0];
                    blk_data[b] = {ld_wtag_i, ld_wdata_i};
                    blk_mask[b] = '1;
                end else if (a_img && (a_blk == SB'(b))) begin
                    blk_v[b] = 1'b1;
                end
            end
        end
    end

    logic [W-1:0] word_q;
    assign word_q = fresh_r ? blk_q[rblk_r] : hold_r;

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            clr_busy       <= 1'b1;
            clr_idx        <= '0;
            phase_r        <= '0;
            id_r           <= '0;
            fault_r        <= MPY_FAULT_NONE;
            rd_r           <= 1'b0;
            rblk_r         <= '0;
            fresh_r        <= 1'b0;
            hold_r         <= '0;
            id_o           <= '0;
            ack_o          <= 1'b0;
            rdata_o        <= '0;
            rtag_o         <= '0;
            fault_o        <= 1'b0;
            fault_reason_o <= MPY_FAULT_NONE;
        end else begin
            if (clr_busy) begin
                clr_idx <= clr_idx + 1'b1;
                if (clr_idx == (AW+1)'(MPY_MEM_BLOCK_WORDS - 1)) clr_busy <= 1'b0;
            end
            ack_o          <= 1'b0;
            fault_o        <= 1'b0;
            fault_reason_o <= MPY_FAULT_NONE;
            if (fresh_r) begin
                fresh_r <= 1'b0;
                hold_r  <= blk_q[rblk_r];
            end
            if (phase_r == 8'd1) begin
                phase_r <= '0;
                ack_o   <= 1'b1;
                id_o    <= id_r;
                rdata_o <= rd_r ? word_q[31:0] : 32'd0;
                rtag_o  <= rd_r ? word_q[35:32] : 4'd0;
                if (fault_r != MPY_FAULT_NONE) begin
                    fault_o        <= 1'b1;
                    fault_reason_o <= fault_r;
                end
            end else if (phase_r != 8'd0) begin
                phase_r <= phase_r - 8'd1;
            end
            // Taken in the last cycle of the previous access, a request
            // replaces that access's fields only after it has used them.
            if (take) begin
                id_r    <= id_i;
                fault_r <= a_fault;
                rd_r    <= (a_sram || a_img) && !we_i;
                rblk_r  <= a_blk;
                fresh_r <= (a_sram || a_img) && !we_i;
                if (a_region == MPY_REGION_FLASH)
                    phase_r <= 8'(SRAM_LATENCY + FLASH_WAIT_STATES);
                else
                    phase_r <= 8'(SRAM_LATENCY);
            end
        end
    end

endmodule
