`include "mpy_defs.svh"

// Reads and writes every tag in the register file and in memory (tags as
// packed nibbles beside the words), checks a MUT_COLLEC address with the
// low bits cleared, and the memory map's faults and latencies.
//
// Frame spills are the core's microcode now (mpy_mem no longer has a spill
// engine); the hardware suite's memory area covers them.
//
// Build it with Verilator from the repo root, then run obj_dir/Vtb_mpy_value:
//   --binary -Iupycore/rtl upycore/rtl/mpy_regfile.sv
//   upycore/rtl/bsg_mem_1rw_sync_mask_write_bit.sv upycore/rtl/mpy_mem.sv
//   upycore/tb/tb_mpy_value.sv --top-module tb_mpy_value
// (upycore/tools/unit_tests.py does this.)
module tb_mpy_value;
    logic clk;
    logic rst_n;

    logic [MPY_RF_ADDR_W-1:0]   rs1_addr;
    logic [MPY_RF_ADDR_W-1:0]   rs2_addr;
    logic [MPY_ENTRY_WIDTH-1:0] rs1;
    logic [MPY_TAG_WIDTH-1:0]   rs1_tag;
    logic [MPY_VAL_WIDTH-1:0]   rs1_pay;
    logic [MPY_ENTRY_WIDTH-1:0] rs2;
    logic [MPY_TAG_WIDTH-1:0]   rs2_tag;
    logic [MPY_VAL_WIDTH-1:0]   rs2_pay;
    logic                       rd_we;
    logic [MPY_RF_ADDR_W-1:0]   rd_addr;
    logic [MPY_ENTRY_WIDTH-1:0] rd;
    logic                       wide_we;
    logic [MPY_RF_ADDR_W-1:0]   wide_addr;
    logic [MPY_TAG_WIDTH-1:0]   wide_tag;
    logic [127:0]               wide_pay;
    logic                       wide_fault;
    logic [MPY_RF_ADDR_W-1:0]   idx_addr;
    logic [MPY_ENTRY_WIDTH-1:0] idx_entry;
    logic                       idx_we;
    logic [MPY_ENTRY_WIDTH-1:0] idx_wdata;

    logic        req;
    logic        we;
    logic        tag_acc;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [3:0]  wtag;
    logic        rdy;
    logic        ack;
    logic        gnt;
    logic [31:0] rdata;
    logic [3:0]  rtag;
    logic        fault;
    logic [3:0]  fault_reason;

    mpy_regfile dut_rf (
        .clk_i(clk),
        .rst_n_i(rst_n),
        .rs1_addr_i(rs1_addr),
        .rs2_addr_i(rs2_addr),
        .rs1_o(rs1),
        .rs1_tag_o(rs1_tag),
        .rs1_pay_o(rs1_pay),
        .rs2_o(rs2),
        .rs2_tag_o(rs2_tag),
        .rs2_pay_o(rs2_pay),
        .rd_we_i(rd_we),
        .rd_addr_i(rd_addr),
        .rd_i(rd),
        .wide_we_i(wide_we),
        .wide_addr_i(wide_addr),
        .wide_tag_i(wide_tag),
        .wide_pay_i(wide_pay),
        .wide_fault_o(wide_fault),
        .idx_addr_i(idx_addr),
        .idx_entry_o(idx_entry),
        .idx_we_i(idx_we),
        .idx_wdata_i(idx_wdata)
    );

    mpy_mem #(.NP(1)) dut_mem (
        .clk_i(clk),
        .rst_n_i(rst_n),
        .req_i(req),
        .we_i(we),
        .tag_we_i(tag_acc),
        .be_i(4'hF),
        .addr_i(addr),
        .wdata_i(wdata),
        .wtag_i(wtag),
        .gnt_o(gnt),
        .ack_o(ack),
        .rdata_o(rdata),
        .rtag_o(rtag),
        .fault_o(fault),
        .fault_reason_o(fault_reason),
        .ld_we_i(1'b0),
        .ld_idx_i('0),
        .ld_wdata_i('0),
        .ld_wtag_i('0),
        .init_done_o(rdy)
    );

    assign idx_addr = '0;

    function automatic string tag_name(input logic [3:0] tag);
        case (tag)
            MPY_TAG_CONTROL:    tag_name = "CONTROL";
            MPY_TAG_INT:        tag_name = "INT";
            MPY_TAG_INT64:      tag_name = "INT64";
            MPY_TAG_FLOAT:      tag_name = "FLOAT";
            MPY_TAG_COMPLEX:    tag_name = "COMPLEX";
            MPY_TAG_RESERVED:   tag_name = "reserved";
            MPY_TAG_QSTR:       tag_name = "QSTR";
            MPY_TAG_SHORT_STR:  tag_name = "SHORT_STR";
            MPY_TAG_STR:        tag_name = "STR";
            MPY_TAG_TUPLE:      tag_name = "TUPLE";
            MPY_TAG_MUT_COLLEC: tag_name = "MUT_COLLEC";
            MPY_TAG_RANGE:      tag_name = "RANGE";
            MPY_TAG_ITER:       tag_name = "ITER";
            MPY_TAG_BYTES:      tag_name = "BYTES";
            MPY_TAG_OBJECT:     tag_name = "OBJECT";
            MPY_TAG_CONT:       tag_name = "CONT";
            default:            tag_name = "?";
        endcase
    endfunction

    function automatic string mut_name(input logic [1:0] kind);
        case (kind)
            MPY_MUT_LIST:      mut_name = "list";
            MPY_MUT_DICT:      mut_name = "dict";
            MPY_MUT_SET:       mut_name = "set";
            MPY_MUT_BYTEARRAY: mut_name = "bytearray";
            default:           mut_name = "?";
        endcase
    endfunction

    function automatic logic tag_is_pointer_expected(input logic [3:0] tag);
        tag_is_pointer_expected = (tag == MPY_TAG_STR) || (tag == MPY_TAG_TUPLE) ||
            (tag == MPY_TAG_MUT_COLLEC) || (tag == MPY_TAG_RANGE) ||
            (tag == MPY_TAG_ITER) || (tag == MPY_TAG_BYTES) ||
            (tag == MPY_TAG_OBJECT);
    endfunction

    task automatic check(input logic cond, input string msg);
        if (!cond) begin
            $error("%s", msg);
            $fatal(1, "mpy value encoding check failed");
        end
    endtask

    task automatic tick;
        #5 clk = 1'b1;
        #5 clk = 1'b0;
    endtask

    task automatic settle;
        #1;
    endtask

    task automatic write_rf(
        input logic [MPY_RF_ADDR_W-1:0] slot,
        input logic [MPY_ENTRY_WIDTH-1:0] entry
    );
        begin
            rd_we = 1'b1;
            rd_addr = slot;
            rd = entry;
            rs1_addr = slot;
            tick();
            rd_we = 1'b0;
        end
    endtask

    // One access: a one-cycle req pulse, then wait for its ack. ticks counts
    // the cycles from the request to the ack.
    task automatic bus(
        input logic        do_we,
        input logic        do_tag,
        input logic [31:0] bus_addr,
        input logic [31:0] bus_wdata,
        input logic [3:0]  bus_wtag,
        output logic [31:0] bus_rdata,
        output logic [3:0]  bus_rtag,
        output logic [31:0] bus_tag_word,
        output logic        bus_fault,
        output logic [3:0]  bus_reason,
        output logic [2:0]  bus_region,
        output int          ticks
    );
        int guard;
        begin
            guard = 0;
            while (!rdy && (guard < 16)) begin tick(); guard = guard + 1; end
            req = 1'b1;
            we = do_we;
            tag_acc = do_tag;
            addr = bus_addr;
            wdata = bus_wdata;
            wtag = bus_wtag;
            tick();
            req = 1'b0;
            ticks = 1;
            guard = 0;
            while (!ack && (guard < 16)) begin
                tick();
                ticks = ticks + 1;
                guard = guard + 1;
            end
            check(ack, "bus request timed out");
            bus_rdata = rdata;
            bus_rtag = rtag;
            bus_tag_word = 32'h0;   // SRAM words hold their own tag now
            bus_fault = fault;
            bus_reason = fault_reason;
            bus_region = mpy_region_of(bus_addr);
            tick();
        end
    endtask

    task automatic expect_ok(
        input logic        do_we,
        input logic        do_tag,
        input logic [31:0] bus_addr,
        input logic [31:0] bus_wdata,
        input logic [3:0]  bus_wtag,
        input logic [31:0] exp_data,
        input logic [3:0]  exp_tag,
        input logic [2:0]  exp_region,
        input int          exp_ticks
    );
        logic [31:0] got_data;
        logic [3:0]  got_tag;
        logic [31:0] got_word;
        logic        got_fault;
        logic [3:0]  got_reason;
        logic [2:0]  got_region;
        int          ticks;
        begin
            bus(do_we, do_tag, bus_addr, bus_wdata, bus_wtag,
                got_data, got_tag, got_word, got_fault, got_reason, got_region, ticks);
            check(!got_fault, "expected a successful access");
            check(got_region == exp_region, "region mismatch");
            check(got_data == exp_data, "data mismatch");
            check(got_tag == exp_tag, "tag mismatch");
            check(ticks == exp_ticks, "latency mismatch");
        end
    endtask

    task automatic expect_fault(
        input logic        do_we,
        input logic [31:0] bus_addr,
        input logic [3:0]  exp_reason,
        input logic [2:0]  exp_region
    );
        logic [31:0] got_data;
        logic [3:0]  got_tag;
        logic [31:0] got_word;
        logic        got_fault;
        logic [3:0]  got_reason;
        logic [2:0]  got_region;
        int          ticks;
        begin
            bus(do_we, 1'b0, bus_addr, 32'h0, 4'h0,
                got_data, got_tag, got_word, got_fault, got_reason, got_region, ticks);
            check(got_fault, "expected a fault");
            check(got_reason == exp_reason, "fault reason mismatch");
            check(got_region == exp_region, "fault region mismatch");
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        rs1_addr = '0;
        rs2_addr = '0;
        rd_we = 1'b0;
        rd_addr = '0;
        rd = '0;
        wide_we = 1'b0;
        wide_addr = '0;
        wide_tag = '0;
        wide_pay = '0;
        idx_we = 1'b0;
        idx_wdata = '0;
        req = 1'b0;
        we = 1'b0;
        tag_acc = 1'b0;
        addr = '0;
        wdata = '0;
        wtag = '0;

        check(MPY_RF_DEPTH == 16, "register file is 16 entries");
        check(MPY_ENTRY_WIDTH == 36, "an entry is 36 bits");
        check(MPY_FRAME_RESERVE_BASE == MPY_SRAM_BASE, "frame reserve starts SRAM");
        check(MPY_FRAME_RESERVE_BYTES == 32'h0000_8000, "frame reserve is 32 KB");
        check(MPY_SCHED_BASE == MPY_FRAME_RESERVE_BASE + MPY_FRAME_RESERVE_BYTES,
              "the scheduler queue follows the frame reserve");
        check(MPY_GC_POOL_BASE == 32'h2000_8500, "GC pool base");
        check(MPY_GC_POOL_BYTES == 32'h0000_7B00, "GC pool size");
        check(MPY_SRAM_WORDS == MPY_SRAM_BLOCKS * MPY_MEM_BLOCK_WORDS, "data SRAM is whole blocks");
        check(MPY_FLASH_WORDS == MPY_IMAGE_BLOCKS * MPY_MEM_BLOCK_WORDS, "image SRAM is whole blocks");
        check(MPY_MEM_BLOCKS == 4 && MPY_MEM_BLOCK_WORDS * 4 == 65536, "four 64 KB blocks");
        check((MPY_GC_POOL_BASE + MPY_GC_POOL_BYTES) ==
              (MPY_SRAM_BASE + MPY_SRAM_BYTES), "GC pool ends at SRAM");
        check(MPY_HANDLER_USED_BYTES == 48, "handler table uses 48 bytes");
        check(MPY_HANDLER_USED_BYTES <= MPY_HANDLER_BYTES, "handler window fits");
        check((MPY_SCHED_DEPTH * MPY_SCHED_ENTRY_WORDS * 4) == MPY_SCHED_BYTES,
              "schedule ring is depth 8");
        check(mpy_region_of(32'h00F4_0000) == MPY_REGION_NONE,
              "256 KB spill at 0xF40000 is not mapped");
        check(mpy_flash_addr_reserved(32'h0) && mpy_flash_addr_reserved(32'h4),
              "flash bytes 0 and 4 are reserved");
        check(!mpy_flash_addr_reserved(32'h8), "flash byte 8 is past the reservation");
        check(mpy_tag_span(MPY_TAG_INT64) == 3'(MPY_SPAN_INT64), "INT64 occupies two");
        check(mpy_tag_span(MPY_TAG_COMPLEX) == 3'(MPY_SPAN_COMPLEX), "COMPLEX occupies two");
        check(mpy_tag_span(MPY_TAG_SHORT_STR) == 3'(MPY_SPAN_SHORT_STR),
              "SHORT_STR occupies four");
        check(mpy_tag_span(MPY_TAG_CONT) == 3'd1, "CONT is one extra entry");
        check(mpy_tag_span(MPY_TAG_RESERVED) == 3'd0, "tag 0101 is reserved");

        tick();
        tick();
        rst_n = 1'b1;
        tick();
        // mpy_mem zeroes the data SRAM after reset, one word per cycle.
        for (int i = 0; i < MPY_MEM_BLOCK_WORDS + 4 && !rdy; i++) tick();
        check(rdy, "data SRAM clear finished");

        rs1_addr = '0;
        settle();
        check(rs1 == mpy_make_control(MPY_CTL_EMPTY), "reset entry is empty CONTROL");

        $display("REGFILE read/write every tag");
        for (int tag = 0; tag < MPY_TAG_SPACE; tag++) begin
            logic [3:0] code;
            logic [31:0] payload;
            logic [MPY_ENTRY_WIDTH-1:0] entry;
            code = 4'(tag);
            payload = 32'h1000_0000 | 32'(tag);
            entry = mpy_make_entry(code, payload);
            write_rf(MPY_RF_ADDR_W'(tag), entry);
            check(rs1 == entry, "packed read is tag beside payload");
            check(rs1_tag == code, "tag mismatch");
            check(rs1_pay == payload, "payload mismatch");
            check(mpy_tag_is_pointer(code) == tag_is_pointer_expected(code),
                  "pointer class mismatch");
            $display("  tag %04b %-10s payload=0x%08h pointer=%0d",
                     code, tag_name(code), payload, mpy_tag_is_pointer(code));
        end

        write_rf(MPY_RF_ADDR_W'(0), mpy_make_control(MPY_CTL_FALSE));
        check(!mpy_tag_is_pointer(rs1_tag), "False is not a pointer");
        check(rs1_pay[3:0] == MPY_CTL_FALSE, "False is CONTROL kind 4");
        check(mpy_bool_as_int(rs1_pay) == 32'd0, "False counts as int 0");
        write_rf(MPY_RF_ADDR_W'(1), mpy_make_control(MPY_CTL_TRUE));
        check(!mpy_tag_is_pointer(rs1_tag), "True is not a pointer");
        check(rs1_pay[3:0] == MPY_CTL_TRUE, "True is CONTROL kind 5");
        check(mpy_bool_as_int(rs1_pay) == 32'd1, "True counts as int 1");
        $display("CONTROL False kind=%0d as_int=%0d  True kind=%0d as_int=%0d",
                 MPY_CTL_FALSE, mpy_bool_as_int({28'b0, MPY_CTL_FALSE}),
                 MPY_CTL_TRUE, mpy_bool_as_int({28'b0, MPY_CTL_TRUE}));

        $display("WIDE INT64 COMPLEX SHORT_STR");
        wide_we = 1'b1;
        wide_addr = MPY_RF_ADDR_W'(0);
        wide_tag = MPY_TAG_INT64;
        wide_pay = {64'b0, 32'h0000_0001, 32'h0000_0002};
        settle();
        check(!wide_fault, "INT64 at slot 0 fits");
        rs1_addr = MPY_RF_ADDR_W'(0);
        rs2_addr = MPY_RF_ADDR_W'(1);
        tick();
        wide_we = 1'b0;
        check(rs1_tag == MPY_TAG_INT64, "INT64 head tag");
        check(rs1_pay == 32'h0000_0002, "INT64 low half");
        check(rs2_tag == MPY_TAG_CONT, "INT64 high half is CONT");
        check(rs2_pay == 32'h0000_0001, "INT64 high half");
        check(rs2 == {rs2_tag, rs2_pay}, "CONT read is one 36-bit entry");

        wide_we = 1'b1;
        wide_addr = MPY_RF_ADDR_W'(2);
        wide_tag = MPY_TAG_COMPLEX;
        wide_pay = {64'b0, 32'hBF80_0000, 32'h3F80_0000};
        settle();
        check(!wide_fault, "COMPLEX at slot 2 fits");
        rs1_addr = MPY_RF_ADDR_W'(2);
        rs2_addr = MPY_RF_ADDR_W'(3);
        tick();
        wide_we = 1'b0;
        check(rs1_tag == MPY_TAG_COMPLEX && rs1_pay == 32'h3F80_0000, "COMPLEX real");
        check(rs2_tag == MPY_TAG_CONT && rs2_pay == 32'hBF80_0000, "COMPLEX imag is CONT");

        begin
            logic [119:0] bytes;
            logic [31:0] word0;
            bytes = '0;
            bytes[7:0] = 8'h48;
            bytes[15:8] = 8'h69;
            word0 = mpy_short_str_word(8'd2, bytes, 2'd0);
            wide_we = 1'b1;
            wide_addr = MPY_RF_ADDR_W'(4);
            wide_tag = MPY_TAG_SHORT_STR;
            wide_pay = {mpy_short_str_word(8'd2, bytes, 2'd3),
                        mpy_short_str_word(8'd2, bytes, 2'd2),
                        mpy_short_str_word(8'd2, bytes, 2'd1),
                        word0};
            settle();
            check(!wide_fault, "SHORT_STR length 2 fits");
            rs1_addr = MPY_RF_ADDR_W'(4);
            rs2_addr = MPY_RF_ADDR_W'(7);
            tick();
            wide_we = 1'b0;
            check(rs1_tag == MPY_TAG_SHORT_STR, "SHORT_STR head");
            check(rs1_pay == 32'h0069_4802, "SHORT_STR length and first bytes");
            rs2_addr = MPY_RF_ADDR_W'(5);
            settle();
            check(rs2_tag == MPY_TAG_CONT && rs2_pay == 32'h0, "SHORT_STR CONT 1");
            rs2_addr = MPY_RF_ADDR_W'(6);
            settle();
            check(rs2_tag == MPY_TAG_CONT, "SHORT_STR CONT 2");
            rs2_addr = MPY_RF_ADDR_W'(7);
            settle();
            check(rs2_tag == MPY_TAG_CONT, "SHORT_STR CONT 3");
        end

        write_rf(MPY_RF_ADDR_W'(8), mpy_make_entry(MPY_TAG_INT, 32'h1111_1111));
        wide_we = 1'b1;
        wide_addr = MPY_RF_ADDR_W'(8);
        wide_tag = MPY_TAG_SHORT_STR;
        wide_pay = 128'd16;
        settle();
        check(wide_fault, "SHORT_STR longer than 15 faults");
        tick();
        wide_we = 1'b0;
        rs1_addr = MPY_RF_ADDR_W'(8);
        settle();
        check(rs1 == mpy_make_entry(MPY_TAG_INT, 32'h1111_1111),
              "rejected SHORT_STR does not write");

        wide_we = 1'b1;
        wide_addr = MPY_RF_ADDR_W'(13);
        wide_tag = MPY_TAG_SHORT_STR;
        wide_pay = 128'd1;
        settle();
        check(wide_fault, "SHORT_STR does not cross the file");
        wide_addr = MPY_RF_ADDR_W'(15);
        wide_tag = MPY_TAG_INT64;
        wide_pay = 128'd1;
        settle();
        check(wide_fault, "INT64 does not cross the file");
        wide_addr = MPY_RF_ADDR_W'(0);
        wide_tag = MPY_TAG_RESERVED;
        settle();
        check(wide_fault, "reserved tag is not a wide value");
        wide_we = 1'b0;

        wide_we = 1'b1;
        wide_addr = MPY_RF_ADDR_W'(12);
        wide_tag = MPY_TAG_SHORT_STR;
        wide_pay = {96'b0, 32'd4};
        settle();
        check(!wide_fault, "SHORT_STR at the last four entries fits");
        rs1_addr = MPY_RF_ADDR_W'(15);
        tick();
        wide_we = 1'b0;
        check(rs1_tag == MPY_TAG_CONT, "last SHORT_STR entry is CONT");

        $display("MUT_COLLEC address clears the low 2 bits");
        begin
            logic [1:0] kind;
            logic [31:0] payload;
            logic [31:0] cleared;
            for (int k = 0; k < 4; k++) begin
                kind = 2'(k);
                payload = mpy_mut_payload(kind, MPY_GC_POOL_BASE);
                cleared = mpy_mut_addr(payload);
                write_rf(MPY_RF_ADDR_W'(2), mpy_make_mut(kind, MPY_GC_POOL_BASE));
                check(rs1_tag == MPY_TAG_MUT_COLLEC, "MUT_COLLEC tag");
                check(mpy_mut_kind(rs1_pay) == kind, "MUT_COLLEC kind");
                check(mpy_pointer_addr(rs1_tag, rs1_pay) == MPY_GC_POOL_BASE,
                      "MUT_COLLEC address");
                check(cleared[1:0] == 2'b00, "cleared address is aligned");
                $display("  MUT_COLLEC %-9s payload=0x%08h addr=0x%08h",
                         mut_name(kind), payload, cleared);
            end
        end

        $display("MEMORY read/write every tag beside its payload");
        begin
            logic [31:0] got_data;
            logic [3:0]  got_tag;
            logic [31:0] got_word;
            logic        got_fault;
            logic [3:0]  got_reason;
            logic [2:0]  got_region;
            int          ticks;
            logic [31:0] nibbles;
            for (int tag = 0; tag < MPY_TAG_SPACE; tag++) begin
                logic [31:0] slot_addr;
                logic [31:0] payload;
                slot_addr = MPY_GC_POOL_BASE + 32'(tag * 4);
                payload = 32'h2000_0000 | 32'(tag);
                bus(1'b1, 1'b1, slot_addr, payload, 4'(tag),
                    got_data, got_tag, got_word, got_fault, got_reason, got_region, ticks);
                check(!got_fault, "pool store faulted");
                check(ticks == (1 + MPY_SRAM_LATENCY), "SRAM store latency");
            end
            // Packed tag words (image tags file, boot stream) put lane 0 in
            // bits [3:0]. Pack eight loaded tags the same way.
            nibbles = 32'h0;
            for (int tag = 0; tag < MPY_TAGS_PER_WORD; tag++) begin
                bus(1'b0, 1'b1, MPY_GC_POOL_BASE + 32'(tag * 4), 32'h0, 4'h0,
                    got_data, got_tag, got_word, got_fault, got_reason, got_region, ticks);
                nibbles = mpy_nibble_write(nibbles, 3'(tag), got_tag);
            end
            check(nibbles == 32'h7654_3210, "nibble lane 0 is bits [3:0]");
            $display("  pool tags 0..7 packed=0x%08h", nibbles);
            for (int tag = 0; tag < MPY_TAG_SPACE; tag++) begin
                bus(1'b0, 1'b1, MPY_GC_POOL_BASE + 32'(tag * 4), 32'h0, 4'h0,
                    got_data, got_tag, got_word, got_fault, got_reason, got_region, ticks);
                check(!got_fault, "pool load faulted");
                check(got_tag == 4'(tag), "memory tag mismatch");
                check(got_data == (32'h2000_0000 | 32'(tag)), "memory payload mismatch");
            end

            bus(1'b1, 1'b0, MPY_GC_POOL_BASE, 32'hABCD_0001, MPY_TAG_STR,
                got_data, got_tag, got_word, got_fault, got_reason, got_region, ticks);
            check(!got_fault, "untagged store faulted");
            bus(1'b0, 1'b1, MPY_GC_POOL_BASE, 32'h0, 4'h0,
                got_data, got_tag, got_word, got_fault, got_reason, got_region, ticks);
            check(got_data == 32'hABCD_0001, "untagged store wrote the word");
            check(got_tag == MPY_TAG_CONTROL, "untagged store left the nibble");
            $display("  tag_acc=0 left nibble %04b beside payload 0x%08h", got_tag, got_data);
        end

        $display("MAP faults");
        expect_fault(1'b0, 32'h2000_0001, MPY_FAULT_UNALIGNED, MPY_REGION_SRAM);
        expect_fault(1'b1, 32'h0000_0000, MPY_FAULT_FLASH_STORE, MPY_REGION_FLASH);
        expect_fault(1'b1, 32'h0000_0008, MPY_FAULT_FLASH_STORE, MPY_REGION_FLASH);
        expect_fault(1'b0, 32'h00F4_0000, MPY_FAULT_BUS, MPY_REGION_NONE);
        expect_fault(1'b0, 32'h0008_0000, MPY_FAULT_BUS, MPY_REGION_NONE);
        expect_fault(1'b0, 32'h2004_0000, MPY_FAULT_BUS, MPY_REGION_NONE);
        expect_fault(1'b0, MPY_FLASH_BYTES, MPY_FAULT_BUS, MPY_REGION_NONE);
        expect_fault(1'b0, MPY_SRAM_BASE + MPY_SRAM_BYTES, MPY_FAULT_BUS, MPY_REGION_NONE);
        expect_ok(1'b0, 1'b0, 32'h0000_0000, 32'h0, 4'h0, 32'h0, 4'h0,
                  MPY_REGION_FLASH, 1 + MPY_SRAM_LATENCY + MPY_FLASH_WAIT_STATES);
        expect_ok(1'b0, 1'b0, 32'h0000_0004, 32'h0, 4'h0, 32'h0, 4'h0,
                  MPY_REGION_FLASH, 1 + MPY_SRAM_LATENCY + MPY_FLASH_WAIT_STATES);
        $display("  flash[0]=0 flash[4]=0 reserved, store faults, wait states=%0d",
                 MPY_FLASH_WAIT_STATES);
        // mpy_soc answers the simulator page and mpy_periph the MMIO page
        // before the memory port; mpy_mem itself faults them.
        expect_fault(1'b1, MPY_MMIO_BASE + MPY_MMIO_UART_TX, MPY_FAULT_BUS, MPY_REGION_MMIO);
        expect_fault(1'b0, MPY_SIM_BASE, MPY_FAULT_BUS, MPY_REGION_SIM);
        expect_ok(1'b1, 1'b1, MPY_SRAM_BASE + MPY_SRAM_BYTES - 32'd4, 32'h5A5A_5A5A,
                  MPY_TAG_INT, 32'h0, 4'h0, MPY_REGION_SRAM, 1 + MPY_SRAM_LATENCY);
        expect_ok(1'b0, 1'b1, MPY_SRAM_BASE + MPY_SRAM_BYTES - 32'd4, 32'h0, 4'h0,
                  32'h5A5A_5A5A, MPY_TAG_INT, MPY_REGION_SRAM, 1 + MPY_SRAM_LATENCY);

        $display("MPY value encoding: ok");
        $finish;
    end
endmodule
