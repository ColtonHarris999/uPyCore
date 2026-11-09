// AHB-Lite master to the island's OBI-style bus, for the Hazard3 option of
// iocore_cpu. One OBI request per AHB transfer, in order.
//
// A read is requested in its address phase, so an SRAM answer ends the data
// phase on the next clock (no wait state). A write's data is only valid in
// its data phase, so the write is requested then and the data phase ends
// when its response comes (one wait state). A request the bus does not grant
// at once is repeated in the data phase until it is. An error response
// becomes AHB's two-clock ERROR response.
module iocore_ahb2obi (
    input  logic        clk_i,
    input  logic        rst_n_i,

    input  logic [31:0] haddr_i,
    input  logic        hwrite_i,
    input  logic [1:0]  htrans_i,
    input  logic [2:0]  hsize_i,
    input  logic [31:0] hwdata_i,
    output logic        hready_o,
    output logic        hresp_o,
    output logic [31:0] hrdata_o,

    output logic        req_o,
    input  logic        gnt_i,
    output logic        we_o,
    output logic [3:0]  be_o,
    output logic [31:0] addr_o,
    output logic [31:0] wdata_o,
    input  logic        rvalid_i,
    input  logic [31:0] rdata_i,
    input  logic        err_i
);
    logic        dp, dp_we, need, err2;
    logic [31:0] dp_addr;
    logic [2:0]  dp_size;
    logic        aph_go, aph_rd;

    function automatic logic [3:0] be_of(input logic [2:0] sz, input logic [1:0] a);
        case (sz)
            3'd0:    be_of = 4'b0001 << a;
            3'd1:    be_of = a[1] ? 4'b1100 : 4'b0011;
            default: be_of = 4'b1111;
        endcase
    endfunction

    // Data phase over: the transfer's response came (an error takes a
    // second clock).
    assign hready_o = !dp || (!need && rvalid_i && !err_i);
    assign hresp_o  = err2 || (dp && !need && rvalid_i && err_i);
    assign hrdata_o = rdata_i;

    assign aph_go = htrans_i[1] && hready_o;
    assign aph_rd = aph_go && !hwrite_i;

    always_comb begin
        if (dp && need) begin
            req_o = 1'b1; we_o = dp_we; addr_o = dp_addr; be_o = be_of(dp_size, dp_addr[1:0]);
        end else begin
            req_o = aph_rd; we_o = 1'b0; addr_o = haddr_i; be_o = be_of(hsize_i, haddr_i[1:0]);
        end
    end
    assign wdata_o = hwdata_i;

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            dp <= 1'b0; dp_we <= 1'b0; need <= 1'b0; err2 <= 1'b0;
            dp_addr <= 32'h0; dp_size <= 3'd0;
        end else begin
            // The second clock of an ERROR response.
            err2 <= dp && !need && rvalid_i && err_i;
            if (dp && need) begin
                if (gnt_i) need <= 1'b0;
            end else begin
                if (dp && !need && rvalid_i) dp <= 1'b0;
                if (aph_go) begin
                    dp      <= 1'b1;
                    dp_we   <= hwrite_i;
                    dp_addr <= haddr_i;
                    dp_size <= hsize_i;
                    need    <= hwrite_i || !gnt_i;
                end
            end
        end
    end
endmodule
