// Four PWM channels on one shared counter, at MMIO offset 0x200.
// Spec: upycore/docs/mpy_peripherals.md (PWM)
//
// The counter advances every PWM_PRESC + 1 clocks while any channel is
// enabled and wraps after PWM_TOP. A channel is high while the count is
// below its duty. Top, duty, and enable are shadowed and load at the wrap,
// so a period is never cut short; the first channel to turn on restarts
// the counter. Offsets outside 0x200..0x2FF read 0.
module mpy_pwm (
    input  logic        clk_i,
    input  logic        rst_n_i,

    input  logic        req_i,
    input  logic        we_i,
    input  logic [11:0] off_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    output logic [3:0]  pwm_o,
    output logic        wrap_o
);
    localparam logic [11:0] PWM_PRESC = 12'h200;
    localparam logic [11:0] PWM_TOP   = 12'h204;
    localparam logic [11:0] PWM_EN    = 12'h208;
    localparam logic [11:0] PWM_COUNT = 12'h20C;
    localparam logic [11:0] PWM_DUTY0 = 12'h210;

    logic [15:0] presc_r, top_r, top_s;
    logic [3:0]  en_r, en_s;
    logic [16:0] duty_r [0:3];
    logic [16:0] duty_s [0:3];
    logic [15:0] pre_r, cnt_r;
    logic        running_r;
    logic        step, wrap;
    logic        wr;

    assign wr = req_i && we_i;
    assign step = running_r && (pre_r == presc_r);
    assign wrap = step && (cnt_r == top_s);
    assign wrap_o = wrap;

    always_comb begin
        for (int k = 0; k < 4; k++)
            pwm_o[k] = running_r && en_s[k] && ({1'b0, cnt_r} < duty_s[k]);
    end

    always_comb begin
        rdata_o = 32'h0;
        if (req_i && !we_i) begin
            case (off_i)
                PWM_PRESC: rdata_o = {16'h0, presc_r};
                PWM_TOP:   rdata_o = {16'h0, top_r};
                PWM_EN:    rdata_o = {28'h0, en_r};
                PWM_COUNT: rdata_o = {16'h0, cnt_r};
                12'h210:   rdata_o = {15'h0, duty_r[0]};
                12'h214:   rdata_o = {15'h0, duty_r[1]};
                12'h218:   rdata_o = {15'h0, duty_r[2]};
                12'h21C:   rdata_o = {15'h0, duty_r[3]};
                default:   rdata_o = 32'h0;
            endcase
        end
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            presc_r   <= 16'h0;
            top_r     <= 16'hFFFF;
            top_s     <= 16'hFFFF;
            en_r      <= 4'h0;
            en_s      <= 4'h0;
            pre_r     <= 16'h0;
            cnt_r     <= 16'h0;
            running_r <= 1'b0;
            for (int k = 0; k < 4; k++) begin
                duty_r[k] <= 17'h0;
                duty_s[k] <= 17'h0;
            end
        end else begin
            if (wr && off_i == PWM_PRESC) presc_r <= wdata_i[15:0];
            if (wr && off_i == PWM_TOP)   top_r <= wdata_i[15:0];
            if (wr && off_i == PWM_EN)    en_r <= wdata_i[3:0];
            for (int k = 0; k < 4; k++)
                if (wr && off_i == PWM_DUTY0 + 12'(4 * k)) duty_r[k] <= wdata_i[16:0];

            if (!running_r) begin
                // Idle until a channel is on, then start a fresh period.
                if (en_r != 4'h0) begin
                    running_r <= 1'b1;
                    pre_r <= 16'h0;
                    cnt_r <= 16'h0;
                    top_s <= top_r;
                    en_s <= en_r;
                    for (int k = 0; k < 4; k++) duty_s[k] <= duty_r[k];
                end
            end else if (step) begin
                pre_r <= 16'h0;
                if (wrap) begin
                    cnt_r <= 16'h0;
                    top_s <= top_r;
                    en_s <= en_r;
                    for (int k = 0; k < 4; k++) duty_s[k] <= duty_r[k];
                    if (en_r == 4'h0) running_r <= 1'b0;
                end else
                    cnt_r <= cnt_r + 16'd1;
            end else
                pre_r <= pre_r + 16'd1;
        end
    end
endmodule
