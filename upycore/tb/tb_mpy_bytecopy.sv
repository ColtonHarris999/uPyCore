`timescale 1ns/1ps
module tb_mpy_bytecopy;
    logic clk=0;always #5 clk=~clk;
    logic reverse_mode=0;
    logic rst=0,valid=0,ready,idle,req,we,gnt=0,ack=0,fault=0,failed;
    logic [31:0] src,dst,n,addr,wd,rd=0,fa;
    logic [3:0] wt,rt=0;
    logic [35:0] mem[256],expected[256];
    logic [7:0] saved[256];
    logic pending=0,pwe;logic [31:0] pa,pd;logic [3:0] pt;
    integer delay_count=0,cycles=0,checks=0;
    mpy_bytecopy dut(.clk_i(clk),.rst_n_i(rst),.reverse_i(reverse_mode),.valid_i(valid),.ready_o(ready),.idle_o(idle),
        .src_i(src),.dst_i(dst),.n_i(n),.req_o(req),.we_o(we),.addr_o(addr),.wdata_o(wd),.wtag_o(wt),
        .gnt_i(gnt),.ack_i(ack),.fault_i(fault),.rdata_i(rd),.rtag_i(rt),.fault_o(failed),.fault_addr_o(fa));
    always @(negedge clk)begin
        cycles++;gnt=0;ack=0;rd='x;rt='x;
        if(pending)begin
            if(delay_count==0)begin
                if(!fault)begin if(pwe)mem[pa>>2]={pt,pd};else {rt,rd}=mem[pa>>2];end
                pending=0;ack=1;
            end else delay_count--;
        end else if(req && $urandom_range(0,3)!=0)begin
            pending=1;pa=addr;pd=wd;pt=wt;pwe=we;gnt=1;delay_count=$urandom_range(0,4);
        end
        if(cycles>1000000)$fatal(1,"timeout");
    end
    task automatic run(input integer source,dest,count);
        for(integer i=0;i<256;i++)begin mem[i]={4'(i),32'($urandom)};expected[i]=mem[i];end
        for(integer i=0;i<count;i++)saved[i]=8'(mem[(source+i)>>2]>>(8*((source+i)&3)));
        for(integer i=0;i<count;i++)expected[(dest+i)>>2][8*((dest+i)&3)+:8]=saved[i];
        @(negedge clk);src=source;dst=dest;n=count;valid=1;
        @(negedge clk);valid=0;
        wait(idle);#1;
        if(failed || pending)$fatal(1,"bad retirement");
        for(integer i=0;i<256;i++)if(mem[i]!==expected[i])$fatal(1,"byte/tag mismatch src=%d dst=%d n=%d word=%d",source,dest,count,i);
        checks++;
    endtask
    initial begin
        repeat(3)@(negedge clk);rst=1;
        for(integer a=0;a<4;a++)for(integer b=0;b<4;b++)for(integer count=0;count<18;count++)begin
            run(128+a,512+b,count);run(512+a,128+b,count);
        end
        for(integer offset=0;offset<12;offset++)begin
            run(128,128+offset,67);run(128+offset,128,67);
        end
        for(integer k=0;k<40;k++)run(128+$urandom_range(0,63),128+$urandom_range(0,63),$urandom_range(0,128));
        for(integer count=0;count<34;count++)begin
            for(integer i=0;i<256;i++)begin mem[i]={4'(i),32'($urandom)};expected[i]=mem[i];end
            for(integer i=0;i<count;i++)expected[32+i]=mem[32+count-1-i];
            @(negedge clk);reverse_mode=1;src=128;dst=128;n=count*4;valid=1;
            @(negedge clk);valid=0;wait(idle);#1;
            for(integer i=0;i<256;i++)if(mem[i]!==expected[i])$fatal(1,"tagged reversal n=%d word=%d",count,i);
            checks++;
        end
        reverse_mode=0;
        @(negedge clk);src=128;dst=512;n=16;valid=1;fault=1;
        @(negedge clk);valid=0;wait(failed);#1;
        if(!idle || ready || req)$fatal(1,"fault retirement");
        rst=0;repeat(3)@(negedge clk);fault=0;rst=1;run(129,514,31);
        $display("PASS mpy_bytecopy checks=%0d cycles=%0d",checks,cycles);$finish;
    end
endmodule
