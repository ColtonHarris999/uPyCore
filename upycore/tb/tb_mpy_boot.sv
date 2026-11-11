`include "mpy_defs.svh"

// Use the real SPI transport and decoder, including resets with new sizes,
// and the I/O core's IOCB section after the image (trials 6-10).
module tb_mpy_boot;
    logic clk = 0, rst_n = 0;
    always #5 clk = ~clk;
    logic sck, cs_n, mosi, miso, ld_we, done, err;
    logic [MPY_FLASH_IDX_W-1:0] idx;
    logic [31:0] data, words, pool;
    logic [3:0] tag;
    int writes = 0, checks = 0, iwrites = 0;
    logic        ioc_we, ioc_loaded;
    logic [48:0] ioc_data;
    int nc, nd;
    mpy_boot dut (
        .clk_i(clk), .rst_n_i(rst_n), .sck_o(sck), .cs_n_o(cs_n),
        .mosi_o(mosi), .miso_i(miso), .ld_we_o(ld_we), .ld_idx_o(idx),
        .ld_wdata_o(data), .ld_wtag_o(tag), .image_words_o(words),
        .pool_bytes_o(pool), .done_o(done), .err_o(err),
        .ioc_we_o(ioc_we), .ioc_data_o(ioc_data), .ioc_stall_i(1'b0), .ioc_loaded_o(ioc_loaded)
    );
    tb_spi_nand u_nand (.sck(sck), .cs_n(cs_n), .mosi(mosi), .miso(miso));
    function automatic logic [31:0] pattern(input int i);
        return i == 14 ? 32'd0 : 32'h12340000 + 32'(i);
    endfunction
    task automatic check(input bit ok, input string what);
        checks++;
        if (!ok) $fatal(1, "%s", what);
    endtask
    task automatic stream_word(input int offset, input logic [31:0] value);
        for (int b = 0; b < 4; b++) u_nand.mem[offset + b] = value[8*b +: 8];
    endtask
    always @(negedge clk) if (rst_n && ld_we) begin
        check(32'(idx) == writes, "boot writes sequential physical words");
        check(data == pattern(writes) && tag == 4'(writes % 8 + 1), "SPI preserves payload and packed tag");
        writes++;
    end
    // IOCB words: nc code words then nd data words, in order.
    function automatic logic [31:0] ipat(input int i);
        return 32'hA5000000 ^ (32'(i) * 32'h00010001);
    endfunction
    always @(negedge clk) if (rst_n && ioc_we) begin
        automatic logic expect_data = (iwrites >= nc);
        automatic int i = expect_data ? iwrites - nc : iwrites;
        check(ioc_data[48] == expect_data && ioc_data[47:32] == 16'(i) && ioc_data[31:0] == ipat(iwrites),
              "IOCB word: SRAM, index and value in order");
        iwrites++;
    end
    initial begin
        int n, offset;
        for (int trial = 0; trial < 11; trial++) begin
            @(negedge clk); rst_n = 0;
            repeat (3) @(negedge clk);
            writes = 0; iwrites = 0;
            for (int b = 0; b < 4096; b++) u_nand.mem[b] = 8'hFF;
            n = trial == 1 ? (MPY_MEM_BYTES - (MPY_GC_POOL_BASE - MPY_SRAM_BASE) - 32) / 4 : 16;
            if (trial == 1) for (int b = 0; b < 4 * (2 + 9 * n / 8) + 64; b++) u_nand.mem[b] = 8'hFF;
            // Exercise the largest valid image, including its tag stream.
            stream_word(0, trial == 5 ? 32'd0 : MPY_BOOT_MAGIC);
            stream_word(4, trial == 2 ? 32'd0 : trial == 3 ? 32'((MPY_MEM_BYTES - (MPY_GC_POOL_BASE - MPY_SRAM_BASE)) / 4) :
                           trial == 4 ? 32'h80000000 : 32'(n));
            offset = 8;
            for (int g = 0; g < n / 8; g++) begin
                stream_word(offset, 32'h87654321); offset += 4;
                for (int k = 0; k < 8; k++) begin
                    stream_word(offset, pattern(8*g + k)); offset += 4;
                end
            end
            // Trials 6-10: an IOCB section after the image (9: a code count too big,
            // 10: a data count one past the island's 1,920-word data SRAM).
            nc = 0; nd = 0;
            if (trial >= 6) begin
                nc = trial == 6 ? 5 : trial == 7 ? 0 : trial == 8 ? 37 : trial == 9 ? 4097 : 2;
                nd = trial == 6 ? 3 : trial == 7 ? 6 : trial == 8 ? 0 : trial == 9 ? 1 : 1921;
                stream_word(offset, MPY_IOCB_MAGIC); offset += 4;
                stream_word(offset, 32'(nc)); offset += 4;
                stream_word(offset, 32'(nd)); offset += 4;
                if (trial < 9)
                    for (int i = 0; i < nc + nd; i++) begin stream_word(offset, ipat(i)); offset += 4; end
            end
            @(negedge clk); rst_n = 1;
            wait (done || err);
            @(negedge clk);
            if (trial < 2) begin
                check(done && !err, "valid image boots");
                check(writes == n && words == 32'(n) && pool == 0, "boot reports exact size and heap cap");
                check(!ioc_loaded && iwrites == 0, "no IOCB section: the I/O core stays unloaded");
            end else if (trial >= 6 && trial < 9) begin
                check(done && !err && writes == n, "image with an IOCB section boots");
                check(ioc_loaded && iwrites == nc + nd, "every IOCB word reaches the load port");
            end else if (trial >= 9) begin
                check(err && !done && iwrites == 0, "an IOCB count beyond the island's SRAM is rejected");
            end else check(err && !done && writes == 0, "invalid count or magic rejected before SRAM writes");
        end
        $display("PASS mpy_boot %0d checks", checks);
        $finish;
    end
    initial begin
        #250000000; $fatal(1, "boot timeout");
    end
endmodule
