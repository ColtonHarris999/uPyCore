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
        I64, REAL_PART, REAL_HASH, REAL_SIGN, IMAG_PART, IMAG_HASH, IMAG_SIGN, QSTR, STR_HASH, STR_LEN, STR_PTR,
        STR_DATA, STR_STEP, TUPLE_LEN, ELEM, SET_FLAGS, SET_LEN, SET_PTR,
        FLT_MAG, FLT_SIGN, FLT_MAG2, FLT_SIGN2} state_t;
    state_t state;
    logic [3:0] tag;
    logic [31:0] payload, result, real_hash, len, ptr, acc, byte_buffer;
    // A complex part read from memory is registered before hash_float, so
    // the float hash does not start from the memory's read data.
    logic [31:0] part_r;
    logic [31:0] mag_r;                 // hash_float_mag(part_r)
    logic [SP_W-1:0] sp;
    logic [31:0] frame_ptr [DEPTH], frame_len [DEPTH];
    logic [31:0] frame_idx [DEPTH], frame_sum [DEPTH];
    logic frame_set [DEPTH];
    logic reading;
    logic [31:0] word_hash, shifted;
    integer count;
    logic str_last;

    assign ready_o = state == IDLE || (state == RESP && ready_i);
    assign valid_o = state == RESP;

    // Every address the state mux can select, as its own prefix add. The
    // mux used to sit inside one carry chain (payload -> addr_o, six adds,
    // 14.9 ns post-route). payload+4 and the qstr form are the long ones;
    // the rest are the same width and would be the next ripple.
    logic [31:0] pay4, pay8, al4, al8, al12, q_in, q_out, q_addr, elem_addr;
    logic        q_ge;
    logic [SP_W-1:0] sp_prev;
    assign sp_prev = (sp == 0) ? '0 : SP_W'(sp - 1'b1);
    upycore_add #(.W(32)) u_pay4 (.a_i(payload), .b_i(32'd4), .cin_i(1'b0), .sum_o(pay4), .cout_o());
    upycore_add #(.W(32)) u_pay8 (.a_i(payload), .b_i(32'd8), .cin_i(1'b0), .sum_o(pay8), .cout_o());
    upycore_add #(.W(32)) u_al4  (.a_i({payload[31:2], 2'b00}), .b_i(32'd4),  .cin_i(1'b0), .sum_o(al4), .cout_o());
    upycore_add #(.W(32)) u_al8  (.a_i({payload[31:2], 2'b00}), .b_i(32'd8),  .cin_i(1'b0), .sum_o(al8), .cout_o());
    upycore_add #(.W(32)) u_al12 (.a_i({payload[31:2], 2'b00}), .b_i(32'd12), .cin_i(1'b0), .sum_o(al12), .cout_o());
    upycore_add #(.W(32)) u_qsub (
        .a_i(payload), .b_i(~qstr_count_i), .cin_i(1'b1), .sum_o(), .cout_o(q_ge));
    upycore_add #(.W(32)) u_qin (
        .a_i(qstr_base_i), .b_i({payload[28:0], 3'b000}), .cin_i(1'b0), .sum_o(q_in), .cout_o());
    // ext + ((payload - count) << 3) = ext + (payload << 3) - (count << 3).
    // The subtract used to feed this add, so the qstr form was two carries
    // in series inside the six-add address cone (14.9 ns post-route).
    upycore_sum3 #(.W(32)) u_qout (
        .a_i(qstr_ext_i), .b_i({payload[28:0], 3'b000}),
        .c_i(~{qstr_count_i[28:0], 3'b000}), .cin_i(1'b1), .sum_o(q_out));
    assign q_addr = q_ge ? q_out : q_in;   // q_ge means payload >= count
    upycore_add #(.W(32)) u_elem (
        .a_i(frame_ptr[sp_prev]), .b_i({frame_idx[sp_prev][29:0], 2'b00}),
        .cin_i(1'b0), .sum_o(elem_addr), .cout_o());
    logic [31:0] frame_sum_plus, ptr_next, len_next;
    upycore_add #(.W(32)) u_fsum (
        .a_i(frame_sum[sp_prev]), .b_i(result), .cin_i(1'b0), .sum_o(frame_sum_plus), .cout_o());
    upycore_add #(.W(32)) u_ptr (
        .a_i(ptr), .b_i(32'(count)), .cin_i(1'b0), .sum_o(ptr_next), .cout_o());
    upycore_add #(.W(32)) u_len (
        .a_i(len), .b_i(~32'(count)), .cin_i(1'b1), .sum_o(len_next), .cout_o());

    always_comb begin
        reading = 1'b1;
        mem_addr_o = payload;
        case (state)
            I64, REAL_PART, STR_LEN, TUPLE_LEN: mem_addr_o = payload;
            IMAG_PART, STR_HASH: mem_addr_o = pay4;
            QSTR: mem_addr_o = q_addr;
            STR_PTR: mem_addr_o = pay8;
            STR_DATA: mem_addr_o = {ptr[31:2], 2'b00};
            ELEM: mem_addr_o = elem_addr;
            SET_FLAGS: mem_addr_o = al12;
            SET_LEN: mem_addr_o = al4;
            SET_PTR: mem_addr_o = al8;
            default: reading = 1'b0;
        endcase
        mem_req_o = reading;
        shifted = state == STR_STEP ? byte_buffer : mem_data_i >> (8 * ptr[1:0]);
        count = BYTES_PER_CYCLE;
        if (count > 4 - integer'(ptr[1:0])) count = 4 - integer'(ptr[1:0]);
        // count is at most 4 here, so `len < count` and `len == count`
        // after the clamp (which is `len <= count` before it) are the high
        // bits of len being zero and a three-bit compare. As 32-bit
        // compares, one behind the other, they were ptr -> state at 9.6 ns.
        str_last = (len[31:3] == 29'd0) && (len[2:0] <= 3'(count));
        if (len[31:3] == 29'd0 && len[2:0] < 3'(count)) count = integer'({29'd0, len[2:0]});
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
            // A float key takes the two-step hash the complex parts use
            // (two cycles more; in one step the shift and the negate were
            // op -> hash_value_i at 11.8 ns).
            3: begin part_r <= payload_i; state <= FLT_MAG; end
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
            tag <= 0; payload <= 0; result <= 0; real_hash <= 0; part_r <= 0; mag_r <= 0;
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
                3: begin part_r <= payload; state <= FLT_MAG2; end
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
                    frame_sum[sp-1] <= frame_sum_plus;
                    if (frame_idx[sp-1] + 1 == frame_len[sp-1]) begin
                        result <= hash_sx31(frame_sum_plus); sp <= sp - 1;
                    end else begin frame_idx[sp-1] <= frame_idx[sp-1] + 1; state <= ELEM; end
                end
            RESP: if (ready_i) begin
                if (valid_i) accept(); else state <= IDLE;
            end
            I64: if (mem_ack_i) finish(mem_data_i);
            FLT_MAG: begin mag_r <= hash_float_mag(part_r); state <= FLT_SIGN; end
            FLT_SIGN: begin hash_o <= hash_float_sign(part_r[31], mag_r); state <= RESP; end
            FLT_MAG2: begin mag_r <= hash_float_mag(part_r); state <= FLT_SIGN2; end
            FLT_SIGN2: finish(hash_float_sign(part_r[31], mag_r));
            REAL_PART: if (mem_ack_i) begin part_r <= mem_data_i; state <= REAL_HASH; end
            // The shift and the sign each take a cycle (hash_float split).
            REAL_HASH: begin mag_r <= hash_float_mag(part_r); state <= REAL_SIGN; end
            REAL_SIGN: begin real_hash <= hash_float_sign(part_r[31], mag_r); state <= IMAG_PART; end
            IMAG_PART: if (mem_ack_i) begin part_r <= mem_data_i; state <= IMAG_HASH; end
            IMAG_HASH: begin mag_r <= hash_float_mag(part_r); state <= IMAG_SIGN; end
            IMAG_SIGN: finish(real_hash ^ hash_float_sign(part_r[31], mag_r));
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
                acc <= word_hash; ptr <= ptr_next; len <= len_next;
                byte_buffer <= shifted >> (8 * count);
                if (str_last) finish(hash_string_finish(word_hash));
                else if (integer'(ptr[1:0]) + count == 4) state <= STR_DATA;
                else state <= STR_STEP;
            end
            TUPLE_LEN: if (mem_ack_i) begin
                if (mem_data_i == 0) finish(TUPLE_SEED);
                else begin
                    frame_ptr[sp] <= pay4; frame_len[sp] <= mem_data_i;
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
