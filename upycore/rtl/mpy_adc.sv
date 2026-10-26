// ADC interface at MMIO offset 0x800. Spec: upycore/docs/mpy_peripherals.md (ADC)
//
// A register front for an external converter; the analog part is a model in
// the testbench. An ADC_CTRL store with bit 8 starts a conversion: one
// adc_start_o clock with adc_chan_o, then busy until adc_done_i, whose
// 12-bit code lands left-aligned in ADC_DATA with the valid bit. A start
// while busy is ignored. Offsets outside 0x800..0x8FF read 0.
module mpy_adc (
    input  logic        clk_i,
    input  logic        rst_n_i,

    input  logic        req_i,
    input  logic        we_i,
    input  logic [11:0] off_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    output logic        adc_start_o,
    output logic [3:0]  adc_chan_o,
    input  logic        adc_done_i,
    input  logic [11:0] adc_code_i
);
    localparam logic [11:0] ADC_CTRL   = 12'h800;
    localparam logic [11:0] ADC_DATA   = 12'h804;
    localparam logic [11:0] ADC_STATUS = 12'h808;

    logic        busy_r, valid_r;
    logic [15:0] data_r;
    logic        start;

    assign start = req_i && we_i && (off_i == ADC_CTRL) && wdata_i[8] && !busy_r;

    always_comb begin
        rdata_o = 32'h0;
        if (req_i && !we_i) begin
            case (off_i)
                ADC_CTRL:   rdata_o = {28'h0, adc_chan_o};
                ADC_DATA:   rdata_o = {valid_r, 15'h0, data_r};
                ADC_STATUS: rdata_o = {31'h0, busy_r};
                default:    rdata_o = 32'h0;
            endcase
        end
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            busy_r <= 1'b0; valid_r <= 1'b0; data_r <= 16'h0;
            adc_start_o <= 1'b0; adc_chan_o <= 4'h0;
        end else begin
            adc_start_o <= 1'b0;
            if (start) begin
                busy_r <= 1'b1;
                valid_r <= 1'b0;
                adc_chan_o <= wdata_i[3:0];
                adc_start_o <= 1'b1;
            end else if (busy_r && adc_done_i) begin
                busy_r <= 1'b0;
                valid_r <= 1'b1;
                data_r <= {adc_code_i, 4'h0};
            end
        end
    end
endmodule
