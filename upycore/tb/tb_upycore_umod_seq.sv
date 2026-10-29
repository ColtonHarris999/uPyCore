// Randomized check of upycore_umod_seq against the % operator.
//
// Operands mix full 32-bit values, small values, the py/map.c table sizes
// and the corners (d = 1, a = 0, a < d, a = d, all ones). Each result must
// match a % d and arrive within the documented latency.
//
// Build it with Verilator from the repo root, then run obj_dir/Vtb_upycore_umod_seq:
//   --binary upycore/rtl/upycore_umod_seq.sv upycore/tb/tb_upycore_umod_seq.sv
//   --top-module tb_upycore_umod_seq
// +SEED=<n> picks the random sequence and +OPS=<n> its length. -GBPC=<n>
// sets the bits per clock.
module tb_upycore_umod_seq #(parameter int BPC = 4);
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #5 clk = ~clk;

    logic        start, done, busy;
    logic [31:0] a, d, rem;

    upycore_umod_seq #(.BPC(BPC)) dut (
        .clk_i(clk), .rst_n_i(rst_n), .start_i(start), .a_i(a), .d_i(d),
        .done_o(done), .rem_o(rem), .busy_o(busy)
    );

    int unsigned primes [0:33] = '{2, 2, 4, 6, 8, 10, 12, 17, 23, 29, 37, 47, 59, 73, 97, 127, 167,
                                   223, 293, 389, 521, 691, 919, 1223, 1627, 2161, 3229, 4831,
                                   7243, 10861, 16273, 24407, 36607, 54907};

    function automatic logic [31:0] pick(input int unsigned sel);
        case (sel % 6)
            0: pick = $urandom();
            1: pick = $urandom() & 32'hFFFF;
            2: pick = $urandom() & 32'hFF;
            3: pick = 32'(primes[$urandom() % 34]);
            4: pick = 32'hFFFF_FFFF - ($urandom() & 32'hF);
            default: pick = $urandom() >> ($urandom() % 32);
        endcase
    endfunction

    function automatic int bits(input logic [31:0] v);
        bits = 0;
        for (int i = 0; i < 32; i++) if (v[i]) bits = i + 1;
    endfunction

    task automatic check(input logic [31:0] aa, input logic [31:0] dd);
        int cyc, k, lim;
        a = aa; d = dd; start = 1'b1;
        @(posedge clk); #1;
        start = 1'b0; a = $urandom(); d = $urandom();   // operands only matter at start
        cyc = 1;
        while (!done) begin @(posedge clk); #1; cyc++; end
        k = bits(aa) - bits(dd) + 1;
        lim = (aa < dd) ? 1 : (k + BPC - 1) / BPC + 1;
        if (rem !== aa % dd || cyc != lim) begin
            $display("FAIL %0d %% %0d: got %0d in %0d cycles, want %0d in %0d",
                     aa, dd, rem, cyc, aa % dd, lim);
            $fatal(1);
        end
    endtask

    initial begin
        int unsigned seed, ops;
        logic [31:0] aa, dd;
        if (!$value$plusargs("SEED=%d", seed)) seed = 1;
        if (!$value$plusargs("OPS=%d", ops)) ops = 200000;
        void'($urandom(seed));
        start = 1'b0; a = '0; d = 32'd1;
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk); #1;
        check(32'd0, 32'd1);
        check(32'hFFFF_FFFF, 32'd1);
        check(32'hFFFF_FFFF, 32'hFFFF_FFFF);
        check(32'hFFFF_FFFE, 32'hFFFF_FFFF);
        check(32'h8000_0000, 32'd3);
        check(32'd17, 32'd17);
        check(32'd16, 32'd17);
        for (int unsigned i = 0; i < ops; i++) begin
            aa = pick($urandom());
            dd = pick($urandom());
            if (dd == 32'd0) dd = 32'd1;
            check(aa, dd);
        end
        $display("PASS upycore_umod_seq BPC=%0d ops=%0d", BPC, ops);
        $finish;
    end
endmodule
