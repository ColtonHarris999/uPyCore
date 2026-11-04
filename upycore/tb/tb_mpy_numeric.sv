`include "upycore_defs.svh"
// Independent C++ casts check both conversion pipelines, including boundary
// rounding and subnormal narrowing. Also exercises real ALU handshakes.
module tb_mpy_numeric;
    import mpy_alu_pkg::*;
    import "DPI-C" function int unsigned oracle_i2f(input longint x);
    import "DPI-C" function int unsigned oracle_narrow(input longint unsigned x);
    import "DPI-C" function int unsigned oracle_classify(input longint unsigned x);
    logic clk = 0, rst_n = 0, start = 0;
    always #5 clk = ~clk;
    logic [63:0] a = 0, result;
    logic done;
    logic [1:0] kind;
    logic [2:0] err;
    mpy_alu dut (.clk_i(clk), .rst_n_i(rst_n), .start_i(start),
        .op_i(ALU_I2F), .a_flt_i(1'b0), .b_flt_i(1'b0), .a_i(a), .b_i(64'd0),
        .small_i(1'b0), .done_o(done), .res_o(result), .rkind_o(kind), .err_o(err));
    logic [63:0] d;
    logic [31:0] narrow;
    mpy_f32_narrow nar (.d_i(d), .q_o(narrow));
    int checks = 0;
    task automatic i2f(input logic [63:0] x);
        int cycles;
        logic [31:0] expected;
        expected = oracle_i2f($signed(x));
        @(negedge clk); a = x; start = 1;
        @(negedge clk); start = 0; a = ~x;
        cycles = 0;
        while (!done && cycles < 10) begin @(negedge clk); cycles++; end
        if (!done || result !== {32'd0, expected} || kind != AK_FLOAT || err != AE_NONE)
            $fatal(1, "i2f %h got %h expected %h", x, result, expected);
        checks++;
    endtask
    task automatic ncheck(input logic [63:0] x);
        logic [31:0] expected;
        d = x;
        expected = oracle_narrow(x);
        #1;
        if (narrow !== expected) $fatal(1, "narrow %h got %h expected %h", x, narrow, expected);
        if ({upycore_f64_is_odd_integer(x), upycore_f64_is_integer(x)} !== 2'(oracle_classify(x)))
            $fatal(1, "classify %h", x);
        checks++;
    endtask
    initial begin
        logic [63:0] x;
        repeat (3) @(negedge clk);
        rst_n = 1;
        i2f(0); i2f(64'h8000_0000_0000_0000); i2f(64'h7fff_ffff_ffff_ffff);
        for (int k = 0; k < 63; k++) begin
            x = 64'd1 << k;
            for (int off = -3; off <= 3; off++) begin
                i2f(x + 64'(off)); i2f(-(x + 64'(off)));
            end
            // Midpoints at each exponent, with even and odd lower neighbors.
            if (k >= 24) begin
                for (int m = 0; m < 2; m++) begin
                    x = (64'd1 << k) + (64'(m) << (k-23)) + (64'd1 << (k-24));
                    for (int off = -1; off <= 1; off++) begin
                        i2f(x + 64'(off)); i2f(-(x + 64'(off)));
                    end
                end
            end
        end
        for (int k = 0; k < 20000; k++) i2f({$urandom, $urandom});
        ncheck(0); ncheck(64'h8000_0000_0000_0000);
        ncheck(64'h7ff0_0000_0000_0000); ncheck(64'hfff0_0000_0000_0000);
        ncheck(64'h7ff0_0000_0000_0001); ncheck(64'hfff8_0000_0000_0001);
        // All exponents, normal tie boundaries, subnormal/normal transition,
        // underflow ties, and overflow. Include both signs.
        for (int e = 0; e < 2047; e++) begin
            for (int off = -2; off <= 2; off++) begin
                x = (64'(e) << 52) + 64'(off);
                ncheck(x); ncheck(x | 64'h8000_0000_0000_0000);
                x = (64'(e) << 52) | 64'h0008_0000_1000_0000;
                ncheck(x + 64'(off)); ncheck((x + 64'(off)) | 64'h8000_0000_0000_0000);
            end
        end
        for (int k = 0; k < 100000; k++) ncheck({$urandom, $urandom});
        $display("PASS mpy_numeric %0d checks", checks);
        $finish;
    end
endmodule
