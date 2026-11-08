`include "mpy_defs.svh"
`include "mpy_abi.svh"

// uPyCore system: mpy_core (data and instruction fetch), mpy_gc and mpy_ca,
// each on its own mpy_mem port, and mpy_boot, which fills the image SRAM
// from SPI NAND.
//
// Boot: mpy_mem clears all SRAM, then mpy_boot loads the image and fixes
// the split, then mpy_gc clears its maximum-capacity allocation table. The core and the
// accelerator stay in reset until all three are done, so the program's cycle
// count starts at its first instruction. A bad boot stream raises
// boot_err_o and the core never starts (upycore/docs/mpy_boot.md).
//
// Memory: words are interleaved across four SRAM blocks, and each block
// takes one access per cycle. The collector, the core's data accesses, the
// core's instruction fetch and the container accelerator (mpy_ca) each have
// a port; when two want the same block they go in that order. Fetch reads
// ahead and a streaming copy runs alongside the core whenever they touch
// different blocks. A
// core access that the accelerator's scoreboard marks busy waits until the
// copy has moved past that word; the core's state machine only sees a longer
// wait for its ack. The collector and the core never contend: the core
// waits on every allocation and collection, and it lets the accelerator
// drain before a collection. Core accesses
// to the simulator-control page (ABI_SIM_BASE) are answered here: a store to
// SIM_STDOUT or SIM_STDERR emits the low byte on the console port, a store to
// SIM_HALT stops the core's clock-enable view through halt_o, and a load of
// SIM_CYCLES returns the cycle counter. Everything else goes to mpy_mem.
module mpy_soc #(
    parameter int SRAM_LATENCY = MPY_SRAM_LATENCY,
    parameter bit CA_TYPE_CACHE = 0,
    parameter int SHORTLIST_MAX = 16,
    parameter int SHORTLIST_MODE = 2,
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

    // SPI NAND holding the boot image (mode 0, one data line each way).
    output logic        nand_sck_o,
    output logic        nand_cs_n_o,
    output logic        nand_mosi_o,
    input  logic        nand_miso_i,
    output logic        boot_done_o,
    output logic        boot_err_o
);

    // core <-> port
    logic        c_req, c_we, c_tag_we;
    logic [3:0]  c_be, c_wtag;
    logic [31:0] c_addr, c_wdata;
    logic        c_ack, c_fault;
    logic        c_gnt;      // the core's request was taken: by mpy_mem, or the sim page (sim_go)
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
    // memory: one port per master
    localparam int P_GC = 0, P_CORE = 1, P_FETCH = 2, P_CA = 3;
    logic [3:0]       m_req, m_we, m_tag_we, m_gnt, m_ack, m_fault;
    logic [3:0][3:0]  m_be, m_wtag, m_rtag, m_fault_reason;
    logic [3:0][31:0] m_addr, m_wdata, m_rdata;
    // core instruction fetch
    logic        f_req;
    logic [31:0] f_addr;

    logic sl_valid, sl_ready, sl_reverse, sl_clear, sl_put, sl_length, sl_response, sl_response_ready;
    logic [31:0] sl_src, sl_dst, sl_n, sl_clear_addr, sl_put_addr, sl_header, sl_new_length;
    logic [35:0] sl_put_value;

    // core <-> container accelerator
    logic ca_byte,ca_reverse;
    logic        ca_valid, ca_ready, ca_idle, ca_busy, ca_fault;
    logic [31:0] ca_dst, ca_src, ca_n, ca_fault_addr, ca_words, ca_cmds;
    logic [3:0]  ca_fault_reason;
    logic mb_valid, mb_ready, mb_return, mb_ok, mb_set;
    logic [2:0] mb_op;
    logic [31:0] mb_src,mb_sn,mb_dst,mb_dn,mb_used,mb_result,mb_header,mb_source_header,mb_hashes;
    logic [31:0] mb_qcount,mb_qbase,mb_qext;
    // accelerator <-> port
    logic        am_req, am_we, am_gnt, am_ack;
    logic [31:0] am_addr, am_wdata;
    logic [3:0]  am_wtag;
    logic        core_halted;
    logic [3:0]  core_hcode;
    logic [31:0] core_hval, core_cycles;

    // Reset release follows memory clear -> image load -> GC metadata clear.
    // The core and accelerator wait for all three.
    logic        mem_ready, boot_done;
    logic [31:0] image_words, requested_pool, physical_pool, active_pool;
    logic layout_error;
    assign physical_pool = MPY_MEM_BYTES - (image_words << 2) -
                           (ABI_GC_POOL_BASE - MPY_SRAM_BASE);
    assign active_pool = (requested_pool == 0) ? physical_pool : requested_pool;
    assign layout_error = boot_done && (requested_pool > physical_pool ||
                                      active_pool < 16 || active_pool[3:0] != 0);
    logic boot_error;
    assign boot_err_o = boot_error || layout_error;
    logic        sys_rst_n;
    logic        ld_we;
    logic [MPY_FLASH_IDX_W-1:0] ld_idx;
    logic [31:0] ld_wdata;
    logic [3:0]  ld_wtag;

    // Reset. rst_n_i asserts asynchronously and is released through two
    // flops (por_n), so no flop sees the external edge's release. Every
    // block reset below is a flop output, never a gate: the boot loader
    // starts after the SRAM clear, the collector after a good boot, and
    // the core and accelerator once the collector's table is clear.
    logic [1:0]  por_q;
    logic        por_n, boot_rst_n, gc_rst_n;
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) por_q <= 2'b00;
        else          por_q <= {por_q[0], 1'b1};
    end
    assign por_n = por_q[1];

    always_ff @(posedge clk_i or negedge por_n) begin
        if (!por_n) begin
            boot_rst_n <= 1'b0;
            gc_rst_n   <= 1'b0;
            sys_rst_n  <= 1'b0;
        end else begin
            if (mem_ready) boot_rst_n <= 1'b1;
            if (boot_done && !boot_err_o) gc_rst_n <= 1'b1;
            if (mem_ready && boot_done && !boot_err_o && gc_rst_n && !g_busy) sys_rst_n <= 1'b1;
        end
    end
    assign boot_done_o = sys_rst_n;

    mpy_boot u_boot (
        .clk_i, .rst_n_i(boot_rst_n),
        .sck_o(nand_sck_o), .cs_n_o(nand_cs_n_o), .mosi_o(nand_mosi_o), .miso_i(nand_miso_i),
        .ld_we_o(ld_we), .ld_idx_o(ld_idx), .ld_wdata_o(ld_wdata), .ld_wtag_o(ld_wtag),
        .image_words_o(image_words), .pool_bytes_o(requested_pool),
        .done_o(boot_done), .err_o(boot_error)
    );

    mpy_core #(.SHORTLIST_MAX(SHORTLIST_MAX), .SHORTLIST_MODE(SHORTLIST_MODE)) u_core (
        .clk_i, .rst_n_i(sys_rst_n),
        .m_req_o(c_req), .m_we_o(c_we), .m_tag_we_o(c_tag_we), .m_be_o(c_be),
        .m_addr_o(c_addr), .m_wdata_o(c_wdata), .m_wtag_o(c_wtag),
        .m_gnt_i(c_gnt), .m_ack_i(c_ack), .m_rdata_i(c_rdata), .m_rtag_i(c_rtag),
        .m_fault_i(c_fault), .m_fault_reason_i(c_fault_reason),
        .f_req_o(f_req), .f_addr_o(f_addr), .f_gnt_i(m_gnt[P_FETCH]), .f_ack_i(m_ack[P_FETCH]),
        .f_rdata_i(m_rdata[P_FETCH]), .f_fault_i(m_fault[P_FETCH]),
        .f_fault_reason_i(m_fault_reason[P_FETCH]),
        .gc_alloc_req_o(g_alloc_req), .gc_alloc_nbytes_o(g_alloc_nbytes),
        .gc_alloc_done_i(g_alloc_done), .gc_alloc_ok_i(g_alloc_ok), .gc_alloc_addr_i(g_alloc_addr),
        .gc_collect_req_o(g_collect_req),
        .gc_root0_lo_o(g_r0lo), .gc_root0_hi_o(g_r0hi),
        .gc_root1_lo_o(g_r1lo), .gc_root1_hi_o(g_r1hi),
        .gc_collect_done_i(g_collect_done),
        .gc_free_i(g_free), .gc_total_i(g_total), .gc_collections_i(g_coll),
        .mb_valid_o(mb_valid),.mb_ready_i(mb_ready),.mb_return_i(mb_return),.mb_ok_i(mb_ok),
        .mb_used_i(mb_result),.mb_op_o(mb_op),.mb_set_o(mb_set),
        .mb_src_o(mb_src),.mb_sn_o(mb_sn),.mb_dst_o(mb_dst),.mb_dn_o(mb_dn),.mb_used_o(mb_used),
        .mb_header_o(mb_header),.mb_source_header_o(mb_source_header),.mb_hashes_o(mb_hashes),
        .mb_qcount_o(mb_qcount),.mb_qbase_o(mb_qbase),.mb_qext_o(mb_qext),
        .ca_reverse_o(ca_reverse),.ca_byte_o(ca_byte),.ca_valid_o(ca_valid), .ca_ready_i(ca_ready),
        .sl_valid_o(sl_valid),
        .sl_ready_i(sl_ready),
        .sl_src_o(sl_src),
        .sl_dst_o(sl_dst),
        .sl_n_o(sl_n),
        .sl_reverse_o(sl_reverse),
        .sl_clear_o(sl_clear),
        .sl_put_o(sl_put),
        .sl_length_o(sl_length),
        .sl_clear_addr_o(sl_clear_addr),
        .sl_put_addr_o(sl_put_addr),
        .sl_header_o(sl_header),
        .sl_new_length_o(sl_new_length),
        .sl_put_value_o(sl_put_value),
        .sl_response_i(sl_response),
        .sl_response_ready_o(sl_response_ready),
        .ca_dst_o(ca_dst), .ca_src_o(ca_src), .ca_n_o(ca_n), .ca_idle_i(ca_idle),
        .ca_fault_i(ca_fault), .ca_fault_reason_i(ca_fault_reason), .ca_fault_addr_i(ca_fault_addr),
        .halted_o(core_halted), .halt_code_o(core_hcode), .halt_value_o(core_hval),
        .cycles_o(core_cycles), .ops_o,
        .trace_o, .trace_pc_o, .trace_op_o, .trace_sp_o
    );

    mpy_gc #(
        .POOL_BASE(ABI_GC_POOL_BASE),
        // The table covers the largest heap a real image leaves
        // (mpy_abi.GC_TABLE_BYTES), not the whole address window.
        .POOL_BYTES(ABI_GC_TABLE_BYTES)
    ) u_gc (
        .clk_i, .rst_n_i(gc_rst_n),
        .pool_bytes_i(active_pool),
        .alloc_req_i(g_alloc_req), .alloc_nbytes_i(g_alloc_nbytes),
        .alloc_done_o(g_alloc_done), .alloc_ok_o(g_alloc_ok), .alloc_addr_o(g_alloc_addr),
        .collect_req_i(g_collect_req),
        .root0_lo_i(g_r0lo), .root0_hi_i(g_r0hi), .root1_lo_i(g_r1lo), .root1_hi_i(g_r1hi),
        .collect_done_o(g_collect_done),
        .busy_o(g_busy), .free_blocks_o(g_free), .total_blocks_o(g_total),
        .collections_o(g_coll), .overflows_o(g_ovf),
        .mem_req_o(gm_req), .mem_we_o(gm_we), .mem_tag_we_o(gm_tag_we),
        .mem_addr_o(gm_addr), .mem_wdata_o(gm_wdata), .mem_wtag_o(gm_wtag),
        .mem_gnt_i(m_gnt[P_GC]), .mem_ack_i(gm_ack), .mem_rdata_i(gm_rdata), .mem_rtag_i(gm_rtag)
    );

    mpy_collection #(.TYPE_CACHE(CA_TYPE_CACHE), .SHORTLIST_MAX(SHORTLIST_MAX)) u_ca (
        .cache_clear_i(g_collect_req || g_collect_done),.cache_write_i(m_gnt[P_CORE] && c_we),.cache_addr_i(c_addr),
        .clk_i,.rst_n_i(sys_rst_n),
        .copy_reverse_i(ca_reverse),.copy_byte_i(ca_byte),.copy_valid_i(ca_valid),.copy_ready_o(ca_ready),
        .copy_src_i(ca_src),.copy_dst_i(ca_dst),.copy_n_i(ca_n),
        .bulk_valid_i(mb_valid),.bulk_ready_o(mb_ready),.bulk_op_i(mb_op),.bulk_set_i(mb_set),
        .bulk_src_i(mb_src),.bulk_sn_i(mb_sn),.bulk_dst_i(mb_dst),.bulk_dn_i(mb_dn),.bulk_used_i(mb_used),
        .bulk_header_i(mb_header),.bulk_source_header_i(mb_source_header),.bulk_hashes_i(mb_hashes),
        .qstr_count_i(mb_qcount),.qstr_base_i(mb_qbase),.qstr_ext_i(mb_qext),
        .bulk_return_o(mb_return),.bulk_ok_o(mb_ok),.bulk_used_o(mb_result),
        .sl_valid_i(sl_valid),
        .sl_ready_o(sl_ready),
        .sl_src_i(sl_src),
        .sl_dst_i(sl_dst),
        .sl_n_i(sl_n),
        .sl_reverse_i(sl_reverse),
        .sl_clear_i(sl_clear),
        .sl_put_i(sl_put),
        .sl_length_i(sl_length),
        .sl_clear_addr_i(sl_clear_addr),
        .sl_put_addr_i(sl_put_addr),
        .sl_header_i(sl_header),
        .sl_new_length_i(sl_new_length),
        .sl_put_value_i(sl_put_value),
        .sl_response_o(sl_response),
        .sl_response_ready_i(sl_response_ready),
        .idle_o(ca_idle),.chk_addr_i(c_addr),.chk_we_i(c_we),.chk_busy_o(ca_busy),
        .req_o(am_req),.we_o(am_we),.addr_o(am_addr),.wdata_o(am_wdata),.wtag_o(am_wtag),
        .gnt_i(am_gnt),.ack_i(am_ack),.fault_i(m_fault[P_CA]),.fault_reason_i(m_fault_reason[P_CA]),
        .rdata_i(m_rdata[P_CA]),.rtag_i(m_rtag[P_CA]),
        .fault_o(ca_fault),.fault_reason_o(ca_fault_reason),.fault_addr_o(ca_fault_addr),
        .words_o(ca_words),.cmds_o(ca_cmds)
    );

    mpy_mem #(
        .NP(4),
        .FLASH_WAIT_STATES(FLASH_WAIT_STATES),
        .SRAM_LATENCY(SRAM_LATENCY)
    ) u_mem (
        .clk_i, .rst_n_i(por_n), .image_words_i(image_words),
        .req_i(m_req), .we_i(m_we), .tag_we_i(m_tag_we), .be_i(m_be),
        .addr_i(m_addr), .wdata_i(m_wdata), .wtag_i(m_wtag),
        .gnt_o(m_gnt), .ack_o(m_ack), .rdata_o(m_rdata), .rtag_o(m_rtag),
        .fault_o(m_fault), .fault_reason_o(m_fault_reason),
        .ld_we_i(ld_we), .ld_idx_i(ld_idx), .ld_wdata_i(ld_wdata), .ld_wtag_i(ld_wtag),
        .init_done_o(mem_ready)
    );

    // Sim-page decode for core requests.
    logic c_sim;
    assign c_sim = (mpy_region_of(c_addr) == MPY_REGION_SIM);

    // The core posts stores and pipelines loads, and takes acks in order.
    // A simulator-page access is answered here, so it is granted (sim_go,
    // which the core sees as its grant) only when none of the core's memory
    // accesses is still waiting for its ack; until then it is held in
    // s_pend (the core holds the request fields while it is ungranted).
    // c_out counts the core's memory accesses granted and not yet acked.
    logic        s_pend, sim_go;
    logic [2:0]  c_out;
    assign sim_go = (s_pend || (c_req && c_sim)) && c_out == 3'd0;
    assign c_gnt = m_gnt[P_CORE] || sim_go;
    always_ff @(posedge clk_i or negedge por_n) begin
        if (!por_n) begin
            s_pend <= 1'b0; c_out <= 3'd0;
        end else begin
            s_pend <= (s_pend || (c_req && c_sim)) && !sim_go;
            c_out <= c_out + (m_gnt[P_CORE] ? 3'd1 : 3'd0) - (m_ack[P_CORE] ? 3'd1 : 3'd0);
        end
    end

    logic        sim_ack;
    logic [31:0] sim_rdata;
    logic        sim_halt;
    logic [31:0] sim_halt_val;

    always_ff @(posedge clk_i or negedge por_n) begin
        if (!por_n) begin
            sim_ack <= 1'b0; sim_rdata <= 32'd0;
            con_valid_o <= 1'b0; con_err_o <= 1'b0; con_byte_o <= 8'd0;
            sim_halt <= 1'b0; sim_halt_val <= 32'd0;
        end else begin
            sim_ack <= 1'b0;
            con_valid_o <= 1'b0;
            if (sim_go) begin
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

    // Memory ports. The core and the collector pulse a request and hold its
    // fields until the ack, so a request mpy_mem does not grant at once is
    // kept pending here; the accelerator holds req until am_gnt. mpy_mem
    // grants each of the four interleaved blocks to one port per cycle
    // (collector first, then core, then accelerator), so masters that touch
    // different blocks run in the same cycle. The core's request waits while
    // the accelerator's scoreboard marks its word busy.
    logic c_pend, g_pend, c_want, g_want;
    assign c_want = c_pend || (c_req && !c_sim);
    assign g_want = g_pend || gm_req;

    assign m_req     = {am_req, f_req && sys_rst_n, c_want && !ca_busy, g_want};
    assign m_we      = {am_we, 1'b0, c_we, gm_we};
    assign m_tag_we  = {am_we, 1'b0, c_tag_we, gm_tag_we};
    assign m_be      = {4'hF, 4'hF, c_be, 4'hF};
    assign m_addr    = {am_addr, f_addr, c_addr, gm_addr};
    assign m_wdata   = {am_wdata, 32'd0, c_wdata, gm_wdata};
    assign m_wtag    = {am_wtag, 4'd0, c_wtag, gm_wtag};
    assign am_gnt    = m_gnt[P_CA];

    always_ff @(posedge clk_i or negedge por_n) begin
        if (!por_n) begin
            c_pend <= 1'b0; g_pend <= 1'b0;
        end else begin
            c_pend <= c_want && !m_gnt[P_CORE];
            g_pend <= g_want && !m_gnt[P_GC];
        end
    end
    assign gm_ack = m_ack[P_GC];
    assign am_ack = m_ack[P_CA];
    assign gm_rdata = m_rdata[P_GC];
    assign gm_rtag = m_rtag[P_GC];
    assign c_ack = m_ack[P_CORE] || sim_ack;
    assign c_rdata = sim_ack ? sim_rdata : m_rdata[P_CORE];
    assign c_rtag = sim_ack ? 4'd0 : m_rtag[P_CORE];
    assign c_fault = !sim_ack && m_fault[P_CORE];
    assign c_fault_reason = m_fault_reason[P_CORE];

    assign halted_o = core_halted || sim_halt;
    assign halt_code_o = core_halted ? core_hcode : ABI_HALT_SYSEXIT;
    assign halt_value_o = core_halted ? core_hval : sim_halt_val;
    assign cycles_o = core_cycles;
    assign gc_collections_o = g_coll;
    assign gc_free_o = g_free;

    logic unused;
    assign unused = ^{g_total, g_ovf, g_busy, ca_words, ca_cmds};
endmodule
