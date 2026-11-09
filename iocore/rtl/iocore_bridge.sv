// The I/O core's side of the hart bridge, at 0x8000_3000 on the island bus.
// Register rules: upycore/docs/mpy_io_core.md (Bridge, I/O core side). The
// FIFOs themselves are in mpy_iobr (hart side); these are their io_clk ends.
//
// A store that would push into a full FIFO (RSP, EVT, CON_RX, UPD) is not
// taken: ready_o is low and the core waits, so nothing is dropped. Loads of
// CMD and CON pop on the clock they are taken.
module iocore_bridge #(
    parameter int NUP = 32,
    parameter int NDN = 8
) (
    input  logic        clk_i,
    input  logic        rst_n_i,

    input  logic        sel_i,
    input  logic        we_i,
    input  logic [11:0] off_i,
    input  logic [31:0] wdata_i,
    output logic        ready_o,
    output logic [31:0] rdata_o,
    output logic        irq_o,

    output logic        cmd_pop_o,
    input  logic [31:0] cmd_data_i,
    input  logic        cmd_empty_i,
    input  logic [5:0]  cmd_level_i,
    output logic        rsp_push_o,
    output logic [31:0] rsp_data_o,
    input  logic        rsp_full_i,
    output logic        evt_push_o,
    output logic [15:0] evt_data_o,
    input  logic        evt_full_i,
    output logic        con_pop_o,
    input  logic [8:0]  con_data_i,
    input  logic        con_empty_i,
    input  logic [6:0]  con_level_i,
    output logic        conrx_push_o,
    output logic [7:0]  conrx_data_o,
    input  logic        conrx_full_i,
    output logic        upd_push_o,
    output logic [36:0] upd_data_o,
    input  logic        upd_full_i,
    output logic        dn_pop_o,
    input  logic [34:0] dn_data_i,
    input  logic        dn_empty_i
);
    localparam logic [11:0] O_CMD = 12'h000, O_CMD_LEVEL = 12'h004, O_RSP = 12'h008, O_EVT = 12'h00C,
                            O_CON = 12'h010, O_CONRX = 12'h014, O_STATUS = 12'h018, O_IRQEN = 12'h01C,
                            O_DN_NEW = 12'h020;

    logic        is_up, is_dn;
    logic [2:0]  irqen_r;
    logic [31:0] dn_r [0:NDN-1];
    logic [NDN-1:0] dn_new_r;

    assign is_up = off_i[11:10] == 2'b10;    // 0x800: page words the hart reads
    assign is_dn = off_i[11:10] == 2'b11;    // 0xC00: page words the hart writes

    assign ready_o = !(we_i && ((off_i == O_RSP && rsp_full_i) || (off_i == O_EVT && evt_full_i) ||
                                (off_i == O_CONRX && conrx_full_i) || (is_up && upd_full_i)));

    assign cmd_pop_o    = sel_i && !we_i && off_i == O_CMD && !cmd_empty_i;
    assign con_pop_o    = sel_i && !we_i && off_i == O_CON && !con_empty_i;
    assign rsp_push_o   = sel_i && we_i && off_i == O_RSP;
    assign rsp_data_o   = wdata_i;
    assign evt_push_o   = sel_i && we_i && off_i == O_EVT;
    assign evt_data_o   = wdata_i[15:0];
    assign conrx_push_o = sel_i && we_i && off_i == O_CONRX;
    assign conrx_data_o = wdata_i[7:0];
    assign upd_push_o   = sel_i && we_i && is_up;
    assign upd_data_o   = {off_i[2 +: 5], wdata_i};
    // The hart's page words land in dn_r as they arrive.
    assign dn_pop_o     = !dn_empty_i;

    assign irq_o = (irqen_r[0] && !cmd_empty_i) || (irqen_r[1] && !con_empty_i) ||
                   (irqen_r[2] && |dn_new_r);

    always_comb begin
        rdata_o = 32'h0;
        if (is_dn)
            rdata_o = dn_r[off_i[2 +: $clog2(NDN)]];
        else case (off_i)
            O_CMD:       rdata_o = cmd_empty_i ? 32'h0 : cmd_data_i;
            O_CMD_LEVEL: rdata_o = {26'h0, cmd_level_i};
            O_CON:       rdata_o = {!con_empty_i, 22'h0, con_empty_i ? 9'h0 : con_data_i};
            O_STATUS:    rdata_o = {1'b0, con_level_i, 2'h0, cmd_level_i, 9'h0, !dn_empty_i,
                                    upd_full_i, evt_full_i, conrx_full_i, rsp_full_i,
                                    !con_empty_i, !cmd_empty_i};
            O_IRQEN:     rdata_o = {29'h0, irqen_r};
            O_DN_NEW:    rdata_o = 32'(dn_new_r);
            default:     rdata_o = 32'h0;
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            irqen_r <= 3'h0; dn_new_r <= '0;
            for (int i = 0; i < NDN; i++) dn_r[i] <= 32'h0;
        end else begin
            if (sel_i && we_i && off_i == O_IRQEN) irqen_r <= wdata_i[2:0];
            // DN_NEW: a bit per hart word that changed since the last read
            // of DN_NEW (the read clears the bits it returned).
            dn_new_r <= (dn_new_r & ~((sel_i && !we_i && off_i == O_DN_NEW) ? dn_new_r : '0))
                        | ((!dn_empty_i) ? (NDN'(1) << dn_data_i[32 +: $clog2(NDN)]) : '0);
            if (!dn_empty_i) dn_r[dn_data_i[32 +: $clog2(NDN)]] <= dn_data_i[31:0];
        end
    end
endmodule
