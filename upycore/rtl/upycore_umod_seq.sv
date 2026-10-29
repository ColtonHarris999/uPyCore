// Unsigned 32-bit remainder, BPC dividend bits per clock.
//
// mpy_core uses it for the dict/set probe start, pos = hash % alloc
// (py/map.c). A combinational 32-bit modulo is about 230 gate levels
// (~34 ns at ss_100C_1v60 in sky130); one restoring step here is a
// 33-bit subtract and a select, so BPC = 4 keeps a cycle near 4-5 ns
// and BPC = 2 halves that if a backend run needs it.
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

    function automatic logic [5:0] clz32(input logic [31:0] v);
        clz32 = 6'd32;
        for (int i = 0; i < 32; i++) begin
            if (v[i]) clz32 = 6'(31 - i);
        end
    endfunction

    logic [31:0] d_r;
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

    // One clock of BPC restoring steps.
    logic [31:0] r_nx, q_nx;
    always_comb begin
        logic [32:0] t;
        r_nx = r_r;
        q_nx = q_r;
        for (int j = 0; j < BPC; j++) begin
            t = {r_nx, q_nx[31]};
            q_nx = {q_nx[30:0], 1'b0};
            r_nx = (t >= {1'b0, d_r}) ? 32'(t - {1'b0, d_r}) : t[31:0];
        end
    end

    assign busy_o = (n_r != 6'd0);

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            d_r <= '0; r_r <= '0; q_r <= '0; n_r <= '0;
            done_o <= 1'b0; rem_o <= '0;
        end else begin
            done_o <= 1'b0;
            if (start_i) begin
                d_r <= d_i;
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
