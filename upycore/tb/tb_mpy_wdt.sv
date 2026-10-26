// WDT and reset controller exit: the watchdog's reset tick with two kicks
// (mpy_periph_model.wdt_reset_tick), LOAD locked and no stop once started,
// a wrong key ignored, the system reset holding sys_rst_n for one scrub
// pass over every SRAM word, the reset causes, the straps kept across a
// system reset with SYS_KEEP, and the id registers.
module tb_mpy_wdt;
    logic        clk = 1'b0;
    logic        por_n = 1'b0;
    logic        req = 1'b0, we = 1'b0;
    logic [11:0] off = 12'h0;
    logic [31:0] wdata = 32'h0;
    logic [31:0] w_rdata, s_rdata, rdata;
    logic        tick = 1'b0;
    logic        wdt_reset, sys_rst_n, scrub;
    logic [15:0] scrub_idx;
    logic [7:0]  strap = 8'h5A;

    localparam int SRAM_WORDS = 65536;

    assign rdata = w_rdata | s_rdata;

    mpy_wdt u_wdt (
        .clk_i(clk), .rst_n_i(sys_rst_n), .req_i(req), .we_i(we), .off_i(off), .wdata_i(wdata),
        .rdata_o(w_rdata), .tick_i(tick), .wdt_reset_o(wdt_reset)
    );
    mpy_sys #(.SRAM_WORDS(SRAM_WORDS)) u_sys (
        .clk_i(clk), .rst_n_i(por_n), .req_i(req), .we_i(we), .off_i(off), .wdata_i(wdata),
        .rdata_o(s_rdata), .strap_i(strap),
        .wdt_reset_i(wdt_reset), .sys_rst_n_o(sys_rst_n), .scrub_o(scrub), .scrub_idx_o(scrub_idx)
    );

    always #5 clk = ~clk;

    task automatic check(input bit cond, input string msg);
        if (!cond) begin
            $error("FAIL: %s", msg);
            $fatal(1);
        end
    endtask

    task automatic wr(input logic [11:0] o, input logic [31:0] d);
        @(negedge clk);
        req = 1'b1; we = 1'b1; off = o; wdata = d;
        @(negedge clk);
        req = 1'b0; we = 1'b0;
    endtask

    task automatic rd(input logic [11:0] o, output logic [31:0] d);
        @(negedge clk);
        req = 1'b1; we = 1'b0; off = o;
        #1 d = rdata;
        @(negedge clk);
        req = 1'b0;
    endtask

    // One tick; returns whether it reset. wdt_reset follows the tick's
    // clock and sys_rst_n falls on the next, with scrub_idx 0 on show.
    task automatic step(output bit fired);
        @(negedge clk);
        tick = 1'b1;
        @(negedge clk);
        tick = 1'b0;
        @(negedge clk);
        fired = !sys_rst_n;
        if (!fired) @(negedge clk);
    endtask

    // A system reset in progress: count the held clocks and the scrub order.
    task automatic wait_reset(output int held);
        int expect_idx;
        held = 0;
        expect_idx = 0;
        while (!sys_rst_n) begin
            check(scrub && scrub_idx == 16'(expect_idx), "scrub walks every word in order");
            expect_idx++;
            held++;
            @(negedge clk);
        end
        check(!scrub, "scrub ends with the reset");
    endtask

    int unsigned load, kick0, kick1, reset_at, zero_at, words;

    initial begin
        logic [31:0] v;
        bit          fired;
        int          t, held;
        if (!$value$plusargs("WDT_LOAD=%d", load)) load = 7;
        if (!$value$plusargs("WDT_KICK0=%d", kick0)) kick0 = 3;
        if (!$value$plusargs("WDT_KICK1=%d", kick1)) kick1 = 9;
        if (!$value$plusargs("WDT_RESET_AT=%d", reset_at)) reset_at = 16;
        if (!$value$plusargs("WDT_ZERO_AT=%d", zero_at)) zero_at = 1;
        if (!$value$plusargs("SRAM_WORDS=%d", words)) words = SRAM_WORDS;
        check(words == SRAM_WORDS, "model and bench agree on the SRAM size");

        repeat (3) @(posedge clk);
        por_n = 1'b1;
        @(negedge clk);
        check(sys_rst_n, "power-on releases sys_rst_n with rst_n");
        rd(12'h608, v); check(v == 32'd1, "PWRON_RESET after power-on");
        rd(12'h604, v); check(v == 32'h5A, "straps latched");
        strap = 8'h00;
        rd(12'h600, v); check(v == 32'd48_000_000, "SYS_FREQ");
        rd(12'h610, v); check(v == 32'h6F72_6501, "SYS_UID0");
        rd(12'h614, v); check(v == 32'h7570_7963, "SYS_UID1");

        // Not started: ticks do nothing.
        wr(12'h500, load);
        step(fired); check(!fired, "a stopped watchdog does not reset");
        rd(12'h50C, v); check(v == 0, "count 0 before the start");
        wr(12'h504, 32'h1);
        rd(12'h504, v); check(v == 32'h1, "started");
        rd(12'h50C, v); check(v == load, "the start loads the counter");
        wr(12'h500, 32'd1000);
        rd(12'h500, v); check(v == load, "LOAD is locked once started");
        wr(12'h504, 32'h0);
        rd(12'h504, v); check(v == 32'h1, "a started watchdog cannot be stopped");

        // Kicks before ticks kick0 + 1 and kick1 + 1; a wrong key in between.
        t = 0;
        fired = 0;
        while (!fired && t < 100) begin
            if (t == kick0 || t == kick1) wr(12'h508, 32'h6B1D_F00D);
            if (t == 5) wr(12'h508, 32'h6B1D_F00E);
            t++;
            step(fired);
        end
        check(t == reset_at, $sformatf("watchdog reset at tick %0d, model %0d", t, reset_at));
        wait_reset(held);
        check(held == SRAM_WORDS, "held for one scrub pass");
        $display("WDT reset at tick %0d, held %0d clocks", t, held);
        rd(12'h608, v); check(v == 32'd3, "WDT_RESET");
        rd(12'h604, v); check(v == 32'h5A, "the straps survive a system reset");
        rd(12'h504, v); check(v == 32'h0, "the system reset stops the watchdog");

        // LOAD 0 resets on the first tick.
        wr(12'h504, 32'h1);
        t = 0;
        fired = 0;
        while (!fired && t < 10) begin t++; step(fired); end
        check(t == zero_at, "LOAD 0 resets on the next tick");
        wait_reset(held);

        // SYS_RESET: a wrong key is ignored, k 1 is soft, k 0 is hard.
        wr(12'h60C, 32'h0B00_7ED2);
        @(negedge clk); check(sys_rst_n, "a wrong key does not reset");
        wr(12'h61C, 32'hA5A5_0001);
        wr(12'h60C, 32'h0B00_7ED1);
        check(!sys_rst_n, "SYS_RESET holds the system");
        wait_reset(held);
        rd(12'h608, v); check(v == 32'd5, "SOFT_RESET");
        rd(12'h61C, v); check(v == 32'hA5A5_0001, "SYS_KEEP survives a system reset");
        wr(12'h60C, 32'h0B00_7ED0);
        wait_reset(held);
        rd(12'h608, v); check(v == 32'd2, "HARD_RESET");
        $display("SYS causes pwron/wdt/soft/hard, straps kept, uid");
        $display("PASS: mpy wdt/reset controller");
        $finish;
    end
endmodule
