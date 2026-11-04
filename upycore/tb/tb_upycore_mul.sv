// Full signed 128-bit products, operand isolation, and level-start protocol.
module tb_upycore_mul #(parameter int STEP = 16);
    logic clk = 0, rst_n = 0, start = 0;
    always #5 clk = ~clk;
    logic [63:0] a = 0, b = 0, lo, hi;
    logic done, busy, stall;
    int checks = 0;
    upycore_mul #(.STEP(STEP)) dut (.clk_i(clk), .rst_n_i(rst_n),
        .start_i(start), .op_a_i(a), .op_b_i(b), .result_o(lo), .result_hi_o(hi),
        .done_o(done), .stall_o(stall), .busy_o(busy));
    task automatic run(input logic [63:0] aa, input logic [63:0] bb);
        logic signed [127:0] expected;
        int cycles;
        expected = $signed(aa) * $signed(bb);
        @(negedge clk); a = aa; b = bb; start = 1;
        @(negedge clk); a = ~aa; b = ~bb;
        cycles = 0;
        while (!done && cycles < (64/STEP)+3) begin
            if (!busy || !stall) $fatal(1, "early busy/stall drop");
            @(negedge clk); cycles++;
        end
        if (!done || {hi,lo} !== expected || cycles != (64/STEP)+1 || busy || stall)
            $fatal(1, "mul %h * %h got %h%h expected %h cycles %0d", aa, bb, hi, lo, expected, cycles);
        // Held start must not reaccept on the done edge.
        @(negedge clk);
        if (done || busy) $fatal(1, "reaccept on done");
        start = 0;
        checks++;
    endtask
    initial begin
        logic [63:0] edgev [0:7];
        edgev = '{64'd0,64'd1,64'hffffffffffffffff,64'h8000000000000000,
                  64'h7fffffffffffffff,64'h00000000ffffffff,
                  64'hffffffff00000000,64'h8000000080000000};
        repeat (3) @(negedge clk); rst_n = 1;
        foreach (edgev[i]) foreach (edgev[j]) run(edgev[i],edgev[j]);
        for (int i = 0; i < 10000; i++) run({$urandom,$urandom},{$urandom,$urandom});
        // Abort at every phase, followed immediately by a fresh operation.
        for (int n = 0; n < (64/STEP)+1; n++) begin
            @(negedge clk); a = 123; b = 456; start = 1;
            repeat (n+1) @(negedge clk);
            start = 0;
            @(negedge clk);
            if (busy || done) $fatal(1, "abort phase %0d", n);
            run(64'h8000000000000000, 64'hffffffffffffffff);
        end
        @(negedge clk); start = 1;
        repeat (2) @(negedge clk);
        rst_n = 0; #1;
        if (busy || done) $fatal(1, "reset during operation");
        @(negedge clk); start = 0; rst_n = 1;
        run(7,9);
        $display("PASS upycore_mul STEP=%0d %0d checks", STEP, checks);
        $finish;
    end
endmodule
