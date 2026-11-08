`include "mpy_defs.svh"
`include "mpy_abi.svh"

// Operation-local tagged snapshot. No dirty data survives a completed command.
// The caller validates list semantics, allocates first, and cannot collect or
// retire the Python operation until the response is accepted. All source words
// are read before the first write, including for self/overlapping assignments.
module mpy_shortlist #(parameter int MAX_ELEMS=16) (
    input logic clk_i, rst_n_i,
    input logic valid_i, output logic ready_o,
    input logic [31:0] src_i, dst_i, n_i,
    input logic reverse_i,
    input logic clear_i, input logic [31:0] clear_addr_i,
    input logic put_i, input logic [31:0] put_addr_i,
    input logic [35:0] put_value_i,
    input logic length_i, input logic [31:0] header_i, new_length_i,
    output logic response_o, input logic response_ready_i,
    output logic idle_o,
    input logic [31:0] chk_addr_i, input logic chk_we_i,
    output logic chk_busy_o,
    output logic req_o, we_o,
    output logic [31:0] addr_o, wdata_o, output logic [3:0] wtag_o,
    input logic gnt_i, ack_i, fault_i,
    input logic [3:0] fault_reason_i,
    input logic [31:0] rdata_i, input logic [3:0] rtag_i,
    output logic fault_o, output logic [31:0] fault_addr_o,
    output logic [3:0] fault_reason_o
);
    localparam int CW=$clog2(MAX_ELEMS+1);
    localparam int IW=(MAX_ELEMS>1) ? $clog2(MAX_ELEMS) : 1;  // buffer index; issued/acked < count <= MAX_ELEMS when used
    // READ and WRITE stream: a request goes out on every grant while words
    // remain, and acks (in order) are counted separately, so the engine
    // keeps the pipelined port busy instead of waiting out each round trip.
    // Every read is acked before the first write is issued.
    typedef enum logic [3:0] {IDLE, READ, WRITE,
        CLEAR_REQ, CLEAR_WAIT, PUT_REQ, PUT_WAIT, LENGTH_REQ, LENGTH_WAIT,
        DONE, FAILED} state_t;
    state_t st;
    logic [35:0] buffer [0:MAX_ELEMS-1];
    logic [CW-1:0] count, issued, acked;
    logic [31:0] src, dst, read_addr, write_addr, clear_addr, put_addr, header, new_length;
    logic reverse_words, clear_tail, put_value, write_length;
    logic [35:0] value;
    logic [32:0] source_end, source_low, dest_end, header_end;
    logic [32:0] cmd_span, cmd_low, cmd_high, cmd_dst_end;
    always_comb begin
        cmd_span = (n_i == 0) ? 33'd0 : (({1'b0,n_i}-33'd1)<<2);
        cmd_low = reverse_i ? ({1'b0,src_i}-cmd_span) : {1'b0,src_i};
        cmd_high = reverse_i ? ({1'b0,src_i}+33'd4) : ({1'b0,src_i}+({1'b0,n_i}<<2));
        cmd_dst_end = {1'b0,dst_i}+({1'b0,n_i}<<2);
        ready_o = st==IDLE;
        idle_o = st==IDLE;
        response_o = st==DONE;
        req_o = ((st==READ || st==WRITE) && issued!=count) ||
                st==CLEAR_REQ || st==PUT_REQ || st==LENGTH_REQ;
        we_o = st!=READ;
        addr_o = read_addr;
        wdata_o = 32'd0; wtag_o = 4'd0;
        case (st)
            WRITE: begin
                addr_o=write_addr; wdata_o=buffer[IW'(issued)][31:0]; wtag_o=buffer[IW'(issued)][35:32];
            end
            CLEAR_REQ,CLEAR_WAIT: begin addr_o=clear_addr; wdata_o=ABI_CTL_NULL; wtag_o=MPY_TAG_CONTROL; end
            PUT_REQ,PUT_WAIT: begin addr_o=put_addr; wdata_o=value[31:0]; wtag_o=value[35:32]; end
            LENGTH_REQ,LENGTH_WAIT: begin addr_o=header; wdata_o=new_length; wtag_o=MPY_TAG_INT; end
            default: ;
        endcase
        chk_busy_o = 0;
        if(st!=IDLE) begin
            if ({1'b0,chk_addr_i}>={1'b0,dst} && {1'b0,chk_addr_i}<dest_end) chk_busy_o=1;
            if(chk_we_i && {1'b0,chk_addr_i}>=source_low && {1'b0,chk_addr_i}<source_end) chk_busy_o=1;
            if(clear_tail && chk_addr_i==clear_addr) chk_busy_o=1;
            if(put_value && chk_addr_i==put_addr) chk_busy_o=1;
            if(write_length && chk_addr_i>=header && {1'b0,chk_addr_i}<header_end) chk_busy_o=1;
        end
    end
    task automatic finish_items();
        if(clear_tail) st<=CLEAR_REQ;
        else if(put_value) st<=PUT_REQ;
        else if(write_length) st<=LENGTH_REQ;
        else st<=DONE;
    endtask
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i) begin
            st<=IDLE;count<=0;issued<=0;acked<=0;src<=0;dst<=0;read_addr<=0;write_addr<=0;
            clear_addr<=0;put_addr<=0;header<=0;new_length<=0;
            reverse_words<=0;clear_tail<=0;put_value<=0;write_length<=0;value<=0;
            source_low<=0;source_end<=0;dest_end<=0;header_end<=0;
            fault_o<=0;fault_addr_o<=0;fault_reason_o<=0;
        end else case(st)
            IDLE: if(valid_i) begin
                src<=src_i;dst<=dst_i;count<=CW'(n_i);issued<=0;acked<=0;
                read_addr<=src_i;write_addr<=dst_i;reverse_words<=reverse_i;
                clear_tail<=clear_i;clear_addr<=clear_addr_i;put_value<=put_i;
                put_addr<=put_addr_i;value<=put_value_i;write_length<=length_i;
                header<=header_i;new_length<=new_length_i;header_end<={1'b0,header_i}+33'd12;
                source_low<=n_i==0 ? 33'd0 : cmd_low;
                source_end<=n_i==0 ? 33'd0 : cmd_high;dest_end<=cmd_dst_end;
                if(n_i>MAX_ELEMS || (n_i!=0 && (src_i[1:0]!=0 || dst_i[1:0]!=0 ||
                   cmd_low[32] || cmd_high[32] || cmd_dst_end[32])) ||
                   (clear_i && clear_addr_i[1:0]!=0) || (put_i && put_addr_i[1:0]!=0) ||
                   (length_i && (header_i[1:0]!=0 || header_i>32'hfffffff3))) begin
                    fault_o<=1;fault_addr_o<=src_i;fault_reason_o<=MPY_FAULT_BUS;st<=FAILED;
                end else if(n_i!=0) st<=READ;
                else if(clear_i) st<=CLEAR_REQ;
                else if(put_i) st<=PUT_REQ;
                else if(length_i) st<=LENGTH_REQ;
                else st<=DONE;
            end
            READ: begin
                if(gnt_i && issued!=count) begin
                    issued<=issued+1'b1;
                    read_addr<=reverse_words ? read_addr-32'd4 : read_addr+32'd4;
                end
                if(ack_i) begin
                    if(fault_i) begin
                        fault_o<=1;fault_reason_o<=fault_reason_i;st<=FAILED;
                        fault_addr_o<=reverse_words ? src-(32'(acked)<<2) : src+(32'(acked)<<2);
                    end else begin
                        buffer[IW'(acked)]<={rtag_i,rdata_i};
                        acked<=acked+1'b1;
                        if(acked+1'b1==count) begin issued<=0;acked<=0;st<=WRITE;end
                    end
                end
            end
            WRITE: begin
                if(gnt_i && issued!=count) begin
                    issued<=issued+1'b1;
                    write_addr<=write_addr+32'd4;
                end
                if(ack_i) begin
                    if(fault_i) begin
                        fault_o<=1;fault_reason_o<=fault_reason_i;st<=FAILED;
                        fault_addr_o<=dst+(32'(acked)<<2);
                    end else begin
                        acked<=acked+1'b1;
                        if(acked+1'b1==count) finish_items();
                    end
                end
            end
            CLEAR_REQ: if(gnt_i) st<=CLEAR_WAIT;
            CLEAR_WAIT: if(ack_i) begin
                if(fault_i) begin fault_o<=1;fault_addr_o<=clear_addr;fault_reason_o<=fault_reason_i;st<=FAILED;end
                else if(put_value) st<=PUT_REQ;
                else if(write_length) st<=LENGTH_REQ;
                else st<=DONE;
            end
            PUT_REQ: if(gnt_i) st<=PUT_WAIT;
            PUT_WAIT: if(ack_i) begin
                if(fault_i) begin fault_o<=1;fault_addr_o<=put_addr;fault_reason_o<=fault_reason_i;st<=FAILED;end
                else if(write_length) st<=LENGTH_REQ;else st<=DONE;
            end
            LENGTH_REQ: if(gnt_i) st<=LENGTH_WAIT;
            LENGTH_WAIT: if(ack_i) begin
                if(fault_i) begin fault_o<=1;fault_addr_o<=header;fault_reason_o<=fault_reason_i;st<=FAILED;end
                else st<=DONE;
            end
            DONE: if(response_ready_i) st<=IDLE;
            FAILED: ; // Fatal bus error: no replay or new admission until reset.
            default: st<=FAILED;
        endcase
    end
endmodule
