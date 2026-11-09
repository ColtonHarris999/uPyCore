// The I/O core's USB device: the vendored no2usb full-speed SIE
// (vendor/no2usb/rtl, unmodified, EPDW 32, no event FIFO) on its own 48 MHz
// usb_clk, endpoint buffers included, and a bridge that carries one I/O
// core access at a time across from io_clk. Spec: upycore/docs/mpy_io_core.md (USB)
//
// io_clk side: req_i takes an access (kind 0: the SIE's registers, word
// address addr_i[11:0] on its 16-bit Wishbone bus; 1: a word of the RX
// endpoint buffer; 2: a word of the TX endpoint buffer, address
// addr_i[8:0]); the inputs are held in flops and req_t toggles. busy_o is
// high from then until done_o, a one-clock pulse with rdata_o. usb_clk
// side: req_t through two flops starts the access (a Wishbone cycle until
// its ack, a buffer read whose data comes a clock later, or a buffer
// write), its answer is held in flops, and ack_t toggles back through two
// io_clk flops. The request flops are stable from the toggle until the
// answer, and the answer from its toggle until the next request, so every
// multi-bit word crosses as data behind a synchronized toggle.
//
// irq_o is the SIE's interrupt through two io_clk flops. The SIE is reset
// by rst_n_i (the island's power-on reset) through two usb_clk flops.
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
    localparam logic [1:0] K_CSR = 2'd0, K_RX = 2'd1, K_TX = 2'd2;

    // ---- io_clk side ----
    logic        req_t, busy_r;
    logic [1:0]  kind_r;
    logic        we_r;
    logic [11:0] addr_r;
    logic [31:0] wdata_r;
    logic [2:0]  ack_s;
    logic [1:0]  irq_s;
    logic [31:0] ans_r;          // usb_clk flops, read behind ack_t
    logic        ack_t;
    logic        u_irq;          // the SIE's interrupt (usb_clk)

    always_ff @(posedge io_clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            req_t <= 1'b0; busy_r <= 1'b0; kind_r <= K_CSR; we_r <= 1'b0; addr_r <= 12'h0;
            wdata_r <= 32'h0; ack_s <= 3'b000; irq_s <= 2'b00; done_o <= 1'b0; rdata_o <= 32'h0;
        end else begin
            ack_s <= {ack_s[1:0], ack_t};
            irq_s <= {irq_s[0], u_irq};
            done_o <= 1'b0;
            if (req_i && !busy_r) begin
                kind_r <= kind_i; we_r <= we_i; addr_r <= addr_i; wdata_r <= wdata_i;
                req_t <= !req_t;
                busy_r <= 1'b1;
            end else if (busy_r && ack_s[2] != ack_s[1]) begin
                busy_r <= 1'b0;
                done_o <= 1'b1;
                rdata_o <= ans_r;
            end
        end
    end
    assign busy_o = busy_r;
    assign irq_o = irq_s[1];

    // ---- usb_clk side ----
    logic [1:0]  rst_q;
    logic        u_rst;
    always_ff @(posedge usb_clk_i or negedge rst_n_i) begin
        if (!rst_n_i) rst_q <= 2'b00;
        else          rst_q <= {rst_q[0], 1'b1};
    end
    assign u_rst = !rst_q[1];

    logic [2:0]  req_s;
    logic        wb_cyc, rx_re, rx_wait, tx_we;
    logic [15:0] wb_rdata;
    logic        wb_ack;
    logic [31:0] ep_rx_data;

    always_ff @(posedge usb_clk_i or posedge u_rst) begin
        if (u_rst) begin
            req_s <= 3'b000; ack_t <= 1'b0; ans_r <= 32'h0;
            wb_cyc <= 1'b0; rx_re <= 1'b0; rx_wait <= 1'b0; tx_we <= 1'b0;
        end else begin
            req_s <= {req_s[1:0], req_t};
            rx_re <= 1'b0;
            tx_we <= 1'b0;
            if (req_s[2] != req_s[1]) begin
                case (kind_r)
                    K_CSR: wb_cyc <= 1'b1;
                    K_RX:  begin rx_re <= 1'b1; rx_wait <= 1'b1; end
                    default: begin
                        tx_we <= we_r;
                        ans_r <= 32'h0;
                        ack_t <= !ack_t;
                    end
                endcase
            end
            if (wb_cyc && wb_ack) begin
                wb_cyc <= 1'b0;
                ans_r <= {16'h0, wb_rdata};
                ack_t <= !ack_t;
            end
            // The buffer's read data comes the clock after rx_re.
            if (rx_wait && !rx_re) begin
                rx_wait <= 1'b0;
                ans_r <= ep_rx_data;
                ack_t <= !ack_t;
            end
        end
    end

    usb #(
        .TARGET("ICE40"),
        .EPDW(32),
        .EVT_DEPTH(0),
        .IRQ(1)
    ) u_usb (
        .pad_dp(usb_dp_io),
        .pad_dn(usb_dn_io),
        .pad_pu(usb_pu_o),
        .ep_tx_addr_0(addr_r[8:0]),
        .ep_tx_data_0(wdata_r),
        .ep_tx_we_0(tx_we),
        .ep_rx_addr_0(addr_r[8:0]),
        .ep_rx_data_1(ep_rx_data),
        .ep_rx_re_0(rx_re),
        .ep_clk(usb_clk_i),
        .wb_addr(addr_r),
        .wb_rdata(wb_rdata),
        .wb_wdata(wdata_r[15:0]),
        .wb_we(we_r),
        .wb_cyc(wb_cyc),
        .wb_ack(wb_ack),
        .irq(u_irq),
        .sof(),
        .clk(usb_clk_i),
        .rst(u_rst)
    );
endmodule

// no2usb sets `default_nettype none for its files; later files keep the default.
`default_nettype wire
