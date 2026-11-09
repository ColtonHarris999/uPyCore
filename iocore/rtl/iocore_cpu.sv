// The I/O core's processor: CVE2 or Hazard3 behind one bus shape, so the
// rest of the island does not depend on the choice (planning/
// rv_io_core_plan.md, decision D1; upycore/docs/mpy_io_core.md).
//
// Both cores are RV32EMC, machine mode only, no debug, no performance
// counters. Reset is at 0x80; mtvec starts at 0 in vectored mode, so the
// same firmware image runs on either core.
//
// Bus (both ports): OBI-style. A request is taken on a clock with req and
// gnt high; its response (rvalid, with rdata and err) comes on a later
// clock, in order. The island's slaves answer on the next clock and stall
// with gnt low.
//
// CORE = 0: CVE2 (vendor/cve2), MUL selects RV32M: 0 slow (iterative),
//           1 fast (single-cycle multiplier).
// CORE = 1: Hazard3 (vendor/hazard3, the team's benchmark commit 8af9929)
//           behind two AHB-Lite to OBI adapters (iocore_ahb2obi). MUL 1
//           turns on its fast multiplier.
//
// Interrupts: irq_timer_i drives mip.MTIP and irq_ext_i mip.MEIP (the
// island's own controller ORs its enabled sources into it). core_sleep_o
// is high while the core waits in wfi.
module iocore_cpu #(
    parameter int CORE = 0,
    parameter int MUL  = 0
) (
    input  logic        clk_i,
    input  logic        rst_n_i,

    output logic        i_req_o,
    input  logic        i_gnt_i,
    output logic [31:0] i_addr_o,
    input  logic        i_rvalid_i,
    input  logic [31:0] i_rdata_i,
    input  logic        i_err_i,

    output logic        d_req_o,
    input  logic        d_gnt_i,
    output logic        d_we_o,
    output logic [3:0]  d_be_o,
    output logic [31:0] d_addr_o,
    output logic [31:0] d_wdata_o,
    input  logic        d_rvalid_i,
    input  logic [31:0] d_rdata_i,
    input  logic        d_err_i,

    input  logic        irq_timer_i,
    input  logic        irq_ext_i,
    output logic        core_sleep_o
);
    localparam logic [31:0] BOOT = 32'h0000_0080;

    if (CORE == 0) begin : g_cve2
        cve2_top #(
            .MHPMCounterNum(0),
            .RV32E(1'b1),
            .RV32M(MUL != 0 ? cve2_pkg::RV32MFast : cve2_pkg::RV32MSlow)
        ) u_core (
            .clk_i, .rst_ni(rst_n_i),
            .test_en_i(1'b0), .ram_cfg_i('0),
            // CVE2 starts at boot_addr and takes mtvec's base from its upper
            // bits: reset at 0x80, the vector table at 0.
            .hart_id_i(32'h0), .boot_addr_i(BOOT),
            .instr_req_o(i_req_o), .instr_gnt_i(i_gnt_i), .instr_rvalid_i(i_rvalid_i),
            .instr_addr_o(i_addr_o), .instr_rdata_i(i_rdata_i), .instr_err_i(i_err_i),
            .data_req_o(d_req_o), .data_gnt_i(d_gnt_i), .data_rvalid_i(d_rvalid_i),
            .data_we_o(d_we_o), .data_be_o(d_be_o), .data_addr_o(d_addr_o),
            .data_wdata_o(d_wdata_o), .data_rdata_i(d_rdata_i), .data_err_i(d_err_i),
            .x_issue_valid_o(), .x_issue_ready_i(1'b0), .x_issue_req_o(), .x_issue_resp_i('0),
            .x_register_o(), .x_commit_valid_o(), .x_commit_o(),
            .x_result_valid_i(1'b0), .x_result_ready_o(), .x_result_i('0),
            .irq_software_i(1'b0), .irq_timer_i(irq_timer_i), .irq_external_i(irq_ext_i),
            .irq_fast_i(16'h0), .irq_nm_i(1'b0),
            .debug_req_i(1'b0), .debug_halted_o(), .dm_halt_addr_i(32'h0),
            .dm_exception_addr_i(32'h0), .crash_dump_o(),
            .fetch_enable_i(1'b1), .core_sleep_o(core_sleep_o)
        );
    end else begin : g_hazard3
        logic [31:0] ih_addr, dh_addr, dh_wdata, ih_rdata, dh_rdata;
        logic [1:0]  ih_trans, dh_trans;
        logic [2:0]  ih_size, dh_size;
        logic        dh_write, ih_ready, dh_ready, ih_resp, dh_resp;
        logic        clk_en;

        hazard3_cpu_2port #(
            .RESET_VECTOR(BOOT),
            .MTVEC_INIT(32'h0000_0001),
            .EXTENSION_A(0), .EXTENSION_C(1), .EXTENSION_E(1), .EXTENSION_M(1),
            .EXTENSION_ZBA(0), .EXTENSION_ZBB(0), .EXTENSION_ZBC(0), .EXTENSION_ZBKB(0),
            .EXTENSION_ZBKX(0), .EXTENSION_ZBS(0), .EXTENSION_ZCB(0), .EXTENSION_ZCLSD(0),
            .EXTENSION_ZCMP(0), .EXTENSION_ZIFENCEI(0), .EXTENSION_ZILSD(0),
            .EXTENSION_XH3BEXTM(0), .EXTENSION_XH3IRQ(0), .EXTENSION_XH3PMPM(0),
            .EXTENSION_XH3POWER(0),
            .CSR_M_MANDATORY(1), .CSR_M_TRAP(1), .CSR_COUNTER(0),
            .U_MODE(0), .PMP_REGIONS(0), .DEBUG_SUPPORT(0), .BREAKPOINT_TRIGGERS(0),
            .NUM_IRQS(1), .MUL_FAST(MUL != 0 ? 1 : 0), .MULH_FAST(0)
        ) u_core (
            .clk(clk_i), .clk_always_on(clk_i), .rst_n(rst_n_i),
            .pwrup_req(), .pwrup_ack(1'b1), .clk_en(clk_en), .unblock_out(), .unblock_in(1'b0),
            .i_haddr(ih_addr), .i_hwrite(), .i_htrans(ih_trans), .i_hsize(ih_size),
            .i_hburst(), .i_hprot(), .i_hmastlock(), .i_hmaster(),
            .i_hready(ih_ready), .i_hresp(ih_resp), .i_hwdata(), .i_hrdata(ih_rdata),
            .d_haddr(dh_addr), .d_hwrite(dh_write), .d_htrans(dh_trans), .d_hsize(dh_size),
            .d_hburst(), .d_hprot(), .d_hmastlock(), .d_hmaster(), .d_hexcl(),
            .d_hready(dh_ready), .d_hresp(dh_resp), .d_hexokay(1'b1),
            .d_hwdata(dh_wdata), .d_hrdata(dh_rdata),
            .fence_i_vld(), .fence_d_vld(), .fence_rdy(1'b1),
            .dbg_req_halt(1'b0), .dbg_req_halt_on_reset(1'b0), .dbg_req_resume(1'b0),
            .dbg_halted(), .dbg_running(),
            .dbg_data0_rdata(32'h0), .dbg_data0_wdata(), .dbg_data0_wen(),
            .dbg_instr_data(32'h0), .dbg_instr_data_vld(1'b0), .dbg_instr_data_rdy(),
            .dbg_instr_caught_exception(), .dbg_instr_caught_ebreak(),
            .dbg_sbus_addr(32'h0), .dbg_sbus_write(1'b0), .dbg_sbus_size(2'b00),
            .dbg_sbus_vld(1'b0), .dbg_sbus_rdy(), .dbg_sbus_err(), .dbg_sbus_wdata(32'h0),
            .dbg_sbus_rdata(),
            .mhartid_val(32'h0), .eco_version(4'h0),
            .irq(irq_ext_i), .soft_irq(1'b0), .timer_irq(irq_timer_i)
        );
        // Without XH3POWER, clk_en drops only in wfi (no clock gate here).
        assign core_sleep_o = !clk_en;

        iocore_ahb2obi u_iad (
            .clk_i, .rst_n_i,
            .haddr_i(ih_addr), .hwrite_i(1'b0), .htrans_i(ih_trans), .hsize_i(ih_size),
            .hwdata_i(32'h0), .hready_o(ih_ready), .hresp_o(ih_resp), .hrdata_o(ih_rdata),
            .req_o(i_req_o), .gnt_i(i_gnt_i), .we_o(), .be_o(), .addr_o(i_addr_o), .wdata_o(),
            .rvalid_i(i_rvalid_i), .rdata_i(i_rdata_i), .err_i(i_err_i)
        );
        iocore_ahb2obi u_dad (
            .clk_i, .rst_n_i,
            .haddr_i(dh_addr), .hwrite_i(dh_write), .htrans_i(dh_trans), .hsize_i(dh_size),
            .hwdata_i(dh_wdata), .hready_o(dh_ready), .hresp_o(dh_resp), .hrdata_o(dh_rdata),
            .req_o(d_req_o), .gnt_i(d_gnt_i), .we_o(d_we_o), .be_o(d_be_o), .addr_o(d_addr_o),
            .wdata_o(d_wdata_o), .rvalid_i(d_rvalid_i), .rdata_i(d_rdata_i), .err_i(d_err_i)
        );
    end
endmodule
