// The I/O island: the I/O core (iocore_cpu), its code and data SRAMs, its
// bus, and its peripherals. Everything here runs on io_clk_i.
// Spec: upycore/docs/mpy_io_core.md (memory map, registers).
//
// Memory map (I/O core view):
//   0x0000_0000  code SRAM, CODE_WORDS words. The instruction port only; a
//                data access faults. Vectors at 0, reset at 0x80.
//   0x0001_0000  data SRAM, DATA_WORDS words. .rodata, .data, .bss, stack.
//   0x8000_0000  SYS: id, debug byte, halt, interrupt controller
//   0x8000_1000  timer (iocore_timer)
//   0x8000_2000  UART0 (iocore_uart)
//   0x8000_3000  the bridge to the hart (iocore_bridge; FIFOs in mpy_iobr)
//   0x8000_4000  GPIO (iocore_gpio)
// Anything else answers with an error (a load or store access fault).
//
// Both SRAMs are one-port macros (bsg_mem_1rw_sync_mask_write_bit, which
// the synthesis flow swaps for fakeram). While run_i is low the core is in
// reset and the load port (ld_*) writes them; mpy_boot drives it from the
// boot stream's IOCB section (upycore/docs/mpy_boot.md).
module iocore_top #(
    parameter int CORE = 0,               // iocore_cpu: 0 CVE2, 1 Hazard3
    parameter int MUL = 0,
    parameter int CODE_WORDS = 4096,      // 16 KB
    parameter int DATA_WORDS = 2048,      // 8 KB
    parameter logic [15:0] US_DIV_RESET = 16'd49,
    parameter logic [15:0] BAUD_RESET = 16'd0,
    parameter int NPINS = 16,
    parameter int IOCLK_HZ = 50_000_000   // SYS FREQ; +IO_CLK_HZ (or the bench's +IO_CLK_NS) overrides it in simulation
) (
    input  logic        io_clk_i,
    input  logic        io_rst_n_i,       // power-on reset, synchronized to io_clk_i
    input  logic        run_i,            // release the core (synchronized here)
    input  logic [1:0]  con_mode_i,       // the console strap (a pin; synchronized here)

    input  logic        ld_valid_i,
    input  logic [48:0] ld_data_i,        // {1 data SRAM / 0 code SRAM, word index, word}
    output logic        ld_pop_o,

    // The bridge FIFOs' io_clk ends (mpy_iobr).
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
    input  logic        dn_empty_i,

    input  logic        uart_rxd_i,
    output logic        uart_txd_o,

    output logic [NPINS-1:0] gpio_o,
    output logic [NPINS-1:0] gpio_oe_o,
    output logic [NPINS-1:0] gpio_pu_o,
    output logic [NPINS-1:0] gpio_pd_o,
    input  logic [NPINS-1:0] gpio_i,

    // The timer's microsecond and millisecond counts in gray code, from
    // flops, for mpy_iobr's tick crossing (one bit changes per count).
    output logic [31:0] us_gray_o,
    output logic [31:0] ms_gray_o,

    // Simulation and bring-up: a store to SYS DEBUG / HALT.
    output logic        dbg_valid_o,
    output logic [7:0]  dbg_byte_o,
    output logic        halt_o,
    output logic [31:0] halt_value_o,
    output logic        sleep_o
);
    localparam int CAW = $clog2(CODE_WORDS);
    localparam int DAW = $clog2(DATA_WORDS);
    localparam logic [31:0] ID = 32'h494F_4301;   // "IOC", version 1

    // ---- core reset: run_i through two flops ----
    // In simulation the flops start released, so the first clock of
    // io_rst_n_i or of run_i low is a falling edge on core_rst_n: CVE2's
    // registers sit behind its own clock gate and see only the async reset.
    logic [1:0] run_q;
    logic       core_rst_n;
