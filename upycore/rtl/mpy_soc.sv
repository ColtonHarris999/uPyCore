`include "mpy_defs.svh"
`include "mpy_abi.svh"

// uPyCore system: mpy_core, mpy_gc, mpy_ca and mpy_mem on one memory port.
//
// Three masters share the port: the collector, the core, and the container
// accelerator (mpy_ca). A request waits in the arbiter below until mpy_mem
// is free, then the highest-priority one goes: collector, core, accelerator.
// The accelerator therefore runs in the cycles the core leaves idle. A core
// access that the accelerator's scoreboard marks busy waits until the copy
// has moved past that word; the core's state machine only sees a longer
// wait for its ack. The collector and the core never contend: the core
// waits on every allocation and collection, and it lets the accelerator
// drain before a collection. Core accesses
// to the simulator-control page (ABI_SIM_BASE) are answered here: a store to
// SIM_STDOUT or SIM_STDERR emits the low byte on the console port, a store to
// SIM_HALT stops the core's clock-enable view through halt_o, and a load of
// SIM_CYCLES returns the cycle counter. Everything else goes to mpy_mem.
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
    output logic [6:0]  trace_sp_o
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

    // core <-> container accelerator
    logic        ca_valid, ca_ready, ca_idle, ca_busy, ca_fault;
    logic [31:0] ca_dst, ca_src, ca_n, ca_fault_addr, ca_words, ca_cmds;
    logic [3:0]  ca_fault_reason;
    // accelerator <-> port
    logic        am_req, am_we, am_gnt, am_ack;
    logic [31:0] am_addr, am_wdata;
    logic [3:0]  am_wtag;
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
        .ca_valid_o(ca_valid), .ca_ready_i(ca_ready),
        .ca_dst_o(ca_dst), .ca_src_o(ca_src), .ca_n_o(ca_n), .ca_idle_i(ca_idle),
        .ca_fault_i(ca_fault), .ca_fault_reason_i(ca_fault_reason), .ca_fault_addr_i(ca_fault_addr),
        .halted_o(core_halted), .halt_code_o(core_hcode), .halt_value_o(core_hval),
        .cycles_o(core_cycles), .ops_o,
        .trace_o, .trace_pc_o, .trace_op_o, .trace_sp_o
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

    mpy_ca u_ca (
        .clk_i, .rst_n_i,
        .cmd_valid_i(ca_valid), .cmd_ready_o(ca_ready),
        .cmd_dst_i(ca_dst), .cmd_src_i(ca_src), .cmd_n_i(ca_n), .idle_o(ca_idle),
        .chk_addr_i(c_addr), .chk_we_i(c_we), .chk_busy_o(ca_busy),
        .req_o(am_req), .we_o(am_we), .addr_o(am_addr), .wdata_o(am_wdata), .wtag_o(am_wtag),
        .gnt_i(am_gnt), .ack_i(am_ack), .fault_i(m_fault), .fault_reason_i(m_fault_reason),
        .rdata_i(m_rdata), .rtag_i(m_rtag),
        .fault_o(ca_fault), .fault_reason_o(ca_fault_reason), .fault_addr_o(ca_fault_addr),
        .words_o(ca_words), .cmds_o(ca_cmds)
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

    // Sim-page decode for core requests.
    logic c_sim;
    assign c_sim = (mpy_region_of(c_addr) == MPY_REGION_SIM);

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

    // Port arbiter. The core and the collector pulse a request and hold its
    // fields until the ack; the accelerator holds req until am_gnt. mpy_mem
    // takes a new request in the cycle its previous ack is visible.
    localparam logic [1:0] P_NONE = 2'd0, P_GC = 2'd1, P_CORE = 2'd2, P_CA = 2'd3;
    logic       c_pend, g_pend, inflight, c_want, g_want, mem_free;
    logic [1:0] owner, pick;
    assign c_want = c_pend || (c_req && !c_sim);
    assign g_want = g_pend || gm_req;
    assign mem_free = !inflight || m_ack;
    always_comb begin
        if (!mem_free) pick = P_NONE;
        else if (g_want) pick = P_GC;
        else if (c_want && !ca_busy) pick = P_CORE;
        else if (am_req) pick = P_CA;
        else pick = P_NONE;
    end
    always_comb begin
        case (pick)
            P_GC: begin
                m_req = 1'b1; m_we = gm_we; m_tag_we = gm_tag_we; m_be = 4'hF;
                m_addr = gm_addr; m_wdata = gm_wdata; m_wtag = gm_wtag;
            end
            P_CA: begin
                m_req = 1'b1; m_we = am_we; m_tag_we = am_we; m_be = 4'hF;
                m_addr = am_addr; m_wdata = am_wdata; m_wtag = am_wtag;
            end
            default: begin
                m_req = (pick == P_CORE); m_we = c_we; m_tag_we = c_tag_we; m_be = c_be;
                m_addr = c_addr; m_wdata = c_wdata; m_wtag = c_wtag;
            end
        endcase
    end
    assign am_gnt = (pick == P_CA);
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            c_pend <= 1'b0; g_pend <= 1'b0; inflight <= 1'b0; owner <= P_NONE;
        end else begin
            c_pend <= c_want && (pick != P_CORE);
            g_pend <= g_want && (pick != P_GC);
            if (pick != P_NONE) begin inflight <= 1'b1; owner <= pick; end
            else if (m_ack) inflight <= 1'b0;
        end
    end
    assign gm_ack = m_ack && (owner == P_GC);
    assign am_ack = m_ack && (owner == P_CA);
    assign gm_rdata = m_rdata;
    assign gm_rtag = m_rtag;
    assign c_ack = (m_ack && owner == P_CORE) || sim_ack;
    assign c_rdata = sim_ack ? sim_rdata : m_rdata;
    assign c_rtag = sim_ack ? 4'd0 : m_rtag;
    assign c_fault = !sim_ack && m_fault && (owner == P_CORE);
    assign c_fault_reason = m_fault_reason;

    assign halted_o = core_halted || sim_halt;
    assign halt_code_o = core_halted ? core_hcode : ABI_HALT_SYSEXIT;
    assign halt_value_o = core_halted ? core_hval : sim_halt_val;
    assign cycles_o = core_cycles;
    assign gc_collections_o = g_coll;
    assign gc_free_o = g_free;

    logic unused;
    assign unused = ^{g_total, g_ovf, g_busy, ca_words, ca_cmds};
endmodule
