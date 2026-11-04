// Behavioral SPI NAND for tb_mpy_soc: the commands mpy_boot sends, in SPI
// mode 0 with one data line each way, on 2 KiB pages (no spare area).
//
//   FFh             reset
//   0Fh <addr>      get feature; C0h returns status, bit 0 = OIP (busy)
//   13h <3 bytes>   page read to cache; the low 16 address bits are the page
//   03h <col 2> <dummy>  read from cache at col, one byte per 8 clocks
//
// After a reset or a page read the status reads busy BUSY_POLLS times, so
// the loader's poll loop runs. +NAND=<file> loads the array from a hex file
// of bytes (upycore/tools/mpy_nand.py); erased bytes read FFh.
module tb_spi_nand #(
    parameter int PAGE_BYTES = 2048,
    parameter int PAGES = 512, // boot stream includes packed tags as well as payload
    parameter int BUSY_POLLS = 2
) (
    input  logic sck,
    input  logic cs_n,
    input  logic mosi,
    output logic miso
);
    logic [7:0] mem   [0:PAGE_BYTES*PAGES-1];
    logic [7:0] cache [0:PAGE_BYTES-1];

    int         nbit;
    logic [7:0] in_sr, out_sr;
    logic [7:0] cmd, feat;
    logic [23:0] addr;
    int         col;
    int         busy;
    int         pages_read;

    initial begin
        string path;
        for (int i = 0; i < PAGE_BYTES * PAGES; i++) mem[i] = 8'hFF;
        for (int i = 0; i < PAGE_BYTES; i++) cache[i] = 8'hFF;
        if ($value$plusargs("NAND=%s", path)) $readmemh(path, mem);
        miso = 1'b1;
        nbit = 0;
        busy = BUSY_POLLS;
        pages_read = 0;
        cmd = 8'h00;
    end

    function automatic logic [7:0] out_byte(input int m);
        if (cmd == 8'h0F && m == 2)
            return (feat == 8'hC0) ? {7'd0, busy > 0} : 8'h00;
        if (cmd == 8'h03 && m >= 4)
            return (col + m - 4 < PAGE_BYTES) ? cache[col + m - 4] : 8'hFF;
        return 8'hFF;
    endfunction

    always @(negedge cs_n) begin
        nbit = 0;
        cmd = 8'h00;
    end

    always @(posedge sck) if (!cs_n) begin
        in_sr = {in_sr[6:0], mosi};
        nbit++;
        if (nbit % 8 == 0) begin
            int m = nbit / 8 - 1;
            if (m == 0) cmd = in_sr;
            else if (cmd == 8'h0F && m == 1) feat = in_sr;
            else if (cmd == 8'h13 && m <= 3) addr = {addr[15:0], in_sr};
            else if (cmd == 8'h03 && m <= 2) col = (m == 1) ? int'(in_sr) << 8 : col | int'(in_sr);
        end
    end

    // Output bits change on the falling edge; the first bit of byte m is
    // driven on the falling edge that ends byte m - 1.
    always @(negedge sck) if (!cs_n) begin
        if (nbit % 8 == 0) out_sr = out_byte(nbit / 8);
        else out_sr = {out_sr[6:0], 1'b1};
        miso = out_sr[7];
    end

    always @(posedge cs_n) begin
        if (cmd == 8'hFF && nbit >= 8) busy = BUSY_POLLS;
        if (cmd == 8'h0F && feat == 8'hC0 && nbit >= 24 && busy > 0) busy--;
        if (cmd == 8'h13 && nbit >= 32) begin
            for (int i = 0; i < PAGE_BYTES; i++)
                cache[i] = (int'(addr[15:0]) < PAGES) ? mem[int'(addr[15:0]) * PAGE_BYTES + i] : 8'hFF;
            busy = BUSY_POLLS;
            pages_read++;
        end
        miso = 1'b1;
    end
endmodule