`ifndef SYNTHESIS
    initial run_q = 2'b11;
`endif
    always_ff @(posedge io_clk_i or negedge io_rst_n_i) begin
        if (!io_rst_n_i) run_q <= 2'b00;
        else             run_q <= {run_q[0], run_i};
    end
    assign core_rst_n = run_q[1];

    // ---- core ----
    logic        i_req, i_gnt, i_rvalid, i_err;
    logic [31:0] i_addr, i_rdata;
    logic        d_req, d_gnt, d_rvalid, d_we, d_err;
    logic [3:0]  d_be;
    logic [31:0] d_addr, d_wdata, d_rdata;
    logic        irq_timer, irq_ext;

    iocore_cpu #(.CORE(CORE), .MUL(MUL)) u_cpu (
        .clk_i(io_clk_i), .rst_n_i(core_rst_n),
        .i_req_o(i_req), .i_gnt_i(i_gnt), .i_addr_o(i_addr),
        .i_rvalid_i(i_rvalid), .i_rdata_i(i_rdata), .i_err_i(i_err),
        .d_req_o(d_req), .d_gnt_i(d_gnt), .d_we_o(d_we), .d_be_o(d_be), .d_addr_o(d_addr),
        .d_wdata_o(d_wdata), .d_rvalid_i(d_rvalid), .d_rdata_i(d_rdata), .d_err_i(d_err),
        .irq_timer_i(irq_timer), .irq_ext_i(irq_ext), .core_sleep_o(sleep_o)
    );

    // ---- load port ----
    logic        ld_we, ld_data;
    logic [15:0] ld_idx_i;
    logic [31:0] ld_wdata_i;
    assign ld_we      = ld_valid_i;
    assign ld_pop_o   = ld_valid_i;
    assign ld_data    = ld_data_i[48];
    assign ld_idx_i   = ld_data_i[47:32];
    assign ld_wdata_i = ld_data_i[31:0];

    // ---- code SRAM: instruction port, load port ----
    logic           c_v, c_w;
    logic [CAW-1:0] c_a;
    logic [31:0]    c_d, c_q;
    logic           i_bad;
    assign i_bad = (i_addr >= 32'(CODE_WORDS * 4));
    assign i_gnt = i_req && core_rst_n;
    assign c_v = ld_we ? !ld_data : (i_req && i_gnt && !i_bad);
    assign c_w = ld_we;
    assign c_a = ld_we ? CAW'(ld_idx_i) : i_addr[CAW+1:2];
    assign c_d = ld_wdata_i;
    bsg_mem_1rw_sync_mask_write_bit #(.width_p(32), .els_p(CODE_WORDS)) u_code (
        .clk_i(io_clk_i), .reset_i(1'b0), .data_i(c_d), .addr_i(c_a), .v_i(c_v),
        .w_mask_i(32'hFFFF_FFFF), .w_i(c_w), .data_o(c_q)
    );
    always_ff @(posedge io_clk_i or negedge core_rst_n) begin
        if (!core_rst_n) begin
            i_rvalid <= 1'b0; i_err <= 1'b0;
        end else begin
            i_rvalid <= i_req && i_gnt;
            i_err    <= i_req && i_gnt && i_bad;
        end
    end
    assign i_rdata = c_q;

    // ---- data port decode ----
    localparam logic [3:0] R_NONE = 4'd0, R_DATA = 4'd1, R_SYS = 4'd2, R_TIMER = 4'd3,
                           R_UART = 4'd4, R_BRIDGE = 4'd5, R_GPIO = 4'd6;
    function automatic logic [3:0] region(input logic [31:0] a);
        if (a >= 32'h0001_0000 && a < 32'h0001_0000 + 32'(DATA_WORDS * 4)) return R_DATA;
        if (a[31:12] == 20'h80000) return R_SYS;
        if (a[31:12] == 20'h80001) return R_TIMER;
        if (a[31:12] == 20'h80002) return R_UART;
        if (a[31:12] == 20'h80003) return R_BRIDGE;
        if (a[31:12] == 20'h80004) return R_GPIO;
        return R_NONE;
    endfunction

    logic [3:0]  rgn, sel_q;
    logic        take, uart_ready, br_ready;
    logic [31:0] rdata_q, timer_rdata, uart_rdata, sys_rdata, br_rdata, gpio_rdata;
    logic        uart_irq, br_irq, gpio_irq;
    logic [7:0]  off;
    // Peripheral registers are words; a byte or halfword access to one is
    // an error, so firmware cannot store half a register.
    logic        bad_size;

    assign rgn = region(d_addr);
    assign off = d_addr[7:0];
    assign bad_size = (rgn != R_DATA) && (d_be != 4'hF || d_addr[1:0] != 2'b00);
    assign d_gnt = d_req && ((rgn != R_UART || uart_ready) && (rgn != R_BRIDGE || br_ready) || bad_size);
    assign take  = d_req && d_gnt;

    // ---- data SRAM ----
    logic           m_v, m_w;
    logic [DAW-1:0] m_a;
    logic [31:0]    m_d, m_mask, m_q;
    always_comb begin
        if (ld_we) begin
            m_v = ld_data; m_w = 1'b1; m_a = DAW'(ld_idx_i); m_d = ld_wdata_i; m_mask = '1;
        end else begin
            m_v = take && rgn == R_DATA; m_w = d_we; m_a = d_addr[DAW+1:2]; m_d = d_wdata;
            m_mask = {{8{d_be[3]}}, {8{d_be[2]}}, {8{d_be[1]}}, {8{d_be[0]}}};
        end
    end
    bsg_mem_1rw_sync_mask_write_bit #(.width_p(32), .els_p(DATA_WORDS)) u_data (
        .clk_i(io_clk_i), .reset_i(1'b0), .data_i(m_d), .addr_i(m_a), .v_i(m_v),
        .w_mask_i(m_mask), .w_i(m_w), .data_o(m_q)
    );

    // ---- SYS block: id, debug, halt, interrupt controller ----
    localparam logic [7:0] S_ID = 8'h00, S_DEBUG = 8'h04, S_HALT = 8'h08, S_IRQ_PEND = 8'h0C,
                           S_IRQ_EN = 8'h10, S_SCRATCH = 8'h14, S_FREQ = 8'h18, S_CON_MODE = 8'h1C;
    logic [1:0] cm_s1, cm_s2;
    always_ff @(posedge io_clk_i or negedge io_rst_n_i) begin
        if (!io_rst_n_i) begin cm_s1 <= 2'd0; cm_s2 <= 2'd0; end
        else begin cm_s1 <= con_mode_i; cm_s2 <= cm_s1; end
    end
    logic [31:0] freq;
`ifdef SYNTHESIS
    assign freq = 32'(IOCLK_HZ);
`else
    int unsigned sim_hz;
    initial begin
        real ns;
        if (!$value$plusargs("IO_CLK_HZ=%d", sim_hz)) begin
            if ($value$plusargs("IO_CLK_NS=%f", ns)) sim_hz = int'(1.0e9 / ns);
            else sim_hz = IOCLK_HZ;
        end
    end
    assign freq = sim_hz;
`endif
    localparam int NIRQ = 8;
    logic [NIRQ-1:0] irq_src, irq_en_r;
    logic [31:0]     scratch_r;
    logic            sys_sel, timer_sel, uart_sel, br_sel, gpio_sel;
    assign sys_sel   = take && !bad_size && rgn == R_SYS;
    assign timer_sel = take && !bad_size && rgn == R_TIMER;
    assign uart_sel  = take && !bad_size && rgn == R_UART;
    assign br_sel    = take && !bad_size && rgn == R_BRIDGE;
    assign gpio_sel  = take && !bad_size && rgn == R_GPIO;

    // Sources: 0 UART0, 1 bridge, 2 GPIO. The rest are assigned as blocks
    // are added.
    assign irq_src = {{(NIRQ-3){1'b0}}, gpio_irq, br_irq, uart_irq};
    assign irq_ext = |(irq_src & irq_en_r);

    always_comb begin
        case (off)
            S_ID:       sys_rdata = ID;
            S_IRQ_PEND: sys_rdata = 32'(irq_src);
            S_IRQ_EN:   sys_rdata = 32'(irq_en_r);
            S_SCRATCH:  sys_rdata = scratch_r;
            S_FREQ:     sys_rdata = freq;
            S_CON_MODE: sys_rdata = {30'h0, cm_s2};
            default:    sys_rdata = 32'h0;
        endcase
    end

    always_ff @(posedge io_clk_i or negedge core_rst_n) begin
        if (!core_rst_n) begin
            irq_en_r <= '0; scratch_r <= 32'h0;
            dbg_valid_o <= 1'b0; dbg_byte_o <= 8'h0; halt_o <= 1'b0; halt_value_o <= 32'h0;
        end else begin
            dbg_valid_o <= 1'b0;
            if (sys_sel && d_we) begin
                case (off)
                    S_DEBUG:   begin dbg_valid_o <= 1'b1; dbg_byte_o <= d_wdata[7:0]; end
                    S_HALT:    begin halt_o <= 1'b1; halt_value_o <= d_wdata; end
                    S_IRQ_EN:  irq_en_r <= d_wdata[NIRQ-1:0];
                    S_SCRATCH: scratch_r <= d_wdata;
                    default: ;
                endcase
            end
        end
    end

    logic [31:0] us_bin, ms_bin;
    iocore_timer #(.US_DIV_RESET(US_DIV_RESET)) u_timer (
        .clk_i(io_clk_i), .rst_n_i(core_rst_n),
        .sel_i(timer_sel), .we_i(d_we), .off_i(off), .wdata_i(d_wdata), .rdata_o(timer_rdata),
        .irq_o(irq_timer), .us_tick_o(), .ms_tick_o(), .us_o(us_bin), .ms_o(ms_bin)
    );
    always_ff @(posedge io_clk_i or negedge core_rst_n) begin
        if (!core_rst_n) begin
            us_gray_o <= 32'h0; ms_gray_o <= 32'h0;
        end else begin
            us_gray_o <= us_bin ^ (us_bin >> 1);
            ms_gray_o <= ms_bin ^ (ms_bin >> 1);
        end
    end

    iocore_gpio #(.NPINS(NPINS)) u_gpio (
        .clk_i(io_clk_i), .rst_n_i(core_rst_n),
        .sel_i(gpio_sel), .we_i(d_we), .off_i(off), .wdata_i(d_wdata), .rdata_o(gpio_rdata),
        .irq_o(gpio_irq),
        .out_o(gpio_o), .oe_o(gpio_oe_o), .pu_o(gpio_pu_o), .pd_o(gpio_pd_o), .in_i(gpio_i),
        .level_o(), .hit_o()
    );

    iocore_uart #(.BAUD_RESET(BAUD_RESET)) u_uart (
        .clk_i(io_clk_i), .rst_n_i(core_rst_n),
        .sel_i(uart_sel), .we_i(d_we), .off_i(off), .wdata_i(d_wdata),
        .ready_o(uart_ready), .rdata_o(uart_rdata),
        .rxd_i(uart_rxd_i), .txd_o(uart_txd_o), .irq_o(uart_irq), .rx_byte_o()
    );

    iocore_bridge u_bridge (
        .clk_i(io_clk_i), .rst_n_i(core_rst_n),
        .sel_i(br_sel), .we_i(d_we), .off_i(d_addr[11:0]), .wdata_i(d_wdata),
        .ready_o(br_ready), .rdata_o(br_rdata), .irq_o(br_irq),
        .cmd_pop_o, .cmd_data_i, .cmd_empty_i, .cmd_level_i,
        .rsp_push_o, .rsp_data_o, .rsp_full_i,
        .evt_push_o, .evt_data_o, .evt_full_i,
        .con_pop_o, .con_data_i, .con_empty_i, .con_level_i,
        .conrx_push_o, .conrx_data_o, .conrx_full_i,
        .upd_push_o, .upd_data_o, .upd_full_i,
        .dn_pop_o, .dn_data_i, .dn_empty_i
    );

    // ---- responses: the clock after the take ----
    always_ff @(posedge io_clk_i or negedge core_rst_n) begin
        if (!core_rst_n) begin
            d_rvalid <= 1'b0; d_err <= 1'b0; sel_q <= R_NONE; rdata_q <= 32'h0;
        end else begin
            d_rvalid <= take;
            d_err    <= take && (rgn == R_NONE || bad_size);
            sel_q    <= rgn;
            case (rgn)
                R_SYS:   rdata_q <= sys_rdata;
                R_TIMER: rdata_q <= timer_rdata;
                R_UART:  rdata_q <= uart_rdata;
                R_BRIDGE: rdata_q <= br_rdata;
                R_GPIO:  rdata_q <= gpio_rdata;
                default: rdata_q <= 32'h0;
            endcase
        end
    end
    assign d_rdata = (sel_q == R_DATA) ? m_q : rdata_q;
endmodule
