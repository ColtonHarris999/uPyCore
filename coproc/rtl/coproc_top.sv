// The USB coprocessor: a CVE2 core (RV32EMC), its code and data SRAMs, the
// coprocessor side of the mailbox, a port on the shared SRAM, and the no2usb
// full-speed SIE. Spec: upycore/docs/mpy_coproc.md (memory map, registers).
//
// Everything runs on cclk_i (48 MHz). rst_n_i is the power-on reset,
// already synchronized to cclk_i. Both core ports are granted on the clock
// they ask and answered on the next, except the SIE's register window,
// which is a Wishbone cycle held until its ack. An address outside the map
// answers with an error, which the core takes as an access fault.
//
// +COPROC=<hex> preloads the code SRAM ($readmemh, one 32-bit word a line);
// +COPROC_LOG=<path> collects the bytes stored to CMB_DEBUG.
module coproc_top #(
    parameter int CODE_WORDS = 4096,    // 16 KB
    parameter int DATA_WORDS = 2048,    // 8 KB
    parameter int MB_AW = 4
) (
    input  logic            cclk_i,
    input  logic            rst_n_i,

    // Mailbox (mpy_mbox): the down FIFO's read side, the up FIFO's write side.
    output logic            mb_pop_o,
    input  logic [31:0]     mb_data_i,
    input  logic            mb_empty_i,
    input  logic [MB_AW:0]  mb_level_i,
    output logic            mb_push_o,
    output logic [31:0]     mb_wdata_o,
    input  logic            mb_full_i,
    input  logic [MB_AW:0]  mb_wlevel_i,
    output logic            mb_kbd_toggle_o,

    // Shared SRAM, port B (mpy_shared_ram).
    output logic            sh_en_o,
    output logic [3:0]      sh_be_o,
    output logic [9:0]      sh_addr_o,
    output logic [31:0]     sh_wdata_o,
    input  logic [31:0]     sh_rdata_i,

    // USB pads: D+ and D- are tristate; usb_pu_o switches the 1.5k pull-up.
    inout  wire             usb_dp_io,
    inout  wire             usb_dn_io,
    output logic            usb_pu_o
);
    // ---- memories ----
    logic [31:0] code [0:CODE_WORDS-1];
    logic [31:0] dram [0:DATA_WORDS-1];

