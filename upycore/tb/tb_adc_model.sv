// Behavioral converter for the ADC benches: LATENCY clocks after a start,
// one done clock with the code for that channel, (273 * ch + 100) & 0xFFF
// (mpy_periph_model.adc_code).
module tb_adc_model #(
    parameter int LATENCY = 48
) (
    input  logic        clk,
    input  logic        start,
    input  logic [3:0]  chan,
    output logic        done,
    output logic [11:0] code
);
    int         left = 0;
    logic [3:0] ch;

    initial begin done = 1'b0; code = 12'h0; end

    always @(posedge clk) begin
        done <= 1'b0;
        if (start) begin
            ch <= chan;
            left <= LATENCY;
        end else if (left > 0) begin
            left <= left - 1;
            if (left == 1) begin
                done <= 1'b1;
                code <= 12'((273 * int'(ch) + 100) & 12'hFFF);
            end
        end
    end
endmodule
