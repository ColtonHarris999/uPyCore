// The hart's bridge to the I/O core: the 4 KB window at MPY_MMIO_BASE.
// Spec: upycore/docs/mpy_io_core.md (Bridge); plan §4.
//
// mpy_soc decodes the window beside the simulator page and takes an access
// on a clock with stall_o low (acc_now_i); it registers the access and
// presents it here on the next clock (acc_i, we_i, off_i, wdata_i). A
// load's word is rdata_o on that clock, and mpy_soc registers it into the
// simulator page's answer flops. Offsets
// outside the implemented registers never reach this block: mpy_soc leaves
// them to mpy_mem, which answers with a bus fault.
//
// Every signal to or from the I/O island crosses through a dual-clock FIFO
// (mpy_async_fifo): CMD (hart to island, 32 words), RSP (island to hart, 16
// words), CON (console bytes, hart to island, 64), CON_RX (console input,
// island to hart, 16), EVT (event set-masks, island to hart), UPD (state
// page updates, island to hart), DN (the hart's page words, hart to island)
// and LD (the boot loader's words into the island's SRAMs). The state page
// the hart reads is a hart-side copy, updated one whole word at a time from
// UPD, so a load never sees half a word.
//
// Page words 3 and 4 are not from UPD: they are the island timer's
// millisecond and microsecond counts, which cross as gray code (one bit
// changes per count) through two flops and are turned back into binary in
// a register, so a load reads an exact count a few clocks old.
//
// stall_o is a flop: it is high when CMD, CON, DN or LD could not take one
// more word, so mpy_soc holds the next window or console access in its skid
// (the core's m_busy_i) instead of dropping it.
module mpy_iobr #(
    parameter int NUP = 32,      // state page words the I/O core writes
    parameter int NDN = 8        // state page words the hart writes
) (
    input  logic        clk_i,
    input  logic        rst_n_i,

    // Window accesses (hart clock).
    input  logic        acc_i,
    input  logic        we_i,
    input  logic [9:0]  off_i,          // word offset in the window
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,
    input  logic        acc_now_i,      // an access is taken this clock (presented on the next)
    output logic        stall_o,

    // Console bytes redirected from the simulator page (bit 8: stderr).
    input  logic        con_push_i,
    input  logic [8:0]  con_data_i,
    input  logic [1:0]  con_mode_i,

    output logic        evt_pend_o,

    // Boot loader words for the island's SRAMs: {data SRAM, index, word}.
    input  logic        ld_push_i,
    input  logic [48:0] ld_data_i,
    output logic        ld_idle_o,      // LD empty as the hart side sees it
    input  logic        run_i,          // the I/O core is released (IOC_CTRL bit 0)
    input  logic        loaded_i,       // the boot stream had an IOCB section (bit 1)

    // Island side (io_clk).
    input  logic        io_clk_i,
    input  logic        io_rst_n_i,
    input  logic [31:0] us_gray_i,      // io_clk flops (iocore_top)
    input  logic [31:0] ms_gray_i,
    input  logic        cmd_pop_i,
    output logic [31:0] cmd_data_o,
    output logic        cmd_empty_o,
    output logic [5:0]  cmd_level_o,
    input  logic        rsp_push_i,
    input  logic [31:0] rsp_data_i,
    output logic        rsp_full_o,
    input  logic        evt_push_i,
    input  logic [15:0] evt_data_i,
    output logic        evt_full_o,
    input  logic        con_pop_i,
    output logic [8:0]  con_data_o,
    output logic        con_empty_o,
    output logic [6:0]  con_level_o,
    input  logic        conrx_push_i,
    input  logic [7:0]  conrx_data_i,
    output logic        conrx_full_o,
    input  logic        upd_push_i,
    input  logic [36:0] upd_data_i,     // {index[4:0], word}
    output logic        upd_full_o,
    input  logic        dn_pop_i,
    output logic [34:0] dn_data_o,      // {index[2:0], word}
    output logic        dn_empty_o,
    input  logic        ld_pop_i,
    output logic [48:0] ld_data_o,
    output logic        ld_empty_o
);
    // Word offsets.
    localparam logic [9:0] O_CMD = 10'h000, O_RSP = 10'h001, O_STATUS = 10'h002, O_EVT = 10'h003,
                           O_EVT_EN = 10'h004, O_EVT_SET = 10'h005, O_EVT_MASK = 10'h006,
                           O_IOC_CTRL = 10'h007, O_CON_RX = 10'h008, O_CON_MODE = 10'h009;

    // ---- FIFOs ----
    logic        cmd_push, cmd_full;
    logic [5:0]  cmd_wl;
    mpy_async_fifo #(.W(32), .AW(5)) u_cmd (
        .wclk(clk_i), .wrst_n(rst_n_i), .w_en(cmd_push), .w_data(wdata_i),
        .w_full(cmd_full), .w_level(cmd_wl),
        .rclk(io_clk_i), .rrst_n(io_rst_n_i), .r_en(cmd_pop_i), .r_data(cmd_data_o),
        .r_empty(cmd_empty_o), .r_level(cmd_level_o)
    );

    logic        rsp_pop, rsp_empty;
    logic [31:0] rsp_head;
    logic [4:0]  rsp_rl, rsp_wl_unused;
    mpy_async_fifo #(.W(32), .AW(4)) u_rsp (
        .wclk(io_clk_i), .wrst_n(io_rst_n_i), .w_en(rsp_push_i), .w_data(rsp_data_i),
        .w_full(rsp_full_o), .w_level(rsp_wl_unused),
        .rclk(clk_i), .rrst_n(rst_n_i), .r_en(rsp_pop), .r_data(rsp_head),
        .r_empty(rsp_empty), .r_level(rsp_rl)
    );

    logic        con_full;
    logic [6:0]  con_wl;
    mpy_async_fifo #(.W(9), .AW(6)) u_con (
        .wclk(clk_i), .wrst_n(rst_n_i), .w_en(con_push_i), .w_data(con_data_i),
        .w_full(con_full), .w_level(con_wl),
        .rclk(io_clk_i), .rrst_n(io_rst_n_i), .r_en(con_pop_i), .r_data(con_data_o),
        .r_empty(con_empty_o), .r_level(con_level_o)
    );

    logic        conrx_pop, conrx_empty;
    logic [7:0]  conrx_head;
    logic [4:0]  conrx_rl_unused, conrx_wl_unused;
    mpy_async_fifo #(.W(8), .AW(4)) u_conrx (
        .wclk(io_clk_i), .wrst_n(io_rst_n_i), .w_en(conrx_push_i), .w_data(conrx_data_i),
        .w_full(conrx_full_o), .w_level(conrx_wl_unused),
        .rclk(clk_i), .rrst_n(rst_n_i), .r_en(conrx_pop), .r_data(conrx_head),
        .r_empty(conrx_empty), .r_level(conrx_rl_unused)
    );

    logic        evt_empty;
    logic [15:0] evt_head;
    logic [2:0]  evt_rl_unused, evt_wl_unused;
    mpy_async_fifo #(.W(16), .AW(2)) u_evt (
        .wclk(io_clk_i), .wrst_n(io_rst_n_i), .w_en(evt_push_i), .w_data(evt_data_i),
        .w_full(evt_full_o), .w_level(evt_wl_unused),
        .rclk(clk_i), .rrst_n(rst_n_i), .r_en(!evt_empty), .r_data(evt_head),
        .r_empty(evt_empty), .r_level(evt_rl_unused)
    );

    logic        upd_empty;
    logic [36:0] upd_head;
    logic [2:0]  upd_rl_unused, upd_wl_unused;
    mpy_async_fifo #(.W(37), .AW(2)) u_upd (
        .wclk(io_clk_i), .wrst_n(io_rst_n_i), .w_en(upd_push_i), .w_data(upd_data_i),
        .w_full(upd_full_o), .w_level(upd_wl_unused),
        .rclk(clk_i), .rrst_n(rst_n_i), .r_en(!upd_empty), .r_data(upd_head),
        .r_empty(upd_empty), .r_level(upd_rl_unused)
    );

    logic        dn_push;
    logic [2:0]  dn_wl, dn_rl_unused;
    logic        dn_full_unused;
    mpy_async_fifo #(.W(35), .AW(2)) u_dn (
        .wclk(clk_i), .wrst_n(rst_n_i), .w_en(dn_push), .w_data({off_i[2:0], wdata_i}),
        .w_full(dn_full_unused), .w_level(dn_wl),
        .rclk(io_clk_i), .rrst_n(io_rst_n_i), .r_en(dn_pop_i), .r_data(dn_data_o),
        .r_empty(dn_empty_o), .r_level(dn_rl_unused)
    );

    logic [2:0]  ld_wl, ld_rl_unused;
    logic        ld_full_unused;
    mpy_async_fifo #(.W(49), .AW(2)) u_ld (
        .wclk(clk_i), .wrst_n(rst_n_i), .w_en(ld_push_i), .w_data(ld_data_i),
        .w_full(ld_full_unused), .w_level(ld_wl),
        .rclk(io_clk_i), .rrst_n(io_rst_n_i), .r_en(ld_pop_i), .r_data(ld_data_o),
        .r_empty(ld_empty_o), .r_level(ld_rl_unused)
    );
    assign ld_idle_o = (ld_wl == '0);

    // ---- tick crossing ----
    localparam int PG_MS = 3, PG_US = 4;
    logic [31:0] us_s1, us_s2, ms_s1, ms_s2, us_r, ms_r;
    function automatic logic [31:0] g2b(input logic [31:0] g);
        logic [31:0] b;
        b = g;
        b = b ^ (b >> 1);
        b = b ^ (b >> 2);
        b = b ^ (b >> 4);
        b = b ^ (b >> 8);
        b = b ^ (b >> 16);
        return b;
    endfunction
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            us_s1 <= '0; us_s2 <= '0; ms_s1 <= '0; ms_s2 <= '0; us_r <= '0; ms_r <= '0;
        end else begin
            us_s1 <= us_gray_i; us_s2 <= us_s1; us_r <= g2b(us_s2);
            ms_s1 <= ms_gray_i; ms_s2 <= ms_s1; ms_r <= g2b(ms_s2);
        end
    end

    // ---- hart-side registers ----
    logic [31:0] evt_r, evt_en_r;
    logic [1:0]  mask_r;
    logic [31:0] up_r [0:NUP-1];
    logic [31:0] dn_r [0:NDN-1];
    logic        is_up, is_dn;

    assign is_up = off_i[9:8] == 2'b10;
    assign is_dn = off_i[9:8] == 2'b11;
    assign cmd_push  = acc_i && we_i && off_i == O_CMD;
    assign dn_push   = acc_i && we_i && is_dn;
    assign rsp_pop   = acc_i && !we_i && off_i == O_RSP;
    assign conrx_pop = acc_i && !we_i && off_i == O_CON_RX;

    always_comb begin
        rdata_o = 32'h0;
        if (is_up && off_i[$clog2(NUP)-1:0] == PG_MS[$clog2(NUP)-1:0])
            rdata_o = ms_r;
        else if (is_up && off_i[$clog2(NUP)-1:0] == PG_US[$clog2(NUP)-1:0])
            rdata_o = us_r;
        else if (is_up)
            rdata_o = up_r[off_i[$clog2(NUP)-1:0]];
        else if (is_dn)
            rdata_o = dn_r[off_i[$clog2(NDN)-1:0]];
        else case (off_i)
            O_RSP:      rdata_o = rsp_empty ? 32'h0 : rsp_head;
            O_STATUS:   rdata_o = {!rsp_empty, con_wl, 5'h0, !conrx_empty, con_full, cmd_full,
                                   3'h0, rsp_rl, 2'h0, cmd_wl};
            O_EVT:      rdata_o = evt_r;
            O_EVT_EN:   rdata_o = evt_en_r;
            O_EVT_MASK: rdata_o = {30'h0, mask_r};
            O_IOC_CTRL: rdata_o = {30'h0, loaded_i, run_i};
            O_CON_RX:   rdata_o = {!conrx_empty, 23'h0, conrx_empty ? 8'h0 : conrx_head};
            O_CON_MODE: rdata_o = {30'h0, con_mode_i};
            default:    rdata_o = 32'h0;
        endcase
    end

    // stall_o: no local access on the next clock. Always on the clock after
    // an access is taken (one bridge access in flight at a time), and while
    // a FIFO might not take one more word: pushes land a clock after the
    // access is taken, so the room counted is this clock's push and one
    // more.
    logic stall_n;
    assign stall_n = acc_now_i ||
                     (32'(cmd_wl) + 32'(cmd_push) >= 30) || (32'(con_wl) + 32'(con_push_i) >= 62) ||
                     (32'(dn_wl) + 32'(dn_push) >= 2) || (32'(ld_wl) + 32'(ld_push_i) >= 2);

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            evt_r <= 32'h0; evt_en_r <= 32'h0; mask_r <= 2'b00;
            stall_o <= 1'b0; evt_pend_o <= 1'b0;
            for (int i = 0; i < NUP; i++) up_r[i] <= 32'h0;
            for (int i = 0; i < NDN; i++) dn_r[i] <= 32'h0;
        end else begin
            stall_o <= stall_n;
            // Events: the island's set-masks and EVT_SET set bits; a store of
            // 1s to EVT clears them (a set on the same clock wins).
            evt_r <= (evt_r & ~((acc_i && we_i && off_i == O_EVT) ? wdata_i : 32'h0))
                     | ((acc_i && we_i && off_i == O_EVT_SET) ? wdata_i : 32'h0)
                     | (!evt_empty ? {16'h0, evt_head} : 32'h0);
            if (acc_i && we_i && off_i == O_EVT_EN)   evt_en_r <= wdata_i;
            if (acc_i && we_i && off_i == O_EVT_MASK) mask_r <= wdata_i[1:0];
            evt_pend_o <= |(evt_r & evt_en_r) && !mask_r[0];
            if (!upd_empty) up_r[upd_head[32 +: $clog2(NUP)]] <= upd_head[31:0];
            if (dn_push) dn_r[off_i[$clog2(NDN)-1:0]] <= wdata_i;
        end
    end

    logic unused;
    assign unused = ^{rsp_wl_unused, conrx_rl_unused, conrx_wl_unused, evt_rl_unused, evt_wl_unused,
                      upd_rl_unused, upd_wl_unused, dn_rl_unused, dn_full_unused, ld_rl_unused,
                      ld_full_unused};
endmodule
