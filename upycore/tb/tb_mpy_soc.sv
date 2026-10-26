
// Runs one linked image on mpy_soc.
//
//   +IMAGE=<out>.hex +TAGS=<out>.tags.hex   flash contents (mpy_link.py)
//   +STDOUT=<path> +STDERR=<path>           console streams (default: this log)
//   +MAX_CYCLES=<n>                         give up after n cycles (default 50M)
//   +TRACE=1                                one line per executed opcode, with the cycle
//   +TIMER_STEP=<n>                         pulse timer_step every n cycles (0: never)
//   +UART_RX=<hex>                          bytes for the UART, two hex digits each,
//   +UART_RX_AT=<n> +UART_RX_GAP=<n>        strobed from cycle n, one every gap cycles
//   +UART_BAUD=<n>                          send them as 8N1 frames at n clocks/bit instead
//   +GPIO_IN=<hex>@<cycle>,...              drive gpio_in (gpio_in_en is high)
//   +UART_RX_IDLE=1                         strobe the next byte only while the core
//                                           is in machine.idle, gap cycles apart; with
//                                           +UART_BAUD only the first frame waits
//   +MAX_TICKS=<n>                          stop at pulse n+1, so tick n's work is
//                                           in: a trace pass (`MPY_TICKS`), not a halt
//   +STRAP=<hex>                            boot straps (SYS_STRAP); default 1, the
//                                           testbench drives the tick
//   +IO_TRACE=1                             one line per GPIO_OUT change and TX byte
//   +SPI_DEV=flash|loop                     a SPI flash on pads 10 (SCK), 11 (MOSI),
//                                           12 (MISO), 13 (CS, a GPIO); or MOSI looped
//                                           back to MISO
//   +I2C_DEV=1                              I2C targets on pads 14 (SCL) and 15 (SDA):
//                                           a 24C02-style EEPROM at 0x50 and a
//                                           16-byte device at 0x42 that stretches
//                                           SCL 6000 clocks after every ACK
//
// Pads: a pad the SoC drives reads back its own level; ext_low pulls a pad
// low (an open-drain target), ext_drv drives ext_val; otherwise the pad's
// pull-up reads 1. Pads that toggled report `pw=<pad>:<high>:<period>`
// from their last full period, in clocks.
//
// Before the last line the bench prints `MPY_IO gpio_out=<hex> gpio_oe=<hex>
// edges=<n> gmask=<hex> ticks=<n> tx=<hex bytes>`. gmask bit k-1 is set when
// GPIO_OUT changed while the tick count was k.
//
// The last line is `MPY_HALT code=<n> value=<hex> cycles=<n> ops=<n> gc=<n>`
// or `MPY_TIMEOUT cycles=<n> ...` (upycore/tools/mpy_build.py parses it).
module tb_mpy_soc;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #5 clk = ~clk;

    logic        con_valid, con_err;
    logic [7:0]  con_byte;
    logic        halted;
    logic [3:0]  halt_code;
    logic [31:0] halt_value, cycles, ops, gc_coll, gc_free;
    logic        trace;
    logic [31:0] trace_pc;
    logic [7:0]  trace_op;
    logic [6:0]  trace_sp;

    logic        timer_step = 1'b0;
    logic        uart_rx_stb = 1'b0;
    logic [7:0]  uart_rx_byte = 8'h0;
    logic        uart_tx_stb;
    logic [7:0]  uart_tx_byte;
    logic        uart_rxd = 1'b1;
    logic        uart_txd;
    logic [31:0] gpio_out, gpio_oe, gpio_pu, gpio_pd;
    logic [31:0] gpio_in = 32'h0;
    logic        gpio_in_en = 1'b0;
    logic [7:0]  strap;
    logic        core_idle;
    logic [15:0] pad_out, pad_oe, pad_in;
    logic [15:0] ext_low;
    logic [15:0] ext_drv;
    logic [15:0] ext_val;
    always_comb begin
        for (int i = 0; i < 16; i++)
            pad_in[i] = ext_low[i] ? 1'b0 :
                        (pad_oe[i] ? pad_out[i] : (ext_drv[i] ? ext_val[i] : 1'b1));
    end

    mpy_soc u_soc (
        .clk_i(clk), .rst_n_i(rst_n),
        .con_valid_o(con_valid), .con_err_o(con_err), .con_byte_o(con_byte),
        .halted_o(halted), .halt_code_o(halt_code), .halt_value_o(halt_value),
        .cycles_o(cycles), .ops_o(ops), .gc_collections_o(gc_coll), .gc_free_o(gc_free),
        .trace_o(trace), .trace_pc_o(trace_pc), .trace_op_o(trace_op), .trace_sp_o(trace_sp),
        .timer_step_i(timer_step),
        .uart_rx_stb_i(uart_rx_stb), .uart_rx_byte_i(uart_rx_byte),
        .uart_tx_stb_o(uart_tx_stb), .uart_tx_byte_o(uart_tx_byte),
        .uart_rxd_i(uart_rxd), .uart_txd_o(uart_txd),
        .gpio_out_o(gpio_out), .gpio_oe_o(gpio_oe), .gpio_pu_o(gpio_pu), .gpio_pd_o(gpio_pd),
        .gpio_in_i(gpio_in), .gpio_in_en_i(gpio_in_en),
        .sim_irq_i(1'b0), .strap_i(strap), .idle_o(core_idle),
        .pad_out_o(pad_out), .pad_oe_o(pad_oe), .pad_in_i(pad_in)
    );

    // SPI devices on the pads.
    string       spi_dev;
    logic        flash_miso;
    initial if (!$value$plusargs("SPI_DEV=%s", spi_dev)) spi_dev = "";
    tb_spi_flash u_flash (.cs_n(pad_in[13] | spi_dev != "flash"), .sck(pad_in[10]), .mosi(pad_in[11]),
                          .miso(flash_miso));
    always_comb begin
        ext_drv = 16'h0;
        ext_val = 16'h0;
        ext_drv[12] = (spi_dev == "flash") || (spi_dev == "loop");
        ext_val[12] = (spi_dev == "flash") ? flash_miso : pad_in[11];
    end

    // I2C targets on pads 14 (SCL) and 15 (SDA).
    bit          i2c_dev;
    logic        e_scl_low, e_sda_low, s_scl_low, s_sda_low;
    initial i2c_dev = $test$plusargs("I2C_DEV");
    tb_i2c_target #(.ADDR(7'h50)) u_eeprom (.clk(clk), .scl(pad_in[14]), .sda(pad_in[15]),
                                            .scl_low(e_scl_low), .sda_low(e_sda_low));
    tb_i2c_target #(.ADDR(7'h42), .BYTES(16), .STRETCH(6000), .INIT(8'hA0)) u_slow (
        .clk(clk), .scl(pad_in[14]), .sda(pad_in[15]), .scl_low(s_scl_low), .sda_low(s_sda_low));
    always_comb begin
        ext_low = 16'h0;
        ext_low[14] = i2c_dev && (e_scl_low || s_scl_low);
        ext_low[15] = i2c_dev && (e_sda_low || s_sda_low);
    end

    // Pulse widths on the pads: last rise, last fall, and the last full period.
    longint pw_rise [0:15];
    longint pw_high [0:15];
    longint pw_per [0:15];
    int     pw_n [0:15];
    logic [15:0] pad_prev = 16'h0;
    initial for (int i = 0; i < 16; i++) begin pw_rise[i] = 0; pw_high[i] = 0; pw_per[i] = 0; pw_n[i] = 0; end
    always @(posedge clk) begin
        for (int i = 0; i < 16; i++) begin
            if (pad_in[i] && !pad_prev[i]) begin
                if (pw_n[i] > 0) pw_per[i] = cyc_n - pw_rise[i];
                pw_rise[i] = cyc_n;
                pw_n[i]++;
            end else if (!pad_in[i] && pad_prev[i] && pw_n[i] > 0)
                pw_high[i] = cyc_n - pw_rise[i];
        end
        pad_prev <= pad_in;
    end

    // ---- peripheral stimulus and the IO summary ----
    int          timer_period;
    bit          io_trace;
    logic [7:0]  rx_bytes [$];
    int          rx_at, rx_gap, rx_baud;
    bit          rx_idle;
    longint      max_ticks, ticks_n;
    logic [31:0] gmask;
    logic [7:0]  tx_log [$];
    int          gpio_edges;
    logic [31:0] gpio_prev;
    longint      cyc_n;

    function automatic int hexval(input byte c);
        if (c >= "0" && c <= "9") return c - "0";
        if (c >= "a" && c <= "f") return c - "a" + 10;
        if (c >= "A" && c <= "F") return c - "A" + 10;
        return -1;
    endfunction

    initial begin
        string text;
        if (!$value$plusargs("TIMER_STEP=%d", timer_period)) timer_period = 0;
        io_trace = $test$plusargs("IO_TRACE");
        if (!$value$plusargs("UART_RX_AT=%d", rx_at)) rx_at = 1000;
        if (!$value$plusargs("UART_RX_GAP=%d", rx_gap)) rx_gap = 1000;
        if (!$value$plusargs("UART_BAUD=%d", rx_baud)) rx_baud = 0;
        rx_idle = $test$plusargs("UART_RX_IDLE");
        if (!$value$plusargs("MAX_TICKS=%d", max_ticks)) max_ticks = 0;
        if (!$value$plusargs("STRAP=%h", strap)) strap = 8'h01;
        ticks_n = 0;
        gmask = 32'h0;
        if ($value$plusargs("UART_RX=%s", text))
            for (int i = 0; i + 1 < text.len(); i += 2)
                rx_bytes.push_back(8'(hexval(text[i]) * 16 + hexval(text[i + 1])));
        gpio_edges = 0;
        gpio_prev = 32'h0;
        cyc_n = 0;
    end

    always @(posedge clk) if (rst_n) cyc_n <= cyc_n + 1;

    always @(negedge clk) begin
        timer_step <= (timer_period > 0) && rst_n && (cyc_n % timer_period == timer_period - 1);
    end
    always @(posedge clk) if (rst_n && timer_step) ticks_n <= ticks_n + 1;

    // UART RX stimulus: strobes in byte mode, or 8N1 frames on uart_rxd.
    initial begin
        @(posedge rst_n);
        repeat (rx_at) @(posedge clk);
        foreach (rx_bytes[k]) begin
            // Serial frames run back to back: only the first waits for idle.
            if (rx_idle && (rx_baud == 0 || k == 0))
                while (!core_idle) @(posedge clk);
            if (rx_baud == 0) begin
                @(negedge clk);
                uart_rx_stb = 1'b1;
                uart_rx_byte = rx_bytes[k];
                @(negedge clk);
                uart_rx_stb = 1'b0;
                repeat (rx_gap - 1) @(posedge clk);
            end else begin
                logic [9:0] bits;
                bits = {1'b1, rx_bytes[k], 1'b0};
                for (int b = 0; b < 10; b++) begin
                    uart_rxd = bits[b];
                    repeat (rx_baud) @(posedge clk);
                end
                repeat (rx_gap) @(posedge clk);
            end
        end
    end

    // GPIO input schedule: +GPIO_IN=<hex>@<cycle>,<hex>@<cycle>,...
    initial begin
        string text;
        int vals [$];
        int ats [$];
        if ($value$plusargs("GPIO_IN=%s", text)) begin
            int v = 0, a = 0;
            bit in_at = 0;
            for (int i = 0; i <= text.len(); i++) begin
                byte c = (i < text.len()) ? text[i] : ",";
                if (c == "@") in_at = 1;
                else if (c == ",") begin vals.push_back(v); ats.push_back(a); v = 0; a = 0; in_at = 0; end
                else if (in_at) a = a * 10 + (c - "0");
                else v = v * 16 + hexval(c);
            end
            gpio_in_en = 1'b1;
            @(posedge rst_n);
            foreach (vals[k]) begin
                while (cyc_n < ats[k]) @(posedge clk);
                gpio_in = 32'(vals[k]);
            end
        end
    end

    always @(posedge clk) begin
        if (rst_n && uart_tx_stb) begin
            tx_log.push_back(uart_tx_byte);
            if (io_trace) $display("UART_TX cycle=%0d byte=%02x", cyc_n, uart_tx_byte);
        end
        if (rst_n && gpio_out != gpio_prev) begin
            gpio_edges++;
            if (ticks_n >= 1 && ticks_n <= 32 && !(max_ticks > 0 && ticks_n > max_ticks))
                gmask[ticks_n - 1] <= 1'b1;
            if (io_trace) $display("GPIO cycle=%0d out=%08x", cyc_n, gpio_out);
            gpio_prev <= gpio_out;
        end
    end

    task automatic io_summary();
        string txs;
        string pws;
        txs = "";
        foreach (tx_log[k]) txs = {txs, $sformatf("%02x", tx_log[k])};
        pws = "";
        for (int i = 0; i < 16; i++)
            if (pw_n[i] >= 3)
                pws = {pws, (pws.len() > 0) ? "," : "", $sformatf("%0d:%0d:%0d", i, pw_high[i], pw_per[i])};
        $display("MPY_IO gpio_out=%08x gpio_oe=%08x edges=%0d gmask=%08x ticks=%0d tx=%s pw=%s",
                 gpio_out, gpio_oe, gpio_edges, gmask,
                 (max_ticks > 0 && ticks_n > max_ticks) ? max_ticks : ticks_n, txs, pws);
    endtask

    int    fd_out, fd_err;
    longint max_cycles;
    bit    do_trace;
    longint n;

    initial begin
        string path;
        int t;
        fd_out = 0; fd_err = 0;
        if ($value$plusargs("STDOUT=%s", path)) fd_out = $fopen(path, "wb");
        if ($value$plusargs("STDERR=%s", path)) fd_err = $fopen(path, "wb");
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles)) max_cycles = 50_000_000;
        do_trace = $value$plusargs("TRACE=%d", t) && t != 0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
    end

    always @(posedge clk) begin
        if (rst_n && con_valid) begin
            if (con_err) begin
                if (fd_err != 0) $fwrite(fd_err, "%c", con_byte);
                else $write("%c", con_byte);
            end else begin
                if (fd_out != 0) $fwrite(fd_out, "%c", con_byte);
                else $write("%c", con_byte);
            end
        end
        if (rst_n && do_trace && trace)
            $display("TRACE pc=%08x op=%02x sp=%0d c=%0d", trace_pc, trace_op, trace_sp, cyc_n);
    end

    initial begin
        n = 0;
        @(posedge rst_n);
        while (!halted && n < max_cycles && !(max_ticks > 0 && ticks_n > max_ticks)) begin
            @(posedge clk);
            n++;
        end
        // let the last console byte land
        repeat (4) @(posedge clk);
        if (fd_out != 0) $fclose(fd_out);
        if (fd_err != 0) $fclose(fd_err);
        io_summary();
        if (!halted && max_ticks > 0 && ticks_n > max_ticks)
            $display("MPY_TICKS ticks=%0d cycles=%0d ops=%0d gc=%0d", max_ticks, cycles, ops, gc_coll);
        else if (halted)
            $display("MPY_HALT code=%0d value=%08x cycles=%0d ops=%0d gc=%0d free=%0d",
                     halt_code, halt_value, cycles, ops, gc_coll, gc_free);
        else
            $display("MPY_TIMEOUT cycles=%0d ops=%0d gc=%0d pc=%08x op=%02x",
                     cycles, ops, gc_coll, trace_pc, trace_op);
        $finish;
    end
endmodule
