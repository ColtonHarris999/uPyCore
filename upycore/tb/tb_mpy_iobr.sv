// mpy_iobr across its clock crossing: randomized traffic through every FIFO
// and register, at hart:io clock ratios from 1:3 to 3:1, with bursts that
// fill each FIFO and drain it again.
//
// Hart side: the bench plays mpy_soc (acc_i only while stall_o is low, like
// the skid). Island side: a model of the I/O core that pops CMD, CON, DN and
// LD at random and pushes RSP, CON_RX, EVT and UPD at random, and stops for
// long stretches so the hart side sees full FIFOs (stall_o) and the island
// side sees empty ones. Every word is checked in order at the far end; EVT
// bits and page words are checked to arrive. Each trial ends with a
// power-on reset of both sides mid-traffic (the only reset the FIFOs take:
// neither the hart's soft reset nor the I/O core's reset touches them).
//
//   +SEED=<n> +TRIALS=<n> +OPS=<n>
module tb_mpy_iobr;
    real hp = 10.0, ip = 20.0;
    logic clk = 0, io_clk = 0;
    logic rst_n = 0, io_rst_n = 0;
    initial forever #(hp / 2.0) clk = ~clk;
    initial begin #3.3; forever #(ip / 2.0) io_clk = ~io_clk; end

    logic        acc, we, stall, evt_pend, ld_push, ld_idle, con_push, acc_now;
    logic [9:0]  off;
    logic [31:0] wdata, rdata;
    logic [8:0]  con_data;
    logic [48:0] ld_data;
    logic        cmd_pop, cmd_empty, rsp_push, rsp_full, evt_push, evt_full;
    logic        con_pop, con_empty, conrx_push, conrx_full, upd_push, upd_full;
    logic        dn_pop, dn_empty, ld_pop, ld_empty;
    logic [31:0] cmd_data, rsp_data;
    logic [5:0]  cmd_level;
    logic [15:0] evt_data;
    logic [8:0]  con_q;
    logic [6:0]  con_level;
    logic [7:0]  conrx_data;
    logic [36:0] upd_data;
    logic [34:0] dn_data;
    logic [48:0] ld_q;
    // A counter in gray code on the island side, as iocore_top makes it.
    logic [31:0] us_cnt = 0, us_gray = 0, ms_gray = 0;
    always @(posedge io_clk) begin
        if ($urandom_range(0, 2) == 0) us_cnt <= us_cnt + 1;
        us_gray <= us_cnt ^ (us_cnt >> 1);
        ms_gray <= (us_cnt >> 3) ^ (us_cnt >> 4);
    end

    mpy_iobr dut (
        .clk_i(clk), .rst_n_i(rst_n), .hart_rst_n_i(rst_n), .sys_reset_o(), .wdt_toggle_i(1'b0),
        .acc_i(acc), .we_i(we), .off_i(off), .wdata_i(wdata), .rdata_o(rdata),
        .acc_now_i(acc_now), .stall_o(stall),
        .con_push_i(con_push), .con_data_i(con_data), .con_mode_i(2'd1),
        .evt_pend_o(evt_pend),
        .ld_push_i(ld_push), .ld_data_i(ld_data), .ld_idle_o(ld_idle), .run_i(1'b1), .loaded_i(1'b1),
        .io_clk_i(io_clk), .io_rst_n_i(io_rst_n), .us_gray_i(us_gray), .ms_gray_i(ms_gray),
        .cmd_pop_i(cmd_pop), .cmd_data_o(cmd_data), .cmd_empty_o(cmd_empty), .cmd_level_o(cmd_level),
        .rsp_push_i(rsp_push), .rsp_data_i(rsp_data), .rsp_full_o(rsp_full),
        .evt_push_i(evt_push), .evt_data_i(evt_data), .evt_full_o(evt_full),
        .con_pop_i(con_pop), .con_data_o(con_q), .con_empty_o(con_empty), .con_level_o(con_level),
        .conrx_push_i(conrx_push), .conrx_data_i(conrx_data), .conrx_full_o(conrx_full),
        .upd_push_i(upd_push), .upd_data_i(upd_data), .upd_full_o(upd_full),
        .dn_pop_i(dn_pop), .dn_data_o(dn_data), .dn_empty_o(dn_empty),
        .ld_pop_i(ld_pop), .ld_data_o(ld_q), .ld_empty_o(ld_empty)
    );

    int checks = 0, errors = 0;
    task automatic check(input bit ok, input string what);
        checks++;
        if (!ok) begin
            errors++;
            if (errors < 20) $display("ERROR %s at %0t", what, $time);
        end
    endtask

    // Expected streams, as queues.
    logic [31:0] q_cmd[$], q_rsp[$];
    logic [8:0]  q_con[$];
    logic [7:0]  q_conrx[$];
    logic [34:0] q_dn[$];
    logic [48:0] q_ld[$];
    logic [31:0] page_want [0:31];
    logic [31:0] evt_sent;        // bits the island raised since the hart last cleared
    // Traffic counts, through a task: Verilator 5.038 drops plain
    // increments made in the island process when the timed initial process
    // reads them (the errors count, also kept by a task, is seen).
    typedef enum int { C_CMD, C_RSP, C_CON, C_CONRX, C_DN, C_LD, C_UPD, C_EVT, C_STALL } cnt_e;
    int cnt [9];
    task automatic bump(input cnt_e c);
        cnt[c]++;
    endtask
    bit io_hold;                  // the island model stops for a while
    bit running;

    // ---- island model (io_clk) ----
    // It samples and drives on the falling edge, so the FIFOs see stable
    // pops and pushes at the rising edge.
    always @(negedge io_clk) begin
        cmd_pop = 0; rsp_push = 0; evt_push = 0; con_pop = 0; conrx_push = 0;
        upd_push = 0; dn_pop = 0; ld_pop = 0;
        // A hold ends on its own after a while.
        if (io_hold && $urandom_range(0, 199) == 0) io_hold = 0;
        if (io_rst_n && running && !io_hold) begin
            if (!cmd_empty && $urandom_range(0, 3) != 0) begin
                check(q_cmd.size() > 0 && cmd_data == q_cmd[0], "CMD order");
                if (q_cmd.size() > 0) void'(q_cmd.pop_front());
                cmd_pop = 1; bump(C_CMD);
            end
            if (!con_empty && $urandom_range(0, 1)) begin
                check(q_con.size() > 0 && con_q == q_con[0], "CON order");
                if (q_con.size() > 0) void'(q_con.pop_front());
                con_pop = 1; bump(C_CON);
            end
            if (!dn_empty) begin
                check(q_dn.size() > 0 && dn_data == q_dn[0], "DN order");
                if (q_dn.size() > 0) void'(q_dn.pop_front());
                dn_pop = 1; bump(C_DN);
            end
            if (!ld_empty && $urandom_range(0, 1)) begin
                check(q_ld.size() > 0 && ld_q == q_ld[0], "LD order");
                if (q_ld.size() > 0) void'(q_ld.pop_front());
                ld_pop = 1; bump(C_LD);
            end
            if (!rsp_full && $urandom_range(0, 2) == 0) begin
                logic [31:0] w = $urandom;
                rsp_data = w; rsp_push = 1; q_rsp.push_back(w);
            end
            if (!conrx_full && $urandom_range(0, 3) == 0) begin
                logic [7:0] b = 8'($urandom);
                conrx_data = b; conrx_push = 1; q_conrx.push_back(b);
            end
            if (!evt_full && $urandom_range(0, 15) == 0) begin
                logic [15:0] e = 16'(1 << $urandom_range(0, 15));
                evt_data = e; evt_push = 1; evt_sent |= 32'(e); bump(C_EVT);
            end
            if (!upd_full && $urandom_range(0, 7) == 0) begin
                logic [4:0] i = 5'($urandom);
                logic [31:0] v = $urandom;
                upd_data = {i, v}; upd_push = 1; page_want[i] = v; bump(C_UPD);
            end
        end
    end

    // ---- hart side ----
    task automatic access(input bit w, input logic [9:0] o, input logic [31:0] d, output logic [31:0] r);
        // Like mpy_soc: wait for a clock without stall, take the access
        // (acc_now), and present it registered on the next clock.
        while (stall) begin @(negedge clk); bump(C_STALL); end
        acc_now = 1;
        @(negedge clk);
        acc_now = 0;
        acc = 1; we = w; off = o; wdata = d;
        #0.01 r = rdata;
        @(negedge clk);
        acc = 0; we = 0;
    endtask

    task automatic hart_op();
        logic [31:0] r;
        int k = $urandom_range(0, 99);
        if (k < 30) begin
            logic [31:0] w = $urandom;
            access(1, 10'h000, w, r); q_cmd.push_back(w);
        end else if (k < 50) begin
            access(0, 10'h002, 0, r);          // STATUS
            if (r[31]) begin
                access(0, 10'h001, 0, r);
                check(q_rsp.size() > 0 && r == q_rsp[0], "RSP order");
                if (q_rsp.size() > 0) void'(q_rsp.pop_front());
                bump(C_RSP);
            end
        end else if (k < 62) begin
            logic [8:0] b = 9'($urandom);
            // A console byte: mpy_soc pushes it in place of a SIM_STDOUT store.
            while (stall) begin @(negedge clk); bump(C_STALL); end
            con_push = 1; con_data = b; q_con.push_back(b);
            @(negedge clk); con_push = 0;
        end else if (k < 70) begin
            access(0, 10'h008, 0, r);          // CON_RX
            if (r[31]) begin
                check(q_conrx.size() > 0 && r[7:0] == q_conrx[0], "CON_RX order");
                if (q_conrx.size() > 0) void'(q_conrx.pop_front());
                bump(C_CONRX);
            end else check(r == 0, "CON_RX empty reads 0");
        end else if (k < 76) begin
            logic [2:0] j = 3'($urandom);
            logic [31:0] v = $urandom;
            access(1, {7'b1100000, j}, v, r); q_dn.push_back({j, v});
            access(0, {7'b1100000, j}, 0, r);
            check(r == v, "DN reads back");
        end else if (k < 82) begin
            logic [48:0] v = {$urandom, $urandom};
            while (stall) begin @(negedge clk); bump(C_STALL); end
            ld_push = 1; ld_data = v; q_ld.push_back(v);
            @(negedge clk); ld_push = 0;
        end else if (k < 90) begin
            access(0, 10'h003, 0, r);          // EVT: bits only from what was raised
            check((r & ~evt_sent & 32'hFFFF) == 0, "EVT has only raised bits");
        end else if (k < 95) begin
            logic [31:0] v = 32'(1 << $urandom_range(16, 31));
            access(1, 10'h005, v, r);          // EVT_SET
            access(0, 10'h003, 0, r);
            check((r & v) == v, "EVT_SET sets");
            access(1, 10'h003, v, r);          // clear it again
        end else if (k < 97) begin
            logic [4:0] i = 5'($urandom);
            access(0, {5'b10000, i}, 0, r);    // a page word: some value the island sent, or 0
        end else begin
            // The tick words: a count no newer than the island's, never
            // going back, and at most a few io clocks old.
            logic [31:0] a, b;
            access(0, {5'b10000, 5'd4}, 0, a);
            access(0, {5'b10000, 5'd4}, 0, b);
            if (!(b >= a && b <= us_cnt && us_cnt - b <= 12)) $display("ticks a=%0d b=%0d cnt=%0d ip=%0f", a, b, us_cnt, ip);
            check(b >= a && b <= us_cnt && us_cnt - b <= 12, "ticks: monotonic and recent");
            access(0, {5'b10000, 5'd3}, 0, a);
            check(a <= (us_cnt >> 3) && (us_cnt >> 3) - a <= 1, "ms ticks recent");
        end
    endtask

    // Wait for the far side, then check every queue drained and every
    // event and page word arrived.
    task automatic drain();
        logic [31:0] r;
        int t;
        io_hold = 0;
        for (t = 0; t < 400 && (q_cmd.size() || q_con.size() || q_dn.size() || q_ld.size()); t++)
            @(negedge clk);
        check(q_cmd.size() == 0 && q_con.size() == 0 && q_dn.size() == 0 && q_ld.size() == 0,
              "hart-to-island FIFOs drain");
        running = 0;
        repeat (20) @(negedge io_clk);
        repeat (20) @(negedge clk);
        while (q_rsp.size()) begin
            access(0, 10'h002, 0, r);
            check(r[31], "RSP has the words pushed");
            access(0, 10'h001, 0, r);
            check(r == q_rsp[0], "RSP order (drain)");
            void'(q_rsp.pop_front()); bump(C_RSP);
        end
        while (q_conrx.size()) begin
            access(0, 10'h008, 0, r);
            check(r[31] && r[7:0] == q_conrx[0], "CON_RX order (drain)");
            void'(q_conrx.pop_front()); bump(C_CONRX);
        end
        access(0, 10'h003, 0, r);
        check((r & 32'hFFFF) == (evt_sent & 32'hFFFF), "every raised event arrived");
        for (int i = 0; i < 32; i++) begin
            access(0, {5'b10000, 5'(i)}, 0, r);
            if (i != 3 && i != 4) check(r == page_want[i], "page word arrived");
        end
        access(0, 10'h002, 0, r);
        check(r[31] == 0 && r[5:0] == 0, "STATUS empty after drain");
    endtask

    initial begin
        int seed, trials, ops;
        if (!$value$plusargs("SEED=%d", seed)) seed = 1;
        if (!$value$plusargs("TRIALS=%d", trials)) trials = 12;
        if (!$value$plusargs("OPS=%d", ops)) ops = 3000;
        void'($urandom(seed));
        acc = 0; we = 0; off = 0; wdata = 0; con_push = 0; acc_now = 0; con_data = 0; ld_push = 0; ld_data = 0;
        for (int i = 0; i < 9; i++) cnt[i] = 0;
        for (int t = 0; t < trials; t++) begin
            // Ratios from 1:3 to 3:1, plus random ones.
            real ratios [6] = '{1.0/3.0, 0.5, 1.0, 1.5, 2.0, 3.0};
            real ratio = (t < 6) ? ratios[t] : (0.34 + 2.66 * $urandom_range(0, 1000) / 1000.0);
            hp = 10.0;
            ip = 10.0 * ratio;            // io period / hart period
            // Power-on reset of both sides (mid-traffic after the first trial).
            rst_n = 0; io_rst_n = 0; running = 0; io_hold = 0;
            q_cmd.delete(); q_rsp.delete(); q_con.delete(); q_conrx.delete(); q_dn.delete(); q_ld.delete();
            evt_sent = 0;
            for (int i = 0; i < 32; i++) page_want[i] = 0;
            repeat (3) @(negedge clk);
            repeat (3) @(negedge io_clk);
            rst_n = 1; io_rst_n = 1;
            repeat (3) @(negedge clk);
            running = 1;
            for (int i = 0; i < ops; i++) begin
                // Bursts: the island stops for a while, so FIFOs fill up.
                if ($urandom_range(0, 299) == 0) io_hold = 1;
                hart_op();
            end
            drain();
            // Mid-traffic reset for the next trial: start traffic, then reset.
            running = 1;
            for (int i = 0; i < 50; i++) hart_op();
        end
        $display("traffic: cmd=%0d rsp=%0d con=%0d conrx=%0d dn=%0d ld=%0d upd=%0d evt=%0d stall_clocks=%0d",
                 cnt[C_CMD], cnt[C_RSP], cnt[C_CON], cnt[C_CONRX], cnt[C_DN], cnt[C_LD], cnt[C_UPD],
                 cnt[C_EVT], cnt[C_STALL]);
        // Every FIFO filled up at least once (stall) and carried traffic.
        check(cnt[C_STALL] > 0 && cnt[C_CMD] > 0 && cnt[C_CON] > 0 && cnt[C_DN] > 0 && cnt[C_LD] > 0 &&
              cnt[C_UPD] > 0 && cnt[C_EVT] > 0, "traffic in every FIFO, and stalls");
        if (errors == 0) $display("PASS mpy_iobr %0d checks, %0d trials", checks, trials);
        else $display("FAIL mpy_iobr %0d errors of %0d checks", errors, checks);
        $finish;
    end
endmodule
