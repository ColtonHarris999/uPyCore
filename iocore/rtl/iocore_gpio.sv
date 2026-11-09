// The I/O core's GPIO: output, output enable and pulls per pin, a two-flop
// input synchronizer, and edge detection. Register rules:
// upycore/docs/mpy_io_core.md (GPIO). The edge and synchronizer rules are
// the epic branch's mpy_periph GPIO, moved onto the I/O bus; the set,
// clear and toggle registers are new, so firmware changes one pin in one
// store.
module iocore_gpio #(
    parameter int NPINS = 16
) (
    input  logic        clk_i,
    input  logic        rst_n_i,

    input  logic        sel_i,
    input  logic        we_i,
    input  logic [7:0]  off_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,
    output logic        irq_o,

    output logic [NPINS-1:0] out_o,
    output logic [NPINS-1:0] oe_o,
    output logic [NPINS-1:0] pu_o,
    output logic [NPINS-1:0] pd_o,
    input  logic [NPINS-1:0] in_i,
    // The synchronized levels and this clock's edges (for the timestamping
    // in iocore_top and the state page).
    output logic [NPINS-1:0] level_o,
    output logic [NPINS-1:0] hit_o
);
    localparam logic [7:0] O_OUT = 8'h00, O_SET = 8'h04, O_CLR = 8'h08, O_XOR = 8'h0C,
                           O_OE = 8'h10, O_PU = 8'h14, O_PD = 8'h18, O_IN = 8'h1C,
                           O_EDGE = 8'h20, O_STATUS = 8'h24, O_IRQEN = 8'h28;

    logic [NPINS-1:0] out_r, oe_r, pu_r, pd_r, s1_r, s2_r, in_r, stat_r, irqen_r, hit;
    logic [2*NPINS-1:0] edge_r;

    always_comb begin
        for (int i = 0; i < NPINS; i++) begin
            case (edge_r[2*i +: 2])
                2'd1:    hit[i] = !in_r[i] && s2_r[i];      // rising
                2'd2:    hit[i] = in_r[i] && !s2_r[i];      // falling
                2'd3:    hit[i] = in_r[i] != s2_r[i];       // both
                default: hit[i] = 1'b0;
            endcase
        end
    end

    assign out_o = out_r;
    assign oe_o  = oe_r;
    assign pu_o  = pu_r;
    assign pd_o  = pd_r;
    assign level_o = in_r;
    assign hit_o = hit;
    assign irq_o = |(stat_r & irqen_r);

    always_comb begin
        case (off_i)
            O_OUT:    rdata_o = 32'(out_r);
            O_OE:     rdata_o = 32'(oe_r);
            O_PU:     rdata_o = 32'(pu_r);
            O_PD:     rdata_o = 32'(pd_r);
            O_IN:     rdata_o = 32'(in_r);
            O_EDGE:   rdata_o = 32'(edge_r);
            O_STATUS: rdata_o = 32'(stat_r);
            O_IRQEN:  rdata_o = 32'(irqen_r);
            default:  rdata_o = 32'h0;
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            out_r <= '0; oe_r <= '0; pu_r <= '0; pd_r <= '0; s1_r <= '0; s2_r <= '0; in_r <= '0;
            stat_r <= '0; irqen_r <= '0; edge_r <= '0;
        end else begin
            s1_r <= in_i;
            s2_r <= s1_r;
            in_r <= s2_r;
            if (sel_i && we_i) begin
                case (off_i)
                    O_OUT:   out_r <= wdata_i[NPINS-1:0];
                    O_SET:   out_r <= out_r | wdata_i[NPINS-1:0];
                    O_CLR:   out_r <= out_r & ~wdata_i[NPINS-1:0];
                    O_XOR:   out_r <= out_r ^ wdata_i[NPINS-1:0];
                    O_OE:    oe_r <= wdata_i[NPINS-1:0];
                    O_PU:    pu_r <= wdata_i[NPINS-1:0];
                    O_PD:    pd_r <= wdata_i[NPINS-1:0];
                    O_EDGE:  edge_r <= wdata_i[2*NPINS-1:0];
                    O_IRQEN: irqen_r <= wdata_i[NPINS-1:0];
                    default: ;
                endcase
            end
            // STATUS: write 1 to clear; an edge on the same clock stays set.
            stat_r <= (stat_r & ~((sel_i && we_i && off_i == O_STATUS) ? wdata_i[NPINS-1:0] : '0)) | hit;
        end
    end
endmodule
