// Behavioral I2C target for the benches: a 24C02-style memory. A write
// sets the pointer from its first byte and stores the rest; a read returns
// bytes from the pointer. With STRETCH > 0 it holds SCL low for that many
// clocks after every ACK bit, which a controller must wait out. Byte a
// starts as a ^ INIT. The lines are open drain: scl and sda are the bus
// levels, *_low are this target's pulls.
module tb_i2c_target #(
    parameter logic [6:0] ADDR = 7'h50,
    parameter int         BYTES = 256,
    parameter int         STRETCH = 0,
    parameter logic [7:0] INIT = 8'h00
) (
    input  logic clk,
    input  logic scl,
    input  logic sda,
    output logic scl_low,
    output logic sda_low
);
    typedef enum { T_IDLE, T_ADDR, T_RX, T_TX } st_e;
    st_e        st;
    logic [7:0] mem [0:BYTES-1];
    logic [7:0] sh;
    int         nbit;
    bit         first;      // the next received byte is the pointer
    bit         ack_phase;
    bit         master_nack;
    bit         addr_ack;   // this ACK answered the address
    logic [7:0] ptr;
    logic       scl_d, sda_d;
    int         hold;

    initial begin
        for (int a = 0; a < BYTES; a++) mem[a] = 8'(a) ^ INIT;
        st = T_IDLE; scl_low = 1'b0; sda_low = 1'b0; ptr = 8'h0;
        scl_d = 1'b1; sda_d = 1'b1; hold = 0; ack_phase = 0;
    end

    always @(posedge clk) begin
        // START and STOP: SDA moves while SCL is high.
        if (scl && scl_d && sda_d && !sda) begin
            st = T_ADDR; nbit = 0; ack_phase = 0; sda_low = 1'b0;
        end else if (scl && scl_d && !sda_d && sda) begin
            st = T_IDLE; sda_low = 1'b0;
        end else if (st != T_IDLE && scl && !scl_d) begin
            // Rising edge: sample.
            if (ack_phase) begin
                if (st == T_TX && !addr_ack) master_nack = sda;
            end else if (st == T_ADDR || st == T_RX) begin
                sh = {sh[6:0], sda};
                nbit++;
            end
        end else if (st != T_IDLE && !scl && scl_d) begin
            // Falling edge: drive the next bit, the ACK, or let go.
            if (ack_phase) begin
                ack_phase = 0;
                sda_low = 1'b0;
                if (STRETCH > 0) begin scl_low = 1'b1; hold = STRETCH; end
                if (st == T_TX) begin
                    if (addr_ack) begin nbit = 0; sda_low = !sh[7]; end
                    else if (master_nack) st = T_IDLE;
                    else begin sh = mem[ptr]; ptr++; nbit = 0; sda_low = !sh[7]; end
                end
                addr_ack = 0;
            end else if (st == T_TX) begin
                nbit++;
                if (nbit == 8) begin ack_phase = 1; sda_low = 1'b0; end
                else sda_low = !sh[7 - nbit];
            end else if (nbit == 8) begin
                nbit = 0;
                if (st == T_ADDR) begin
                    if (sh[7:1] == ADDR) begin
                        ack_phase = 1; addr_ack = 1; sda_low = 1'b1; first = !sh[0];
                        if (sh[0]) begin st = T_TX; sh = mem[ptr]; ptr++; end
                        else st = T_RX;
                    end else st = T_IDLE;
                end else begin
                    if (first) begin ptr = sh; first = 0; end
                    else begin mem[ptr] = sh; ptr++; end
                    ack_phase = 1; sda_low = 1'b1;
                end
            end
        end
        if (hold > 0) begin
            hold--;
            if (hold == 0) scl_low = 1'b0;
        end
        scl_d = scl;
        sda_d = sda;
    end
endmodule
