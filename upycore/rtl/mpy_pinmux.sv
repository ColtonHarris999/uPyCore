// Pad function select, at MMIO offset 0x900.
// Spec: upycore/docs/mpy_peripherals.md (Pin mux)
//
// Four bits per pin pick what drives the pad. I2C pads are open drain: the
// pad output is 0 and the output enable is the drive-low request. An input
// function reads the lowest pad that selects it; with none selected MISO
// reads 0, SCL and SDA read 1, and the UART receiver keeps its own pin.
module mpy_pinmux (
    input  logic        clk_i,
    input  logic        rst_n_i,

    input  logic        req_i,
    input  logic        we_i,
    input  logic [11:0] off_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    input  logic [15:0] gpio_out_i,
    input  logic [15:0] gpio_oe_i,
    input  logic [3:0]  pwm_i,
    input  logic        spi_sck_i,
    input  logic        spi_mosi_i,
    input  logic        i2c_scl_low_i,
    input  logic        i2c_sda_low_i,
    input  logic        uart_txd_i,
    input  logic        uart_rxd_pin_i,

    output logic        spi_miso_o,
    output logic        i2c_scl_o,
    output logic        i2c_sda_o,
    output logic        uart_rxd_o,

    output logic [15:0] pad_out_o,
    output logic [15:0] pad_oe_o,
    input  logic [15:0] pad_in_i
);
    localparam logic [11:0] PINMUX0 = 12'h900;
    localparam logic [11:0] PINMUX1 = 12'h904;

    localparam logic [3:0] F_GPIO = 4'd0;
    localparam logic [3:0] F_SCK  = 4'd5;
    localparam logic [3:0] F_MOSI = 4'd6;
    localparam logic [3:0] F_MISO = 4'd7;
    localparam logic [3:0] F_SCL  = 4'd8;
    localparam logic [3:0] F_SDA  = 4'd9;
    localparam logic [3:0] F_TX   = 4'd10;
    localparam logic [3:0] F_RX   = 4'd11;

    logic [31:0] mux_r [0:1];
    logic [3:0]  fn [0:15];

    always_comb begin
        for (int i = 0; i < 16; i++)
            fn[i] = mux_r[i / 8][4 * (i % 8) +: 4];
    end

    always_comb begin
        rdata_o = 32'h0;
        if (req_i && !we_i) begin
            if (off_i == PINMUX0) rdata_o = mux_r[0];
            if (off_i == PINMUX1) rdata_o = mux_r[1];
        end
    end

    always_comb begin
        logic miso_seen, scl_seen, sda_seen, rx_seen;
        miso_seen = 1'b0; scl_seen = 1'b0; sda_seen = 1'b0; rx_seen = 1'b0;
        spi_miso_o = 1'b0;
        i2c_scl_o  = 1'b1;
        i2c_sda_o  = 1'b1;
        uart_rxd_o = uart_rxd_pin_i;
        for (int i = 0; i < 16; i++) begin
            case (fn[i])
                F_GPIO: begin pad_out_o[i] = gpio_out_i[i]; pad_oe_o[i] = gpio_oe_i[i]; end
                4'd1, 4'd2, 4'd3, 4'd4: begin pad_out_o[i] = pwm_i[fn[i] - 4'd1]; pad_oe_o[i] = 1'b1; end
                F_SCK:  begin pad_out_o[i] = spi_sck_i;  pad_oe_o[i] = 1'b1; end
                F_MOSI: begin pad_out_o[i] = spi_mosi_i; pad_oe_o[i] = 1'b1; end
                F_SCL:  begin pad_out_o[i] = 1'b0; pad_oe_o[i] = i2c_scl_low_i; end
                F_SDA:  begin pad_out_o[i] = 1'b0; pad_oe_o[i] = i2c_sda_low_i; end
                F_TX:   begin pad_out_o[i] = uart_txd_i; pad_oe_o[i] = 1'b1; end
                default: begin pad_out_o[i] = 1'b0; pad_oe_o[i] = 1'b0; end
            endcase
            if (fn[i] == F_MISO && !miso_seen) begin spi_miso_o = pad_in_i[i]; miso_seen = 1'b1; end
            if (fn[i] == F_SCL && !scl_seen) begin i2c_scl_o = pad_in_i[i]; scl_seen = 1'b1; end
            if (fn[i] == F_SDA && !sda_seen) begin i2c_sda_o = pad_in_i[i]; sda_seen = 1'b1; end
            if (fn[i] == F_RX && !rx_seen) begin uart_rxd_o = pad_in_i[i]; rx_seen = 1'b1; end
        end
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            mux_r[0] <= 32'h0;
            mux_r[1] <= 32'h0;
        end else if (req_i && we_i) begin
            if (off_i == PINMUX0) mux_r[0] <= wdata_i;
            if (off_i == PINMUX1) mux_r[1] <= wdata_i;
        end
    end
endmodule
