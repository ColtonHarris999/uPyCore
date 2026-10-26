// SPI controller exit: loopback in modes 0-3 at two dividers, the FIFOs
// and overrun, and a modeled SPI flash (JEDEC id, read, program) in modes
// 0 and 3. The flash model is tb_spi_flash.sv.
module tb_mpy_spi;
    logic        clk = 1'b0;
    logic        rst_n = 1'b0;
    logic        req = 1'b0, we = 1'b0;
    logic [11:0] off = 12'h0;
    logic [31:0] wdata = 32'h0;
    logic [31:0] rdata;
    logic        sck, mosi, miso, irq;
    logic        loop = 1'b1;
    logic        cs_n = 1'b1;
    logic        flash_miso;

    assign miso = loop ? mosi : flash_miso;

    mpy_spi dut (
        .clk_i(clk), .rst_n_i(rst_n), .req_i(req), .we_i(we), .off_i(off), .wdata_i(wdata),
        .rdata_o(rdata), .sck_o(sck), .mosi_o(mosi), .miso_i(miso), .irq_o(irq)
    );

    tb_spi_flash flash (.cs_n(cs_n), .sck(sck), .mosi(mosi), .miso(flash_miso));

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

    task automatic cs_hi();
        cs_n = 1'b1;
        repeat (2) @(posedge clk);
    endtask

    task automatic wait_idle();
        logic [31:0] st;
        do rd(12'h308, st); while (st[16]);
    endtask

    // Send n bytes, then return what came back.
    task automatic xfer(input logic [7:0] tx [], output logic [7:0] rx []);
        logic [31:0] v;
        rx = new[tx.size()];
        foreach (tx[k]) wr(12'h304, 32'(tx[k]));
        wait_idle();
        foreach (rx[k]) begin
            rd(12'h304, v);
            check(v[31], "RX byte valid");
            rx[k] = v[7:0];
        end
    endtask

    initial begin
        logic [7:0] tx [];
        logic [7:0] rx [];
        logic [31:0] v;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        // Loopback: every mode and two dividers return what was sent.
        tx = '{8'hA5, 8'h3C, 8'h00, 8'hFF, 8'h81};
        for (int mode = 0; mode < 4; mode++) begin
            for (int div = 0; div < 4; div += 3) begin
                wr(12'h300, 32'(div << 8) | 32'(mode[1] << 1) | 32'(mode[0] << 2) | 32'h1);
                @(negedge clk);
                check(sck == mode[1], "SCK idles at CPOL");
                xfer(tx, rx);
                foreach (tx[k]) check(rx[k] == tx[k], $sformatf("loopback mode %0d div %0d", mode, div));
            end
        end
        $display("LOOPBACK modes 0-3, dividers 0 and 3");

        // Nine bytes with the RX FIFO undrained: the ninth overruns.
        wr(12'h300, 32'h1);
        for (int k = 0; k < 9; k++) begin
            wr(12'h304, 32'(k));
            wait_idle();
        end
        rd(12'h308, v);
        check(v[19] && v[12:8] == 5'd8, "the ninth byte overruns a full RX FIFO");
        wr(12'h308, 32'h1 << 19);
        rd(12'h308, v);
        check(!v[19], "write 1 to bit 19 clears overrun");
        for (int k = 0; k < 8; k++) begin
            rd(12'h304, v);
            check(v[31] && v[7:0] == 8'(k), "the first eight stay");
        end
        wr(12'h30C, 32'h2);
        check(!irq, "RX-ready IRQ low when empty");
        wr(12'h304, 32'h55);
        wait_idle();
        check(irq, "RX-ready IRQ");
        rd(12'h304, v);
        wr(12'h30C, 32'h0);

        // The flash, mode 0 then mode 3.
        loop = 1'b0;
        for (int mode = 0; mode < 4; mode += 3) begin
            wr(12'h300, 32'(1 << 8) | 32'(mode[1] << 1) | 32'(mode[0] << 2) | 32'h1);
            cs_n = 1'b0;
            tx = '{8'h9F, 8'h00, 8'h00, 8'h00};
            xfer(tx, rx);
            cs_hi();
            check(rx[1] == 8'hEF && rx[2] == 8'h40 && rx[3] == 8'h18, $sformatf("JEDEC id mode %0d", mode));
            cs_n = 1'b0;
            tx = '{8'h03, 8'h00, 8'h01, 8'h00, 8'h00, 8'h00, 8'h00};
            xfer(tx, rx);
            cs_hi();
            for (int k = 0; k < 3; k++)
                check(rx[4 + k] == 8'((7 * (256 + k) + 3) & 8'hFF), $sformatf("read mode %0d byte %0d", mode, k));
        end
        // Program two bytes at 0x10, read them back.
        wr(12'h300, 32'h1);
        cs_n = 1'b0; tx = '{8'h06}; xfer(tx, rx); cs_hi();
        cs_n = 1'b0; tx = '{8'h05, 8'h00}; xfer(tx, rx); cs_hi();
        check(rx[1][1], "WEL after write enable");
        cs_n = 1'b0; tx = '{8'h02, 8'h00, 8'h00, 8'h10, 8'hDE, 8'hAD}; xfer(tx, rx); cs_hi();
        cs_n = 1'b0; tx = '{8'h03, 8'h00, 8'h00, 8'h10, 8'h00, 8'h00}; xfer(tx, rx); cs_hi();
        check(rx[4] == 8'hDE && rx[5] == 8'hAD, "programmed bytes read back");
        $display("FLASH jedec=ef4018 read and program, modes 0 and 3");
        $display("PASS: mpy spi loopback/fifo/overrun/flash");
        $finish;
    end
endmodule
