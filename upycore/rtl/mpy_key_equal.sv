`include "mpy_abi.svh"

// Callback-free key equality. Exact integers, binary32/complex numeric
// promotion (including the pinned MicroPython int->float rounding), and
// qstr/str/bytes content comparison. OBJECT/aggregate keys remain on the core.
// A complete tagged-value identity match has the core's identity semantics.
// Memory requests hold until ack; callers adapt grant/ack ports exactly once.
module mpy_key_equal (
    input logic clk_i,rst_n_i,valid_i,
    output logic ready_o,
    input logic [35:0] a_i,b_i,
    input logic [31:0] qstr_count_i,qstr_base_i,qstr_ext_i,
    output logic valid_o,
    input logic ready_i,
    output logic equal_o,error_o,
    output logic mem_req_o,
    output logic [31:0] mem_addr_o,
    input logic mem_ack_i,mem_fault_i,
    input logic [31:0] mem_data_i
);
    typedef enum logic [4:0] {IDLE,DISPATCH,LOAD_NUM,NUM_LO,NUM_HI,NUM_NEXT,
        NUM_CONVERT,CONV_ABS,CONV_SCAN,CONV_SHIFT,CONV_ROUND,NUM_COMPARE,STR_LEN,STR_PTR,STR_NEXT,STR_CHECK,
        READ_A,READ_B,BYTES_COMPARE,RESULT} state_t;
    state_t state;
    logic [35:0] a,b;
    logic side,is_float[2];
    logic [63:0] integer_value[2];
    logic [31:0] real_value[2],imag_value[2],length[2],ptr[2];
    logic [31:0] aword,bword,remaining,qcount,qbase,qext;
    // qext - 8 * qcount, taken at accept: a descriptor address is then one
    // add after the table select instead of a subtract and an add
    // (side -> the engine's address, 10.3 ns).
    logic [31:0] qext_off;
    // The descriptor address, a cycle old: STR_PTR follows at least one
    // cycle of STR_LEN on the same side, so its + 4 starts from a flop.
    logic [31:0] desc_r;
    logic [2:0] acount,bcount;
    logic [35:0] current;
    logic [31:0] descriptor;
    always_ff @(posedge clk_i) desc_r<=descriptor;
    logic [63:0] convert_input,magnitude,normalized;
    logic convert_sign,convert_side;
    logic [5:0] exponent_index,leading_index;
    logic [63:0] scan_bits;
    logic [24:0] rounded;
    logic [7:0] exponent_bits;
    // Balanced leading-bit search and separate normalization/rounding stages.
    always_comb begin
        scan_bits=magnitude;leading_index=0;
        if(|scan_bits[63:32])begin leading_index[5]=1;scan_bits=scan_bits>>32;end
        if(|scan_bits[31:16])begin leading_index[4]=1;scan_bits=scan_bits>>16;end
        if(|scan_bits[15:8])begin leading_index[3]=1;scan_bits=scan_bits>>8;end
        if(|scan_bits[7:4])begin leading_index[2]=1;scan_bits=scan_bits>>4;end
        if(|scan_bits[3:2])begin leading_index[1]=1;scan_bits=scan_bits>>2;end
        leading_index[0]=scan_bits[1];
        rounded={1'b0,normalized[63:40]} + (normalized[39] && ((|normalized[38:0]) || normalized[40]));
        exponent_bits=8'd127+{2'b0,exponent_index}+{7'd0,rounded[24]};
    end
    assign current=side ? b : a;
    assign descriptor=current[31:0]<qcount ? qbase+(current[31:0]<<3) : qext_off+(current[31:0]<<3);
    assign ready_o=state==IDLE || (state==RESULT && ready_i);
    assign valid_o=state==RESULT;
    function automatic logic numeric(input logic [35:0] v);
        return v[35:32]==ABI_TAG_INT || v[35:32]==ABI_TAG_INT64 || v[35:32]==ABI_TAG_FLOAT || v[35:32]==ABI_TAG_COMPLEX ||
            (v[35:32]==ABI_TAG_CONTROL && (v[31:0]==ABI_CTL_FALSE || v[31:0]==ABI_CTL_TRUE));
    endfunction
    function automatic logic stringlike(input logic [35:0] v);
        return v[35:32]==ABI_TAG_QSTR || v[35:32]==ABI_TAG_STR;
    endfunction
    function automatic logic float_equal(input logic [31:0] x,y);
        return !(x[30:23]==255 && x[22:0]!=0) && !(y[30:23]==255 && y[22:0]!=0) &&
            (x==y || (x[30:0]==0 && y[30:0]==0));
    endfunction
    task automatic finish(input logic result);
        equal_o<=result;state<=RESULT;
    endtask
    task automatic accept;
        a<=a_i;b<=b_i;side<=0;error_o<=0;equal_o<=0;
        qcount<=qstr_count_i;qbase<=qstr_base_i;qext<=qstr_ext_i;
        qext_off<=qstr_ext_i-(qstr_count_i<<3);
        state<=DISPATCH;
    endtask
    always_comb begin
        mem_req_o=1;mem_addr_o=current[31:0];
        case(state)
            NUM_LO:mem_addr_o=current[31:0];
            NUM_HI:mem_addr_o=current[31:0]+4;
            STR_LEN:mem_addr_o=current[35:32]==ABI_TAG_QSTR ? descriptor : current[31:0];
            STR_PTR:mem_addr_o=current[35:32]==ABI_TAG_QSTR ? desc_r+4 : current[31:0]+8;
            READ_A:mem_addr_o={ptr[0][31:2],2'b00};
            READ_B:mem_addr_o={ptr[1][31:2],2'b00};
            default:mem_req_o=0;
        endcase
    end
    always_ff @(posedge clk_i or negedge rst_n_i)begin
        if(!rst_n_i)begin
            state<=IDLE;a<=0;b<=0;side<=0;equal_o<=0;error_o<=0;
            convert_input<=0;magnitude<=0;normalized<=0;convert_sign<=0;convert_side<=0;exponent_index<=0;
            qcount<=0;qbase<=0;qext<=0;qext_off<=0;aword<=0;bword<=0;remaining<=0;acount<=0;bcount<=0;
            for(int i=0;i<2;i++)begin
                is_float[i]<=0;integer_value[i]<=0;real_value[i]<=0;imag_value[i]<=0;length[i]<=0;ptr[i]<=0;
            end
        end else if(mem_req_o && mem_ack_i && mem_fault_i)begin error_o<=1;finish(0);end
        else case(state)
            IDLE:if(valid_i)accept();
            RESULT:if(ready_i)begin if(valid_i)accept();else state<=IDLE;end
            DISPATCH:if(a==b)finish(1);
                else if(numeric(a) && numeric(b))state<=LOAD_NUM;
                else if((stringlike(a) && stringlike(b)) || (a[35:32]==ABI_TAG_BYTES && b[35:32]==ABI_TAG_BYTES))state<=STR_LEN;
                else finish(0);
            LOAD_NUM:begin
                imag_value[side]<=0;
                case(current[35:32])
                    ABI_TAG_INT:begin is_float[side]<=0;integer_value[side]<={{33{current[30]}},current[30:0]};state<=NUM_NEXT;end
                    ABI_TAG_CONTROL:begin is_float[side]<=0;integer_value[side]<=current[31:0]==ABI_CTL_TRUE ? 64'd1 : 64'd0;state<=NUM_NEXT;end
                    ABI_TAG_FLOAT:begin is_float[side]<=1;real_value[side]<=current[31:0];state<=NUM_NEXT;end
                    default:begin is_float[side]<=current[35:32]==ABI_TAG_COMPLEX;state<=NUM_LO;end
                endcase
            end
            NUM_LO:if(mem_ack_i)begin
                if(is_float[side])real_value[side]<=mem_data_i;else integer_value[side][31:0]<=mem_data_i;
                state<=NUM_HI;
            end
            NUM_HI:if(mem_ack_i)begin
                if(is_float[side])imag_value[side]<=mem_data_i;else integer_value[side][63:32]<=mem_data_i;
                state<=NUM_NEXT;
            end
            NUM_NEXT:if(!side)begin side<=1;state<=LOAD_NUM;end else state<=NUM_CONVERT;
            NUM_CONVERT:if(!is_float[0] && !is_float[1])finish(integer_value[0]==integer_value[1]);
                else if(is_float[0] && is_float[1])state<=NUM_COMPARE;
                else begin
                    convert_side<=is_float[0];
                    convert_input<=is_float[0] ? integer_value[1] : integer_value[0];
                    state<=CONV_ABS;
                end
            CONV_ABS:begin
                convert_sign<=convert_input[63];
                magnitude<=convert_input[63] ? -convert_input : convert_input;
                state<=CONV_SCAN;
            end
            CONV_SCAN:begin exponent_index<=leading_index;state<=CONV_SHIFT;end
            CONV_SHIFT:begin normalized<=magnitude << (~exponent_index);state<=CONV_ROUND;end
            CONV_ROUND:begin
                real_value[convert_side]<=magnitude==0 ? 32'd0 :
                    {convert_sign,exponent_bits,rounded[24] ? rounded[23:1] : rounded[22:0]};
                state<=NUM_COMPARE;
            end
            NUM_COMPARE:finish(float_equal(real_value[0],real_value[1]) && float_equal(imag_value[0],imag_value[1]));
            STR_LEN:if(mem_ack_i)begin length[side]<=current[35:32]==ABI_TAG_QSTR ? {16'd0,mem_data_i[31:16]} : mem_data_i;state<=STR_PTR;end
            STR_PTR:if(mem_ack_i)begin ptr[side]<=current[35:32]==ABI_TAG_QSTR ? {1'b0,mem_data_i[30:0]} : mem_data_i;state<=STR_NEXT;end
            STR_NEXT:if(!side)begin side<=1;state<=STR_LEN;end else state<=STR_CHECK;
            STR_CHECK:if(length[0]!=length[1])finish(0);
                else if(length[0]==0)finish(1);
                else begin remaining<=length[0];acount<=0;bcount<=0;state<=READ_A;end
            READ_A:if(mem_ack_i)begin
                aword<=mem_data_i>>(8*ptr[0][1:0]);acount<=4-{1'b0,ptr[0][1:0]};
                state<=bcount==0 ? READ_B : BYTES_COMPARE;
            end
            READ_B:if(mem_ack_i)begin bword<=mem_data_i>>(8*ptr[1][1:0]);bcount<=4-{1'b0,ptr[1][1:0]};state<=BYTES_COMPARE;end
            BYTES_COMPARE:if(aword[7:0]!=bword[7:0])finish(0);
                else if(remaining==1)finish(1);
                else begin
                    remaining<=remaining-1;ptr[0]<=ptr[0]+1;ptr[1]<=ptr[1]+1;
                    aword<=aword>>8;bword<=bword>>8;acount<=acount-1;bcount<=bcount-1;
                    if(acount==1)state<=READ_A;else if(bcount==1)state<=READ_B;
                end
            default:state<=IDLE;
        endcase
    end
endmodule