`ifndef SYNTHESIS
    integer log_fd;
    initial begin
        string path;
        for (int i = 0; i < CODE_WORDS; i++) code[i] = 32'h0;
        for (int i = 0; i < DATA_WORDS; i++) dram[i] = 32'h0;
        if ($value$plusargs("COPROC=%s", path)) $readmemh(path, code);
        log_fd = 0;
        if ($value$plusargs("COPROC_LOG=%s", path)) log_fd = $fopen(path, "wb");
    end
`endif

    // ---- core ----
    logic        i_req, i_gnt, i_rvalid, i_err;
    logic [31:0] i_addr, i_rdata;
    logic        d_req, d_gnt, d_rvalid, d_we, d_err;
    logic [3:0]  d_be;
    logic [31:0] d_addr, d_wdata, d_rdata;
    logic [15:0] irq_fast;

    cve2_top #(
        .MHPMCounterNum(0),
        .RV32E(1'b1),
        .RV32M(cve2_pkg::RV32MFast)
    ) u_core (
        .clk_i(cclk_i), .rst_ni(rst_n_i),
        .test_en_i(1'b0), .ram_cfg_i('0),
        // CVE2 starts at boot_addr and takes mtvec from its upper bits: reset
        // at 0x80, the vector table at 0 (coproc/sw/common/crt0.S).
        .hart_id_i(32'h0), .boot_addr_i(32'h80),
        .instr_req_o(i_req), .instr_gnt_i(i_gnt), .instr_rvalid_i(i_rvalid),
        .instr_addr_o(i_addr), .instr_rdata_i(i_rdata), .instr_err_i(i_err),
        .data_req_o(d_req), .data_gnt_i(d_gnt), .data_rvalid_i(d_rvalid),
        .data_we_o(d_we), .data_be_o(d_be), .data_addr_o(d_addr),
        .data_wdata_o(d_wdata), .data_rdata_i(d_rdata), .data_err_i(d_err),
        .x_issue_valid_o(), .x_issue_ready_i(1'b0), .x_issue_req_o(), .x_issue_resp_i('0),
        .x_register_o(), .x_commit_valid_o(), .x_commit_o(),
        .x_result_valid_i(1'b0), .x_result_ready_o(), .x_result_i('0),
        .irq_software_i(1'b0), .irq_timer_i(1'b0), .irq_external_i(1'b0),
        .irq_fast_i(irq_fast), .irq_nm_i(1'b0),
        .debug_req_i(1'b0), .debug_halted_o(), .dm_halt_addr_i(32'h0),
        .dm_exception_addr_i(32'h0), .crash_dump_o(),
        .fetch_enable_i(1'b1), .core_sleep_o()
    );

    // ---- instruction port: code SRAM only ----
    assign i_gnt = i_req;
    always_ff @(posedge cclk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            i_rvalid <= 1'b0; i_err <= 1'b0; i_rdata <= 32'h0;
        end else begin
            i_rvalid <= i_req;
            i_err    <= i_req && (i_addr >= 32'(CODE_WORDS * 4));
            i_rdata  <= code[i_addr[$clog2(CODE_WORDS)+1:2]];
        end
    end

    // ---- data port decode ----
    localparam logic [3:0] R_NONE = 4'd0, R_CODE = 4'd1, R_DATA = 4'd2, R_MBOX = 4'd3,
                           R_SHARED = 4'd4, R_USB = 4'd5, R_USB_RX = 4'd6, R_USB_TX = 4'd7;

    function automatic logic [3:0] region(input logic [31:0] a);
        if (a < 32'(CODE_WORDS * 4))                                   return R_CODE;
        if (a >= 32'h0001_0000 && a < 32'h0001_0000 + 32'(DATA_WORDS * 4)) return R_DATA;
        if (a[31:6] == 26'(32'h8000_0000 >> 6))                          return R_MBOX;
        if (a[31:12] == 20'h8000_4)                                      return R_SHARED;
        if (a[31:14] == 18'(32'h8001_0000 >> 14))                        return R_USB;
        if (a[31:11] == 21'(32'h8002_0000 >> 11))                        return R_USB_RX;
        if (a[31:11] == 21'(32'h8003_0000 >> 11))                        return R_USB_TX;
        return R_NONE;
    endfunction

    localparam logic [5:0] CMB_TX = 6'h00, CMB_RX = 6'h04, CMB_STATUS = 6'h08, CMB_KBD = 6'h0C,
                           CMB_IRQEN = 6'h10, CMB_CYCLES = 6'h14, CMB_DEBUG = 6'h18;

    logic [3:0]  rgn;
    logic        take;           // a request granted this clock
    logic        wb_busy_r, wb_ack;
    logic [11:0] wb_addr_r;
    logic [15:0] wb_wdata_r, wb_rdata;
    logic        wb_we_r;
    logic [3:0]  sel_q;
    logic [31:0] rdata_q;
    logic        mb_ovr_r;
    logic [1:0]  irqen_r;
    logic [31:0] cycles_r;
    logic        usb_irq;
    logic [31:0] ep_rx_data;

    assign rgn  = region(d_addr);
    // The SIE's registers take a Wishbone cycle; nothing else waits.
    assign d_gnt = d_req && !wb_busy_r && !(d_rvalid && sel_q == R_USB);
    assign take  = d_req && d_gnt;

    // Mailbox: pop and push on the clock the request is taken.
    assign mb_pop_o   = take && rgn == R_MBOX && !d_we && d_addr[5:0] == CMB_RX && !mb_empty_i;
    assign mb_push_o  = take && rgn == R_MBOX && d_we && d_addr[5:0] == CMB_TX && !mb_full_i;
    assign mb_wdata_o = d_wdata;

    // Shared SRAM: the word comes out after the taking clock.
    assign sh_en_o    = take && rgn == R_SHARED;
    assign sh_be_o    = d_we ? d_be : 4'h0;
    assign sh_addr_o  = d_addr[11:2];
    assign sh_wdata_o = d_wdata;

    assign irq_fast = {14'h0, usb_irq && irqen_r[1], !mb_empty_i && irqen_r[0]};

    always_comb begin
        case (sel_q)
            R_SHARED: d_rdata = sh_rdata_i;
            R_USB_RX: d_rdata = ep_rx_data;
            default:  d_rdata = rdata_q;
        endcase
    end

    always_ff @(posedge cclk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            d_rvalid <= 1'b0; d_err <= 1'b0; sel_q <= R_NONE; rdata_q <= 32'h0;
            mb_ovr_r <= 1'b0; irqen_r <= 2'b00; cycles_r <= 32'h0; mb_kbd_toggle_o <= 1'b0;
            wb_busy_r <= 1'b0; wb_addr_r <= 12'h0; wb_wdata_r <= 16'h0; wb_we_r <= 1'b0;
        end else begin
            cycles_r <= cycles_r + 32'd1;
            d_rvalid <= 1'b0;
            d_err    <= 1'b0;
            if (wb_busy_r) begin
                if (wb_ack) begin
                    wb_busy_r <= 1'b0;
                    d_rvalid  <= 1'b1;
                    rdata_q   <= {16'h0, wb_rdata};
                    sel_q     <= R_USB;
                end
            end else if (take) begin
                sel_q <= rgn;
                case (rgn)
                    R_CODE: begin
                        d_rvalid <= 1'b1;
                        rdata_q  <= code[d_addr[$clog2(CODE_WORDS)+1:2]];
                    end
                    R_DATA: begin
                        d_rvalid <= 1'b1;
                        rdata_q  <= dram[d_addr[$clog2(DATA_WORDS)+1:2]];
                    end
                    R_MBOX: begin
                        d_rvalid <= 1'b1;
                        rdata_q  <= 32'h0;
                        if (d_we) begin
                            case (d_addr[5:0])
                                CMB_TX:     if (mb_full_i) mb_ovr_r <= 1'b1;
                                CMB_STATUS: if (d_wdata[18]) mb_ovr_r <= 1'b0;
                                CMB_KBD:    mb_kbd_toggle_o <= !mb_kbd_toggle_o;
                                CMB_IRQEN:  irqen_r <= d_wdata[1:0];
`ifndef SYNTHESIS
                                CMB_DEBUG:  if (log_fd != 0) begin $fwrite(log_fd, "%c", d_wdata[7:0]); $fflush(log_fd); end
`endif
                                default: ;
                            endcase
                        end else begin
                            case (d_addr[5:0])
                                CMB_RX:     rdata_q <= mb_empty_i ? 32'h0 : mb_data_i;
                                CMB_STATUS: rdata_q <= {13'h0, mb_ovr_r, !mb_empty_i, mb_full_i,
                                                        3'h0, 5'(mb_wlevel_i), 3'h0, 5'(mb_level_i)};
                                CMB_IRQEN:  rdata_q <= {30'h0, irqen_r};
                                CMB_CYCLES: rdata_q <= cycles_r;
                                default:    rdata_q <= 32'h0;
                            endcase
                        end
                    end
                    R_SHARED, R_USB_RX, R_USB_TX: d_rvalid <= 1'b1;
                    R_USB: begin
                        wb_busy_r  <= 1'b1;
                        wb_addr_r  <= d_addr[13:2];
                        wb_wdata_r <= d_wdata[15:0];
                        wb_we_r    <= d_we;
                    end
                    default: begin d_rvalid <= 1'b1; d_err <= 1'b1; end
                endcase
            end
        end
    end

    // Data SRAM stores, with byte enables.
    always_ff @(posedge cclk_i) begin
        if (take && rgn == R_DATA && d_we)
            for (int k = 0; k < 4; k++)
                if (d_be[k]) dram[d_addr[$clog2(DATA_WORDS)+1:2]][8*k +: 8] <= d_wdata[8*k +: 8];
    end

    // ---- USB SIE ----
    logic usb_rst;
    assign usb_rst = !rst_n_i;

    usb #(
        .TARGET("ICE40"),
        .EPDW(32),
        .EVT_DEPTH(0),
        .IRQ(1)
    ) u_usb (
        .pad_dp(usb_dp_io),
        .pad_dn(usb_dn_io),
        .pad_pu(usb_pu_o),
        .ep_tx_addr_0(d_addr[10:2]),
        .ep_tx_data_0(d_wdata),
        .ep_tx_we_0(take && rgn == R_USB_TX && d_we),
        .ep_rx_addr_0(d_addr[10:2]),
        .ep_rx_data_1(ep_rx_data),
        .ep_rx_re_0(take && rgn == R_USB_RX),
        .ep_clk(cclk_i),
        .wb_addr(wb_addr_r),
        .wb_rdata(wb_rdata),
        .wb_wdata(wb_wdata_r),
        .wb_we(wb_we_r),
        .wb_cyc(wb_busy_r),
        .wb_ack(wb_ack),
        .irq(usb_irq),
        .sof(),
        .clk(cclk_i),
        .rst(usb_rst)
    );
endmodule
