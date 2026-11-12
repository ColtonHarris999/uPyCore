`include "upycore_defs.svh"

// Scalar number unit for mpy_core (upycore/docs/mpy_core.md, "ALU").
//
// One operation per start_i pulse; done_o pulses when res_o, rkind_o and
// err_o are valid. Operands are 64-bit: a signed integer (INT, INT64 and
// bool all reach here as int64) or a binary32 in [31:0] when the matching
// *_flt_i is set. Ops are the bytecode binary op numbers (py/runtime0.h,
// in-place forms already folded onto the plain ones) and ALU_NEG..ALU_F2I.
//
// Integer semantics follow the oracle's 32-bit longlong build:
//   + - * << overflowing int64          err OVERFLOW
//   // and % with both operands in the 31-bit small-int range round toward
//   minus infinity; otherwise they truncate, as C long long does
//   ** with a negative exponent, and /, are float operations
// Floats are binary32: each operand is widened to binary64, upycore_fpu
// runs the operation once, and the result is rounded back. That is exact
// for + - * /, fmod and the comparisons; ** may differ from powf in the
// last bit. A float ** that overflows gives inf, as powf does.
// A negative base with a fractional exponent reports err COMPLEX so the
// firmware can build the complex result.
//
// Timing: the FPU's binary64 result is registered (A_FNAR) before it is
// rounded back to binary32. An op that converts an int operand checks
// the converted value in A_FCONV. Integer conversion takes
// magnitude, normalize and round stages before A_FCONV checks the result.

// verilator lint_off DECLFILENAME
package mpy_alu_pkg;
    localparam logic [5:0] ALU_LT      = 6'd0;
    localparam logic [5:0] ALU_GT      = 6'd1;
    localparam logic [5:0] ALU_EQ      = 6'd2;
    localparam logic [5:0] ALU_LE      = 6'd3;
    localparam logic [5:0] ALU_GE      = 6'd4;
    localparam logic [5:0] ALU_NE      = 6'd5;
    localparam logic [5:0] ALU_OR      = 6'd22;
    localparam logic [5:0] ALU_XOR     = 6'd23;
    localparam logic [5:0] ALU_AND     = 6'd24;
    localparam logic [5:0] ALU_LSHIFT  = 6'd25;
    localparam logic [5:0] ALU_RSHIFT  = 6'd26;
    localparam logic [5:0] ALU_ADD     = 6'd27;
    localparam logic [5:0] ALU_SUB     = 6'd28;
    localparam logic [5:0] ALU_MUL     = 6'd29;
    localparam logic [5:0] ALU_MATMUL  = 6'd30;
    localparam logic [5:0] ALU_FLOOR   = 6'd31;
    localparam logic [5:0] ALU_TDIV    = 6'd32;
    localparam logic [5:0] ALU_MOD     = 6'd33;
    localparam logic [5:0] ALU_POW     = 6'd34;
    localparam logic [5:0] ALU_NEG     = 6'd40;
    localparam logic [5:0] ALU_POS     = 6'd41;
    localparam logic [5:0] ALU_INVERT  = 6'd42;
    localparam logic [5:0] ALU_ABS     = 6'd43;
    localparam logic [5:0] ALU_I2F     = 6'd44;
    localparam logic [5:0] ALU_F2I     = 6'd45;

    localparam logic [1:0] AK_INT   = 2'd0;
    localparam logic [1:0] AK_FLOAT = 2'd1;
    localparam logic [1:0] AK_BOOL  = 2'd3;

    localparam logic [2:0] AE_NONE        = 3'd0;
    localparam logic [2:0] AE_ZERO_DIV    = 3'd1;
    localparam logic [2:0] AE_OVERFLOW    = 3'd2;
    localparam logic [2:0] AE_NEG_SHIFT   = 3'd3;
    localparam logic [2:0] AE_UNSUPPORTED = 3'd4;
    localparam logic [2:0] AE_COMPLEX     = 3'd5;
    localparam logic [2:0] AE_FTOI        = 3'd6;

    // Round a normalized integer magnitude. Leading one is at bit 63;
    // only the 24 retained bits take part in the rounding carry chain.
    function automatic logic [31:0] mpy_i64_round(
        input logic sign, input logic zero,
        input logic [5:0] lz, input logic [63:0] norm);
        logic [24:0] rounded;
        logic [7:0] exp;
        begin
            rounded = {1'b0, norm[63:40]} +
                      {24'd0, norm[39] && ((|norm[38:0]) || norm[40])};
            exp = 8'd190 - {2'd0, lz} + {7'd0, rounded[24]};
            mpy_i64_round = zero ? 32'd0 :
                {sign, exp, rounded[24] ? rounded[23:1] : rounded[22:0]};
        end
    endfunction

    // binary32 -> |int64| toward zero (the caller negates for a negative
    // f, in its own cycle). ok = 0 for NaN, inf, and |f| >= 2**63.
    function automatic logic [63:0] mpy_f32_to_i64(input logic [31:0] f, output logic ok);
        logic [7:0]  e;
        logic [63:0] m;
        int          x;
        begin
            e = f[30:23];
            ok = 1'b1;
            mpy_f32_to_i64 = 64'd0;
            if (e == 8'hFF) begin
                ok = 1'b0;
            end else if (e >= 8'd127) begin
                x = int'(e) - 127;
                if (x >= 63) begin
                    ok = 1'b0;
                end else begin
                    m = {40'd0, 1'b1, f[22:0]};
                    if (x >= 23) m = m << (x - 23);
                    else m = m >> (23 - x);
                    mpy_f32_to_i64 = m;
                end
            end
        end
    endfunction

    function automatic logic mpy_f32_nan(input logic [31:0] f);
        mpy_f32_nan = (f[30:23] == 8'hFF) && (f[22:0] != 23'd0);
    endfunction

    function automatic logic mpy_f32_zero(input logic [31:0] f);
        mpy_f32_zero = (f[30:0] == 31'd0);
    endfunction

    // a < b with IEEE semantics (NaN compares false, -0 == +0).
    function automatic logic mpy_f32_lt(input logic [31:0] a, input logic [31:0] b);
        if (mpy_f32_nan(a) || mpy_f32_nan(b) || (mpy_f32_zero(a) && mpy_f32_zero(b)))
            mpy_f32_lt = 1'b0;
        else if (a[31] != b[31])
            mpy_f32_lt = a[31];
        else if (!a[31])
            mpy_f32_lt = a[30:0] < b[30:0];
        else
            mpy_f32_lt = a[30:0] > b[30:0];
    endfunction

    function automatic logic mpy_f32_eq(input logic [31:0] a, input logic [31:0] b);
        mpy_f32_eq = !mpy_f32_nan(a) && !mpy_f32_nan(b) &&
                     ((a == b) || (mpy_f32_zero(a) && mpy_f32_zero(b)));
    endfunction

    // An integral binary32 (including the infinities' neighbours).
    // The shift stays in the comparison. A separate mask assignment is
    // moved after its use by Verilator -O3, which then sees a zero mask.
    function automatic logic mpy_f32_integral(input logic [31:0] f);
        logic [7:0] e;
        begin
            e = f[30:23];
            if (e == 8'hFF) mpy_f32_integral = 1'b0;
            else if (e >= 8'd150) mpy_f32_integral = 1'b1;
            else if (e < 8'd127) mpy_f32_integral = (f[30:0] == 31'd0);
            else mpy_f32_integral = (f[22:0] & (23'h7FFFFF >> (e - 8'd127))) == 23'd0;
        end
    endfunction

    // An odd integral binary32.
    function automatic logic mpy_f32_odd(input logic [31:0] f);
        logic [7:0] e;
        begin
            e = f[30:23];
            if (!mpy_f32_integral(f) || e < 8'd127 || e > 8'd150) mpy_f32_odd = 1'b0;
            else if (e == 8'd127) mpy_f32_odd = 1'b1;
            else mpy_f32_odd = f[5'(8'd150 - e)];
        end
    endfunction

endpackage
// verilator lint_on DECLFILENAME

// Widen binary32 to binary64 with wires. The subnormal shift used to live
// in a function whose blocking assignments Verilator -O3 reordered.
module mpy_f32_widen (
    input  logic [31:0] f_i,
    output logic [63:0] d_o
);
    logic        sign;
    logic [7:0]  exp;
    logic [22:0] frac;
    logic [4:0]  sh;
    logic [22:0] shifted;

    assign sign = f_i[31];
    assign exp  = f_i[30:23];
    assign frac = f_i[22:0];
    // Leading zeros of frac[22:1] (22 when they are all zero), as the
    // shared tree; the 22-step priority select was st -> fb64_r at 10.2 ns.
    assign sh = 5'(upycore_clz64({frac[22:1], 1'b1, 41'd0}));
    assign shifted = frac << sh;

    always_comb begin
        if (exp == 8'hFF) begin
            d_o = (frac == 23'b0) ? {sign, 11'h7FF, 52'b0}
                                  : {sign, 11'h7FF, frac, 29'b0};
        end else if (exp == 8'h00 && frac == 23'b0) begin
            d_o = {sign, 63'b0};
        end else if (exp == 8'h00) begin
            d_o = {sign, 11'd896 - {6'b0, sh}, shifted[21:0], 30'b0};
        end else begin
            d_o = {sign, ({3'b0, exp} + 11'd896), frac, 29'b0};
        end
    end
endmodule

// Narrow binary64 to binary32 with wires, not a function. Verilator -O3
// schedules a function's blocking assignments after the expression that
// reads them, so the fraction was added after it had already been used.
module mpy_f32_narrow (
    input  logic [63:0] d_i,
    output logic [31:0] q_o,
    // A subnormal result takes two steps: the sticky shift's output goes
    // out (jam_o), the caller registers it and gives it back (jam_i) for
    // the rounding add, and sub_o says the result is that case. (Shift,
    // add and the result select in one step were fres_r -> alu_res at
    // 11.6 ns.) Every other result does not use jam_i.
    output logic [54:0] jam_o,
    input  logic [54:0] jam_i,
    output logic        sub_o
);
    logic               sign;
    logic [10:0]        exp;
    logic [51:0]        frac;
    logic signed [12:0] exp32;
    logic               round_up;
    logic [23:0]        sumf;
    logic [52:0]        sig;
    logic [11:0]        sh;
    logic [54:0]        jam [0:6];
    logic [23:0]        mag;

    assign sign     = d_i[63];
    assign exp      = d_i[62:52];
    assign frac     = d_i[51:0];
    assign exp32    = $signed({2'b0, exp}) - 13'sd896;
    assign round_up = d_i[28] && (|d_i[27:0] || d_i[29]);
    assign sumf     = {1'b0, d_i[51:29]} + {23'b0, round_up};
    assign sig      = {1'b1, frac};
    assign sh       = 12'd926 - {1'b0, exp};
    // Shift right with sticky (jammed into bit 0) at each mux level.
    // This replaces a variable mask followed by a 53-bit subtract. Bits
    // [24:2] retain the fraction, [1] is guard, [0] is sticky.
    assign jam[0] = {sig, 2'b00};
    for (genvar k = 0; k < 6; k++) begin : gen_jam
        localparam int S = 1 << k;
        assign jam[k+1] = sh[k] ?
            { {S{1'b0}}, jam[k][54:S+1], (|jam[k][S:0]) } : jam[k];
    end
    assign jam_o = jam[6];
    assign mag = {1'b0, jam_i[24:2]} +
                 {23'd0, jam_i[1] && (jam_i[0] || jam_i[2])};
    assign sub_o = !(exp == 11'h7FF) && !(d_i[62:0] == 63'b0 || exp == 11'b0) &&
                   !(exp32 >= 13'sd1) && !(sh >= 12'd53);

    always_comb begin
        if (exp == 11'h7FF) begin
            q_o = (frac == 52'b0) ? {sign, 8'hFF, 23'b0} : {sign, 8'hFF, 1'b1, 22'b0};
        end else if (d_i[62:0] == 63'b0 || exp == 11'b0) begin
            q_o = {sign, 31'b0};
        end else if (exp32 >= 13'sd255) begin
            q_o = {sign, 8'hFF, 23'b0};
        end else if (exp32 >= 13'sd1) begin
            q_o = sumf[23] ? ((exp32 >= 13'sd254) ? {sign, 8'hFF, 23'b0}
                                                  : {sign, exp32[7:0] + 8'd1, 23'b0})
                           : {sign, exp32[7:0], sumf[22:0]};
        end else if (sh >= 12'd54) begin
            q_o = {sign, 31'b0};
        end else if (sh == 12'd53) begin
            q_o = {sign, 8'b0, 22'b0, sig[52] && (|sig[51:0])};
        end else begin
            q_o = mag[23] ? {sign, 8'd1, 23'b0} : {sign, 8'b0, mag[22:0]};
        end
    end
endmodule

module mpy_alu (
    input  logic        clk_i,
    input  logic        rst_n_i,
    input  logic        start_i,
    input  logic [5:0]  op_i,
    input  logic        a_flt_i,
    input  logic        b_flt_i,
    input  logic [63:0] a_i,
    input  logic [63:0] b_i,
    // Both integer operands are in the oracle's 31-bit small-int range.
    input  logic        small_i,
    output logic        done_o,
    output logic [63:0] res_o,
    output logic [1:0]  rkind_o,
    output logic [2:0]  err_o
);
    import mpy_alu_pkg::*;

    typedef enum logic [3:0] { A_IDLE, A_MUL, A_DIV, A_POW, A_FPU, A_FNAR, A_FCONV, A_DONE, A_INORM, A_IROUND, A_FNAR2, A_FERR, A_F2I } astate_e;
    astate_e st;

    logic [5:0]  op;
    logic        small_r;
    logic [63:0] a, b;
    logic [31:0] fa, fb;
    logic [63:0] fa64, fb64, fa64_r, fb64_r;

    // Conversion pipeline: magnitude at accept, normalization next,
    // then a 24-bit rounding add. Neither sign correction nor rounding
    // shares a cycle with the leading-zero encoder and barrel shifter.
    logic [63:0] amag, bmag, anorm, bnorm;
    logic [5:0] alz, blz;
    logic azero, bzero, aflt, bflt;
    logic [31:0] aconv, bconv;
    assign aconv = mpy_i64_round(a[63], azero, alz, anorm);
    assign bconv = mpy_i64_round(b[63], bzero, blz, bnorm);

    // Integer datapath (combinational ops).
    // iop is the integer unit's code for op, registered wherever op is
    // (iop_of): decoded from op in the cycle the unit answers it led the
    // 64-bit subtract into res_o (op -> alu_res, 9.9 ns).
    logic [4:0]  iop;
    logic [63:0] ires;
    logic        izero, iovf, iverr;
    function automatic logic [4:0] iop_of(input logic [5:0] o);
        case (o)
            ALU_ADD:    iop_of = UPY_ALU_ADD;
            ALU_SUB:    iop_of = UPY_ALU_SUB;
            ALU_AND:    iop_of = UPY_ALU_AND;
            ALU_OR:     iop_of = UPY_ALU_OR;
            ALU_XOR:    iop_of = UPY_ALU_XOR;
            ALU_LSHIFT: iop_of = UPY_ALU_LSHIFT;
            ALU_RSHIFT: iop_of = UPY_ALU_RSHIFT;
            ALU_LT:     iop_of = UPY_ALU_LT;
            ALU_GT:     iop_of = UPY_ALU_GT;
            ALU_EQ:     iop_of = UPY_ALU_EQ;
            ALU_LE:     iop_of = UPY_ALU_LE;
            ALU_GE:     iop_of = UPY_ALU_GE;
            ALU_NE:     iop_of = UPY_ALU_NE;
            ALU_NEG:    iop_of = UPY_ALU_NEG;
            ALU_INVERT: iop_of = UPY_ALU_INVERT;
            default:    iop_of = UPY_ALU_PASS;
        endcase
    endfunction
`ifdef MPY_CHECK
    always_ff @(posedge clk_i)
        if (rst_n_i && iop != iop_of(op)) $error("mpy_alu: iop is not the code of op %0d", op);
