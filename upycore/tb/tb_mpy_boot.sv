`include "mpy_defs.svh"

// Use the real SPI transport and decoder, including resets with new sizes.
module tb_mpy_boot;
    logic clk = 0, rst_n = 0;
    always #5 clk = ~clk;
    logic sck, cs_n, mosi, miso, ld_we, done, err;
    logic [MPY_FLASH_IDX_W-1:0] idx;
    logic [31:0] data, words, pool;
    logic [3:0] tag;
    int writes = 0, checks = 0;
    mpy_boot dut (
        .clk_i(clk), .rst_n_i(rst_n), .sck_o(sck), .cs_n_o(cs_n),
        .mosi_o(mosi), .miso_i(miso), .ld_we_o(ld_we), .ld_idx_o(idx),
        .ld_wdata_o(data), .ld_wtag_o(tag), .image_words_o(words),
        .pool_bytes_o(pool), .done_o(done), .err_o(err)
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
    initial begin
        int n, offset;
        for (int trial = 0; trial < 6; trial++) begin
            @(negedge clk); rst_n = 0;
            repeat (3) @(negedge clk);
            writes = 0;
            n = trial == 1 ? (MPY_MEM_BYTES - (MPY_GC_POOL_BASE - MPY_SRAM_BASE) - 32) / 4 : 16;
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
            @(negedge clk); rst_n = 1;
            wait (done || err);
            @(negedge clk);
            if (trial < 2) begin
                check(done && !err, "valid image boots");
                check(writes == n && words == 32'(n) && pool == 0, "boot reports exact size and heap cap");
            end else check(err && !done && writes == 0, "invalid count or magic rejected before SRAM writes");
        end
        $display("PASS mpy_boot %0d checks", checks);
        $finish;
    end
    initial begin
        #250000000; $fatal(1, "boot timeout");
    end
endmodule
