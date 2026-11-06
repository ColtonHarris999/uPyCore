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
    typedef enum logic [3:0] {IDLE, READ_REQ, READ_WAIT, WRITE_REQ, WRITE_WAIT,
        CLEAR_REQ, CLEAR_WAIT, PUT_REQ, PUT_WAIT, LENGTH_REQ, LENGTH_WAIT,
        DONE, FAILED} state_t;
    state_t st;
    logic [35:0] buffer [0:MAX_ELEMS-1];
    logic [CW-1:0] count, index;
    logic [31:0] src, dst, read_addr, write_addr, clear_addr, put_addr, header, new_length;
    logic reverse_words, clear_tail, put_value, write_length;
    logic [35:0] value;
    logic [32:0] source_end, source_low, dest_end;
    logic [32:0] cmd_span, cmd_low, cmd_high, cmd_dst_end;
    always_comb begin
        cmd_span = (n_i == 0) ? 33'd0 : (({1'b0,n_i}-33'd1)<<2);
        cmd_low = reverse_i ? ({1'b0,src_i}-cmd_span) : {1'b0,src_i};
        cmd_high = reverse_i ? ({1'b0,src_i}+33'd4) : ({1'b0,src_i}+({1'b0,n_i}<<2));
        cmd_dst_end = {1'b0,dst_i}+({1'b0,n_i}<<2);
        ready_o = st==IDLE;
        idle_o = st==IDLE;
        response_o = st==DONE;
        req_o = st==READ_REQ || st==WRITE_REQ || st==CLEAR_REQ || st==PUT_REQ || st==LENGTH_REQ;
        we_o = st!=READ_REQ;
        addr_o = read_addr;
        wdata_o = 32'd0; wtag_o = 4'd0;
        case (st)
            WRITE_REQ,WRITE_WAIT: begin
                addr_o=write_addr; wdata_o=buffer[index][31:0]; wtag_o=buffer[index][35:32];
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
            if(write_length && chk_addr_i>=header && {1'b0,chk_addr_i}<{1'b0,header}+33'd12) chk_busy_o=1;
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
            st<=IDLE;count<=0;index<=0;src<=0;dst<=0;read_addr<=0;write_addr<=0;
            clear_addr<=0;put_addr<=0;header<=0;new_length<=0;
            reverse_words<=0;clear_tail<=0;put_value<=0;write_length<=0;value<=0;
            source_low<=0;source_end<=0;dest_end<=0;
            fault_o<=0;fault_addr_o<=0;fault_reason_o<=0;
        end else case(st)
            IDLE: if(valid_i) begin
                src<=src_i;dst<=dst_i;count<=CW'(n_i);index<=0;
                read_addr<=src_i;write_addr<=dst_i;reverse_words<=reverse_i;
                clear_tail<=clear_i;clear_addr<=clear_addr_i;put_value<=put_i;
                put_addr<=put_addr_i;value<=put_value_i;write_length<=length_i;
                header<=header_i;new_length<=new_length_i;
                source_low<=n_i==0 ? 33'd0 : cmd_low;
                source_end<=n_i==0 ? 33'd0 : cmd_high;dest_end<=cmd_dst_end;
                if(n_i>MAX_ELEMS || (n_i!=0 && (src_i[1:0]!=0 || dst_i[1:0]!=0 ||
                   cmd_low[32] || cmd_high[32] || cmd_dst_end[32])) ||
                   (clear_i && clear_addr_i[1:0]!=0) || (put_i && put_addr_i[1:0]!=0) ||
                   (length_i && (header_i[1:0]!=0 || header_i>32'hfffffff3))) begin
                    fault_o<=1;fault_addr_o<=src_i;fault_reason_o<=MPY_FAULT_BUS;st<=FAILED;
                end else if(n_i!=0) st<=READ_REQ;
                else if(clear_i) st<=CLEAR_REQ;
                else if(put_i) st<=PUT_REQ;
                else if(length_i) st<=LENGTH_REQ;
                else st<=DONE;
            end
            READ_REQ: if(gnt_i) st<=READ_WAIT;
            READ_WAIT: if(ack_i) begin
                if(fault_i) begin fault_o<=1;fault_addr_o<=read_addr;fault_reason_o<=fault_reason_i;st<=FAILED;end
                else begin
                    buffer[index]<={rtag_i,rdata_i};
                    if(index+1==count) begin index<=0;st<=WRITE_REQ;end
                    else begin index<=index+1'b1;read_addr<=reverse_words ? read_addr-32'd4 : read_addr+32'd4;st<=READ_REQ;end
                end
            end
            WRITE_REQ: if(gnt_i) st<=WRITE_WAIT;
            WRITE_WAIT: if(ack_i) begin
                if(fault_i) begin fault_o<=1;fault_addr_o<=write_addr;fault_reason_o<=fault_reason_i;st<=FAILED;end
                else if(index+1==count) finish_items();
                else begin index<=index+1'b1;write_addr<=write_addr+32'd4;st<=WRITE_REQ;end
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
