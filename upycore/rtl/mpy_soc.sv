`include "mpy_defs.svh"
`include "mpy_abi.svh"

// uPyCore system: mpy_core, mpy_gc and mpy_mem on one memory port, and
// mpy_periph on the MMIO window.
//
// The collector owns the port while it is busy; the core only waits on an
// allocation or a collection then, so the two never contend. Core accesses
// to the simulator-control page (ABI_SIM_BASE) are answered here: a store to
// SIM_STDOUT or SIM_STDERR emits the low byte on the console port, a store to
// SIM_HALT stops the core's clock-enable view through halt_o, and a load of
// SIM_CYCLES returns the cycle counter. A core access in the MMIO window
// (MPY_REGION_MMIO) goes to mpy_periph and never enters mpy_mem; the answer
// is registered one cycle later, like the sim page. MMIO is word access only:
// an unaligned address or a partial-word store faults as unaligned. Everything
// else goes to mpy_mem.
module mpy_soc #(
    parameter int SRAM_LATENCY = MPY_SRAM_LATENCY,
    parameter int FLASH_WAIT_STATES = MPY_FLASH_WAIT_STATES
) (
    input  logic        clk_i,
    input  logic        rst_n_i,

    output logic        con_valid_o,
    output logic        con_err_o,
    output logic [7:0]  con_byte_o,

    output logic        halted_o,
    output logic [3:0]  halt_code_o,
    output logic [31:0] halt_value_o,
    output logic [31:0] cycles_o,
    output logic [31:0] ops_o,
    output logic [31:0] gc_collections_o,
    output logic [31:0] gc_free_o,

    output logic        trace_o,
    output logic [31:0] trace_pc_o,
    output logic [7:0]  trace_op_o,
    output logic [6:0]  trace_sp_o,

    // Peripheral pins (upycore/docs/mpy_peripherals.md)
    input  logic        timer_step_i,
    input  logic        uart_rx_stb_i,
    input  logic [7:0]  uart_rx_byte_i,
    output logic        uart_tx_stb_o,
    output logic [7:0]  uart_tx_byte_o,
    input  logic        uart_rxd_i,
    output logic        uart_txd_o,
    output logic [31:0] gpio_out_o,
    output logic [31:0] gpio_oe_o,
    output logic [31:0] gpio_pu_o,
    output logic [31:0] gpio_pd_o,
    input  logic [31:0] gpio_in_i,
    input  logic        gpio_in_en_i,
    input  logic        sim_irq_i,
    input  logic [7:0]  strap_i,
    output logic        idle_o,

    // Pads after the pin mux (upycore/docs/mpy_peripherals.md, Pin mux)
    output logic [15:0] pad_out_o,
    output logic [15:0] pad_oe_o,
    input  logic [15:0] pad_in_i
);
    // core <-> port
    logic        c_req, c_we, c_tag_we;
    logic [3:0]  c_be, c_wtag;
    logic [31:0] c_addr, c_wdata;
    logic        c_ack, c_fault;
    logic [31:0] c_rdata;
    logic [3:0]  c_rtag, c_fault_reason;

    // core <-> gc
    logic        g_alloc_req, g_alloc_done, g_alloc_ok, g_collect_req, g_collect_done;
    logic [31:0] g_alloc_nbytes, g_alloc_addr;
    logic [31:0] g_r0lo, g_r0hi, g_r1lo, g_r1hi;
    logic [31:0] g_free, g_total, g_coll, g_ovf;
    logic        g_busy;

    // gc <-> port
    logic        gm_req, gm_we, gm_tag_we, gm_ack;
    logic [31:0] gm_addr, gm_wdata, gm_rdata;
    logic [3:0]  gm_wtag, gm_rtag;

    // memory
    logic        m_req, m_we, m_tag_we, m_ack, m_fault;
    logic [3:0]  m_be, m_wtag, m_rtag, m_fault_reason;
    logic [31:0] m_addr, m_wdata, m_rdata;

    // core <-> periph delivery
    logic        i_bnd, i_jmp, i_done, i_fire, i_fire_hard, i_heap_locked, i_kbd;
    logic [2:0]  i_fire_src;
    logic [31:0] i_fire_fn, i_fire_arg;
    logic [3:0]  i_fire_fn_tag, i_fire_arg_tag;
    logic        i_hwe, i_spush, i_sched_full, i_mdirty, i_mclr;
    logic [2:0]  i_hidx;
    logic [35:0] i_hfn, i_harg, i_sfn, i_sarg, i_mfn, i_marg;
    logic [3:0]  i_msel;
    logic [31:0] d_pc, d_fp, d_sp, d_xsp;
    logic        i_wake;

    logic        core_halted;
    logic [3:0]  core_hcode;
    logic [31:0] core_hval, core_cycles;

    mpy_core u_core (
        .clk_i, .rst_n_i,
        .m_req_o(c_req), .m_we_o(c_we), .m_tag_we_o(c_tag_we), .m_be_o(c_be),
        .m_addr_o(c_addr), .m_wdata_o(c_wdata), .m_wtag_o(c_wtag),
        .m_ack_i(c_ack), .m_rdata_i(c_rdata), .m_rtag_i(c_rtag),
        .m_fault_i(c_fault), .m_fault_reason_i(c_fault_reason),
        .gc_alloc_req_o(g_alloc_req), .gc_alloc_nbytes_o(g_alloc_nbytes),
        .gc_alloc_done_i(g_alloc_done), .gc_alloc_ok_i(g_alloc_ok), .gc_alloc_addr_i(g_alloc_addr),
        .gc_collect_req_o(g_collect_req),
        .gc_root0_lo_o(g_r0lo), .gc_root0_hi_o(g_r0hi),
        .gc_root1_lo_o(g_r1lo), .gc_root1_hi_o(g_r1hi),
        .gc_collect_done_i(g_collect_done),
        .gc_free_i(g_free), .gc_total_i(g_total), .gc_collections_i(g_coll),
        .halted_o(core_halted), .halt_code_o(core_hcode), .halt_value_o(core_hval),
        .cycles_o(core_cycles), .ops_o,
        .trace_o, .trace_pc_o, .trace_op_o, .trace_sp_o,
        .irq_boundary_o(i_bnd), .irq_jump_o(i_jmp), .irq_done_o(i_done),
        .irq_fire_i(i_fire), .irq_fire_hard_i(i_fire_hard), .irq_fire_src_i(i_fire_src),
        .irq_fire_fn_i({i_fire_fn_tag, i_fire_fn}), .irq_fire_arg_i({i_fire_arg_tag, i_fire_arg}),
        .irq_heap_locked_i(i_heap_locked), .irq_kbd_i(i_kbd),
        .irq_handler_we_o(i_hwe), .irq_handler_idx_o(i_hidx),
        .irq_handler_fn_o(i_hfn), .irq_handler_arg_o(i_harg),
        .irq_sched_push_o(i_spush), .irq_sched_fn_o(i_sfn), .irq_sched_arg_o(i_sarg),
        .irq_sched_full_i(i_sched_full),
        .irq_mirror_dirty_i(i_mdirty), .irq_mirror_sel_o(i_msel), .irq_mirror_clr_o(i_mclr),
        .irq_mirror_fn_i(i_mfn), .irq_mirror_arg_i(i_marg),
        .irq_wake_i(i_wake), .idle_o,
        .dbg_pc_o(d_pc), .dbg_fp_o(d_fp), .dbg_sp_o(d_sp), .dbg_exc_sp_o(d_xsp)
    );

    mpy_gc #(
        .POOL_BASE(ABI_GC_POOL_BASE),
        .POOL_BYTES(ABI_GC_POOL_BYTES)
    ) u_gc (
        .clk_i, .rst_n_i,
        .alloc_req_i(g_alloc_req), .alloc_nbytes_i(g_alloc_nbytes),
        .alloc_done_o(g_alloc_done), .alloc_ok_o(g_alloc_ok), .alloc_addr_o(g_alloc_addr),
        .collect_req_i(g_collect_req),
        .root0_lo_i(g_r0lo), .root0_hi_i(g_r0hi), .root1_lo_i(g_r1lo), .root1_hi_i(g_r1hi),
        .collect_done_o(g_collect_done),
        .busy_o(g_busy), .free_blocks_o(g_free), .total_blocks_o(g_total),
        .collections_o(g_coll), .overflows_o(g_ovf),
        .mem_req_o(gm_req), .mem_we_o(gm_we), .mem_tag_we_o(gm_tag_we),
        .mem_addr_o(gm_addr), .mem_wdata_o(gm_wdata), .mem_wtag_o(gm_wtag),
        .mem_ack_i(gm_ack), .mem_rdata_i(gm_rdata), .mem_rtag_i(gm_rtag)
    );

    mpy_mem #(
        .FLASH_WAIT_STATES(FLASH_WAIT_STATES),
        .SRAM_LATENCY(SRAM_LATENCY)
    ) u_mem (
        .clk_i, .rst_n_i,
        .req_i(m_req), .we_i(m_we), .tag_we_i(m_tag_we), .be_i(m_be),
        .addr_i(m_addr), .wdata_i(m_wdata), .wtag_i(m_wtag),
        .ack_o(m_ack), .rdata_o(m_rdata), .rtag_o(m_rtag),
        .fault_o(m_fault), .fault_reason_o(m_fault_reason)
    );

    // Sim-page and MMIO decode for core requests.
    logic c_sim, c_mmio;
    assign c_sim  = (mpy_region_of(c_addr) == MPY_REGION_SIM);
    assign c_mmio = (mpy_region_of(c_addr) == MPY_REGION_MMIO);

    logic        p_req, p_ack, p_fault;
    logic [31:0] p_rdata;
    logic        mmio_ack, mmio_fault;
    logic [31:0] mmio_rdata;
    logic        p_partial;

    // Every block past the base registers sees the same request; each one
    // decodes its own range and reads 0 elsewhere.
    logic        blk_req;
    logic [31:0] pwm_rdata, mux_rdata, spi_rdata, i2c_rdata;
    logic [3:0]  pwm;
    logic        uart_txd, uart_rxd;
    logic        spi_sck, spi_mosi, spi_miso;
    logic        i2c_scl_low, i2c_sda_low, i2c_scl, i2c_sda;
    assign blk_req = p_req && !p_fault;
    assign uart_txd_o = uart_txd;

    mpy_periph u_periph (
        .clk_i, .rst_n_i,
        .req_i(p_req), .we_i(c_we), .addr_i(c_addr), .wdata_i(c_wdata),
        .rdata_o(p_rdata), .ack_o(p_ack), .fault_o(p_fault),
        .timer_step_i, .uart_rx_stb_i, .uart_rx_byte_i,
        .uart_tx_stb_o, .uart_tx_byte_o, .uart_rxd_i(uart_rxd), .uart_txd_o(uart_txd),
        .gpio_out_o, .gpio_oe_o, .gpio_pu_o, .gpio_pd_o, .gpio_in_i, .gpio_in_en_i,
        .soft_set_i(1'b0), .gc_req_i(1'b0), .sim_set_i(sim_irq_i),
        .kbd_set_i(1'b0), .mbox_set_i(1'b0),
        .bc_boundary_i(i_bnd), .jump_i(i_jmp), .done_i(i_done), .wake_o(i_wake),
        .fire_o(i_fire), .fire_hard_o(i_fire_hard), .fire_sched_o(), .fire_src_o(i_fire_src),
        .fire_fn_o(i_fire_fn), .fire_arg_o(i_fire_arg),
        .fire_fn_tag_o(i_fire_fn_tag), .fire_arg_tag_o(i_fire_arg_tag), .kbd_raise_o(i_kbd),
        .heap_locked_o(i_heap_locked), .sched_locked_o(), .irq_active_o(),
        .handler_we_i(i_hwe), .handler_idx_i(i_hidx),
        .handler_fn_i(i_hfn[31:0]), .handler_arg_i(i_harg[31:0]),
        .handler_fn_tag_i(i_hfn[35:32]), .handler_arg_tag_i(i_harg[35:32]),
        .sched_push_i(i_spush), .sched_fn_i(i_sfn[31:0]), .sched_arg_i(i_sarg[31:0]),
        .sched_fn_tag_i(i_sfn[35:32]), .sched_arg_tag_i(i_sarg[35:32]),
        .sched_ok_o(), .sched_full_o(i_sched_full),
        .mirror_dirty_o(i_mdirty), .mirror_sel_i(i_msel), .mirror_clr_i(i_mclr),
        .mirror_fn_o(i_mfn), .mirror_arg_o(i_marg),
        .pc_i(d_pc), .fp_i(d_fp), .sp_i(d_sp), .exc_sp_i(d_xsp),
        .saved_pc_o(), .saved_fp_o(), .saved_sp_o(), .saved_exc_sp_o()
    );

    logic [31:0] sys_rdata;
    mpy_sys u_sys (
        .clk_i, .rst_n_i,
        .req_i(blk_req), .we_i(c_we), .off_i(c_addr[11:0]), .wdata_i(c_wdata),
        .rdata_o(sys_rdata), .strap_i
    );

    mpy_pwm u_pwm (
        .clk_i, .rst_n_i,
        .req_i(blk_req), .we_i(c_we), .off_i(c_addr[11:0]), .wdata_i(c_wdata),
        .rdata_o(pwm_rdata), .pwm_o(pwm), .wrap_o()
    );

    mpy_spi u_spi (
        .clk_i, .rst_n_i,
        .req_i(blk_req), .we_i(c_we), .off_i(c_addr[11:0]), .wdata_i(c_wdata),
        .rdata_o(spi_rdata), .sck_o(spi_sck), .mosi_o(spi_mosi), .miso_i(spi_miso), .irq_o()
    );

    mpy_i2c u_i2c (
        .clk_i, .rst_n_i,
        .req_i(blk_req), .we_i(c_we), .off_i(c_addr[11:0]), .wdata_i(c_wdata),
        .rdata_o(i2c_rdata), .scl_low_o(i2c_scl_low), .sda_low_o(i2c_sda_low),
        .scl_i(i2c_scl), .sda_i(i2c_sda), .irq_o()
    );

    mpy_pinmux u_mux (
        .clk_i, .rst_n_i,
        .req_i(blk_req), .we_i(c_we), .off_i(c_addr[11:0]), .wdata_i(c_wdata),
        .rdata_o(mux_rdata),
        .gpio_out_i(gpio_out_o[15:0]), .gpio_oe_i(gpio_oe_o[15:0]), .pwm_i(pwm),
        .spi_sck_i(spi_sck), .spi_mosi_i(spi_mosi),
        .i2c_scl_low_i(i2c_scl_low), .i2c_sda_low_i(i2c_sda_low),
        .uart_txd_i(uart_txd), .uart_rxd_pin_i(uart_rxd_i),
        .spi_miso_o(spi_miso), .i2c_scl_o(i2c_scl), .i2c_sda_o(i2c_sda), .uart_rxd_o(uart_rxd),
        .pad_out_o, .pad_oe_o, .pad_in_i
    );

    // A partial-word store would write a replicated byte; it faults instead.
    assign p_partial = c_we && (c_be != 4'hF);
    assign p_req = c_req && c_mmio && !p_partial && !g_busy;

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            mmio_ack <= 1'b0; mmio_fault <= 1'b0; mmio_rdata <= 32'd0;
        end else begin
            mmio_ack <= c_req && c_mmio && !g_busy;
            mmio_fault <= c_req && c_mmio && !g_busy && (p_partial || p_fault);
            mmio_rdata <= p_rdata | sys_rdata | pwm_rdata | mux_rdata | spi_rdata | i2c_rdata;
        end
    end

    logic        sim_ack;
    logic [31:0] sim_rdata;
    logic        sim_halt;
    logic [31:0] sim_halt_val;

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            sim_ack <= 1'b0; sim_rdata <= 32'd0;
            con_valid_o <= 1'b0; con_err_o <= 1'b0; con_byte_o <= 8'd0;
            sim_halt <= 1'b0; sim_halt_val <= 32'd0;
        end else begin
            sim_ack <= 1'b0;
            con_valid_o <= 1'b0;
            if (c_req && c_sim) begin
                sim_ack <= 1'b1;
                sim_rdata <= 32'd0;
                if (c_we) begin
                    case ((c_addr - ABI_SIM_BASE) >> 2)
                        32'(ABI_SIM_STDOUT): begin con_valid_o <= 1'b1; con_err_o <= 1'b0; con_byte_o <= c_wdata[7:0]; end
                        32'(ABI_SIM_STDERR): begin con_valid_o <= 1'b1; con_err_o <= 1'b1; con_byte_o <= c_wdata[7:0]; end
                        32'(ABI_SIM_HALT): begin sim_halt <= 1'b1; sim_halt_val <= c_wdata; end
                        default: ;
                    endcase
                end else if (((c_addr - ABI_SIM_BASE) >> 2) == 32'(ABI_SIM_CYCLES)) begin
                    sim_rdata <= core_cycles;
                end
            end
        end
    end

    // Port mux: the collector while busy, else the core (sim page excluded).
    always_comb begin
        if (g_busy) begin
            m_req = gm_req; m_we = gm_we; m_tag_we = gm_tag_we; m_be = 4'hF;
            m_addr = gm_addr; m_wdata = gm_wdata; m_wtag = gm_wtag;
        end else begin
            m_req = c_req && !c_sim && !c_mmio; m_we = c_we; m_tag_we = c_tag_we; m_be = c_be;
            m_addr = c_addr; m_wdata = c_wdata; m_wtag = c_wtag;
        end
    end
    assign gm_ack = g_busy && m_ack;
    assign gm_rdata = m_rdata;
    assign gm_rtag = m_rtag;
    assign c_ack = (!g_busy && m_ack) || sim_ack || mmio_ack;
    assign c_rdata = sim_ack ? sim_rdata : mmio_ack ? mmio_rdata : m_rdata;
    assign c_rtag = (sim_ack || mmio_ack) ? 4'd0 : m_rtag;
    assign c_fault = mmio_ack ? mmio_fault : (!sim_ack && m_fault);
    assign c_fault_reason = mmio_ack ? MPY_FAULT_UNALIGNED : m_fault_reason;

    assign halted_o = core_halted || sim_halt;
    assign halt_code_o = core_halted ? core_hcode : ABI_HALT_SYSEXIT;
    assign halt_value_o = core_halted ? core_hval : sim_halt_val;
    assign cycles_o = core_cycles;
    assign gc_collections_o = g_coll;
    assign gc_free_o = g_free;

    logic unused;
    assign unused = ^{g_total, g_ovf};
endmodule
