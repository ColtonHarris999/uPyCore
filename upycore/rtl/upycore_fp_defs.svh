`ifndef UPYCORE_FP_DEFS_SVH
`define UPYCORE_FP_DEFS_SVH

// IEEE 754 binary64 helpers shared by the FPU (upycore_fpu.sv and its
// pipelines), operand promotion (upycore_promote.sv) and the few core paths
// that compare floats (BI_MAX).  Everything here is plain combinational
// bit manipulation: no `real`, no $bitstoreal / $realtobits, so it
// synthesizes.  Rounding is round-to-nearest-even throughout, which is what
// CPython gets from the host FPU.

localparam logic [63:0] UPY_F64_PZERO = 64'h0000_0000_0000_0000;
localparam logic [63:0] UPY_F64_NZERO = 64'h8000_0000_0000_0000;
localparam logic [63:0] UPY_F64_ONE   = 64'h3FF0_0000_0000_0000;
localparam logic [63:0] UPY_F64_NONE  = 64'hBFF0_0000_0000_0000;
localparam logic [63:0] UPY_F64_HALF  = 64'h3FE0_0000_0000_0000;
localparam logic [63:0] UPY_F64_PINF  = 64'h7FF0_0000_0000_0000;
localparam logic [63:0] UPY_F64_NINF  = 64'hFFF0_0000_0000_0000;
localparam logic [63:0] UPY_F64_QNAN  = 64'h7FF8_0000_0000_0000;

// ---------------------------------------------------------------------------
// Classification
// ---------------------------------------------------------------------------
function automatic logic upycore_f64_is_nan(input logic [63:0] v);
    upycore_f64_is_nan = (v[62:52] == 11'h7FF) && (v[51:0] != 52'd0);
endfunction

function automatic logic upycore_f64_is_inf(input logic [63:0] v);
    upycore_f64_is_inf = (v[62:52] == 11'h7FF) && (v[51:0] == 52'd0);
endfunction

function automatic logic upycore_f64_is_zero(input logic [63:0] v);
    upycore_f64_is_zero = (v[62:0] == 63'd0);
endfunction

function automatic logic upycore_f64_is_finite(input logic [63:0] v);
    upycore_f64_is_finite = (v[62:52] != 11'h7FF);
endfunction

// x < 0 in the C sense: negative, nonzero, not NaN (-0.0 < 0 is false).
function automatic logic upycore_f64_lt_zero(input logic [63:0] v);
    upycore_f64_lt_zero = v[63] && !upycore_f64_is_zero(v) && !upycore_f64_is_nan(v);
endfunction

// Significand with the hidden bit, and the effective biased exponent
// (subnormals use exponent 1 with hidden bit 0, so value =
// sig * 2^(exp - 1023 - 52) holds for every finite input).
function automatic logic [52:0] upycore_f64_sig(input logic [63:0] v);
    upycore_f64_sig = {(v[62:52] != 11'd0), v[51:0]};
endfunction

function automatic logic [10:0] upycore_f64_exp_eff(input logic [63:0] v);
    upycore_f64_exp_eff = (v[62:52] == 11'd0) ? 11'd1 : v[62:52];
endfunction

// ---------------------------------------------------------------------------
// Leading-zero counts
// ---------------------------------------------------------------------------
function automatic logic [6:0] upycore_clz64(input logic [63:0] v);
    // A tree: each level joins two blocks (the upper block's count, or the
    // block size plus the lower one's when the upper is zero), so the count
    // is six selects deep. The binary search this replaces tested 32, 16,
    // 8, 4 and 2 bits of a value it shifted in between, and led the
    // divider's and the power unit's normalize paths (state_r ->
    // s1_exp_a_r at 14.0 ns). SAT-proven equal. Each level is its own
    // vector, written once: one wide array updated in place made the
    // simulation model 2.5 times slower.
    logic [31:0] z1; logic [31:0]  c1;     // 32 blocks of 2, count 1 bit
    logic [15:0] z2; logic [31:0]  c2;     // 16 blocks of 4, count 2 bits
    logic [7:0]  z3; logic [23:0]  c3;     //  8 blocks of 8, count 3 bits
    logic [3:0]  z4; logic [15:0]  c4;     //  4 blocks of 16, count 4 bits
    logic [1:0]  z5; logic [9:0]   c5;     //  2 blocks of 32, count 5 bits
    begin
        for (int i = 0; i < 32; i++) begin
            z1[i] = !v[2*i+1] && !v[2*i];
            c1[i] = !v[2*i+1];
        end
        for (int i = 0; i < 16; i++) begin
            z2[i] = z1[2*i+1] && z1[2*i];
            c2[2*i +: 2] = z1[2*i+1] ? {1'b1, c1[2*i]} : {1'b0, c1[2*i+1]};
        end
        for (int i = 0; i < 8; i++) begin
            z3[i] = z2[2*i+1] && z2[2*i];
            c3[3*i +: 3] = z2[2*i+1] ? {1'b1, c2[2*(2*i) +: 2]} : {1'b0, c2[2*(2*i+1) +: 2]};
        end
        for (int i = 0; i < 4; i++) begin
            z4[i] = z3[2*i+1] && z3[2*i];
            c4[4*i +: 4] = z3[2*i+1] ? {1'b1, c3[3*(2*i) +: 3]} : {1'b0, c3[3*(2*i+1) +: 3]};
        end
        for (int i = 0; i < 2; i++) begin
            z5[i] = z4[2*i+1] && z4[2*i];
            c5[5*i +: 5] = z4[2*i+1] ? {1'b1, c4[4*(2*i) +: 4]} : {1'b0, c4[4*(2*i+1) +: 4]};
        end
        upycore_clz64 = (z5[1] && z5[0]) ? 7'd64 :
                        z5[1] ? {2'b01, c5[4:0]} : {2'b00, c5[9:5]};
    end
endfunction

// A set bit below the significand makes the all-zero count saturate at
// the significand width while keeping the same balanced encoder.
function automatic logic [5:0] upycore_clz53(input logic [52:0] v);
    return 6'(upycore_clz64({v, 11'h400}));
endfunction

function automatic logic [5:0] upycore_clz56(input logic [55:0] v);
    return 6'(upycore_clz64({v, 8'h80}));
