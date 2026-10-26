`include "mpy_defs.svh"

// Container accelerator (CA): a background word mover with a scoreboard
// (upycore/docs/mpy_ca.md).
//
// The core ships "copy n tagged words from src to dst" and moves on to the
// next instruction. Commands queue QDEPTH deep and run in issue order. A copy
// whose destination sits above its source runs from the top word down, so an
// overlapping shift inside one item array behaves like memmove, the same as
// the core's own _wcopy loop.
//
// Scoreboard. Every queued command holds two byte ranges: the destination
// words it has not written yet and the source words it has not read yet. The
// running command shrinks both ranges as each word lands. chk_busy_o answers
// for the core's pending access: a load or store of a busy destination word,
// or a store to a busy source word, is busy. mpy_soc holds that access at the
// port until the range has moved past it. Every heap access the core makes,
// microcode or firmware, goes through that port, so whatever touches a copy
// in flight waits for exactly the words it needs and nothing else.
//
// The core keeps three rules that make this safe:
//   - it allocates the destination itself before it ships, so a failed
//     allocation and its MemoryError stay on the instruction that caused them;
//   - its own stores that a command reads have completed before it ships;
//   - it waits for idle_o before it starts a collection, so nothing is in
//     flight while the collector marks and no source block is freed under
//     the engine.
//
// The memory port holds req_o until gnt_i. ack_i pulses when this unit's
// access completes. The engine issues the write of a word in the cycle the
// read's ack arrives, and the next read in the cycle the write's ack
// arrives, so a copy on an idle port takes four cycles per word.
//
// A faulting access (unaligned word, flash store, bus) drops its command and
// sets fault_o until reset. The core halts on it at the next instruction.
module mpy_ca #(
    parameter int QDEPTH = 2
) (
    input  logic        clk_i,
    input  logic        rst_n_i,

    input  logic        cmd_valid_i,
    output logic        cmd_ready_o,
    input  logic [31:0] cmd_dst_i,
    input  logic [31:0] cmd_src_i,
    input  logic [31:0] cmd_n_i,
    output logic        idle_o,

    input  logic [31:0] chk_addr_i,
    input  logic        chk_we_i,
    output logic        chk_busy_o,

    output logic        req_o,
    output logic        we_o,
    output logic [31:0] addr_o,
    output logic [31:0] wdata_o,
    output logic [3:0]  wtag_o,
    input  logic        gnt_i,
    input  logic        ack_i,
    input  logic        fault_i,
    input  logic [3:0]  fault_reason_i,
    input  logic [31:0] rdata_i,
    input  logic [3:0]  rtag_i,

    output logic        fault_o,
    output logic [3:0]  fault_reason_o,
    output logic [31:0] fault_addr_o,
    output logic [31:0] words_o,
    output logic [31:0] cmds_o
);
    localparam int QW = (QDEPTH > 1) ? $clog2(QDEPTH) : 1;

    typedef enum logic [2:0] { E_IDLE, E_RD, E_RDW, E_WR, E_WRW } est_e;
    est_e st;

    // Queue slots. [lo, hi) are byte ranges of words still owed.
    logic          qv   [0:QDEPTH-1];
    logic          back [0:QDEPTH-1];
    logic [31:0]   dlo  [0:QDEPTH-1];
    logic [31:0]   dhi  [0:QDEPTH-1];
    logic [31:0]   slo  [0:QDEPTH-1];
    logic [31:0]   shi  [0:QDEPTH-1];
    logic [QW-1:0] head;
    logic [QW:0]   cnt;

    logic [31:0] dat_r;
    logic [3:0]  tag_r;

    function automatic logic [QW-1:0] nxt(input logic [QW-1:0] i);
        nxt = (32'(i) == QDEPTH - 1) ? '0 : i + 1'b1;
    endfunction

    logic [QW-1:0] tail;
    always_comb begin
        logic [QW:0] s;
        s = {1'b0, head} + cnt;
        tail = (32'(s) >= QDEPTH) ? QW'(32'(s) - QDEPTH) : s[QW-1:0];
    end

    // The head command's current word, and the read after it.
    logic        hb, last;
    logic [31:0] rd_a, rd_next, wr_a;
    assign hb      = back[head];
    assign last    = (dhi[head] - dlo[head]) == 32'd4;
    assign rd_a    = hb ? shi[head] - 32'd4 : slo[head];
    assign rd_next = hb ? shi[head] - 32'd8 : slo[head] + 32'd4;
    assign wr_a    = hb ? dhi[head] - 32'd4 : dlo[head];

    logic issue_wr, issue_rd;
    assign issue_wr = (st == E_WR) || (st == E_RDW && ack_i && !fault_i);
    assign issue_rd = (st == E_RD) || (st == E_WRW && ack_i && !fault_i && !last);

    assign req_o   = issue_wr || issue_rd;
    assign we_o    = issue_wr;
    assign addr_o  = issue_wr ? wr_a : (st == E_WRW) ? rd_next : rd_a;
    assign wdata_o = (st == E_RDW) ? rdata_i : dat_r;
    assign wtag_o  = (st == E_RDW) ? rtag_i : tag_r;

    // The core holds one more command while its last ship is still landing.
    assign cmd_ready_o = 32'(cnt) < QDEPTH;
    assign idle_o = (cnt == '0);

    always_comb begin
        chk_busy_o = 1'b0;
        for (int k = 0; k < QDEPTH; k++) begin
            if (qv[k] && chk_addr_i >= dlo[k] && chk_addr_i < dhi[k]) chk_busy_o = 1'b1;
            if (qv[k] && chk_we_i && chk_addr_i >= slo[k] && chk_addr_i < shi[k]) chk_busy_o = 1'b1;
        end
    end

    // A command leaves the queue when its last word lands or an access faults.
    logic push, pop;
    assign push = cmd_valid_i && cmd_ready_o && cmd_n_i != 32'd0;
    assign pop = ack_i && ((st == E_RDW && fault_i) || (st == E_WRW && (fault_i || last)));

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            st <= E_IDLE;
            head <= '0;
            cnt <= '0;
            for (int k = 0; k < QDEPTH; k++) begin
                qv[k] <= 1'b0; back[k] <= 1'b0;
                dlo[k] <= '0; dhi[k] <= '0; slo[k] <= '0; shi[k] <= '0;
            end
            dat_r <= '0; tag_r <= '0;
            fault_o <= 1'b0; fault_reason_o <= '0; fault_addr_o <= '0;
            words_o <= '0; cmds_o <= '0;
        end else begin
            if (push) begin
                qv[tail] <= 1'b1;
                back[tail] <= cmd_dst_i > cmd_src_i;
                dlo[tail] <= cmd_dst_i;
                dhi[tail] <= cmd_dst_i + (cmd_n_i << 2);
                slo[tail] <= cmd_src_i;
                shi[tail] <= cmd_src_i + (cmd_n_i << 2);
            end
            case (st)
                E_IDLE: if (cnt != '0) st <= E_RD;
                E_RD: if (gnt_i) st <= E_RDW;
                E_RDW: if (ack_i) begin
                    if (fault_i) begin
                        fault_o <= 1'b1; fault_reason_o <= fault_reason_i; fault_addr_o <= rd_a;
                        st <= E_IDLE;
                    end else begin
                        dat_r <= rdata_i; tag_r <= rtag_i;
                        st <= gnt_i ? E_WRW : E_WR;
                    end
                end
                E_WR: if (gnt_i) st <= E_WRW;
                E_WRW: if (ack_i) begin
                    if (fault_i) begin
                        fault_o <= 1'b1; fault_reason_o <= fault_reason_i; fault_addr_o <= wr_a;
                        st <= E_IDLE;
                    end else begin
                        words_o <= words_o + 32'd1;
                        if (hb) begin
                            dhi[head] <= dhi[head] - 32'd4; shi[head] <= shi[head] - 32'd4;
                        end else begin
                            dlo[head] <= dlo[head] + 32'd4; slo[head] <= slo[head] + 32'd4;
                        end
                        if (last) begin
                            cmds_o <= cmds_o + 32'd1;
                            st <= E_IDLE;
                        end else st <= gnt_i ? E_RDW : E_RD;
                    end
                end
                default: st <= E_IDLE;
            endcase
            if (pop) begin
                qv[head] <= 1'b0;
                head <= nxt(head);
            end
            cnt <= cnt + (push ? 1'b1 : 1'b0) - (pop ? 1'b1 : 1'b0);
        end
    end
endmodule
