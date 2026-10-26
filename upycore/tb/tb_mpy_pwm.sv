// PWM and pin-mux exit: duty and period measured on the outputs, duty
// shadowing at the wrap, and the pad functions. Expected clocks come from
// `upycore/tools/mpy_periph_model.py --pwm-plusargs`.
module tb_mpy_pwm;
    logic        clk = 1'b0;
    logic        rst_n = 1'b0;
    logic        req = 1'b0, we = 1'b0;
    logic [11:0] off = 12'h0;
    logic [31:0] wdata = 32'h0;
    logic [31:0] rd_pwm, rd_mux;
    logic [3:0]  pwm;
    logic        wrap;
    logic [15:0] pad_out, pad_oe;
    logic [15:0] pad_in = 16'h0;
    logic        miso, scl, sda, rxd;

    int presc, top, period;
    int duty [0:3];
    int high [0:3];

    mpy_pwm dut (
        .clk_i(clk), .rst_n_i(rst_n), .req_i(req), .we_i(we), .off_i(off), .wdata_i(wdata),
        .rdata_o(rd_pwm), .pwm_o(pwm), .wrap_o(wrap)
    );

    mpy_pinmux mux (
        .clk_i(clk), .rst_n_i(rst_n), .req_i(req), .we_i(we), .off_i(off), .wdata_i(wdata),
        .rdata_o(rd_mux),
        .gpio_out_i(16'hA5A5), .gpio_oe_i(16'h00FF), .pwm_i(pwm),
        .spi_sck_i(1'b1), .spi_mosi_i(1'b0), .i2c_scl_low_i(1'b1), .i2c_sda_low_i(1'b0),
        .uart_txd_i(1'b1), .uart_rxd_pin_i(1'b0),
        .spi_miso_o(miso), .i2c_scl_o(scl), .i2c_sda_o(sda), .uart_rxd_o(rxd),
        .pad_out_o(pad_out), .pad_oe_o(pad_oe), .pad_in_i(pad_in)
    );

    always #5 clk = ~clk;

    task automatic check(input bit cond, input string msg);
        if (!cond) begin
            $error("FAIL: %s", msg);
            $fatal(1);
        end
    endtask

    task automatic wr(input logic [11:0] o, input logic [31:0] d);
        @(negedge clk);
        req = 1'b1; we = 1'b1; off = o; wdata = d;
        @(negedge clk);
        req = 1'b0; we = 1'b0;
    endtask

    task automatic rd(input logic [11:0] o, output logic [31:0] d);
        @(negedge clk);
        req = 1'b1; we = 1'b0; off = o;
        #1 d = rd_pwm | rd_mux;
        @(negedge clk);
        req = 1'b0;
    endtask

    // Clocks each channel is high over one period, starting at a wrap.
    task automatic measure(output int h [0:3], output int p);
        // Sample each cycle 1 ns after its opening edge: the cycle after
        // a wrap is count 0, and the next wrap cycle closes the period.
        @(posedge clk iff wrap);
        for (int k = 0; k < 4; k++) h[k] = 0;
        p = 0;
        forever begin
            #1;
            for (int k = 0; k < 4; k++) if (pwm[k]) h[k]++;
            p++;
            if (wrap) break;
            @(posedge clk);
        end
        @(posedge clk);
    endtask

    initial begin
        int h [0:3];
        int p;
        logic [31:0] v;
        if (!$value$plusargs("PRESC=%d", presc)) $fatal(1, "missing PRESC");
        if (!$value$plusargs("TOP=%d", top)) $fatal(1, "missing TOP");
        if (!$value$plusargs("PERIOD=%d", period)) $fatal(1, "missing PERIOD");
        if (!$value$plusargs("DUTY0=%d", duty[0])) $fatal(1, "missing DUTY0");
        if (!$value$plusargs("DUTY1=%d", duty[1])) $fatal(1, "missing DUTY1");
        if (!$value$plusargs("DUTY2=%d", duty[2])) $fatal(1, "missing DUTY2");
        if (!$value$plusargs("DUTY3=%d", duty[3])) $fatal(1, "missing DUTY3");
        if (!$value$plusargs("HIGH0=%d", high[0])) $fatal(1, "missing HIGH0");
        if (!$value$plusargs("HIGH1=%d", high[1])) $fatal(1, "missing HIGH1");
        if (!$value$plusargs("HIGH2=%d", high[2])) $fatal(1, "missing HIGH2");
        if (!$value$plusargs("HIGH3=%d", high[3])) $fatal(1, "missing HIGH3");
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        check(pwm == 4'h0, "outputs low with no channel on");
        wr(12'h200, 32'(presc));
        wr(12'h204, 32'(top));
        for (int k = 0; k < 4; k++) wr(12'h210 + 12'(4 * k), 32'(duty[k]));
        wr(12'h208, 32'hF);
        measure(h, p);
        check(p == period, "period clocks");
        for (int k = 0; k < 4; k++) check(h[k] == high[k], $sformatf("channel %0d high clocks", k));
        $display("PWM period=%0d high=%0d,%0d,%0d,%0d", p, h[0], h[1], h[2], h[3]);

        // A duty write lands at the next wrap, never mid-period.
        @(posedge clk iff wrap);
        repeat (3) @(posedge clk);
        wr(12'h210, 32'(top + 1));
        @(posedge clk iff wrap);
        measure(h, p);
        check(h[0] == period, "new duty after the wrap");
        rd(12'h210, v);
        check(v == 32'(top + 1), "duty readback");

        // Off at a wrap; the counter stops when none is on.
        wr(12'h208, 32'h0);
        @(posedge clk iff wrap);
        repeat (2 * period) @(posedge clk);
        check(pwm == 4'h0, "all channels off");
        rd(12'h20C, v);
        check(v == 32'h0, "counter stopped");

        // Pin mux: pad 0 PWM0 (always high now), pad 1 GPIO, pad 2 SCK,
        // pad 3 SCL (open drain, driven low), pad 4 SDA (released),
        // pad 5 MISO, pad 6 UART RX, pad 9 UART TX.
        wr(12'h210, 32'(top + 1));
        wr(12'h208, 32'h1);
        wr(12'h900, 32'h0B79_8501);
        wr(12'h904, 32'h0000_00A0);
        rd(12'h900, v);
        check(v == 32'h0B79_8501, "PINMUX0 round trip");
        @(posedge clk iff wrap);
        @(posedge clk);
        #1;
        check(pad_oe[0] && pad_out[0], "PWM on pad 0");
        check(pad_out[1] == 1'b0 && pad_oe[1], "GPIO bit on pad 1");
        check(pad_out[2] && pad_oe[2], "SCK on pad 2");
        check(pad_oe[3] && !pad_out[3], "SCL driven low");
        check(!pad_oe[4] && !pad_out[4], "SDA released");
        check(!pad_oe[5] && !pad_oe[6], "MISO and RX are inputs");
        check(pad_out[9] && pad_oe[9], "UART TX on pad 9");
        check(pad_out[15] == 1'b1 && pad_oe[15] == 1'b0, "pad 15 is GPIO");
        pad_in = 16'h0038;
        #1;
        check(miso && scl && sda && !rxd, "inputs from pads 5, 3, 4, 6");
        pad_in = 16'h0040;
        #1;
        check(!miso && rxd && !scl && !sda, "inputs follow the pads");
        $display("PINMUX pads ok");
        $display("PASS: mpy pwm duty/period/shadow and pin mux");
        $finish;
    end
endmodule
