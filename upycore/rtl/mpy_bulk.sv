// Admission and retirement adapter for mpy_map_engine. A successful scalar
// bulk operation returns at admission; the scoreboard protects both headers
// and tables until the final used-count write is acknowledged. Rehash returns
// at completion because its new table remains unpublished until success.
module mpy_bulk #(parameter bit TYPE_CACHE=0) (
    input logic cache_clear_i,cache_write_i,cache_write2_i,
    input logic [31:0] cache_addr_i,cache_addr2_i,
    input logic clk_i,rst_n_i, valid_i,
    output logic ready_o,
    input logic [2:0] op_i,
    input logic set_i,
    input logic [31:0] src_i,sn_i,dst_i,dn_i,used_i,header_i,source_header_i,hashes_i,
    input logic [31:0] qstr_count_i,qstr_base_i,qstr_ext_i,
    output logic return_o,ok_o,idle_o,
    output logic [31:0] used_o,
    input logic [31:0] chk_addr_i,
    input logic chk_we_i,
    output logic busy_o,
    output logic req_o,we_o,
    output logic [31:0] addr_o,wdata_o,
    output logic [3:0] wtag_o,
    input logic gnt_i,ack_i,fault_i,
    input logic [31:0] rdata_i,
    input logic [3:0] rtag_i,
    output logic fault_o,
    output logic [31:0] fault_addr_o
);
    typedef enum logic [2:0] {IDLE,RUN,PUBLISH,ACK} state_t;
    state_t state;
    logic ev,er,done,admitted,efallback,efault,eq,ew;
    logic [31:0] ea,ed,used,header,source_header,src,src_end,dst,dst_end;
    logic [3:0] et;
    logic [2:0] op;
    logic accepted;
    logic [1:0] sh_valid,sh_result_ready,sh_ack;
    logic [1:0][3:0] sh_tag;
    logic [1:0][31:0] sh_payload;
    logic hready,hvalid,herror,hreq;
    logic [31:0] hvalue,haddr,qcount,qbase,qext;
    wire select_stream=op==0;
    mpy_hash #(.DEPTH(1)) shared_hash (
        .clk_i,.rst_n_i(rst_n_i && state==RUN),
        .valid_i(state==RUN && sh_valid[select_stream]),.ready_o(hready),
        .tag_i(sh_tag[select_stream]),.payload_i(sh_payload[select_stream]),
        .qstr_count_i(qcount),.qstr_base_i(qbase),.qstr_ext_i(qext),
        .valid_o(hvalid),.ready_i(state==RUN && sh_result_ready[select_stream]),
        .hash_o(hvalue),.error_o(herror),.mem_req_o(hreq),.mem_addr_o(haddr),
        .mem_ack_i(sh_ack[select_stream]),.mem_fault_i(fault_i),.mem_data_i(rdata_i),.mem_tag_i(rtag_i)
    );
    logic mdone,mfallback,mfault,mreq,mwe;
    logic [31:0] mused,maddr,mdata;
    logic [3:0] mtag;
    logic rdone,rfallback,rfault,rreq,rwe;
    logic [31:0] rused,raddr,rdata,initial_used,hashes,hashes_end;
    logic [3:0] rtag;
    assign done=op==0 ? rdone : mdone;
    assign efallback=op==0 ? rfallback : mfallback;
    assign efault=op==0 ? rfault : mfault;
    assign used=op==0 ? rused+initial_used : mused;
    assign eq=op==0 ? rreq : mreq;
    assign ew=op==0 ? rwe : mwe;
    assign ea=op==0 ? raddr : maddr;
    assign ed=op==0 ? rdata : mdata;
    assign et=op==0 ? rtag : mtag;
    assign ready_o=state==IDLE && !fault_o;
    assign idle_o=state==IDLE;
    assign ev=valid_i && ready_o;
    assign req_o=state==PUBLISH || (state==RUN && eq);
    assign we_o=state==PUBLISH || (state==RUN && ew);
    assign addr_o=state==PUBLISH ? header : ea;
    assign wdata_o=state==PUBLISH ? used : ed;
    assign wtag_o=state==PUBLISH ? 4'd1 : et;
    assign busy_o=state!=IDLE && (
        (chk_we_i && hashes!=0 && chk_addr_i>=hashes && chk_addr_i<hashes_end) ||
        (chk_addr_i>=dst && chk_addr_i<dst_end) ||
        (header!=0 && chk_addr_i>=header && chk_addr_i<header+16) ||
        (chk_we_i && ((chk_addr_i>=src && chk_addr_i<src_end) ||
        (source_header!=0 && chk_addr_i>=source_header && chk_addr_i<source_header+16))));
    mpy_map_engine #(.EXTERNAL_HASH(1),.TYPE_CACHE(TYPE_CACHE)) engine(
        .cache_clear_i,.cache_write_i,.cache_write2_i,.cache_addr_i,.cache_addr2_i,
        .hash_valid_o(sh_valid[0]),.hash_ready_i(hready && state==RUN && !select_stream),
        .hash_tag_o(sh_tag[0]),.hash_payload_o(sh_payload[0]),
        .hash_result_valid_i(hvalid && state==RUN && !select_stream),
        .hash_result_ready_o(sh_result_ready[0]),.hash_value_i(hvalue),.hash_error_i(herror),
        .hash_mem_req_i(hreq && state==RUN && !select_stream),.hash_mem_addr_i(haddr),.hash_mem_ack_o(sh_ack[0]),
        .clk_i,.rst_n_i,.valid_i(ev && op_i!=0),.ready_o(er),.op_i,.set_i,
        .src_i,.src_alloc_i(sn_i),.dst_i,.dst_alloc_i(dn_i),.used_i,.hashes_i(32'd0),
        .qstr_count_i,.qstr_base_i,.qstr_ext_i,.done_o(mdone),.admitted_o(admitted),
        .fallback_o(mfallback),.fault_o(mfault),.used_o(mused),
        .req_o(mreq),.we_o(mwe),.addr_o(maddr),.wdata_o(mdata),.wtag_o(mtag),
        .gnt_i(gnt_i && state==RUN && op!=0),.ack_i(ack_i && state==RUN && op!=0),.fault_i,
        .mem_data_i(rdata_i),.mem_tag_i(rtag_i));
    mpy_rehash_stream #(.EXTERNAL_HASH(1)) rehash (
        .hash_valid_o(sh_valid[1]),.hash_ready_i(hready && state==RUN && select_stream==1'b1),
        .hash_tag_o(sh_tag[1]),.hash_payload_o(sh_payload[1]),
        .hash_result_valid_i(hvalid && state==RUN && select_stream==1'b1),
        .hash_result_ready_o(sh_result_ready[1]),.hash_value_i(hvalue),.hash_error_i(herror),
        .hash_mem_req_i(hreq && state==RUN && select_stream==1'b1),.hash_mem_addr_i(haddr),.hash_mem_ack_o(sh_ack[1]),

        .clk_i,.rst_n_i,.valid_i(ev && op_i==0),.ready_o(),.set_i,
        .src_i,.sn_i,.dst_i,.dn_i,.hashes_i,.qstr_count_i,.qstr_base_i,.qstr_ext_i,
        .done_o(rdone),.fallback_o(rfallback),.fault_o(rfault),.used_o(rused),
        .req_o(rreq),.we_o(rwe),.addr_o(raddr),.wdata_o(rdata),.wtag_o(rtag),
        .gnt_i(gnt_i && state==RUN && op==0),.ack_i(ack_i && state==RUN && op==0),
        .fault_i,.rdata_i,.rtag_i
    );
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i) begin
            state<=IDLE;return_o<=0;ok_o<=0;fault_o<=0;fault_addr_o<=0;
            qcount<=0;qbase<=0;qext<=0;initial_used<=0;hashes<=0;hashes_end<=0;
            header<=0;source_header<=0;src<=0;src_end<=0;dst<=0;dst_end<=0;
            op<=0;accepted<=0;used_o<=0;
        end else begin
            return_o<=0;
            case(state)
                IDLE: if(ev) begin
                    initial_used<=used_i;hashes<=hashes_i;hashes_end<=hashes_i+(sn_i<<2);
                    qcount<=qstr_count_i;qbase<=qstr_base_i;qext<=qstr_ext_i;
                    state<=RUN;op<=op_i;header<=header_i;source_header<=source_header_i;
                    src<=src_i;src_end<=src_i+(sn_i<<(set_i?2:3));
                    dst<=dst_i;dst_end<=dst_i+(dn_i<<(set_i?2:3));accepted<=0;
                end
                RUN: begin
                    if(admitted && op<5) begin return_o<=1;ok_o<=1;accepted<=1;end
                    if(done) begin
                        used_o<=used;
                        if(efault) begin fault_o<=1;fault_addr_o<=ea;end
                        if(!accepted) begin return_o<=1;ok_o<=!efallback && !efault;end
                        if(!efallback && !efault && header!=0 && op<5) state<=PUBLISH;
                        else state<=IDLE;
                    end
                end
                PUBLISH: if(gnt_i) state<=ACK;
                ACK: if(ack_i) begin
                    if(fault_i) begin fault_o<=1;fault_addr_o<=header;end
                    state<=IDLE;
                end
                default: state<=IDLE;
            endcase
        end
    end
endmodule
