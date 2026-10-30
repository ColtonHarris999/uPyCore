// Elastic hash -> unsigned modulo pipeline. Hashing of the next key overlaps
// division of the previous hash, including memory stalls. The result register
// decouples the memory/probe consumer. alloc_i == 0 returns an error.
module mpy_hash_slot #(
    parameter integer BPC = 4,
    parameter integer DEPTH = 8,
    parameter integer BYTES_PER_CYCLE = 1,
    parameter logic [31:0] TUPLE_SEED = 32'd12345,
    parameter logic [31:0] FROZEN_SEED = 32'd54321
) (
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
    mpy_hash #(.DEPTH(DEPTH), .BYTES_PER_CYCLE(BYTES_PER_CYCLE),
               .TUPLE_SEED(TUPLE_SEED), .FROZEN_SEED(FROZEN_SEED)) hash (
        .clk_i, .rst_n_i, .valid_i, .ready_o, .tag_i, .payload_i,
        .qstr_count_i, .qstr_base_i, .qstr_ext_i,
        .valid_o(hv), .ready_i(hr), .hash_o(h), .error_o(he),
        .mem_req_o, .mem_addr_o, .mem_ack_i, .mem_fault_i, .mem_data_i, .mem_tag_i
    );
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
