// Timing stand-in for iocore_usb in the island's open-flow timing run
// (iocore/tools/island_measure.py): every input ends in a flop and every
// output leaves one, as at the real block's io_clk edge, where its request
// and answer flops are. The SIE behind it runs on usb_clk and samples D+
// and D- on both edges (no2usb's SB_IO), which upycore/tools/sta does not
// model; its timing is the class flow's (usb_clk in constraints.tcl).
module iocore_usb (
    input  logic        io_clk_i,
    input  logic        rst_n_i,
    input  logic        req_i,
    input  logic [1:0]  kind_i,
    input  logic        we_i,
    input  logic [11:0] addr_i,
    input  logic [31:0] wdata_i,
    output logic        busy_o,
    output logic        done_o,
    output logic [31:0] rdata_o,
    output logic        irq_o,
    input  logic        usb_clk_i,
    inout  wire         usb_dp_io,
    inout  wire         usb_dn_io,
    output logic        usb_pu_o
);
    (* keep *) logic q_req, q_we;
    (* keep *) logic [1:0] q_kind;
    (* keep *) logic [11:0] q_addr;
    (* keep *) logic [31:0] q_wdata, q_out;
    always_ff @(posedge io_clk_i) begin
        q_req <= req_i; q_kind <= kind_i; q_we <= we_i; q_addr <= addr_i; q_wdata <= wdata_i;
        q_out <= q_out + 32'd1;
    end
    assign busy_o = q_out[0];
    assign done_o = q_out[1];
    assign irq_o = q_out[2];
    assign usb_pu_o = q_out[3];
    assign rdata_o = q_out;
    logic unused;
    assign unused = rst_n_i ^ usb_clk_i;
endmodule
