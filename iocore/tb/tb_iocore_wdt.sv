// Watchdog exit (iocore_wdt): the expiry tick with two kicks
// (iocore_periph_model.wdt_reset_tick), LOAD locked once started, no stop
// through CTRL, a wrong key ignored, the expiry pulsing wdt_reset_o for one
// clock and stopping the watchdog, LOAD 0 expiring on the first tick, a
// restart after an expiry, and the stop key. Adapted from the epic
// branch's tb_mpy_wdt.sv; the reset controller it also covered is the
// bridge's here (tb_mpy_iobr, the system area's reset tests).
module tb_iocore_wdt;
    logic        clk = 1'b0;
    logic        rst_n = 1'b0;
    logic        req = 1'b0, we = 1'b0;
    logic [11:0] off = 12'h0;
    logic [31:0] wdata = 32'h0;
    logic [31:0] rdata;
    logic        tick = 1'b0;
    logic        wdt_reset;
    int          pulses = 0;

    iocore_wdt u_wdt (
        .clk_i(clk), .rst_n_i(rst_n), .req_i(req), .we_i(we), .off_i(off), .wdata_i(wdata),
        .rdata_o(rdata), .tick_i(tick), .wdt_reset_o(wdt_reset)
    );

    always #5 clk = ~clk;
    always @(posedge clk) if (wdt_reset) pulses++;

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

    // One tick; returns whether it expired (one wdt_reset_o pulse).
    task automatic step(output bit fired);
        int n0;
        n0 = pulses;
        @(negedge clk);
        tick = 1'b1;
        @(negedge clk);
        tick = 1'b0;
        repeat (3) @(negedge clk);
        check(pulses - n0 <= 1, "one pulse an expiry");
        fired = pulses != n0;
    endtask

    int unsigned load, kick0, kick1, reset_at, zero_at;

    initial begin
        logic [31:0] v;
        bit          fired;
        int          t;
        if (!$value$plusargs("WDT_LOAD=%d", load)) load = 7;
        if (!$value$plusargs("WDT_KICK0=%d", kick0)) kick0 = 3;
        if (!$value$plusargs("WDT_KICK1=%d", kick1)) kick1 = 9;
        if (!$value$plusargs("WDT_RESET_AT=%d", reset_at)) reset_at = 16;
        if (!$value$plusargs("WDT_ZERO_AT=%d", zero_at)) zero_at = 1;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        // Not started: ticks do nothing.
        wr(12'h500, load);
        step(fired); check(!fired, "a stopped watchdog does not expire");
        rd(12'h50C, v); check(v == 0, "count 0 before the start");
        wr(12'h504, 32'h1);
        rd(12'h504, v); check(v == 32'h1, "started");
        rd(12'h50C, v); check(v == load, "the start loads the counter");
        wr(12'h500, 32'd1000);
        rd(12'h500, v); check(v == load, "LOAD is locked once started");
        wr(12'h504, 32'h0);
        rd(12'h504, v); check(v == 32'h1, "CTRL does not stop it");

        // Kicks before ticks kick0 + 1 and kick1 + 1; a wrong key in between.
        t = 0;
        fired = 0;
        while (!fired && t < 100) begin
            if (t == kick0 || t == kick1) wr(12'h508, 32'h6B1D_F00D);
            if (t == 5) wr(12'h508, 32'h6B1D_F00E);
            t++;
            step(fired);
        end
        check(t == reset_at, $sformatf("expiry at tick %0d, model %0d", t, reset_at));
        rd(12'h504, v); check(v == 32'h0, "the expiry stops the watchdog");
        rd(12'h50C, v); check(v == 32'h0, "count 0 after the expiry");
        for (int k = 0; k < 20; k++) begin
            step(fired); check(!fired, "no second expiry once stopped");
        end
        $display("WDT expiry at tick %0d, then stopped", t);

        // LOAD 0 expires on the first tick (LOAD is writable again).
        wr(12'h500, 32'h0);
        wr(12'h504, 32'h1);
        t = 0;
        fired = 0;
        while (!fired && t < 10) begin t++; step(fired); end
        check(t == zero_at, "LOAD 0 expires on the next tick");

        // The stop key; a wrong stop key does nothing.
        wr(12'h500, 32'd3);
        wr(12'h504, 32'h1);
        step(fired); check(!fired, "count 3, one tick");
        wr(12'h508, 32'h5709_DEAE);
        rd(12'h504, v); check(v == 32'h1, "a wrong stop key does nothing");
        wr(12'h508, 32'h5709_DEAD);
        rd(12'h504, v); check(v == 32'h0, "the stop key stops it");
        for (int k = 0; k < 10; k++) begin
            step(fired); check(!fired, "stopped by the key, no expiry");
        end
        check(pulses == 2, "two expiries in all");
        $display("PASS: iocore wdt expiry/stop/lock/keys");
        $finish;
    end
endmodule
