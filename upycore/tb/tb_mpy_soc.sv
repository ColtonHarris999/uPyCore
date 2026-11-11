
// Runs one linked image on mpy_soc.
//
//   +IMAGE=<out>.hex +TAGS=<out>.tags.hex   image contents (mpy_link.py); mpy_boot
//                                           streams them into the image SRAM
//   +NAND=<out>.nand.hex                    boot over SPI from the NAND model instead
//                                           (mpy_nand.py writes the file)
//   +STDOUT=<path> +STDERR=<path>           console streams (default: this log)
//   +MAX_CYCLES=<n>                         give up after n cycles (default 50M)
//   +TRACE=1                                one line per executed opcode
//   +IOC_CODE=<hex> +IOC_DATA=<hex>         the I/O core's firmware: mpy_boot's simulation
//                                           stream appends the IOCB section
//   +IO_CLK_NS=<ns>                         io_clk period (default 20: 50 MHz; the hart's is 10)
//   +CONSOLE=sim|uart|usb                   the console strap (default sim)
//   +IOC_LOG=<path>                         the I/O core's SYS DEBUG bytes
//   +UART_OUT=<path>                        bytes the UART0 line model decodes
//   +UART_IN=<string> +UART_IN_US=<n>       bytes the line model sends, n µs after boot
//                                           (\n, \r, \t, \\ and \xHH are escapes)
//   +UART_BPS=<n>                           the line model's baud rate (default 115200)
//   +UART_SCRIPT=<path>                     a host session on the UART (the REPL tests): one
//                                           step a line, "send <s>", "expect <s>" (wait until
//                                           the line model has decoded <s> after the last
//                                           match), "wait <us>", "#" comments; <s> takes the
//                                           +UART_IN escapes. The run ends with
//                                           MPY_SESSION_END once the last step is done and
//                                           the UART has been quiet for 2 ms
//   +GPIO_LOOP=1                            wire pad i to pad i^8 (pins 0-7 to 8-15)
//   +SPI_FLASH=1                            an SPI NOR flash (tb_spi_flash) on pads 10 SCK,
//                                           11 MOSI, 12 MISO, 13 CS
//   +I2C_TARGET=1                           a 24C02-style I2C target at 0x50 (tb_i2c_target) on
//                                           pads 14 SCL, 15 SDA, with the bus pull-ups
//   +MEAS_FILE=<path>                       measurement events, one a line, times in ps
//                                           (iocore/tools/io_measure.py): "pad <i> <t> <v>" for
//                                           each change of a driven pad, "edge <t>" for each
//                                           rising edge +PULSE drives, "hit <t>" each time the
//                                           core runs the opcode at +MEAS_PC=<hex>, "rx <t>" for
//                                           each byte the UART line model decodes, "evt <t>" each
//                                           time the bridge raises evt_pend to the core
//   +PULSE=<pin>,<start us>,<period us>,<n> the bench drives pad <pin>: n periods, high for the
//                                           first half of each, from <start> µs after boot
//   +UART_IN_PATTERN=<n>                    with +UART_IN_US: n bytes 'a'..'z' repeating, back to back
//   +USB_SCRIPT=<path>                      attach the USB host model (iocore/tb/tb_usb_host.sv)
//                                           and run its script; with +CONSOLE=usb the bytes it
//                                           reads are the program's stdout. The run ends with
//                                           MPY_SESSION_END when the script finishes, or
//                                           MPY_USB_FAIL <why>. +USB_DEBUG traces transactions
//   +USB_CLK_NS=<ns>                        usb_clk period (default 20.833: 48 MHz)
//
// Board I/O runs end with summary lines before the last line (hw_tests.py
// compares them with a test's .io golden): `MPY_IO gpio<i> edges=<n>
// ms=<intervals>` for each output pad that changed (intervals between
// changes, rounded to the millisecond), and `MPY_IO uart="<bytes>"` for
// the bytes the UART line model decoded (unless they were the console).
// With the uart console strap, the line model's bytes are the program's
// stdout (+STDOUT); after the halt the bench waits for the UART to go quiet.
//
// The last line is `MPY_BOOT_ERROR`, `MPY_HALT code=<n> value=<hex> cycles=<n> ops=<n> gc=<n>`
// or `MPY_TIMEOUT cycles=<n> ...` (upycore/tools/mpy_build.py parses it).
module tb_mpy_soc #(parameter int SHORTLIST_MAX=16, parameter int SHORTLIST_MODE=2);
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
    logic        nand_sck, nand_cs_n, nand_mosi, nand_miso;
    logic        boot_done, boot_err;

    // The I/O island's clock, independent of the hart's.
    real io_clk_ns = 20.0;
    logic io_clk = 1'b0;
    initial begin
        real r;
        if ($value$plusargs("IO_CLK_NS=%f", r)) io_clk_ns = r;
        // The I/O core reads its clock from SYS FREQ (iocore_top: +IO_CLK_HZ).
        // Start a fraction of a period off the hart's clock.
        #(io_clk_ns * 0.37);
        forever #(io_clk_ns / 2.0) io_clk = ~io_clk;
    end
    // USB: its own 48 MHz clock, the host's 15k pull-downs on D+ and D-,
    // and the device's 1.5k pull-up on D+ (usb_pu).
    real usb_clk_ns = 20.8333;
    logic usb_clk = 1'b0;
    initial begin
        real r;
        if ($value$plusargs("USB_CLK_NS=%f", r)) usb_clk_ns = r;
        #(usb_clk_ns * 0.61);
        forever #(usb_clk_ns / 2.0) usb_clk = ~usb_clk;
    end
    wire  usb_dp, usb_dn;
    logic usb_pu;
    assign (weak0, weak1) usb_dp = usb_pu ? 1'b1 : 1'b0;
    assign (weak0, weak1) usb_dn = 1'b0;
    tb_usb_host u_host (.dp(usb_dp), .dn(usb_dn));
    logic [1:0] console_sel = 2'd0;
    initial begin
        string c;
        if ($value$plusargs("CONSOLE=%s", c))
            console_sel = (c == "uart") ? 2'd1 : (c == "usb") ? 2'd2 : 2'd0;
    end
    logic uart0_rxd, uart0_txd, ioc_dbg_valid;
    logic [15:0] gpio_out, gpio_oe, gpio_pu, gpio_pd, gpio_in;
    // Pads: a pad the chip drives shows its output; else a bench device
    // driving it; else its pull (a pull-up, the chip's or the I2C bus's,
    // reads 1), else 0. With +GPIO_LOOP pads i and i^8 are one net.
    bit gpio_loop, spi_on, i2c_on;
    initial begin
        gpio_loop = $test$plusargs("GPIO_LOOP");
        spi_on = $test$plusargs("SPI_FLASH");
        i2c_on = $test$plusargs("I2C_TARGET");
    end
    logic spi_miso, i2c_scl_low, i2c_sda_low;
    tb_spi_flash u_flash (.cs_n(!spi_on || gpio_in[13]), .sck(spi_on && gpio_in[10]),
                          .mosi(gpio_in[11]), .miso(spi_miso));
    tb_i2c_target u_i2c (.clk(clk), .scl(gpio_in[14]), .sda(gpio_in[15]),
                         .scl_low(i2c_scl_low), .sda_low(i2c_sda_low));
    // +PULSE: the bench drives one pad.
    int  pulse_pin = -1;
    logic pulse_level = 1'b0;
    always_comb begin
        for (int i = 0; i < 16; i++) begin
            int j = i ^ 8;
            if (gpio_oe[i]) gpio_in[i] = gpio_out[i];
            else if (i == pulse_pin) gpio_in[i] = pulse_level;
            else if (gpio_loop && gpio_oe[j]) gpio_in[i] = gpio_out[j];
            else if (spi_on && i == 12 && !gpio_in[13]) gpio_in[i] = spi_miso;
            else if (i2c_on && i == 14) gpio_in[i] = !i2c_scl_low;
            else if (i2c_on && i == 15) gpio_in[i] = !i2c_sda_low;
            else gpio_in[i] = gpio_pu[i] || (gpio_loop && gpio_pu[j]);
        end
    end
    // The ADC converter: channel c answers (273 * c + 100) & 0xFFF.
    logic adc_start, adc_done;
    logic [3:0] adc_chan;
    logic [11:0] adc_code;
    tb_adc_model u_adc (.clk(io_clk), .start(adc_start), .chan(adc_chan), .done(adc_done), .code(adc_code));
    logic term_rx_valid;
    logic [7:0] term_rx_byte;
    tb_uart_line u_term (.line_i(uart0_txd), .line_o(uart0_rxd),
                         .rx_valid_o(term_rx_valid), .rx_byte_o(term_rx_byte));

    tb_spi_nand u_nand (.sck(nand_sck), .cs_n(nand_cs_n), .mosi(nand_mosi), .miso(nand_miso));

    mpy_soc #(.SHORTLIST_MAX(SHORTLIST_MAX), .SHORTLIST_MODE(SHORTLIST_MODE)) u_soc (
        .clk_i(clk), .rst_n_i(rst_n),
        .con_valid_o(con_valid), .con_err_o(con_err), .con_byte_o(con_byte),
        .halted_o(halted), .halt_code_o(halt_code), .halt_value_o(halt_value),
        .cycles_o(cycles), .ops_o(ops), .gc_collections_o(gc_coll), .gc_free_o(gc_free),
        .trace_o(trace), .trace_pc_o(trace_pc), .trace_op_o(trace_op), .trace_sp_o(trace_sp),
        .nand_sck_o(nand_sck), .nand_cs_n_o(nand_cs_n), .nand_mosi_o(nand_mosi),
        .nand_miso_i(nand_miso), .boot_done_o(boot_done), .boot_err_o(boot_err),
        .io_clk_i(io_clk), .console_sel_i(console_sel),
        .uart0_rxd_i(uart0_rxd), .uart0_txd_o(uart0_txd),
        .gpio_o(gpio_out), .gpio_oe_o(gpio_oe), .gpio_pu_o(gpio_pu), .gpio_pd_o(gpio_pd), .gpio_i(gpio_in),
        .adc_start_o(adc_start), .adc_chan_o(adc_chan), .adc_done_i(adc_done), .adc_code_i(adc_code),
        .usb_clk_i(usb_clk), .usb_dp_io(usb_dp), .usb_dn_io(usb_dn), .usb_pu_o(usb_pu),
        .ioc_dbg_valid_o(ioc_dbg_valid), .ioc_dbg_byte_o(ioc_dbg_byte)
    );

    // Measurement events (+MEAS_FILE).
    int fd_meas = 0;
    logic [31:0] meas_pc = 32'hFFFF_FFFF;
    initial begin
        string path, arg;
        int pin, start_us, period_us, count;
        if ($value$plusargs("MEAS_FILE=%s", path)) fd_meas = $fopen(path, "w");
        if (!$value$plusargs("MEAS_PC=%h", meas_pc)) meas_pc = 32'hFFFF_FFFF;
        if ($value$plusargs("PULSE=%s", arg)) begin
            void'($sscanf(arg, "%d,%d,%d,%d", pin, start_us, period_us, count));
            pulse_pin = pin;
            wait (boot_done);
            #(start_us * 1us);
            for (int k = 0; k < count; k++) begin
                pulse_level = 1'b1;
                if (fd_meas != 0) $fwrite(fd_meas, "edge %0d\n", longint'($realtime * 1000.0));
                #(period_us * 0.5us);
                pulse_level = 1'b0;
                #(period_us * 0.5us);
            end
        end
    end
    always @(posedge clk) if (fd_meas != 0 && trace && trace_pc == meas_pc)
        $fwrite(fd_meas, "hit %0d\n", longint'($realtime * 1000.0));
    always @(term_rx_valid) if (fd_meas != 0 && rst_n)
        $fwrite(fd_meas, "rx %0d\n", longint'($realtime * 1000.0));
    always @(posedge u_soc.io_evt_pend) if (fd_meas != 0)
        $fwrite(fd_meas, "evt %0d\n", longint'($realtime * 1000.0));

    // GPIO trace: the times each driven pad changed.
    realtime gpio_t [16][$];
    logic [15:0] gpio_prev = 16'h0;
    always @(gpio_out or gpio_oe) begin
        for (int i = 0; i < 16; i++) begin
            logic v = gpio_oe[i] ? gpio_out[i] : 1'b0;
            if (v != gpio_prev[i] && rst_n && boot_done) begin
                gpio_t[i].push_back($realtime);
                if (fd_meas != 0) $fwrite(fd_meas, "pad %0d %0d %0d\n", i, longint'($realtime * 1000.0), v);
            end
            gpio_prev[i] = v;
        end
    end
    task automatic io_summary();
        string line, x;
        for (int i = 0; i < 16; i++) begin
            if (gpio_t[i].size() == 0) continue;
            line = $sformatf("MPY_IO gpio%0d edges=%0d ms=", i, gpio_t[i].size());
            for (int k = 1; k < gpio_t[i].size(); k++) begin
                // A real-to-int cast rounds to the nearest.
                x = $sformatf("%0d", longint'((gpio_t[i][k] - gpio_t[i][k-1]) / 1.0e6));
                line = {line, (k > 1) ? "," : "", x};
            end
            $display("%s", line);
        end
        if (console_sel != 2'd1 && u_term.q.size() > 0) begin
            line = "MPY_IO uart=\"";
            foreach (u_term.q[k]) begin
                byte c = u_term.q[k];
                if (c == "\n") line = {line, "\\n"};
                else if (c == "\r") line = {line, "\\r"};
                else if (c == "\"" || c == "\\") line = {line, "\\", string'(c)};
                else if (c >= 32 && c < 127) line = {line, string'(c)};
                else line = {line, $sformatf("\\x%02x", c)};
            end
            $display("%s\"", line);
        end
        // The USB host: configured, bytes the device accepted, bytes read,
        // suspends the host made.
        if (u_host.active)
            $display("MPY_IO usb configured=%0d tx=%0d rx=%0d suspends=%0d",
                     u_host.configured, u_host.tx_total, u_host.rx_n, u_host.suspends);
    endtask

    // A plusarg string with C-style escapes, as bytes.
    function automatic void unescape(input string s, ref byte q[$]);
        int i = 0;
        while (i < s.len()) begin
            if (s[i] == "\\" && i + 1 < s.len()) begin
                byte c = s[i + 1];
                i += 2;
                if (c == "n") q.push_back(8'h0A);
                else if (c == "r") q.push_back(8'h0D);
                else if (c == "t") q.push_back(8'h09);
                else if (c == "x" && i + 1 < s.len()) begin
                    int v;
                    void'($sscanf(s.substr(i, i + 1), "%h", v));
                    q.push_back(byte'(v));
                    i += 2;
                end else q.push_back(c);
            end else begin
                q.push_back(s[i]);
                i++;
            end
        end
    endfunction

    int fd_ioc = 0;
    always @(posedge io_clk) if (ioc_dbg_valid && fd_ioc != 0) begin
        $fwrite(fd_ioc, "%c", ioc_dbg_byte);
        $fflush(fd_ioc);
    end
    initial begin
        string path, s;
        int baud, at_us;
        if ($value$plusargs("IOC_LOG=%s", path)) fd_ioc = $fopen(path, "wb");
        if (!$value$plusargs("UART_BPS=%d", baud)) baud = 115200;
        u_term.set_bit_ns(1.0e9 / baud);
        if ($value$plusargs("UART_OUT=%s", path)) u_term.fd = $fopen(path, "wb");
        else if (!$test$plusargs("CONSOLE=uart")) u_term.fd = -1;
        if ($value$plusargs("UART_IN=%s", s) || $test$plusargs("UART_IN_PATTERN=")) begin
            byte q[$];
            int npat;
            if (!$value$plusargs("UART_IN_US=%d", at_us)) at_us = 100;
            if ($value$plusargs("UART_IN_PATTERN=%d", npat))
                for (int k = 0; k < npat; k++) q.push_back(byte'(8'h61 + k % 26));
            else unescape(s, q);
            wait (boot_done);
            #(at_us * 1us);
            foreach (q[i]) u_term.send(q[i]);
        end
    end

    // +UART_SCRIPT: the host side of a console session.
    bit script_on = 0, script_done = 0;
    int script_step = 0;
    initial begin
        string path, ln, cmd, arg;
        int fd, pos, from, sp, us;
        if ($value$plusargs("UART_SCRIPT=%s", path)) begin
            script_on = 1;
            fd = $fopen(path, "r");
            if (fd == 0) begin
                $display("MPY_SESSION_FAIL cannot open %s", path);
                $finish;
            end
            pos = 0;
            wait (boot_done);
            while ($fgets(ln, fd) > 0) begin
                while (ln.len() > 0 && (ln[ln.len() - 1] == 8'h0A || ln[ln.len() - 1] == 8'h0D))
                    ln = ln.substr(0, ln.len() - 2);
                script_step++;
                if (ln.len() == 0 || ln[0] == "#") continue;
                if ($test$plusargs("SCRIPT_LOG")) begin
                    $display("MPY_SESSION step %0d at %0t: %s", script_step, $time, ln);
                    $fflush();
                end
                sp = 0;
                while (sp < ln.len() && ln[sp] != " ") sp++;
                cmd = ln.substr(0, sp - 1);
                arg = (sp + 1 < ln.len()) ? ln.substr(sp + 1, ln.len() - 1) : "";
                // Block variables in an initial block are static: clear them.
                if (cmd == "send") begin
                    byte q[$];
                    q.delete();
                    unescape(arg, q);
                    foreach (q[i]) u_term.send(q[i]);
                end else if (cmd == "expect") begin
                    byte q[$];
                    q.delete();
                    unescape(arg, q);
                    from = pos;
                    forever begin
                        int found;
                        found = -1;
                        for (int st = from; st + q.size() <= u_term.q.size(); st++) begin
                            bit ok;
                            ok = 1;
                            for (int j = 0; j < q.size(); j++)
                                if (u_term.q[st + j] != q[j]) begin ok = 0; break; end
                            if (ok) begin found = st; break; end
                        end
                        if (found >= 0) begin
                            pos = found + q.size();
                            break;
                        end
                        if (u_term.q.size() - q.size() + 1 > from) from = u_term.q.size() - q.size() + 1;
                        @(u_term.rx_valid_o);
                    end
                end else if (cmd == "wait") begin
                    void'($sscanf(arg, "%d", us));
                    #(us * 1us);
                end else begin
                    $display("MPY_SESSION_FAIL step %0d: %s", script_step, ln);
                    $finish;
                end
            end
            $fclose(fd);
            begin
                realtime quiet;
                quiet = $realtime;
                for (int k = 0; k < 200000; k++) begin
                    #(1us);
                    if (uart0_txd == 1'b0) quiet = $realtime;
                    if ($realtime - quiet > 2.0e6) break;
                end
            end
            script_done = 1;
        end
    end

`ifdef MPY_PROFILE
    `include "upycore/tb/mpy_profile.svh"
`endif

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
        // The UART console: the line model's bytes are the program's stdout
        // (set here, where fd_out is opened).
        if ($value$plusargs("CONSOLE=%s", path) && path == "uart") u_term.fd = (fd_out != 0) ? fd_out : 0;
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles)) max_cycles = 50_000_000;
        do_trace = $value$plusargs("TRACE=%d", t) && t != 0;
`ifdef MPY_SAIF
        // Switching activity of the core for power analysis: +SAIF=<path>,
        // in a build made with --trace-saif -DMPY_SAIF (see synth/hammer).
        if ($value$plusargs("SAIF=%s", path)) begin
            $dumpfile(path);
            $dumpvars(0, u_soc.u_core);
        end
        // The I/O island instead (iocore/tools/io_measure.py power):
        // +SAIF_ISLAND=<path>, counting from +SAIF_START_US µs after boot.
        else if ($value$plusargs("SAIF_ISLAND=%s", path)) begin
            int start_us;
            if (!$value$plusargs("SAIF_START_US=%d", start_us)) start_us = 0;
            fork begin
                wait (boot_done);
                #(start_us * 1us);
                $dumpfile(path);
                $dumpvars(0, u_soc.u_ioc);
                if (fd_meas != 0) $fwrite(fd_meas, "saif %0d\n", longint'($realtime * 1000.0));
            end join_none
        end
`endif
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
            $display("TRACE pc=%08x op=%02x sp=%0d", trace_pc, trace_op, trace_sp);
    end

    // Cycles from reset until the core starts (data SRAM clear, image load).
    longint boot_cycles = 0;
    always @(posedge clk) if (rst_n && !boot_done) boot_cycles++;

    initial begin
        n = 0;
        @(posedge rst_n);
        while (!halted && !boot_err && !script_done && !u_host.done && !u_host.failed && n < max_cycles) begin
            @(posedge clk);
            n++;
        end
        // let the last console byte land
        repeat (4) @(posedge clk);
        // A UART console drains after the halt: wait until CON is empty and
        // the line has been idle for 2 ms (at most 200 ms).
        if (console_sel == 2'd1 && halted) begin
            realtime quiet;
            quiet = $realtime;
            for (int k = 0; k < 200000; k++) begin
                #(1us);
                if (uart0_txd == 1'b0 || !u_soc.u_iobr.u_con.r_empty) quiet = $realtime;
                if ($realtime - quiet > 2.0e6) break;
            end
        end
        // A USB console drains after the halt too: until the host's script
        // has finished, or CON is empty and 2 ms pass (at most 200 ms).
        if (console_sel == 2'd2 && halted) begin
            realtime quiet;
            quiet = $realtime;
            for (int k = 0; k < 200000 && !u_host.done && !u_host.failed; k++) begin
                #(1us);
                if (!u_soc.u_iobr.u_con.r_empty || !u_host.active) quiet = $realtime;
                if (!u_host.active && $realtime - quiet > 2.0e6) break;
                if (u_host.active && u_host.configured && $realtime - quiet > 2.0e6
                    && u_host.txq.size() == 0) break;
            end
        end
        io_summary();
        // The USB console: what the host read from CDC IN is stdout.
        if (console_sel == 2'd2)
            for (int k = 0; k < u_host.rx_n; k++) begin
                if (fd_out != 0) $fwrite(fd_out, "%c", u_host.rxmem[k % 65536]);
                else $write("%c", u_host.rxmem[k % 65536]);
            end
        if (u_host.failed) begin
            $display("MPY_USB_FAIL %s", u_host.fail_msg);
            if (fd_err != 0) $fwrite(fd_err, "USB host: %s\n", u_host.fail_msg);
        end
        if (fd_out != 0) $fclose(fd_out);
        if (fd_meas != 0) $fclose(fd_meas);
        if (fd_err != 0) $fclose(fd_err);
        if (script_on && !script_done)
            $display("MPY_SESSION_STUCK step=%0d", script_step);
        if (boot_err)
            $display("MPY_BOOT_ERROR cycles=%0d", n);
        else if (halted)
            $display("MPY_HALT code=%0d value=%08x cycles=%0d ops=%0d gc=%0d free=%0d boot=%0d",
                     halt_code, halt_value, cycles, ops, gc_coll, gc_free, boot_cycles);
        else if (script_done || (u_host.done && !u_host.failed))
            $display("MPY_SESSION_END cycles=%0d ops=%0d gc=%0d", cycles, ops, gc_coll);
        else
            // st, the posted-store count and the pending request, to place a hang.
            $display("MPY_TIMEOUT cycles=%0d ops=%0d gc=%0d pc=%08x op=%02x st=%0d wret=%0d wpend=%0d m_req=%0d",
                     cycles, ops, gc_coll, trace_pc, trace_op, u_soc.u_core.st, u_soc.u_core.wret,
                     u_soc.u_core.wpend, u_soc.u_core.m_req);
        $finish;
    end
endmodule
