`timescale 1ns/1ps
module tb_mpy_rehash_stream;
    logic clk=0;always #5 clk=~clk;
    logic rst=0,valid=0,is_set=1,stream=1;
    logic [31:0] src=256,sn=67,dst=1024,dn=97,hashes=0;
    logic [1:0] ready,done,fallback,fault,rq,wr;
    logic [1:0][31:0] used,addr,wd;
    logic [1:0][3:0] wt;
    logic gnt=0,ack=0,mfault=0;
    logic [31:0] rd=0;logic [3:0] rt=0;
    logic [35:0] mem[8192],expected[194];
    logic pending=0,pwe;logic [31:0] pa,pd;logic [3:0] pt;
    integer delay_count=0,cycles=0,checks=0,peak=0,begin_cycle,total_cycles=0;
    mpy_rehash_stream dut(.clk_i(clk),.rst_n_i(rst),.valid_i(valid && stream),.ready_o(ready[1]),
        .set_i(is_set),.src_i(src),.sn_i(sn),.dst_i(dst),.dn_i(dn),.hashes_i(hashes),
        .qstr_count_i(32'd0),.qstr_base_i(32'd0),.qstr_ext_i(32'd0),
        .done_o(done[1]),.fallback_o(fallback[1]),.fault_o(fault[1]),.used_o(used[1]),
        .req_o(rq[1]),.we_o(wr[1]),.addr_o(addr[1]),.wdata_o(wd[1]),.wtag_o(wt[1]),
        .gnt_i(gnt && stream),.ack_i(ack && stream),.fault_i(mfault),.rdata_i(rd),.rtag_i(rt));
    mpy_map_engine legacy(.clk_i(clk),.rst_n_i(rst),.valid_i(valid && !stream),.ready_o(ready[0]),
        .op_i(3'd0),.set_i(is_set),.src_i(src),.src_alloc_i(sn),.dst_i(dst),.dst_alloc_i(dn),.used_i(32'd0),.hashes_i(hashes),
        .qstr_count_i(32'd0),.qstr_base_i(32'd0),.qstr_ext_i(32'd0),
        .done_o(done[0]),.admitted_o(),.fallback_o(fallback[0]),.fault_o(fault[0]),.used_o(used[0]),
        .req_o(rq[0]),.we_o(wr[0]),.addr_o(addr[0]),.wdata_o(wd[0]),.wtag_o(wt[0]),
        .gnt_i(gnt && !stream),.ack_i(ack && !stream),.fault_i(mfault),.mem_data_i(rd),.mem_tag_i(rt));
    always @(negedge clk)begin
        cycles++;gnt=0;ack=0;rd='x;rt='x;
        if(pending)begin
            if(delay_count==0)begin
                if(!mfault)begin
                    if(pwe)mem[pa>>2]={pt,pd};else {rt,rd}=mem[pa>>2];
                end
                ack=1;pending=0;
            end else delay_count--;
        end else if(rq[stream] && $urandom_range(0,3)!=0)begin
            gnt=1;pending=1;pa=addr[stream];pd=wd[stream];pt=wt[stream];pwe=wr[stream];
            delay_count=$urandom_range(0,4);
        end
        if(int'(dut.count)>peak)peak=int'(dut.count);
        if(cycles>1000000)$fatal(1,"timeout");
    end
    task automatic clear_mem;
        for(int i=0;i<8192;i++)mem[i]=0;
        for(int i=0;i<194;i++)expected[i]=0;
        src=256;sn=67;dst=1024;dn=97;hashes=0;
    endtask
    task automatic run(input bit reject=0,input bit error=0);
        @(negedge clk);valid=1;begin_cycle=cycles;
        @(negedge clk);valid=0;
        wait(done[stream]);#1;
        if(fallback[stream]!=reject || fault[stream]!=error)$fatal(1,"status reject=%b fault=%b",fallback[stream],fault[stream]);
        if(pending || rq[stream])$fatal(1,"completion before port drain");
        total_cycles+=cycles-begin_cycle;checks++;
        @(negedge clk);
    endtask
    initial begin
        int mode,n,step,p,k;
        logic [31:0] h;
        if($value$plusargs("STREAM=%d",mode))stream=(mode!=0);
        clear_mem();repeat(3)@(negedge clk);rst=1;
        for(int trial=0;trial<12;trial++)begin
            clear_mem();is_set=trial%2==0;step=is_set?1:2;n=trial<2?0:31;
            for(int i=0;i<n;i++)begin
                k=i%3==0 ? -(i*97+1+trial) : i*97+1+trial;
                p=(i*7)%67;
                mem[(src>>2)+p*step]={4'd1,32'(k)};
                if(!is_set)mem[(src>>2)+p*step+1]={4'd1,32'(i+100)};
            end
            // Tombstones and empty slots contribute no entry.
            for(int i=0;i<67;i++)if(mem[(src>>2)+i*step]==0 && i%4==0)mem[(src>>2)+i*step]={4'd0,32'd3};
            for(int i=0;i<67;i++)if(mem[(src>>2)+i*step][35:32]==1)begin
                h=mem[(src>>2)+i*step][31:0];h={h[30],h[30:0]};p=h%dn;
                while(expected[p*step]!=0)p=(p+1)%dn;
                expected[p*step]=mem[(src>>2)+i*step];
                if(!is_set)expected[p*step+1]=mem[(src>>2)+i*step+1];
            end
            run();
            if(used[stream]!=n)$fatal(1,"used mismatch");
            for(int i=0;i<int'(dn)*step;i++)if(mem[(dst>>2)+i]!==expected[i])$fatal(1,"table mismatch trial=%d word=%d",trial,i);
        end
        clear_mem();is_set=1;sn=1;mem[src>>2]={4'd14,32'd3000};hashes=2048;mem[512]={4'd1,32'hffffffff};
        run();if(mem[(dst>>2)+(32'hffffffff%dn)]!={4'd14,32'd3000})$fatal(1,"override");
        clear_mem();sn=2;mem[src>>2]={4'd1,32'd3};mem[(src>>2)+1]={4'd14,32'd3000};
        run(1);
        clear_mem();sn=1;mem[src>>2]={4'd1,32'd3};run();
        if(used[stream]!=1)$fatal(1,"restart after fallback");
        clear_mem();sn=1;dn=2;mem[src>>2]={4'd1,32'd3};mem[dst>>2]={4'd1,32'd1};mem[(dst>>2)+1]={4'd1,32'd2};run(1);
        clear_mem();sn=1;mem[src>>2]={4'd1,32'd3};mfault=1;run(0,1);mfault=0;
        clear_mem();sn=1;mem[src>>2]={4'd1,32'd3};run();
        if(stream && peak<2)$fatal(1,"no overlapping metadata observed");
        $display("PASS mpy_rehash_stream stream=%0d checks=%0d cycles=%0d peak=%0d",stream,checks,total_cycles,peak);$finish;
    end
endmodule
