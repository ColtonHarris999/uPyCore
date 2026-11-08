`include "upycore_defs.svh"

// Binary64 floating-point unit for the execute fabric.
//
// Three hardware pipelines do the real arithmetic -- upycore_fp_add
// (add / subtract), upycore_fp_mul and upycore_fp_divrem (divide, fmod) --
// and a small sequencer composes everything else out of them exactly the
// way CPython does in floatobject.c, so the results are bit-identical to
// the host for every operation that is a fixed sequence of IEEE operations:
//
//   ADD SUB MUL TRUE_DIV   one pipeline pass (pass-through, no extra cycle)
//   MOD                    fmod, then the sign fix-up add        (float_rem)
//   FLOOR_DIV              fmod, sub, div, fix-ups, floor        (float_divmod)
//   POWER                  CPython's special cases; x ** +-1, +-2 by
//                          multiply / divide, everything else on the
//                          upycore_fp_pow unit (2 ** (y log2 x); its
//                          header gives the accuracy versus libm pow())
//   NEG POS NOT EQ..GE     combinational, 1 cycle
//
// Complex numbers are not handled here: mpy_alu only issues binary64
// scalars (widened binary32), and complex arithmetic follows
// py/objcomplex.c in firmware, one binary32 operation at a time.
//
// exception_o replaces done_o when the operation ends in a Python
// exception: ZeroDivisionError (x / 0.0, x // 0.0, x % 0.0, 0.0 ** -y,
// OverflowError (finite ** finite overflowing to inf), and the
// one power case the hardware does not implement: a negative base with
// a fractional exponent, which is a complex result in Python.  Division
// by zero is reported in the accept cycle, before any pipeline starts.
//
// Operands are binary64 bit patterns (mpy_alu widens binary32).  Handshake:
// level start_i, one-cycle done_o / exception_o, stall_o = start_i and
// neither; withdrawing start_i aborts (see upycore_umul_seq.sv).
module upycore_fpu #(
    parameter int MUL_STEP = 14,
    parameter int DIV_RL   = 2,
    // Integer exponents with |n| <= POW_CHAIN_MAX use square-and-multiply
    // (n = +-1, +-2: a single multiply / divide, exact to the last rounding);
    // larger ones go through upycore_fp_pow like fractional exponents.
    parameter int POW_CHAIN_MAX = 2
) (
    input  logic         clk_i,
    input  logic         rst_n_i,
    input  logic         start_i,
    input  logic [4:0]   op_i,
    input  logic [63:0]  op_a_i,
    input  logic [63:0]  op_b_i,
    output logic [63:0]  result_o,
    output logic         exception_o,
    output logic         done_o,
    output logic         stall_o,
    output logic         busy_o
);

    // ---------------------------------------------------------------------
    // Primitive pipelines and the shared issue bus
    // ---------------------------------------------------------------------
    logic        u_add_start, u_sub, u_mul_start, u_div_start, u_fmod, u_sqrt, u_pow_start;
    logic [63:0] u_a, u_b;
    logic [63:0] add_res, mul_res, div_res, pow_res;
    logic        add_done, mul_done, div_done, pow_done;
    logic        add_busy, mul_busy, div_busy, pow_busy;
    logic        u_done;
    logic [63:0] u_res;

    upycore_fp_add u_add (
        .clk_i(clk_i), .rst_n_i(rst_n_i),
        .start_i(u_add_start), .sub_i(u_sub),
        .op_a_i(u_a), .op_b_i(u_b),
        .result_o(add_res), .done_o(add_done), .busy_o(add_busy)
    );

    // One significand multiplier (POW_LMW x 53, the wider of the two users)
    // serves both upycore_fp_mul and upycore_fp_pow; the sequencer never has
    // both in flight, so the power unit simply takes the bus while it runs.
    localparam int POW_LMW = 75;
    logic                 sm_start, fm_mul_start, pw_mul_start, sm_done, sm_busy;
    logic [POW_LMW-1:0]   sm_a, pw_mul_a;
    logic [52:0]          sm_b, fm_mul_a, fm_mul_b, pw_mul_b;
    logic [POW_LMW+52:0]  sm_product;

    assign sm_start = u_pow_start ? pw_mul_start : fm_mul_start;
    assign sm_a     = u_pow_start ? pw_mul_a : {{(POW_LMW-53){1'b0}}, fm_mul_a};
    assign sm_b     = u_pow_start ? pw_mul_b : fm_mul_b;

    upycore_umul_seq #(.AW(POW_LMW), .BW(53), .STEP(MUL_STEP)) u_sig_mul (
        .clk_i(clk_i), .rst_n_i(rst_n_i),
        .start_i(sm_start),
        .op_a_i(sm_a), .op_b_i(sm_b),
        .product_o(sm_product), .done_o(sm_done), .busy_o(sm_busy)
    );

    upycore_fp_mul u_mul (
        .clk_i(clk_i), .rst_n_i(rst_n_i),
        .start_i(u_mul_start),
        .op_a_i(u_a), .op_b_i(u_b),
        .result_o(mul_res), .done_o(mul_done), .busy_o(mul_busy),
        .mul_start_o(fm_mul_start), .mul_a_o(fm_mul_a), .mul_b_o(fm_mul_b),
        .mul_product_i(sm_product[105:0]), .mul_done_i(sm_done && !u_pow_start),
        .mul_busy_i(sm_busy && !u_pow_start)
    );

    upycore_fp_divrem #(.RL(DIV_RL)) u_div (
        .clk_i(clk_i), .rst_n_i(rst_n_i),
        .start_i(u_div_start), .fmod_i(u_fmod), .sqrt_i(u_sqrt),
        .op_a_i(u_a), .op_b_i(u_b),
        .result_o(div_res), .done_o(div_done), .busy_o(div_busy)
    );

    upycore_fp_pow #(.LMW(POW_LMW)) u_pow (
        .clk_i(clk_i), .rst_n_i(rst_n_i),
        .start_i(u_pow_start),
        .op_x_i(u_a), .op_y_i(u_b),
        .result_o(pow_res), .done_o(pow_done), .busy_o(pow_busy),
        .mul_start_o(pw_mul_start), .mul_a_o(pw_mul_a), .mul_b_o(pw_mul_b),
        .mul_product_i(sm_product), .mul_done_i(sm_done && u_pow_start)
    );

    assign u_done = add_done | mul_done | div_done | pow_done;
    assign u_res  = add_done ? add_res : (mul_done ? mul_res : (div_done ? div_res : pow_res));

    // ---------------------------------------------------------------------
    // Sequencer state
    // ---------------------------------------------------------------------
    typedef enum logic [5:0] {
        S_IDLE,
        S_DIRECT,                       // scalar add/sub/mul/div pass-through
        S_MOD_FMOD, S_MOD_FIX, S_MOD_ADD,
        S_FD_FMOD, S_FD_SUB, S_FD_DIV, S_FD_FIX, S_FD_SUB1,
        S_FD_FLOORW, S_FD_FLOOR, S_FD_DIFF, S_FD_HALF, S_FD_ADD1,
        S_POW_NORM, S_POW_STEP, S_POW_SQR, S_POW_MUL, S_POW_FIN, S_POW_RECIP, S_POW_INV,
        S_POW_END, S_POW_UNIT, S_POW_SQRT,
        S_DONE, S_EXC
    } state_e;

    state_e       state_r;
    logic [63:0]  t0_r, t1_r, t2_r, t3_r;
    logic [63:0]  pow_n_r;                // exponent bits below the MSB, MSB first
    logic [63:0]  pow_n0_r;               // |exponent| as accepted (for the retry)
    logic [6:0]   pow_cnt_r;              // how many of them remain
    logic         pow_neg_r, pow_recip_r;
    logic [63:0]  res_r;
    // Direct multiply holds the shared multiplier with a register. Reading
    // the multiplier's busy back into this issue block is a combinational
    // loop through u_pow_start, and that loop drops fraction bits.
    logic         mul_run;

    // Operand shorthands.
    logic [63:0] ar, br;
    assign ar = op_a_i;
    assign br = op_b_i;

    // ---------------------------------------------------------------------
    // Accept-cycle decode (state S_IDLE)
    // ---------------------------------------------------------------------
    typedef enum logic [1:0] { K_COMB, K_EXC, K_DIRECT, K_SEQ } kind_e;

    kind_e        dec_kind;
    logic [63:0]  dec_result;
    state_e       dec_next;
    logic         dec_sub;                // DIRECT: subtract
    logic         dec_div;                // DIRECT: divide (else add/mul)
    logic         dec_mul;
    logic         dec_pow_neg, dec_pow_recip;
    logic [63:0]  dec_pow_n;

    logic        a_nan, b_nan, a_inf, b_inf, a_zero, b_zero, b_int;
    logic        a_abs_one, a_abs_gt_one;
    logic        b_odd, b_gt0, b_lt0;
    logic [63:0] a_abs;
    logic        b_trunc_ok;

    assign a_nan  = upycore_f64_is_nan(ar);
    assign b_nan  = upycore_f64_is_nan(br);
    assign a_inf  = upycore_f64_is_inf(ar);
    assign b_inf  = upycore_f64_is_inf(br);
    assign a_zero = upycore_f64_is_zero(ar);
    assign b_zero = upycore_f64_is_zero(br);
    assign a_abs  = {1'b0, ar[62:0]};
    assign a_abs_one    = (a_abs == UPY_F64_ONE);
    assign a_abs_gt_one = upycore_f64_gt(a_abs, UPY_F64_ONE);
    assign b_int  = upycore_f64_is_integer(br);
    assign b_odd  = upycore_f64_is_odd_integer(br);
    assign b_gt0  = upycore_f64_gt(br, UPY_F64_PZERO);
    assign b_lt0  = upycore_f64_lt_zero(br);

    logic [63:0] b_trunc_abs;
    logic        pow_n_small;
    logic [10:0] b_uexp;
    logic [63:0] b_sig;
    // Exponent magnitude directly: converting to signed and taking abs
    // would put two dependent 64-bit negations in the accept path.
    assign b_uexp = br[62:52] - 11'd1023;
    assign b_sig = {11'd0, 1'b1, br[51:0]};
    assign b_trunc_ok = (br[62:52] != 11'h7ff) &&
                        ((br[62:52] < 11'd1023) || (b_uexp < 11'd63));
    assign b_trunc_abs = !b_trunc_ok || (br[62:52] < 11'd1023) ? 64'd0 :
                         (b_uexp < 11'd52) ? b_sig >> (11'd52 - b_uexp) :
                                            b_sig << (b_uexp - 11'd52);
    assign pow_n_small = (b_trunc_abs <= 64'(POW_CHAIN_MAX));

    always_comb begin
        dec_kind      = K_EXC;
        dec_result    = '0;
        dec_next      = S_IDLE;
        dec_sub       = 1'b0;
        dec_div       = 1'b0;
        dec_mul       = 1'b0;
        dec_pow_neg   = 1'b0;
        dec_pow_recip = 1'b0;
        dec_pow_n     = '0;

        unique case (op_i)
            UPY_ALU_ADD: begin dec_kind = K_DIRECT; end
            UPY_ALU_SUB: begin dec_kind = K_DIRECT; dec_sub = 1'b1; end
            UPY_ALU_MUL: begin dec_kind = K_DIRECT; dec_mul = 1'b1; end
            UPY_ALU_TRUE_DIV: begin
                dec_kind = b_zero ? K_EXC : K_DIRECT;
                dec_div  = 1'b1;
            end
            UPY_ALU_MOD: begin
                dec_kind = b_zero ? K_EXC : K_SEQ;
                dec_next = S_MOD_FMOD;
            end
            UPY_ALU_FLOOR_DIV: begin
                dec_kind = b_zero ? K_EXC : K_SEQ;
                dec_next = S_FD_FMOD;
            end
            UPY_ALU_POWER: begin
                // CPython float_pow(), special cases first.
                dec_kind = K_COMB;
                if (b_zero) begin
                    dec_result = UPY_F64_ONE;
                end else if (a_nan) begin
                    dec_result = ar;
                end else if (b_nan) begin
                    dec_result = (ar == UPY_F64_ONE) ? UPY_F64_ONE : br;
                end else if (b_inf) begin
                    if (a_abs_one)                     dec_result = UPY_F64_ONE;
                    else if (b_gt0 == a_abs_gt_one)    dec_result = UPY_F64_PINF;
                    else                               dec_result = UPY_F64_PZERO;
                end else if (a_inf) begin
                    if (b_gt0) dec_result = b_odd ? ar : a_abs;
                    else       dec_result = b_odd ? {ar[63], 63'd0} : UPY_F64_PZERO;
                end else if (a_zero) begin
                    if (b_lt0) dec_kind = K_EXC;                 // ZeroDivisionError
                    else       dec_result = b_odd ? ar : UPY_F64_PZERO;
                end else if (!b_int && ar[63]) begin
                    dec_kind = K_EXC;   // complex result in Python: not in hardware
                end else if (a_abs_one) begin
                    dec_result = (ar[63] && b_odd) ? UPY_F64_NONE : UPY_F64_ONE;
                end else if (br == UPY_F64_HALF) begin
                    // x ** 0.5: correctly rounded square root on the divider
                    dec_kind = K_SEQ;
                    dec_next = S_POW_SQRT;
                end else if (b_int && b_trunc_ok && pow_n_small) begin
                    // x ** n, |n| <= POW_CHAIN_MAX: square-and-multiply
                    dec_kind      = K_SEQ;
                    dec_next      = S_POW_NORM;
                    dec_pow_neg   = ar[63] && b_odd;
                    dec_pow_recip = b_lt0;
                    dec_pow_n     = b_trunc_abs;
                end else begin
                    // fractional, large or non-int64 exponent: 2 ** (y log2 |x|)
                    dec_kind      = K_SEQ;
                    dec_next      = S_POW_UNIT;
                    dec_pow_neg   = ar[63] && b_odd;
                end
            end
            UPY_ALU_NEG: begin
                dec_kind   = K_COMB;
                dec_result = {~ar[63], ar[62:0]};
            end
            UPY_ALU_POS, UPY_ALU_PASS: begin
                dec_kind   = K_COMB;
                dec_result = ar;
            end
            UPY_ALU_NOT: begin
                dec_kind   = K_COMB;
                dec_result = {63'd0, a_zero};
            end
            UPY_ALU_EQ, UPY_ALU_NE, UPY_ALU_LT, UPY_ALU_LE, UPY_ALU_GT, UPY_ALU_GE: begin
                dec_kind   = K_COMB;
                dec_result = {63'd0, upycore_f64_compare_op(op_i, ar, br)};
            end
            default: begin
                dec_kind = K_EXC;
            end
        endcase
    end

    // ---------------------------------------------------------------------
    // Issue logic: which primitive runs in the current state, on what
    // ---------------------------------------------------------------------
    always_comb begin
        u_add_start = 1'b0;
        u_sub       = 1'b0;
        u_mul_start = 1'b0;
        u_div_start = 1'b0;
        u_fmod      = 1'b0;
        u_sqrt      = 1'b0;
        u_pow_start = 1'b0;
        u_a         = ar;
        u_b         = br;

        unique case (state_r)
            S_IDLE: begin
                // Scalar add/sub/mul/div start in the accept cycle itself.
                if (start_i && dec_kind == K_DIRECT) begin
                    u_add_start = !dec_mul && !dec_div;
                    u_sub       = dec_sub;
                    u_mul_start = dec_mul;
                    u_div_start = dec_div;
                end
            end
            S_DIRECT: begin
                u_add_start = add_busy;
                u_sub       = (op_i == UPY_ALU_SUB);
                u_mul_start = mul_run;
                u_div_start = div_busy;
            end

            // ---- float % ----
            S_MOD_FMOD: begin u_div_start = 1'b1; u_fmod = 1'b1; end
            S_MOD_ADD:  begin u_add_start = 1'b1; u_a = t0_r; u_b = br; end

            // ---- float // ----
            S_FD_FMOD:  begin u_div_start = 1'b1; u_fmod = 1'b1; end
            S_FD_SUB:   begin u_add_start = 1'b1; u_sub = 1'b1; u_a = ar; u_b = t0_r; end
            S_FD_DIV:   begin u_div_start = 1'b1; u_a = t1_r; u_b = br; end
            S_FD_SUB1:  begin u_add_start = 1'b1; u_sub = 1'b1; u_a = t1_r; u_b = UPY_F64_ONE; end
            S_FD_DIFF:  begin u_add_start = 1'b1; u_sub = 1'b1; u_a = t1_r; u_b = t2_r; end
            S_FD_ADD1:  begin u_add_start = 1'b1; u_a = t2_r; u_b = UPY_F64_ONE; end

            // ---- float ** (t0 = acc, t1 = base) ----
            S_POW_SQR:   begin u_mul_start = 1'b1; u_a = t0_r; u_b = t0_r; end
            S_POW_MUL:   begin u_mul_start = 1'b1; u_a = t0_r; u_b = t1_r; end
            S_POW_RECIP: begin u_div_start = 1'b1; u_a = UPY_F64_ONE; u_b = t0_r; end
            S_POW_INV:   begin u_div_start = 1'b1; u_a = UPY_F64_ONE; u_b = t1_r; end
            S_POW_UNIT:  begin u_pow_start = 1'b1; u_a = a_abs; u_b = br; end
            S_POW_SQRT:  begin u_div_start = 1'b1; u_sqrt = 1'b1; u_a = a_abs; end

            default: ;
        endcase
    end

    // ---------------------------------------------------------------------
    // Sequencer
    // ---------------------------------------------------------------------
    logic        mod_fix_add;             // (b < 0) != (mod < 0), mod != 0
    logic        fd_div_nonzero;
    logic        fd_half_up;
    logic [63:0] fd_floor;
    logic        pow_overflow;
    logic [6:0]  pow_lz;

    assign mod_fix_add    = !upycore_f64_eq(t0_r, UPY_F64_PZERO) &&
                            (b_lt0 != upycore_f64_lt_zero(t0_r));
    assign fd_div_nonzero = !upycore_f64_eq(t1_r, UPY_F64_PZERO);
    assign fd_floor       = upycore_f64_floor(t1_r);
    assign fd_half_up     = upycore_f64_gt(t3_r, UPY_F64_HALF);
    assign pow_overflow   = upycore_f64_is_inf(t0_r);
    assign pow_lz         = upycore_clz64(pow_n_r);

    // floor(t1_r) takes its own cycle. S_FD_FLOOR is entered from S_FD_FIX,
    // which does not write t1_r, or through S_FD_FLOORW after S_FD_SUB1 did.
    logic [63:0] fd_floor_r;
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) fd_floor_r <= '0;
        else          fd_floor_r <= fd_floor;
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            state_r     <= S_IDLE;
            t0_r <= '0; t1_r <= '0; t2_r <= '0; t3_r <= '0;
            pow_n_r     <= '0;
            pow_n0_r    <= '0;
            pow_cnt_r   <= '0;
            pow_neg_r   <= 1'b0;
            pow_recip_r <= 1'b0;
            res_r       <= '0;
            mul_run     <= 1'b0;
        end else if (!start_i) begin
            state_r <= S_IDLE;
            mul_run <= 1'b0;
        end else begin
            unique case (state_r)
                S_IDLE: begin
                    if (dec_kind == K_DIRECT) begin
                        state_r <= S_DIRECT;
                        mul_run <= dec_mul;
                    end else if (dec_kind == K_SEQ) begin
                        state_r     <= dec_next;
                        pow_neg_r   <= dec_pow_neg;
                        pow_recip_r <= dec_pow_recip;
                        pow_n_r     <= dec_pow_n;
                        pow_n0_r    <= dec_pow_n;
                        t0_r        <= UPY_F64_ONE;        // pow accumulator
                        t1_r        <= a_abs;             // pow base
                    end
                    // K_COMB / K_EXC complete in this cycle.
                end
                S_DIRECT: begin
                    if (u_done) begin
                        state_r <= S_IDLE;
                        mul_run <= 1'b0;
                    end
                end

                // ---- float % : CPython float_rem ----
                S_MOD_FMOD: if (u_done) begin t0_r <= u_res; state_r <= S_MOD_FIX; end
                S_MOD_FIX: begin
                    if (mod_fix_add) begin
                        state_r <= S_MOD_ADD;
                    end else begin
                        res_r   <= upycore_f64_eq(t0_r, UPY_F64_PZERO)
                                   ? {br[63], 63'd0} : t0_r;
                        state_r <= S_DONE;
                    end
                end
                S_MOD_ADD: if (u_done) begin res_r <= u_res; state_r <= S_DONE; end

                // ---- float // : CPython float_divmod ----
                S_FD_FMOD: if (u_done) begin t0_r <= u_res; state_r <= S_FD_SUB; end
                S_FD_SUB:  if (u_done) begin t1_r <= u_res; state_r <= S_FD_DIV; end
                S_FD_DIV:  if (u_done) begin t1_r <= u_res; state_r <= S_FD_FIX; end
                S_FD_FIX:  state_r <= mod_fix_add ? S_FD_SUB1 : S_FD_FLOOR;
                // fd_floor_r is floor(t1_r) one cycle late, so after this
                // write it needs a cycle before S_FD_FLOOR reads it.
                S_FD_SUB1: if (u_done) begin t1_r <= u_res; state_r <= S_FD_FLOORW; end
                S_FD_FLOORW: state_r <= S_FD_FLOOR;
                S_FD_FLOOR: begin
                    if (fd_div_nonzero) begin
                        t2_r    <= fd_floor_r;
                        state_r <= S_FD_DIFF;
                    end else begin
                        res_r   <= {ar[63] ^ br[63], 63'd0};
                        state_r <= S_DONE;
                    end
                end
                S_FD_DIFF: if (u_done) begin t3_r <= u_res; state_r <= S_FD_HALF; end
                S_FD_HALF: begin
                    if (fd_half_up) begin
                        state_r <= S_FD_ADD1;
                    end else begin
                        res_r   <= t2_r;
                        state_r <= S_DONE;
                    end
                end
                S_FD_ADD1: if (u_done) begin res_r <= u_res; state_r <= S_DONE; end

                // ---- float ** : MSB-first square-and-multiply ----
                S_POW_NORM: begin
                    // acc = base; the exponent's leading one is consumed by
                    // that, the remaining bits are walked high to low.
                    t0_r      <= t1_r;
                    pow_n_r   <= pow_n_r << (pow_lz + 7'd1);
                    pow_cnt_r <= 7'd63 - pow_lz;
                    state_r   <= S_POW_STEP;
                end
                S_POW_STEP: state_r <= (pow_cnt_r == 7'd0) ? S_POW_FIN : S_POW_SQR;
                S_POW_SQR: if (u_done) begin
                    t0_r <= u_res;
                    if (pow_n_r[63]) begin
                        state_r <= S_POW_MUL;
                    end else begin
                        pow_n_r   <= pow_n_r << 1;
                        pow_cnt_r <= pow_cnt_r - 7'd1;
                        state_r   <= S_POW_STEP;
                    end
                end
                S_POW_MUL: if (u_done) begin
                    t0_r      <= u_res;
                    pow_n_r   <= pow_n_r << 1;
                    pow_cnt_r <= pow_cnt_r - 7'd1;
                    state_r   <= S_POW_STEP;
                end
                S_POW_FIN: begin
                    // x ** -n: 1 / x**n, unless x**n overflowed -- then the
                    // true result is tiny or subnormal and is recomputed as
                    // (1/|x|) ** n, which cannot overflow (|x| > 1 here).
                    if (!pow_recip_r)      state_r <= S_POW_END;
                    else if (pow_overflow) state_r <= S_POW_INV;
                    else                   state_r <= S_POW_RECIP;
                end
                S_POW_RECIP: if (u_done) begin t0_r <= u_res; state_r <= S_POW_END; end
                S_POW_INV: if (u_done) begin
                    t1_r        <= u_res;
                    pow_n_r     <= pow_n0_r;
                    pow_recip_r <= 1'b0;
                    state_r     <= S_POW_NORM;
                end
                S_POW_END: begin
                    if (pow_overflow) begin
                        state_r <= S_EXC;                 // OverflowError
                    end else begin
                        res_r   <= {t0_r[63] ^ pow_neg_r, t0_r[62:0]};
                        state_r <= S_DONE;
                    end
                end
                // ---- float ** : |x| ** y on the log / exp unit ----
                S_POW_UNIT: if (u_done) begin t0_r <= u_res; state_r <= S_POW_END; end
                // ---- float ** 0.5 : sqrt on the divider ----
                S_POW_SQRT: if (u_done) begin t0_r <= u_res; state_r <= S_POW_END; end

                S_DONE, S_EXC: state_r <= S_IDLE;
                default:       state_r <= S_IDLE;
            endcase
        end
    end

    // ---------------------------------------------------------------------
    // Outputs
    // ---------------------------------------------------------------------
    always_comb begin
        result_o    = res_r;
        done_o      = 1'b0;
        exception_o = 1'b0;
        unique case (state_r)
            S_IDLE: begin
                if (start_i) begin
                    unique case (dec_kind)
                        K_COMB: begin done_o = 1'b1; result_o = dec_result; end
                        K_EXC:  exception_o = 1'b1;
                        default: ;
                    endcase
                end
            end
            S_DIRECT: begin
                done_o   = u_done;
                result_o = u_res;
            end
            S_DONE: done_o = 1'b1;
            S_EXC:  exception_o = 1'b1;
            default: ;
        endcase
    end

    assign stall_o = start_i && !done_o && !exception_o;
    assign busy_o  = (state_r != S_IDLE);

endmodule
