`include "mpy_defs.svh"

// Instruction fetch for mpy_core: a QD-word queue of bytecode words that
// reads ahead of pc on its own mpy_mem port.
//
// The queue holds words qb, qb + 4, ... in order. While there is room it
// requests the word after the last one queued or in flight, so the next
// instructions arrive while the core executes the current one. Words are
// interleaved across the SRAM blocks, so these reads run in the same cycles
// as the core's data accesses unless both want the same block.
//
// pc_i is the core's pc. When it moves past the head word, the head is
// dropped. When it leaves the stream (a jump backward, or past the words
// queued and in flight), the queue restarts at pc's word; reads already in
// flight are discarded as they come back. flush_i restarts it the same way
// (the core raises it when it changes frames, as it used to drop its fetch
// window).
//
// The core decodes from win_o >> 8 * (pc - base_o) and may use avail_o
// bytes: the bytes from pc up to the end of the queued words, or up to the
// first word whose read faulted. A read that faults stops the stream; it
// only matters if the core needs that word: fault_o names it (fault_addr_o,
// fault_reason_o) once it is the first unusable word. Reading ahead past the
// end of the code is harmless: those words are never decoded.
//
// req_o comes from flops and is held until gnt_i, with addr_o unchanged.
// It is high in reset, so the system must not grant it while this unit is
// held in reset (mpy_soc masks it with the core's reset).
module mpy_fetch #(
    parameter int QD = 3    // queue depth in words (the window is 4 * QD bytes); at least 3
) (
    input  logic        clk_i,
    input  logic        rst_n_i,

    input  logic [31:0] pc_i,
    input  logic        flush_i,

    output logic        req_o,
    output logic [31:0] addr_o,
    input  logic        gnt_i,
    input  logic        ack_i,
    input  logic [31:0] rdata_i,
    input  logic        fault_i,
    input  logic [3:0]  fault_reason_i,

    output logic [32*QD-1:0] win_o,
    output logic [31:0]      base_o,
    output logic [5:0]       avail_o,
    output logic             fault_o,
    output logic [31:0]      fault_addr_o,
    output logic [3:0]       fault_reason_o
);
    localparam int NW = $clog2(QD + 1);   // counts 0 .. QD
    localparam int IW = (QD > 1) ? $clog2(QD) : 1;   // queue index

    logic [31:0]   q_w   [0:QD-1];
    logic          q_f   [0:QD-1];   // the read faulted
    logic [3:0]    q_r   [0:QD-1];   // its fault reason
    logic [31:0]   qb;               // address of q_w[0]
    logic [NW-1:0] qn;               // words queued
    logic [2:0]    nfl;              // reads granted and not back, kept
    logic [2:0]    ndrop;            // reads granted and not back, discarded
    logic          stop;             // a faulted word is queued

    // Words usable from the head: up to the first faulted one.
    logic [NW-1:0] vn;
    always_comb begin
        vn = qn;
        for (int i = QD - 1; i >= 0; i--)
            if (NW'(i) < qn && q_f[i]) vn = NW'(i);
    end

    logic [29:0] pw, bw, dw;
    assign pw = pc_i[31:2];
    assign bw = qb[31:2];
    assign dw = pw - bw;

    logic redirect, pop;
    assign redirect = flush_i || (pw < bw) || (dw > 30'(qn) + 30'(nfl));
    assign pop = !redirect && (qn != '0) && (dw != '0);

    assign req_o  = !stop && (32'(qn) + 32'(nfl) < QD);
    assign addr_o = qb + {30'(qn) + 30'(nfl), 2'b00};

    for (genvar i = 0; i < QD; i++) begin : g_win
        assign win_o[32*i +: 32] = q_w[i];
    end
    assign base_o = qb;

    logic [31:0] off;
    assign off = pc_i - qb;
    always_comb begin
        if (!redirect && (dw < 30'(vn)))
            avail_o = 6'(32'(4 * vn) - off);
        else
            avail_o = '0;
    end
    assign fault_o        = (vn != qn);
    assign fault_addr_o   = qb + {30'(vn), 2'b00};
    assign fault_reason_o = q_r[IW'(vn)];   // only read while vn < qn <= QD

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            for (int i = 0; i < QD; i++) begin
                q_w[i] <= '0;
                q_f[i] <= 1'b0;
                q_r[i] <= '0;
            end
            qb    <= '0;
            qn    <= '0;
            nfl   <= '0;
            ndrop <= '0;
            stop  <= 1'b0;
        end else if (redirect) begin
            // Everything granted and not back, this cycle's grant included,
            // comes back to be dropped.
            ndrop <= ndrop + nfl + (gnt_i ? 3'd1 : 3'd0) - (ack_i ? 3'd1 : 3'd0);
            nfl   <= '0;
            qn    <= '0;
            qb    <= {pc_i[31:2], 2'b00};
            stop  <= 1'b0;
        end else begin
            logic          keep;
            logic [NW-1:0] n;
            keep = ack_i && (ndrop == '0);
            if (ack_i && ndrop != '0) ndrop <= ndrop - 3'd1;
            nfl <= nfl + (gnt_i ? 3'd1 : 3'd0) - (keep ? 3'd1 : 3'd0);
            n = qn;
            if (pop) begin
                for (int i = 0; i < QD - 1; i++) begin
                    q_w[i] <= q_w[i + 1];
                    q_f[i] <= q_f[i + 1];
                    q_r[i] <= q_r[i + 1];
                end
                qb <= qb + 32'd4;
                n = qn - 1'b1;
            end
            if (keep) begin
                // n < QD here: a read is only requested while there is room.
                q_w[IW'(n)] <= rdata_i;
                q_f[IW'(n)] <= fault_i;
                q_r[IW'(n)] <= fault_reason_i;
                if (fault_i) stop <= 1'b1;
                n = n + 1'b1;
            end
            qn <= n;
        end
    end

endmodule
