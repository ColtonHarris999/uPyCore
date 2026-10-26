// IRQ delivery for the MicroPython hart.
// Spec: upycore/docs/mpy_peripherals.md
//
// Hard: taken at a bytecode boundary. heap_locked and sched_locked stay
// set until done. Soft device IRQs and micropython.schedule share one
// ring of depth 8 and run one callback at a jump opcode. That callback
// leaves the heap unlocked. The ninth schedule while the ring is full
// pulses sched_full; the native builtin raises RuntimeError.
//
// KBD is not a callback. At a jump with no hard callback running, an
// armed KBD pulses kbd_raise instead of the soft steps, and the hart
// raises KeyboardInterrupt in the running frame.
//
// Every handler word and ring slot carries the tag of its payload. The
// hart mirrors them into the SRAM windows the collector scans; dirty says
// a handler write, a push, or a pop happened since the last mirror_clr.
module mpy_irq
    import mpy_mmio_pkg::*;
(
    input  logic                          clk_i,
    input  logic                          rst_n_i,

    input  logic [MPY_NSRC-1:0]           status_i,
    input  logic [MPY_NSRC-1:0]           event_set_i,
    input  logic [MPY_NSRC-1:0]           enable_i,
    input  logic [MPY_NSRC-1:0]           hard_i,
    input  logic                          gie_i,
    output logic [MPY_NSRC-1:0]           accept_clr_o,

    input  logic                          bc_boundary_i,
    input  logic                          jump_i,
    input  logic                          done_i,

    output logic                          fire_o,
    output logic                          fire_hard_o,
    output logic                          fire_sched_o,
    output logic [2:0]                    fire_src_o,
    output logic [31:0]                   fire_fn_o,
    output logic [31:0]                   fire_arg_o,
    output logic [3:0]                    fire_fn_tag_o,
    output logic [3:0]                    fire_arg_tag_o,
    output logic                          kbd_raise_o,

    output logic                          heap_locked_o,
    output logic                          sched_locked_o,
    output logic                          irq_active_o,

    input  logic                          handler_we_i,
    input  logic [2:0]                    handler_idx_i,
    input  logic [31:0]                   handler_fn_i,
    input  logic [31:0]                   handler_arg_i,
    input  logic [3:0]                    handler_fn_tag_i,
    input  logic [3:0]                    handler_arg_tag_i,

    input  logic                          sched_push_i,
    input  logic [31:0]                   sched_fn_i,
    input  logic [31:0]                   sched_arg_i,
    input  logic [3:0]                    sched_fn_tag_i,
    input  logic [3:0]                    sched_arg_tag_i,
    output logic                          sched_ok_o,
    output logic                          sched_full_o,

    output logic [7:0]                    sched_head_o,
    output logic [7:0]                    sched_tail_o,

    // Mirror read port: 0..7 ring slot, 8..15 handler slot.
    output logic                          mirror_dirty_o,
    input  logic [3:0]                    mirror_sel_i,
    input  logic                          mirror_clr_i,
    output logic [35:0]                   mirror_fn_o,
    output logic [35:0]                   mirror_arg_o,

    input  logic [31:0]                   pc_i,
    input  logic [31:0]                   fp_i,
    input  logic [31:0]                   sp_i,
    input  logic [31:0]                   exc_sp_i,
    output logic [31:0]                   saved_pc_o,
    output logic [31:0]                   saved_fp_o,
    output logic [31:0]                   saved_sp_o,
    output logic [31:0]                   saved_exc_sp_o
);
    localparam int DEPTH = MPY_SCHED_DEPTH;
    localparam int SLOT_W = $clog2(DEPTH);
    // KBD raises; it is never queued or called.
    localparam logic [MPY_NSRC-1:0] CALLABLE = ~(MPY_NSRC'(1) << MPY_SRC_KBD);

    logic [31:0] handler_fn_r [0:MPY_NSRC-1];
    logic [31:0] handler_arg_r [0:MPY_NSRC-1];
    logic [3:0]  handler_fn_tag_r [0:MPY_NSRC-1];
    logic [3:0]  handler_arg_tag_r [0:MPY_NSRC-1];

    mpy_sched_entry_t ring_r [0:DEPTH-1];
    logic [7:0] head_r;
    logic [7:0] tail_r;
    logic       dirty_r;

    logic [MPY_NSRC-1:0] accept_clr_c;
    logic                start_c;
    logic                start_hard_c;
    logic                start_sched_c;
    logic [2:0]          start_src_c;
    logic [31:0]         start_fn_c;
    logic [31:0]         start_arg_c;
    logic [3:0]          start_fn_tag_c;
    logic [3:0]          start_arg_tag_c;
    logic                kbd_c;
    logic                push_ok_c;
    logic                push_full_c;
    logic [7:0]          head_n;
    logic [7:0]          tail_n;
    mpy_sched_entry_t    ring_n [0:DEPTH-1];

    assign accept_clr_o  = accept_clr_c;
    assign kbd_raise_o   = kbd_c;
    assign sched_head_o  = head_r;
    assign sched_tail_o  = tail_r;
    assign heap_locked_o = fire_o && fire_hard_o;
    assign sched_locked_o = fire_o && fire_hard_o;
    assign irq_active_o  = fire_o && fire_hard_o;
    assign mirror_dirty_o = dirty_r;

    // Mirror words. A ring slot outside [head, tail) is the empty word.
    always_comb begin
        logic [2:0] slot;
        logic [7:0] occ;
        logic [7:0] rel;
        slot = mirror_sel_i[2:0];
        occ  = mpy_sched_occ(head_r, tail_r);
        rel  = {5'd0, 3'(slot - head_r[SLOT_W-1:0])};
        if (mirror_sel_i[3]) begin
            mirror_fn_o  = {handler_fn_tag_r[slot], handler_fn_r[slot]};
            mirror_arg_o = {handler_arg_tag_r[slot], handler_arg_r[slot]};
        end else if (rel < occ) begin
            mirror_fn_o  = {ring_r[slot].fn_tag, ring_r[slot].fn};
            mirror_arg_o = {ring_r[slot].arg_tag, ring_r[slot].arg};
        end else begin
            mirror_fn_o  = 36'h0;
            mirror_arg_o = 36'h0;
        end
    end

    // Delivery order matches upycore/docs/mpy_peripherals.md.
    // Hard at a bytecode boundary. Soft sources join the ring only at a
    // jump. schedule() pushes against the depth after that enqueue and
    // before the pop, so a full ring raises even on a jump that will run
    // one callback. One pop per jump, and only when no callback is running.
    always_comb begin
        logic [MPY_NSRC-1:0] pend;
        logic [MPY_NSRC-1:0] hard_bits;
        logic [MPY_NSRC-1:0] soft_bits;
        logic                found_hard;
        logic                took_hard;
        logic [2:0]          hard_src;
        int                  i;

        for (i = 0; i < DEPTH; i++)
            ring_n[i] = ring_r[i];
        head_n          = head_r;
        tail_n          = tail_r;
        accept_clr_c    = '0;
        start_c         = 1'b0;
        start_hard_c    = 1'b0;
        start_sched_c   = 1'b0;
        start_src_c     = '0;
        start_fn_c      = '0;
        start_arg_c     = '0;
        start_fn_tag_c  = '0;
        start_arg_tag_c = '0;
        kbd_c           = 1'b0;
        push_ok_c       = 1'b0;
        push_full_c     = 1'b0;
        found_hard      = 1'b0;
        took_hard       = 1'b0;
        hard_src        = '0;

        pend      = (status_i | event_set_i) & enable_i;
        hard_bits = pend & hard_i & CALLABLE & {MPY_NSRC{gie_i}};
        soft_bits = pend & ~hard_i & CALLABLE & {MPY_NSRC{gie_i}};

        if (!fire_o && gie_i && bc_boundary_i) begin
            for (i = 0; i < MPY_NSRC; i++) begin
                if (!found_hard && hard_bits[i] && (handler_fn_r[i] != 32'h0)) begin
                    found_hard = 1'b1;
                    hard_src   = i[2:0];
                end
            end
        end

        if (found_hard) begin
            took_hard       = 1'b1;
            start_c         = 1'b1;
            start_hard_c    = 1'b1;
            start_src_c     = hard_src;
            start_fn_c      = handler_fn_r[hard_src];
            start_arg_c     = handler_arg_r[hard_src];
            start_fn_tag_c  = handler_fn_tag_r[hard_src];
            start_arg_tag_c = handler_arg_tag_r[hard_src];
            accept_clr_c[hard_src] = 1'b1;
        end else if (jump_i && gie_i && !(fire_o && fire_hard_o) && pend[MPY_SRC_KBD]) begin
            // A soft callback may be running; KBD interrupts it.
            kbd_c = 1'b1;
            accept_clr_c[MPY_SRC_KBD] = 1'b1;
        end else if (!fire_o && jump_i && gie_i) begin
            for (i = 0; i < MPY_NSRC; i++) begin
                if (soft_bits[i] && (handler_fn_r[i] != 32'h0) &&
                    (mpy_sched_occ(head_n, tail_n) < 8'(DEPTH))) begin
                    ring_n[tail_n[SLOT_W-1:0]].fn       = handler_fn_r[i];
                    ring_n[tail_n[SLOT_W-1:0]].arg      = handler_arg_r[i];
                    ring_n[tail_n[SLOT_W-1:0]].fn_tag   = handler_fn_tag_r[i];
                    ring_n[tail_n[SLOT_W-1:0]].arg_tag  = handler_arg_tag_r[i];
                    ring_n[tail_n[SLOT_W-1:0]].src      = i[2:0];
                    ring_n[tail_n[SLOT_W-1:0]].is_sched = 1'b0;
                    tail_n = tail_n + 8'd1;
                    accept_clr_c[i] = 1'b1;
                end
            end
        end

        if (sched_push_i) begin
            if (mpy_sched_occ(head_n, tail_n) < 8'(DEPTH)) begin
                ring_n[tail_n[SLOT_W-1:0]].fn       = sched_fn_i;
                ring_n[tail_n[SLOT_W-1:0]].arg      = sched_arg_i;
                ring_n[tail_n[SLOT_W-1:0]].fn_tag   = sched_fn_tag_i;
                ring_n[tail_n[SLOT_W-1:0]].arg_tag  = sched_arg_tag_i;
                ring_n[tail_n[SLOT_W-1:0]].src      = 3'd0;
                ring_n[tail_n[SLOT_W-1:0]].is_sched = 1'b1;
                tail_n    = tail_n + 8'd1;
                push_ok_c = 1'b1;
            end else begin
                push_full_c = 1'b1;
            end
        end

        if (!fire_o && !took_hard && !kbd_c && jump_i && (head_n != tail_n)) begin
            start_c         = 1'b1;
            start_hard_c    = 1'b0;
            start_sched_c   = ring_n[head_n[SLOT_W-1:0]].is_sched;
            start_src_c     = ring_n[head_n[SLOT_W-1:0]].src;
            start_fn_c      = ring_n[head_n[SLOT_W-1:0]].fn;
            start_arg_c     = ring_n[head_n[SLOT_W-1:0]].arg;
            start_fn_tag_c  = ring_n[head_n[SLOT_W-1:0]].fn_tag;
            start_arg_tag_c = ring_n[head_n[SLOT_W-1:0]].arg_tag;
            head_n          = head_n + 8'd1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        int i;
        if (!rst_n_i) begin
            for (i = 0; i < MPY_NSRC; i++) begin
                handler_fn_r[i]      <= 32'h0;
                handler_arg_r[i]     <= 32'h0;
                handler_fn_tag_r[i]  <= 4'h0;
                handler_arg_tag_r[i] <= 4'h0;
            end
            for (i = 0; i < DEPTH; i++)
                ring_r[i] <= '0;
            head_r         <= 8'h0;
            tail_r         <= 8'h0;
            dirty_r        <= 1'b0;
            fire_o         <= 1'b0;
            fire_hard_o    <= 1'b0;
            fire_sched_o   <= 1'b0;
            fire_src_o     <= 3'h0;
            fire_fn_o      <= 32'h0;
            fire_arg_o     <= 32'h0;
            fire_fn_tag_o  <= 4'h0;
            fire_arg_tag_o <= 4'h0;
            sched_ok_o     <= 1'b0;
            sched_full_o   <= 1'b0;
            saved_pc_o     <= 32'h0;
            saved_fp_o     <= 32'h0;
            saved_sp_o     <= 32'h0;
            saved_exc_sp_o <= 32'h0;
        end else begin
            if (handler_we_i && ({29'h0, handler_idx_i} < MPY_NSRC)) begin
                handler_fn_r[handler_idx_i]      <= handler_fn_i;
                handler_arg_r[handler_idx_i]     <= handler_arg_i;
                handler_fn_tag_r[handler_idx_i]  <= handler_fn_tag_i;
                handler_arg_tag_r[handler_idx_i] <= handler_arg_tag_i;
            end

            for (i = 0; i < DEPTH; i++)
                ring_r[i] <= ring_n[i];
            head_r       <= head_n;
            tail_r       <= tail_n;
            sched_ok_o   <= push_ok_c;
            sched_full_o <= push_full_c;

            // A change in the same cycle as the clear keeps the flag set.
            if (handler_we_i || (head_n != head_r) || (tail_n != tail_r))
                dirty_r <= 1'b1;
            else if (mirror_clr_i)
                dirty_r <= 1'b0;

            if (start_c && !fire_o) begin
                fire_o         <= 1'b1;
                fire_hard_o    <= start_hard_c;
                fire_sched_o   <= start_sched_c;
                fire_src_o     <= start_src_c;
                fire_fn_o      <= start_fn_c;
                fire_arg_o     <= start_arg_c;
                fire_fn_tag_o  <= start_fn_tag_c;
                fire_arg_tag_o <= start_arg_tag_c;
                if (start_hard_c) begin
                    saved_pc_o     <= pc_i;
                    saved_fp_o     <= fp_i;
                    saved_sp_o     <= sp_i;
                    saved_exc_sp_o <= exc_sp_i;
                end
            end else if (done_i && fire_o) begin
                fire_o       <= 1'b0;
                fire_hard_o  <= 1'b0;
                fire_sched_o <= 1'b0;
            end
        end
    end
endmodule
