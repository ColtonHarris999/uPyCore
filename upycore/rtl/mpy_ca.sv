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
// words it has not written yet and the source words it has not read yet. A
// range shrinks when the port takes the access for its next word. The port
// completes accesses in the order it takes them, so an access the core makes
// after that sees the copy's read or write as done. chk_busy_o answers for
// the core's pending access: a load or store of a busy destination word, or
// a store to a busy source word, is busy. mpy_soc holds that access at the
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
// Engine. The running command streams: reads go out ahead of the writes
// into a BUF-word buffer (data and tag), and each write takes the oldest
// buffered word. A read is put on the port only while the buffer has room
// for it and for every read already on its way, so read data never waits.
// Writes go first when both are ready, which retires destination words as
// early as possible. Running ahead is safe for overlapping copies: reads
// move away from the words the writes have reached. The next command starts
// after the port has taken the last write of this one, so its reads see
// those writes.
//
// The request to the port comes from flops (held until gnt_i) and so do the
// next addresses and counts, so no path runs from the port back through
// this unit's arithmetic in one cycle except the grant itself. On mpy_soc's
// pipelined port a copy on an idle port takes two cycles per word, one
// read and one write, which is the port's whole bandwidth.
//
// ack_i pulses when one of this unit's accesses completes; they complete in
// order. A faulting access (unaligned word, flash store, bus) sets fault_o
// until reset and drops every queued command. The core halts on it at the
// next instruction; until then it can still ship, and those commands are
// dropped too.
module mpy_ca #(
    parameter int QDEPTH = 2,
    parameter int BUF = 4
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
    localparam int BW = (BUF > 1) ? $clog2(BUF) : 1;
    // mpy_mem takes a request only in the last cycle of the one before, so
    // at most two accesses are taken and not yet acked.
    localparam int IFD = 2;

    // Queue slots. [lo, hi) are byte ranges of words still owed.
    logic          qv   [0:QDEPTH-1];
    logic          back [0:QDEPTH-1];
    logic [31:0]   dlo  [0:QDEPTH-1];
    logic [31:0]   dhi  [0:QDEPTH-1];
    logic [31:0]   slo  [0:QDEPTH-1];
    logic [31:0]   shi  [0:QDEPTH-1];
    logic [QW-1:0] head;
    logic [QW:0]   cnt;

    function automatic logic [QW-1:0] nxt(input logic [QW-1:0] i);
        nxt = (32'(i) == QDEPTH - 1) ? '0 : i + 1'b1;
    endfunction

    logic [QW-1:0] tail;
    always_comb begin
        logic [QW:0] s;
        s = {1'b0, head} + cnt;
        tail = (32'(s) >= QDEPTH) ? QW'(32'(s) - QDEPTH) : s[QW-1:0];
    end

    // The running command: next addresses to put on the port and the
    // accesses left to put there.
    logic        act, eb;
    logic [31:0] ra, wa, rn, wn;
    logic [31:0] step;
    assign step = eb ? 32'hFFFF_FFFC : 32'd4;

    // Read-ahead buffer, and the reads that will land in it.
    logic [35:0]   fb [0:BUF-1];
    logic [BW-1:0] fb_rp, fb_wp;
    logic [BW:0]   fc, rpend;

    // Accesses the port has taken, oldest first, for the acks.
    logic          if_we   [0:IFD-1];
    logic [31:0]   if_addr [0:IFD-1];
    logic [1:0]    if_n;

    // The request register.
    logic        rq_v, rq_we;
    logic [31:0] rq_a, rq_d;
    logic [3:0]  rq_t;
    assign req_o   = rq_v;
    assign we_o    = rq_we;
    assign addr_o  = rq_a;
    assign wdata_o = rq_d;
    assign wtag_o  = rq_t;

    logic take, ld_ok, ld_wr, ld_rd, last_wr, rd_ack, wr_ack, flt, push, pop;
    assign take    = rq_v && gnt_i;
    assign ld_ok   = !rq_v || gnt_i;
    assign ld_wr   = ld_ok && act && wn != 32'd0 && fc != '0;
    assign ld_rd   = ld_ok && act && !ld_wr && rn != 32'd0 && 32'(rpend) + 32'(fc) < BUF;
    assign last_wr = take && rq_we && wn == 32'd0;
    assign flt     = ack_i && fault_i && !fault_o;
    assign rd_ack  = ack_i && !fault_i && !fault_o && !if_we[0];
    assign wr_ack  = ack_i && !fault_i && !fault_o && if_we[0];
    assign push    = cmd_valid_i && cmd_ready_o && cmd_n_i != 32'd0 && !fault_o && !flt;
    assign pop     = last_wr && !flt;

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

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            head <= '0;
            cnt <= '0;
            for (int k = 0; k < QDEPTH; k++) begin
                qv[k] <= 1'b0; back[k] <= 1'b0;
                dlo[k] <= '0; dhi[k] <= '0; slo[k] <= '0; shi[k] <= '0;
            end
            act <= 1'b0; eb <= 1'b0;
            ra <= '0; wa <= '0; rn <= '0; wn <= '0;
            for (int k = 0; k < BUF; k++) fb[k] <= '0;
            fb_rp <= '0; fb_wp <= '0; fc <= '0; rpend <= '0;
            for (int k = 0; k < IFD; k++) begin if_we[k] <= 1'b0; if_addr[k] <= '0; end
            if_n <= '0;
            rq_v <= 1'b0; rq_we <= 1'b0; rq_a <= '0; rq_d <= '0; rq_t <= '0;
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

            // Start the head command once the one before has left.
            if (!act && cnt != '0 && !fault_o) begin
                act <= 1'b1;
                eb <= back[head];
                ra <= back[head] ? shi[head] - 32'd4 : slo[head];
                wa <= back[head] ? dhi[head] - 32'd4 : dlo[head];
                rn <= (shi[head] - slo[head]) >> 2;
                wn <= (shi[head] - slo[head]) >> 2;
            end

            // The port took the request: the word it covers is no longer owed.
            if (take) begin
                if (rq_we) begin
                    if (eb) dhi[head] <= rq_a; else dlo[head] <= rq_a + 32'd4;
                end else begin
                    if (eb) shi[head] <= rq_a; else slo[head] <= rq_a + 32'd4;
                end
            end

            // Next request.
            if (ld_wr) begin
                rq_v <= 1'b1; rq_we <= 1'b1; rq_a <= wa;
                {rq_t, rq_d} <= fb[fb_rp];
                fb_rp <= (32'(fb_rp) == BUF - 1) ? '0 : fb_rp + 1'b1;
                wa <= wa + step;
                wn <= wn - 32'd1;
            end else if (ld_rd) begin
                rq_v <= 1'b1; rq_we <= 1'b0; rq_a <= ra;
                ra <= ra + step;
                rn <= rn - 32'd1;
            end else if (ld_ok) begin
                rq_v <= 1'b0;
            end
            fc <= fc + (rd_ack ? 1'b1 : 1'b0) - (ld_wr ? 1'b1 : 1'b0);
            rpend <= rpend + (ld_rd ? 1'b1 : 1'b0) - (rd_ack ? 1'b1 : 1'b0);
            if (rd_ack) begin
                fb[fb_wp] <= {rtag_i, rdata_i};
                fb_wp <= (32'(fb_wp) == BUF - 1) ? '0 : fb_wp + 1'b1;
            end
            if (wr_ack) words_o <= words_o + 32'd1;

            // Taken accesses wait here for their acks.
            if (ack_i) begin
                for (int k = 0; k < IFD - 1; k++) begin
                    if_we[k] <= if_we[k + 1]; if_addr[k] <= if_addr[k + 1];
                end
            end
            if (take) begin
                if_we[32'(if_n) - (ack_i ? 1 : 0)] <= rq_we;
                if_addr[32'(if_n) - (ack_i ? 1 : 0)] <= rq_a;
            end
            if_n <= if_n + (take ? 2'd1 : 2'd0) - (ack_i ? 2'd1 : 2'd0);

            if (pop) begin
                qv[head] <= 1'b0;
                head <= nxt(head);
                act <= 1'b0;
                cmds_o <= cmds_o + 32'd1;
            end
            cnt <= cnt + (push ? 1'b1 : 1'b0) - (pop ? 1'b1 : 1'b0);

            if (flt) begin
                fault_o <= 1'b1; fault_reason_o <= fault_reason_i; fault_addr_o <= if_addr[0];
                for (int k = 0; k < QDEPTH; k++) qv[k] <= 1'b0;
                head <= '0; cnt <= '0;
                act <= 1'b0; rq_v <= 1'b0;
                fb_rp <= '0; fb_wp <= '0; fc <= '0; rpend <= '0;
            end
        end
    end

`ifndef SYNTHESIS
    always @(posedge clk_i) begin
        if (rst_n_i && !fault_o && ((take && !ack_i && 32'(if_n) == IFD) || (ack_i && if_n == '0)))
            $error("mpy_ca: %0d taken accesses awaiting acks is out of range", if_n);
    end
`endif
endmodule
