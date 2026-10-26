// Mailbox and coprocessor exit: the coprocessor firmware (+COPROC) on CVE2
// at 48 MHz, the hart's side of the mailbox driven from this bench on an
// unrelated clock. ECHO words round-trip in order with the hart stalling
// its reads, so both FIFOs fill and drain across the crossing; COPY moves
// a word the bench wrote into the shared SRAM; KBD_TEST rings the KBD
// doorbell once; a store to a full TX FIFO sets overrun. The word count and
// sum come from mpy_periph_model.mbox_plusargs.
module tb_mpy_mbox;
    logic hclk = 1'b0, cclk = 1'b0;
    logic por_n = 1'b0;
    // The synchronizer starts high so the coprocessor's reset falls after
    // time 0: CVE2 gates its own clock in reset, so its flops reset only on
    // that edge.
    logic [1:0] csync = 2'b11;
    logic crst_n;

    always #5 hclk = ~hclk;             // the hart's clock
    always #10.417 cclk = ~cclk;        // 48 MHz

    always_ff @(posedge cclk or negedge por_n)
        if (!por_n) csync <= 2'b00; else csync <= {csync[0], 1'b1};
    assign crst_n = csync[1];

    logic        req = 1'b0, we = 1'b0;
    logic [11:0] off = 12'h0;
    logic [31:0] wdata = 32'h0, rdata;
    logic        mbox_set, kbd_set;
    logic        c_pop, c_empty, c_push, c_full, c_kbd;
    logic [31:0] c_data, c_wdata;
    logic [4:0]  c_level, c_wlevel;
    logic        sh_en;
    logic [3:0]  sh_be;
    logic [9:0]  sh_addr;
    logic [31:0] sh_wdata, sh_rdata, a_rdata;
    logic        a_en = 1'b0, a_we = 1'b0;
    logic [9:0]  a_addr = 10'h0;
    logic [31:0] a_wdata = 32'h0;
    wire         usb_dp, usb_dn;
    logic        usb_pu;

    // Host pull-downs: with no host the bus reads SE0.
    assign (weak0, weak1) usb_dp = usb_pu ? 1'b1 : 1'b0;
    assign (weak0, weak1) usb_dn = 1'b0;

    mpy_mbox u_mbox (
        .clk_i(hclk), .rst_n_i(por_n), .por_n_i(por_n),
        .req_i(req), .we_i(we), .off_i(off), .wdata_i(wdata), .rdata_o(rdata),
        .con_stb_i(1'b0), .con_byte_i(8'h0), .con_ready_o(),
        .mbox_set_o(mbox_set), .kbd_set_o(kbd_set),
        .cclk_i(cclk), .crst_n_i(crst_n),
        .c_pop_i(c_pop), .c_data_o(c_data), .c_empty_o(c_empty), .c_level_o(c_level),
        .c_push_i(c_push), .c_wdata_i(c_wdata), .c_full_o(c_full), .c_wlevel_o(c_wlevel),
        .c_kbd_toggle_i(c_kbd)
    );

    mpy_shared_ram u_shared (
        .a_clk(hclk), .a_en(a_en), .a_we(a_we), .a_addr(a_addr), .a_wdata(a_wdata), .a_rdata(a_rdata),
        .b_clk(cclk), .b_en(sh_en), .b_be(sh_be), .b_addr(sh_addr), .b_wdata(sh_wdata), .b_rdata(sh_rdata)
    );

    coproc_top u_coproc (
        .cclk_i(cclk), .rst_n_i(crst_n),
        .mb_pop_o(c_pop), .mb_data_i(c_data), .mb_empty_i(c_empty), .mb_level_i(c_level),
        .mb_push_o(c_push), .mb_wdata_o(c_wdata), .mb_full_i(c_full), .mb_wlevel_i(c_wlevel),
        .mb_kbd_toggle_o(c_kbd),
        .sh_en_o(sh_en), .sh_be_o(sh_be), .sh_addr_o(sh_addr), .sh_wdata_o(sh_wdata),
        .sh_rdata_i(sh_rdata),
        .usb_dp_io(usb_dp), .usb_dn_io(usb_dn), .usb_pu_o(usb_pu)
    );

    task automatic check(input bit cond, input string msg);
        if (!cond) begin
            $error("FAIL: %s", msg);
            $fatal(1);
        end
    endtask

    task automatic wr(input logic [11:0] o, input logic [31:0] d);
        @(negedge hclk);
        req = 1'b1; we = 1'b1; off = o; wdata = d;
        @(negedge hclk);
        req = 1'b0; we = 1'b0;
    endtask

    task automatic rd(input logic [11:0] o, output logic [31:0] d);
        @(negedge hclk);
        req = 1'b1; we = 1'b0; off = o;
        #1 d = rdata;
        @(negedge hclk);
        req = 1'b0;
    endtask

    task automatic sh_write(input int idx, input logic [31:0] d);
        @(negedge hclk);
        a_en = 1'b1; a_we = 1'b1; a_addr = 10'(idx); a_wdata = d;
        @(negedge hclk);
        a_en = 1'b0; a_we = 1'b0;
    endtask

    task automatic sh_read(input int idx, output logic [31:0] d);
        @(negedge hclk);
        a_en = 1'b1; a_we = 1'b0; a_addr = 10'(idx);
        @(negedge hclk);
        a_en = 1'b0;
        d = a_rdata;
    endtask

    // Wait up to n hart clocks for a word, then pop it.
    task automatic recv(input int n, output logic [31:0] w, output bit ok);
        logic [31:0] st;
        ok = 0;
        for (int k = 0; k < n && !ok; k++) begin
            rd(12'h108, st);
            if (st[17]) begin rd(12'h104, w); ok = 1; end
        end
    endtask

    int kbd_count = 0, set_count = 0;
    always @(posedge hclk) begin
        if (kbd_set) kbd_count++;
        if (mbox_set) set_count++;
    end

    int unsigned n_words, want_sum;
    longint      t0, t1;

    initial begin
        logic [31:0] st, w;
        bit ok;
        int sent, got, stall;
        int unsigned sum;
        if (!$value$plusargs("MBOX_N=%d", n_words)) n_words = 256;
        if (!$value$plusargs("MBOX_SUM=%d", want_sum)) want_sum = 0;
        repeat (4) @(posedge hclk);
        por_n = 1'b1;

        // The firmware's first words: the USB state (not configured).
        recv(20000, w, ok);
        check(ok && w == 32'h0180_0000, $sformatf("STATE first, got %08x", w));

        // ECHO: send while there is room, read back in bursts with stalls.
        t0 = $time;
        sent = 0; got = 0; sum = 0; stall = 0;
        while (got < n_words) begin
            rd(12'h108, st);
            if (sent < n_words && !st[16]) begin
                wr(12'h100, {8'h02, 24'((sent * 40503 + 7) & 24'hFFFFFF)});
                sent++;
            end
            // Every 64 words, stop reading for a while: the up FIFO fills,
            // the coprocessor holds its reply, and the down FIFO fills too.
            if ((got % 64) == 63 && stall < 400) begin stall++; continue; end
            if (st[17]) begin
                rd(12'h104, w);
                check(w[31:24] == 8'h02 && w[23:0] == 24'((got * 40503 + 7) & 24'hFFFFFF),
                      $sformatf("echo word %0d is %08x", got, w));
                sum += w[23:0];
                got++;
                stall = 0;
            end
        end
        t1 = $time;
        check(want_sum == 0 || sum == want_sum, $sformatf("echo sum %0d, model %0d", sum, want_sum));
        check(set_count >= 1, "MBOX source set as words arrived");
        $display("ECHO %0d words in order, %0d ns", n_words, t1 - t0);

        // COPY: the coprocessor moves shared word 5 to word 700.
        sh_write(5, 32'hC0FF_EE11);
        wr(12'h100, {8'h03, 4'h0, 10'd700, 10'd5});
        recv(20000, w, ok);
        check(ok && w == {8'h03, 4'h0, 10'd700, 10'd5}, "COPY answered");
        sh_read(700, w);
        check(w == 32'hC0FF_EE11, $sformatf("shared word 700 is %08x", w));
        $display("SHARED copy 5 -> 700 by the coprocessor");

        // KBD_TEST: one doorbell.
        check(kbd_count == 0, "no KBD before the test");
        wr(12'h100, 32'h0102_0000);
        repeat (4000) @(posedge hclk);
        check(kbd_count == 1, $sformatf("KBD rang %0d times", kbd_count));
        $display("KBD doorbell");

        // Overrun: with the coprocessor's reads paused by a stream of
        // pending replies, 40 stores into 16 slots overflow.
        for (int k = 0; k < 40; k++) wr(12'h100, {8'h02, 24'(k)});
        rd(12'h108, st);
        check(st[18], "overrun after storing to a full TX FIFO");
        wr(12'h108, 32'h1 << 18);
        rd(12'h108, st);
        check(!st[18], "write 1 clears overrun");
        $display("PASS: mpy mailbox echo/shared/kbd/overrun");
        $finish;
    end

    initial begin
        #50ms;
        $error("FAIL: timeout");
        $fatal(1);
    end
endmodule
