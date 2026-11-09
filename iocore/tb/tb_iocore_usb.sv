// iocore_usb's clock-domain crossing: random accesses from io_clk to the
// SIE on usb_clk at twelve clock ratios (1:3 to 3:1, six of them random),
// each with a random phase. Writes and reads of the SIE's endpoint status
// table (Wishbone 0x800-0x8FF, a 256 x 16 RAM) are checked against a model;
// RX buffer reads and TX buffer writes must complete; requests come back
// to back and after random gaps. No host is on the bus (the pads are pulled
// low), so the SIE's own state does not change the table.
`timescale 1ns/1ps
module tb_iocore_usb;
    real io_ns, usb_ns;
    logic io_clk = 1'b0, usb_clk = 1'b0;
    logic rst_n = 1'b0;
    bit   run_clk = 1'b0;

    logic        req = 1'b0, we = 1'b0;
    logic [1:0]  kind = 2'd0;
    logic [11:0] addr = 12'h0;
    logic [31:0] wdata = 32'h0;
    logic        busy, done, irq;
    logic [31:0] rdata;
    wire         dp, dn;
    logic        pu;
    assign (weak0, weak1) dp = 1'b0;
    assign (weak0, weak1) dn = 1'b0;

    iocore_usb dut (
        .io_clk_i(io_clk), .rst_n_i(rst_n), .req_i(req), .kind_i(kind), .we_i(we), .addr_i(addr),
        .wdata_i(wdata), .busy_o(busy), .done_o(done), .rdata_o(rdata), .irq_o(irq),
        .usb_clk_i(usb_clk), .usb_dp_io(dp), .usb_dn_io(dn), .usb_pu_o(pu)
    );

    always begin
        if (run_clk) begin #(io_ns / 2.0) io_clk = ~io_clk; end
        else #1;
    end
    always begin
        if (run_clk) begin #(usb_ns / 2.0) usb_clk = ~usb_clk; end
        else #1;
    end

    int checks = 0;
    logic [15:0] model [0:255];

    task automatic check(input bit cond, input string msg);
        checks++;
        if (!cond) begin
            $error("FAIL: %s (io %0.3f ns, usb %0.3f ns)", msg, io_ns, usb_ns);
            $fatal(1);
        end
    endtask

    // One access: request on an io_clk edge, wait for done.
    task automatic access(input logic [1:0] k, input bit w, input logic [11:0] a,
                          input logic [31:0] d, output logic [31:0] q);
        int guard;
        @(negedge io_clk);
        req = 1'b1; kind = k; we = w; addr = a; wdata = d;
        @(negedge io_clk);
        req = 1'b0;
        check(busy, "busy the clock after the request");
        guard = 0;
        while (!done && guard < 2000) begin @(posedge io_clk); #0.01; guard++; end
        check(done, "the access completes");
        q = rdata;
        @(negedge io_clk);
        check(!busy, "not busy after done");
    endtask

    initial begin
        logic [31:0] q;
        int seed;
        if (!$value$plusargs("SEED=%d", seed)) seed = 1;
        void'($urandom(seed));
        for (int trial = 0; trial < 12; trial++) begin
            real ratio;
            case (trial)
                0: ratio = 1.0 / 3.0; 1: ratio = 0.5; 2: ratio = 1.0; 3: ratio = 1.5;
                4: ratio = 2.0; 5: ratio = 3.0;
                default: ratio = 0.34 + ($urandom % 2660) / 1000.0;
            endcase
            usb_ns = 20.833;
            io_ns = usb_ns * ratio;
            run_clk = 1'b0;
            rst_n = 1'b0;
            #((($urandom % 1000) / 1000.0) * usb_ns);
            run_clk = 1'b1;
            repeat (4) @(posedge io_clk);
            repeat (4) @(posedge usb_clk);
            rst_n = 1'b1;
            repeat (8) @(posedge usb_clk);
            repeat (4) @(posedge io_clk);
            // Fill the table, then random traffic.
            for (int i = 0; i < 256; i++) begin
                model[i] = 16'($urandom);
                access(2'd0, 1'b1, 12'h800 | 12'(i), {16'h0, model[i]}, q);
            end
            for (int n = 0; n < 600; n++) begin
                int r = $urandom % 10;
                logic [7:0] a = 8'($urandom);
                if (r < 4) begin
                    model[a] = 16'($urandom);
                    access(2'd0, 1'b1, 12'h800 | 12'(a), {16'($urandom), model[a]}, q);
                end else if (r < 8) begin
                    access(2'd0, 1'b0, 12'h800 | 12'(a), 32'h0, q);
                    check(q == {16'h0, model[a]}, $sformatf("status word %0d", a));
                end else if (r == 8) begin
                    access(2'd1, 1'b0, 12'($urandom % 512), 32'h0, q);
                end else begin
                    access(2'd2, 1'b1, 12'($urandom % 512), $urandom, q);
                end
                if ($urandom % 4 == 0) repeat ($urandom % 5) @(posedge io_clk);
            end
        end
        $display("PASS tb_iocore_usb %0d checks, 12 ratios", checks);
        $finish;
    end
endmodule
