// Byte memmove with word-sized groups, or in-place tagged-word reversal. Read/modify/write preserves both bytes
// outside the requested range and the destination's tag. One transaction is
// outstanding; the caller locks complete intersecting words until idle.
// Reversal takes an aligned start and a byte length divisible by four.
module mpy_bytecopy (
    input logic clk_i,rst_n_i,valid_i,reverse_i,
    output logic ready_o,idle_o,
    input logic [31:0] src_i,dst_i,n_i,
    output logic req_o,we_o,
    output logic [31:0] addr_o,wdata_o,
    output logic [3:0] wtag_o,
    input logic gnt_i,ack_i,fault_i,
    input logic [31:0] rdata_i,
    input logic [3:0] rtag_i,
    output logic fault_o,
    output logic [31:0] fault_addr_o
);
    typedef enum logic [3:0] {IDLE,SETUP,READ_SRC,SRC_ACK,READ_DST,DST_ACK,WRITE,WRITE_ACK,WRITE_RIGHT,RIGHT_ACK} state_t;
    state_t state;
    logic back,reverse_words;
    logic [31:0] left_data;logic [3:0] left_tag;
    logic [31:0] source,dest,remaining,sa,da,piece,mask;
    logic [2:0] group_n,next_n,src_room,dst_room;
    logic [1:0] src_offset,dst_offset;
    assign ready_o=state==IDLE && !fault_o;
    assign idle_o=state==IDLE;
    assign req_o=state==READ_SRC || state==READ_DST || state==WRITE || state==WRITE_RIGHT;
    assign we_o=state==WRITE || state==WRITE_RIGHT;
    assign addr_o=state==READ_SRC || state==SRC_ACK || (reverse_words && (state==WRITE || state==WRITE_ACK)) ? {sa[31:2],2'b00} : {da[31:2],2'b00};
    always_comb begin
        // Low two bits only. A 32-bit source-1 here was a ripple in front of
        // the SETUP address subtract (back -> da, 15.0 ns post-route).
        src_offset=back ? source[1:0]-2'd1 : source[1:0];
        dst_offset=back ? dest[1:0]-2'd1 : dest[1:0];
        src_room=back ? {1'b0,src_offset}+3'd1 : 3'd4-{1'b0,src_offset};
        dst_room=back ? {1'b0,dst_offset}+3'd1 : 3'd4-{1'b0,dst_offset};
        next_n=src_room<dst_room ? src_room : dst_room;
        // remaining<next_n with next_n at most 4: the high bits are all zero
        // and the low three compare. As a 32-bit compare behind the room
        // select it led SETUP's subtract into sa and da.
        if(remaining[31:3]==29'd0 && remaining[2:0]<next_n)next_n=remaining[2:0];
    end
    // Address arithmetic is a prefix add, computed beside the state mux.
    // Folding it into the mux is what made head/back -> dest/da a 32-bit
    // ripple at 15 ns after routing.
    logic dst_gt, dst_ge;
    logic [31:0] src_plus_n, dst_plus_n, dst_plus_n_m4;
    logic [31:0] src_minus_n, dst_minus_n;
    logic [31:0] src_plus_g, src_minus_g, dst_plus_g, dst_minus_g;
    logic [31:0] src_plus_4, dst_minus_4, rem_minus_g, rem_minus_1;
    upycore_add #(.W(32)) u_sn  (.a_i(src_i), .b_i(n_i), .cin_i(1'b0), .sum_o(src_plus_n), .cout_o());
    upycore_add #(.W(32)) u_dn  (.a_i(dst_i), .b_i(n_i), .cin_i(1'b0), .sum_o(dst_plus_n), .cout_o());
    // dst+n-4 is one carry-save and one prefix. A second hard adder on
    // dst+n cannot be folded back into it, and this is the IDLE update
    // that routed at 15.1 ns (head -> dest).
    upycore_sum3 #(.W(32)) u_dm (
        .a_i(dst_i), .b_i(n_i), .c_i(32'hffff_fffc), .cin_i(1'b0), .sum_o(dst_plus_n_m4));
    upycore_add #(.W(32)) u_gt  (.a_i(dst_i), .b_i(~src_i), .cin_i(1'b1), .sum_o(), .cout_o(dst_ge));
    assign dst_gt = dst_ge && (dst_i != src_i);
    upycore_add #(.W(32)) u_sm  (.a_i(source), .b_i(~{29'b0, next_n}), .cin_i(1'b1), .sum_o(src_minus_n), .cout_o());
    upycore_add #(.W(32)) u_dmn (.a_i(dest), .b_i(~{29'b0, next_n}), .cin_i(1'b1), .sum_o(dst_minus_n), .cout_o());
    upycore_add #(.W(32)) u_sg  (.a_i(source), .b_i({29'b0, group_n}), .cin_i(1'b0), .sum_o(src_plus_g), .cout_o());
    upycore_add #(.W(32)) u_sgm (.a_i(source), .b_i(~{29'b0, group_n}), .cin_i(1'b1), .sum_o(src_minus_g), .cout_o());
    upycore_add #(.W(32)) u_dg  (.a_i(dest), .b_i({29'b0, group_n}), .cin_i(1'b0), .sum_o(dst_plus_g), .cout_o());
    upycore_add #(.W(32)) u_dgm (.a_i(dest), .b_i(~{29'b0, group_n}), .cin_i(1'b1), .sum_o(dst_minus_g), .cout_o());
    upycore_add #(.W(32)) u_s4  (.a_i(source), .b_i(32'd4), .cin_i(1'b0), .sum_o(src_plus_4), .cout_o());
    upycore_add #(.W(32)) u_d4  (.a_i(dest), .b_i(32'hffff_fffc), .cin_i(1'b0), .sum_o(dst_minus_4), .cout_o());
    upycore_add #(.W(32)) u_rg  (.a_i(remaining), .b_i(~{29'b0, group_n}), .cin_i(1'b1), .sum_o(rem_minus_g), .cout_o());
    upycore_add #(.W(32)) u_r1  (.a_i(remaining), .b_i(32'hffff_ffff), .cin_i(1'b0), .sum_o(rem_minus_1), .cout_o());
    always_ff @(posedge clk_i or negedge rst_n_i)begin
        if(!rst_n_i)begin
            state<=IDLE;back<=0;reverse_words<=0;left_data<=0;left_tag<=0;source<=0;dest<=0;remaining<=0;sa<=0;da<=0;
            piece<=0;mask<=0;group_n<=0;wdata_o<=0;wtag_o<=0;fault_o<=0;fault_addr_o<=0;
        end else if(ack_i && fault_i)begin
            fault_o<=1;fault_addr_o<=addr_o;state<=IDLE;
        end else case(state)
            IDLE:if(valid_i && ready_o && n_i!=0 && (!reverse_i || n_i>=8))begin
                reverse_words<=reverse_i;back<=dst_gt;
                source<=!reverse_i && dst_gt ? src_plus_n : src_i;
                dest<=reverse_i ? dst_plus_n_m4 : dst_gt ? dst_plus_n : dst_i;
                remaining<=reverse_i ? n_i>>3 : n_i;state<=SETUP;
            end
            SETUP:if(reverse_words)begin sa<=source;da<=dest;state<=READ_SRC;end else begin
                group_n<=next_n;
                sa<=back ? src_minus_n : source;
                da<=back ? dst_minus_n : dest;
                case(next_n)
                    1:mask<=32'hff;
                    2:mask<=32'hffff;
                    3:mask<=32'hffffff;
                    default:mask<=32'hffffffff;
                endcase
                state<=READ_SRC;
            end
            READ_SRC:if(gnt_i)state<=SRC_ACK;
            SRC_ACK:if(ack_i)begin left_data<=rdata_i;left_tag<=rtag_i;piece<=rdata_i>>(8*sa[1:0]);state<=READ_DST;end
            READ_DST:if(gnt_i)state<=DST_ACK;
            DST_ACK:if(ack_i)begin
                wdata_o<=reverse_words ? rdata_i : (rdata_i & ~(mask<<(8*da[1:0]))) | ((piece & mask)<<(8*da[1:0]));
                wtag_o<=rtag_i;state<=WRITE;
            end
            WRITE:if(gnt_i)state<=WRITE_ACK;
            WRITE_ACK:if(ack_i && reverse_words)begin
                wdata_o<=left_data;wtag_o<=left_tag;state<=WRITE_RIGHT;
            end else if(ack_i)begin
                remaining<=rem_minus_g;
                source<=back ? src_minus_g : src_plus_g;
                dest<=back ? dst_minus_g : dst_plus_g;
                state<=remaining==32'(group_n) ? IDLE : SETUP;
            end
            WRITE_RIGHT:if(gnt_i)state<=RIGHT_ACK;
            RIGHT_ACK:if(ack_i)begin
                remaining<=rem_minus_1;source<=src_plus_4;dest<=dst_minus_4;
                state<=remaining==1 ? IDLE : SETUP;
            end
            default:state<=IDLE;
        endcase
    end
endmodule
