// Unsigned 32-bit remainder, BPC dividend bits per clock.
//
// mpy_core uses it for the dict/set probe start, pos = hash % alloc
// (py/map.c). A combinational 32-bit modulo is about 230 gate levels
// (~34 ns at ss_100C_1v60 in sky130); one restoring step here is a
// 33-bit subtract and a select. BPC = 4 runs two of those steps in one
// cycle; after place-and-route that cone was 15.2 ns at ss_100C_1v60
// (P2, u_hmod r_r). The chip instantiates BPC = 2, one step per cycle.
//
// The accept cycle skips the steps that cannot subtract. With
// k = bits(a) - bits(d) + 1 bits to bring down, rounded up to a multiple
// of BPC, the start remainder a >> k has fewer bits than d, so it is
// already below d. Only the low k bits are iterated:
//
//   a < d         done_o one cycle after start_i, rem_o = a
//   otherwise     done_o ceil(k / BPC) + 1 cycles after start_i
//
// A 16-bit string hash in a 17..127 slot table takes 2 to 4 steps.
// d must be nonzero (the core checks alloc == 0 before it probes).
//
// Handshake: start_i is a one-cycle pulse; done_o pulses for one cycle
// with rem_o, which holds until the next start.
module upycore_umod_seq #(
    parameter int BPC = 4    // dividend bits per clock: 1, 2 or 4
) (
    input  logic        clk_i,
    input  logic        rst_n_i,
    input  logic        start_i,
    input  logic [31:0] a_i,
    input  logic [31:0] d_i,
    output logic        done_o,
    output logic [31:0] rem_o,
    output logic        busy_o
);

    generate
        if (BPC != 1 && BPC != 2 && BPC != 4) begin : gen_bad_bpc
            nonexistent_module_BPC_must_be_1_2_or_4 bad_bpc ();
        end
    endgenerate

    // Leading zeros by halving (16, 8, 4, 2, 1): five zero tests and
    // shifts instead of a 32-step priority scan, which was 8.7 ns of the
    // accept cycle (hh -> q_r at 13.6 ns). SAT-proven equal to the scan.
    function automatic logic [5:0] clz32(input logic [31:0] v);
        logic [31:0] x;
        logic [4:0]  n;
        x = v;
        n[4] = (x[31:16] == 16'd0); if (n[4]) x = {x[15:0], 16'd0};
        n[3] = (x[31:24] == 8'd0);  if (n[3]) x = {x[23:0], 8'd0};
        n[2] = (x[31:28] == 4'd0);  if (n[2]) x = {x[27:0], 4'd0};
        n[1] = (x[31:30] == 2'd0);  if (n[1]) x = {x[29:0], 2'd0};
        n[0] = !x[31];
        clz32 = (v == 32'd0) ? 6'd32 : {1'b0, n};
    endfunction

    logic [31:0] d_r;
    logic [33:0] d3_r;       // 3 * d_r, for the radix-4 steps
    logic [31:0] r_r;        // partial remainder, always < d_r
    logic [31:0] q_r;        // dividend bits still to bring down, MSB first
    logic [5:0]  n_r;        // steps left

    // Accept: k = lz(d) - lz(a) + 1, rounded up to a multiple of BPC.
    logic [5:0]  lz_a, lz_d;
    logic [6:0]  k, kr;
    assign lz_a = clz32(a_i);
    assign lz_d = clz32(d_i);
    assign k    = 7'(lz_d) - 7'(lz_a) + 7'd1;
    assign kr   = (k + 7'(BPC - 1)) & ~7'(BPC - 1);

    // One clock of BPC restoring steps. A radix-2 step is one 34-bit
    // subtract: t >= d exactly when t - d does not borrow (diff[33] clear),
    // and then diff[31:0] is t - d. BPC = 2 and 4 run radix-4 steps
    // instead, each worth two radix-2 steps: t4 - 3d, t4 - 2d and t4 - d
    // are computed in parallel and the largest multiple that does not
    // borrow is taken, in the order 3d, 2d, d. Since r < d, t4 < 4d, so the
    // multiple is unique and the remainder is the one the two radix-2
    // steps leave. With d = 0 every subtract succeeds and the order makes
    // the step shift bits in, as the radix-2 steps do.
    logic [31:0] r_nx, q_nx;
    always_comb begin
        logic [32:0] t;
        logic [33:0] t4;
        logic [33:0] dif2;
        logic [34:0] e1, e2, e3;
        r_nx = r_r;
        q_nx = q_r;
        if (BPC == 1) begin
            t = {r_nx, q_nx[31]};
            q_nx = {q_nx[30:0], 1'b0};
            dif2 = {1'b0, t} - {2'b0, d_r};
            r_nx = dif2[33] ? t[31:0] : dif2[31:0];
        end else begin
            for (int j = 0; j < BPC/2; j++) begin
                t4 = {r_nx, q_nx[31:30]};
                q_nx = {q_nx[29:0], 2'b0};
                e1 = {1'b0, t4} - {3'b0, d_r};
                e2 = {1'b0, t4} - {2'b0, d_r, 1'b0};
                e3 = {1'b0, t4} - {1'b0, d3_r};
                if (!e3[34])      r_nx = e3[31:0];
                else if (!e2[34]) r_nx = e2[31:0];
                else if (!e1[34]) r_nx = e1[31:0];
                else              r_nx = t4[31:0];
            end
        end
    end

    assign busy_o = (n_r != 6'd0);

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            d_r <= '0; d3_r <= '0; r_r <= '0; q_r <= '0; n_r <= '0;
            done_o <= 1'b0; rem_o <= '0;
        end else begin
            done_o <= 1'b0;
            if (start_i) begin
                d_r <= d_i;
                d3_r <= {2'b0, d_i} + {1'b0, d_i, 1'b0};
                if (a_i < d_i) begin
                    n_r <= '0;
                    done_o <= 1'b1;
                    rem_o <= a_i;
                end else begin
                    r_r <= 32'(64'(a_i) >> kr);
                    q_r <= 32'(64'(a_i) << (7'd32 - kr));
                    n_r <= 6'(kr / 7'(BPC));
                end
            end else if (n_r != 6'd0) begin
                r_r <= r_nx;
                q_r <= q_nx;
                n_r <= n_r - 6'd1;
                if (n_r == 6'd1) begin
                    done_o <= 1'b1;
                    rem_o <= r_nx;
                end
            end
        end
    end
endmodule
