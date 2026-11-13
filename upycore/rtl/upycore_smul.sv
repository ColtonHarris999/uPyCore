// Signed AW x BW product, low AW+BW bits, as a carry-save tree plus one
// prefix add. The integer multiplier's 33 x 17 limb product was a partial-
// product array that place-and-route timed at 15.0 ns (P2, pp_low_r). A
// ripple array meets 12 ns under Genus's global-wire model; this tree does
// not give it that choice. syn_hier keeps the tree through synthesis.
//
// signed = unsigned - sign*2^width, so
//   a*b = ua*ub - a_sign*(ub<<AW) - b_sign*(ua<<BW)   (mod 2^(AW+BW))
// The two corrections are extra rows in the same tree (invert + a +1 at
// bit 0), not a second adder after the product.
(* syn_hier = "hard" *)
module upycore_smul #(
    parameter int AW = 33,
    parameter int BW = 17
) (
    input  logic [AW-1:0]       a_i,
    input  logic [BW-1:0]       b_i,
    output logic [AW+BW-1:0]    p_o
);
    localparam int W  = AW + BW;
    localparam int C0 = BW + 4;
    localparam int C1 = (C0 <= 2) ? C0 : (C0/3)*2 + (C0%3);
    localparam int C2 = (C1 <= 2) ? C1 : (C1/3)*2 + (C1%3);
    localparam int C3 = (C2 <= 2) ? C2 : (C2/3)*2 + (C2%3);
    localparam int C4 = (C3 <= 2) ? C3 : (C3/3)*2 + (C3%3);
    localparam int C5 = (C4 <= 2) ? C4 : (C4/3)*2 + (C4%3);
    localparam int C6 = (C5 <= 2) ? C5 : (C5/3)*2 + (C5%3);
    localparam int C7 = (C6 <= 2) ? C6 : (C6/3)*2 + (C6%3);
    localparam int C8 = (C7 <= 2) ? C7 : (C7/3)*2 + (C7%3);
    localparam int C9 = (C8 <= 2) ? C8 : (C8/3)*2 + (C8%3);
    localparam int C10 = (C9 <= 2) ? C9 : (C9/3)*2 + (C9%3);
    localparam int C11 = (C10 <= 2) ? C10 : (C10/3)*2 + (C10%3);
    localparam int C12 = (C11 <= 2) ? C11 : (C11/3)*2 + (C11%3);

    generate
        if (C12 != 2) begin : gen_bad_tree
            nonexistent_module_smul_tree_did_not_reduce bad_tree ();
        end
    endgenerate

    logic [C0*W-1:0]  d0;
    logic [C1*W-1:0]  d1;
    logic [C2*W-1:0]  d2;
    logic [C3*W-1:0]  d3;
    logic [C4*W-1:0]  d4;
    logic [C5*W-1:0]  d5;
    logic [C6*W-1:0]  d6;
    logic [C7*W-1:0]  d7;
    logic [C8*W-1:0]  d8;
    logic [C9*W-1:0]  d9;
    logic [C10*W-1:0] d10;
    logic [C11*W-1:0] d11;
    logic [C12*W-1:0] d12;

    generate
        for (genvar i = 0; i < BW; i++) begin : pp
            assign d0[i*W +: W] = (W'(a_i) << i) & {W{b_i[i]}};
        end
    endgenerate
    // ~x + 1 is the negation. The +1 is its own row so both signs can be set.
    assign d0[BW*W +: W]       = a_i[AW-1] ? ~(W'(b_i) << AW) : '0;
    assign d0[(BW+1)*W +: W]   = b_i[BW-1] ? ~(W'(a_i) << BW) : '0;
    assign d0[(BW+2)*W +: W]   = W'(a_i[AW-1]);
    assign d0[(BW+3)*W +: W]   = W'(b_i[BW-1]);

    upycore_csa_step #(.W(W), .N(C0))  s0  (.din(d0),  .dout(d1));
    upycore_csa_step #(.W(W), .N(C1))  s1  (.din(d1),  .dout(d2));
    upycore_csa_step #(.W(W), .N(C2))  s2  (.din(d2),  .dout(d3));
    upycore_csa_step #(.W(W), .N(C3))  s3  (.din(d3),  .dout(d4));
    upycore_csa_step #(.W(W), .N(C4))  s4  (.din(d4),  .dout(d5));
    upycore_csa_step #(.W(W), .N(C5))  s5  (.din(d5),  .dout(d6));
    upycore_csa_step #(.W(W), .N(C6))  s6  (.din(d6),  .dout(d7));
    upycore_csa_step #(.W(W), .N(C7))  s7  (.din(d7),  .dout(d8));
    upycore_csa_step #(.W(W), .N(C8))  s8  (.din(d8),  .dout(d9));
    upycore_csa_step #(.W(W), .N(C9))  s9  (.din(d9),  .dout(d10));
    upycore_csa_step #(.W(W), .N(C10)) s10 (.din(d10), .dout(d11));
    upycore_csa_step #(.W(W), .N(C11)) s11 (.din(d11), .dout(d12));

    upycore_add #(.W(W)) u_sum (
        .a_i(d12[W-1:0]), .b_i(d12[2*W-1:W]), .cin_i(1'b0),
        .sum_o(p_o), .cout_o()
    );
endmodule

// One 3:2 pass over N rows. Groups of three become a sum and a shifted
// carry; a leftover row is copied. N <= 2 is a wire. The carry out of the
// top bit does not affect the low W bits, which is all the product keeps.
(* syn_hier = "hard" *)
module upycore_csa_step #(
    parameter int W = 8,
    parameter int N = 3
) (
    input  logic [N*W-1:0] din,
    output logic [(((N <= 2) ? N : ((N/3)*2 + (N%3)))*W)-1:0] dout
);
    localparam int M  = (N <= 2) ? N : ((N/3)*2 + (N%3));
    localparam int NG = (N <= 2) ? 0 : (N/3);
    localparam int NR = (N <= 2) ? 0 : (N%3);

    generate
        if (N <= 2) begin : gen_copy
            assign dout = din;
        end else begin : gen_fold
            for (genvar g = 0; g < NG; g++) begin : grp
                logic [W-1:0] a, b, c, maj;
                assign a   = din[(3*g)*W +: W];
                assign b   = din[(3*g+1)*W +: W];
                assign c   = din[(3*g+2)*W +: W];
                assign maj = (a & b) | (a & c) | (b & c);
                assign dout[(2*g)*W +: W]     = a ^ b ^ c;
                assign dout[(2*g+1)*W +: W]   = {maj[W-2:0], 1'b0};
            end
            if (NR != 0) begin : gen_rest
                assign dout[(2*NG)*W +: (NR*W)] = din[(3*NG)*W +: (NR*W)];
            end
        end
    endgenerate
endmodule
