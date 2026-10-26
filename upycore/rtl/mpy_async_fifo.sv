// Dual-clock FIFO, 2**AW words of W bits. Spec: upycore/docs/mpy_coproc.md
// (Clocks and resets).
//
// Binary pointers count one past the depth, so full and empty differ; each
// side sends its pointer to the other in gray code through two flops. A
// side's level is its own pointer against the synchronized copy of the
// other's, so it lags the far side by up to three of its clocks: the write
// side never reads fewer words queued than there are (full stays safe), and
// the read side never reads more (empty stays safe). r_data shows the head
// word while not empty; r_en pops it; r_new is high for one read clock each
// time words arrive. Each side has its own reset.
module mpy_async_fifo #(
    parameter int W = 32,
    parameter int AW = 4
) (
    input  logic          wclk,
    input  logic          wrst_n,
    input  logic          w_en,
    input  logic [W-1:0]  w_data,
    output logic          w_full,
    output logic [AW:0]   w_level,

    input  logic          rclk,
    input  logic          rrst_n,
    input  logic          r_en,
    output logic [W-1:0]  r_data,
    output logic          r_empty,
    output logic [AW:0]   r_level,
    output logic          r_new     // the synchronized write pointer moved
);
    localparam int DEPTH = 1 << AW;

    logic [W-1:0] mem [0:DEPTH-1];
    logic [AW:0]  wbin, wgray, rbin, rgray;
    logic [AW:0]  rgray_w1, rgray_w2, wgray_r1, wgray_r2, wgray_r3;

    function automatic logic [AW:0] bin2gray(input logic [AW:0] b);
        return b ^ (b >> 1);
    endfunction

    function automatic logic [AW:0] gray2bin(input logic [AW:0] g);
        logic [AW:0] b;
        b[AW] = g[AW];
        for (int i = AW - 1; i >= 0; i--) b[i] = b[i + 1] ^ g[i];
        return b;
    endfunction

    // ---- write side ----
    assign w_level = wbin - gray2bin(rgray_w2);
    assign w_full  = (32'(w_level) == DEPTH);

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin <= '0; wgray <= '0; rgray_w1 <= '0; rgray_w2 <= '0;
        end else begin
            rgray_w1 <= rgray;
            rgray_w2 <= rgray_w1;
            if (w_en && !w_full) begin
                wbin  <= wbin + 1'b1;
                wgray <= bin2gray(wbin + 1'b1);
            end
        end
    end

    always_ff @(posedge wclk)
        if (w_en && !w_full) mem[wbin[AW-1:0]] <= w_data;

    // ---- read side ----
    assign r_level = gray2bin(wgray_r2) - rbin;
    assign r_empty = (r_level == '0);
    assign r_data  = mem[rbin[AW-1:0]];
    assign r_new   = (wgray_r2 != wgray_r3);

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin <= '0; rgray <= '0; wgray_r1 <= '0; wgray_r2 <= '0; wgray_r3 <= '0;
        end else begin
            wgray_r1 <= wgray;
            wgray_r2 <= wgray_r1;
            wgray_r3 <= wgray_r2;
            if (r_en && !r_empty) begin
                rbin  <= rbin + 1'b1;
                rgray <= bin2gray(rbin + 1'b1);
            end
        end
    end
endmodule
