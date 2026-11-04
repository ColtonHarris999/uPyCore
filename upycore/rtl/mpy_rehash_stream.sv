`include "mpy_abi.svh"

// Ordered rehash pipeline: source scan -> hash/modulo -> serial probes/writes.
// Four metadata slots keep key/value identity aligned with hash responses.
// Hashing, source reads, and the current probe overlap, but inserts retire in
// source-slot order so colliding keys never probe stale destination contents.
// The caller owns disjoint source/new tables and keeps the new table unpublished
// until success. Unsupported keys may abandon a partially populated new table.
module mpy_rehash_stream #(parameter bit EXTERNAL_HASH=0) (
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

    input logic clk_i,rst_n_i,valid_i,
    output logic ready_o,
    input logic set_i,
    input logic [31:0] src_i,sn_i,dst_i,dn_i,hashes_i,
    input logic [31:0] qstr_count_i,qstr_base_i,qstr_ext_i,
    output logic done_o,fallback_o,fault_o,
    output logic [31:0] used_o,
    output logic req_o,we_o,
    output logic [31:0] addr_o,wdata_o,
    output logic [3:0] wtag_o,
    input logic gnt_i,ack_i,fault_i,
    input logic [31:0] rdata_i,
    input logic [3:0] rtag_i
);
    typedef enum logic [2:0] {P_KEY,P_VALUE,P_OVERRIDE,P_SEND,P_DONE} producer_t;
    typedef enum logic [2:0] {C_HASH,C_PROBE,C_KEY,C_VALUE} consumer_t;
    producer_t ps;
    consumer_t cs;
    logic active,aborting,is_set,override_valid;
    logic [31:0] src,sn,dst,dn,hashes,idx,pos,start_pos,override_hash;
    logic [31:0] qcount,qbase,qext;
    logic [35:0] skey,svalue,ckey,cvalue;
    logic [35:0] key_fifo[4],value_fifo[4];
    logic [1:0] wp,rp;
    logic [2:0] count;
    logic push,pop,hin,hready,hout,herror,hreq,hack;
    logic [31:0] slot,haddr;
    logic sreq,sack,creq,cack,cwe;
    logic [31:0] saddr,caddr,cdata;
    logic [3:0] ctag;
    logic pending;
    logic [1:0] owner,turn,selected;
    logic found;
    logic [2:0] requests;
    assign ready_o=!active;
    assign hin=active && !aborting && ps==P_SEND && count<4;
    assign push=hin && hready;
    assign pop=active && !aborting && cs==C_HASH && hout;
    assign sreq=active && !aborting && ((ps==P_KEY && idx<sn && count<4) || ps==P_VALUE || ps==P_OVERRIDE);
    assign saddr=ps==P_OVERRIDE ? hashes+(idx<<2) : src+(idx<<(is_set?2:3))+(ps==P_VALUE?32'd4:32'd0);
    assign creq=active && !aborting && cs!=C_HASH;
    assign cwe=cs==C_KEY || cs==C_VALUE;
    assign caddr=dst+(pos<<(is_set?2:3))+(cs==C_VALUE?32'd4:32'd0);
    assign {ctag,cdata}=cs==C_VALUE ? cvalue : ckey;
    assign sack=pending && owner==0 && ack_i;
    assign hack=pending && owner==1 && ack_i;
    assign cack=pending && owner==2 && ack_i;
    // Reset the elastic pipeline between commands, after the shared port drains.
    mpy_hash_slot #(.DEPTH(1),.EXTERNAL_HASH(EXTERNAL_HASH)) pipeline (
        .hash_valid_o,.hash_ready_i,.hash_tag_o,.hash_payload_o,
        .hash_result_valid_i,.hash_result_ready_o,.hash_value_i,.hash_error_i,
        .hash_mem_req_i,.hash_mem_addr_i,.hash_mem_ack_o,
        .clk_i,.rst_n_i(rst_n_i && active),.valid_i(hin),.ready_o(hready),
        .tag_i(override_valid ? ABI_TAG_INT : skey[35:32]),
        .payload_i(override_valid ? override_hash : skey[31:0]),.alloc_i(dn),
        .qstr_count_i(qcount),.qstr_base_i(qbase),.qstr_ext_i(qext),
        .valid_o(hout),.ready_i(active && !aborting && cs==C_HASH),.slot_o(slot),.error_o(herror),
        .mem_req_o(hreq),.mem_addr_o(haddr),.mem_ack_i(hack),.mem_fault_i(fault_i),
        .mem_data_i(rdata_i),.mem_tag_i(rtag_i)
    );
    function automatic logic vacant(input logic [3:0] t,input logic [31:0] d);
        return t==ABI_TAG_CONTROL && (d==ABI_CTL_NULL || d==ABI_CTL_TOMB);
    endfunction
    function automatic logic callback_key(input logic [3:0] t);
        return t==ABI_TAG_OBJECT || t==ABI_TAG_TUPLE || t==ABI_TAG_MUT;
    endfunction
    task automatic next_source;
        idx<=idx+1;ps<=P_KEY;
    endtask
    task automatic source_ready;
        if(hashes!=0)ps<=P_OVERRIDE;
        else if(callback_key(skey[35:32]))begin fallback_o<=1;aborting<=1;end
        else ps<=P_SEND;
    endtask
    task automatic retire_key;
        used_o<=used_o+1;cs<=C_HASH;
    endtask
    // Fair word arbitration. No arithmetic or combinational memory response
    // feeds the external request outputs: all request fields are registered.
    always_comb begin
        requests={creq,hreq,sreq};selected=0;found=0;
        for(int off=0;off<3;off++)begin
            int k;
            k=int'(turn)+off;if(k>=3)k=k-3;
            if(!found && requests[k])begin selected=2'(k);found=1;end
        end
    end
    always_ff @(posedge clk_i or negedge rst_n_i)begin
        if(!rst_n_i)begin
            active<=0;aborting<=0;is_set<=0;ps<=P_DONE;cs<=C_HASH;
            src<=0;sn<=0;dst<=0;dn<=0;hashes<=0;idx<=0;pos<=0;start_pos<=0;
            qcount<=0;qbase<=0;qext<=0;skey<=0;svalue<=0;ckey<=0;cvalue<=0;
            override_valid<=0;override_hash<=0;wp<=0;rp<=0;count<=0;
            for(int i=0;i<4;i++)begin key_fifo[i]<=0;value_fifo[i]<=0;end
            pending<=0;owner<=0;turn<=0;req_o<=0;we_o<=0;addr_o<=0;wdata_o<=0;wtag_o<=0;
            done_o<=0;fallback_o<=0;fault_o<=0;used_o<=0;
        end else begin
            done_o<=0;
            if(req_o && gnt_i)req_o<=0;
            if(pending && ack_i)begin
                pending<=0;
                if(fault_i)begin fault_o<=1;aborting<=1;end
            end
            if(active && !aborting && !pending && found)begin
                pending<=1;owner<=selected;turn<=selected==2 ? 2'd0 : selected+1;
                req_o<=1;we_o<=selected==2 && cwe;
                addr_o<=selected==0 ? saddr : selected==1 ? haddr : caddr;
                wdata_o<=cdata;wtag_o<=ctag;
            end
            if(!active && valid_i)begin
                active<=1;aborting<=0;is_set<=set_i;ps<=P_KEY;cs<=C_HASH;
                src<=src_i;sn<=sn_i;dst<=dst_i;dn<=dn_i;hashes<=hashes_i;idx<=0;
                qcount<=qstr_count_i;qbase<=qstr_base_i;qext<=qstr_ext_i;
                wp<=0;rp<=0;count<=0;used_o<=0;fallback_o<=0;fault_o<=0;override_valid<=0;
                if(src_i==dst_i || src_i[1:0]!=0 || dst_i[1:0]!=0 || (dn_i==0 && sn_i!=0))begin
                    aborting<=1;fallback_o<=1;
                end
            end else if(active)begin
                count<=count+3'(push)-3'(pop);
                if(!aborting)begin
                    if(ps==P_KEY && idx==sn)ps<=P_DONE;
                    if(sack && !fault_i)case(ps)
                        P_KEY: if(vacant(rtag_i,rdata_i))next_source();
                            else begin
                                skey<={rtag_i,rdata_i};override_valid<=0;
                                if(!is_set)ps<=P_VALUE;
                                else if(hashes!=0)ps<=P_OVERRIDE;
                                else if(callback_key(rtag_i))begin fallback_o<=1;aborting<=1;end
                                else ps<=P_SEND;
                            end
                        P_VALUE:begin svalue<={rtag_i,rdata_i};source_ready();end
                        P_OVERRIDE:if(rtag_i==ABI_TAG_INT)begin
                            override_valid<=1;override_hash<=rdata_i;ps<=P_SEND;
                        end else if(callback_key(skey[35:32]))begin fallback_o<=1;aborting<=1;end
                        else ps<=P_SEND;
                        default:begin end
                    endcase
                    if(push)begin
                        key_fifo[wp]<=skey;value_fifo[wp]<=svalue;wp<=wp+1;next_source();
                    end
                    if(pop)begin
                        rp<=rp+1;
                        if(herror)begin fallback_o<=1;aborting<=1;end
                        else begin ckey<=key_fifo[rp];cvalue<=value_fifo[rp];pos<=slot;start_pos<=slot;cs<=C_PROBE;end
                    end
                    if(cack && !fault_i)case(cs)
                        C_PROBE:if(vacant(rtag_i,rdata_i))cs<=C_KEY;
                            else if((pos+1==dn?32'd0:pos+1)==start_pos)begin fallback_o<=1;aborting<=1;end
                            else pos<=pos+1==dn?32'd0:pos+1;
                        C_KEY:if(is_set)retire_key();else cs<=C_VALUE;
                        C_VALUE:retire_key();
                        default:begin end
                    endcase
                end
                if(!pending && (aborting || (ps==P_DONE && count==0 && cs==C_HASH)))begin
                    active<=0;done_o<=1;
                end
            end
        end
    end
`ifndef SYNTHESIS
    always @(posedge clk_i)if(rst_n_i && active)begin
        if(count>4 || (pop && count==0))$error("rehash metadata FIFO mismatch");
        if(ack_i && !pending)$error("rehash unexpected memory response");
    end
`endif
endmodule
