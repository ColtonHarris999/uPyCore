// Behavioral SPI NOR flash for the benches, SPI mode 0 or 3 (sample on
// the rising edge, shift on the falling edge). Commands: 0x9F JEDEC id
// (EF 40 18), 0x03 read, 0x06 write enable, 0x02 page program, 0x05 read
// status (bit 1 WEL). Byte a starts as (7*a + 3) & 0xFF; a program needs
// WEL and clears it when CS rises.
module tb_spi_flash #(
    parameter int BYTES = 4096
) (
    input  logic cs_n,
    input  logic sck,
    input  logic mosi,
    output logic miso
);
    logic [7:0] mem [0:BYTES-1];
    logic [7:0] in_sh, out_sh, cmd;
    int         nbits, nbytes;
    logic [23:0] addr;
    logic       wel;

    initial begin
        for (int a = 0; a < BYTES; a++) mem[a] = 8'((7 * a + 3) & 8'hFF);
        miso = 1'b0;
        wel = 1'b0;
        out_sh = 8'h00;
    end

    always @(negedge cs_n) begin
        nbits = 0;
        nbytes = 0;
        out_sh = 8'h00;
        miso = 1'b0;
    end

    always @(posedge cs_n) begin
        if (cmd == 8'h02) wel = 1'b0;
    end

    // Next byte out, from the bytes received so far in this command.
    function automatic logic [7:0] reply();
        case (cmd)
            8'h9F: reply = (nbytes == 1) ? 8'hEF : (nbytes == 2) ? 8'h40 : (nbytes == 3) ? 8'h18 : 8'h00;
            8'h05: reply = {6'h0, wel, 1'b0};
            8'h03: reply = (nbytes >= 4) ? mem[addr % BYTES] : 8'h00;
            default: reply = 8'h00;
        endcase
    endfunction

    always @(posedge sck) begin
        if (!cs_n) begin
            in_sh = {in_sh[6:0], mosi};
            nbits++;
            if (nbits == 8) begin
                nbits = 0;
                nbytes++;
                if (nbytes == 1) begin
                    cmd = in_sh;
                    addr = 24'h0;
                    if (cmd == 8'h06) wel = 1'b1;
                end else if ((cmd == 8'h03 || cmd == 8'h02) && nbytes <= 4) begin
                    addr = {addr[15:0], in_sh};
                end else if (cmd == 8'h03) begin
                    addr = addr + 24'd1;
                end else if (cmd == 8'h02 && wel) begin
                    mem[addr % BYTES] = in_sh;
                    addr = addr + 24'd1;
                end
                out_sh = reply();
            end
        end
    end

    always @(negedge sck) begin
        if (!cs_n) begin
            miso = out_sh[7];
            out_sh = {out_sh[6:0], 1'b0};
        end
    end
endmodule
