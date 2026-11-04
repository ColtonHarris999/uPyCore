// MicroPython 0fd6c573, REPR_A, 32-bit mp_int_t, binary32.
// Include inside a module. Hashes are signed 31-bit small ints in 32 bits.
function automatic logic [31:0] hash_sx31(input logic [31:0] x);
    return {x[30], x[30:0]};
endfunction

// py/obj.h low-quality mp_float_hash: truncation to signed mp_int_t.
// The pinned i686 oracle returns INT_MIN for invalid/out-of-range casts;
// REPR_A small-int wrapping turns that into zero. No -1 -> -2 remapping.
function automatic logic [31:0] hash_float(input logic [31:0] bits);
    logic [31:0] value, frac;
    integer e;
    begin
        e = integer'({1'b0, bits[30:23]}) - 127;
        frac = {8'd0, 1'b1, bits[22:0]};
        if (e < 0 || e >= 31) value = 0;
        else if (e >= 23) value = frac << (e - 23);
        else value = frac >> (23 - e);
        if (bits[31]) value = -value;
        return hash_sx31(value);
    end
endfunction

function automatic logic [31:0] hash_byte(input logic [31:0] h,
                                         input logic [7:0] b);
    return ((h << 5) + h) ^ {24'd0, b};
endfunction
function automatic logic [31:0] hash_string_finish(input logic [31:0] h);
    return h[15:0] == 0 ? 32'd1 : {16'd0, h[15:0]};
endfunction
