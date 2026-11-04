`timescale 1ns/1ps
module tb_mpy_bulk;
    logic clk=0;always #5 clk=~clk;
    logic rst=0,valid=0,ready,ret,ok,idle,busy,fault;
    logic [31:0] used,check_addr=1024,fault_addr;
    logic check_we=0;
    logic req,we,gnt=0,ack=0;
    logic [31:0] addr,wd,rd=0;logic [3:0] wt,rt=0;
    logic [35:0] mem[1024];
    logic pending=0,pwe;logic [31:0] pa,pd;logic [3:0] pt;
    integer delay_count=0,cycles=0;
    mpy_bulk dut(.clk_i(clk),.rst_n_i(rst),.valid_i(valid),.ready_o(ready),
        .op_i(3'd1),.set_i(1'b1),.src_i(32'd256),.sn_i(32'd17),.dst_i(32'd1024),.dn_i(32'd37),
        .used_i(32'd0),.hashes_i(32'd0),.header_i(32'd2048),.source_header_i(32'd2080),
        .qstr_count_i(32'd0),.qstr_base_i(32'd0),.qstr_ext_i(32'd0),
        .return_o(ret),.ok_o(ok),.idle_o(idle),.used_o(used),
        .chk_addr_i(check_addr),.chk_we_i(check_we),.busy_o(busy),
        .req_o(req),.we_o(we),.addr_o(addr),.wdata_o(wd),.wtag_o(wt),
        .gnt_i(gnt),.ack_i(ack),.fault_i(1'b0),.rdata_i(rd),.rtag_i(rt),
        .fault_o(fault),.fault_addr_o(fault_addr));
    always @(negedge clk) begin
        cycles++;gnt=0;ack=0;rd='x;rt='x;
        if(pending) begin
            if(delay_count==0) begin
                if(pwe)mem[pa>>2]={pt,pd};else {rt,rd}=mem[pa>>2];
                ack=1;pending=0;
            end else delay_count--;
        end else if(req)begin
            gnt=1;pending=1;pa=addr;pd=wd;pt=wt;pwe=we;delay_count=3;
        end
        if(cycles>100000)$fatal(1,"timeout");
    end
    initial begin
        for(integer i=0;i<1024;i++)mem[i]=0;
        for(integer i=0;i<10;i++)mem[64+i]={4'd1,32'(i)};
        repeat(3)@(negedge clk);rst=1;
        @(negedge clk);valid=1;@(negedge clk);valid=0;
        wait(ret);#1;
        if(!ok || idle || !busy)$fatal(1,"must return before completing, with destination locked");
        check_addr=256;check_we=0;#1;if(busy)$fatal(1,"source read unnecessarily locked");
        check_we=1;#1;if(!busy)$fatal(1,"source write not locked");
        check_addr=2048;check_we=0;#1;if(!busy)$fatal(1,"header not locked");
        wait(req && we && addr==2048);@(posedge clk);#1;
        if(idle)$fatal(1,"idle before final write ack");
        wait(idle);#1;
        if(fault || used!=10 || mem[512]!={4'd1,32'd10} || busy)$fatal(1,"retirement");
        for(integer i=0;i<10;i++)if(mem[256+i]!={4'd1,32'(i)})$fatal(1,"copy");
        $display("PASS mpy_bulk cycles=%0d",cycles);$finish;
    end
endmodule
