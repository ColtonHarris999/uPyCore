`include "upycore_defs.svh"
// Directed check of the binary64 add, multiply and divide units on results
// that land in the subnormal range (the denormalize-then-round path) and
// next to it, against the simulator's IEEE double arithmetic.
module tb_upycore_fp_subnormal;
    logic clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    logic        a_start, a_sub, a_done, a_busy;
    logic [63:0] a_x, a_y, a_res;
    upycore_fp_add u_add (.clk_i(clk), .rst_n_i(rst_n), .start_i(a_start), .sub_i(a_sub),
                          .op_a_i(a_x), .op_b_i(a_y), .result_o(a_res), .done_o(a_done), .busy_o(a_busy));

    logic        m_start, m_done, m_busy, mm_start, mm_done, mm_busy;
    logic [63:0] m_x, m_y, m_res;
    logic [52:0] mm_a, mm_b;
    logic [105:0] mm_p;
    upycore_fp_mul u_mul (.clk_i(clk), .rst_n_i(rst_n), .start_i(m_start), .op_a_i(m_x), .op_b_i(m_y),
                          .result_o(m_res), .done_o(m_done), .busy_o(m_busy),
                          .mul_start_o(mm_start), .mul_a_o(mm_a), .mul_b_o(mm_b),
                          .mul_product_i(mm_p), .mul_done_i(mm_done), .mul_busy_i(mm_busy));
    upycore_umul_seq #(.AW(53), .BW(53), .STEP(14)) u_core (
        .clk_i(clk), .rst_n_i(rst_n), .start_i(mm_start), .op_a_i(mm_a), .op_b_i(mm_b),
        .product_o(mm_p), .done_o(mm_done), .busy_o(mm_busy));

    logic        d_start, d_done, d_busy;
    logic [63:0] d_x, d_y, d_res;
    upycore_fp_divrem u_div (.clk_i(clk), .rst_n_i(rst_n), .start_i(d_start), .fmod_i(1'b0), .sqrt_i(1'b0),
                             .op_a_i(d_x), .op_b_i(d_y), .result_o(d_res), .done_o(d_done), .busy_o(d_busy));

    int fails = 0, n = 0, subn = 0;
    function automatic logic [63:0] ref_op(input int k, input logic [63:0] x, input logic [63:0] y);
        real rx, ry;
        rx = $bitstoreal(x); ry = $bitstoreal(y);
        case (k)
            0: ref_op = $realtobits(rx + ry);
            1: ref_op = $realtobits(rx * ry);
            default: ref_op = $realtobits(rx / ry);
        endcase
    endfunction

    task automatic run(input int k, input logic [63:0] x, input logic [63:0] y);
        logic [63:0] got, want;
        int guard;
        @(negedge clk);
        case (k) 0: begin a_x = x; a_y = y; a_sub = 0; a_start = 1; end
                 1: begin m_x = x; m_y = y; m_start = 1; end
                 default: begin d_x = x; d_y = y; d_start = 1; end endcase
        guard = 0;
        do begin @(posedge clk); #1; guard++; end
        while (!((k == 0 && a_done) || (k == 1 && m_done) || (k == 2 && d_done)) && guard < 200);
        got = (k == 0) ? a_res : (k == 1) ? m_res : d_res;
        @(negedge clk); a_start = 0; m_start = 0; d_start = 0;
        @(negedge clk);
        want = ref_op(k, x, y);
        n++;
        if (want[62:52] == 11'd0 && want[51:0] != 0) subn++;
        if (got !== want && !(want[62:52] == 11'h7ff && want[51:0] != 0 && got[62:52] == 11'h7ff)) begin
            fails++;
            if (fails < 10) $display("FAIL op%0d %h %h got %h want %h", k, x, y, got, want);
        end
    endtask

    initial begin
        logic [63:0] x, y;
        a_start = 0; m_start = 0; d_start = 0; a_sub = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        for (int i = 0; i < 3000; i++) begin
            // Operands near the bottom of the normal range, and subnormals,
            // so the products, quotients and sums are subnormal or close.
            x = {1'b0, 11'($urandom_range(0, 40)), 52'({$urandom, $urandom})};
            y = {$urandom_range(0, 1) == 1, 11'($urandom_range(1000, 1060)), 52'({$urandom, $urandom})};
            if (i % 3 == 0) x[63] = 1'b1;
            run(1, x, y);
            run(2, x, {y[63], 11'($urandom_range(1023, 1100)), y[51:0]});
            run(0, x, {~x[63], x[62:52], 52'({$urandom, $urandom})});
            run(0, x, {x[63], 11'($urandom_range(0, 2)), 52'({$urandom, $urandom})});
        end
        $display("%s upycore_fp_subnormal %0d checks, %0d subnormal results, %0d failures",
                 fails == 0 ? "PASS" : "FAIL", n, subn, fails);
        $finish;
    end
endmodule