`endif
    upycore_int_alu u_int (
        .op_a_i(a), .op_b_i(b), .op_i(iop),
        .result_o(ires), .zero_flag_o(izero), .overflow_flag_o(iovf), .value_error_o(iverr)
    );

    // Multiplier, shared by * and the power sequencer.
    logic        pow_mul_start;
    logic [63:0] mul_a, mul_b, pow_mul_a, pow_mul_b, mul_lo, mul_hi;
    logic        mul_done, mul_stall, mul_busy;
    assign mul_a = (st == A_POW) ? pow_mul_a : a;
    assign mul_b = (st == A_POW) ? pow_mul_b : b;
    upycore_mul u_mul (
        .clk_i(clk_i), .rst_n_i(rst_n_i),
        .start_i((st == A_MUL) || ((st == A_POW) && pow_mul_start)),
        .op_a_i(mul_a), .op_b_i(mul_b),
        .result_o(mul_lo), .result_hi_o(mul_hi),
        .done_o(mul_done), .stall_o(mul_stall), .busy_o(mul_busy)
    );

    logic [63:0] pow_res;
    logic        pow_trap, pow_done, pow_stall, pow_busy;
    upycore_ipow u_pow (
        .clk_i(clk_i), .rst_n_i(rst_n_i), .start_i(st == A_POW),
        .base_i(a), .exp_i(b),
        .mul_start_o(pow_mul_start), .mul_a_o(pow_mul_a), .mul_b_o(pow_mul_b),
        .mul_lo_i(mul_lo), .mul_hi_i(mul_hi), .mul_done_i(mul_done),
        .result_o(pow_res), .trap_o(pow_trap), .done_o(pow_done),
        .stall_o(pow_stall), .busy_o(pow_busy)
    );

    logic [63:0] quot, rem;
    logic        div_zero, div_done, div_stall, div_busy;
    upycore_div u_div (
        .clk_i(clk_i), .rst_n_i(rst_n_i), .start_i(st == A_DIV),
        .op_a_i(a), .op_b_i(b),
        .quot_o(quot), .rem_o(rem), .div_zero_o(div_zero),
        .done_o(div_done), .stall_o(div_stall), .busy_o(div_busy)
    );

    // Float unit in binary64.
    logic [4:0]   fop;
    logic [63:0]  fres;
    logic [31:0]  fnarrow;
    logic [63:0]  fres_r;
    logic         fexc, fdone, fstall, fbusy;
    always_comb begin
        case (op)
            ALU_ADD:   fop = UPY_ALU_ADD;
            ALU_SUB:   fop = UPY_ALU_SUB;
            ALU_MUL:   fop = UPY_ALU_MUL;
            ALU_TDIV:  fop = UPY_ALU_TRUE_DIV;
            ALU_FLOOR: fop = UPY_ALU_FLOOR_DIV;
            ALU_MOD:   fop = UPY_ALU_MOD;
            ALU_POW:   fop = UPY_ALU_POWER;
            default:   fop = UPY_ALU_PASS;
        endcase
    end
    upycore_fpu u_fpu (
        .clk_i(clk_i), .rst_n_i(rst_n_i), .start_i(st == A_FPU),
        .op_i(fop),
        .op_a_i(fa64_r), .op_b_i(fb64_r),
        .result_o(fres), .exception_o(fexc), .done_o(fdone), .stall_o(fstall), .busy_o(fbusy)
    );
    logic [54:0] nar_jam, nar_jam_r;
    logic        nar_sub;
    mpy_f32_narrow u_narrow (.d_i(fres_r), .q_o(fnarrow), .jam_o(nar_jam), .jam_i(nar_jam_r), .sub_o(nar_sub));
    always_ff @(posedge clk_i or negedge rst_n_i)
        if (!rst_n_i) nar_jam_r <= '0;
        else nar_jam_r <= nar_jam;

    // Float compare and issue checks. At accept they read the operands
    // directly, which is only done when both are already floats; an op
    // that converts an int operand decides in A_FCONV from fa / fb, so the
    // int-to-float conversion and these checks are never in one cycle.
    logic [5:0]  dop;
    logic [31:0] dxa, dxb;
    logic        f_cmp, f_fpu;
    logic [2:0]  f_err;
    assign dop = (st == A_FCONV) ? op : op_i;
    assign dxa = (st == A_FCONV) ? fa : a_i[31:0];
    assign dxb = (st == A_FCONV) ? fb : b_i[31:0];
    always_comb begin
        case (dop)
            ALU_LT:  f_cmp = mpy_f32_lt(dxa, dxb);
            ALU_GT:  f_cmp = mpy_f32_lt(dxb, dxa);
            ALU_LE:  f_cmp = mpy_f32_lt(dxa, dxb) || mpy_f32_eq(dxa, dxb);
            ALU_GE:  f_cmp = mpy_f32_lt(dxb, dxa) || mpy_f32_eq(dxa, dxb);
            ALU_EQ:  f_cmp = mpy_f32_eq(dxa, dxb);
            default: f_cmp = !mpy_f32_eq(dxa, dxb);
        endcase
        f_err = AE_NONE;
        case (dop)
            ALU_ADD, ALU_SUB, ALU_MUL: ;
            ALU_TDIV, ALU_FLOOR, ALU_MOD:
                if (mpy_f32_zero(dxb)) f_err = AE_ZERO_DIV;
            ALU_POW: ;   // checked in A_FERR
            default: f_err = AE_UNSUPPORTED;
        endcase
        f_fpu = (f_err == AE_NONE);
    end

    // The FPU's operands are widened to binary64 in the cycle that decides
    // the op and registered, so the widening and the FPU's accept decode
    // (which can finish an op combinationally) never share a cycle.
    mpy_f32_widen u_wa (.f_i(dxa), .d_o(fa64));
    mpy_f32_widen u_wb (.f_i(dxb), .d_o(fb64));

    // Accept: everything that finishes in one cycle is answered here.
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            st <= A_IDLE;
            done_o <= 1'b0;
            res_o <= '0;
            rkind_o <= AK_INT;
            err_o <= AE_NONE;
            amag <= '0; bmag <= '0; anorm <= '0; bnorm <= '0;
            alz <= '0; blz <= '0; azero <= 1'b1; bzero <= 1'b1;
            aflt <= 1'b0; bflt <= 1'b0;
            op <= '0;
            iop <= iop_of(6'd0);
            small_r <= 1'b0;
            a <= '0;
            b <= '0;
            fa <= '0;
            fb <= '0;
            fres_r <= '0;
            fa64_r <= '0;
            fb64_r <= '0;
        end else begin
            done_o <= 1'b0;
            case (st)
                A_IDLE: if (start_i) begin
                    logic        isf, conv, ok;
                    logic [63:0] v;
                    op <= op_i;
                    iop <= iop_of(op_i);
                    small_r <= small_i;
                    a <= a_i;
                    b <= b_i;
                    aflt <= a_flt_i;
                    bflt <= b_flt_i;
                    amag <= a_i[63] ? (~a_i + 64'd1) : a_i;
                    bmag <= b_i[63] ? (~b_i + 64'd1) : b_i;
                    fa <= a_i[31:0];
                    fb <= b_i[31:0];
                    // Right when both are floats; A_FCONV rewrites them otherwise.
                    fa64_r <= fa64;
                    fb64_r <= fb64;
                    err_o <= AE_NONE;
                    res_o <= '0;
                    rkind_o <= AK_INT;
                    isf = a_flt_i || b_flt_i;
                    conv = !a_flt_i || !b_flt_i;
                    if (op_i == ALU_I2F) begin
                        rkind_o <= AK_FLOAT;
                        st <= A_INORM;
                    end else if (op_i == ALU_F2I) begin
                        // Magnitude now, sign in A_F2I (shift and negate in
                        // one cycle were na -> alu_res at 11.0 ns).
                        v = mpy_f32_to_i64(a_i[31:0], ok);
                        res_o <= v;
                        if (!ok) err_o <= AE_FTOI;
                        st <= A_F2I;
                    end else if (op_i >= ALU_NEG) begin
                        if (a_flt_i) begin
                            rkind_o <= AK_FLOAT;
                            case (op_i)
                                ALU_NEG: res_o <= {32'd0, ~a_i[31], a_i[30:0]};
                                ALU_POS: res_o <= {32'd0, a_i[31:0]};
                                ALU_ABS: res_o <= {32'd0, 1'b0, a_i[30:0]};
                                default: err_o <= AE_UNSUPPORTED;
                            endcase
                            st <= A_DONE;
                        end else begin
                            // The integer unit answers next cycle (A_DONE reads it).
                            if (op_i == ALU_ABS && !a_i[63]) begin op <= ALU_POS; iop <= iop_of(ALU_POS); end
                            else if (op_i == ALU_ABS) begin op <= ALU_NEG; iop <= iop_of(ALU_NEG); end
                            st <= A_DONE;
                        end
                    end else if (op_i <= ALU_NE) begin
                        if (isf && conv) begin
                            st <= A_INORM;
                        end else if (isf) begin
                            rkind_o <= AK_BOOL;
                            res_o <= {63'd0, f_cmp};
                            st <= A_DONE;
                        end else begin
                            st <= A_DONE;
                        end
                    end else if (isf || op_i == ALU_TDIV || (op_i == ALU_POW && b_i[63])) begin
                        rkind_o <= AK_FLOAT;
                        if (conv) begin
                            st <= A_INORM;
                        end else if (op_i == ALU_POW) begin
                            st <= A_FERR;
                        end else begin
                            err_o <= f_err;
                            st <= f_fpu ? A_FPU : A_DONE;
                        end
                    end else begin
                        case (op_i)
                            ALU_MUL: st <= A_MUL;
                            ALU_FLOOR, ALU_MOD: begin
                                if (b_i == 64'd0) begin
                                    err_o <= AE_ZERO_DIV;
                                    st <= A_DONE;
                                end else begin
                                    st <= A_DIV;
                                end
                            end
                            ALU_POW: st <= A_POW;
                            ALU_MATMUL: begin
                                err_o <= AE_UNSUPPORTED;
                                st <= A_DONE;
                            end
                            default: st <= A_DONE;
                        endcase
                    end
                end
                A_MUL: if (mul_done) begin
                    res_o <= mul_lo;
                    if (mul_hi != {64{mul_lo[63]}}) err_o <= AE_OVERFLOW;
                    st <= A_IDLE;
                    done_o <= 1'b1;
                end
                A_DIV: if (div_done) begin
                    // The divider floors. Only the legacy long-long profile
                    // truncates outside the small-int range.
                    if (small_r && op == ALU_FLOOR && a == 64'h8000_0000_0000_0000 && b == 64'hffff_ffff_ffff_ffff) begin
                        err_o <= AE_OVERFLOW;
                    end else if (!small_r && rem != 64'd0 && (a[63] != b[63])) begin
                        res_o <= (op == ALU_FLOOR) ? quot + 64'd1 : rem - b;
                    end else begin
                        res_o <= (op == ALU_FLOOR) ? quot : rem;
                    end
                    st <= A_IDLE;
                    done_o <= 1'b1;
                end
                A_POW: if (pow_done || pow_trap) begin
                    res_o <= pow_res;
                    if (pow_trap) err_o <= AE_OVERFLOW;
                    st <= A_IDLE;
                    done_o <= 1'b1;
                end
                A_FPU: if (fdone || fexc) begin
                    if (fexc) begin
                        // Only ** overflow is left; powf gives inf with the sign of the result.
                        res_o <= {32'd0, fa[31] && mpy_f32_odd(fb), 8'hFF, 23'd0};
                        st <= A_IDLE;
                        done_o <= 1'b1;
                    end else begin
                        fres_r <= fres;
                        st <= A_FNAR;
                    end
                end
                A_INORM: begin
                    alz <= 6'(upycore_clz64(amag));
                    blz <= 6'(upycore_clz64(bmag));
                    azero <= (amag == 64'd0);
                    bzero <= (bmag == 64'd0);
                    anorm <= amag << 6'(upycore_clz64(amag));
                    bnorm <= bmag << 6'(upycore_clz64(bmag));
                    st <= A_IROUND;
                end
                A_IROUND: begin
                    fa <= aflt ? fa : aconv;
                    fb <= bflt ? fb : bconv;
                    if (op == ALU_I2F) begin
                        res_o <= {32'd0, aflt ? fa : aconv};
                        st <= A_DONE;
                    end else st <= A_FCONV;
                end
                A_FCONV: begin
                    fa64_r <= fa64;
                    fb64_r <= fb64;
                    if (op <= ALU_NE) begin
                        rkind_o <= AK_BOOL;
                        res_o <= {63'd0, f_cmp};
                        st <= A_DONE;
                    end else if (op == ALU_POW) begin
                        st <= A_FERR;
                    end else begin
                        err_o <= f_err;
                        st <= f_fpu ? A_FPU : A_DONE;
                    end
                end
                // A subnormal binary32 result waits one cycle for nar_jam_r.
                A_FNAR: if (nar_sub) st <= A_FNAR2;
                else begin
                    res_o <= {32'd0, fnarrow};
                    st <= A_IDLE;
                    done_o <= 1'b1;
                end
                A_F2I: begin
                    if (fa[31]) res_o <= ~res_o + 64'd1;
                    st <= A_DONE;
                end
                A_FNAR2: begin
                    res_o <= {32'd0, fnarrow};
                    st <= A_IDLE;
                    done_o <= 1'b1;
                end
                // float **: the domain errors, from the operand flops (one
                // cycle per float power; in the dispatch cycle the test sat
                // in front of the state select, st -> st at 11.4 ns).
                A_FERR: begin
                    if (mpy_f32_zero(fa) && fb[31] && !(fb[30:23] == 8'hFF && fb[22:0] == 23'd0)) begin
                        err_o <= AE_ZERO_DIV; st <= A_DONE;
                    end else if (fa[31] && !mpy_f32_zero(fa) && !mpy_f32_nan(fa) &&
                                 !mpy_f32_integral(fb) && !mpy_f32_nan(fb) && !(fb[30:23] == 8'hFF)) begin
                        err_o <= AE_COMPLEX; st <= A_DONE;
                    end else st <= A_FPU;
                end
                A_DONE: begin
                    // Integer one-cycle ops: the unit sees the latched operands now.
                    if (rkind_o == AK_INT && err_o == AE_NONE && op != ALU_F2I) begin
                        res_o <= ires;
                        if (op <= ALU_NE) begin
                            rkind_o <= AK_BOOL;
                        end else if (small_r && (op == ALU_LSHIFT || op == ALU_RSHIFT) &&
                                     b[63:31] != {33{b[31]}}) begin
                            // Only the MPZ profile sets small_r with a
                            // shift count beyond the signed machine word.
                            err_o <= AE_OVERFLOW;
                        end else if (iverr) begin
                            err_o <= AE_NEG_SHIFT;
                        end else if (iovf) begin
                            err_o <= AE_OVERFLOW;
                        end
                    end
                    st <= A_IDLE;
                    done_o <= 1'b1;
                end
                default: st <= A_IDLE;
            endcase
        end
    end

    // verilator lint_off UNUSEDSIGNAL
    logic unused;
    assign unused = ^{izero, mul_stall, mul_busy, pow_stall, pow_busy, div_zero, div_stall, div_busy,
                      fstall, fbusy};
    // verilator lint_on UNUSEDSIGNAL
endmodule
