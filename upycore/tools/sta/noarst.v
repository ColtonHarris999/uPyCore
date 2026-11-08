(* techmap_celltype = "$_DFF_PN0_" *)
module _m_N0 (input C, D, R, output Q);
  \$_DFF_P_ _TECHMAP_REPLACE_ (.C(C), .D(D), .Q(Q));
endmodule

(* techmap_celltype = "$_DFF_PN1_" *)
module _m_N1 (input C, D, R, output Q);
  \$_DFF_P_ _TECHMAP_REPLACE_ (.C(C), .D(D), .Q(Q));
endmodule

(* techmap_celltype = "$_DFF_PP0_" *)
module _m_P0 (input C, D, R, output Q);
  \$_DFF_P_ _TECHMAP_REPLACE_ (.C(C), .D(D), .Q(Q));
endmodule

(* techmap_celltype = "$_DFF_PP1_" *)
module _m_P1 (input C, D, R, output Q);
  \$_DFF_P_ _TECHMAP_REPLACE_ (.C(C), .D(D), .Q(Q));
endmodule

(* techmap_celltype = "$_DFFE_PN0N_" *)
module _m_N0N (input C, D, R, E, output Q);
  \$_DFFE_PN_ _TECHMAP_REPLACE_ (.C(C), .D(D), .E(E), .Q(Q));
endmodule

(* techmap_celltype = "$_DFFE_PN0P_" *)
module _m_N0P (input C, D, R, E, output Q);
  \$_DFFE_PP_ _TECHMAP_REPLACE_ (.C(C), .D(D), .E(E), .Q(Q));
endmodule

(* techmap_celltype = "$_DFFE_PN1N_" *)
module _m_N1N (input C, D, R, E, output Q);
  \$_DFFE_PN_ _TECHMAP_REPLACE_ (.C(C), .D(D), .E(E), .Q(Q));
endmodule

(* techmap_celltype = "$_DFFE_PN1P_" *)
module _m_N1P (input C, D, R, E, output Q);
  \$_DFFE_PP_ _TECHMAP_REPLACE_ (.C(C), .D(D), .E(E), .Q(Q));
endmodule

(* techmap_celltype = "$_DFFE_PP0N_" *)
module _m_P0N (input C, D, R, E, output Q);
  \$_DFFE_PN_ _TECHMAP_REPLACE_ (.C(C), .D(D), .E(E), .Q(Q));
endmodule

(* techmap_celltype = "$_DFFE_PP0P_" *)
module _m_P0P (input C, D, R, E, output Q);
  \$_DFFE_PP_ _TECHMAP_REPLACE_ (.C(C), .D(D), .E(E), .Q(Q));
endmodule

(* techmap_celltype = "$_DFFE_PP1N_" *)
module _m_P1N (input C, D, R, E, output Q);
  \$_DFFE_PN_ _TECHMAP_REPLACE_ (.C(C), .D(D), .E(E), .Q(Q));
endmodule

(* techmap_celltype = "$_DFFE_PP1P_" *)
module _m_P1P (input C, D, R, E, output Q);
  \$_DFFE_PP_ _TECHMAP_REPLACE_ (.C(C), .D(D), .E(E), .Q(Q));
endmodule
