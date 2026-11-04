`timescale 1ns/1ps
module tb_mpy_map_engine #(parameter bit TYPE_CACHE=0);
    logic cache_clear=0,cache_write=0,cache_write2=0;logic [31:0] cache_addr=0;
    logic clk=0; always #5 clk=~clk;
    logic rst=0, valid=0, ready, done, fallback, fault;
    logic [2:0] op=0;
    logic is_set=1;
    logic [31:0] src=256, sn=17, dst=1024, dn=37, used=0, hashes=0, result;
    logic req,we,gnt=0,ack=0,mfault=0;
    logic [31:0] addr,wd,rd=0; logic [3:0] wt,rt=0;
    logic [35:0] mem[4096];
    logic pending=0, pwe; logic [31:0] pa,pd; logic [3:0] pt;
    integer delay_count=0, cycles=0, writes=0, checks=0;
    mpy_map_engine #(.TYPE_CACHE(TYPE_CACHE)) dut(
        .cache_clear_i(cache_clear),.cache_write_i(cache_write),.cache_addr_i(cache_addr),
        .cache_write2_i((req && gnt && we) || cache_write2),.cache_addr2_i(cache_write2 ? cache_addr : addr),.clk_i(clk),.rst_n_i(rst),.valid_i(valid),.ready_o(ready),
        .op_i(op),.set_i(is_set),.src_i(src),.src_alloc_i(sn),.dst_i(dst),.dst_alloc_i(dn),
        .used_i(used),.hashes_i(hashes),.qstr_count_i(32'd0),.qstr_base_i(32'd0),.qstr_ext_i(32'd0),
        .done_o(done),.admitted_o(),.fallback_o(fallback),.fault_o(fault),.used_o(result),
        .req_o(req),.we_o(we),.addr_o(addr),.wdata_o(wd),.wtag_o(wt),
        .gnt_i(gnt),.ack_i(ack),.fault_i(mfault),.mem_data_i(rd),.mem_tag_i(rt));
    // Random grants and delayed acks; poison read data between acks.
    always @(negedge clk) begin
        cycles=cycles+1; gnt=0; ack=0; rd='x; rt='x;
        if(pending) begin
            if(delay_count==0) begin
                if(pwe) begin mem[pa>>2]={pt,pd}; writes=writes+1; end
                else {rt,rd}=mem[pa>>2];
                ack=1; pending=0;
            end else delay_count=delay_count-1;
        end else if(req && $urandom_range(0,3)!=0) begin
            gnt=1; pending=1; pa=addr; pd=wd; pt=wt; pwe=we;
            delay_count=$urandom_range(0,3);
        end
        if(cycles>2000000) $fatal(1,"timeout");
    end
    task automatic clear_mem;
        for(integer i=0;i<4096;i++) mem[i]=0;
        used=0; hashes=0; src=256; sn=17; dst=1024; dn=37; is_set=1;
    endtask
    task automatic insert(input integer base,n,k,v,input bit set_table);
        integer p,step;
        p=32'(k)%n; step=set_table?1:2;
        while(mem[(base>>2)+p*step]!=0) p=(p+1)%n;
        mem[(base>>2)+p*step]={4'd1,32'(k)};
        if(!set_table) mem[(base>>2)+p*step+1]={4'd1,32'(v)};
    endtask
    function automatic integer find_key(input integer k);
        integer p,step;
        find_key=-1; step=is_set?1:2;
        for(p=0;p<dn;p++) if(mem[(dst>>2)+p*step]=={4'd1,32'(k)}) find_key=p;
    endfunction
    task automatic run(input integer operation,input bit expect_fallback=0,input bit keep_cache=0);
        @(negedge clk); cache_clear=!keep_cache;op=3'(operation);valid=1;
        @(negedge clk); valid=0;cache_clear=0;
        wait(done); #1;
        if(fault || fallback!=expect_fallback) $fatal(1,"status op=%d fallback=%b fault=%b",operation,fallback,fault);
        checks=checks+1; @(negedge clk);
    endtask
    integer before_writes,p,expected,ncase,start_cycles;
    initial begin
        clear_mem(); repeat(3) @(negedge clk); rst=1;
        for(ncase=0;ncase<30;ncase++) begin
            for(integer operation=0;operation<5;operation++) begin
                clear_mem(); dn=47; sn=23;
                for(integer k=5;k<15;k++) insert(src,sn,k,k+100,1);
                if(operation!=0) begin
                    for(integer k=0;k<10;k++) insert(dst,dn,k,k+200,1);
                    used=10;
                end
                run(operation);
                expected=0;
                for(integer k=0;k<20;k++) begin
                    bit want;
                    case(operation)
                        0: want=k>=5 && k<15;
                        1: want=k<15;
                        2: want=k<5;
                        3: want=k>=5 && k<10;
                        4: want=k<5 || (k>=10 && k<15);
                    endcase
                    if((find_key(k)>=0)!=want) $fatal(1,"membership op=%d key=%d",operation,k);
                    expected+=integer'(want);
                end
                if(result!=expected) $fatal(1,"count op=%d got=%d want=%d",operation,result,expected);
            end
        end
        clear_mem(); is_set=0; used=2;
        insert(dst,dn,1,10,0);insert(dst,dn,38,20,0);
        insert(src,sn,1,99,0);insert(src,sn,75,30,0);
        run(1);
        if(result!=3 || mem[(dst>>2)+find_key(1)*2+1]!={4'd1,32'd99}) $fatal(1,"dict overwrite");
        // Unsupported equality rejects before writing, even after valid keys.
        clear_mem(); mem[src>>2]={4'd1,32'd5};mem[(src>>2)+16]={4'd14,32'd700};
        before_writes=writes;run(1,1);
        if(writes!=before_writes) $fatal(1,"fallback wrote memory");
        // Insufficient conservative capacity also rejects before writing.
        clear_mem(); dn=2;used=1;insert(dst,dn,4,0,1);
        insert(src,sn,1,0,1);insert(src,sn,2,0,1);
        before_writes=writes;run(1,1);
        if(writes!=before_writes) $fatal(1,"capacity fallback wrote");
        // Rehash object with a core-computed hash; no type callback in hardware.
        clear_mem();sn=1;hashes=2048;mem[src>>2]={4'd14,32'd700};mem[hashes>>2]={4'd1,32'hffffffff};
        run(0);p=32'hffffffff%dn;
        if(mem[(dst>>2)+p]!={4'd14,32'd700}) $fatal(1,"override");
        // Full destination with tombstone must terminate and reuse the slot.
        clear_mem();dn=2;sn=1;mem[src>>2]={4'd1,32'd5};
        mem[dst>>2]={4'd1,32'd2};mem[(dst>>2)+1]={4'd0,32'd3};used=1;
        run(1);if(result!=2 || find_key(5)<0) $fatal(1,"tombstone reuse");
        // Pointer-based scalar hashing through the grant/ack adapter.
        clear_mem();sn=1;mem[src>>2]={4'd8,32'd3000};mem[751]={4'd0,32'd27};
        run(0);if(mem[(dst>>2)+27]!={4'd8,32'd3000})$fatal(1,"cached string hash");
        clear_mem();sn=1;mem[src>>2]={4'd2,32'd3000};mem[750]={4'd0,32'hffffffff};
        run(0);if(mem[(dst>>2)+(32'hffffffff%dn)]!={4'd2,32'd3000})$fatal(1,"boxed integer hash");
        clear_mem();sn=1;mem[src>>2]={4'd4,32'd3000};
        mem[750]={4'd0,32'h40400000};mem[751]={4'd0,32'h40000000};
        run(0);if(mem[(dst>>2)+1]!={4'd4,32'd3000})$fatal(1,"complex hash");
        clear_mem();sn=1;mem[src>>2]={4'd6,32'd3};mem[6]={4'd0,32'd19};
        run(0);if(mem[(dst>>2)+19]!={4'd6,32'd3})$fatal(1,"qstr hash");
        clear_mem();sn=1;mem[src>>2]={4'd3,32'h40200000};
        run(0);if(mem[(dst>>2)+2]!={4'd3,32'h40200000})$fatal(1,"float hash");
        clear_mem();sn=1;used=1;mem[src>>2]={4'd0,32'd4};insert(dst,dn,0,0,1);
        run(1);if(result!=1)$fatal(1,"bool/int equality");
        clear_mem();sn=0;used=1;insert(dst,dn,0,0,1);
        run(2);if(result!=1)$fatal(1,"difference empty");
        run(3);if(result!=0)$fatal(1,"intersection empty");
        // Read-only predicates: empty/full/tombstone tables, aliases and fallback.
        for(integer mask=0;mask<16;mask++)begin
            clear_mem();sn=7;dn=7;
            for(integer k=0;k<4;k++)begin
                insert(src,sn,k,0,1);
                if(mask & (1<<k))begin insert(dst,dn,k,0,1);used++;end
            end
            before_writes=writes;run(5);
            if(result!=1 || writes!=before_writes)$fatal(1,"subset predicate");
            run(6);if(result!=(mask==0) || writes!=before_writes)$fatal(1,"disjoint predicate");
            insert(dst,dn,6,0,1);used++;run(5);
            if(result!=0 || writes!=before_writes)$fatal(1,"missing subset key");
        end
        clear_mem();src=dst;sn=dn;insert(dst,dn,3,0,1);used=1;
        before_writes=writes;run(5);if(result!=1)$fatal(1,"alias subset");
        run(6);if(result!=0 || writes!=before_writes)$fatal(1,"alias disjoint");
        clear_mem();sn=0;insert(dst,dn,3,0,1);used=1;
        run(5);if(result!=0)$fatal(1,"empty probe subset");
        run(6);if(result!=1)$fatal(1,"empty probe disjoint");
        clear_mem();sn=2;mem[src>>2]={4'd0,32'd3};mem[(src>>2)+1]={4'd0,32'd3};
        insert(dst,dn,3,0,1);used=1;
        run(5);if(result!=0)$fatal(1,"tombstone full walk subset");
        run(6);if(result!=1)$fatal(1,"tombstone full walk disjoint");
        clear_mem();mem[src>>2]={4'd14,32'd3000};before_writes=writes;
        run(5,1);run(6,1);if(writes!=before_writes)$fatal(1,"predicate fallback wrote");
        // Sequence count/find use the same equality datapath without hashing.
        for(integer count=0;count<20;count++)begin
            clear_mem();sn=1;dn=count;used=0;mem[src>>2]={4'd1,32'd3};
            expected=0;
            for(integer k=0;k<count;k++)begin mem[(dst>>2)+k]={4'd1,32'(k%5)};if(k%5==3)expected++;end
            before_writes=writes;run(7);if(result!=expected || writes!=before_writes)$fatal(1,"sequence count");
            used=1;run(7);if(result!=(count>3 ? 32'd3 : 32'hffffffff))$fatal(1,"sequence find");
        end
        clear_mem();sn=1;dn=1;mem[src>>2]={4'd14,32'd3000};run(7,1);
        if(TYPE_CACHE)begin
            clear_mem();for(integer k=0;k<8;k++)begin insert(src,sn,k,0,1);insert(dst,dn,k,0,1);end
            used=8;start_cycles=cycles;run(5);expected=cycles-start_cycles;
            start_cycles=cycles;run(5,0,1);
            if(result!=1 || cycles-start_cycles>=expected)$fatal(1,"type cache did not skip scans");
            // A core write changes a previously validated key to a callback key.
            @(negedge clk);mem[src>>2]={4'd14,32'd3000};cache_addr=src;cache_write=1;
            @(negedge clk);cache_write=0;run(5,1,1);
            // Copy/byte/map writes use the second invalidation port.
            clear_mem();insert(src,sn,1,0,1);insert(dst,dn,1,0,1);used=1;run(5);
            @(negedge clk);mem[src>>2]={4'd14,32'd3000};cache_addr=src;cache_write2=1;
            @(negedge clk);cache_write2=0;run(5,1,1);
            // GC/reuse invalidates even if the table address is unchanged.
            clear_mem();insert(src,sn,1,0,1);insert(dst,dn,1,0,1);used=1;run(5);
            @(negedge clk);mem[src>>2]={4'd14,32'd3000};cache_clear=1;
            @(negedge clk);cache_clear=0;run(5,1,1);
        end
        $display("PASS mpy_map_engine checks=%0d cycles=%0d",checks,cycles);$finish;
    end
endmodule
