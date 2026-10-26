// I2C controller exit: scan, EEPROM write and read with a repeated start,
// a target that stretches SCL, the stretch timeout, and NACK on a missing
// address. The targets are tb_i2c_target.sv.
module tb_mpy_i2c;
    logic        clk = 1'b0;
    logic        rst_n = 1'b0;
    logic        req = 1'b0, we = 1'b0;
    logic [11:0] off = 12'h0;
    logic [31:0] wdata = 32'h0;
    logic [31:0] rdata;
    logic        c_scl_low, c_sda_low, irq;
    logic        e_scl_low, e_sda_low, s_scl_low, s_sda_low;
    logic        scl, sda;

    assign scl = !(c_scl_low || e_scl_low || s_scl_low);
    assign sda = !(c_sda_low || e_sda_low || s_sda_low);

    mpy_i2c dut (
        .clk_i(clk), .rst_n_i(rst_n), .req_i(req), .we_i(we), .off_i(off), .wdata_i(wdata),
        .rdata_o(rdata), .scl_low_o(c_scl_low), .sda_low_o(c_sda_low), .scl_i(scl), .sda_i(sda),
        .irq_o(irq)
    );
    tb_i2c_target #(.ADDR(7'h50)) eeprom (.clk(clk), .scl(scl), .sda(sda),
                                         .scl_low(e_scl_low), .sda_low(e_sda_low));
    tb_i2c_target #(.ADDR(7'h42), .BYTES(16), .STRETCH(200), .INIT(8'hA0)) slow (
        .clk(clk), .scl(scl), .sda(sda), .scl_low(s_scl_low), .sda_low(s_sda_low));

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

    // Run one command and return the status when it is done.
    task automatic cmd(input logic [31:0] c, output logic [31:0] st);
        wr(12'h404, c);
        do rd(12'h408, st); while (st[0]);
    endtask

    task automatic start();  logic [31:0] st; cmd(32'h1, st); endtask
    task automatic stop();   logic [31:0] st; cmd(32'h2, st); endtask
    task automatic wbyte(input logic [7:0] b, output bit nack);
        logic [31:0] st;
        cmd({16'h0, b, 8'h3}, st);
        nack = st[1];
    endtask
    task automatic rbyte(input bit nack, output logic [7:0] b);
        logic [31:0] st;
        cmd({15'h0, nack, 8'h0, 8'h4}, st);
        b = st[15:8];
    endtask

    initial begin
        logic [31:0] st;
        logic [7:0]  b;
        bit          nack;
        int          found;
        longint      t0, t1;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        wr(12'h410, 32'h1);
        wr(12'h400, 32'd3);

        // Scan: only 0x42 and 0x50 answer.
        found = 0;
        for (int a = 8; a < 120; a++) begin
            start();
            wbyte(8'(a << 1), nack);
            stop();
            if (!nack) begin
                check(a == 8'h42 || a == 8'h50, $sformatf("unexpected ACK from 0x%02x", a));
                found++;
            end
        end
        check(found == 2, "scan finds two targets");
        $display("SCAN 0x42 0x50");

        // EEPROM: write two bytes at 0x10, read them back after a repeated start.
        start(); wbyte(8'hA0, nack); check(!nack, "address ACK");
        wbyte(8'h10, nack); wbyte(8'h11, nack); wbyte(8'h22, nack); check(!nack, "data ACK");
        stop();
        start(); wbyte(8'hA0, nack); wbyte(8'h10, nack);
        start();
        rd(12'h408, st);
        check(st[3], "bus held across the repeated start");
        wbyte(8'hA1, nack); check(!nack, "read address ACK");
        rbyte(1'b0, b); check(b == 8'h11, "first byte");
        rbyte(1'b0, b); check(b == 8'h22, "second byte");
        rbyte(1'b1, b); check(b == 8'h12, "third byte is the initial contents");
        stop();
        rd(12'h408, st);
        check(!st[3], "STOP releases the bus");
        $display("EEPROM write/read with repeated start");

        // Stretching target: a read takes longer and still completes.
        t0 = $time;
        start(); wbyte(8'h84, nack); check(!nack, "stretching target ACK");
        wbyte(8'h03, nack);
        start(); wbyte(8'h85, nack); rbyte(1'b1, b); stop();
        t1 = $time;
        check(b == (8'h03 ^ 8'hA0), "stretched read");
        rd(12'h408, st);
        check(!st[2], "no timeout with the default limit");
        $display("STRETCH read=0x%02x in %0d ns", b, t1 - t0);

        // A limit below the stretch times out and releases the bus. The
        // target stretches after the address ACK, so the next byte waits.
        wr(12'h40C, 32'd100);
        start(); wbyte(8'h84, nack);
        wbyte(8'h03, nack);
        rd(12'h408, st);
        check(st[2] && !st[3], "stretch timeout");
        repeat (400) @(posedge clk);
        check(scl && sda, "lines released after the timeout");
        wr(12'h40C, 32'h0010_0000);
        start(); stop();

        // Missing address: NACK.
        start(); wbyte(8'h66, nack); stop();
        check(nack, "NACK from 0x33");
        $display("TIMEOUT and NACK");
        $display("PASS: mpy i2c scan/eeprom/stretch/timeout/nack");
        $finish;
    end
endmodule
