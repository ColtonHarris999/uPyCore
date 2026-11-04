// Read-only hash engine for the linked-image ABI (mpy_abi.py), not the
// expanded RF format in mpy_memory_map.md. INT64/COMPLEX payloads are boxes.
// Objects use payload >> 1; callers resolve Python __hash__ separately.
// Tuples/frozensets use configurable seeds: upstream seeds are addresses.
// Unsupported/unhashable values, depth overflow, and bus faults return error.
// One outstanding request. Response holds under backpressure. Reads hold
// until mem_ack_i; acks may be immediate. Reset cancels the transaction.
// Qstr configuration is image-wide and must remain stable until retirement.
// The caller owns bounds checking, object immutability and GC exclusion;
// mem_fault_i must flag invalid reads. Depth overflow requires fallback.
// Object tags always use identity, even inside aggregates: callers must
// route keys needing Python __hash__ through separate logic/software.
module mpy_hash #(
    parameter integer DEPTH = 8,
    parameter integer BYTES_PER_CYCLE = 1,
    parameter logic [31:0] TUPLE_SEED = 32'd12345,
    parameter logic [31:0] FROZEN_SEED = 32'd54321
) (
    input logic clk_i, rst_n_i,
    input logic valid_i,
    output logic ready_o,
    input logic [3:0] tag_i,
    input logic [31:0] payload_i,
    input logic [31:0] qstr_count_i, qstr_base_i, qstr_ext_i,
    output logic valid_o,
    input logic ready_i,
    output logic [31:0] hash_o,
    output logic error_o,
    output logic mem_req_o,
    output logic [31:0] mem_addr_o,
    input logic mem_ack_i, mem_fault_i,
    input logic [31:0] mem_data_i,
    input logic [3:0] mem_tag_i
);
    `include "mpy_hash_funcs.svh"
    localparam integer SP_W = DEPTH < 2 ? 1 : $clog2(DEPTH + 1);
    typedef enum logic [4:0] {IDLE, DISPATCH, RESULT, RESP,
        I64, REAL_PART, IMAG_PART, QSTR, STR_HASH, STR_LEN, STR_PTR,
        STR_DATA, STR_STEP, TUPLE_LEN, ELEM, SET_FLAGS, SET_LEN, SET_PTR} state_t;
    state_t state;
    logic [3:0] tag;
    logic [31:0] payload, result, real_hash, len, ptr, acc, byte_buffer;
    logic [SP_W-1:0] sp;
    logic [31:0] frame_ptr [DEPTH], frame_len [DEPTH];
    logic [31:0] frame_idx [DEPTH], frame_sum [DEPTH];
    logic frame_set [DEPTH];
    logic reading;
    logic [31:0] word_hash, shifted;
    integer count;

    assign ready_o = state == IDLE || (state == RESP && ready_i);
    assign valid_o = state == RESP;
    always_comb begin
        reading = 1'b1;
        mem_addr_o = payload;
        case (state)
            I64, REAL_PART, STR_LEN, TUPLE_LEN: mem_addr_o = payload;
            IMAG_PART, STR_HASH: mem_addr_o = payload + 4;
            QSTR: mem_addr_o = payload < qstr_count_i ?
                qstr_base_i + (payload << 3) : qstr_ext_i + ((payload - qstr_count_i) << 3);
            STR_PTR: mem_addr_o = payload + 8;
            STR_DATA: mem_addr_o = {ptr[31:2], 2'b00};
            ELEM: mem_addr_o = frame_ptr[sp-1] + (frame_idx[sp-1] << 2);
            SET_FLAGS: mem_addr_o = (payload & 32'hfffffffc) + 12;
            SET_LEN: mem_addr_o = (payload & 32'hfffffffc) + 4;
            SET_PTR: mem_addr_o = (payload & 32'hfffffffc) + 8;
            default: reading = 1'b0;
        endcase
        mem_req_o = reading;
        shifted = state == STR_STEP ? byte_buffer : mem_data_i >> (8 * ptr[1:0]);
        count = BYTES_PER_CYCLE;
        if (count > 4 - integer'(ptr[1:0])) count = 4 - integer'(ptr[1:0]);
        if (len < 32'(count)) count = integer'(len);
        word_hash = acc;
        for (integer i = 0; i < BYTES_PER_CYCLE; i = i + 1)
            if (i < count) word_hash = hash_byte(word_hash, shifted[8*i +: 8]);
    end

    task automatic fail();
        error_o <= 1'b1; hash_o <= 0; state <= RESP;
    endtask
    task automatic finish(input logic [31:0] h);
        result <= hash_sx31(h); state <= RESULT;
    endtask

    // Scalar hashes can retire at acceptance. A consumed response can be
    // replaced in the same cycle, sustaining one immediate key per clock.
    task automatic accept();
        error_o <= 0; sp <= 0;
        tag <= tag_i; payload <= payload_i;
        state <= RESP;
        case (tag_i)
            0: case (payload_i)
                1: hash_o <= 6;
                4: hash_o <= 0;
                5: hash_o <= 1;
                default: fail();
            endcase
            1: hash_o <= hash_sx31(payload_i);
            3: hash_o <= hash_float(payload_i);
            11, 12, 14: hash_o <= hash_sx31(payload_i >> 1);
            default: state <= DISPATCH;
        endcase
    endtask

    initial begin
        if (DEPTH < 1 || (BYTES_PER_CYCLE != 1 && BYTES_PER_CYCLE != 4))
            $error("mpy_hash: invalid parameters");
    end
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            state <= IDLE; hash_o <= 0; error_o <= 0; sp <= 0;
            tag <= 0; payload <= 0; result <= 0; real_hash <= 0;
            len <= 0; ptr <= 0; acc <= 0; byte_buffer <= 0;
        end else if (reading && mem_ack_i && mem_fault_i) fail();
        else case (state)
            IDLE: if (valid_i) accept();
            DISPATCH: case (tag)
                0: case (payload)
                    1: finish(6);
                    4: finish(0);
                    5: finish(1);
                    default: fail();
                endcase
                1: finish(payload);
                2: state <= I64;
                3: finish(hash_float(payload));
                4: state <= REAL_PART;
                6: state <= QSTR;
                8, 13: state <= STR_HASH;
                9: if (sp == DEPTH) fail(); else state <= TUPLE_LEN;
                10: if (payload[1:0] != 2 || sp == DEPTH) fail(); else state <= SET_FLAGS;
                11, 12, 14: finish(payload >> 1);
                default: fail(); // reserved, CONT, and non-ABI SHORT_STR
            endcase
            RESULT: if (sp == 0) begin hash_o <= result; state <= RESP; end
                else begin
                    frame_sum[sp-1] <= frame_sum[sp-1] + result;
                    if (frame_idx[sp-1] + 1 == frame_len[sp-1]) begin
                        result <= hash_sx31(frame_sum[sp-1] + result); sp <= sp - 1;
                    end else begin frame_idx[sp-1] <= frame_idx[sp-1] + 1; state <= ELEM; end
                end
            RESP: if (ready_i) begin
                if (valid_i) accept(); else state <= IDLE;
            end
            I64: if (mem_ack_i) finish(mem_data_i);
            REAL_PART: if (mem_ack_i) begin real_hash <= hash_float(mem_data_i); state <= IMAG_PART; end
            IMAG_PART: if (mem_ack_i) finish(real_hash ^ hash_float(mem_data_i));
            QSTR: if (mem_ack_i) finish({16'd0, mem_data_i[15:0]});
            STR_HASH: if (mem_ack_i) begin
                if (mem_data_i[15:0] != 0) finish({16'd0, mem_data_i[15:0]});
                else state <= STR_LEN;
            end
            STR_LEN: if (mem_ack_i) begin len <= mem_data_i; state <= STR_PTR; end
            STR_PTR: if (mem_ack_i) begin
                ptr <= mem_data_i; acc <= 5381;
                if (len == 0) finish(5381); else state <= STR_DATA;
            end
            STR_DATA, STR_STEP: if (state == STR_STEP || mem_ack_i) begin
                acc <= word_hash; ptr <= ptr + 32'(count); len <= len - 32'(count);
                byte_buffer <= shifted >> (8 * count);
                if (len == 32'(count)) finish(hash_string_finish(word_hash));
                else if (integer'(ptr[1:0]) + count == 4) state <= STR_DATA;
                else state <= STR_STEP;
            end
            TUPLE_LEN: if (mem_ack_i) begin
                if (mem_data_i == 0) finish(TUPLE_SEED);
                else begin
                    frame_ptr[sp] <= payload + 4; frame_len[sp] <= mem_data_i;
                    frame_idx[sp] <= 0; frame_sum[sp] <= TUPLE_SEED;
                    frame_set[sp] <= 0; sp <= sp + 1; state <= ELEM;
                end
            end
            SET_FLAGS: if (mem_ack_i) begin
                if ((mem_data_i & 2) == 0) fail(); else state <= SET_LEN;
            end
            SET_LEN: if (mem_ack_i) begin len <= mem_data_i; state <= SET_PTR; end
            SET_PTR: if (mem_ack_i) begin
                if (len == 0) finish(FROZEN_SEED);
                else begin
                    frame_ptr[sp] <= mem_data_i; frame_len[sp] <= len;
                    frame_idx[sp] <= 0; frame_sum[sp] <= FROZEN_SEED;
                    frame_set[sp] <= 1; sp <= sp + 1; state <= ELEM;
                end
            end
            ELEM: if (mem_ack_i) begin
                if (frame_set[sp-1] && mem_tag_i == 0 && (mem_data_i == 0 || mem_data_i == 3))
                    finish(0); // empty/tombstone contributes nothing
                else begin tag <= mem_tag_i; payload <= mem_data_i; state <= DISPATCH; end
            end
            default: state <= IDLE;
        endcase
    end
endmodule
