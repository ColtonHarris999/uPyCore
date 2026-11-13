`include "mpy_abi.svh"

// Bulk map operations on already allocated tables. No allocation or callbacks.
// op: 0 rehash, 1 merge/union, 2 difference, 3 intersection, 4 symmetric difference.
// Tables must be disjoint and stable until done. The caller locks both tables,
// drains before GC, and publishes the returned used count only on success.
// Merge/algebra admission scans both tables before any write. Only immediate
// int/bool/None/qstr keys are accepted: other equality requires a core fallback.
// Rehash accepts hash-engine keys; OBJECT and aggregates require caller-provided
// hashes (a dense tagged array indexed by old slot, INT override or NULL).
// Rehash destination must be empty and unpublished, so a hash fallback may
// abandon it without changing the original collection. Bus faults are fatal.
// Operations 5/6 are read-only subset/disjoint predicates; operation 7 scans
// a word sequence for count/first index, with used_i selecting the mode.
// Requests are registered and issued once; acknowledgements may be delayed.
module mpy_map_engine #(parameter bit EXTERNAL_HASH=0, TYPE_CACHE=0) (
    input logic cache_clear_i,cache_write_i,cache_write2_i,
    input logic [31:0] cache_addr_i,cache_addr2_i,
    output logic hash_valid_o,
    input logic hash_ready_i,
    output logic [3:0] hash_tag_o,
    output logic [31:0] hash_payload_o,
    input logic hash_result_valid_i,
    output logic hash_result_ready_o,
    input logic [31:0] hash_value_i,
    input logic hash_error_i,hash_mem_req_i,
    input logic [31:0] hash_mem_addr_i,
    output logic hash_mem_ack_o,

    input logic clk_i, rst_n_i, valid_i,
    output logic ready_o,
    input logic [2:0] op_i,
    input logic set_i,
    input logic [31:0] src_i, src_alloc_i, dst_i, dst_alloc_i, used_i,
    input logic [31:0] hashes_i,
    input logic [31:0] qstr_count_i, qstr_base_i, qstr_ext_i,
    output logic done_o, admitted_o, fallback_o, fault_o,
    output logic [31:0] used_o,
    output logic req_o, we_o,
    output logic [31:0] addr_o, wdata_o,
    output logic [3:0] wtag_o,
    input logic gnt_i, ack_i, fault_i,
    input logic [31:0] mem_data_i,
    input logic [3:0] mem_tag_i
);
    `include "mpy_hash_funcs.svh"
    typedef enum logic [5:0] {IDLE, CHECK_SRC, CHECK_DST, CHECK_KEY,
        SCAN, KEY, VALUE, OVERRIDE, HASH_GO, HASH_WAIT, MOD_GO, MOD_WAIT,
        PROBE, PROBE_KEY, WRITE_KEY, WRITE_VALUE, ERASE, ERASE_WRITE, NEXT, FINISH,
        SEQ_TARGET,SEQ_SCAN,SEQ_KEY,SEQ_NEXT, MEM_WAIT, HASH_MEM_WAIT, EQ_GO, EQ_WAIT, EQ_MEM_WAIT} state_t;
    state_t state, after_mem;
    logic [2:0] op;
    logic is_set, check_dst, granted,find_first;
    logic [31:0] src, sn, dst, dn, hashes, idx, pos, start_pos, avail;
    logic [31:0] key, value, hash_value, active_base, active_n, probe_base, probe_n;
    logic [3:0] key_tag, value_tag;
    logic [35:0] probe_key;
    logic [31:0] qcount, qbase, qext;
    logic eq_ready,eq_valid,eq_result,eq_error,eq_req;
    logic [31:0] eq_addr;
    mpy_key_equal equality (
        .clk_i,.rst_n_i,.valid_i(state==EQ_GO),.ready_o(eq_ready),
        .a_i(probe_key),.b_i({key_tag,key}),
        .qstr_count_i(qcount),.qstr_base_i(qbase),.qstr_ext_i(qext),
        .valid_o(eq_valid),.ready_i(state==EQ_WAIT),.equal_o(eq_result),.error_o(eq_error),
        .mem_req_o(eq_req),.mem_addr_o(eq_addr),.mem_ack_i(state==EQ_MEM_WAIT && ack_i),
        .mem_fault_i(fault_i),.mem_data_i
    );
    logic hv, hr, he, hmreq, hmack, mod_done;
    logic [31:0] hout, hmaddr, rem;
    logic [31:0] src_used, rdata_i;
    logic [3:0] rtag_i;
    // Two table-tag summaries. Entries describe an exact table extent and
    // stride, not Python classes. All writes and GC invalidate conservatively.
    logic [1:0] cache_valid,cache_set;
    logic [31:0] cache_base[2],cache_end[2],cache_n[2],cache_used[2];
    logic [15:0] cache_tags[2],scan_tags[2];
    logic [31:0] dst_scan_used;
    logic src_hit,dst_hit;
    logic [31:0] src_cached_used;
    always_comb begin
        src_hit=0;dst_hit=0;src_cached_used=0;
        for(int i=0;i<2;i++)if(TYPE_CACHE && cache_valid[i] && cache_set[i]==is_set &&
            !(op==7 && (cache_tags[i][ABI_TAG_FLOAT] || cache_tags[i][ABI_TAG_COMPLEX])))begin
            if(cache_base[i]==src && cache_n[i]==sn)begin src_hit=1;src_cached_used=cache_used[i];end
            if(cache_base[i]==dst && cache_n[i]==dn)dst_hit=1;
        end
    end
    function automatic logic empty(input logic [3:0] t, input logic [31:0] d);
        return t == ABI_TAG_CONTROL && d == ABI_CTL_NULL;
    endfunction
    function automatic logic tomb(input logic [3:0] t, input logic [31:0] d);
        return t == ABI_TAG_CONTROL && d == ABI_CTL_TOMB;
    endfunction
    function automatic logic scalar(input logic [3:0] t, input logic [31:0] d);
        return t == ABI_TAG_INT || t == ABI_TAG_INT64 || t == ABI_TAG_FLOAT || t == ABI_TAG_COMPLEX ||
            t == ABI_TAG_STR || t == ABI_TAG_BYTES || t == ABI_TAG_QSTR ||
            (t == ABI_TAG_CONTROL && (d == ABI_CTL_NONE || d == ABI_CTL_FALSE || d == ABI_CTL_TRUE));
    endfunction
    function automatic logic numeric(input logic [3:0] t, input logic [31:0] d);
        return t == ABI_TAG_INT || (t == ABI_TAG_CONTROL && (d == ABI_CTL_FALSE || d == ABI_CTL_TRUE));
    endfunction
    function automatic logic [30:0] number(input logic [3:0] t, input logic [31:0] d);
        return t == ABI_TAG_INT ? d[30:0] : {30'd0, d == ABI_CTL_TRUE};
    endfunction
    function automatic logic equal_key(input logic [3:0] t, input logic [31:0] d);
        if (numeric(t,d) && numeric(key_tag,key)) return number(t,d) == number(key_tag,key);
        return t == key_tag && d == key;
    endfunction
    function automatic logic extended(input logic [3:0] t);
        return t==ABI_TAG_INT64 || t==ABI_TAG_FLOAT || t==ABI_TAG_COMPLEX || t==ABI_TAG_STR || t==ABI_TAG_BYTES;
    endfunction
    // base + (slot << (is_set ? 2 : 3)), one prefix add per (base, slot) the state mux
    // selects. Putting the add after the state decode is what made
    // state -> addr_o a ripple at 15.0 ns post-route.
    logic [31:0] sh_idx, sh_pos, sh_sn, sh_dn;
    assign sh_idx = is_set ? {idx[29:0], 2'b00} : {idx[28:0], 3'b000};
    assign sh_pos = is_set ? {pos[29:0], 2'b00} : {pos[28:0], 3'b000};
    assign sh_sn  = is_set ? {sn[29:0],  2'b00} : {sn[28:0],  3'b000};
    assign sh_dn  = is_set ? {dn[29:0],  2'b00} : {dn[28:0],  3'b000};
    logic [31:0] at_src_idx, at_dst_idx, at_act_idx, at_src_idx4, hash_idx;
    logic [31:0] at_probe, at_dst_pos, at_dst_pos4, src_span, dst_span;
    logic [31:0] er_slot, er_slot1, er_sh, er_addr, er_addr1;
    assign er_slot = (op == 2 || op == 3) ? idx : pos;
    assign er_sh   = is_set ? {er_slot[29:0],  2'b00} : {er_slot[28:0],  3'b000};
    upycore_add #(.W(32)) u_src_idx  (.a_i(src),         .b_i(sh_idx), .cin_i(1'b0), .sum_o(at_src_idx),  .cout_o());
    upycore_add #(.W(32)) u_dst_idx  (.a_i(dst),         .b_i(sh_idx), .cin_i(1'b0), .sum_o(at_dst_idx),  .cout_o());
    upycore_add #(.W(32)) u_act_idx  (.a_i(active_base), .b_i(sh_idx), .cin_i(1'b0), .sum_o(at_act_idx),  .cout_o());
    // +4 is a third operand, not a second prefix chained on the first sum.
    upycore_sum3 #(.W(32)) u_src_idx4 (
        .a_i(src), .b_i(sh_idx), .c_i(32'd4), .cin_i(1'b0), .sum_o(at_src_idx4));
    upycore_add #(.W(32)) u_hash_idx (.a_i(hashes), .b_i({idx[29:0], 2'b00}), .cin_i(1'b0), .sum_o(hash_idx), .cout_o());
    upycore_add #(.W(32)) u_probe    (.a_i(probe_base),  .b_i(sh_pos), .cin_i(1'b0), .sum_o(at_probe),    .cout_o());
    upycore_add #(.W(32)) u_dst_pos  (.a_i(dst),         .b_i(sh_pos), .cin_i(1'b0), .sum_o(at_dst_pos),  .cout_o());
    upycore_sum3 #(.W(32)) u_dst_pos4 (
        .a_i(dst), .b_i(sh_pos), .c_i(32'd4), .cin_i(1'b0), .sum_o(at_dst_pos4));
    upycore_add #(.W(32)) u_src_span (.a_i(src),         .b_i(sh_sn),  .cin_i(1'b0), .sum_o(src_span),    .cout_o());
    upycore_add #(.W(32)) u_dst_span (.a_i(dst),         .b_i(sh_dn),  .cin_i(1'b0), .sum_o(dst_span),    .cout_o());
    upycore_add #(.W(32)) u_er_inc   (.a_i(er_slot),     .b_i(32'd1),  .cin_i(1'b0), .sum_o(er_slot1),    .cout_o());
    upycore_add #(.W(32)) u_er_addr  (.a_i(dst),         .b_i(er_sh),  .cin_i(1'b0), .sum_o(er_addr),     .cout_o());
    // (slot+1)<<k is slot<<k plus 4 or 8. That keeps the +1 off the address carry.
    upycore_sum3 #(.W(32)) u_er_addr1 (
        .a_i(dst), .b_i(er_sh), .c_i(is_set ? 32'd4 : 32'd8), .cin_i(1'b0), .sum_o(er_addr1));
    assign ready_o = state == IDLE;
    // Aggregate keys require overrides/fallback, so no recursive hash stack
    // is needed in this integration. Keep the standalone full hash unit intact.
    assign hash_valid_o=state==HASH_GO && key_tag!=ABI_TAG_INT && key_tag!=ABI_TAG_CONTROL;
    assign hash_tag_o=key_tag;
    assign hash_payload_o=key;
    assign hash_result_ready_o=state==HASH_WAIT;
    assign hash_mem_ack_o=hmack;
    generate if(EXTERNAL_HASH)begin : shared_hash
        assign hr=hash_ready_i;
        assign hv=hash_result_valid_i;
        assign hout=hash_value_i;
        assign he=hash_error_i;
        assign hmreq=hash_mem_req_i;
        assign hmaddr=hash_mem_addr_i;
    end else begin : private_hash
    mpy_hash #(.DEPTH(1)) hash_unit (
        .clk_i, .rst_n_i, .valid_i(state == HASH_GO && key_tag != ABI_TAG_INT && key_tag != ABI_TAG_CONTROL), .ready_o(hr),
        .tag_i(key_tag), .payload_i(key), .qstr_count_i(qcount), .qstr_base_i(qbase), .qstr_ext_i(qext),
        .valid_o(hv), .ready_i(state == HASH_WAIT), .hash_o(hout), .error_o(he),
        .mem_req_o(hmreq), .mem_addr_o(hmaddr), .mem_ack_i(hmack),
        .mem_fault_i(fault_i), .mem_data_i, .mem_tag_i
    );
    end endgenerate
    assign hmack = state == HASH_MEM_WAIT && ack_i;
    // Same post-route step as the core's divider (15.2 ns at BPC=4).
    upycore_umod_seq #(.BPC(2)) modulo (.clk_i, .rst_n_i, .start_i(state == MOD_GO && hash_value >= probe_n),
        .a_i(hash_value), .d_i(probe_n), .done_o(mod_done), .rem_o(rem), .busy_o());
    task automatic read_word(input logic [31:0] a, input state_t next_state);
        req_o <= 1; we_o <= 0; addr_o <= a; granted <= 0;
        after_mem <= next_state; state <= MEM_WAIT;
    endtask
    task automatic write_word(input logic [31:0] a, input logic [3:0] t,
                              input logic [31:0] d, input state_t next_state);
        req_o <= 1; we_o <= 1; addr_o <= a; wtag_o <= t; wdata_o <= d; granted <= 0;
        after_mem <= next_state; state <= MEM_WAIT;
    endtask
    task automatic reject();
        fallback_o <= 1; state <= FINISH;
    endtask
    task automatic missing();
        if (op == 5) begin used_o<=0;state<=FINISH;end
        else if (op == 6) state<=NEXT;
        else if (op == 3) state <= ERASE;
        else if (op == 2) state <= NEXT;
        else begin
            if (avail != 32'hffffffff) pos <= avail;
            state <= WRITE_KEY;
        end
    endtask
    task automatic found_key;
        if (op == 7)begin
            if(find_first)begin used_o<=idx;state<=FINISH;end
            else begin used_o<=used_o+1;state<=SEQ_NEXT;end
        end else if (op == 6) begin used_o<=0;state<=FINISH;end
        else if (op == 2 || op == 4) state <= ERASE;
        else if (op == 1 && !is_set) state <= WRITE_VALUE;
        else state <= NEXT;
    endtask
    task automatic advance_probe(input logic is_tomb);
        if(op==7)state<=SEQ_NEXT;
        else if ((pos + 1 == probe_n ? 32'd0 : pos + 1) == start_pos) begin
            if (op == 5 || op == 6) missing();
            else if (op == 2) state <= NEXT;
            else if (op == 3) state <= ERASE;
            else if (avail != 32'hffffffff) begin pos <= avail; state <= WRITE_KEY; end
            else if (is_tomb) state <= WRITE_KEY;
            else reject();
        end else begin
            if (is_tomb && avail == 32'hffffffff) avail <= pos;
            pos <= pos + 1 == probe_n ? 32'd0 : pos + 1;
            state <= PROBE;
        end
    endtask
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            qcount<=0;qbase<=0;qext<=0;
            state <= IDLE; after_mem <= IDLE; op <= 0; is_set <= 0;
            src <= 0; sn <= 0; dst <= 0; dn <= 0; hashes <= 0; idx <= 0;
            probe_key<=0;find_first<=0;cache_valid<=0;cache_set<=0;dst_scan_used<=0;
            for(int i=0;i<2;i++)begin cache_base[i]<=0;cache_end[i]<=0;cache_n[i]<=0;cache_used[i]<=0;cache_tags[i]<=0;scan_tags[i]<=0;end
            pos <= 0; start_pos <= 0; avail <= 0; key <= 0; key_tag <= 0;
            value <= 0; value_tag <= 0; hash_value <= 0; src_used <= 0;
            active_base <= 0; active_n <= 0; probe_base <= 0; probe_n <= 0;
            used_o <= 0; done_o <= 0; admitted_o <= 0; fallback_o <= 0; fault_o <= 0;
            req_o <= 0; we_o <= 0; addr_o <= 0; wdata_o <= 0; wtag_o <= 0;
            check_dst <= 0; granted <= 0; rdata_i <= 0; rtag_i <= 0;
        end else begin
            done_o <= 0; admitted_o <= 0;
            if (ack_i) begin rdata_i <= mem_data_i; rtag_i <= mem_tag_i; end
            if (req_o && gnt_i) begin req_o <= 0; granted <= 1; end
            case (state)
                IDLE: if (valid_i) begin
                    qcount<=qstr_count_i;qbase<=qstr_base_i;qext<=qstr_ext_i;
                    op <= op_i; is_set <= set_i; src <= src_i; sn <= src_alloc_i;
                    dst <= dst_i; dn <= dst_alloc_i; hashes <= hashes_i; used_o <= op_i==7 ? (used_i==1 ? 32'hffffffff : 32'd0) : op_i>=5 ? 32'd1 : used_i;
                    find_first<=used_i==1;
                    fallback_o <= 0; fault_o <= 0; idx <= 0; src_used <= 0;dst_scan_used<=0;scan_tags[0]<=0;scan_tags[1]<=0;
                    active_base <= (op_i == 2 || op_i == 3 || op_i>=5) ? dst_i : src_i;
                    active_n <= (op_i == 2 || op_i == 3 || op_i>=5) ? dst_alloc_i : src_alloc_i;
                    probe_base <= (op_i == 2 || op_i == 3 || op_i>=5) ? src_i : dst_i;
                    probe_n <= (op_i == 2 || op_i == 3 || op_i>=5) ? src_alloc_i : dst_alloc_i;
                    // Same-table algebra is left to the core (including x ^= x).
                    if ((!set_i && op_i > 1) || (src_i == dst_i && op_i<5) ||
                        (src_i[1:0] != 0) || (dst_i[1:0] != 0) || (op_i<7 && used_i > dst_alloc_i))
                        reject();
                    else if (op_i == 0) state <= SCAN;
                    else state <= CHECK_SRC;
                end
                CHECK_SRC: if(idx==0 && src_hit)begin src_used<=src_cached_used;state<=CHECK_DST;end
                    else if (idx == sn) begin
                        if(TYPE_CACHE)begin
                            cache_valid[0]<=1;cache_set[0]<=is_set;cache_base[0]<=src;cache_n[0]<=sn;
                            cache_end[0]<=src_span;cache_used[0]<=src_used;cache_tags[0]<=scan_tags[0];
                        end
                        idx <= 0; state <= CHECK_DST;
                    end
                    else begin check_dst <= 0; read_word(at_src_idx, CHECK_KEY); end
                CHECK_DST: if (idx == dn || (idx==0 && dst_hit)) begin
                    if(TYPE_CACHE && !dst_hit)begin
                        cache_valid[1]<=1;cache_set[1]<=is_set;cache_base[1]<=dst;cache_n[1]<=dn;
                        cache_end[1]<=dst_span;cache_used[1]<=dst_scan_used;cache_tags[1]<=scan_tags[1];
                    end
                    idx <= 0;
                    // Conservative capacity bound: no mid-command allocation.
                    if ((op == 1 || op == 4) && src_used > dn - used_o) reject();
                    else begin admitted_o <= 1;if(op==7)read_word(src,SEQ_TARGET);else state <= SCAN;end
                end else begin check_dst <= 1; read_word(at_dst_idx, CHECK_KEY); end
                CHECK_KEY: begin
                    if (!empty(rtag_i,rdata_i) && !tomb(rtag_i,rdata_i)) begin
                        if (!scalar(rtag_i,rdata_i) || (op==7 && (rtag_i==ABI_TAG_FLOAT || rtag_i==ABI_TAG_COMPLEX))) reject();
                        else begin
                            scan_tags[check_dst]<=scan_tags[check_dst] | (16'd1<<rtag_i);
                            if (!check_dst) src_used <= src_used + 1;else dst_scan_used<=dst_scan_used+1;
                            idx <= idx + 1; state <= check_dst ? CHECK_DST : CHECK_SRC;
                        end
                    end else begin idx <= idx + 1; state <= check_dst ? CHECK_DST : CHECK_SRC; end
                end
                SEQ_TARGET:begin key<=rdata_i;key_tag<=rtag_i;state<=SEQ_SCAN;end
                SEQ_SCAN:if(idx==dn)state<=FINISH;else read_word(at_dst_idx,SEQ_KEY);
                SEQ_KEY:if(equal_key(rtag_i,rdata_i))found_key();
                    else if(extended(rtag_i) || extended(key_tag))begin probe_key<={rtag_i,rdata_i};state<=EQ_GO;end
                    else state<=SEQ_NEXT;
                SEQ_NEXT:begin idx<=idx+1;state<=SEQ_SCAN;end
                SCAN: if (idx == active_n) state <= FINISH;
                    else read_word(at_act_idx,KEY);
                KEY: if (empty(rtag_i,rdata_i) || tomb(rtag_i,rdata_i)) state <= NEXT;
                    else begin
                        key <= rdata_i; key_tag <= rtag_i;
                        if (probe_n == 0) begin
                            if (op>=5) missing();
                            else if (op == 3) state <= ERASE;
                            else if (op == 2) state <= NEXT;
                            else reject();
                        end else if (!is_set) read_word(at_src_idx4,VALUE);
                        else if (op == 0 && hashes != 0) read_word(hash_idx,OVERRIDE);
                        else if (op == 0 && (rtag_i == ABI_TAG_OBJECT || rtag_i == ABI_TAG_TUPLE || rtag_i == ABI_TAG_MUT)) reject();
                        else state <= HASH_GO;
                    end
                VALUE: begin
                    value <= rdata_i; value_tag <= rtag_i;
                    if (op == 0 && hashes != 0) read_word(hash_idx,OVERRIDE);
                    else if (op == 0 && (key_tag == ABI_TAG_OBJECT || key_tag == ABI_TAG_TUPLE || key_tag == ABI_TAG_MUT)) reject();
                    else state <= HASH_GO;
                end
                OVERRIDE: if (rtag_i == ABI_TAG_INT) begin
                    hash_value <= {rdata_i[30],rdata_i[30:0]}; state <= MOD_GO;
                end else if (key_tag == ABI_TAG_OBJECT || key_tag == ABI_TAG_TUPLE || key_tag == ABI_TAG_MUT) reject();
                else state <= HASH_GO;
                HASH_GO: if (key_tag == ABI_TAG_INT) begin
                    hash_value <= hash_sx31(key); state <= MOD_GO;
                end else if (key_tag == ABI_TAG_CONTROL) begin
                    hash_value <= key == ABI_CTL_NONE ? 32'd6 : key == ABI_CTL_TRUE ? 32'd1 : 32'd0;
                    state <= MOD_GO;
                end else if (hr) state <= HASH_WAIT;
                HASH_WAIT: if (hv) begin
                    if (he) reject(); else begin hash_value <= hout; state <= MOD_GO; end
                end else if (hmreq) begin
                    req_o <= 1; we_o <= 0; addr_o <= hmaddr; granted <= 0; state <= HASH_MEM_WAIT;
                end
                HASH_MEM_WAIT: if (ack_i) begin
                    granted <= 0;
                    if (fault_i) begin fault_o <= 1; state <= FINISH; end
                    else state <= HASH_WAIT;
                end
                MOD_GO: if (hash_value < probe_n) begin
                    pos <= hash_value; start_pos <= hash_value; avail <= 32'hffffffff; state <= PROBE;
                end else state <= MOD_WAIT;
                MOD_WAIT: if (mod_done) begin pos <= rem; start_pos <= rem; avail <= 32'hffffffff; state <= PROBE; end
                PROBE: read_word(at_probe,PROBE_KEY);
                PROBE_KEY: if (empty(rtag_i,rdata_i)) missing();
                    else if (op != 0 && !tomb(rtag_i,rdata_i) && equal_key(rtag_i,rdata_i)) found_key();
                    else if (op != 0 && !tomb(rtag_i,rdata_i) && (extended(rtag_i) || extended(key_tag))) begin
                        probe_key<={rtag_i,rdata_i};state<=EQ_GO;
                    end else advance_probe(tomb(rtag_i,rdata_i));
                EQ_GO:if(eq_ready)state<=EQ_WAIT;
                EQ_WAIT:if(eq_valid)begin
                    if(eq_error)begin fault_o<=1;state<=FINISH;end
                    else if(eq_result)found_key();else advance_probe(0);
                end else if(eq_req)begin
                    req_o<=1;we_o<=0;addr_o<=eq_addr;granted<=0;state<=EQ_MEM_WAIT;
                end
                EQ_MEM_WAIT:if(ack_i)begin
                    granted<=0;
                    if(fault_i)begin fault_o<=1;state<=FINISH;end else state<=EQ_WAIT;
                end
                WRITE_KEY: begin
                    used_o <= used_o + 1;
                    write_word(at_dst_pos,key_tag,key,is_set ? NEXT : WRITE_VALUE);
                end
                WRITE_VALUE: write_word(at_dst_pos4,value_tag,value,NEXT);
                // The slot after the erased one, slot 0 after the last. The
                // wrap selects between the table base and the summed address:
                // selecting the slot number first put the compare with dn in
                // front of the address add (op -> addr_o, 10.0 ns).
                ERASE: read_word(er_slot1 == dn ? dst : er_addr1, ERASE_WRITE);
                ERASE_WRITE: begin
                    used_o <= used_o - 1;
                    write_word(er_addr,ABI_TAG_CONTROL,
                        empty(rtag_i,rdata_i) ? ABI_CTL_NULL : ABI_CTL_TOMB,NEXT);
                end
                NEXT: begin idx <= idx + 1; state <= SCAN; end
                FINISH: begin done_o <= 1; state <= IDLE; end
                MEM_WAIT: if (ack_i) begin
                    granted <= 0;
                    if (fault_i) begin fault_o <= 1; state <= FINISH; end
                    else state <= after_mem;
                end
                default: state <= IDLE;
            endcase
            for(int i=0;i<2;i++)begin
                if(cache_clear_i || (cache_write_i && cache_addr_i>=cache_base[i] && cache_addr_i<cache_end[i]) ||
                    (cache_write2_i && cache_addr2_i>=cache_base[i] && cache_addr2_i<cache_end[i]))cache_valid[i]<=0;
            end
        end
    end
endmodule
