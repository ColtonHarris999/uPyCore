`timescale 1ns/1ps
module tb_mpy_key_equal;
    logic clk=0;always #5 clk=~clk;
    logic rst=0,valid=0,ready,done,consume=0,equal,error,req,ack=0,fault=0;
    logic [35:0] a=0,b=0;
    logic [31:0] addr,rd=0,mem[2048];
    logic pending=0;logic [31:0] pending_addr;
    integer delay_count=0,checks=0,cycles=0,reads=0;
    mpy_key_equal dut(.clk_i(clk),.rst_n_i(rst),.valid_i(valid),.ready_o(ready),.a_i(a),.b_i(b),
        .qstr_count_i(32'd0),.qstr_base_i(32'd0),.qstr_ext_i(32'd64),
        .valid_o(done),.ready_i(consume),.equal_o(equal),.error_o(error),
        .mem_req_o(req),.mem_addr_o(addr),.mem_ack_i(ack),.mem_fault_i(fault),.mem_data_i(rd));
    always @(negedge clk)begin
        cycles++;ack=0;rd='x;
        if(pending)begin
            if(delay_count==0)begin ack=1;rd=mem[pending_addr>>2];pending=0;reads++;end
            else delay_count--;
        end else if(req)begin
            if(addr[1:0]!=0)$fatal(1,"unaligned equality read");
            pending=1;pending_addr=addr;delay_count=$urandom_range(0,3);
        end
        if(cycles>300000)$fatal(1,"timeout");
    end
    function automatic logic [35:0] vint(input logic [63:0] n,input integer box);
        mem[box>>2]=n[31:0];mem[(box>>2)+1]=n[63:32];
        return {4'd2,32'(box)};
    endfunction
    function automatic logic [35:0] complex_value(input logic [31:0] real_bits,imag_bits,input integer box);
        mem[box>>2]=real_bits;mem[(box>>2)+1]=imag_bits;
        return {4'd4,32'(box)};
    endfunction
    task automatic byte_at(input integer address,input logic [7:0] v);
        mem[address>>2][8*(address%4)+:8]=v;
    endtask
    task automatic check(input logic [35:0] av,bv,input bit expected,input bit expected_error=0);
        @(negedge clk);a=av;b=bv;valid=1;
        @(negedge clk);valid=0;a='x;b='x;
        wait(done);#1;
        if(equal!=expected || error!=expected_error)$fatal(1,"equality a=%h b=%h got=%b error=%b expected=%b",av,bv,equal,error,expected);
        repeat(3)begin @(negedge clk);if(!done || equal!=expected || error!=expected_error)$fatal(1,"unstable held result");end
        consume=1;@(negedge clk);consume=0;checks++;
    endtask
    initial begin
        logic [35:0] av,bv;
        for(int i=0;i<2048;i++)mem[i]=0;
        repeat(3)@(negedge clk);rst=1;
        check({4'd1,32'd1},{4'd0,32'd5},1);
        check({4'd1,32'hffffffff},vint(-64'd1,512),1);
        check(vint(64'h8000000000000000,512),vint(64'h8000000000000001,528),0);
        check(vint(64'h8000000000000000,512),{4'd3,32'hdf000000},1);
        // MicroPython promotes integers to binary32 before mixed comparison.
        check(vint(64'd16777217,512),{4'd3,32'h4b800000},1);
        check(vint(64'd16777219,512),{4'd3,32'h4b800002},1);
        check({4'd1,32'h3fffffff},{4'd3,32'h4e800000},1);
        check({4'd3,32'h80000000},{4'd3,32'd0},1);
        check({4'd3,32'h7f800000},{4'd3,32'hff800000},0);
        check({4'd3,32'h7fc00001},{4'd3,32'h7fc00001},1); // tagged identity
        check({4'd3,32'h7fc00001},{4'd3,32'h7fc00002},0);
        check(complex_value(32'h3f800000,0,512),{4'd0,32'd5},1);
        check(complex_value(32'h3f800000,32'h80000000,512),{4'd3,32'h3f800000},1);
        check(complex_value(32'h3f800000,32'h40000000,512),complex_value(32'h3f800000,32'h40000000,528),1);
        check(complex_value(32'h7fc00001,0,512),complex_value(32'h7fc00001,0,528),0);
        check({4'd0,32'd1},{4'd1,32'd0},0);
        // Exact powers and adjacent integers exercise every normalization shift,
        // rounding carry, sign, and both operand orders with analytic bit patterns.
        check(vint(0,512),{4'd3,32'd0},1);
        for(int k=1;k<63;k++)begin
            logic [63:0] power;
            logic [31:0] bits,above,below;
            power=64'd1<<k;bits=32'(127+k)<<23;
            above=k<=23 ? bits+(32'd1<<(23-k)) : bits;
            below=k<=24 ? ((32'(126+k)<<23) | (32'h800000-(32'd1<<(24-k)))) : bits;
            check(vint(power,512),{4'd3,bits},1);
            check({4'd3,bits|32'h80000000},vint(-power,512),1);
            check(vint(power+1,512),{4'd3,above},1);
            check(vint(-(power+1),512),{4'd3,above|32'h80000000},1);
            check(vint(power-1,512),{4'd3,below},1);
            check({4'd3,below|32'h80000000},vint(-(power-1),512),1);
        end
        for(int len=0;len<13;len++)for(int offa=0;offa<4;offa++)for(int offb=0;offb<4;offb++)begin
            mem[256]=len;mem[257]=123;mem[258]=2048+offa;
            mem[272]=len;mem[273]=123;mem[274]=2304+offb;
            for(int i=0;i<len;i++)begin byte_at(2048+offa+i,8'(65+i));byte_at(2304+offb+i,8'(65+i));end
            check({4'd8,32'd1024},{4'd8,32'd1088},1);
            check({4'd13,32'd1024},{4'd13,32'd1088},1);
            check({4'd13,32'd1024},{4'd8,32'd1088},0);
            mem[22]=(len<<16)|123;mem[23]=(2304+offb)|32'h80000000;
            check({4'd8,32'd1024},{4'd6,32'd3},1);
            if(len>0)begin byte_at(2304+offb+len-1,8'hff);check({4'd8,32'd1024},{4'd6,32'd3},0);end
        end
        fault=1;check(vint(64'd1,512),{4'd1,32'd1},0,1);fault=0;
        check(vint(64'd1,512),{4'd1,32'd1},1);
        $display("PASS mpy_key_equal checks=%0d reads=%0d cycles=%0d",checks,reads,cycles);$finish;
    end
endmodule
