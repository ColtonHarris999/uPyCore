`include "upycore_defs.svh"

// Exit checks for mpy_alu.
//
// Each op is one start_i pulse; the bench waits for done_o and checks
// res_o, rkind_o, err_o and, where the path matters, what reached the
// binary64 adder inside upycore_fpu. Covered: bools and ints, int64
// overflow, a binary32 add widened onto the binary64 adder (normal,
// subnormal, -0, subtract), float compares, ops that convert an int
// operand first (A_FCONV), the float error checks (zero divisor, a
// complex power), int <-> float conversion, and the binary32 narrowing
// one cycle after the FPU (A_FNAR).
//
// Build it with Verilator from the repo root, then run obj_dir/Vtb_mpy_alu:
//   --binary -Iupycore/rtl <the ALU_FILES of upycore/tools/mpy_synth.py>
//   upycore/tb/tb_mpy_alu.sv --top-module tb_mpy_alu
// (upycore/tools/unit_tests.py does this.)
module tb_mpy_alu;
    import mpy_alu_pkg::*;

    logic        clk = 1'b0;
    logic        rst_n = 1'b0;
    logic        start = 1'b0;
    logic [5:0]  op = '0;
    logic        a_flt = 1'b0, b_flt = 1'b0, sm_int = 1'b0;
    logic [63:0] a = '0, b = '0;
    logic        done;
    logic [63:0] res;
    logic [1:0]  kind;
    logic [2:0]  err;

    always #5 clk = ~clk;

    mpy_alu dut (
        .clk_i(clk), .rst_n_i(rst_n), .start_i(start), .op_i(op),
        .a_flt_i(a_flt), .b_flt_i(b_flt), .a_i(a), .b_i(b), .small_i(sm_int),
        .done_o(done), .res_o(res), .rkind_o(kind), .err_o(err)
    );

    localparam logic [31:0] F32_M0   = 32'h8000_0000;
    localparam logic [31:0] F32_0    = 32'h0000_0000;
    localparam logic [31:0] F32_HALF = 32'h3f00_0000;
    localparam logic [31:0] F32_1    = 32'h3f80_0000;
    localparam logic [31:0] F32_1_5  = 32'h3fc0_0000;
    localparam logic [31:0] F32_2    = 32'h4000_0000;
    localparam logic [31:0] F32_3    = 32'h4040_0000;
    localparam logic [31:0] F32_3_5  = 32'h4060_0000;
    localparam logic [31:0] F32_M2   = 32'hc000_0000;
    localparam logic [31:0] F32_THIRD = 32'h3eaa_aaab;   // 1/3 rounded to nearest

    localparam logic [63:0] F64_M0 = 64'h8000_0000_0000_0000;
    localparam logic [63:0] F64_1  = 64'h3FF0_0000_0000_0000;
    localparam logic [63:0] F64_2  = 64'h4000_0000_0000_0000;
    localparam logic [63:0] F64_3  = 64'h4008_0000_0000_0000;
    // binary32 min subnormal 2^-149, widened.
    localparam logic [63:0] F64_F32_MIN_SUB = 64'h36A0_0000_0000_0000;

    // What the binary64 adder accepted during the last op.
    int          add_seen;
    logic [63:0] seen_a, seen_b;
    logic        seen_sub;
    always @(posedge clk) begin
        if (start) add_seen <= 0;
        else if (dut.u_fpu.u_add.start_i && !dut.u_fpu.u_add.busy_o && add_seen == 0) begin
            seen_a   <= dut.u_fpu.u_add.op_a_i;
            seen_b   <= dut.u_fpu.u_add.op_b_i;
            seen_sub <= dut.u_fpu.u_add.sub_i;
            add_seen <= 1;
        end
    end

    int checks = 0;
    int cycles;

    task automatic check(input logic cond, input string msg);
        if (!cond) $fatal(1, "FAIL %s (res=%h kind=%0d err=%0d cycles=%0d)", msg, res, kind, err, cycles);
        checks++;
    endtask

    // One op: operands are an int64 or a binary32 in [31:0] (af / bf set).
    task automatic run(input logic [5:0] o, input logic af, input logic [63:0] av,
                       input logic bf, input logic [63:0] bv, input logic sm = 1'b1);
        @(negedge clk);
        op = o; a_flt = af; b_flt = bf; a = av; b = bv; sm_int = sm; start = 1'b1;
        @(negedge clk);
        start = 1'b0;
        a = 64'hDEAD_BEEF_DEAD_BEEF; b = 64'hDEAD_BEEF_DEAD_BEEF;   // only read at accept
        cycles = 1;
        while (!done) begin
            @(negedge clk);
            cycles++;
            if (cycles > 2000) $fatal(1, "timeout op=%0d", o);
        end
    endtask

    function automatic logic [63:0] f(input logic [31:0] x);
        f = {32'd0, x};
    endfunction

    function automatic logic [63:0] i(input longint x);
        i = 64'(x);
    endfunction

    initial begin
        int fast_add;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        // Ints and bools.
        run(ALU_ADD, 0, i(1), 0, i(1));                   // True + 1: bools reach here as ints
        check(err == AE_NONE && kind == AK_INT && res == 64'd2, "1 + 1 == 2");
        check(add_seen == 0, "int add used the float adder");
        run(ALU_EQ, 0, i(7), 0, i(7));
        check(kind == AK_BOOL && res == 64'd1, "7 == 7 is True");
        run(ALU_LT, 0, i(-3), 0, i(2));
        check(kind == AK_BOOL && res == 64'd1, "-3 < 2");
        run(ALU_ADD, 0, i(64'h7FFF_FFFF_FFFF_FFFF), 0, i(1), 1'b0);
        check(err == AE_OVERFLOW, "int64 max + 1 is OverflowError");
        run(ALU_FLOOR, 0, i(-7), 0, i(2));
        check(err == AE_NONE && res == i(-4), "-7 // 2 == -4");
        run(ALU_MOD, 0, i(7), 0, i(0));
        check(err == AE_ZERO_DIV, "7 % 0 is ZeroDivisionError");

        // binary32 adds go through the binary64 adder, widened.
        run(ALU_ADD, 1, f(F32_1), 1, f(F32_2));
        fast_add = cycles;
        check(err == AE_NONE && kind == AK_FLOAT && res == f(F32_3), "1.0 + 2.0 == 3.0");
        check(add_seen == 1 && seen_a == F64_1 && seen_b == F64_2 && !seen_sub,
              "1.0 + 2.0 was not one binary64 add of the widened values");
        run(ALU_ADD, 1, f(F32_HALF), 1, f(F32_HALF));
        check(res == f(F32_1), "0.5 + 0.5 == 1.0");
        run(ALU_ADD, 1, f(32'h0000_0001), 1, f(32'h0000_0001));
        check(res == f(32'h0000_0002), "subnormal 1 + 1 == 2");
        check(seen_a == F64_F32_MIN_SUB && seen_b == F64_F32_MIN_SUB, "subnormal was not widened");
        run(ALU_ADD, 1, f(F32_M0), 1, f(F32_M0));
        check(res == f(F32_M0) && seen_a == F64_M0, "-0 + -0 == -0");
        run(ALU_SUB, 1, f(F32_3), 1, f(F32_1));
        check(res == f(F32_2) && seen_sub && seen_a == F64_3 && seen_b == F64_1, "3.0 - 1.0 == 2.0");

        // Float compares at accept (both operands already floats).
        run(ALU_LT, 1, f(F32_1), 1, f(F32_2));
        check(kind == AK_BOOL && res == 64'd1, "1.0 < 2.0");
        run(ALU_EQ, 1, f(F32_M0), 1, f(F32_0));
        check(kind == AK_BOOL && res == 64'd1, "-0.0 == 0.0");

        // An int operand is converted first (A_FCONV), then checked and run.
        run(ALU_ADD, 0, i(1), 1, f(F32_HALF));
        check(kind == AK_FLOAT && res == f(F32_1_5), "1 + 0.5 == 1.5");
        check(cycles == fast_add + 1, "a converted operand costs one cycle");
        run(ALU_LT, 1, f(F32_3_5), 0, i(3));
        check(kind == AK_BOOL && res == 64'd0, "3.5 < 3 is False");
        run(ALU_GE, 0, i(-2), 1, f(F32_M2));
        check(kind == AK_BOOL && res == 64'd1, "-2 >= -2.0");
        run(ALU_TDIV, 0, i(1), 0, i(3));
        check(err == AE_NONE && kind == AK_FLOAT && res == f(F32_THIRD), "1 / 3 rounds to nearest");
        run(ALU_TDIV, 0, i(7), 0, i(2));
        check(res == f(F32_3_5), "7 / 2 == 3.5");

        // Float error checks, from accept and from A_FCONV.
        run(ALU_TDIV, 1, f(F32_1), 1, f(F32_0));
        check(err == AE_ZERO_DIV, "1.0 / 0.0 is ZeroDivisionError");
        run(ALU_TDIV, 1, f(F32_1), 0, i(0));
        check(err == AE_ZERO_DIV, "1.0 / 0 is ZeroDivisionError");
        run(ALU_POW, 1, f(F32_0), 1, f(32'hbf80_0000));
        check(err == AE_ZERO_DIV, "0.0 ** -1.0 is ZeroDivisionError");
        run(ALU_POW, 1, f(F32_M2), 1, f(F32_HALF));
        check(err == AE_COMPLEX, "-2.0 ** 0.5 is a complex result");
        run(ALU_POW, 1, f(F32_M2), 1, f(F32_3));
        check(err == AE_NONE && res == f(32'hc100_0000), "-2.0 ** 3.0 == -8.0");
        run(ALU_POW, 1, f(F32_2), 1, f(F32_HALF));
        check(err == AE_NONE && res == f(32'h3fb5_04f3), "2.0 ** 0.5 == 1.4142135");
        run(ALU_POW, 0, i(2), 0, i(-2), 1'b1);
        check(err == AE_NONE && kind == AK_FLOAT && res == f(32'h3e80_0000), "2 ** -2 == 0.25");

        // Conversions.
        run(ALU_I2F, 0, i(-3), 0, i(0));
        check(kind == AK_FLOAT && res == f(32'hc040_0000), "float(-3) == -3.0");
        run(ALU_I2F, 0, i(16777217), 0, i(0));
        check(res == f(32'h4b80_0000), "float(2**24 + 1) rounds to even");
        run(ALU_F2I, 1, f(32'hc060_0000), 0, i(0));
        check(err == AE_NONE && res == i(-3), "int(-3.5) == -3");
        run(ALU_F2I, 1, f(32'h7f80_0000), 0, i(0));
        check(err == AE_FTOI, "int(inf) is an error");

        // Unary float ops answer at accept.
        run(ALU_NEG, 1, f(F32_2), 0, i(0));
        check(kind == AK_FLOAT && res == f(F32_M2), "-(2.0)");
        run(ALU_ABS, 1, f(F32_M0), 0, i(0));
        check(res == f(F32_0), "abs(-0.0) == 0.0");

        $display("PASS mpy_alu %0d checks", checks);
        $finish;
    end
endmodule
