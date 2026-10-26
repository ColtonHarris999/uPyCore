// UART, GPIO, timer, ticks, and the IRQ register file.
// Spec: upycore/docs/mpy_peripherals.md
//
// The six draft offsets are unchanged. Added registers start at 0x18.
// UART_RX is the head of a UART_FIFO_DEPTH-byte FIFO: a load pops it, and
// a byte that arrives while the FIFO is full sets sticky overrun bit 30
// and is dropped. Depth 1 is the v1 buffer. UART_BAUD 0 is byte mode: the
// strobe pushes whole bytes and a TX store leaves in the same cycle. A
// nonzero UART_BAUD runs 8N1 on uart_txd/uart_rxd. TIMER_COUNT advances
// on a tick, which is timer_step or the TIMER_PRESC pulse. Compare 0
// disables the timer. mpy_irq clears a source when its callback is
// accepted.
module mpy_periph
    import mpy_mmio_pkg::*;
#(
    parameter int UART_FIFO_DEPTH = 16
) (
    input  logic        clk_i,
    input  logic        rst_n_i,

    input  logic        req_i,
    input  logic        we_i,
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,
    output logic        ack_o,
    output logic        fault_o,

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

    input  logic        soft_set_i,
    input  logic        gc_req_i,
    input  logic        sim_set_i,
    input  logic        kbd_set_i,
    input  logic        mbox_set_i,

    input  logic        bc_boundary_i,
    input  logic        jump_i,
    input  logic        done_i,
    output logic        wake_o,

    output logic        fire_o,
    output logic        fire_hard_o,
    output logic        fire_sched_o,
    output logic [2:0]  fire_src_o,
    output logic [31:0] fire_fn_o,
    output logic [31:0] fire_arg_o,
    output logic [3:0]  fire_fn_tag_o,
    output logic [3:0]  fire_arg_tag_o,
    output logic        kbd_raise_o,
    output logic        heap_locked_o,
    output logic        sched_locked_o,
    output logic        irq_active_o,

    input  logic        handler_we_i,
    input  logic [2:0]  handler_idx_i,
    input  logic [31:0] handler_fn_i,
    input  logic [31:0] handler_arg_i,
    input  logic [3:0]  handler_fn_tag_i,
    input  logic [3:0]  handler_arg_tag_i,

    input  logic        sched_push_i,
    input  logic [31:0] sched_fn_i,
    input  logic [31:0] sched_arg_i,
    input  logic [3:0]  sched_fn_tag_i,
    input  logic [3:0]  sched_arg_tag_i,
    output logic        sched_ok_o,
    output logic        sched_full_o,

    output logic        mirror_dirty_o,
    input  logic [3:0]  mirror_sel_i,
    input  logic        mirror_clr_i,
    output logic [35:0] mirror_fn_o,
    output logic [35:0] mirror_arg_o,

    input  logic [31:0] pc_i,
    input  logic [31:0] fp_i,
    input  logic [31:0] sp_i,
    input  logic [31:0] exc_sp_i,
    output logic [31:0] saved_pc_o,
    output logic [31:0] saved_fp_o,
    output logic [31:0] saved_sp_o,
    output logic [31:0] saved_exc_sp_o
);
    localparam int FD = UART_FIFO_DEPTH;
    localparam int FPW = (FD > 1) ? $clog2(FD) : 1;
    localparam int FCW = $clog2(FD + 1);

    logic [11:0] off;
    logic        in_window;
    logic        aligned;
    logic        req_ok;

    logic wr_tx, wr_rx, wr_gout, wr_tc, wr_stat, wr_en, wr_hard, wr_gie;
    logic wr_table, wr_gin, wr_gedge, rd_rx;
    logic wr_baud, wr_presc, wr_oe, wr_pu, wr_pd, wr_gstat, wr_kbd;

    logic [31:0] gpio_out_r, gpio_in_r, gpio_edge_r;
    logic [31:0] gpio_oe_r, gpio_pu_r, gpio_pd_r;
    logic [15:0] gpio_stat_r;
    logic [31:0] gpio_sync1_r, gpio_sync2_r;
    logic [31:0] compare_r, count_r, ticks_r;
    logic [31:0] presc_r, presc_cnt_r;
    logic [7:0]  tx_byte_r;
    logic        overrun_r, frame_err_r;
    logic [8:0]  kbd_r;
    logic [MPY_NSRC-1:0] status_r, enable_r, hard_r;
    logic        gie_r;
    logic [31:0] irq_table_r;

    // UART
    logic [15:0] baud_r;
    logic [15:0] baud;
    logic        byte_mode;
    logic [7:0]  rxq [0:FD-1];
    logic [7:0]  txq [0:FD-1];
    logic [FPW-1:0] rx_rd_r, rx_wr_r, tx_rd_r, tx_wr_r;
    logic [FCW-1:0] rx_cnt_r, tx_cnt_r;
    logic        rx_full, tx_full, rx_empty, tx_empty;
    logic        rx_in;
    logic [7:0]  rx_in_byte;
    logic        kbd_hit;
    logic        rx_pop;
    logic        tx_push, tx_pop;
    // serializer
    logic        txd_r, tx_busy_r;
    logic [8:0]  tx_sh_r;
    logic [3:0]  tx_bit_r;
    logic [15:0] tx_clk_r;
    // receiver
    logic        rxd_s1_r, rxd_s2_r, rxd_d_r;
    logic        rx_busy_r;
    logic [3:0]  rx_bit_r;
    logic [15:0] rx_clk_r;
    logic [7:0]  rx_sh_r;
    logic        ser_valid;
    logic [7:0]  ser_byte;
    logic        ser_ferr;

    logic        presc_tick;
    logic        tick;
    logic [32:0] count_inc;
    logic        timer_match;
    logic        uart_take;
    logic        uart_drop;
    logic        gin_write;
    logic [31:0] gin_new;
    logic [15:0] gpio_pins;
    logic        gpio_hit;
    logic [MPY_NSRC-1:0] event_set;
    logic [MPY_NSRC-1:0] accept_clr;
    logic [MPY_NSRC-1:0] w1c;
    logic [MPY_NSRC-1:0] status_n;
    logic [7:0]          sched_head;
    logic [7:0]          sched_tail;

    function automatic logic [FPW-1:0] fnext(input logic [FPW-1:0] p);
        fnext = (32'(p) == FD - 1) ? '0 : p + 1'b1;
    endfunction

    assign off = addr_i[11:0];
    assign in_window = (addr_i[31:12] == 20'h00000) ||
                       (addr_i[31:12] == MPY_MMIO_BASE[31:12]);
    assign aligned = (addr_i[1:0] == 2'b00);
    assign fault_o = req_i && (!aligned || !in_window);
    assign req_ok  = req_i && aligned && in_window;
    assign ack_o   = req_ok;

    assign wr_tx    = req_ok && we_i && (off == MPY_UART_TX);
    assign wr_rx    = req_ok && we_i && (off == MPY_UART_RX);
    assign wr_gout  = req_ok && we_i && (off == MPY_GPIO_OUT);
    assign wr_tc    = req_ok && we_i && (off == MPY_TIMER_COUNT);
    assign wr_stat  = req_ok && we_i && (off == MPY_IRQ_STATUS);
    assign wr_en    = req_ok && we_i && (off == MPY_IRQ_ENABLE);
    assign wr_hard  = req_ok && we_i && (off == MPY_IRQ_HARD);
    assign wr_gie   = req_ok && we_i && (off == MPY_IRQ_GIE);
    assign wr_table = req_ok && we_i && (off == MPY_IRQ_TABLE);
    assign wr_gin   = req_ok && we_i && (off == MPY_GPIO_IN);
    assign wr_gedge = req_ok && we_i && (off == MPY_GPIO_EDGE);
    assign wr_baud  = req_ok && we_i && (off == MPY_UART_BAUD);
    assign wr_presc = req_ok && we_i && (off == MPY_TIMER_PRESC);
    assign wr_oe    = req_ok && we_i && (off == MPY_GPIO_OE);
    assign wr_pu    = req_ok && we_i && (off == MPY_GPIO_PU);
    assign wr_pd    = req_ok && we_i && (off == MPY_GPIO_PD);
    assign wr_gstat = req_ok && we_i && (off == MPY_GPIO_STATUS);
    assign wr_kbd   = req_ok && we_i && (off == MPY_UART_KBD);
    assign rd_rx    = req_ok && !we_i && (off == MPY_UART_RX);

    assign gpio_out_o = gpio_out_r;
    assign gpio_oe_o  = gpio_oe_r;
    assign gpio_pu_o  = gpio_pu_r;
    assign gpio_pd_o  = gpio_pd_r;

    // ---- UART ----
    // A divider below 4 cannot sample mid-bit, so it is raised to 4.
    assign byte_mode = (baud_r == 16'h0);
    assign baud = (baud_r < 16'd4) ? 16'd4 : baud_r;
    assign rx_full  = (32'(rx_cnt_r) == FD);
    assign rx_empty = (rx_cnt_r == '0);
    assign tx_full  = (32'(tx_cnt_r) == FD);
    assign tx_empty = (tx_cnt_r == '0);

    // The strobe and the receiver share the FIFO's write side.
    assign rx_in      = uart_rx_stb_i || ser_valid;
    assign rx_in_byte = uart_rx_stb_i ? uart_rx_byte_i : ser_byte;
    assign kbd_hit    = rx_in && kbd_r[8] && (rx_in_byte == kbd_r[7:0]);
    // A byte is judged against the level before this cycle's pop.
    assign uart_take = rx_in && !kbd_hit && !rx_full;
    assign uart_drop = rx_in && !kbd_hit && rx_full;
    assign rx_pop    = rd_rx && !rx_empty;

    assign tx_push = wr_tx && !byte_mode && !tx_full;
    assign tx_pop  = !byte_mode && !tx_busy_r && !tx_empty;
    assign uart_tx_stb_o  = byte_mode ? wr_tx : tx_pop;
    assign uart_tx_byte_o = byte_mode ? (wr_tx ? wdata_i[7:0] : tx_byte_r)
                                      : (tx_pop ? txq[tx_rd_r] : tx_byte_r);
    assign uart_txd_o = txd_r;

    // Stop bit sampled this cycle.
    assign ser_valid = rx_busy_r && (rx_bit_r == 4'd9) && (rx_clk_r == 16'h0) && rxd_s2_r;
    assign ser_ferr  = rx_busy_r && (rx_bit_r == 4'd9) && (rx_clk_r == 16'h0) && !rxd_s2_r;
    assign ser_byte  = rx_sh_r;

    // ---- tick ----
    assign presc_tick = (presc_r != 32'h0) && (presc_cnt_r + 32'd1 >= presc_r);
    assign tick = timer_step_i || presc_tick;
    assign count_inc = {1'b0, count_r} + 33'd1;
    assign timer_match = tick && (compare_r != 32'h0) &&
                         (count_inc >= {1'b0, compare_r});

    // ---- GPIO ----
    // A store and a pin sample in the same cycle: the store wins.
    assign gin_write = wr_gin || gpio_in_en_i;
    assign gin_new   = wr_gin ? wdata_i : (gpio_in_en_i ? gpio_sync2_r : gpio_in_r);
    assign gpio_pins = gin_write ? gpio_edge_pins(gpio_edge_r, gpio_in_r, gin_new) : 16'h0;
    assign gpio_hit  = |gpio_pins;

    assign event_set[MPY_SRC_TIMER]  = timer_match;
    assign event_set[MPY_SRC_UART]   = uart_take;
    assign event_set[MPY_SRC_GPIO]   = gpio_hit;
    assign event_set[MPY_SRC_SOFT]   = soft_set_i;
    assign event_set[MPY_SRC_GC_REQ] = gc_req_i;
    assign event_set[MPY_SRC_SIM]    = sim_set_i;
    assign event_set[MPY_SRC_KBD]    = kbd_set_i || kbd_hit;
    assign event_set[MPY_SRC_MBOX]   = mbox_set_i;

    // machine.idle returns on any of these, enabled or not.
    assign wake_o = tick || (|event_set);

    assign w1c = wr_stat ? wdata_i[MPY_NSRC-1:0] : '0;
    // The event that is accepted this cycle is cleared with the status
    // bit. A later event, while the callback is already running, has
    // accept_clr low and sets the bit again.
    assign status_n = (status_r & ~w1c & ~accept_clr) | (event_set & ~accept_clr);

    mpy_irq u_irq (
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .status_i(status_r),
        .event_set_i(event_set),
        .enable_i(enable_r),
        .hard_i(hard_r),
        .gie_i(gie_r),
        .accept_clr_o(accept_clr),
        .bc_boundary_i(bc_boundary_i),
        .jump_i(jump_i),
        .done_i(done_i),
        .fire_o(fire_o),
        .fire_hard_o(fire_hard_o),
        .fire_sched_o(fire_sched_o),
        .fire_src_o(fire_src_o),
        .fire_fn_o(fire_fn_o),
        .fire_arg_o(fire_arg_o),
        .fire_fn_tag_o(fire_fn_tag_o),
        .fire_arg_tag_o(fire_arg_tag_o),
        .kbd_raise_o(kbd_raise_o),
        .heap_locked_o(heap_locked_o),
        .sched_locked_o(sched_locked_o),
        .irq_active_o(irq_active_o),
        .handler_we_i(handler_we_i),
        .handler_idx_i(handler_idx_i),
        .handler_fn_i(handler_fn_i),
        .handler_arg_i(handler_arg_i),
        .handler_fn_tag_i(handler_fn_tag_i),
        .handler_arg_tag_i(handler_arg_tag_i),
        .sched_push_i(sched_push_i),
        .sched_fn_i(sched_fn_i),
        .sched_arg_i(sched_arg_i),
        .sched_fn_tag_i(sched_fn_tag_i),
        .sched_arg_tag_i(sched_arg_tag_i),
        .sched_ok_o(sched_ok_o),
        .sched_full_o(sched_full_o),
        .sched_head_o(sched_head),
        .sched_tail_o(sched_tail),
        .mirror_dirty_o(mirror_dirty_o),
        .mirror_sel_i(mirror_sel_i),
        .mirror_clr_i(mirror_clr_i),
        .mirror_fn_o(mirror_fn_o),
        .mirror_arg_o(mirror_arg_o),
        .pc_i(pc_i),
        .fp_i(fp_i),
        .sp_i(sp_i),
        .exc_sp_i(exc_sp_i),
        .saved_pc_o(saved_pc_o),
        .saved_fp_o(saved_fp_o),
        .saved_sp_o(saved_sp_o),
        .saved_exc_sp_o(saved_exc_sp_o)
    );

    // Pins whose GPIO_EDGE mode matches the change, one bit per pin.
    function automatic logic [15:0] gpio_edge_pins(
        input logic [31:0] edge_cfg,
        input logic [31:0] old_in,
        input logic [31:0] new_in
    );
        logic [15:0] rose;
        logic [15:0] fell;
        logic [15:0] hit;
        rose = ~old_in[15:0] & new_in[15:0];
        fell = old_in[15:0] & ~new_in[15:0];
        hit  = 16'h0;
        for (int i = 0; i < 16; i++) begin
            case (edge_cfg[2*i +: 2])
                2'd1: hit[i] = rose[i];
                2'd2: hit[i] = fell[i];
                2'd3: hit[i] = rose[i] | fell[i];
                default: hit[i] = 1'b0;
            endcase
        end
        gpio_edge_pins = hit;
    endfunction

    always_comb begin
        rdata_o = 32'h0;
        if (req_ok && !we_i) begin
            case (off)
                MPY_UART_TX:     rdata_o = {24'h0, tx_byte_r};
                MPY_UART_RX:     rdata_o = {!rx_empty, overrun_r, frame_err_r, 21'h0,
                                            rx_empty ? 8'h0 : rxq[rx_rd_r]};
                MPY_GPIO_OUT:    rdata_o = gpio_out_r;
                MPY_TIMER_COUNT: rdata_o = count_r;
                MPY_IRQ_STATUS:  rdata_o = {{(32-MPY_NSRC){1'b0}}, status_r};
                MPY_IRQ_ENABLE:  rdata_o = {{(32-MPY_NSRC){1'b0}}, enable_r};
                MPY_IRQ_HARD:    rdata_o = {{(32-MPY_NSRC){1'b0}}, hard_r};
                MPY_IRQ_GIE:     rdata_o = {31'h0, gie_r};
                MPY_IRQ_ACTIVE:  rdata_o = {31'h0, irq_active_o};
                MPY_IRQ_TABLE:   rdata_o = irq_table_r;
                MPY_SCHED_HEAD:  rdata_o = {24'h0, sched_head};
                MPY_SCHED_TAIL:  rdata_o = {24'h0, sched_tail};
                MPY_GPIO_IN:     rdata_o = gpio_in_r;
                MPY_GPIO_EDGE:   rdata_o = gpio_edge_r;
                MPY_TICKS:       rdata_o = ticks_r;
                MPY_UART_BAUD:   rdata_o = {16'h0, baud_r};
                MPY_UART_STATUS: rdata_o = {13'h0, tx_full, rx_full,
                                            tx_busy_r || !tx_empty,
                                            8'(tx_cnt_r), 8'(rx_cnt_r)};
                MPY_TIMER_PRESC: rdata_o = presc_r;
                MPY_GPIO_OE:     rdata_o = gpio_oe_r;
                MPY_GPIO_PU:     rdata_o = gpio_pu_r;
                MPY_GPIO_PD:     rdata_o = gpio_pd_r;
                MPY_GPIO_STATUS: rdata_o = {16'h0, gpio_stat_r};
                MPY_UART_KBD:    rdata_o = {23'h0, kbd_r};
                default:         rdata_o = 32'h0;
            endcase
        end
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            gpio_out_r   <= 32'h0;
            gpio_in_r    <= 32'h0;
            gpio_edge_r  <= 32'h0;
            gpio_oe_r    <= 32'h0;
            gpio_pu_r    <= 32'h0;
            gpio_pd_r    <= 32'h0;
            gpio_stat_r  <= 16'h0;
            gpio_sync1_r <= 32'h0;
            gpio_sync2_r <= 32'h0;
            compare_r    <= 32'h0;
            count_r      <= 32'h0;
            ticks_r      <= 32'h0;
            presc_r      <= 32'h0;
            presc_cnt_r  <= 32'h0;
            tx_byte_r    <= 8'h0;
            overrun_r    <= 1'b0;
            frame_err_r  <= 1'b0;
            kbd_r        <= 9'h0;
            baud_r       <= 16'h0;
            rx_rd_r      <= '0;
            rx_wr_r      <= '0;
            rx_cnt_r     <= '0;
            tx_rd_r      <= '0;
            tx_wr_r      <= '0;
            tx_cnt_r     <= '0;
            txd_r        <= 1'b1;
            tx_busy_r    <= 1'b0;
            tx_sh_r      <= 9'h1FF;
            tx_bit_r     <= 4'h0;
            tx_clk_r     <= 16'h0;
            rxd_s1_r     <= 1'b1;
            rxd_s2_r     <= 1'b1;
            rxd_d_r      <= 1'b1;
            rx_busy_r    <= 1'b0;
            rx_bit_r     <= 4'h0;
            rx_clk_r     <= 16'h0;
            rx_sh_r      <= 8'h0;
            status_r     <= '0;
            enable_r     <= '0;
            hard_r       <= '0;
            gie_r        <= 1'b1;
            irq_table_r  <= 32'h0;
        end else begin
            if (wr_gout)
                gpio_out_r <= wdata_i;
            if (gin_write)
                gpio_in_r <= gin_new;
            gpio_sync1_r <= gpio_in_i;
            gpio_sync2_r <= gpio_sync1_r;
            if (wr_gedge)
                gpio_edge_r <= wdata_i;
            if (wr_oe)
                gpio_oe_r <= wdata_i;
            if (wr_pu)
                gpio_pu_r <= wdata_i;
            if (wr_pd)
                gpio_pd_r <= wdata_i;
            gpio_stat_r <= (gpio_stat_r & ~(wr_gstat ? wdata_i[15:0] : 16'h0)) | gpio_pins;
            if (wr_tc)
                compare_r <= wdata_i;
            if (wr_en)
                enable_r <= wdata_i[MPY_NSRC-1:0];
            if (wr_hard)
                hard_r <= wdata_i[MPY_NSRC-1:0];
            if (wr_gie)
                gie_r <= wdata_i[0];
            if (wr_table)
                irq_table_r <= wdata_i;
            if (wr_kbd)
                kbd_r <= wdata_i[8:0];
            if (wr_baud)
                baud_r <= wdata_i[15:0];

            // The prescaler restarts its count when it is written.
            if (wr_presc) begin
                presc_r     <= wdata_i;
                presc_cnt_r <= 32'h0;
            end else if (presc_tick)
                presc_cnt_r <= 32'h0;
            else if (presc_r != 32'h0)
                presc_cnt_r <= presc_cnt_r + 32'd1;

            if (tick)
                ticks_r <= ticks_r + 32'd1;
            if (timer_match)
                count_r <= 32'h0;
            else if (tick && (compare_r != 32'h0))
                count_r <= count_inc[31:0];

            if (wr_tx)
                tx_byte_r <= wdata_i[7:0];

            // RX FIFO. A byte that arrives while it is full is dropped,
            // even when the same cycle pops, so the v1 depth-1 rule holds.
            if (uart_take) begin
                rxq[rx_wr_r] <= rx_in_byte;
                rx_wr_r <= fnext(rx_wr_r);
            end
            if (rx_pop)
                rx_rd_r <= fnext(rx_rd_r);
            if (uart_take && !rx_pop)
                rx_cnt_r <= rx_cnt_r + 1'b1;
            else if (rx_pop && !uart_take)
                rx_cnt_r <= rx_cnt_r - 1'b1;

            if (wr_rx && wdata_i[30])
                overrun_r <= 1'b0;
            if (uart_drop)
                overrun_r <= 1'b1;
            if (wr_rx && wdata_i[29])
                frame_err_r <= 1'b0;
            if (ser_ferr)
                frame_err_r <= 1'b1;

            // TX FIFO and serializer.
            if (tx_push) begin
                txq[tx_wr_r] <= wdata_i[7:0];
                tx_wr_r <= fnext(tx_wr_r);
            end
            if (tx_pop)
                tx_rd_r <= fnext(tx_rd_r);
            if (tx_push && !tx_pop)
                tx_cnt_r <= tx_cnt_r + 1'b1;
            else if (tx_pop && !tx_push)
                tx_cnt_r <= tx_cnt_r - 1'b1;

            if (tx_pop) begin
                tx_busy_r <= 1'b1;
                txd_r     <= 1'b0;
                tx_sh_r   <= {1'b1, txq[tx_rd_r]};
                tx_bit_r  <= 4'd0;
                tx_clk_r  <= baud - 16'd1;
            end else if (tx_busy_r) begin
                if (tx_clk_r != 16'h0)
                    tx_clk_r <= tx_clk_r - 16'd1;
                else if (tx_bit_r == 4'd9) begin
                    tx_busy_r <= 1'b0;
                    txd_r     <= 1'b1;
                end else begin
                    txd_r    <= tx_sh_r[0];
                    tx_sh_r  <= {1'b1, tx_sh_r[8:1]};
                    tx_bit_r <= tx_bit_r + 4'd1;
                    tx_clk_r <= baud - 16'd1;
                end
            end
            if (byte_mode) begin
                tx_busy_r <= 1'b0;
                txd_r     <= 1'b1;
            end

            // Receiver: start edge, mid-bit check, eight data bits, stop.
            rxd_s1_r <= uart_rxd_i;
            rxd_s2_r <= rxd_s1_r;
            rxd_d_r  <= rxd_s2_r;
            if (byte_mode) begin
                rx_busy_r <= 1'b0;
            end else if (!rx_busy_r) begin
                if (rxd_d_r && !rxd_s2_r) begin
                    rx_busy_r <= 1'b1;
                    rx_bit_r  <= 4'd0;
                    rx_clk_r  <= (baud >> 1) - 16'd1;
                end
            end else if (rx_clk_r != 16'h0) begin
                rx_clk_r <= rx_clk_r - 16'd1;
            end else begin
                rx_clk_r <= baud - 16'd1;
                if (rx_bit_r == 4'd0) begin
                    if (rxd_s2_r)
                        rx_busy_r <= 1'b0;
                    else
                        rx_bit_r <= 4'd1;
                end else if (rx_bit_r == 4'd9) begin
                    rx_busy_r <= 1'b0;
                end else begin
                    rx_sh_r  <= {rxd_s2_r, rx_sh_r[7:1]};
                    rx_bit_r <= rx_bit_r + 4'd1;
                end
            end

            status_r <= status_n;
        end
    end
endmodule
