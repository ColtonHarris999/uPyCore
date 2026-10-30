`include "mpy_defs.svh"

// Randomized check of mpy_ca and its scoreboard against mpy_mem.
//
// A core agent shares the port with the accelerator through the same
// arbiter rules as mpy_soc: the core goes first, and its access waits while
// chk_busy_o is set. The agent ships copies (overlapping ones too, in both
// directions) and loads and stores words in the same 64-word window. The
// golden model applies a shipped copy at once, as memmove would. Every load
// the agent makes must match the model, and after a drain the whole window
// must match it. That is the scoreboard's promise: the core sees the copies
// as if they had finished when they were shipped. The agent sometimes idles
// between accesses so the engine also streams on a free port, and at the
// end one copy runs alone to measure the engine's rate.
//
// Build it with Verilator from the repo root, then run obj_dir/Vtb_mpy_ca:
//   --binary -Iupycore/rtl upycore/rtl/mpy_ca.sv
//   upycore/rtl/bsg_mem_1rw_sync_mask_write_bit.sv upycore/rtl/mpy_mem.sv
//   upycore/tb/tb_mpy_ca.sv --top-module tb_mpy_ca
// +SEED=<n> picks the random sequence and +OPS=<n> its length. -GQDEPTH=<n>
// sets the queue depth, -GBUF=<n> the read-ahead buffer and -GLAT=<n> the
// SRAM latency.
module tb_mpy_ca #(parameter int QDEPTH = 2, parameter int BUF = 4, parameter int LAT = 1);
    localparam logic [31:0] BASE = MPY_SRAM_BASE + 32'h1000;
    localparam int W = 64;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #5 clk = ~clk;

    // core agent
    logic        c_req, c_we, c_pend, c_ack;
    logic [31:0] c_addr, c_wdata;
    logic [3:0]  c_wtag;
    // accelerator
    logic        cmd_valid, cmd_ready, idle, busy;
    logic [31:0] cmd_dst, cmd_src, cmd_n;
    logic        a_req, a_we, a_gnt, a_ack, a_fault;
    logic [31:0] a_addr, a_wdata, a_faddr, a_words, a_cmds;
    logic [3:0]  a_wtag, a_freason;
    // memory
    // memory ports: 0 core, 1 accelerator
    logic [1:0]       m_req, m_we, m_gnt, m_ack, m_fault;
    logic [1:0][31:0] m_addr, m_wdata, m_rdata;
    logic [1:0][3:0]  m_wtag, m_rtag, m_freason;

    mpy_ca #(.QDEPTH(QDEPTH), .BUF(BUF)) dut (
        .clk_i(clk), .rst_n_i(rst_n),
        .cmd_valid_i(cmd_valid), .cmd_ready_o(cmd_ready),
        .cmd_dst_i(cmd_dst), .cmd_src_i(cmd_src), .cmd_n_i(cmd_n), .idle_o(idle),
        .chk_addr_i(c_addr), .chk_we_i(c_we), .chk_busy_o(busy),
        .req_o(a_req), .we_o(a_we), .addr_o(a_addr), .wdata_o(a_wdata), .wtag_o(a_wtag),
        .gnt_i(a_gnt), .ack_i(a_ack), .fault_i(m_fault[1]), .fault_reason_i(m_freason[1]),
        .rdata_i(m_rdata[1]), .rtag_i(m_rtag[1]),
        .fault_o(a_fault), .fault_reason_o(a_freason), .fault_addr_o(a_faddr),
        .words_o(a_words), .cmds_o(a_cmds)
    );

    mpy_mem #(.NP(2), .SRAM_LATENCY(LAT)) mem (
        .clk_i(clk), .rst_n_i(rst_n),
        .req_i(m_req), .we_i(m_we), .tag_we_i(m_we), .be_i({4'hF, 4'hF}),
        .addr_i(m_addr), .wdata_i(m_wdata), .wtag_i(m_wtag),
        .gnt_o(m_gnt), .ack_o(m_ack), .rdata_o(m_rdata), .rtag_o(m_rtag),
        .fault_o(m_fault), .fault_reason_o(m_freason),
        .ld_we_i(1'b0), .ld_idx_i('0), .ld_wdata_i('0), .ld_wtag_i('0), .init_done_o()
    );

    // The mpy_soc ports without the collector: the core holds its request
    // pending until granted and waits on the scoreboard; both may be granted
    // in one cycle when they touch different blocks.
    logic c_want;
    assign c_want = c_pend || c_req;
    assign m_req = {a_req, c_want && !busy};
    assign m_we = {a_we, c_we};
    assign m_addr = {a_addr, c_addr};
    assign m_wdata = {a_wdata, c_wdata};
    assign m_wtag = {a_wtag, c_wtag};
    assign a_gnt = m_gnt[1];
    assign a_ack = m_ack[1];
    assign c_ack = m_ack[0];
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) c_pend <= 1'b0;
        else c_pend <= c_want && !m_gnt[0];
    end

    logic [35:0] gm [0:W-1];
    int errors = 0, loads = 0, stores = 0, ships = 0, stall = 0, cyc = 0, rate = 0;

    always @(posedge clk) begin
        cyc++;
        if (c_want && busy) stall++;
    end

    function automatic logic [35:0] word_of(input int i);
        word_of = {4'(i & 15), 32'hC0DE_0000 | 32'(i)};
    endfunction

    task automatic core_access(input logic we, input int i, input logic [35:0] v);
        if ($urandom_range(0, 3) == 0) repeat ($urandom_range(1, 12)) @(negedge clk);
        @(negedge clk);
        c_req = 1'b1; c_we = we; c_addr = BASE + 32'(i * 4); c_wdata = v[31:0]; c_wtag = v[35:32];
        @(negedge clk);
        c_req = 1'b0;
        while (!c_ack) @(negedge clk);
    endtask

    task automatic ship(input int d, input int s, input int n);
        @(negedge clk);
        while (!cmd_ready) @(negedge clk);
        cmd_valid = 1'b1; cmd_dst = BASE + 32'(d * 4); cmd_src = BASE + 32'(s * 4); cmd_n = 32'(n);
        @(negedge clk);
        cmd_valid = 1'b0;
        // memmove in the model
        if (d > s) for (int k = n - 1; k >= 0; k--) gm[d + k] = gm[s + k];
        else for (int k = 0; k < n; k++) gm[d + k] = gm[s + k];
        ships++;
    endtask

    initial begin
        int seed, ops, n, d, s, i;
        logic [35:0] got;
        if (!$value$plusargs("SEED=%d", seed)) seed = 1;
        if (!$value$plusargs("OPS=%d", ops)) ops = 4000;
        void'($urandom(seed));
        c_req = 1'b0; c_we = 1'b0; c_addr = BASE; c_wdata = '0; c_wtag = '0;
        cmd_valid = 1'b0; cmd_dst = '0; cmd_src = '0; cmd_n = '0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        for (int k = 0; k < W; k++) begin
            gm[k] = word_of(k);
            core_access(1'b1, k, gm[k]);
        end
        for (int op = 0; op < ops; op++) begin
            case ($urandom_range(0, 9))
                0, 1, 2: begin
                    n = $urandom_range(1, 24);
                    d = $urandom_range(0, W - n);
                    s = $urandom_range(0, W - n);
                    ship(d, s, n);
                end
                3, 4, 5, 6: begin
                    i = $urandom_range(0, W - 1);
                    core_access(1'b0, i, '0);
                    got = {m_rtag[0], m_rdata[0]};
                    loads++;
                    if (got !== gm[i]) begin
                        errors++;
                        if (errors < 10)
                            $display("FAIL load [%0d] got %09h want %09h (op %0d)", i, got, gm[i], op);
                    end
                end
                default: begin
                    i = $urandom_range(0, W - 1);
                    gm[i] = word_of(op + 1000);
                    core_access(1'b1, i, gm[i]);
                    stores++;
                end
            endcase
        end
        while (!idle) @(negedge clk);
        for (int k = 0; k < W; k++) begin
            core_access(1'b0, k, '0);
            if ({m_rtag[0], m_rdata[0]} !== gm[k]) begin
                errors++;
                if (errors < 10) $display("FAIL drain [%0d] got %09h want %09h", k, {m_rtag[0], m_rdata[0]}, gm[k]);
            end
        end
        // One copy alone on the port, ship to idle.
        begin
            int c0;
            ship(0, 32, 32);
            c0 = cyc;
            while (!idle) @(negedge clk);
            rate = cyc - c0;
        end
        for (int k = 0; k < W; k++) begin
            core_access(1'b0, k, '0);
            if ({m_rtag[0], m_rdata[0]} !== gm[k]) begin
                errors++;
                if (errors < 10) $display("FAIL alone [%0d] got %09h want %09h", k, {m_rtag[0], m_rdata[0]}, gm[k]);
            end
        end
        if (a_fault) begin errors++; $display("FAIL fault %0h at %08h", a_freason, a_faddr); end
        if (errors == 0)
            $display("PASS mpy_ca qdepth=%0d buf=%0d lat=%0d seed=%0d ships=%0d words=%0d loads=%0d stores=%0d stall=%0d cycles=%0d alone=32 words in %0d cycles",
                     QDEPTH, BUF, LAT, seed, ships, a_words, loads, stores, stall, cyc, rate);
        else
            $display("FAIL %0d checks", errors);
        $finish;
    end

    initial begin
        #50_000_000;
        $display("FAIL timeout");
        $finish;
    end
endmodule
