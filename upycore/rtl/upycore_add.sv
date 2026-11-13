// Prefix adder (Kogge-Stone).
//
// A 32-bit or 64-bit ripple meets a 12 ns clock in Genus's global-wire
// model and then arrives at about 15 ns after sky130 ss place-and-route
// (P2, core_clk data paths of 14.9-15.3 ns: the byte engine, the integer
// ALU, spill, fetch, the bulk address add, and the power residual). The
// carry here is a tree of depth log2(W), and syn_hier keeps Genus from
// flattening that tree back into one ripple. dont_touch is the wrong
// attribute: it would also stop the interior from mapping to sky130 cells.
(* syn_hier = "hard" *)
module upycore_add #(
    parameter int W = 32
) (
    input  logic [W-1:0] a_i,
    input  logic [W-1:0] b_i,
    input  logic         cin_i,
    output logic [W-1:0] sum_o,
    output logic         cout_o
);
    localparam int LV = (W <= 1) ? 1 : $clog2(W);

    logic [W-1:0] p, g;
    // cin folds into bit 0's generate, so a later stage never has to carry
    // it separately. p[0] stays a^b: sum[0] is p[0] ^ cin.
    assign p    = a_i ^ b_i;
    assign g[0] = (a_i[0] & b_i[0]) | (cin_i & (a_i[0] | b_i[0]));
    generate
        if (W > 1) begin : gen_g
            assign g[W-1:1] = a_i[W-1:1] & b_i[W-1:1];
        end
    endgenerate

    // Packed, so a synthesis tool keeps a wire per bit. An unpacked array
    // here is what Yosys turns into a memory.
    logic [LV:0][W-1:0] pp;
    logic [LV:0][W-1:0] gg;
    assign pp[0] = p;
    assign gg[0] = g;

    generate
        for (genvar s = 0; s < LV; s++) begin : lvl
            localparam int D = 1 << s;
            for (genvar i = 0; i < W; i++) begin : gbit
                if (i >= D) begin : merge
                    assign gg[s+1][i] = gg[s][i] | (pp[s][i] & gg[s][i-D]);
                    assign pp[s+1][i] = pp[s][i] & pp[s][i-D];
                end else begin : keep
                    assign gg[s+1][i] = gg[s][i];
                    assign pp[s+1][i] = pp[s][i];
                end
            end
        end
    endgenerate

    // gg[LV][i] is the carry into bit i+1 (the group generate of bits i..0).
    logic [W-1:0] carry;
    assign carry[0] = cin_i;
    generate
        if (W > 1) begin : gen_carry
            assign carry[W-1:1] = gg[LV][W-2:0];
        end
    endgenerate
    assign sum_o  = p ^ carry;
    assign cout_o = gg[LV][W-1];
endmodule

// Three-operand sum, low W bits. One carry-save stage and one prefix add,
// so a residual of the form (r - C + w) is not two ripples in series.
(* syn_hier = "hard" *)
module upycore_sum3 #(
    parameter int W = 32
) (
    input  logic [W-1:0] a_i,
    input  logic [W-1:0] b_i,
    input  logic [W-1:0] c_i,
    input  logic         cin_i,
    output logic [W-1:0] sum_o
);
    logic [W-1:0] s, g, gsh;
    assign s = a_i ^ b_i ^ c_i;
    assign g = (a_i & b_i) | (a_i & c_i) | (b_i & c_i);
    // g[i] is the carry into bit i+1. g[W-1] falls outside the low W bits.
    generate
        if (W == 1) begin : gen_gsh1
            assign gsh = '0;
        end else begin : gen_gsh
            assign gsh = {g[W-2:0], 1'b0};
        end
    endgenerate
    upycore_add #(.W(W)) u (
        .a_i(s), .b_i(gsh), .cin_i(cin_i), .sum_o(sum_o), .cout_o()
    );
endmodule
