// ADC interface exit: conversions of three channels against
// mpy_periph_model.adc_read_u16, the latency, busy and valid, and a start
// while busy that is ignored. The converter is tb_adc_model.sv.
module tb_mpy_adc;
    logic        clk = 1'b0;
    logic        rst_n = 1'b0;
    logic        req = 1'b0, we = 1'b0;
    logic [11:0] off = 12'h0;
    logic [31:0] wdata = 32'h0;
    logic [31:0] rdata;
    logic        start, done;
    logic [3:0]  chan;
    logic [11:0] code;

    mpy_adc dut (
        .clk_i(clk), .rst_n_i(rst_n), .req_i(req), .we_i(we), .off_i(off), .wdata_i(wdata),
        .rdata_o(rdata), .adc_start_o(start), .adc_chan_o(chan), .adc_done_i(done), .adc_code_i(code)
    );
    tb_adc_model conv (.clk(clk), .start(start), .chan(chan), .done(done), .code(code));

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
        #1 d = rdata;
        @(negedge clk);
        req = 1'b0;
    endtask

    // Start channel ch; return the data word and the clocks spent busy.
    task automatic convert(input int ch, output logic [31:0] d, output int clocks);
        logic [31:0] st;
        wr(12'h800, 32'h100 | 32'(ch));
        clocks = 0;
        do begin rd(12'h808, st); clocks += 2; end while (st[0]);
        rd(12'h804, d);
    endtask

    initial begin
        logic [31:0] d, st;
        int clocks, latency, want;
        if (!$value$plusargs("ADC_LATENCY=%d", latency)) latency = 48;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        rd(12'h804, d); check(!d[31], "no data before a conversion");
        for (int i = 0; i < 3; i++) begin
            int ch;
            ch = (i == 0) ? 0 : (i == 1) ? 5 : 15;
            if (!$value$plusargs($sformatf("ADC_U16_%0d=%%d", ch), want)) want = -1;
            convert(ch, d, clocks);
            check(d[31] && d[15:0] == 16'(want), $sformatf("channel %0d reads %0d, model %0d", ch, d[15:0], want));
            check(clocks >= latency && clocks <= latency + 6, $sformatf("busy %0d clocks", clocks));
            rd(12'h800, st); check(st[3:0] == 4'(ch), "ADC_CTRL reads the channel");
        end
        // A start while busy is ignored: channel 5's result, not 9's.
        wr(12'h800, 32'h105);
        wr(12'h800, 32'h109);
        rd(12'h804, d); check(!d[31], "a start clears valid");
        do rd(12'h808, st); while (st[0]);
        rd(12'h804, d);
        check(d[31] && d[15:0] == 16'(((273 * 5 + 100) & 12'hFFF) << 4), "start while busy ignored");
        $display("ADC channels 0 5 15, latency %0d", latency);
        $display("PASS: mpy adc");
        $finish;
    end
endmodule
