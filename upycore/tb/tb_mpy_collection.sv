`timescale 1ns/1ps
module tb_mpy_collection;
    logic clk=0;always #5 clk=~clk;
    logic [2:0] operation=1;
    logic byte_mode=0;
    logic rst=0,cv=0,cr,bv=0,br,ret,ok,idle,busy,fault;
    logic [31:0] cs=0,cd=0,cn=0,bs=256,bd=1024,sn=17,dn=37,used=0,hdr=2048,shdr=2080;
    logic [31:0] result,hashes=0,chk=0,fault_addr,words,cmds;
    logic chkwe=0,req,we,gnt=0,ack=0,inject_fault=0;
    logic [31:0] addr,wd,rd=0;logic [3:0] wt,rt=0,reason;
    logic [35:0] mem[4096];
    logic pending=0,pwe;
    logic [31:0] pa,pd;logic [3:0] pt;
    integer delay_count=0,cycles=0,returns=0;
    mpy_collection #(.TYPE_CACHE(0)) dut(.clk_i(clk),.rst_n_i(rst),
        .copy_reverse_i(1'b0),.copy_byte_i(byte_mode),.copy_valid_i(cv),.copy_ready_o(cr),.copy_src_i(cs),.copy_dst_i(cd),.copy_n_i(cn),
        .bulk_valid_i(bv),.bulk_ready_o(br),.bulk_op_i(operation),.bulk_set_i(1'b1),
        .bulk_src_i(bs),.bulk_sn_i(sn),.bulk_dst_i(bd),.bulk_dn_i(dn),.bulk_used_i(used),.bulk_hashes_i(hashes),
        .bulk_header_i(hdr),.bulk_source_header_i(shdr),
        .qstr_count_i(32'd0),.qstr_base_i(32'd0),.qstr_ext_i(32'd0),
        .bulk_return_o(ret),.bulk_ok_o(ok),.bulk_used_o(result),.idle_o(idle),
        .chk_addr_i(chk),.chk_we_i(chkwe),.chk_busy_o(busy),
        .req_o(req),.we_o(we),.addr_o(addr),.wdata_o(wd),.wtag_o(wt),
        .gnt_i(gnt),.ack_i(ack),.fault_i(inject_fault),.fault_reason_i(4'd3),.rdata_i(rd),.rtag_i(rt),
        .fault_o(fault),.fault_reason_o(reason),.fault_addr_o(fault_addr),.words_o(words),.cmds_o(cmds));
    always @(negedge clk) begin
        cycles++;gnt=0;ack=0;rd='x;rt='x;
        if(pending) begin
            if(delay_count==0) begin
                if(!inject_fault) begin
                    if(pwe)mem[pa>>2]={pt,pd};else {rt,rd}=mem[pa>>2];
                end
                ack=1;pending=0;
            end else delay_count--;
        end else if(req && $urandom_range(0,3)!=0)begin
            gnt=1;pending=1;pa=addr;pd=wd;pt=wt;pwe=we;delay_count=$urandom_range(0,4);
        end
        if(cycles>20000)$fatal(1,"timeout");
    end
    always @(posedge clk)if(ret)begin
        if(!ok)$fatal(1,"unexpected rejection");
        returns++;
    end
    task automatic copy(input integer source,dest,n,input bit bytes_command=0);
        @(negedge clk);cs=source;cd=dest;cn=n;cv=1;byte_mode=bytes_command;
        do @(posedge clk);while(!cr);
        @(negedge clk);cv=0;
    endtask
    task automatic bulk;
        @(negedge clk);bv=1;
        do @(posedge clk);while(!br);
        @(negedge clk);bv=0;
    endtask
    task automatic check_busy(input integer a,input bit w,input bit expect_busy);
        chk=a;chkwe=w;#1;if(busy!=expect_busy)$fatal(1,"scoreboard addr=%d write=%b got=%b",a,w,busy);
    endtask
    initial begin
        for(integer i=0;i<4096;i++)mem[i]=0;
        for(integer i=0;i<10;i++)mem[64+i]={4'd1,32'(i)};
        repeat(3)@(negedge clk);rst=1;
        bulk();wait(ret);#1;if(idle)$fatal(1,"early completion");
        copy(1024,3072,37);
        if(cr || br)$fatal(1,"shared queue must be full");
        check_busy(3072,0,1);check_busy(256,1,1);check_busy(256,0,0);
        // Held third command must not be lost or accepted before space opens.
        copy(3072,4096,37);
        wait(idle);#1;
        if(fault || returns!=1 || mem[512]!={4'd1,32'd10})$fatal(1,"bulk retirement");
        for(integer i=0;i<37;i++) begin
            if(mem[768+i]!==mem[256+i] || mem[1024+i]!==mem[256+i])$fatal(1,"dependent copy order");
        end
        if(cmds!=2 || words!=74)$fatal(1,"copy counters");
        // Copy first, then bulk: source contents must be observed after copy.
        for(integer i=0;i<17;i++)mem[64+i]=0;
        for(integer i=0;i<37;i++)mem[256+i]=0;
        for(integer i=0;i<17;i++)mem[1536+i]=i<5 ? {4'd1,32'(20+i)} : 36'd0;
        copy(6144,256,17);bulk();
        check_busy(2048,0,1);check_busy(256,1,1);
        wait(idle);#1;
        if(returns!=2 || mem[512]!={4'd1,32'd5})$fatal(1,"copy then bulk");
        for(integer i=20;i<25;i++)if(mem[256+i]!={4'd1,32'(i)})$fatal(1,"new source not observed");
        // Rehash uses the shared hash block through the elastic pipeline.
        for(integer i=0;i<17;i++)mem[64+i]=0;
        for(integer i=0;i<37;i++)mem[256+i]=0;
        mem[64]={4'd6,32'd3};mem[6]={4'd0,32'd7};
        mem[65]={4'd8,32'd3000};mem[751]={4'd0,32'd11};
        mem[66]={4'd4,32'd3200};mem[800]={4'd0,32'h40400000};mem[801]={4'd0,32'h40000000};
        operation=0;hdr=0;bulk();wait(idle);#1;
        if(result!=3 || mem[263]!={4'd6,32'd3} || mem[267]!={4'd8,32'd3000} || mem[257]!={4'd4,32'd3200})$fatal(1,"shared pipeline hashing");
        // The serial merger subsequently takes ownership of the same hash unit.
        for(integer i=0;i<17;i++)mem[64+i]=0;
        for(integer i=0;i<37;i++)mem[256+i]=0;
        mem[64]={4'd6,32'd3};mem[263]={4'd6,32'd3};
        operation=1;hdr=2048;used=1;bulk();wait(idle);#1;
        if(result!=1 || mem[512]!={4'd1,32'd1} || returns!=4)$fatal(1,"shared merge hashing");
        // Core-precomputed hashes can insert callback keys into a live table.
        // Protect the argument-buffer sidecar and publish the cumulative count.
        mem[64]={4'd14,32'd5000};mem[1200]={4'd1,32'd7};
        operation=0;hashes=4800;sn=1;used=1;bulk();
        check_busy(4800,1,1);check_busy(4800,0,0);
        wait(idle);#1;
        if(result!=2 || mem[512]!={4'd1,32'd2} || mem[264]!={4'd14,32'd5000})$fatal(1,"prepared hash insertion/count");
        check_busy(4800,1,0);hashes=0;
        // An unaligned byte operation participates in the same queue. Partial
        // destination words are locked, and their tags/untouched bytes survive.
        mem[1500]={4'd7,32'h44332211};mem[1501]={4'd8,32'h88776655};
        mem[1550]={4'd9,32'haaaaaaaa};mem[1551]={4'd10,32'hbbbbbbbb};
        copy(6001,6202,5,1);check_busy(6200,0,1);check_busy(6000,1,1);
        copy(6200,6400,2);wait(idle);#1;
        if(mem[1550]!={4'd9,32'h3322aaaa} || mem[1551]!={4'd10,32'hbb665544})$fatal(1,"queued byte data/tags");
        if(mem[1600]!==mem[1550] || mem[1601]!==mem[1551])$fatal(1,"byte then word dependency");
        // Zero-length copy still retires its FIFO entry without memory requests.
        copy(0,0,0);wait(idle);
        // A fault cancels queued work and prevents further accepts.
        copy(6144,256,17);copy(256,7168,17);
        inject_fault=1;wait(fault);repeat(10)@(negedge clk);
        if(cr || br || req)$fatal(1,"fault did not stop queue");
        for(integer i=0;i<17;i++)if(mem[1792+i]!=0)$fatal(1,"faulted queue executed successor");
        rst=0;pending=0;inject_fault=0;repeat(3)@(negedge clk);rst=1;
        #1;if(!idle || fault)$fatal(1,"reset did not clear queue");
        $display("PASS mpy_collection cycles=%0d",cycles);$finish;
    end
endmodule
