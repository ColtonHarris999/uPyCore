// Elastic hash -> unsigned modulo pipeline. Hashing of the next key overlaps
// division of the previous hash, including memory stalls. The result register
// decouples the memory/probe consumer. alloc_i == 0 returns an error.
module mpy_hash_slot #(
    parameter bit EXTERNAL_HASH = 0,
    parameter integer BPC = 4,
    parameter integer DEPTH = 8,
    parameter integer BYTES_PER_CYCLE = 1,
    parameter logic [31:0] TUPLE_SEED = 32'd12345,
    parameter logic [31:0] FROZEN_SEED = 32'd54321
) (
    output logic hash_valid_o,
    input logic hash_ready_i,
    output logic [3:0] hash_tag_o,
    output logic [31:0] hash_payload_o,
    input logic hash_result_valid_i,
    output logic hash_result_ready_o,
    input logic [31:0] hash_value_i,
    input logic hash_error_i,hash_mem_req_i,
    input logic [31:0] hash_mem_addr_i,
    output logic hash_mem_ack_o,
    input logic clk_i, rst_n_i, valid_i,
    output logic ready_o,
    input logic [3:0] tag_i,
    input logic [31:0] payload_i, alloc_i,
    input logic [31:0] qstr_count_i, qstr_base_i, qstr_ext_i,
    output logic valid_o,
    input logic ready_i,
    output logic [31:0] slot_o,
    output logic error_o,
    output logic mem_req_o,
    output logic [31:0] mem_addr_o,
    input logic mem_ack_i, mem_fault_i,
    input logic [31:0] mem_data_i,
    input logic [3:0] mem_tag_i
);
    logic hv, hr, he, launch, active, done, completed, stage_error;
    logic retire;
    logic [31:0] h, alloc, rem;
    assign hash_valid_o=valid_i;
    assign hash_tag_o=tag_i;
    assign hash_payload_o=payload_i;
    assign hash_result_ready_o=hr;
    assign hash_mem_ack_o=mem_ack_i;
    generate if(EXTERNAL_HASH)begin : shared_hash
        assign ready_o=hash_ready_i;
        assign hv=hash_result_valid_i;
        assign h=hash_value_i;
        assign he=hash_error_i;
        assign mem_req_o=hash_mem_req_i;
        assign mem_addr_o=hash_mem_addr_i;
    end else begin : private_hash
    mpy_hash #(.DEPTH(DEPTH), .BYTES_PER_CYCLE(BYTES_PER_CYCLE),
               .TUPLE_SEED(TUPLE_SEED), .FROZEN_SEED(FROZEN_SEED)) hash (
        .clk_i, .rst_n_i, .valid_i, .ready_o, .tag_i, .payload_i,
        .qstr_count_i, .qstr_base_i, .qstr_ext_i,
        .valid_o(hv), .ready_i(hr), .hash_o(h), .error_o(he),
        .mem_req_o, .mem_addr_o, .mem_ack_i, .mem_fault_i, .mem_data_i, .mem_tag_i
    );
    end endgenerate
    // The modulo result holds until the next start. Remember its done pulse
    // if the output is stalled; retire and launch the next key together.
    assign retire = active && (completed || done) && (!valid_o || ready_i);
    assign hr = !active || retire;
    assign launch = hv && hr && !he && alloc != 0;
    upycore_umod_seq #(.BPC(BPC)) modulo (
        .clk_i, .rst_n_i, .start_i(launch), .a_i(h), .d_i(alloc),
        .done_o(done), .rem_o(rem), .busy_o()
    );
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            alloc <= 0; active <= 0; completed <= 0; stage_error <= 0;
            valid_o <= 0; error_o <= 0; slot_o <= 0;
        end else begin
            if (valid_i && ready_o) alloc <= alloc_i;
            if (valid_o && ready_i) valid_o <= 0;
            if (done) completed <= 1;
            if (retire) begin
                active <= 0; valid_o <= 1;
                error_o <= stage_error; slot_o <= stage_error ? 32'd0 : rem;
            end
            if (hv && hr) begin
                active <= 1;
                stage_error <= he || alloc == 0;
                completed <= he || alloc == 0;
            end
        end
    end
endmodule
