`include "mpy_defs.svh"

// Randomized check of mpy_fetch on a real mpy_mem port.
//
// The image SRAM is loaded with a known pattern through the load port.
// A model of the core moves pc: it steps forward by up to the bytes the
// queue says are available (like a decode), jumps anywhere in the image or
// just before its end (so read-ahead runs past it and faults), and raises
// flush. Every cycle the bytes the queue offers from pc must match memory,
// a reported fault must name the first word past the image, and a pc inside
// the image must get bytes within a bounded time.
//
// +SEED=<n> +STEPS=<n>. Pass line: "PASS mpy_fetch ...".
module tb_mpy_fetch;
    localparam int QD = 3;   // mpy_core's FE_QD
    localparam int N = 1024;               // image words
    localparam logic [31:0] END = N * 4;    // first byte past the image

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #5 clk = ~clk;

    logic [31:0] pc;
    logic        flush;
    logic        req, gnt, ack, mfault;
    logic [31:0] addr, rdata;
    logic [3:0]  rtag, mreason;
    logic [32*QD-1:0] win;
    logic [31:0] base, faddr;
    logic [5:0]  avail;
    logic        ffault;
    logic [3:0]  freason;
    logic        ld_we, ready;
    logic [MPY_FLASH_IDX_W-1:0] ld_idx;
    logic [31:0] ld_data;

    mpy_mem #(.NP(1)) mem (
        .clk_i(clk), .rst_n_i(rst_n), .image_words_i(N),
        .req_i(req && ready), .we_i(1'b0), .tag_we_i(1'b0), .be_i(4'hF),
        .addr_i(addr), .wdata_i(32'd0), .wtag_i(4'd0),
        .gnt_o(gnt), .ack_o(ack), .rdata_o(rdata), .rtag_o(rtag),
        .fault_o(mfault), .fault_reason_o(mreason),
        .ld_we_i(ld_we), .ld_idx_i(ld_idx), .ld_wdata_i(ld_data), .ld_wtag_i(4'd0),
        .init_done_o()
    );

    mpy_fetch #(.QD(QD)) dut (
        .clk_i(clk), .rst_n_i(rst_n && ready),
        .pc_i(pc), .flush_i(flush),
        .req_o(req), .addr_o(addr), .gnt_i(gnt), .ack_i(ack),
        .rdata_i(rdata), .fault_i(mfault), .fault_reason_i(mreason),
        .win_o(win), .base_o(base), .avail_o(avail),
        .fault_o(ffault), .fault_addr_o(faddr), .fault_reason_o(freason)
    );

    function automatic logic [31:0] word_of(input int i);
        word_of = (32'(i) * 32'h9E37_79B9) ^ 32'h5A5A_0000;
    endfunction
    function automatic logic [7:0] byte_at(input logic [31:0] a);
        logic [31:0] w;
        w = word_of(int'(a >> 2));
        byte_at = w[8 * a[1:0] +: 8];
    endfunction

    int errors = 0, steps = 0, jumps = 0, flushes = 0, faults = 0, waits = 0, worst = 0;

    task automatic check_now();
        logic [31:0] off;
        off = pc - base;
        for (int k = 0; k < 32; k++) begin
            if (k < int'(avail)) begin
                logic [7:0] got;
                got = win[8 * (int'(off) + k) +: 8];
                if (pc + 32'(k) >= END || got !== byte_at(pc + 32'(k))) begin
                    errors++;
                    if (errors < 10)
                        $display("FAIL byte pc=%h +%0d got %02h want %02h (base %h avail %0d)",
                                 pc, k, got, byte_at(pc + 32'(k)), base, avail);
                end
            end
        end
        if (ffault && (faddr != {END[31:2], 2'b00} || freason != MPY_FAULT_BUS)) begin
            errors++;
            if (errors < 10) $display("FAIL fault at %h reason %0d", faddr, freason);
        end
    endtask

    initial begin
        int seed, nsteps, wait_n;
        if (!$value$plusargs("SEED=%d", seed)) seed = 1;
        if (!$value$plusargs("STEPS=%d", nsteps)) nsteps = 20000;
        void'($urandom(seed));
        pc = 32'd0; flush = 1'b0; ld_we = 1'b0; ld_idx = '0; ld_data = '0; ready = 1'b0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        wait (mem.init_done_o);
        @(negedge clk);
        // Load the image, then let the fetch unit out of reset.
        for (int i = 0; i < N; i++) begin
            ld_we = 1'b1; ld_idx = MPY_FLASH_IDX_W'(i); ld_data = word_of(i);
            @(negedge clk);
        end
        ld_we = 1'b0;
        repeat (MPY_SRAM_WORDS / 4 + 8) @(negedge clk);
        ready = 1'b1;
        wait_n = 0;
        while (steps < nsteps) begin
            int r;
            @(negedge clk);
            check_now();
            flush = 1'b0;
            r = $urandom_range(0, 99);
            if (r < 4) begin
                pc = 32'($urandom_range(0, N * 4 - 1));          // jump in the image
                jumps++; wait_n = 0;
            end else if (r < 6) begin
                pc = END - 32'($urandom_range(1, 24));           // near the end
                jumps++; wait_n = 0;
            end else if (r < 7) begin
                flush = 1'b1;
                flushes++; wait_n = 0;
            end else if (avail != 0) begin
                int n;
                n = $urandom_range(1, (int'(avail) > 8) ? 8 : int'(avail));
                pc = pc + 32'(n);
                steps++; wait_n = 0;
            end else if (ffault) begin
                faults++;
                pc = 32'($urandom_range(0, N * 4 - 1));
                wait_n = 0;
            end else begin
                waits++; wait_n++;
                if (wait_n > worst) worst = wait_n;
                if (wait_n > 40) begin
                    errors++;
                    if (errors < 10) $display("FAIL no bytes for pc=%h after 40 cycles", pc);
                    pc = 32'd0; wait_n = 0;
                end
            end
        end
        if (errors == 0)
            $display("PASS mpy_fetch seed=%0d steps=%0d jumps=%0d flushes=%0d faults=%0d waits=%0d worst=%0d",
                     seed, steps, jumps, flushes, faults, waits, worst);
        else
            $display("FAIL mpy_fetch %0d errors", errors);
        $finish;
    end
endmodule
