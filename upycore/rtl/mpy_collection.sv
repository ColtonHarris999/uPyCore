`include "mpy_defs.svh"

// One two-entry FIFO for copy and map commands, including the running command.
// Commands execute in issue order. Queued ranges enter the scoreboard at
// acceptance, before either engine starts. Only the head owns the memory port;
// ownership changes after every response, including the final write, retires.
// There is one core producer: it never asserts both command valids together.
module mpy_collection #(parameter bit TYPE_CACHE=0, parameter int SHORTLIST_MAX=16) (
    input logic cache_clear_i,cache_write_i,
    input logic [31:0] cache_addr_i,
    input logic clk_i, rst_n_i,
    input logic sl_valid_i, output logic sl_ready_o,
    input logic [31:0] sl_src_i, sl_dst_i, sl_n_i,
    input logic sl_reverse_i, sl_clear_i, sl_put_i, sl_length_i,
    input logic [31:0] sl_clear_addr_i, sl_put_addr_i, sl_header_i, sl_new_length_i,
    input logic [35:0] sl_put_value_i,
    output logic sl_response_o, input logic sl_response_ready_i,
    input logic copy_valid_i,copy_byte_i,copy_reverse_i,
    output logic copy_ready_o,
    input logic [31:0] copy_src_i, copy_dst_i, copy_n_i,
    input logic bulk_valid_i,
    output logic bulk_ready_o,
    input logic [2:0] bulk_op_i,
    input logic bulk_set_i,
    input logic [31:0] bulk_src_i, bulk_sn_i, bulk_dst_i, bulk_dn_i, bulk_used_i,
    input logic [31:0] bulk_header_i, bulk_source_header_i, bulk_hashes_i,
    input logic [31:0] qstr_count_i, qstr_base_i, qstr_ext_i,
    output logic bulk_return_o, bulk_ok_o,
    output logic [31:0] bulk_used_o,
    output logic idle_o,
    input logic [31:0] chk_addr_i,
    input logic chk_we_i,
    output logic chk_busy_o,
    output logic req_o, we_o,
    output logic [31:0] addr_o, wdata_o,
    output logic [3:0] wtag_o,
    input logic gnt_i, ack_i, fault_i,
    input logic [3:0] fault_reason_i,
    input logic [31:0] rdata_i,
    input logic [3:0] rtag_i,
    output logic fault_o,
    output logic [3:0] fault_reason_o,
    output logic [31:0] fault_addr_o,
    output logic [31:0] words_o, cmds_o
);
    typedef struct packed {
        logic bulk, is_set, bytes_mode,reverse_words;
        logic [2:0] op;
        logic [31:0] src, sn, dst, dn, used, header, source_header, hashes;
        logic [31:0] src_end, dst_end;
        // Scoreboard bounds, formed at push so the core's request path
        // sees only compares against flops (no adders, no alignment mux).
        logic [31:0] src_lo, dst_lo, hashes_end, header_end, source_header_end;
        logic hashes_v, header_v, source_header_v;
        logic [31:0] qcount, qbase, qext;
    } command_t;
    command_t queue [2];
    logic [1:0] occupied;
    logic head, tail, running, owner_bulk,owner_byte;
    logic by_launch,by_ready,by_idle,by_req,by_we,by_fault;
    logic [31:0] by_addr,by_data,by_fault_addr;
    logic [3:0] by_tag;
    logic [1:0] count;
    logic push, pop, dispatch, cp_launch, bm_launch;
    logic cp_ready, cp_idle, cp_busy, cp_req, cp_we, cp_fault;
    logic bm_ready, bm_idle, bm_req, bm_we, bm_fault;
    logic [31:0] cp_addr, cp_data, cp_fault_addr, bm_addr, bm_data, bm_fault_addr;
    logic [3:0] cp_tag, cp_reason, bm_tag;
    logic sl_idle, sl_req, sl_we, sl_fault, sl_lock;
    logic [31:0] sl_addr, sl_data, sl_faddr;
    logic [3:0] sl_tag, sl_reason;
    logic legacy_idle;
    command_t current;
    assign current = queue[head];
    assign tail = head ^ count[0];
    assign copy_ready_o = count < 2 && !fault_o && !bulk_valid_i && sl_idle && !sl_valid_i;
    assign bulk_ready_o = count < 2 && !fault_o && sl_idle && !sl_valid_i;
    assign push = (copy_valid_i && copy_ready_o) || (bulk_valid_i && bulk_ready_o);
    assign dispatch = count != 0 && !running && !fault_o;
    assign cp_launch = dispatch && !current.bulk && !current.bytes_mode && cp_ready;
    assign by_launch = dispatch && !current.bulk && current.bytes_mode && by_ready;
    assign bm_launch = dispatch && current.bulk && bm_ready;
    assign pop = running && (owner_bulk ? bm_idle : owner_byte ? by_idle : cp_idle) && !fault_o;
    assign legacy_idle = count == 0 && !running && cp_idle && bm_idle && by_idle;
    assign sl_ready_o = legacy_idle && sl_idle && !fault_o;
    assign idle_o = legacy_idle && sl_idle && !sl_valid_i;
    assign req_o = !sl_idle ? sl_req : (!fault_o && (owner_bulk ? bm_req : owner_byte ? by_req : cp_req));
    assign we_o = !sl_idle ? sl_we : (owner_bulk ? bm_we : owner_byte ? by_we : cp_we);
    assign addr_o = !sl_idle ? sl_addr : (owner_bulk ? bm_addr : owner_byte ? by_addr : cp_addr);
    assign wdata_o = !sl_idle ? sl_data : (owner_bulk ? bm_data : owner_byte ? by_data : cp_data);
    assign wtag_o = !sl_idle ? sl_tag : (owner_bulk ? bm_tag : owner_byte ? by_tag : cp_tag);
    assign fault_o = cp_fault || bm_fault || by_fault || sl_fault;
    assign fault_addr_o = sl_fault ? sl_faddr : bm_fault ? bm_fault_addr : by_fault ? by_fault_addr : cp_fault_addr;
    assign fault_reason_o = sl_fault ? sl_reason : (bm_fault || by_fault) ? MPY_FAULT_BUS : cp_reason;

    // Every range test feeds one OR (hit), not a chain of overriding
    // assignments: the chain sat between the core's address and its
    // request to mpy_mem (c_pend -> the engines' grants, 16.1 ns).
    logic [9:0] chk_hit;
    always_comb begin
        chk_hit = '0;
        for (int i=0; i<2; i++) begin
            // Once a copy starts, its own scoreboard releases completed words.
            // A map retains whole-table ownership through count publication.
            if (occupied[i] && !(running && !owner_bulk && !owner_byte && head == 1'(i))) begin
                chk_hit[5*i+0] = chk_addr_i >= queue[i].dst_lo && chk_addr_i < queue[i].dst_end;
                chk_hit[5*i+1] = chk_we_i && chk_addr_i >= queue[i].src_lo && chk_addr_i < queue[i].src_end;
                // The *_v bits are only set for bulk commands.
                chk_hit[5*i+2] = chk_we_i && queue[i].hashes_v && chk_addr_i >= queue[i].hashes && chk_addr_i < queue[i].hashes_end;
                chk_hit[5*i+3] = queue[i].header_v && chk_addr_i >= queue[i].header && chk_addr_i < queue[i].header_end;
                chk_hit[5*i+4] = chk_we_i && queue[i].source_header_v && chk_addr_i >= queue[i].source_header && chk_addr_i < queue[i].source_header_end;
            end
        end
        chk_busy_o = cp_busy || sl_lock || (|chk_hit);
    end
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            occupied<=0;head<=0;count<=0;running<=0;owner_bulk<=0;owner_byte<=0;
            for(int i=0;i<2;i++) queue[i]<='0;
        end else begin
            if (push) begin
                occupied[tail]<=1;
                queue[tail].bulk<=bulk_valid_i;
                queue[tail].reverse_words<=copy_reverse_i;
                queue[tail].bytes_mode<=!bulk_valid_i && copy_byte_i;
                queue[tail].is_set<=bulk_set_i;
                queue[tail].op<=bulk_op_i;
                queue[tail].src<=bulk_valid_i ? bulk_src_i : copy_src_i;
                queue[tail].sn<=bulk_valid_i ? bulk_sn_i : copy_n_i;
                queue[tail].dst<=bulk_valid_i ? bulk_dst_i : copy_dst_i;
                queue[tail].dn<=bulk_dn_i;
                queue[tail].used<=bulk_used_i;
                queue[tail].hashes<=bulk_valid_i ? bulk_hashes_i : 32'd0;
                queue[tail].header<=bulk_valid_i ? bulk_header_i : 32'd0;
                queue[tail].source_header<=bulk_valid_i ? bulk_source_header_i : 32'd0;
                queue[tail].src_end<=bulk_valid_i ? bulk_src_i+(bulk_sn_i<<(bulk_set_i?2:3)) : copy_byte_i ? ((copy_src_i+copy_n_i+3)&32'hfffffffc) : copy_src_i+(copy_n_i<<2);
                queue[tail].dst_end<=bulk_valid_i ? bulk_dst_i+(bulk_dn_i<<(bulk_set_i?2:3)) : copy_byte_i ? ((copy_dst_i+copy_n_i+3)&32'hfffffffc) : copy_dst_i+(copy_n_i<<2);
                queue[tail].src_lo<=bulk_valid_i ? bulk_src_i : copy_byte_i ? {copy_src_i[31:2],2'b00} : copy_src_i;
                queue[tail].dst_lo<=bulk_valid_i ? bulk_dst_i : copy_byte_i ? {copy_dst_i[31:2],2'b00} : copy_dst_i;
                queue[tail].hashes_v<=bulk_valid_i && bulk_hashes_i!=0;
                queue[tail].header_v<=bulk_valid_i && bulk_header_i!=0;
                queue[tail].source_header_v<=bulk_valid_i && bulk_source_header_i!=0;
                queue[tail].hashes_end<=bulk_hashes_i+(bulk_sn_i<<2);
                queue[tail].header_end<=bulk_header_i+32'd16;
                queue[tail].source_header_end<=bulk_source_header_i+32'd16;
                queue[tail].qcount<=qstr_count_i;
                queue[tail].qbase<=qstr_base_i;
                queue[tail].qext<=qstr_ext_i;
            end
            if (cp_launch || bm_launch || by_launch) begin running<=1;owner_bulk<=current.bulk;owner_byte<=current.bytes_mode;end
            if (pop) begin occupied[head]<=0;head<=!head;running<=0;end
            count<=count+2'(push)-2'(pop);
            if (fault_o) begin occupied<=0;count<=0;running<=0;end
        end
    end
    mpy_shortlist #(.MAX_ELEMS(SHORTLIST_MAX)) short_engine (
        .clk_i,.rst_n_i,.valid_i(sl_valid_i && legacy_idle && !fault_o),.ready_o(),
        .src_i(sl_src_i),.dst_i(sl_dst_i),.n_i(sl_n_i),.reverse_i(sl_reverse_i),
        .clear_i(sl_clear_i),.clear_addr_i(sl_clear_addr_i),.put_i(sl_put_i),
        .put_addr_i(sl_put_addr_i),.put_value_i(sl_put_value_i),
        .length_i(sl_length_i),.header_i(sl_header_i),.new_length_i(sl_new_length_i),
        .response_o(sl_response_o),.response_ready_i(sl_response_ready_i),.idle_o(sl_idle),
        .chk_addr_i,.chk_we_i,.chk_busy_o(sl_lock),
        .req_o(sl_req),.we_o(sl_we),.addr_o(sl_addr),.wdata_o(sl_data),.wtag_o(sl_tag),
        .gnt_i(gnt_i && !sl_idle),.ack_i(ack_i && !sl_idle),.fault_i,.fault_reason_i,.rdata_i,.rtag_i,
        .fault_o(sl_fault),.fault_addr_o(sl_faddr),.fault_reason_o(sl_reason)
    );
    mpy_ca #(.QDEPTH(1)) copy_engine (
        .clk_i,.rst_n_i,.cmd_valid_i(cp_launch),.cmd_ready_o(cp_ready),
        .cmd_src_i(current.src),.cmd_dst_i(current.dst),.cmd_n_i(current.sn),.idle_o(cp_idle),
        .chk_addr_i,.chk_we_i,.chk_busy_o(cp_busy),
        .req_o(cp_req),.we_o(cp_we),.addr_o(cp_addr),.wdata_o(cp_data),.wtag_o(cp_tag),
        .gnt_i(gnt_i && !owner_bulk && !owner_byte && sl_idle),.ack_i(ack_i && !owner_bulk && !owner_byte && sl_idle),.fault_i,.fault_reason_i,.rdata_i,.rtag_i,
        .fault_o(cp_fault),.fault_reason_o(cp_reason),.fault_addr_o(cp_fault_addr),.words_o,.cmds_o
    );
    mpy_bytecopy byte_engine (
        .clk_i,.rst_n_i,.valid_i(by_launch),.ready_o(by_ready),.idle_o(by_idle),
        .src_i(current.src),.dst_i(current.dst),.n_i(current.sn),.reverse_i(current.reverse_words),
        .req_o(by_req),.we_o(by_we),.addr_o(by_addr),.wdata_o(by_data),.wtag_o(by_tag),
        .gnt_i(gnt_i && owner_byte && !owner_bulk && sl_idle),.ack_i(ack_i && owner_byte && !owner_bulk && sl_idle),
        .fault_i,.rdata_i,.rtag_i,.fault_o(by_fault),.fault_addr_o(by_fault_addr)
    );
    mpy_bulk #(.TYPE_CACHE(TYPE_CACHE)) bulk_engine (
        .cache_clear_i,.cache_write_i,.cache_addr_i,
        .cache_write2_i(req_o && gnt_i && we_o),.cache_addr2_i(addr_o),
        .clk_i,.rst_n_i,.valid_i(bm_launch),.ready_o(bm_ready),
        .op_i(current.op),.set_i(current.is_set),.src_i(current.src),.sn_i(current.sn),
        .dst_i(current.dst),.dn_i(current.dn),.used_i(current.used),
        .header_i(current.header),.source_header_i(current.source_header),.hashes_i(current.hashes),
        .qstr_count_i(current.qcount),.qstr_base_i(current.qbase),.qstr_ext_i(current.qext),
        .return_o(bulk_return_o),.ok_o(bulk_ok_o),.idle_o(bm_idle),.used_o(bulk_used_o),
        .chk_addr_i,.chk_we_i,.busy_o(),
        .req_o(bm_req),.we_o(bm_we),.addr_o(bm_addr),.wdata_o(bm_data),.wtag_o(bm_tag),
        .gnt_i(gnt_i && owner_bulk && sl_idle),.ack_i(ack_i && owner_bulk && sl_idle),.fault_i,.rdata_i,.rtag_i,
        .fault_o(bm_fault),.fault_addr_o(bm_fault_addr)
    );
`ifndef SYNTHESIS
    always @(posedge clk_i) if (rst_n_i) begin
        if(copy_valid_i && bulk_valid_i) $error("collection: simultaneous core command ports");
        if(count>2) $error("collection: queue overflow");
    end
`endif
endmodule