endfunction

// ---------------------------------------------------------------------------
// Round-to-nearest-even and pack.
//   value = sig * 2^(exp_s - 1023 - 52) with guard / round / sticky bits
//   below the significand.  sig must be normalized (bit 52 set) unless the
//   whole {sig, g, r, s} is zero or exp_s == 1 (a result that is already in
//   the subnormal range after a bounded left normalization).  exp_s <= 0
//   is denormalized here with a sticky-collecting right shift; exponents
//   that saturate round to infinity.
// ---------------------------------------------------------------------------
// The two halves of upycore_f64_pack_round, for units that give a
// subnormal result an extra cycle (the right shift) and keep the shift out
// of the common path:
//   upycore_f64_denorm      {sig, g, r, s} shifted right for exp_s <= 0,
//                           with the lost bits in the sticky
//   upycore_f64_round_pack  RNE and pack of an already-denormalized value
// upycore_f64_round_pack(sign, exp_s > 0 ? exp_s : 1,
//                        exp_s > 0 ? ext : upycore_f64_denorm(ext, exp_s))
// equals upycore_f64_pack_round(sign, exp_s, sig, g, r, s) for every input.
function automatic logic [55:0] upycore_f64_denorm(
    input logic [55:0]        ext,
    input logic signed [13:0] exp_s
);
    logic signed [13:0] sh;
    logic [55:0]        lost_mask;
    begin
        sh = 14'sd1 - exp_s;
        if (sh > 14'sd55) begin
            upycore_f64_denorm = {55'd0, |ext};
        end else begin
            for (int i = 0; i < 56; i++) lost_mask[i] = (6'(i) < sh[5:0]);   // (1 << sh) - 1
            upycore_f64_denorm = ext >> sh[5:0];
            upycore_f64_denorm[0] = upycore_f64_denorm[0] | (|(ext & lost_mask));
        end
    end
endfunction

function automatic logic [63:0] upycore_f64_round_pack(
    input logic               sign,
    input logic signed [13:0] exp_eff_i,
    input logic [55:0]        shifted
);
    logic               inc;
    logic [53:0]        sig_r;
    logic signed [13:0] exp_eff;
    logic [10:0]        e_field;
    begin
        exp_eff = exp_eff_i;
        if (shifted == 56'd0) begin
            upycore_f64_round_pack = {sign, 63'd0};
        end else begin
            inc   = shifted[2] & (shifted[1] | shifted[0] | shifted[3]);
            sig_r = {1'b0, shifted[55:3]} + {53'd0, inc};
            if (sig_r[53]) begin
                sig_r   = sig_r >> 1;
                exp_eff = exp_eff + 14'sd1;
            end
            if (exp_eff >= 14'sd2047) begin
                upycore_f64_round_pack = {sign, UPY_F64_PINF[62:0]};
            end else begin
                e_field = sig_r[52] ? exp_eff[10:0] : 11'd0;
                upycore_f64_round_pack = {sign, e_field, sig_r[51:0]};
            end
        end
    end
endfunction

function automatic logic [63:0] upycore_f64_pack_round(
    input logic               sign,
    input logic signed [13:0] exp_s,
    input logic [52:0]        sig,
    input logic               g,
    input logic               r,
    input logic               s
);
    logic [55:0]        ext;
    logic [55:0]        shifted;
    logic [55:0]        lost_mask;
    logic signed [13:0] sh;
    logic signed [13:0] exp_eff;
    logic               inc;
    logic [53:0]        sig_r;
    logic [10:0]        e_field;
    begin
        ext = {sig, g, r, s};
        if (ext == 56'd0) begin
            upycore_f64_pack_round = {sign, 63'd0};
        end else begin
            if (exp_s <= 14'sd0) begin
                sh = 14'sd1 - exp_s;
                if (sh > 14'sd55) begin
                    shifted = {55'd0, |ext};
                end else begin
                    for (int i = 0; i < 56; i++) lost_mask[i] = (6'(i) < sh[5:0]);   // (1 << sh) - 1
                    shifted = ext >> sh[5:0];
                    shifted[0] = shifted[0] | (|(ext & lost_mask));
                end
                exp_eff = 14'sd1;
            end else begin
                shifted = ext;
                exp_eff = exp_s;
            end
            // RNE on guard / (round | sticky) / lsb.
            inc   = shifted[2] & (shifted[1] | shifted[0] | shifted[3]);
            sig_r = {1'b0, shifted[55:3]} + {53'd0, inc};
            if (sig_r[53]) begin
                sig_r   = sig_r >> 1;
                exp_eff = exp_eff + 14'sd1;
            end
            if (exp_eff >= 14'sd2047) begin
                upycore_f64_pack_round = {sign, UPY_F64_PINF[62:0]};
            end else begin
                // A clear hidden bit only happens at exp_eff == 1, which
                // is exactly the subnormal encoding (exponent field 0).
                e_field = sig_r[52] ? exp_eff[10:0] : 11'd0;
                upycore_f64_pack_round = {sign, e_field, sig_r[51:0]};
            end
        end
    end
endfunction

// ---------------------------------------------------------------------------
// Comparison: returns {unordered, gt, eq, lt}.  +0 == -0; NaN is unordered.
// ---------------------------------------------------------------------------
function automatic logic [3:0] upycore_f64_cmp(input logic [63:0] a, input logic [63:0] b);
    logic lt_mag;
    begin
        if (upycore_f64_is_nan(a) || upycore_f64_is_nan(b)) begin
            upycore_f64_cmp = 4'b1000;
        end else if (upycore_f64_is_zero(a) && upycore_f64_is_zero(b)) begin
            upycore_f64_cmp = 4'b0010;
        end else if (a[63] != b[63]) begin
            upycore_f64_cmp = a[63] ? 4'b0001 : 4'b0100;
        end else if (a[62:0] == b[62:0]) begin
            upycore_f64_cmp = 4'b0010;
        end else begin
            lt_mag = (a[62:0] < b[62:0]);
            // Both negative: the larger magnitude is the smaller value.
            upycore_f64_cmp = (lt_mag ^ a[63]) ? 4'b0001 : 4'b0100;
        end
    end
endfunction

// (Indexing a function result directly is not portable to every
// synthesis frontend, hence the temporaries.)
function automatic logic upycore_f64_lt(input logic [63:0] a, input logic [63:0] b);
    logic [3:0] c;
    c = upycore_f64_cmp(a, b);
    upycore_f64_lt = c[0];
endfunction

function automatic logic upycore_f64_eq(input logic [63:0] a, input logic [63:0] b);
    logic [3:0] c;
    c = upycore_f64_cmp(a, b);
    upycore_f64_eq = c[1];
endfunction

function automatic logic upycore_f64_gt(input logic [63:0] a, input logic [63:0] b);
    logic [3:0] c;
    c = upycore_f64_cmp(a, b);
    upycore_f64_gt = c[2];
endfunction

// Evaluate one of the six Python comparison selectors.
function automatic logic upycore_f64_compare_op(
    input logic [4:0]  op,
    input logic [63:0] a,
    input logic [63:0] b
);
    logic [3:0] c;
    begin
        c = upycore_f64_cmp(a, b);
        unique case (op)
            UPY_ALU_EQ: upycore_f64_compare_op = c[1];
            UPY_ALU_NE: upycore_f64_compare_op = !c[1];
            UPY_ALU_LT: upycore_f64_compare_op = c[0];
            UPY_ALU_LE: upycore_f64_compare_op = c[0] | c[1];
            UPY_ALU_GT: upycore_f64_compare_op = c[2];
            UPY_ALU_GE: upycore_f64_compare_op = c[2] | c[1];
            default:   upycore_f64_compare_op = 1'b0;
        endcase
    end
endfunction

// ---------------------------------------------------------------------------
// floor(): exact, so a 1-cycle combinational function.
// ---------------------------------------------------------------------------
function automatic logic [63:0] upycore_f64_floor(input logic [63:0] a);
    logic [10:0] e;
    logic [5:0]  nfrac;          // fraction bits below the binary point
    logic [51:0] frac_mask;
    logic [62:0] trunc;
    begin
        e = a[62:52];
        if (e == 11'h7FF) begin
            upycore_f64_floor = a;                       // inf / nan
        end else if (e < 11'd1023) begin
            if (upycore_f64_is_zero(a)) upycore_f64_floor = a;
            else                       upycore_f64_floor = a[63] ? UPY_F64_NONE : UPY_F64_PZERO;
        end else if (e >= 11'd1075) begin
            upycore_f64_floor = a;                       // already integral
        end else begin
            nfrac     = 6'(11'd1075 - e);               // 1..52
            frac_mask = (52'd1 << nfrac) - 52'd1;
            trunc     = {e, a[51:0] & ~frac_mask};
            if (a[63] && ((a[51:0] & frac_mask) != 52'd0)) begin
                // Negative with a fraction: one unit at the integer position.
                // The IEEE encoding is monotonic so the add carries into the
                // exponent field by itself (e.g. -1.5 -> -2.0).
                upycore_f64_floor = {1'b1, trunc + (63'd1 << nfrac)};
            end else begin
                upycore_f64_floor = {a[63], trunc};
            end
        end
    end
endfunction

// Classification only: testing integral bits must not compute floor(),
// whose negative-fraction correction contains a wide carry-propagate add.
function automatic logic upycore_f64_is_integer(input logic [63:0] v);
    logic [10:0] e;
    begin
        e = v[62:52];
        if (e == 11'h7ff) upycore_f64_is_integer = 1'b0;
        else if (e >= 11'd1075) upycore_f64_is_integer = 1'b1;
        else if (e < 11'd1023) upycore_f64_is_integer = (v[62:0] == 0);
        else upycore_f64_is_integer =
            (v[51:0] & (52'hfffffffffffff >> (e - 11'd1023))) == 0;
    end
endfunction

// True when v is an odd integer (CPython DOUBLE_IS_ODD_INTEGER).
function automatic logic upycore_f64_is_odd_integer(input logic [63:0] v);
    logic [10:0] e;
    begin
        e = v[62:52];
        if (e < 11'd1023 || e >= 11'd1076 || !upycore_f64_is_finite(v)) begin
            upycore_f64_is_odd_integer = 1'b0;           // |v| < 1, or even/huge
        end else if (!upycore_f64_is_integer(v)) begin
            upycore_f64_is_odd_integer = 1'b0;
        end else begin
            // Integer: the units bit sits at fraction position 52 - (e-1023)
            // (the hidden bit itself when e == 1023).
            upycore_f64_is_odd_integer = (e == 11'd1023) ? 1'b1
                                      : v[6'(11'd1075 - e)];
        end
    end
endfunction

// ---------------------------------------------------------------------------
// int64 -> binary64 (round-to-nearest-even; |v| > 2^53 loses bits exactly
// the way CPython's PyLong_AsDouble does).
// ---------------------------------------------------------------------------
function automatic logic [63:0] upycore_i64_to_f64(input logic [63:0] v);
    logic        sign;
    logic [63:0] mag;
    logic [6:0]  lz;
    logic [63:0] norm;
    begin
        sign = v[63];
        mag  = sign ? (~v + 64'd1) : v;
        if (mag == 64'd0) begin
            upycore_i64_to_f64 = UPY_F64_PZERO;
        end else begin
            lz   = upycore_clz64(mag);
            norm = mag << lz[5:0];
            upycore_i64_to_f64 = upycore_f64_pack_round(
                sign, 14'sd1086 - 14'(lz), norm[63:11], norm[10], norm[9], |norm[8:0]);
        end
    end
endfunction

`endif
