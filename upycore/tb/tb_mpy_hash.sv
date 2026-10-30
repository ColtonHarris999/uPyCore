`timescale 1ns/1ps
module tb_mpy_hash;
    parameter integer BYTES_PER_CYCLE = 1;
    logic clk=0;
    always #5 clk=~clk;
    logic rst=0, valid=0, ready, out_valid, out_ready=0, error;
    logic [3:0] tag;
    logic [31:0] payload, hash, address;
    logic req, ack, fault=0;
    logic [35:0] memory [0:65535];
    logic [31:0] random_state=32'h12345678;
    integer stall=1, latency=0, mem_wait=0;
    always @(negedge clk) random_state <= {random_state[30:0], random_state[31]^random_state[21]^random_state[1]^random_state[0]};
    assign ack = req && mem_wait >= latency && (!stall || random_state[0]);
    always @(posedge clk) begin
        if (!rst || !req || ack) mem_wait <= 0;
        else if (mem_wait < latency) mem_wait <= mem_wait + 1;
    end
    mpy_hash #(.BYTES_PER_CYCLE(BYTES_PER_CYCLE)) dut (
        .clk_i(clk), .rst_n_i(rst), .valid_i(valid), .ready_o(ready),
        .tag_i(tag), .payload_i(payload), .qstr_count_i(32'd2),
        .qstr_base_i(32'h100), .qstr_ext_i(32'h200),
        .valid_o(out_valid), .ready_i(out_ready), .hash_o(hash), .error_o(error),
        .mem_req_o(req), .mem_addr_o(address), .mem_ack_i(ack), .mem_fault_i(fault),
        .mem_data_i(memory[address[17:2]][31:0]), .mem_tag_i(memory[address[17:2]][35:32])
    );
    string filename;
    integer fd, n, t, p, h, e, cycles, total=0, tests=0, reads=0;
    logic [31:0] held;
    initial begin
        if (!$value$plusargs("VECTORS=%s", filename)) $fatal(1,"missing vectors");
        n=$value$plusargs("STALL=%d",stall);
        n=$value$plusargs("LATENCY=%d",latency);
        $readmemh("memory.hex", memory);
        fd=$fopen(filename,"r");
        repeat(2) @(negedge clk); rst=1;
        while (!$feof(fd)) begin
            n=$fscanf(fd,"%x %x %x %x\n",t,p,h,e);
            if(n != 4) break;
            @(negedge clk);
            if(!ready) $fatal(1,"not ready");
            tag=4'(t); payload=32'(p); valid=1;
            @(negedge clk); valid=0; tag=5; payload='1;
            cycles=1;
            while(!out_valid) begin
                if(req && ack) reads++;
                @(negedge clk); cycles++;
                if(cycles>5000) $fatal(1,"timeout test %0d",tests);
            end
            if(error != 1'(e) || (!e && hash != 32'(h)))
                $fatal(1,"test %0d tag=%x payload=%x got=%x err=%d expected=%x err=%d",tests,t,p,hash,error,h,e);
            held=hash;
            repeat(3) begin
                @(negedge clk);
                if(!out_valid || hash != held || ready || req) $fatal(1,"response changed while stalled");
            end
            out_ready=1; @(negedge clk); out_ready=0;
            total+=cycles; tests++;
        end
        // A bus fault must terminate with error.
        tag=2; payload=32'h1000; valid=1;
        @(negedge clk); valid=0; fault=1;
        wait(out_valid); @(negedge clk);
        if(!error) $fatal(1,"fault lost");
        rst=0; @(negedge clk); rst=1; @(negedge clk);
        if(!ready || out_valid || req) $fatal(1,"reset did not cancel");
        // Cancel an active memory transaction, before it has a response.
        fault=0; tag=4; payload=32'h1000; valid=1;
        @(negedge clk); valid=0;
        wait(req); rst=0;
        @(negedge clk);
        if(req || out_valid) $fatal(1,"reset left active transaction");
        rst=1; @(negedge clk);
        if(!ready) $fatal(1,"reset left engine busy");
        $display("PASS mpy_hash tests=%0d cycles=%0d reads=%0d bytes=%0d stall=%0d latency=%0d",tests,total,reads,BYTES_PER_CYCLE,stall,latency);
        $finish;
    end
endmodule
