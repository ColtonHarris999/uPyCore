`include "mpy_defs.svh"

// Exercise boot-selected boundaries on the real four-bank SRAM controller.
module tb_mpy_shared_mem;
    logic clk = 0, rst_n = 0;
    always #5 clk = ~clk;
    logic [31:0] image_words = 8;
    logic req, we, tag_we, gnt, ack, fault, ready, ld_we;
    logic [31:0] addr, data, out_data, ld_data;
    logic [3:0] tag, out_tag, reason, ld_tag;
    logic [MPY_FLASH_IDX_W-1:0] ld_idx;
    int checks = 0;
    mpy_mem #(.NP(1)) dut (
        .clk_i(clk), .rst_n_i(rst_n), .image_words_i(image_words),
        .req_i(req), .we_i(we), .tag_we_i(tag_we), .be_i(4'hf),
        .addr_i(addr), .wdata_i(data), .wtag_i(tag),
        .gnt_o(gnt), .ack_o(ack), .rdata_o(out_data), .rtag_o(out_tag),
        .fault_o(fault), .fault_reason_o(reason),
        .ld_we_i(ld_we), .ld_idx_i(ld_idx), .ld_wdata_i(ld_data), .ld_wtag_i(ld_tag),
        .init_done_o(ready)
    );
    task automatic check(input bit ok, input string what);
        checks++;
        if (!ok) $fatal(1, "%s", what);
    endtask
    task automatic access(input bit write_en, input logic [31:0] a,
                          input logic [31:0] value, input logic [3:0] t,
                          input logic [3:0] expected_fault);
        @(negedge clk);
        req = 1; we = write_en; tag_we = write_en; addr = a; data = value; tag = t;
        do @(posedge clk); while (!gnt);
        @(negedge clk); req = 0;
        while (!ack) @(negedge clk);
        check(fault == (expected_fault != 0) && reason == expected_fault, "access fault agrees with runtime boundary");
        if (!write_en && expected_fault == 0)
            check(out_data == value && out_tag == t, "data and tag preserved across image/data mapping");
    endtask
    task automatic load(input int index, input logic [31:0] value, input logic [3:0] t);
        @(negedge clk); ld_we = 1; ld_idx = MPY_FLASH_IDX_W'(index); ld_data = value; ld_tag = t;
        @(negedge clk); ld_we = 0;
    endtask
    initial begin
        int aligned_words, data_bytes;
        req = 0; we = 0; tag_we = 0; addr = 0; data = 0; tag = 0;
        ld_we = 0; ld_idx = 0; ld_data = 0; ld_tag = 0;
        for (int layout = 0; layout < 3; layout++) begin
            @(negedge clk); rst_n = 0;
            // Include an image above the previous 192 KiB cap, and an
            // unaligned image size whose padding must remain protected.
            image_words = layout == 0 ? 9 : layout == 1 ? 8192 : 49160;
            aligned_words = (image_words + 7) & ~7;
            data_bytes = MPY_MEM_BYTES - 4 * aligned_words;
            repeat (3) @(negedge clk); rst_n = 1;
            wait (ready);
            for (int bank = 0; bank < 4; bank++) begin
                load(bank, 32'h12345600 + bank, 4'(bank + 1));
                load(aligned_words - 4 + bank, 32'h98765400 + bank, 4'(bank + 5));
                access(0, MPY_SRAM_BASE + bank * 4, 0, 0, 0);
                access(1, MPY_SRAM_BASE + bank * 4, 32'hcafeb000 + bank, 4'(bank + 9), 0);
                access(1, MPY_SRAM_BASE + data_bytes - 16 + bank * 4, 32'habcd0000 + bank, 4'(bank + 3), 0);
            end
            for (int bank = 0; bank < 4; bank++) begin
                access(0, bank * 4, 32'h12345600 + bank, 4'(bank + 1), 0);
                access(0, (aligned_words - 4 + bank) * 4, 32'h98765400 + bank, 4'(bank + 5), 0);
                access(0, MPY_SRAM_BASE + bank * 4, 32'hcafeb000 + bank, 4'(bank + 9), 0);
                access(0, MPY_SRAM_BASE + data_bytes - 16 + bank * 4, 32'habcd0000 + bank, 4'(bank + 3), 0);
            end
            access(1, 0, 0, 0, MPY_FAULT_FLASH_STORE);
            access(0, aligned_words * 4, 0, 0, MPY_FAULT_BUS);
            access(1, MPY_SRAM_BASE + data_bytes, 0, 0, MPY_FAULT_BUS);
            access(0, MPY_SRAM_BASE + data_bytes, 0, 0, MPY_FAULT_BUS);
        end
        $display("PASS mpy_shared_mem %0d checks", checks);
        $finish;
    end
    initial begin
        #10000000; $fatal(1, "timeout");
    end
endmodule
