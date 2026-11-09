// Standalone bench for the I/O island (iocore_top).
//
//   +CODE=<hex> +DATA=<hex>   firmware images ($readmemh, one 32-bit word a
//                             line), written through the island's load port
//   +UART_OUT=<path>          bytes the UART line model decodes (default: log)
//   +UART_IN=<string>         bytes the model sends once the core runs
//   +MAX_US=<n>               give up after n µs of simulated time
//   +EXPECT=<path>            the bytes the line model must decode; the bench
//                             prints `PASS tb_iocore` or `FAIL tb_iocore`
//
// io_clk is 50 MHz (CLK_NS 20). The UART runs at BAUD clocks per bit; the
// line model at the matching bit time. The run ends at a store to SYS HALT.
// Last line: `IOC_HALT value=<hex> us=<n> rx=<n> ferr=<n>` or `IOC_TIMEOUT`.
module tb_iocore #(
    parameter int  CORE = 0,
    parameter int  MUL = 0,
    parameter real CLK_NS = 20.0,
    parameter int  BAUD = 434          // 50 MHz / 115200
);
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #(CLK_NS / 2.0) clk = ~clk;

    logic        run, ld_we, ld_data;
    logic [15:0] ld_idx;
    logic [31:0] ld_wdata;
    logic        txd, rxd;
    logic        dbg_valid, halt, sleep;
    logic [7:0]  dbg_byte;
    logic [31:0] halt_value;
    logic        rx_valid;
    logic [7:0]  rx_byte;

    iocore_top #(.CORE(CORE), .MUL(MUL), .BAUD_RESET(16'(BAUD))) dut (
        .io_clk_i(clk), .io_rst_n_i(rst_n), .run_i(run),
        .ld_we_i(ld_we), .ld_data_i(ld_data), .ld_idx_i(ld_idx), .ld_wdata_i(ld_wdata),
        .uart_rxd_i(rxd), .uart_txd_o(txd),
        .dbg_valid_o(dbg_valid), .dbg_byte_o(dbg_byte), .halt_o(halt), .halt_value_o(halt_value),
        .sleep_o(sleep)
    );

    tb_uart_line #(.BIT_NS(CLK_NS * BAUD)) u_term (
        .line_i(txd), .line_o(rxd), .rx_valid_o(rx_valid), .rx_byte_o(rx_byte)
    );

    logic [31:0] code [0:16383];
    logic [31:0] data [0:16383];
    int fd_out;
    longint max_us;

    // One 32-bit hex word a line; returns the number of words.
    function automatic int read_hex(input string path, ref logic [31:0] mem [0:16383]);
        int fd, n;
        logic [31:0] w;
        n = 0;
        fd = $fopen(path, "r");
        if (fd == 0) $fatal(1, "cannot open %s", path);
        while (n < 16384 && $fscanf(fd, "%h", w) == 1) begin mem[n] = w; n++; end
        $fclose(fd);
        return n;
    endfunction

    always @(posedge clk) if (dbg_valid) $write("%c", dbg_byte);

    initial begin
        string path, s;
        int ncode, ndata;
        fd_out = 0;
        run = 1'b0; ld_we = 1'b0; ld_data = 1'b0; ld_idx = '0; ld_wdata = '0;
        ncode = 0; ndata = 0;
        if ($value$plusargs("CODE=%s", path)) ncode = read_hex(path, code);
        if ($value$plusargs("DATA=%s", path)) ndata = read_hex(path, data);
        if ($value$plusargs("UART_OUT=%s", path)) fd_out = $fopen(path, "wb");
        u_term.fd = fd_out;
        if (!$value$plusargs("MAX_US=%d", max_us)) max_us = 20000;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        // The load port, one word a clock, as mpy_boot drives it.
        for (int i = 0; i < ncode; i++) begin
            @(negedge clk); ld_we = 1'b1; ld_data = 1'b0; ld_idx = 16'(i); ld_wdata = code[i];
        end
        for (int i = 0; i < ndata; i++) begin
            @(negedge clk); ld_we = 1'b1; ld_data = 1'b1; ld_idx = 16'(i); ld_wdata = data[i];
        end
        @(negedge clk); ld_we = 1'b0;
        run = 1'b1;
        $display("IOC_LOAD code=%0d data=%0d words", ncode, ndata);
        if ($value$plusargs("UART_IN=%s", s)) begin
            #(200us);
            for (int i = 0; i < s.len(); i++) u_term.send(s[i]);
        end
    end

    string path;
    initial begin
        @(posedge rst_n);
        fork
            begin wait (halt); end
            begin #(max_us * 1us); end
        join_any
        #(20 * CLK_NS * BAUD);
        if (fd_out != 0) $fclose(fd_out);
        if ($value$plusargs("EXPECT=%s", path)) begin
            int fd, c, n;
            bit ok;
            ok = halt && halt_value == 0;
            n = 0;
            fd = $fopen(path, "rb");
            if (fd == 0) $fatal(1, "cannot open %s", path);
            while ((c = $fgetc(fd)) != -1) begin
                if (n >= u_term.q.size() || u_term.q[n] != byte'(c)) ok = 0;
                n++;
            end
            $fclose(fd);
            if (n != u_term.q.size()) ok = 0;
            $display("%s tb_iocore core=%0d bytes=%0d expected=%0d", ok ? "PASS" : "FAIL", CORE,
                     u_term.q.size(), n);
        end
        if (halt)
            $display("IOC_HALT value=%08x us=%0d rx=%0d ferr=%0d", halt_value,
                     longint'($realtime / 1000.0), u_term.n_rx, u_term.n_ferr);
        else
            $display("IOC_TIMEOUT us=%0d rx=%0d", longint'($realtime / 1000.0), u_term.n_rx);
        $finish;
    end
endmodule
