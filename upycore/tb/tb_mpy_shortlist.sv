`timescale 1ns/1ps
`include "mpy_defs.svh"
`include "mpy_abi.svh"
module tb_mpy_shortlist #(parameter int MAX_ELEMS=16);
    logic clk=0;always #5 clk=~clk;
    logic rst=0,valid=0,ready,response,accept=0,idle,req,we,gnt=0,ack=0,fault=0,failed;
    logic reverse_mode=0,clear_mode=0,put_mode=0,length_mode=0;
    logic [31:0] src=128,dst=512,n=0,clear_addr=700,put_addr=704,header=708,new_length=0;
    logic [35:0] put_value;
    logic [31:0] addr,wd,rd=0,fa;logic [3:0] wt,rt=0,reason;
    logic [31:0] check_addr;logic check_we=0,check_busy;
    logic [35:0] mem[256],expected[256],saved[16];
    logic pending=0,pwe;logic [31:0] pa,pd;logic [3:0] pt;
    integer delay_count=0,cycles=0,checks=0,transactions=0,inject=-1;
    mpy_shortlist #(.MAX_ELEMS(MAX_ELEMS)) dut(.clk_i(clk),.rst_n_i(rst),
        .valid_i(valid),.ready_o(ready),.src_i(src),.dst_i(dst),.n_i(n),.reverse_i(reverse_mode),
        .clear_i(clear_mode),.clear_addr_i(clear_addr),.put_i(put_mode),.put_addr_i(put_addr),.put_value_i(put_value),
        .length_i(length_mode),.header_i(header),.new_length_i(new_length),
        .response_o(response),.response_ready_i(accept),.idle_o(idle),
        .chk_addr_i(check_addr),.chk_we_i(check_we),.chk_busy_o(check_busy),
        .req_o(req),.we_o(we),.addr_o(addr),.wdata_o(wd),.wtag_o(wt),
        .gnt_i(gnt),.ack_i(ack),.fault_i(fault),.fault_reason_i(4'd1),.rdata_i(rd),.rtag_i(rt),
        .fault_o(failed),.fault_addr_o(fa),.fault_reason_o(reason));
    always @(negedge clk) begin
        cycles++;gnt=0;ack=0;fault=0;
        if(!rst)begin pending=0;transactions=0;end
        else if(pending)begin
            if(delay_count==0)begin
                fault=transactions==inject;
                if(!fault)begin if(pwe)mem[pa>>2]={pt,pd};else {rt,rd}=mem[pa>>2];end
                pending=0;ack=1;
            end else delay_count--;
        end else if(req && $urandom_range(0,3)!=0)begin
            pending=1;pa=addr;pd=wd;pt=wt;pwe=we;gnt=1;delay_count=$urandom_range(0,4);transactions++;
        end
        if(cycles>3000000)$fatal(1,"timeout");
    end
    logic stalled=0;
    logic [68:0] held;
    always @(posedge clk)begin
        if(!rst)stalled<=0;
        else begin
            // A fatal fault may withdraw a request that was still waiting.
            if(stalled && !failed && (!req || {we,addr,wt,wd}!==held))$fatal(1,"request changed before grant");
            stalled<=req && !gnt;
            if(req && !gnt)held<={we,addr,wt,wd};
        end
    end
    task automatic reset_unit();
        @(negedge clk);rst=0;valid=0;accept=0;
        repeat(3)@(negedge clk);rst=1;
    endtask
    task automatic run(input integer source,dest,count,input bit rev,clr,put,len);
        for(integer i=0;i<256;i++)begin mem[i]={4'(i),32'($urandom)};expected[i]=mem[i];end
        for(integer i=0;i<count;i++)saved[i]=mem[(source+(rev?-4*i:4*i))>>2];
        for(integer i=0;i<count;i++)expected[(dest>>2)+i]=saved[i];
        if(clr)expected[clear_addr>>2]={ABI_TAG_CONTROL,ABI_CTL_NULL};
        if(put)expected[put_addr>>2]=put_value;
        if(len)expected[header>>2]={ABI_TAG_INT,new_length};
        @(negedge clk);src=source;dst=dest;n=count;reverse_mode=rev;
        clear_mode=clr;put_mode=put;length_mode=len;valid=1;accept=0;
        @(negedge clk);valid=0;
        wait(response);#1;
        if(failed || pending || idle || ready || req)$fatal(1,"bad retirement");
        // The final write has acknowledged, and response backpressure retains
        // ownership without issuing extra stores or accepting a second command.
        repeat(4)begin @(negedge clk);if(!response||idle||ready||req)$fatal(1,"response not held");end
        for(integer i=0;i<256;i++)if(mem[i]!==expected[i])$fatal(1,"mismatch src=%d dst=%d n=%d rev=%d word=%d",source,dest,count,rev,i);
        @(negedge clk);accept=1;@(negedge clk);accept=0;
        if(!idle)$fatal(1,"did not release");checks++;
    endtask
    initial begin
        check_addr=512;put_value={4'd14,32'h20001234};new_length=7;
        reset_unit();
        for(integer count=0;count<=MAX_ELEMS;count++)begin
            run(128,512,count,0,0,0,0);
            run(128+4*(count?count-1:0),512,count,1,0,0,0);
            for(integer offset=0;offset<5;offset++)begin
                run(128,128+4*offset,count,0,0,0,0);
                run(128+4*offset,128,count,0,0,0,0);
            end
            run(128,132,count,0,1,0,1);
            run(128,132,count,0,0,1,1);
        end
        for(integer i=0;i<100;i++)run(128+4*$urandom_range(0,16),128+4*$urandom_range(0,16),$urandom_range(0,MAX_ELEMS),0,1,1,1);
        // Fault each read, each write, clear, insertion store and length commit.
        for(integer k=1;k<=11;k++)begin
            reset_unit();inject=k;
            @(negedge clk);src=128;dst=512;n=4;reverse_mode=0;
            clear_mode=1;put_mode=1;length_mode=1;valid=1;
            @(negedge clk);valid=0;wait(failed);#1;
            if(response||ready||req||!check_busy||reason!=1||fa!=pa)$fatal(1,"fault not latched/locked/addressed");
            repeat(3)@(negedge clk);
        end
        inject=-1;reset_unit();
        @(negedge clk);src=0;dst=512;n=2;reverse_mode=1;valid=1;
        @(negedge clk);valid=0;wait(failed);#1;
        if(req||response)$fatal(1,"invalid command accessed memory");
        reset_unit();run(128,512,MAX_ELEMS,0,0,0,0);
        $display("PASS mpy_shortlist checks=%0d cycles=%0d max=%0d",checks,cycles,MAX_ELEMS);$finish;
    end
endmodule
