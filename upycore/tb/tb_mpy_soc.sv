
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
//   +UART_IN=<string> +UART_IN_US=<n>       bytes the line model sends, n µs after reset
//   +UART_BAUD=<n>                          io_clk cycles per bit of the line model (434)
//   +GPIO_LOOP=1                            wire pad i to pad i^8 (pins 0-7 to 8-15)
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
        // Start a fraction of a period off the hart's clock.
        #(io_clk_ns * 0.37);
        forever #(io_clk_ns / 2.0) io_clk = ~io_clk;
    end
    logic [1:0] console_sel = 2'd0;
    initial begin
        string c;
        if ($value$plusargs("CONSOLE=%s", c))
            console_sel = (c == "uart") ? 2'd1 : (c == "usb") ? 2'd2 : 2'd0;
    end
    logic uart0_rxd, uart0_txd, ioc_dbg_valid;
    logic [15:0] gpio_out, gpio_oe, gpio_pu, gpio_pd, gpio_in;
    // Pads: a driven pad shows its output; an undriven one its pull (a
    // pull-up reads 1), else 0. With +GPIO_LOOP pads i and i^8 are one net.
    bit gpio_loop;
    initial gpio_loop = $test$plusargs("GPIO_LOOP");
    always_comb begin
        for (int i = 0; i < 16; i++) begin
            int j = i ^ 8;
            if (gpio_oe[i]) gpio_in[i] = gpio_out[i];
            else if (gpio_loop && gpio_oe[j]) gpio_in[i] = gpio_out[j];
            else gpio_in[i] = gpio_pu[i] || (gpio_loop && gpio_pu[j]);
        end
    end
    logic [7:0] ioc_dbg_byte;
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
        .ioc_dbg_valid_o(ioc_dbg_valid), .ioc_dbg_byte_o(ioc_dbg_byte)
    );

    int fd_ioc = 0;
    always @(posedge io_clk) if (ioc_dbg_valid && fd_ioc != 0) begin
        $fwrite(fd_ioc, "%c", ioc_dbg_byte);
        $fflush(fd_ioc);
    end
    initial begin
        string path, s;
        int baud, at_us;
        if ($value$plusargs("IOC_LOG=%s", path)) fd_ioc = $fopen(path, "wb");
        if (!$value$plusargs("UART_BAUD=%d", baud)) baud = 434;
        u_term.set_bit_ns(io_clk_ns * baud);
        if ($value$plusargs("UART_OUT=%s", path)) u_term.fd = $fopen(path, "wb");
        else u_term.fd = -1;
        if ($value$plusargs("UART_IN=%s", s)) begin
            if (!$value$plusargs("UART_IN_US=%d", at_us)) at_us = 100;
            #(at_us * 1us);
            for (int i = 0; i < s.len(); i++) u_term.send(s[i]);
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
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles)) max_cycles = 50_000_000;
        do_trace = $value$plusargs("TRACE=%d", t) && t != 0;
`ifdef MPY_SAIF
        // Switching activity of the core for power analysis: +SAIF=<path>,
        // in a build made with --trace-saif -DMPY_SAIF (see synth/hammer).
        if ($value$plusargs("SAIF=%s", path)) begin
            $dumpfile(path);
            $dumpvars(0, u_soc.u_core);
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
        while (!halted && !boot_err && n < max_cycles) begin
            @(posedge clk);
            n++;
        end
        // let the last console byte land
        repeat (4) @(posedge clk);
        if (fd_out != 0) $fclose(fd_out);
        if (fd_err != 0) $fclose(fd_err);
        if (boot_err)
            $display("MPY_BOOT_ERROR cycles=%0d", n);
        else if (halted)
            $display("MPY_HALT code=%0d value=%08x cycles=%0d ops=%0d gc=%0d free=%0d boot=%0d",
                     halt_code, halt_value, cycles, ops, gc_coll, gc_free, boot_cycles);
        else
            $display("MPY_TIMEOUT cycles=%0d ops=%0d gc=%0d pc=%08x op=%02x",
                     cycles, ops, gc_coll, trace_pc, trace_op);
        $finish;
    end
endmodule
