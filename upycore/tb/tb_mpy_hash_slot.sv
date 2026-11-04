`timescale 1ns/1ps
module tb_mpy_hash_slot;
    parameter integer BPC=4, BYTES_PER_CYCLE=1, SERIAL=0, BENCHMARK=0;
    logic clk=0;
    always #5 clk=~clk;
    logic rst=0, valid, ready, ov, ordy, error, req, ack;
    logic [3:0] tag;
    logic [31:0] payload, alloc, slot, address;
    logic [35:0] memory [0:65535];
    logic [3:0] tags [0:9999];
    logic [31:0] payloads [0:9999], hashes [0:9999];
    logic errors [0:9999];
    logic [31:0] random_state=32'h12345678;
    integer fd,n,t,p,h,e,num=0,sent=0,received=0,cycles=0,reads=0,stall=1;
    integer latency=0, mem_wait=0;
    logic held_req=0, held_out=0, held_error;
    logic [31:0] held_address, held_slot;
    string filename;
    logic accepted, consumed;
    always @(negedge clk) random_state <= {random_state[30:0], random_state[31]^random_state[21]^random_state[1]^random_state[0]};
    assign valid = sent < num && (!SERIAL || sent == received);
    assign tag = tags[sent];
    assign payload = payloads[sent];
    function automatic logic [31:0] divisor(input integer i);
        if (BENCHMARK) begin
            case (i%4)
                0: return 17;
                1: return 127;
                2: return 1021;
                default: return 65521;
            endcase
        end
        case(i%6)
            0: return 0;
            1: return 1;
            2: return 17;
            3: return 127;
            4: return 1021;
            default: return 65521;
        endcase
    endfunction
    assign alloc = divisor(sent);
    assign ack = req && mem_wait >= latency && (!stall || random_state[0]);
    assign ordy = !stall || random_state[1];
    always @(posedge clk) begin
        if (!rst || !req || ack) mem_wait <= 0;
        else if (mem_wait < latency) mem_wait <= mem_wait + 1;
        if (rst) begin
            if (held_req && (!req || address != held_address)) $fatal(1,"request changed while waiting");
            if (held_out && (!ov || slot != held_slot || error != held_error)) $fatal(1,"response changed while stalled");
        end
        held_req <= rst && req && !ack; held_address <= address;
        held_out <= rst && ov && !ordy; held_slot <= slot; held_error <= error;
    end
    mpy_hash_slot #(.BPC(BPC), .BYTES_PER_CYCLE(BYTES_PER_CYCLE)) dut (
        .clk_i(clk), .rst_n_i(rst), .valid_i(valid), .ready_o(ready), .tag_i(tag),
        .payload_i(payload), .alloc_i(alloc), .qstr_count_i(32'd2),
        .qstr_base_i(32'h100), .qstr_ext_i(32'h200),
        .valid_o(ov), .ready_i(ordy), .slot_o(slot), .error_o(error),
        .mem_req_o(req), .mem_addr_o(address), .mem_ack_i(ack), .mem_fault_i(1'b0),
        .mem_data_i(memory[address[17:2]][31:0]), .mem_tag_i(memory[address[17:2]][35:32])
    );
    initial begin
        if (!$value$plusargs("VECTORS=%s",filename)) $fatal(1,"missing vectors");
        n=$value$plusargs("STALL=%d",stall);
        n=$value$plusargs("LATENCY=%d",latency);
        $readmemh("memory.hex",memory);
        fd=$fopen(filename,"r");
        while(!$feof(fd)) begin
            n=$fscanf(fd,"%x %x %x %x\n",t,p,h,e);
            if(n!=4) break;
            tags[num]=4'(t); payloads[num]=32'(p); hashes[num]=32'(h); errors[num]=1'(e); num++;
        end
        repeat(2) @(negedge clk); rst=1;
        while(received < num) begin
            @(posedge clk);
            accepted=valid && ready;
            consumed=ov && ordy;
            if(req && ack) reads++;
            if(ov && ordy) begin
                if(error != (errors[received] || divisor(received)==0)) $fatal(1,"error lost at %d",received);
                if(!error && slot != hashes[received] % divisor(received))
                    $fatal(1,"bad slot at %d got=%x expected=%x",received,slot,hashes[received]%divisor(received));

            end
            @(negedge clk); cycles++;
            if(accepted) sent++;
            if(consumed) received++;
            if(cycles>1000000) $fatal(1,"timeout");
        end
        $display("PASS mpy_hash_slot tests=%0d cycles=%0d reads=%0d BPC=%0d bytes=%0d serial=%0d stall=%0d latency=%0d",num,cycles,reads,BPC,BYTES_PER_CYCLE,SERIAL,stall,latency);
        $finish;
    end
endmodule
