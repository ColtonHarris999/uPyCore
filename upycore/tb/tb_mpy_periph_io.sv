// Revision 1 peripheral exit: UART FIFOs and 8N1 framing, the tick
// prescaler, GPIO direction and per-pin edge status, and the interrupt
// character. Expected counts come from
// `upycore/tools/mpy_periph_model.py --io-plusargs`.
module tb_mpy_periph_io;
    import mpy_mmio_pkg::*;

    localparam int DEPTH = 16;

    logic        clk = 1'b0;
    logic        rst_n = 1'b0;
    logic        req = 1'b0;
    logic        we = 1'b0;
    logic [31:0] addr_bus = 32'h0;
    logic [31:0] wdata = 32'h0;
    logic [31:0] rdata;
    logic        ack, fault;
    logic        timer_step = 1'b0;
    logic        uart_rx_stb = 1'b0;
    logic [7:0]  uart_rx_byte = 8'h0;
    logic        uart_tx_stb;
    logic [7:0]  uart_tx_byte;
    logic        rxd = 1'b1;
    logic        txd;
    logic [31:0] gpio_out, gpio_oe, gpio_pu, gpio_pd;
    logic [31:0] gpio_in = 32'h0;
    logic        gpio_in_en = 1'b0;
    logic        kbd_set = 1'b0;
    logic        mbox_set = 1'b0;
    logic        fire, fire_hard, fire_sched, heap_locked, sched_locked, irq_active;
    logic [2:0]  fire_src;
    logic [31:0] fire_fn, fire_arg;
    logic        sched_ok, sched_full;
    logic        bnd = 1'b0, jmp = 1'b0, done = 1'b0;
    logic [3:0]  fire_fn_tag, fire_arg_tag;
    logic        kbd_raise;
    logic        hwe = 1'b0;
    logic [2:0]  hidx = 3'h0;
    logic [35:0] hfn = 36'h0, harg = 36'h0;
    logic        spush = 1'b0;
    logic [35:0] sfn = 36'h0, sarg = 36'h0;
    logic        mir_dirty, mir_clr = 1'b0;
    logic [3:0]  mir_sel = 4'h0;
    logic [35:0] mir_fn, mir_arg;
    logic [31:0] saved_pc, saved_fp, saved_sp, saved_exc;

    int fifo_depth, baud, burst, echo_n, echo_sum, echo_ovr, echo17_n, echo17_sum, echo17_ovr;
    int presc, presc_clocks, presc_ticks;
    int stall [0:1];
    int kept [0:1];
    int drop [0:1];

    mpy_periph #(.UART_FIFO_DEPTH(DEPTH)) dut (
        .clk_i(clk), .rst_n_i(rst_n),
        .req_i(req), .we_i(we), .addr_i(addr_bus), .wdata_i(wdata),
        .rdata_o(rdata), .ack_o(ack), .fault_o(fault),
        .timer_step_i(timer_step),
        .uart_rx_stb_i(uart_rx_stb), .uart_rx_byte_i(uart_rx_byte),
        .uart_tx_stb_o(uart_tx_stb), .uart_tx_byte_o(uart_tx_byte),
        .uart_rxd_i(rxd), .uart_txd_o(txd),
        .gpio_out_o(gpio_out), .gpio_oe_o(gpio_oe), .gpio_pu_o(gpio_pu), .gpio_pd_o(gpio_pd),
        .gpio_in_i(gpio_in), .gpio_in_en_i(gpio_in_en),
        .soft_set_i(1'b0), .gc_req_i(1'b0), .sim_set_i(1'b0),
        .kbd_set_i(kbd_set), .mbox_set_i(mbox_set),
        .bc_boundary_i(bnd), .jump_i(jmp), .done_i(done),
        .fire_o(fire), .fire_hard_o(fire_hard), .fire_sched_o(fire_sched),
        .fire_src_o(fire_src), .fire_fn_o(fire_fn), .fire_arg_o(fire_arg),
        .fire_fn_tag_o(fire_fn_tag), .fire_arg_tag_o(fire_arg_tag), .kbd_raise_o(kbd_raise),
        .heap_locked_o(heap_locked), .sched_locked_o(sched_locked), .irq_active_o(irq_active),
        .handler_we_i(hwe), .handler_idx_i(hidx), .handler_fn_i(hfn[31:0]), .handler_arg_i(harg[31:0]),
        .handler_fn_tag_i(hfn[35:32]), .handler_arg_tag_i(harg[35:32]),
        .sched_push_i(spush), .sched_fn_i(sfn[31:0]), .sched_arg_i(sarg[31:0]),
        .sched_fn_tag_i(sfn[35:32]), .sched_arg_tag_i(sarg[35:32]),
        .sched_ok_o(sched_ok), .sched_full_o(sched_full),
        .mirror_dirty_o(mir_dirty), .mirror_sel_i(mir_sel), .mirror_clr_i(mir_clr),
        .mirror_fn_o(mir_fn), .mirror_arg_o(mir_arg),
        .pc_i(32'h0), .fp_i(32'h0), .sp_i(32'h0), .exc_sp_i(32'h0),
        .saved_pc_o(saved_pc), .saved_fp_o(saved_fp), .saved_sp_o(saved_sp),
        .saved_exc_sp_o(saved_exc)
    );

    always #5 clk = ~clk;

    task automatic check(input bit cond, input string msg);
        if (!cond) begin
            $error("FAIL: %s", msg);
            $fatal(1);
        end
    endtask

    task automatic do_reset();
        req = 1'b0; we = 1'b0; uart_rx_stb = 1'b0; rxd = 1'b1; gpio_in_en = 1'b0;
        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        @(negedge clk);
    endtask

    task automatic bus_write(input logic [11:0] off, input logic [31:0] data);
        @(negedge clk);
        req = 1'b1; we = 1'b1; addr_bus = mpy_mmio_addr(off); wdata = data;
        #1 check(ack && !fault, "store acked");
        @(posedge clk);
        @(negedge clk);
        req = 1'b0; we = 1'b0;
    endtask

    task automatic bus_read(input logic [11:0] off, output logic [31:0] data);
        @(negedge clk);
        req = 1'b1; we = 1'b0; addr_bus = mpy_mmio_addr(off);
        #1 check(ack && !fault, "load acked");
        data = rdata;
        @(posedge clk);
        @(negedge clk);
        req = 1'b0;
    endtask

    task automatic push_rx(input logic [7:0] b);
        @(negedge clk);
        uart_rx_stb = 1'b1; uart_rx_byte = b;
        @(posedge clk);
        @(negedge clk);
        uart_rx_stb = 1'b0;
    endtask

    // Pop until empty; sum and count the bytes, and note bit 30.
    task automatic drain(output int n, output int sum, output int ovr);
        logic [31:0] v;
        n = 0; sum = 0; ovr = 0;
        forever begin
            bus_read(MPY_UART_RX, v);
            if (v[30]) ovr = 1;
            if (!v[31]) break;
            n++;
            sum += v[7:0];
        end
    endtask

    // One 8N1 frame on rxd, baud clocks per bit.
    task automatic send_frame(input logic [7:0] b);
        logic [9:0] bits;
        bits = {1'b1, b, 1'b0};
        for (int i = 0; i < 10; i++) begin
            rxd = bits[i];
            repeat (baud) @(posedge clk);
        end
    endtask

    task automatic check_fifo_echo();
        logic [31:0] v;
        int n, sum, ovr, n2, sum2, ovr2;
        do_reset();
        push_rx(8'h41);
        bus_read(MPY_UART_RX, v);
        check(v[31] && v[7:0] == 8'h41 && !v[30], "0x41 echoed");
        push_rx(8'h42);
        bus_read(MPY_UART_RX, v);
        check(v[31] && v[7:0] == 8'h42, "0x42 echoed");
        push_rx(8'h43);
        push_rx(8'h44);
        bus_read(MPY_UART_STATUS, v);
        check(v[7:0] == 8'd2, "two bytes buffered");
        drain(n, sum, ovr);
        check(2 + n == echo_n && 8'h41 + 8'h42 + sum == echo_sum && ovr == echo_ovr,
              "0x43 and 0x44 stay buffered and come back in order");
        // 17 unread bytes: the 17th overruns, the first 16 stay.
        push_rx(8'h41);
        bus_read(MPY_UART_RX, v);
        push_rx(8'h42);
        bus_read(MPY_UART_RX, v);
        for (int i = 0; i < 17; i++)
            push_rx(8'h43 + 8'(i));
        bus_read(MPY_UART_STATUS, v);
        check(v[17] && v[7:0] == 8'(DEPTH), "FIFO full at depth");
        drain(n2, sum2, ovr2);
        check(2 + n2 == echo17_n && 8'h41 + 8'h42 + sum2 == echo17_sum && ovr2 == echo17_ovr,
              "17th unread byte sets overrun and is dropped");
        $display("FIFO echo=%0d bytes overrun=%0d; 17 unread: %0d kept, overrun=%0d",
                 2 + n, ovr, n2, ovr2);
    endtask

    task automatic check_status_bits();
        logic [31:0] v;
        do_reset();
        push_rx(8'h11);
        bus_read(MPY_IRQ_STATUS, v);
        check(v[MPY_SRC_UART], "each accepted byte sets the UART source");
        bus_write(MPY_UART_KBD, 32'h100 | 32'h03);
        bus_write(MPY_IRQ_STATUS, 32'hFF);
        push_rx(8'h03);
        bus_read(MPY_IRQ_STATUS, v);
        check(v[MPY_SRC_KBD] && !v[MPY_SRC_UART], "the interrupt character sets KBD only");
        bus_read(MPY_UART_STATUS, v);
        check(v[7:0] == 8'd1, "the interrupt character is not queued");
        bus_write(MPY_UART_KBD, 32'h03);
        push_rx(8'h03);
        bus_read(MPY_UART_STATUS, v);
        check(v[7:0] == 8'd2, "disabled, the character is data");
        bus_write(MPY_IRQ_STATUS, 32'hFF);
        @(negedge clk); kbd_set = 1'b1; mbox_set = 1'b1;
        @(negedge clk); kbd_set = 1'b0; mbox_set = 1'b0;
        bus_read(MPY_IRQ_STATUS, v);
        check(v[MPY_SRC_KBD] && v[MPY_SRC_MBOX], "KBD and MBOX pulses");
    endtask

    task automatic check_serial();
        logic [31:0] v;
        logic [7:0] got [$];
        logic [7:0] want [$];
        int n, sum, ovr;
        do_reset();
        bus_write(MPY_UART_BAUD, 32'(baud));
        // RX: two frames, then a framing error.
        send_frame(8'hA5);
        send_frame(8'h3C);
        repeat (2 * baud) @(posedge clk);
        bus_read(MPY_UART_RX, v);
        check(v[31] && v[7:0] == 8'hA5, "serial RX byte 0");
        bus_read(MPY_UART_RX, v);
        check(v[31] && v[7:0] == 8'h3C, "serial RX byte 1");
        for (int i = 0; i < 9; i++) begin
            rxd = (i == 0) ? 1'b0 : 1'b1;
            repeat (baud) @(posedge clk);
        end
        rxd = 1'b0;
        repeat (baud) @(posedge clk);
        rxd = 1'b1;
        repeat (3 * baud) @(posedge clk);
        bus_read(MPY_UART_RX, v);
        check(!v[31] && v[29], "a low stop bit is a framing error");
        bus_write(MPY_UART_RX, 32'h1 << 29);
        bus_read(MPY_UART_RX, v);
        check(!v[29], "writing bit 29 clears it");
        // TX: three bytes through the FIFO, decoded from txd.
        want = '{8'h55, 8'h00, 8'hF1};
        fork
            begin
                for (int k = 0; k < 3; k++) begin
                    logic [7:0] b;
                    @(negedge txd);
                    repeat (baud / 2) @(posedge clk);
                    check(!txd, "TX start bit");
                    for (int i = 0; i < 8; i++) begin
                        repeat (baud) @(posedge clk);
                        b[i] = txd;
                    end
                    repeat (baud) @(posedge clk);
                    check(txd, "TX stop bit");
                    got.push_back(b);
                end
            end
            begin
                for (int k = 0; k < 3; k++)
                    bus_write(MPY_UART_TX, 32'(want[k]));
                bus_read(MPY_UART_STATUS, v);
                check(v[16], "TX busy while frames are queued");
            end
        join
        check(got.size() == 3 && got[0] == want[0] && got[1] == want[1] && got[2] == want[2],
              "serial TX bytes");
        repeat (2 * baud) @(posedge clk);
        bus_read(MPY_UART_STATUS, v);
        check(!v[16] && v[15:8] == 8'h0, "TX idle");
        $display("SERIAL baud=%0d rx=a5,3c tx=55,00,f1 framing=1", baud);
    endtask

    // A burst at the line rate while the reader is stalled. Byte k is k,
    // so the first value that does not match its position is the first
    // dropped byte.
    task automatic check_burst(input int which);
        logic [31:0] v;
        int n, first_drop;
        bit sent;
        do_reset();
        bus_write(MPY_UART_BAUD, 32'(baud));
        sent = 1'b0;
        n = 0;
        first_drop = -1;
        fork
            begin
                for (int k = 0; k < burst; k++)
                    send_frame(8'(k));
                repeat (2 * baud) @(posedge clk);
                sent = 1'b1;
            end
            begin
                repeat (stall[which]) @(posedge clk);
                forever begin
                    bus_read(MPY_UART_RX, v);
                    if (v[31]) begin
                        if (first_drop < 0 && v[7:0] != 8'(n)) first_drop = n;
                        n++;
                    end else if (sent) break;
                end
            end
        join
        check(n == kept[which], "burst bytes kept");
        check(v[30] == (drop[which] >= 0), "overrun sets exactly when the model says");
        check(first_drop == drop[which], "first dropped byte");
        $display("BURST stall=%0d clocks kept=%0d first_drop=%0d overrun=%0d",
                 stall[which], n, first_drop, v[30]);
    endtask

    task automatic check_tick();
        logic [31:0] v;
        do_reset();
        bus_write(MPY_TIMER_PRESC, 32'(presc));
        repeat (presc_clocks - 1) @(posedge clk);
        @(negedge clk);
        bus_write(MPY_TIMER_PRESC, 32'h0);
        bus_read(MPY_TICKS, v);
        check(v == 32'(presc_ticks), "prescaler ticks");
        @(negedge clk); timer_step = 1'b1;
        @(negedge clk); timer_step = 1'b0;
        bus_read(MPY_TICKS, v);
        check(v == 32'(presc_ticks + 1), "timer_step still ticks");
        bus_write(MPY_TIMER_COUNT, 32'd3);
        bus_write(MPY_TIMER_PRESC, 32'd2);
        repeat (6) @(posedge clk);
        @(negedge clk);
        bus_read(MPY_IRQ_STATUS, v);
        check(v[MPY_SRC_TIMER], "prescaled ticks reach the compare");
        $display("TICKS presc=%0d clocks=%0d ticks=%0d", presc, presc_clocks, presc_ticks);
    endtask

    task automatic check_gpio();
        logic [31:0] v;
        do_reset();
        bus_write(MPY_GPIO_OE, 32'h0000_0005);
        bus_write(MPY_GPIO_PU, 32'h0000_0002);
        bus_write(MPY_GPIO_PD, 32'h0000_0008);
        check(gpio_oe == 32'h5 && gpio_pu == 32'h2 && gpio_pd == 32'h8, "direction and pull pins");
        bus_read(MPY_GPIO_OE, v);
        check(v == 32'h5, "GPIO_OE round trip");
        // Pin 0 rising, pin 1 falling.
        bus_write(MPY_GPIO_EDGE, 32'h0000_0009);
        bus_write(MPY_GPIO_IN, 32'h0000_0002);
        bus_write(MPY_GPIO_IN, 32'h0000_0001);
        bus_read(MPY_GPIO_STATUS, v);
        check(v[15:0] == 16'h3, "per-pin edge status");
        bus_write(MPY_GPIO_STATUS, 32'h1);
        bus_read(MPY_GPIO_STATUS, v);
        check(v[15:0] == 16'h2, "GPIO_STATUS write-1-to-clear");
        // The pin sampler, through the synchronizer.
        bus_write(MPY_GPIO_STATUS, 32'hFFFF);
        gpio_in = 32'h1;
        gpio_in_en = 1'b1;
        repeat (4) @(posedge clk);
        bus_read(MPY_GPIO_IN, v);
        check(v == 32'h1, "sampled pin level");
        gpio_in = 32'h0;
        repeat (4) @(posedge clk);
        gpio_in = 32'h1;
        repeat (4) @(posedge clk);
        bus_read(MPY_GPIO_STATUS, v);
        check(v[0] && !v[1], "a sampled rising edge on pin 0");
        bus_read(MPY_IRQ_STATUS, v);
        check(v[MPY_SRC_GPIO], "sampled edge sets the GPIO source");
        gpio_in_en = 1'b0;
        $display("GPIO oe=5 pu=2 pd=8 status per pin");
    endtask

    // Tags travel with handler words and ring slots; the mirror port shows
    // occupied slots and the empty word elsewhere; KBD raises at a jump.
    task automatic check_mirror_kbd();
        logic [31:0] v;
        do_reset();
        check(!mir_dirty, "mirror clean after reset");
        @(negedge clk);
        hwe = 1'b1; hidx = 3'(MPY_SRC_TIMER); hfn = {4'hE, 32'h2000_9000}; harg = {4'h1, 32'h2000_A000};
        @(negedge clk);
        hwe = 1'b0;
        check(mir_dirty, "a handler write dirties the mirror");
        mir_sel = 4'd8 + 4'(MPY_SRC_TIMER);
        #1 check(mir_fn == {4'hE, 32'h2000_9000} && mir_arg == {4'h1, 32'h2000_A000},
                 "handler word and tags on the mirror port");
        @(negedge clk); mir_clr = 1'b1;
        @(negedge clk); mir_clr = 1'b0;
        check(!mir_dirty, "mirror_clr");
        @(negedge clk);
        spush = 1'b1; sfn = {4'h8, 32'h2000_B000}; sarg = {4'h9, 32'h2000_C000};
        @(negedge clk);
        spush = 1'b0;
        check(sched_ok && mir_dirty, "a push dirties the mirror");
        mir_sel = 4'd0;
        #1 check(mir_fn == {4'h8, 32'h2000_B000} && mir_arg == {4'h9, 32'h2000_C000}, "ring slot 0 mirrored");
        mir_sel = 4'd1;
        #1 check(mir_fn == 36'h0 && mir_arg == 36'h0, "an empty slot is the empty word");
        @(negedge clk); mir_clr = 1'b1;
        @(negedge clk); mir_clr = 1'b0;
        // KBD at a jump wins over the queued callback; the ring stays.
        bus_write(MPY_IRQ_ENABLE, 32'h1 << MPY_SRC_KBD);
        @(negedge clk); kbd_set = 1'b1;
        @(negedge clk); kbd_set = 1'b0;
        @(negedge clk); bnd = 1'b1; jmp = 1'b0;
        #1 check(!kbd_raise, "KBD waits for a jump");
        @(negedge clk); bnd = 1'b1; jmp = 1'b1;
        #1 check(kbd_raise, "KBD raises at a jump");
        @(negedge clk); bnd = 1'b0; jmp = 1'b0;
        check(!fire && !mir_dirty, "no callback on the KBD jump");
        bus_read(MPY_IRQ_STATUS, v);
        check(!v[MPY_SRC_KBD], "the raise clears KBD");
        @(negedge clk); bnd = 1'b1; jmp = 1'b1;
        @(negedge clk); bnd = 1'b0; jmp = 1'b0;
        check(fire && fire_sched && fire_fn_tag == 4'h8 && fire_arg_tag == 4'h9 && mir_dirty,
              "the next jump pops with tags");
        // KBD interrupts a running soft callback, not a hard one.
        @(negedge clk); kbd_set = 1'b1;
        @(negedge clk); kbd_set = 1'b0; bnd = 1'b1; jmp = 1'b1;
        #1 check(kbd_raise, "KBD inside a soft callback");
        @(negedge clk); bnd = 1'b0; jmp = 1'b0; done = 1'b1;
        @(negedge clk); done = 1'b0;
        $display("MIRROR tags and empty slots; KBD at the jump");
    endtask

    initial begin
        if (!$value$plusargs("FIFO_DEPTH=%d", fifo_depth)) $fatal(1, "missing FIFO_DEPTH");
        if (!$value$plusargs("BAUD=%d", baud)) $fatal(1, "missing BAUD");
        if (!$value$plusargs("BURST=%d", burst)) $fatal(1, "missing BURST");
        if (!$value$plusargs("ECHO_N=%d", echo_n)) $fatal(1, "missing ECHO_N");
        if (!$value$plusargs("ECHO_SUM=%d", echo_sum)) $fatal(1, "missing ECHO_SUM");
        if (!$value$plusargs("ECHO_OVR=%d", echo_ovr)) $fatal(1, "missing ECHO_OVR");
        if (!$value$plusargs("ECHO17_N=%d", echo17_n)) $fatal(1, "missing ECHO17_N");
        if (!$value$plusargs("ECHO17_SUM=%d", echo17_sum)) $fatal(1, "missing ECHO17_SUM");
        if (!$value$plusargs("ECHO17_OVR=%d", echo17_ovr)) $fatal(1, "missing ECHO17_OVR");
        if (!$value$plusargs("PRESC=%d", presc)) $fatal(1, "missing PRESC");
        if (!$value$plusargs("PRESC_CLOCKS=%d", presc_clocks)) $fatal(1, "missing PRESC_CLOCKS");
        if (!$value$plusargs("PRESC_TICKS=%d", presc_ticks)) $fatal(1, "missing PRESC_TICKS");
        if (!$value$plusargs("STALL0=%d", stall[0])) $fatal(1, "missing STALL0");
        if (!$value$plusargs("KEPT0=%d", kept[0])) $fatal(1, "missing KEPT0");
        if (!$value$plusargs("DROP0=%d", drop[0])) $fatal(1, "missing DROP0");
        if (!$value$plusargs("STALL1=%d", stall[1])) $fatal(1, "missing STALL1");
        if (!$value$plusargs("KEPT1=%d", kept[1])) $fatal(1, "missing KEPT1");
        if (!$value$plusargs("DROP1=%d", drop[1])) $fatal(1, "missing DROP1");
        check(fifo_depth == DEPTH, "model and bench FIFO depth");

        check_fifo_echo();
        check_status_bits();
        check_serial();
        check_burst(0);
        check_burst(1);
        check_tick();
        check_gpio();
        check_mirror_kbd();
        $display("PASS: mpy periph io fifo/serial/burst/tick/gpio/mirror/kbd");
        $finish;
    end
endmodule
