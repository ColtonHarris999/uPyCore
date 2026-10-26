// The hart's side of the coprocessor mailbox, MMIO offset 0x100, and the
// clock crossing to the coprocessor's side. Spec:
// upycore/docs/mpy_peripherals.md (Mailbox) and upycore/docs/mpy_coproc.md.
//
// Two dual-clock FIFOs: down (the hart writes, the coprocessor reads) and up
// (the other way). The FIFOs and the KBD synchronizer run on the power-on
// reset, so a system reset of the hart keeps the words in flight; only the
// sticky overrun bit is on the hart's system reset. A console byte
// (SYS_CONSOLE = 2) is pushed as a CON word through con_stb_i, taken on a
// clock with con_ready_o. mbox_set_o pulses when words reach the up FIFO's
// read side; kbd_set_o pulses on each CMB_KBD doorbell. Offsets outside
// 0x100..0x1FF read 0.
module mpy_mbox #(
    parameter int AW = 4
) (
    input  logic        clk_i,
    input  logic        rst_n_i,        // the hart's system reset
    input  logic        por_n_i,        // power-on, the hart's clock

    input  logic        req_i,
    input  logic        we_i,
    input  logic [11:0] off_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    input  logic        con_stb_i,
    input  logic [7:0]  con_byte_i,
    output logic        con_ready_o,

    output logic        mbox_set_o,
    output logic        kbd_set_o,

    // The coprocessor's side, on cclk_i.
    input  logic        cclk_i,
    input  logic        crst_n_i,       // power-on, synchronized to cclk_i
    input  logic        c_pop_i,        // down FIFO
    output logic [31:0] c_data_o,
    output logic        c_empty_o,
    output logic [AW:0] c_level_o,
    input  logic        c_push_i,       // up FIFO
    input  logic [31:0] c_wdata_i,
    output logic        c_full_o,
    output logic [AW:0] c_wlevel_o,
    input  logic        c_kbd_toggle_i
);
    localparam logic [11:0] MBOX_TX     = 12'h100;
    localparam logic [11:0] MBOX_RX     = 12'h104;
    localparam logic [11:0] MBOX_STATUS = 12'h108;

    logic          d_push, d_full, u_pop, u_empty;
    logic [31:0]   d_wdata, u_data;
    logic [AW:0]   d_level, u_level;
    logic          u_new;
    logic          ovr_r;
    logic          wr_tx, rd_rx;
    logic [2:0]    kbd_sync;

    assign wr_tx = req_i && we_i && (off_i == MBOX_TX);
    assign rd_rx = req_i && !we_i && (off_i == MBOX_RX);

    // A store and a console byte share the down FIFO's write side; the core
    // makes one access at a time.
    assign d_push  = (wr_tx || con_stb_i) && !d_full;
    assign d_wdata = con_stb_i ? {24'h0, con_byte_i} : wdata_i;
    assign con_ready_o = !d_full;
    assign u_pop = rd_rx;

    mpy_async_fifo #(.W(32), .AW(AW)) u_down (
        .wclk(clk_i), .wrst_n(por_n_i), .w_en(d_push), .w_data(d_wdata),
        .w_full(d_full), .w_level(d_level),
        .rclk(cclk_i), .rrst_n(crst_n_i), .r_en(c_pop_i), .r_data(c_data_o),
        .r_empty(c_empty_o), .r_level(c_level_o), .r_new()
    );

    mpy_async_fifo #(.W(32), .AW(AW)) u_up (
        .wclk(cclk_i), .wrst_n(crst_n_i), .w_en(c_push_i), .w_data(c_wdata_i),
        .w_full(c_full_o), .w_level(c_wlevel_o),
        .rclk(clk_i), .rrst_n(por_n_i), .r_en(u_pop), .r_data(u_data),
        .r_empty(u_empty), .r_level(u_level), .r_new(u_new)
    );

    always_comb begin
        rdata_o = 32'h0;
        if (req_i && !we_i) begin
            case (off_i)
                MBOX_RX:     rdata_o = u_empty ? 32'h0 : u_data;
                MBOX_STATUS: rdata_o = {13'h0, ovr_r, !u_empty, d_full,
                                        3'h0, 5'(d_level), 3'h0, 5'(u_level)};
                default:     rdata_o = 32'h0;
            endcase
        end
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) ovr_r <= 1'b0;
        else if (wr_tx && d_full) ovr_r <= 1'b1;
        else if (req_i && we_i && off_i == MBOX_STATUS && wdata_i[18]) ovr_r <= 1'b0;
    end

    always_ff @(posedge clk_i or negedge por_n_i) begin
        if (!por_n_i) begin
            kbd_sync <= 3'b000; mbox_set_o <= 1'b0; kbd_set_o <= 1'b0;
        end else begin
            mbox_set_o <= u_new;
            kbd_sync   <= {kbd_sync[1:0], c_kbd_toggle_i};
            kbd_set_o  <= kbd_sync[2] ^ kbd_sync[1];
        end
    end
endmodule
