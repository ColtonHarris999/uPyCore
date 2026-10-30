// mpy_gc unit testbench (upycore/docs/mpy_gc.md).
//
// 1. Allocation is next-fit in 16-byte blocks and returns zeroed words.
// 2. A collection keeps what the roots reach, through an object's fields,
//    and frees the rest; the next allocation reuses the freed blocks.
// 3. Words with non-pointer tags (INT, FLOAT, CONTROL, QSTR) keep nothing
//    alive even when their payload is a pool address.
// 4. A pointer into a later block of an object (not its head) keeps
//    nothing alive.
// 5. A MUT_COLLEC pointer carries its kind in the low 2 bits; it still
//    keeps its object alive.
// 6. An allocation larger than the pool fails and changes nothing.
// 7. With a 2-entry mark stack a wide object overflows it; the rescan
//    still marks everything reachable.
//
// Build it with Verilator from the repo root, then run obj_dir/Vtb_mpy_gc:
//   --binary -Iupycore/rtl upycore/rtl/mpy_gc.sv upycore/tb/tb_mpy_gc.sv
//   --top-module tb_mpy_gc
// (upycore/tools/unit_tests.py does this.)

`include "mpy_defs.svh"

module tb_mpy_gc;
    localparam int          POOL_BYTES = 256;          // 16 blocks
    localparam logic [31:0] POOL  = 32'h2001_0000;
    localparam logic [31:0] ROOTS = 32'h2001_8000;     // outside the pool
    localparam int          NB = POOL_BYTES / 16;

    logic        clk = 1'b0;
    logic        rst_n = 1'b0;
    logic        alloc_req = 1'b0, collect_req = 1'b0;
    logic [31:0] alloc_nbytes = '0;
    logic        alloc_done, alloc_ok, collect_done, busy;
    logic [31:0] alloc_addr, free_blocks, total_blocks, collections, overflows;
    logic [31:0] r0lo = '0, r0hi = '0, r1lo = '0, r1hi = '0;
    logic        mem_req, mem_we, mem_tag_we;
    logic [31:0] mem_addr, mem_wdata;
    logic [3:0]  mem_wtag;
    logic        mem_ack = 1'b0;
    logic [31:0] mem_rdata = '0;
    logic [3:0]  mem_rtag = '0;

    always #5 clk = ~clk;

    mpy_gc #(.POOL_BASE(POOL), .POOL_BYTES(POOL_BYTES), .STACK_DEPTH(2)) dut (
        .clk_i(clk), .rst_n_i(rst_n),
        .alloc_req_i(alloc_req), .alloc_nbytes_i(alloc_nbytes),
        .alloc_done_o(alloc_done), .alloc_ok_o(alloc_ok), .alloc_addr_o(alloc_addr),
        .collect_req_i(collect_req),
        .root0_lo_i(r0lo), .root0_hi_i(r0hi), .root1_lo_i(r1lo), .root1_hi_i(r1hi),
        .collect_done_o(collect_done),
        .busy_o(busy), .free_blocks_o(free_blocks), .total_blocks_o(total_blocks),
        .collections_o(collections), .overflows_o(overflows),
        .mem_req_o(mem_req), .mem_we_o(mem_we), .mem_tag_we_o(mem_tag_we),
        .mem_addr_o(mem_addr), .mem_wdata_o(mem_wdata), .mem_wtag_o(mem_wtag),
        .mem_ack_i(mem_ack), .mem_rdata_i(mem_rdata), .mem_rtag_i(mem_rtag)
    );

    // Word memory, one-cycle access as mpy_mem with SRAM_LATENCY = 0.
    logic [31:0] data [logic [31:0]];
    logic [3:0]  tags [logic [31:0]];
    always @(posedge clk) begin
        mem_ack <= mem_req;
        if (mem_req) begin
            if (mem_we) begin
                data[mem_addr] = mem_wdata;
                if (mem_tag_we) tags[mem_addr] = mem_wtag;
            end
            mem_rdata <= data.exists(mem_addr) ? data[mem_addr] : 32'hBAD0_BAD0;
            mem_rtag  <= tags.exists(mem_addr) ? tags[mem_addr] : 4'(MPY_TAG_INT);
        end
    end

    int checks = 0;
    task automatic check(input logic cond, input string msg);
        if (!cond) $fatal(1, "FAIL %s", msg);
        checks++;
    endtask

    task automatic put(input logic [31:0] a, input logic [3:0] tag, input logic [31:0] v);
        data[a] = v;
        tags[a] = tag;
    endtask

    task automatic alloc(input int nbytes, output logic ok, output logic [31:0] addr);
        @(negedge clk);
        alloc_nbytes = 32'(nbytes); alloc_req = 1'b1;
        @(negedge clk);
        alloc_req = 1'b0;
        while (!alloc_done) @(negedge clk);
        ok = alloc_ok; addr = alloc_addr;
    endtask

    task automatic collect(input logic [31:0] lo, input logic [31:0] hi);
        @(negedge clk);
        r0lo = lo; r0hi = hi; r1lo = '0; r1hi = '0; collect_req = 1'b1;
        @(negedge clk);
        collect_req = 1'b0;
        while (!collect_done) @(negedge clk);
    endtask

    // Fill an object's words with a non-pointer filler.
    task automatic fill(input logic [31:0] a, input int words);
        for (int k = 0; k < words; k++) put(a + 32'(4 * k), MPY_TAG_INT, 32'd0);
    endtask

    initial begin
        logic        ok;
        logic [31:0] a, b, c, d, e, x;
        logic [31:0] kids [0:5];
        int          free0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        while (busy) @(negedge clk);     // the allocation table clears after reset

        // 1. Next-fit allocation of zeroed blocks.
        check(total_blocks == 32'(NB) && free_blocks == 32'(NB), "pool starts empty");
        // 40 blocks is 8 in the 5-bit block count: the request must still fail.
        alloc(640, ok, x);
        check(!ok && free_blocks == 32'(NB), "a request larger than the pool fails");
        put(POOL, MPY_TAG_OBJECT, 32'h1234_5678);        // stale data the alloc must clear
        alloc(20, ok, a);                                // 2 blocks
        check(ok && a == POOL, "first object at the pool base");
        check(data[POOL] == 32'd0 && tags[POOL] == 4'd0 && data[POOL + 28] == 32'd0,
              "allocation zeroes data and tags");
        alloc(0, ok, b);                                 // 0 bytes still takes a block
        check(ok && b == POOL + 32, "next fit after the first object");
        alloc(16, ok, c);
        check(ok && c == POOL + 48, "third object");
        alloc(48, ok, d);                                // 3 blocks
        check(ok && d == POOL + 64, "fourth object");
        check(free_blocks == 32'(NB - 7), "free count after four allocations");

        // 2-5. a is rooted; a.field1 -> b; c is reached only through a
        // non-pointer word, an interior pointer, or nothing; d through a
        // MUT_COLLEC pointer with kind bits set.
        fill(a, 8); fill(b, 4); fill(c, 4); fill(d, 12);
        put(a + 4, MPY_TAG_OBJECT, b);                   // keeps b
        put(a + 8, MPY_TAG_INT, c);                      // not a pointer tag
        put(a + 12, MPY_TAG_FLOAT, c);
        put(a + 16, MPY_TAG_CONTROL, c);
        put(a + 20, MPY_TAG_QSTR, c);
        put(a + 24, MPY_TAG_OBJECT, d + 16);             // interior: d's second block
        put(ROOTS, MPY_TAG_OBJECT, a);
        put(ROOTS + 4, MPY_TAG_INT, 32'd7);
        collect(ROOTS, ROOTS + 8);
        check(collections == 32'd1, "one collection");
        check(free_blocks == 32'(NB - 3), "only a (2 blocks) and b (1 block) survive");
        alloc(16, ok, x);
        check(ok && x == c, "the next allocation reuses c's block");
        alloc(48, ok, e);
        check(ok && e == d, "and then d's three blocks");

        // 5. A MUT_COLLEC pointer with its kind bits set keeps e alive.
        fill(e, 12);
        put(a + 24, MPY_TAG_MUT_COLLEC, e | 32'd1);      // dict kind in bits 1:0
        free0 = free_blocks;
        collect(ROOTS, ROOTS + 8);
        // x is unreferenced and goes; a, b, e stay.
        check(free_blocks == 32'(free0 + 1), "MUT_COLLEC kept its object, x was freed");
        alloc(48, ok, x);
        check(ok && x != e, "e was not freed");

        // 6. Larger than the pool: fails and changes nothing.
        free0 = free_blocks;
        alloc(POOL_BYTES + 16, ok, x);
        check(!ok, "an allocation larger than the pool fails");
        check(free_blocks == 32'(free0), "a failed allocation commits nothing");
        // Count-width and byte-rounding overflow must also be harmless misses.
        for (int k = 0; k < 4; k++) begin
            case (k)
                0: alloc(528, ok, x);  // 33 blocks would truncate to 1
                1: alloc(1024, ok, x); // block count would truncate to 0
                2: alloc(32'hFFFF_FFF0, ok, x);
                3: alloc(32'hFFFF_FFFF, ok, x); // +15 would wrap
            endcase
            check(!ok, "oversized count does not wrap into an allocation");
            check(free_blocks == 32'(free0), "oversized count leaves pool unchanged");
        end

        // 7. Six children of one object overflow the 2-entry mark stack.
        collect(ROOTS, ROOTS);                           // no roots: empty the pool
        check(free_blocks == 32'(NB), "no roots frees everything");
        alloc(32, ok, a);                                // parent, 2 blocks, 8 words
        fill(a, 8);
        for (int k = 0; k < 6; k++) begin
            alloc(16, ok, kids[k]);
            check(ok, "child allocation");
            fill(kids[k], 4);
            put(a + 32'(4 * k), MPY_TAG_OBJECT, kids[k]);
        end
        alloc(16, ok, x);                                // unreferenced
        fill(x, 4);
        put(ROOTS, MPY_TAG_OBJECT, a);
        free0 = overflows;
        collect(ROOTS, ROOTS + 4);
        check(overflows > 32'(free0), "the mark stack overflowed");
        check(free_blocks == 32'(NB - 8), "parent and six children survive the overflow");

        $display("PASS mpy_gc %0d checks", checks);
        $finish;
    end

    initial begin
        #2_000_000;
        $fatal(1, "FAIL timeout");
    end
endmodule
