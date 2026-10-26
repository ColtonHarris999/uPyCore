// I2C controller, MMIO offset 0x400. Spec: upycore/docs/mpy_peripherals.md
//
// One command at a time from I2C_CMD: START (repeated when the bus is
// held), STOP, WRITE a byte and read the ACK, READ a byte and send ACK or
// NACK. Every command runs in quarter periods of DIV + 1 clocks. Both
// lines are open drain: scl_low/sda_low drive a line low, otherwise it is
// released and read back. A quarter that releases SCL first waits for SCL
// to read high, so a target may stretch the clock; a stretch longer than
// I2C_TIMEOUT clocks ends the command with the timeout bit and releases
// both lines. Offsets outside 0x400..0x4FF read 0.
module mpy_i2c (
    input  logic        clk_i,
    input  logic        rst_n_i,

    input  logic        req_i,
    input  logic        we_i,
    input  logic [11:0] off_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    output logic        scl_low_o,
    output logic        sda_low_o,
    input  logic        scl_i,
    input  logic        sda_i,
    output logic        irq_o
);
    localparam logic [11:0] I2C_DIV     = 12'h400;
    localparam logic [11:0] I2C_CMD     = 12'h404;
    localparam logic [11:0] I2C_STATUS  = 12'h408;
    localparam logic [11:0] I2C_TIMEOUT = 12'h40C;
    localparam logic [11:0] I2C_CTRL    = 12'h410;

    localparam logic [3:0] C_START = 4'd1;
    localparam logic [3:0] C_STOP  = 4'd2;
    localparam logic [3:0] C_WRITE = 4'd3;
    localparam logic [3:0] C_READ  = 4'd4;

    // A command is a list of bits, each four quarters. A WRITE or READ is
    // eight data bits and an ACK bit; START and STOP are one bit each.
    typedef enum logic [2:0] { K_IDLE, K_START, K_RSTART, K_BIT, K_STOP } kind_e;

    logic        en_r;
    logic [15:0] div_r;
    logic [31:0] tmo_r;
    kind_e       kind_r;
    logic [3:0]  cmd_r;
    logic        rd_nack_r;
    logic [3:0]  bit_r;         // 0..7 data, 8 ACK
    logic [1:0]  q_r;
    logic [15:0] cnt_r;
    logic [31:0] wait_r;
    logic        waiting_r;
    logic [7:0]  sh_r;
    logic [7:0]  rx_r;
    logic        nack_r, tmo_hit_r, held_r;
    logic        scl_low_r, sda_low_r;
    logic        busy;
    logic        start_cmd;

    assign busy = (kind_r != K_IDLE);
    assign start_cmd = req_i && we_i && (off_i == I2C_CMD) && !busy && en_r;
    assign scl_low_o = en_r && scl_low_r;
    assign sda_low_o = en_r && sda_low_r;
    assign irq_o = 1'b0;

    always_comb begin
        rdata_o = 32'h0;
        if (req_i && !we_i) begin
            case (off_i)
                I2C_DIV:     rdata_o = {16'h0, div_r};
                I2C_STATUS:  rdata_o = {16'h0, rx_r, 4'h0, held_r, tmo_hit_r, nack_r, busy};
                I2C_TIMEOUT: rdata_o = tmo_r;
                I2C_CTRL:    rdata_o = {31'h0, en_r};
                default:     rdata_o = 32'h0;
            endcase
        end
    end

    // The SDA level this bit drives in quarter q, for the bit kinds.
    function automatic logic data_bit(input logic [3:0] b, input logic [7:0] sh,
                                      input logic [3:0] cmd, input logic nack);
        if (b == 4'd8)
            data_bit = (cmd == C_WRITE) ? 1'b1 : nack;   // release for the target's ACK
        else
            data_bit = (cmd == C_WRITE) ? sh[3'd7 - b[2:0]] : 1'b1;
    endfunction

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            en_r <= 1'b0; div_r <= 16'h0; tmo_r <= 32'h0010_0000;
            kind_r <= K_IDLE; cmd_r <= 4'h0; rd_nack_r <= 1'b0;
            bit_r <= 4'h0; q_r <= 2'h0; cnt_r <= 16'h0; wait_r <= 32'h0; waiting_r <= 1'b0;
            sh_r <= 8'h0; rx_r <= 8'h0;
            nack_r <= 1'b0; tmo_hit_r <= 1'b0; held_r <= 1'b0;
            scl_low_r <= 1'b0; sda_low_r <= 1'b0;
        end else begin
            if (req_i && we_i && off_i == I2C_DIV) div_r <= wdata_i[15:0];
            if (req_i && we_i && off_i == I2C_TIMEOUT) tmo_r <= wdata_i;
            if (req_i && we_i && off_i == I2C_CTRL) begin
                en_r <= wdata_i[0];
                if (!wdata_i[0]) begin
                    kind_r <= K_IDLE; held_r <= 1'b0;
                    scl_low_r <= 1'b0; sda_low_r <= 1'b0;
                end
            end

            if (start_cmd) begin
                cmd_r <= wdata_i[3:0];
                rd_nack_r <= wdata_i[16];
                sh_r <= wdata_i[15:8];
                q_r <= 2'd0; cnt_r <= 16'h0; waiting_r <= 1'b0; wait_r <= 32'h0;
                bit_r <= 4'd0;
                case (wdata_i[3:0])
                    C_START: begin
                        kind_r <= held_r ? K_RSTART : K_START;
                        tmo_hit_r <= 1'b0;
                    end
                    C_STOP: kind_r <= K_STOP;
                    C_WRITE, C_READ: kind_r <= K_BIT;
                    default: kind_r <= K_IDLE;
                endcase
            end else if (busy) begin
                // A quarter that released SCL waits for it to read high.
                if (waiting_r) begin
                    if (scl_i)
                        waiting_r <= 1'b0;
                    else if (wait_r >= tmo_r) begin
                        tmo_hit_r <= 1'b1; kind_r <= K_IDLE; held_r <= 1'b0;
                        scl_low_r <= 1'b0; sda_low_r <= 1'b0;
                    end else
                        wait_r <= wait_r + 32'd1;
                end else if (cnt_r != div_r) begin
                    cnt_r <= cnt_r + 16'd1;
                end else begin
                    cnt_r <= 16'h0;
                    q_r <= q_r + 2'd1;
                    // The action at the start of the next quarter.
                    case (kind_r)
                        // SDA falls while SCL is high, then SCL falls.
                        K_START: case (q_r)
                            2'd0: begin sda_low_r <= 1'b1; end
                            2'd1: begin scl_low_r <= 1'b1; end
                            2'd2: ;
                            default: begin kind_r <= K_IDLE; held_r <= 1'b1; end
                        endcase
                        K_RSTART: case (q_r)
                            2'd0: begin scl_low_r <= 1'b0; waiting_r <= 1'b1; wait_r <= 32'h0; end
                            2'd1: begin sda_low_r <= 1'b1; end
                            2'd2: begin scl_low_r <= 1'b1; end
                            default: kind_r <= K_IDLE;
                        endcase
                        // SDA rises while SCL is high.
                        K_STOP: case (q_r)
                            2'd0: begin scl_low_r <= 1'b0; waiting_r <= 1'b1; wait_r <= 32'h0; end
                            2'd1: begin sda_low_r <= 1'b0; end
                            2'd2: ;
                            default: begin kind_r <= K_IDLE; held_r <= 1'b0; end
                        endcase
                        // q0 SCL low, SDA set; q1 SCL released; q2 sample; q3 SCL low.
                        K_BIT: case (q_r)
                            2'd0: begin scl_low_r <= 1'b0; waiting_r <= 1'b1; wait_r <= 32'h0; end
                            2'd1: begin
                                if (bit_r == 4'd8) begin
                                    if (cmd_r == C_WRITE) nack_r <= sda_i;
                                end else if (cmd_r == C_READ)
                                    rx_r <= {rx_r[6:0], sda_i};
                            end
                            2'd2: scl_low_r <= 1'b1;
                            default: begin
                                if (bit_r == 4'd8) begin
                                    kind_r <= K_IDLE;
                                    sda_low_r <= 1'b0;
                                end else begin
                                    bit_r <= bit_r + 4'd1;
                                    sda_low_r <= !data_bit(bit_r + 4'd1, sh_r, cmd_r, rd_nack_r);
                                end
                            end
                        endcase
                        default: kind_r <= K_IDLE;
                    endcase
                end
            end

            // The first quarter of a data bit sets SDA while SCL is low.
            if (start_cmd && (wdata_i[3:0] == C_WRITE || wdata_i[3:0] == C_READ))
                sda_low_r <= (wdata_i[3:0] == C_WRITE) ? !wdata_i[15] : 1'b0;
            if (start_cmd && wdata_i[3:0] == C_STOP)
                sda_low_r <= 1'b1;
            if (start_cmd && wdata_i[3:0] == C_START && held_r)
                sda_low_r <= 1'b0;
            if (start_cmd && wdata_i[3:0] == C_START && !held_r) begin
                scl_low_r <= 1'b0; sda_low_r <= 1'b0;
            end
        end
    end
endmodule
