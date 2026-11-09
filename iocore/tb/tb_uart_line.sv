// UART line model: an 8N1 terminal on the far end of a TX/RX pair.
// Spec: upycore/docs/mpy_io_core.md (Benches).
//
// The receiver decodes `line_i` (the chip's TX) at BIT_NS per bit: it waits
// for the start bit's falling edge, checks it again half a bit later, and
// samples eight data bits and the stop bit at bit intervals. Each byte
// toggles `rx_valid_o`, sets `rx_byte_o`, joins the queue `q`, is
// written to `fd` (or the log), and counts in `n_rx`; a low stop bit counts in `n_ferr`.
//
// `send(b)` drives `line_o` (the chip's RX) with one frame. The line idles
// high. `bit_ns` can be changed at run time (set_bit_ns) for baud tests.
module tb_uart_line #(
    parameter real BIT_NS = 8680.555    // 115200 baud
) (
    input  logic line_i,
    output logic line_o,
    output logic rx_valid_o,
    output logic [7:0] rx_byte_o
);
    real bit_ns = BIT_NS;
    int  n_rx = 0;
    int  n_ferr = 0;
    int  fd = 0;          // decoded bytes go here when set (0: the log, -1: nowhere)
    byte q[$];            // and into this queue
    logic [7:0] sh;

    initial begin
        line_o = 1'b1;
        rx_valid_o = 1'b0;
        rx_byte_o = 8'h0;
    end

    function automatic void set_bit_ns(input real b);
        bit_ns = b;
    endfunction

    task automatic send(input logic [7:0] b);
        line_o = 1'b0;
        #(bit_ns);
        for (int i = 0; i < 8; i++) begin
            line_o = b[i];
            #(bit_ns);
        end
        line_o = 1'b1;
        #(bit_ns);
    endtask

    always begin
        @(negedge line_i);
        #(bit_ns / 2.0);
        if (line_i == 1'b0) begin
            for (int i = 0; i < 8; i++) begin
                #(bit_ns);
                sh[i] = line_i;
            end
            #(bit_ns);
            if (line_i == 1'b1) begin
                rx_byte_o = sh;
                n_rx++;
                q.push_back(sh);
                if (fd > 0) begin $fwrite(fd, "%c", sh); $fflush(fd); end
                else if (fd == 0) $write("%c", sh);
                rx_valid_o = ~rx_valid_o;
            end else
                n_ferr++;
        end
    end
endmodule
