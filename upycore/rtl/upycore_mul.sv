`include "upycore_defs.svh"

// Signed 64 x 64 -> 128 integer multiplier, STEP multiplier bits per chunk.
// Accept loads the operands; each of 64/STEP chunks crosses two stages:
//   product: two independent 33 x (STEP+1) signed limb products
//   accumulate: carry-save merge with the shifted accumulator, then one add
// There is no combinational path through a multiply AND an accumulator add,
// and no external operand/power mux in front of a multiply on accept.
// The top multiplier chunk is signed; all other chunks are unsigned.
// Products are independent of the accumulator, so the two stages overlap:
// one chunk per clock, result 64/STEP + 1 clocks after accept (5 at STEP=16).
//
// Handshake: see upycore_umul_seq.sv (level start_i, one-cycle done_o,
// withdrawing start_i aborts).  stall_o is start_i && !done_o, so the
// requester can tie it straight into its hold condition.
module upycore_mul #(
    parameter int STEP = 16
) (
    input  logic        clk_i,
    input  logic        rst_n_i,
    input  logic        start_i,
    input  logic [63:0] op_a_i,
    input  logic [63:0] op_b_i,
    output logic [63:0] result_o,      // product[63:0]  (Python int wraps)
    output logic [63:0] result_hi_o,   // product[127:64]
    output logic        done_o,
    output logic        stall_o,
    output logic        busy_o
);

    localparam int NSTEP = 64 / STEP;
    localparam int ACC_W = 64 + STEP + 2;
    localparam int CNT_W = (NSTEP > 1) ? $clog2(NSTEP + 1) : 1;

    // Elaboration check: keep out of the synthesis initial-procedure path.
    generate
        if ((64 % STEP) != 0) begin : gen_bad_step
            nonexistent_module_STEP_must_divide_64 bad_step ();
        end
    endgenerate

    logic                    busy_r;
    logic                    done_r;
    logic [CNT_W-1:0]        cnt_r;
    logic [63:0]             a_r;
    logic [63:0]             b_r;
    logic signed [ACC_W-1:0] acc_r;
    logic [63:0]             lo_r;
    logic [63:0]             lo_result_r;
    logic [63:0]             hi_result_r;

    logic                    product_valid;
    logic                    last_step;
    logic signed [STEP:0]    chunk_s;
    logic signed [32:0]      a_low, a_high;
    logic signed [STEP+33:0] pp_low_r, pp_high_r;
    logic [ACC_W-1:0]        x, y, z, csa_s, csa_c;
    logic signed [ACC_W-1:0] sum;
    logic [63:0]             lo_next;
    logic                    accept;

    assign accept    = start_i && !busy_r && !done_r;
    assign last_step = cnt_r == CNT_W'(NSTEP - 1);
    assign chunk_s   = {last_step ? b_r[STEP-1] : 1'b0, b_r[STEP-1:0]};
    assign a_low     = {1'b0, a_r[31:0]};
    assign a_high    = {a_r[63], a_r[63:32]};
    assign x         = ACC_W'(pp_low_r);
    assign y         = ACC_W'(pp_high_r) << 32;
    assign z         = acc_r >>> STEP;
    assign csa_s     = x ^ y ^ z;
    assign csa_c     = (x & y) | (x & z) | (y & z);
    assign sum       = csa_s + (csa_c << 1);
    assign lo_next   = 64'(lo_r >> STEP) | 64'(64'(sum[STEP-1:0]) << (64 - STEP));

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            product_valid <= 1'b0;
            pp_low_r <= '0; pp_high_r <= '0;
            busy_r      <= 1'b0;
            done_r      <= 1'b0;
            cnt_r       <= '0;
            a_r         <= '0;
            b_r         <= '0;
            acc_r       <= '0;
            lo_r        <= '0;
            lo_result_r <= '0;
            hi_result_r <= '0;
        end else begin
            done_r <= 1'b0;
            if (!start_i) begin
                busy_r <= 1'b0;
            end else if (accept) begin
                a_r <= op_a_i;
                b_r <= op_b_i;
                acc_r <= '0;
                lo_r <= '0;
                cnt_r <= '0;
                busy_r <= 1'b1;
                product_valid <= 1'b0;
            end else if (busy_r) begin
                // Issue the next product while accumulating the previous one.
                if (cnt_r < CNT_W'(NSTEP)) begin
                    pp_low_r <= a_low * chunk_s;
                    pp_high_r <= a_high * chunk_s;
                    b_r <= b_r >> STEP;
                    cnt_r <= cnt_r + 1'b1;
                    product_valid <= 1'b1;
                end else product_valid <= 1'b0;
                if (product_valid) begin
                    acc_r <= sum;
                    lo_r <= lo_next;
                    if (cnt_r == CNT_W'(NSTEP)) begin
                        busy_r <= 1'b0;
                        done_r <= 1'b1;
                        lo_result_r <= lo_next;
                        hi_result_r <= 64'(sum >>> STEP);
                    end
                end
            end
        end
    end

    assign result_o    = lo_result_r;
    assign result_hi_o = hi_result_r;
    assign done_o      = done_r;
    assign stall_o     = start_i && !done_r;
    assign busy_o      = busy_r;

endmodule
