// Generated from the uPyCore RTL by mpy_dc_unit.py and sv2v v0.0.12
// (see ../README.md). Do not edit; regenerate with convert_rtl.sh.
module upycore_umul_seq (
	clk_i,
	rst_n_i,
	start_i,
	op_a_i,
	op_b_i,
	product_o,
	done_o,
	busy_o
);
	parameter signed [31:0] AW = 53;
	parameter signed [31:0] BW = 53;
	parameter signed [31:0] STEP = 14;
	input wire clk_i;
	input wire rst_n_i;
	input wire start_i;
	input wire [AW - 1:0] op_a_i;
	input wire [BW - 1:0] op_b_i;
	output wire [(AW + BW) - 1:0] product_o;
	output wire done_o;
	output wire busy_o;
	localparam signed [31:0] NSTEP = ((BW + STEP) - 1) / STEP;
	localparam signed [31:0] BWP = NSTEP * STEP;
	localparam signed [31:0] ACC_W = (AW + STEP) + 1;
	localparam signed [31:0] CNT_W = (NSTEP > 1 ? $clog2(NSTEP) : 1);
	reg busy_r;
	reg done_r;
	reg [CNT_W - 1:0] cnt_r;
	reg [AW - 1:0] a_r;
	reg [BWP - 1:0] b_r;
	reg [ACC_W - 1:0] acc_r;
	reg [BWP - 1:0] lo_r;
	reg [(AW + BW) - 1:0] product_r;
	wire [STEP - 1:0] chunk;
	wire [(AW + STEP) - 1:0] pp;
	wire [ACC_W - 1:0] sum;
	wire [BWP - 1:0] lo_next;
	wire accept;
	wire last_step;
	assign accept = (start_i && !busy_r) && !done_r;
	assign chunk = b_r[STEP - 1:0];
	assign pp = a_r * chunk;
	function automatic [ACC_W - 1:0] sv2v_cast_60BB9;
		input reg [ACC_W - 1:0] inp;
		sv2v_cast_60BB9 = inp;
	endfunction
	assign sum = (acc_r >> STEP) + sv2v_cast_60BB9(pp);
	function automatic [BWP - 1:0] sv2v_cast_EDFA3;
		input reg [BWP - 1:0] inp;
		sv2v_cast_EDFA3 = inp;
	endfunction
	assign lo_next = sv2v_cast_EDFA3(lo_r >> STEP) | (sv2v_cast_EDFA3(sum[STEP - 1:0]) << (BWP - STEP));
	function automatic signed [CNT_W - 1:0] sv2v_cast_7B3D1_signed;
		input reg signed [CNT_W - 1:0] inp;
		sv2v_cast_7B3D1_signed = inp;
	endfunction
	assign last_step = cnt_r == sv2v_cast_7B3D1_signed(NSTEP - 1);
	function automatic [(AW + BW) - 1:0] sv2v_cast_074AA;
		input reg [(AW + BW) - 1:0] inp;
		sv2v_cast_074AA = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			busy_r <= 1'b0;
			done_r <= 1'b0;
			cnt_r <= 1'sb0;
			a_r <= 1'sb0;
			b_r <= 1'sb0;
			acc_r <= 1'sb0;
			lo_r <= 1'sb0;
			product_r <= 1'sb0;
		end
		else begin
			done_r <= 1'b0;
			if (!busy_r) begin
				a_r <= op_a_i;
				b_r <= sv2v_cast_EDFA3(op_b_i);
				acc_r <= 1'sb0;
				cnt_r <= 1'sb0;
				if (accept)
					busy_r <= 1'b1;
			end
			else begin
				b_r <= b_r >> STEP;
				acc_r <= sum;
				lo_r <= lo_next;
				cnt_r <= cnt_r + 1'b1;
				if (last_step)
					product_r <= sv2v_cast_074AA({sum[ACC_W - 1:STEP], lo_next});
				if (!start_i)
					busy_r <= 1'b0;
				else if (last_step) begin
					busy_r <= 1'b0;
					done_r <= 1'b1;
				end
			end
		end
	assign product_o = product_r;
	assign done_o = done_r;
	assign busy_o = busy_r;
endmodule
module upycore_udiv_seq (
	clk_i,
	rst_n_i,
	start_i,
	sqrt_i,
	rem_init_i,
	bits_i,
	divisor_i,
	nsteps_i,
	quotient_o,
	remainder_o,
	done_o,
	busy_o
);
	reg _sv2v_0;
	parameter signed [31:0] DW = 64;
	parameter signed [31:0] VW = 64;
	parameter signed [31:0] RL = 2;
	parameter [0:0] SQRT = 1'b0;
	input wire clk_i;
	input wire rst_n_i;
	input wire start_i;
	input wire sqrt_i;
	input wire [VW - 1:0] rem_init_i;
	input wire [DW - 1:0] bits_i;
	input wire [VW - 1:0] divisor_i;
	input wire [15:0] nsteps_i;
	output wire [DW - 1:0] quotient_o;
	output wire [VW - 1:0] remainder_o;
	output wire done_o;
	output wire busy_o;
	localparam signed [31:0] BR = (SQRT ? 2 * RL : RL);
	localparam signed [31:0] TW = VW + BR;
	generate
		if ((RL != 1) && (RL != 2)) begin : gen_bad_rl
			nonexistent_module_RL_must_be_1_or_2 bad_rl();
		end
	endgenerate
	reg busy_r;
	reg done_r;
	reg [15:0] steps_r;
	reg [VW - 1:0] rem_r;
	reg [DW - 1:0] bits_r;
	reg [TW - 1:0] d1_r;
	reg [TW - 1:0] d2_r;
	reg [TW - 1:0] d3_r;
	reg [DW - 1:0] q_r;
	reg [DW - 1:0] q_result_r;
	reg [VW - 1:0] rem_result_r;
	wire [TW - 1:0] trial;
	wire [TW - 1:0] sub1;
	wire [TW - 1:0] sub2;
	wire [TW - 1:0] sub3;
	wire [TW:0] s1;
	reg [RL - 1:0] qbits;
	reg [VW - 1:0] rem_next;
	reg sqrt_r;
	reg [TW - 1:0] q3p1_r;
	function automatic [TW - 1:0] sv2v_cast_C1BC4;
		input reg [TW - 1:0] inp;
		sv2v_cast_C1BC4 = inp;
	endfunction
	generate
		if (SQRT) begin : gen_sqrt_mode
			assign trial = (sqrt_r ? {rem_r, bits_r[DW - 1-:BR]} : {{BR - RL {1'b0}}, rem_r, bits_r[DW - 1-:RL]});
			if (RL == 2) begin : gen_sqrt4
				assign sub1 = (sqrt_r ? sv2v_cast_C1BC4({q_r, 3'b001}) : d1_r);
				assign sub2 = (sqrt_r ? sv2v_cast_C1BC4({q_r, 4'b0100}) : d2_r);
				assign sub3 = (sqrt_r ? sv2v_cast_C1BC4({q3p1_r, 3'b001}) : d3_r);
			end
			else begin : gen_sqrt2
				assign sub1 = (sqrt_r ? sv2v_cast_C1BC4({q_r, 2'b01}) : d1_r);
				assign sub2 = d2_r;
				assign sub3 = d3_r;
			end
		end
		else begin : gen_div_only
			assign trial = {rem_r, bits_r[DW - 1-:RL]};
			assign sub1 = d1_r;
			assign sub2 = d2_r;
			assign sub3 = d3_r;
		end
	endgenerate
	assign s1 = {1'b0, trial} - {1'b0, sub1};
	generate
		if (RL == 2) begin : gen_radix4
			wire [TW:0] s2;
			wire [TW:0] s3;
			assign s2 = {1'b0, trial} - {1'b0, sub2};
			assign s3 = {1'b0, trial} - {1'b0, sub3};
			always @(*) begin
				if (_sv2v_0)
					;
				if (!s3[TW]) begin
					qbits = 2'd3;
					rem_next = s3[VW - 1:0];
				end
				else if (!s2[TW]) begin
					qbits = 2'd2;
					rem_next = s2[VW - 1:0];
				end
				else if (!s1[TW]) begin
					qbits = 2'd1;
					rem_next = s1[VW - 1:0];
				end
				else begin
					qbits = 2'd0;
					rem_next = trial[VW - 1:0];
				end
			end
		end
		else begin : gen_radix2
			always @(*) begin
				if (_sv2v_0)
					;
				if (!s1[TW]) begin
					qbits = 1'b1;
					rem_next = s1[VW - 1:0];
				end
				else begin
					qbits = 1'b0;
					rem_next = trial[VW - 1:0];
				end
			end
		end
	endgenerate
	reg [TW - 1:0] q3p1_next;
	function automatic signed [TW - 1:0] sv2v_cast_C1BC4_signed;
		input reg signed [TW - 1:0] inp;
		sv2v_cast_C1BC4_signed = inp;
	endfunction
	generate
		if (SQRT && (RL == 2)) begin : gen_q3p1
			wire [TW - 1:0] q3p1_x4;
			wire [TW - 1:0] q3p1_c0;
			wire [TW - 1:0] q3p1_c1;
			wire [TW - 1:0] q3p1_c2;
			wire [TW - 1:0] q3p1_c3;
			assign q3p1_x4 = q3p1_r << 2;
			assign q3p1_c0 = q3p1_x4 - sv2v_cast_C1BC4_signed(3);
			assign q3p1_c1 = q3p1_x4;
			assign q3p1_c2 = q3p1_x4 + sv2v_cast_C1BC4_signed(3);
			assign q3p1_c3 = q3p1_x4 + sv2v_cast_C1BC4_signed(6);
			always @(*) begin
				if (_sv2v_0)
					;
				(* full_case, parallel_case *)
				case (qbits)
					2'd0: q3p1_next = q3p1_c0;
					2'd1: q3p1_next = q3p1_c1;
					2'd2: q3p1_next = q3p1_c2;
					default: q3p1_next = q3p1_c3;
				endcase
			end
		end
		else begin : gen_no_q3p1
			wire [TW:1] sv2v_tmp_56C1F;
			assign sv2v_tmp_56C1F = q3p1_r;
			always @(*) q3p1_next = sv2v_tmp_56C1F;
		end
	endgenerate
	function automatic [DW - 1:0] sv2v_cast_A0774;
		input reg [DW - 1:0] inp;
		sv2v_cast_A0774 = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			busy_r <= 1'b0;
			done_r <= 1'b0;
			steps_r <= 1'sb0;
			rem_r <= 1'sb0;
			bits_r <= 1'sb0;
			d1_r <= 1'sb0;
			d2_r <= 1'sb0;
			d3_r <= 1'sb0;
			q_r <= 1'sb0;
			q_result_r <= 1'sb0;
			rem_result_r <= 1'sb0;
			sqrt_r <= 1'b0;
			q3p1_r <= 1'sb0;
		end
		else begin
			done_r <= 1'b0;
			if ((start_i && !busy_r) && !done_r) begin
				busy_r <= 1'b1;
				steps_r <= nsteps_i;
				rem_r <= rem_init_i;
				bits_r <= bits_i;
				d1_r <= sv2v_cast_C1BC4(divisor_i);
				d2_r <= sv2v_cast_C1BC4(divisor_i) << 1;
				d3_r <= sv2v_cast_C1BC4(divisor_i) + (sv2v_cast_C1BC4(divisor_i) << 1);
				q_r <= 1'sb0;
				sqrt_r <= SQRT && sqrt_i;
				q3p1_r <= sv2v_cast_C1BC4_signed(1);
			end
			else if (busy_r) begin
				if (!start_i)
					busy_r <= 1'b0;
				else if (steps_r == 16'd0) begin
					busy_r <= 1'b0;
					done_r <= 1'b1;
					q_result_r <= q_r;
					rem_result_r <= rem_r;
				end
				else begin
					steps_r <= steps_r - 16'd1;
					rem_r <= rem_next;
					bits_r <= bits_r << (sqrt_r ? BR : RL);
					q_r <= (q_r << RL) | sv2v_cast_A0774(qbits);
					q3p1_r <= q3p1_next;
				end
			end
		end
	assign quotient_o = q_result_r;
	assign remainder_o = rem_result_r;
	assign done_o = done_r;
	assign busy_o = busy_r;
	initial _sv2v_0 = 0;
endmodule
module upycore_int_alu (
	op_a_i,
	op_b_i,
	op_i,
	result_o,
	zero_flag_o,
	overflow_flag_o,
	value_error_o
);
	reg _sv2v_0;
	input wire [63:0] op_a_i;
	input wire [63:0] op_b_i;
	input wire [4:0] op_i;
	output reg [63:0] result_o;
	output wire zero_flag_o;
	output reg overflow_flag_o;
	output reg value_error_o;
	wire signed [63:0] a_s;
	wire signed [63:0] b_s;
	wire signed [64:0] add_ext;
	wire signed [64:0] sub_ext;
	wire signed [63:0] sra;
	wire signed [63:0] sll;
	wire signed [63:0] sll_back;
	reg cmp_result;
	assign a_s = op_a_i;
	assign b_s = op_b_i;
	assign add_ext = {a_s[63], a_s} + {b_s[63], b_s};
	assign sub_ext = {a_s[63], a_s} - {b_s[63], b_s};
	assign sra = a_s >>> op_b_i[5:0];
	assign sll = a_s <<< op_b_i[5:0];
	assign sll_back = sll >>> op_b_i[5:0];
	localparam [4:0] UPY_ALU_ADD = 5'd0;
	localparam [4:0] UPY_ALU_AND = 5'd9;
	localparam [4:0] UPY_ALU_EQ = 5'd16;
	localparam [4:0] UPY_ALU_GE = 5'd21;
	localparam [4:0] UPY_ALU_GT = 5'd20;
	localparam [4:0] UPY_ALU_INVERT = 5'd14;
	localparam [4:0] UPY_ALU_LE = 5'd19;
	localparam [4:0] UPY_ALU_LSHIFT = 5'd7;
	localparam [4:0] UPY_ALU_LT = 5'd18;
	localparam [4:0] UPY_ALU_NE = 5'd17;
	localparam [4:0] UPY_ALU_NEG = 5'd12;
	localparam [4:0] UPY_ALU_NOT = 5'd15;
	localparam [4:0] UPY_ALU_OR = 5'd10;
	localparam [4:0] UPY_ALU_PASS = 5'd22;
	localparam [4:0] UPY_ALU_POS = 5'd13;
	localparam [4:0] UPY_ALU_RSHIFT = 5'd8;
	localparam [4:0] UPY_ALU_SUB = 5'd1;
	localparam [4:0] UPY_ALU_XOR = 5'd11;
	always @(*) begin
		if (_sv2v_0)
			;
		result_o = 64'b0000000000000000000000000000000000000000000000000000000000000000;
		cmp_result = 1'b0;
		overflow_flag_o = 1'b0;
		value_error_o = 1'b0;
		(* full_case, parallel_case *)
		case (op_i)
			UPY_ALU_ADD: begin
				result_o = op_a_i + op_b_i;
				overflow_flag_o = add_ext[64] != add_ext[63];
			end
			UPY_ALU_SUB: begin
				result_o = op_a_i - op_b_i;
				overflow_flag_o = sub_ext[64] != sub_ext[63];
			end
			UPY_ALU_NEG: begin
				result_o = -op_a_i;
				overflow_flag_o = op_a_i == 64'h8000000000000000;
			end
			UPY_ALU_POS, UPY_ALU_PASS: result_o = op_a_i;
			UPY_ALU_INVERT: result_o = ~op_a_i;
			UPY_ALU_LSHIFT: begin
				value_error_o = b_s < 0;
				if (op_b_i[63:6] != 58'b0000000000000000000000000000000000000000000000000000000000) begin
					result_o = 64'b0000000000000000000000000000000000000000000000000000000000000000;
					overflow_flag_o = !value_error_o && (op_a_i != 64'b0000000000000000000000000000000000000000000000000000000000000000);
				end
				else begin
					result_o = sll;
					overflow_flag_o = !value_error_o && (sll_back != a_s);
				end
			end
			UPY_ALU_RSHIFT: begin
				value_error_o = b_s < 0;
				result_o = (op_b_i[63:6] != 58'b0000000000000000000000000000000000000000000000000000000000 ? (a_s[63] ? 64'hffffffffffffffff : 64'b0000000000000000000000000000000000000000000000000000000000000000) : sra);
			end
			UPY_ALU_AND: result_o = op_a_i & op_b_i;
			UPY_ALU_OR: result_o = op_a_i | op_b_i;
			UPY_ALU_XOR: result_o = op_a_i ^ op_b_i;
			UPY_ALU_NOT: result_o = {63'b000000000000000000000000000000000000000000000000000000000000000, op_a_i == 64'b0000000000000000000000000000000000000000000000000000000000000000};
			UPY_ALU_EQ: begin
				cmp_result = op_a_i == op_b_i;
				result_o = {63'b000000000000000000000000000000000000000000000000000000000000000, cmp_result};
			end
			UPY_ALU_NE: begin
				cmp_result = op_a_i != op_b_i;
				result_o = {63'b000000000000000000000000000000000000000000000000000000000000000, cmp_result};
			end
			UPY_ALU_LT: begin
				cmp_result = a_s < b_s;
				result_o = {63'b000000000000000000000000000000000000000000000000000000000000000, cmp_result};
			end
			UPY_ALU_LE: begin
				cmp_result = a_s <= b_s;
				result_o = {63'b000000000000000000000000000000000000000000000000000000000000000, cmp_result};
			end
			UPY_ALU_GT: begin
				cmp_result = a_s > b_s;
				result_o = {63'b000000000000000000000000000000000000000000000000000000000000000, cmp_result};
			end
			UPY_ALU_GE: begin
				cmp_result = a_s >= b_s;
				result_o = {63'b000000000000000000000000000000000000000000000000000000000000000, cmp_result};
			end
			default: result_o = 64'b0000000000000000000000000000000000000000000000000000000000000000;
		endcase
	end
	assign zero_flag_o = result_o == 64'b0000000000000000000000000000000000000000000000000000000000000000;
	initial _sv2v_0 = 0;
endmodule
module upycore_mul (
	clk_i,
	rst_n_i,
	start_i,
	op_a_i,
	op_b_i,
	result_o,
	result_hi_o,
	done_o,
	stall_o,
	busy_o
);
	parameter signed [31:0] STEP = 16;
	input wire clk_i;
	input wire rst_n_i;
	input wire start_i;
	input wire [63:0] op_a_i;
	input wire [63:0] op_b_i;
	output wire [63:0] result_o;
	output wire [63:0] result_hi_o;
	output wire done_o;
	output wire stall_o;
	output wire busy_o;
	localparam signed [31:0] NSTEP = 64 / STEP;
	localparam signed [31:0] ACC_W = (64 + STEP) + 2;
	localparam signed [31:0] CNT_W = (NSTEP > 1 ? $clog2(NSTEP + 1) : 1);
	generate
		if ((64 % STEP) != 0) begin : gen_bad_step
			nonexistent_module_STEP_must_divide_64 bad_step();
		end
	endgenerate
	reg busy_r;
	reg done_r;
	reg [CNT_W - 1:0] cnt_r;
	reg [63:0] a_r;
	reg [63:0] b_r;
	reg signed [ACC_W - 1:0] acc_r;
	reg [63:0] lo_r;
	reg [63:0] lo_result_r;
	reg [63:0] hi_result_r;
	reg product_valid;
	wire last_step;
	wire signed [STEP:0] chunk_s;
	wire signed [32:0] a_low;
	wire signed [32:0] a_high;
	reg signed [STEP + 33:0] pp_low_r;
	reg signed [STEP + 33:0] pp_high_r;
	wire [ACC_W - 1:0] x;
	wire [ACC_W - 1:0] y;
	wire [ACC_W - 1:0] z;
	wire [ACC_W - 1:0] csa_s;
	wire [ACC_W - 1:0] csa_c;
	wire signed [ACC_W - 1:0] sum;
	wire [63:0] lo_next;
	wire accept;
	assign accept = (start_i && !busy_r) && !done_r;
	function automatic signed [CNT_W - 1:0] sv2v_cast_7B3D1_signed;
		input reg signed [CNT_W - 1:0] inp;
		sv2v_cast_7B3D1_signed = inp;
	endfunction
	assign last_step = cnt_r == sv2v_cast_7B3D1_signed(NSTEP - 1);
	assign chunk_s = {(last_step ? b_r[STEP - 1] : 1'b0), b_r[STEP - 1:0]};
	assign a_low = {1'b0, a_r[31:0]};
	assign a_high = {a_r[63], a_r[63:32]};
	function automatic signed [ACC_W - 1:0] sv2v_cast_60BB9_signed;
		input reg signed [ACC_W - 1:0] inp;
		sv2v_cast_60BB9_signed = inp;
	endfunction
	assign x = sv2v_cast_60BB9_signed(pp_low_r);
	assign y = sv2v_cast_60BB9_signed(pp_high_r) << 32;
	assign z = acc_r >>> STEP;
	assign csa_s = (x ^ y) ^ z;
	assign csa_c = ((x & y) | (x & z)) | (y & z);
	assign sum = csa_s + (csa_c << 1);
	function automatic [63:0] sv2v_cast_64;
		input reg [63:0] inp;
		sv2v_cast_64 = inp;
	endfunction
	assign lo_next = (lo_r >> STEP) | (sv2v_cast_64(sum[STEP - 1:0]) << (32'sd64 - STEP));
	function automatic signed [63:0] sv2v_cast_64_signed;
		input reg signed [63:0] inp;
		sv2v_cast_64_signed = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			product_valid <= 1'b0;
			pp_low_r <= 1'sb0;
			pp_high_r <= 1'sb0;
			busy_r <= 1'b0;
			done_r <= 1'b0;
			cnt_r <= 1'sb0;
			a_r <= 1'sb0;
			b_r <= 1'sb0;
			acc_r <= 1'sb0;
			lo_r <= 1'sb0;
			lo_result_r <= 1'sb0;
			hi_result_r <= 1'sb0;
		end
		else begin
			done_r <= 1'b0;
			if (!start_i)
				busy_r <= 1'b0;
			else if (accept) begin
				a_r <= op_a_i;
				b_r <= op_b_i;
				acc_r <= 1'sb0;
				lo_r <= 1'sb0;
				cnt_r <= 1'sb0;
				busy_r <= 1'b1;
				product_valid <= 1'b0;
			end
			else if (busy_r) begin
				if (cnt_r < sv2v_cast_7B3D1_signed(NSTEP)) begin
					pp_low_r <= a_low * chunk_s;
					pp_high_r <= a_high * chunk_s;
					b_r <= b_r >> STEP;
					cnt_r <= cnt_r + 1'b1;
					product_valid <= 1'b1;
				end
				else
					product_valid <= 1'b0;
				if (product_valid) begin
					acc_r <= sum;
					lo_r <= lo_next;
					if (cnt_r == sv2v_cast_7B3D1_signed(NSTEP)) begin
						busy_r <= 1'b0;
						done_r <= 1'b1;
						lo_result_r <= lo_next;
						hi_result_r <= sv2v_cast_64_signed(sum >>> STEP);
					end
				end
			end
		end
	assign result_o = lo_result_r;
	assign result_hi_o = hi_result_r;
	assign done_o = done_r;
	assign stall_o = start_i && !done_r;
	assign busy_o = busy_r;
endmodule
module upycore_div (
	clk_i,
	rst_n_i,
	start_i,
	op_a_i,
	op_b_i,
	quot_o,
	rem_o,
	div_zero_o,
	done_o,
	stall_o,
	busy_o
);
	reg _sv2v_0;
	parameter signed [31:0] RL = 2;
	input wire clk_i;
	input wire rst_n_i;
	input wire start_i;
	input wire [63:0] op_a_i;
	input wire [63:0] op_b_i;
	output wire [63:0] quot_o;
	output wire [63:0] rem_o;
	output wire div_zero_o;
	output wire done_o;
	output wire stall_o;
	output wire busy_o;
	reg [2:0] state_r;
	reg sa_r;
	reg sb_r;
	reg [63:0] a_mag_r;
	reg [63:0] b_mag_r;
	reg [63:0] quot_r;
	reg [63:0] rem_r;
	wire [63:0] a_mag;
	wire [63:0] b_mag;
	assign a_mag = (op_a_i[63] ? ~op_a_i + 64'd1 : op_a_i);
	assign b_mag = (op_b_i[63] ? ~op_b_i + 64'd1 : op_b_i);
	assign div_zero_o = start_i && (op_b_i == 64'd0);
	wire [6:0] lz_a;
	wire [6:0] lz_b;
	wire [7:0] n_q1;
	wire n_q_pos;
	reg [7:0] n_pad;
	reg [63:0] rem_init;
	reg [63:0] bits;
	reg [15:0] nsteps;
	function automatic [6:0] upycore_clz64;
		input reg [63:0] v;
		reg [63:0] x;
		reg [5:0] n;
		begin
			x = v;
			n = 1'sb0;
			if (x[63:32] == 0) begin
				n[5] = 1'b1;
				x = x << 32;
			end
			if (x[63:48] == 0) begin
				n[4] = 1'b1;
				x = x << 16;
			end
			if (x[63:56] == 0) begin
				n[3] = 1'b1;
				x = x << 8;
			end
			if (x[63:60] == 0) begin
				n[2] = 1'b1;
				x = x << 4;
			end
			if (x[63:62] == 0) begin
				n[1] = 1'b1;
				x = x << 2;
			end
			n[0] = !x[63];
			upycore_clz64 = (v == 0 ? 7'd64 : {1'b0, n});
		end
	endfunction
	assign lz_a = upycore_clz64(a_mag_r);
	assign lz_b = upycore_clz64(b_mag_r);
	assign n_q_pos = lz_a <= lz_b;
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
	endfunction
	assign n_q1 = (sv2v_cast_8(lz_b) - sv2v_cast_8(lz_a)) + 8'd2;
	reg [7:0] n_pad_r;
	function automatic [15:0] sv2v_cast_16;
		input reg [15:0] inp;
		sv2v_cast_16 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		if (!n_q_pos)
			n_pad = 8'd0;
		else if (RL == 2)
			n_pad = n_q1 & 8'hfe;
		else
			n_pad = (sv2v_cast_8(lz_b) - sv2v_cast_8(lz_a)) + 8'd1;
		rem_init = a_mag_r >> n_pad_r;
		bits = a_mag_r << (8'd64 - n_pad_r);
		nsteps = (RL == 2 ? sv2v_cast_16(n_pad_r >> 1) : sv2v_cast_16(n_pad_r));
	end
	wire core_start;
	wire core_done;
	wire core_busy;
	wire [63:0] q_mag;
	wire [63:0] r_mag;
	assign core_start = start_i && ((state_r == 3'd2) || (state_r == 3'd3));
	upycore_udiv_seq #(
		.DW(64),
		.VW(64),
		.RL(RL)
	) u_core(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.start_i(core_start),
		.sqrt_i(1'b0),
		.rem_init_i(rem_init),
		.bits_i(bits),
		.divisor_i(b_mag_r),
		.nsteps_i(nsteps),
		.quotient_o(q_mag),
		.remainder_o(r_mag),
		.done_o(core_done),
		.busy_o(core_busy)
	);
	wire signs_differ;
	wire fix;
	wire [63:0] q_neg;
	wire [63:0] r_neg;
	wire [63:0] r_minus_b;
	wire [63:0] b_minus_r;
	reg [63:0] q_floor;
	reg [63:0] r_floor;
	assign signs_differ = sa_r ^ sb_r;
	assign fix = (r_mag != 64'd0) && signs_differ;
	assign q_neg = ~q_mag + 64'd1;
	assign r_neg = ~r_mag + 64'd1;
	assign r_minus_b = r_mag - b_mag_r;
	assign b_minus_r = b_mag_r - r_mag;
	always @(*) begin
		if (_sv2v_0)
			;
		if (fix) begin
			q_floor = ~q_mag;
			r_floor = (sa_r ? b_minus_r : r_minus_b);
		end
		else begin
			q_floor = (signs_differ ? q_neg : q_mag);
			r_floor = (sa_r ? r_neg : r_mag);
		end
	end
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			state_r <= 3'd0;
			sa_r <= 1'b0;
			sb_r <= 1'b0;
			a_mag_r <= 1'sb0;
			b_mag_r <= 1'sb0;
			quot_r <= 1'sb0;
			rem_r <= 1'sb0;
			n_pad_r <= 1'sb0;
		end
		else if (!start_i)
			state_r <= 3'd0;
		else
			(* full_case, parallel_case *)
			case (state_r)
				3'd0:
					if (!div_zero_o) begin
						sa_r <= op_a_i[63];
						sb_r <= op_b_i[63];
						a_mag_r <= a_mag;
						b_mag_r <= b_mag;
						state_r <= 3'd1;
					end
				3'd1: begin
					n_pad_r <= n_pad;
					state_r <= 3'd2;
				end
				3'd2: state_r <= 3'd3;
				3'd3:
					if (core_done) begin
						quot_r <= q_floor;
						rem_r <= r_floor;
						state_r <= 3'd4;
					end
				3'd4: state_r <= 3'd0;
				default: state_r <= 3'd0;
			endcase
	assign quot_o = quot_r;
	assign rem_o = rem_r;
	assign done_o = state_r == 3'd4;
	assign stall_o = (start_i && !done_o) && !div_zero_o;
	assign busy_o = state_r != 3'd0;
	initial _sv2v_0 = 0;
endmodule
module upycore_ipow (
	clk_i,
	rst_n_i,
	start_i,
	base_i,
	exp_i,
	mul_start_o,
	mul_a_o,
	mul_b_o,
	mul_lo_i,
	mul_hi_i,
	mul_done_i,
	result_o,
	trap_o,
	done_o,
	stall_o,
	busy_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_n_i;
	input wire start_i;
	input wire [63:0] base_i;
	input wire [63:0] exp_i;
	output wire mul_start_o;
	output wire [63:0] mul_a_o;
	output wire [63:0] mul_b_o;
	input wire [63:0] mul_lo_i;
	input wire [63:0] mul_hi_i;
	input wire mul_done_i;
	output reg [63:0] result_o;
	output reg trap_o;
	output reg done_o;
	output wire stall_o;
	output wire busy_o;
	reg [2:0] state_r;
	reg [63:0] acc_r;
	reg [63:0] bits_r;
	reg [6:0] cnt_r;
	reg [63:0] result_r;
	wire exp_neg;
	wire exp_zero;
	wire overflow;
	wire [6:0] lz;
	assign exp_neg = exp_i[63];
	assign exp_zero = exp_i == 64'd0;
	assign overflow = mul_hi_i != {64 {mul_lo_i[63]}};
	function automatic [6:0] upycore_clz64;
		input reg [63:0] v;
		reg [63:0] x;
		reg [5:0] n;
		begin
			x = v;
			n = 1'sb0;
			if (x[63:32] == 0) begin
				n[5] = 1'b1;
				x = x << 32;
			end
			if (x[63:48] == 0) begin
				n[4] = 1'b1;
				x = x << 16;
			end
			if (x[63:56] == 0) begin
				n[3] = 1'b1;
				x = x << 8;
			end
			if (x[63:60] == 0) begin
				n[2] = 1'b1;
				x = x << 4;
			end
			if (x[63:62] == 0) begin
				n[1] = 1'b1;
				x = x << 2;
			end
			n[0] = !x[63];
			upycore_clz64 = (v == 0 ? 7'd64 : {1'b0, n});
		end
	endfunction
	assign lz = upycore_clz64(bits_r);
	assign mul_start_o = (state_r == 3'd3) || (state_r == 3'd4);
	assign mul_a_o = acc_r;
	assign mul_b_o = (state_r == 3'd3 ? acc_r : base_i);
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			state_r <= 3'd0;
			acc_r <= 1'sb0;
			bits_r <= 1'sb0;
			cnt_r <= 1'sb0;
			result_r <= 1'sb0;
		end
		else if (!start_i)
			state_r <= 3'd0;
		else
			(* full_case, parallel_case *)
			case (state_r)
				3'd0:
					if (!exp_neg && !exp_zero) begin
						acc_r <= base_i;
						bits_r <= exp_i;
						state_r <= 3'd1;
					end
				3'd1: begin
					bits_r <= bits_r << (lz + 7'd1);
					cnt_r <= 7'd63 - lz;
					state_r <= 3'd2;
				end
				3'd2:
					if (cnt_r == 7'd0) begin
						result_r <= acc_r;
						state_r <= 3'd5;
					end
					else
						state_r <= 3'd3;
				3'd3:
					if (mul_done_i) begin
						acc_r <= mul_lo_i;
						if (overflow)
							state_r <= 3'd6;
						else if (bits_r[63])
							state_r <= 3'd4;
						else begin
							bits_r <= bits_r << 1;
							cnt_r <= cnt_r - 7'd1;
							state_r <= 3'd2;
						end
					end
				3'd4:
					if (mul_done_i) begin
						acc_r <= mul_lo_i;
						bits_r <= bits_r << 1;
						cnt_r <= cnt_r - 7'd1;
						state_r <= (overflow ? 3'd6 : 3'd2);
					end
				3'd5, 3'd6: state_r <= 3'd0;
				default: state_r <= 3'd0;
			endcase
	always @(*) begin
		if (_sv2v_0)
			;
		result_o = result_r;
		done_o = 1'b0;
		trap_o = 1'b0;
		(* full_case, parallel_case *)
		case (state_r)
			3'd0:
				if (start_i) begin
					if (exp_neg)
						trap_o = 1'b1;
					else if (exp_zero) begin
						done_o = 1'b1;
						result_o = 64'd1;
					end
				end
			3'd5: done_o = 1'b1;
			3'd6: trap_o = 1'b1;
			default:
				;
		endcase
	end
	assign stall_o = (start_i && !done_o) && !trap_o;
	assign busy_o = state_r != 3'd0;
	initial _sv2v_0 = 0;
endmodule
module upycore_fp_add (
	clk_i,
	rst_n_i,
	start_i,
	sub_i,
	op_a_i,
	op_b_i,
	result_o,
	done_o,
	busy_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_n_i;
	input wire start_i;
	input wire sub_i;
	input wire [63:0] op_a_i;
	input wire [63:0] op_b_i;
	output wire [63:0] result_o;
	output wire done_o;
	output wire busy_o;
	reg s1_valid_r;
	reg s1_sign_big_r;
	reg s1_sign_small_r;
	reg [10:0] s1_exp_big_r;
	reg [5:0] s1_shift_r;
	wire [10:0] exp_a;
	wire [10:0] exp_b;
	wire [10:0] diff_ab;
	wire [10:0] diff_ba;
	reg [52:0] s1_sig_big_r;
	reg [52:0] s1_sig_small_r;
	reg s1_special_r;
	reg [63:0] s1_special_val_r;
	wire b_sign_eff;
	wire a_bigger;
	wire a_nan;
	wire b_nan;
	wire a_inf;
	wire b_inf;
	reg special;
	reg [63:0] special_val;
	assign b_sign_eff = op_b_i[63] ^ sub_i;
	assign a_bigger = op_a_i[62:0] >= op_b_i[62:0];
	function automatic [10:0] upycore_f64_exp_eff;
		input reg [63:0] v;
		upycore_f64_exp_eff = (v[62:52] == 11'd0 ? 11'd1 : v[62:52]);
	endfunction
	assign exp_a = upycore_f64_exp_eff(op_a_i);
	assign exp_b = upycore_f64_exp_eff(op_b_i);
	assign diff_ab = exp_a - exp_b;
	assign diff_ba = exp_b - exp_a;
	function automatic upycore_f64_is_nan;
		input reg [63:0] v;
		upycore_f64_is_nan = (v[62:52] == 11'h7ff) && (v[51:0] != 52'd0);
	endfunction
	assign a_nan = upycore_f64_is_nan(op_a_i);
	assign b_nan = upycore_f64_is_nan(op_b_i);
	function automatic upycore_f64_is_inf;
		input reg [63:0] v;
		upycore_f64_is_inf = (v[62:52] == 11'h7ff) && (v[51:0] == 52'd0);
	endfunction
	assign a_inf = upycore_f64_is_inf(op_a_i);
	assign b_inf = upycore_f64_is_inf(op_b_i);
	localparam [63:0] UPY_F64_QNAN = 64'h7ff8000000000000;
	always @(*) begin
		if (_sv2v_0)
			;
		special = 1'b0;
		special_val = UPY_F64_QNAN;
		if (a_nan || b_nan)
			special = 1'b1;
		else if (a_inf && b_inf) begin
			special = 1'b1;
			special_val = (op_a_i[63] == b_sign_eff ? op_a_i : UPY_F64_QNAN);
		end
		else if (a_inf) begin
			special = 1'b1;
			special_val = op_a_i;
		end
		else if (b_inf) begin
			special = 1'b1;
			special_val = {b_sign_eff, op_b_i[62:0]};
		end
	end
	reg s2_valid_r;
	reg s2_sign_r;
	reg s2_both_neg_r;
	reg [10:0] s2_exp_r;
	reg [56:0] s2_sum_r;
	reg s2_special_r;
	reg [63:0] s2_special_val_r;
	wire [55:0] ext_big;
	wire [55:0] ext_small;
	reg [55:0] aligned;
	reg [55:0] lost_mask;
	reg sticky;
	reg [56:0] sum;
	assign ext_big = {s1_sig_big_r, 3'b000};
	assign ext_small = {s1_sig_small_r, 3'b000};
	always @(*) begin
		if (_sv2v_0)
			;
		lost_mask = 1'sb0;
		sticky = 1'b0;
		if (s1_shift_r > 6'd55)
			aligned = {55'd0, |ext_small};
		else begin
			lost_mask = (56'd1 << s1_shift_r) - 56'd1;
			sticky = |(ext_small & lost_mask);
			aligned = ext_small >> s1_shift_r;
			aligned[0] = aligned[0] | sticky;
		end
		if (s1_sign_big_r == s1_sign_small_r)
			sum = {1'b0, ext_big} + {1'b0, aligned};
		else
			sum = {1'b0, ext_big} - {1'b0, aligned};
	end
	reg s3_valid_r;
	reg s3_sign_r;
	reg signed [13:0] s3_exp_r;
	reg [52:0] s3_sig_r;
	reg s3_g_r;
	reg s3_r_r;
	reg s3_s_r;
	reg s3_special_r;
	reg [63:0] s3_special_val_r;
	reg [5:0] lz;
	reg [5:0] sh;
	reg [55:0] norm;
	reg n_sign;
	reg signed [13:0] n_exp;
	reg [52:0] n_sig;
	reg n_g;
	reg n_r;
	reg n_s;
	function automatic [6:0] upycore_clz64;
		input reg [63:0] v;
		reg [63:0] x;
		reg [5:0] n;
		begin
			x = v;
			n = 1'sb0;
			if (x[63:32] == 0) begin
				n[5] = 1'b1;
				x = x << 32;
			end
			if (x[63:48] == 0) begin
				n[4] = 1'b1;
				x = x << 16;
			end
			if (x[63:56] == 0) begin
				n[3] = 1'b1;
				x = x << 8;
			end
			if (x[63:60] == 0) begin
				n[2] = 1'b1;
				x = x << 4;
			end
			if (x[63:62] == 0) begin
				n[1] = 1'b1;
				x = x << 2;
			end
			n[0] = !x[63];
			upycore_clz64 = (v == 0 ? 7'd64 : {1'b0, n});
		end
	endfunction
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
	function automatic [5:0] upycore_clz56;
		input reg [55:0] v;
		upycore_clz56 = sv2v_cast_6(upycore_clz64({v, 8'h80}));
	endfunction
	function automatic [13:0] sv2v_cast_14;
		input reg [13:0] inp;
		sv2v_cast_14 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		lz = upycore_clz56(s2_sum_r[55:0]);
		sh = (sv2v_cast_14(lz) < (sv2v_cast_14(s2_exp_r) - 14'd1) ? lz : sv2v_cast_6(s2_exp_r - 11'd1));
		norm = s2_sum_r[55:0] << sh;
		n_sign = s2_sign_r;
		if (s2_sum_r[56]) begin
			n_exp = $signed(sv2v_cast_14(s2_exp_r)) + 14'sd1;
			n_sig = s2_sum_r[56:4];
			n_g = s2_sum_r[3];
			n_r = s2_sum_r[2];
			n_s = s2_sum_r[1] | s2_sum_r[0];
		end
		else begin
			n_exp = $signed(sv2v_cast_14(s2_exp_r)) - $signed(sv2v_cast_14(sh));
			n_sig = norm[55:3];
			n_g = norm[2];
			n_r = norm[1];
			n_s = norm[0];
		end
		if (s2_sum_r == 57'd0)
			n_sign = s2_both_neg_r;
	end
	function automatic [52:0] upycore_f64_sig;
		input reg [63:0] v;
		upycore_f64_sig = {v[62:52] != 11'd0, v[51:0]};
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			s1_valid_r <= 1'b0;
			s2_valid_r <= 1'b0;
			s3_valid_r <= 1'b0;
			s1_sign_big_r <= 1'b0;
			s1_sign_small_r <= 1'b0;
			s1_exp_big_r <= 1'sb0;
			s1_shift_r <= 1'sb0;
			s1_sig_big_r <= 1'sb0;
			s1_sig_small_r <= 1'sb0;
			s1_special_r <= 1'b0;
			s1_special_val_r <= 1'sb0;
			s2_sign_r <= 1'b0;
			s2_both_neg_r <= 1'b0;
			s2_exp_r <= 1'sb0;
			s2_sum_r <= 1'sb0;
			s2_special_r <= 1'b0;
			s2_special_val_r <= 1'sb0;
			s3_sign_r <= 1'b0;
			s3_exp_r <= 1'sb0;
			s3_sig_r <= 1'sb0;
			s3_g_r <= 1'b0;
			s3_r_r <= 1'b0;
			s3_s_r <= 1'b0;
			s3_special_r <= 1'b0;
			s3_special_val_r <= 1'sb0;
		end
		else if (!start_i) begin
			s1_valid_r <= 1'b0;
			s2_valid_r <= 1'b0;
			s3_valid_r <= 1'b0;
		end
		else begin
			s1_valid_r <= start_i && !busy_o;
			if (a_bigger) begin
				s1_sign_big_r <= op_a_i[63];
				s1_sign_small_r <= b_sign_eff;
				s1_exp_big_r <= exp_a;
				s1_shift_r <= (diff_ab > 11'd55 ? 6'd56 : diff_ab[5:0]);
				s1_sig_big_r <= upycore_f64_sig(op_a_i);
				s1_sig_small_r <= upycore_f64_sig(op_b_i);
			end
			else begin
				s1_sign_big_r <= b_sign_eff;
				s1_sign_small_r <= op_a_i[63];
				s1_exp_big_r <= exp_b;
				s1_shift_r <= (diff_ba > 11'd55 ? 6'd56 : diff_ba[5:0]);
				s1_sig_big_r <= upycore_f64_sig(op_b_i);
				s1_sig_small_r <= upycore_f64_sig(op_a_i);
			end
			s1_special_r <= special;
			s1_special_val_r <= special_val;
			s2_valid_r <= s1_valid_r;
			s2_sign_r <= s1_sign_big_r;
			s2_both_neg_r <= s1_sign_big_r & s1_sign_small_r;
			s2_exp_r <= s1_exp_big_r;
			s2_sum_r <= sum;
			s2_special_r <= s1_special_r;
			s2_special_val_r <= s1_special_val_r;
			s3_valid_r <= s2_valid_r;
			s3_sign_r <= n_sign;
			s3_exp_r <= n_exp;
			s3_sig_r <= n_sig;
			s3_g_r <= n_g;
			s3_r_r <= n_r;
			s3_s_r <= n_s;
			s3_special_r <= s2_special_r;
			s3_special_val_r <= s2_special_val_r;
		end
	reg s4_valid_r;
	reg [63:0] s4_res_r;
	reg dn_pend_r;
	reg dn_sign_r;
	reg [55:0] dn_r;
	wire [55:0] s3_ext;
	assign s3_ext = {s3_sig_r, s3_g_r, s3_r_r, s3_s_r};
	function automatic [55:0] upycore_f64_denorm;
		input reg [55:0] ext;
		input reg signed [13:0] exp_s;
		reg signed [13:0] sh;
		reg [55:0] lost_mask;
		begin
			sh = 14'sd1 - exp_s;
			if (sh > 14'sd55)
				upycore_f64_denorm = {55'd0, |ext};
			else begin
				lost_mask = (56'd1 << sh[5:0]) - 56'd1;
				upycore_f64_denorm = ext >> sh[5:0];
				upycore_f64_denorm[0] = upycore_f64_denorm[0] | (|(ext & lost_mask));
			end
		end
	endfunction
	localparam [63:0] UPY_F64_PINF = 64'h7ff0000000000000;
	function automatic [63:0] upycore_f64_round_pack;
		input reg sign;
		input reg signed [13:0] exp_eff_i;
		input reg [55:0] shifted;
		reg inc;
		reg [53:0] sig_r;
		reg signed [13:0] exp_eff;
		reg [10:0] e_field;
		begin
			exp_eff = exp_eff_i;
			if (shifted == 56'd0)
				upycore_f64_round_pack = {sign, 63'd0};
			else begin
				inc = shifted[2] & ((shifted[1] | shifted[0]) | shifted[3]);
				sig_r = {1'b0, shifted[55:3]} + {53'd0, inc};
				if (sig_r[53]) begin
					sig_r = sig_r >> 1;
					exp_eff = exp_eff + 14'sd1;
				end
				if (exp_eff >= 14'sd2047)
					upycore_f64_round_pack = {sign, UPY_F64_PINF[62:0]};
				else begin
					e_field = (sig_r[52] ? exp_eff[10:0] : 11'd0);
					upycore_f64_round_pack = {sign, e_field, sig_r[51:0]};
				end
			end
		end
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			s4_valid_r <= 1'b0;
			s4_res_r <= 1'sb0;
			dn_pend_r <= 1'b0;
			dn_sign_r <= 1'b0;
			dn_r <= 1'sb0;
		end
		else if (!start_i) begin
			s4_valid_r <= 1'b0;
			dn_pend_r <= 1'b0;
		end
		else begin
			s4_valid_r <= dn_pend_r || (s3_valid_r && (s3_special_r || (s3_exp_r > 14'sd0)));
			dn_pend_r <= (s3_valid_r && !s3_special_r) && (s3_exp_r <= 14'sd0);
			if (dn_pend_r)
				s4_res_r <= upycore_f64_round_pack(dn_sign_r, 14'sd1, dn_r);
			else
				s4_res_r <= (s3_special_r ? s3_special_val_r : upycore_f64_round_pack(s3_sign_r, s3_exp_r, s3_ext));
			dn_sign_r <= s3_sign_r;
			dn_r <= upycore_f64_denorm(s3_ext, s3_exp_r);
		end
	assign result_o = s4_res_r;
	assign done_o = s4_valid_r;
	assign busy_o = (((s1_valid_r | s2_valid_r) | s3_valid_r) | dn_pend_r) | s4_valid_r;
	initial _sv2v_0 = 0;
endmodule
module upycore_fp_mul (
	clk_i,
	rst_n_i,
	start_i,
	op_a_i,
	op_b_i,
	result_o,
	done_o,
	busy_o,
	mul_start_o,
	mul_a_o,
	mul_b_o,
	mul_product_i,
	mul_done_i,
	mul_busy_i
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_n_i;
	input wire start_i;
	input wire [63:0] op_a_i;
	input wire [63:0] op_b_i;
	output wire [63:0] result_o;
	output wire done_o;
	output wire busy_o;
	output wire mul_start_o;
	output wire [52:0] mul_a_o;
	output wire [52:0] mul_b_o;
	input wire [105:0] mul_product_i;
	input wire mul_done_i;
	input wire mul_busy_i;
	reg s1_valid_r;
	reg s1_sign_r;
	reg signed [13:0] s1_exp_r;
	reg [10:0] s1_ea_r;
	reg [10:0] s1_eb_r;
	reg [5:0] s1_lza_r;
	reg [5:0] s1_lzb_r;
	reg [52:0] s1_sig_a_r;
	reg [52:0] s1_sig_b_r;
	reg s1_special_r;
	reg [63:0] s1_special_val_r;
	wire [52:0] sig_a;
	wire [52:0] sig_b;
	wire [52:0] sig_a_n;
	wire [52:0] sig_b_n;
	wire [5:0] lz_a;
	wire [5:0] lz_b;
	wire signed [13:0] exp_a_n;
	wire signed [13:0] exp_b_n;
	wire a_nan;
	wire b_nan;
	wire a_inf;
	wire b_inf;
	wire a_zero;
	wire b_zero;
	wire sign;
	reg special;
	reg [63:0] special_val;
	function automatic [52:0] upycore_f64_sig;
		input reg [63:0] v;
		upycore_f64_sig = {v[62:52] != 11'd0, v[51:0]};
	endfunction
	assign sig_a = upycore_f64_sig(op_a_i);
	assign sig_b = upycore_f64_sig(op_b_i);
	function automatic [6:0] upycore_clz64;
		input reg [63:0] v;
		reg [63:0] x;
		reg [5:0] n;
		begin
			x = v;
			n = 1'sb0;
			if (x[63:32] == 0) begin
				n[5] = 1'b1;
				x = x << 32;
			end
			if (x[63:48] == 0) begin
				n[4] = 1'b1;
				x = x << 16;
			end
			if (x[63:56] == 0) begin
				n[3] = 1'b1;
				x = x << 8;
			end
			if (x[63:60] == 0) begin
				n[2] = 1'b1;
				x = x << 4;
			end
			if (x[63:62] == 0) begin
				n[1] = 1'b1;
				x = x << 2;
			end
			n[0] = !x[63];
			upycore_clz64 = (v == 0 ? 7'd64 : {1'b0, n});
		end
	endfunction
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
	function automatic [5:0] upycore_clz53;
		input reg [52:0] v;
		upycore_clz53 = sv2v_cast_6(upycore_clz64({v, 11'h400}));
	endfunction
	assign lz_a = upycore_clz53(sig_a);
	assign lz_b = upycore_clz53(sig_b);
	assign sig_a_n = sig_a << lz_a;
	assign sig_b_n = sig_b << lz_b;
	function automatic [10:0] upycore_f64_exp_eff;
		input reg [63:0] v;
		upycore_f64_exp_eff = (v[62:52] == 11'd0 ? 11'd1 : v[62:52]);
	endfunction
	function automatic [13:0] sv2v_cast_14;
		input reg [13:0] inp;
		sv2v_cast_14 = inp;
	endfunction
	assign exp_a_n = $signed(sv2v_cast_14(upycore_f64_exp_eff(op_a_i))) - $signed(sv2v_cast_14(lz_a));
	assign exp_b_n = $signed(sv2v_cast_14(upycore_f64_exp_eff(op_b_i))) - $signed(sv2v_cast_14(lz_b));
	function automatic upycore_f64_is_nan;
		input reg [63:0] v;
		upycore_f64_is_nan = (v[62:52] == 11'h7ff) && (v[51:0] != 52'd0);
	endfunction
	assign a_nan = upycore_f64_is_nan(op_a_i);
	assign b_nan = upycore_f64_is_nan(op_b_i);
	function automatic upycore_f64_is_inf;
		input reg [63:0] v;
		upycore_f64_is_inf = (v[62:52] == 11'h7ff) && (v[51:0] == 52'd0);
	endfunction
	assign a_inf = upycore_f64_is_inf(op_a_i);
	assign b_inf = upycore_f64_is_inf(op_b_i);
	function automatic upycore_f64_is_zero;
		input reg [63:0] v;
		upycore_f64_is_zero = v[62:0] == 63'd0;
	endfunction
	assign a_zero = upycore_f64_is_zero(op_a_i);
	assign b_zero = upycore_f64_is_zero(op_b_i);
	assign sign = op_a_i[63] ^ op_b_i[63];
	localparam [63:0] UPY_F64_PINF = 64'h7ff0000000000000;
	localparam [63:0] UPY_F64_QNAN = 64'h7ff8000000000000;
	always @(*) begin
		if (_sv2v_0)
			;
		special = 1'b0;
		special_val = UPY_F64_QNAN;
		if (a_nan || b_nan)
			special = 1'b1;
		else if (a_inf || b_inf) begin
			special = 1'b1;
			special_val = (a_zero || b_zero ? UPY_F64_QNAN : {sign, UPY_F64_PINF[62:0]});
		end
		else if (a_zero || b_zero) begin
			special = 1'b1;
			special_val = {sign, 63'd0};
		end
	end
	wire [105:0] product;
	wire mul_done;
	wire mul_busy;
	assign mul_start_o = start_i && (s1_valid_r || mul_busy);
	assign mul_a_o = s1_sig_a_r;
	assign mul_b_o = s1_sig_b_r;
	assign product = mul_product_i;
	assign mul_done = mul_done_i;
	assign mul_busy = mul_busy_i;
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			s1_valid_r <= 1'b0;
			s1_sign_r <= 1'b0;
			s1_exp_r <= 1'sb0;
			s1_ea_r <= 1'sb0;
			s1_eb_r <= 1'sb0;
			s1_lza_r <= 1'sb0;
			s1_lzb_r <= 1'sb0;
			s1_sig_a_r <= 1'sb0;
			s1_sig_b_r <= 1'sb0;
			s1_special_r <= 1'b0;
			s1_special_val_r <= 1'sb0;
		end
		else if (!start_i)
			s1_valid_r <= 1'b0;
		else begin
			s1_valid_r <= start_i && !busy_o;
			if (s1_valid_r)
				s1_exp_r <= ((($signed(sv2v_cast_14(s1_ea_r)) - $signed(sv2v_cast_14(s1_lza_r))) + $signed(sv2v_cast_14(s1_eb_r))) - $signed(sv2v_cast_14(s1_lzb_r))) - 14'sd1023;
			if (start_i && !busy_o) begin
				s1_sign_r <= sign;
				s1_ea_r <= upycore_f64_exp_eff(op_a_i);
				s1_eb_r <= upycore_f64_exp_eff(op_b_i);
				s1_lza_r <= lz_a;
				s1_lzb_r <= lz_b;
				s1_sig_a_r <= sig_a_n;
				s1_sig_b_r <= sig_b_n;
				s1_special_r <= special;
				s1_special_val_r <= special_val;
			end
		end
	reg signed [13:0] r_exp;
	reg [52:0] r_sig;
	reg r_g;
	reg r_r;
	reg r_s;
	always @(*) begin
		if (_sv2v_0)
			;
		if (product[105]) begin
			r_exp = s1_exp_r + 14'sd1;
			r_sig = product[105:53];
			r_g = product[52];
			r_r = product[51];
			r_s = |product[50:0];
		end
		else begin
			r_exp = s1_exp_r;
			r_sig = product[104:52];
			r_g = product[51];
			r_r = product[50];
			r_s = |product[49:0];
		end
	end
	reg out_valid_r;
	reg [63:0] out_res_r;
	reg dn_pend_r;
	reg dn_sign_r;
	reg [55:0] dn_r;
	wire [55:0] r_ext;
	assign r_ext = {r_sig, r_g, r_r, r_s};
	function automatic [55:0] upycore_f64_denorm;
		input reg [55:0] ext;
		input reg signed [13:0] exp_s;
		reg signed [13:0] sh;
		reg [55:0] lost_mask;
		begin
			sh = 14'sd1 - exp_s;
			if (sh > 14'sd55)
				upycore_f64_denorm = {55'd0, |ext};
			else begin
				lost_mask = (56'd1 << sh[5:0]) - 56'd1;
				upycore_f64_denorm = ext >> sh[5:0];
				upycore_f64_denorm[0] = upycore_f64_denorm[0] | (|(ext & lost_mask));
			end
		end
	endfunction
	function automatic [63:0] upycore_f64_round_pack;
		input reg sign;
		input reg signed [13:0] exp_eff_i;
		input reg [55:0] shifted;
		reg inc;
		reg [53:0] sig_r;
		reg signed [13:0] exp_eff;
		reg [10:0] e_field;
		begin
			exp_eff = exp_eff_i;
			if (shifted == 56'd0)
				upycore_f64_round_pack = {sign, 63'd0};
			else begin
				inc = shifted[2] & ((shifted[1] | shifted[0]) | shifted[3]);
				sig_r = {1'b0, shifted[55:3]} + {53'd0, inc};
				if (sig_r[53]) begin
					sig_r = sig_r >> 1;
					exp_eff = exp_eff + 14'sd1;
				end
				if (exp_eff >= 14'sd2047)
					upycore_f64_round_pack = {sign, UPY_F64_PINF[62:0]};
				else begin
					e_field = (sig_r[52] ? exp_eff[10:0] : 11'd0);
					upycore_f64_round_pack = {sign, e_field, sig_r[51:0]};
				end
			end
		end
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			out_valid_r <= 1'b0;
			out_res_r <= 1'sb0;
			dn_pend_r <= 1'b0;
			dn_sign_r <= 1'b0;
			dn_r <= 1'sb0;
		end
		else if (!start_i) begin
			out_valid_r <= 1'b0;
			dn_pend_r <= 1'b0;
		end
		else begin
			out_valid_r <= dn_pend_r || (mul_done && (s1_special_r || (r_exp > 14'sd0)));
			dn_pend_r <= (mul_done && !s1_special_r) && (r_exp <= 14'sd0);
			if (dn_pend_r)
				out_res_r <= upycore_f64_round_pack(dn_sign_r, 14'sd1, dn_r);
			else
				out_res_r <= (s1_special_r ? s1_special_val_r : upycore_f64_round_pack(s1_sign_r, r_exp, r_ext));
			dn_sign_r <= s1_sign_r;
			dn_r <= upycore_f64_denorm(r_ext, r_exp);
		end
	assign result_o = out_res_r;
	assign done_o = out_valid_r;
	assign busy_o = (((s1_valid_r | mul_busy) | mul_done) | dn_pend_r) | out_valid_r;
	initial _sv2v_0 = 0;
endmodule
module upycore_fp_divrem (
	clk_i,
	rst_n_i,
	start_i,
	fmod_i,
	sqrt_i,
	op_a_i,
	op_b_i,
	result_o,
	done_o,
	busy_o
);
	reg _sv2v_0;
	parameter signed [31:0] RL = 2;
	input wire clk_i;
	input wire rst_n_i;
	input wire start_i;
	input wire fmod_i;
	input wire sqrt_i;
	input wire [63:0] op_a_i;
	input wire [63:0] op_b_i;
	output wire [63:0] result_o;
	output wire done_o;
	output wire busy_o;
	localparam signed [31:0] DIV_STEPS = 56 / RL;
	localparam signed [31:0] SQRT_STEPS = (RL == 2 ? 28 : 55);
	localparam signed [31:0] RW = 57;
	reg s1_valid_r;
	reg s1_fmod_r;
	reg s1_sqrt_r;
	reg s1_sign_r;
	reg signed [13:0] s1_exp_a_r;
	reg signed [13:0] s1_exp_b_r;
	reg [52:0] s1_sig_a_r;
	reg [52:0] s1_sig_b_r;
	reg s1_special_r;
	reg [63:0] s1_special_val_r;
	reg [63:0] s1_a_r;
	wire [52:0] sig_a;
	wire [52:0] sig_b;
	wire [5:0] lz_a;
	wire [5:0] lz_b;
	wire a_nan;
	wire b_nan;
	wire a_inf;
	wire b_inf;
	wire a_zero;
	wire b_zero;
	wire qsign;
	reg special;
	reg [63:0] special_val;
	function automatic [52:0] upycore_f64_sig;
		input reg [63:0] v;
		upycore_f64_sig = {v[62:52] != 11'd0, v[51:0]};
	endfunction
	assign sig_a = upycore_f64_sig(op_a_i);
	assign sig_b = upycore_f64_sig(op_b_i);
	function automatic [6:0] upycore_clz64;
		input reg [63:0] v;
		reg [63:0] x;
		reg [5:0] n;
		begin
			x = v;
			n = 1'sb0;
			if (x[63:32] == 0) begin
				n[5] = 1'b1;
				x = x << 32;
			end
			if (x[63:48] == 0) begin
				n[4] = 1'b1;
				x = x << 16;
			end
			if (x[63:56] == 0) begin
				n[3] = 1'b1;
				x = x << 8;
			end
			if (x[63:60] == 0) begin
				n[2] = 1'b1;
				x = x << 4;
			end
			if (x[63:62] == 0) begin
				n[1] = 1'b1;
				x = x << 2;
			end
			n[0] = !x[63];
			upycore_clz64 = (v == 0 ? 7'd64 : {1'b0, n});
		end
	endfunction
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
	function automatic [5:0] upycore_clz53;
		input reg [52:0] v;
		upycore_clz53 = sv2v_cast_6(upycore_clz64({v, 11'h400}));
	endfunction
	assign lz_a = upycore_clz53(sig_a);
	assign lz_b = upycore_clz53(sig_b);
	function automatic upycore_f64_is_nan;
		input reg [63:0] v;
		upycore_f64_is_nan = (v[62:52] == 11'h7ff) && (v[51:0] != 52'd0);
	endfunction
	assign a_nan = upycore_f64_is_nan(op_a_i);
	assign b_nan = upycore_f64_is_nan(op_b_i);
	function automatic upycore_f64_is_inf;
		input reg [63:0] v;
		upycore_f64_is_inf = (v[62:52] == 11'h7ff) && (v[51:0] == 52'd0);
	endfunction
	assign a_inf = upycore_f64_is_inf(op_a_i);
	assign b_inf = upycore_f64_is_inf(op_b_i);
	function automatic upycore_f64_is_zero;
		input reg [63:0] v;
		upycore_f64_is_zero = v[62:0] == 63'd0;
	endfunction
	assign a_zero = upycore_f64_is_zero(op_a_i);
	assign b_zero = upycore_f64_is_zero(op_b_i);
	assign qsign = op_a_i[63] ^ op_b_i[63];
	localparam [63:0] UPY_F64_PINF = 64'h7ff0000000000000;
	localparam [63:0] UPY_F64_QNAN = 64'h7ff8000000000000;
	always @(*) begin
		if (_sv2v_0)
			;
		special = 1'b0;
		special_val = UPY_F64_QNAN;
		if (sqrt_i) begin
			if (a_nan || (op_a_i[63] && !a_zero))
				special = 1'b1;
			else if (a_inf || a_zero) begin
				special = 1'b1;
				special_val = op_a_i;
			end
		end
		else if (a_nan || b_nan)
			special = 1'b1;
		else if (fmod_i) begin
			if (a_inf || b_zero)
				special = 1'b1;
			else if (b_inf || a_zero) begin
				special = 1'b1;
				special_val = op_a_i;
			end
		end
		else if (a_inf && b_inf)
			special = 1'b1;
		else if (a_inf) begin
			special = 1'b1;
			special_val = {qsign, UPY_F64_PINF[62:0]};
		end
		else if (b_inf) begin
			special = 1'b1;
			special_val = {qsign, 63'd0};
		end
		else if (b_zero) begin
			special = 1'b1;
			special_val = (a_zero ? UPY_F64_QNAN : {qsign, UPY_F64_PINF[62:0]});
		end
		else if (a_zero) begin
			special = 1'b1;
			special_val = {qsign, 63'd0};
		end
	end
	wire signed [13:0] d;
	wire signed [13:0] n_bits;
	wire fmod_small;
	wire pad;
	reg [56:0] rem_init;
	reg [55:0] bits;
	reg [15:0] nsteps;
	assign d = s1_exp_a_r - s1_exp_b_r;
	assign n_bits = d + 14'sd1;
	assign fmod_small = s1_fmod_r && (d < 14'sd0);
	assign pad = (RL == 2) && n_bits[0];
	function automatic signed [15:0] sv2v_cast_16_signed;
		input reg signed [15:0] inp;
		sv2v_cast_16_signed = inp;
	endfunction
	function automatic [56:0] sv2v_cast_57;
		input reg [56:0] inp;
		sv2v_cast_57 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		if (s1_sqrt_r) begin
			rem_init = 1'sb0;
			bits = (!s1_exp_a_r[0] ? {s1_sig_a_r, 3'b000} : {1'b0, s1_sig_a_r, 2'b00});
			nsteps = sv2v_cast_16_signed(SQRT_STEPS);
		end
		else if (!s1_fmod_r) begin
			rem_init = sv2v_cast_57(s1_sig_a_r >> 1);
			bits = {s1_sig_a_r[0], 55'd0};
			nsteps = sv2v_cast_16_signed(DIV_STEPS);
		end
		else if (pad) begin
			rem_init = sv2v_cast_57(s1_sig_a_r >> 2);
			bits = {s1_sig_a_r[1:0], 54'd0};
			nsteps = sv2v_cast_16_signed((n_bits + 14'sd1) >>> 1);
		end
		else begin
			rem_init = sv2v_cast_57(s1_sig_a_r >> 1);
			bits = {s1_sig_a_r[0], 55'd0};
			nsteps = (RL == 2 ? sv2v_cast_16_signed(n_bits >>> 1) : sv2v_cast_16_signed(n_bits));
		end
	end
	wire core_start;
	wire core_busy;
	wire core_done;
	wire [55:0] quot;
	wire [56:0] rem;
	reg fin_r;
	reg s2_fmod_r;
	reg s2_sqrt_r;
	reg s2_sign_r;
	reg signed [13:0] s2_exp_r;
	reg s2_special_r;
	reg [63:0] s2_special_val_r;
	reg signed [13:0] r_exp;
	reg [52:0] r_sig;
	reg r_g;
	reg r_r;
	reg r_s;
	reg mod_norm_r;
	wire pack_result;
	reg [5:0] rem_lz_r;
	reg [52:0] mod_rem_r;
	reg p_valid_r;
	reg p_special_r;
	reg p_sign_r;
	reg p_g_r;
	reg p_r_r;
	reg p_s_r;
	reg [63:0] p_special_val_r;
	reg signed [13:0] p_exp_r;
	reg [52:0] p_sig_r;
	assign pack_result = ((core_done && !s2_fmod_r) || fin_r) || mod_norm_r;
	assign core_start = (start_i && !fin_r) && (((s1_valid_r && !s1_special_r) && !fmod_small) || core_busy);
	upycore_udiv_seq #(
		.DW(56),
		.VW(RW),
		.RL(RL),
		.SQRT(1'b1)
	) u_div(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.start_i(core_start),
		.sqrt_i(s1_sqrt_r),
		.rem_init_i(rem_init),
		.bits_i(bits),
		.divisor_i(sv2v_cast_57(s1_sig_b_r)),
		.nsteps_i(nsteps),
		.quotient_o(quot),
		.remainder_o(rem),
		.done_o(core_done),
		.busy_o(core_busy)
	);
	function automatic [10:0] upycore_f64_exp_eff;
		input reg [63:0] v;
		upycore_f64_exp_eff = (v[62:52] == 11'd0 ? 11'd1 : v[62:52]);
	endfunction
	function automatic [13:0] sv2v_cast_14;
		input reg [13:0] inp;
		sv2v_cast_14 = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			s1_valid_r <= 1'b0;
			s1_fmod_r <= 1'b0;
			s1_sqrt_r <= 1'b0;
			s1_sign_r <= 1'b0;
			s1_exp_a_r <= 1'sb0;
			s1_exp_b_r <= 1'sb0;
			s1_sig_a_r <= 1'sb0;
			s1_sig_b_r <= 1'sb0;
			s1_special_r <= 1'b0;
			s1_special_val_r <= 1'sb0;
			s1_a_r <= 1'sb0;
			fin_r <= 1'b0;
			s2_fmod_r <= 1'b0;
			s2_sqrt_r <= 1'b0;
			s2_sign_r <= 1'b0;
			s2_exp_r <= 1'sb0;
			s2_special_r <= 1'b0;
			s2_special_val_r <= 1'sb0;
			mod_norm_r <= 1'b0;
			rem_lz_r <= 1'sb0;
			mod_rem_r <= 1'sb0;
			p_valid_r <= 1'b0;
			p_special_r <= 1'b0;
			p_sign_r <= 1'b0;
			p_g_r <= 1'b0;
			p_r_r <= 1'b0;
			p_s_r <= 1'b0;
			p_special_val_r <= 1'sb0;
			p_exp_r <= 1'sb0;
			p_sig_r <= 1'sb0;
		end
		else if (!start_i) begin
			s1_valid_r <= 1'b0;
			fin_r <= 1'b0;
			p_valid_r <= 1'b0;
			mod_norm_r <= 1'b0;
		end
		else begin
			mod_norm_r <= core_done && s2_fmod_r;
			if (core_done && s2_fmod_r) begin
				rem_lz_r <= upycore_clz53(rem[52:0]);
				mod_rem_r <= rem[52:0];
			end
			p_valid_r <= pack_result;
			if (pack_result) begin
				p_special_r <= s2_special_r;
				p_special_val_r <= s2_special_val_r;
				p_sign_r <= s2_sign_r;
				p_exp_r <= r_exp;
				p_sig_r <= r_sig;
				p_g_r <= r_g;
				p_r_r <= r_r;
				p_s_r <= r_s;
			end
			s1_valid_r <= start_i && !busy_o;
			if (start_i && !busy_o) begin
				s1_fmod_r <= fmod_i;
				s1_sqrt_r <= sqrt_i;
				s1_sign_r <= (sqrt_i ? 1'b0 : (fmod_i ? op_a_i[63] : qsign));
				s1_exp_a_r <= $signed(sv2v_cast_14(upycore_f64_exp_eff(op_a_i))) - $signed(sv2v_cast_14(lz_a));
				s1_exp_b_r <= $signed(sv2v_cast_14(upycore_f64_exp_eff(op_b_i))) - $signed(sv2v_cast_14(lz_b));
				s1_sig_a_r <= sig_a << lz_a;
				s1_sig_b_r <= sig_b << lz_b;
				s1_special_r <= special;
				s1_special_val_r <= special_val;
				s1_a_r <= op_a_i;
			end
			fin_r <= s1_valid_r && (s1_special_r || fmod_small);
			if (s1_valid_r) begin
				s2_fmod_r <= s1_fmod_r;
				s2_sqrt_r <= s1_sqrt_r;
				s2_sign_r <= s1_sign_r;
				s2_exp_r <= (s1_sqrt_r ? ((s1_exp_a_r - 14'sd1023) >>> 1) + 14'sd1023 : (s1_fmod_r ? s1_exp_b_r : d + 14'sd1023));
				s2_special_r <= s1_special_r || fmod_small;
				s2_special_val_r <= (s1_special_r ? s1_special_val_r : s1_a_r);
			end
		end
	always @(*) begin
		if (_sv2v_0)
			;
		if (s2_fmod_r) begin
			r_exp = s2_exp_r - $signed(sv2v_cast_14(rem_lz_r));
			r_sig = mod_rem_r << rem_lz_r;
			r_g = 1'b0;
			r_r = 1'b0;
			r_s = 1'b0;
		end
		else if (s2_sqrt_r) begin
			r_exp = s2_exp_r;
			if (RL == 2) begin
				r_sig = quot[55:3];
				r_g = quot[2];
				r_r = quot[1];
				r_s = quot[0] | (rem != {57 {1'sb0}});
			end
			else begin
				r_sig = quot[54:2];
				r_g = quot[1];
				r_r = quot[0];
				r_s = rem != {57 {1'sb0}};
			end
		end
		else if (quot[55]) begin
			r_exp = s2_exp_r;
			r_sig = quot[55:3];
			r_g = quot[2];
			r_r = quot[1];
			r_s = quot[0] | (rem != {57 {1'sb0}});
		end
		else begin
			r_exp = s2_exp_r - 14'sd1;
			r_sig = quot[54:2];
			r_g = quot[1];
			r_r = quot[0];
			r_s = rem != {57 {1'sb0}};
		end
	end
	reg o_valid_r;
	reg [63:0] o_res_r;
	reg dn_pend_r;
	reg dn_sign_r;
	reg [55:0] dn_r;
	wire [55:0] p_ext;
	assign p_ext = {p_sig_r, p_g_r, p_r_r, p_s_r};
	function automatic [55:0] upycore_f64_denorm;
		input reg [55:0] ext;
		input reg signed [13:0] exp_s;
		reg signed [13:0] sh;
		reg [55:0] lost_mask;
		begin
			sh = 14'sd1 - exp_s;
			if (sh > 14'sd55)
				upycore_f64_denorm = {55'd0, |ext};
			else begin
				lost_mask = (56'd1 << sh[5:0]) - 56'd1;
				upycore_f64_denorm = ext >> sh[5:0];
				upycore_f64_denorm[0] = upycore_f64_denorm[0] | (|(ext & lost_mask));
			end
		end
	endfunction
	function automatic [63:0] upycore_f64_round_pack;
		input reg sign;
		input reg signed [13:0] exp_eff_i;
		input reg [55:0] shifted;
		reg inc;
		reg [53:0] sig_r;
		reg signed [13:0] exp_eff;
		reg [10:0] e_field;
		begin
			exp_eff = exp_eff_i;
			if (shifted == 56'd0)
				upycore_f64_round_pack = {sign, 63'd0};
			else begin
				inc = shifted[2] & ((shifted[1] | shifted[0]) | shifted[3]);
				sig_r = {1'b0, shifted[55:3]} + {53'd0, inc};
				if (sig_r[53]) begin
					sig_r = sig_r >> 1;
					exp_eff = exp_eff + 14'sd1;
				end
				if (exp_eff >= 14'sd2047)
					upycore_f64_round_pack = {sign, UPY_F64_PINF[62:0]};
				else begin
					e_field = (sig_r[52] ? exp_eff[10:0] : 11'd0);
					upycore_f64_round_pack = {sign, e_field, sig_r[51:0]};
				end
			end
		end
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			o_valid_r <= 1'b0;
			o_res_r <= 1'sb0;
			dn_pend_r <= 1'b0;
			dn_sign_r <= 1'b0;
			dn_r <= 1'sb0;
		end
		else if (!start_i) begin
			o_valid_r <= 1'b0;
			dn_pend_r <= 1'b0;
		end
		else begin
			o_valid_r <= dn_pend_r || (p_valid_r && (p_special_r || (p_exp_r > 14'sd0)));
			dn_pend_r <= (p_valid_r && !p_special_r) && (p_exp_r <= 14'sd0);
			if (dn_pend_r)
				o_res_r <= upycore_f64_round_pack(dn_sign_r, 14'sd1, dn_r);
			else
				o_res_r <= (p_special_r ? p_special_val_r : upycore_f64_round_pack(p_sign_r, p_exp_r, p_ext));
			dn_sign_r <= p_sign_r;
			dn_r <= upycore_f64_denorm(p_ext, p_exp_r);
		end
	assign result_o = o_res_r;
	assign done_o = o_valid_r;
	assign busy_o = ((((((s1_valid_r | core_busy) | core_done) | fin_r) | mod_norm_r) | p_valid_r) | dn_pend_r) | o_valid_r;
	initial _sv2v_0 = 0;
endmodule
module upycore_fp_pow (
	clk_i,
	rst_n_i,
	start_i,
	op_x_i,
	op_y_i,
	result_o,
	done_o,
	busy_o,
	mul_start_o,
	mul_a_o,
	mul_b_o,
	mul_product_i,
	mul_done_i
);
	reg _sv2v_0;
	parameter signed [31:0] LMW = 75;
	input wire clk_i;
	input wire rst_n_i;
	input wire start_i;
	input wire [63:0] op_x_i;
	input wire [63:0] op_y_i;
	output wire [63:0] result_o;
	output wire done_o;
	output wire busy_o;
	output wire mul_start_o;
	output wire [LMW - 1:0] mul_a_o;
	output wire [52:0] mul_b_o;
	input wire [LMW + 52:0] mul_product_i;
	input wire mul_done_i;
	localparam signed [31:0] UPY_POW_ROM_FW = 88;
	localparam signed [31:0] FW = UPY_POW_ROM_FW;
	localparam signed [31:0] NLOG = 80;
	localparam signed [31:0] NEXP = 72;
	localparam signed [31:0] FP = 80;
	localparam signed [31:0] WW = 90;
	localparam signed [31:0] AW = 91;
	localparam signed [31:0] LW = 101;
	localparam signed [31:0] QW = 53 + LMW;
	localparam signed [31:0] PW = 92;
	localparam [52:0] FOUR_THIRDS = 53'h15555555555555;
	reg [3:0] state_r;
	reg done_r;
	reg rz_r;
	reg [52:0] x_sig_r;
	reg [52:0] y_sig_r;
	reg [10:0] x_exp_r;
	reg [10:0] y_exp_r;
	reg [52:0] mx_r;
	reg signed [12:0] ex_r;
	reg [52:0] my_r;
	reg signed [12:0] ey_r;
	reg ysign_r;
	reg signed [12:0] e_r;
	reg signed [89:0] r_r;
	reg [7:0] j_r;
	reg [6:0] i_r;
	reg [7:0] j0_r;
	reg signed [90:0] acc_r;
	reg [89:0] cpos_r;
	reg [89:0] cneg_r;
	reg signed [LW:0] v_r;
	reg lsign_r;
	reg [100:0] lmag_r;
	reg [7:0] lscale_r;
	reg [6:0] lz_r;
	reg [LMW - 1:0] lm_r;
	reg signed [12:0] el_r;
	wire [QW - 1:0] q_prod;
	wire mul_done;
	reg [91:0] pfix_r;
	reg huge_r;
	reg psign_r;
	reg signed [12:0] i_int_r;
	reg [FW:0] z_r;
	reg [87:0] f_r;
	reg [63:0] result_r;
	wire [5:0] x_lz;
	wire [5:0] y_lz;
	function automatic [6:0] upycore_clz64;
		input reg [63:0] v;
		reg [63:0] x;
		reg [5:0] n;
		begin
			x = v;
			n = 1'sb0;
			if (x[63:32] == 0) begin
				n[5] = 1'b1;
				x = x << 32;
			end
			if (x[63:48] == 0) begin
				n[4] = 1'b1;
				x = x << 16;
			end
			if (x[63:56] == 0) begin
				n[3] = 1'b1;
				x = x << 8;
			end
			if (x[63:60] == 0) begin
				n[2] = 1'b1;
				x = x << 4;
			end
			if (x[63:62] == 0) begin
				n[1] = 1'b1;
				x = x << 2;
			end
			n[0] = !x[63];
			upycore_clz64 = (v == 0 ? 7'd64 : {1'b0, n});
		end
	endfunction
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
	function automatic [5:0] upycore_clz53;
		input reg [52:0] v;
		upycore_clz53 = sv2v_cast_6(upycore_clz64({v, 11'h400}));
	endfunction
	assign x_lz = upycore_clz53(x_sig_r);
	assign y_lz = upycore_clz53(y_sig_r);
	wire halve;
	wire signed [89:0] r_red;
	reg [87:0] r_mag_r;
	wire [7:0] r_clz;
	wire [7:0] j0_sel;
	assign halve = mx_r > FOUR_THIRDS;
	assign r_red = (halve ? $signed({{(WW - FW) - 1 {1'b1}}, 1'b1, mx_r, {35 {1'b0}}}) : $signed({{WW - FW {1'b0}}, mx_r[51:0], {36 {1'b0}}}));
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
	endfunction
	assign r_clz = (|r_mag_r[87-:64] ? sv2v_cast_8(upycore_clz64(r_mag_r[87-:64])) : 8'd64 + sv2v_cast_8(upycore_clz64({r_mag_r[23:0], 1'b1, {39 {1'b0}}})));
	assign j0_sel = (r_clz < 8'd2 ? 8'd2 : r_clz);
	wire d_pos;
	wire d_neg;
	wire signed [89:0] w_sh;
	wire [FW:0] z_sh;
	reg signed [89:0] w_next;
	reg signed [90:0] acc_next;
	wire [87:0] exp_c;
	wire exp_take;
	assign d_pos = !r_r[89] && (r_r[88:87] != 2'b00);
	assign d_neg = r_r[89] && (r_r[88:87] != 2'b11);
	wire signed [89:0] w_sh_full;
	assign w_sh_full = r_r >>> j_r[6:0];
	function automatic signed [7:0] sv2v_cast_8_signed;
		input reg signed [7:0] inp;
		sv2v_cast_8_signed = inp;
	endfunction
	assign w_sh = (j_r >= sv2v_cast_8_signed(WW) ? $signed({WW {r_r[89]}}) : w_sh_full);
	assign z_sh = z_r >> i_r;
	always @(*) begin
		if (_sv2v_0)
			;
		if (d_pos)
			w_next = ((r_r - $signed({{(WW - FW) - 1 {1'b0}}, 1'b1, {FW {1'b0}}})) + w_sh) <<< 1;
		else if (d_neg)
			w_next = ((r_r + $signed({{(WW - FW) - 1 {1'b0}}, 1'b1, {FW {1'b0}}})) - w_sh) <<< 1;
		else
			w_next = r_r <<< 1;
		if (d_pos)
			acc_next = acc_r - $signed({1'b0, cpos_r});
		else if (d_neg)
			acc_next = acc_r + $signed({1'b0, cneg_r});
		else
			acc_next = acc_r;
	end
	assign exp_c = cpos_r[87:0];
	assign exp_take = f_r >= exp_c;
	reg [7:0] pf_k;
	reg [6:0] pf_sh;
	wire [89:0] pf_pos;
	wire [89:0] pf_neg;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (state_r)
			4'd5: begin
				pf_k = j0_r;
				pf_sh = 7'd0;
			end
			4'd6: begin
				pf_k = j_r + 8'd1;
				pf_sh = i_r + 7'd1;
			end
			4'd13: begin
				pf_k = 8'd1;
				pf_sh = 7'd1;
			end
			default: begin
				pf_k = {1'b0, i_r} + 8'd1;
				pf_sh = i_r + 7'd1;
			end
		endcase
	end
	function automatic [89:0] upycore_pow_rom;
		input reg neg;
		input reg [7:0] k;
		(* full_case, parallel_case *)
		case ({neg, k})
			9'h000: upycore_pow_rom = 90'h00000000000000000000000;
			9'h001: upycore_pow_rom = 90'h12b803473f7ad0f3f401624;
			9'h002: upycore_pow_rom = 90'h149a784bcd1b8afe492bf70;
			9'h003: upycore_pow_rom = 90'h15c01a39fbd6879fa00b121;
			9'h004: upycore_pow_rom = 90'h1663f6fac913167ccc53826;
			9'h005: upycore_pow_rom = 90'h16bad3758efd87313606f09;
			9'h006: upycore_pow_rom = 90'h16e79685c2d2298a6e27e21;
			9'h007: upycore_pow_rom = 90'h16fe50b6ef08517f8e37b00;
			9'h008: upycore_pow_rom = 90'h1709c46d7aac774ad9bd249;
			9'h009: upycore_pow_rom = 90'h170f83ff0a7564c63a8ceda;
			9'h00a: upycore_pow_rom = 90'h1712653743f4541fa9f9439;
			9'h00b: upycore_pow_rom = 90'h1713d62f7957c30af53ad3a;
			9'h00c: upycore_pow_rom = 90'h17148ec2a1bfc88e10f006b;
			9'h00d: upycore_pow_rom = 90'h1714eb11fa53637548e216b;
			9'h00e: upycore_pow_rom = 90'h1715193b17d35d328b2afec;
			9'h00f: upycore_pow_rom = 90'h1715305002e4ae466ed064a;
			9'h010: upycore_pow_rom = 90'h17153bda8f822507ba0acfb;
			9'h011: upycore_pow_rom = 90'h1715419fdb96231bd1fa15f;
			9'h012: upycore_pow_rom = 90'h17154482831174b773b3598;
			9'h013: upycore_pow_rom = 90'h171545f3d72b72664180e99;
			9'h014: upycore_pow_rom = 90'h171546ac814f867d7a99ac2;
			9'h015: upycore_pow_rom = 90'h17154708d66755d9fe119ed;
			9'h016: upycore_pow_rom = 90'h1715473700f4aedc97d4649;
			9'h017: upycore_pow_rom = 90'h1715474e163bb7b2fe80f7d;
			9'h018: upycore_pow_rom = 90'h17154759a0df533378c33d5;
			9'h019: upycore_pow_rom = 90'h1715475f663126b907ae84f;
			9'h01a: upycore_pow_rom = 90'h1715476248da11ed239896c;
			9'h01b: upycore_pow_rom = 90'h17154763ba2e87e386aaf7c;
			9'h01c: upycore_pow_rom = 90'h1715476472d8c2f5cd7b85d;
			9'h01d: upycore_pow_rom = 90'h17154764cf2de084b635a53;
			9'h01e: upycore_pow_rom = 90'h17154764fd586f4d9be72b2;
			9'h01f: upycore_pow_rom = 90'h17154765146db6b26b150ba;
			9'h020: upycore_pow_rom = 90'h171547651ff85a64e9c1434;
			9'h021: upycore_pow_rom = 90'h1715476525bdac3e2edcb0f;
			9'h022: upycore_pow_rom = 90'h1715476528a0552ad2dbbc4;
			9'h023: upycore_pow_rom = 90'h171547652a11a9a12537970;
			9'h024: upycore_pow_rom = 90'h171547652aca53dc4e7c99b;
			9'h025: upycore_pow_rom = 90'h171547652b26a8f9e324e05;
			9'h026: upycore_pow_rom = 90'h171547652b54d388ad7a750;
			9'h027: upycore_pow_rom = 90'h171547652b6be8d012a59ba;
			9'h028: upycore_pow_rom = 90'h171547652b777373c53b461;
			9'h029: upycore_pow_rom = 90'h171547652b7d38c59e86210;
			9'h02a: upycore_pow_rom = 90'h171547652b801b6e8b2b8ff;
			9'h02b: upycore_pow_rom = 90'h171547652b818cc3017e47d;
			9'h02c: upycore_pow_rom = 90'h171547652b82456d3ca7a3d;
			9'h02d: upycore_pow_rom = 90'h171547652b82a1c25a3c51d;
			9'h02e: upycore_pow_rom = 90'h171547652b82cfece906a8d;
			9'h02f: upycore_pow_rom = 90'h171547652b82e702306bd45;
			9'h030: upycore_pow_rom = 90'h171547652b82f28cd41e6a2;
			9'h031: upycore_pow_rom = 90'h171547652b82f85225f7b50;
			9'h032: upycore_pow_rom = 90'h171547652b82fb34cee45a7;
			9'h033: upycore_pow_rom = 90'h171547652b82fca6235aad2;
			9'h034: upycore_pow_rom = 90'h171547652b82fd5ecd95d68;
			9'h035: upycore_pow_rom = 90'h171547652b82fdbb22b36b3;
			9'h036: upycore_pow_rom = 90'h171547652b82fde94d42358;
			9'h037: upycore_pow_rom = 90'h171547652b82fe0062899ab;
			9'h038: upycore_pow_rom = 90'h171547652b82fe0bed2d4d4;
			9'h039: upycore_pow_rom = 90'h171547652b82fe11b27f269;
			9'h03a: upycore_pow_rom = 90'h171547652b82fe149528133;
			9'h03b: upycore_pow_rom = 90'h171547652b82fe16067c898;
			9'h03c: upycore_pow_rom = 90'h171547652b82fe16bf26c4b;
			9'h03d: upycore_pow_rom = 90'h171547652b82fe171b7be24;
			9'h03e: upycore_pow_rom = 90'h171547652b82fe1749a6711;
			9'h03f: upycore_pow_rom = 90'h171547652b82fe1760bbb87;
			9'h040: upycore_pow_rom = 90'h171547652b82fe176c465c2;
			9'h041: upycore_pow_rom = 90'h171547652b82fe17720bae0;
			9'h042: upycore_pow_rom = 90'h171547652b82fe1774ee56f;
			9'h043: upycore_pow_rom = 90'h171547652b82fe17765fab6;
			9'h044: upycore_pow_rom = 90'h171547652b82fe17771855a;
			9'h045: upycore_pow_rom = 90'h171547652b82fe177774aac;
			9'h046: upycore_pow_rom = 90'h171547652b82fe1777a2d55;
			9'h047: upycore_pow_rom = 90'h171547652b82fe1777b9ea9;
			9'h048: upycore_pow_rom = 90'h171547652b82fe1777c5753;
			9'h049: upycore_pow_rom = 90'h171547652b82fe1777cb3a9;
			9'h04a: upycore_pow_rom = 90'h171547652b82fe1777ce1d3;
			9'h04b: upycore_pow_rom = 90'h171547652b82fe1777cf8e8;
			9'h04c: upycore_pow_rom = 90'h171547652b82fe1777d0473;
			9'h04d: upycore_pow_rom = 90'h171547652b82fe1777d0a38;
			9'h04e: upycore_pow_rom = 90'h171547652b82fe1777d0d1b;
			9'h04f: upycore_pow_rom = 90'h171547652b82fe1777d0e8c;
			9'h050: upycore_pow_rom = 90'h171547652b82fe1777d0f45;
			9'h051: upycore_pow_rom = 90'h171547652b82fe1777d0fa1;
			9'h052: upycore_pow_rom = 90'h171547652b82fe1777d0fcf;
			9'h053: upycore_pow_rom = 90'h171547652b82fe1777d0fe7;
			9'h054: upycore_pow_rom = 90'h171547652b82fe1777d0ff2;
			9'h055: upycore_pow_rom = 90'h171547652b82fe1777d0ff8;
			9'h056: upycore_pow_rom = 90'h171547652b82fe1777d0ffb;
			9'h057: upycore_pow_rom = 90'h171547652b82fe1777d0ffc;
			9'h058: upycore_pow_rom = 90'h171547652b82fe1777d0ffd;
			9'h059: upycore_pow_rom = 90'h171547652b82fe1777d0ffd;
			9'h05a: upycore_pow_rom = 90'h171547652b82fe1777d0ffd;
			9'h05b: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h05c: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h05d: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h05e: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h05f: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h060: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h061: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h062: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h063: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h064: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h065: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h066: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h067: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h068: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h069: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h06a: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h06b: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h06c: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h06d: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h06e: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h06f: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h070: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h071: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h072: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h073: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h074: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h075: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h076: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h077: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h078: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h079: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h07a: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h07b: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h07c: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h07d: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h07e: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h07f: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h080: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h081: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h082: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h083: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h084: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h085: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h086: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h087: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h100: upycore_pow_rom = 90'h00000000000000000000000;
			9'h101: upycore_pow_rom = 90'h20000000000000000000000;
			9'h102: upycore_pow_rom = 90'h1a8ff971810a5e1817fd3b8;
			9'h103: upycore_pow_rom = 90'h18a8980abfbd32666a9b7e3;
			9'h104: upycore_pow_rom = 90'h17d60496cfbb4c673b45120;
			9'h105: upycore_pow_rom = 90'h177394c9d958d55de5c3810;
			9'h106: upycore_pow_rom = 90'h1743ee861f3556365483612;
			9'h107: upycore_pow_rom = 90'h172c7ba20f73275b5d184a3;
			9'h108: upycore_pow_rom = 90'h1720d9c06a835ea6ef18f97;
			9'h109: upycore_pow_rom = 90'h171b0ea42e5fda261dbbd1a;
			9'h10a: upycore_pow_rom = 90'h17182a894b69c595f7920cf;
			9'h10b: upycore_pow_rom = 90'h1716b8d86bc28553668fa99;
			9'h10c: upycore_pow_rom = 90'h1716001718cb2af996dfc38;
			9'h10d: upycore_pow_rom = 90'h1715a3bc3593d4d4a2a2397;
			9'h10e: upycore_pow_rom = 90'h17157590356aede7704d157;
			9'h10f: upycore_pow_rom = 90'h17155e7a91af61a18894f88;
			9'h110: upycore_pow_rom = 90'h171552efd6e75c155bd4e4f;
			9'h111: upycore_pow_rom = 90'h17154d2a7f48ba4ea57c24d;
			9'h112: upycore_pow_rom = 90'h17154a47d4eabfc65dc801d;
			9'h113: upycore_pow_rom = 90'h171548d6801817dc6695b1d;
			9'h114: upycore_pow_rom = 90'h1715481dd5c5d93663255ed;
			9'h115: upycore_pow_rom = 90'h171547c180a27f362d17a1f;
			9'h116: upycore_pow_rom = 90'h171547935612438aa6af6b5;
			9'h117: upycore_pow_rom = 90'h1715477c40ca820a04d97be;
			9'h118: upycore_pow_rom = 90'h17154770b626b85efbccdf7;
			9'h119: upycore_pow_rom = 90'h1715476af0d4d94ec92f020;
			9'h11a: upycore_pow_rom = 90'h171547680e2beb3804584ac;
			9'h11b: upycore_pow_rom = 90'h171547669cd77488f70ac07;
			9'h11c: upycore_pow_rom = 90'h17154765e42d394885ab680;
			9'h11d: upycore_pow_rom = 90'h1715476587d81bae124d960;
			9'h11e: upycore_pow_rom = 90'h1715476559ad8ce249f3238;
			9'h11f: upycore_pow_rom = 90'h171547654298457cc21b07d;
			9'h120: upycore_pow_rom = 90'h17154765370da1ca1544416;
			9'h121: upycore_pow_rom = 90'h1715476531484ff0c49e300;
			9'h122: upycore_pow_rom = 90'h171547652e65a7041dbc7bc;
			9'h123: upycore_pow_rom = 90'h171547652cf4528dcaa7f6c;
			9'h124: upycore_pow_rom = 90'h171547652c3ba852a134c99;
			9'h125: upycore_pow_rom = 90'h171547652bdf53350c80f84;
			9'h126: upycore_pow_rom = 90'h171547652bb128a6422880f;
			9'h127: upycore_pow_rom = 90'h171547652b9a135edcfca1a;
			9'h128: upycore_pow_rom = 90'h171547652b8e88bb2a66c91;
			9'h129: upycore_pow_rom = 90'h171547652b88c369511be28;
			9'h12a: upycore_pow_rom = 90'h171547652b85e0c0647670b;
			9'h12b: upycore_pow_rom = 90'h171547652b846f6bee23b83;
			9'h12c: upycore_pow_rom = 90'h171547652b83b6c1b2fa5c0;
			9'h12d: upycore_pow_rom = 90'h171547652b835a6c9565ade;
			9'h12e: upycore_pow_rom = 90'h171547652b832c42069b56e;
			9'h12f: upycore_pow_rom = 90'h171547652b83152cbf362b6;
			9'h130: upycore_pow_rom = 90'h171547652b8309a21b8395a;
			9'h131: upycore_pow_rom = 90'h171547652b8303dcc9aa4ac;
			9'h132: upycore_pow_rom = 90'h171547652b8300fa20bda55;
			9'h133: upycore_pow_rom = 90'h171547652b82ff88cc47529;
			9'h134: upycore_pow_rom = 90'h171547652b82fed0220c293;
			9'h135: upycore_pow_rom = 90'h171547652b82fe73ccee949;
			9'h136: upycore_pow_rom = 90'h171547652b82fe45a25fca3;
			9'h137: upycore_pow_rom = 90'h171547652b82fe2e8d18650;
			9'h138: upycore_pow_rom = 90'h171547652b82fe230274b27;
			9'h139: upycore_pow_rom = 90'h171547652b82fe1d3d22d92;
			9'h13a: upycore_pow_rom = 90'h171547652b82fe1a5a79ec8;
			9'h13b: upycore_pow_rom = 90'h171547652b82fe18e925763;
			9'h13c: upycore_pow_rom = 90'h171547652b82fe18307b3b0;
			9'h13d: upycore_pow_rom = 90'h171547652b82fe17d4261d7;
			9'h13e: upycore_pow_rom = 90'h171547652b82fe17a5fb8ea;
			9'h13f: upycore_pow_rom = 90'h171547652b82fe178ee6474;
			9'h140: upycore_pow_rom = 90'h171547652b82fe17835ba39;
			9'h141: upycore_pow_rom = 90'h171547652b82fe177d9651b;
			9'h142: upycore_pow_rom = 90'h171547652b82fe177ab3a8c;
			9'h143: upycore_pow_rom = 90'h171547652b82fe177942545;
			9'h144: upycore_pow_rom = 90'h171547652b82fe177889aa1;
			9'h145: upycore_pow_rom = 90'h171547652b82fe17782d54f;
			9'h146: upycore_pow_rom = 90'h171547652b82fe1777ff2a7;
			9'h147: upycore_pow_rom = 90'h171547652b82fe1777e8152;
			9'h148: upycore_pow_rom = 90'h171547652b82fe1777dc8a8;
			9'h149: upycore_pow_rom = 90'h171547652b82fe1777d6c53;
			9'h14a: upycore_pow_rom = 90'h171547652b82fe1777d3e28;
			9'h14b: upycore_pow_rom = 90'h171547652b82fe1777d2713;
			9'h14c: upycore_pow_rom = 90'h171547652b82fe1777d1b88;
			9'h14d: upycore_pow_rom = 90'h171547652b82fe1777d15c3;
			9'h14e: upycore_pow_rom = 90'h171547652b82fe1777d12e0;
			9'h14f: upycore_pow_rom = 90'h171547652b82fe1777d116f;
			9'h150: upycore_pow_rom = 90'h171547652b82fe1777d10b6;
			9'h151: upycore_pow_rom = 90'h171547652b82fe1777d105a;
			9'h152: upycore_pow_rom = 90'h171547652b82fe1777d102c;
			9'h153: upycore_pow_rom = 90'h171547652b82fe1777d1015;
			9'h154: upycore_pow_rom = 90'h171547652b82fe1777d1009;
			9'h155: upycore_pow_rom = 90'h171547652b82fe1777d1003;
			9'h156: upycore_pow_rom = 90'h171547652b82fe1777d1001;
			9'h157: upycore_pow_rom = 90'h171547652b82fe1777d0fff;
			9'h158: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h159: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h15a: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h15b: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h15c: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h15d: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h15e: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h15f: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h160: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h161: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h162: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h163: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h164: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h165: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h166: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h167: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h168: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h169: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h16a: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h16b: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h16c: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h16d: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h16e: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h16f: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h170: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h171: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h172: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h173: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h174: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h175: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h176: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h177: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h178: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h179: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h17a: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h17b: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h17c: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h17d: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h17e: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h17f: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h180: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h181: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h182: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h183: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h184: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h185: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h186: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			9'h187: upycore_pow_rom = 90'h171547652b82fe1777d0ffe;
			default: upycore_pow_rom = 90'd0;
		endcase
	endfunction
	assign pf_pos = upycore_pow_rom(1'b0, pf_k) >> pf_sh;
	assign pf_neg = upycore_pow_rom(1'b1, pf_k) >> pf_sh;
	reg signed [LW:0] v_sum;
	wire [6:0] lmag_clz;
	wire [100:0] lmag_norm;
	always @(*) begin
		if (_sv2v_0)
			;
		if (e_r == 13'sd0)
			v_sum = $signed({{11 {acc_r[90]}}, acc_r});
		else begin
			v_sum = $signed({{89 {e_r[12]}}, e_r}) <<< FW;
			v_sum = v_sum + ($signed({{11 {acc_r[90]}}, acc_r}) >>> j0_r);
		end
	end
	assign lmag_clz = (|lmag_r[100-:64] ? upycore_clz64(lmag_r[100-:64]) : 7'd64 + upycore_clz64({lmag_r[36:0], 1'b1, {26 {1'b0}}}));
	assign lmag_norm = lmag_r << lz_r;
	assign mul_start_o = state_r == 4'd11;
	assign mul_a_o = lm_r;
	assign mul_b_o = my_r;
	assign q_prod = mul_product_i;
	assign mul_done = mul_done_i;
	wire signed [13:0] p_sh;
	wire [13:0] t_amt;
	wire [QW - 1:0] q_shifted;
	wire p_huge;
	wire signed [PW:0] pfix_s;
	function automatic signed [13:0] sv2v_cast_14_signed;
		input reg signed [13:0] inp;
		sv2v_cast_14_signed = inp;
	endfunction
	assign p_sh = ((sv2v_cast_14_signed(ey_r) - 14'sd52) + sv2v_cast_14_signed(el_r)) + sv2v_cast_14_signed(FP);
	assign t_amt = -p_sh;
	reg sh_pos_r;
	reg t_big_r;
	reg [7:0] t_amt_r;
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			sh_pos_r <= 1'b0;
			t_big_r <= 1'b0;
			t_amt_r <= 1'sb0;
		end
		else begin
			sh_pos_r <= p_sh >= 14'sd0;
			t_big_r <= t_amt >= sv2v_cast_14_signed(QW);
			t_amt_r <= t_amt[7:0];
		end
	assign q_shifted = (sh_pos_r ? q_prod : (t_big_r ? {QW {1'sb0}} : q_prod >> t_amt_r));
	assign p_huge = (sh_pos_r ? q_prod != {QW {1'sb0}} : q_shifted[QW - 1:91] != {((QW - 1) >= 91 ? QW - 91 : 93 - QW) * 1 {1'sb0}});
	assign pfix_s = (psign_r ? -$signed({1'b0, pfix_r}) : $signed({1'b0, pfix_r}));
	reg signed [13:0] pexp_r;
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i)
			pexp_r <= 1'sb0;
		else
			pexp_r <= $signed({i_int_r[12], i_int_r}) + 14'sd1023;
	wire [63:0] pack_res;
	localparam [63:0] UPY_F64_PINF = 64'h7ff0000000000000;
	function automatic [63:0] upycore_f64_pack_round;
		input reg sign;
		input reg signed [13:0] exp_s;
		input reg [52:0] sig;
		input reg g;
		input reg r;
		input reg s;
		reg [55:0] ext;
		reg [55:0] shifted;
		reg [55:0] lost_mask;
		reg signed [13:0] sh;
		reg signed [13:0] exp_eff;
		reg inc;
		reg [53:0] sig_r;
		reg [10:0] e_field;
		begin
			ext = {sig, g, r, s};
			if (ext == 56'd0)
				upycore_f64_pack_round = {sign, 63'd0};
			else begin
				if (exp_s <= 14'sd0) begin
					sh = 14'sd1 - exp_s;
					if (sh > 14'sd55)
						shifted = {55'd0, |ext};
					else begin
						lost_mask = (56'd1 << sh[5:0]) - 56'd1;
						shifted = ext >> sh[5:0];
						shifted[0] = shifted[0] | (|(ext & lost_mask));
					end
					exp_eff = 14'sd1;
				end
				else begin
					shifted = ext;
					exp_eff = exp_s;
				end
				inc = shifted[2] & ((shifted[1] | shifted[0]) | shifted[3]);
				sig_r = {1'b0, shifted[55:3]} + {53'd0, inc};
				if (sig_r[53]) begin
					sig_r = sig_r >> 1;
					exp_eff = exp_eff + 14'sd1;
				end
				if (exp_eff >= 14'sd2047)
					upycore_f64_pack_round = {sign, UPY_F64_PINF[62:0]};
				else begin
					e_field = (sig_r[52] ? exp_eff[10:0] : 11'd0);
					upycore_f64_pack_round = {sign, e_field, sig_r[51:0]};
				end
			end
		end
	endfunction
	assign pack_res = upycore_f64_pack_round(1'b0, pexp_r, z_r[FW:36], z_r[35], z_r[34], |z_r[33:0]);
	localparam [63:0] UPY_F64_PZERO = 64'h0000000000000000;
	function automatic [10:0] upycore_f64_exp_eff;
		input reg [63:0] v;
		upycore_f64_exp_eff = (v[62:52] == 11'd0 ? 11'd1 : v[62:52]);
	endfunction
	function automatic [52:0] upycore_f64_sig;
		input reg [63:0] v;
		upycore_f64_sig = {v[62:52] != 11'd0, v[51:0]};
	endfunction
	function automatic [12:0] sv2v_cast_13;
		input reg [12:0] inp;
		sv2v_cast_13 = inp;
	endfunction
	function automatic signed [87:0] sv2v_cast_88_signed;
		input reg signed [87:0] inp;
		sv2v_cast_88_signed = inp;
	endfunction
	function automatic signed [6:0] sv2v_cast_7_signed;
		input reg signed [6:0] inp;
		sv2v_cast_7_signed = inp;
	endfunction
	function automatic signed [100:0] sv2v_cast_4587C_signed;
		input reg signed [100:0] inp;
		sv2v_cast_4587C_signed = inp;
	endfunction
	function automatic signed [12:0] sv2v_cast_13_signed;
		input reg signed [12:0] inp;
		sv2v_cast_13_signed = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			state_r <= 4'd0;
			done_r <= 1'b0;
			x_sig_r <= 1'sb0;
			y_sig_r <= 1'sb0;
			x_exp_r <= 1'sb0;
			y_exp_r <= 1'sb0;
			r_mag_r <= 1'sb0;
			mx_r <= 1'sb0;
			ex_r <= 1'sb0;
			my_r <= 1'sb0;
			ey_r <= 1'sb0;
			ysign_r <= 1'b0;
			e_r <= 1'sb0;
			r_r <= 1'sb0;
			j_r <= 1'sb0;
			i_r <= 1'sb0;
			j0_r <= 1'sb0;
			acc_r <= 1'sb0;
			rz_r <= 1'b0;
			v_r <= 1'sb0;
			lsign_r <= 1'b0;
			lmag_r <= 1'sb0;
			lscale_r <= 1'sb0;
			lz_r <= 1'sb0;
			lm_r <= 1'sb0;
			el_r <= 1'sb0;
			cpos_r <= 1'sb0;
			cneg_r <= 1'sb0;
			pfix_r <= 1'sb0;
			huge_r <= 1'b0;
			psign_r <= 1'b0;
			i_int_r <= 1'sb0;
			z_r <= 1'sb0;
			f_r <= 1'sb0;
			result_r <= 1'sb0;
		end
		else begin
			done_r <= 1'b0;
			if ((state_r != 4'd0) && !start_i)
				state_r <= 4'd0;
			else
				(* full_case, parallel_case *)
				case (state_r)
					4'd0:
						if (start_i && !done_r) begin
							x_sig_r <= upycore_f64_sig(op_x_i);
							y_sig_r <= upycore_f64_sig(op_y_i);
							x_exp_r <= upycore_f64_exp_eff(op_x_i);
							y_exp_r <= upycore_f64_exp_eff(op_y_i);
							ysign_r <= op_y_i[63];
							state_r <= 4'd1;
						end
					4'd1: begin
						mx_r <= x_sig_r << x_lz;
						ex_r <= (sv2v_cast_13(x_exp_r) - sv2v_cast_13(x_lz)) - 13'sd1023;
						my_r <= y_sig_r << y_lz;
						ey_r <= (sv2v_cast_13(y_exp_r) - sv2v_cast_13(y_lz)) - 13'sd1023;
						state_r <= 4'd2;
					end
					4'd2: begin
						r_r <= r_red;
						e_r <= (halve ? ex_r + 13'sd1 : ex_r);
						acc_r <= 1'sb0;
						state_r <= 4'd3;
					end
					4'd3: begin
						r_mag_r <= (r_r[89] ? sv2v_cast_88_signed(-r_r) : r_r[87:0]);
						state_r <= 4'd4;
					end
					4'd4: begin
						j0_r <= j0_sel;
						rz_r <= r_mag_r == {88 {1'sb0}};
						state_r <= 4'd5;
					end
					4'd5: begin
						r_r <= -r_r <<< j0_r;
						j_r <= j0_r;
						i_r <= 1'sb0;
						cpos_r <= pf_pos;
						cneg_r <= pf_neg;
						state_r <= (rz_r ? 4'd7 : 4'd6);
					end
					4'd6: begin
						r_r <= w_next;
						acc_r <= acc_next;
						j_r <= j_r + 8'd1;
						i_r <= i_r + 7'd1;
						cpos_r <= pf_pos;
						cneg_r <= pf_neg;
						if (i_r == sv2v_cast_7_signed(79))
							state_r <= 4'd7;
					end
					4'd7: begin
						v_r <= v_sum;
						lscale_r <= (e_r == 13'sd0 ? j0_r : 8'd0);
						state_r <= 4'd8;
					end
					4'd8: begin
						lsign_r <= v_r[LW];
						lmag_r <= sv2v_cast_4587C_signed((v_r[LW] ? -v_r : v_r));
						state_r <= 4'd9;
					end
					4'd9: begin
						lz_r <= lmag_clz;
						state_r <= 4'd10;
					end
					4'd10: begin
						lm_r <= lmag_norm[100:LW - LMW];
						el_r <= ((sv2v_cast_13_signed(LW - LMW) - sv2v_cast_13(lz_r)) - sv2v_cast_13_signed(FW)) - sv2v_cast_13(lscale_r);
						psign_r <= ysign_r ^ lsign_r;
						state_r <= 4'd11;
					end
					4'd11:
						if (mul_done)
							state_r <= 4'd12;
					4'd12: begin
						pfix_r <= q_shifted[91:0];
						huge_r <= p_huge;
						state_r <= 4'd13;
					end
					4'd13: begin
						i_int_r <= pfix_s[PW:FP];
						f_r <= {pfix_s[79:0], {FW - FP {1'b0}}};
						z_r <= {1'b1, {FW {1'b0}}};
						i_r <= 7'd1;
						cpos_r <= pf_pos;
						state_r <= (huge_r ? 4'd15 : 4'd14);
					end
					4'd14: begin
						if (exp_take) begin
							f_r <= f_r - exp_c;
							z_r <= z_r + z_sh;
						end
						i_r <= i_r + 7'd1;
						cpos_r <= pf_pos;
						if (i_r == sv2v_cast_7_signed(NEXP))
							state_r <= 4'd15;
					end
					4'd15: begin
						if (huge_r)
							result_r <= (psign_r ? UPY_F64_PZERO : UPY_F64_PINF);
						else
							result_r <= pack_res;
						done_r <= 1'b1;
						state_r <= 4'd0;
					end
					default: state_r <= 4'd0;
				endcase
		end
	assign result_o = result_r;
	assign done_o = done_r;
	assign busy_o = state_r != 4'd0;
	initial _sv2v_0 = 0;
endmodule
module upycore_fpu (
	clk_i,
	rst_n_i,
	start_i,
	op_i,
	op_a_i,
	op_b_i,
	result_o,
	exception_o,
	done_o,
	stall_o,
	busy_o
);
	reg _sv2v_0;
	parameter signed [31:0] MUL_STEP = 14;
	parameter signed [31:0] DIV_RL = 2;
	parameter signed [31:0] POW_CHAIN_MAX = 2;
	input wire clk_i;
	input wire rst_n_i;
	input wire start_i;
	input wire [4:0] op_i;
	input wire [63:0] op_a_i;
	input wire [63:0] op_b_i;
	output reg [63:0] result_o;
	output reg exception_o;
	output reg done_o;
	output wire stall_o;
	output wire busy_o;
	reg u_add_start;
	reg u_sub;
	reg u_mul_start;
	reg u_div_start;
	reg u_fmod;
	reg u_sqrt;
	reg u_pow_start;
	reg [63:0] u_a;
	reg [63:0] u_b;
	wire [63:0] add_res;
	wire [63:0] mul_res;
	wire [63:0] div_res;
	wire [63:0] pow_res;
	wire add_done;
	wire mul_done;
	wire div_done;
	wire pow_done;
	wire add_busy;
	wire mul_busy;
	wire div_busy;
	wire pow_busy;
	wire u_done;
	wire [63:0] u_res;
	upycore_fp_add u_add(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.start_i(u_add_start),
		.sub_i(u_sub),
		.op_a_i(u_a),
		.op_b_i(u_b),
		.result_o(add_res),
		.done_o(add_done),
		.busy_o(add_busy)
	);
	localparam signed [31:0] POW_LMW = 75;
	wire sm_start;
	wire fm_mul_start;
	wire pw_mul_start;
	wire sm_done;
	wire sm_busy;
	wire [74:0] sm_a;
	wire [74:0] pw_mul_a;
	wire [52:0] sm_b;
	wire [52:0] fm_mul_a;
	wire [52:0] fm_mul_b;
	wire [52:0] pw_mul_b;
	wire [127:0] sm_product;
	assign sm_start = (u_pow_start ? pw_mul_start : fm_mul_start);
	assign sm_a = (u_pow_start ? pw_mul_a : {{22 {1'b0}}, fm_mul_a});
	assign sm_b = (u_pow_start ? pw_mul_b : fm_mul_b);
	upycore_umul_seq #(
		.AW(POW_LMW),
		.BW(53),
		.STEP(MUL_STEP)
	) u_sig_mul(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.start_i(sm_start),
		.op_a_i(sm_a),
		.op_b_i(sm_b),
		.product_o(sm_product),
		.done_o(sm_done),
		.busy_o(sm_busy)
	);
	upycore_fp_mul u_mul(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.start_i(u_mul_start),
		.op_a_i(u_a),
		.op_b_i(u_b),
		.result_o(mul_res),
		.done_o(mul_done),
		.busy_o(mul_busy),
		.mul_start_o(fm_mul_start),
		.mul_a_o(fm_mul_a),
		.mul_b_o(fm_mul_b),
		.mul_product_i(sm_product[105:0]),
		.mul_done_i(sm_done && !u_pow_start),
		.mul_busy_i(sm_busy && !u_pow_start)
	);
	upycore_fp_divrem #(.RL(DIV_RL)) u_div(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.start_i(u_div_start),
		.fmod_i(u_fmod),
		.sqrt_i(u_sqrt),
		.op_a_i(u_a),
		.op_b_i(u_b),
		.result_o(div_res),
		.done_o(div_done),
		.busy_o(div_busy)
	);
	upycore_fp_pow #(.LMW(POW_LMW)) u_pow(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.start_i(u_pow_start),
		.op_x_i(u_a),
		.op_y_i(u_b),
		.result_o(pow_res),
		.done_o(pow_done),
		.busy_o(pow_busy),
		.mul_start_o(pw_mul_start),
		.mul_a_o(pw_mul_a),
		.mul_b_o(pw_mul_b),
		.mul_product_i(sm_product),
		.mul_done_i(sm_done && u_pow_start)
	);
	assign u_done = ((add_done | mul_done) | div_done) | pow_done;
	assign u_res = (add_done ? add_res : (mul_done ? mul_res : (div_done ? div_res : pow_res)));
	reg [5:0] state_r;
	reg [63:0] t0_r;
	reg [63:0] t1_r;
	reg [63:0] t2_r;
	reg [63:0] t3_r;
	reg [63:0] pow_n_r;
	reg [63:0] pow_n0_r;
	reg [6:0] pow_cnt_r;
	reg pow_neg_r;
	reg pow_recip_r;
	reg [63:0] res_r;
	reg mul_run;
	wire [63:0] ar;
	wire [63:0] br;
	assign ar = op_a_i;
	assign br = op_b_i;
	reg [1:0] dec_kind;
	reg [63:0] dec_result;
	reg [5:0] dec_next;
	reg dec_sub;
	reg dec_div;
	reg dec_mul;
	reg dec_pow_neg;
	reg dec_pow_recip;
	reg [63:0] dec_pow_n;
	wire a_nan;
	wire b_nan;
	wire a_inf;
	wire b_inf;
	wire a_zero;
	wire b_zero;
	wire b_int;
	wire a_abs_one;
	wire a_abs_gt_one;
	wire b_odd;
	wire b_gt0;
	wire b_lt0;
	wire [63:0] a_abs;
	wire b_trunc_ok;
	function automatic upycore_f64_is_nan;
		input reg [63:0] v;
		upycore_f64_is_nan = (v[62:52] == 11'h7ff) && (v[51:0] != 52'd0);
	endfunction
	assign a_nan = upycore_f64_is_nan(ar);
	assign b_nan = upycore_f64_is_nan(br);
	function automatic upycore_f64_is_inf;
		input reg [63:0] v;
		upycore_f64_is_inf = (v[62:52] == 11'h7ff) && (v[51:0] == 52'd0);
	endfunction
	assign a_inf = upycore_f64_is_inf(ar);
	assign b_inf = upycore_f64_is_inf(br);
	function automatic upycore_f64_is_zero;
		input reg [63:0] v;
		upycore_f64_is_zero = v[62:0] == 63'd0;
	endfunction
	assign a_zero = upycore_f64_is_zero(ar);
	assign b_zero = upycore_f64_is_zero(br);
	assign a_abs = {1'b0, ar[62:0]};
	localparam [63:0] UPY_F64_ONE = 64'h3ff0000000000000;
	assign a_abs_one = a_abs == UPY_F64_ONE;
	function automatic [3:0] upycore_f64_cmp;
		input reg [63:0] a;
		input reg [63:0] b;
		reg lt_mag;
		if (upycore_f64_is_nan(a) || upycore_f64_is_nan(b))
			upycore_f64_cmp = 4'b1000;
		else if (upycore_f64_is_zero(a) && upycore_f64_is_zero(b))
			upycore_f64_cmp = 4'b0010;
		else if (a[63] != b[63])
			upycore_f64_cmp = (a[63] ? 4'b0001 : 4'b0100);
		else if (a[62:0] == b[62:0])
			upycore_f64_cmp = 4'b0010;
		else begin
			lt_mag = a[62:0] < b[62:0];
			upycore_f64_cmp = (lt_mag ^ a[63] ? 4'b0001 : 4'b0100);
		end
	endfunction
	function automatic upycore_f64_gt;
		input reg [63:0] a;
		input reg [63:0] b;
		reg [3:0] c;
		begin
			c = upycore_f64_cmp(a, b);
			upycore_f64_gt = c[2];
		end
	endfunction
	assign a_abs_gt_one = upycore_f64_gt(a_abs, UPY_F64_ONE);
	function automatic upycore_f64_is_integer;
		input reg [63:0] v;
		reg [10:0] e;
		begin
			e = v[62:52];
			if (e == 11'h7ff)
				upycore_f64_is_integer = 1'b0;
			else if (e >= 11'd1075)
				upycore_f64_is_integer = 1'b1;
			else if (e < 11'd1023)
				upycore_f64_is_integer = v[62:0] == 0;
			else
				upycore_f64_is_integer = (v[51:0] & (52'hfffffffffffff >> (e - 11'd1023))) == 0;
		end
	endfunction
	assign b_int = upycore_f64_is_integer(br);
	function automatic upycore_f64_is_finite;
		input reg [63:0] v;
		upycore_f64_is_finite = v[62:52] != 11'h7ff;
	endfunction
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
	function automatic upycore_f64_is_odd_integer;
		input reg [63:0] v;
		reg [10:0] e;
		begin
			e = v[62:52];
			if (((e < 11'd1023) || (e >= 11'd1076)) || !upycore_f64_is_finite(v))
				upycore_f64_is_odd_integer = 1'b0;
			else if (!upycore_f64_is_integer(v))
				upycore_f64_is_odd_integer = 1'b0;
			else
				upycore_f64_is_odd_integer = (e == 11'd1023 ? 1'b1 : v[sv2v_cast_6(11'd1075 - e)]);
		end
	endfunction
	assign b_odd = upycore_f64_is_odd_integer(br);
	localparam [63:0] UPY_F64_PZERO = 64'h0000000000000000;
	assign b_gt0 = upycore_f64_gt(br, UPY_F64_PZERO);
	function automatic upycore_f64_lt_zero;
		input reg [63:0] v;
		upycore_f64_lt_zero = (v[63] && !upycore_f64_is_zero(v)) && !upycore_f64_is_nan(v);
	endfunction
	assign b_lt0 = upycore_f64_lt_zero(br);
	wire [63:0] b_trunc_abs;
	wire pow_n_small;
	wire [10:0] b_uexp;
	wire [63:0] b_sig;
	assign b_uexp = br[62:52] - 11'd1023;
	assign b_sig = {12'h001, br[51:0]};
	assign b_trunc_ok = (br[62:52] != 11'h7ff) && ((br[62:52] < 11'd1023) || (b_uexp < 11'd63));
	assign b_trunc_abs = (!b_trunc_ok || (br[62:52] < 11'd1023) ? 64'd0 : (b_uexp < 11'd52 ? b_sig >> (11'd52 - b_uexp) : b_sig << (b_uexp - 11'd52)));
	function automatic signed [63:0] sv2v_cast_64_signed;
		input reg signed [63:0] inp;
		sv2v_cast_64_signed = inp;
	endfunction
	assign pow_n_small = b_trunc_abs <= sv2v_cast_64_signed(POW_CHAIN_MAX);
	localparam [4:0] UPY_ALU_ADD = 5'd0;
	localparam [4:0] UPY_ALU_EQ = 5'd16;
	localparam [4:0] UPY_ALU_FLOOR_DIV = 5'd3;
	localparam [4:0] UPY_ALU_GE = 5'd21;
	localparam [4:0] UPY_ALU_GT = 5'd20;
	localparam [4:0] UPY_ALU_LE = 5'd19;
	localparam [4:0] UPY_ALU_LT = 5'd18;
	localparam [4:0] UPY_ALU_MOD = 5'd5;
	localparam [4:0] UPY_ALU_MUL = 5'd2;
	localparam [4:0] UPY_ALU_NE = 5'd17;
	localparam [4:0] UPY_ALU_NEG = 5'd12;
	localparam [4:0] UPY_ALU_NOT = 5'd15;
	localparam [4:0] UPY_ALU_PASS = 5'd22;
	localparam [4:0] UPY_ALU_POS = 5'd13;
	localparam [4:0] UPY_ALU_POWER = 5'd6;
	localparam [4:0] UPY_ALU_SUB = 5'd1;
	localparam [4:0] UPY_ALU_TRUE_DIV = 5'd4;
	localparam [63:0] UPY_F64_HALF = 64'h3fe0000000000000;
	localparam [63:0] UPY_F64_NONE = 64'hbff0000000000000;
	localparam [63:0] UPY_F64_PINF = 64'h7ff0000000000000;
	function automatic upycore_f64_compare_op;
		input reg [4:0] op;
		input reg [63:0] a;
		input reg [63:0] b;
		reg [3:0] c;
		begin
			c = upycore_f64_cmp(a, b);
			(* full_case, parallel_case *)
			case (op)
				UPY_ALU_EQ: upycore_f64_compare_op = c[1];
				UPY_ALU_NE: upycore_f64_compare_op = !c[1];
				UPY_ALU_LT: upycore_f64_compare_op = c[0];
				UPY_ALU_LE: upycore_f64_compare_op = c[0] | c[1];
				UPY_ALU_GT: upycore_f64_compare_op = c[2];
				UPY_ALU_GE: upycore_f64_compare_op = c[2] | c[1];
				default: upycore_f64_compare_op = 1'b0;
			endcase
		end
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		dec_kind = 2'd1;
		dec_result = 1'sb0;
		dec_next = 6'd0;
		dec_sub = 1'b0;
		dec_div = 1'b0;
		dec_mul = 1'b0;
		dec_pow_neg = 1'b0;
		dec_pow_recip = 1'b0;
		dec_pow_n = 1'sb0;
		(* full_case, parallel_case *)
		case (op_i)
			UPY_ALU_ADD: dec_kind = 2'd2;
			UPY_ALU_SUB: begin
				dec_kind = 2'd2;
				dec_sub = 1'b1;
			end
			UPY_ALU_MUL: begin
				dec_kind = 2'd2;
				dec_mul = 1'b1;
			end
			UPY_ALU_TRUE_DIV: begin
				dec_kind = (b_zero ? 2'd1 : 2'd2);
				dec_div = 1'b1;
			end
			UPY_ALU_MOD: begin
				dec_kind = (b_zero ? 2'd1 : 2'd3);
				dec_next = 6'd2;
			end
			UPY_ALU_FLOOR_DIV: begin
				dec_kind = (b_zero ? 2'd1 : 2'd3);
				dec_next = 6'd5;
			end
			UPY_ALU_POWER: begin
				dec_kind = 2'd0;
				if (b_zero)
					dec_result = UPY_F64_ONE;
				else if (a_nan)
					dec_result = ar;
				else if (b_nan)
					dec_result = (ar == UPY_F64_ONE ? UPY_F64_ONE : br);
				else if (b_inf) begin
					if (a_abs_one)
						dec_result = UPY_F64_ONE;
					else if (b_gt0 == a_abs_gt_one)
						dec_result = UPY_F64_PINF;
					else
						dec_result = UPY_F64_PZERO;
				end
				else if (a_inf) begin
					if (b_gt0)
						dec_result = (b_odd ? ar : a_abs);
					else
						dec_result = (b_odd ? {ar[63], 63'd0} : UPY_F64_PZERO);
				end
				else if (a_zero) begin
					if (b_lt0)
						dec_kind = 2'd1;
					else
						dec_result = (b_odd ? ar : UPY_F64_PZERO);
				end
				else if (!b_int && ar[63])
					dec_kind = 2'd1;
				else if (a_abs_one)
					dec_result = (ar[63] && b_odd ? UPY_F64_NONE : UPY_F64_ONE);
				else if (br == UPY_F64_HALF) begin
					dec_kind = 2'd3;
					dec_next = 6'd24;
				end
				else if ((b_int && b_trunc_ok) && pow_n_small) begin
					dec_kind = 2'd3;
					dec_next = 6'd15;
					dec_pow_neg = ar[63] && b_odd;
					dec_pow_recip = b_lt0;
					dec_pow_n = b_trunc_abs;
				end
				else begin
					dec_kind = 2'd3;
					dec_next = 6'd23;
					dec_pow_neg = ar[63] && b_odd;
				end
			end
			UPY_ALU_NEG: begin
				dec_kind = 2'd0;
				dec_result = {~ar[63], ar[62:0]};
			end
			UPY_ALU_POS, UPY_ALU_PASS: begin
				dec_kind = 2'd0;
				dec_result = ar;
			end
			UPY_ALU_NOT: begin
				dec_kind = 2'd0;
				dec_result = {63'd0, a_zero};
			end
			UPY_ALU_EQ, UPY_ALU_NE, UPY_ALU_LT, UPY_ALU_LE, UPY_ALU_GT, UPY_ALU_GE: begin
				dec_kind = 2'd0;
				dec_result = {63'd0, upycore_f64_compare_op(op_i, ar, br)};
			end
			default: dec_kind = 2'd1;
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		u_add_start = 1'b0;
		u_sub = 1'b0;
		u_mul_start = 1'b0;
		u_div_start = 1'b0;
		u_fmod = 1'b0;
		u_sqrt = 1'b0;
		u_pow_start = 1'b0;
		u_a = ar;
		u_b = br;
		(* full_case, parallel_case *)
		case (state_r)
			6'd0:
				if (start_i && (dec_kind == 2'd2)) begin
					u_add_start = !dec_mul && !dec_div;
					u_sub = dec_sub;
					u_mul_start = dec_mul;
					u_div_start = dec_div;
				end
			6'd1: begin
				u_add_start = add_busy;
				u_sub = op_i == UPY_ALU_SUB;
				u_mul_start = mul_run;
				u_div_start = div_busy;
			end
			6'd2: begin
				u_div_start = 1'b1;
				u_fmod = 1'b1;
			end
			6'd4: begin
				u_add_start = 1'b1;
				u_a = t0_r;
				u_b = br;
			end
			6'd5: begin
				u_div_start = 1'b1;
				u_fmod = 1'b1;
			end
			6'd6: begin
				u_add_start = 1'b1;
				u_sub = 1'b1;
				u_a = ar;
				u_b = t0_r;
			end
			6'd7: begin
				u_div_start = 1'b1;
				u_a = t1_r;
				u_b = br;
			end
			6'd9: begin
				u_add_start = 1'b1;
				u_sub = 1'b1;
				u_a = t1_r;
				u_b = UPY_F64_ONE;
			end
			6'd12: begin
				u_add_start = 1'b1;
				u_sub = 1'b1;
				u_a = t1_r;
				u_b = t2_r;
			end
			6'd14: begin
				u_add_start = 1'b1;
				u_a = t2_r;
				u_b = UPY_F64_ONE;
			end
			6'd17: begin
				u_mul_start = 1'b1;
				u_a = t0_r;
				u_b = t0_r;
			end
			6'd18: begin
				u_mul_start = 1'b1;
				u_a = t0_r;
				u_b = t1_r;
			end
			6'd20: begin
				u_div_start = 1'b1;
				u_a = UPY_F64_ONE;
				u_b = t0_r;
			end
			6'd21: begin
				u_div_start = 1'b1;
				u_a = UPY_F64_ONE;
				u_b = t1_r;
			end
			6'd23: begin
				u_pow_start = 1'b1;
				u_a = a_abs;
				u_b = br;
			end
			6'd24: begin
				u_div_start = 1'b1;
				u_sqrt = 1'b1;
				u_a = a_abs;
			end
			default:
				;
		endcase
	end
	wire mod_fix_add;
	wire fd_div_nonzero;
	wire fd_half_up;
	wire [63:0] fd_floor;
	wire pow_overflow;
	wire [6:0] pow_lz;
	function automatic upycore_f64_eq;
		input reg [63:0] a;
		input reg [63:0] b;
		reg [3:0] c;
		begin
			c = upycore_f64_cmp(a, b);
			upycore_f64_eq = c[1];
		end
	endfunction
	assign mod_fix_add = !upycore_f64_eq(t0_r, UPY_F64_PZERO) && (b_lt0 != upycore_f64_lt_zero(t0_r));
	assign fd_div_nonzero = !upycore_f64_eq(t1_r, UPY_F64_PZERO);
	function automatic [63:0] upycore_f64_floor;
		input reg [63:0] a;
		reg [10:0] e;
		reg [5:0] nfrac;
		reg [51:0] frac_mask;
		reg [62:0] trunc;
		begin
			e = a[62:52];
			if (e == 11'h7ff)
				upycore_f64_floor = a;
			else if (e < 11'd1023) begin
				if (upycore_f64_is_zero(a))
					upycore_f64_floor = a;
				else
					upycore_f64_floor = (a[63] ? UPY_F64_NONE : UPY_F64_PZERO);
			end
			else if (e >= 11'd1075)
				upycore_f64_floor = a;
			else begin
				nfrac = sv2v_cast_6(11'd1075 - e);
				frac_mask = (52'd1 << nfrac) - 52'd1;
				trunc = {e, a[51:0] & ~frac_mask};
				if (a[63] && ((a[51:0] & frac_mask) != 52'd0))
					upycore_f64_floor = {1'b1, trunc + (63'd1 << nfrac)};
				else
					upycore_f64_floor = {a[63], trunc};
			end
		end
	endfunction
	assign fd_floor = upycore_f64_floor(t1_r);
	assign fd_half_up = upycore_f64_gt(t3_r, UPY_F64_HALF);
	assign pow_overflow = upycore_f64_is_inf(t0_r);
	function automatic [6:0] upycore_clz64;
		input reg [63:0] v;
		reg [63:0] x;
		reg [5:0] n;
		begin
			x = v;
			n = 1'sb0;
			if (x[63:32] == 0) begin
				n[5] = 1'b1;
				x = x << 32;
			end
			if (x[63:48] == 0) begin
				n[4] = 1'b1;
				x = x << 16;
			end
			if (x[63:56] == 0) begin
				n[3] = 1'b1;
				x = x << 8;
			end
			if (x[63:60] == 0) begin
				n[2] = 1'b1;
				x = x << 4;
			end
			if (x[63:62] == 0) begin
				n[1] = 1'b1;
				x = x << 2;
			end
			n[0] = !x[63];
			upycore_clz64 = (v == 0 ? 7'd64 : {1'b0, n});
		end
	endfunction
	assign pow_lz = upycore_clz64(pow_n_r);
	reg [63:0] fd_floor_r;
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i)
			fd_floor_r <= 1'sb0;
		else
			fd_floor_r <= fd_floor;
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			state_r <= 6'd0;
			t0_r <= 1'sb0;
			t1_r <= 1'sb0;
			t2_r <= 1'sb0;
			t3_r <= 1'sb0;
			pow_n_r <= 1'sb0;
			pow_n0_r <= 1'sb0;
			pow_cnt_r <= 1'sb0;
			pow_neg_r <= 1'b0;
			pow_recip_r <= 1'b0;
			res_r <= 1'sb0;
			mul_run <= 1'b0;
		end
		else if (!start_i) begin
			state_r <= 6'd0;
			mul_run <= 1'b0;
		end
		else
			(* full_case, parallel_case *)
			case (state_r)
				6'd0:
					if (dec_kind == 2'd2) begin
						state_r <= 6'd1;
						mul_run <= dec_mul;
					end
					else if (dec_kind == 2'd3) begin
						state_r <= dec_next;
						pow_neg_r <= dec_pow_neg;
						pow_recip_r <= dec_pow_recip;
						pow_n_r <= dec_pow_n;
						pow_n0_r <= dec_pow_n;
						t0_r <= UPY_F64_ONE;
						t1_r <= a_abs;
					end
				6'd1:
					if (u_done) begin
						state_r <= 6'd0;
						mul_run <= 1'b0;
					end
				6'd2:
					if (u_done) begin
						t0_r <= u_res;
						state_r <= 6'd3;
					end
				6'd3:
					if (mod_fix_add)
						state_r <= 6'd4;
					else begin
						res_r <= (upycore_f64_eq(t0_r, UPY_F64_PZERO) ? {br[63], 63'd0} : t0_r);
						state_r <= 6'd25;
					end
				6'd4:
					if (u_done) begin
						res_r <= u_res;
						state_r <= 6'd25;
					end
				6'd5:
					if (u_done) begin
						t0_r <= u_res;
						state_r <= 6'd6;
					end
				6'd6:
					if (u_done) begin
						t1_r <= u_res;
						state_r <= 6'd7;
					end
				6'd7:
					if (u_done) begin
						t1_r <= u_res;
						state_r <= 6'd8;
					end
				6'd8: state_r <= (mod_fix_add ? 6'd9 : 6'd11);
				6'd9:
					if (u_done) begin
						t1_r <= u_res;
						state_r <= 6'd10;
					end
				6'd10: state_r <= 6'd11;
				6'd11:
					if (fd_div_nonzero) begin
						t2_r <= fd_floor_r;
						state_r <= 6'd12;
					end
					else begin
						res_r <= {ar[63] ^ br[63], 63'd0};
						state_r <= 6'd25;
					end
				6'd12:
					if (u_done) begin
						t3_r <= u_res;
						state_r <= 6'd13;
					end
				6'd13:
					if (fd_half_up)
						state_r <= 6'd14;
					else begin
						res_r <= t2_r;
						state_r <= 6'd25;
					end
				6'd14:
					if (u_done) begin
						res_r <= u_res;
						state_r <= 6'd25;
					end
				6'd15: begin
					t0_r <= t1_r;
					pow_n_r <= pow_n_r << (pow_lz + 7'd1);
					pow_cnt_r <= 7'd63 - pow_lz;
					state_r <= 6'd16;
				end
				6'd16: state_r <= (pow_cnt_r == 7'd0 ? 6'd19 : 6'd17);
				6'd17:
					if (u_done) begin
						t0_r <= u_res;
						if (pow_n_r[63])
							state_r <= 6'd18;
						else begin
							pow_n_r <= pow_n_r << 1;
							pow_cnt_r <= pow_cnt_r - 7'd1;
							state_r <= 6'd16;
						end
					end
				6'd18:
					if (u_done) begin
						t0_r <= u_res;
						pow_n_r <= pow_n_r << 1;
						pow_cnt_r <= pow_cnt_r - 7'd1;
						state_r <= 6'd16;
					end
				6'd19:
					if (!pow_recip_r)
						state_r <= 6'd22;
					else if (pow_overflow)
						state_r <= 6'd21;
					else
						state_r <= 6'd20;
				6'd20:
					if (u_done) begin
						t0_r <= u_res;
						state_r <= 6'd22;
					end
				6'd21:
					if (u_done) begin
						t1_r <= u_res;
						pow_n_r <= pow_n0_r;
						pow_recip_r <= 1'b0;
						state_r <= 6'd15;
					end
				6'd22:
					if (pow_overflow)
						state_r <= 6'd26;
					else begin
						res_r <= {t0_r[63] ^ pow_neg_r, t0_r[62:0]};
						state_r <= 6'd25;
					end
				6'd23:
					if (u_done) begin
						t0_r <= u_res;
						state_r <= 6'd22;
					end
				6'd24:
					if (u_done) begin
						t0_r <= u_res;
						state_r <= 6'd22;
					end
				6'd25, 6'd26: state_r <= 6'd0;
				default: state_r <= 6'd0;
			endcase
	always @(*) begin
		if (_sv2v_0)
			;
		result_o = res_r;
		done_o = 1'b0;
		exception_o = 1'b0;
		(* full_case, parallel_case *)
		case (state_r)
			6'd0:
				if (start_i)
					(* full_case, parallel_case *)
					case (dec_kind)
						2'd0: begin
							done_o = 1'b1;
							result_o = dec_result;
						end
						2'd1: exception_o = 1'b1;
						default:
							;
					endcase
			6'd1: begin
				done_o = u_done;
				result_o = u_res;
			end
			6'd25: done_o = 1'b1;
			6'd26: exception_o = 1'b1;
			default:
				;
		endcase
	end
	assign stall_o = (start_i && !done_o) && !exception_o;
	assign busy_o = state_r != 6'd0;
	initial _sv2v_0 = 0;
endmodule
module mpy_f32_widen (
	f_i,
	d_o
);
	reg _sv2v_0;
	input wire [31:0] f_i;
	output reg [63:0] d_o;
	wire sign;
	wire [7:0] exp;
	wire [22:0] frac;
	wire [4:0] sh;
	wire [22:0] shifted;
	assign sign = f_i[31];
	assign exp = f_i[30:23];
	assign frac = f_i[22:0];
	assign sh = (frac[22] ? 5'd0 : (frac[21] ? 5'd1 : (frac[20] ? 5'd2 : (frac[19] ? 5'd3 : (frac[18] ? 5'd4 : (frac[17] ? 5'd5 : (frac[16] ? 5'd6 : (frac[15] ? 5'd7 : (frac[14] ? 5'd8 : (frac[13] ? 5'd9 : (frac[12] ? 5'd10 : (frac[11] ? 5'd11 : (frac[10] ? 5'd12 : (frac[9] ? 5'd13 : (frac[8] ? 5'd14 : (frac[7] ? 5'd15 : (frac[6] ? 5'd16 : (frac[5] ? 5'd17 : (frac[4] ? 5'd18 : (frac[3] ? 5'd19 : (frac[2] ? 5'd20 : (frac[1] ? 5'd21 : 5'd22))))))))))))))))))))));
	assign shifted = frac << sh;
	always @(*) begin
		if (_sv2v_0)
			;
		if (exp == 8'hff)
			d_o = (frac == 23'b00000000000000000000000 ? {sign, 63'h7ff0000000000000} : {sign, 11'h7ff, frac, 29'b00000000000000000000000000000});
		else if ((exp == 8'h00) && (frac == 23'b00000000000000000000000))
			d_o = {sign, 63'b000000000000000000000000000000000000000000000000000000000000000};
		else if (exp == 8'h00)
			d_o = {sign, 11'd896 - {6'b000000, sh}, shifted[21:0], 30'b000000000000000000000000000000};
		else
			d_o = {sign, {3'b000, exp} + 11'd896, frac, 29'b00000000000000000000000000000};
	end
	initial _sv2v_0 = 0;
endmodule
module mpy_f32_narrow (
	d_i,
	q_o
);
	reg _sv2v_0;
	input wire [63:0] d_i;
	output reg [31:0] q_o;
	wire sign;
	wire [10:0] exp;
	wire [51:0] frac;
	wire signed [12:0] exp32;
	wire round_up;
	wire [23:0] sumf;
	wire [52:0] sig;
	wire [11:0] sh;
	wire [54:0] jam [0:6];
	wire [23:0] mag;
	assign sign = d_i[63];
	assign exp = d_i[62:52];
	assign frac = d_i[51:0];
	assign exp32 = $signed({2'b00, exp}) - 13'sd896;
	assign round_up = d_i[28] && (|d_i[27:0] || d_i[29]);
	assign sumf = {1'b0, d_i[51:29]} + {23'b00000000000000000000000, round_up};
	assign sig = {1'b1, frac};
	assign sh = 12'd926 - {1'b0, exp};
	assign jam[0] = {sig, 2'b00};
	genvar _gv_k_1;
	generate
		for (_gv_k_1 = 0; _gv_k_1 < 6; _gv_k_1 = _gv_k_1 + 1) begin : gen_jam
			localparam k = _gv_k_1;
			localparam signed [31:0] S = 1 << k;
			assign jam[k + 1] = (sh[k] ? {{S {1'b0}}, jam[k][54:S + 1], |jam[k][S:0]} : jam[k]);
		end
	endgenerate
	assign mag = {1'b0, jam[6][24:2]} + {23'd0, jam[6][1] && (jam[6][0] || jam[6][2])};
	always @(*) begin
		if (_sv2v_0)
			;
		if (exp == 11'h7ff)
			q_o = (frac == 52'b0000000000000000000000000000000000000000000000000000 ? {sign, 31'h7f800000} : {sign, 31'h7fc00000});
		else if ((d_i[62:0] == 63'b000000000000000000000000000000000000000000000000000000000000000) || (exp == 11'b00000000000))
			q_o = {sign, 31'b0000000000000000000000000000000};
		else if (exp32 >= 13'sd255)
			q_o = {sign, 31'h7f800000};
		else if (exp32 >= 13'sd1)
			q_o = (sumf[23] ? (exp32 >= 13'sd254 ? {sign, 31'h7f800000} : {sign, exp32[7:0] + 8'd1, 23'b00000000000000000000000}) : {sign, exp32[7:0], sumf[22:0]});
		else if (sh >= 12'd54)
			q_o = {sign, 31'b0000000000000000000000000000000};
		else if (sh == 12'd53)
			q_o = {sign, 30'b000000000000000000000000000000, sig[52] && |sig[51:0]};
		else
			q_o = (mag[23] ? {sign, 31'h00800000} : {sign, 8'b00000000, mag[22:0]});
	end
	initial _sv2v_0 = 0;
endmodule
module mpy_alu (
	clk_i,
	rst_n_i,
	start_i,
	op_i,
	a_flt_i,
	b_flt_i,
	a_i,
	b_i,
	small_i,
	done_o,
	res_o,
	rkind_o,
	err_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_n_i;
	input wire start_i;
	input wire [5:0] op_i;
	input wire a_flt_i;
	input wire b_flt_i;
	input wire [63:0] a_i;
	input wire [63:0] b_i;
	input wire small_i;
	output reg done_o;
	output reg [63:0] res_o;
	output reg [1:0] rkind_o;
	output reg [2:0] err_o;
	reg [3:0] st;
	reg [5:0] op;
	reg small_r;
	reg [63:0] a;
	reg [63:0] b;
	reg [31:0] fa;
	reg [31:0] fb;
	wire [63:0] fa64;
	wire [63:0] fb64;
	reg [63:0] fa64_r;
	reg [63:0] fb64_r;
	reg [63:0] amag;
	reg [63:0] bmag;
	reg [63:0] anorm;
	reg [63:0] bnorm;
	reg [5:0] alz;
	reg [5:0] blz;
	reg azero;
	reg bzero;
	reg aflt;
	reg bflt;
	wire [31:0] aconv;
	wire [31:0] bconv;
	function automatic [31:0] mpy_alu_pkg_mpy_i64_round;
		input reg sign;
		input reg zero;
		input reg [5:0] lz;
		input reg [63:0] norm;
		reg [24:0] rounded;
		reg [7:0] exp;
		begin
			rounded = {1'b0, norm[63:40]} + {24'd0, norm[39] && (|norm[38:0] || norm[40])};
			exp = (8'd190 - {2'd0, lz}) + {7'd0, rounded[24]};
			mpy_alu_pkg_mpy_i64_round = (zero ? 32'd0 : {sign, exp, (rounded[24] ? rounded[23:1] : rounded[22:0])});
		end
	endfunction
	assign aconv = mpy_alu_pkg_mpy_i64_round(a[63], azero, alz, anorm);
	assign bconv = mpy_alu_pkg_mpy_i64_round(b[63], bzero, blz, bnorm);
	reg [4:0] iop;
	wire [63:0] ires;
	wire izero;
	wire iovf;
	wire iverr;
	localparam [4:0] UPY_ALU_ADD = 5'd0;
	localparam [4:0] UPY_ALU_AND = 5'd9;
	localparam [4:0] UPY_ALU_EQ = 5'd16;
	localparam [4:0] UPY_ALU_GE = 5'd21;
	localparam [4:0] UPY_ALU_GT = 5'd20;
	localparam [4:0] UPY_ALU_INVERT = 5'd14;
	localparam [4:0] UPY_ALU_LE = 5'd19;
	localparam [4:0] UPY_ALU_LSHIFT = 5'd7;
	localparam [4:0] UPY_ALU_LT = 5'd18;
	localparam [4:0] UPY_ALU_NE = 5'd17;
	localparam [4:0] UPY_ALU_NEG = 5'd12;
	localparam [4:0] UPY_ALU_OR = 5'd10;
	localparam [4:0] UPY_ALU_PASS = 5'd22;
	localparam [4:0] UPY_ALU_RSHIFT = 5'd8;
	localparam [4:0] UPY_ALU_SUB = 5'd1;
	localparam [4:0] UPY_ALU_XOR = 5'd11;
	localparam [5:0] mpy_alu_pkg_ALU_ADD = 6'd27;
	localparam [5:0] mpy_alu_pkg_ALU_AND = 6'd24;
	localparam [5:0] mpy_alu_pkg_ALU_EQ = 6'd2;
	localparam [5:0] mpy_alu_pkg_ALU_GE = 6'd4;
	localparam [5:0] mpy_alu_pkg_ALU_GT = 6'd1;
	localparam [5:0] mpy_alu_pkg_ALU_INVERT = 6'd42;
	localparam [5:0] mpy_alu_pkg_ALU_LE = 6'd3;
	localparam [5:0] mpy_alu_pkg_ALU_LSHIFT = 6'd25;
	localparam [5:0] mpy_alu_pkg_ALU_LT = 6'd0;
	localparam [5:0] mpy_alu_pkg_ALU_NE = 6'd5;
	localparam [5:0] mpy_alu_pkg_ALU_NEG = 6'd40;
	localparam [5:0] mpy_alu_pkg_ALU_OR = 6'd22;
	localparam [5:0] mpy_alu_pkg_ALU_RSHIFT = 6'd26;
	localparam [5:0] mpy_alu_pkg_ALU_SUB = 6'd28;
	localparam [5:0] mpy_alu_pkg_ALU_XOR = 6'd23;
	always @(*) begin
		if (_sv2v_0)
			;
		case (op)
			mpy_alu_pkg_ALU_ADD: iop = UPY_ALU_ADD;
			mpy_alu_pkg_ALU_SUB: iop = UPY_ALU_SUB;
			mpy_alu_pkg_ALU_AND: iop = UPY_ALU_AND;
			mpy_alu_pkg_ALU_OR: iop = UPY_ALU_OR;
			mpy_alu_pkg_ALU_XOR: iop = UPY_ALU_XOR;
			mpy_alu_pkg_ALU_LSHIFT: iop = UPY_ALU_LSHIFT;
			mpy_alu_pkg_ALU_RSHIFT: iop = UPY_ALU_RSHIFT;
			mpy_alu_pkg_ALU_LT: iop = UPY_ALU_LT;
			mpy_alu_pkg_ALU_GT: iop = UPY_ALU_GT;
			mpy_alu_pkg_ALU_EQ: iop = UPY_ALU_EQ;
			mpy_alu_pkg_ALU_LE: iop = UPY_ALU_LE;
			mpy_alu_pkg_ALU_GE: iop = UPY_ALU_GE;
			mpy_alu_pkg_ALU_NE: iop = UPY_ALU_NE;
			mpy_alu_pkg_ALU_NEG: iop = UPY_ALU_NEG;
			mpy_alu_pkg_ALU_INVERT: iop = UPY_ALU_INVERT;
			default: iop = UPY_ALU_PASS;
		endcase
	end
	upycore_int_alu u_int(
		.op_a_i(a),
		.op_b_i(b),
		.op_i(iop),
		.result_o(ires),
		.zero_flag_o(izero),
		.overflow_flag_o(iovf),
		.value_error_o(iverr)
	);
	wire pow_mul_start;
	wire [63:0] mul_a;
	wire [63:0] mul_b;
	wire [63:0] pow_mul_a;
	wire [63:0] pow_mul_b;
	wire [63:0] mul_lo;
	wire [63:0] mul_hi;
	wire mul_done;
	wire mul_stall;
	wire mul_busy;
	assign mul_a = (st == 4'd3 ? pow_mul_a : a);
	assign mul_b = (st == 4'd3 ? pow_mul_b : b);
	upycore_mul u_mul(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.start_i((st == 4'd1) || ((st == 4'd3) && pow_mul_start)),
		.op_a_i(mul_a),
		.op_b_i(mul_b),
		.result_o(mul_lo),
		.result_hi_o(mul_hi),
		.done_o(mul_done),
		.stall_o(mul_stall),
		.busy_o(mul_busy)
	);
	wire [63:0] pow_res;
	wire pow_trap;
	wire pow_done;
	wire pow_stall;
	wire pow_busy;
	upycore_ipow u_pow(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.start_i(st == 4'd3),
		.base_i(a),
		.exp_i(b),
		.mul_start_o(pow_mul_start),
		.mul_a_o(pow_mul_a),
		.mul_b_o(pow_mul_b),
		.mul_lo_i(mul_lo),
		.mul_hi_i(mul_hi),
		.mul_done_i(mul_done),
		.result_o(pow_res),
		.trap_o(pow_trap),
		.done_o(pow_done),
		.stall_o(pow_stall),
		.busy_o(pow_busy)
	);
	wire [63:0] quot;
	wire [63:0] rem;
	wire div_zero;
	wire div_done;
	wire div_stall;
	wire div_busy;
	upycore_div u_div(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.start_i(st == 4'd2),
		.op_a_i(a),
		.op_b_i(b),
		.quot_o(quot),
		.rem_o(rem),
		.div_zero_o(div_zero),
		.done_o(div_done),
		.stall_o(div_stall),
		.busy_o(div_busy)
	);
	reg [4:0] fop;
	wire [63:0] fres;
	wire [31:0] fnarrow;
	reg [63:0] fres_r;
	wire fexc;
	wire fdone;
	wire fstall;
	wire fbusy;
	localparam [4:0] UPY_ALU_FLOOR_DIV = 5'd3;
	localparam [4:0] UPY_ALU_MOD = 5'd5;
	localparam [4:0] UPY_ALU_MUL = 5'd2;
	localparam [4:0] UPY_ALU_POWER = 5'd6;
	localparam [4:0] UPY_ALU_TRUE_DIV = 5'd4;
	localparam [5:0] mpy_alu_pkg_ALU_FLOOR = 6'd31;
	localparam [5:0] mpy_alu_pkg_ALU_MOD = 6'd33;
	localparam [5:0] mpy_alu_pkg_ALU_MUL = 6'd29;
	localparam [5:0] mpy_alu_pkg_ALU_POW = 6'd34;
	localparam [5:0] mpy_alu_pkg_ALU_TDIV = 6'd32;
	always @(*) begin
		if (_sv2v_0)
			;
		case (op)
			mpy_alu_pkg_ALU_ADD: fop = UPY_ALU_ADD;
			mpy_alu_pkg_ALU_SUB: fop = UPY_ALU_SUB;
			mpy_alu_pkg_ALU_MUL: fop = UPY_ALU_MUL;
			mpy_alu_pkg_ALU_TDIV: fop = UPY_ALU_TRUE_DIV;
			mpy_alu_pkg_ALU_FLOOR: fop = UPY_ALU_FLOOR_DIV;
			mpy_alu_pkg_ALU_MOD: fop = UPY_ALU_MOD;
			mpy_alu_pkg_ALU_POW: fop = UPY_ALU_POWER;
			default: fop = UPY_ALU_PASS;
		endcase
	end
	upycore_fpu u_fpu(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.start_i(st == 4'd4),
		.op_i(fop),
		.op_a_i(fa64_r),
		.op_b_i(fb64_r),
		.result_o(fres),
		.exception_o(fexc),
		.done_o(fdone),
		.stall_o(fstall),
		.busy_o(fbusy)
	);
	mpy_f32_narrow u_narrow(
		.d_i(fres_r),
		.q_o(fnarrow)
	);
	wire [5:0] dop;
	wire [31:0] dxa;
	wire [31:0] dxb;
	reg f_cmp;
	reg f_fpu;
	reg [2:0] f_err;
	assign dop = (st == 4'd6 ? op : op_i);
	assign dxa = (st == 4'd6 ? fa : a_i[31:0]);
	assign dxb = (st == 4'd6 ? fb : b_i[31:0]);
	localparam [2:0] mpy_alu_pkg_AE_COMPLEX = 3'd5;
	localparam [2:0] mpy_alu_pkg_AE_NONE = 3'd0;
	localparam [2:0] mpy_alu_pkg_AE_UNSUPPORTED = 3'd4;
	localparam [2:0] mpy_alu_pkg_AE_ZERO_DIV = 3'd1;
	function automatic mpy_alu_pkg_mpy_f32_nan;
		input reg [31:0] f;
		mpy_alu_pkg_mpy_f32_nan = (f[30:23] == 8'hff) && (f[22:0] != 23'd0);
	endfunction
	function automatic mpy_alu_pkg_mpy_f32_zero;
		input reg [31:0] f;
		mpy_alu_pkg_mpy_f32_zero = f[30:0] == 31'd0;
	endfunction
	function automatic mpy_alu_pkg_mpy_f32_eq;
		input reg [31:0] a;
		input reg [31:0] b;
		mpy_alu_pkg_mpy_f32_eq = (!mpy_alu_pkg_mpy_f32_nan(a) && !mpy_alu_pkg_mpy_f32_nan(b)) && ((a == b) || (mpy_alu_pkg_mpy_f32_zero(a) && mpy_alu_pkg_mpy_f32_zero(b)));
	endfunction
	function automatic mpy_alu_pkg_mpy_f32_integral;
		input reg [31:0] f;
		reg [7:0] e;
		begin
			e = f[30:23];
			if (e == 8'hff)
				mpy_alu_pkg_mpy_f32_integral = 1'b0;
			else if (e >= 8'd150)
				mpy_alu_pkg_mpy_f32_integral = 1'b1;
			else if (e < 8'd127)
				mpy_alu_pkg_mpy_f32_integral = f[30:0] == 31'd0;
			else
				mpy_alu_pkg_mpy_f32_integral = (f[22:0] & (23'h7fffff >> (e - 8'd127))) == 23'd0;
		end
	endfunction
	function automatic mpy_alu_pkg_mpy_f32_lt;
		input reg [31:0] a;
		input reg [31:0] b;
		if ((mpy_alu_pkg_mpy_f32_nan(a) || mpy_alu_pkg_mpy_f32_nan(b)) || (mpy_alu_pkg_mpy_f32_zero(a) && mpy_alu_pkg_mpy_f32_zero(b)))
			mpy_alu_pkg_mpy_f32_lt = 1'b0;
		else if (a[31] != b[31])
			mpy_alu_pkg_mpy_f32_lt = a[31];
		else if (!a[31])
			mpy_alu_pkg_mpy_f32_lt = a[30:0] < b[30:0];
		else
			mpy_alu_pkg_mpy_f32_lt = a[30:0] > b[30:0];
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		case (dop)
			mpy_alu_pkg_ALU_LT: f_cmp = mpy_alu_pkg_mpy_f32_lt(dxa, dxb);
			mpy_alu_pkg_ALU_GT: f_cmp = mpy_alu_pkg_mpy_f32_lt(dxb, dxa);
			mpy_alu_pkg_ALU_LE: f_cmp = mpy_alu_pkg_mpy_f32_lt(dxa, dxb) || mpy_alu_pkg_mpy_f32_eq(dxa, dxb);
			mpy_alu_pkg_ALU_GE: f_cmp = mpy_alu_pkg_mpy_f32_lt(dxb, dxa) || mpy_alu_pkg_mpy_f32_eq(dxa, dxb);
			mpy_alu_pkg_ALU_EQ: f_cmp = mpy_alu_pkg_mpy_f32_eq(dxa, dxb);
			default: f_cmp = !mpy_alu_pkg_mpy_f32_eq(dxa, dxb);
		endcase
		f_err = mpy_alu_pkg_AE_NONE;
		case (dop)
			mpy_alu_pkg_ALU_ADD, mpy_alu_pkg_ALU_SUB, mpy_alu_pkg_ALU_MUL:
				;
			mpy_alu_pkg_ALU_TDIV, mpy_alu_pkg_ALU_FLOOR, mpy_alu_pkg_ALU_MOD:
				if (mpy_alu_pkg_mpy_f32_zero(dxb))
					f_err = mpy_alu_pkg_AE_ZERO_DIV;
			mpy_alu_pkg_ALU_POW:
				if ((mpy_alu_pkg_mpy_f32_zero(dxa) && dxb[31]) && !((dxb[30:23] == 8'hff) && (dxb[22:0] == 23'd0)))
					f_err = mpy_alu_pkg_AE_ZERO_DIV;
				else if (((((dxa[31] && !mpy_alu_pkg_mpy_f32_zero(dxa)) && !mpy_alu_pkg_mpy_f32_nan(dxa)) && !mpy_alu_pkg_mpy_f32_integral(dxb)) && !mpy_alu_pkg_mpy_f32_nan(dxb)) && (dxb[30:23] != 8'hff))
					f_err = mpy_alu_pkg_AE_COMPLEX;
			default: f_err = mpy_alu_pkg_AE_UNSUPPORTED;
		endcase
		f_fpu = f_err == mpy_alu_pkg_AE_NONE;
	end
	mpy_f32_widen u_wa(
		.f_i(dxa),
		.d_o(fa64)
	);
	mpy_f32_widen u_wb(
		.f_i(dxb),
		.d_o(fb64)
	);
	localparam [2:0] mpy_alu_pkg_AE_FTOI = 3'd6;
	localparam [2:0] mpy_alu_pkg_AE_NEG_SHIFT = 3'd3;
	localparam [2:0] mpy_alu_pkg_AE_OVERFLOW = 3'd2;
	localparam [1:0] mpy_alu_pkg_AK_BOOL = 2'd3;
	localparam [1:0] mpy_alu_pkg_AK_FLOAT = 2'd1;
	localparam [1:0] mpy_alu_pkg_AK_INT = 2'd0;
	localparam [5:0] mpy_alu_pkg_ALU_ABS = 6'd43;
	localparam [5:0] mpy_alu_pkg_ALU_F2I = 6'd45;
	localparam [5:0] mpy_alu_pkg_ALU_I2F = 6'd44;
	localparam [5:0] mpy_alu_pkg_ALU_MATMUL = 6'd30;
	localparam [5:0] mpy_alu_pkg_ALU_POS = 6'd41;
	function automatic [4:0] sv2v_cast_5;
		input reg [4:0] inp;
		sv2v_cast_5 = inp;
	endfunction
	function automatic mpy_alu_pkg_mpy_f32_odd;
		input reg [31:0] f;
		reg [7:0] e;
		begin
			e = f[30:23];
			if ((!mpy_alu_pkg_mpy_f32_integral(f) || (e < 8'd127)) || (e > 8'd150))
				mpy_alu_pkg_mpy_f32_odd = 1'b0;
			else if (e == 8'd127)
				mpy_alu_pkg_mpy_f32_odd = 1'b1;
			else
				mpy_alu_pkg_mpy_f32_odd = f[sv2v_cast_5(8'd150 - e)];
		end
	endfunction
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	function automatic [63:0] mpy_alu_pkg_mpy_f32_to_i64;
		input reg [31:0] f;
		output reg ok;
		reg [7:0] e;
		reg [63:0] m;
		reg signed [31:0] x;
		begin
			e = f[30:23];
			ok = 1'b1;
			mpy_alu_pkg_mpy_f32_to_i64 = 64'd0;
			if (e == 8'hff)
				ok = 1'b0;
			else if (e >= 8'd127) begin
				x = sv2v_cast_32_signed(e) - 127;
				if (x >= 63)
					ok = 1'b0;
				else begin
					m = {41'h00000000001, f[22:0]};
					if (x >= 23)
						m = m << (x - 23);
					else
						m = m >> (23 - x);
					mpy_alu_pkg_mpy_f32_to_i64 = (f[31] ? ~m + 64'd1 : m);
				end
			end
		end
	endfunction
	function automatic [6:0] upycore_clz64;
		input reg [63:0] v;
		reg [63:0] x;
		reg [5:0] n;
		begin
			x = v;
			n = 1'sb0;
			if (x[63:32] == 0) begin
				n[5] = 1'b1;
				x = x << 32;
			end
			if (x[63:48] == 0) begin
				n[4] = 1'b1;
				x = x << 16;
			end
			if (x[63:56] == 0) begin
				n[3] = 1'b1;
				x = x << 8;
			end
			if (x[63:60] == 0) begin
				n[2] = 1'b1;
				x = x << 4;
			end
			if (x[63:62] == 0) begin
				n[1] = 1'b1;
				x = x << 2;
			end
			n[0] = !x[63];
			upycore_clz64 = (v == 0 ? 7'd64 : {1'b0, n});
		end
	endfunction
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			st <= 4'd0;
			done_o <= 1'b0;
			res_o <= 1'sb0;
			rkind_o <= mpy_alu_pkg_AK_INT;
			err_o <= mpy_alu_pkg_AE_NONE;
			amag <= 1'sb0;
			bmag <= 1'sb0;
			anorm <= 1'sb0;
			bnorm <= 1'sb0;
			alz <= 1'sb0;
			blz <= 1'sb0;
			azero <= 1'b1;
			bzero <= 1'b1;
			aflt <= 1'b0;
			bflt <= 1'b0;
			op <= 1'sb0;
			small_r <= 1'b0;
			a <= 1'sb0;
			b <= 1'sb0;
			fa <= 1'sb0;
			fb <= 1'sb0;
			fres_r <= 1'sb0;
			fa64_r <= 1'sb0;
			fb64_r <= 1'sb0;
		end
		else begin
			done_o <= 1'b0;
			case (st)
				4'd0:
					if (start_i) begin : sv2v_autoblock_1
						reg isf;
						reg conv;
						reg ok;
						reg [63:0] v;
						op <= op_i;
						small_r <= small_i;
						a <= a_i;
						b <= b_i;
						aflt <= a_flt_i;
						bflt <= b_flt_i;
						amag <= (a_i[63] ? ~a_i + 64'd1 : a_i);
						bmag <= (b_i[63] ? ~b_i + 64'd1 : b_i);
						fa <= a_i[31:0];
						fb <= b_i[31:0];
						fa64_r <= fa64;
						fb64_r <= fb64;
						err_o <= mpy_alu_pkg_AE_NONE;
						res_o <= 1'sb0;
						rkind_o <= mpy_alu_pkg_AK_INT;
						isf = a_flt_i || b_flt_i;
						conv = !a_flt_i || !b_flt_i;
						if (op_i == mpy_alu_pkg_ALU_I2F) begin
							rkind_o <= mpy_alu_pkg_AK_FLOAT;
							st <= 4'd8;
						end
						else if (op_i == mpy_alu_pkg_ALU_F2I) begin
							v = mpy_alu_pkg_mpy_f32_to_i64(a_i[31:0], ok);
							res_o <= v;
							if (!ok)
								err_o <= mpy_alu_pkg_AE_FTOI;
							st <= 4'd7;
						end
						else if (op_i >= mpy_alu_pkg_ALU_NEG) begin
							if (a_flt_i) begin
								rkind_o <= mpy_alu_pkg_AK_FLOAT;
								case (op_i)
									mpy_alu_pkg_ALU_NEG: res_o <= {32'd0, ~a_i[31], a_i[30:0]};
									mpy_alu_pkg_ALU_POS: res_o <= {32'd0, a_i[31:0]};
									mpy_alu_pkg_ALU_ABS: res_o <= {33'h000000000, a_i[30:0]};
									default: err_o <= mpy_alu_pkg_AE_UNSUPPORTED;
								endcase
								st <= 4'd7;
							end
							else begin
								if ((op_i == mpy_alu_pkg_ALU_ABS) && !a_i[63])
									op <= mpy_alu_pkg_ALU_POS;
								else if (op_i == mpy_alu_pkg_ALU_ABS)
									op <= mpy_alu_pkg_ALU_NEG;
								st <= 4'd7;
							end
						end
						else if (op_i <= mpy_alu_pkg_ALU_NE) begin
							if (isf && conv)
								st <= 4'd8;
							else if (isf) begin
								rkind_o <= mpy_alu_pkg_AK_BOOL;
								res_o <= {63'd0, f_cmp};
								st <= 4'd7;
							end
							else
								st <= 4'd7;
						end
						else if ((isf || (op_i == mpy_alu_pkg_ALU_TDIV)) || ((op_i == mpy_alu_pkg_ALU_POW) && b_i[63])) begin
							rkind_o <= mpy_alu_pkg_AK_FLOAT;
							if (conv)
								st <= 4'd8;
							else begin
								err_o <= f_err;
								st <= (f_fpu ? 4'd4 : 4'd7);
							end
						end
						else
							case (op_i)
								mpy_alu_pkg_ALU_MUL: st <= 4'd1;
								mpy_alu_pkg_ALU_FLOOR, mpy_alu_pkg_ALU_MOD:
									if (b_i == 64'd0) begin
										err_o <= mpy_alu_pkg_AE_ZERO_DIV;
										st <= 4'd7;
									end
									else
										st <= 4'd2;
								mpy_alu_pkg_ALU_POW: st <= 4'd3;
								mpy_alu_pkg_ALU_MATMUL: begin
									err_o <= mpy_alu_pkg_AE_UNSUPPORTED;
									st <= 4'd7;
								end
								default: st <= 4'd7;
							endcase
					end
				4'd1:
					if (mul_done) begin
						res_o <= mul_lo;
						if (mul_hi != {64 {mul_lo[63]}})
							err_o <= mpy_alu_pkg_AE_OVERFLOW;
						st <= 4'd0;
						done_o <= 1'b1;
					end
				4'd2:
					if (div_done) begin
						if (((small_r && (op == mpy_alu_pkg_ALU_FLOOR)) && (a == 64'h8000000000000000)) && (b == 64'hffffffffffffffff))
							err_o <= mpy_alu_pkg_AE_OVERFLOW;
						else if ((!small_r && (rem != 64'd0)) && (a[63] != b[63]))
							res_o <= (op == mpy_alu_pkg_ALU_FLOOR ? quot + 64'd1 : rem - b);
						else
							res_o <= (op == mpy_alu_pkg_ALU_FLOOR ? quot : rem);
						st <= 4'd0;
						done_o <= 1'b1;
					end
				4'd3:
					if (pow_done || pow_trap) begin
						res_o <= pow_res;
						if (pow_trap)
							err_o <= mpy_alu_pkg_AE_OVERFLOW;
						st <= 4'd0;
						done_o <= 1'b1;
					end
				4'd4:
					if (fdone || fexc) begin
						if (fexc) begin
							res_o <= {32'd0, fa[31] && mpy_alu_pkg_mpy_f32_odd(fb), 31'h7f800000};
							st <= 4'd0;
							done_o <= 1'b1;
						end
						else begin
							fres_r <= fres;
							st <= 4'd5;
						end
					end
				4'd8: begin
					alz <= sv2v_cast_6(upycore_clz64(amag));
					blz <= sv2v_cast_6(upycore_clz64(bmag));
					azero <= amag == 64'd0;
					bzero <= bmag == 64'd0;
					anorm <= amag << sv2v_cast_6(upycore_clz64(amag));
					bnorm <= bmag << sv2v_cast_6(upycore_clz64(bmag));
					st <= 4'd9;
				end
				4'd9: begin
					fa <= (aflt ? fa : aconv);
					fb <= (bflt ? fb : bconv);
					if (op == mpy_alu_pkg_ALU_I2F) begin
						res_o <= {32'd0, (aflt ? fa : aconv)};
						st <= 4'd7;
					end
					else
						st <= 4'd6;
				end
				4'd6: begin
					fa64_r <= fa64;
					fb64_r <= fb64;
					if (op <= mpy_alu_pkg_ALU_NE) begin
						rkind_o <= mpy_alu_pkg_AK_BOOL;
						res_o <= {63'd0, f_cmp};
						st <= 4'd7;
					end
					else begin
						err_o <= f_err;
						st <= (f_fpu ? 4'd4 : 4'd7);
					end
				end
				4'd5: begin
					res_o <= {32'd0, fnarrow};
					st <= 4'd0;
					done_o <= 1'b1;
				end
				4'd7: begin
					if (((rkind_o == mpy_alu_pkg_AK_INT) && (err_o == mpy_alu_pkg_AE_NONE)) && (op != mpy_alu_pkg_ALU_F2I)) begin
						res_o <= ires;
						if (op <= mpy_alu_pkg_ALU_NE)
							rkind_o <= mpy_alu_pkg_AK_BOOL;
						else if ((small_r && ((op == mpy_alu_pkg_ALU_LSHIFT) || (op == mpy_alu_pkg_ALU_RSHIFT))) && (b[63:31] != {33 {b[31]}}))
							err_o <= mpy_alu_pkg_AE_OVERFLOW;
						else if (iverr)
							err_o <= mpy_alu_pkg_AE_NEG_SHIFT;
						else if (iovf)
							err_o <= mpy_alu_pkg_AE_OVERFLOW;
					end
					st <= 4'd0;
					done_o <= 1'b1;
				end
				default: st <= 4'd0;
			endcase
		end
	wire unused;
	assign unused = ^{izero, mul_stall, mul_busy, pow_stall, pow_busy, div_zero, div_stall, div_busy, fstall, fbusy};
	initial _sv2v_0 = 0;
endmodule
module upycore_umod_seq (
	clk_i,
	rst_n_i,
	start_i,
	a_i,
	d_i,
	done_o,
	rem_o,
	busy_o
);
	reg _sv2v_0;
	parameter signed [31:0] BPC = 4;
	input wire clk_i;
	input wire rst_n_i;
	input wire start_i;
	input wire [31:0] a_i;
	input wire [31:0] d_i;
	output reg done_o;
	output reg [31:0] rem_o;
	output wire busy_o;
	generate
		if (((BPC != 1) && (BPC != 2)) && (BPC != 4)) begin : gen_bad_bpc
			nonexistent_module_BPC_must_be_1_2_or_4 bad_bpc();
		end
	endgenerate
	function automatic signed [5:0] sv2v_cast_6_signed;
		input reg signed [5:0] inp;
		sv2v_cast_6_signed = inp;
	endfunction
	function automatic [5:0] clz32;
		input reg [31:0] v;
		begin
			clz32 = 6'd32;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < 32; i = i + 1)
					if (v[i])
						clz32 = sv2v_cast_6_signed(31 - i);
			end
		end
	endfunction
	reg [31:0] d_r;
	reg [33:0] d3_r;
	reg [31:0] r_r;
	reg [31:0] q_r;
	reg [5:0] n_r;
	wire [5:0] lz_a;
	wire [5:0] lz_d;
	wire [6:0] k;
	wire [6:0] kr;
	assign lz_a = clz32(a_i);
	assign lz_d = clz32(d_i);
	function automatic [6:0] sv2v_cast_7;
		input reg [6:0] inp;
		sv2v_cast_7 = inp;
	endfunction
	assign k = (sv2v_cast_7(lz_d) - sv2v_cast_7(lz_a)) + 7'd1;
	function automatic signed [6:0] sv2v_cast_7_signed;
		input reg signed [6:0] inp;
		sv2v_cast_7_signed = inp;
	endfunction
	assign kr = (k + sv2v_cast_7_signed(BPC - 1)) & ~sv2v_cast_7_signed(BPC - 1);
	reg [31:0] r_nx;
	reg [31:0] q_nx;
	always @(*) begin : sv2v_autoblock_2
		reg [32:0] t;
		reg [33:0] t4;
		reg [33:0] dif2;
		reg [34:0] e1;
		reg [34:0] e2;
		reg [34:0] e3;
		if (_sv2v_0)
			;
		r_nx = r_r;
		q_nx = q_r;
		if (BPC == 1) begin
			t = {r_nx, q_nx[31]};
			q_nx = {q_nx[30:0], 1'b0};
			dif2 = {1'b0, t} - {2'b00, d_r};
			r_nx = (dif2[33] ? t[31:0] : dif2[31:0]);
		end
		else begin : sv2v_autoblock_3
			reg signed [31:0] j;
			for (j = 0; j < (BPC / 2); j = j + 1)
				begin
					t4 = {r_nx, q_nx[31:30]};
					q_nx = {q_nx[29:0], 2'b00};
					e1 = {1'b0, t4} - {3'b000, d_r};
					e2 = {1'b0, t4} - {2'b00, d_r, 1'b0};
					e3 = {1'b0, t4} - {1'b0, d3_r};
					if (!e3[34])
						r_nx = e3[31:0];
					else if (!e2[34])
						r_nx = e2[31:0];
					else if (!e1[34])
						r_nx = e1[31:0];
					else
						r_nx = t4[31:0];
				end
		end
	end
	assign busy_o = n_r != 6'd0;
	function automatic [63:0] sv2v_cast_64;
		input reg [63:0] inp;
		sv2v_cast_64 = inp;
	endfunction
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			d_r <= 1'sb0;
			d3_r <= 1'sb0;
			r_r <= 1'sb0;
			q_r <= 1'sb0;
			n_r <= 1'sb0;
			done_o <= 1'b0;
			rem_o <= 1'sb0;
		end
		else begin
			done_o <= 1'b0;
			if (start_i) begin
				d_r <= d_i;
				d3_r <= {2'b00, d_i} + {1'b0, d_i, 1'b0};
				if (a_i < d_i) begin
					n_r <= 1'sb0;
					done_o <= 1'b1;
					rem_o <= a_i;
				end
				else begin
					r_r <= sv2v_cast_32(sv2v_cast_64(a_i) >> kr);
					q_r <= sv2v_cast_32(sv2v_cast_64(a_i) << (7'd32 - kr));
					n_r <= sv2v_cast_6(kr / sv2v_cast_7_signed(BPC));
				end
			end
			else if (n_r != 6'd0) begin
				r_r <= r_nx;
				q_r <= q_nx;
				n_r <= n_r - 6'd1;
				if (n_r == 6'd1) begin
					done_o <= 1'b1;
					rem_o <= r_nx;
				end
			end
		end
	initial _sv2v_0 = 0;
endmodule
module mpy_decode (
	instr_valid_i,
	bytes_i,
	nbytes_i,
	decoded_valid_o,
	illegal_o,
	truncated_o,
	arg_overflow_o,
	len_o,
	opcode_o,
	format_o,
	entry_o,
	arg_valid_o,
	arg_o,
	extra_valid_o,
	extra_o
);
	reg _sv2v_0;
	input wire instr_valid_i;
	input wire [63:0] bytes_i;
	input wire [3:0] nbytes_i;
	output reg decoded_valid_o;
	output reg illegal_o;
	output reg truncated_o;
	output reg arg_overflow_o;
	output reg [3:0] len_o;
	output reg [7:0] opcode_o;
	output reg [1:0] format_o;
	output reg [6:0] entry_o;
	output reg arg_valid_o;
	output reg signed [31:0] arg_o;
	output reg extra_valid_o;
	output reg [7:0] extra_o;
	localparam [1:0] FMT_BYTE = 2'd0;
	localparam [1:0] FMT_QSTR = 2'd1;
	localparam [1:0] FMT_VARUINT = 2'd2;
	localparam [1:0] FMT_OFFSET = 2'd3;
	localparam [7:0] EXTRA_MASK = 8'h9e;
	localparam [7:0] BC_LOAD_CONST_SMALL_INT = 8'h22;
	localparam [7:0] BC_SMALL_INT_BASE = 8'h70;
	localparam [7:0] BC_LOAD_FAST_BASE = 8'hb0;
	localparam [7:0] BC_STORE_FAST_BASE = 8'hc0;
	localparam [7:0] BC_UNARY_BASE = 8'hd0;
	localparam [7:0] BC_BINARY_BASE = 8'hd7;
	localparam [7:0] SMALL_INT_NUM = 8'd64;
	localparam [7:0] SMALL_INT_EXCESS = 8'd16;
	localparam [7:0] FAST_NUM = 8'd16;
	localparam [7:0] UNARY_NUM = 8'd4;
	localparam [7:0] BINARY_NUM = 8'd35;
	function automatic [1:0] sv2v_cast_2;
		input reg [1:0] inp;
		sv2v_cast_2 = inp;
	endfunction
	function automatic [1:0] bc_format;
		input reg [3:0] hi;
		bc_format = sv2v_cast_2((32'h000003a4 >> {27'b000000000000000000000000000, hi, 1'b0}) & 32'h00000003);
	endfunction
	function automatic offset_is_signed;
		input reg [7:0] op;
		offset_is_signed = (((op == 8'h40) || (op == 8'h42)) || (op == 8'h43)) || (op == 8'h44);
	endfunction
	function automatic [6:0] sv2v_cast_7;
		input reg [6:0] inp;
		sv2v_cast_7 = inp;
	endfunction
	function automatic [6:0] map_entry;
		input reg [7:0] op;
		input reg signed [31:0] arg;
		output reg known;
		reg [7:0] imm;
		begin
			known = 1'b1;
			imm = 8'h00;
			map_entry = 7'd0;
			if ((op >= BC_SMALL_INT_BASE) && (op < (BC_SMALL_INT_BASE + SMALL_INT_NUM)))
				map_entry = sv2v_cast_7((7'd0 + 1) + 3);
			else if ((op >= BC_LOAD_FAST_BASE) && (op < (BC_LOAD_FAST_BASE + FAST_NUM)))
				map_entry = sv2v_cast_7(7'd0 + 1);
			else if ((op >= BC_STORE_FAST_BASE) && (op < (BC_STORE_FAST_BASE + FAST_NUM)))
				map_entry = sv2v_cast_7((7'd0 + 1) + 1);
			else if ((op >= BC_UNARY_BASE) && (op < (BC_UNARY_BASE + UNARY_NUM))) begin
				imm = op - BC_UNARY_BASE;
				if (imm == 8'd0)
					map_entry = sv2v_cast_7((7'd0 + 1) + 11);
				else if (imm == 8'd1)
					map_entry = sv2v_cast_7((7'd0 + 1) + 12);
				else if (imm == 8'd2)
					map_entry = sv2v_cast_7((7'd0 + 1) + 13);
				else
					map_entry = sv2v_cast_7((7'd0 + 1) + 14);
			end
			else if ((op >= BC_BINARY_BASE) && (op < (BC_BINARY_BASE + BINARY_NUM))) begin
				imm = op - BC_BINARY_BASE;
				if (imm <= 8'd5)
					map_entry = sv2v_cast_7((7'd0 + 1) + 7);
				else if (imm == 8'd6)
					map_entry = sv2v_cast_7((7'd0 + 1) + 8);
				else if (imm == 8'd7)
					map_entry = sv2v_cast_7((7'd0 + 1) + 9);
				else if (imm == 8'd8)
					map_entry = sv2v_cast_7((7'd0 + 1) + 10);
				else
					map_entry = sv2v_cast_7((7'd0 + 1) + 6);
			end
			else
				case (op)
					8'h10, 8'h23, 8'h50, 8'h51, 8'h52: map_entry = sv2v_cast_7((7'd0 + 1) + 4);
					8'h11: map_entry = sv2v_cast_7((7'd0 + 1) + 18);
					8'h12: map_entry = sv2v_cast_7((7'd0 + 1) + 19);
					8'h13, 8'h14: map_entry = sv2v_cast_7((7'd0 + 1) + 15);
					8'h15: map_entry = sv2v_cast_7((7'd0 + 1) + 16);
					8'h16: map_entry = sv2v_cast_7((7'd0 + 1) + 20);
					8'h17: map_entry = sv2v_cast_7((7'd0 + 1) + 21);
					8'h18: map_entry = sv2v_cast_7((7'd0 + 1) + 22);
					8'h19: map_entry = sv2v_cast_7((7'd0 + 1) + 23);
					8'h1a: map_entry = sv2v_cast_7((7'd0 + 1) + 24);
					8'h1b: map_entry = sv2v_cast_7((7'd0 + 1) + 70);
					8'h1c: map_entry = sv2v_cast_7((7'd0 + 1) + 71);
					8'h20: map_entry = sv2v_cast_7((7'd0 + 1) + 61);
					8'h21: map_entry = sv2v_cast_7((7'd0 + 1) + 62);
					8'h22: map_entry = sv2v_cast_7((7'd0 + 1) + 3);
					8'h24: map_entry = sv2v_cast_7(7'd0 + 1);
					8'h25: map_entry = sv2v_cast_7((7'd0 + 1) + 63);
					8'h26: map_entry = sv2v_cast_7((7'd0 + 1) + 1);
					8'h27: map_entry = sv2v_cast_7((7'd0 + 1) + 64);
					8'h28: map_entry = sv2v_cast_7((7'd0 + 1) + 2);
					8'h29: map_entry = sv2v_cast_7((7'd0 + 1) + 65);
					8'h2a: map_entry = sv2v_cast_7((7'd0 + 1) + 51);
					8'h2b: map_entry = sv2v_cast_7((7'd0 + 1) + 52);
					8'h2c: map_entry = sv2v_cast_7((7'd0 + 1) + 53);
					8'h2d: map_entry = sv2v_cast_7((7'd0 + 1) + 55);
					8'h2e: map_entry = sv2v_cast_7((7'd0 + 1) + 56);
					8'h2f:
						if (arg[1:0] == 2'd0)
							map_entry = sv2v_cast_7((7'd0 + 1) + 48);
						else if (arg[1:0] == 2'd1)
							map_entry = sv2v_cast_7((7'd0 + 1) + 49);
						else
							map_entry = sv2v_cast_7((7'd0 + 1) + 50);
					8'h30: map_entry = sv2v_cast_7((7'd0 + 1) + 57);
					8'h31: map_entry = sv2v_cast_7((7'd0 + 1) + 58);
					8'h32: map_entry = sv2v_cast_7((7'd0 + 1) + 59);
					8'h33: map_entry = sv2v_cast_7((7'd0 + 1) + 60);
					8'h34, 8'h36:
						if (arg[15:8] != 8'h00)
							map_entry = sv2v_cast_7((7'd0 + 1) + 67);
						else
							map_entry = sv2v_cast_7((7'd0 + 1) + 66);
					8'h35, 8'h37: map_entry = sv2v_cast_7((7'd0 + 1) + 68);
					8'h40: map_entry = sv2v_cast_7((7'd0 + 1) + 39);
					8'h42: map_entry = sv2v_cast_7((7'd0 + 1) + 30);
					8'h43: map_entry = sv2v_cast_7((7'd0 + 1) + 31);
					8'h44: map_entry = sv2v_cast_7((7'd0 + 1) + 32);
					8'h45: map_entry = sv2v_cast_7((7'd0 + 1) + 33);
					8'h46: map_entry = sv2v_cast_7((7'd0 + 1) + 34);
					8'h47: map_entry = sv2v_cast_7((7'd0 + 1) + 35);
					8'h48: map_entry = sv2v_cast_7((7'd0 + 1) + 36);
					8'h49: map_entry = sv2v_cast_7((7'd0 + 1) + 37);
					8'h4a: map_entry = sv2v_cast_7((7'd0 + 1) + 38);
					8'h4b: map_entry = sv2v_cast_7((7'd0 + 1) + 47);
					8'h53: map_entry = sv2v_cast_7((7'd0 + 1) + 5);
					8'h54: map_entry = sv2v_cast_7((7'd0 + 1) + 17);
					8'h55: map_entry = sv2v_cast_7((7'd0 + 1) + 25);
					8'h56: map_entry = sv2v_cast_7((7'd0 + 1) + 26);
					8'h57, 8'h58: map_entry = sv2v_cast_7((7'd0 + 1) + 27);
					8'h59: map_entry = sv2v_cast_7((7'd0 + 1) + 29);
					8'h5a, 8'h5b: map_entry = sv2v_cast_7((7'd0 + 1) + 28);
					8'h5c: map_entry = sv2v_cast_7((7'd0 + 1) + 40);
					8'h5d: map_entry = sv2v_cast_7((7'd0 + 1) + 41);
					8'h5e: map_entry = sv2v_cast_7((7'd0 + 1) + 45);
					8'h5f: map_entry = sv2v_cast_7((7'd0 + 1) + 46);
					8'h62: map_entry = sv2v_cast_7((7'd0 + 1) + 54);
					8'h63: map_entry = sv2v_cast_7((7'd0 + 1) + 69);
					8'h64: map_entry = sv2v_cast_7((7'd0 + 1) + 42);
					8'h65: map_entry = sv2v_cast_7((7'd0 + 1) + 43);
					8'h66: map_entry = sv2v_cast_7((7'd0 + 1) + 44);
					8'h67: map_entry = sv2v_cast_7((7'd0 + 1) + 73);
					8'h68: map_entry = sv2v_cast_7((7'd0 + 1) + 74);
					8'h69: map_entry = sv2v_cast_7((7'd0 + 1) + 72);
					default: begin
						known = 1'b0;
						map_entry = 7'd0;
					end
				endcase
		end
	endfunction
	reg [3:0] nwin;
	reg [7:0] op;
	reg [1:0] fmt;
	reg [3:0] len_b;
	reg signed [31:0] arg;
	reg arg_ok;
	reg extra_ok;
	reg [7:0] extra_b;
	reg trunc;
	reg overflow;
	reg known;
	reg [6:0] mapped;
	reg signed [63:0] acc;
	reg cont;
	reg [7:0] bv;
	reg [14:0] raw15;
	function automatic [63:0] sv2v_cast_64;
		input reg [63:0] inp;
		sv2v_cast_64 = inp;
	endfunction
	function automatic [3:0] sv2v_cast_4;
		input reg [3:0] inp;
		sv2v_cast_4 = inp;
	endfunction
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		nwin = (nbytes_i > 4'd8 ? 4'd8 : nbytes_i);
		op = bytes_i[7:0];
		fmt = bc_format(op[7:4]);
		len_b = 4'd1;
		arg = 32'sd0;
		arg_ok = 1'b0;
		extra_ok = 1'b0;
		extra_b = 8'h00;
		trunc = 1'b0;
		overflow = 1'b0;
		known = 1'b0;
		mapped = 7'd0;
		acc = 64'sd0;
		cont = 1'b0;
		bv = 8'h00;
		raw15 = 15'h0000;
		decoded_valid_o = 1'b0;
		illegal_o = 1'b0;
		truncated_o = 1'b0;
		arg_overflow_o = 1'b0;
		len_o = 4'd0;
		opcode_o = 8'h00;
		format_o = FMT_BYTE;
		entry_o = 7'd0;
		arg_valid_o = 1'b0;
		arg_o = 32'sd0;
		extra_valid_o = 1'b0;
		extra_o = 8'h00;
		if (instr_valid_i) begin
			opcode_o = op;
			format_o = fmt;
			if (nwin == 4'd0)
				trunc = 1'b1;
			else if ((fmt == FMT_QSTR) || (fmt == FMT_VARUINT)) begin
				if (nwin < 4'd2)
					trunc = 1'b1;
				else begin
					cont = 1'b1;
					begin : sv2v_autoblock_1
						reg [31:0] k;
						for (k = 0; k < 7; k = k + 1)
							if (cont && !trunc) begin
								if ((k + 1) >= {28'b0000000000000000000000000000, nwin}) begin
									trunc = 1'b1;
									cont = 1'b0;
								end
								else begin
									bv = bytes_i[8 * (k + 1)+:8];
									if (k == 0) begin
										acc = sv2v_cast_64(bv[6:0]);
										if ((op == BC_LOAD_CONST_SMALL_INT) && bv[6])
											acc[63:7] = {57 {1'b1}};
									end
									else
										acc = (acc << 7) | sv2v_cast_64(bv[6:0]);
									cont = bv[7];
									len_b = sv2v_cast_4(k + 2);
								end
							end
					end
					if (cont)
						trunc = 1'b1;
				end
				if (!trunc) begin
					arg_ok = 1'b1;
					arg = acc[31:0];
					if (op == BC_LOAD_CONST_SMALL_INT)
						overflow = acc[63:31] != {33 {acc[31]}};
					else
						overflow = acc[63:32] != 32'h00000000;
				end
			end
			else if (fmt == FMT_OFFSET) begin
				if (nwin < 4'd2)
					trunc = 1'b1;
				else begin
					bv = bytes_i[15:8];
					if (!bv[7]) begin
						len_b = 4'd2;
						arg_ok = 1'b1;
						if (offset_is_signed(op))
							arg = $signed({25'b0000000000000000000000000, bv[6:0]}) - 32'sd64;
						else
							arg = $signed({25'b0000000000000000000000000, bv[6:0]});
					end
					else if (nwin < 4'd3)
						trunc = 1'b1;
					else begin
						raw15 = {bytes_i[23:16], bv[6:0]};
						len_b = 4'd3;
						arg_ok = 1'b1;
						if (offset_is_signed(op))
							arg = $signed({17'b00000000000000000, raw15}) - 32'sd16384;
						else
							arg = $signed({17'b00000000000000000, raw15});
					end
				end
			end
			if (!trunc && ((op & EXTRA_MASK) == 8'h00)) begin
				if (len_b >= nwin)
					trunc = 1'b1;
				else begin
					extra_b = bytes_i[8 * len_b+:8];
					extra_ok = 1'b1;
					len_b = len_b + 4'd1;
				end
			end
			if (!trunc && (fmt == FMT_BYTE)) begin
				if ((op >= BC_SMALL_INT_BASE) && (op < (BC_SMALL_INT_BASE + SMALL_INT_NUM))) begin
					arg_ok = 1'b1;
					arg = ($signed({24'b000000000000000000000000, op}) - 32'sd112) - sv2v_cast_32(SMALL_INT_EXCESS);
				end
				else if ((op >= BC_LOAD_FAST_BASE) && (op < (BC_LOAD_FAST_BASE + FAST_NUM))) begin
					arg_ok = 1'b1;
					arg = $signed({24'b000000000000000000000000, op - BC_LOAD_FAST_BASE});
				end
				else if ((op >= BC_STORE_FAST_BASE) && (op < (BC_STORE_FAST_BASE + FAST_NUM))) begin
					arg_ok = 1'b1;
					arg = $signed({24'b000000000000000000000000, op - BC_STORE_FAST_BASE});
				end
				else if ((op >= BC_UNARY_BASE) && (op < (BC_UNARY_BASE + UNARY_NUM))) begin
					arg_ok = 1'b1;
					arg = $signed({24'b000000000000000000000000, op - BC_UNARY_BASE});
				end
				else if ((op >= BC_BINARY_BASE) && (op < (BC_BINARY_BASE + BINARY_NUM))) begin
					arg_ok = 1'b1;
					arg = $signed({24'b000000000000000000000000, op - BC_BINARY_BASE});
				end
			end
			if (trunc)
				truncated_o = 1'b1;
			else begin
				mapped = map_entry(op, arg, known);
				decoded_valid_o = 1'b1;
				illegal_o = !known;
				arg_overflow_o = overflow;
				len_o = len_b;
				entry_o = (known ? mapped : 7'd0);
				arg_valid_o = arg_ok;
				arg_o = (arg_ok ? arg : 32'sd0);
				extra_valid_o = extra_ok;
				extra_o = (extra_ok ? extra_b : 8'h00);
			end
		end
	end
	initial _sv2v_0 = 0;
endmodule
module mpy_prelude_decode (
	clk_i,
	rst_n_i,
	start_i,
	byte_valid_i,
	byte_i,
	ready_o,
	done_o,
	error_o,
	n_state_o,
	n_exc_stack_o,
	scope_flags_o,
	n_pos_args_o,
	n_kwonly_args_o,
	n_def_pos_args_o,
	n_info_o,
	n_cell_o,
	opcode_off_o,
	line_info_off_o,
	line_info_end_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_n_i;
	input wire start_i;
	input wire byte_valid_i;
	input wire [7:0] byte_i;
	output wire ready_o;
	output wire done_o;
	output wire error_o;
	output wire [15:0] n_state_o;
	output wire [15:0] n_exc_stack_o;
	output wire [15:0] scope_flags_o;
	output wire [15:0] n_pos_args_o;
	output wire [15:0] n_kwonly_args_o;
	output wire [15:0] n_def_pos_args_o;
	output wire [15:0] n_info_o;
	output wire [15:0] n_cell_o;
	output wire [15:0] opcode_off_o;
	output wire [15:0] line_info_off_o;
	output wire [15:0] line_info_end_o;
	reg [2:0] state_q;
	reg [31:0] idx_q;
	reg [31:0] s_q;
	reg [31:0] e_q;
	reg [31:0] f_q;
	reg [31:0] a_q;
	reg [31:0] k_q;
	reg [31:0] d_q;
	reg [31:0] i_q;
	reg [31:0] c_q;
	reg sig_more_q;
	reg [3:0] sig_n_q;
	reg [3:0] size_n_q;
	reg [31:0] names_left_q;
	reg [31:0] source_end_q;
	reg [31:0] op_at_q;
	reg [31:0] line_off_q;
	reg [31:0] line_end_q;
	reg fields_ok_q;
	reg [2:0] st;
	reg [31:0] idx;
	reg [31:0] s;
	reg [31:0] e;
	reg [31:0] f;
	reg [31:0] a;
	reg [31:0] k;
	reg [31:0] d;
	reg [31:0] info;
	reg [31:0] cells;
	reg sig_more;
	reg [3:0] sig_n;
	reg [3:0] size_n;
	reg [31:0] names_left;
	reg [31:0] source_end;
	reg [31:0] op_at;
	reg [31:0] line_off;
	reg [31:0] line_end;
	reg fields_ok;
	reg dn;
	reg err;
	reg take;
	reg active;
	reg [31:0] z32;
	assign ready_o = (state_q != 3'd5) && (state_q != 3'd6);
	assign done_o = state_q == 3'd5;
	assign error_o = state_q == 3'd6;
	assign n_state_o = (fields_ok_q ? s_q[15:0] : 16'h0000);
	assign n_exc_stack_o = (fields_ok_q ? e_q[15:0] : 16'h0000);
	assign scope_flags_o = (fields_ok_q ? f_q[15:0] : 16'h0000);
	assign n_pos_args_o = (fields_ok_q ? a_q[15:0] : 16'h0000);
	assign n_kwonly_args_o = (fields_ok_q ? k_q[15:0] : 16'h0000);
	assign n_def_pos_args_o = (fields_ok_q ? d_q[15:0] : 16'h0000);
	assign n_info_o = (fields_ok_q ? i_q[15:0] : 16'h0000);
	assign n_cell_o = (fields_ok_q ? c_q[15:0] : 16'h0000);
	assign opcode_off_o = (fields_ok_q ? op_at_q[15:0] : 16'h0000);
	assign line_info_off_o = (fields_ok_q ? line_off_q[15:0] : 16'h0000);
	assign line_info_end_o = (fields_ok_q ? line_end_q[15:0] : 16'h0000);
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		st = state_q;
		idx = idx_q;
		s = s_q;
		e = e_q;
		f = f_q;
		a = a_q;
		k = k_q;
		d = d_q;
		info = i_q;
		cells = c_q;
		sig_more = sig_more_q;
		sig_n = sig_n_q;
		size_n = size_n_q;
		names_left = names_left_q;
		source_end = source_end_q;
		op_at = op_at_q;
		line_off = line_off_q;
		line_end = line_end_q;
		fields_ok = fields_ok_q;
		dn = state_q == 3'd5;
		err = state_q == 3'd6;
		z32 = {24'b000000000000000000000000, byte_i};
		active = (((state_q == 3'd1) || (state_q == 3'd2)) || (state_q == 3'd3)) || (state_q == 3'd4);
		if (start_i) begin
			st = 3'd1;
			idx = 32'h00000000;
			s = 32'h00000000;
			e = 32'h00000000;
			f = 32'h00000000;
			a = 32'h00000000;
			k = 32'h00000000;
			d = 32'h00000000;
			info = 32'h00000000;
			cells = 32'h00000000;
			sig_more = 1'b0;
			sig_n = 4'h0;
			size_n = 4'h0;
			names_left = 32'h00000000;
			source_end = 32'h00000000;
			op_at = 32'h00000000;
			line_off = 32'h00000000;
			line_end = 32'h00000000;
			fields_ok = 1'b0;
			dn = 1'b0;
			err = 1'b0;
		end
		take = ((byte_valid_i && !dn) && !err) && (start_i || active);
		if (take) begin
			if (idx == 32'h0000ffff)
				err = 1'b1;
			else begin
				idx = idx + 32'h00000001;
				case (st)
					3'd1: begin
						if (!sig_more) begin
							s = (z32 >> 3) & 32'h0000000f;
							e = (z32 >> 2) & 32'h00000001;
							f = 32'h00000000;
							a = z32 & 32'h00000003;
							k = 32'h00000000;
							d = 32'h00000000;
							if (byte_i[7]) begin
								sig_more = 1'b1;
								sig_n = 4'h0;
							end
							else begin
								s = s + 32'h00000001;
								st = 3'd2;
								info = 32'h00000000;
								cells = 32'h00000000;
								size_n = 4'h0;
							end
						end
						else begin
							s = s | ((z32 & 32'h00000030) << (sv2v_cast_32(sig_n) * 32'd2));
							e = e | ((z32 & 32'h00000002) << sv2v_cast_32(sig_n));
							f = f | (((z32 & 32'h00000040) >> 6) << sv2v_cast_32(sig_n));
							a = a | ((z32 & 32'h00000004) << sv2v_cast_32(sig_n));
							k = k | (((z32 & 32'h00000008) >> 3) << sv2v_cast_32(sig_n));
							d = d | ((z32 & 32'h00000001) << sv2v_cast_32(sig_n));
							if (byte_i[7]) begin
								if (sig_n == 4'hf)
									err = 1'b1;
								else
									sig_n = sig_n + 4'h1;
							end
							else begin
								s = s + 32'h00000001;
								st = 3'd2;
								info = 32'h00000000;
								cells = 32'h00000000;
								size_n = 4'h0;
							end
						end
						if ((!err && (st == 3'd2)) && (s > 32'h0000ffff))
							err = 1'b1;
					end
					3'd2: begin
						cells = cells | ((z32 & 32'h00000001) << sv2v_cast_32(size_n));
						info = info | (((z32 & 32'h0000007e) >> 1) << (sv2v_cast_32(size_n) * 32'd6));
						if (byte_i[7]) begin
							if (size_n >= 4'd5)
								err = 1'b1;
							else
								size_n = size_n + 4'h1;
						end
						else if ((info > 32'h0000ffff) || (cells > 32'h0000ffff))
							err = 1'b1;
						else begin
							source_end = idx + info;
							op_at = source_end + cells;
							names_left = (32'h00000001 + a) + k;
							if (info == 32'h00000000)
								err = 1'b1;
							else
								st = 3'd3;
						end
					end
					3'd3:
						if (idx > source_end)
							err = 1'b1;
						else if (!byte_i[7]) begin
							names_left = names_left - 32'h00000001;
							if (names_left == 32'h00000000) begin
								line_off = idx;
								line_end = source_end;
								if (line_off > line_end)
									err = 1'b1;
								else if (idx == op_at) begin
									fields_ok = 1'b1;
									dn = 1'b1;
									st = 3'd5;
								end
								else if (idx > op_at)
									err = 1'b1;
								else begin
									fields_ok = 1'b1;
									st = 3'd4;
								end
							end
						end
					3'd4:
						if (idx == op_at) begin
							fields_ok = 1'b1;
							dn = 1'b1;
							st = 3'd5;
						end
						else if (idx > op_at)
							err = 1'b1;
					default: err = 1'b1;
				endcase
			end
			if (err) begin
				st = 3'd6;
				dn = 1'b0;
				fields_ok = 1'b0;
			end
			else if (dn) begin
				st = 3'd5;
				if (((((((((((s > 32'h0000ffff) || (e > 32'h0000ffff)) || (f > 32'h0000ffff)) || (a > 32'h0000ffff)) || (k > 32'h0000ffff)) || (d > 32'h0000ffff)) || (info > 32'h0000ffff)) || (cells > 32'h0000ffff)) || (op_at > 32'h0000ffff)) || (line_off > 32'h0000ffff)) || (line_end > 32'h0000ffff)) begin
					st = 3'd6;
					dn = 1'b0;
					fields_ok = 1'b0;
				end
			end
		end
	end
	always @(posedge clk_i)
		if (!rst_n_i) begin
			state_q <= 3'd0;
			idx_q <= 32'h00000000;
			s_q <= 32'h00000000;
			e_q <= 32'h00000000;
			f_q <= 32'h00000000;
			a_q <= 32'h00000000;
			k_q <= 32'h00000000;
			d_q <= 32'h00000000;
			i_q <= 32'h00000000;
			c_q <= 32'h00000000;
			sig_more_q <= 1'b0;
			sig_n_q <= 4'h0;
			size_n_q <= 4'h0;
			names_left_q <= 32'h00000000;
			source_end_q <= 32'h00000000;
			op_at_q <= 32'h00000000;
			line_off_q <= 32'h00000000;
			line_end_q <= 32'h00000000;
			fields_ok_q <= 1'b0;
		end
		else begin
			state_q <= st;
			idx_q <= idx;
			s_q <= s;
			e_q <= e;
			f_q <= f;
			a_q <= a;
			k_q <= k;
			d_q <= d;
			i_q <= info;
			c_q <= cells;
			sig_more_q <= sig_more;
			sig_n_q <= sig_n;
			size_n_q <= size_n;
			names_left_q <= names_left;
			source_end_q <= source_end;
			op_at_q <= op_at;
			line_off_q <= line_off;
			line_end_q <= line_end;
			fields_ok_q <= fields_ok;
		end
	initial _sv2v_0 = 0;
endmodule
module mpy_fetch (
	clk_i,
	rst_n_i,
	pc_i,
	flush_i,
	req_o,
	addr_o,
	gnt_i,
	ack_i,
	rdata_i,
	fault_i,
	fault_reason_i,
	win_o,
	base_o,
	avail_o,
	fault_o,
	fault_addr_o,
	fault_reason_o
);
	reg _sv2v_0;
	parameter signed [31:0] QD = 3;
	input wire clk_i;
	input wire rst_n_i;
	input wire [31:0] pc_i;
	input wire flush_i;
	output wire req_o;
	output wire [31:0] addr_o;
	input wire gnt_i;
	input wire ack_i;
	input wire [31:0] rdata_i;
	input wire fault_i;
	input wire [3:0] fault_reason_i;
	output wire [(32 * QD) - 1:0] win_o;
	output wire [31:0] base_o;
	output reg [5:0] avail_o;
	output wire fault_o;
	output wire [31:0] fault_addr_o;
	output wire [3:0] fault_reason_o;
	localparam signed [31:0] NW = $clog2(QD + 1);
	localparam signed [31:0] IW = (QD > 1 ? $clog2(QD) : 1);
	reg [31:0] q_w [0:QD - 1];
	reg q_f [0:QD - 1];
	reg [3:0] q_r [0:QD - 1];
	reg [31:0] qb;
	reg [NW - 1:0] qn;
	reg [2:0] nfl;
	reg [2:0] ndrop;
	reg stop;
	reg [NW - 1:0] vn;
	function automatic signed [NW - 1:0] sv2v_cast_BFA7E_signed;
		input reg signed [NW - 1:0] inp;
		sv2v_cast_BFA7E_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		vn = qn;
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = QD - 1; i >= 0; i = i - 1)
				if ((sv2v_cast_BFA7E_signed(i) < qn) && q_f[i])
					vn = sv2v_cast_BFA7E_signed(i);
		end
	end
	wire [29:0] pw;
	wire [29:0] bw;
	wire [29:0] dw;
	assign pw = pc_i[31:2];
	assign bw = qb[31:2];
	assign dw = pw - bw;
	wire redirect;
	wire pop;
	function automatic [29:0] sv2v_cast_30;
		input reg [29:0] inp;
		sv2v_cast_30 = inp;
	endfunction
	assign redirect = (flush_i || (pw < bw)) || (dw > (sv2v_cast_30(qn) + sv2v_cast_30(nfl)));
	assign pop = (!redirect && (qn != {NW {1'sb0}})) && (dw != {30 {1'sb0}});
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	assign req_o = !stop && ((sv2v_cast_32(qn) + sv2v_cast_32(nfl)) < QD);
	assign addr_o = qb + {sv2v_cast_30(qn) + sv2v_cast_30(nfl), 2'b00};
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < QD; _gv_i_1 = _gv_i_1 + 1) begin : g_win
			localparam i = _gv_i_1;
			assign win_o[32 * i+:32] = q_w[i];
		end
	endgenerate
	assign base_o = qb;
	wire [31:0] off;
	assign off = pc_i - qb;
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		if (!redirect && (dw < sv2v_cast_30(vn)))
			avail_o = sv2v_cast_6(sv2v_cast_32(4 * vn) - off);
		else
			avail_o = 1'sb0;
	end
	assign fault_o = vn != qn;
	assign fault_addr_o = qb + {sv2v_cast_30(vn), 2'b00};
	function automatic [IW - 1:0] sv2v_cast_83959;
		input reg [IW - 1:0] inp;
		sv2v_cast_83959 = inp;
	endfunction
	assign fault_reason_o = q_r[sv2v_cast_83959(vn)];
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			begin : sv2v_autoblock_2
				reg signed [31:0] i;
				for (i = 0; i < QD; i = i + 1)
					begin
						q_w[i] <= 1'sb0;
						q_f[i] <= 1'b0;
						q_r[i] <= 1'sb0;
					end
			end
			qb <= 1'sb0;
			qn <= 1'sb0;
			nfl <= 1'sb0;
			ndrop <= 1'sb0;
			stop <= 1'b0;
		end
		else if (redirect) begin
			ndrop <= ((ndrop + nfl) + (gnt_i ? 3'd1 : 3'd0)) - (ack_i ? 3'd1 : 3'd0);
			nfl <= 1'sb0;
			qn <= 1'sb0;
			qb <= {pc_i[31:2], 2'b00};
			stop <= 1'b0;
		end
		else begin : sv2v_autoblock_3
			reg keep;
			reg [NW - 1:0] n;
			keep = ack_i && (ndrop == {3 {1'sb0}});
			if (ack_i && (ndrop != {3 {1'sb0}}))
				ndrop <= ndrop - 3'd1;
			nfl <= (nfl + (gnt_i ? 3'd1 : 3'd0)) - (keep ? 3'd1 : 3'd0);
			n = qn;
			if (pop) begin
				qb <= qb + 32'd4;
				n = qn - 1'b1;
			end
			begin : sv2v_autoblock_4
				reg signed [31:0] i;
				for (i = 0; i < QD; i = i + 1)
					if (keep && (n == sv2v_cast_BFA7E_signed(i))) begin
						q_w[i] <= rdata_i;
						q_f[i] <= fault_i;
						q_r[i] <= fault_reason_i;
					end
					else if (pop && (i < (QD - 1))) begin
						q_w[i] <= q_w[i + 1];
						q_f[i] <= q_f[i + 1];
						q_r[i] <= q_r[i + 1];
					end
			end
			if (keep) begin
				if (fault_i)
					stop <= 1'b1;
				n = n + 1'b1;
			end
			qn <= n;
		end
	initial _sv2v_0 = 0;
endmodule
module mpy_core (
	clk_i,
	rst_n_i,
	m_req_o,
	m_we_o,
	m_tag_we_o,
	m_be_o,
	m_addr_o,
	m_wdata_o,
	m_wtag_o,
	m_busy_i,
	m_ack_i,
	m_rdata_i,
	m_rtag_i,
	m_fault_i,
	m_fault_reason_i,
	f_req_o,
	f_addr_o,
	f_gnt_i,
	f_ack_i,
	f_rdata_i,
	f_fault_i,
	f_fault_reason_i,
	gc_alloc_req_o,
	gc_alloc_nbytes_o,
	gc_alloc_done_i,
	gc_alloc_ok_i,
	gc_alloc_addr_i,
	gc_collect_req_o,
	gc_root0_lo_o,
	gc_root0_hi_o,
	gc_root1_lo_o,
	gc_root1_hi_o,
	gc_collect_done_i,
	gc_free_i,
	gc_total_i,
	gc_collections_i,
	sl_valid_o,
	sl_ready_i,
	sl_src_o,
	sl_dst_o,
	sl_n_o,
	sl_reverse_o,
	sl_clear_o,
	sl_put_o,
	sl_length_o,
	sl_clear_addr_o,
	sl_put_addr_o,
	sl_header_o,
	sl_new_length_o,
	sl_put_value_o,
	sl_response_i,
	sl_response_ready_o,
	mb_valid_o,
	mb_ready_i,
	mb_return_i,
	mb_ok_i,
	mb_used_i,
	mb_op_o,
	mb_set_o,
	mb_src_o,
	mb_sn_o,
	mb_dst_o,
	mb_dn_o,
	mb_used_o,
	mb_header_o,
	mb_source_header_o,
	mb_hashes_o,
	mb_qcount_o,
	mb_qbase_o,
	mb_qext_o,
	ca_valid_o,
	ca_ready_i,
	ca_dst_o,
	ca_byte_o,
	ca_reverse_o,
	ca_src_o,
	ca_n_o,
	ca_idle_i,
	ca_fault_i,
	ca_fault_reason_i,
	ca_fault_addr_i,
	evt_pend_i,
	halted_o,
	halt_code_o,
	halt_value_o,
	cycles_o,
	ops_o,
	trace_o,
	trace_pc_o,
	trace_op_o,
	trace_sp_o
);
	reg _sv2v_0;
	parameter signed [31:0] RSTK_DEPTH = 16;
	parameter signed [31:0] GROW_CHUNK = 8;
	parameter signed [31:0] GROW_ADAPT = 1;
	parameter signed [31:0] LC_N = 8;
	parameter signed [31:0] LC_WB = 1;
	parameter signed [31:0] CA_EN = 1;
	parameter signed [31:0] SHORTLIST_MAX = 16;
	parameter signed [31:0] SHORTLIST_MODE = 2;
	parameter signed [31:0] AALU = 1;
	input wire clk_i;
	input wire rst_n_i;
	output wire m_req_o;
	output wire m_we_o;
	output wire m_tag_we_o;
	output wire [3:0] m_be_o;
	output wire [31:0] m_addr_o;
	output wire [31:0] m_wdata_o;
	output wire [3:0] m_wtag_o;
	input wire m_busy_i;
	input wire m_ack_i;
	input wire [31:0] m_rdata_i;
	input wire [3:0] m_rtag_i;
	input wire m_fault_i;
	input wire [3:0] m_fault_reason_i;
	output wire f_req_o;
	output wire [31:0] f_addr_o;
	input wire f_gnt_i;
	input wire f_ack_i;
	input wire [31:0] f_rdata_i;
	input wire f_fault_i;
	input wire [3:0] f_fault_reason_i;
	output wire gc_alloc_req_o;
	output wire [31:0] gc_alloc_nbytes_o;
	input wire gc_alloc_done_i;
	input wire gc_alloc_ok_i;
	input wire [31:0] gc_alloc_addr_i;
	output wire gc_collect_req_o;
	output wire [31:0] gc_root0_lo_o;
	output wire [31:0] gc_root0_hi_o;
	output wire [31:0] gc_root1_lo_o;
	output wire [31:0] gc_root1_hi_o;
	input wire gc_collect_done_i;
	input wire [31:0] gc_free_i;
	input wire [31:0] gc_total_i;
	input wire [31:0] gc_collections_i;
	output wire sl_valid_o;
	input wire sl_ready_i;
	output wire [31:0] sl_src_o;
	output wire [31:0] sl_dst_o;
	output wire [31:0] sl_n_o;
	output wire sl_reverse_o;
	output wire sl_clear_o;
	output wire sl_put_o;
	output wire sl_length_o;
	output wire [31:0] sl_clear_addr_o;
	output wire [31:0] sl_put_addr_o;
	output wire [31:0] sl_header_o;
	output wire [31:0] sl_new_length_o;
	output wire [35:0] sl_put_value_o;
	input wire sl_response_i;
	output wire sl_response_ready_o;
	output reg mb_valid_o;
	input wire mb_ready_i;
	input wire mb_return_i;
	input wire mb_ok_i;
	input wire [31:0] mb_used_i;
	output reg [2:0] mb_op_o;
	output reg mb_set_o;
	output reg [31:0] mb_src_o;
	output reg [31:0] mb_sn_o;
	output reg [31:0] mb_dst_o;
	output reg [31:0] mb_dn_o;
	output reg [31:0] mb_used_o;
	output reg [31:0] mb_header_o;
	output reg [31:0] mb_source_header_o;
	output reg [31:0] mb_hashes_o;
	output wire [31:0] mb_qcount_o;
	output wire [31:0] mb_qbase_o;
	output wire [31:0] mb_qext_o;
	output wire ca_valid_o;
	input wire ca_ready_i;
	output wire [31:0] ca_dst_o;
	output reg ca_byte_o;
	output reg ca_reverse_o;
	output wire [31:0] ca_src_o;
	output wire [31:0] ca_n_o;
	input wire ca_idle_i;
	input wire ca_fault_i;
	input wire [3:0] ca_fault_reason_i;
	input wire [31:0] ca_fault_addr_i;
	input wire evt_pend_i;
	output wire halted_o;
	output wire [3:0] halt_code_o;
	output wire [31:0] halt_value_o;
	output wire [31:0] cycles_o;
	output wire [31:0] ops_o;
	output wire trace_o;
	output wire [31:0] trace_pc_o;
	output wire [7:0] trace_op_o;
	output wire [6:0] trace_sp_o;
	localparam [31:0] ABI_CTL_NULL = 32'd0;
	localparam [3:0] ABI_TAG_CONTROL = 4'd0;
	localparam [35:0] VNULL = {ABI_TAG_CONTROL, ABI_CTL_NULL};
	localparam [31:0] ABI_CTL_NONE = 32'd1;
	localparam [35:0] VNONE = {ABI_TAG_CONTROL, ABI_CTL_NONE};
	localparam [31:0] ABI_CTL_STOP = 32'd2;
	localparam [35:0] VSTOP = {ABI_TAG_CONTROL, ABI_CTL_STOP};
	localparam [31:0] ABI_CTL_TOMB = 32'd3;
	localparam [35:0] VTOMB = {ABI_TAG_CONTROL, ABI_CTL_TOMB};
	localparam [31:0] ABI_CTL_FALSE = 32'd4;
	localparam [35:0] VFALSE = {ABI_TAG_CONTROL, ABI_CTL_FALSE};
	localparam [31:0] ABI_CTL_TRUE = 32'd5;
	localparam [35:0] VTRUE = {ABI_TAG_CONTROL, ABI_CTL_TRUE};
	localparam [31:0] ABI_TYPE_TABLE = 32'h00000040;
	localparam [31:0] TT = ABI_TYPE_TABLE;
	localparam [7:0] ABI_SR_EMERG = 8'd16;
	localparam [31:0] ABI_SYSROOT_BASE = 32'h20008080;
	localparam [31:0] EMERG_ADDR = ABI_SYSROOT_BASE + (4 * ABI_SR_EMERG);
	localparam [31:0] HASH_NONE = 32'd6;
	localparam [7:0] FF_FW = 8'h01;
	localparam [7:0] FF_GEN = 8'h02;
	localparam [7:0] FF_YFAST = 8'h04;
	localparam [7:0] FF_NOTB = 8'h80;
	localparam [31:0] LS_CA_MIN = 32'd16;
	localparam [1:0] LK_FIND = 2'd0;
	localparam [1:0] LK_ADD = 2'd1;
	localparam [1:0] LK_REMOVE = 2'd2;
	function automatic [3:0] tg;
		input reg [35:0] v;
		tg = v[35:32];
	endfunction
	function automatic [31:0] adr;
		input reg [35:0] v;
		adr = {v[31:2], 2'b00};
	endfunction
	function automatic [31:0] aoff;
		input reg [31:0] b;
		input reg [5:0] k;
		reg [6:0] lo;
		reg [25:0] run;
		begin
			lo = {1'b0, b[5:0]} + {1'b0, k};
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < 26; i = i + 1)
					run[i] = &(b[31:6] | ~((26'd1 << i) - 26'd1));
			end
			aoff = {(lo[6] ? b[31:6] ^ run : b[31:6]), lo[5:0]};
		end
	endfunction
	localparam [3:0] ABI_TAG_INT = 4'd1;
	function automatic [35:0] vint;
		input reg [31:0] x;
		vint = {ABI_TAG_INT, x};
	endfunction
	localparam [3:0] ABI_TAG_OBJECT = 4'd14;
	function automatic [35:0] vobj;
		input reg [31:0] x;
		vobj = {ABI_TAG_OBJECT, x};
	endfunction
	function automatic [35:0] vbool;
		input reg b;
		vbool = (b ? VTRUE : VFALSE);
	endfunction
	localparam [3:0] ABI_TAG_MUT = 4'd10;
	function automatic [35:0] vmut;
		input reg [31:0] a;
		input reg [1:0] k;
		vmut = {ABI_TAG_MUT, a[31:2], k};
	endfunction
	function automatic is_bool;
		input reg [35:0] v;
		is_bool = (v == VTRUE) || (v == VFALSE);
	endfunction
	function automatic intlike;
		input reg [35:0] v;
		intlike = (tg(v) == ABI_TAG_INT) || is_bool(v);
	endfunction
	localparam [3:0] ABI_TAG_FLOAT = 4'd3;
	localparam [3:0] ABI_TAG_INT64 = 4'd2;
	function automatic numlike;
		input reg [35:0] v;
		numlike = (intlike(v) || (tg(v) == ABI_TAG_INT64)) || (tg(v) == ABI_TAG_FLOAT);
	endfunction
	function automatic [31:0] ival;
		input reg [35:0] v;
		ival = (is_bool(v) ? {31'd0, v == VTRUE} : v[31:0]);
	endfunction
	function automatic [63:0] sx64;
		input reg [31:0] x;
		sx64 = {{32 {x[31]}}, x};
	endfunction
	localparam [3:0] ABI_TAG_QSTR = 4'd6;
	localparam [3:0] ABI_TAG_STR = 4'd8;
	function automatic strlike;
		input reg [35:0] v;
		strlike = (tg(v) == ABI_TAG_QSTR) || (tg(v) == ABI_TAG_STR);
	endfunction
	function automatic is_mut;
		input reg [35:0] v;
		input reg [1:0] k;
		is_mut = (tg(v) == ABI_TAG_MUT) && (v[1:0] == k);
	endfunction
	function automatic [31:0] sx31;
		input reg [31:0] x;
		sx31 = {x[30], x[30:0]};
	endfunction
	function automatic fits31;
		input reg [63:0] x;
		fits31 = (x[63:30] == {34 {1'b0}}) || (x[63:30] == {34 {1'b1}});
	endfunction
	function automatic fits32;
		input reg [63:0] x;
		fits32 = (x[63:31] == {33 {1'b0}}) || (x[63:31] == {33 {1'b1}});
	endfunction
	function automatic [31:0] padr;
		input reg [35:0] v;
		padr = (tg(v) == ABI_TAG_INT ? v[31:0] : adr(v));
	endfunction
	function automatic [7:0] byte_of;
		input reg [31:0] w;
		input reg [1:0] i;
		byte_of = w[8 * i+:8];
	endfunction
	function automatic [31:0] next_alloc;
		input reg [31:0] x;
		reg [1087:0] t;
		reg [33:0] ge;
		reg [33:0] first;
		reg [31:0] r;
		begin
			t = 1088'h20000000400000006000000080000000a0000000c00000011000000170000001d000000250000002f0000003b00000049000000610000007f000000a7000000df000001250000018500000209000002b300000397000004c70000065b0000087100000c9d000012df00001c4b00002a6d00003f9100005f5700008eff0000d67b;
			begin : sv2v_autoblock_2
				reg signed [31:0] i;
				for (i = 0; i < 34; i = i + 1)
					ge[i] = t[(33 - i) * 32+:32] >= x;
			end
			first = ge & ~{ge[32:0], 1'b0};
			r = (ge[33] ? 32'd0 : (x + (x >> 1)) | 32'd1);
			begin : sv2v_autoblock_3
				reg signed [31:0] i;
				for (i = 0; i < 34; i = i + 1)
					if (first[i])
						r = r | t[(33 - i) * 32+:32];
			end
			next_alloc = r;
		end
	endfunction
	localparam [7:0] ABI_MSGT_ASSERT = 8'd42;
	localparam [7:0] ABI_MSGT_BYTES_INDEX = 8'd48;
	localparam [7:0] ABI_MSGT_DIV_ZERO = 8'd63;
	localparam [7:0] ABI_MSGT_EMPTY = 8'd40;
	localparam [7:0] ABI_MSGT_GEN_IGNORED = 8'd57;
	localparam [7:0] ABI_MSGT_GEN_RUNNING = 8'd62;
	localparam [7:0] ABI_MSGT_GEN_SEND = 8'd61;
	localparam [7:0] ABI_MSGT_GEN_STOP = 8'd57;
	localparam [7:0] ABI_MSGT_HEAP_LOCKED = 8'd52;
	localparam [7:0] ABI_MSGT_KBD = 8'd50;
	localparam [7:0] ABI_MSGT_LIST_INDEX = 8'd48;
	localparam [7:0] ABI_MSGT_LOCAL_UNBOUND = 8'd53;
	localparam [7:0] ABI_MSGT_MEMORY = 8'd52;
	localparam [7:0] ABI_MSGT_NEG_SHIFT = 8'd62;
	localparam [7:0] ABI_MSGT_NO_ACTIVE_EXC = 8'd57;
	localparam [7:0] ABI_MSGT_OVERFLOW = 8'd56;
	localparam [7:0] ABI_MSGT_POP_EMPTY = 8'd48;
	localparam [7:0] ABI_MSGT_RANGE_INDEX = 8'd48;
	localparam [7:0] ABI_MSGT_RECURSION = 8'd57;
	localparam [7:0] ABI_MSGT_SCHED_FULL = 8'd57;
	localparam [7:0] ABI_MSGT_STOP_ITER = 8'd58;
	localparam [7:0] ABI_MSGT_STR_INDEX = 8'd48;
	localparam [7:0] ABI_MSGT_TUPLE_INDEX = 8'd48;
	localparam [7:0] ABI_MSGT_ZERO_STEP = 8'd62;
	localparam [7:0] ABI_MSG_ASSERT = 8'd17;
	localparam [7:0] ABI_MSG_BYTES_INDEX = 8'd18;
	localparam [7:0] ABI_MSG_DIV_ZERO = 8'd2;
	localparam [7:0] ABI_MSG_GEN_IGNORED = 8'd14;
	localparam [7:0] ABI_MSG_GEN_RUNNING = 8'd13;
	localparam [7:0] ABI_MSG_GEN_SEND = 8'd12;
	localparam [7:0] ABI_MSG_GEN_STOP = 8'd15;
	localparam [7:0] ABI_MSG_HEAP_LOCKED = 8'd21;
	localparam [7:0] ABI_MSG_KBD = 8'd23;
	localparam [7:0] ABI_MSG_LIST_INDEX = 8'd4;
	localparam [7:0] ABI_MSG_LOCAL_UNBOUND = 8'd7;
	localparam [7:0] ABI_MSG_MEMORY = 8'd16;
	localparam [7:0] ABI_MSG_NEG_SHIFT = 8'd8;
	localparam [7:0] ABI_MSG_NO_ACTIVE_EXC = 8'd9;
	localparam [7:0] ABI_MSG_OVERFLOW = 8'd3;
	localparam [7:0] ABI_MSG_POP_EMPTY = 8'd20;
	localparam [7:0] ABI_MSG_RANGE_INDEX = 8'd19;
	localparam [7:0] ABI_MSG_RECURSION = 8'd1;
	localparam [7:0] ABI_MSG_SCHED_FULL = 8'd22;
	localparam [7:0] ABI_MSG_STOP_ITER = 8'd11;
	localparam [7:0] ABI_MSG_STR_INDEX = 8'd6;
	localparam [7:0] ABI_MSG_TUPLE_INDEX = 8'd5;
	localparam [7:0] ABI_MSG_ZERO_STEP = 8'd10;
	function automatic [7:0] msg_type;
		input reg [7:0] id;
		case (id)
			ABI_MSG_RECURSION: msg_type = ABI_MSGT_RECURSION;
			ABI_MSG_DIV_ZERO: msg_type = ABI_MSGT_DIV_ZERO;
			ABI_MSG_OVERFLOW: msg_type = ABI_MSGT_OVERFLOW;
			ABI_MSG_LIST_INDEX: msg_type = ABI_MSGT_LIST_INDEX;
			ABI_MSG_TUPLE_INDEX: msg_type = ABI_MSGT_TUPLE_INDEX;
			ABI_MSG_STR_INDEX: msg_type = ABI_MSGT_STR_INDEX;
			ABI_MSG_LOCAL_UNBOUND: msg_type = ABI_MSGT_LOCAL_UNBOUND;
			ABI_MSG_NEG_SHIFT: msg_type = ABI_MSGT_NEG_SHIFT;
			ABI_MSG_NO_ACTIVE_EXC: msg_type = ABI_MSGT_NO_ACTIVE_EXC;
			ABI_MSG_ZERO_STEP: msg_type = ABI_MSGT_ZERO_STEP;
			ABI_MSG_STOP_ITER: msg_type = ABI_MSGT_STOP_ITER;
			ABI_MSG_MEMORY: msg_type = ABI_MSGT_MEMORY;
			ABI_MSG_ASSERT: msg_type = ABI_MSGT_ASSERT;
			ABI_MSG_BYTES_INDEX: msg_type = ABI_MSGT_BYTES_INDEX;
			ABI_MSG_RANGE_INDEX: msg_type = ABI_MSGT_RANGE_INDEX;
			ABI_MSG_POP_EMPTY: msg_type = ABI_MSGT_POP_EMPTY;
			ABI_MSG_HEAP_LOCKED: msg_type = ABI_MSGT_HEAP_LOCKED;
			ABI_MSG_SCHED_FULL: msg_type = ABI_MSGT_SCHED_FULL;
			ABI_MSG_KBD: msg_type = ABI_MSGT_KBD;
			ABI_MSG_GEN_SEND: msg_type = ABI_MSGT_GEN_SEND;
			ABI_MSG_GEN_RUNNING: msg_type = ABI_MSGT_GEN_RUNNING;
			ABI_MSG_GEN_IGNORED: msg_type = ABI_MSGT_GEN_IGNORED;
			ABI_MSG_GEN_STOP: msg_type = ABI_MSGT_GEN_STOP;
			default: msg_type = ABI_MSGT_EMPTY;
		endcase
	endfunction
	reg [9:0] st;
	reg [9:0] wret;
	reg [9:0] rstk [0:RSTK_DEPTH - 1];
	reg [4:0] rsp;
	reg m_req;
	reg m_we;
	reg m_tag_we;
	localparam signed [31:0] WQ = 4;
	wire m_wait;
	assign m_wait = m_req && m_busy_i;
	reg [2:0] wpend;
	reg [31:0] wfifo [0:3];
	reg [1:0] wf_w;
	reg [1:0] wf_r;
	reg wfault_p;
	reg [7:0] bl_n;
	reg [2:0] bl_k;
	reg [3:0] wfault_code;
	reg [31:0] wfault_addr;
	reg [3:0] m_be;
	reg [3:0] m_wtag;
	reg [31:0] m_addr;
	reg [31:0] m_wdata;
	reg [31:0] md;
	reg [3:0] mt;
	wire [1:0] cfg_sl;
	reg ss_store;
	reg ss_native;
	reg ss_reverse;
	reg ss_omitted;
	reg [31:0] ss_len;
	reg [31:0] ss_start;
	reg [31:0] ss_stop;
	reg [31:0] ss_bound;
	reg [31:0] ss_count;
	reg [31:0] ss_src;
	reg [31:0] ss_dst;
	reg [31:0] ss_n;
	reg [31:0] ss_clear_addr;
	reg [31:0] ss_put_addr;
	reg [31:0] ss_header;
	reg [31:0] ss_new_length;
	reg ss_clear;
	reg ss_put;
	reg ss_length;
	reg [35:0] ss_put_value;
	reg [35:0] ss_buf [0:SHORTLIST_MAX - 1];
	localparam [0:0] SL_REFERENCE = (SHORTLIST_MODE == 1) || (CA_EN == 0);
	reg [$clog2(SHORTLIST_MAX + 1) - 1:0] ss_i;
	reg [9:0] ss_back;
	assign sl_valid_o = st == 10'd800;
	assign sl_response_ready_o = st == 10'd801;
	assign sl_src_o = ss_src;
	assign sl_dst_o = ss_dst;
	assign sl_n_o = ss_n;
	assign sl_reverse_o = ss_reverse;
	assign sl_clear_o = ss_clear;
	assign sl_put_o = ss_put;
	assign sl_length_o = ss_length;
	assign sl_clear_addr_o = ss_clear_addr;
	assign sl_put_addr_o = ss_put_addr;
	assign sl_header_o = ss_header;
	assign sl_new_length_o = ss_new_length;
	assign sl_put_value_o = ss_put_value;
	wire [35:0] mv;
	assign mv = {mt, md};
	reg [31:0] h_qdesc;
	reg [31:0] h_builtins;
	reg [31:0] h_hooks;
	reg [31:0] h_msgs;
	reg [31:0] h_chars;
	reg [31:0] h_empty;
	reg h_bigint;
	reg [31:0] h_nq;
	reg [31:0] h_qext;
	reg [31:0] h_qextn;
	reg [31:0] qid;
	reg [9:0] qd_nxt;
	reg [35:0] ty_fun;
	reg [35:0] ty_bm;
	reg [35:0] ty_cell;
	reg [35:0] ty_obj;
	reg [35:0] ty_stop;
	reg [35:0] ty_mem;
	reg [35:0] ty_slice;
	reg [35:0] ty_str;
	reg [31:0] fbase;
	reg [31:0] fprev;
	reg [31:0] rc;
	reg [31:0] pc;
	reg [31:0] op_pc;
	reg [31:0] qbase;
	reg [31:0] cbase;
	reg [6:0] sp;
	reg [7:0] nloc;
	reg locals_in_image;
	reg [8:0] stack_prefix_words;
	reg [16:0] local_image_word;
	reg [31:0] local_base;
	reg gen_direct_locals;
	reg [5:0] rf_base;
	reg [15:0] spilled_reals;
	reg [31:0] spill_hp;
	reg [4:0] xsp;
	reg [4:0] nexc;
	reg [7:0] fflags;
	reg [7:0] fcont;
	reg [3:0] frk;
	reg [35:0] glb;
	reg [35:0] loc;
	reg [35:0] fun;
	reg [35:0] aux;
	reg [35:0] aux2;
	reg [35:0] aux3;
	reg [35:0] rf [0:15];
	reg [31:0] xh;
	reg [15:0] xv;
	reg xf;
	reg [35:0] xp;
	reg noframe;
	reg rf_pend;
	wire rf_icpt;
	assign rf_icpt = ((((((((((((((rf_pend && (st != 10'd2)) && (st != 10'd156)) && (st != 10'd585)) && (st != 10'd112)) && (st != 10'd118)) && (st != 10'd117)) && (st != 10'd359)) && (st != 10'd766)) && (st != 10'd777)) && (st != 10'd563)) && (st != 10'd564)) && (st != 10'd565)) && (st != 10'd566)) && (st != 10'd567)) && (st != 10'd568);
	reg [35:0] rf_pend_v;
	reg [9:0] rf_resume;
	reg [31:0] spill_addr;
	reg [5:0] spill_n;
	reg [5:0] spill_ntag;
	reg [31:0] spill_words;
	reg [5:0] spill_nc;
	reg [31:0] spill_bc;
	reg spill_had_link;
	reg reload_top;
	reg [31:0] spill_prev;
	reg rf_mono;
	reg sp_hold;
	reg rf_reload_miss;
	reg [6:0] sp_d;
	wire [5:0] cfg_grow;
	wire cfg_adapt;
	reg spill_to_img;
	reg lc_v [0:7];
	reg lc_dirty [0:7];
	reg [2:0] lc_age [0:7];
	reg [2:0] lc_pick_r;
	reg [7:0] lc_ix [0:7];
	reg [35:0] lc_d [0:7];
	wire [3:0] cfg_lc_n;
	wire cfg_lc_wb;
	wire cfg_lc_dm;
	wire cfg_ca;
	wire cfg_aalu;
	wire cfg_bulk;
	reg [2:0] lc_ev_way;
	reg [7:0] lc_ev_idx;
	reg [35:0] lc_ev_val;
	reg lc_ev_dirty;
	reg [3:0] lc_fi;
	reg lc_dirty_any;
	reg [9:0] lc_fl_ret;
	always @(*) begin
		if (_sv2v_0)
			;
		lc_dirty_any = 1'b0;
		begin : sv2v_autoblock_4
			reg signed [31:0] k;
			for (k = 0; k < 8; k = k + 1)
				if ((k < cfg_lc_n) && lc_dirty[k])
					lc_dirty_any = 1'b1;
		end
	end
	reg [31:0] exc_base;
	reg [31:0] stack_base;
	reg [15:0] srd_g;
	reg [15:0] srd_off;
	reg [15:0] stk_from;
	reg [31:0] srd_addr;
	reg [35:0] srd_v;
	wire [31:0] srd_p0;
	reg [15:0] srd_hops;
	reg [15:0] drop_left;
	reg [15:0] ur_target;
	reg drop_push_en;
	reg [35:0] drop_push_v;
	reg [35:0] ur_val;
	reg [9:0] drop_then;
	reg [35:0] gen;
	reg [35:0] inj;
	reg fl_img;
	reg [7:0] op;
	reg [7:0] ext;
	reg [31:0] arg;
	reg [31:0] jt;
	reg extv;
	wire [31:0] jt_c;
	assign jt_c = (pc + arg) - {31'd0, extv};
	reg [1:0] ovr;
	reg [35:0] ab_q;
	reg [35:0] ab_s [0:3];
	reg [7:0] ab_lo;
	reg [7:0] ab_pe;
	reg [7:0] ab_nkw;
	reg [35:0] bov;
	reg [3:0] crk;
	reg [3:0] d_rk;
	reg [3:0] r_rk;
	reg [35:0] cl_loc;
	reg [7:0] hk_id;
	reg [7:0] nid;
	reg [35:0] t [0:7];
	reg [35:0] xc;
	reg halted;
	reg [3:0] hcode;
	reg [31:0] hval;
	reg [31:0] cyc;
	reg [31:0] nops;
	reg evt_q;
	reg soft_pt;
	reg hl_r;
	reg hl_skip;
	reg [14:0] hl_cnt;
	reg [31:0] wfe_n;
	reg trace;
	localparam signed [31:0] FE_QD = 3;
	localparam signed [31:0] FE_OW = 4;
	wire [95:0] fe_win;
	wire [31:0] fe_base;
	wire [31:0] fe_fault_addr;
	wire [5:0] fe_avail;
	wire fe_fault;
	wire fe_req;
	reg fe_flush;
	wire [3:0] fe_fault_reason;
	reg [31:0] x0;
	reg [31:0] x1;
	reg [31:0] x2;
	reg [31:0] x3;
	reg [31:0] x4;
	reg [31:0] limb_factor;
	reg [31:0] limb_carry;
	reg [31:0] limb_offset;
	reg [63:0] limb_product;
	wire [63:0] limb_sum;
	assign limb_sum = limb_product + sx64(limb_offset);
	reg bi_inline;
	reg bi_left_neg;
	reg bi_right_neg;
	reg bi_swap;
	reg bi_neg;
	reg bi_sub;
	reg [5:0] bi_op;
	reg [17:0] bi_an;
	reg [17:0] bi_bn;
	reg [17:0] bi_i;
	reg [17:0] bi_used;
	reg [29:0] bi_top;
	reg bi_low_nonzero;
	reg [31:0] bi_cmp_l;
	reg [31:0] bi_q;
	reg [63:0] bi_prefix;
	wire [31:0] bi_scalar;
	assign bi_scalar = (tg(t[0]) == ABI_TAG_OBJECT ? t[1][31:0] : t[0][31:0]);
	reg [7:0] i0;
	reg [7:0] i1;
	reg [7:0] i2;
	reg [6:0] s0;
	reg [6:0] s1;
	reg b0;
	reg b1;
	reg [35:0] ty_v;
	reg [35:0] ty_t;
	reg [35:0] hk;
	reg [31:0] hh;
	reg hok;
	reg hm_start;
	wire hm_done;
	wire [31:0] hm_rem;
	reg [35:0] si_v;
	reg [31:0] si_len;
	reg [31:0] si_hash;
	reg [31:0] si_addr;
	reg si_na;
	reg [35:0] se_a;
	reg [35:0] se_b;
	reg se_eq;
	reg [35:0] ke_a;
	reg [35:0] ke_b;
	reg ke_eq;
	reg ke_cx;
	reg [3:0] key_tuple_len;
	reg [3:0] key_tuple_index;
	reg [35:0] key_tuple_item;
	reg [1:0] lk_mode;
	reg lk_set;
	reg lk_found;
	reg lk_cx;
	reg lk_ro;
	reg [35:0] lk_res;
	reg lk_hasav;
	reg [31:0] al_n;
	reg [31:0] al_a;
	reg al_ok;
	reg al_soft;
	reg al_gc;
	reg [31:0] sw_i;
	reg [1:0] sw_k;
	reg [31:0] fl_base;
	reg [31:0] fl_i;
	reg [1:0] fl_k;
	reg [31:0] gi;
	reg [35:0] is_t;
	reg [35:0] is_c;
	reg is_r;
	reg [31:0] is_m;
	reg [31:0] is_n;
	reg [31:0] is_i;
	reg [31:0] at_q;
	reg [1:0] at_kind;
	reg at_ty;
	reg at_objd;
	reg at_nat;
	reg [35:0] at_v;
	reg [35:0] tr_v;
	reg tr_r;
	reg tr_x;
	reg tb_src;
	reg tb_nz;
	reg [7:0] tb_from;
	reg [15:0] tb_n;
	reg [15:0] tb_i;
	reg [31:0] tb_a;
	reg [35:0] tb_v;
	reg [35:0] wb_v [0:7];
	reg [31:0] wb_a;
	reg [3:0] wb_n;
	reg [3:0] wb_i;
	reg it_stop;
	reg it_py;
	reg it_h;
	reg [35:0] it_val;
	localparam [3:0] SCR_NONE = 4'd0;
	localparam [3:0] SCR_LK = 4'd1;
	localparam [3:0] SCR_RH = 4'd2;
	localparam [3:0] SCR_SE = 4'd3;
	localparam [3:0] SCR_AT = 4'd4;
	localparam [3:0] SCR_IT = 4'd5;
	localparam [3:0] SCR_LA = 4'd6;
	localparam [3:0] SCR_KE = 4'd7;
	reg [3:0] scr_id;
	reg [3:0] scr_cmd;
	reg [3:0] scr_i;
	reg scr_storing;
	reg scr_gosub_p;
	reg [9:0] scr_ret;
	reg [9:0] scr_gt;
	reg [9:0] scr_gb;
	reg [35:0] sV [0:7];
	reg [31:0] sA [0:7];
	reg [31:0] c_rc;
	reg [31:0] c_md;
	reg [31:0] c_cells;
	reg [31:0] c_tflags;
	reg [31:0] c_pc;
	reg [35:0] c_clos;
	reg [35:0] c_defs;
	reg [35:0] c_glob;
	reg [7:0] c_nst;
	reg [7:0] c_nexc;
	reg [7:0] c_scope;
	reg [7:0] c_rcf;
	reg [7:0] c_npos;
	reg [7:0] c_nkwo;
	reg [7:0] c_ndef;
	reg [7:0] c_ncell;
	reg [7:0] c_cn;
	reg c_fast;
	reg c_ismod;
	reg [31:0] c_ci;
	reg rx_from;
	reg [3:0] rx_crk;
	reg [31:0] rx_off;
	reg [7:0] rm_id;
	reg [31:0] uj;
	reg [7:0] cv_i;
	reg [7:0] cv_n;
	reg [7:0] cv_j;
	reg [31:0] cv_bm;
	reg [31:0] cv_items;
	reg [6:0] cv_base;
	reg [6:0] cv_fidx;
	reg ab_chunked;
	reg ab_ovf;
	reg cv_wide;
	reg cv_kw;
	reg [31:0] ab_npos;
	reg [31:0] ab_nitems;
	reg [31:0] ab_nblk;
	reg [31:0] cv_k;
	reg [4:0] ab_fill;
	reg [7:0] ab_lo0;
	reg [15:0] cv_g;
	reg [15:0] cv_pos_g;
	reg [15:0] cv_fun_g;
	reg [35:0] ab_blk;
	reg [9:0] cv_ret;
	reg alu_start;
	wire alu_done;
	reg [5:0] alu_op;
	reg na_f;
	reg nb_f;
	reg n_small;
	reg n_un;
	reg [63:0] na;
	reg [63:0] nb;
	wire [63:0] alu_res;
	wire [1:0] alu_kind;
	wire [2:0] alu_err;
	reg [7:0] n_o;
	localparam [1:0] CX_ADD = 2'd0;
	localparam [1:0] CX_SUB = 2'd1;
	localparam [1:0] CX_MUL = 2'd2;
	localparam [1:0] CX_ABS = 2'd3;
	reg [1:0] cx_op;
	reg cx_acx;
	reg cx_bcx;
	reg [31:0] cx_pa;
	reg [31:0] cx_pb;
	reg [31:0] cx_ar;
	reg [31:0] cx_ai;
	reg [31:0] cx_br;
	reg [31:0] cx_bi;
	reg [31:0] cx_t0;
	reg [31:0] cx_t1;
	reg [31:0] cx_re;
	reg [31:0] cx_im;
	reg [2:0] cx_k;
	localparam [3:0] ABI_TAG_COMPLEX = 4'd4;
	function automatic cx_operand;
		input reg [35:0] v;
		cx_operand = (tg(v) == ABI_TAG_COMPLEX) || (tg(v) == ABI_TAG_FLOAT);
	endfunction
	reg aalu_pend;
	reg aalu_ready;
	wire aalu_go;
	reg [3:0] aalu_slot;
	reg [9:0] aalu_ret;
	assign aalu_go = aalu_ready || alu_done;
	function automatic fits16;
		input reg [63:0] x;
		fits16 = (x[63:15] == {49 {1'b0}}) || (x[63:15] == {49 {1'b1}});
	endfunction
	localparam [5:0] mpy_alu_pkg_ALU_ADD = 6'd27;
	localparam [5:0] mpy_alu_pkg_ALU_AND = 6'd24;
	localparam [5:0] mpy_alu_pkg_ALU_FLOOR = 6'd31;
	localparam [5:0] mpy_alu_pkg_ALU_MOD = 6'd33;
	localparam [5:0] mpy_alu_pkg_ALU_MUL = 6'd29;
	localparam [5:0] mpy_alu_pkg_ALU_NE = 6'd5;
	localparam [5:0] mpy_alu_pkg_ALU_OR = 6'd22;
	localparam [5:0] mpy_alu_pkg_ALU_SUB = 6'd28;
	localparam [5:0] mpy_alu_pkg_ALU_TDIV = 6'd32;
	localparam [5:0] mpy_alu_pkg_ALU_XOR = 6'd23;
	function automatic aalu_safe;
		input reg [5:0] o;
		input reg un;
		input reg af;
		input reg bf;
		input reg [63:0] a;
		input reg [63:0] b;
		reg cmp;
		reg nz;
		begin
			cmp = o <= mpy_alu_pkg_ALU_NE;
			nz = (bf ? b[30:0] != 31'd0 : b != 64'd0);
			if (un)
				aalu_safe = 1'b0;
			else if (af || bf)
				aalu_safe = (((cmp || (o == mpy_alu_pkg_ALU_ADD)) || (o == mpy_alu_pkg_ALU_SUB)) || (o == mpy_alu_pkg_ALU_MUL)) || ((((o == mpy_alu_pkg_ALU_TDIV) || (o == mpy_alu_pkg_ALU_FLOOR)) || (o == mpy_alu_pkg_ALU_MOD)) && nz);
			else if (!fits31(a) || !fits31(b))
				aalu_safe = 1'b0;
			else
				aalu_safe = ((((((cmp || (o == mpy_alu_pkg_ALU_ADD)) || (o == mpy_alu_pkg_ALU_SUB)) || (o == mpy_alu_pkg_ALU_AND)) || (o == mpy_alu_pkg_ALU_OR)) || (o == mpy_alu_pkg_ALU_XOR)) || ((((o == mpy_alu_pkg_ALU_TDIV) || (o == mpy_alu_pkg_ALU_FLOOR)) || (o == mpy_alu_pkg_ALU_MOD)) && nz)) || (((o == mpy_alu_pkg_ALU_MUL) && fits16(a)) && fits16(b));
		end
	endfunction
	function automatic aalu_pass;
		input reg [7:0] o;
		aalu_pass = (((((((o >= 8'h70) && (o < 8'hc0)) || (o == 8'h10)) || (o == 8'h22)) || (o == 8'h23)) || (o == 8'h24)) || ((o >= 8'h50) && (o <= 8'h53))) || (o == 8'h42);
	endfunction
	mpy_alu u_alu(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.start_i(alu_start),
		.op_i(alu_op),
		.a_flt_i(na_f),
		.b_flt_i(nb_f),
		.a_i(na),
		.b_i(nb),
		.small_i(n_small),
		.done_o(alu_done),
		.res_o(alu_res),
		.rkind_o(alu_kind),
		.err_o(alu_err)
	);
	upycore_umod_seq #(.BPC(4)) u_hmod(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.start_i(hm_start),
		.a_i(hh),
		.d_i(sA[0]),
		.done_o(hm_done),
		.rem_o(hm_rem),
		.busy_o()
	);
	mpy_fetch #(.QD(FE_QD)) u_fetch(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.pc_i(pc),
		.flush_i(fe_flush),
		.req_o(fe_req),
		.addr_o(f_addr_o),
		.gnt_i(f_gnt_i),
		.ack_i(f_ack_i),
		.rdata_i(f_rdata_i),
		.fault_i(f_fault_i),
		.fault_reason_i(f_fault_reason_i),
		.win_o(fe_win),
		.base_o(fe_base),
		.avail_o(fe_avail),
		.fault_o(fe_fault),
		.fault_addr_o(fe_fault_addr),
		.fault_reason_o(fe_fault_reason)
	);
	localparam [2:0] MPY_REGION_SRAM = 3'd2;
	localparam signed [31:0] MPY_MEM_BLOCKS = 4;
	localparam signed [31:0] MPY_MEM_BLOCK_WORDS = 32768;
	localparam signed [31:0] MPY_MEM_WORDS = MPY_MEM_BLOCKS * MPY_MEM_BLOCK_WORDS;
	localparam signed [31:0] MPY_MEM_BYTES = MPY_MEM_WORDS * 4;
	localparam [31:0] MPY_FLASH_BYTES = MPY_MEM_BYTES;
	localparam [31:0] MPY_MMIO_BASE = 32'h40000000;
	localparam [31:0] MPY_MMIO_BYTES = 32'h00001000;
	localparam [2:0] MPY_REGION_FLASH = 3'd1;
	localparam [2:0] MPY_REGION_MMIO = 3'd3;
	localparam [2:0] MPY_REGION_NONE = 3'd0;
	localparam [2:0] MPY_REGION_SIM = 3'd4;
	localparam [31:0] MPY_SIM_BASE = 32'he0000000;
	localparam [31:0] MPY_SIM_BYTES = 32'd256;
	localparam [31:0] MPY_SRAM_BASE = 32'h20000000;
	localparam [31:0] MPY_SRAM_BYTES = MPY_MEM_BYTES;
	function automatic [2:0] mpy_region_of;
		input reg [31:0] addr;
		if (addr < MPY_FLASH_BYTES)
			mpy_region_of = MPY_REGION_FLASH;
		else if ((addr >= MPY_SRAM_BASE) && ((addr - MPY_SRAM_BASE) < MPY_SRAM_BYTES))
			mpy_region_of = MPY_REGION_SRAM;
		else if ((addr >= MPY_MMIO_BASE) && ((addr - MPY_MMIO_BASE) < MPY_MMIO_BYTES))
			mpy_region_of = MPY_REGION_MMIO;
		else if ((addr >= MPY_SIM_BASE) && ((addr - MPY_SIM_BASE) < MPY_SIM_BYTES))
			mpy_region_of = MPY_REGION_SIM;
		else
			mpy_region_of = MPY_REGION_NONE;
	endfunction
	assign f_req_o = fe_req && !((mpy_region_of(f_addr_o) == MPY_REGION_SRAM) && !ca_idle_i);
	wire [31:0] f_off;
	wire [63:0] d_bytes;
	wire [3:0] d_n;
	wire d_valid;
	wire d_illegal;
	wire d_trunc;
	wire d_ovf;
	wire d_argv;
	wire d_extv;
	wire [3:0] d_len;
	wire [7:0] d_op;
	wire [7:0] d_ext;
	wire [1:0] d_fmt;
	wire [6:0] d_entry;
	wire signed [31:0] d_arg;
	reg [63:0] dq_bytes;
	reg [3:0] dq_n;
	assign f_off = pc - fe_base;
	function automatic [63:0] sv2v_cast_64;
		input reg [63:0] inp;
		sv2v_cast_64 = inp;
	endfunction
	assign d_bytes = sv2v_cast_64(fe_win >> {f_off[3:0], 3'b000});
	function automatic [3:0] sv2v_cast_4;
		input reg [3:0] inp;
		sv2v_cast_4 = inp;
	endfunction
	assign d_n = (fe_avail > 6'd8 ? 4'd8 : sv2v_cast_4(fe_avail));
	mpy_decode u_dec(
		.instr_valid_i(1'b1),
		.bytes_i(dq_bytes),
		.nbytes_i(dq_n),
		.decoded_valid_o(d_valid),
		.illegal_o(d_illegal),
		.truncated_o(d_trunc),
		.arg_overflow_o(d_ovf),
		.len_o(d_len),
		.opcode_o(d_op),
		.format_o(d_fmt),
		.entry_o(d_entry),
		.arg_valid_o(d_argv),
		.arg_o(d_arg),
		.extra_valid_o(d_extv),
		.extra_o(d_ext)
	);
	wire [31:0] ftop;
	function automatic [8:0] sv2v_cast_9;
		input reg [8:0] inp;
		sv2v_cast_9 = inp;
	endfunction
	function automatic [8:0] frame_prefix;
		input reg [7:0] locals;
		input reg [4:0] exceptions;
		frame_prefix = (9'd17 + sv2v_cast_9(locals)) + (9'd3 * sv2v_cast_9(exceptions));
	endfunction
	assign ftop = fbase + {21'd0, stack_prefix_words, 2'b00};
	wire [9:0] stk_off;
	wire [31:0] stk_top;
	function automatic [9:0] sv2v_cast_10;
		input reg [9:0] inp;
		sv2v_cast_10 = inp;
	endfunction
	assign stk_off = sv2v_cast_10(stack_prefix_words) + sv2v_cast_10(sp);
	assign stk_top = fbase + {20'd0, stk_off, 2'b00};
	function automatic [31:0] loc_ptr;
		input reg [7:0] idx;
		loc_ptr = (local_base + 32'h00000044) + {22'd0, idx, 2'b00};
	endfunction
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	function automatic [31:0] exc_ptr;
		input reg [31:0] base;
		input reg [4:0] slot;
		exc_ptr = ((base + 32'h00000044) + ({24'd0, nloc} << 2)) + (32'd12 * sv2v_cast_32(slot));
	endfunction
	function automatic [31:0] exc_words;
		input reg [31:0] base;
		exc_words = (base + 32'h00000044) + ({24'd0, nloc} << 2);
	endfunction
	localparam [31:0] ABI_ARGBUF_BASE = 32'h20008100;
	function automatic [31:0] ab_ptr;
		input reg [7:0] idx;
		ab_ptr = ABI_ARGBUF_BASE + {22'd0, idx, 2'b00};
	endfunction
	function automatic [7:0] lc_match;
		input reg [7:0] idx;
		reg signed [31:0] k;
		for (k = 0; k < 8; k = k + 1)
			lc_match[k] = ((k < cfg_lc_n) && lc_v[k]) && (lc_ix[k] == idx);
	endfunction
	function automatic lc_is_hit;
		input reg [7:0] idx;
		lc_is_hit = |lc_match(idx);
	endfunction
	function automatic [2:0] lc_hit_way;
		input reg [7:0] idx;
		reg [7:0] m;
		begin
			m = lc_match(idx);
			lc_hit_way = 3'd0;
			begin : sv2v_autoblock_5
				reg signed [31:0] k;
				for (k = 0; k < 8; k = k + 1)
					if (m[k])
						lc_hit_way = k[2:0];
			end
		end
	endfunction
	function automatic signed [2:0] sv2v_cast_3_signed;
		input reg signed [2:0] inp;
		sv2v_cast_3_signed = inp;
	endfunction
	function automatic [2:0] lc_pick_lru;
		input reg _sv2v_unused;
		reg [2:0] best;
		reg any_inv;
		begin
			best = 3'd0;
			any_inv = 1'b0;
			begin : sv2v_autoblock_6
				reg signed [31:0] k;
				for (k = 0; k < 8; k = k + 1)
					if (((k < cfg_lc_n) && !lc_v[k]) && !any_inv) begin
						best = k[2:0];
						any_inv = 1'b1;
					end
			end
			if (!any_inv) begin : sv2v_autoblock_7
				reg [2:0] w1 [0:3];
				reg [2:0] w2 [0:1];
				reg e1 [0:3];
				reg e2 [0:1];
				begin : sv2v_autoblock_8
					reg signed [31:0] p;
					for (p = 0; p < 4; p = p + 1)
						begin : sv2v_autoblock_9
							reg el;
							reg er;
							el = ((2 * p) == 0) || ((2 * p) < cfg_lc_n);
							er = ((2 * p) + 1) < cfg_lc_n;
							w1[p] = (er && (!el || (lc_age[(2 * p) + 1] < lc_age[2 * p])) ? sv2v_cast_3_signed((2 * p) + 1) : sv2v_cast_3_signed(2 * p));
							e1[p] = el || er;
						end
				end
				begin : sv2v_autoblock_10
					reg signed [31:0] p;
					for (p = 0; p < 2; p = p + 1)
						begin
							w2[p] = (e1[(2 * p) + 1] && (!e1[2 * p] || (lc_age[w1[(2 * p) + 1]] < lc_age[w1[2 * p]])) ? w1[(2 * p) + 1] : w1[2 * p]);
							e2[p] = e1[2 * p] || e1[(2 * p) + 1];
						end
				end
				best = (e2[1] && (!e2[0] || (lc_age[w2[1]] < lc_age[w2[0]])) ? w2[1] : w2[0]);
			end
			lc_pick_lru = best;
		end
	endfunction
	function automatic [2:0] lc_pick;
		input reg [7:0] idx;
		if (cfg_lc_dm && (cfg_lc_n != 4'd0))
			lc_pick = idx[2:0] & (cfg_lc_n[2:0] - 3'd1);
		else
			lc_pick = lc_pick_r;
	endfunction
	task automatic lc_note;
		input reg [2:0] w;
		reg signed [31:0] k;
		for (k = 0; k < 8; k = k + 1)
			if (k[2:0] == w)
				lc_age[k] <= 3'd7;
			else if (lc_age[k] > lc_age[w])
				lc_age[k] <= lc_age[k] - 3'd1;
	endtask
	task automatic lc_inval;
		reg signed [31:0] k;
		for (k = 0; k < 8; k = k + 1)
			begin
				lc_v[k] <= 1'b0;
				lc_dirty[k] <= 1'b0;
			end
	endtask
	task automatic post;
		input reg [31:0] a;
		input reg [9:0] nxt;
		begin
			m_req <= 1'b1;
			st <= nxt;
		end
	endtask
	task automatic wr;
		input reg [31:0] a;
		input reg [35:0] v;
		input reg [9:0] nxt;
		begin
			m_addr <= a;
			m_wdata <= v[31:0];
			m_wtag <= v[35:32];
			m_we <= 1'b1;
			m_tag_we <= 1'b1;
			m_be <= 4'hf;
			post(a, nxt);
		end
	endtask
	task automatic lc_fill;
		input reg [7:0] idx;
		input reg [35:0] v;
		input reg dirty;
		input reg set_st;
		input reg [9:0] done;
		reg [2:0] w;
		reg [2:0] p;
		reg hit;
		reg [7:0] ev;
		begin
			hit = lc_is_hit(idx);
			p = lc_pick(idx);
			w = (hit ? lc_hit_way(idx) : p);
			begin : sv2v_autoblock_11
				reg signed [31:0] k;
				for (k = 0; k < 8; k = k + 1)
					ev[k] = (lc_v[k] && lc_dirty[k]) && (lc_ix[k] != idx);
			end
			if (cfg_lc_n == 4'd0) begin
				if (set_st)
					st <= done;
			end
			else if (!((!hit && cfg_lc_wb) && ev[p])) begin
				lc_v[w] <= 1'b1;
				lc_ix[w] <= idx;
				lc_d[w] <= v;
				lc_dirty[w] <= dirty && cfg_lc_wb;
				lc_note(w);
				if (set_st)
					st <= done;
			end
			else begin
				lc_ev_way <= p;
				lc_ev_idx <= idx;
				lc_ev_val <= v;
				lc_ev_dirty <= dirty && cfg_lc_wb;
				wr(loc_ptr(lc_ix[p]), lc_d[p], 10'd554);
			end
		end
	endtask
	assign cfg_grow = GROW_CHUNK[5:0];
	assign cfg_adapt = GROW_ADAPT != 0;
	assign cfg_lc_n = LC_N[3:0];
	assign cfg_lc_wb = LC_WB != 0;
	assign cfg_lc_dm = 1'b0;
	assign cfg_bulk = 1'b1;
	function automatic signed [1:0] sv2v_cast_2_signed;
		input reg signed [1:0] inp;
		sv2v_cast_2_signed = inp;
	endfunction
	assign cfg_sl = sv2v_cast_2_signed(SHORTLIST_MODE);
	assign cfg_ca = CA_EN != 0;
	assign cfg_aalu = AALU != 0;
	function automatic [35:0] hdr_word;
		input reg [31:0] i;
		case (i)
			4'd0: hdr_word = {4'd0, fprev};
			4'd1: hdr_word = {4'd0, rc};
			4'd2: hdr_word = {4'd0, pc};
			4'd3: hdr_word = {4'd0, op_pc};
			4'd4: hdr_word = {4'd0, fflags, 1'b0, nloc[6:0], 3'b000, xsp, locals_in_image, sp};
			4'd5: hdr_word = {4'd0, local_image_word[16:6], nexc, fcont, local_image_word[5:2], frk};
			4'd6: hdr_word = glb;
			4'd7: hdr_word = loc;
			4'd8: hdr_word = fun;
			4'd9: hdr_word = aux;
			4'd10: hdr_word = aux2;
			4'd11: hdr_word = aux3;
			4'd12: hdr_word = {4'd0, qbase};
			4'd13: hdr_word = {4'd0, cbase};
			4'd14: hdr_word = gen;
			4'd15: hdr_word = {4'd0, spill_hp};
			32'd16: hdr_word = {4'd0, local_image_word[1:0], spilled_reals, nloc, rf_base};
			default: hdr_word = VNULL;
		endcase
	endfunction
	wire has_link;
	wire [15:0] resident_reals;
	wire [15:0] stk_depth;
	reg [15:0] rf_lnk;
	wire [15:0] sd_nl;
	wire [15:0] sd_l;
	localparam [3:0] MPY_CTL_RF_LINK = 4'd6;
	localparam signed [31:0] MPY_TAG_WIDTH = 4;
	localparam signed [31:0] MPY_VAL_WIDTH = 32;
	localparam signed [31:0] MPY_ENTRY_WIDTH = MPY_TAG_WIDTH + MPY_VAL_WIDTH;
	localparam [3:0] MPY_TAG_CONTROL = 4'b0000;
	localparam signed [31:0] MPY_TAG_LSB = MPY_VAL_WIDTH;
	function automatic [3:0] mpy_entry_tag;
		input reg [MPY_ENTRY_WIDTH - 1:0] entry;
		mpy_entry_tag = entry[MPY_ENTRY_WIDTH - 1:MPY_TAG_LSB];
	endfunction
	function automatic mpy_is_rf_link;
		input reg [MPY_ENTRY_WIDTH - 1:0] entry;
		mpy_is_rf_link = (mpy_entry_tag(entry) == MPY_TAG_CONTROL) && (entry[3:0] == MPY_CTL_RF_LINK);
	endfunction
	always @(*) begin : sv2v_autoblock_12
		reg signed [31:0] k;
		if (_sv2v_0)
			;
		for (k = 0; k < 16; k = k + 1)
			rf_lnk[k] = mpy_is_rf_link(rf[k]);
	end
	assign has_link = (sp != 7'd0) && rf_lnk[rf_base[3:0]];
	function automatic [15:0] sv2v_cast_16;
		input reg [15:0] inp;
		sv2v_cast_16 = inp;
	endfunction
	assign resident_reals = (has_link ? sv2v_cast_16(sp) - 16'd1 : sv2v_cast_16(sp));
	assign sd_nl = spilled_reals + sv2v_cast_16(sp);
	assign sd_l = (spilled_reals + sv2v_cast_16(sp)) - 16'd1;
	assign stk_depth = (has_link ? sd_l : sd_nl);
	function automatic stk_hit;
		input reg [15:0] g;
		stk_hit = (g >= spilled_reals) && (has_link ? g < sd_l : g < sd_nl);
	endfunction
	function automatic [6:0] sv2v_cast_7;
		input reg [6:0] inp;
		sv2v_cast_7 = inp;
	endfunction
	function automatic [6:0] stk_slot;
		input reg [15:0] g;
		stk_slot = (has_link ? sv2v_cast_7(g - spilled_reals) + 7'd1 : sv2v_cast_7(g - spilled_reals));
	endfunction
	function automatic [35:0] stk_val;
		input reg [15:0] g;
		stk_val = rf[rf_base[3:0] + sv2v_cast_4(stk_slot(g))];
	endfunction
	assign m_req_o = m_req;
	assign m_we_o = m_we;
	assign m_tag_we_o = m_tag_we;
	assign m_be_o = m_be;
	assign m_addr_o = m_addr;
	assign m_wdata_o = m_wdata;
	assign m_wtag_o = m_wtag;
	localparam signed [31:0] ABI_GC_POOL_BYTES = 490240;
	assign gc_alloc_nbytes_o = (al_n > 122560 ? ABI_GC_POOL_BYTES + 32'd16 : al_n << 2);
	localparam [31:0] ABI_FRAME_BASE = 32'h20000000;
	assign gc_root0_lo_o = ABI_FRAME_BASE;
	assign gc_root0_hi_o = (noframe ? ABI_FRAME_BASE : stk_top);
	localparam [31:0] ABI_SCHED_BASE = 32'h20008000;
	assign gc_root1_lo_o = ABI_SCHED_BASE;
	localparam [31:0] ABI_GC_POOL_BASE = 32'h20008500;
	assign gc_root1_hi_o = ABI_GC_POOL_BASE;
	assign halted_o = halted;
	assign halt_code_o = hcode;
	assign halt_value_o = hval;
	assign cycles_o = cyc;
	assign ops_o = nops;
	assign trace_o = trace;
	assign trace_pc_o = op_pc;
	assign trace_op_o = op;
	assign trace_sp_o = sp;
	reg gc_alloc_req;
	reg gc_collect_req;
	assign gc_alloc_req_o = gc_alloc_req;
	assign gc_collect_req_o = gc_collect_req;
	reg ca_valid;
	reg [31:0] ca_dst;
	reg [31:0] ca_src;
	reg [31:0] ca_n;
	wire ca_ok;
	assign mb_qcount_o = h_nq;
	assign mb_qbase_o = h_qdesc;
	assign mb_qext_o = h_qext;
	assign ca_valid_o = ca_valid;
	assign ca_dst_o = ca_dst;
	assign ca_src_o = ca_src;
	assign ca_n_o = ca_n;
	assign ca_ok = ca_ready_i && !ca_valid;
	task automatic halt;
		input reg [3:0] code;
		input reg [31:0] value;
		begin
			halted <= 1'b1;
			hcode <= code;
			hval <= value;
			st <= 10'd1;
		end
	endtask
	localparam [3:0] ABI_HALT_BUS = 4'd6;
	localparam [3:0] ABI_HALT_FLASH_STORE = 4'd4;
	localparam [3:0] ABI_HALT_UNALIGNED = 4'd5;
	localparam [3:0] MPY_FAULT_FLASH_STORE = 4'd2;
	localparam [3:0] MPY_FAULT_UNALIGNED = 4'd1;
	task automatic fetch_fault;
		case (fe_fault_reason)
			MPY_FAULT_UNALIGNED:
				halt(ABI_HALT_UNALIGNED, fe_fault_addr);
			MPY_FAULT_FLASH_STORE:
				halt(ABI_HALT_FLASH_STORE, fe_fault_addr);
			default:
				halt(ABI_HALT_BUS, fe_fault_addr);
		endcase
	endtask
	task automatic rd;
		input reg [31:0] a;
		input reg [9:0] nxt;
		begin
			m_addr <= a;
			m_we <= 1'b0;
			m_tag_we <= 1'b0;
			m_be <= 4'hf;
			m_req <= 1'b1;
			wret <= nxt;
			st <= 10'd2;
		end
	endtask
	task automatic bload;
		input reg [31:0] a;
		begin
			m_addr <= a;
			m_we <= 1'b0;
			m_tag_we <= 1'b0;
			m_be <= 4'hf;
			m_req <= 1'b1;
		end
	endtask
	task automatic cx_start;
		input reg [35:0] a;
		input reg [35:0] b;
		begin
			cx_acx <= tg(a) == ABI_TAG_COMPLEX;
			cx_pa <= adr(a);
			cx_bcx <= tg(b) == ABI_TAG_COMPLEX;
			cx_pb <= adr(b);
			cx_ar <= a[31:0];
			cx_ai <= 32'd0;
			cx_br <= b[31:0];
			cx_bi <= 32'd0;
			cx_k <= 3'd0;
			bl_k <= 3'd0;
			if (tg(a) == ABI_TAG_COMPLEX) begin
				bload(adr(a));
				bl_n <= 8'd1;
				st <= 10'd359;
			end
			else if (tg(b) == ABI_TAG_COMPLEX) begin
				bload(adr(b));
				bl_n <= 8'd3;
				st <= 10'd359;
			end
			else
				st <= 10'd360;
		end
	endtask
	task automatic rc_burst;
		begin
			bload(c_rc);
			bl_n <= 8'd1;
			bl_k <= 3'd0;
			st <= 10'd118;
		end
	endtask
	function automatic [3:0] fault_code;
		input reg [3:0] reason;
		fault_code = (reason == MPY_FAULT_UNALIGNED ? ABI_HALT_UNALIGNED : (reason == MPY_FAULT_FLASH_STORE ? ABI_HALT_FLASH_STORE : ABI_HALT_BUS));
	endfunction
	task automatic wrb;
		input reg [31:0] a;
		input reg [7:0] b;
		input reg [9:0] nxt;
		begin
			m_addr <= {a[31:2], 2'b00};
			m_wdata <= {4 {b}};
			m_wtag <= 4'd0;
			m_we <= 1'b1;
			m_tag_we <= 1'b0;
			m_be <= 4'b0001 << a[1:0];
			post({a[31:2], 2'b00}, nxt);
		end
	endtask
	task automatic raise_msg;
		input reg [7:0] id;
		begin
			rm_id <= id;
			rsp <= 5'd0;
			st <= 10'd462;
		end
	endtask
	localparam [1:0] ABI_MUT_BYTEARRAY = 2'd3;
	localparam [3:0] ABI_TAG_TUPLE = 4'd9;
	task automatic load_seq_index;
		input reg [31:0] index;
		if ((index[31] || (index >= md)) && is_mut(t[0], ABI_MUT_BYTEARRAY))
			st <= 10'd324;
		else if (index[31] || (index >= md))
			raise_msg((tg(t[0]) == ABI_TAG_TUPLE ? ABI_MSG_TUPLE_INDEX : ABI_MSG_LIST_INDEX));
		else if (tg(t[0]) == ABI_TAG_TUPLE)
			rd((adr(t[0]) + 32'd4) + (index << 2), 10'd328);
		else
			rd(aoff(adr(t[0]), 8), 10'd325);
	endtask
	localparam [3:0] ABI_TAG_BYTES = 4'd13;
	task automatic load_string_index;
		input reg [31:0] index;
		if (index[31] || (index >= si_len))
			raise_msg((tg(t[0]) == ABI_TAG_BYTES ? ABI_MSG_BYTES_INDEX : ABI_MSG_STR_INDEX));
		else
			rd(si_addr + {index[31:2], 2'b00}, 10'd331);
	endtask
	task automatic store_seq_index;
		input reg [31:0] index;
		if ((index[31] || (index >= md)) && is_mut(t[0], ABI_MUT_BYTEARRAY))
			st <= 10'd516;
		else if (index[31] || (index >= md))
			raise_msg(ABI_MSG_LIST_INDEX);
		else
			rd(aoff(adr(t[0]), 8), 10'd517);
	endtask
	localparam [31:0] MPY_CORE_SCRATCH_BYTES = 32'd512;
	localparam [31:0] MPY_FRAME_RESERVE_BASE = MPY_SRAM_BASE;
	localparam [31:0] MPY_FRAME_RESERVE_BYTES = 32'h00008000;
	localparam [31:0] MPY_CORE_SCRATCH_BASE = (MPY_FRAME_RESERVE_BASE + MPY_FRAME_RESERVE_BYTES) - MPY_CORE_SCRATCH_BYTES;
	function automatic [31:0] scr_addr;
		input reg [3:0] id;
		input reg [3:0] wi;
		reg [31:0] basew;
		begin
			case (id)
				SCR_LK: basew = 32'd0;
				SCR_RH: basew = 32'd8;
				SCR_SE: basew = 32'd16;
				SCR_AT: basew = 32'd24;
				SCR_IT: basew = 32'd32;
				SCR_LA: basew = 32'd40;
				default: basew = 32'd48;
			endcase
			scr_addr = MPY_CORE_SCRATCH_BASE + ((basew + {28'd0, wi}) << 2);
		end
	endfunction
	function automatic [3:0] scr_words;
		input reg [3:0] id;
		scr_words = (id == SCR_KE ? 4'd4 : 4'd8);
	endfunction
	function automatic scr_tag;
		input reg [3:0] id;
		input reg [3:0] wi;
		case (id)
			SCR_RH: scr_tag = wi == 4'd7;
			SCR_AT: scr_tag = wi == 4'd6;
			SCR_IT: scr_tag = wi <= 4'd3;
			default: scr_tag = 1'b0;
		endcase
	endfunction
	task automatic gosub;
		input reg [9:0] target;
		input reg [9:0] back;
		begin
			rstk[rsp] <= back;
			rsp <= rsp + 5'd1;
			st <= target;
		end
	endtask
	task automatic ret;
		begin
			st <= rstk[rsp - 5'd1];
			rsp <= rsp - 5'd1;
		end
	endtask
	task automatic scr_go_store;
		input reg [3:0] id;
		input reg [9:0] back;
		begin
			scr_cmd <= id;
			scr_i <= 4'd0;
			scr_storing <= 1'b1;
			scr_gosub_p <= 1'b0;
			scr_ret <= back;
			st <= 10'd766;
		end
	endtask
	task automatic scr_go_load;
		input reg [3:0] id;
		input reg [9:0] back;
		begin
			scr_cmd <= id;
			scr_i <= 4'd0;
			scr_storing <= 1'b0;
			scr_gosub_p <= 1'b0;
			bl_n <= 8'd0;
			scr_ret <= back;
			st <= 10'd766;
		end
	endtask
	task automatic scr_go_store_gosub;
		input reg [3:0] id;
		input reg [9:0] target;
		input reg [9:0] back;
		begin
			scr_cmd <= id;
			scr_i <= 4'd0;
			scr_storing <= 1'b1;
			scr_gosub_p <= 1'b1;
			scr_gt <= target;
			scr_gb <= back;
			st <= 10'd766;
		end
	endtask
	task automatic scr_ensure;
		input reg [3:0] id;
		input reg [9:0] back;
		if (scr_id != SCR_NONE)
			scr_go_store(scr_id, back);
		else
			scr_go_load(id, back);
	endtask
	task automatic scr_adopt;
		input reg [3:0] id;
		input reg [9:0] back;
		if ((scr_id != SCR_NONE) && (scr_id != id))
			scr_go_store(scr_id, back);
		else if (scr_id != id) begin
			scr_id <= id;
			st <= back;
		end
		else
			st <= back;
	endtask
	task automatic gosub_scr;
		input reg [3:0] dest;
		input reg [9:0] target;
		input reg [9:0] back;
		if ((scr_id != SCR_NONE) && (scr_id != dest))
			scr_go_store_gosub(scr_id, target, back);
		else
			gosub(target, back);
	endtask
	task automatic go_next;
		if ((fe_avail != 6'd0) && !ca_fault_i) begin
			dq_bytes <= d_bytes;
			dq_n <= d_n;
			st <= 10'd132;
		end
		else
			st <= 10'd147;
	endtask
	localparam signed [31:0] MPY_RF_DEPTH = 16;
	function automatic signed [6:0] sv2v_cast_7_signed;
		input reg signed [6:0] inp;
		sv2v_cast_7_signed = inp;
	endfunction
	task automatic push;
		input reg [35:0] v;
		if (sp >= sv2v_cast_7_signed(MPY_RF_DEPTH)) begin
			rf_pend <= 1'b1;
			rf_pend_v <= v;
		end
		else begin
			rf[rf_base[3:0] + sv2v_cast_4(sp)] <= v;
			sp <= sp + 7'd1;
		end
	endtask
	task automatic raise_val;
		input reg [35:0] v;
		begin
			xc <= v;
			rx_from <= 1'b0;
			rsp <= 5'd0;
			st <= 10'd442;
		end
	endtask
	localparam [7:0] ABI_HOOK_RAISE = 8'd1;
	localparam [3:0] ABI_RK_PUSH = 4'd0;
	task automatic raise_err;
		input reg [7:0] code;
		input reg [35:0] a;
		input reg [35:0] b;
		begin
			ab_s[0] <= vint({24'd0, code});
			ab_s[1] <= a;
			ab_s[2] <= b;
			ab_s[3] <= VNULL;
			ab_lo <= 8'd32;
			ab_pe <= 8'd35;
			ab_nkw <= 8'd0;
			crk <= ABI_RK_PUSH;
			ab_chunked <= 1'b0;
			hk_id <= ABI_HOOK_RAISE;
			rsp <= 5'd0;
			i0 <= 8'd0;
			st <= 10'd592;
		end
	endtask
	task automatic hook;
		input reg [7:0] id;
		input reg [3:0] rk;
		input reg [7:0] n;
		input reg [35:0] a;
		input reg [35:0] b;
		input reg [35:0] c;
		input reg [35:0] d;
		begin
			ab_s[0] <= a;
			ab_s[1] <= b;
			ab_s[2] <= c;
			ab_s[3] <= d;
			ab_lo <= 8'd32;
			ab_pe <= 8'd32 + n;
			ab_nkw <= 8'd0;
			crk <= rk;
			ab_chunked <= 1'b0;
			hk_id <= id;
			i0 <= 8'd0;
			st <= 10'd592;
		end
	endtask
	task automatic deliver;
		input reg [35:0] v;
		input reg [3:0] rk;
		begin
			t[7] <= v;
			d_rk <= rk;
			st <= 10'd134;
		end
	endtask
	task automatic wblock;
		input reg [31:0] a;
		input reg [3:0] n;
		input reg [9:0] back;
		begin
			wb_a <= a;
			wb_n <= n;
			wb_i <= 4'd0;
			gosub(10'd546, back);
		end
	endtask
	task automatic lookup;
		input reg [35:0] d;
		input reg [35:0] key;
		input reg [35:0] val;
		input reg [1:0] mode;
		input reg set;
		input reg [9:0] back;
		begin
			t[4] <= d;
			t[5] <= key;
			t[6] <= val;
			lk_mode <= mode;
			lk_set <= set;
			gosub_scr(SCR_LK, 10'd296, back);
		end
	endtask
	task automatic alloc;
		input reg [31:0] n;
		input reg [9:0] back;
		begin
			al_n <= (n == 32'd0 ? 32'd1 : n);
			gosub(10'd3, back);
		end
	endtask
	task automatic ca_ship;
		input reg [31:0] dst;
		input reg [31:0] src;
		input reg [31:0] n;
		begin
			ca_byte_o <= 0;
			ca_reverse_o <= 0;
			ca_valid <= 1'b1;
			ca_dst <= dst;
			ca_src <= src;
			ca_n <= n;
		end
	endtask
	wire [31:0] ha_m4;
	wire [31:0] ha_lk4;
	wire [31:0] ha_qarg;
	wire [31:0] ha_carg;
	wire [31:0] ha_mdarg;
	wire [31:0] ha_cx_pa4;
	wire [31:0] ha_cx_pb4;
	wire [31:0] ha_bl_rc;
	wire [31:0] ha_bl_fl;
	wire [31:0] ha_bl_stk;
	wire [31:0] ha_bl_ab;
	wire [31:0] ha_ab8;
	wire [31:0] ha_bl_scr;
	assign ha_m4 = aoff(m_addr, 4);
	assign ha_lk4 = aoff(sA[5], 4);
	assign ha_qarg = qbase + (4 * arg);
	assign ha_carg = cbase + (4 * arg);
	assign ha_mdarg = md + (4 * arg);
	assign ha_cx_pa4 = aoff(cx_pa, 4);
	assign ha_cx_pb4 = aoff(cx_pb, 4);
	assign ha_bl_rc = c_rc + {22'd0, bl_n, 2'b00};
	assign ha_bl_fl = fl_base + {22'd0, bl_n, 2'b00};
	assign ha_bl_stk = stack_base + {22'd0, bl_n, 2'b00};
	assign ha_ab8 = aoff(adr(ab_q), 8);
	assign ha_bl_ab = ha_ab8 + {22'd0, bl_n, 2'b00};
	assign ha_bl_scr = scr_addr(scr_cmd, bl_n[3:0]);
	wire signed [32:0] ss_d_bw;
	wire signed [32:0] ss_d_fw;
	wire [31:0] ss_count_d;
	assign ss_d_bw = $signed({ss_start[31], ss_start}) - $signed({ss_stop[31], ss_stop});
	assign ss_d_fw = $signed({ss_stop[31], ss_stop}) - $signed({ss_start[31], ss_start});
	wire ss_ne;
	assign ss_ne = ss_start != ss_stop;
	assign ss_count_d = (ss_reverse ? (!ss_d_bw[32] && ss_ne ? ss_d_bw[31:0] : 32'd0) : (!ss_d_fw[32] && ss_ne ? ss_d_fw[31:0] : 32'd0));
	localparam [7:0] ABI_BINOP_ADD = 8'd27;
	localparam [7:0] ABI_BINOP_EQUAL = 8'd2;
	localparam [7:0] ABI_BINOP_EXCEPTION_MATCH = 8'd8;
	localparam [7:0] ABI_BINOP_FLOOR_DIVIDE = 8'd31;
	localparam [7:0] ABI_BINOP_IN = 8'd6;
	localparam [7:0] ABI_BINOP_INPLACE_ADD = 8'd14;
	localparam [7:0] ABI_BINOP_INPLACE_MULTIPLY = 8'd16;
	localparam [7:0] ABI_BINOP_INPLACE_OR = 8'd9;
	localparam [7:0] ABI_BINOP_INPLACE_SUBTRACT = 8'd15;
	localparam [7:0] ABI_BINOP_IS = 8'd7;
	localparam [7:0] ABI_BINOP_LESS = 8'd0;
	localparam [7:0] ABI_BINOP_LESS_EQUAL = 8'd3;
	localparam [7:0] ABI_BINOP_MORE = 8'd1;
	localparam [7:0] ABI_BINOP_MORE_EQUAL = 8'd4;
	localparam [7:0] ABI_BINOP_MULTIPLY = 8'd29;
	localparam [7:0] ABI_BINOP_NOT_EQUAL = 8'd5;
	localparam [7:0] ABI_BINOP_OR = 8'd22;
	localparam [7:0] ABI_BINOP_POWER = 8'd34;
	localparam [7:0] ABI_BINOP_SUBTRACT = 8'd28;
	localparam [7:0] ABI_CONT_BIND = 8'd15;
	localparam [7:0] ABI_CONT_FOR_NEXT = 8'd12;
	localparam [7:0] ABI_CONT_GETITER = 8'd13;
	localparam [7:0] ABI_CONT_INIT = 8'd2;
	localparam [7:0] ABI_CONT_RAISE = 8'd8;
	localparam [7:0] ABI_CONT_REDISPATCH = 8'd0;
	localparam [7:0] ABI_CONT_REPLACE = 8'd1;
	localparam [7:0] ABI_CONT_SPILL_REPLACE = 8'd18;
	localparam [7:0] ABI_CONT_TRUTH = 8'd9;
	localparam [7:0] ABI_CONT_UNPACK = 8'd7;
	localparam [7:0] ABI_CONT_WITH_ATTR = 8'd17;
	localparam [7:0] ABI_CONT_WITH_ENTER = 8'd3;
	localparam [7:0] ABI_CONT_WITH_EXC = 8'd6;
	localparam [7:0] ABI_CONT_WITH_NONE = 8'd4;
	localparam [7:0] ABI_CONT_WITH_TRUTH = 8'd10;
	localparam [7:0] ABI_CONT_WITH_UNWIND = 8'd5;
	localparam [7:0] ABI_CONT_YFROM = 8'd16;
	localparam signed [31:0] ABI_DICT_FLAG_ROM = 1;
	localparam [7:0] ABI_ERR_ATTR = 8'd13;
	localparam [7:0] ABI_ERR_BUILTIN_ARGS = 8'd18;
	localparam [7:0] ABI_ERR_CANT_CREATE = 8'd24;
	localparam [7:0] ABI_ERR_GENERATOR = 8'd22;
	localparam [7:0] ABI_ERR_INIT_NONE = 8'd16;
	localparam [7:0] ABI_ERR_INTERNAL = 8'd27;
	localparam [7:0] ABI_ERR_KEY = 8'd12;
	localparam [7:0] ABI_ERR_NAME = 8'd0;
	localparam [7:0] ABI_ERR_NOT_EXC = 8'd14;
	localparam [7:0] ABI_ERR_NOT_ITERATOR = 8'd3;
	localparam [7:0] ABI_ERR_STAR_ARGS = 8'd25;
	localparam [3:0] ABI_HALT_BAD_IMAGE = 4'd3;
	localparam [3:0] ABI_HALT_BAD_OPCODE = 4'd2;
	localparam [3:0] ABI_HALT_CLEAN = 4'd0;
	localparam [3:0] ABI_HALT_INTERNAL = 4'd9;
	localparam [3:0] ABI_HALT_SYSEXIT = 4'd10;
	localparam [3:0] ABI_HALT_UNCAUGHT = 4'd1;
	localparam [31:0] ABI_HDR_BUILTINS = 32'd6;
	localparam [31:0] ABI_HDR_CHARS = 32'd11;
	localparam [31:0] ABI_HDR_EMPTY_TUPLE = 32'd12;
	localparam [31:0] ABI_HDR_FLAGS = 32'd15;
	localparam [31:0] ABI_HDR_HOOKS = 32'd9;
	localparam [31:0] ABI_HDR_MSGS = 32'd10;
	localparam [31:0] ABI_HDR_QSTR_COUNT = 32'd3;
	localparam [31:0] ABI_HDR_QSTR_DESC = 32'd4;
	localparam [7:0] ABI_HOOK_BIND = 8'd21;
	localparam [7:0] ABI_HOOK_BIND_WIDE = 8'd24;
	localparam [7:0] ABI_HOOK_BINOP = 8'd2;
	localparam [7:0] ABI_HOOK_BOOT = 8'd0;
	localparam [7:0] ABI_HOOK_BUILD_CLASS = 8'd18;
	localparam [7:0] ABI_HOOK_CALL = 8'd19;
	localparam [7:0] ABI_HOOK_DICTOP = 8'd12;
	localparam [7:0] ABI_HOOK_GETATTR = 8'd5;
	localparam [7:0] ABI_HOOK_GETITER = 8'd9;
	localparam [7:0] ABI_HOOK_IMPORT = 8'd13;
	localparam [7:0] ABI_HOOK_IMPORT_FROM = 8'd14;
	localparam [7:0] ABI_HOOK_IMPORT_STAR = 8'd15;
	localparam [7:0] ABI_HOOK_INT_OVERFLOW = 8'd25;
	localparam [7:0] ABI_HOOK_IRQ_DISPATCH = 8'd26;
	localparam [7:0] ABI_HOOK_SETATTR = 8'd6;
	localparam [7:0] ABI_HOOK_SETSUBSCR = 8'd8;
	localparam [7:0] ABI_HOOK_SUBSCR = 8'd7;
	localparam [7:0] ABI_HOOK_SUPER_METHOD = 8'd22;
	localparam [7:0] ABI_HOOK_TRUTH = 8'd4;
	localparam [7:0] ABI_HOOK_TUPLE = 8'd11;
	localparam [7:0] ABI_HOOK_UNOP = 8'd3;
	localparam [7:0] ABI_HOOK_UNPACK = 8'd16;
	localparam [7:0] ABI_HOOK_WARN = 8'd23;
	localparam [7:0] ABI_HOOK_YFROM = 8'd10;
	localparam signed [31:0] ABI_IMAGE_FLAG_BIGINT = 1;
	localparam [31:0] ABI_IMAGE_MAGIC = 32'h324d5055;
	localparam [31:0] ABI_IT_DICT = 32'd2;
	localparam [31:0] ABI_IT_HEAPITER = 32'd6;
	localparam [31:0] ABI_IT_PYOBJ = 32'd4;
	localparam [31:0] ABI_IT_RANGE = 32'd1;
	localparam [31:0] ABI_IT_SEQ = 32'd0;
	localparam [31:0] ABI_IT_SET = 32'd3;
	localparam [31:0] ABI_IT_STR = 32'd5;
	localparam [31:0] ABI_MD_CONSTS = 32'd1;
	localparam [31:0] ABI_MD_QSTRS = 32'd0;
	localparam [31:0] ABI_MD_RAW = 32'd3;
	localparam [1:0] ABI_MUT_DICT = 2'd1;
	localparam [1:0] ABI_MUT_LIST = 2'd0;
	localparam [1:0] ABI_MUT_SET = 2'd2;
	localparam [7:0] ABI_N_ABS = 8'd49;
	localparam [7:0] ABI_N_ALLOC = 8'd14;
	localparam [7:0] ABI_N_BASEEXCEPTION_INIT = 8'd37;
	localparam [7:0] ABI_N_BCMP = 8'd28;
	localparam [7:0] ABI_N_BCOPY = 8'd18;
	localparam [7:0] ABI_N_CALLNS = 8'd16;
	localparam [7:0] ABI_N_CHR = 8'd54;
	localparam [7:0] ABI_N_DATA = 8'd30;
	localparam [7:0] ABI_N_DICT_GET = 8'd52;
	localparam [7:0] ABI_N_FGET = 8'd32;
	localparam [7:0] ABI_N_FIND_BYTES = 8'd60;
	localparam [7:0] ABI_N_FLOC = 8'd33;
	localparam [7:0] ABI_N_FTOI = 8'd25;
	localparam [7:0] ABI_N_GC = 8'd23;
	localparam [7:0] ABI_N_GCINFO = 8'd24;
	localparam [7:0] ABI_N_GETATTR = 8'd50;
	localparam [7:0] ABI_N_GRESUME = 8'd27;
	localparam [7:0] ABI_N_HALT = 8'd5;
	localparam [7:0] ABI_N_HASH = 8'd29;
	localparam [7:0] ABI_N_HLOCK = 8'd62;
	localparam [7:0] ABI_N_HUNLOCK = 8'd63;
	localparam [7:0] ABI_N_ID = 8'd2;
	localparam [7:0] ABI_N_INEXT = 8'd26;
	localparam [7:0] ABI_N_ISINSTANCE = 8'd1;
	localparam [7:0] ABI_N_LD = 8'd9;
	localparam [7:0] ABI_N_LEN = 8'd0;
	localparam [7:0] ABI_N_LIMB_MAC = 8'd58;
	localparam [7:0] ABI_N_LIMB_NEW = 8'd59;
	localparam [7:0] ABI_N_LIST_APPEND = 8'd35;
	localparam [7:0] ABI_N_LIST_COPY = 8'd48;
	localparam [7:0] ABI_N_LIST_INSERT = 8'd46;
	localparam [7:0] ABI_N_LIST_POP = 8'd45;
	localparam [7:0] ABI_N_LOOKUP = 8'd21;
	localparam [7:0] ABI_N_MAPBULK = 8'd40;
	localparam [7:0] ABI_N_MAPINSERT_HASHED = 8'd41;
	localparam [7:0] ABI_N_MAPRELATION = 8'd42;
	localparam [7:0] ABI_N_MK = 8'd8;
	localparam [7:0] ABI_N_NEW_FLOAT = 8'd55;
	localparam [7:0] ABI_N_NEW_INT = 8'd56;
	localparam [7:0] ABI_N_NEW_OBJECT = 8'd39;
	localparam [7:0] ABI_N_NEW_RANGE = 8'd38;
	localparam [7:0] ABI_N_NEW_TYPE = 8'd57;
	localparam [7:0] ABI_N_OBJECT_INIT = 8'd36;
	localparam [7:0] ABI_N_ORD = 8'd53;
	localparam [7:0] ABI_N_PAY = 8'd7;
	localparam [7:0] ABI_N_PEEK32 = 8'd13;
	localparam [7:0] ABI_N_PEEK8 = 8'd11;
	localparam [7:0] ABI_N_POKE8 = 8'd12;
	localparam [7:0] ABI_N_QXSET = 8'd34;
	localparam [7:0] ABI_N_SEQREVERSE = 8'd43;
	localparam [7:0] ABI_N_SEQSCAN = 8'd44;
	localparam [7:0] ABI_N_SETATTR = 8'd51;
	localparam [7:0] ABI_N_SLEN = 8'd31;
	localparam [7:0] ABI_N_ST = 8'd10;
	localparam [7:0] ABI_N_STRFIN = 8'd20;
	localparam [7:0] ABI_N_STRNEW = 8'd19;
	localparam [7:0] ABI_N_TAG = 8'd6;
	localparam [7:0] ABI_N_TICKS = 8'd22;
	localparam [7:0] ABI_N_TYPEOF = 8'd15;
	localparam [7:0] ABI_N_WCOPY = 8'd17;
	localparam [7:0] ABI_N_WCOPY_STEP = 8'd47;
	localparam [7:0] ABI_N_WE = 8'd4;
	localparam [7:0] ABI_N_WFE = 8'd61;
	localparam [7:0] ABI_N_WR = 8'd3;
	localparam [31:0] ABI_OB_BIGINT = 32'd20;
	localparam [31:0] ABI_OB_BOUND_METHOD = 32'd7;
	localparam [31:0] ABI_OB_BUILTIN = 32'd8;
	localparam [31:0] ABI_OB_CELL = 32'd4;
	localparam [31:0] ABI_OB_CLASSMETHOD = 32'd13;
	localparam [31:0] ABI_OB_DICT_VIEW = 32'd15;
	localparam [31:0] ABI_OB_EXCEPTION = 32'd3;
	localparam [31:0] ABI_OB_FUNCTION = 32'd5;
	localparam [31:0] ABI_OB_GENERATOR = 32'd6;
	localparam [31:0] ABI_OB_INSTANCE = 32'd1;
	localparam [31:0] ABI_OB_ITEROBJ = 32'd16;
	localparam [31:0] ABI_OB_MODULE = 32'd9;
	localparam [31:0] ABI_OB_PROPERTY = 32'd11;
	localparam [31:0] ABI_OB_SLICE = 32'd14;
	localparam [31:0] ABI_OB_STATICMETHOD = 32'd12;
	localparam [31:0] ABI_OB_TYPE = 32'd2;
	localparam [1:0] ABI_OVR_FALSE = 2'd3;
	localparam [1:0] ABI_OVR_NONE = 2'd0;
	localparam [1:0] ABI_OVR_PYOBJ = 2'd1;
	localparam [1:0] ABI_OVR_TRUE = 2'd2;
	localparam [31:0] ABI_Q_CLASS_D = 32'd9;
	localparam [31:0] ABI_Q_DICT_D = 32'd167;
	localparam [31:0] ABI_Q_EMPTY = 32'd0;
	localparam [31:0] ABI_Q_ENTER_D = 32'd11;
	localparam [31:0] ABI_Q_EXIT_D = 32'd12;
	localparam [31:0] ABI_Q_INIT_D = 32'd16;
	localparam [31:0] ABI_Q_ITER_D = 32'd18;
	localparam [31:0] ABI_Q_NEXT_D = 32'd24;
	localparam [31:0] ABI_RC_ARGS = 32'd2;
	localparam [31:0] ABI_RC_CELLS = 32'd4;
	localparam [31:0] ABI_RC_CHILDREN = 32'd6;
	localparam signed [31:0] ABI_RC_FLAG_FIRMWARE = 1;
	localparam signed [31:0] ABI_RC_FLAG_GENERATOR = 2;
	localparam [31:0] ABI_RC_MODULE = 32'd5;
	localparam [31:0] ABI_RC_OP_START = 32'd0;
	localparam [31:0] ABI_RC_SIG = 32'd1;
	localparam [3:0] ABI_RK_CONT = 4'd2;
	localparam [3:0] ABI_RK_DISCARD = 4'd1;
	localparam [3:0] ABI_RK_HALT = 4'd3;
	localparam [3:0] ABI_RK_PUSH_NULL = 4'd4;
	localparam signed [31:0] ABI_SCOPE_VARARGS = 4;
	localparam signed [31:0] ABI_SCOPE_VARKEYWORDS = 2;
	localparam signed [31:0] ABI_SET_FLAG_FROZEN = 2;
	localparam [31:0] ABI_SIM_BASE = 32'he0000000;
	localparam [7:0] ABI_SIM_STDERR = 8'd1;
	localparam [7:0] ABI_SIM_STDOUT = 8'd2;
	localparam [7:0] ABI_SR_CUR_EXC = 8'd0;
	localparam [7:0] ABI_SR_FW7 = 8'd27;
	localparam [7:0] ABI_SR_T0 = 8'd1;
	localparam [7:0] ABI_SR_T1 = 8'd2;
	localparam [7:0] ABI_SR_T2 = 8'd3;
	localparam [7:0] ABI_SR_T3 = 8'd4;
	localparam [7:0] ABI_SR_T4 = 8'd8;
	localparam [7:0] ABI_SR_T5 = 8'd9;
	localparam [7:0] ABI_SR_T6 = 8'd10;
	localparam [7:0] ABI_SR_T7 = 8'd11;
	localparam [31:0] ABI_STR_NONASCII = 32'h40000000;
	localparam [3:0] ABI_TAG_CONT = 4'd15;
	localparam [3:0] ABI_TAG_ITER = 4'd12;
	localparam [3:0] ABI_TAG_RANGE = 4'd11;
	localparam [31:0] ABI_TF_DESC = 32'd128;
	localparam [31:0] ABI_TF_EXC = 32'd2;
	localparam [31:0] ABI_TF_GETATTR = 32'd256;
	localparam [31:0] ABI_TF_INST = 32'd1;
	localparam [31:0] ABI_TF_NATIVE_SUB = 32'd32;
	localparam [31:0] ABI_TF_SETATTR = 32'd64;
	localparam [31:0] ABI_TF_TRUTH = 32'd16;
	localparam [7:0] ABI_T_BOOL = 8'd4;
	localparam [7:0] ABI_T_BOUND_METHOD = 8'd26;
	localparam [7:0] ABI_T_BYTEARRAY = 8'd10;
	localparam [7:0] ABI_T_BYTES = 8'd9;
	localparam [7:0] ABI_T_CELL = 8'd29;
	localparam [7:0] ABI_T_COMPLEX = 8'd7;
	localparam [7:0] ABI_T_DICT = 8'd13;
	localparam [7:0] ABI_T_FLOAT = 8'd6;
	localparam [7:0] ABI_T_FROZENSET = 8'd15;
	localparam [7:0] ABI_T_FUNCTION = 8'd24;
	localparam [7:0] ABI_T_GENERATOR = 8'd25;
	localparam [7:0] ABI_T_GENERATOREXIT = 8'd45;
	localparam [7:0] ABI_T_INT = 8'd5;
	localparam [7:0] ABI_T_ITERATOR = 8'd18;
	localparam [7:0] ABI_T_LIST = 8'd12;
	localparam [7:0] ABI_T_MEMORYERROR = 8'd52;
	localparam [7:0] ABI_T_NONETYPE = 8'd3;
	localparam [7:0] ABI_T_OBJECT = 8'd1;
	localparam [7:0] ABI_T_RANGE = 8'd16;
	localparam [7:0] ABI_T_SET = 8'd14;
	localparam [7:0] ABI_T_SLICE = 8'd17;
	localparam [7:0] ABI_T_STOPITERATION = 8'd58;
	localparam [7:0] ABI_T_STR = 8'd8;
	localparam [7:0] ABI_T_TUPLE = 8'd11;
	localparam [7:0] ABI_T_TYPE = 8'd2;
	localparam [7:0] ABI_UNOP_INVERT = 8'd2;
	localparam [7:0] ABI_UNOP_NEGATIVE = 8'd1;
	localparam [7:0] ABI_UNOP_NOT = 8'd3;
	localparam [7:0] ABI_UNOP_POSITIVE = 8'd0;
	localparam signed [31:0] MPY_RF_CHUNK_MAX = 8;
	localparam signed [31:0] MPY_RF_CHUNK_MIN = 4;
	localparam signed [31:0] RF_LEAVE_SP = 5;
	localparam signed [31:0] RF_RELOAD_AT = 4;
	localparam signed [31:0] RF_SPILL_AT = 12;
	localparam [2:0] mpy_alu_pkg_AE_NEG_SHIFT = 3'd3;
	localparam [2:0] mpy_alu_pkg_AE_NONE = 3'd0;
	localparam [2:0] mpy_alu_pkg_AE_OVERFLOW = 3'd2;
	localparam [2:0] mpy_alu_pkg_AE_ZERO_DIV = 3'd1;
	localparam [1:0] mpy_alu_pkg_AK_BOOL = 2'd3;
	localparam [1:0] mpy_alu_pkg_AK_FLOAT = 2'd1;
	localparam [5:0] mpy_alu_pkg_ALU_ABS = 6'd43;
	localparam [5:0] mpy_alu_pkg_ALU_F2I = 6'd45;
	localparam [5:0] mpy_alu_pkg_ALU_INVERT = 6'd42;
	localparam [5:0] mpy_alu_pkg_ALU_NEG = 6'd40;
	localparam [5:0] mpy_alu_pkg_ALU_POS = 6'd41;
	localparam [5:0] mpy_alu_pkg_ALU_POW = 6'd34;
	function automatic [MPY_ENTRY_WIDTH - 1:0] mpy_make_entry;
		input reg [3:0] tag;
		input reg [31:0] payload;
		mpy_make_entry = {tag, payload};
	endfunction
	function automatic [MPY_ENTRY_WIDTH - 1:0] mpy_make_rf_link;
		input reg [31:0] addr;
		mpy_make_rf_link = mpy_make_entry(MPY_TAG_CONTROL, {addr[31:4], MPY_CTL_RF_LINK});
	endfunction
	function automatic [31:0] mpy_rf_block_bytes;
		input reg [5:0] n;
		reg [31:0] ntag;
		reg [31:0] raw;
		begin
			ntag = sv2v_cast_32((n + 6'd7) >> 3);
			raw = (32'd4 + (ntag << 2)) + (sv2v_cast_32(n) << 2);
			mpy_rf_block_bytes = (raw + 32'd15) & 32'hfffffff0;
		end
	endfunction
	function automatic [7:0] mpy_rf_chunk_count;
		input reg [3:0] tag;
		input reg [31:0] word;
		mpy_rf_chunk_count = {tag, word[3:0]};
	endfunction
	function automatic [35:0] mpy_rf_chunk_hdr;
		input reg [31:0] prev;
		input reg [5:0] n;
		mpy_rf_chunk_hdr = {2'b00, n[5:4], prev[31:4], n[3:0]};
	endfunction
	function automatic [31:0] mpy_rf_chunk_prev;
		input reg [31:0] word;
		mpy_rf_chunk_prev = {word[31:4], 4'b0000};
	endfunction
	function automatic [31:0] mpy_rf_link_addr;
		input reg [MPY_ENTRY_WIDTH - 1:0] entry;
		mpy_rf_link_addr = {entry[31:4], 4'b0000};
	endfunction
	function automatic [2:0] sv2v_cast_3;
		input reg [2:0] inp;
		sv2v_cast_3 = inp;
	endfunction
	function automatic [11:0] sv2v_cast_12;
		input reg [11:0] inp;
		sv2v_cast_12 = inp;
	endfunction
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
	endfunction
	function automatic signed [5:0] sv2v_cast_6_signed;
		input reg signed [5:0] inp;
		sv2v_cast_6_signed = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i) begin : seq
		reg [31:0] v0;
		reg [31:0] v1;
		reg [31:0] v2;
		reg [31:0] v3;
		reg [7:0] vi;
		reg [6:0] vs0;
		reg [6:0] vs1;
		reg vb;
		if (!rst_n_i) begin
			st <= 10'd0;
			rsp <= 5'd0;
			m_req <= 1'b0;
			m_we <= 1'b0;
			m_tag_we <= 1'b0;
			m_be <= 4'hf;
			m_addr <= 32'd0;
			m_wdata <= 32'd0;
			m_wtag <= 4'd0;
			wpend <= 3'd0;
			wf_w <= 2'd0;
			wf_r <= 2'd0;
			wfault_p <= 1'b0;
			wfault_code <= 4'd0;
			wfault_addr <= 32'd0;
			bl_n <= 8'd0;
			bl_k <= 3'd0;
			begin : sv2v_autoblock_13
				reg signed [31:0] k;
				for (k = 0; k < WQ; k = k + 1)
					wfifo[k] <= 32'd0;
			end
			gc_alloc_req <= 1'b0;
			gc_collect_req <= 1'b0;
			alu_start <= 1'b0;
			hm_start <= 1'b0;
			aalu_pend <= 1'b0;
			aalu_ready <= 1'b0;
			aalu_slot <= 4'd0;
			aalu_ret <= 10'd147;
			mb_valid_o <= 0;
			mb_op_o <= 0;
			mb_set_o <= 0;
			mb_src_o <= 0;
			mb_sn_o <= 0;
			mb_dst_o <= 0;
			mb_dn_o <= 0;
			mb_used_o <= 0;
			mb_header_o <= 0;
			mb_source_header_o <= 0;
			mb_hashes_o <= 0;
			ca_byte_o <= 0;
			ca_reverse_o <= 0;
			ca_valid <= 1'b0;
			ca_dst <= 32'd0;
			ca_src <= 32'd0;
			ca_n <= 32'd0;
			halted <= 1'b0;
			hcode <= 4'd0;
			hval <= 32'd0;
			cyc <= 32'd0;
			nops <= 32'd0;
			trace <= 1'b0;
			evt_q <= 1'b0;
			soft_pt <= 1'b0;
			hl_r <= 1'b0;
			hl_skip <= 1'b0;
			hl_cnt <= 15'd0;
			wfe_n <= 32'd0;
			fe_flush <= 1'b0;
			h_nq <= 32'd0;
			h_qext <= 32'd0;
			h_qextn <= 32'd0;
			qd_nxt <= 10'd0;
			sp <= 7'd0;
			nloc <= 8'd0;
			stack_prefix_words <= 9'd17;
			rf_base <= 6'd0;
			spilled_reals <= 16'd0;
			spill_hp <= MPY_CORE_SCRATCH_BASE;
			rf_pend <= 1'b0;
			scr_id <= SCR_NONE;
			scr_i <= 4'd0;
			scr_storing <= 1'b0;
			scr_gosub_p <= 1'b0;
			begin : sv2v_autoblock_14
				reg signed [31:0] k;
				for (k = 0; k < 8; k = k + 1)
					begin
						sA[k] <= 32'd0;
						sV[k] <= VNULL;
					end
			end
			rf_mono <= 1'b1;
			sp_hold <= 1'b0;
			sp_d <= 7'd0;
			rf_reload_miss <= 1'b0;
			xsp <= 5'd0;
			nexc <= 5'd0;
			xh <= 32'd0;
			xv <= 16'd0;
			xf <= 1'b0;
			xp <= VNULL;
			noframe <= 1'b1;
			ovr <= ABI_OVR_NONE;
			cl_loc <= VNULL;
			al_soft <= 1'b0;
			fflags <= 8'd0;
			fcont <= 8'd0;
			frk <= ABI_RK_HALT;
			fbase <= ABI_FRAME_BASE;
			fprev <= 32'd0;
			local_base <= ABI_FRAME_BASE;
			local_image_word <= 17'd0;
			locals_in_image <= 1'b0;
			gen_direct_locals <= 1'b0;
			gen <= VNULL;
			inj <= VNONE;
			fl_img <= 1'b0;
			spill_to_img <= 1'b0;
			lc_fl_ret <= 10'd508;
			ss_store <= 0;
			ss_native <= 0;
			ss_reverse <= 0;
			ss_omitted <= 0;
			ss_len <= 0;
			ss_start <= 0;
			ss_stop <= 0;
			ss_bound <= 0;
			ss_count <= 0;
			ss_src <= 0;
			ss_dst <= 0;
			ss_n <= 0;
			ss_clear_addr <= 0;
			ss_put_addr <= 0;
			ss_header <= 0;
			ss_new_length <= 0;
			ss_clear <= 0;
			ss_put <= 0;
			ss_length <= 0;
			ss_put_value <= VNULL;
			ss_i <= 0;
			ss_back <= 10'd147;
			begin : sv2v_autoblock_15
				reg signed [31:0] k;
				for (k = 0; k < 8; k = k + 1)
					t[k] <= VNULL;
			end
			xc <= VNULL;
			bov <= VNULL;
			ab_chunked <= 1'b0;
			ab_ovf <= 1'b0;
			cv_wide <= 1'b0;
			cv_kw <= 1'b0;
			ab_npos <= 32'd0;
			ab_nitems <= 32'd0;
			ab_nblk <= 32'd0;
			ab_fill <= 5'd0;
			ab_lo0 <= 8'd0;
			ab_blk <= VNULL;
			cv_k <= 32'd0;
			cv_g <= 16'd0;
			cv_pos_g <= 16'd0;
			cv_fun_g <= 16'd0;
			ab_q <= VNULL;
			begin : sv2v_autoblock_16
				reg signed [31:0] k;
				for (k = 0; k < 4; k = k + 1)
					ab_s[k] <= VNULL;
			end
			begin : sv2v_autoblock_17
				reg signed [31:0] k;
				for (k = 0; k < MPY_RF_DEPTH; k = k + 1)
					rf[k] <= VNULL;
			end
			begin : sv2v_autoblock_18
				reg signed [31:0] k;
				for (k = 0; k < 8; k = k + 1)
					begin
						lc_v[k] <= 1'b0;
						lc_dirty[k] <= 1'b0;
						lc_age[k] <= 3'd0;
					end
			end
			lc_fi <= 4'd0;
			lc_pick_r <= 3'd0;
		end
		else begin
			m_req <= m_req && m_busy_i;
			lc_pick_r <= lc_pick_lru(0);
			fe_flush <= 1'b0;
			gc_alloc_req <= 1'b0;
			gc_collect_req <= 1'b0;
			alu_start <= 1'b0;
			hm_start <= 1'b0;
			ca_valid <= 1'b0;
			mb_valid_o <= 1'b0;
			trace <= 1'b0;
			if (!halted)
				cyc <= cyc + 32'd1;
			evt_q <= evt_pend_i;
			hl_r <= (hl_cnt != 15'd0) && !hl_skip;
			if (sp_hold)
				sp_hold <= 1'b0;
			else if (sp < sp_d)
				rf_mono <= 1'b0;
			else if (sp > sp_d)
				rf_mono <= 1'b1;
			sp_d <= sp;
			if (aalu_pend && alu_done)
				aalu_ready <= 1'b1;
			if ((m_req && m_we) && !m_busy_i) begin
				wfifo[wf_w] <= m_addr;
				wf_w <= wf_w + 2'd1;
				if (m_tag_we && (m_addr == (ABI_SYSROOT_BASE + (4 * ABI_SR_FW7))))
					bov <= {m_wtag, m_wdata};
			end
			if (m_ack_i && (wpend != 3'd0)) begin
				wf_r <= wf_r + 2'd1;
				if (m_fault_i && !wfault_p) begin
					wfault_p <= 1'b1;
					wfault_addr <= wfifo[wf_r];
					wfault_code <= (m_fault_reason_i == MPY_FAULT_UNALIGNED ? ABI_HALT_UNALIGNED : (m_fault_reason_i == MPY_FAULT_FLASH_STORE ? ABI_HALT_FLASH_STORE : ABI_HALT_BUS));
				end
			end
			wpend <= (wpend + ((m_req && m_we) && !m_busy_i ? 3'd1 : 3'd0)) - (m_ack_i && (wpend != 3'd0) ? 3'd1 : 3'd0);
			if ((wfault_p || ((m_req && m_we) && m_busy_i)) || rf_icpt) begin
				if (wfault_p) begin
					if (st != 10'd1)
						halt(wfault_code, wfault_addr);
				end
				else if ((m_req && m_we) && m_busy_i)
					;
				else if (sp >= sv2v_cast_7_signed(MPY_RF_DEPTH)) begin
					rf_resume <= st;
					st <= 10'd563;
				end
				else begin
					rf[rf_base[3:0] + sv2v_cast_4(sp)] <= rf_pend_v;
					sp <= sp + 7'd1;
					rf_pend <= 1'b0;
				end
			end
			else
				case (st)
					10'd1:
						;
					10'd2:
						if (m_ack_i && (wpend == 3'd0)) begin
							md <= m_rdata_i;
							mt <= m_rtag_i;
							if (m_fault_i)
								case (m_fault_reason_i)
									MPY_FAULT_UNALIGNED:
										halt(ABI_HALT_UNALIGNED, m_addr);
									MPY_FAULT_FLASH_STORE:
										halt(ABI_HALT_FLASH_STORE, m_addr);
									default:
										halt(ABI_HALT_BUS, m_addr);
								endcase
							else
								st <= wret;
						end
					10'd766:
						if (scr_i == scr_words(scr_cmd)) begin
							scr_gosub_p <= 1'b0;
							if (scr_storing)
								scr_id <= SCR_NONE;
							else
								scr_id <= scr_cmd;
							if (scr_gosub_p)
								gosub(scr_gt, scr_gb);
							else
								st <= scr_ret;
						end
						else if (scr_storing) begin
							if (scr_tag(scr_cmd, scr_i))
								wr(scr_addr(scr_cmd, scr_i), sV[scr_i[2:0]], 10'd766);
							else
								wr(scr_addr(scr_cmd, scr_i), {4'd0, sA[scr_i[2:0]]}, 10'd766);
							scr_i <= scr_i + 4'd1;
						end
						else begin
							if ((bl_n != {4'd0, scr_words(scr_cmd)}) && !m_wait) begin
								bload(ha_bl_scr);
								bl_n <= bl_n + 8'd1;
							end
							if (m_ack_i && (wpend == 3'd0)) begin
								if (m_fault_i)
									halt(fault_code(m_fault_reason_i), scr_addr(scr_cmd, scr_i));
								else begin
									if (scr_tag(scr_cmd, scr_i))
										sV[scr_i[2:0]] <= {m_rtag_i, m_rdata_i};
									else
										sA[scr_i[2:0]] <= m_rdata_i;
									scr_i <= scr_i + 4'd1;
								end
							end
						end
					10'd0:
						rd(32'd0, 10'd69);
					10'd69:
						if (md != ABI_IMAGE_MAGIC)
							halt(ABI_HALT_BAD_IMAGE, md);
						else
							rd(16, 10'd77);
					10'd77: begin
						h_qdesc <= md;
						h_qext <= 32'd0;
						h_qextn <= 32'd0;
						rd(12, 10'd78);
					end
					10'd78: begin
						h_nq <= md;
						rd(24, 10'd79);
					end
					10'd79: begin
						h_builtins <= md;
						rd(36, 10'd80);
					end
					10'd80: begin
						h_hooks <= md;
						rd(60, 10'd81);
					end
					10'd81: begin
						h_bigint <= (md & ABI_IMAGE_FLAG_BIGINT) != 0;
						rd(40, 10'd83);
					end
					10'd83: begin
						h_msgs <= md;
						rd(44, 10'd84);
					end
					10'd84: begin
						h_chars <= md;
						rd(48, 10'd85);
					end
					10'd85: begin
						h_empty <= md;
						rd(TT + (4 * ABI_T_FUNCTION), 10'd86);
					end
					10'd86: begin
						ty_fun <= mv;
						rd(TT + (4 * ABI_T_BOUND_METHOD), 10'd87);
					end
					10'd87: begin
						ty_bm <= mv;
						rd(TT + (4 * ABI_T_CELL), 10'd70);
					end
					10'd70: begin
						ty_cell <= mv;
						rd(TT + (4 * ABI_T_OBJECT), 10'd71);
					end
					10'd71: begin
						ty_obj <= mv;
						rd(TT + (4 * ABI_T_STOPITERATION), 10'd72);
					end
					10'd72: begin
						ty_stop <= mv;
						rd(TT + (4 * ABI_T_MEMORYERROR), 10'd73);
					end
					10'd73: begin
						ty_mem <= mv;
						rd(TT + (4 * ABI_T_SLICE), 10'd74);
					end
					10'd74: begin
						ty_slice <= mv;
						rd(TT + (4 * ABI_T_STR), 10'd82);
					end
					10'd82: begin
						ty_str <= mv;
						rd(h_msgs + (4 * ABI_MSG_MEMORY), 10'd75);
					end
					10'd75: begin
						wb_v[0] <= vint(ABI_OB_EXCEPTION);
						wb_v[1] <= ty_mem;
						wb_v[2] <= mv;
						wb_v[3] <= VNULL;
						wb_v[4] <= VNULL;
						wblock(EMERG_ADDR, 4'd5, 10'd76);
					end
					10'd76: begin
						ab_lo <= 8'd32;
						ab_pe <= 8'd32;
						ab_nkw <= 8'd0;
						crk <= ABI_RK_HALT;
						hk_id <= ABI_HOOK_BOOT;
						st <= 10'd241;
					end
					10'd592: begin
						wr(ab_ptr(8'd32 + i0), ab_s[i0[1:0]], (i0 == 8'd3 ? 10'd241 : 10'd592));
						i0 <= i0 + 8'd1;
					end
					10'd241:
						rd(h_hooks + (4 * hk_id), 10'd242);
					10'd242:
						if (mv == VNULL)
							halt(ABI_HALT_INTERNAL, {24'd0, hk_id});
						else
							wr(ab_ptr(8'd0), mv, 10'd94);
					10'd94:
						rd(ab_ptr(8'd0), 10'd593);
					10'd593: begin
						ab_q <= mv;
						if (tg(mv) != ABI_TAG_OBJECT)
							st <= 10'd240;
						else
							rd(adr(mv), 10'd97);
					end
					10'd97:
						case (md)
							ABI_OB_FUNCTION: begin
								c_ismod <= 1'b0;
								st <= 10'd111;
							end
							ABI_OB_BOUND_METHOD:
								rd(aoff(adr(ab_q), 12), 10'd96);
							ABI_OB_BUILTIN:
								rd(aoff(adr(ab_q), 8), 10'd99);
							ABI_OB_TYPE:
								rd(aoff(adr(ab_q), 28), 10'd100);
							default: st <= 10'd240;
						endcase
					10'd96:
						if (ab_chunked)
							st <= 10'd651;
						else if (ab_lo <= 8'd2)
							raise_err(ABI_ERR_STAR_ARGS, VNULL, VNULL);
						else begin
							wr(ab_ptr(ab_lo - 8'd1), mv, 10'd594);
							ab_lo <= ab_lo - 8'd1;
						end
					10'd594:
						rd(aoff(adr(ab_q), 8), 10'd95);
					10'd95:
						wr(ab_ptr(8'd0), mv, 10'd94);
					10'd99: begin
						nid <= md[7:0];
						st <= 10'd339;
					end
					10'd100: begin
						c_tflags <= md;
						if (md & ABI_TF_INST)
							st <= 10'd343;
						else if (((ab_q == ty_str) && !ab_chunked) && (ab_nkw == 8'd0)) begin
							if (ab_pe == ab_lo)
								deliver({ABI_TAG_QSTR, ABI_Q_EMPTY}, crk);
							else if (ab_pe == (ab_lo + 8'd1))
								rd(ab_ptr(ab_lo), 10'd101);
							else
								st <= 10'd102;
						end
						else
							rd(aoff(adr(ab_q), 32), 10'd98);
					end
					10'd101:
						if (strlike(mv))
							deliver(mv, crk);
						else
							st <= 10'd102;
					10'd102:
						rd(aoff(adr(ab_q), 32), 10'd98);
					10'd98:
						if (mv == VNULL)
							raise_err(ABI_ERR_CANT_CREATE, ab_q, VNULL);
						else if (ab_lo <= 8'd2)
							raise_err(ABI_ERR_STAR_ARGS, VNULL, VNULL);
						else begin
							ab_s[0] <= mv;
							wr(ab_ptr(ab_lo - 8'd1), ab_q, 10'd595);
							ab_lo <= ab_lo - 8'd1;
						end
					10'd595:
						wr(ab_ptr(8'd0), ab_s[0], 10'd94);
					10'd240: begin
						tb_src <= 1'b0;
						tb_nz <= 1'b0;
						tb_from <= ab_lo;
						tb_n <= sv2v_cast_16(ab_pe - ab_lo);
						gosub(10'd528, 10'd238);
					end
					10'd238: begin
						t[0] <= tb_v;
						tb_src <= 1'b0;
						tb_nz <= 1'b1;
						tb_from <= ab_pe;
						tb_n <= {8'd0, ab_nkw[6:0], 1'b0};
						gosub(10'd528, 10'd239);
					end
					10'd239:
						hook(ABI_HOOK_CALL, crk, 8'd3, ab_q, t[0], tb_v, VNULL);
					10'd343:
						if (c_tflags & ABI_TF_EXC) begin
							tb_src <= 1'b0;
							tb_nz <= 1'b0;
							tb_from <= ab_lo;
							tb_n <= sv2v_cast_16(ab_pe - ab_lo);
							gosub(10'd528, 10'd347);
						end
						else
							alloc(32'd3, 10'd344);
					10'd347: begin
						t[0] <= tb_v;
						alloc(32'd5, 10'd348);
					end
					10'd348: begin
						wb_v[0] <= vint(ABI_OB_EXCEPTION);
						wb_v[1] <= ab_q;
						wb_v[2] <= t[0];
						wb_v[3] <= VNULL;
						wb_v[4] <= VNULL;
						t[1] <= vobj(al_a);
						wblock(al_a, 4'd5, 10'd345);
					end
					10'd344: begin
						wb_v[0] <= vint(ABI_OB_INSTANCE);
						wb_v[1] <= ab_q;
						wb_v[2] <= VNULL;
						t[1] <= vobj(al_a);
						wblock(al_a, 4'd3, 10'd345);
					end
					10'd345:
						if (scr_id != SCR_AT)
							scr_ensure(SCR_AT, 10'd345);
						else begin
							sV[6] <= ab_q;
							at_ty <= 1'b1;
							at_objd <= 1'b0;
							at_q <= ABI_Q_INIT_D;
							gosub(10'd20, 10'd346);
						end
					10'd346:
						if (at_kind == 2'd1) begin
							wr(ab_ptr(ab_lo - 8'd1), t[1], 10'd596);
							ab_lo <= ab_lo - 8'd1;
							aux <= t[1];
							aux2 <= vint({28'd0, crk});
							aux3 <= vint({24'd0, fcont});
							fcont <= ABI_CONT_INIT;
							crk <= ABI_RK_CONT;
						end
						else
							deliver(t[1], crk);
					10'd596:
						wr(ab_ptr(8'd0), at_v, 10'd94);
					10'd111: begin
						ab_lo0 <= ab_lo;
						bload(ha_ab8);
						bl_n <= 8'd1;
						bl_k <= 3'd0;
						st <= 10'd112;
					end
					10'd112: begin
						if ((bl_n != 8'd5) && !m_wait) begin
							bload(ha_bl_ab);
							bl_n <= bl_n + 8'd1;
						end
						if (m_ack_i && (wpend == 3'd0)) begin
							if (m_fault_i)
								halt(fault_code(m_fault_reason_i), (adr(ab_q) + 32'd8) + {27'd0, bl_k, 2'b00});
							else begin
								bl_k <= bl_k + 3'd1;
								case (bl_k)
									3'd0: c_rc <= m_rdata_i;
									3'd1: c_clos <= {m_rtag_i, m_rdata_i};
									3'd2: c_defs <= {m_rtag_i, m_rdata_i};
									3'd3:
										;
									default: begin
										c_glob <= {m_rtag_i, m_rdata_i};
										if (c_clos != VNULL)
											rd(adr(c_clos), 10'd115);
										else
											rc_burst;
									end
								endcase
							end
						end
					end
					10'd115: begin
						c_cn <= md[7:0];
						st <= 10'd114;
					end
					10'd114:
						if (c_cn == 8'd0)
							rc_burst;
						else if (ab_lo <= 8'd2)
							raise_err(ABI_ERR_STAR_ARGS, VNULL, VNULL);
						else
							rd(adr(c_clos) + (4 * c_cn), 10'd116);
					10'd116: begin
						wr(ab_ptr(ab_lo - 8'd1), mv, 10'd114);
						ab_lo <= ab_lo - 8'd1;
						c_cn <= c_cn - 8'd1;
					end
					10'd119:
						rc_burst;
					10'd118: begin
						if ((bl_n != 8'd6) && !m_wait) begin
							bload(ha_bl_rc);
							bl_n <= bl_n + 8'd1;
						end
						if (m_ack_i && (wpend == 3'd0)) begin
							if (m_fault_i)
								halt(fault_code(m_fault_reason_i), c_rc + {27'd0, bl_k, 2'b00});
							else begin
								bl_k <= bl_k + 3'd1;
								case (bl_k)
									sv2v_cast_3(ABI_RC_OP_START): c_pc <= m_rdata_i;
									sv2v_cast_3(ABI_RC_SIG): begin
										c_nst <= m_rdata_i[7:0];
										c_nexc <= m_rdata_i[15:8];
										c_scope <= m_rdata_i[23:16];
										c_rcf <= m_rdata_i[31:24];
									end
									sv2v_cast_3(ABI_RC_ARGS): begin
										c_npos <= m_rdata_i[7:0];
										c_nkwo <= m_rdata_i[15:8];
										c_ndef <= m_rdata_i[23:16];
										c_ncell <= m_rdata_i[31:24];
									end
									sv2v_cast_3(ABI_RC_CELLS): c_cells <= m_rdata_i;
									sv2v_cast_3(ABI_RC_MODULE): begin
										c_md <= m_rdata_i;
										st <= 10'd113;
									end
									default:
										;
								endcase
							end
						end
					end
					10'd113: begin
						v0 = (noframe ? ABI_FRAME_BASE : stk_top);
						v3 = sv2v_cast_32((12'd17 + sv2v_cast_12(c_nst)) + (12'd3 * sv2v_cast_12(c_nexc)));
						v1 = (noframe ? ABI_FRAME_BASE + (v3 << 2) : fbase + {18'd0, sv2v_cast_12(stk_off) + v3[11:0], 2'b00});
						v2 = ab_pe - ab_lo;
						c_fast <= (((!ab_chunked && (ab_nkw == 8'd0)) && (c_nkwo == 8'd0)) && ((v2 + c_ndef) >= c_npos)) && ((v2 <= c_npos) || (c_scope & ABI_SCOPE_VARARGS));
						x3 <= v0;
						if (v1 > spill_hp)
							raise_msg(ABI_MSG_RECURSION);
						else if (noframe)
							st <= 10'd120;
						else
							gosub(10'd508, 10'd120);
					end
					10'd120: begin
						fprev <= (noframe ? 32'd0 : fbase);
						fbase <= x3;
						noframe <= 1'b0;
						local_base <= x3;
						local_image_word <= 17'd0;
						rc <= c_rc;
						nloc <= c_nst;
						nexc <= c_nexc[4:0];
						stack_prefix_words <= frame_prefix(c_nst, c_nexc[4:0]);
						locals_in_image <= 1'b0;
						sp <= 7'd0;
						rf_base <= 6'd0;
						spilled_reals <= 16'd0;
						rf_pend <= 1'b0;
						xsp <= 5'd0;
						i0 <= 8'd0;
						fflags <= (c_rcf & ABI_RC_FLAG_FIRMWARE ? FF_FW : 8'd0) | (c_rcf & ABI_RC_FLAG_GENERATOR ? FF_GEN : 8'd0);
						frk <= crk;
						fcont <= 8'd0;
						gen <= VNULL;
						glb <= (c_ismod ? cl_loc : c_glob);
						loc <= cl_loc;
						cl_loc <= VNULL;
						fun <= (c_ismod ? VNULL : ab_q);
						aux <= VNULL;
						aux2 <= VNULL;
						aux3 <= VNULL;
						begin : sv2v_autoblock_19
							reg signed [31:0] k;
							for (k = 0; k < MPY_RF_DEPTH; k = k + 1)
								rf[k] <= VNULL;
						end
						lc_inval;
						st <= 10'd550;
					end
					10'd550:
						if (i0 == nloc) begin
							pc <= c_pc;
							op_pc <= c_pc;
							bload(c_md + 0);
							bl_n <= 8'd1;
							bl_k <= 3'd0;
							st <= 10'd117;
						end
						else begin
							wr(loc_ptr(i0), VNULL, 10'd550);
							i0 <= i0 + 8'd1;
						end
					10'd117: begin
						if ((bl_n != 8'd2) && !m_wait) begin
							bload(c_md + 4);
							bl_n <= bl_n + 8'd1;
						end
						if (m_ack_i && (wpend == 3'd0)) begin
							if (m_fault_i)
								halt(fault_code(m_fault_reason_i), c_md + {27'd0, bl_k, 2'b00});
							else if (bl_k == 3'd0) begin
								qbase <= m_rdata_i;
								bl_k <= 3'd1;
							end
							else begin
								cbase <= m_rdata_i;
								if (c_fast)
									st <= 10'd25;
								else
									st <= 10'd88;
							end
						end
					end
					10'd25: begin
						i0 <= ab_pe - ab_lo;
						i1 <= 8'd0;
						st <= 10'd558;
					end
					10'd558:
						if ((i1 >= c_npos) || (i1 >= i0))
							st <= 10'd26;
						else
							rd(ab_ptr(ab_lo + i1), 10'd598);
					10'd598:
						wr(loc_ptr(i1), mv, 10'd559);
					10'd559: begin
						i1 <= i1 + 8'd1;
						st <= 10'd558;
					end
					10'd26:
						if (i0 >= c_npos)
							st <= 10'd30;
						else
							rd((adr(c_defs) + 4) + (4 * (i0 - (c_npos - c_ndef))), 10'd27);
					10'd27: begin
						wr(loc_ptr(i0), mv, 10'd26);
						i0 <= i0 + 8'd1;
					end
					10'd30:
						if (c_scope & ABI_SCOPE_VARARGS) begin
							tb_src <= 1'b0;
							tb_nz <= 1'b0;
							tb_from <= ab_lo + c_npos;
							tb_n <= ((ab_pe - ab_lo) > c_npos ? sv2v_cast_16((ab_pe - ab_lo) - c_npos) : 16'd0);
							gosub(10'd528, 10'd31);
						end
						else
							st <= 10'd28;
					10'd31:
						wr(loc_ptr(c_npos + c_nkwo), tb_v, 10'd28);
					10'd28: begin
						c_ci <= 32'd0;
						if (c_scope & ABI_SCOPE_VARKEYWORDS)
							alloc(32'd4, 10'd29);
						else
							st <= 10'd108;
					end
					10'd29: begin
						wb_v[0] <= vint(32'd0);
						wb_v[1] <= vint(32'd0);
						wb_v[2] <= VNULL;
						wb_v[3] <= vint(32'd0);
						i1 <= (c_npos + c_nkwo) + (c_scope & ABI_SCOPE_VARARGS ? 8'd1 : 8'd0);
						wblock(al_a, 4'd4, 10'd560);
					end
					10'd560:
						wr(loc_ptr(i1), vmut(al_a, ABI_MUT_DICT), 10'd108);
					10'd108:
						if (c_ci == c_ncell) begin
							fflags <= fflags & ~FF_NOTB;
							if (fflags & FF_GEN)
								st <= 10'd164;
							else
								st <= 10'd147;
						end
						else
							rd(c_cells + (4 * c_ci), 10'd110);
					10'd110: begin
						i1 <= md[7:0];
						rd(loc_ptr(md[7:0]), 10'd561);
					end
					10'd561: begin
						t[3] <= mv;
						alloc(32'd3, 10'd109);
					end
					10'd109: begin
						wb_v[0] <= vint(ABI_OB_CELL);
						wb_v[1] <= ty_cell;
						wb_v[2] <= t[3];
						c_ci <= c_ci + 32'd1;
						wblock(al_a, 4'd3, 10'd562);
					end
					10'd562:
						wr(loc_ptr(i1), vobj(al_a), 10'd108);
					10'd88:
						if (ab_chunked)
							st <= 10'd659;
						else
							rd(ab_ptr(8'd0), 10'd597);
					10'd597: begin
						fflags <= fflags | FF_NOTB;
						fcont <= ABI_CONT_BIND;
						t[2] <= mv;
						tb_src <= 1'b0;
						tb_nz <= 1'b0;
						tb_from <= ab_lo;
						tb_n <= sv2v_cast_16(ab_pe - ab_lo);
						gosub(10'd528, 10'd89);
					end
					10'd89: begin
						t[0] <= tb_v;
						tb_src <= 1'b0;
						tb_nz <= 1'b1;
						tb_from <= ab_pe;
						tb_n <= {8'd0, ab_nkw[6:0], 1'b0};
						gosub(10'd528, 10'd90);
					end
					10'd90:
						hook(ABI_HOOK_BIND, ABI_RK_CONT, 8'd3, t[2], t[0], tb_v, VNULL);
					10'd121: begin
						c_rc <= md;
						c_defs <= VNULL;
						c_clos <= VNULL;
						st <= 10'd119;
					end
					10'd508:
						if (lc_dirty_any) begin
							lc_fi <= 4'd0;
							lc_fl_ret <= 10'd508;
							st <= 10'd555;
						end
						else begin
							sw_i <= (spill_to_img && locals_in_image ? 32'd2 : 32'd0);
							sw_k <= 2'd0;
							gosub(10'd588, 10'd509);
						end
					10'd509:
						if (sw_i == 32'd17) begin
							sw_i <= 32'd0;
							sw_k <= 2'd0;
							st <= (spill_to_img && !locals_in_image ? 10'd510 : 10'd512);
						end
						else begin
							wr(fbase + (sw_i << 2), hdr_word(sw_i), 10'd509);
							if ((spill_to_img && locals_in_image) && (sw_i == 32'd5))
								sw_i <= 32'd9;
							else if ((spill_to_img && locals_in_image) && (sw_i == 32'd11))
								sw_i <= 32'd15;
							else
								sw_i <= sw_i + 32'd1;
						end
					10'd510:
						if (sw_i == nloc) begin
							sw_i <= 32'd0;
							sw_k <= 2'd0;
							st <= 10'd513;
						end
						else
							rd((x4 + 32'h00000044) + (sw_i << 2), 10'd511);
					10'd511: begin
						wr((fbase + 32'h00000044) + (sw_i << 2), mv, 10'd510);
						sw_i <= sw_i + 32'd1;
					end
					10'd513:
						if (sw_i == (sv2v_cast_32(xsp) * 32'd3)) begin
							sw_i <= 32'd0;
							st <= 10'd512;
						end
						else if (sw_k == 2'd0) begin
							rd(exc_words(x4) + (sw_i << 2), 10'd513);
							sw_k <= 2'd1;
						end
						else begin
							wr(exc_words(fbase) + (sw_i << 2), mv, 10'd513);
							sw_k <= 2'd0;
							sw_i <= sw_i + 32'd1;
						end
					10'd512:
						if (sw_i == sp)
							ret;
						else begin
							wr(ftop + (sw_i << 2), rf[rf_base[3:0] + sv2v_cast_4(sw_i[6:0])], 10'd512);
							sw_i <= sw_i + 32'd1;
						end
					10'd148: begin
						fl_i <= 32'd0;
						bl_n <= 8'd0;
						fe_flush <= 1'b1;
						lc_inval;
						if (!fl_img)
							fbase <= fl_base;
						st <= 10'd156;
					end
					10'd156: begin
						if ((bl_n != 8'd17) && !m_wait) begin
							bload(ha_bl_fl);
							bl_n <= bl_n + 8'd1;
						end
						if (m_ack_i && (wpend == 3'd0)) begin
							if (m_fault_i)
								halt(fault_code(m_fault_reason_i), fl_base + (fl_i << 2));
							else begin
								case (fl_i)
									4'd0:
										if (!fl_img)
											fprev <= m_rdata_i;
									4'd1: rc <= m_rdata_i;
									4'd2: pc <= m_rdata_i;
									4'd3: op_pc <= m_rdata_i;
									4'd4: begin
										sp <= m_rdata_i[6:0];
										xsp <= m_rdata_i[12:8];
										fflags <= m_rdata_i[31:24];
										if (!fl_img)
											locals_in_image <= m_rdata_i[7];
									end
									4'd5: begin
										frk <= m_rdata_i[3:0];
										fcont <= m_rdata_i[15:8];
										nexc <= m_rdata_i[20:16];
										if (!fl_img)
											local_image_word[16:2] <= {m_rdata_i[31:21], m_rdata_i[7:4]};
									end
									4'd6: glb <= {m_rtag_i, m_rdata_i};
									4'd7: loc <= {m_rtag_i, m_rdata_i};
									4'd8: fun <= {m_rtag_i, m_rdata_i};
									4'd9: aux <= {m_rtag_i, m_rdata_i};
									4'd10: aux2 <= {m_rtag_i, m_rdata_i};
									4'd11: aux3 <= {m_rtag_i, m_rdata_i};
									4'd12: qbase <= m_rdata_i;
									4'd13: cbase <= m_rdata_i;
									4'd14: gen <= {m_rtag_i, m_rdata_i};
									4'd15: spill_hp <= m_rdata_i;
									default:
										if (fl_i == 32'd16) begin
											rf_base <= m_rdata_i[5:0];
											nloc <= m_rdata_i[13:6];
											stack_prefix_words <= frame_prefix((locals_in_image ? 8'd0 : m_rdata_i[13:6]), nexc);
											spilled_reals <= m_rdata_i[29:14];
											exc_base <= (fl_base + 32'h00000044) + ({24'd0, m_rdata_i[13:6]} << 2);
											if (!fl_img) begin
												local_image_word[1:0] <= m_rdata_i[31:30];
												local_base <= (locals_in_image ? MPY_SRAM_BASE | {13'd0, local_image_word[16:2], m_rdata_i[31:30], 2'b00} : fl_base);
											end
											stack_base <= fl_base + {21'd0, frame_prefix((fl_img || !locals_in_image ? m_rdata_i[13:6] : 8'd0), nexc), 2'b00};
										end
								endcase
								md <= m_rdata_i;
								mt <= m_rtag_i;
								if (fl_i == 32'd16) begin
									fl_i <= 32'd0;
									fl_k <= 2'd0;
									bl_n <= 8'd0;
									if (fl_img && locals_in_image) begin
										fl_img <= 1'b0;
										st <= 10'd585;
									end
									else if (fl_img)
										st <= 10'd583;
									else begin
										sw_k <= 2'd0;
										gosub(10'd589, 10'd585);
									end
								end
								else
									fl_i <= fl_i + 32'd1;
							end
						end
					end
					10'd583:
						if (fl_i == nloc) begin
							fl_i <= 32'd0;
							fl_k <= 2'd0;
							st <= 10'd159;
						end
						else
							rd((fl_base + 32'h00000044) + (fl_i << 2), 10'd584);
					10'd584: begin
						wr((fbase + 32'h00000044) + (fl_i << 2), mv, 10'd583);
						fl_i <= fl_i + 32'd1;
					end
					10'd159:
						if (fl_i == (sv2v_cast_32(xsp) * 32'd3)) begin
							fl_i <= 32'd0;
							bl_n <= 8'd0;
							fl_img <= 1'b0;
							sw_k <= 2'd0;
							gosub(10'd589, 10'd585);
						end
						else
							rd(exc_base + (fl_i << 2), 10'd158);
					10'd158: begin
						wr(exc_words(fbase) + (fl_i << 2), mv, 10'd159);
						fl_i <= fl_i + 32'd1;
					end
					10'd585:
						if (fl_i == sv2v_cast_32(sp))
							ret;
						else begin
							if ((bl_n != {1'b0, sp}) && !m_wait) begin
								bload(ha_bl_stk);
								bl_n <= bl_n + 8'd1;
							end
							if (m_ack_i && (wpend == 3'd0)) begin
								if (m_fault_i)
									halt(fault_code(m_fault_reason_i), stack_base + (fl_i << 2));
								else begin
									rf[rf_base[3:0] + sv2v_cast_4(fl_i[6:0])] <= {m_rtag_i, m_rdata_i};
									fl_i <= fl_i + 32'd1;
								end
							end
						end
					10'd444:
						if (frk == ABI_RK_HALT)
							halt(ABI_HALT_CLEAN, 32'd0);
						else begin
							r_rk <= frk;
							fl_base <= fprev;
							gosub(10'd148, 10'd445);
						end
					10'd445: begin
						d_rk <= r_rk;
						st <= 10'd134;
					end
					10'd134:
						case (d_rk)
							ABI_RK_PUSH: begin
								push(t[7]);
								st <= 10'd147;
							end
							ABI_RK_DISCARD: st <= 10'd147;
							ABI_RK_PUSH_NULL: begin
								rf[rf_base[3:0] + sv2v_cast_4(sp)] <= t[7];
								rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd1))] <= VNULL;
								sp <= sp + 7'd2;
								st <= 10'd147;
							end
							ABI_RK_CONT: st <= 10'd122;
							default:
								halt(ABI_HALT_CLEAN, 32'd0);
						endcase
					10'd122:
						case (fcont)
							ABI_CONT_REDISPATCH: begin
								op <= aux[7:0];
								st <= 10'd139;
							end
							ABI_CONT_REPLACE: begin
								rf[rf_base[3:0] + sv2v_cast_4(aux[6:0])] <= t[7];
								pc <= op_pc;
								st <= 10'd147;
							end
							ABI_CONT_INIT:
								if (t[7] != VNONE)
									raise_err(ABI_ERR_INIT_NONE, t[7], VNULL);
								else begin
									fcont <= aux3[7:0];
									deliver(aux, aux2[3:0]);
								end
							ABI_CONT_WITH_ENTER: begin
								x0 <= aux[31:0];
								b0 <= 1'b1;
								x1 <= {16'd0, stk_depth};
								sw_k <= 2'd0;
								push(t[7]);
								gosub(10'd586, 10'd147);
							end
							ABI_CONT_WITH_NONE: begin
								push(VNONE);
								st <= 10'd147;
							end
							ABI_CONT_WITH_UNWIND: begin
								rf[rf_base[3:0] + sv2v_cast_4(sp)] <= aux;
								rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd1))] <= aux2;
								sp <= sp + 7'd2;
								st <= 10'd147;
							end
							ABI_CONT_WITH_EXC: begin
								tr_v <= t[7];
								gosub(10'd524, 10'd549);
							end
							ABI_CONT_UNPACK:
								rd(adr(t[7]), 10'd538);
							ABI_CONT_RAISE:
								raise_val(t[7]);
							ABI_CONT_TRUTH: begin
								ovr <= (t[7] == VTRUE ? ABI_OVR_TRUE : ABI_OVR_FALSE);
								pc <= op_pc;
								st <= 10'd147;
							end
							ABI_CONT_WITH_TRUTH: begin
								push((t[7] == VTRUE ? VNONE : aux));
								st <= 10'd147;
							end
							ABI_CONT_WITH_ATTR: begin
								t[0] <= aux3;
								jt <= aux[31:0];
								if (aux2 == vint(32'd0)) begin
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= t[7];
									rf[rf_base[3:0] + sv2v_cast_4(sp)] <= VNULL;
									sp <= sp + 7'd1;
									at_q <= ABI_Q_ENTER_D;
									gosub_scr(SCR_AT, 10'd9, 10'd522);
								end
								else begin
									at_v <= t[7];
									at_kind <= 2'd1;
									st <= 10'd522;
								end
							end
							ABI_CONT_FOR_NEXT:
								if (t[7] == VSTOP) begin
									sp <= sp - 7'd4;
									pc <= aux[31:0];
									st <= 10'd147;
								end
								else begin
									push(t[7]);
									st <= 10'd147;
								end
							ABI_CONT_GETITER: begin
								rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= t[7];
								ovr <= ABI_OVR_PYOBJ;
								pc <= op_pc;
								st <= 10'd147;
							end
							ABI_CONT_BIND:
								rd(adr(t[7]), 10'd106);
							ABI_CONT_YFROM:
								if (fflags & FF_YFAST) begin
									fflags <= fflags & ~FF_YFAST;
									push(t[7]);
									pc <= op_pc;
									st <= 10'd193;
								end
								else
									rd(aoff(adr(t[7]), 4), 10'd196);
							ABI_CONT_SPILL_REPLACE:
								if (!has_link)
									halt(ABI_HALT_INTERNAL, 32'h0000c0c0);
								else begin
									srd_g <= aux[15:0];
									srd_addr <= mpy_rf_link_addr(rf[rf_base[3:0] + 4'd0]);
									srd_off <= (spilled_reals - 16'd1) - aux[15:0];
									srd_hops <= 16'd0;
									st <= 10'd611;
								end
							default:
								halt(ABI_HALT_INTERNAL, {24'd0, fcont});
						endcase
					10'd549:
						if (tr_x) begin
							fcont <= ABI_CONT_WITH_TRUTH;
							hook(ABI_HOOK_TRUTH, ABI_RK_CONT, 8'd1, tr_v, VNULL, VNULL, VNULL);
						end
						else begin
							push((tr_r ? VNONE : aux));
							st <= 10'd147;
						end
					10'd538: begin
						x1 <= md;
						st <= 10'd537;
					end
					10'd537:
						if (x1 == 32'd0)
							st <= 10'd147;
						else
							rd(adr(t[7]) + (x1 << 2), 10'd539);
					10'd539: begin
						x1 <= x1 - 32'd1;
						push(mv);
						st <= 10'd537;
					end
					10'd106: begin
						x1 <= md;
						i0 <= 8'd0;
						st <= 10'd105;
					end
					10'd105:
						if (i0 == x1[7:0])
							rd(rc + 8, 10'd103);
						else
							rd((adr(t[7]) + 4) + (4 * i0), 10'd107);
					10'd107: begin
						wr(loc_ptr(i0), mv, 10'd105);
						i0 <= i0 + 8'd1;
					end
					10'd103: begin
						c_ncell <= md[31:24];
						rd(rc + 16, 10'd104);
					end
					10'd104: begin
						c_cells <= md;
						c_ci <= 32'd0;
						fcont <= 8'd0;
						st <= 10'd108;
					end
					10'd462:
						if (aalu_pend) begin
							if (aalu_go) begin
								aalu_ret <= 10'd462;
								st <= 10'd777;
							end
						end
						else
							alloc(32'd5, 10'd463);
					10'd463:
						rd(h_msgs + (4 * rm_id), 10'd464);
					10'd464: begin
						t[0] <= mv;
						rd(TT + (4 * msg_type(rm_id)), 10'd465);
					end
					10'd465: begin
						wb_v[0] <= vint(ABI_OB_EXCEPTION);
						wb_v[1] <= mv;
						wb_v[2] <= t[0];
						wb_v[3] <= VNULL;
						wb_v[4] <= VNULL;
						xc <= vobj(al_a);
						wblock(al_a, 4'd5, 10'd466);
					end
					10'd466: begin
						rx_from <= 1'b0;
						rsp <= 5'd0;
						st <= 10'd442;
					end
					10'd442:
						if (aalu_pend) begin
							if (aalu_go) begin
								aalu_ret <= 10'd442;
								st <= 10'd777;
							end
						end
						else if (((rx_from && (rx_crk == ABI_RK_CONT)) && (fcont == ABI_CONT_FOR_NEXT)) || (!rx_from && (op == 8'h4b)))
							rd(aoff(adr(xc), 4), 10'd472);
						else if ((rx_from && (rx_crk == ABI_RK_CONT)) && (fcont == ABI_CONT_YFROM))
							rd(aoff(adr(xc), 4), 10'd204);
						else
							st <= 10'd474;
					10'd472: begin
						is_t <= mv;
						is_c <= ty_stop;
						gosub(10'd249, 10'd473);
					end
					10'd473:
						if (is_r) begin
							sp <= sp - 7'd4;
							pc <= aux[31:0];
							st <= 10'd147;
						end
						else
							st <= 10'd474;
					10'd474:
						if ((fflags & (FF_NOTB | FF_FW)) || (!rx_from && ((op == 8'h5d) || (op == 8'h64))))
							st <= 10'd470;
						else
							rd(rc + 0, 10'd475);
					10'd475: begin
						rx_off <= op_pc - md;
						rd(aoff(adr(xc), 12), 10'd476);
					end
					10'd476:
						if (mv == VNULL) begin
							al_soft <= 1'b1;
							alloc(32'd7, 10'd481);
						end
						else begin
							t[2] <= mv;
							st <= 10'd477;
						end
					10'd481:
						if (!al_ok) begin
							al_soft <= 1'b0;
							st <= 10'd470;
						end
						else begin
							wb_v[0] <= vint(32'd0);
							wb_v[1] <= vint(32'd4);
							wb_v[2] <= {ABI_TAG_CONT, al_a + 32'd12};
							t[2] <= vmut(al_a, ABI_MUT_LIST);
							wblock(al_a, 4'd3, 10'd480);
						end
					10'd480:
						wr(aoff(adr(xc), 12), t[2], 10'd477);
					10'd477: begin
						t[3] <= vint(rc);
						al_soft <= 1'b1;
						gosub_scr(SCR_LA, 10'd280, 10'd478);
					end
					10'd478: begin
						t[3] <= vint(rx_off);
						gosub_scr(SCR_LA, 10'd280, 10'd479);
					end
					10'd479: begin
						al_soft <= 1'b0;
						st <= 10'd470;
					end
					10'd470:
						if ((xsp != 5'd0) && (xh <= op_pc)) begin
							sw_k <= 2'd0;
							gosub(10'd587, 10'd470);
						end
						else if (xsp != 5'd0)
							st <= 10'd443;
						else if ((gen != VNULL) && (fprev != 32'd0)) begin
							pc <= 32'd0;
							st <= 10'd170;
						end
						else if (fprev == 32'd0)
							halt(ABI_HALT_UNCAUGHT, xc[31:0]);
						else begin
							rx_crk <= frk;
							fl_base <= fprev;
							gosub(10'd148, 10'd471);
						end
					10'd443: begin
						pc <= xh;
						xp <= xc;
						drop_left <= (stk_depth > xv ? stk_depth - xv : 16'd0);
						drop_push_en <= 1'b1;
						drop_push_v <= xc;
						drop_then <= 10'd147;
						st <= 10'd580;
					end
					10'd471: begin
						rx_from <= 1'b1;
						st <= 10'd442;
					end
					10'd147:
						if (ca_fault_i)
							case (ca_fault_reason_i)
								MPY_FAULT_UNALIGNED:
									halt(ABI_HALT_UNALIGNED, ca_fault_addr_i);
								MPY_FAULT_FLASH_STORE:
									halt(ABI_HALT_FLASH_STORE, ca_fault_addr_i);
								default:
									halt(ABI_HALT_BUS, ca_fault_addr_i);
							endcase
						else if (aalu_pend && (((sp >= sv2v_cast_7_signed(RF_SPILL_AT)) || (has_link && (sp <= sv2v_cast_7_signed(RF_RELOAD_AT)))) || (soft_pt && evt_q))) begin
							if (aalu_go) begin
								aalu_ret <= 10'd147;
								st <= 10'd777;
							end
						end
						else if (sp >= sv2v_cast_7_signed(RF_SPILL_AT)) begin
							rf_resume <= 10'd147;
							st <= 10'd563;
						end
						else if (has_link && (sp <= sv2v_cast_7_signed(RF_RELOAD_AT))) begin
							rf_resume <= 10'd147;
							st <= 10'd566;
						end
						else if (soft_pt && evt_q)
							st <= 10'd811;
						else if (fe_avail != 6'd0) begin
							dq_bytes <= d_bytes;
							dq_n <= d_n;
							st <= 10'd132;
						end
						else if (fe_fault && (fe_fault_addr[31:2] == pc[31:2]))
							fetch_fault;
					10'd132:
						if ((ca_fault_i || (sp >= sv2v_cast_7_signed(RF_SPILL_AT))) || (has_link && (sp <= sv2v_cast_7_signed(RF_RELOAD_AT))))
							st <= 10'd147;
						else if (d_trunc) begin
							if (dq_n == 4'd8)
								halt(ABI_HALT_BAD_OPCODE, pc);
							else if (fe_fault)
								fetch_fault;
							else
								st <= 10'd147;
						end
						else if (d_illegal || !d_valid)
							halt(ABI_HALT_BAD_OPCODE, pc);
						else begin
							op <= d_op;
							arg <= d_arg;
							ext <= d_ext;
							op_pc <= pc;
							pc <= pc + d_len;
							soft_pt <= 1'b0;
							extv <= d_extv;
							nops <= nops + 32'd1;
							trace <= 1'b1;
							st <= 10'd139;
						end
					10'd139: begin
						jt <= jt_c;
						if (aalu_pend && !aalu_pass(op)) begin
							if (aalu_go) begin
								aalu_ret <= 10'd139;
								st <= 10'd777;
							end
						end
						else if (((op >= 8'hb0) && (op < 8'hc0)) || (op == 8'h24)) begin
							vi = (op == 8'h24 ? arg[7:0] : op - 8'hb0);
							if (lc_is_hit(vi)) begin
								vs0 = {4'd0, lc_hit_way(vi)};
								if ((lc_d[vs0[2:0]] == VNULL) && !(fflags & FF_FW))
									raise_msg(ABI_MSG_LOCAL_UNBOUND);
								else begin
									push(lc_d[vs0[2:0]]);
									lc_note(vs0[2:0]);
									go_next;
								end
							end
							else begin
								i0 <= vi;
								rd(loc_ptr(vi), 10'd553);
							end
						end
						else if (((op >= 8'hc0) && (op < 8'hd0)) || (op == 8'h26)) begin
							vi = (op == 8'h26 ? arg[7:0] : op - 8'hc0);
							if ((cfg_lc_n != 4'd0) && cfg_lc_wb) begin
								sp <= sp - 7'd1;
								lc_fill(vi, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], 1'b1, 1'b1, 10'd147);
							end
							else begin
								wr(loc_ptr(vi), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], 10'd147);
								sp <= sp - 7'd1;
								if (cfg_lc_n != 4'd0)
									lc_fill(vi, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], 1'b0, 1'b0, 10'd147);
							end
						end
						else if ((((op == 8'h25) || (op == 8'h27)) || (op == 8'h29)) || (op == 8'h28)) begin
							vi = arg[7:0];
							if (lc_is_hit(vi)) begin
								vs0 = {4'd0, lc_hit_way(vi)};
								lc_note(vs0[2:0]);
								if ((lc_d[vs0[2:0]] == VNULL) && ((op == 8'h28) || !(fflags & FF_FW)))
									raise_msg(ABI_MSG_LOCAL_UNBOUND);
								else if (op == 8'h25)
									rd(aoff(adr(lc_d[vs0[2:0]]), 8), 10'd135);
								else if (op == 8'h27) begin
									wr(aoff(adr(lc_d[vs0[2:0]]), 8), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], 10'd147);
									sp <= sp - 7'd1;
								end
								else if (op == 8'h29)
									rd(aoff(adr(lc_d[vs0[2:0]]), 8), 10'd133);
								else begin
									wr(loc_ptr(vi), VNULL, 10'd147);
									lc_v[vs0[2:0]] <= 1'b0;
									lc_dirty[vs0[2:0]] <= 1'b0;
								end
							end
							else begin
								i0 <= vi;
								if (op == 8'h25)
									rd(loc_ptr(vi), 10'd552);
								else if (op == 8'h27)
									rd(loc_ptr(vi), 10'd557);
								else if (op == 8'h29)
									rd(loc_ptr(vi), 10'd556);
								else
									rd(loc_ptr(vi), 10'd551);
							end
						end
						else if ((op >= 8'h70) && (op < 8'hb0)) begin
							push(vint(sv2v_cast_32(op) - 32'h00000080));
							go_next;
						end
						else if ((op >= 8'hd0) && (op < 8'hd7)) begin
							n_o <= op - 8'hd0;
							st <= 10'd536;
						end
						else if ((op >= 8'hd7) && (op < 8'hfa)) begin
							n_o <= op - 8'hd7;
							st <= 10'd32;
						end
						else
							case (op)
								8'h10:
									rd(ha_qarg, 10'd295);
								8'h22: begin
									push(vint(arg));
									go_next;
								end
								8'h23:
									rd(ha_carg, 10'd294);
								8'h50: begin
									push(VFALSE);
									go_next;
								end
								8'h51: begin
									push(VNONE);
									go_next;
								end
								8'h52: begin
									push(VTRUE);
									go_next;
								end
								8'h53: begin
									push(VNULL);
									go_next;
								end
								8'h24, 8'h25, 8'h26, 8'h27, 8'h28, 8'h29:
									halt(ABI_HALT_INTERNAL, 32'h000010ca);
								8'h11, 8'h12, 8'h16, 8'h17, 8'h19, 8'h1a, 8'h13, 8'h14, 8'h18, 8'h15, 8'h1b, 8'h1c:
									rd(ha_qarg, 10'd441);
								8'h54:
									rd(h_hooks + (4 * ABI_HOOK_BUILD_CLASS), 10'd294);
								8'h55: begin
									t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))];
									t[1] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									st <= 10'd322;
								end
								8'h56: begin
									t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))];
									t[1] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									t[6] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))];
									st <= 10'd514;
								end
								8'h57: begin
									push(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]);
									go_next;
								end
								8'h58: begin
									rf[rf_base[3:0] + sv2v_cast_4(sp)] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))];
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd1))] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									sp <= sp + 7'd2;
									go_next;
								end
								8'h59: begin
									sp <= sp - 7'd1;
									go_next;
								end
								8'h5a: begin
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))];
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									go_next;
								end
								8'h5b: begin
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))];
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))];
									go_next;
								end
								8'h42: begin
									pc <= jt_c;
									st <= 10'd147;
									soft_pt <= !(fflags & FF_FW);
								end
								8'h43, 8'h44, 8'h45, 8'h46: begin
									tr_v <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									gosub(10'd524, 10'd267);
								end
								8'h47: begin
									t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									at_q <= ABI_Q_EXIT_D;
									gosub_scr(SCR_AT, 10'd9, 10'd523);
								end
								8'h48, 8'h49:
									if (xsp >= nexc)
										halt(ABI_HALT_INTERNAL, op_pc);
									else begin
										x0 <= jt_c;
										b0 <= op == 8'h49;
										x1 <= {16'd0, stk_depth};
										sw_k <= 2'd0;
										gosub(10'd586, 10'd147);
									end
								8'h4a: begin
									pc <= jt_c;
									sw_k <= 2'd0;
									gosub(10'd587, 10'd147);
									soft_pt <= !(fflags & FF_FW);
								end
								8'h40: begin
									rf[rf_base[3:0] + sv2v_cast_4(sp)] <= vint(jt_c);
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd1))] <= vint({24'd0, ext});
									sp <= sp + 7'd2;
									st <= 10'd534;
								end
								8'h5c: st <= 10'd547;
								8'h5d: begin
									sw_k <= 2'd0;
									gosub(10'd587, 10'd591);
								end
								8'h63: st <= 10'd544;
								8'h64:
									if ((xsp != 5'd0) && (xp != VNULL)) begin
										xc <= xp;
										rx_from <= 1'b0;
										rsp <= 5'd0;
										st <= 10'd442;
									end
									else if (xsp < 5'd2)
										raise_msg(ABI_MSG_NO_ACTIVE_EXC);
									else begin
										sw_i <= sv2v_cast_32(xsp - 5'd2);
										sw_k <= 2'd0;
										st <= 10'd590;
									end
								8'h65: begin
									t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									sp <= sp - 7'd1;
									st <= 10'd467;
								end
								8'h66:
									if (rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] != VNONE) begin
										sp <= sp - 7'd1;
										aux <= vint(32'h00000065);
										fcont <= ABI_CONT_REDISPATCH;
										hook(ABI_HOOK_WARN, ABI_RK_CONT, 8'd1, vint(32'd0), VNULL, VNULL, VNULL);
									end
									else begin
										op <= 8'h65;
										sp <= sp - 7'd1;
									end
								8'h5e: begin
									t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									st <= 10'd215;
								end
								8'h5f: begin
									t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									b1 <= ovr == ABI_OVR_PYOBJ;
									ovr <= ABI_OVR_NONE;
									st <= 10'd214;
								end
								8'h4b: st <= 10'd771;
								8'h2a: begin
									tb_src <= 1'b1;
									tb_nz <= 1'b0;
									tb_from <= sv2v_cast_8(sp - sv2v_cast_7(arg));
									stk_from <= stk_depth - sv2v_cast_16(arg);
									tb_n <= arg[15:0];
									gosub(10'd528, 10'd93);
								end
								8'h2b:
									alloc(32'd3 + (arg < 32'd4 ? 32'd4 : arg), 10'd66);
								8'h2c:
									alloc(32'd4 + (2 * arg), 10'd68);
								8'h2d: begin
									tb_src <= 1'b1;
									tb_nz <= 1'b0;
									tb_from <= sv2v_cast_8(sp - sv2v_cast_7(arg));
									stk_from <= stk_depth - sv2v_cast_16(arg);
									tb_n <= arg[15:0];
									gosub(10'd528, 10'd91);
								end
								8'h2e:
									alloc(32'd5, 10'd506);
								8'h2f: begin
									vs0 = sv2v_cast_7((sp - 7'd1) - sv2v_cast_7(arg >> 2));
									case (arg[1:0])
										2'd0: begin
											t[2] <= rf[rf_base[3:0] + sv2v_cast_4(vs0)];
											t[3] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
											gosub_scr(SCR_LA, 10'd280, 10'd493);
										end
										2'd1:
											lookup(rf[rf_base[3:0] + sv2v_cast_4(vs0)], rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))], LK_ADD, 1'b0, 10'd492);
										default:
											lookup(rf[rf_base[3:0] + sv2v_cast_4(vs0)], rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], VNULL, LK_ADD, 1'b1, 10'd494);
									endcase
								end
								8'h62:
									lookup(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))], rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))], LK_ADD, 1'b0, 10'd520);
								8'h30: begin
									t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									if ((tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]) == ABI_TAG_TUPLE) || is_mut(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], ABI_MUT_LIST))
										rd(adr(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]), 10'd541);
									else begin
										sp <= sp - 7'd1;
										fcont <= ABI_CONT_UNPACK;
										hook(ABI_HOOK_UNPACK, ABI_RK_CONT, 8'd3, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], vint(arg), vint(32'd0), VNULL);
									end
								end
								8'h31: begin
									sp <= sp - 7'd1;
									fcont <= ABI_CONT_UNPACK;
									hook(ABI_HOOK_UNPACK, ABI_RK_CONT, 8'd3, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], vint(arg), vint(32'd1), VNULL);
								end
								8'h32, 8'h33, 8'h20, 8'h21:
									rd(rc + 24, 10'd334);
								8'h34, 8'h36: begin
									ab_chunked <= 1'b0;
									v0 = {24'd0, arg[7:0]};
									v1 = {24'd0, arg[15:8]};
									v2 = (v0 + (v1 << 1)) + (op == 8'h36 ? 32'd2 : 32'd1);
									if (v2 <= sv2v_cast_32(resident_reals)) begin
										rf_reload_miss <= 1'b0;
										vs0 = sv2v_cast_7((sp - sv2v_cast_7(v0)) - sv2v_cast_7(2 * v1));
										vs1 = vs0 - (op == 8'h36 ? 7'd2 : 7'd1);
										s0 <= vs0;
										s1 <= vs1;
										x1 <= v0 + (v1 << 1);
										i0 <= 8'd0;
										if ((op == 8'h36) && (rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(vs1 + 7'd1))] != VNULL)) begin
											b1 <= 1'b1;
											ab_lo <= 8'd31;
										end
										else begin
											b1 <= 1'b0;
											ab_lo <= 8'd32;
										end
										ab_pe <= 8'd32 + v0[7:0];
										ab_nkw <= v1[7:0];
										sp <= vs1;
										crk <= ABI_RK_PUSH;
										wr(ab_ptr(8'd0), rf[rf_base[3:0] + sv2v_cast_4(vs1)], 10'd599);
									end
									else if ((has_link && !rf_reload_miss) && (v2 <= MPY_RF_DEPTH)) begin
										rf_resume <= 10'd139;
										st <= 10'd566;
									end
									else if ((v0 + (v1 << 1)) > 32'd224)
										raise_err(ABI_ERR_STAR_ARGS, VNULL, VNULL);
									else begin
										rf_reload_miss <= 1'b0;
										b0 <= op == 8'h36;
										x4 <= v0;
										x1 <= v0 + (v1 << 1);
										ab_nkw <= v1[7:0];
										x0 <= sv2v_cast_32(stk_depth) - v2;
										x2 <= (sv2v_cast_32(stk_depth) - v2) + (op == 8'h36 ? 32'd2 : 32'd1);
										x3 <= v2;
										gi <= 32'd0;
										st <= 10'd573;
									end
								end
								8'h35, 8'h37: begin
									v0 = {24'd0, arg[7:0]};
									v1 = {24'd0, arg[15:8]};
									v2 = ((v0 + (v1 << 1)) + 32'd2) + (op == 8'h37 ? 32'd1 : 32'd0);
									ab_chunked <= 1'b0;
									cv_wide <= v2 > sv2v_cast_32(resident_reals);
									cv_pos_g <= ((stk_depth - 16'd1) - v0[15:0]) - {v1[14:0], 1'b0};
									cv_fun_g <= (((stk_depth - 16'd1) - v0[15:0]) - {v1[14:0], 1'b0}) - (op == 8'h37 ? 16'd2 : 16'd1);
									cv_base <= sv2v_cast_7(((sp - 7'd1) - sv2v_cast_7(v0)) - sv2v_cast_7(2 * v1));
									cv_fidx <= sv2v_cast_7((((sp - 7'd1) - sv2v_cast_7(v0)) - sv2v_cast_7(2 * v1)) - (op == 8'h37 ? 7'd2 : 7'd1));
									cv_bm <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))][31:0];
									cv_n <= v0[7:0];
									cv_j <= v1[7:0];
									cv_i <= 8'd0;
									st <= 10'd127;
								end
								8'h67:
									if (gen == VNULL)
										raise_err(ABI_ERR_GENERATOR, VNULL, VNULL);
									else
										st <= 10'd193;
								8'h68: begin
									fflags <= fflags & ~FF_YFAST;
									if (((inj == VNONE) && (rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] == VNONE)) && (tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))]) == ABI_TAG_OBJECT))
										rd(adr(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))]), 10'd197);
									else begin
										aux <= inj;
										fcont <= ABI_CONT_YFROM;
										hook(ABI_HOOK_YFROM, ABI_RK_CONT, 8'd3, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))], (inj != VNONE ? VNONE : rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]), (inj != VNONE ? inj : VNONE), VNULL);
										inj <= VNONE;
										sp <= sp - 7'd1;
									end
								end
								8'h69: begin
									sp <= sp - 7'd1;
									hook(ABI_HOOK_IMPORT_STAR, ABI_RK_DISCARD, 8'd2, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], (loc == VNULL ? glb : loc), VNULL, VNULL);
								end
								default:
									halt(ABI_HALT_BAD_OPCODE, op_pc);
							endcase
					end
					10'd295: begin
						push({ABI_TAG_QSTR, md});
						st <= 10'd147;
					end
					10'd294: begin
						push(mv);
						st <= 10'd147;
					end
					10'd553:
						if ((mv == VNULL) && !(fflags & FF_FW))
							raise_msg(ABI_MSG_LOCAL_UNBOUND);
						else begin
							push(mv);
							lc_fill(i0, mv, 1'b0, 1'b1, 10'd147);
						end
					10'd554: begin
						lc_v[lc_ev_way] <= 1'b1;
						lc_ix[lc_ev_way] <= lc_ev_idx;
						lc_d[lc_ev_way] <= lc_ev_val;
						lc_dirty[lc_ev_way] <= lc_ev_dirty;
						lc_note(lc_ev_way);
						st <= 10'd147;
					end
					10'd555:
						if (lc_fi >= cfg_lc_n) begin
							lc_fi <= 4'd0;
							st <= lc_fl_ret;
						end
						else if (lc_v[lc_fi[2:0]] && lc_dirty[lc_fi[2:0]]) begin
							lc_dirty[lc_fi[2:0]] <= 1'b0;
							wr(loc_ptr(lc_ix[lc_fi[2:0]]), lc_d[lc_fi[2:0]], 10'd555);
							lc_fi <= lc_fi + 4'd1;
						end
						else
							lc_fi <= lc_fi + 4'd1;
					10'd551:
						if (mv == VNULL)
							raise_msg(ABI_MSG_LOCAL_UNBOUND);
						else
							wr(loc_ptr(i0), VNULL, 10'd147);
					10'd552:
						if ((mv == VNULL) && !(fflags & FF_FW))
							raise_msg(ABI_MSG_LOCAL_UNBOUND);
						else begin
							rd(aoff(adr(mv), 8), 10'd135);
							if (cfg_lc_n != 4'd0) begin
								vs0 = {4'd0, lc_pick(i0)};
								if (!lc_v[vs0[2:0]] || !lc_dirty[vs0[2:0]])
									lc_fill(i0, mv, 1'b0, 1'b0, 10'd135);
							end
						end
					10'd557:
						if (mv == VNULL)
							raise_msg(ABI_MSG_LOCAL_UNBOUND);
						else begin
							wr(aoff(adr(mv), 8), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], 10'd147);
							sp <= sp - 7'd1;
						end
					10'd556:
						if (mv == VNULL)
							raise_msg(ABI_MSG_LOCAL_UNBOUND);
						else
							rd(aoff(adr(mv), 8), 10'd133);
					10'd135:
						if (mv == VNULL)
							raise_msg(ABI_MSG_LOCAL_UNBOUND);
						else begin
							push(mv);
							st <= 10'd147;
						end
					10'd133:
						if (mv == VNULL)
							raise_msg(ABI_MSG_LOCAL_UNBOUND);
						else
							wr(m_addr, VNULL, 10'd147);
					10'd441: begin
						at_q <= md;
						case (op)
							8'h11, 8'h12: begin
								b0 <= ((op == 8'h11) && (loc != VNULL) ? 1'b0 : 1'b1);
								i2 <= ((op == 8'h11) && (loc != VNULL) ? 8'd0 : 8'd1);
								st <= 10'd320;
							end
							8'h16, 8'h17:
								lookup(((op == 8'h16) && (loc != VNULL) ? loc : glb), {ABI_TAG_QSTR, md}, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], LK_ADD, 1'b0, 10'd507);
							8'h19, 8'h1a:
								lookup(((op == 8'h19) && (loc != VNULL) ? loc : glb), {ABI_TAG_QSTR, md}, VNULL, LK_REMOVE, 1'b0, 10'd136);
							8'h13, 8'h14: begin
								at_nat <= 1'b0;
								t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
								gosub_scr(SCR_AT, 10'd9, 10'd292);
							end
							8'h18: begin
								at_nat <= 1'b0;
								t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
								t[6] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))];
								st <= 10'd482;
							end
							8'h15: begin
								sp <= sp - 7'd3;
								hook(ABI_HOOK_SUPER_METHOD, ABI_RK_PUSH_NULL, 8'd3, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))], rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], {ABI_TAG_QSTR, md}, VNULL);
							end
							8'h1b: begin
								sp <= sp - 7'd2;
								hook(ABI_HOOK_IMPORT, ABI_RK_PUSH, 8'd4, {ABI_TAG_QSTR, md}, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))], glb);
							end
							8'h1c:
								hook(ABI_HOOK_IMPORT_FROM, ABI_RK_PUSH, 8'd2, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], {ABI_TAG_QSTR, md}, VNULL, VNULL);
							default:
								halt(ABI_HALT_BAD_OPCODE, op_pc);
						endcase
					end
					10'd320:
						if ((i2 == 8'd2) && (bov != VNULL))
							lookup(bov, {ABI_TAG_QSTR, at_q}, VNULL, LK_FIND, 1'b0, 10'd321);
						else
							lookup((i2 == 8'd0 ? loc : (i2 == 8'd1 ? glb : vmut(h_builtins, ABI_MUT_DICT))), {ABI_TAG_QSTR, at_q}, VNULL, LK_FIND, 1'b0, 10'd321);
					10'd321:
						if (lk_found) begin
							push(lk_res);
							st <= 10'd147;
						end
						else if ((i2 == 8'd2) && (bov != VNULL)) begin
							i2 <= 8'd3;
							lookup(vmut(h_builtins, ABI_MUT_DICT), {ABI_TAG_QSTR, at_q}, VNULL, LK_FIND, 1'b0, 10'd321);
						end
						else if (i2 >= 8'd2)
							raise_err(ABI_ERR_NAME, {ABI_TAG_QSTR, at_q}, VNULL);
						else begin
							i2 <= i2 + 8'd1;
							st <= 10'd320;
						end
					10'd507:
						if (lk_ro || lk_cx)
							raise_err(ABI_ERR_INTERNAL, t[4], VNULL);
						else begin
							sp <= sp - 7'd1;
							st <= 10'd147;
						end
					10'd136:
						if (!lk_found)
							raise_err(ABI_ERR_NAME, {ABI_TAG_QSTR, at_q}, VNULL);
						else
							st <= 10'd147;
					10'd292:
						if (at_nat) begin
							if (at_kind == 2'd1)
								deliver(at_v, crk);
							else if (((((at_kind == 2'd0) && ((ab_pe - ab_lo) == 8'd3)) && (tg(t[0]) == ABI_TAG_OBJECT)) && (at_q != ABI_Q_CLASS_D)) && (at_q != ABI_Q_DICT_D))
								rd(adr(t[0]), 10'd676);
							else
								st <= 10'd340;
						end
						else
							case (at_kind)
								2'd1: begin
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= at_v;
									if (op == 8'h14)
										push(VNULL);
									st <= 10'd147;
								end
								2'd2:
									if (op == 8'h14) begin
										rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= at_v;
										push(t[0]);
										st <= 10'd147;
									end
									else begin
										t[1] <= at_v;
										alloc(32'd4, 10'd282);
									end
								default: begin
									sp <= sp - 7'd1;
									hook(ABI_HOOK_GETATTR, (op == 8'h14 ? ABI_RK_PUSH_NULL : ABI_RK_PUSH), 8'd2, t[0], {ABI_TAG_QSTR, at_q}, VNULL, VNULL);
								end
							endcase
					10'd282: begin
						wb_v[0] <= vint(ABI_OB_BOUND_METHOD);
						wb_v[1] <= ty_bm;
						wb_v[2] <= t[1];
						wb_v[3] <= t[0];
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= vobj(al_a);
						wblock(al_a, 4'd4, 10'd147);
					end
					10'd482:
						if (tg(t[0]) == ABI_TAG_OBJECT)
							rd(adr(t[0]), 10'd485);
						else
							st <= 10'd484;
					10'd485:
						if ((scr_id == SCR_NONE) || (scr_id == SCR_AT)) begin
							scr_id <= SCR_AT;
							sA[3] <= md;
							if ((md == ABI_OB_INSTANCE) || (md == ABI_OB_EXCEPTION))
								rd(aoff(adr(t[0]), 4), 10'd491);
							else if ((md == ABI_OB_TYPE) || (md == ABI_OB_MODULE))
								rd(aoff(adr(t[0]), 8), 10'd483);
							else
								st <= 10'd484;
						end
						else
							wr(scr_addr(SCR_AT, 4'd3), {4'd0, md}, 10'd773);
					10'd773:
						if (scr_id != SCR_AT)
							scr_ensure(SCR_AT, 10'd773);
						else if ((sA[3] == ABI_OB_INSTANCE) || (sA[3] == ABI_OB_EXCEPTION))
							rd(aoff(adr(t[0]), 4), 10'd491);
						else if ((sA[3] == ABI_OB_TYPE) || (sA[3] == ABI_OB_MODULE))
							rd(aoff(adr(t[0]), 8), 10'd483);
						else
							st <= 10'd484;
					10'd491:
						rd(aoff(adr(mv), 28), 10'd490);
					10'd490:
						if (md & (ABI_TF_SETATTR | ABI_TF_DESC))
							st <= 10'd484;
						else
							rd(adr(t[0]) + (sA[3] == ABI_OB_EXCEPTION ? 16 : 8), 10'd483);
					10'd483:
						if (mv == VNULL) begin
							if ((t[6] == VNULL) || !((sA[3] == ABI_OB_INSTANCE) || (sA[3] == ABI_OB_EXCEPTION)))
								st <= 10'd484;
							else
								alloc(32'd4, 10'd486);
						end
						else
							lookup(mv, {ABI_TAG_QSTR, at_q}, t[6], (t[6] == VNULL ? LK_REMOVE : LK_ADD), 1'b0, 10'd489);
					10'd486: begin
						wb_v[0] <= vint(32'd0);
						wb_v[1] <= vint(32'd0);
						wb_v[2] <= VNULL;
						wb_v[3] <= vint(32'd0);
						t[4] <= vmut(al_a, ABI_MUT_DICT);
						wblock(al_a, 4'd4, 10'd487);
					end
					10'd487:
						wr(adr(t[0]) + (sA[3] == ABI_OB_EXCEPTION ? 16 : 8), t[4], 10'd488);
					10'd488:
						lookup(t[4], {ABI_TAG_QSTR, at_q}, t[6], LK_ADD, 1'b0, 10'd489);
					10'd489:
						if ((lk_ro || lk_cx) || ((lk_mode == LK_REMOVE) && !lk_found))
							st <= 10'd484;
						else if (at_nat)
							deliver(VNONE, crk);
						else begin
							sp <= sp - 7'd2;
							st <= 10'd147;
						end
					10'd484:
						if (at_nat)
							st <= 10'd340;
						else begin
							sp <= sp - 7'd2;
							hook(ABI_HOOK_SETATTR, ABI_RK_DISCARD, 8'd3, t[0], {ABI_TAG_QSTR, at_q}, t[6], VNULL);
						end
					10'd322:
						if (((is_mut(t[0], ABI_MUT_LIST) || is_mut(t[0], ABI_MUT_BYTEARRAY)) || (tg(t[0]) == ABI_TAG_TUPLE)) && intlike(t[1]))
							rd(adr(t[0]), 10'd326);
						else if (((cfg_sl != 0) && is_mut(t[0], ABI_MUT_LIST)) && (tg(t[1]) == ABI_TAG_OBJECT)) begin
							ss_store <= 0;
							ss_native <= 0;
							st <= 10'd799;
							ss_back <= 10'd778;
						end
						else if (is_mut(t[0], ABI_MUT_DICT))
							lookup(t[0], t[1], VNULL, LK_FIND, 1'b0, 10'd323);
						else if ((strlike(t[0]) || (tg(t[0]) == ABI_TAG_BYTES)) && intlike(t[1])) begin
							si_v <= t[0];
							gosub(10'd500, 10'd329);
						end
						else
							st <= 10'd324;
					10'd326: begin
						v0 = ival(t[1]);
						if (v0[31]) begin
							x1 <= v0 + md;
							st <= 10'd327;
						end
						else begin
							x1 <= v0;
							load_seq_index(v0);
						end
					end
					10'd327:
						load_seq_index(x1);
					10'd325:
						if (is_mut(t[0], ABI_MUT_BYTEARRAY))
							rd(md + {x1[31:2], 2'b00}, 10'd331);
						else
							rd(md + (x1 << 2), 10'd328);
					10'd328: begin
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= mv;
						sp <= sp - 7'd1;
						st <= 10'd147;
					end
					10'd323:
						if (lk_cx)
							st <= 10'd324;
						else if (lk_found) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= lk_res;
							sp <= sp - 7'd1;
							st <= 10'd147;
						end
						else
							raise_err(ABI_ERR_KEY, t[1], VNULL);
					10'd329: begin
						v0 = ival(t[1]);
						if (si_na && (tg(t[0]) != ABI_TAG_BYTES))
							st <= 10'd324;
						else if (v0[31]) begin
							x1 <= v0 + si_len;
							st <= 10'd330;
						end
						else begin
							x1 <= v0;
							load_string_index(v0);
						end
					end
					10'd330:
						load_string_index(x1);
					10'd331:
						if (!strlike(t[0])) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= vint({24'd0, byte_of(md, x1[1:0])});
							sp <= sp - 7'd1;
							st <= 10'd147;
						end
						else
							rd(h_chars + (4 * byte_of(md, x1[1:0])), 10'd332);
					10'd332: begin
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= {ABI_TAG_QSTR, md};
						sp <= sp - 7'd1;
						st <= 10'd147;
					end
					10'd324: begin
						sp <= sp - 7'd2;
						hook(ABI_HOOK_SUBSCR, ABI_RK_PUSH, 8'd2, t[0], t[1], VNULL, VNULL);
					end
					10'd778:
						rd(adr(t[1]), 10'd779);
					10'd779:
						if (md != ABI_OB_SLICE)
							st <= 10'd798;
						else
							rd(adr(t[0]), 10'd780);
					10'd780:
						if (md > SHORTLIST_MAX)
							st <= 10'd798;
						else begin
							ss_len <= md;
							rd(aoff(adr(t[1]), 16), 10'd781);
						end
					10'd781:
						if ((mv == VNONE) || ((tg(mv) == ABI_TAG_INT) && (mv[31:0] == 1))) begin
							ss_reverse <= 0;
							rd(aoff(adr(t[1]), 8), 10'd782);
						end
						else if ((!ss_store && (tg(mv) == ABI_TAG_INT)) && (mv[31:0] == 32'hffffffff)) begin
							ss_reverse <= 1;
							rd(aoff(adr(t[1]), 8), 10'd782);
						end
						else
							st <= 10'd798;
					10'd782:
						if ((mv != VNONE) && (tg(mv) != ABI_TAG_INT))
							st <= 10'd798;
						else begin
							ss_omitted <= mv == VNONE;
							ss_bound <= (mv == VNONE ? (ss_reverse ? ss_len - 32'd1 : 32'd0) : mv[31:0]);
							st <= 10'd783;
						end
					10'd783: begin
						if (!ss_omitted && ss_bound[31])
							ss_bound <= ss_bound + ss_len;
						st <= 10'd784;
					end
					10'd784: begin
						if (ss_omitted)
							ss_start <= ss_bound;
						else if (ss_bound[31])
							ss_start <= (ss_reverse ? 32'hffffffff : 0);
						else if (ss_bound >= ss_len)
							ss_start <= (ss_reverse ? ss_len - 32'd1 : ss_len);
						else
							ss_start <= ss_bound;
						rd(aoff(adr(t[1]), 12), 10'd785);
					end
					10'd785:
						if ((mv != VNONE) && (tg(mv) != ABI_TAG_INT))
							st <= 10'd798;
						else begin
							ss_omitted <= mv == VNONE;
							ss_bound <= (mv == VNONE ? (ss_reverse ? 32'hffffffff : ss_len) : mv[31:0]);
							st <= 10'd786;
						end
					10'd786: begin
						if (!ss_omitted && ss_bound[31])
							ss_bound <= ss_bound + ss_len;
						st <= 10'd787;
					end
					10'd787: begin
						if (ss_omitted)
							ss_stop <= ss_bound;
						else if (ss_bound[31])
							ss_stop <= (ss_reverse ? 32'hffffffff : 0);
						else if (ss_bound >= ss_len)
							ss_stop <= (ss_reverse ? ss_len - 32'd1 : ss_len);
						else
							ss_stop <= ss_bound;
						st <= 10'd788;
					end
					10'd788: begin
						ss_count <= ss_count_d;
						st <= 10'd789;
					end
					10'd789:
						if (ss_store) begin
							if (!is_mut(t[6], ABI_MUT_LIST) && (tg(t[6]) != ABI_TAG_TUPLE))
								st <= 10'd798;
							else
								rd(adr(t[6]), 10'd792);
						end
						else
							alloc(32'd3 + (ss_count < 4 ? 32'd4 : ss_count), 10'd790);
					10'd790: begin
						t[2] <= vmut(al_a, ABI_MUT_LIST);
						ss_dst <= al_a + 32'd12;
						wb_v[0] <= vint(ss_count);
						wb_v[1] <= vint((ss_count < 4 ? 32'd4 : ss_count));
						wb_v[2] <= {ABI_TAG_CONT, al_a + 32'd12};
						wblock(al_a, 4'd3, 10'd793);
					end
					10'd793:
						if (!ss_store)
							rd(aoff(adr(t[0]), 8), 10'd794);
						else begin
							ss_src <= md;
							rd(aoff(adr(t[0]), 8), 10'd794);
						end
					10'd794: begin
						if (ss_store) begin
							ss_dst <= md + (ss_start << 2);
							ss_back <= 10'd795;
						end
						else begin
							ss_src <= md + (ss_start << 2);
							ss_back <= 10'd791;
						end
						ss_n <= ss_count;
						ss_clear <= 0;
						ss_put <= 0;
						ss_length <= 0;
						ss_i <= 0;
						st <= 10'd799;
					end
					10'd792:
						if ((md != ss_count) || (md > SHORTLIST_MAX))
							st <= 10'd798;
						else if (tg(t[6]) == ABI_TAG_TUPLE) begin
							ss_src <= adr(t[6]) + 32'd4;
							rd(aoff(adr(t[0]), 8), 10'd794);
						end
						else
							rd(aoff(adr(t[6]), 8), 10'd793);
					10'd796: begin
						ss_store <= 0;
						ss_native <= 1;
						ss_reverse <= 0;
						ss_start <= 0;
						rd(adr(t[0]), 10'd797);
					end
					10'd797:
						if (md > SHORTLIST_MAX)
							st <= 10'd340;
						else begin
							ss_count <= md;
							st <= 10'd789;
						end
					10'd798:
						if (ss_native)
							st <= 10'd340;
						else
							st <= (ss_store ? 10'd516 : 10'd324);
					10'd791:
						if (ss_native)
							deliver(t[2], crk);
						else begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= t[2];
							sp <= sp - 7'd1;
							st <= 10'd147;
						end
					10'd795: begin
						sp <= sp - 7'd3;
						st <= 10'd147;
					end
					10'd799:
						if (!ca_valid && ca_idle_i) begin
							if ((ss_back == 10'd778) || (ss_back == 10'd796))
								st <= ss_back;
							else if ((cfg_sl == 2) && cfg_ca)
								st <= 10'd800;
							else begin
								ss_i <= 0;
								st <= 10'd802;
							end
						end
					10'd800:
						if (sl_ready_i)
							st <= 10'd801;
					10'd801:
						if (sl_response_i)
							st <= 10'd808;
					10'd802:
						if (ss_i == ss_n) begin
							ss_i <= 0;
							st <= 10'd804;
						end
						else
							rd((ss_reverse ? ss_src - (sv2v_cast_32(ss_i) << 2) : ss_src + (sv2v_cast_32(ss_i) << 2)), 10'd803);
					10'd803:
						if (SL_REFERENCE) begin
							ss_buf[ss_i] <= mv;
							ss_i <= ss_i + 1'b1;
							st <= 10'd802;
						end
						else
							halt(ABI_HALT_INTERNAL, 32'h534c0001);
					10'd804:
						if (!SL_REFERENCE)
							halt(ABI_HALT_INTERNAL, 32'h534c0002);
						else if (ss_i == ss_n)
							st <= 10'd805;
						else begin
							wr(ss_dst + (sv2v_cast_32(ss_i) << 2), ss_buf[ss_i], 10'd804);
							ss_i <= ss_i + 1'b1;
						end
					10'd805:
						if (ss_clear)
							wr(ss_clear_addr, VNULL, 10'd806);
						else
							st <= 10'd806;
					10'd806:
						if (ss_put)
							wr(ss_put_addr, ss_put_value, 10'd807);
						else
							st <= 10'd807;
					10'd807:
						if (ss_length)
							wr(ss_header, vint(ss_new_length), 10'd808);
						else
							st <= 10'd808;
					10'd808: st <= ss_back;
					10'd514:
						if (t[6] == VNULL)
							st <= 10'd516;
						else if (is_mut(t[0], ABI_MUT_LIST) && intlike(t[1]))
							rd(adr(t[0]), 10'd518);
						else if (((cfg_sl != 0) && is_mut(t[0], ABI_MUT_LIST)) && (tg(t[1]) == ABI_TAG_OBJECT)) begin
							ss_store <= 1;
							ss_native <= 0;
							st <= 10'd799;
							ss_back <= 10'd778;
						end
						else if ((is_mut(t[0], ABI_MUT_BYTEARRAY) && intlike(t[1])) && intlike(t[6]))
							rd(adr(t[0]), 10'd518);
						else if (is_mut(t[0], ABI_MUT_DICT))
							lookup(t[0], t[1], t[6], LK_ADD, 1'b0, 10'd515);
						else
							st <= 10'd516;
					10'd518: begin
						v0 = ival(t[1]);
						if (v0[31]) begin
							x1 <= v0 + md;
							st <= 10'd519;
						end
						else begin
							x1 <= v0;
							store_seq_index(v0);
						end
					end
					10'd519:
						store_seq_index(x1);
					10'd517: begin
						if (is_mut(t[0], ABI_MUT_BYTEARRAY))
							wrb(md + x1, ival(t[6]) & 32'h000000ff, 10'd147);
						else
							wr(md + (x1 << 2), t[6], 10'd147);
						sp <= sp - 7'd3;
					end
					10'd515:
						if (lk_cx || lk_ro)
							st <= 10'd516;
						else begin
							sp <= sp - 7'd3;
							st <= 10'd147;
						end
					10'd516: begin
						sp <= sp - 7'd3;
						hook(ABI_HOOK_SETSUBSCR, ABI_RK_DISCARD, 8'd3, t[0], t[1], t[6], VNULL);
					end
					10'd267:
						if (tr_x) begin
							fcont <= ABI_CONT_TRUTH;
							pc <= op_pc;
							hook(ABI_HOOK_TRUTH, ABI_RK_CONT, 8'd1, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], VNULL, VNULL, VNULL);
						end
						else begin
							case (op)
								8'h43: begin
									sp <= sp - 7'd1;
									if (tr_r)
										pc <= jt;
								end
								8'h44: begin
									sp <= sp - 7'd1;
									if (!tr_r)
										pc <= jt;
								end
								8'h45:
									if (tr_r)
										pc <= jt;
									else
										sp <= sp - 7'd1;
								8'h46:
									if (!tr_r)
										pc <= jt;
									else
										sp <= sp - 7'd1;
								default: rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= vbool(!tr_r);
							endcase
							if (op[7:3] == 5'b01000)
								soft_pt <= !(fflags & FF_FW);
							st <= 10'd147;
						end
					10'd523: begin
						if (at_kind == 2'd2) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= at_v;
							rf[rf_base[3:0] + sv2v_cast_4(sp)] <= t[0];
							sp <= sp + 7'd1;
						end
						else if (at_kind == 2'd1) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= at_v;
							rf[rf_base[3:0] + sv2v_cast_4(sp)] <= VNULL;
							sp <= sp + 7'd1;
						end
						if ((at_kind == 2'd1) || (at_kind == 2'd2)) begin
							at_q <= ABI_Q_ENTER_D;
							gosub_scr(SCR_AT, 10'd9, 10'd522);
						end
						else if (at_kind == 2'd3) begin
							aux <= vint(jt);
							aux2 <= vint(32'd0);
							aux3 <= t[0];
							fcont <= ABI_CONT_WITH_ATTR;
							hook(ABI_HOOK_GETATTR, ABI_RK_CONT, 8'd2, t[0], {ABI_TAG_QSTR, ABI_Q_EXIT_D}, VNULL, VNULL);
						end
						else
							raise_err(ABI_ERR_ATTR, t[0], {ABI_TAG_QSTR, ABI_Q_EXIT_D});
					end
					10'd522:
						if ((at_kind == 2'd2) || (at_kind == 2'd1)) begin
							ab_lo <= (at_kind == 2'd2 ? 8'd31 : 8'd32);
							ab_pe <= 8'd32;
							ab_nkw <= 8'd0;
							crk <= ABI_RK_CONT;
							fcont <= ABI_CONT_WITH_ENTER;
							aux <= vint(jt);
							wr(ab_ptr(8'd0), at_v, 10'd601);
						end
						else if (at_kind == 2'd3) begin
							aux <= vint(jt);
							aux2 <= vint(32'd1);
							aux3 <= t[0];
							fcont <= ABI_CONT_WITH_ATTR;
							hook(ABI_HOOK_GETATTR, ABI_RK_CONT, 8'd2, t[0], {ABI_TAG_QSTR, ABI_Q_ENTER_D}, VNULL, VNULL);
						end
						else
							raise_err(ABI_ERR_ATTR, t[0], {ABI_TAG_QSTR, ABI_Q_ENTER_D});
					10'd601:
						wr(ab_ptr(8'd31), t[0], 10'd94);
					10'd547: begin
						ab_nkw <= 8'd0;
						crk <= ABI_RK_CONT;
						ab_pe <= 8'd35;
						if (rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] == VNONE) begin
							x0 <= 32'd0;
							ab_lo <= (rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] != VNULL ? 8'd31 : 8'd32);
							fcont <= ABI_CONT_WITH_NONE;
						end
						else if (tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]) == ABI_TAG_INT) begin
							x0 <= 32'd1;
							ab_lo <= (rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))] != VNULL ? 8'd31 : 8'd32);
							aux <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))];
							aux2 <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
							fcont <= ABI_CONT_WITH_UNWIND;
						end
						else begin
							x0 <= 32'd2;
							ab_lo <= (rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] != VNULL ? 8'd31 : 8'd32);
							aux <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
							fcont <= ABI_CONT_WITH_EXC;
						end
						i0 <= 8'd0;
						st <= 10'd602;
					end
					10'd602:
						case (i0)
							8'd0: begin
								wr(ab_ptr(8'd34), VNONE, 10'd602);
								i0 <= 8'd1;
							end
							8'd1:
								if (x0 == 32'd2)
									i0 <= 8'd2;
								else begin
									wr(ab_ptr(8'd32), VNONE, 10'd602);
									i0 <= 8'd2;
								end
							8'd2: begin
								if (x0 == 32'd2)
									wr(ab_ptr(8'd33), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], 10'd602);
								else
									wr(ab_ptr(8'd33), VNONE, 10'd602);
								i0 <= 8'd3;
							end
							8'd3: begin
								if (x0 == 32'd1)
									wr(ab_ptr(8'd0), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd4))], 10'd602);
								else
									wr(ab_ptr(8'd0), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))], 10'd602);
								i0 <= 8'd4;
							end
							8'd4: begin
								if (x0 == 32'd1)
									wr(ab_ptr(8'd31), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))], 10'd602);
								else
									wr(ab_ptr(8'd31), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))], 10'd602);
								i0 <= 8'd5;
							end
							default:
								if (x0 == 32'd2)
									rd(aoff(adr(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]), 4), 10'd548);
								else
									st <= 10'd603;
						endcase
					10'd548:
						wr(ab_ptr(8'd32), mv, 10'd603);
					10'd603: begin
						if (x0 == 32'd1)
							sp <= sp - 7'd4;
						else
							sp <= sp - 7'd3;
						st <= 10'd94;
					end
					10'd586:
						if ((xsp != 5'd0) && (sw_k != 2'd3)) begin
							v0 = exc_ptr(fbase, xsp - 5'd1) + {28'd0, sw_k, 2'b00};
							case (sw_k)
								2'd0:
									wr(v0, {4'd0, xh}, 10'd586);
								2'd1:
									wr(v0, {4'd0, xf, 15'd0, xv}, 10'd586);
								default:
									wr(v0, xp, 10'd586);
							endcase
							sw_k <= sw_k + 2'd1;
						end
						else begin
							xh <= x0;
							xv <= x1[15:0];
							xf <= b0;
							xp <= VNULL;
							xsp <= xsp + 5'd1;
							ret;
						end
					10'd587:
						if (sw_k == 2'd0) begin
							if (xsp <= 5'd1) begin
								if (xsp == 5'd1)
									xsp <= 5'd0;
								ret;
							end
							else begin
								rd(exc_ptr(fbase, xsp - 5'd2), 10'd587);
								xsp <= xsp - 5'd1;
								sw_k <= 2'd1;
							end
						end
						else if (sw_k == 2'd1) begin
							xh <= md;
							rd(aoff(exc_ptr(fbase, xsp - 5'd1), 4), 10'd587);
							sw_k <= 2'd2;
						end
						else if (sw_k == 2'd2) begin
							xv <= md[15:0];
							xf <= md[31];
							rd(aoff(exc_ptr(fbase, xsp - 5'd1), 8), 10'd587);
							sw_k <= 2'd3;
						end
						else begin
							xp <= mv;
							ret;
						end
					10'd588:
						if ((xsp == 5'd0) || (sw_k == 2'd3))
							ret;
						else begin
							v0 = exc_ptr((spill_to_img ? x4 : fbase), xsp - 5'd1) + {28'd0, sw_k, 2'b00};
							case (sw_k)
								2'd0:
									wr(v0, {4'd0, xh}, 10'd588);
								2'd1:
									wr(v0, {4'd0, xf, 15'd0, xv}, 10'd588);
								default:
									wr(v0, xp, 10'd588);
							endcase
							sw_k <= sw_k + 2'd1;
						end
					10'd589:
						if (xsp == 5'd0)
							ret;
						else if (sw_k == 2'd0) begin
							rd(exc_ptr(fbase, xsp - 5'd1), 10'd589);
							sw_k <= 2'd1;
						end
						else if (sw_k == 2'd1) begin
							xh <= md;
							rd(aoff(exc_ptr(fbase, xsp - 5'd1), 4), 10'd589);
							sw_k <= 2'd2;
						end
						else if (sw_k == 2'd2) begin
							xv <= md[15:0];
							xf <= md[31];
							rd(aoff(exc_ptr(fbase, xsp - 5'd1), 8), 10'd589);
							sw_k <= 2'd3;
						end
						else begin
							xp <= mv;
							ret;
						end
					10'd590:
						if (sw_k == 2'd0) begin
							rd(aoff(exc_ptr(fbase, sw_i[4:0]), 8), 10'd590);
							sw_k <= 2'd1;
						end
						else if (mv != VNULL) begin
							xc <= mv;
							rx_from <= 1'b0;
							rsp <= 5'd0;
							st <= 10'd442;
						end
						else if (sw_i == 32'd0)
							raise_msg(ABI_MSG_NO_ACTIVE_EXC);
						else begin
							rd(aoff(exc_ptr(fbase, sw_i[4:0] - 5'd1), 8), 10'd590);
							sw_i <= sw_i - 32'd1;
						end
					10'd591:
						if (rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] == VNONE) begin
							sp <= sp - 7'd1;
							st <= 10'd147;
						end
						else if (tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]) == ABI_TAG_INT) begin
							if (rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))][31]) begin
								sp <= sp - 7'd1;
								st <= 10'd544;
							end
							else
								st <= 10'd534;
						end
						else
							raise_val(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]);
					10'd544:
						if (has_link && (sp <= sv2v_cast_7_signed(RF_RELOAD_AT))) begin
							rf_resume <= 10'd544;
							st <= 10'd566;
						end
						else if (xsp == 5'd0) begin
							t[7] <= rf[rf_base[3:0] + sv2v_cast_4(sp - 7'd1)];
							if (gen != VNULL) begin
								pc <= 32'd0;
								st <= 10'd176;
							end
							else
								st <= 10'd444;
						end
						else if (xf && (xh >= pc)) begin
							if ((((spilled_reals != 16'd0) || has_link) || (rf_base != 6'd0)) || ((sv2v_cast_32(xv) + 32'd2) > MPY_RF_DEPTH)) begin
								ur_target <= xv;
								ur_val <= rf[rf_base[3:0] + sv2v_cast_4(sp - 7'd1)];
								pc <= xh;
								st <= 10'd545;
							end
							else begin
								rf[rf_base[3:0] + sv2v_cast_4(xv[6:0])] <= rf[rf_base[3:0] + sv2v_cast_4(sp - 7'd1)];
								rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(xv[6:0] + 7'd1))] <= vint(32'hffffffff);
								sp <= xv[6:0] + 7'd2;
								pc <= xh;
								st <= 10'd147;
							end
						end
						else begin
							if (xf) begin
								if (tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))]) == ABI_TAG_INT) begin
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									sp <= sp - 7'd2;
								end
								else begin
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									sp <= sp - 7'd1;
								end
							end
							sw_k <= 2'd0;
							gosub(10'd587, 10'd544);
						end
					10'd534: begin
						uj <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))][31:0];
						sp <= sp - 7'd1;
						st <= 10'd535;
					end
					10'd535:
						if (uj[6:0] == 7'd0) begin
							pc <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))][31:0];
							sp <= (sp - 7'd1) - (uj[7] ? 7'd4 : 7'd0);
							soft_pt <= !(fflags & FF_FW);
							st <= 10'd147;
						end
						else if (xsp == 5'd0)
							uj <= uj - 32'd1;
						else if (xf && (xh >= pc)) begin
							uj <= uj - 32'd1;
							push(vint(uj - 32'd1));
							pc <= xh;
							st <= 10'd147;
						end
						else begin
							uj <= uj - 32'd1;
							if (xf) begin
								if (tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))]) == ABI_TAG_INT) begin
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									sp <= sp - 7'd2;
								end
								else begin
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									sp <= sp - 7'd1;
								end
							end
							sw_k <= 2'd0;
							gosub(10'd587, 10'd535);
						end
					10'd467:
						if (tg(t[0]) != ABI_TAG_OBJECT)
							raise_err(ABI_ERR_NOT_EXC, t[0], VNULL);
						else
							rd(adr(t[0]), 10'd468);
					10'd468:
						if (md == ABI_OB_EXCEPTION)
							raise_val(t[0]);
						else if (md == ABI_OB_TYPE)
							rd(aoff(adr(t[0]), 28), 10'd469);
						else
							raise_err(ABI_ERR_NOT_EXC, t[0], VNULL);
					10'd469:
						if (md & ABI_TF_EXC) begin
							wr(ab_ptr(8'd0), t[0], 10'd94);
							ab_lo <= 8'd32;
							ab_pe <= 8'd32;
							ab_nkw <= 8'd0;
							crk <= ABI_RK_CONT;
							fcont <= ABI_CONT_RAISE;
						end
						else
							raise_err(ABI_ERR_NOT_EXC, t[0], VNULL);
					10'd214: begin
						vs0 = sp - 7'd1;
						if ((((((((tg(t[0]) == ABI_TAG_TUPLE) || (tg(t[0]) == ABI_TAG_BYTES)) || is_mut(t[0], ABI_MUT_LIST)) || is_mut(t[0], ABI_MUT_DICT)) || is_mut(t[0], ABI_MUT_SET)) || is_mut(t[0], ABI_MUT_BYTEARRAY)) || (tg(t[0]) == ABI_TAG_ITER)) || ((tg(t[0]) == ABI_TAG_OBJECT) && b1)) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(vs0 + 7'd1))] <= vint(32'd0);
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(vs0 + 7'd2))] <= vint(32'd0);
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(vs0 + 7'd3))] <= vint((tg(t[0]) == ABI_TAG_ITER ? ABI_IT_HEAPITER : (tg(t[0]) == ABI_TAG_OBJECT ? ABI_IT_PYOBJ : (is_mut(t[0], ABI_MUT_DICT) ? ABI_IT_DICT : (is_mut(t[0], ABI_MUT_SET) ? ABI_IT_SET : ABI_IT_SEQ)))));
							sp <= sp + 7'd3;
							st <= 10'd147;
						end
						else if (tg(t[0]) == ABI_TAG_RANGE)
							rd(adr(t[0]), 10'd225);
						else if (strlike(t[0])) begin
							si_v <= t[0];
							gosub(10'd500, 10'd228);
						end
						else if (tg(t[0]) == ABI_TAG_OBJECT)
							rd(adr(t[0]), 10'd224);
						else
							st <= 10'd223;
					end
					10'd225: begin
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= mv;
						rd(aoff(adr(t[0]), 4), 10'd226);
					end
					10'd226: begin
						rf[rf_base[3:0] + sv2v_cast_4(sp)] <= mv;
						rd(aoff(adr(t[0]), 8), 10'd227);
					end
					10'd227: begin
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd1))] <= mv;
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd2))] <= vint(ABI_IT_RANGE);
						sp <= sp + 7'd3;
						st <= 10'd147;
					end
					10'd228:
						if (si_na)
							st <= 10'd223;
						else begin
							rf[rf_base[3:0] + sv2v_cast_4(sp)] <= vint(32'd0);
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd1))] <= vint(32'd0);
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd2))] <= vint(ABI_IT_STR);
							sp <= sp + 7'd3;
							st <= 10'd147;
						end
					10'd224:
						if ((md == ABI_OB_GENERATOR) || (md == ABI_OB_ITEROBJ)) begin
							rf[rf_base[3:0] + sv2v_cast_4(sp)] <= vint(32'd0);
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd1))] <= vint(32'd0);
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd2))] <= vint(ABI_IT_PYOBJ);
							sp <= sp + 7'd3;
							st <= 10'd147;
						end
						else if (md == ABI_OB_DICT_VIEW)
							rd(aoff(adr(t[0]), 8), 10'd229);
						else begin
							at_q <= ABI_Q_ITER_D;
							gosub_scr(SCR_AT, 10'd9, 10'd222);
						end
					10'd229: begin
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= mv;
						rd(aoff(adr(t[0]), 12), 10'd230);
					end
					10'd230: begin
						rf[rf_base[3:0] + sv2v_cast_4(sp)] <= vint(32'd0);
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd1))] <= mv;
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd2))] <= vint(ABI_IT_DICT);
						sp <= sp + 7'd3;
						st <= 10'd147;
					end
					10'd222:
						if ((at_kind == 2'd2) || (at_kind == 2'd1)) begin
							ab_lo <= (at_kind == 2'd2 ? 8'd31 : 8'd32);
							ab_pe <= 8'd32;
							ab_nkw <= 8'd0;
							crk <= ABI_RK_CONT;
							fcont <= ABI_CONT_GETITER;
							pc <= op_pc;
							wr(ab_ptr(8'd0), at_v, 10'd601);
						end
						else
							st <= 10'd223;
					10'd215:
						if (tg(t[0]) == ABI_TAG_ITER)
							st <= 10'd147;
						else if ((((((tg(t[0]) == ABI_TAG_TUPLE) || (tg(t[0]) == ABI_TAG_BYTES)) || is_mut(t[0], ABI_MUT_LIST)) || is_mut(t[0], ABI_MUT_BYTEARRAY)) || is_mut(t[0], ABI_MUT_DICT)) || is_mut(t[0], ABI_MUT_SET)) begin
							wb_v[0] <= t[0];
							wb_v[1] <= vint(32'd0);
							wb_v[2] <= vint(32'd0);
							wb_v[3] <= vint((is_mut(t[0], ABI_MUT_DICT) ? ABI_IT_DICT : (is_mut(t[0], ABI_MUT_SET) ? ABI_IT_SET : ABI_IT_SEQ)));
							alloc(32'd4, 10'd220);
						end
						else if (tg(t[0]) == ABI_TAG_RANGE)
							rd(adr(t[0]), 10'd217);
						else if (tg(t[0]) == ABI_TAG_OBJECT)
							rd(adr(t[0]), 10'd216);
						else begin
							sp <= sp - 7'd1;
							hook(ABI_HOOK_GETITER, ABI_RK_PUSH, 8'd1, t[0], VNULL, VNULL, VNULL);
						end
					10'd216:
						if ((md == ABI_OB_GENERATOR) || (md == ABI_OB_ITEROBJ))
							st <= 10'd147;
						else begin
							sp <= sp - 7'd1;
							hook(ABI_HOOK_GETITER, ABI_RK_PUSH, 8'd1, t[0], VNULL, VNULL, VNULL);
						end
					10'd217: begin
						wb_v[0] <= mv;
						rd(aoff(adr(t[0]), 4), 10'd218);
					end
					10'd218: begin
						wb_v[1] <= mv;
						rd(aoff(adr(t[0]), 8), 10'd219);
					end
					10'd219: begin
						wb_v[2] <= mv;
						wb_v[3] <= vint(ABI_IT_RANGE);
						alloc(32'd4, 10'd220);
					end
					10'd220: begin
						t[2] <= {ABI_TAG_ITER, al_a};
						wblock(al_a, 4'd4, 10'd221);
					end
					10'd221: begin
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= t[2];
						st <= 10'd147;
					end
					10'd223: begin
						fcont <= ABI_CONT_GETITER;
						pc <= op_pc;
						hook(ABI_HOOK_GETITER, ABI_RK_CONT, 8'd1, t[0], VNULL, VNULL, VNULL);
					end
					10'd771:
						if ((scr_id != SCR_NONE) && (scr_id != SCR_IT))
							scr_go_store(scr_id, 10'd771);
						else begin
							begin : sv2v_autoblock_20
								reg signed [31:0] k;
								for (k = 0; k < 4; k = k + 1)
									sV[k] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6((sp - 7'd4) + sv2v_cast_7_signed(k)))];
							end
							scr_id <= SCR_IT;
							if (rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd4))] == VNULL) begin
								if (tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))]) == ABI_TAG_ITER) begin
									it_h <= 1'b1;
									t[3] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))];
									i0 <= 8'd0;
									st <= 10'd152;
								end
								else begin
									t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))];
									if (tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))]) == ABI_TAG_OBJECT)
										rd(adr(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))]), 10'd151);
									else begin
										at_q <= ABI_Q_NEXT_D;
										scr_go_store_gosub(SCR_IT, 10'd9, 10'd149);
									end
								end
							end
							else if (rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] == vint(ABI_IT_HEAPITER)) begin
								it_h <= 1'b1;
								t[3] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd4))];
								i0 <= 8'd0;
								st <= 10'd152;
							end
							else begin
								it_h <= 1'b0;
								gosub(10'd254, 10'd154);
							end
						end
					10'd152:
						if (((i0 == 8'd0) && (scr_id != SCR_NONE)) && (scr_id != SCR_IT))
							scr_go_store(scr_id, 10'd152);
						else begin
							if (scr_id != SCR_IT)
								scr_id <= SCR_IT;
							if (i0 == 8'd4)
								gosub(10'd254, 10'd154);
							else
								rd(adr(t[3]) + (4 * i0), 10'd153);
						end
					10'd153: begin
						sV[i0[1:0]] <= mv;
						i0 <= i0 + 8'd1;
						st <= 10'd152;
					end
					10'd154:
						if (it_py) begin
							t[0] <= sV[0];
							if (tg(sV[0]) == ABI_TAG_OBJECT)
								rd(adr(sV[0]), 10'd151);
							else begin
								at_q <= ABI_Q_NEXT_D;
								gosub_scr(SCR_AT, 10'd9, 10'd149);
							end
						end
						else if (it_h)
							wr(adr(t[3]), sV[0], 10'd155);
						else begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd4))] <= sV[0];
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))] <= sV[1];
							st <= 10'd150;
						end
					10'd155:
						wr(aoff(adr(t[3]), 4), sV[1], 10'd150);
					10'd150: begin
						if (it_stop) begin
							sp <= sp - 7'd4;
							pc <= jt;
						end
						else
							push(it_val);
						st <= 10'd147;
					end
					10'd149:
						if ((at_kind == 2'd2) || (at_kind == 2'd1)) begin
							ab_lo <= (at_kind == 2'd2 ? 8'd31 : 8'd32);
							ab_pe <= 8'd32;
							ab_nkw <= 8'd0;
							crk <= ABI_RK_CONT;
							fcont <= ABI_CONT_FOR_NEXT;
							aux <= vint(jt);
							wr(ab_ptr(8'd0), at_v, 10'd601);
						end
						else
							raise_err(ABI_ERR_NOT_ITERATOR, t[0], VNULL);
					10'd151:
						if (md == ABI_OB_GENERATOR) begin
							t[1] <= VNONE;
							t[2] <= VNONE;
							r_rk <= ABI_RK_CONT;
							fcont <= ABI_CONT_FOR_NEXT;
							aux <= vint(jt);
							st <= 10'd180;
						end
						else begin
							at_q <= ABI_Q_NEXT_D;
							gosub_scr(SCR_AT, 10'd9, 10'd149);
						end
					10'd93: begin
						drop_left <= tb_n;
						drop_push_en <= 1'b1;
						drop_push_v <= tb_v;
						drop_then <= 10'd147;
						st <= 10'd580;
					end
					10'd66: begin
						v0 = (arg < 32'd4 ? 32'd4 : arg);
						wb_v[0] <= vint(arg);
						wb_v[1] <= vint(v0);
						wb_v[2] <= {ABI_TAG_CONT, al_a + 32'd12};
						t[0] <= vmut(al_a, ABI_MUT_LIST);
						gi <= 32'd0;
						wblock(al_a, 4'd3, 10'd67);
					end
					10'd67:
						if (gi == arg) begin
							drop_left <= arg[15:0];
							drop_push_en <= 1'b1;
							drop_push_v <= t[0];
							drop_then <= 10'd147;
							st <= 10'd580;
						end
						else begin
							v0 = (sv2v_cast_32(stk_depth) - arg) + gi;
							if (stk_hit(v0[15:0])) begin
								wr((adr(t[0]) + 12) + (4 * gi), stk_val(v0[15:0]), 10'd67);
								gi <= gi + 32'd1;
							end
							else begin
								srd_g <= v0[15:0];
								gosub(10'd569, 10'd581);
							end
						end
					10'd581: begin
						wr((adr(t[0]) + 12) + (4 * gi), srd_v, 10'd67);
						gi <= gi + 32'd1;
					end
					10'd68: begin
						wb_v[0] <= vint(32'd0);
						wb_v[1] <= vint(arg);
						wb_v[2] <= (arg == 32'd0 ? VNULL : {ABI_TAG_CONT, al_a + 32'd16});
						wb_v[3] <= vint(32'd0);
						rf[rf_base[3:0] + sv2v_cast_4(sp)] <= vmut(al_a, ABI_MUT_DICT);
						sp <= sp + 7'd1;
						wblock(al_a, 4'd4, 10'd147);
					end
					10'd91:
						if (tb_n > resident_reals) begin
							drop_left <= tb_n;
							drop_push_en <= 1'b0;
							drop_then <= 10'd92;
							st <= 10'd580;
						end
						else begin
							sp <= sp - sv2v_cast_7(tb_n);
							hook(ABI_HOOK_DICTOP, ABI_RK_PUSH, 8'd4, vint(32'd0), tb_v, VNULL, VNULL);
						end
					10'd92:
						hook(ABI_HOOK_DICTOP, ABI_RK_PUSH, 8'd4, vint(32'd0), tb_v, VNULL, VNULL);
					10'd506: begin
						wb_v[0] <= vint(ABI_OB_SLICE);
						wb_v[1] <= ty_slice;
						if (arg == 32'd3) begin
							wb_v[2] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))];
							wb_v[3] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))];
							wb_v[4] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
						end
						else begin
							wb_v[2] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))];
							wb_v[3] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
							wb_v[4] <= VNONE;
						end
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - sv2v_cast_7(arg)))] <= vobj(al_a);
						sp <= (sp - sv2v_cast_7(arg)) + 7'd1;
						wblock(al_a, 4'd5, 10'd147);
					end
					10'd493: begin
						sp <= sp - 7'd1;
						st <= 10'd147;
					end
					10'd492:
						if (lk_cx || lk_ro) begin
							sp <= sp - 7'd2;
							hook(ABI_HOOK_DICTOP, ABI_RK_DISCARD, 8'd4, vint(32'd1), t[4], t[5], t[6]);
						end
						else begin
							sp <= sp - 7'd2;
							st <= 10'd147;
						end
					10'd494:
						if (lk_cx || lk_ro) begin
							sp <= sp - 7'd1;
							hook(ABI_HOOK_DICTOP, ABI_RK_DISCARD, 8'd4, vint(32'd2), t[4], t[5], VNULL);
						end
						else begin
							sp <= sp - 7'd1;
							st <= 10'd147;
						end
					10'd520:
						if (lk_cx || lk_ro) begin
							sp <= sp - 7'd2;
							hook(ABI_HOOK_DICTOP, ABI_RK_DISCARD, 8'd4, vint(32'd1), t[4], t[5], t[6]);
						end
						else begin
							sp <= sp - 7'd2;
							st <= 10'd147;
						end
					10'd541:
						if (md != arg) begin
							sp <= sp - 7'd1;
							fcont <= ABI_CONT_UNPACK;
							hook(ABI_HOOK_UNPACK, ABI_RK_CONT, 8'd3, t[0], vint(arg), vint(32'd0), VNULL);
						end
						else if (tg(t[0]) == ABI_TAG_TUPLE) begin
							x2 <= adr(t[0]) + 4;
							x1 <= arg;
							sp <= sp - 7'd1;
							st <= 10'd540;
						end
						else
							rd(aoff(adr(t[0]), 8), 10'd542);
					10'd542: begin
						x2 <= md;
						x1 <= arg;
						sp <= sp - 7'd1;
						st <= 10'd540;
					end
					10'd540:
						if (x1 == 32'd0)
							st <= 10'd147;
						else
							rd((x2 + (x1 << 2)) - 32'd4, 10'd543);
					10'd543: begin
						x1 <= x1 - 32'd1;
						push(mv);
						st <= 10'd540;
					end
					10'd334:
						rd(ha_mdarg, 10'd336);
					10'd336: begin
						c_rc <= md;
						if ((op == 8'h20) || (op == 8'h21)) begin
							tb_src <= 1'b1;
							tb_nz <= 1'b0;
							tb_from <= sv2v_cast_8(sp - sv2v_cast_7(ext));
							stk_from <= stk_depth - sv2v_cast_16(ext);
							tb_n <= {8'd0, ext};
							gosub(10'd528, 10'd335);
						end
						else begin
							t[0] <= VNULL;
							st <= 10'd337;
						end
					end
					10'd335: begin
						t[0] <= tb_v;
						st <= 10'd337;
					end
					10'd337:
						if (fun == VNULL) begin
							t[1] <= VNULL;
							alloc(32'd8, 10'd333);
						end
						else
							rd(aoff(adr(fun), 28), 10'd338);
					10'd338: begin
						t[1] <= mv;
						alloc(32'd8, 10'd333);
					end
					10'd333: begin
						v0 = ((op == 8'h20) || (op == 8'h21) ? {24'd0, ext} : 32'd0);
						wb_v[0] <= vint(ABI_OB_FUNCTION);
						wb_v[1] <= ty_fun;
						wb_v[2] <= vint(c_rc);
						wb_v[3] <= t[0];
						wb_v[6] <= glb;
						wb_v[7] <= t[1];
						if ((op == 8'h33) || (op == 8'h21)) begin
							wb_v[4] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6((sp - sv2v_cast_7(v0)) - 7'd2))];
							wb_v[5] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6((sp - sv2v_cast_7(v0)) - 7'd1))];
							v0 = v0 + 32'd2;
						end
						else begin
							wb_v[4] <= VNULL;
							wb_v[5] <= VNULL;
						end
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - sv2v_cast_7(v0)))] <= vobj(al_a);
						sp <= (sp - sv2v_cast_7(v0)) + 7'd1;
						wblock(al_a, 4'd8, 10'd147);
					end
					10'd127:
						if (cv_wide)
							st <= 10'd606;
						else if (cv_i == cv_n) begin
							if ((op == 8'h37) && (rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(cv_fidx + 7'd1))] != VNULL)) begin
								b1 <= 1'b1;
								ab_lo <= 8'd31;
							end
							else begin
								b1 <= 1'b0;
								ab_lo <= 8'd32;
							end
							ab_pe <= 8'd32;
							cv_i <= 8'd0;
							wr(ab_ptr(8'd0), rf[rf_base[3:0] + sv2v_cast_4(cv_fidx)], 10'd604);
						end
						else begin
							t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(cv_base + sv2v_cast_7(cv_i)))];
							if (cv_bm[cv_i[4:0]] && !((tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(cv_base + sv2v_cast_7(cv_i)))]) == ABI_TAG_TUPLE) || is_mut(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(cv_base + sv2v_cast_7(cv_i)))], ABI_MUT_LIST))) begin
								aux <= vint({25'd0, sv2v_cast_7(cv_base + sv2v_cast_7(cv_i))});
								fcont <= ABI_CONT_REPLACE;
								pc <= op_pc;
								hook(ABI_HOOK_TUPLE, ABI_RK_CONT, 8'd1, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(cv_base + sv2v_cast_7(cv_i)))], VNULL, VNULL, VNULL);
							end
							else
								cv_i <= cv_i + 8'd1;
						end
					10'd604:
						if (b1)
							wr(ab_ptr(8'd31), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(cv_fidx + 7'd1))], 10'd123);
						else
							st <= 10'd123;
					10'd606:
						if (cv_i == cv_n) begin
							cv_g <= cv_fun_g;
							cv_ret <= 10'd607;
							st <= 10'd617;
						end
						else begin
							cv_g <= cv_pos_g + {8'd0, cv_i};
							cv_ret <= 10'd610;
							st <= 10'd617;
						end
					10'd607:
						if (op == 8'h37) begin
							t[2] <= t[3];
							cv_g <= cv_fun_g + 16'd1;
							cv_ret <= 10'd608;
							st <= 10'd617;
						end
						else begin
							b1 <= 1'b0;
							ab_lo <= 8'd32;
							ab_pe <= 8'd32;
							cv_i <= 8'd0;
							wr(ab_ptr(8'd0), t[3], 10'd123);
						end
					10'd608: begin
						t[6] <= t[3];
						if (t[3] != VNULL) begin
							b1 <= 1'b1;
							ab_lo <= 8'd31;
						end
						else begin
							b1 <= 1'b0;
							ab_lo <= 8'd32;
						end
						ab_pe <= 8'd32;
						cv_i <= 8'd0;
						wr(ab_ptr(8'd0), t[2], 10'd609);
					end
					10'd609:
						if (b1)
							wr(ab_ptr(8'd31), t[6], 10'd123);
						else
							st <= 10'd123;
					10'd610: begin
						t[0] <= t[3];
						if (cv_bm[cv_i[4:0]] && !((tg(t[3]) == ABI_TAG_TUPLE) || is_mut(t[3], ABI_MUT_LIST))) begin
							if (stk_hit(cv_g)) begin
								aux <= vint({25'd0, stk_slot(cv_g)});
								fcont <= ABI_CONT_REPLACE;
							end
							else begin
								aux <= vint({16'd0, cv_g});
								fcont <= ABI_CONT_SPILL_REPLACE;
							end
							pc <= op_pc;
							hook(ABI_HOOK_TUPLE, ABI_RK_CONT, 8'd1, t[3], VNULL, VNULL, VNULL);
						end
						else begin
							cv_i <= cv_i + 8'd1;
							st <= 10'd606;
						end
					end
					10'd611:
						rd(srd_addr, 10'd612);
					10'd612: begin
						v0 = sv2v_cast_32(mpy_rf_chunk_count(mt, md));
						v1 = mpy_rf_chunk_prev(md);
						if ((v0 != 32'd0) && (srd_off < v0[15:0])) begin
							x1 <= (v0 - 32'd1) - sv2v_cast_32(srd_off);
							x0 <= ((srd_addr + 32'd4) + (sv2v_cast_32((v0[5:0] + 6'd7) >> 3) << 2)) + (((v0 - 32'd1) - sv2v_cast_32(srd_off)) << 2);
							st <= 10'd613;
						end
						else if ((v1 == 32'd0) || (srd_hops == spilled_reals))
							halt(ABI_HALT_INTERNAL, 32'h0000c0c1);
						else begin
							srd_off <= srd_off - v0[15:0];
							srd_addr <= v1;
							srd_hops <= srd_hops + 16'd1;
							st <= 10'd611;
						end
					end
					10'd613:
						rd((srd_addr + 32'd4) + ((x1 >> 3) << 2), 10'd614);
					10'd614: begin
						case (x1[2:0])
							3'd0: v3 = {md[31:4], t[7][35:32]};
							3'd1: v3 = {md[31:8], t[7][35:32], md[3:0]};
							3'd2: v3 = {md[31:12], t[7][35:32], md[7:0]};
							3'd3: v3 = {md[31:16], t[7][35:32], md[11:0]};
							3'd4: v3 = {md[31:20], t[7][35:32], md[15:0]};
							3'd5: v3 = {md[31:24], t[7][35:32], md[19:0]};
							3'd6: v3 = {md[31:28], t[7][35:32], md[23:0]};
							default: v3 = {t[7][35:32], md[27:0]};
						endcase
						wr((srd_addr + 32'd4) + ((x1 >> 3) << 2), {4'd0, v3}, 10'd615);
					end
					10'd615:
						wr(x0, t[7], 10'd616);
					10'd616: begin
						pc <= op_pc;
						st <= 10'd147;
					end
					10'd617:
						if (stk_hit(cv_g)) begin
							t[3] <= stk_val(cv_g);
							st <= cv_ret;
						end
						else begin
							srd_g <= cv_g;
							gosub(10'd569, 10'd618);
						end
					10'd618: begin
						t[3] <= srd_v;
						st <= cv_ret;
					end
					10'd123:
						if (cv_i == cv_n) begin
							ab_nkw <= cv_j;
							crk <= ABI_RK_PUSH;
							gi <= 32'd0;
							if (ab_chunked)
								ab_npos <= ab_nitems;
							if (!cv_wide)
								sp <= cv_fidx;
							st <= 10'd605;
						end
						else if (cv_wide) begin
							cv_g <= cv_pos_g + {8'd0, cv_i};
							cv_ret <= (cv_bm[cv_i[4:0]] ? 10'd620 : 10'd619);
							st <= 10'd617;
						end
						else if (!cv_bm[cv_i[4:0]]) begin
							wr(ab_ptr(ab_pe), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(cv_base + sv2v_cast_7(cv_i)))], 10'd123);
							ab_pe <= ab_pe + 8'd1;
							cv_i <= cv_i + 8'd1;
						end
						else begin
							t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(cv_base + sv2v_cast_7(cv_i)))];
							rd(adr(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(cv_base + sv2v_cast_7(cv_i)))]), 10'd126);
						end
					10'd619:
						if (ab_chunked) begin
							cv_i <= cv_i + 8'd1;
							cv_ret <= 10'd123;
							st <= 10'd628;
						end
						else begin
							wr(ab_ptr(ab_pe), t[3], 10'd123);
							ab_pe <= ab_pe + 8'd1;
							cv_i <= cv_i + 8'd1;
						end
					10'd620: begin
						t[0] <= t[3];
						rd(adr(t[3]), 10'd126);
					end
					10'd126: begin
						x4 <= md;
						gi <= 32'd0;
						if (tg(t[0]) == ABI_TAG_TUPLE) begin
							cv_items <= adr(t[0]) + 4;
							st <= 10'd125;
						end
						else
							rd(aoff(adr(t[0]), 8), 10'd124);
					end
					10'd124: begin
						cv_items <= md;
						st <= 10'd125;
					end
					10'd125:
						if (gi == x4) begin
							cv_i <= cv_i + 8'd1;
							st <= 10'd123;
						end
						else if (ab_chunked)
							rd(cv_items + (gi << 2), 10'd623);
						else if (ab_pe >= 8'd200) begin
							cv_kw <= 1'b0;
							st <= 10'd624;
						end
						else
							rd(cv_items + (gi << 2), 10'd128);
					10'd623: begin
						t[3] <= mv;
						gi <= gi + 32'd1;
						cv_ret <= 10'd125;
						st <= 10'd628;
					end
					10'd128: begin
						wr(ab_ptr(ab_pe), mv, 10'd125);
						ab_pe <= ab_pe + 8'd1;
						gi <= gi + 32'd1;
					end
					10'd605:
						if ((!ab_chunked && (gi == 32'd0)) && (({24'd0, ab_pe} + {23'd0, cv_j, 1'b0}) > 32'd256)) begin
							cv_kw <= 1'b1;
							st <= 10'd624;
						end
						else if (gi == {23'd0, cv_j, 1'b0}) begin
							if (cv_wide) begin
								drop_left <= stk_depth - cv_fun_g;
								drop_push_en <= 1'b0;
								drop_then <= (ab_chunked ? 10'd643 : 10'd94);
								st <= 10'd580;
							end
							else
								st <= (ab_chunked ? 10'd643 : 10'd94);
						end
						else if (cv_wide) begin
							cv_g <= (cv_pos_g + {8'd0, cv_n}) + gi[15:0];
							cv_ret <= 10'd621;
							st <= 10'd617;
						end
						else if (ab_chunked) begin
							t[3] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6((cv_base + sv2v_cast_7(cv_n)) + gi[6:0]))];
							st <= 10'd621;
						end
						else begin
							wr(ab_ptr(ab_pe + gi[7:0]), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6((cv_base + sv2v_cast_7(cv_n)) + gi[6:0]))], 10'd605);
							gi <= gi + 32'd1;
						end
					10'd621: begin
						if ((t[3] == VNULL) && !gi[0])
							t[3] <= vint(32'd0);
						st <= 10'd622;
					end
					10'd622: begin
						gi <= gi + 32'd1;
						if (ab_chunked) begin
							cv_ret <= 10'd605;
							st <= 10'd628;
						end
						else
							wr(ab_ptr(ab_pe + gi[7:0]), t[3], 10'd605);
					end
					10'd624: begin
						ab_chunked <= 1'b1;
						ab_ovf <= 1'b0;
						ab_npos <= {24'd0, ab_pe} - {24'd0, ab_lo};
						ab_nitems <= 32'd0;
						ab_nblk <= 32'd0;
						ab_fill <= 5'd0;
						ab_blk <= VNULL;
						t[5] <= VNULL;
						cv_k <= 32'd0;
						wr(ab_ptr(8'd1), vint(32'd1), 10'd625);
					end
					10'd625:
						wr(ab_ptr(8'd4), VNULL, 10'd626);
					10'd626:
						if (cv_k == ab_npos)
							st <= (cv_kw ? 10'd605 : 10'd125);
						else
							rd(ab_ptr(sv2v_cast_8({24'd0, ab_lo} + cv_k)), 10'd627);
					10'd627: begin
						t[3] <= mv;
						cv_k <= cv_k + 32'd1;
						cv_ret <= 10'd626;
						st <= 10'd628;
					end
					10'd628:
						if ((ab_nblk != 32'd0) && (ab_fill != 5'd16))
							wr((adr(ab_blk) + 32'd4) + {25'd0, ab_fill, 2'b00}, t[3], 10'd629);
						else
							alloc(32'd17, 10'd631);
					10'd629: begin
						wr(adr(ab_blk), vint({27'd0, ab_fill} + 32'd1), 10'd630);
						ab_fill <= ab_fill + 5'd1;
						ab_nitems <= ab_nitems + 32'd1;
					end
					10'd630: st <= cv_ret;
					10'd631: begin
						ab_blk <= {ABI_TAG_TUPLE, al_a};
						t[2] <= {ABI_TAG_TUPLE, al_a};
						if (ab_ovf || (ab_nblk >= 32'd251))
							st <= 10'd634;
						else begin
							wr(ab_ptr(sv2v_cast_8(32'd5 + ab_nblk)), {ABI_TAG_TUPLE, al_a}, 10'd632);
							ab_nblk <= ab_nblk + 32'd1;
							ab_fill <= 5'd0;
						end
					end
					10'd632:
						wr(aoff(adr(ab_blk), 4), t[3], 10'd633);
					10'd633: begin
						wr(adr(ab_blk), vint(32'd1), 10'd630);
						ab_fill <= 5'd1;
						ab_nitems <= ab_nitems + 32'd1;
					end
					10'd634:
						if (!ab_ovf)
							alloc(32'd253, 10'd635);
						else
							rd(adr(t[5]), 10'd639);
					10'd635: begin
						t[4] <= {ABI_TAG_TUPLE, al_a};
						cv_k <= 32'd0;
						wr(al_a, vint(32'd252), 10'd636);
					end
					10'd636:
						if (cv_k == 32'd251) begin
							x0 <= 32'd252;
							wr((adr(t[4]) + 32'd4) + (32'd251 << 2), t[2], 10'd638);
						end
						else
							rd(ab_ptr(sv2v_cast_8(32'd5 + cv_k)), 10'd637);
					10'd637: begin
						wr((adr(t[4]) + 32'd4) + (cv_k << 2), mv, 10'd636);
						cv_k <= cv_k + 32'd1;
					end
					10'd638: begin
						wr(ab_ptr(8'd4), t[4], 10'd632);
						t[5] <= t[4];
						ab_ovf <= 1'b1;
						ab_nblk <= x0;
						ab_fill <= 5'd0;
					end
					10'd639: begin
						x1 <= md;
						alloc(md + 32'd2, 10'd640);
					end
					10'd640: begin
						t[4] <= {ABI_TAG_TUPLE, al_a};
						cv_k <= 32'd0;
						wr(al_a, vint(x1 + 32'd1), 10'd641);
					end
					10'd641:
						if (cv_k == x1) begin
							x0 <= ab_nblk + 32'd1;
							wr((adr(t[4]) + 32'd4) + (x1 << 2), t[2], 10'd638);
						end
						else
							rd((adr(t[5]) + 32'd4) + (cv_k << 2), 10'd642);
					10'd642: begin
						wr((adr(t[4]) + 32'd4) + (cv_k << 2), mv, 10'd641);
						cv_k <= cv_k + 32'd1;
					end
					10'd643:
						rd(ab_ptr(8'd0), 10'd644);
					10'd644: begin
						t[0] <= mv;
						if (ab_ovf) begin
							t[1] <= t[5];
							cv_k <= 32'd5;
							x1 <= 32'd256;
							st <= 10'd648;
						end
						else if (ab_nblk == 32'd0) begin
							t[1] <= {ABI_TAG_TUPLE, h_empty};
							cv_k <= 32'd5;
							x1 <= 32'd5;
							st <= 10'd648;
						end
						else
							alloc(32'd1 + ab_nblk, 10'd645);
					end
					10'd645: begin
						t[1] <= {ABI_TAG_TUPLE, al_a};
						cv_k <= 32'd0;
						wr(al_a, vint(ab_nblk), 10'd646);
					end
					10'd646:
						if (cv_k == ab_nblk) begin
							cv_k <= 32'd5;
							x1 <= 32'd5 + ab_nblk;
							st <= 10'd648;
						end
						else
							rd(ab_ptr(sv2v_cast_8(32'd5 + cv_k)), 10'd647);
					10'd647: begin
						wr((adr(t[1]) + 32'd4) + (cv_k << 2), mv, 10'd646);
						cv_k <= cv_k + 32'd1;
					end
					10'd648:
						if (cv_k == x1)
							st <= 10'd649;
						else begin
							wr(ab_ptr(cv_k[7:0]), VNULL, 10'd648);
							cv_k <= cv_k + 32'd1;
						end
					10'd649:
						if (ab_ovf)
							wr(ab_ptr(8'd4), VNULL, 10'd650);
						else
							st <= 10'd650;
					10'd650:
						wr(ab_ptr(8'd1), VNULL, 10'd94);
					10'd651: begin
						t[2] <= mv;
						alloc(32'd2, 10'd652);
					end
					10'd652: begin
						t[3] <= {ABI_TAG_TUPLE, al_a};
						wr(al_a, vint(32'd1), 10'd653);
					end
					10'd653:
						wr(aoff(al_a, 4), t[2], 10'd654);
					10'd654:
						alloc(32'd2 + ab_nblk, 10'd655);
					10'd655: begin
						t[4] <= {ABI_TAG_TUPLE, al_a};
						x0 <= al_a;
						cv_k <= 32'd0;
						wr(al_a, vint(ab_nblk + 32'd1), 10'd656);
					end
					10'd656:
						wr(aoff(x0, 4), t[3], 10'd657);
					10'd657:
						if (cv_k == ab_nblk) begin
							t[1] <= t[4];
							ab_npos <= ab_npos + 32'd1;
							ab_nblk <= ab_nblk + 32'd1;
							rd(aoff(adr(ab_q), 8), 10'd95);
						end
						else
							rd((adr(t[1]) + 32'd4) + (cv_k << 2), 10'd658);
					10'd658: begin
						wr((x0 + 32'd8) + (cv_k << 2), mv, 10'd657);
						cv_k <= cv_k + 32'd1;
					end
					10'd659:
						if (ab_lo0 != ab_lo) begin
							x1 <= {24'd0, ab_lo0} - {24'd0, ab_lo};
							cv_k <= 32'd0;
							alloc(32'd1 + ({24'd0, ab_lo0} - {24'd0, ab_lo}), 10'd660);
						end
						else
							st <= 10'd668;
					10'd660: begin
						t[3] <= {ABI_TAG_TUPLE, al_a};
						x0 <= al_a;
						wr(al_a, vint(x1), 10'd661);
					end
					10'd661:
						if (cv_k == x1)
							st <= 10'd664;
						else
							rd(ab_ptr(ab_lo + cv_k[7:0]), 10'd662);
					10'd662: begin
						wr((x0 + 32'd4) + (cv_k << 2), mv, 10'd661);
						cv_k <= cv_k + 32'd1;
					end
					10'd664: begin
						cv_k <= 32'd0;
						alloc(32'd2 + ab_nblk, 10'd663);
					end
					10'd663: begin
						t[4] <= {ABI_TAG_TUPLE, al_a};
						x0 <= al_a;
						wr(al_a, vint(ab_nblk + 32'd1), 10'd665);
					end
					10'd665:
						wr(aoff(x0, 4), t[3], 10'd666);
					10'd666:
						if (cv_k == ab_nblk) begin
							t[1] <= t[4];
							ab_npos <= ab_npos + x1;
							ab_nblk <= ab_nblk + 32'd1;
							ab_lo <= ab_lo0;
							st <= 10'd668;
						end
						else
							rd((adr(t[1]) + 32'd4) + (cv_k << 2), 10'd667);
					10'd667: begin
						wr((x0 + 32'd8) + (cv_k << 2), mv, 10'd666);
						cv_k <= cv_k + 32'd1;
					end
					10'd668:
						rd(ab_ptr(8'd0), 10'd669);
					10'd669: begin
						fflags <= fflags | FF_NOTB;
						fcont <= ABI_CONT_BIND;
						hook(ABI_HOOK_BIND_WIDE, ABI_RK_CONT, 8'd3, mv, vint(ab_npos), t[1], VNULL);
					end
					10'd536: begin
						v0 = sv2v_cast_32(n_o);
						if (v0 == ABI_UNOP_NOT) begin
							tr_v <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
							gosub(10'd524, 10'd267);
						end
						else if (numlike(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]) && (v0 <= ABI_UNOP_INVERT)) begin
							n_un <= 1'b1;
							alu_op <= (v0 == ABI_UNOP_POSITIVE ? mpy_alu_pkg_ALU_POS : (v0 == ABI_UNOP_NEGATIVE ? mpy_alu_pkg_ALU_NEG : mpy_alu_pkg_ALU_INVERT));
							t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
							t[1] <= vint(32'd0);
							if (tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]) != ABI_TAG_INT64) begin
								na_f <= tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]) == ABI_TAG_FLOAT;
								na <= sx64(ival(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]));
								nb_f <= 1'b0;
								nb <= 64'd0;
								st <= 10'd356;
							end
							else
								st <= 10'd349;
						end
						else begin
							sp <= sp - 7'd1;
							hook(ABI_HOOK_UNOP, ABI_RK_PUSH, 8'd2, vint(v0), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], VNULL, VNULL);
						end
					end
					10'd32: begin
						v0 = sv2v_cast_32(n_o);
						t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))];
						t[1] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
						n_un <= 1'b0;
						if (v0 == ABI_BINOP_IS) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= vbool(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] == rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]);
							sp <= sp - 7'd1;
							st <= 10'd147;
						end
						else if (v0 == ABI_BINOP_EXCEPTION_MATCH)
							st <= 10'd140;
						else if (v0 == ABI_BINOP_IN)
							st <= 10'd243;
						else if (((((tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))]) == ABI_TAG_COMPLEX) || (tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]) == ABI_TAG_COMPLEX)) && cx_operand(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))])) && cx_operand(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))])) && ((((((v0 == ABI_BINOP_ADD) || (v0 == ABI_BINOP_INPLACE_ADD)) || (v0 == ABI_BINOP_SUBTRACT)) || (v0 == ABI_BINOP_INPLACE_SUBTRACT)) || (v0 == ABI_BINOP_MULTIPLY)) || (v0 == ABI_BINOP_INPLACE_MULTIPLY))) begin
							cx_op <= ((v0 == ABI_BINOP_ADD) || (v0 == ABI_BINOP_INPLACE_ADD) ? CX_ADD : ((v0 == ABI_BINOP_SUBTRACT) || (v0 == ABI_BINOP_INPLACE_SUBTRACT) ? CX_SUB : CX_MUL));
							cx_start(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))], rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]);
						end
						else if ((numlike(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))]) && numlike(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))])) && ((v0 <= ABI_BINOP_NOT_EQUAL) || ((v0 >= ABI_BINOP_INPLACE_OR) && (v0 <= ABI_BINOP_POWER)))) begin
							alu_op <= ((v0 >= ABI_BINOP_INPLACE_OR) && (v0 < ABI_BINOP_OR) ? sv2v_cast_6(v0 + 32'd13) : sv2v_cast_6(v0));
							if ((tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))]) != ABI_TAG_INT64) && (tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]) != ABI_TAG_INT64)) begin
								na_f <= tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))]) == ABI_TAG_FLOAT;
								nb_f <= tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]) == ABI_TAG_FLOAT;
								na <= sx64(ival(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))]));
								nb <= sx64(ival(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]));
								st <= 10'd356;
							end
							else
								st <= 10'd349;
						end
						else if ((v0 == ABI_BINOP_EQUAL) || (v0 == ABI_BINOP_NOT_EQUAL))
							st <= 10'd137;
						else
							st <= 10'd33;
					end
					10'd33:
						if (((((n_o == ABI_BINOP_LESS) || (n_o == ABI_BINOP_MORE)) || (n_o == ABI_BINOP_LESS_EQUAL)) || (n_o == ABI_BINOP_MORE_EQUAL)) && ((strlike(t[0]) && strlike(t[1])) || ((tg(t[0]) == ABI_TAG_BYTES) && (tg(t[1]) == ABI_TAG_BYTES)))) begin
							b0 <= 1'b0;
							si_v <= t[0];
							gosub(10'd500, 10'd371);
						end
						else if (((n_o == ABI_BINOP_ADD) && is_mut(t[0], ABI_MUT_LIST)) && is_mut(t[1], ABI_MUT_LIST))
							rd(adr(t[0]), 10'd34);
						else if (h_bigint && ((tg(t[0]) == ABI_TAG_OBJECT) || (tg(t[1]) == ABI_TAG_OBJECT)))
							st <= 10'd45;
						else
							st <= 10'd44;
					10'd34: begin
						x0 <= md;
						rd(adr(t[1]), 10'd35);
					end
					10'd35: begin
						x1 <= md;
						x4 <= x0 + md;
						st <= 10'd36;
					end
					10'd36:
						alloc(32'd3 + (x4 < 32'd4 ? 32'd4 : x4), 10'd37);
					10'd37: begin
						t[2] <= vmut(al_a, ABI_MUT_LIST);
						wb_v[0] <= vint(x4);
						wb_v[1] <= vint((x4 < 32'd4 ? 32'd4 : x4));
						wb_v[2] <= {ABI_TAG_CONT, al_a + 32'd12};
						x3 <= al_a + 32'd12;
						b0 <= 1'b0;
						wblock(al_a, 4'd3, 10'd38);
					end
					10'd38:
						rd(aoff(adr(t[0]), 8), 10'd39);
					10'd39: begin
						x2 <= md;
						gi <= 32'd0;
						st <= 10'd40;
					end
					10'd40:
						if (x0 == 32'd0)
							st <= 10'd43;
						else if (cfg_ca) begin
							if (ca_ok) begin
								ca_ship(x3, x2, x0);
								st <= 10'd43;
							end
						end
						else
							st <= 10'd41;
					10'd41:
						if (gi == x0)
							st <= 10'd43;
						else
							rd(x2 + (gi << 2), 10'd42);
					10'd42: begin
						wr(x3 + (gi << 2), mv, 10'd41);
						gi <= gi + 32'd1;
					end
					10'd43:
						if (b0 || (x1 == 32'd0))
							st <= 10'd357;
						else begin
							b0 <= 1'b1;
							x3 <= x3 + (x0 << 2);
							x0 <= x1;
							rd(aoff(adr(t[1]), 8), 10'd39);
						end
					10'd45: begin
						v0 = sv2v_cast_32(n_o);
						if ((v0 >= ABI_BINOP_INPLACE_OR) && (v0 < ABI_BINOP_OR))
							v0 = v0 + 32'd13;
						if ((h_bigint && !n_un) && ((((v0 == ABI_BINOP_MULTIPLY) && (((tg(t[0]) == ABI_TAG_OBJECT) && (tg(t[1]) == ABI_TAG_INT)) || ((tg(t[1]) == ABI_TAG_OBJECT) && (tg(t[0]) == ABI_TAG_INT)))) || (((((v0 == ABI_BINOP_ADD) || (v0 == ABI_BINOP_SUBTRACT)) || (v0 == ABI_BINOP_FLOOR_DIVIDE)) && (tg(t[0]) == ABI_TAG_OBJECT)) && (tg(t[1]) == ABI_TAG_OBJECT))) || ((v0 == ABI_BINOP_ADD) && (((tg(t[0]) == ABI_TAG_OBJECT) && (t[1] == vint(32'd0))) || ((tg(t[1]) == ABI_TAG_OBJECT) && (t[0] == vint(32'd0))))))) begin
							bi_op <= sv2v_cast_6(v0);
							bi_an <= 18'd0;
							bi_bn <= 18'd0;
							bi_left_neg <= 1'b0;
							bi_right_neg <= 1'b0;
							if (tg(t[0]) == ABI_TAG_OBJECT)
								rd(adr(t[0]), 10'd46);
							else
								rd(adr(t[1]), 10'd48);
						end
						else
							st <= 10'd44;
					end
					10'd44: begin
						sp <= sp - 7'd2;
						hook(ABI_HOOK_BINOP, ABI_RK_PUSH, 8'd3, vint(sv2v_cast_32(n_o)), t[0], t[1], VNULL);
					end
					10'd46:
						if (md == ABI_OB_BIGINT)
							rd(aoff(adr(t[0]), 8), 10'd47);
						else
							st <= 10'd44;
					10'd47: begin
						bi_an <= (md[31] ? -md[17:0] : md[17:0]);
						bi_left_neg <= md[31];
						if (tg(t[1]) == ABI_TAG_OBJECT)
							rd(adr(t[1]), 10'd48);
						else
							st <= 10'd50;
					end
					10'd48:
						if (md == ABI_OB_BIGINT)
							rd(aoff(adr(t[1]), 8), 10'd49);
						else
							st <= 10'd44;
					10'd49: begin
						bi_bn <= (md[31] ? -md[17:0] : md[17:0]);
						bi_right_neg <= md[31] ^ (bi_op == mpy_alu_pkg_ALU_SUB);
						st <= 10'd50;
					end
					10'd50: begin
						bi_swap <= 1'b0;
						bi_sub <= bi_left_neg ^ bi_right_neg;
						bi_neg <= bi_left_neg;
						if (bi_op == mpy_alu_pkg_ALU_MUL) begin
							if (($signed(bi_scalar) < -32'sd1073741823) || ($signed(bi_scalar) > 32'sd1073741823))
								st <= 10'd44;
							else if (bi_scalar == 32'd0) begin
								t[2] <= vint(32'd0);
								st <= 10'd357;
							end
							else if (bi_scalar == 32'd1) begin
								t[2] <= (bi_an != 0 ? t[0] : t[1]);
								st <= 10'd357;
							end
							else begin
								limb_factor <= (bi_scalar[31] ? -bi_scalar : bi_scalar);
								bi_neg <= (bi_left_neg ^ bi_right_neg) ^ bi_scalar[31];
								alloc(sv2v_cast_32(bi_an | bi_bn) + 32'd4, 10'd54);
							end
						end
						else if (bi_op == mpy_alu_pkg_ALU_FLOOR) begin
							if (((bi_left_neg != bi_right_neg) || (bi_bn < 18'd2)) || (bi_an > (bi_bn + 18'd1)))
								st <= 10'd44;
							else if (bi_an < bi_bn) begin
								t[2] <= vint(32'd0);
								st <= 10'd357;
							end
							else if (bi_an != bi_bn)
								rd((adr(t[0]) + 32'd8) + (sv2v_cast_32(bi_an) << 2), 10'd58);
							else begin
								bi_prefix <= 64'd0;
								rd((adr(t[0]) + 32'd8) + (sv2v_cast_32(bi_bn) << 2), 10'd59);
							end
						end
						else if ((bi_an == 0) || (bi_bn == 0)) begin
							t[2] <= (bi_an != 0 ? t[0] : t[1]);
							st <= 10'd357;
						end
						else if (bi_left_neg == bi_right_neg)
							st <= 10'd53;
						else if (bi_an != bi_bn) begin
							bi_swap <= bi_an < bi_bn;
							st <= 10'd53;
						end
						else begin
							bi_i <= bi_an;
							rd((adr(t[0]) + 32'd8) + (sv2v_cast_32(bi_an) << 2), 10'd51);
						end
					end
					10'd51: begin
						bi_cmp_l <= md;
						rd((adr(t[1]) + 32'd8) + (sv2v_cast_32(bi_i) << 2), 10'd52);
					end
					10'd52:
						if (md != bi_cmp_l) begin
							bi_swap <= bi_cmp_l < md;
							st <= 10'd53;
						end
						else if (bi_i == 18'd1) begin
							t[2] <= vint(32'd0);
							st <= 10'd357;
						end
						else begin
							bi_i <= bi_i - 18'd1;
							rd((adr(t[0]) + 32'd4) + (sv2v_cast_32(bi_i) << 2), 10'd51);
						end
					10'd53: begin
						bi_neg <= (bi_swap ? bi_right_neg : bi_left_neg);
						limb_factor <= (bi_sub ? 32'hffffffff : 32'd1);
						alloc(sv2v_cast_32((bi_an > bi_bn ? bi_an : bi_bn)) + 32'd4, 10'd54);
					end
					10'd54: begin
						x0 <= al_a + 32'd12;
						if (bi_op == mpy_alu_pkg_ALU_MUL) begin
							x1 <= adr((bi_an != 0 ? t[0] : t[1])) + 32'd12;
							x3 <= (adr((bi_an != 0 ? t[0] : t[1])) + 32'd12) + (sv2v_cast_32(bi_an | bi_bn) << 2);
							x2 <= 32'd0;
							x4 <= 32'd0;
						end
						else if (bi_sub && !bi_swap) begin
							x1 <= adr(t[1]) + 32'd12;
							x3 <= (adr(t[1]) + 32'd12) + (sv2v_cast_32(bi_bn) << 2);
							x2 <= adr(t[0]) + 32'd12;
							x4 <= (adr(t[0]) + 32'd12) + (sv2v_cast_32(bi_an) << 2);
						end
						else begin
							x1 <= adr(t[0]) + 32'd12;
							x3 <= (adr(t[0]) + 32'd12) + (sv2v_cast_32(bi_an) << 2);
							x2 <= adr(t[1]) + 32'd12;
							x4 <= (adr(t[1]) + 32'd12) + (sv2v_cast_32(bi_bn) << 2);
						end
						bi_inline <= 1'b1;
						bi_i <= 18'd0;
						bi_used <= 18'd0;
						bi_top <= 30'd0;
						bi_low_nonzero <= 1'b0;
						limb_carry <= 32'd0;
						st <= 10'd701;
					end
					10'd55:
						if (limb_carry == 32'd0)
							st <= 10'd56;
						else begin
							bi_used <= bi_i + 18'd1;
							bi_top <= limb_carry[29:0];
							wr(x0, vint(limb_carry), 10'd56);
						end
					10'd56:
						if (bi_used == 0) begin
							t[2] <= vint(32'd0);
							st <= 10'd357;
						end
						else if ((bi_used < 18'd3) || ((bi_used == 18'd3) && ((bi_top < 30'd8) || ((bi_neg && (bi_top == 30'd8)) && !bi_low_nonzero))))
							st <= 10'd44;
						else
							rd(TT + (4 * ABI_T_INT), 10'd57);
					10'd57: begin
						t[2] <= vobj(al_a);
						wb_v[0] <= vint(ABI_OB_BIGINT);
						wb_v[1] <= mv;
						wb_v[2] <= vint((bi_neg ? -sv2v_cast_32(bi_used) : sv2v_cast_32(bi_used)));
						wblock(al_a, 4'd3, 10'd357);
					end
					10'd58:
						if (md > 32'd7)
							st <= 10'd44;
						else begin
							bi_prefix <= {1'b0, md[2:0], 60'd0};
							rd((adr(t[0]) + 32'd8) + (sv2v_cast_32(bi_bn) << 2), 10'd59);
						end
					10'd59: begin
						bi_prefix[59:30] <= md[29:0];
						rd(m_addr - 32'd4, 10'd60);
					end
					10'd60: begin
						bi_prefix[29:0] <= md[29:0];
						rd((adr(t[1]) + 32'd8) + (sv2v_cast_32(bi_bn) << 2), 10'd61);
					end
					10'd61: begin
						nb[63:30] <= {4'd0, md[29:0]};
						rd(m_addr - 32'd4, 10'd62);
					end
					10'd62: begin
						nb[29:0] <= md[29:0];
						st <= 10'd63;
					end
					10'd63: begin
						na <= bi_prefix;
						na_f <= 1'b0;
						nb_f <= 1'b0;
						n_small <= 1'b0;
						alu_op <= mpy_alu_pkg_ALU_FLOOR;
						alu_start <= 1'b1;
						st <= 10'd64;
					end
					10'd64:
						if (alu_done) begin
							if ((alu_err != mpy_alu_pkg_AE_NONE) || (alu_res[63:31] != 0))
								st <= 10'd44;
							else if (alu_res == 0) begin
								t[2] <= vint(32'd0);
								st <= 10'd357;
							end
							else begin
								bi_q <= alu_res[31:0];
								na <= alu_res;
								alu_op <= mpy_alu_pkg_ALU_MUL;
								alu_start <= 1'b1;
								st <= 10'd65;
							end
						end
					10'd65:
						if (alu_done) begin
							if ((alu_err == mpy_alu_pkg_AE_NONE) && ((bi_prefix - alu_res) >= sv2v_cast_64(bi_q))) begin
								t[2] <= vint(bi_q);
								st <= 10'd357;
							end
							else
								st <= 10'd44;
						end
					10'd137: begin
						vb = sv2v_cast_32(n_o) == ABI_BINOP_NOT_EQUAL;
						if (((t[0] == t[1]) && (tg(t[0]) != ABI_TAG_OBJECT)) && (tg(t[0]) != ABI_TAG_COMPLEX)) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= vbool(!vb);
							sp <= sp - 7'd1;
							st <= 10'd147;
						end
						else if (strlike(t[0]) && strlike(t[1])) begin
							se_a <= t[0];
							se_b <= t[1];
							gosub_scr(SCR_SE, 10'd521, 10'd138);
						end
						else if (((strlike(t[0]) || strlike(t[1])) || ((tg(t[0]) == ABI_TAG_CONTROL) && (tg(t[1]) != ABI_TAG_OBJECT))) || ((tg(t[1]) == ABI_TAG_CONTROL) && (tg(t[0]) != ABI_TAG_OBJECT))) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= vbool(vb);
							sp <= sp - 7'd1;
							st <= 10'd147;
						end
						else
							st <= 10'd44;
					end
					10'd138: begin
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= vbool(se_eq ^ (sv2v_cast_32(n_o) == ABI_BINOP_NOT_EQUAL));
						sp <= sp - 7'd1;
						st <= 10'd147;
					end
					10'd243:
						if (is_mut(t[1], ABI_MUT_DICT) || is_mut(t[1], ABI_MUT_SET))
							lookup(t[1], t[0], VNULL, LK_FIND, is_mut(t[1], ABI_MUT_SET), 10'd244);
						else if ((tg(t[0]) == ABI_TAG_INT) && (is_mut(t[1], ABI_MUT_LIST) || (tg(t[1]) == ABI_TAG_TUPLE)))
							rd(adr(t[1]), 10'd245);
						else
							st <= 10'd44;
					10'd245: begin
						x4 <= md;
						gi <= 32'd0;
						if (tg(t[1]) == ABI_TAG_TUPLE) begin
							x3 <= adr(t[1]) + 32'd4;
							st <= 10'd247;
						end
						else
							rd(aoff(adr(t[1]), 8), 10'd246);
					end
					10'd246: begin
						x3 <= md;
						st <= 10'd247;
					end
					10'd247:
						if (gi == x4) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= VFALSE;
							sp <= sp - 7'd1;
							st <= 10'd147;
						end
						else
							rd(x3 + (gi << 2), 10'd248);
					10'd248:
						if (((tg(mv) == ABI_TAG_INT) && (mv[31:0] == t[0][31:0])) || (is_bool(mv) && (t[0][31:0] == {31'd0, mv == VTRUE}))) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= VTRUE;
							sp <= sp - 7'd1;
							st <= 10'd147;
						end
						else if (((((((((tg(mv) == ABI_TAG_INT) || is_bool(mv)) || (mv == VNONE)) || (tg(mv) == ABI_TAG_QSTR)) || (tg(mv) == ABI_TAG_STR)) || (tg(mv) == ABI_TAG_BYTES)) || (tg(mv) == ABI_TAG_TUPLE)) || (tg(mv) == ABI_TAG_MUT)) || (tg(mv) == ABI_TAG_RANGE)) begin
							gi <= gi + 32'd1;
							st <= 10'd247;
						end
						else
							st <= 10'd44;
					10'd244:
						if (lk_cx)
							st <= 10'd44;
						else begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= vbool(lk_found);
							sp <= sp - 7'd1;
							st <= 10'd147;
						end
					10'd140:
						if (tg(t[0]) != ABI_TAG_OBJECT)
							st <= 10'd44;
						else
							rd(aoff(adr(t[0]), 4), 10'd142);
					10'd142: begin
						is_t <= mv;
						if (tg(t[1]) == ABI_TAG_OBJECT) begin
							is_c <= t[1];
							gosub(10'd249, 10'd141);
						end
						else if (tg(t[1]) == ABI_TAG_TUPLE)
							rd(adr(t[1]), 10'd145);
						else
							st <= 10'd44;
					end
					10'd141: begin
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= vbool(is_r);
						sp <= sp - 7'd1;
						st <= 10'd147;
					end
					10'd145: begin
						x4 <= md;
						gi <= 32'd0;
						st <= 10'd144;
					end
					10'd144:
						if (gi == x4) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= VFALSE;
							sp <= sp - 7'd1;
							st <= 10'd147;
						end
						else
							rd((adr(t[1]) + 4) + (gi << 2), 10'd143);
					10'd143: begin
						is_c <= mv;
						gosub(10'd249, 10'd146);
					end
					10'd146:
						if (is_r) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= VTRUE;
							sp <= sp - 7'd1;
							st <= 10'd147;
						end
						else begin
							gi <= gi + 32'd1;
							st <= 10'd144;
						end
					10'd349: begin
						na_f <= tg(t[0]) == ABI_TAG_FLOAT;
						if (tg(t[0]) == ABI_TAG_INT64)
							rd(adr(t[0]), 10'd351);
						else begin
							na <= sx64(ival(t[0]));
							st <= 10'd352;
						end
					end
					10'd351: begin
						na[31:0] <= md;
						rd(aoff(adr(t[0]), 4), 10'd350);
					end
					10'd350: begin
						na[63:32] <= md;
						st <= 10'd352;
					end
					10'd352: begin
						nb_f <= tg(t[1]) == ABI_TAG_FLOAT;
						if (tg(t[1]) == ABI_TAG_INT64)
							rd(adr(t[1]), 10'd354);
						else begin
							nb <= sx64(ival(t[1]));
							st <= 10'd356;
						end
					end
					10'd354: begin
						nb[31:0] <= md;
						rd(aoff(adr(t[1]), 4), 10'd353);
					end
					10'd353: begin
						nb[63:32] <= md;
						st <= 10'd356;
					end
					10'd356:
						if (((h_bigint && !n_un) && ((tg(t[0]) == ABI_TAG_INT64) || (tg(t[1]) == ABI_TAG_INT64))) && (((na_f || nb_f) || (alu_op == mpy_alu_pkg_ALU_TDIV)) || ((alu_op == mpy_alu_pkg_ALU_POW) && nb[63])))
							st <= 10'd44;
						else begin
							n_small <= (!na_f && !nb_f) && (h_bigint || (fits31(na) && fits31(nb)));
							alu_start <= 1'b1;
							if (cfg_aalu && aalu_safe(alu_op, n_un, na_f, nb_f, na, nb)) begin
								aalu_pend <= 1'b1;
								aalu_slot <= rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2));
								sp <= sp - 7'd1;
								go_next;
							end
							else
								st <= 10'd358;
						end
					10'd358:
						if (alu_done)
							case (alu_err)
								mpy_alu_pkg_AE_NONE:
									if (alu_kind == mpy_alu_pkg_AK_BOOL) begin
										t[2] <= vbool(alu_res[0]);
										st <= 10'd357;
									end
									else if (alu_kind == mpy_alu_pkg_AK_FLOAT) begin
										t[2] <= {ABI_TAG_FLOAT, alu_res[31:0]};
										st <= 10'd357;
									end
									else if (fits32(alu_res)) begin
										t[2] <= vint(alu_res[31:0]);
										st <= 10'd357;
									end
									else
										alloc(32'd2, 10'd355);
								mpy_alu_pkg_AE_ZERO_DIV:
									raise_msg(ABI_MSG_DIV_ZERO);
								mpy_alu_pkg_AE_OVERFLOW:
									if ((h_bigint && !na_f) && !nb_f) begin
										sp <= sp - (n_un ? 7'd1 : 7'd2);
										hook(ABI_HOOK_INT_OVERFLOW, ABI_RK_PUSH, 8'd3, vint(sv2v_cast_32(n_o)), t[0], (n_un ? VNULL : t[1]), VNULL);
									end
									else
										raise_msg(ABI_MSG_OVERFLOW);
								mpy_alu_pkg_AE_NEG_SHIFT:
									raise_msg(ABI_MSG_NEG_SHIFT);
								default:
									if (n_un) begin
										sp <= sp - 7'd1;
										hook(ABI_HOOK_UNOP, ABI_RK_PUSH, 8'd2, vint(sv2v_cast_32(n_o)), t[0], VNULL, VNULL);
									end
									else
										st <= 10'd44;
							endcase
					10'd355: begin
						wb_v[0] <= vint(alu_res[31:0]);
						wb_v[1] <= vint(alu_res[63:32]);
						t[2] <= {ABI_TAG_INT64, al_a};
						wblock(al_a, 4'd2, 10'd357);
					end
					10'd777: begin
						rf[aalu_slot] <= (alu_kind == mpy_alu_pkg_AK_BOOL ? vbool(alu_res[0]) : (alu_kind == mpy_alu_pkg_AK_FLOAT ? {ABI_TAG_FLOAT, alu_res[31:0]} : vint(alu_res[31:0])));
						aalu_pend <= 1'b0;
						aalu_ready <= 1'b0;
						st <= aalu_ret;
					end
					10'd357: begin
						if (n_un)
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= t[2];
						else begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= t[2];
							sp <= sp - 7'd1;
						end
						go_next;
					end
					10'd359: begin
						if (!m_wait) begin
							if (bl_n == 8'd1) begin
								bload(ha_cx_pa4);
								bl_n <= 8'd2;
							end
							else if ((bl_n == 8'd2) && cx_bcx) begin
								bload(cx_pb);
								bl_n <= 8'd3;
							end
							else if (bl_n == 8'd3) begin
								bload(ha_cx_pb4);
								bl_n <= 8'd4;
							end
						end
						if (m_ack_i && (wpend == 3'd0)) begin
							v0 = {29'd0, ((bl_k == 3'd0) && !cx_acx ? 3'd2 : bl_k)};
							if (m_fault_i)
								halt(fault_code(m_fault_reason_i), (v0 < 32'd2 ? cx_pa + (v0 << 2) : cx_pb + ((v0 - 32'd2) << 2)));
							else begin
								case (v0[1:0])
									2'd0: cx_ar <= m_rdata_i;
									2'd1: cx_ai <= m_rdata_i;
									2'd2: cx_br <= m_rdata_i;
									default: cx_bi <= m_rdata_i;
								endcase
								bl_k <= v0[2:0] + 3'd1;
								if ((v0 == 32'd3) || ((v0 == 32'd1) && (!cx_bcx || (cx_op == CX_ABS))))
									st <= 10'd360;
							end
						end
					end
					10'd360: begin
						na_f <= 1'b1;
						nb_f <= 1'b1;
						n_small <= 1'b0;
						n_un <= 1'b0;
						case (cx_op)
							CX_ADD, CX_SUB: begin
								alu_op <= (cx_op == CX_ADD ? mpy_alu_pkg_ALU_ADD : mpy_alu_pkg_ALU_SUB);
								na <= sx64((cx_k[0] ? cx_ai : cx_ar));
								nb <= sx64((cx_k[0] ? cx_bi : cx_br));
							end
							CX_MUL:
								case (cx_k)
									3'd0: begin
										alu_op <= mpy_alu_pkg_ALU_MUL;
										na <= sx64(cx_ar);
										nb <= sx64(cx_br);
									end
									3'd1: begin
										alu_op <= mpy_alu_pkg_ALU_MUL;
										na <= sx64(cx_ai);
										nb <= sx64(cx_bi);
									end
									3'd2: begin
										alu_op <= mpy_alu_pkg_ALU_SUB;
										na <= sx64(cx_t0);
										nb <= sx64(cx_t1);
									end
									3'd3: begin
										alu_op <= mpy_alu_pkg_ALU_MUL;
										na <= sx64(cx_ar);
										nb <= sx64(cx_bi);
									end
									3'd4: begin
										alu_op <= mpy_alu_pkg_ALU_MUL;
										na <= sx64(cx_ai);
										nb <= sx64(cx_br);
									end
									default: begin
										alu_op <= mpy_alu_pkg_ALU_ADD;
										na <= sx64(cx_t0);
										nb <= sx64(cx_t1);
									end
								endcase
							default:
								case (cx_k)
									3'd0: begin
										alu_op <= mpy_alu_pkg_ALU_MUL;
										na <= sx64(cx_ar);
										nb <= sx64(cx_ar);
									end
									3'd1: begin
										alu_op <= mpy_alu_pkg_ALU_MUL;
										na <= sx64(cx_ai);
										nb <= sx64(cx_ai);
									end
									3'd2: begin
										alu_op <= mpy_alu_pkg_ALU_ADD;
										na <= sx64(cx_t0);
										nb <= sx64(cx_t1);
									end
									default: begin
										alu_op <= mpy_alu_pkg_ALU_POW;
										na <= sx64(cx_t0);
										nb <= sx64(32'h3f000000);
									end
								endcase
						endcase
						alu_start <= 1'b1;
						st <= 10'd361;
					end
					10'd361:
						if (alu_done) begin
							if ((alu_err != mpy_alu_pkg_AE_NONE) || (alu_kind != mpy_alu_pkg_AK_FLOAT)) begin
								if (cx_op == CX_ABS)
									st <= 10'd340;
								else
									st <= 10'd44;
							end
							else begin
								cx_k <= cx_k + 3'd1;
								cx_im <= alu_res[31:0];
								st <= 10'd360;
								case (cx_op)
									CX_ADD, CX_SUB:
										if (cx_k == 3'd0)
											cx_re <= alu_res[31:0];
										else
											alloc(32'd2, 10'd362);
									CX_MUL:
										case (cx_k)
											3'd0, 3'd3: cx_t0 <= alu_res[31:0];
											3'd1, 3'd4: cx_t1 <= alu_res[31:0];
											3'd2: cx_re <= alu_res[31:0];
											default:
												alloc(32'd2, 10'd362);
										endcase
									default:
										case (cx_k)
											3'd0, 3'd2: cx_t0 <= alu_res[31:0];
											3'd1: cx_t1 <= alu_res[31:0];
											default:
												deliver({ABI_TAG_FLOAT, alu_res[31:0]}, crk);
										endcase
								endcase
							end
						end
					10'd362: begin
						wb_v[0] <= vint(cx_re);
						wb_v[1] <= vint(cx_im);
						t[2] <= {ABI_TAG_COMPLEX, al_a};
						wblock(al_a, 4'd2, 10'd357);
					end
					10'd339:
						if (ab_nkw != 8'd0)
							st <= 10'd340;
						else
							rd(ab_ptr(ab_lo), 10'd672);
					10'd672: begin
						ab_q <= mv;
						v0 = sv2v_cast_32(ab_pe - ab_lo);
						v1 = mv[31:0];
						case (nid)
							ABI_N_LEN:
								if (v0 != 32'd1)
									st <= 10'd340;
								else if (strlike(mv) || (tg(mv) == ABI_TAG_BYTES)) begin
									si_v <= mv;
									gosub(10'd500, 10'd419);
								end
								else if ((((tg(mv) == ABI_TAG_TUPLE) || is_mut(mv, ABI_MUT_LIST)) || is_mut(mv, ABI_MUT_DICT)) || is_mut(mv, ABI_MUT_SET))
									rd(adr(mv), 10'd425);
								else
									st <= 10'd340;
							ABI_N_ISINSTANCE:
								if (v0 != 32'd2)
									st <= 10'd340;
								else
									rd(ab_ptr(ab_lo + 8'd1), 10'd674);
							ABI_N_ID:
								deliver(vint(v1), crk);
							ABI_N_WFE: begin
								wfe_n <= v1;
								st <= 10'd813;
							end
							ABI_N_HLOCK: begin
								hl_cnt <= hl_cnt + 15'd1;
								deliver(VNONE, crk);
							end
							ABI_N_HUNLOCK: begin
								hl_cnt <= hl_cnt - 15'd1;
								deliver(vint({17'd0, hl_cnt - 15'd1}), crk);
							end
							ABI_N_WR, ABI_N_WE: begin
								x4 <= ABI_SIM_BASE + (4 * (nid == ABI_N_WR ? ABI_SIM_STDOUT : ABI_SIM_STDERR));
								if (tg(mv) == ABI_TAG_INT)
									wr(ABI_SIM_BASE + (4 * (nid == ABI_N_WR ? ABI_SIM_STDOUT : ABI_SIM_STDERR)), mv, 10'd421);
								else begin
									si_v <= mv;
									gosub(10'd500, 10'd437);
								end
							end
							ABI_N_HALT:
								halt((v1 == 32'd0 ? ABI_HALT_CLEAN : ABI_HALT_SYSEXIT), v1);
							ABI_N_TAG:
								deliver(vint({28'd0, tg(mv)}), crk);
							ABI_N_PAY:
								deliver(vint(v1), crk);
							ABI_N_MK:
								rd(ab_ptr(ab_lo + 8'd1), 10'd681);
							ABI_N_LD:
								rd(ab_ptr(ab_lo + 8'd1), 10'd682);
							ABI_N_ST:
								rd(ab_ptr(ab_lo + 8'd1), 10'd683);
							ABI_N_PEEK8:
								rd(ab_ptr(ab_lo + 8'd1), 10'd685);
							ABI_N_POKE8:
								rd(ab_ptr(ab_lo + 8'd1), 10'd686);
							ABI_N_PEEK32:
								rd(v1, 10'd425);
							ABI_N_ALLOC:
								alloc(v1, 10'd363);
							ABI_N_TYPEOF: begin
								ty_v <= mv;
								gosub(10'd531, 10'd434);
							end
							ABI_N_CALLNS:
								if (tg(mv) == ABI_TAG_INT)
									rd(ab_ptr(ab_lo + 8'd1), 10'd688);
								else
									wr(ab_ptr(8'd0), mv, 10'd689);
							ABI_N_WCOPY:
								rd(ab_ptr(ab_lo + 8'd1), 10'd691);
							ABI_N_LIMB_MAC:
								if (v0 != 32'd6)
									st <= 10'd340;
								else begin
									x0 <= padr(mv) + 32'd12;
									rd(ab_ptr(ab_lo + 8'd1), 10'd696);
								end
							ABI_N_LIMB_NEW:
								if (v0 != 32'd1)
									st <= 10'd340;
								else if ((tg(mv) != ABI_TAG_INT) || (v1 > 122557))
									raise_msg(ABI_MSG_MEMORY);
								else
									alloc(v1 + 32'd3, 10'd707);
							ABI_N_BCOPY:
								rd(ab_ptr(ab_lo + 8'd2), 10'd709);
							ABI_N_STRNEW:
								if ((!intlike(mv) || v1[31]) || (v1 > (ABI_GC_POOL_BYTES - 32'd12)))
									alloc(122561, 10'd432);
								else
									alloc(32'd3 + ((v1 + 32'd3) >> 2), 10'd432);
							ABI_N_STRFIN:
								rd(adr(mv), 10'd427);
							ABI_N_LOOKUP:
								rd(ab_ptr(ab_lo + 8'd1), 10'd710);
							ABI_N_TICKS:
								deliver(vint({2'b00, cyc[29:0]}), crk);
							ABI_N_GC:
								gosub(10'd209, 10'd421);
							ABI_N_GCINFO:
								deliver(vint((v1 == 32'd0 ? gc_free_i << 4 : (v1 == 32'd1 ? gc_total_i << 4 : gc_collections_i))), crk);
							ABI_N_FTOI: begin
								t[0] <= mv;
								t[1] <= vint(32'd0);
								n_un <= 1'b1;
								alu_op <= mpy_alu_pkg_ALU_F2I;
								st <= 10'd385;
							end
							ABI_N_ABS:
								if (v0 != 32'd1)
									st <= 10'd340;
								else if (tg(mv) == ABI_TAG_COMPLEX) begin
									cx_op <= CX_ABS;
									cx_start(mv, VNULL);
								end
								else if (!(((tg(mv) == ABI_TAG_INT) || (tg(mv) == ABI_TAG_FLOAT)) || is_bool(mv)))
									st <= 10'd340;
								else begin
									na_f <= tg(mv) == ABI_TAG_FLOAT;
									na <= sx64(ival(mv));
									nb_f <= 1'b0;
									nb <= 64'd0;
									n_small <= 1'b0;
									alu_op <= mpy_alu_pkg_ALU_ABS;
									alu_start <= 1'b1;
									st <= 10'd388;
								end
							ABI_N_GETATTR:
								if ((v0 != 32'd2) && (v0 != 32'd3))
									st <= 10'd340;
								else
									rd(ab_ptr(ab_lo + 8'd1), 10'd675);
							ABI_N_SETATTR:
								if (v0 != 32'd3)
									st <= 10'd340;
								else
									rd(ab_ptr(ab_lo + 8'd1), 10'd679);
							ABI_N_INEXT:
								if (tg(mv) != ABI_TAG_ITER)
									deliver(VNULL, crk);
								else begin
									t[3] <= mv;
									i0 <= 8'd0;
									st <= 10'd412;
								end
							ABI_N_GRESUME:
								if (v0 != 32'd3)
									st <= 10'd340;
								else begin
									r_rk <= crk;
									t[0] <= mv;
									rd(ab_ptr(ab_lo + 8'd1), 10'd720);
								end
							ABI_N_FIND_BYTES:
								if ((v0 != 32'd4) || !(strlike(mv) || (tg(mv) == ABI_TAG_BYTES)))
									st <= 10'd340;
								else begin
									t[0] <= mv;
									rd(ab_ptr(ab_lo + 8'd1), 10'd373);
								end
							ABI_N_BCMP: begin
								b0 <= 1'b1;
								si_v <= mv;
								gosub(10'd500, 10'd371);
							end
							ABI_N_SEQSCAN:
								if ((!cfg_ca || !cfg_bulk) || (v0 != 5))
									deliver(vint(32'hfffffffe), crk);
								else begin
									mb_op_o <= 7;
									mb_set_o <= 1;
									mb_src_o <= ab_ptr(ab_lo + 8'd3);
									mb_sn_o <= 1;
									mb_header_o <= 0;
									mb_source_header_o <= 0;
									mb_hashes_o <= 0;
									rd(ab_ptr(ab_lo + 8'd1), 10'd390);
								end
							ABI_N_SEQREVERSE:
								if ((!cfg_ca || !cfg_bulk) || (v0 != 2))
									deliver(VFALSE, crk);
								else
									rd(ab_ptr(ab_lo + 8'd1), 10'd393);
							ABI_N_MAPINSERT_HASHED:
								if (((!cfg_ca || !cfg_bulk) || (v0 != 6)) || !(is_mut(mv, ABI_MUT_DICT) || is_mut(mv, ABI_MUT_SET)))
									deliver(VFALSE, crk);
								else begin
									mb_header_o <= adr(mv);
									mb_set_o <= is_mut(mv, ABI_MUT_SET);
									mb_op_o <= 0;
									mb_source_header_o <= 0;
									mb_src_o <= ab_ptr(ab_lo + 8'd3);
									mb_sn_o <= 1;
									mb_hashes_o <= ab_ptr(ab_lo + 8'd5);
									rd(ab_ptr(ab_lo + 8'd1), 10'd395);
								end
							ABI_N_MAPBULK, ABI_N_MAPRELATION:
								if ((((!cfg_ca || !cfg_bulk) || (v0 != 3)) || (tg(mv) != ABI_TAG_MUT)) || !(is_mut(mv, ABI_MUT_DICT) || is_mut(mv, ABI_MUT_SET)))
									deliver((nid == ABI_N_MAPRELATION ? vint(32'hffffffff) : VFALSE), crk);
								else begin
									mb_hashes_o <= 0;
									mb_header_o <= adr(mv);
									mb_set_o <= is_mut(mv, ABI_MUT_SET);
									rd(ab_ptr(ab_lo + 8'd1), 10'd399);
								end
							ABI_N_HASH: begin
								hk <= mv;
								gosub(10'd231, 10'd389);
							end
							ABI_N_DATA: begin
								si_v <= mv;
								gosub(10'd129, 10'd383);
							end
							ABI_N_FGET:
								if (fprev == 32'd0)
									deliver(VNULL, crk);
								else begin
									x3 <= v1;
									rd(fprev + (v1 << 2), 10'd384);
								end
							ABI_N_FLOC:
								if (fprev == 32'd0)
									deliver(VNULL, crk);
								else
									rd((fprev + 32'd64) + (v1 << 2), 10'd426);
							ABI_N_QXSET: begin
								h_qext <= mv[31:0];
								rd(ab_ptr(ab_lo + 8'd1), 10'd754);
							end
							ABI_N_SLEN:
								if ((tg(mv) == ABI_TAG_MUT) || (tg(mv) == ABI_TAG_TUPLE))
									rd(adr(mv), 10'd425);
								else begin
									si_v <= mv;
									gosub(10'd500, 10'd419);
								end
							ABI_N_LIST_APPEND:
								if ((v0 != 32'd2) || !is_mut(mv, ABI_MUT_LIST))
									st <= 10'd340;
								else begin
									t[2] <= mv;
									rd(ab_ptr(ab_lo + 8'd1), 10'd722);
								end
							ABI_N_LIST_COPY:
								if (((v0 != 1) || !is_mut(mv, ABI_MUT_LIST)) || (cfg_sl == 0))
									st <= 10'd340;
								else begin
									t[0] <= mv;
									ss_store <= 0;
									ss_native <= 1;
									ss_back <= 10'd796;
									st <= 10'd799;
								end
							ABI_N_ORD:
								if ((v0 != 32'd1) || !(strlike(mv) || (tg(mv) == ABI_TAG_BYTES)))
									st <= 10'd340;
								else begin
									si_v <= mv;
									gosub(10'd500, 10'd713);
								end
							ABI_N_CHR:
								if (((v0 != 32'd1) || (tg(mv) != ABI_TAG_INT)) || (v1 >= 32'd128))
									st <= 10'd340;
								else
									rd(h_chars + (v1 << 2), 10'd715);
							ABI_N_DICT_GET:
								if (((v0 != 32'd2) && (v0 != 32'd3)) || !is_mut(mv, ABI_MUT_DICT))
									st <= 10'd340;
								else
									rd(ab_ptr(ab_lo + 8'd1), 10'd711);
							ABI_N_LIST_POP:
								if (((v0 != 32'd1) && (v0 != 32'd2)) || !is_mut(mv, ABI_MUT_LIST))
									st <= 10'd340;
								else begin
									t[2] <= mv;
									x0 <= 32'hffffffff;
									if (v0 == 32'd2)
										rd(ab_ptr(ab_lo + 8'd1), 10'd723);
									else
										rd(adr(mv), 10'd724);
								end
							ABI_N_LIST_INSERT:
								if ((v0 != 32'd3) || !is_mut(mv, ABI_MUT_LIST))
									st <= 10'd340;
								else begin
									t[2] <= mv;
									rd(ab_ptr(ab_lo + 8'd1), 10'd735);
								end
							ABI_N_WCOPY_STEP:
								if (v0 != 32'd6)
									st <= 10'd340;
								else
									rd(ab_ptr(ab_lo + 8'd1), 10'd747);
							ABI_N_OBJECT_INIT:
								if (v0 != 32'd1)
									st <= 10'd340;
								else
									deliver(VNONE, crk);
							ABI_N_BASEEXCEPTION_INIT:
								if ((v0 < 32'd1) || (tg(mv) != ABI_TAG_OBJECT))
									st <= 10'd340;
								else begin
									t[0] <= mv;
									tb_src <= 1'b0;
									tb_nz <= 1'b0;
									tb_from <= ab_lo + 8'd1;
									tb_n <= sv2v_cast_16((ab_pe - ab_lo) - 8'd1);
									gosub(10'd528, 10'd382);
								end
							ABI_N_NEW_RANGE:
								if ((v0 < 32'd2) || (v0 > 32'd4))
									st <= 10'd340;
								else begin
									x0 <= v0;
									rd(ab_ptr(ab_lo + 8'd1), 10'd755);
								end
							ABI_N_NEW_FLOAT, ABI_N_NEW_INT, ABI_N_NEW_TYPE:
								if (v0 != 32'd2)
									st <= 10'd340;
								else
									rd(TT + (4 * (nid == ABI_N_NEW_FLOAT ? ABI_T_FLOAT : (nid == ABI_N_NEW_INT ? ABI_T_INT : ABI_T_TYPE))), 10'd716);
							ABI_N_NEW_OBJECT:
								if (v0 != 32'd1)
									st <= 10'd340;
								else begin
									t[0] <= mv;
									alloc(32'd3, 10'd422);
								end
							default: st <= 10'd340;
						endcase
					end
					10'd390:
						if ((tg(mv) != ABI_TAG_INT) || mv[31])
							deliver(vint(32'hfffffffe), crk);
						else begin
							mb_dst_o <= padr(ab_q) + (mv[31:0] << 2);
							rd(ab_ptr(ab_lo + 8'd2), 10'd391);
						end
					10'd391:
						if ((tg(mv) != ABI_TAG_INT) || mv[31])
							deliver(vint(32'hfffffffe), crk);
						else begin
							mb_dn_o <= mv[31:0];
							rd(ab_ptr(ab_lo + 8'd4), 10'd392);
						end
					10'd392: begin
						mb_used_o <= mv[31:0];
						st <= 10'd407;
					end
					10'd393: begin
						x0 <= mv[31:0];
						st <= 10'd394;
					end
					10'd394:
						if (x0 < 2)
							deliver(VTRUE, crk);
						else if (ca_ok) begin
							ca_ship(padr(ab_q), padr(ab_q), x0 << 2);
							ca_byte_o <= 1;
							ca_reverse_o <= 1;
							deliver(VTRUE, crk);
						end
					10'd395: begin
						mb_dst_o <= padr(mv);
						rd(ab_ptr(ab_lo + 8'd2), 10'd396);
					end
					10'd396:
						if (((tg(mv) != ABI_TAG_INT) || (mv[31:0] == 0)) || mv[31])
							deliver(VFALSE, crk);
						else begin
							mb_dn_o <= mv[31:0];
							rd(ab_ptr(ab_lo + 8'd5), 10'd397);
						end
					10'd397:
						if (tg(mv) != ABI_TAG_INT)
							deliver(VFALSE, crk);
						else
							rd(mb_header_o, 10'd398);
					10'd398: begin
						mb_used_o <= md;
						st <= 10'd407;
					end
					10'd399:
						if ((tg(mv) != ABI_TAG_MUT) || !(mb_set_o ? is_mut(mv, ABI_MUT_SET) : is_mut(mv, ABI_MUT_DICT)))
							deliver((nid == ABI_N_MAPRELATION ? vint(32'hffffffff) : VFALSE), crk);
						else begin
							mb_source_header_o <= adr(mv);
							rd(ab_ptr(ab_lo + 8'd2), 10'd400);
						end
					10'd400:
						if (((tg(mv) != ABI_TAG_INT) || (nid == ABI_N_MAPRELATION ? (mv[31:0] < 5) || (mv[31:0] > 6) : (mv[31:0] < 1) || (mv[31:0] > 4))) || (!mb_set_o && (mv[31:0] != 1)))
							deliver((nid == ABI_N_MAPRELATION ? vint(32'hffffffff) : VFALSE), crk);
						else begin
							mb_op_o <= mv[2:0];
							rd(mb_header_o, 10'd401);
						end
					10'd401: begin
						mb_used_o <= md;
						rd(aoff(mb_header_o, 4), 10'd402);
					end
					10'd402: begin
						mb_dn_o <= md;
						rd(aoff(mb_header_o, 8), 10'd403);
					end
					10'd403: begin
						mb_dst_o <= md;
						rd(aoff(mb_header_o, 12), 10'd404);
					end
					10'd404:
						if ((mb_op_o < 5) && ((md & (mb_set_o ? ABI_SET_FLAG_FROZEN : ABI_DICT_FLAG_ROM)) != 0))
							deliver((nid == ABI_N_MAPRELATION ? vint(32'hffffffff) : VFALSE), crk);
						else
							rd(aoff(mb_source_header_o, 4), 10'd405);
					10'd405: begin
						mb_sn_o <= md;
						rd(aoff(mb_source_header_o, 8), 10'd406);
					end
					10'd406: begin
						mb_src_o <= md;
						st <= 10'd407;
					end
					10'd407:
						if (mb_ready_i) begin
							mb_valid_o <= 1;
							st <= 10'd408;
						end
					10'd408:
						if (mb_return_i)
							deliver((nid == ABI_N_SEQSCAN ? vint((mb_ok_i ? mb_used_i : 32'hfffffffe)) : (nid == ABI_N_MAPRELATION ? vint((mb_ok_i ? mb_used_i : 32'hffffffff)) : (mb_ok_i ? VTRUE : VFALSE))), crk);
					10'd409:
						if (mb_ready_i) begin
							mb_valid_o <= 1;
							mb_op_o <= 0;
							mb_set_o <= lk_set;
							mb_src_o <= sA[6];
							mb_sn_o <= sA[5];
							mb_dst_o <= sA[1];
							mb_dn_o <= sA[0];
							mb_used_o <= 0;
							mb_header_o <= 0;
							mb_hashes_o <= 0;
							mb_source_header_o <= adr(t[4]);
							st <= 10'd410;
						end
					10'd410:
						if (mb_return_i) begin
							if (mb_ok_i) begin
								sA[4] <= mb_used_i;
								sA[2] <= sA[5];
								st <= 10'd456;
							end
							else begin
								lk_cx <= 1;
								ret;
							end
						end
					10'd674:
						if (tg(mv) != ABI_TAG_OBJECT)
							st <= 10'd340;
						else begin
							ab_s[0] <= mv;
							rd(adr(mv), 10'd416);
						end
					10'd681:
						deliver({ab_q[3:0], mv[31:0]}, crk);
					10'd682:
						rd(padr(ab_q) + (mv[31:0] << 2), 10'd426);
					10'd683: begin
						x0 <= mv[31:0];
						rd(ab_ptr(ab_lo + 8'd2), 10'd684);
					end
					10'd684:
						wr(padr(ab_q) + (x0 << 2), mv, 10'd421);
					10'd685: begin
						v2 = padr(ab_q) + mv[31:0];
						x3 <= v2;
						rd({v2[31:2], 2'b00}, 10'd423);
					end
					10'd686: begin
						x0 <= mv[31:0];
						rd(ab_ptr(ab_lo + 8'd2), 10'd687);
					end
					10'd687:
						wrb(padr(ab_q) + x0, mv[7:0], 10'd421);
					10'd688: begin
						c_ismod <= 1'b1;
						c_md <= ab_q[31:0];
						cl_loc <= mv;
						ab_lo <= 8'd32;
						ab_pe <= 8'd32;
						rd(ab_q[31:0] + 12, 10'd121);
					end
					10'd689:
						rd(ab_ptr(ab_lo + 8'd1), 10'd690);
					10'd690: begin
						cl_loc <= mv;
						ab_lo <= 8'd32;
						ab_pe <= 8'd32;
						st <= 10'd94;
					end
					10'd696: begin
						x1 <= padr(mv) + 32'd12;
						rd(ab_ptr(ab_lo + 8'd2), 10'd697);
					end
					10'd697: begin
						x3 <= x1 + (md << 2);
						rd(ab_ptr(ab_lo + 8'd3), 10'd698);
					end
					10'd698: begin
						x2 <= padr(mv) + 32'd12;
						rd(ab_ptr(ab_lo + 8'd4), 10'd699);
					end
					10'd699: begin
						x4 <= x2 + (md << 2);
						rd(ab_ptr(ab_lo + 8'd5), 10'd700);
					end
					10'd700: begin
						bi_inline <= 1'b0;
						limb_factor <= md;
						limb_carry <= 32'd0;
						st <= 10'd701;
					end
					10'd701:
						if ((x1 == x3) && (x2 == x4)) begin
							if (bi_inline)
								st <= 10'd55;
							else
								deliver(vint(limb_carry), crk);
						end
						else if (x1 == x3) begin
							limb_product <= 64'd0;
							st <= 10'd704;
						end
						else
							rd(x1, 10'd702);
					10'd702: begin
						x1 <= x1 + 32'd4;
						if ((limb_factor == 32'd1) || (limb_factor == 32'hffffffff)) begin
							limb_product <= (limb_factor[31] ? -{34'd0, md[29:0]} : {34'd0, md[29:0]});
							st <= 10'd704;
						end
						else begin
							na <= {34'd0, md[29:0]};
							nb <= sx64(limb_factor);
							na_f <= 1'b0;
							nb_f <= 1'b0;
							n_small <= 1'b0;
							alu_op <= mpy_alu_pkg_ALU_MUL;
							alu_start <= 1'b1;
							st <= 10'd703;
						end
					end
					10'd703:
						if (alu_done) begin
							limb_product <= alu_res;
							st <= 10'd704;
						end
					10'd704:
						if (x2 == x4) begin
							limb_offset <= limb_carry;
							st <= 10'd706;
						end
						else
							rd(x2, 10'd705);
					10'd705: begin
						limb_offset <= limb_carry + {2'd0, md[29:0]};
						x2 <= x2 + 32'd4;
						st <= 10'd706;
					end
					10'd706: begin
						if (bi_inline) begin
							bi_i <= bi_i + 18'd1;
							if (limb_sum[29:0] != 0) begin
								bi_used <= bi_i + 18'd1;
								bi_top <= limb_sum[29:0];
								if (bi_i < 18'd2)
									bi_low_nonzero <= 1'b1;
							end
						end
						limb_carry <= limb_sum[61:30];
						wr(x0, vint({2'd0, limb_sum[29:0]}), 10'd701);
						x0 <= x0 + 32'd4;
					end
					10'd707:
						rd(TT + (4 * ABI_T_INT), 10'd708);
					10'd708: begin
						t[0] <= {ABI_TAG_OBJECT, al_a};
						wb_v[0] <= vint(ABI_OB_BIGINT);
						wb_v[1] <= mv;
						wb_v[2] <= vint(32'd0);
						wblock(al_a, 4'd3, 10'd433);
					end
					10'd691: begin
						x1 <= mv[31:0];
						rd(ab_ptr(ab_lo + 8'd2), 10'd692);
					end
					10'd692: begin
						ab_s[0] <= mv;
						rd(ab_ptr(ab_lo + 8'd3), 10'd693);
					end
					10'd693: begin
						x2 <= mv[31:0];
						rd(ab_ptr(ab_lo + 8'd4), 10'd694);
					end
					10'd694: begin
						x3 <= mv[31:0];
						if (cfg_ca)
							st <= 10'd775;
						else if (scr_id != SCR_LA)
							scr_adopt(SCR_LA, 10'd695);
						else
							st <= 10'd695;
					end
					10'd775:
						if (x3 == 32'd0)
							deliver(VNONE, crk);
						else if (ca_ok) begin
							ca_ship(padr(ab_q) + (x1 << 2), padr(ab_s[0]) + (x2 << 2), x3);
							deliver(VNONE, crk);
						end
					10'd695: begin
						v2 = padr(ab_q) + (x1 << 2);
						v3 = padr(ab_s[0]) + (x2 << 2);
						sA[3] <= v2;
						sA[2] <= v3;
						sA[0] <= x3;
						b1 <= v2 > v3;
						sA[4] <= 32'd0;
						st <= 10'd435;
					end
					10'd709: begin
						si_v <= mv;
						gosub(10'd129, 10'd365);
					end
					10'd710:
						lookup(ab_q, mv, VNULL, LK_FIND, is_mut(ab_q, ABI_MUT_SET), 10'd420);
					10'd713:
						if (si_len != 32'd1)
							st <= 10'd340;
						else
							rd({si_addr[31:2], 2'b00}, 10'd714);
					10'd714:
						if ((byte_of(md, si_addr[1:0]) >= 8'd128) && (tg(si_v) != ABI_TAG_BYTES))
							st <= 10'd340;
						else
							deliver(vint({24'd0, byte_of(md, si_addr[1:0])}), crk);
					10'd715:
						deliver({ABI_TAG_QSTR, md}, crk);
					10'd718: begin
						na[31:0] <= md;
						rd(ha_m4, 10'd719);
					end
					10'd719: begin
						na[63:32] <= md;
						alu_start <= 1'b1;
						st <= 10'd388;
					end
					10'd716:
						if (mv != ab_q)
							st <= 10'd340;
						else
							rd(ab_ptr(ab_lo + 8'd1), 10'd717);
					10'd717: begin
						nb_f <= 1'b1;
						nb <= 64'd0;
						n_small <= 1'b0;
						n_un <= 1'b0;
						na_f <= tg(mv) == ABI_TAG_FLOAT;
						na <= (tg(mv) == ABI_TAG_FLOAT ? {32'd0, mv[31:0]} : sx64(ival(mv)));
						if (nid == ABI_N_NEW_TYPE) begin
							ty_v <= mv;
							gosub(10'd531, 10'd434);
						end
						else if ((nid == ABI_N_NEW_FLOAT) && (tg(mv) == ABI_TAG_FLOAT))
							deliver(mv, crk);
						else if ((nid == ABI_N_NEW_INT) && (tg(mv) == ABI_TAG_INT))
							deliver(mv, crk);
						else if ((nid == ABI_N_NEW_INT) && is_bool(mv))
							deliver(vint({31'd0, mv == VTRUE}), crk);
						else if ((nid == ABI_N_NEW_FLOAT) && ((tg(mv) == ABI_TAG_INT) || is_bool(mv))) begin
							alu_op <= mpy_alu_pkg_ALU_ADD;
							alu_start <= 1'b1;
							st <= 10'd388;
						end
						else if (((nid == ABI_N_NEW_FLOAT) && (tg(mv) == ABI_TAG_INT64)) && !h_bigint) begin
							alu_op <= mpy_alu_pkg_ALU_ADD;
							rd(adr(mv), 10'd718);
						end
						else if ((nid == ABI_N_NEW_INT) && (tg(mv) == ABI_TAG_FLOAT)) begin
							nb_f <= 1'b0;
							alu_op <= mpy_alu_pkg_ALU_F2I;
							alu_start <= 1'b1;
							st <= 10'd388;
						end
						else
							st <= 10'd340;
					end
					10'd711:
						lookup(ab_q, mv, VNULL, LK_FIND, 1'b0, 10'd712);
					10'd712:
						if (lk_cx)
							st <= 10'd340;
						else if (lk_found)
							deliver(lk_res, crk);
						else if ((ab_pe - ab_lo) == 8'd3)
							rd(ab_ptr(ab_lo + 8'd2), 10'd426);
						else
							deliver(VNONE, crk);
					10'd720: begin
						t[1] <= mv;
						rd(ab_ptr(ab_lo + 8'd2), 10'd721);
					end
					10'd721: begin
						t[2] <= mv;
						st <= 10'd180;
					end
					10'd722: begin
						t[3] <= mv;
						gosub(10'd280, 10'd421);
					end
					10'd723:
						if (!intlike(mv))
							st <= 10'd340;
						else begin
							x0 <= ival(mv);
							rd(adr(t[2]), 10'd724);
						end
					10'd724: begin
						v0 = x0;
						if (v0[31])
							v0 = v0 + md;
						if (((md == 32'd0) || v0[31]) || (v0 >= md))
							st <= 10'd340;
						else begin
							x0 <= v0;
							x1 <= md;
							rd(aoff(adr(t[2]), 8), 10'd725);
						end
					end
					10'd725: begin
						x2 <= md;
						x3 <= x0;
						rd(md + (x0 << 2), 10'd726);
					end
					10'd726: begin
						t[3] <= mv;
						if (((cfg_sl != 0) && (x1 <= SHORTLIST_MAX)) && ((x0 + 32'd1) != x1)) begin
							ss_src <= x2 + ((x0 + 32'd1) << 2);
							ss_dst <= x2 + (x0 << 2);
							ss_n <= (x1 - x0) - 32'd1;
							ss_reverse <= 0;
							ss_clear <= 1;
							ss_clear_addr <= x2 + ((x1 - 32'd1) << 2);
							ss_put <= 0;
							ss_length <= 1;
							ss_header <= adr(t[2]);
							ss_new_length <= x1 - 32'd1;
							ss_back <= 10'd734;
							st <= 10'd799;
						end
						else if ((x0 + 32'd1) == x1)
							st <= 10'd732;
						else if (cfg_ca && ((x1 - x0) > LS_CA_MIN))
							st <= 10'd729;
						else
							st <= 10'd727;
					end
					10'd727:
						if ((x3 + 32'd1) == x1)
							st <= 10'd732;
						else
							rd(x2 + ((x3 + 32'd1) << 2), 10'd728);
					10'd728: begin
						wr(x2 + (x3 << 2), mv, 10'd727);
						x3 <= x3 + 32'd1;
					end
					10'd729:
						if (ca_ok) begin
							ca_ship(x2 + (x0 << 2), x2 + ((x0 + 32'd1) << 2), (x1 - x0) - 32'd1);
							st <= 10'd730;
						end
					10'd730: st <= 10'd731;
					10'd731:
						if (!ca_valid && ca_idle_i)
							st <= 10'd732;
					10'd732:
						wr(x2 + ((x1 - 32'd1) << 2), VNULL, 10'd733);
					10'd733:
						wr(adr(t[2]), vint(x1 - 32'd1), 10'd734);
					10'd734:
						deliver(t[3], crk);
					10'd747:
						if (tg(mv) != ABI_TAG_INT)
							st <= 10'd340;
						else begin
							x1 <= mv[31:0];
							rd(ab_ptr(ab_lo + 8'd2), 10'd748);
						end
					10'd748: begin
						ab_s[0] <= mv;
						rd(ab_ptr(ab_lo + 8'd3), 10'd749);
					end
					10'd749:
						if (tg(mv) != ABI_TAG_INT)
							st <= 10'd340;
						else begin
							x2 <= mv[31:0];
							rd(ab_ptr(ab_lo + 8'd4), 10'd750);
						end
					10'd750:
						if ((tg(mv) != ABI_TAG_INT) || mv[31])
							st <= 10'd340;
						else begin
							x3 <= mv[31:0];
							rd(ab_ptr(ab_lo + 8'd5), 10'd751);
						end
					10'd751:
						if (tg(mv) != ABI_TAG_INT)
							st <= 10'd340;
						else begin
							x4 <= mv[31:0] << 2;
							x1 <= padr(ab_q) + (x1 << 2);
							x2 <= padr(ab_s[0]) + (x2 << 2);
							st <= 10'd752;
						end
					10'd752:
						if (x3 == 32'd0)
							deliver(VNONE, crk);
						else
							rd(x2, 10'd753);
					10'd753: begin
						wr(x1, mv, 10'd752);
						x1 <= x1 + 32'd4;
						x2 <= x2 + x4;
						x3 <= x3 - 32'd1;
					end
					10'd735:
						if (!intlike(mv) || ((cfg_sl != 0) && is_bool(mv)))
							st <= 10'd340;
						else begin
							x0 <= ival(mv);
							rd(ab_ptr(ab_lo + 8'd2), 10'd736);
						end
					10'd736: begin
						t[3] <= mv;
						rd(adr(t[2]), 10'd737);
					end
					10'd737: begin
						x1 <= md;
						if (x0[31])
							x0 <= x0 + md;
						rd(aoff(adr(t[2]), 4), 10'd738);
					end
					10'd738: begin
						if (x0[31])
							x0 <= 32'd0;
						else if (x0 > x1)
							x0 <= x1;
						if (x1 >= md)
							st <= 10'd340;
						else
							rd(aoff(adr(t[2]), 8), 10'd739);
					end
					10'd739: begin
						x2 <= md;
						x3 <= x1;
						if (((cfg_sl != 0) && (x1 < SHORTLIST_MAX)) && (x0 != x1)) begin
							ss_src <= md + (x0 << 2);
							ss_dst <= md + ((x0 + 32'd1) << 2);
							ss_n <= x1 - x0;
							ss_reverse <= 0;
							ss_clear <= 0;
							ss_put <= 1;
							ss_put_addr <= md + (x0 << 2);
							ss_put_value <= t[3];
							ss_length <= 1;
							ss_header <= adr(t[2]);
							ss_new_length <= x1 + 32'd1;
							ss_back <= 10'd421;
							st <= 10'd799;
						end
						else if (x0 == x1)
							st <= 10'd745;
						else if (cfg_ca && ((x1 - x0) > LS_CA_MIN))
							st <= 10'd742;
						else
							st <= 10'd740;
					end
					10'd740:
						if (x3 == x0)
							st <= 10'd745;
						else
							rd(x2 + ((x3 - 32'd1) << 2), 10'd741);
					10'd741: begin
						wr(x2 + (x3 << 2), mv, 10'd740);
						x3 <= x3 - 32'd1;
					end
					10'd742:
						if (ca_ok) begin
							ca_ship(x2 + ((x0 + 32'd1) << 2), x2 + (x0 << 2), x1 - x0);
							st <= 10'd743;
						end
					10'd743: st <= 10'd744;
					10'd744:
						if (!ca_valid && ca_idle_i)
							st <= 10'd745;
					10'd745:
						wr(x2 + (x0 << 2), t[3], 10'd746);
					10'd746:
						wr(adr(t[2]), vint(x1 + 32'd1), 10'd421);
					10'd754: begin
						h_qextn <= mv[31:0];
						deliver(VNONE, crk);
					end
					10'd755:
						if (!intlike(mv))
							st <= 10'd340;
						else if (x0 == 32'd2) begin
							wb_v[0] <= vint(32'd0);
							wb_v[1] <= vint(ival(mv));
							wb_v[2] <= vint(32'd1);
							alloc(32'd3, 10'd424);
						end
						else begin
							ab_s[0] <= mv;
							rd(ab_ptr(ab_lo + 8'd2), 10'd756);
						end
					10'd756:
						if (!intlike(mv))
							st <= 10'd340;
						else if (x0 == 32'd3) begin
							wb_v[0] <= vint(ival(ab_s[0]));
							wb_v[1] <= vint(ival(mv));
							wb_v[2] <= vint(32'd1);
							alloc(32'd3, 10'd424);
						end
						else begin
							ab_s[1] <= mv;
							rd(ab_ptr(ab_lo + 8'd3), 10'd757);
						end
					10'd757:
						if (!intlike(mv))
							st <= 10'd340;
						else if (ival(mv) == 32'd0)
							raise_msg(ABI_MSG_ZERO_STEP);
						else begin
							wb_v[0] <= vint(ival(ab_s[0]));
							wb_v[1] <= vint(ival(ab_s[1]));
							wb_v[2] <= vint(ival(mv));
							alloc(32'd3, 10'd424);
						end
					10'd675:
						if (tg(mv) != ABI_TAG_QSTR)
							st <= 10'd340;
						else begin
							at_q <= mv[31:0];
							at_nat <= 1'b1;
							t[0] <= ab_q;
							gosub_scr(SCR_AT, 10'd9, 10'd292);
						end
					10'd676:
						if (md != ABI_OB_INSTANCE)
							st <= 10'd340;
						else
							rd(aoff(adr(t[0]), 4), 10'd677);
					10'd677:
						rd(aoff(adr(mv), 28), 10'd678);
					10'd678:
						if (md & (ABI_TF_GETATTR | ABI_TF_NATIVE_SUB))
							st <= 10'd340;
						else
							rd(ab_ptr(ab_lo + 8'd2), 10'd426);
					10'd679:
						if (tg(mv) != ABI_TAG_QSTR)
							st <= 10'd340;
						else begin
							at_q <= mv[31:0];
							rd(ab_ptr(ab_lo + 8'd2), 10'd680);
						end
					10'd680: begin
						at_nat <= 1'b1;
						t[0] <= ab_q;
						t[6] <= mv;
						st <= 10'd482;
					end
					10'd340:
						rd(ab_ptr(8'd0), 10'd673);
					10'd673: begin
						ab_q <= mv;
						rd(aoff(adr(mv), 12), 10'd341);
					end
					10'd341:
						if (mv == VNULL)
							rd(aoff(adr(ab_q), 16), 10'd342);
						else
							wr(ab_ptr(8'd0), mv, 10'd94);
					10'd342:
						raise_err(ABI_ERR_BUILTIN_ARGS, mv, vint(sv2v_cast_32(ab_pe - ab_lo)));
					10'd421:
						deliver(VNONE, crk);
					10'd425:
						deliver(vint(md), crk);
					10'd426:
						deliver(mv, crk);
					10'd419:
						if ((si_na && (tg(si_v) != ABI_TAG_BYTES)) && (nid == ABI_N_LEN))
							st <= 10'd340;
						else
							deliver(vint(si_len), crk);
					10'd416:
						if (md != ABI_OB_TYPE)
							st <= 10'd340;
						else begin
							ty_v <= ab_q;
							is_c <= ab_s[0];
							gosub(10'd531, 10'd417);
						end
					10'd417: begin
						is_t <= ty_t;
						gosub(10'd249, 10'd418);
					end
					10'd418:
						deliver(vbool(is_r), crk);
					10'd437: begin
						x2 <= si_addr;
						x1 <= 32'd0;
						st <= 10'd439;
					end
					10'd439:
						if (x1 == si_len)
							deliver(VNONE, crk);
						else
							rd(x2 + {x1[31:2], 2'b00}, 10'd438);
					10'd438: begin
						wr(x4, vint({24'd0, byte_of(md, x1[1:0])}), 10'd439);
						x1 <= x1 + 32'd1;
					end
					10'd423:
						deliver(vint({24'd0, byte_of(md, x3[1:0])}), crk);
					10'd363:
						rd(ab_ptr(ab_lo + 8'd1), 10'd758);
					10'd758: begin
						ab_q <= mv;
						rd(ab_ptr(ab_lo + 8'd2), 10'd759);
					end
					10'd759:
						deliver({ab_q[3:0], al_a | mv[31:0]}, crk);
					10'd434:
						deliver(ty_t, crk);
					10'd435:
						if (sA[4] == sA[0])
							deliver(VNONE, crk);
						else
							rd((b1 ? sA[2] + (((sA[0] - 32'd1) - sA[4]) << 2) : sA[2] + (sA[4] << 2)), 10'd436);
					10'd436: begin
						wr((b1 ? sA[3] + (((sA[0] - 32'd1) - sA[4]) << 2) : sA[3] + (sA[4] << 2)), mv, 10'd435);
						sA[4] <= sA[4] + 32'd1;
					end
					10'd365:
						if (scr_id != SCR_LA)
							scr_adopt(SCR_LA, 10'd365);
						else
							rd(ab_ptr(ab_lo + 8'd3), 10'd760);
					10'd760: begin
						sA[2] <= si_addr + mv[31:0];
						si_v <= ab_q;
						gosub(10'd129, 10'd366);
					end
					10'd366:
						rd(ab_ptr(ab_lo + 8'd1), 10'd761);
					10'd761: begin
						x0 <= mv[31:0];
						rd(ab_ptr(ab_lo + 8'd4), 10'd762);
					end
					10'd762: begin
						sA[3] <= si_addr + x0;
						sA[0] <= mv[31:0];
						b1 <= (si_addr + x0) > sA[2];
						sA[4] <= 32'd0;
						st <= 10'd364;
					end
					10'd364:
						if (sA[4] == sA[0])
							deliver(VNONE, crk);
						else if (cfg_ca && cfg_bulk) begin
							if (ca_ok) begin
								ca_ship(sA[3], sA[2], sA[0]);
								ca_byte_o <= 1;
								deliver(VNONE, crk);
							end
						end
						else begin
							v2 = (b1 ? ((sA[2] + sA[0]) - 32'd1) - sA[4] : sA[2] + sA[4]);
							x3 <= v2;
							rd({v2[31:2], 2'b00}, 10'd367);
						end
					10'd367: begin
						wrb((b1 ? ((sA[3] + sA[0]) - 32'd1) - sA[4] : sA[3] + sA[4]), byte_of(md, x3[1:0]), 10'd364);
						sA[4] <= sA[4] + 32'd1;
					end
					10'd432:
						rd(ab_ptr(ab_lo), 10'd764);
					10'd764: begin
						wb_v[0] <= vint(mv[31:0]);
						wb_v[1] <= vint(32'd0);
						wb_v[2] <= {ABI_TAG_CONT, al_a + 32'd12};
						rd(ab_ptr(ab_lo + 8'd1), 10'd765);
					end
					10'd765: begin
						t[0] <= {mv[3:0], al_a};
						wblock(al_a, 4'd3, 10'd433);
					end
					10'd433:
						deliver(t[0], crk);
					10'd427:
						if ((scr_id == SCR_NONE) || (scr_id == SCR_LA)) begin
							scr_id <= SCR_LA;
							sA[0] <= md;
							rd(aoff(adr(ab_q), 8), 10'd428);
						end
						else
							wr(scr_addr(SCR_LA, 4'd0), {4'd0, md}, 10'd772);
					10'd772:
						if (scr_id != SCR_LA)
							scr_ensure(SCR_LA, 10'd772);
						else
							rd(aoff(adr(ab_q), 8), 10'd428);
					10'd428: begin
						sA[2] <= md;
						sA[4] <= 32'd0;
						x2 <= 32'd5381;
						b1 <= 1'b0;
						st <= 10'd431;
					end
					10'd431:
						if (sA[4] == sA[0]) begin
							v3 = {16'd0, x2[15:0]};
							if (v3 == 32'd0)
								v3 = 32'd1;
							wr(aoff(adr(ab_q), 4), vint(v3 | (b1 ? ABI_STR_NONASCII : 32'd0)), 10'd429);
						end
						else
							rd(sA[2] + {sA[4][31:2], 2'b00}, 10'd430);
					10'd430: begin
						v3 = {24'd0, byte_of(md, sA[4][1:0])};
						x2 <= (x2 * 32'd33) ^ v3;
						if (v3[7])
							b1 <= 1'b1;
						sA[4] <= sA[4] + 32'd1;
						st <= 10'd431;
					end
					10'd429:
						deliver(ab_q, crk);
					10'd420:
						deliver((lk_cx ? VSTOP : (lk_found ? lk_res : VNULL)), crk);
					10'd385: begin
						na_f <= 1'b1;
						na <= {32'd0, t[0][31:0]};
						nb_f <= 1'b0;
						nb <= 64'd0;
						n_small <= 1'b0;
						alu_start <= 1'b1;
						st <= 10'd387;
					end
					10'd387:
						if (alu_done) begin
							if (alu_err != mpy_alu_pkg_AE_NONE)
								deliver(VSTOP, crk);
							else if (fits32(alu_res))
								deliver(vint(alu_res[31:0]), crk);
							else
								alloc(32'd2, 10'd386);
						end
					10'd388:
						if (alu_done) begin
							if (alu_err != mpy_alu_pkg_AE_NONE)
								st <= 10'd340;
							else if (alu_kind == mpy_alu_pkg_AK_FLOAT)
								deliver({ABI_TAG_FLOAT, alu_res[31:0]}, crk);
							else if (fits32(alu_res))
								deliver(vint(alu_res[31:0]), crk);
							else
								alloc(32'd2, 10'd386);
						end
					10'd386: begin
						wb_v[0] <= vint(alu_res[31:0]);
						wb_v[1] <= vint(alu_res[63:32]);
						t[0] <= {ABI_TAG_INT64, al_a};
						wblock(al_a, 4'd2, 10'd433);
					end
					10'd412:
						if (((i0 == 8'd0) && (scr_id != SCR_NONE)) && (scr_id != SCR_IT))
							scr_go_store(scr_id, 10'd412);
						else begin
							if (scr_id != SCR_IT)
								scr_id <= SCR_IT;
							if (i0 == 8'd4) begin
								it_h <= 1'b1;
								gosub(10'd254, 10'd414);
							end
							else
								rd(adr(t[3]) + (4 * i0), 10'd413);
						end
					10'd413: begin
						sV[i0[1:0]] <= mv;
						i0 <= i0 + 8'd1;
						st <= 10'd412;
					end
					10'd414:
						if (it_py)
							deliver(VNULL, crk);
						else
							wr(adr(t[3]), sV[0], 10'd415);
					10'd415:
						wr(aoff(adr(t[3]), 4), sV[1], 10'd411);
					10'd411:
						deliver((it_stop ? VSTOP : it_val), crk);
					10'd373:
						if (!(strlike(mv) || (tg(mv) == ABI_TAG_BYTES)))
							st <= 10'd340;
						else begin
							si_v <= mv;
							gosub(10'd500, 10'd374);
						end
					10'd374:
						if (si_len != 32'd1)
							st <= 10'd340;
						else
							rd({si_addr[31:2], 2'b00}, 10'd375);
					10'd375: begin
						x4 <= {24'd0, byte_of(md, si_addr[1:0])};
						rd(ab_ptr(ab_lo + 8'd2), 10'd376);
					end
					10'd376:
						if ((tg(mv) != ABI_TAG_INT) || mv[31])
							st <= 10'd340;
						else begin
							x0 <= {mv[31:2], 2'b00};
							x1 <= mv[31:0];
							rd(ab_ptr(ab_lo + 8'd3), 10'd377);
						end
					10'd377:
						if ((tg(mv) != ABI_TAG_INT) || mv[31])
							st <= 10'd340;
						else begin
							x2 <= mv[31:0];
							si_v <= t[0];
							gosub(10'd500, 10'd378);
						end
					10'd378:
						if ((x2 > si_len) || (si_addr[1:0] != 2'b00))
							st <= 10'd340;
						else if (x1 >= x2)
							deliver(vint(32'hffffffff), crk);
						else begin
							x3 <= si_addr;
							st <= 10'd379;
						end
					10'd379:
						if (x0 >= x2)
							deliver(vint(32'hffffffff), crk);
						else
							rd(x3 + x0, 10'd380);
					10'd380: begin
						begin : sv2v_autoblock_21
							reg signed [31:0] k;
							for (k = 0; k < 4; k = k + 1)
								gi[k] <= ((md[8 * k+:8] == x4[7:0]) && ({x0[31:2], sv2v_cast_2_signed(k)} >= x1)) && ({x0[31:2], sv2v_cast_2_signed(k)} < x2);
						end
						st <= 10'd381;
					end
					10'd381:
						if (gi[3:0] == 4'b0000) begin
							x0 <= x0 + 32'd4;
							st <= 10'd379;
						end
						else begin
							casez (gi[3:0])
								4'bzzz1: v0 = x0;
								4'bzz10: v0 = {x0[31:2], 2'd1};
								4'bz100: v0 = {x0[31:2], 2'd2};
								default: v0 = {x0[31:2], 2'd3};
							endcase
							deliver(vint(v0), crk);
						end
					10'd371: begin
						x0 <= si_len;
						x2 <= si_addr;
						if (b0)
							rd(ab_ptr(ab_lo + 8'd1), 10'd763);
						else begin
							si_v <= t[1];
							gosub(10'd500, 10'd372);
						end
					end
					10'd763: begin
						si_v <= mv;
						gosub(10'd500, 10'd372);
					end
					10'd372: begin
						x1 <= si_len;
						x3 <= si_addr;
						x4 <= 32'd0;
						gi <= (x0 < si_len ? x0 : si_len);
						st <= 10'd370;
					end
					10'd370:
						if (x4 >= gi) begin
							t[7] <= vint(x0 - x1);
							st <= 10'd774;
						end
						else
							rd(x2 + x4, 10'd368);
					10'd368: begin
						t[2] <= vint(md);
						rd(x3 + x4, 10'd369);
					end
					10'd369: begin
						v0 = gi - x4;
						vs0 = 7'd4;
						begin : sv2v_autoblock_22
							reg signed [31:0] k;
							for (k = 3; k >= 0; k = k - 1)
								if ((k < v0) && (t[2][8 * k+:8] != md[8 * k+:8]))
									vs0 = sv2v_cast_7_signed(k);
						end
						if (vs0 != 7'd4) begin
							v1 = {24'd0, byte_of(t[2][31:0], vs0[1:0])};
							v2 = {24'd0, byte_of(md, vs0[1:0])};
							t[7] <= vint(v1 - v2);
							st <= 10'd774;
						end
						else begin
							x4 <= x4 + 32'd4;
							st <= 10'd370;
						end
					end
					10'd774:
						if (b0)
							deliver(t[7], crk);
						else begin
							v0 = t[7][31:0];
							case (n_o)
								ABI_BINOP_LESS: vb = v0[31];
								ABI_BINOP_LESS_EQUAL: vb = v0[31] || (v0 == 0);
								ABI_BINOP_MORE: vb = !v0[31] && (v0 != 0);
								default: vb = !v0[31];
							endcase
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= vbool(vb);
							sp <= sp - 7'd1;
							st <= 10'd147;
						end
					10'd389:
						deliver((hok ? vint(hh) : VSTOP), crk);
					10'd383:
						deliver(vint(si_addr), crk);
					10'd384:
						if ((x3 >= 32'd6) && (x3 <= 32'd11))
							deliver(mv, crk);
						else
							deliver(vint(md), crk);
					10'd382:
						wr(aoff(adr(t[0]), 8), tb_v, 10'd421);
					10'd424: begin
						t[0] <= {ABI_TAG_RANGE, al_a};
						wblock(al_a, 4'd3, 10'd433);
					end
					10'd422: begin
						wb_v[0] <= vint(ABI_OB_INSTANCE);
						wb_v[1] <= t[0];
						wb_v[2] <= VNULL;
						t[0] <= vobj(al_a);
						wblock(al_a, 4'd3, 10'd433);
					end
					10'd160:
						rd(aoff(adr(gen), 20), 10'd161);
					10'd161: begin
						x4 <= fbase;
						x0 <= md;
						spill_to_img <= 1'b1;
						if (lc_dirty_any) begin
							lc_fi <= 4'd0;
							lc_fl_ret <= 10'd162;
							st <= 10'd555;
						end
						else
							st <= 10'd162;
					end
					10'd162: begin
						fbase <= x0;
						if (locals_in_image)
							stack_prefix_words <= frame_prefix(nloc, 5'd0);
						gosub(10'd508, 10'd163);
					end
					10'd163: begin
						fbase <= x4;
						if (locals_in_image)
							stack_prefix_words <= 9'd17;
						spill_to_img <= 1'b0;
						ret;
					end
					10'd164:
						rd(TT + (4 * ABI_T_GENERATOR), 10'd165);
					10'd165: begin
						t[3] <= mv;
						alloc(32'd6, 10'd166);
					end
					10'd166: begin
						t[0] <= vobj(al_a);
						alloc(((32'd17 + sv2v_cast_32(nloc)) + (32'd3 * {27'd0, nexc})) + 32'd64, 10'd167);
					end
					10'd167: begin
						wb_v[0] <= vint(ABI_OB_GENERATOR);
						wb_v[1] <= t[3];
						wb_v[2] <= fun;
						wb_v[3] <= vint(32'd0);
						wb_v[4] <= VNONE;
						wb_v[5] <= {ABI_TAG_CONT, al_a};
						gen <= t[0];
						wblock(adr(t[0]), 4'd6, 10'd168);
					end
					10'd168:
						gosub(10'd160, 10'd169);
					10'd169: begin
						t[7] <= gen;
						st <= 10'd444;
					end
					10'd176:
						wr(aoff(adr(gen), 12), vint(32'd0), 10'd177);
					10'd177:
						gosub(10'd160, 10'd178);
					10'd178: begin
						fl_base <= fprev;
						gosub(10'd148, 10'd179);
					end
					10'd179:
						if (fflags & FF_YFAST) begin
							fflags <= fflags & ~FF_YFAST;
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= t[7];
							st <= 10'd147;
						end
						else if (fcont == ABI_CONT_FOR_NEXT) begin
							op <= 8'h4b;
							raise_msg(ABI_MSG_STOP_ITER);
						end
						else if (t[7] == VNONE)
							raise_msg(ABI_MSG_STOP_ITER);
						else begin
							ab_lo <= 8'd32;
							ab_pe <= 8'd33;
							ab_nkw <= 8'd0;
							crk <= ABI_RK_CONT;
							fcont <= ABI_CONT_RAISE;
							wr(ab_ptr(8'd0), ty_stop, 10'd670);
						end
					10'd670:
						wr(ab_ptr(8'd32), t[7], 10'd94);
					10'd170:
						wr(aoff(adr(gen), 12), vint(32'd0), 10'd171);
					10'd171:
						gosub(10'd160, 10'd172);
					10'd172:
						rd(aoff(adr(xc), 4), 10'd173);
					10'd173: begin
						is_t <= mv;
						is_c <= ty_stop;
						gosub(10'd249, 10'd174);
					end
					10'd174: begin
						b0 <= is_r;
						rx_crk <= frk;
						fl_base <= fprev;
						gosub(10'd148, 10'd175);
					end
					10'd175: begin
						fflags <= fflags & ~FF_YFAST;
						if (b0)
							raise_msg(ABI_MSG_GEN_STOP);
						else begin
							rx_from <= 1'b1;
							st <= 10'd442;
						end
					end
					10'd180:
						rd(aoff(adr(t[0]), 20), 10'd181);
					10'd181: begin
						x4 <= md;
						rd(aoff(md, 8), 10'd182);
					end
					10'd182:
						if (md == 32'd0) begin
							if (fflags & FF_YFAST) begin
								fflags <= fflags & ~FF_YFAST;
								rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= VNONE;
								st <= 10'd147;
							end
							else
								raise_msg(ABI_MSG_STOP_ITER);
						end
						else
							rd(aoff(adr(t[0]), 12), 10'd183);
					10'd183:
						if (md[0]) begin
							fflags <= fflags & ~FF_YFAST;
							raise_msg(ABI_MSG_GEN_RUNNING);
						end
						else
							rd(aoff(adr(t[0]), 16), 10'd184);
					10'd184: begin
						if (mv != VNONE)
							t[2] <= mv;
						rd(aoff(x4, 16), 10'd185);
					end
					10'd185: begin
						x1 <= md;
						rd(aoff(x4, 20), 10'd186);
					end
					10'd186: begin
						v0 = (noframe ? ABI_FRAME_BASE : stk_top);
						v3 = sv2v_cast_32((12'd17 + sv2v_cast_12((md[20:16] == 0 ? 7'd0 : x1[22:16]))) + (12'd3 * sv2v_cast_12(md[20:16])));
						v1 = (noframe ? ABI_FRAME_BASE + (v3 << 2) : fbase + {18'd0, sv2v_cast_12(stk_off) + v3[11:0], 2'b00});
						if ((x1[6:0] == 7'd0) && (t[1] != VNONE)) begin
							fflags <= fflags & ~FF_YFAST;
							raise_msg(ABI_MSG_GEN_SEND);
						end
						else if (v1 > spill_hp) begin
							fflags <= fflags & ~FF_YFAST;
							raise_msg(ABI_MSG_RECURSION);
						end
						else begin
							x3 <= v0;
							b1 <= x1[6:0] != 7'd0;
							gen_direct_locals <= md[20:16] == 0;
							wr(aoff(adr(t[0]), 16), VNONE, 10'd187);
						end
					end
					10'd187:
						wr(aoff(adr(t[0]), 12), vint(32'd1), 10'd192);
					10'd192:
						if (noframe)
							st <= 10'd189;
						else
							gosub(10'd508, 10'd189);
					10'd189: begin
						fprev <= (noframe ? 32'd0 : fbase);
						fbase <= x3;
						noframe <= 1'b0;
						local_base <= (gen_direct_locals ? x4 : x3);
						local_image_word <= (gen_direct_locals ? x4[18:2] : 17'd0);
						locals_in_image <= gen_direct_locals;
						fl_base <= x4;
						fl_img <= 1'b1;
						gosub(10'd148, 10'd188);
					end
					10'd188: begin
						frk <= r_rk;
						gen <= t[0];
						if (b1)
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= t[1];
						if (t[2] != VNONE)
							st <= 10'd191;
						else begin
							inj <= VNONE;
							st <= 10'd147;
						end
					end
					10'd191:
						rd({pc[31:2], 2'b00}, 10'd190);
					10'd190:
						if (byte_of(md, pc[1:0]) == 8'h68) begin
							inj <= t[2];
							st <= 10'd147;
						end
						else begin
							inj <= VNONE;
							t[0] <= t[2];
							op <= 8'h65;
							op_pc <= pc;
							st <= 10'd467;
						end
					10'd193: begin
						t[7] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= VNONE;
						wr(aoff(adr(gen), 12), vint(32'd0), 10'd194);
					end
					10'd194:
						gosub(10'd160, 10'd195);
					10'd195: st <= 10'd444;
					10'd197:
						if (md == ABI_OB_GENERATOR) begin
							fflags <= fflags | FF_YFAST;
							t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))];
							t[1] <= VNONE;
							t[2] <= VNONE;
							r_rk <= ABI_RK_CONT;
							fcont <= ABI_CONT_YFROM;
							sp <= sp - 7'd1;
							st <= 10'd180;
						end
						else begin
							aux <= inj;
							fcont <= ABI_CONT_YFROM;
							hook(ABI_HOOK_YFROM, ABI_RK_CONT, 8'd3, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))], (inj != VNONE ? VNONE : rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]), (inj != VNONE ? inj : VNONE), VNULL);
							inj <= VNONE;
							sp <= sp - 7'd1;
						end
					10'd196: begin
						b0 <= mv == VTRUE;
						rd(aoff(adr(t[7]), 8), 10'd198);
					end
					10'd198: begin
						fcont <= 8'd0;
						if (b0) begin
							aux <= VNONE;
							push(mv);
							pc <= op_pc;
							st <= 10'd193;
						end
						else begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= mv;
							if (aux != VNONE)
								st <= 10'd199;
							else
								st <= 10'd147;
						end
					end
					10'd199:
						if (tg(aux) != ABI_TAG_OBJECT) begin
							aux <= VNONE;
							st <= 10'd147;
						end
						else
							rd(adr(aux), 10'd200);
					10'd200:
						if (md == ABI_OB_EXCEPTION)
							rd(aoff(adr(aux), 4), 10'd201);
						else if (md == ABI_OB_TYPE) begin
							is_t <= aux;
							rd(TT + (4 * ABI_T_GENERATOREXIT), 10'd202);
						end
						else begin
							aux <= VNONE;
							st <= 10'd147;
						end
					10'd201: begin
						is_t <= mv;
						rd(TT + (4 * ABI_T_GENERATOREXIT), 10'd202);
					end
					10'd202: begin
						is_c <= mv;
						gosub(10'd249, 10'd203);
					end
					10'd203: begin
						if (is_r) begin
							t[0] <= aux;
							st <= 10'd467;
						end
						else
							st <= 10'd147;
						aux <= VNONE;
					end
					10'd204: begin
						is_t <= mv;
						is_c <= ty_stop;
						fcont <= 8'd0;
						gosub(10'd249, 10'd205);
					end
					10'd205:
						if (is_r)
							rd(aoff(adr(xc), 8), 10'd206);
						else begin
							sp <= sp - 7'd1;
							st <= 10'd474;
						end
					10'd206: begin
						t[6] <= mv;
						rd(adr(mv), 10'd207);
					end
					10'd207:
						if (md == 32'd0) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= VNONE;
							st <= 10'd147;
						end
						else
							rd(aoff(adr(t[6]), 4), 10'd208);
					10'd208: begin
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= mv;
						st <= 10'd147;
					end
					10'd546:
						if (wb_i == wb_n)
							ret;
						else begin
							wr(wb_a + (4 * wb_i), wb_v[wb_i[2:0]], 10'd546);
							wb_i <= wb_i + 4'd1;
						end
					10'd3: begin
						al_gc <= 1'b0;
						hl_skip <= 1'b0;
						if (hl_r)
							st <= 10'd812;
						else begin
							gc_alloc_req <= 1'b1;
							st <= 10'd8;
						end
					end
					10'd812:
						if (al_soft) begin
							al_ok <= 1'b0;
							al_a <= 32'd0;
							ret;
						end
						else begin
							hl_skip <= 1'b1;
							raise_msg(ABI_MSG_HEAP_LOCKED);
						end
					10'd811: begin
						soft_pt <= 1'b0;
						ab_lo <= 8'd32;
						ab_pe <= 8'd32;
						ab_nkw <= 8'd0;
						crk <= ABI_RK_DISCARD;
						ab_chunked <= 1'b0;
						hk_id <= ABI_HOOK_IRQ_DISPATCH;
						st <= 10'd241;
					end
					10'd8:
						if (gc_alloc_done_i) begin
							if (gc_alloc_ok_i) begin
								al_a <= gc_alloc_addr_i;
								al_ok <= 1'b1;
								ret;
							end
							else if (!al_gc) begin
								al_gc <= 1'b1;
								gosub(10'd209, 10'd7);
							end
							else if (al_soft) begin
								al_ok <= 1'b0;
								al_a <= 32'd0;
								ret;
							end
							else begin
								al_soft <= 1'b0;
								if (ab_chunked && ((ab_nblk != 32'd0) || ab_ovf)) begin
									t[2] <= VNULL;
									ab_blk <= VNULL;
									if (ab_ovf) begin
										t[4] <= VNULL;
										t[5] <= VNULL;
									end
									cv_k <= (ab_ovf ? 32'd4 : 32'd5);
									x1 <= (ab_ovf ? 32'd256 : 32'd5 + ab_nblk);
									st <= 10'd6;
								end
								else
									wr(aoff(EMERG_ADDR, 20), vint(al_n << 2), 10'd4);
							end
						end
					10'd7: begin
						gc_alloc_req <= 1'b1;
						st <= 10'd8;
					end
					10'd813:
						if (evt_q)
							deliver(VTRUE, crk);
						else if ((wfe_n == 32'd0) || wfe_n[31])
							deliver(VFALSE, crk);
						else
							wfe_n <= wfe_n - 32'd1;
					10'd4:
						wr(aoff(EMERG_ADDR, 12), VNULL, 10'd5);
					10'd5:
						raise_val(vobj(EMERG_ADDR));
					10'd6:
						if (cv_k == x1)
							wr(aoff(EMERG_ADDR, 20), vint(al_n << 2), 10'd4);
						else begin
							wr(ab_ptr(cv_k[7:0]), VNULL, 10'd6);
							cv_k <= cv_k + 32'd1;
						end
					10'd209:
						if (aalu_pend) begin
							if (aalu_go) begin
								aalu_ret <= 10'd209;
								st <= 10'd777;
							end
						end
						else if (noframe) begin
							gi <= 32'd0;
							st <= 10'd212;
						end
						else
							gosub(10'd508, 10'd210);
					10'd210: begin
						gi <= 32'd0;
						st <= 10'd212;
					end
					10'd211: begin
						gi <= 32'd0;
						st <= 10'd212;
					end
					10'd212:
						if (gi == 32'd9) begin
							if (ca_idle_i) begin
								gc_collect_req <= 1'b1;
								st <= 10'd213;
							end
						end
						else begin
							case (gi[3:0])
								4'd0:
									wr(ABI_SYSROOT_BASE + (4 * ABI_SR_CUR_EXC), xc, 10'd212);
								4'd1:
									wr(ABI_SYSROOT_BASE + (4 * ABI_SR_T0), t[0], 10'd212);
								4'd2:
									wr(ABI_SYSROOT_BASE + (4 * ABI_SR_T1), t[1], 10'd212);
								4'd3:
									wr(ABI_SYSROOT_BASE + (4 * ABI_SR_T2), t[2], 10'd212);
								4'd4:
									wr(ABI_SYSROOT_BASE + (4 * ABI_SR_T3), t[3], 10'd212);
								4'd5:
									wr(ABI_SYSROOT_BASE + (4 * ABI_SR_T4), t[4], 10'd212);
								4'd6:
									wr(ABI_SYSROOT_BASE + (4 * ABI_SR_T5), t[5], 10'd212);
								4'd7:
									wr(ABI_SYSROOT_BASE + (4 * ABI_SR_T6), t[6], 10'd212);
								default:
									wr(ABI_SYSROOT_BASE + (4 * ABI_SR_T7), t[7], 10'd212);
							endcase
							gi <= gi + 32'd1;
						end
					10'd213:
						if (gc_collect_done_i)
							ret;
					10'd531:
						case (tg(ty_v))
							ABI_TAG_CONTROL:
								rd(TT + (4 * (is_bool(ty_v) ? ABI_T_BOOL : ABI_T_NONETYPE)), 10'd533);
							ABI_TAG_INT, ABI_TAG_INT64:
								rd(TT + (4 * ABI_T_INT), 10'd533);
							ABI_TAG_FLOAT:
								rd(TT + (4 * ABI_T_FLOAT), 10'd533);
							ABI_TAG_COMPLEX:
								rd(TT + (4 * ABI_T_COMPLEX), 10'd533);
							ABI_TAG_QSTR, ABI_TAG_STR:
								rd(TT + (4 * ABI_T_STR), 10'd533);
							ABI_TAG_BYTES:
								rd(TT + (4 * ABI_T_BYTES), 10'd533);
							ABI_TAG_TUPLE:
								rd(TT + (4 * ABI_T_TUPLE), 10'd533);
							ABI_TAG_RANGE:
								rd(TT + (4 * ABI_T_RANGE), 10'd533);
							ABI_TAG_ITER:
								rd(TT + (4 * ABI_T_ITERATOR), 10'd533);
							ABI_TAG_OBJECT:
								rd(aoff(adr(ty_v), 4), 10'd533);
							ABI_TAG_MUT:
								case (ty_v[1:0])
									ABI_MUT_LIST:
										rd(TT + (4 * ABI_T_LIST), 10'd533);
									ABI_MUT_DICT:
										rd(TT + (4 * ABI_T_DICT), 10'd533);
									ABI_MUT_SET:
										rd(aoff(adr(ty_v), 12), 10'd532);
									default:
										rd(TT + (4 * ABI_T_BYTEARRAY), 10'd533);
								endcase
							default:
								rd(TT + (4 * ABI_T_OBJECT), 10'd533);
						endcase
					10'd532:
						rd(TT + (4 * (md & ABI_SET_FLAG_FROZEN ? ABI_T_FROZENSET : ABI_T_SET)), 10'd533);
					10'd533: begin
						ty_t <= mv;
						ret;
					end
					10'd231: begin
						hok <= 1'b1;
						case (tg(hk))
							ABI_TAG_INT: begin
								hh <= sx31(hk[31:0]);
								ret;
							end
							ABI_TAG_CONTROL: begin
								if (hk == VTRUE)
									hh <= 32'd1;
								else if (hk == VFALSE)
									hh <= 32'd0;
								else if (hk == VNONE)
									hh <= HASH_NONE;
								else
									hok <= 1'b0;
								ret;
							end
							ABI_TAG_QSTR: begin
								qid <= hk[31:0];
								qd_nxt <= 10'd237;
								st <= 10'd440;
							end
							ABI_TAG_STR, ABI_TAG_BYTES:
								rd(aoff(adr(hk), 4), 10'd237);
							ABI_TAG_INT64:
								rd(adr(hk), 10'd232);
							ABI_TAG_TUPLE:
								rd(adr(hk), 10'd233);
							ABI_TAG_OBJECT:
								rd(adr(hk), 10'd236);
							default: begin
								hok <= 1'b0;
								ret;
							end
						endcase
					end
					10'd237: begin
						hh <= {16'd0, md[15:0]};
						ret;
					end
					10'd232: begin
						hh <= sx31(md);
						ret;
					end
					10'd233: begin
						hh <= 32'd12345;
						if (md > 32'd15) begin
							hok <= 1'b0;
							ret;
						end
						else if (md == 32'd0)
							ret;
						else begin
							key_tuple_len <= md[3:0];
							key_tuple_index <= 4'd1;
							rd(ha_m4, 10'd234);
						end
					end
					10'd234:
						if (!intlike(mv)) begin
							hok <= 1'b0;
							ret;
						end
						else begin
							hh <= sx31(hh + ival(mv));
							st <= 10'd235;
						end
					10'd235:
						if (key_tuple_index == key_tuple_len)
							ret;
						else begin
							key_tuple_index <= key_tuple_index + 4'd1;
							rd(ha_m4, 10'd234);
						end
					10'd236: begin
						if (((md == ABI_OB_INSTANCE) || (md == ABI_OB_EXCEPTION)) || (md == ABI_OB_BIGINT))
							hok <= 1'b0;
						else
							hh <= {1'b0, hk[31:1]};
						ret;
					end
					10'd440:
						rd((qid < h_nq ? h_qdesc + (qid << 3) : h_qext + ((qid - h_nq) << 3)), qd_nxt);
					10'd500:
						if (tg(si_v) == ABI_TAG_QSTR) begin
							qid <= si_v[31:0];
							qd_nxt <= 10'd501;
							st <= 10'd440;
						end
						else
							rd(adr(si_v), 10'd503);
					10'd501: begin
						si_hash <= {16'd0, md[15:0]};
						si_len <= {16'd0, md[31:16]};
						rd(ha_m4, 10'd502);
					end
					10'd502: begin
						si_addr <= {1'b0, md[30:0]};
						si_na <= md[31];
						ret;
					end
					10'd503: begin
						si_len <= md;
						rd(aoff(adr(si_v), 4), 10'd504);
					end
					10'd504: begin
						si_hash <= {16'd0, md[15:0]};
						si_na <= md[30];
						rd(aoff(adr(si_v), 8), 10'd505);
					end
					10'd505: begin
						si_addr <= md;
						ret;
					end
					10'd129:
						if (tg(si_v) == ABI_TAG_QSTR)
							gosub(10'd500, 10'd131);
						else if (tg(si_v) == ABI_TAG_INT) begin
							si_addr <= si_v[31:0];
							ret;
						end
						else
							rd(aoff(adr(si_v), 8), 10'd130);
					10'd130: begin
						si_addr <= md;
						ret;
					end
					10'd131:
						ret;
					10'd521:
						if (scr_id != SCR_SE)
							scr_adopt(SCR_SE, 10'd521);
						else if (se_a == se_b) begin
							se_eq <= 1'b1;
							ret;
						end
						else begin
							si_v <= se_a;
							gosub(10'd500, 10'd495);
						end
					10'd495: begin
						sA[0] <= si_len;
						sA[1] <= si_hash;
						sA[2] <= si_addr;
						si_v <= se_b;
						gosub(10'd500, 10'd496);
					end
					10'd496:
						if ((si_len != sA[0]) || (si_hash != sA[1])) begin
							se_eq <= 1'b0;
							ret;
						end
						else begin
							sA[3] <= si_addr;
							sA[4] <= 32'd0;
							st <= 10'd499;
						end
					10'd499:
						if (sA[4] >= sA[0]) begin
							se_eq <= 1'b1;
							ret;
						end
						else
							rd(sA[2] + sA[4], 10'd497);
					10'd497: begin
						sA[5] <= md;
						rd(sA[3] + sA[4], 10'd498);
					end
					10'd498: begin
						v0 = sA[0] - sA[4];
						v1 = (v0 >= 32'd4 ? 32'hffffffff : (32'd1 << (v0 << 3)) - 32'd1);
						if (((sA[5] ^ md) & v1) != 32'd0) begin
							se_eq <= 1'b0;
							ret;
						end
						else begin
							sA[4] <= sA[4] + 32'd4;
							st <= 10'd499;
						end
					end
					10'd268: begin
						ke_cx <= 1'b0;
						if (ke_a == ke_b) begin
							ke_eq <= 1'b1;
							ret;
						end
						else if ((tg(ke_a) == ABI_TAG_QSTR) && (tg(ke_b) == ABI_TAG_QSTR)) begin
							ke_eq <= 1'b0;
							ret;
						end
						else if (strlike(ke_a) && strlike(ke_b)) begin
							se_a <= ke_a;
							se_b <= ke_b;
							gosub_scr(SCR_SE, 10'd521, 10'd279);
						end
						else if ((tg(ke_a) == ABI_TAG_BYTES) && (tg(ke_b) == ABI_TAG_BYTES)) begin
							se_a <= ke_a;
							se_b <= ke_b;
							gosub_scr(SCR_SE, 10'd521, 10'd279);
						end
						else if (strlike(ke_a) || strlike(ke_b)) begin
							ke_eq <= 1'b0;
							ret;
						end
						else if (intlike(ke_a) && intlike(ke_b)) begin
							ke_eq <= ival(ke_a) == ival(ke_b);
							ret;
						end
						else if ((tg(ke_a) == ABI_TAG_INT64) && (tg(ke_b) == ABI_TAG_INT64)) begin
							if (scr_id != SCR_KE)
								scr_adopt(SCR_KE, 10'd268);
							else
								rd(adr(ke_a), 10'd269);
						end
						else if ((tg(ke_a) == ABI_TAG_FLOAT) || (tg(ke_a) == ABI_TAG_COMPLEX)) begin
							ke_eq <= 1'b0;
							ke_cx <= numlike(ke_b);
							ret;
						end
						else if ((tg(ke_a) == ABI_TAG_TUPLE) && (tg(ke_b) == ABI_TAG_TUPLE))
							rd(adr(ke_a), 10'd274);
						else if ((tg(ke_a) == ABI_TAG_TUPLE) && (tg(ke_b) == ABI_TAG_OBJECT)) begin
							ke_eq <= 1'b0;
							ke_cx <= 1'b1;
							ret;
						end
						else if (tg(ke_a) == ABI_TAG_OBJECT)
							rd(adr(ke_a), 10'd273);
						else begin
							ke_eq <= 1'b0;
							ret;
						end
					end
					10'd279: begin
						ke_eq <= se_eq;
						ret;
					end
					10'd269: begin
						sA[0] <= md;
						rd(aoff(adr(ke_a), 4), 10'd270);
					end
					10'd270: begin
						sA[1] <= md;
						rd(adr(ke_b), 10'd271);
					end
					10'd271:
						if (md != sA[0]) begin
							ke_eq <= 1'b0;
							ret;
						end
						else
							rd(aoff(adr(ke_b), 4), 10'd272);
					10'd272: begin
						ke_eq <= md == sA[1];
						ret;
					end
					10'd273: begin
						ke_eq <= 1'b0;
						ke_cx <= (md == ABI_OB_INSTANCE) || (md == ABI_OB_EXCEPTION);
						ret;
					end
					10'd274:
						if (md > 32'd15) begin
							ke_eq <= 1'b0;
							ke_cx <= 1'b1;
							ret;
						end
						else begin
							key_tuple_len <= md[3:0];
							rd(adr(ke_b), 10'd275);
						end
					10'd275:
						if (md != sv2v_cast_32(key_tuple_len)) begin
							ke_eq <= 1'b0;
							ret;
						end
						else if (md == 32'd0) begin
							ke_eq <= 1'b1;
							ret;
						end
						else begin
							key_tuple_index <= 4'd1;
							st <= 10'd278;
						end
					10'd278:
						rd(adr(ke_a) + {26'd0, key_tuple_index, 2'b00}, 10'd276);
					10'd276: begin
						key_tuple_item <= mv;
						rd(adr(ke_b) + {26'd0, key_tuple_index, 2'b00}, 10'd277);
					end
					10'd277:
						if ((((key_tuple_item == mv) && (tg(mv) != ABI_TAG_FLOAT)) && (tg(mv) != ABI_TAG_COMPLEX)) || ((intlike(key_tuple_item) && intlike(mv)) && (ival(key_tuple_item) == ival(mv)))) begin
							if (key_tuple_index == key_tuple_len) begin
								ke_eq <= 1'b1;
								ret;
							end
							else begin
								key_tuple_index <= key_tuple_index + 4'd1;
								st <= 10'd278;
							end
						end
						else begin
							ke_eq <= 1'b0;
							ke_cx <= !(intlike(key_tuple_item) && intlike(mv));
							ret;
						end
					10'd296:
						if (scr_id != SCR_LK)
							scr_adopt(SCR_LK, 10'd296);
						else begin
							lk_found <= 1'b0;
							lk_cx <= 1'b0;
							lk_ro <= 1'b0;
							lk_res <= VNULL;
							rd(aoff(adr(t[4]), 12), 10'd299);
						end
					10'd299:
						if ((lk_mode != LK_FIND) && (md & ABI_DICT_FLAG_ROM)) begin
							lk_ro <= 1'b1;
							ret;
						end
						else
							rd(aoff(adr(t[4]), 4), 10'd297);
					10'd297: begin
						sA[0] <= md;
						rd(aoff(adr(t[4]), 8), 10'd318);
					end
					10'd318: begin
						sA[1] <= md;
						if (sA[0] == 32'd0) begin
							if (lk_mode == LK_ADD)
								gosub_scr(SCR_RH, 10'd446, 10'd312);
							else
								ret;
						end
						else begin
							hk <= t[5];
							gosub(10'd231, 10'd300);
						end
					end
					10'd312:
						if (lk_cx)
							ret;
						else
							st <= 10'd296;
					10'd300:
						if (!hok) begin
							lk_cx <= 1'b1;
							ret;
						end
						else if (hh < sA[0]) begin
							sA[2] <= hh;
							sA[3] <= hh;
							lk_hasav <= 1'b0;
							st <= 10'd310;
						end
						else begin
							hm_start <= 1'b1;
							st <= 10'd301;
						end
					10'd301:
						if (hm_done) begin
							sA[2] <= hm_rem;
							sA[3] <= hm_rem;
							lk_hasav <= 1'b0;
							st <= 10'd310;
						end
					10'd310: begin
						sA[5] <= sA[1] + (lk_set ? sA[2] << 2 : sA[2] << 3);
						rd(sA[1] + (lk_set ? sA[2] << 2 : sA[2] << 3), 10'd307);
					end
					10'd307:
						if (mv == VNULL) begin
							if (lk_mode == LK_ADD) begin
								if (lk_hasav)
									sA[5] <= sA[4];
								st <= 10'd304;
							end
							else
								ret;
						end
						else if (mv == VTOMB) begin
							if (!lk_hasav) begin
								lk_hasav <= 1'b1;
								sA[4] <= sA[5];
							end
							st <= 10'd309;
						end
						else if (mv == t[5])
							st <= 10'd302;
						else if (((tg(mv) == ABI_TAG_QSTR) && (tg(t[5]) == ABI_TAG_QSTR)) || ((tg(mv) == ABI_TAG_INT) && (tg(t[5]) == ABI_TAG_INT)))
							st <= 10'd309;
						else begin
							ke_a <= mv;
							ke_b <= t[5];
							gosub(10'd268, 10'd308);
						end
					10'd308:
						if (ke_cx) begin
							lk_cx <= 1'b1;
							ret;
						end
						else if (scr_id != SCR_LK)
							scr_ensure(SCR_LK, 10'd308);
						else if (ke_eq)
							st <= 10'd302;
						else
							st <= 10'd309;
					10'd309: begin
						v0 = ((sA[2] + 32'd1) == sA[0] ? 32'd0 : sA[2] + 32'd1);
						if (v0 == sA[3]) begin
							if (lk_mode == LK_ADD) begin
								if (lk_hasav) begin
									sA[5] <= sA[4];
									st <= 10'd304;
								end
								else
									gosub_scr(SCR_RH, 10'd446, 10'd312);
							end
							else
								ret;
						end
						else begin
							sA[2] <= v0;
							st <= 10'd310;
						end
					end
					10'd302: begin
						lk_found <= 1'b1;
						case (lk_mode)
							LK_FIND:
								if (lk_set) begin
									lk_res <= t[5];
									ret;
								end
								else
									rd(ha_lk4, 10'd319);
							LK_ADD:
								if (lk_set)
									ret;
								else
									wr(ha_lk4, t[6], 10'd311);
							default:
								if (lk_set)
									st <= 10'd313;
								else
									rd(ha_lk4, 10'd317);
						endcase
					end
					10'd319: begin
						lk_res <= mv;
						ret;
					end
					10'd311:
						ret;
					10'd317: begin
						lk_res <= mv;
						st <= 10'd313;
					end
					10'd313: begin
						v0 = ((sA[2] + 32'd1) == sA[0] ? 32'd0 : sA[2] + 32'd1);
						rd(sA[1] + (lk_set ? v0 << 2 : v0 << 3), 10'd314);
					end
					10'd314:
						wr(sA[5], (mv == VNULL ? VNULL : VTOMB), 10'd315);
					10'd315:
						if (lk_set)
							rd(adr(t[4]), 10'd298);
						else
							wr(ha_lk4, VNULL, 10'd316);
					10'd316:
						rd(adr(t[4]), 10'd298);
					10'd298:
						wr(adr(t[4]), vint(md - 32'd1), 10'd311);
					10'd304:
						wr(sA[5], t[5], (lk_set ? 10'd306 : 10'd305));
					10'd305:
						wr(ha_lk4, t[6], 10'd306);
					10'd306:
						rd(adr(t[4]), 10'd303);
					10'd303:
						wr(adr(t[4]), vint(md + 32'd1), 10'd311);
					10'd446:
						if (scr_id != SCR_RH)
							scr_adopt(SCR_RH, 10'd446);
						else
							st <= 10'd767;
					10'd767:
						rd(scr_addr(SCR_LK, 4'd0), 10'd768);
					10'd768: begin
						sA[0] <= md + 32'd1;
						st <= 10'd769;
					end
					10'd769: begin
						sA[0] <= next_alloc(sA[0]);
						alloc(next_alloc(sA[0]) << (lk_set ? 0 : 1), 10'd447);
					end
					10'd447: begin
						sA[1] <= al_a;
						sA[2] <= 32'd0;
						sA[4] <= 32'd0;
						rd(aoff(adr(t[4]), 4), 10'd448);
					end
					10'd448: begin
						sA[5] <= md;
						rd(aoff(adr(t[4]), 8), 10'd449);
					end
					10'd449: begin
						sA[6] <= md;
						st <= ((cfg_ca && cfg_bulk) && (sA[5] != 0) ? 10'd409 : 10'd456);
					end
					10'd456:
						if (sA[2] == sA[5])
							wr(aoff(adr(t[4]), 4), vint(sA[0]), 10'd450);
						else
							rd(sA[6] + (lk_set ? sA[2] << 2 : sA[2] << 3), 10'd455);
					10'd455:
						if ((mv == VNULL) || (mv == VTOMB)) begin
							sA[2] <= sA[2] + 32'd1;
							st <= 10'd456;
						end
						else begin
							sV[7] <= mv;
							hk <= mv;
							gosub(10'd231, 10'd453);
						end
					10'd453:
						if (!hok) begin
							lk_cx <= 1'b1;
							ret;
						end
						else if (hh < sA[0]) begin
							sA[3] <= hh;
							st <= 10'd458;
						end
						else begin
							hm_start <= 1'b1;
							st <= 10'd454;
						end
					10'd454:
						if (hm_done) begin
							sA[3] <= hm_rem;
							st <= 10'd458;
						end
					10'd458:
						rd(sA[1] + (lk_set ? sA[3] << 2 : sA[3] << 3), 10'd459);
					10'd459:
						if (mv != VNULL) begin
							sA[3] <= ((sA[3] + 32'd1) == sA[0] ? 32'd0 : sA[3] + 32'd1);
							st <= 10'd458;
						end
						else
							wr(sA[1] + (lk_set ? sA[3] << 2 : sA[3] << 3), sV[7], (lk_set ? 10'd457 : 10'd460));
					10'd460:
						rd((sA[6] + (sA[2] << 3)) + 4, 10'd461);
					10'd461:
						wr((sA[1] + (sA[3] << 3)) + 4, mv, 10'd457);
					10'd457: begin
						sA[4] <= sA[4] + 32'd1;
						sA[2] <= sA[2] + 32'd1;
						st <= 10'd456;
					end
					10'd450:
						wr(aoff(adr(t[4]), 8), {ABI_TAG_CONT, sA[1]}, 10'd451);
					10'd451:
						wr(adr(t[4]), vint(sA[4]), 10'd452);
					10'd452:
						wr(scr_addr(SCR_LK, 4'd0), {4'd0, sA[0]}, 10'd770);
					10'd770:
						wr(scr_addr(SCR_LK, 4'd1), {4'd0, sA[1]}, 10'd311);
					10'd280:
						if (scr_id != SCR_LA)
							scr_adopt(SCR_LA, 10'd280);
						else
							rd(adr(t[2]), 10'd291);
					10'd291: begin
						sA[0] <= md;
						rd(aoff(adr(t[2]), 4), 10'd281);
					end
					10'd281: begin
						sA[1] <= md;
						rd(aoff(adr(t[2]), 8), 10'd289);
					end
					10'd289: begin
						sA[2] <= md;
						if (sA[0] < sA[1])
							wr(md + (sA[0] << 2), t[3], 10'd290);
						else
							alloc((sA[1] == 32'd0 ? 32'd4 : sA[1] << 1), 10'd285);
					end
					10'd285:
						if (!al_ok)
							ret;
						else begin
							sA[3] <= al_a;
							sA[4] <= 32'd0;
							rd(aoff(adr(t[2]), 8), 10'd286);
						end
					10'd286: begin
						sA[2] <= md;
						st <= (cfg_ca && (sA[0] != 32'd0) ? 10'd776 : 10'd283);
					end
					10'd776:
						if (ca_ok) begin
							ca_ship(sA[3], sA[2], sA[0]);
							sA[4] <= sA[0];
							st <= 10'd283;
						end
					10'd283:
						if (sA[4] == sA[0])
							wr(aoff(adr(t[2]), 4), vint((sA[1] == 32'd0 ? 32'd4 : sA[1] << 1)), 10'd287);
						else
							rd(sA[2] + (sA[4] << 2), 10'd284);
					10'd284: begin
						wr(sA[3] + (sA[4] << 2), mv, 10'd283);
						sA[4] <= sA[4] + 32'd1;
					end
					10'd287:
						wr(aoff(adr(t[2]), 8), {ABI_TAG_CONT, sA[3]}, 10'd288);
					10'd288:
						if (sA[2] == (adr(t[2]) + 32'd12)) begin
							sA[4] <= 0;
							st <= 10'd809;
						end
						else
							st <= 10'd810;
					10'd809:
						if (sA[4] == sA[0])
							st <= 10'd810;
						else begin
							wr(sA[2] + (sA[4] << 2), VNULL, 10'd809);
							sA[4] <= sA[4] + 32'd1;
						end
					10'd810:
						wr(sA[3] + (sA[0] << 2), t[3], 10'd290);
					10'd290:
						wr(adr(t[2]), vint(sA[0] + 32'd1), 10'd293);
					10'd293:
						ret;
					10'd528:
						if (tb_n == 16'd0) begin
							tb_v <= {ABI_TAG_TUPLE, h_empty};
							ret;
						end
						else
							alloc(32'd1 + tb_n, 10'd529);
					10'd529: begin
						tb_a <= al_a;
						tb_i <= 16'd0;
						wr(al_a, vint(sv2v_cast_32(tb_n)), 10'd530);
					end
					10'd530:
						if (tb_i == tb_n) begin
							tb_v <= {ABI_TAG_TUPLE, tb_a};
							ret;
						end
						else if (!tb_src)
							rd(ab_ptr(sv2v_cast_8(tb_from + tb_i)), 10'd671);
						else begin
							v0 = {16'd0, stk_from} + {16'd0, tb_i};
							if (stk_hit(v0[15:0])) begin
								wr((tb_a + 4) + (4 * tb_i), stk_val(v0[15:0]), 10'd530);
								tb_i <= tb_i + 16'd1;
							end
							else begin
								srd_g <= v0[15:0];
								gosub(10'd569, 10'd582);
							end
						end
					10'd671: begin
						if (tb_nz && (mv == VNULL))
							wr((tb_a + 4) + (4 * tb_i), vint(32'd0), 10'd530);
						else
							wr((tb_a + 4) + (4 * tb_i), mv, 10'd530);
						tb_i <= tb_i + 16'd1;
					end
					10'd582: begin
						wr((tb_a + 4) + (4 * tb_i), srd_v, 10'd530);
						tb_i <= tb_i + 16'd1;
					end
					10'd249:
						if ((is_c == ty_obj) || (is_c == is_t)) begin
							is_r <= 1'b1;
							ret;
						end
						else
							rd(aoff(adr(is_t), 20), 10'd252);
					10'd252: begin
						is_m <= adr(mv);
						rd(adr(mv), 10'd253);
					end
					10'd253: begin
						is_n <= md;
						is_i <= 32'd0;
						st <= 10'd251;
					end
					10'd251:
						if (is_i == is_n) begin
							is_r <= 1'b0;
							ret;
						end
						else
							rd((is_m + 4) + (is_i << 2), 10'd250);
					10'd250:
						if (mv == is_c) begin
							is_r <= 1'b1;
							ret;
						end
						else begin
							is_i <= is_i + 32'd1;
							st <= 10'd251;
						end
					10'd524: begin
						tr_x <= 1'b0;
						if ((ovr == ABI_OVR_TRUE) || (ovr == ABI_OVR_FALSE)) begin
							tr_r <= ovr == ABI_OVR_TRUE;
							ovr <= ABI_OVR_NONE;
							ret;
						end
						else
							case (tg(tr_v))
								ABI_TAG_CONTROL: begin
									tr_r <= tr_v == VTRUE;
									ret;
								end
								ABI_TAG_INT: begin
									tr_r <= tr_v[31:0] != 32'd0;
									ret;
								end
								ABI_TAG_FLOAT: begin
									tr_r <= tr_v[30:0] != 31'd0;
									ret;
								end
								ABI_TAG_INT64, ABI_TAG_ITER: begin
									tr_r <= 1'b1;
									ret;
								end
								ABI_TAG_QSTR: begin
									tr_r <= tr_v[31:0] != ABI_Q_EMPTY;
									ret;
								end
								ABI_TAG_STR, ABI_TAG_BYTES, ABI_TAG_TUPLE, ABI_TAG_MUT:
									rd(adr(tr_v), 10'd526);
								ABI_TAG_OBJECT:
									rd(aoff(adr(tr_v), 4), 10'd527);
								default: begin
									tr_x <= 1'b1;
									ret;
								end
							endcase
					end
					10'd526: begin
						tr_r <= md != 32'd0;
						ret;
					end
					10'd527:
						rd(aoff(adr(mv), 28), 10'd525);
					10'd525: begin
						if (md & ABI_TF_TRUTH)
							tr_x <= 1'b1;
						else
							tr_r <= 1'b1;
						ret;
					end
					10'd9:
						if (scr_id != SCR_AT)
							scr_adopt(SCR_AT, 10'd9);
						else begin
							at_ty <= 1'b0;
							at_objd <= 1'b0;
							if (tg(t[0]) == ABI_TAG_OBJECT)
								rd(adr(t[0]), 10'd12);
							else begin
								ty_v <= t[0];
								gosub(10'd531, 10'd22);
							end
						end
					10'd12:
						if (md == ABI_OB_INSTANCE)
							rd(aoff(adr(t[0]), 8), 10'd10);
						else if (md == ABI_OB_EXCEPTION)
							rd(aoff(adr(t[0]), 16), 10'd10);
						else if (md == ABI_OB_TYPE) begin
							sV[6] <= t[0];
							at_ty <= 1'b1;
							st <= 10'd20;
						end
						else if (md == ABI_OB_MODULE)
							rd(aoff(adr(t[0]), 8), 10'd17);
						else
							rd(aoff(adr(t[0]), 4), 10'd23);
					10'd10:
						if (mv == VNULL)
							rd(aoff(adr(t[0]), 4), 10'd23);
						else
							lookup(mv, {ABI_TAG_QSTR, at_q}, VNULL, LK_FIND, 1'b0, 10'd11);
					10'd11:
						if (lk_found) begin
							at_kind <= 2'd1;
							at_v <= lk_res;
							ret;
						end
						else if (scr_id != SCR_AT)
							scr_ensure(SCR_AT, 10'd11);
						else
							rd(aoff(adr(t[0]), 4), 10'd23);
					10'd17:
						lookup(mv, {ABI_TAG_QSTR, at_q}, VNULL, LK_FIND, 1'b0, 10'd18);
					10'd18: begin
						at_kind <= (lk_found ? 2'd1 : 2'd0);
						at_v <= lk_res;
						ret;
					end
					10'd23: begin
						sV[6] <= mv;
						st <= 10'd20;
					end
					10'd22: begin
						sV[6] <= ty_t;
						st <= 10'd20;
					end
					10'd20:
						rd(aoff(adr(sV[6]), 20), 10'd13);
					10'd13: begin
						sA[0] <= adr(mv);
						rd(adr(mv), 10'd14);
					end
					10'd14: begin
						sA[1] <= md;
						sA[2] <= 32'd0;
						st <= 10'd16;
					end
					10'd16:
						if (sA[2] == sA[1]) begin
							if (!at_objd) begin
								at_objd <= 1'b1;
								rd(aoff(adr(ty_obj), 8), 10'd15);
							end
							else begin
								at_kind <= 2'd0;
								ret;
							end
						end
						else
							rd((sA[0] + 4) + (sA[2] << 2), 10'd21);
					10'd21:
						rd(aoff(adr(mv), 8), 10'd15);
					10'd15:
						lookup(mv, {ABI_TAG_QSTR, at_q}, VNULL, LK_FIND, 1'b0, 10'd19);
					10'd19:
						if (scr_id != SCR_AT)
							scr_ensure(SCR_AT, 10'd19);
						else if (!lk_found) begin
							if (at_objd) begin
								at_kind <= 2'd0;
								ret;
							end
							else begin
								sA[2] <= sA[2] + 32'd1;
								st <= 10'd16;
							end
						end
						else begin
							at_v <= lk_res;
							if (tg(lk_res) == ABI_TAG_OBJECT)
								rd(adr(lk_res), 10'd24);
							else begin
								at_kind <= 2'd1;
								ret;
							end
						end
					10'd24: begin
						if ((md == ABI_OB_FUNCTION) || (md == ABI_OB_BUILTIN))
							at_kind <= (at_ty ? 2'd1 : 2'd2);
						else if (((md == ABI_OB_STATICMETHOD) || (md == ABI_OB_CLASSMETHOD)) || (md == ABI_OB_PROPERTY))
							at_kind <= 2'd3;
						else
							at_kind <= 2'd3;
						ret;
					end
					10'd254:
						if (scr_id != SCR_IT)
							scr_ensure(SCR_IT, 10'd254);
						else begin
							it_stop <= 1'b0;
							it_py <= 1'b0;
							sA[4] <= sV[1][31:0];
							case (sV[3][31:0])
								ABI_IT_RANGE: begin
									if ((sV[2][31] ? $signed(sV[0][31:0]) <= $signed(sV[1][31:0]) : $signed(sV[0][31:0]) >= $signed(sV[1][31:0])))
										it_stop <= 1'b1;
									else begin
										it_val <= sV[0];
										sV[0] <= vint(sV[0][31:0] + sV[2][31:0]);
									end
									ret;
								end
								ABI_IT_SEQ:
									if ((tg(sV[0]) == ABI_TAG_TUPLE) || is_mut(sV[0], ABI_MUT_LIST))
										rd(adr(sV[0]), 10'd265);
									else begin
										si_v <= sV[0];
										gosub(10'd500, 10'd256);
									end
								ABI_IT_DICT, ABI_IT_SET:
									rd(aoff(adr(sV[0]), 4), 10'd257);
								ABI_IT_STR: begin
									si_v <= sV[0];
									gosub(10'd500, 10'd256);
								end
								ABI_IT_PYOBJ: begin
									it_py <= 1'b1;
									ret;
								end
								default: begin
									it_stop <= 1'b1;
									ret;
								end
							endcase
						end
					10'd265:
						if (sA[4] >= md) begin
							it_stop <= 1'b1;
							ret;
						end
						else if (tg(sV[0]) == ABI_TAG_TUPLE)
							rd((adr(sV[0]) + 4) + (sA[4] << 2), 10'd266);
						else
							rd(aoff(adr(sV[0]), 8), 10'd263);
					10'd263:
						rd(md + (sA[4] << 2), 10'd266);
					10'd266: begin
						it_val <= mv;
						sV[1] <= vint(sA[4] + 32'd1);
						ret;
					end
					10'd256:
						if (sA[4] >= si_len) begin
							it_stop <= 1'b1;
							ret;
						end
						else
							rd(si_addr + {sA[4][31:2], 2'b00}, 10'd255);
					10'd255:
						if ((tg(sV[0]) == ABI_TAG_BYTES) || is_mut(sV[0], ABI_MUT_BYTEARRAY)) begin
							it_val <= vint({24'd0, byte_of(md, sA[4][1:0])});
							sV[1] <= vint(sA[4] + 32'd1);
							ret;
						end
						else
							rd(h_chars + (4 * byte_of(md, sA[4][1:0])), 10'd264);
					10'd264: begin
						it_val <= {ABI_TAG_QSTR, md};
						sV[1] <= vint(sA[4] + 32'd1);
						ret;
					end
					10'd257: begin
						sA[5] <= md;
						rd(aoff(adr(sV[0]), 8), 10'd261);
					end
					10'd261: begin
						sA[6] <= md;
						st <= 10'd260;
					end
					10'd260:
						if (sA[4] >= sA[5]) begin
							it_stop <= 1'b1;
							sV[1] <= vint(sA[4]);
							ret;
						end
						else
							rd(sA[6] + (sV[3][31:0] == ABI_IT_SET ? sA[4] << 2 : sA[4] << 3), 10'd259);
					10'd259:
						if ((mv == VNULL) || (mv == VTOMB)) begin
							sA[4] <= sA[4] + 32'd1;
							st <= 10'd260;
						end
						else if ((sV[3][31:0] == ABI_IT_SET) || (sV[2][31:0] == 32'd0)) begin
							it_val <= mv;
							sV[1] <= vint(sA[4] + 32'd1);
							ret;
						end
						else if (sV[2][31:0] == 32'd1)
							rd(ha_m4, 10'd266);
						else begin
							t[2] <= mv;
							rd(ha_m4, 10'd262);
						end
					10'd262: begin
						t[1] <= mv;
						alloc(32'd3, 10'd258);
					end
					10'd258: begin
						wb_v[0] <= vint(32'd2);
						wb_v[1] <= t[2];
						wb_v[2] <= t[1];
						it_val <= {ABI_TAG_TUPLE, al_a};
						sV[1] <= vint(sA[4] + 32'd1);
						wblock(al_a, 4'd3, 10'd293);
					end
					10'd563:
						if (aalu_pend) begin
							if (aalu_go) begin
								aalu_ret <= 10'd563;
								st <= 10'd777;
							end
						end
						else begin
							v0 = (cfg_adapt && !rf_mono ? MPY_RF_CHUNK_MIN : sv2v_cast_32(cfg_grow));
							if (v0 < MPY_RF_CHUNK_MIN)
								v0 = MPY_RF_CHUNK_MIN;
							if (v0 > MPY_RF_CHUNK_MAX)
								v0 = MPY_RF_CHUNK_MAX;
							v1 = (has_link ? (sp > sv2v_cast_7_signed(RF_LEAVE_SP) ? sv2v_cast_32(sp - sv2v_cast_7_signed(RF_LEAVE_SP)) : 32'd0) : (sp > sv2v_cast_7_signed(4) ? sv2v_cast_32(sp - sv2v_cast_7_signed(4)) : 32'd0));
							if (v0 > v1)
								v0 = v1;
							spill_nc <= v0[5:0];
							spill_bc <= mpy_rf_block_bytes(v0[5:0]);
							st <= 10'd564;
						end
					10'd564:
						if (spill_nc < sv2v_cast_6_signed(MPY_RF_CHUNK_MIN))
							st <= rf_resume;
						else if (spill_hp < (ftop + spill_bc))
							raise_msg(ABI_MSG_RECURSION);
						else begin
							spill_n <= spill_nc;
							spill_ntag <= (spill_nc + 6'd7) >> 32'sd3;
							spill_words <= (32'd1 + sv2v_cast_32((spill_nc + 6'd7) >> 3)) + sv2v_cast_32(spill_nc);
							spill_addr <= spill_hp - spill_bc;
							spill_had_link <= has_link;
							spill_prev <= (has_link ? mpy_rf_link_addr(rf[rf_base[3:0] + 4'd0]) : 32'd0);
							sw_i <= 32'd0;
							st <= 10'd565;
						end
					10'd565:
						if (sw_i == spill_words) begin
							if (spill_had_link) begin
								rf[rf_base[3:0] + sv2v_cast_4(spill_n)] <= mpy_make_rf_link(spill_addr);
								rf_base <= sv2v_cast_6(sv2v_cast_4(rf_base + spill_n));
								sp <= sp - {1'b0, spill_n};
							end
							else begin
								rf[rf_base[3:0] + sv2v_cast_4(spill_n - 6'd1)] <= mpy_make_rf_link(spill_addr);
								rf_base <= sv2v_cast_6(sv2v_cast_4((rf_base + spill_n) - 6'd1));
								sp <= (sp - {1'b0, spill_n}) + 7'd1;
							end
							spill_hp <= spill_addr;
							spilled_reals <= spilled_reals + {10'd0, spill_n};
							sp_hold <= 1'b1;
							st <= rf_resume;
						end
						else if (sw_i == 32'd0) begin
							wr(spill_addr, mpy_rf_chunk_hdr(spill_prev, spill_n), 10'd565);
							sw_i <= 32'd1;
						end
						else if (sw_i <= sv2v_cast_32(spill_ntag)) begin
							v3 = 32'd0;
							begin : sv2v_autoblock_23
								reg signed [31:0] k;
								for (k = 0; k < 8; k = k + 1)
									begin
										vs0 = sv2v_cast_7((sw_i[5:0] - 6'd1) << 3) + sv2v_cast_7_signed(k);
										if (vs0 < {1'b0, spill_n})
											v3[4 * k+:4] = rf[rf_base[3:0] + sv2v_cast_4((spill_had_link ? vs0 + 7'd1 : vs0))][35:32];
									end
							end
							wr(spill_addr + (sw_i << 2), {4'd0, v3}, 10'd565);
							sw_i <= sw_i + 32'd1;
						end
						else begin
							vs0 = (spill_had_link ? sw_i[6:0] - {1'b0, spill_ntag} : (sw_i[6:0] - 7'd1) - {1'b0, spill_ntag});
							wr(spill_addr + (sw_i << 2), rf[rf_base[3:0] + sv2v_cast_4(vs0)], 10'd565);
							sw_i <= sw_i + 32'd1;
						end
					10'd566:
						if (aalu_pend) begin
							if (aalu_go) begin
								aalu_ret <= 10'd566;
								st <= 10'd777;
							end
						end
						else if (!has_link)
							st <= rf_resume;
						else begin
							spill_addr <= mpy_rf_link_addr(rf[rf_base[3:0] + 4'd0]);
							sw_i <= 32'd0;
							st <= 10'd567;
						end
					10'd567:
						if ((sw_i != 32'd0) && (sw_i == spill_words)) begin
							spilled_reals <= (spilled_reals >= {10'd0, spill_n} ? spilled_reals - {10'd0, spill_n} : 16'd0);
							if (reload_top)
								spill_hp <= spill_addr + mpy_rf_block_bytes(spill_n);
							if (spill_prev != 32'd0) begin
								rf[sv2v_cast_4(rf_base - spill_n)] <= mpy_make_rf_link(spill_prev);
								rf_base <= sv2v_cast_6(sv2v_cast_4(rf_base - spill_n));
								sp <= sp + {1'b0, spill_n};
							end
							else begin
								rf_base <= sv2v_cast_6(sv2v_cast_4(rf_base - (spill_n - 6'd1)));
								sp <= (sp + {1'b0, spill_n}) - 7'd1;
							end
							rf_reload_miss <= 1'b0;
							sp_hold <= 1'b1;
							st <= rf_resume;
						end
						else
							rd(spill_addr + (sw_i << 2), 10'd568);
					10'd568:
						if (sw_i == 32'd0) begin
							v0 = sv2v_cast_32(mpy_rf_chunk_count(mt, md));
							v1 = mpy_rf_chunk_prev(md);
							v2 = sv2v_cast_32(sp) + (v1 != 32'd0 ? v0 : v0 - 32'd1);
							spill_n <= v0[5:0];
							spill_prev <= v1;
							spill_ntag <= sv2v_cast_6((v0[5:0] + 6'd7) >> 3);
							spill_words <= (32'd1 + sv2v_cast_32((v0[5:0] + 6'd7) >> 3)) + v0;
							reload_top <= spill_addr == spill_hp;
							if (((v0 < MPY_RF_CHUNK_MIN) || (v0 > MPY_RF_CHUNK_MAX)) || (v2 > MPY_RF_DEPTH)) begin
								if (rf_resume == 10'd139) begin
									rf_reload_miss <= 1'b1;
									st <= 10'd139;
								end
								else
									halt(ABI_HALT_INTERNAL, 32'h00005f01);
							end
							else begin
								sw_i <= 32'd1 + sv2v_cast_32((v0[5:0] + 6'd7) >> 3);
								st <= 10'd567;
							end
						end
						else begin
							v0 = (sw_i - 32'd1) - sv2v_cast_32(spill_ntag);
							rf[sv2v_cast_4(((rf_base - spill_n) + v0) + 32'd1)] <= mv;
							sw_i <= sw_i + 32'd1;
							st <= 10'd567;
						end
					10'd569:
						if (stk_hit(srd_g)) begin
							srd_v <= stk_val(srd_g);
							ret;
						end
						else if (!has_link) begin
							srd_v <= VNULL;
							ret;
						end
						else begin
							srd_addr <= mpy_rf_link_addr(rf[rf_base[3:0] + 4'd0]);
							srd_off <= (spilled_reals - 16'd1) - srd_g;
							srd_hops <= 16'd0;
							st <= 10'd570;
						end
					10'd570:
						rd(srd_addr, 10'd571);
					10'd571: begin
						v0 = sv2v_cast_32(mpy_rf_chunk_count(mt, md));
						v1 = mpy_rf_chunk_prev(md);
						if ((v0 != 32'd0) && (srd_off < v0[15:0]))
							rd(((srd_addr + 32'd4) + (sv2v_cast_32((v0[5:0] + 6'd7) >> 3) << 2)) + (((v0 - 32'd1) - sv2v_cast_32(srd_off)) << 2), 10'd572);
						else if ((v1 == 32'd0) || (srd_hops == spilled_reals)) begin
							srd_v <= VNULL;
							ret;
						end
						else begin
							srd_off <= srd_off - v0[15:0];
							srd_addr <= v1;
							srd_hops <= srd_hops + 16'd1;
							st <= 10'd570;
						end
					end
					10'd572: begin
						srd_v <= mv;
						ret;
					end
					10'd599:
						if (b1)
							wr(ab_ptr(8'd31), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(s1 + 7'd1))], 10'd600);
						else
							st <= 10'd600;
					10'd600:
						if (sv2v_cast_32(i0) == x1)
							st <= 10'd94;
						else begin
							wr(ab_ptr(8'd32 + i0), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(s0 + sv2v_cast_7(i0)))], 10'd600);
							i0 <= i0 + 8'd1;
						end
					10'd573:
						if (stk_hit(x0[15:0]))
							wr(ab_ptr(8'd0), stk_val(x0[15:0]), 10'd575);
						else begin
							srd_g <= x0[15:0];
							gosub(10'd569, 10'd574);
						end
					10'd574:
						wr(ab_ptr(8'd0), srd_v, 10'd575);
					10'd575:
						if (!b0) begin
							ab_lo <= 8'd32;
							st <= 10'd577;
						end
						else if (stk_hit(x0[15:0] + 16'd1)) begin
							if (stk_val(x0[15:0] + 16'd1) != VNULL) begin
								wr(ab_ptr(8'd31), stk_val(x0[15:0] + 16'd1), 10'd577);
								ab_lo <= 8'd31;
							end
							else begin
								ab_lo <= 8'd32;
								st <= 10'd577;
							end
						end
						else begin
							srd_g <= x0[15:0] + 16'd1;
							gosub(10'd569, 10'd576);
						end
					10'd576:
						if (srd_v != VNULL) begin
							wr(ab_ptr(8'd31), srd_v, 10'd577);
							ab_lo <= 8'd31;
						end
						else begin
							ab_lo <= 8'd32;
							st <= 10'd577;
						end
					10'd577:
						if (gi == x1)
							st <= 10'd579;
						else if (stk_hit(x2[15:0] + gi[15:0])) begin
							wr(ab_ptr(sv2v_cast_8(32 + gi)), stk_val(x2[15:0] + gi[15:0]), 10'd577);
							gi <= gi + 32'd1;
						end
						else begin
							srd_g <= x2[15:0] + gi[15:0];
							gosub(10'd569, 10'd578);
						end
					10'd578: begin
						wr(ab_ptr(sv2v_cast_8(32 + gi)), srd_v, 10'd577);
						gi <= gi + 32'd1;
					end
					10'd579: begin
						ab_pe <= sv2v_cast_8(32 + x4);
						crk <= ABI_RK_PUSH;
						drop_left <= x3[15:0];
						drop_push_en <= 1'b0;
						drop_then <= 10'd94;
						st <= 10'd580;
					end
					10'd580:
						if (drop_left == 16'd0) begin
							if (drop_push_en) begin
								if (sp >= sv2v_cast_7_signed(MPY_RF_DEPTH)) begin
									rf_pend <= 1'b1;
									rf_pend_v <= drop_push_v;
									rf_resume <= drop_then;
									st <= 10'd563;
								end
								else begin
									rf[rf_base[3:0] + sv2v_cast_4(sp)] <= drop_push_v;
									sp <= sp + 7'd1;
									st <= drop_then;
								end
							end
							else
								st <= drop_then;
						end
						else if (has_link && (sp <= 7'd1)) begin
							rf_resume <= 10'd580;
							st <= 10'd566;
						end
						else if (sp == 7'd0)
							drop_left <= 16'd0;
						else begin
							sp <= sp - 7'd1;
							drop_left <= drop_left - 16'd1;
						end
					10'd545:
						if (stk_depth <= ur_target) begin
							if (sp >= sv2v_cast_7_signed(14)) begin
								rf_resume <= 10'd545;
								st <= 10'd563;
							end
							else begin
								rf[rf_base[3:0] + sv2v_cast_4(sp)] <= ur_val;
								rf[rf_base[3:0] + sv2v_cast_4(sp + 7'd1)] <= vint(32'hffffffff);
								sp <= sp + 7'd2;
								st <= 10'd147;
							end
						end
						else if (has_link && (sp <= 7'd1)) begin
							rf_resume <= 10'd545;
							st <= 10'd566;
						end
						else if (sp != 7'd0)
							sp <= sp - 7'd1;
						else
							st <= 10'd147;
					default:
						halt(ABI_HALT_INTERNAL, 32'hdead0000 | sv2v_cast_32(st));
				endcase
		end
	end
	initial _sv2v_0 = 0;
endmodule
module mpy_gc (
	clk_i,
	rst_n_i,
	pool_bytes_i,
	alloc_req_i,
	alloc_nbytes_i,
	alloc_done_o,
	alloc_ok_o,
	alloc_addr_o,
	collect_req_i,
	root0_lo_i,
	root0_hi_i,
	root1_lo_i,
	root1_hi_i,
	collect_done_o,
	busy_o,
	free_blocks_o,
	total_blocks_o,
	collections_o,
	overflows_o,
	mem_req_o,
	mem_we_o,
	mem_tag_we_o,
	mem_addr_o,
	mem_wdata_o,
	mem_wtag_o,
	mem_gnt_i,
	mem_ack_i,
	mem_rdata_i,
	mem_rtag_i
);
	reg _sv2v_0;
	localparam [31:0] MPY_FRAME_RESERVE_BYTES = 32'h00008000;
	localparam [31:0] MPY_SRAM_BASE = 32'h20000000;
	localparam [31:0] MPY_SCHED_BASE = MPY_SRAM_BASE + MPY_FRAME_RESERVE_BYTES;
	localparam [31:0] MPY_SCHED_BYTES = 32'h00000040;
	localparam [31:0] MPY_HANDLER_BASE = MPY_SCHED_BASE + MPY_SCHED_BYTES;
	localparam [31:0] MPY_HANDLER_BYTES = 32'h00000040;
	localparam [31:0] MPY_SYSROOT_BASE = MPY_HANDLER_BASE + MPY_HANDLER_BYTES;
	localparam [31:0] MPY_ARGBUF_BASE = MPY_SYSROOT_BASE + 32'h00000080;
	localparam [31:0] MPY_GC_POOL_BASE = MPY_ARGBUF_BASE + 32'h00000400;
	parameter [31:0] POOL_BASE = MPY_GC_POOL_BASE;
	localparam signed [31:0] ABI_GC_TABLE_BYTES = 307200;
	parameter signed [31:0] POOL_BYTES = ABI_GC_TABLE_BYTES;
	parameter signed [31:0] STACK_DEPTH = 64;
	input wire clk_i;
	input wire rst_n_i;
	input wire [31:0] pool_bytes_i;
	input wire alloc_req_i;
	input wire [31:0] alloc_nbytes_i;
	output reg alloc_done_o;
	output reg alloc_ok_o;
	output reg [31:0] alloc_addr_o;
	input wire collect_req_i;
	input wire [31:0] root0_lo_i;
	input wire [31:0] root0_hi_i;
	input wire [31:0] root1_lo_i;
	input wire [31:0] root1_hi_i;
	output reg collect_done_o;
	output wire busy_o;
	output wire [31:0] free_blocks_o;
	output wire [31:0] total_blocks_o;
	output wire [31:0] collections_o;
	output wire [31:0] overflows_o;
	output reg mem_req_o;
	output reg mem_we_o;
	output reg mem_tag_we_o;
	output reg [31:0] mem_addr_o;
	output reg [31:0] mem_wdata_o;
	output reg [3:0] mem_wtag_o;
	input wire mem_gnt_i;
	input wire mem_ack_i;
	input wire [31:0] mem_rdata_i;
	input wire [3:0] mem_rtag_i;
	localparam signed [31:0] NB = POOL_BYTES / 16;
	localparam signed [31:0] BW = $clog2(NB + 1);
	reg [BW - 1:0] active_blocks;
	reg [31:0] active_bytes;
	reg active_v;
	function automatic [BW - 1:0] sv2v_cast_F35F2;
		input reg [BW - 1:0] inp;
		sv2v_cast_F35F2 = inp;
	endfunction
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			active_blocks <= 1'sb0;
			active_bytes <= 1'sb0;
			active_v <= 1'b0;
		end
		else begin
			active_v <= 1'b1;
			active_blocks <= sv2v_cast_F35F2((pool_bytes_i > POOL_BYTES ? POOL_BYTES : pool_bytes_i) >> 4);
			active_bytes <= sv2v_cast_32(sv2v_cast_F35F2((pool_bytes_i > POOL_BYTES ? POOL_BYTES : pool_bytes_i) >> 4)) << 4;
		end
	localparam signed [31:0] SW = $clog2(STACK_DEPTH + 1);
	localparam signed [31:0] SI = $clog2(STACK_DEPTH);
	localparam [1:0] A_FREE = 2'd0;
	localparam [1:0] A_HEAD = 2'd1;
	localparam [1:0] A_TAIL = 2'd2;
	localparam [1:0] A_MARK = 2'd3;
	reg [4:0] st;
	reg [BW - 1:0] stk [0:STACK_DEPTH - 1];
	reg [SW - 1:0] ssp;
	reg ovf;
	reg [BW - 1:0] rover;
	reg [BW - 1:0] idx;
	reg [BW - 1:0] run_start;
	reg [BW - 1:0] run_len;
	reg [BW - 1:0] need;
	reg [BW - 1:0] scanned;
	reg [31:0] zaddr;
	reg [31:0] zend;
	reg zwait;
	reg [2:0] zout;
	reg [31:0] raddr;
	reg [31:0] rhi;
	reg rsel;
	reg [31:0] lnk_addr;
	reg [31:0] lnk_next;
	reg [3:0] lnk_tags [0:47];
	reg [7:0] lnk_n;
	reg [5:0] lnk_i;
	reg [2:0] lnk_ntag;
	reg [2:0] lnk_tw;
	reg [7:0] lnk_hops;
	reg lnk_follow;
	reg [BW - 1:0] oblk;
	reg [1:0] oword;
	reg rescanning;
	reg freeing;
	reg [31:0] free_cnt;
	reg [31:0] ncoll;
	reg [31:0] novf;
	reg cand_ptr;
	reg [31:0] cand_addr;
	reg [31:0] cand_off;
	reg [BW - 1:0] cand_blk;
	localparam [3:0] MPY_TAG_BYTES = 4'b1101;
	localparam [3:0] MPY_TAG_COMPLEX = 4'b0100;
	localparam [3:0] MPY_TAG_CONT = 4'b1111;
	localparam [3:0] MPY_TAG_INT64 = 4'b0010;
	localparam [3:0] MPY_TAG_ITER = 4'b1100;
	localparam [3:0] MPY_TAG_MUT_COLLEC = 4'b1010;
	localparam [3:0] MPY_TAG_OBJECT = 4'b1110;
	localparam [3:0] MPY_TAG_RANGE = 4'b1011;
	localparam [3:0] MPY_TAG_STR = 4'b1000;
	localparam [3:0] MPY_TAG_TUPLE = 4'b1001;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (mem_rtag_i)
			MPY_TAG_INT64, MPY_TAG_COMPLEX, MPY_TAG_STR, MPY_TAG_TUPLE, MPY_TAG_MUT_COLLEC, MPY_TAG_RANGE, MPY_TAG_ITER, MPY_TAG_BYTES, MPY_TAG_OBJECT, MPY_TAG_CONT: cand_ptr = 1'b1;
			default: cand_ptr = 1'b0;
		endcase
		cand_addr = {mem_rdata_i[31:2], 2'b00};
		cand_off = cand_addr - POOL_BASE;
		cand_blk = sv2v_cast_F35F2(cand_off >> 4);
		if ((cand_addr < POOL_BASE) || (cand_off >= active_bytes))
			cand_ptr = 1'b0;
	end
	wire [BW - 1:0] run_first;
	assign run_first = (run_len == {BW {1'sb0}} ? idx : run_start);
	localparam signed [31:0] NW = (NB + 31) / 32;
	localparam signed [31:0] WW = (NW > 1 ? $clog2(NW) : 1);
	function automatic [WW - 1:0] sv2v_cast_93667;
		input reg [WW - 1:0] inp;
		sv2v_cast_93667 = inp;
	endfunction
	function automatic [WW - 1:0] word_of;
		input reg [BW - 1:0] b;
		word_of = sv2v_cast_93667(sv2v_cast_32(b) >> 5);
	endfunction
	function automatic [4:0] sv2v_cast_5;
		input reg [4:0] inp;
		sv2v_cast_5 = inp;
	endfunction
	function automatic [4:0] slot_of;
		input reg [BW - 1:0] b;
		slot_of = sv2v_cast_5(sv2v_cast_32(b));
	endfunction
	function automatic [63:0] slot_mask;
		input reg [BW - 1:0] b;
		slot_mask = 64'd3 << {slot_of(b), 1'b0};
	endfunction
	function automatic [1:0] ent_of;
		input reg [63:0] w;
		input reg [BW - 1:0] b;
		ent_of = w[{slot_of(b), 1'b0}+:2];
	endfunction
	reg p_v;
	reg p_w;
	reg [WW - 1:0] p_addr;
	reg [63:0] p_data;
	reg [63:0] p_mask;
	wire [63:0] q;
	bsg_mem_1rw_sync_mask_write_bit #(
		.width_p(64),
		.els_p(NW)
	) u_atb(
		.clk_i(clk_i),
		.reset_i(!rst_n_i),
		.data_i(p_data),
		.addr_i(p_addr),
		.v_i(p_v),
		.w_mask_i(p_mask),
		.w_i(p_w),
		.data_o(q)
	);
	reg mk_v;
	reg mk_chk;
	reg mk_wr;
	wire mk_stall;
	wire mk_busy;
	reg [BW - 1:0] mk_blk;
	reg [BW - 1:0] mk_cb;
	reg [BW - 1:0] mk_wb;
	assign mk_stall = mk_wr;
	assign mk_busy = (mk_v | mk_chk) | mk_wr;
	reg [63:0] wb;
	reg [63:0] wbk;
	reg [WW - 1:0] wb_w;
	reg [WW - 1:0] ld_w;
	reg [WW - 1:0] wbk_w;
	reg wb_v;
	reg wb_dirty;
	reg ld_pend;
	reg wbk_v;
	wire cur_hit;
	wire [1:0] cur;
	assign cur_hit = wb_v && (wb_w == word_of(idx));
	assign cur = ent_of(wb, idx);
	reg tl_have;
	reg tl_tail;
	reg tl_rd;
	wire [BW - 1:0] onext;
	assign onext = oblk + 1'b1;
	wire scan_fail;
	assign scan_fail = (need > active_blocks) || (scanned == active_blocks);
	reg f_v;
	reg f_w;
	reg [WW - 1:0] f_addr;
	reg [63:0] f_data;
	reg [63:0] f_mask;
	always @(*) begin
		if (_sv2v_0)
			;
		f_v = 1'b0;
		f_w = 1'b0;
		f_addr = word_of(idx);
		f_data = 1'sb0;
		f_mask = 1'sb1;
		(* full_case, parallel_case *)
		case (st)
			5'd0: begin
				f_v = 1'b1;
				f_w = 1'b1;
				f_addr = sv2v_cast_93667(sv2v_cast_32(idx));
			end
			5'd2: f_v = (!scan_fail && !cur_hit) && !ld_pend;
			5'd10: f_v = ((idx != active_blocks) && !cur_hit) && !ld_pend;
			5'd11:
				if (((idx != active_blocks) && !cur_hit) && !ld_pend)
					f_v = 1'b1;
				else if (ld_pend && wbk_v) begin
					f_v = 1'b1;
					f_w = 1'b1;
					f_addr = wbk_w;
					f_data = wbk;
				end
				else if (((idx == active_blocks) && wb_v) && wb_dirty) begin
					f_v = 1'b1;
					f_w = 1'b1;
					f_addr = wb_w;
					f_data = wb;
				end
			5'd3: begin
				f_v = 1'b1;
				f_w = 1'b1;
				f_mask = slot_mask(idx);
				f_data = {32 {(idx == run_start ? A_HEAD : A_TAIL)}};
			end
			5'd8, 5'd17: begin
				f_v = ((!tl_have && !tl_rd) && !mk_busy) && (onext < active_blocks);
				f_addr = word_of(onext);
			end
			default:
				;
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		p_v = f_v;
		p_w = f_w;
		p_addr = f_addr;
		p_data = f_data;
		p_mask = f_mask;
		if (mk_wr) begin
			p_v = 1'b1;
			p_w = 1'b1;
			p_addr = word_of(mk_wb);
			p_data = {32 {A_MARK}};
			p_mask = slot_mask(mk_wb);
		end
		else if (mk_v) begin
			p_v = 1'b1;
			p_w = 1'b0;
			p_addr = word_of(mk_blk);
		end
	end
	assign busy_o = st != 5'd1;
	assign free_blocks_o = free_cnt;
	assign total_blocks_o = sv2v_cast_32(active_blocks);
	assign collections_o = ncoll;
	assign overflows_o = novf;
	task automatic try_mark;
		input reg [BW - 1:0] b;
		begin
			mk_v <= 1'b1;
			mk_blk <= b;
		end
	endtask
	task automatic mem_read;
		input reg [31:0] a;
		begin
			mem_req_o <= 1'b1;
			mem_we_o <= 1'b0;
			mem_tag_we_o <= 1'b0;
			mem_addr_o <= a;
		end
	endtask
	localparam [3:0] MPY_CTL_RF_LINK = 4'd6;
	localparam signed [31:0] MPY_RF_CHUNK_MAX = 8;
	localparam signed [31:0] MPY_RF_CHUNK_MIN = 4;
	localparam [3:0] MPY_TAG_CONTROL = 4'b0000;
	function automatic [31:0] mpy_rf_block_bytes;
		input reg [5:0] n;
		reg [31:0] ntag;
		reg [31:0] raw;
		begin
			ntag = sv2v_cast_32((n + 6'd7) >> 3);
			raw = (32'd4 + (ntag << 2)) + (sv2v_cast_32(n) << 2);
			mpy_rf_block_bytes = (raw + 32'd15) & 32'hfffffff0;
		end
	endfunction
	function automatic [7:0] mpy_rf_chunk_count;
		input reg [3:0] tag;
		input reg [31:0] word;
		mpy_rf_chunk_count = {tag, word[3:0]};
	endfunction
	function automatic [31:0] mpy_rf_chunk_prev;
		input reg [31:0] word;
		mpy_rf_chunk_prev = {word[31:4], 4'b0000};
	endfunction
	localparam signed [31:0] MPY_TAG_WIDTH = 4;
	function automatic mpy_tag_is_pointer;
		input reg [3:0] tag;
		case (tag)
			MPY_TAG_STR, MPY_TAG_TUPLE, MPY_TAG_MUT_COLLEC, MPY_TAG_RANGE, MPY_TAG_ITER, MPY_TAG_BYTES, MPY_TAG_OBJECT: mpy_tag_is_pointer = 1'b1;
			default: mpy_tag_is_pointer = 1'b0;
		endcase
	endfunction
	function automatic signed [SW - 1:0] sv2v_cast_6C2E3_signed;
		input reg signed [SW - 1:0] inp;
		sv2v_cast_6C2E3_signed = inp;
	endfunction
	function automatic [SI - 1:0] sv2v_cast_B49BD;
		input reg [SI - 1:0] inp;
		sv2v_cast_B49BD = inp;
	endfunction
	function automatic signed [BW - 1:0] sv2v_cast_F35F2_signed;
		input reg signed [BW - 1:0] inp;
		sv2v_cast_F35F2_signed = inp;
	endfunction
	function automatic [2:0] sv2v_cast_3;
		input reg [2:0] inp;
		sv2v_cast_3 = inp;
	endfunction
	function automatic signed [7:0] sv2v_cast_8_signed;
		input reg signed [7:0] inp;
		sv2v_cast_8_signed = inp;
	endfunction
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			st <= 5'd0;
			ssp <= 1'sb0;
			ovf <= 1'b0;
			rover <= 1'sb0;
			idx <= 1'sb0;
			run_start <= 1'sb0;
			run_len <= 1'sb0;
			need <= 1'sb0;
			scanned <= 1'sb0;
			zaddr <= 1'sb0;
			zwait <= 1'b0;
			zout <= 1'sb0;
			zend <= 1'sb0;
			raddr <= 1'sb0;
			rhi <= 1'sb0;
			rsel <= 1'b0;
			oblk <= 1'sb0;
			oword <= 1'sb0;
			rescanning <= 1'b0;
			freeing <= 1'b0;
			free_cnt <= 1'sb0;
			ncoll <= 1'sb0;
			novf <= 1'sb0;
			alloc_done_o <= 1'b0;
			alloc_ok_o <= 1'b0;
			alloc_addr_o <= 1'sb0;
			collect_done_o <= 1'b0;
			mem_req_o <= 1'b0;
			mem_we_o <= 1'b0;
			mem_tag_we_o <= 1'b0;
			mem_addr_o <= 1'sb0;
			mem_wdata_o <= 1'sb0;
			mem_wtag_o <= 1'sb0;
			mk_v <= 1'b0;
			mk_chk <= 1'b0;
			mk_wr <= 1'b0;
			mk_blk <= 1'sb0;
			mk_cb <= 1'sb0;
			mk_wb <= 1'sb0;
			wb <= 1'sb0;
			wb_w <= 1'sb0;
			wb_v <= 1'b0;
			wb_dirty <= 1'b0;
			ld_pend <= 1'b0;
			ld_w <= 1'sb0;
			wbk <= 1'sb0;
			wbk_w <= 1'sb0;
			wbk_v <= 1'b0;
			tl_have <= 1'b0;
			tl_tail <= 1'b0;
			tl_rd <= 1'b0;
		end
		else begin
			alloc_done_o <= 1'b0;
			collect_done_o <= 1'b0;
			mem_req_o <= 1'b0;
			if (mk_v && !mk_stall)
				mk_v <= 1'b0;
			mk_chk <= mk_v && !mk_stall;
			if (mk_v && !mk_stall)
				mk_cb <= mk_blk;
			mk_wr <= 1'b0;
			if (mk_chk && (ent_of(q, mk_cb) == A_HEAD)) begin
				mk_wr <= 1'b1;
				mk_wb <= mk_cb;
				if (ssp < sv2v_cast_6C2E3_signed(STACK_DEPTH)) begin
					stk[sv2v_cast_B49BD(ssp)] <= mk_cb;
					ssp <= ssp + 1'b1;
				end
				else begin
					ovf <= 1'b1;
					novf <= novf + 32'd1;
				end
			end
			ld_pend <= ((f_v && !f_w) && (st != 5'd8)) && (st != 5'd17);
			if (((f_v && !f_w) && (st != 5'd8)) && (st != 5'd17))
				ld_w <= f_addr;
			if (ld_pend) begin
				wb <= q;
				wb_w <= ld_w;
				wb_v <= 1'b1;
			end
			else if (((p_v && p_w) && wb_v) && (p_addr == wb_w))
				wb <= (wb & ~p_mask) | (p_data & p_mask);
			tl_rd <= f_v && ((st == 5'd8) || (st == 5'd17));
			if (tl_rd) begin
				tl_tail <= ent_of(q, onext) == A_TAIL;
				tl_have <= 1'b1;
			end
			(* full_case, parallel_case *)
			case (st)
				5'd0: begin
					idx <= idx + 1'b1;
					if (idx == sv2v_cast_F35F2_signed(NW - 1)) begin
						if (active_v) begin
							idx <= 1'sb0;
							free_cnt <= sv2v_cast_32(active_blocks);
							st <= 5'd1;
						end
						else
							idx <= idx;
					end
				end
				5'd1:
					if (alloc_req_i) begin
						if ((active_blocks == 0) || (alloc_nbytes_i > active_bytes)) begin
							alloc_done_o <= 1'b1;
							alloc_ok_o <= 1'b0;
						end
						else begin
							need <= (alloc_nbytes_i == 32'd0 ? sv2v_cast_F35F2_signed(1) : sv2v_cast_F35F2(({1'b0, alloc_nbytes_i} + 33'd15) >> 4));
							idx <= rover;
							run_len <= 1'sb0;
							scanned <= 1'sb0;
							st <= 5'd2;
						end
					end
					else if (collect_req_i) begin
						raddr <= root0_lo_i;
						rhi <= root0_hi_i;
						rsel <= 1'b0;
						ssp <= 1'sb0;
						ovf <= 1'b0;
						st <= 5'd5;
					end
				5'd2:
					if ((need > active_blocks) || (scanned == active_blocks)) begin
						alloc_done_o <= 1'b1;
						alloc_ok_o <= 1'b0;
						st <= 5'd1;
					end
					else if (cur_hit) begin
						scanned <= scanned + 1'b1;
						if ((cur == A_FREE) && ((run_len + 1'b1) == need)) begin
							run_start <= run_first;
							st <= 5'd3;
						end
						else begin
							if (cur == A_FREE) begin
								run_start <= run_first;
								run_len <= run_len + 1'b1;
							end
							else
								run_len <= 1'sb0;
							if (idx == (active_blocks - 1'b1)) begin
								idx <= 1'sb0;
								run_len <= 1'sb0;
							end
							else
								idx <= idx + 1'b1;
						end
					end
				5'd3:
					if (idx == run_start) begin
						zaddr <= POOL_BASE + {run_start, 4'b0000};
						zend <= (POOL_BASE + {run_start, 4'b0000}) + {need, 4'b0000};
						free_cnt <= free_cnt - sv2v_cast_32(need);
						rover <= ((run_start + need) >= active_blocks ? {BW {1'sb0}} : run_start + need);
						st <= 5'd4;
					end
					else
						idx <= idx - 1'b1;
				5'd4: begin : sv2v_autoblock_1
					reg issue;
					reg [2:0] zout_n;
					issue = (zaddr != zend) && (!zwait || mem_gnt_i);
					zout_n = (zout + (issue ? 3'd1 : 3'd0)) - (mem_ack_i ? 3'd1 : 3'd0);
					zout <= zout_n;
					if (issue) begin
						mem_req_o <= 1'b1;
						mem_we_o <= 1'b1;
						mem_tag_we_o <= 1'b1;
						mem_addr_o <= zaddr;
						mem_wdata_o <= 1'sb0;
						mem_wtag_o <= 1'sb0;
						zaddr <= zaddr + 32'd4;
						zwait <= 1'b1;
					end
					else if (mem_gnt_i)
						zwait <= 1'b0;
					if (((zaddr == zend) && (!zwait || mem_gnt_i)) && (zout_n == 3'd0)) begin
						alloc_done_o <= 1'b1;
						alloc_ok_o <= 1'b1;
						alloc_addr_o <= POOL_BASE + {run_start, 4'b0000};
						zwait <= 1'b0;
						st <= 5'd1;
					end
				end
				5'd5:
					if (raddr >= rhi) begin
						if (!rsel) begin
							raddr <= root1_lo_i;
							rhi <= root1_hi_i;
							rsel <= 1'b1;
						end
						else begin
							rescanning <= 1'b0;
							st <= 5'd7;
						end
					end
					else begin
						mem_read(raddr);
						st <= 5'd6;
					end
				5'd6:
					if (mem_ack_i) begin
						if ((((mem_rtag_i == MPY_TAG_CONTROL) && (mem_rdata_i[3:0] == MPY_CTL_RF_LINK)) && ({mem_rdata_i[31:4], 4'b0000} >= MPY_SRAM_BASE)) && (({mem_rdata_i[31:4], 4'b0000} + 32'd4) <= (MPY_SRAM_BASE + MPY_FRAME_RESERVE_BYTES))) begin
							lnk_addr <= {mem_rdata_i[31:4], 4'b0000};
							lnk_hops <= 8'd0;
							raddr <= raddr + 32'd4;
							st <= 5'd12;
						end
						else begin
							if (cand_ptr)
								try_mark(cand_blk);
							raddr <= raddr + 32'd4;
							st <= 5'd5;
						end
					end
				5'd12: begin
					lnk_follow <= 1'b0;
					mem_read(lnk_addr);
					st <= 5'd13;
				end
				5'd13:
					if (mem_ack_i) begin
						lnk_n <= mpy_rf_chunk_count(mem_rtag_i, mem_rdata_i);
						if ((mpy_rf_chunk_prev(mem_rdata_i) != 32'd0) && (lnk_hops != 8'd64)) begin
							lnk_next <= mpy_rf_chunk_prev(mem_rdata_i);
							lnk_follow <= 1'b1;
						end
						lnk_ntag <= sv2v_cast_3((mpy_rf_chunk_count(mem_rtag_i, mem_rdata_i) + 8'd7) >> 3);
						lnk_tw <= 3'd0;
						if (((mpy_rf_chunk_count(mem_rtag_i, mem_rdata_i) < sv2v_cast_8_signed(MPY_RF_CHUNK_MIN)) || (mpy_rf_chunk_count(mem_rtag_i, mem_rdata_i) > sv2v_cast_8_signed(MPY_RF_CHUNK_MAX))) || ((lnk_addr + mpy_rf_block_bytes(sv2v_cast_6(mpy_rf_chunk_count(mem_rtag_i, mem_rdata_i)))) > (MPY_SRAM_BASE + MPY_FRAME_RESERVE_BYTES)))
							st <= 5'd5;
						else begin
							mem_read(lnk_addr + 32'd4);
							st <= 5'd14;
						end
					end
				5'd14:
					if (mem_ack_i) begin
						begin : sv2v_autoblock_2
							reg signed [31:0] k;
							for (k = 0; k < 8; k = k + 1)
								lnk_tags[(8 * lnk_tw) + k] <= mem_rdata_i[4 * k+:4];
						end
						if ((lnk_tw + 3'd1) < lnk_ntag) begin
							lnk_tw <= lnk_tw + 3'd1;
							mem_read((lnk_addr + 32'd8) + ({29'd0, lnk_tw} << 2));
							st <= 5'd14;
						end
						else begin
							lnk_i <= 6'd0;
							mem_read((lnk_addr + 32'd4) + ({29'd0, lnk_ntag} << 2));
							st <= 5'd16;
						end
					end
				5'd15: st <= 5'd5;
				5'd16:
					if (mem_ack_i) begin
						if (mpy_tag_is_pointer(lnk_tags[lnk_i])) begin
							if (lnk_tags[lnk_i] == MPY_TAG_MUT_COLLEC) begin
								if (({mem_rdata_i[31:2], 2'b00} >= POOL_BASE) && (({mem_rdata_i[31:2], 2'b00} - POOL_BASE) < active_bytes))
									try_mark(sv2v_cast_F35F2(({mem_rdata_i[31:2], 2'b00} - POOL_BASE) >> 4));
							end
							else if ((mem_rdata_i >= POOL_BASE) && ((mem_rdata_i - POOL_BASE) < active_bytes))
								try_mark(sv2v_cast_F35F2((mem_rdata_i - POOL_BASE) >> 4));
						end
						if (({2'b00, lnk_i} + 8'd1) == lnk_n) begin
							if (lnk_follow && (lnk_hops != 8'd64)) begin
								lnk_addr <= lnk_next;
								lnk_hops <= lnk_hops + 8'd1;
								st <= 5'd12;
							end
							else
								st <= 5'd5;
						end
						else begin
							lnk_i <= lnk_i + 6'd1;
							mem_read(((lnk_addr + 32'd8) + ({29'd0, lnk_ntag} << 2)) + ({26'd0, lnk_i} << 2));
							st <= 5'd16;
						end
					end
				5'd7:
					if (!mk_busy) begin
						if (ssp != {SW {1'sb0}}) begin
							oblk <= stk[sv2v_cast_B49BD(ssp - 1'b1)];
							oword <= 1'sb0;
							tl_have <= 1'b0;
							ssp <= ssp - 1'b1;
							st <= 5'd8;
						end
						else if (rescanning) begin
							idx <= idx + 1'b1;
							st <= 5'd10;
						end
						else if (ovf) begin
							ovf <= 1'b0;
							rescanning <= 1'b1;
							idx <= 1'sb0;
							st <= 5'd10;
						end
						else begin
							idx <= 1'sb0;
							freeing <= 1'b0;
							st <= 5'd11;
						end
					end
				5'd8: begin
					mem_read((POOL_BASE + {oblk, 4'b0000}) + {28'b0000000000000000000000000000, oword, 2'b00});
					st <= 5'd9;
				end
				5'd9:
					if (mem_ack_i) begin
						if (cand_ptr)
							try_mark(cand_blk);
						if (oword != 2'd3) begin
							oword <= oword + 1'b1;
							st <= 5'd8;
						end
						else if (onext >= active_blocks)
							st <= 5'd7;
						else if (!tl_have)
							st <= 5'd17;
						else if (tl_tail) begin
							oblk <= onext;
							oword <= 1'sb0;
							tl_have <= 1'b0;
							st <= 5'd8;
						end
						else
							st <= 5'd7;
					end
				5'd17:
					if (tl_have) begin
						if (tl_tail) begin
							oblk <= onext;
							oword <= 1'sb0;
							tl_have <= 1'b0;
							st <= 5'd8;
						end
						else
							st <= 5'd7;
					end
				5'd10:
					if (idx == active_blocks) begin
						if (ovf) begin
							ovf <= 1'b0;
							idx <= 1'sb0;
						end
						else begin
							rescanning <= 1'b0;
							idx <= 1'sb0;
							freeing <= 1'b0;
							st <= 5'd11;
						end
					end
					else if (!cur_hit)
						;
					else if (cur == A_MARK) begin
						oblk <= idx;
						oword <= 1'sb0;
						tl_have <= 1'b0;
						st <= 5'd8;
					end
					else
						idx <= idx + 1'b1;
				5'd11: begin
					if (ld_pend)
						wbk_v <= 1'b0;
					if (idx == active_blocks) begin
						if (wb_v && wb_dirty)
							wb_dirty <= 1'b0;
						else
							st <= 5'd18;
					end
					else if (!cur_hit) begin
						if ((!ld_pend && wb_v) && wb_dirty) begin
							wbk <= wb;
							wbk_w <= wb_w;
							wbk_v <= 1'b1;
							wb_dirty <= 1'b0;
						end
					end
					else begin
						(* full_case, parallel_case *)
						case (cur)
							A_HEAD: begin
								wb[{slot_of(idx), 1'b0}+:2] <= A_FREE;
								wb_dirty <= 1'b1;
								freeing <= 1'b1;
								free_cnt <= free_cnt + 32'd1;
							end
							A_TAIL:
								if (freeing) begin
									wb[{slot_of(idx), 1'b0}+:2] <= A_FREE;
									wb_dirty <= 1'b1;
									free_cnt <= free_cnt + 32'd1;
								end
							A_MARK: begin
								wb[{slot_of(idx), 1'b0}+:2] <= A_HEAD;
								wb_dirty <= 1'b1;
								freeing <= 1'b0;
							end
							default: freeing <= 1'b0;
						endcase
						idx <= idx + 1'b1;
					end
				end
				5'd18: begin
					collect_done_o <= 1'b1;
					ncoll <= ncoll + 32'd1;
					rover <= 1'sb0;
					st <= 5'd1;
				end
				default: st <= 5'd1;
			endcase
		end
	initial _sv2v_0 = 0;
endmodule
module mpy_ca (
	clk_i,
	rst_n_i,
	cmd_valid_i,
	cmd_ready_o,
	cmd_dst_i,
	cmd_src_i,
	cmd_n_i,
	idle_o,
	chk_addr_i,
	chk_we_i,
	chk_busy_o,
	req_o,
	we_o,
	addr_o,
	wdata_o,
	wtag_o,
	gnt_i,
	ack_i,
	fault_i,
	fault_reason_i,
	rdata_i,
	rtag_i,
	fault_o,
	fault_reason_o,
	fault_addr_o,
	words_o,
	cmds_o
);
	reg _sv2v_0;
	parameter signed [31:0] QDEPTH = 2;
	parameter signed [31:0] BUF = 4;
	input wire clk_i;
	input wire rst_n_i;
	input wire cmd_valid_i;
	output wire cmd_ready_o;
	input wire [31:0] cmd_dst_i;
	input wire [31:0] cmd_src_i;
	input wire [31:0] cmd_n_i;
	output wire idle_o;
	input wire [31:0] chk_addr_i;
	input wire chk_we_i;
	output reg chk_busy_o;
	output wire req_o;
	output wire we_o;
	output wire [31:0] addr_o;
	output wire [31:0] wdata_o;
	output wire [3:0] wtag_o;
	input wire gnt_i;
	input wire ack_i;
	input wire fault_i;
	input wire [3:0] fault_reason_i;
	input wire [31:0] rdata_i;
	input wire [3:0] rtag_i;
	output reg fault_o;
	output reg [3:0] fault_reason_o;
	output reg [31:0] fault_addr_o;
	output reg [31:0] words_o;
	output reg [31:0] cmds_o;
	localparam signed [31:0] QW = (QDEPTH > 1 ? $clog2(QDEPTH) : 1);
	localparam signed [31:0] BW = (BUF > 1 ? $clog2(BUF) : 1);
	localparam signed [31:0] IFD = 2;
	reg qv [0:QDEPTH - 1];
	reg back [0:QDEPTH - 1];
	reg [31:0] dlo [0:QDEPTH - 1];
	reg [31:0] dhi [0:QDEPTH - 1];
	reg [31:0] slo [0:QDEPTH - 1];
	reg [31:0] shi [0:QDEPTH - 1];
	reg [QW - 1:0] head;
	reg [QW:0] cnt;
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	function automatic [QW - 1:0] nxt;
		input reg [QW - 1:0] i;
		nxt = (sv2v_cast_32(i) == (QDEPTH - 1) ? {QW {1'sb0}} : i + 1'b1);
	endfunction
	reg [QW - 1:0] tail;
	function automatic [QW - 1:0] sv2v_cast_0D861;
		input reg [QW - 1:0] inp;
		sv2v_cast_0D861 = inp;
	endfunction
	always @(*) begin : sv2v_autoblock_1
		reg [QW:0] s;
		if (_sv2v_0)
			;
		s = {1'b0, head} + cnt;
		tail = (sv2v_cast_32(s) >= QDEPTH ? sv2v_cast_0D861(sv2v_cast_32(s) - QDEPTH) : s[QW - 1:0]);
	end
	reg act;
	reg eb;
	reg [31:0] ra;
	reg [31:0] wa;
	reg [31:0] rn;
	reg [31:0] wn;
	wire [31:0] step;
	assign step = (eb ? 32'hfffffffc : 32'd4);
	reg [35:0] fb [0:BUF - 1];
	reg [BW - 1:0] fb_rp;
	reg [BW - 1:0] fb_wp;
	reg [BW:0] fc;
	reg [BW:0] rpend;
	reg if_we [0:1];
	reg [31:0] if_addr [0:1];
	reg [1:0] if_n;
	reg rq_v;
	reg rq_we;
	reg [31:0] rq_a;
	reg [31:0] rq_d;
	reg [3:0] rq_t;
	assign req_o = rq_v;
	assign we_o = rq_we;
	assign addr_o = rq_a;
	assign wdata_o = rq_d;
	assign wtag_o = rq_t;
	wire take;
	wire ld_ok;
	wire ld_wr;
	wire ld_rd;
	wire last_wr;
	wire rd_ack;
	wire wr_ack;
	wire flt;
	wire push;
	wire pop;
	assign take = rq_v && gnt_i;
	assign ld_ok = !rq_v || gnt_i;
	assign ld_wr = ((ld_ok && act) && (wn != 32'd0)) && (fc != {(BW >= 0 ? BW + 1 : 1 - BW) {1'sb0}});
	assign ld_rd = (((ld_ok && act) && !ld_wr) && (rn != 32'd0)) && ((sv2v_cast_32(rpend) + sv2v_cast_32(fc)) < BUF);
	assign last_wr = (take && rq_we) && (wn == 32'd0);
	assign flt = (ack_i && fault_i) && !fault_o;
	assign rd_ack = ((ack_i && !fault_i) && !fault_o) && !if_we[0];
	assign wr_ack = ((ack_i && !fault_i) && !fault_o) && if_we[0];
	assign push = (((cmd_valid_i && cmd_ready_o) && (cmd_n_i != 32'd0)) && !fault_o) && !flt;
	assign pop = last_wr && !flt;
	assign cmd_ready_o = sv2v_cast_32(cnt) < QDEPTH;
	assign idle_o = ((cnt == {(QW >= 0 ? QW + 1 : 1 - QW) {1'sb0}}) && (if_n == {2 {1'sb0}})) && !rq_v;
	always @(*) begin
		if (_sv2v_0)
			;
		chk_busy_o = 1'b0;
		begin : sv2v_autoblock_2
			reg signed [31:0] k;
			for (k = 0; k < QDEPTH; k = k + 1)
				begin
					if ((qv[k] && (chk_addr_i >= dlo[k])) && (chk_addr_i < dhi[k]))
						chk_busy_o = 1'b1;
					if (((qv[k] && chk_we_i) && (chk_addr_i >= slo[k])) && (chk_addr_i < shi[k]))
						chk_busy_o = 1'b1;
				end
		end
	end
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			head <= 1'sb0;
			cnt <= 1'sb0;
			begin : sv2v_autoblock_3
				reg signed [31:0] k;
				for (k = 0; k < QDEPTH; k = k + 1)
					begin
						qv[k] <= 1'b0;
						back[k] <= 1'b0;
						dlo[k] <= 1'sb0;
						dhi[k] <= 1'sb0;
						slo[k] <= 1'sb0;
						shi[k] <= 1'sb0;
					end
			end
			act <= 1'b0;
			eb <= 1'b0;
			ra <= 1'sb0;
			wa <= 1'sb0;
			rn <= 1'sb0;
			wn <= 1'sb0;
			begin : sv2v_autoblock_4
				reg signed [31:0] k;
				for (k = 0; k < BUF; k = k + 1)
					fb[k] <= 1'sb0;
			end
			fb_rp <= 1'sb0;
			fb_wp <= 1'sb0;
			fc <= 1'sb0;
			rpend <= 1'sb0;
			begin : sv2v_autoblock_5
				reg signed [31:0] k;
				for (k = 0; k < IFD; k = k + 1)
					begin
						if_we[k] <= 1'b0;
						if_addr[k] <= 1'sb0;
					end
			end
			if_n <= 1'sb0;
			rq_v <= 1'b0;
			rq_we <= 1'b0;
			rq_a <= 1'sb0;
			rq_d <= 1'sb0;
			rq_t <= 1'sb0;
			fault_o <= 1'b0;
			fault_reason_o <= 1'sb0;
			fault_addr_o <= 1'sb0;
			words_o <= 1'sb0;
			cmds_o <= 1'sb0;
		end
		else begin
			if (push) begin
				qv[tail] <= 1'b1;
				back[tail] <= cmd_dst_i > cmd_src_i;
				dlo[tail] <= cmd_dst_i;
				dhi[tail] <= cmd_dst_i + (cmd_n_i << 2);
				slo[tail] <= cmd_src_i;
				shi[tail] <= cmd_src_i + (cmd_n_i << 2);
			end
			if ((!act && (cnt != {(QW >= 0 ? QW + 1 : 1 - QW) {1'sb0}})) && !fault_o) begin
				act <= 1'b1;
				eb <= back[head];
				ra <= (back[head] ? shi[head] - 32'd4 : slo[head]);
				wa <= (back[head] ? dhi[head] - 32'd4 : dlo[head]);
				rn <= (shi[head] - slo[head]) >> 2;
				wn <= (shi[head] - slo[head]) >> 2;
			end
			if (take) begin
				if (rq_we) begin
					if (eb)
						dhi[head] <= rq_a;
					else
						dlo[head] <= rq_a + 32'd4;
				end
				else if (eb)
					shi[head] <= rq_a;
				else
					slo[head] <= rq_a + 32'd4;
			end
			if (ld_wr) begin
				rq_v <= 1'b1;
				rq_we <= 1'b1;
				rq_a <= wa;
				{rq_t, rq_d} <= fb[fb_rp];
				fb_rp <= (sv2v_cast_32(fb_rp) == (BUF - 1) ? {BW {1'sb0}} : fb_rp + 1'b1);
				wa <= wa + step;
				wn <= wn - 32'd1;
			end
			else if (ld_rd) begin
				rq_v <= 1'b1;
				rq_we <= 1'b0;
				rq_a <= ra;
				ra <= ra + step;
				rn <= rn - 32'd1;
			end
			else if (ld_ok)
				rq_v <= 1'b0;
			fc <= (fc + (rd_ack ? 1'b1 : 1'b0)) - (ld_wr ? 1'b1 : 1'b0);
			rpend <= (rpend + (ld_rd ? 1'b1 : 1'b0)) - (rd_ack ? 1'b1 : 1'b0);
			if (rd_ack) begin
				fb[fb_wp] <= {rtag_i, rdata_i};
				fb_wp <= (sv2v_cast_32(fb_wp) == (BUF - 1) ? {BW {1'sb0}} : fb_wp + 1'b1);
			end
			if (wr_ack)
				words_o <= words_o + 32'd1;
			if (ack_i) begin : sv2v_autoblock_6
				reg signed [31:0] k;
				for (k = 0; k < 1; k = k + 1)
					begin
						if_we[k] <= if_we[k + 1];
						if_addr[k] <= if_addr[k + 1];
					end
			end
			if (take) begin
				if_we[sv2v_cast_32(if_n) - (ack_i ? 1 : 0)] <= rq_we;
				if_addr[sv2v_cast_32(if_n) - (ack_i ? 1 : 0)] <= rq_a;
			end
			if_n <= (if_n + (take ? 2'd1 : 2'd0)) - (ack_i ? 2'd1 : 2'd0);
			if (pop) begin
				qv[head] <= 1'b0;
				head <= nxt(head);
				act <= 1'b0;
				cmds_o <= cmds_o + 32'd1;
			end
			cnt <= (cnt + (push ? 1'b1 : 1'b0)) - (pop ? 1'b1 : 1'b0);
			if (flt) begin
				fault_o <= 1'b1;
				fault_reason_o <= fault_reason_i;
				fault_addr_o <= if_addr[0];
				begin : sv2v_autoblock_7
					reg signed [31:0] k;
					for (k = 0; k < QDEPTH; k = k + 1)
						qv[k] <= 1'b0;
				end
				head <= 1'sb0;
				cnt <= 1'sb0;
				act <= 1'b0;
				rq_v <= 1'b0;
				fb_rp <= 1'sb0;
				fb_wp <= 1'sb0;
				fc <= 1'sb0;
				rpend <= 1'sb0;
			end
		end
	initial _sv2v_0 = 0;
endmodule
module mpy_hash (
	clk_i,
	rst_n_i,
	valid_i,
	ready_o,
	tag_i,
	payload_i,
	qstr_count_i,
	qstr_base_i,
	qstr_ext_i,
	valid_o,
	ready_i,
	hash_o,
	error_o,
	mem_req_o,
	mem_addr_o,
	mem_ack_i,
	mem_fault_i,
	mem_data_i,
	mem_tag_i
);
	reg _sv2v_0;
	parameter integer DEPTH = 8;
	parameter integer BYTES_PER_CYCLE = 1;
	parameter [31:0] TUPLE_SEED = 32'd12345;
	parameter [31:0] FROZEN_SEED = 32'd54321;
	input wire clk_i;
	input wire rst_n_i;
	input wire valid_i;
	output wire ready_o;
	input wire [3:0] tag_i;
	input wire [31:0] payload_i;
	input wire [31:0] qstr_count_i;
	input wire [31:0] qstr_base_i;
	input wire [31:0] qstr_ext_i;
	output wire valid_o;
	input wire ready_i;
	output reg [31:0] hash_o;
	output reg error_o;
	output reg mem_req_o;
	output reg [31:0] mem_addr_o;
	input wire mem_ack_i;
	input wire mem_fault_i;
	input wire [31:0] mem_data_i;
	input wire [3:0] mem_tag_i;
	function automatic [31:0] hash_sx31;
		input reg [31:0] x;
		hash_sx31 = {x[30], x[30:0]};
	endfunction
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	function automatic [31:0] hash_float;
		input reg [31:0] bits;
		reg [31:0] value;
		reg [31:0] frac;
		integer e;
		begin
			e = sv2v_cast_32_signed({1'b0, bits[30:23]}) - 127;
			frac = {9'h001, bits[22:0]};
			if ((e < 0) || (e >= 31))
				value = 0;
			else if (e >= 23)
				value = frac << (e - 23);
			else
				value = frac >> (23 - e);
			if (bits[31])
				value = -value;
			hash_float = hash_sx31(value);
		end
	endfunction
	function automatic [31:0] hash_float_mag;
		input reg [31:0] bits;
		reg [31:0] frac;
		integer e;
		begin
			e = sv2v_cast_32_signed({1'b0, bits[30:23]}) - 127;
			frac = {9'h001, bits[22:0]};
			if ((e < 0) || (e >= 31))
				hash_float_mag = 0;
			else if (e >= 23)
				hash_float_mag = frac << (e - 23);
			else
				hash_float_mag = frac >> (23 - e);
		end
	endfunction
	function automatic [31:0] hash_float_sign;
		input reg neg;
		input reg [31:0] mag;
		hash_float_sign = hash_sx31((neg ? -mag : mag));
	endfunction
	function automatic [31:0] hash_byte;
		input reg [31:0] h;
		input reg [7:0] b;
		hash_byte = ((h << 5) + h) ^ {24'd0, b};
	endfunction
	function automatic [31:0] hash_string_finish;
		input reg [31:0] h;
		hash_string_finish = (h[15:0] == 0 ? 32'd1 : {16'd0, h[15:0]});
	endfunction
	localparam integer SP_W = (DEPTH < 2 ? 1 : $clog2(DEPTH + 1));
	reg [4:0] state;
	reg [3:0] tag;
	reg [31:0] payload;
	reg [31:0] result;
	reg [31:0] real_hash;
	reg [31:0] len;
	reg [31:0] ptr;
	reg [31:0] acc;
	reg [31:0] byte_buffer;
	reg [31:0] part_r;
	reg [31:0] mag_r;
	reg [SP_W - 1:0] sp;
	reg [31:0] frame_ptr [0:DEPTH - 1];
	reg [31:0] frame_len [0:DEPTH - 1];
	reg [31:0] frame_idx [0:DEPTH - 1];
	reg [31:0] frame_sum [0:DEPTH - 1];
	reg frame_set [0:DEPTH - 1];
	reg reading;
	reg [31:0] word_hash;
	reg [31:0] shifted;
	integer count;
	assign ready_o = (state == 5'd0) || ((state == 5'd3) && ready_i);
	assign valid_o = state == 5'd3;
	always @(*) begin
		if (_sv2v_0)
			;
		reading = 1'b1;
		mem_addr_o = payload;
		case (state)
			5'd4, 5'd5, 5'd13, 5'd17: mem_addr_o = payload;
			5'd8, 5'd12: mem_addr_o = payload + 4;
			5'd11: mem_addr_o = (payload < qstr_count_i ? qstr_base_i + (payload << 3) : qstr_ext_i + ((payload - qstr_count_i) << 3));
			5'd14: mem_addr_o = payload + 8;
			5'd15: mem_addr_o = {ptr[31:2], 2'b00};
			5'd18: mem_addr_o = frame_ptr[sp - 1] + (frame_idx[sp - 1] << 2);
			5'd19: mem_addr_o = (payload & 32'hfffffffc) + 12;
			5'd20: mem_addr_o = (payload & 32'hfffffffc) + 4;
			5'd21: mem_addr_o = (payload & 32'hfffffffc) + 8;
			default: reading = 1'b0;
		endcase
		mem_req_o = reading;
		shifted = (state == 5'd16 ? byte_buffer : mem_data_i >> (8 * ptr[1:0]));
		count = BYTES_PER_CYCLE;
		if (count > (4 - sv2v_cast_32_signed(ptr[1:0])))
			count = 4 - sv2v_cast_32_signed(ptr[1:0]);
		if (len < count)
			count = sv2v_cast_32_signed(len);
		word_hash = acc;
		begin : sv2v_autoblock_1
			integer i;
			for (i = 0; i < BYTES_PER_CYCLE; i = i + 1)
				if (i < count)
					word_hash = hash_byte(word_hash, shifted[8 * i+:8]);
		end
	end
	task automatic fail;
		begin
			error_o <= 1'b1;
			hash_o <= 0;
			state <= 5'd3;
		end
	endtask
	task automatic finish;
		input reg [31:0] h;
		begin
			result <= hash_sx31(h);
			state <= 5'd2;
		end
	endtask
	task automatic accept;
		begin
			error_o <= 0;
			sp <= 0;
			tag <= tag_i;
			payload <= payload_i;
			state <= 5'd3;
			case (tag_i)
				0:
					case (payload_i)
						1: hash_o <= 6;
						4: hash_o <= 0;
						5: hash_o <= 1;
						default:
							fail;
					endcase
				1: hash_o <= hash_sx31(payload_i);
				3: hash_o <= hash_float(payload_i);
				11, 12, 14: hash_o <= hash_sx31(payload_i >> 1);
				default: state <= 5'd1;
			endcase
		end
	endtask
	initial if ((DEPTH < 1) || ((BYTES_PER_CYCLE != 1) && (BYTES_PER_CYCLE != 4)))
		$error("mpy_hash: invalid parameters");
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			state <= 5'd0;
			hash_o <= 0;
			error_o <= 0;
			sp <= 0;
			tag <= 0;
			payload <= 0;
			result <= 0;
			real_hash <= 0;
			part_r <= 0;
			mag_r <= 0;
			len <= 0;
			ptr <= 0;
			acc <= 0;
			byte_buffer <= 0;
		end
		else if ((reading && mem_ack_i) && mem_fault_i)
			fail;
		else
			case (state)
				5'd0:
					if (valid_i)
						accept;
				5'd1:
					case (tag)
						0:
							case (payload)
								1:
									finish(6);
								4:
									finish(0);
								5:
									finish(1);
								default:
									fail;
							endcase
						1:
							finish(payload);
						2: state <= 5'd4;
						3:
							finish(hash_float(payload));
						4: state <= 5'd5;
						6: state <= 5'd11;
						8, 13: state <= 5'd12;
						9:
							if (sp == DEPTH)
								fail;
							else
								state <= 5'd17;
						10:
							if ((payload[1:0] != 2) || (sp == DEPTH))
								fail;
							else
								state <= 5'd19;
						11, 12, 14:
							finish(payload >> 1);
						default:
							fail;
					endcase
				5'd2:
					if (sp == 0) begin
						hash_o <= result;
						state <= 5'd3;
					end
					else begin
						frame_sum[sp - 1] <= frame_sum[sp - 1] + result;
						if ((frame_idx[sp - 1] + 1) == frame_len[sp - 1]) begin
							result <= hash_sx31(frame_sum[sp - 1] + result);
							sp <= sp - 1;
						end
						else begin
							frame_idx[sp - 1] <= frame_idx[sp - 1] + 1;
							state <= 5'd18;
						end
					end
				5'd3:
					if (ready_i) begin
						if (valid_i)
							accept;
						else
							state <= 5'd0;
					end
				5'd4:
					if (mem_ack_i)
						finish(mem_data_i);
				5'd5:
					if (mem_ack_i) begin
						part_r <= mem_data_i;
						state <= 5'd6;
					end
				5'd6: begin
					mag_r <= hash_float_mag(part_r);
					state <= 5'd7;
				end
				5'd7: begin
					real_hash <= hash_float_sign(part_r[31], mag_r);
					state <= 5'd8;
				end
				5'd8:
					if (mem_ack_i) begin
						part_r <= mem_data_i;
						state <= 5'd9;
					end
				5'd9: begin
					mag_r <= hash_float_mag(part_r);
					state <= 5'd10;
				end
				5'd10:
					finish(real_hash ^ hash_float_sign(part_r[31], mag_r));
				5'd11:
					if (mem_ack_i)
						finish({16'd0, mem_data_i[15:0]});
				5'd12:
					if (mem_ack_i) begin
						if (mem_data_i[15:0] != 0)
							finish({16'd0, mem_data_i[15:0]});
						else
							state <= 5'd13;
					end
				5'd13:
					if (mem_ack_i) begin
						len <= mem_data_i;
						state <= 5'd14;
					end
				5'd14:
					if (mem_ack_i) begin
						ptr <= mem_data_i;
						acc <= 5381;
						if (len == 0)
							finish(5381);
						else
							state <= 5'd15;
					end
				5'd15, 5'd16:
					if ((state == 5'd16) || mem_ack_i) begin
						acc <= word_hash;
						ptr <= ptr + count;
						len <= len - count;
						byte_buffer <= shifted >> (8 * count);
						if (len == count)
							finish(hash_string_finish(word_hash));
						else if ((sv2v_cast_32_signed(ptr[1:0]) + count) == 4)
							state <= 5'd15;
						else
							state <= 5'd16;
					end
				5'd17:
					if (mem_ack_i) begin
						if (mem_data_i == 0)
							finish(TUPLE_SEED);
						else begin
							frame_ptr[sp] <= payload + 4;
							frame_len[sp] <= mem_data_i;
							frame_idx[sp] <= 0;
							frame_sum[sp] <= TUPLE_SEED;
							frame_set[sp] <= 0;
							sp <= sp + 1;
							state <= 5'd18;
						end
					end
				5'd19:
					if (mem_ack_i) begin
						if ((mem_data_i & 2) == 0)
							fail;
						else
							state <= 5'd20;
					end
				5'd20:
					if (mem_ack_i) begin
						len <= mem_data_i;
						state <= 5'd21;
					end
				5'd21:
					if (mem_ack_i) begin
						if (len == 0)
							finish(FROZEN_SEED);
						else begin
							frame_ptr[sp] <= mem_data_i;
							frame_len[sp] <= len;
							frame_idx[sp] <= 0;
							frame_sum[sp] <= FROZEN_SEED;
							frame_set[sp] <= 1;
							sp <= sp + 1;
							state <= 5'd18;
						end
					end
				5'd18:
					if (mem_ack_i) begin
						if ((frame_set[sp - 1] && (mem_tag_i == 0)) && ((mem_data_i == 0) || (mem_data_i == 3)))
							finish(0);
						else begin
							tag <= mem_tag_i;
							payload <= mem_data_i;
							state <= 5'd1;
						end
					end
				default: state <= 5'd0;
			endcase
	initial _sv2v_0 = 0;
endmodule
module mpy_key_equal (
	clk_i,
	rst_n_i,
	valid_i,
	ready_o,
	a_i,
	b_i,
	qstr_count_i,
	qstr_base_i,
	qstr_ext_i,
	valid_o,
	ready_i,
	equal_o,
	error_o,
	mem_req_o,
	mem_addr_o,
	mem_ack_i,
	mem_fault_i,
	mem_data_i
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_n_i;
	input wire valid_i;
	output wire ready_o;
	input wire [35:0] a_i;
	input wire [35:0] b_i;
	input wire [31:0] qstr_count_i;
	input wire [31:0] qstr_base_i;
	input wire [31:0] qstr_ext_i;
	output wire valid_o;
	input wire ready_i;
	output reg equal_o;
	output reg error_o;
	output reg mem_req_o;
	output reg [31:0] mem_addr_o;
	input wire mem_ack_i;
	input wire mem_fault_i;
	input wire [31:0] mem_data_i;
	reg [4:0] state;
	reg [35:0] a;
	reg [35:0] b;
	reg side;
	reg is_float [0:1];
	reg [63:0] integer_value [0:1];
	reg [31:0] real_value [0:1];
	reg [31:0] imag_value [0:1];
	reg [31:0] length [0:1];
	reg [31:0] ptr [0:1];
	reg [31:0] aword;
	reg [31:0] bword;
	reg [31:0] remaining;
	reg [31:0] qcount;
	reg [31:0] qbase;
	reg [31:0] qext;
	reg [2:0] acount;
	reg [2:0] bcount;
	wire [35:0] current;
	wire [31:0] descriptor;
	reg [63:0] convert_input;
	reg [63:0] magnitude;
	reg [63:0] normalized;
	reg convert_sign;
	reg convert_side;
	reg [5:0] exponent_index;
	reg [5:0] leading_index;
	reg [63:0] scan_bits;
	reg [24:0] rounded;
	reg [7:0] exponent_bits;
	always @(*) begin
		if (_sv2v_0)
			;
		scan_bits = magnitude;
		leading_index = 0;
		if (|scan_bits[63:32]) begin
			leading_index[5] = 1;
			scan_bits = scan_bits >> 32;
		end
		if (|scan_bits[31:16]) begin
			leading_index[4] = 1;
			scan_bits = scan_bits >> 16;
		end
		if (|scan_bits[15:8]) begin
			leading_index[3] = 1;
			scan_bits = scan_bits >> 8;
		end
		if (|scan_bits[7:4]) begin
			leading_index[2] = 1;
			scan_bits = scan_bits >> 4;
		end
		if (|scan_bits[3:2]) begin
			leading_index[1] = 1;
			scan_bits = scan_bits >> 2;
		end
		leading_index[0] = scan_bits[1];
		rounded = {1'b0, normalized[63:40]} + (normalized[39] && (|normalized[38:0] || normalized[40]));
		exponent_bits = (8'd127 + {2'b00, exponent_index}) + {7'd0, rounded[24]};
	end
	assign current = (side ? b : a);
	assign descriptor = (current[31:0] < qcount ? qbase + (current[31:0] << 3) : qext + ((current[31:0] - qcount) << 3));
	assign ready_o = (state == 5'd0) || ((state == 5'd19) && ready_i);
	assign valid_o = state == 5'd19;
	localparam [31:0] ABI_CTL_FALSE = 32'd4;
	localparam [31:0] ABI_CTL_TRUE = 32'd5;
	localparam [3:0] ABI_TAG_COMPLEX = 4'd4;
	localparam [3:0] ABI_TAG_CONTROL = 4'd0;
	localparam [3:0] ABI_TAG_FLOAT = 4'd3;
	localparam [3:0] ABI_TAG_INT = 4'd1;
	localparam [3:0] ABI_TAG_INT64 = 4'd2;
	function automatic numeric;
		input reg [35:0] v;
		numeric = ((((v[35:32] == ABI_TAG_INT) || (v[35:32] == ABI_TAG_INT64)) || (v[35:32] == ABI_TAG_FLOAT)) || (v[35:32] == ABI_TAG_COMPLEX)) || ((v[35:32] == ABI_TAG_CONTROL) && ((v[31:0] == ABI_CTL_FALSE) || (v[31:0] == ABI_CTL_TRUE)));
	endfunction
	localparam [3:0] ABI_TAG_QSTR = 4'd6;
	localparam [3:0] ABI_TAG_STR = 4'd8;
	function automatic stringlike;
		input reg [35:0] v;
		stringlike = (v[35:32] == ABI_TAG_QSTR) || (v[35:32] == ABI_TAG_STR);
	endfunction
	function automatic float_equal;
		input reg [31:0] x;
		input reg [31:0] y;
		float_equal = (!((x[30:23] == 255) && (x[22:0] != 0)) && !((y[30:23] == 255) && (y[22:0] != 0))) && ((x == y) || ((x[30:0] == 0) && (y[30:0] == 0)));
	endfunction
	task automatic finish;
		input reg result;
		begin
			equal_o <= result;
			state <= 5'd19;
		end
	endtask
	task automatic accept;
		begin
			a <= a_i;
			b <= b_i;
			side <= 0;
			error_o <= 0;
			equal_o <= 0;
			qcount <= qstr_count_i;
			qbase <= qstr_base_i;
			qext <= qstr_ext_i;
			state <= 5'd1;
		end
	endtask
	always @(*) begin
		if (_sv2v_0)
			;
		mem_req_o = 1;
		mem_addr_o = current[31:0];
		case (state)
			5'd3: mem_addr_o = current[31:0];
			5'd4: mem_addr_o = current[31:0] + 4;
			5'd12: mem_addr_o = (current[35:32] == ABI_TAG_QSTR ? descriptor : current[31:0]);
			5'd13: mem_addr_o = (current[35:32] == ABI_TAG_QSTR ? descriptor + 4 : current[31:0] + 8);
			5'd16: mem_addr_o = {ptr[0][31:2], 2'b00};
			5'd17: mem_addr_o = {ptr[1][31:2], 2'b00};
			default: mem_req_o = 0;
		endcase
	end
	localparam [3:0] ABI_TAG_BYTES = 4'd13;
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			state <= 5'd0;
			a <= 0;
			b <= 0;
			side <= 0;
			equal_o <= 0;
			error_o <= 0;
			convert_input <= 0;
			magnitude <= 0;
			normalized <= 0;
			convert_sign <= 0;
			convert_side <= 0;
			exponent_index <= 0;
			qcount <= 0;
			qbase <= 0;
			qext <= 0;
			aword <= 0;
			bword <= 0;
			remaining <= 0;
			acount <= 0;
			bcount <= 0;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < 2; i = i + 1)
					begin
						is_float[i] <= 0;
						integer_value[i] <= 0;
						real_value[i] <= 0;
						imag_value[i] <= 0;
						length[i] <= 0;
						ptr[i] <= 0;
					end
			end
		end
		else if ((mem_req_o && mem_ack_i) && mem_fault_i) begin
			error_o <= 1;
			finish(0);
		end
		else
			case (state)
				5'd0:
					if (valid_i)
						accept;
				5'd19:
					if (ready_i) begin
						if (valid_i)
							accept;
						else
							state <= 5'd0;
					end
				5'd1:
					if (a == b)
						finish(1);
					else if (numeric(a) && numeric(b))
						state <= 5'd2;
					else if ((stringlike(a) && stringlike(b)) || ((a[35:32] == ABI_TAG_BYTES) && (b[35:32] == ABI_TAG_BYTES)))
						state <= 5'd12;
					else
						finish(0);
				5'd2: begin
					imag_value[side] <= 0;
					case (current[35:32])
						ABI_TAG_INT: begin
							is_float[side] <= 0;
							integer_value[side] <= {{33 {current[30]}}, current[30:0]};
							state <= 5'd5;
						end
						ABI_TAG_CONTROL: begin
							is_float[side] <= 0;
							integer_value[side] <= (current[31:0] == ABI_CTL_TRUE ? 64'd1 : 64'd0);
							state <= 5'd5;
						end
						ABI_TAG_FLOAT: begin
							is_float[side] <= 1;
							real_value[side] <= current[31:0];
							state <= 5'd5;
						end
						default: begin
							is_float[side] <= current[35:32] == ABI_TAG_COMPLEX;
							state <= 5'd3;
						end
					endcase
				end
				5'd3:
					if (mem_ack_i) begin
						if (is_float[side])
							real_value[side] <= mem_data_i;
						else
							integer_value[side][31:0] <= mem_data_i;
						state <= 5'd4;
					end
				5'd4:
					if (mem_ack_i) begin
						if (is_float[side])
							imag_value[side] <= mem_data_i;
						else
							integer_value[side][63:32] <= mem_data_i;
						state <= 5'd5;
					end
				5'd5:
					if (!side) begin
						side <= 1;
						state <= 5'd2;
					end
					else
						state <= 5'd6;
				5'd6:
					if (!is_float[0] && !is_float[1])
						finish(integer_value[0] == integer_value[1]);
					else if (is_float[0] && is_float[1])
						state <= 5'd11;
					else begin
						convert_side <= is_float[0];
						convert_input <= (is_float[0] ? integer_value[1] : integer_value[0]);
						state <= 5'd7;
					end
				5'd7: begin
					convert_sign <= convert_input[63];
					magnitude <= (convert_input[63] ? -convert_input : convert_input);
					state <= 5'd8;
				end
				5'd8: begin
					exponent_index <= leading_index;
					state <= 5'd9;
				end
				5'd9: begin
					normalized <= magnitude << ~exponent_index;
					state <= 5'd10;
				end
				5'd10: begin
					real_value[convert_side] <= (magnitude == 0 ? 32'd0 : {convert_sign, exponent_bits, (rounded[24] ? rounded[23:1] : rounded[22:0])});
					state <= 5'd11;
				end
				5'd11:
					finish(float_equal(real_value[0], real_value[1]) && float_equal(imag_value[0], imag_value[1]));
				5'd12:
					if (mem_ack_i) begin
						length[side] <= (current[35:32] == ABI_TAG_QSTR ? {16'd0, mem_data_i[31:16]} : mem_data_i);
						state <= 5'd13;
					end
				5'd13:
					if (mem_ack_i) begin
						ptr[side] <= (current[35:32] == ABI_TAG_QSTR ? {1'b0, mem_data_i[30:0]} : mem_data_i);
						state <= 5'd14;
					end
				5'd14:
					if (!side) begin
						side <= 1;
						state <= 5'd12;
					end
					else
						state <= 5'd15;
				5'd15:
					if (length[0] != length[1])
						finish(0);
					else if (length[0] == 0)
						finish(1);
					else begin
						remaining <= length[0];
						acount <= 0;
						bcount <= 0;
						state <= 5'd16;
					end
				5'd16:
					if (mem_ack_i) begin
						aword <= mem_data_i >> (8 * ptr[0][1:0]);
						acount <= 4 - {1'b0, ptr[0][1:0]};
						state <= (bcount == 0 ? 5'd17 : 5'd18);
					end
				5'd17:
					if (mem_ack_i) begin
						bword <= mem_data_i >> (8 * ptr[1][1:0]);
						bcount <= 4 - {1'b0, ptr[1][1:0]};
						state <= 5'd18;
					end
				5'd18:
					if (aword[7:0] != bword[7:0])
						finish(0);
					else if (remaining == 1)
						finish(1);
					else begin
						remaining <= remaining - 1;
						ptr[0] <= ptr[0] + 1;
						ptr[1] <= ptr[1] + 1;
						aword <= aword >> 8;
						bword <= bword >> 8;
						acount <= acount - 1;
						bcount <= bcount - 1;
						if (acount == 1)
							state <= 5'd16;
						else if (bcount == 1)
							state <= 5'd17;
					end
				default: state <= 5'd0;
			endcase
	initial _sv2v_0 = 0;
endmodule
module mpy_map_engine (
	cache_clear_i,
	cache_write_i,
	cache_write2_i,
	cache_addr_i,
	cache_addr2_i,
	hash_valid_o,
	hash_ready_i,
	hash_tag_o,
	hash_payload_o,
	hash_result_valid_i,
	hash_result_ready_o,
	hash_value_i,
	hash_error_i,
	hash_mem_req_i,
	hash_mem_addr_i,
	hash_mem_ack_o,
	clk_i,
	rst_n_i,
	valid_i,
	ready_o,
	op_i,
	set_i,
	src_i,
	src_alloc_i,
	dst_i,
	dst_alloc_i,
	used_i,
	hashes_i,
	qstr_count_i,
	qstr_base_i,
	qstr_ext_i,
	done_o,
	admitted_o,
	fallback_o,
	fault_o,
	used_o,
	req_o,
	we_o,
	addr_o,
	wdata_o,
	wtag_o,
	gnt_i,
	ack_i,
	fault_i,
	mem_data_i,
	mem_tag_i
);
	reg _sv2v_0;
	parameter [0:0] EXTERNAL_HASH = 0;
	parameter [0:0] TYPE_CACHE = 0;
	input wire cache_clear_i;
	input wire cache_write_i;
	input wire cache_write2_i;
	input wire [31:0] cache_addr_i;
	input wire [31:0] cache_addr2_i;
	output wire hash_valid_o;
	input wire hash_ready_i;
	output wire [3:0] hash_tag_o;
	output wire [31:0] hash_payload_o;
	input wire hash_result_valid_i;
	output wire hash_result_ready_o;
	input wire [31:0] hash_value_i;
	input wire hash_error_i;
	input wire hash_mem_req_i;
	input wire [31:0] hash_mem_addr_i;
	output wire hash_mem_ack_o;
	input wire clk_i;
	input wire rst_n_i;
	input wire valid_i;
	output wire ready_o;
	input wire [2:0] op_i;
	input wire set_i;
	input wire [31:0] src_i;
	input wire [31:0] src_alloc_i;
	input wire [31:0] dst_i;
	input wire [31:0] dst_alloc_i;
	input wire [31:0] used_i;
	input wire [31:0] hashes_i;
	input wire [31:0] qstr_count_i;
	input wire [31:0] qstr_base_i;
	input wire [31:0] qstr_ext_i;
	output reg done_o;
	output reg admitted_o;
	output reg fallback_o;
	output reg fault_o;
	output reg [31:0] used_o;
	output reg req_o;
	output reg we_o;
	output reg [31:0] addr_o;
	output reg [31:0] wdata_o;
	output reg [3:0] wtag_o;
	input wire gnt_i;
	input wire ack_i;
	input wire fault_i;
	input wire [31:0] mem_data_i;
	input wire [3:0] mem_tag_i;
	function automatic [31:0] hash_sx31;
		input reg [31:0] x;
		hash_sx31 = {x[30], x[30:0]};
	endfunction
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	function automatic [31:0] hash_float;
		input reg [31:0] bits;
		reg [31:0] value;
		reg [31:0] frac;
		integer e;
		begin
			e = sv2v_cast_32_signed({1'b0, bits[30:23]}) - 127;
			frac = {9'h001, bits[22:0]};
			if ((e < 0) || (e >= 31))
				value = 0;
			else if (e >= 23)
				value = frac << (e - 23);
			else
				value = frac >> (23 - e);
			if (bits[31])
				value = -value;
			hash_float = hash_sx31(value);
		end
	endfunction
	function automatic [31:0] hash_float_mag;
		input reg [31:0] bits;
		reg [31:0] frac;
		integer e;
		begin
			e = sv2v_cast_32_signed({1'b0, bits[30:23]}) - 127;
			frac = {9'h001, bits[22:0]};
			if ((e < 0) || (e >= 31))
				hash_float_mag = 0;
			else if (e >= 23)
				hash_float_mag = frac << (e - 23);
			else
				hash_float_mag = frac >> (23 - e);
		end
	endfunction
	function automatic [31:0] hash_float_sign;
		input reg neg;
		input reg [31:0] mag;
		hash_float_sign = hash_sx31((neg ? -mag : mag));
	endfunction
	function automatic [31:0] hash_byte;
		input reg [31:0] h;
		input reg [7:0] b;
		hash_byte = ((h << 5) + h) ^ {24'd0, b};
	endfunction
	function automatic [31:0] hash_string_finish;
		input reg [31:0] h;
		hash_string_finish = (h[15:0] == 0 ? 32'd1 : {16'd0, h[15:0]});
	endfunction
	reg [5:0] state;
	reg [5:0] after_mem;
	reg [2:0] op;
	reg is_set;
	reg check_dst;
	reg granted;
	reg find_first;
	reg [31:0] src;
	reg [31:0] sn;
	reg [31:0] dst;
	reg [31:0] dn;
	reg [31:0] hashes;
	reg [31:0] idx;
	reg [31:0] pos;
	reg [31:0] start_pos;
	reg [31:0] avail;
	reg [31:0] key;
	reg [31:0] value;
	reg [31:0] hash_value;
	reg [31:0] active_base;
	reg [31:0] active_n;
	reg [31:0] probe_base;
	reg [31:0] probe_n;
	reg [3:0] key_tag;
	reg [3:0] value_tag;
	reg [35:0] probe_key;
	reg [31:0] qcount;
	reg [31:0] qbase;
	reg [31:0] qext;
	wire eq_ready;
	wire eq_valid;
	wire eq_result;
	wire eq_error;
	wire eq_req;
	wire [31:0] eq_addr;
	mpy_key_equal equality(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.valid_i(state == 6'd26),
		.ready_o(eq_ready),
		.a_i(probe_key),
		.b_i({key_tag, key}),
		.qstr_count_i(qcount),
		.qstr_base_i(qbase),
		.qstr_ext_i(qext),
		.valid_o(eq_valid),
		.ready_i(state == 6'd27),
		.equal_o(eq_result),
		.error_o(eq_error),
		.mem_req_o(eq_req),
		.mem_addr_o(eq_addr),
		.mem_ack_i((state == 6'd28) && ack_i),
		.mem_fault_i(fault_i),
		.mem_data_i(mem_data_i)
	);
	wire hv;
	wire hr;
	wire he;
	wire hmreq;
	wire hmack;
	wire mod_done;
	wire [31:0] hout;
	wire [31:0] hmaddr;
	wire [31:0] rem;
	reg [31:0] src_used;
	reg [31:0] rdata_i;
	reg [3:0] rtag_i;
	reg [1:0] cache_valid;
	reg [1:0] cache_set;
	reg [31:0] cache_base [0:1];
	reg [31:0] cache_end [0:1];
	reg [31:0] cache_n [0:1];
	reg [31:0] cache_used [0:1];
	reg [15:0] cache_tags [0:1];
	reg [15:0] scan_tags [0:1];
	reg [31:0] dst_scan_used;
	reg src_hit;
	reg dst_hit;
	reg [31:0] src_cached_used;
	localparam [3:0] ABI_TAG_COMPLEX = 4'd4;
	localparam [3:0] ABI_TAG_FLOAT = 4'd3;
	always @(*) begin
		if (_sv2v_0)
			;
		src_hit = 0;
		dst_hit = 0;
		src_cached_used = 0;
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < 2; i = i + 1)
				if (((TYPE_CACHE && cache_valid[i]) && (cache_set[i] == is_set)) && !((op == 7) && (cache_tags[i][ABI_TAG_FLOAT] || cache_tags[i][ABI_TAG_COMPLEX]))) begin
					if ((cache_base[i] == src) && (cache_n[i] == sn)) begin
						src_hit = 1;
						src_cached_used = cache_used[i];
					end
					if ((cache_base[i] == dst) && (cache_n[i] == dn))
						dst_hit = 1;
				end
		end
	end
	localparam [31:0] ABI_CTL_NULL = 32'd0;
	localparam [3:0] ABI_TAG_CONTROL = 4'd0;
	function automatic empty;
		input reg [3:0] t;
		input reg [31:0] d;
		empty = (t == ABI_TAG_CONTROL) && (d == ABI_CTL_NULL);
	endfunction
	localparam [31:0] ABI_CTL_TOMB = 32'd3;
	function automatic tomb;
		input reg [3:0] t;
		input reg [31:0] d;
		tomb = (t == ABI_TAG_CONTROL) && (d == ABI_CTL_TOMB);
	endfunction
	localparam [31:0] ABI_CTL_FALSE = 32'd4;
	localparam [31:0] ABI_CTL_NONE = 32'd1;
	localparam [31:0] ABI_CTL_TRUE = 32'd5;
	localparam [3:0] ABI_TAG_BYTES = 4'd13;
	localparam [3:0] ABI_TAG_INT = 4'd1;
	localparam [3:0] ABI_TAG_INT64 = 4'd2;
	localparam [3:0] ABI_TAG_QSTR = 4'd6;
	localparam [3:0] ABI_TAG_STR = 4'd8;
	function automatic scalar;
		input reg [3:0] t;
		input reg [31:0] d;
		scalar = (((((((t == ABI_TAG_INT) || (t == ABI_TAG_INT64)) || (t == ABI_TAG_FLOAT)) || (t == ABI_TAG_COMPLEX)) || (t == ABI_TAG_STR)) || (t == ABI_TAG_BYTES)) || (t == ABI_TAG_QSTR)) || ((t == ABI_TAG_CONTROL) && (((d == ABI_CTL_NONE) || (d == ABI_CTL_FALSE)) || (d == ABI_CTL_TRUE)));
	endfunction
	function automatic numeric;
		input reg [3:0] t;
		input reg [31:0] d;
		numeric = (t == ABI_TAG_INT) || ((t == ABI_TAG_CONTROL) && ((d == ABI_CTL_FALSE) || (d == ABI_CTL_TRUE)));
	endfunction
	function automatic [30:0] number;
		input reg [3:0] t;
		input reg [31:0] d;
		number = (t == ABI_TAG_INT ? d[30:0] : {30'd0, d == ABI_CTL_TRUE});
	endfunction
	function automatic equal_key;
		input reg [3:0] t;
		input reg [31:0] d;
		reg [0:1] _sv2v_jump;
		begin
			_sv2v_jump = 2'b00;
			if (numeric(t, d) && numeric(key_tag, key)) begin
				equal_key = number(t, d) == number(key_tag, key);
				_sv2v_jump = 2'b11;
			end
			if (_sv2v_jump == 2'b00) begin
				equal_key = (t == key_tag) && (d == key);
				_sv2v_jump = 2'b11;
			end
		end
	endfunction
	function automatic extended;
		input reg [3:0] t;
		extended = ((((t == ABI_TAG_INT64) || (t == ABI_TAG_FLOAT)) || (t == ABI_TAG_COMPLEX)) || (t == ABI_TAG_STR)) || (t == ABI_TAG_BYTES);
	endfunction
	function automatic [31:0] at;
		input reg [31:0] base;
		input reg [31:0] slot;
		at = base + (slot << (is_set ? 2 : 3));
	endfunction
	assign ready_o = state == 6'd0;
	assign hash_valid_o = ((state == 6'd8) && (key_tag != ABI_TAG_INT)) && (key_tag != ABI_TAG_CONTROL);
	assign hash_tag_o = key_tag;
	assign hash_payload_o = key;
	assign hash_result_ready_o = state == 6'd9;
	assign hash_mem_ack_o = hmack;
	generate
		if (EXTERNAL_HASH) begin : shared_hash
			assign hr = hash_ready_i;
			assign hv = hash_result_valid_i;
			assign hout = hash_value_i;
			assign he = hash_error_i;
			assign hmreq = hash_mem_req_i;
			assign hmaddr = hash_mem_addr_i;
		end
		else begin : private_hash
			mpy_hash #(.DEPTH(1)) hash_unit(
				.clk_i(clk_i),
				.rst_n_i(rst_n_i),
				.valid_i(((state == 6'd8) && (key_tag != ABI_TAG_INT)) && (key_tag != ABI_TAG_CONTROL)),
				.ready_o(hr),
				.tag_i(key_tag),
				.payload_i(key),
				.qstr_count_i(qcount),
				.qstr_base_i(qbase),
				.qstr_ext_i(qext),
				.valid_o(hv),
				.ready_i(state == 6'd9),
				.hash_o(hout),
				.error_o(he),
				.mem_req_o(hmreq),
				.mem_addr_o(hmaddr),
				.mem_ack_i(hmack),
				.mem_fault_i(fault_i),
				.mem_data_i(mem_data_i),
				.mem_tag_i(mem_tag_i)
			);
		end
	endgenerate
	assign hmack = (state == 6'd25) && ack_i;
	upycore_umod_seq modulo(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.start_i((state == 6'd10) && (hash_value >= probe_n)),
		.a_i(hash_value),
		.d_i(probe_n),
		.done_o(mod_done),
		.rem_o(rem),
		.busy_o()
	);
	task automatic read_word;
		input reg [31:0] a;
		input reg [5:0] next_state;
		begin
			req_o <= 1;
			we_o <= 0;
			addr_o <= a;
			granted <= 0;
			after_mem <= next_state;
			state <= 6'd24;
		end
	endtask
	task automatic write_word;
		input reg [31:0] a;
		input reg [3:0] t;
		input reg [31:0] d;
		input reg [5:0] next_state;
		begin
			req_o <= 1;
			we_o <= 1;
			addr_o <= a;
			wtag_o <= t;
			wdata_o <= d;
			granted <= 0;
			after_mem <= next_state;
			state <= 6'd24;
		end
	endtask
	task automatic reject;
		begin
			fallback_o <= 1;
			state <= 6'd19;
		end
	endtask
	task automatic missing;
		if (op == 5) begin
			used_o <= 0;
			state <= 6'd19;
		end
		else if (op == 6)
			state <= 6'd18;
		else if (op == 3)
			state <= 6'd16;
		else if (op == 2)
			state <= 6'd18;
		else begin
			if (avail != 32'hffffffff)
				pos <= avail;
			state <= 6'd14;
		end
	endtask
	task automatic found_key;
		if (op == 7) begin
			if (find_first) begin
				used_o <= idx;
				state <= 6'd19;
			end
			else begin
				used_o <= used_o + 1;
				state <= 6'd23;
			end
		end
		else if (op == 6) begin
			used_o <= 0;
			state <= 6'd19;
		end
		else if ((op == 2) || (op == 4))
			state <= 6'd16;
		else if ((op == 1) && !is_set)
			state <= 6'd15;
		else
			state <= 6'd18;
	endtask
	task automatic advance_probe;
		input reg is_tomb;
		if (op == 7)
			state <= 6'd23;
		else if (((pos + 1) == probe_n ? 32'd0 : pos + 1) == start_pos) begin
			if ((op == 5) || (op == 6))
				missing;
			else if (op == 2)
				state <= 6'd18;
			else if (op == 3)
				state <= 6'd16;
			else if (avail != 32'hffffffff) begin
				pos <= avail;
				state <= 6'd14;
			end
			else if (is_tomb)
				state <= 6'd14;
			else
				reject;
		end
		else begin
			if (is_tomb && (avail == 32'hffffffff))
				avail <= pos;
			pos <= ((pos + 1) == probe_n ? 32'd0 : pos + 1);
			state <= 6'd12;
		end
	endtask
	localparam [3:0] ABI_TAG_MUT = 4'd10;
	localparam [3:0] ABI_TAG_OBJECT = 4'd14;
	localparam [3:0] ABI_TAG_TUPLE = 4'd9;
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			qcount <= 0;
			qbase <= 0;
			qext <= 0;
			state <= 6'd0;
			after_mem <= 6'd0;
			op <= 0;
			is_set <= 0;
			src <= 0;
			sn <= 0;
			dst <= 0;
			dn <= 0;
			hashes <= 0;
			idx <= 0;
			probe_key <= 0;
			find_first <= 0;
			cache_valid <= 0;
			cache_set <= 0;
			dst_scan_used <= 0;
			begin : sv2v_autoblock_2
				reg signed [31:0] i;
				for (i = 0; i < 2; i = i + 1)
					begin
						cache_base[i] <= 0;
						cache_end[i] <= 0;
						cache_n[i] <= 0;
						cache_used[i] <= 0;
						cache_tags[i] <= 0;
						scan_tags[i] <= 0;
					end
			end
			pos <= 0;
			start_pos <= 0;
			avail <= 0;
			key <= 0;
			key_tag <= 0;
			value <= 0;
			value_tag <= 0;
			hash_value <= 0;
			src_used <= 0;
			active_base <= 0;
			active_n <= 0;
			probe_base <= 0;
			probe_n <= 0;
			used_o <= 0;
			done_o <= 0;
			admitted_o <= 0;
			fallback_o <= 0;
			fault_o <= 0;
			req_o <= 0;
			we_o <= 0;
			addr_o <= 0;
			wdata_o <= 0;
			wtag_o <= 0;
			check_dst <= 0;
			granted <= 0;
			rdata_i <= 0;
			rtag_i <= 0;
		end
		else begin
			done_o <= 0;
			admitted_o <= 0;
			if (ack_i) begin
				rdata_i <= mem_data_i;
				rtag_i <= mem_tag_i;
			end
			if (req_o && gnt_i) begin
				req_o <= 0;
				granted <= 1;
			end
			case (state)
				6'd0:
					if (valid_i) begin
						qcount <= qstr_count_i;
						qbase <= qstr_base_i;
						qext <= qstr_ext_i;
						op <= op_i;
						is_set <= set_i;
						src <= src_i;
						sn <= src_alloc_i;
						dst <= dst_i;
						dn <= dst_alloc_i;
						hashes <= hashes_i;
						used_o <= (op_i == 7 ? (used_i == 1 ? 32'hffffffff : 32'd0) : (op_i >= 5 ? 32'd1 : used_i));
						find_first <= used_i == 1;
						fallback_o <= 0;
						fault_o <= 0;
						idx <= 0;
						src_used <= 0;
						dst_scan_used <= 0;
						scan_tags[0] <= 0;
						scan_tags[1] <= 0;
						active_base <= (((op_i == 2) || (op_i == 3)) || (op_i >= 5) ? dst_i : src_i);
						active_n <= (((op_i == 2) || (op_i == 3)) || (op_i >= 5) ? dst_alloc_i : src_alloc_i);
						probe_base <= (((op_i == 2) || (op_i == 3)) || (op_i >= 5) ? src_i : dst_i);
						probe_n <= (((op_i == 2) || (op_i == 3)) || (op_i >= 5) ? src_alloc_i : dst_alloc_i);
						if (((((!set_i && (op_i > 1)) || ((src_i == dst_i) && (op_i < 5))) || (src_i[1:0] != 0)) || (dst_i[1:0] != 0)) || ((op_i < 7) && (used_i > dst_alloc_i)))
							reject;
						else if (op_i == 0)
							state <= 6'd4;
						else
							state <= 6'd1;
					end
				6'd1:
					if ((idx == 0) && src_hit) begin
						src_used <= src_cached_used;
						state <= 6'd2;
					end
					else if (idx == sn) begin
						if (TYPE_CACHE) begin
							cache_valid[0] <= 1;
							cache_set[0] <= is_set;
							cache_base[0] <= src;
							cache_n[0] <= sn;
							cache_end[0] <= src + (sn << (is_set ? 2 : 3));
							cache_used[0] <= src_used;
							cache_tags[0] <= scan_tags[0];
						end
						idx <= 0;
						state <= 6'd2;
					end
					else begin
						check_dst <= 0;
						read_word(at(src, idx), 6'd3);
					end
				6'd2:
					if ((idx == dn) || ((idx == 0) && dst_hit)) begin
						if (TYPE_CACHE && !dst_hit) begin
							cache_valid[1] <= 1;
							cache_set[1] <= is_set;
							cache_base[1] <= dst;
							cache_n[1] <= dn;
							cache_end[1] <= dst + (dn << (is_set ? 2 : 3));
							cache_used[1] <= dst_scan_used;
							cache_tags[1] <= scan_tags[1];
						end
						idx <= 0;
						if (((op == 1) || (op == 4)) && (src_used > (dn - used_o)))
							reject;
						else begin
							admitted_o <= 1;
							if (op == 7)
								read_word(src, 6'd20);
							else
								state <= 6'd4;
						end
					end
					else begin
						check_dst <= 1;
						read_word(at(dst, idx), 6'd3);
					end
				6'd3:
					if (!empty(rtag_i, rdata_i) && !tomb(rtag_i, rdata_i)) begin
						if (!scalar(rtag_i, rdata_i) || ((op == 7) && ((rtag_i == ABI_TAG_FLOAT) || (rtag_i == ABI_TAG_COMPLEX))))
							reject;
						else begin
							scan_tags[check_dst] <= scan_tags[check_dst] | (16'd1 << rtag_i);
							if (!check_dst)
								src_used <= src_used + 1;
							else
								dst_scan_used <= dst_scan_used + 1;
							idx <= idx + 1;
							state <= (check_dst ? 6'd2 : 6'd1);
						end
					end
					else begin
						idx <= idx + 1;
						state <= (check_dst ? 6'd2 : 6'd1);
					end
				6'd20: begin
					key <= rdata_i;
					key_tag <= rtag_i;
					state <= 6'd21;
				end
				6'd21:
					if (idx == dn)
						state <= 6'd19;
					else
						read_word(at(dst, idx), 6'd22);
				6'd22:
					if (equal_key(rtag_i, rdata_i))
						found_key;
					else if (extended(rtag_i) || extended(key_tag)) begin
						probe_key <= {rtag_i, rdata_i};
						state <= 6'd26;
					end
					else
						state <= 6'd23;
				6'd23: begin
					idx <= idx + 1;
					state <= 6'd21;
				end
				6'd4:
					if (idx == active_n)
						state <= 6'd19;
					else
						read_word(at(active_base, idx), 6'd5);
				6'd5:
					if (empty(rtag_i, rdata_i) || tomb(rtag_i, rdata_i))
						state <= 6'd18;
					else begin
						key <= rdata_i;
						key_tag <= rtag_i;
						if (probe_n == 0) begin
							if (op >= 5)
								missing;
							else if (op == 3)
								state <= 6'd16;
							else if (op == 2)
								state <= 6'd18;
							else
								reject;
						end
						else if (!is_set)
							read_word(at(src, idx) + 4, 6'd6);
						else if ((op == 0) && (hashes != 0))
							read_word(hashes + (idx << 2), 6'd7);
						else if ((op == 0) && (((rtag_i == ABI_TAG_OBJECT) || (rtag_i == ABI_TAG_TUPLE)) || (rtag_i == ABI_TAG_MUT)))
							reject;
						else
							state <= 6'd8;
					end
				6'd6: begin
					value <= rdata_i;
					value_tag <= rtag_i;
					if ((op == 0) && (hashes != 0))
						read_word(hashes + (idx << 2), 6'd7);
					else if ((op == 0) && (((key_tag == ABI_TAG_OBJECT) || (key_tag == ABI_TAG_TUPLE)) || (key_tag == ABI_TAG_MUT)))
						reject;
					else
						state <= 6'd8;
				end
				6'd7:
					if (rtag_i == ABI_TAG_INT) begin
						hash_value <= {rdata_i[30], rdata_i[30:0]};
						state <= 6'd10;
					end
					else if (((key_tag == ABI_TAG_OBJECT) || (key_tag == ABI_TAG_TUPLE)) || (key_tag == ABI_TAG_MUT))
						reject;
					else
						state <= 6'd8;
				6'd8:
					if (key_tag == ABI_TAG_INT) begin
						hash_value <= hash_sx31(key);
						state <= 6'd10;
					end
					else if (key_tag == ABI_TAG_CONTROL) begin
						hash_value <= (key == ABI_CTL_NONE ? 32'd6 : (key == ABI_CTL_TRUE ? 32'd1 : 32'd0));
						state <= 6'd10;
					end
					else if (hr)
						state <= 6'd9;
				6'd9:
					if (hv) begin
						if (he)
							reject;
						else begin
							hash_value <= hout;
							state <= 6'd10;
						end
					end
					else if (hmreq) begin
						req_o <= 1;
						we_o <= 0;
						addr_o <= hmaddr;
						granted <= 0;
						state <= 6'd25;
					end
				6'd25:
					if (ack_i) begin
						granted <= 0;
						if (fault_i) begin
							fault_o <= 1;
							state <= 6'd19;
						end
						else
							state <= 6'd9;
					end
				6'd10:
					if (hash_value < probe_n) begin
						pos <= hash_value;
						start_pos <= hash_value;
						avail <= 32'hffffffff;
						state <= 6'd12;
					end
					else
						state <= 6'd11;
				6'd11:
					if (mod_done) begin
						pos <= rem;
						start_pos <= rem;
						avail <= 32'hffffffff;
						state <= 6'd12;
					end
				6'd12:
					read_word(at(probe_base, pos), 6'd13);
				6'd13:
					if (empty(rtag_i, rdata_i))
						missing;
					else if (((op != 0) && !tomb(rtag_i, rdata_i)) && equal_key(rtag_i, rdata_i))
						found_key;
					else if (((op != 0) && !tomb(rtag_i, rdata_i)) && (extended(rtag_i) || extended(key_tag))) begin
						probe_key <= {rtag_i, rdata_i};
						state <= 6'd26;
					end
					else
						advance_probe(tomb(rtag_i, rdata_i));
				6'd26:
					if (eq_ready)
						state <= 6'd27;
				6'd27:
					if (eq_valid) begin
						if (eq_error) begin
							fault_o <= 1;
							state <= 6'd19;
						end
						else if (eq_result)
							found_key;
						else
							advance_probe(0);
					end
					else if (eq_req) begin
						req_o <= 1;
						we_o <= 0;
						addr_o <= eq_addr;
						granted <= 0;
						state <= 6'd28;
					end
				6'd28:
					if (ack_i) begin
						granted <= 0;
						if (fault_i) begin
							fault_o <= 1;
							state <= 6'd19;
						end
						else
							state <= 6'd27;
					end
				6'd14: begin
					used_o <= used_o + 1;
					write_word(at(dst, pos), key_tag, key, (is_set ? 6'd18 : 6'd15));
				end
				6'd15:
					write_word(at(dst, pos) + 4, value_tag, value, 6'd18);
				6'd16:
					read_word(at(dst, ((((op == 2) || (op == 3) ? idx : pos) + 1) == dn ? 32'd0 : ((op == 2) || (op == 3) ? idx : pos) + 1)), 6'd17);
				6'd17: begin
					used_o <= used_o - 1;
					write_word(at(dst, ((op == 2) || (op == 3) ? idx : pos)), ABI_TAG_CONTROL, (empty(rtag_i, rdata_i) ? ABI_CTL_NULL : ABI_CTL_TOMB), 6'd18);
				end
				6'd18: begin
					idx <= idx + 1;
					state <= 6'd4;
				end
				6'd19: begin
					done_o <= 1;
					state <= 6'd0;
				end
				6'd24:
					if (ack_i) begin
						granted <= 0;
						if (fault_i) begin
							fault_o <= 1;
							state <= 6'd19;
						end
						else
							state <= after_mem;
					end
				default: state <= 6'd0;
			endcase
			begin : sv2v_autoblock_3
				reg signed [31:0] i;
				for (i = 0; i < 2; i = i + 1)
					if ((cache_clear_i || ((cache_write_i && (cache_addr_i >= cache_base[i])) && (cache_addr_i < cache_end[i]))) || ((cache_write2_i && (cache_addr2_i >= cache_base[i])) && (cache_addr2_i < cache_end[i])))
						cache_valid[i] <= 0;
			end
		end
	initial _sv2v_0 = 0;
endmodule
module mpy_bulk (
	cache_clear_i,
	cache_write_i,
	cache_write2_i,
	cache_addr_i,
	cache_addr2_i,
	clk_i,
	rst_n_i,
	valid_i,
	ready_o,
	op_i,
	set_i,
	src_i,
	sn_i,
	dst_i,
	dn_i,
	used_i,
	header_i,
	source_header_i,
	hashes_i,
	qstr_count_i,
	qstr_base_i,
	qstr_ext_i,
	return_o,
	ok_o,
	idle_o,
	used_o,
	chk_addr_i,
	chk_we_i,
	busy_o,
	req_o,
	we_o,
	addr_o,
	wdata_o,
	wtag_o,
	gnt_i,
	ack_i,
	fault_i,
	rdata_i,
	rtag_i,
	fault_o,
	fault_addr_o
);
	parameter [0:0] TYPE_CACHE = 0;
	input wire cache_clear_i;
	input wire cache_write_i;
	input wire cache_write2_i;
	input wire [31:0] cache_addr_i;
	input wire [31:0] cache_addr2_i;
	input wire clk_i;
	input wire rst_n_i;
	input wire valid_i;
	output wire ready_o;
	input wire [2:0] op_i;
	input wire set_i;
	input wire [31:0] src_i;
	input wire [31:0] sn_i;
	input wire [31:0] dst_i;
	input wire [31:0] dn_i;
	input wire [31:0] used_i;
	input wire [31:0] header_i;
	input wire [31:0] source_header_i;
	input wire [31:0] hashes_i;
	input wire [31:0] qstr_count_i;
	input wire [31:0] qstr_base_i;
	input wire [31:0] qstr_ext_i;
	output reg return_o;
	output reg ok_o;
	output wire idle_o;
	output reg [31:0] used_o;
	input wire [31:0] chk_addr_i;
	input wire chk_we_i;
	output wire busy_o;
	output wire req_o;
	output wire we_o;
	output wire [31:0] addr_o;
	output wire [31:0] wdata_o;
	output wire [3:0] wtag_o;
	input wire gnt_i;
	input wire ack_i;
	input wire fault_i;
	input wire [31:0] rdata_i;
	input wire [3:0] rtag_i;
	output reg fault_o;
	output reg [31:0] fault_addr_o;
	reg [2:0] state;
	wire ev;
	wire er;
	wire done;
	wire admitted;
	wire efallback;
	wire efault;
	wire eq;
	wire ew;
	wire [31:0] ea;
	wire [31:0] ed;
	wire [31:0] used;
	reg [31:0] header;
	reg [31:0] source_header;
	reg [31:0] src;
	reg [31:0] src_end;
	reg [31:0] dst;
	reg [31:0] dst_end;
	wire [3:0] et;
	reg [2:0] op;
	reg accepted;
	wire [1:0] sh_valid;
	wire [1:0] sh_result_ready;
	wire [1:0] sh_ack;
	wire [7:0] sh_tag;
	wire [63:0] sh_payload;
	wire hready;
	wire hvalid;
	wire herror;
	wire hreq;
	wire [31:0] hvalue;
	wire [31:0] haddr;
	reg [31:0] qcount;
	reg [31:0] qbase;
	reg [31:0] qext;
	wire select_stream = op == 0;
	mpy_hash #(.DEPTH(1)) shared_hash(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i && (state == 3'd1)),
		.valid_i((state == 3'd1) && sh_valid[select_stream]),
		.ready_o(hready),
		.tag_i(sh_tag[select_stream * 4+:4]),
		.payload_i(sh_payload[select_stream * 32+:32]),
		.qstr_count_i(qcount),
		.qstr_base_i(qbase),
		.qstr_ext_i(qext),
		.valid_o(hvalid),
		.ready_i((state == 3'd1) && sh_result_ready[select_stream]),
		.hash_o(hvalue),
		.error_o(herror),
		.mem_req_o(hreq),
		.mem_addr_o(haddr),
		.mem_ack_i(sh_ack[select_stream]),
		.mem_fault_i(fault_i),
		.mem_data_i(rdata_i),
		.mem_tag_i(rtag_i)
	);
	wire mdone;
	wire mfallback;
	wire mfault;
	wire mreq;
	wire mwe;
	wire [31:0] mused;
	wire [31:0] maddr;
	wire [31:0] mdata;
	wire [3:0] mtag;
	wire rdone;
	wire rfallback;
	wire rfault;
	wire rreq;
	wire rwe;
	wire [31:0] rused;
	wire [31:0] raddr;
	wire [31:0] rdata;
	reg [31:0] initial_used;
	reg [31:0] hashes;
	reg [31:0] hashes_end;
	wire [3:0] rtag;
	assign done = (op == 0 ? rdone : mdone);
	assign efallback = (op == 0 ? rfallback : mfallback);
	assign efault = (op == 0 ? rfault : mfault);
	assign used = (op == 0 ? rused + initial_used : mused);
	assign eq = (op == 0 ? rreq : mreq);
	assign ew = (op == 0 ? rwe : mwe);
	assign ea = (op == 0 ? raddr : maddr);
	assign ed = (op == 0 ? rdata : mdata);
	assign et = (op == 0 ? rtag : mtag);
	assign ready_o = (state == 3'd0) && !fault_o;
	assign idle_o = state == 3'd0;
	assign ev = valid_i && ready_o;
	assign req_o = (state == 3'd2) || ((state == 3'd1) && eq);
	assign we_o = (state == 3'd2) || ((state == 3'd1) && ew);
	assign addr_o = (state == 3'd2 ? header : ea);
	assign wdata_o = (state == 3'd2 ? used : ed);
	assign wtag_o = (state == 3'd2 ? 4'd1 : et);
	assign busy_o = (state != 3'd0) && ((((((chk_we_i && (hashes != 0)) && (chk_addr_i >= hashes)) && (chk_addr_i < hashes_end)) || ((chk_addr_i >= dst) && (chk_addr_i < dst_end))) || (((header != 0) && (chk_addr_i >= header)) && (chk_addr_i < (header + 16)))) || (chk_we_i && (((chk_addr_i >= src) && (chk_addr_i < src_end)) || (((source_header != 0) && (chk_addr_i >= source_header)) && (chk_addr_i < (source_header + 16))))));
	mpy_map_engine #(
		.EXTERNAL_HASH(1),
		.TYPE_CACHE(TYPE_CACHE)
	) engine(
		.cache_clear_i(cache_clear_i),
		.cache_write_i(cache_write_i),
		.cache_write2_i(cache_write2_i),
		.cache_addr_i(cache_addr_i),
		.cache_addr2_i(cache_addr2_i),
		.hash_valid_o(sh_valid[0]),
		.hash_ready_i((hready && (state == 3'd1)) && !select_stream),
		.hash_tag_o(sh_tag[0+:4]),
		.hash_payload_o(sh_payload[0+:32]),
		.hash_result_valid_i((hvalid && (state == 3'd1)) && !select_stream),
		.hash_result_ready_o(sh_result_ready[0]),
		.hash_value_i(hvalue),
		.hash_error_i(herror),
		.hash_mem_req_i((hreq && (state == 3'd1)) && !select_stream),
		.hash_mem_addr_i(haddr),
		.hash_mem_ack_o(sh_ack[0]),
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.valid_i(ev && (op_i != 0)),
		.ready_o(er),
		.op_i(op_i),
		.set_i(set_i),
		.src_i(src_i),
		.src_alloc_i(sn_i),
		.dst_i(dst_i),
		.dst_alloc_i(dn_i),
		.used_i(used_i),
		.hashes_i(32'd0),
		.qstr_count_i(qstr_count_i),
		.qstr_base_i(qstr_base_i),
		.qstr_ext_i(qstr_ext_i),
		.done_o(mdone),
		.admitted_o(admitted),
		.fallback_o(mfallback),
		.fault_o(mfault),
		.used_o(mused),
		.req_o(mreq),
		.we_o(mwe),
		.addr_o(maddr),
		.wdata_o(mdata),
		.wtag_o(mtag),
		.gnt_i((gnt_i && (state == 3'd1)) && (op != 0)),
		.ack_i((ack_i && (state == 3'd1)) && (op != 0)),
		.fault_i(fault_i),
		.mem_data_i(rdata_i),
		.mem_tag_i(rtag_i)
	);
	mpy_rehash_stream #(.EXTERNAL_HASH(1)) rehash(
		.hash_valid_o(sh_valid[1]),
		.hash_ready_i((hready && (state == 3'd1)) && (select_stream == 1'b1)),
		.hash_tag_o(sh_tag[4+:4]),
		.hash_payload_o(sh_payload[32+:32]),
		.hash_result_valid_i((hvalid && (state == 3'd1)) && (select_stream == 1'b1)),
		.hash_result_ready_o(sh_result_ready[1]),
		.hash_value_i(hvalue),
		.hash_error_i(herror),
		.hash_mem_req_i((hreq && (state == 3'd1)) && (select_stream == 1'b1)),
		.hash_mem_addr_i(haddr),
		.hash_mem_ack_o(sh_ack[1]),
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.valid_i(ev && (op_i == 0)),
		.ready_o(),
		.set_i(set_i),
		.src_i(src_i),
		.sn_i(sn_i),
		.dst_i(dst_i),
		.dn_i(dn_i),
		.hashes_i(hashes_i),
		.qstr_count_i(qstr_count_i),
		.qstr_base_i(qstr_base_i),
		.qstr_ext_i(qstr_ext_i),
		.done_o(rdone),
		.fallback_o(rfallback),
		.fault_o(rfault),
		.used_o(rused),
		.req_o(rreq),
		.we_o(rwe),
		.addr_o(raddr),
		.wdata_o(rdata),
		.wtag_o(rtag),
		.gnt_i((gnt_i && (state == 3'd1)) && (op == 0)),
		.ack_i((ack_i && (state == 3'd1)) && (op == 0)),
		.fault_i(fault_i),
		.rdata_i(rdata_i),
		.rtag_i(rtag_i)
	);
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			state <= 3'd0;
			return_o <= 0;
			ok_o <= 0;
			fault_o <= 0;
			fault_addr_o <= 0;
			qcount <= 0;
			qbase <= 0;
			qext <= 0;
			initial_used <= 0;
			hashes <= 0;
			hashes_end <= 0;
			header <= 0;
			source_header <= 0;
			src <= 0;
			src_end <= 0;
			dst <= 0;
			dst_end <= 0;
			op <= 0;
			accepted <= 0;
			used_o <= 0;
		end
		else begin
			return_o <= 0;
			case (state)
				3'd0:
					if (ev) begin
						initial_used <= used_i;
						hashes <= hashes_i;
						hashes_end <= hashes_i + (sn_i << 2);
						qcount <= qstr_count_i;
						qbase <= qstr_base_i;
						qext <= qstr_ext_i;
						state <= 3'd1;
						op <= op_i;
						header <= header_i;
						source_header <= source_header_i;
						src <= src_i;
						src_end <= src_i + (sn_i << (set_i ? 2 : 3));
						dst <= dst_i;
						dst_end <= dst_i + (dn_i << (set_i ? 2 : 3));
						accepted <= 0;
					end
				3'd1: begin
					if (admitted && (op < 5)) begin
						return_o <= 1;
						ok_o <= 1;
						accepted <= 1;
					end
					if (done) begin
						used_o <= used;
						if (efault) begin
							fault_o <= 1;
							fault_addr_o <= ea;
						end
						if (!accepted) begin
							return_o <= 1;
							ok_o <= !efallback && !efault;
						end
						if (((!efallback && !efault) && (header != 0)) && (op < 5))
							state <= 3'd2;
						else
							state <= 3'd0;
					end
				end
				3'd2:
					if (gnt_i)
						state <= 3'd3;
				3'd3:
					if (ack_i) begin
						if (fault_i) begin
							fault_o <= 1;
							fault_addr_o <= header;
						end
						state <= 3'd0;
					end
				default: state <= 3'd0;
			endcase
		end
endmodule
module mpy_hash_slot (
	hash_valid_o,
	hash_ready_i,
	hash_tag_o,
	hash_payload_o,
	hash_result_valid_i,
	hash_result_ready_o,
	hash_value_i,
	hash_error_i,
	hash_mem_req_i,
	hash_mem_addr_i,
	hash_mem_ack_o,
	clk_i,
	rst_n_i,
	valid_i,
	ready_o,
	tag_i,
	payload_i,
	alloc_i,
	qstr_count_i,
	qstr_base_i,
	qstr_ext_i,
	valid_o,
	ready_i,
	slot_o,
	error_o,
	mem_req_o,
	mem_addr_o,
	mem_ack_i,
	mem_fault_i,
	mem_data_i,
	mem_tag_i
);
	parameter [0:0] EXTERNAL_HASH = 0;
	parameter integer BPC = 4;
	parameter integer DEPTH = 8;
	parameter integer BYTES_PER_CYCLE = 1;
	parameter [31:0] TUPLE_SEED = 32'd12345;
	parameter [31:0] FROZEN_SEED = 32'd54321;
	output wire hash_valid_o;
	input wire hash_ready_i;
	output wire [3:0] hash_tag_o;
	output wire [31:0] hash_payload_o;
	input wire hash_result_valid_i;
	output wire hash_result_ready_o;
	input wire [31:0] hash_value_i;
	input wire hash_error_i;
	input wire hash_mem_req_i;
	input wire [31:0] hash_mem_addr_i;
	output wire hash_mem_ack_o;
	input wire clk_i;
	input wire rst_n_i;
	input wire valid_i;
	output wire ready_o;
	input wire [3:0] tag_i;
	input wire [31:0] payload_i;
	input wire [31:0] alloc_i;
	input wire [31:0] qstr_count_i;
	input wire [31:0] qstr_base_i;
	input wire [31:0] qstr_ext_i;
	output reg valid_o;
	input wire ready_i;
	output reg [31:0] slot_o;
	output reg error_o;
	output wire mem_req_o;
	output wire [31:0] mem_addr_o;
	input wire mem_ack_i;
	input wire mem_fault_i;
	input wire [31:0] mem_data_i;
	input wire [3:0] mem_tag_i;
	wire hv;
	wire hr;
	wire he;
	wire launch;
	reg active;
	wire done;
	reg completed;
	reg stage_error;
	wire retire;
	wire [31:0] h;
	reg [31:0] alloc;
	wire [31:0] rem;
	assign hash_valid_o = valid_i;
	assign hash_tag_o = tag_i;
	assign hash_payload_o = payload_i;
	assign hash_result_ready_o = hr;
	assign hash_mem_ack_o = mem_ack_i;
	generate
		if (EXTERNAL_HASH) begin : shared_hash
			assign ready_o = hash_ready_i;
			assign hv = hash_result_valid_i;
			assign h = hash_value_i;
			assign he = hash_error_i;
			assign mem_req_o = hash_mem_req_i;
			assign mem_addr_o = hash_mem_addr_i;
		end
		else begin : private_hash
			mpy_hash #(
				.DEPTH(DEPTH),
				.BYTES_PER_CYCLE(BYTES_PER_CYCLE),
				.TUPLE_SEED(TUPLE_SEED),
				.FROZEN_SEED(FROZEN_SEED)
			) hash(
				.clk_i(clk_i),
				.rst_n_i(rst_n_i),
				.valid_i(valid_i),
				.ready_o(ready_o),
				.tag_i(tag_i),
				.payload_i(payload_i),
				.qstr_count_i(qstr_count_i),
				.qstr_base_i(qstr_base_i),
				.qstr_ext_i(qstr_ext_i),
				.valid_o(hv),
				.ready_i(hr),
				.hash_o(h),
				.error_o(he),
				.mem_req_o(mem_req_o),
				.mem_addr_o(mem_addr_o),
				.mem_ack_i(mem_ack_i),
				.mem_fault_i(mem_fault_i),
				.mem_data_i(mem_data_i),
				.mem_tag_i(mem_tag_i)
			);
		end
	endgenerate
	assign retire = (active && (completed || done)) && (!valid_o || ready_i);
	assign hr = !active || retire;
	assign launch = ((hv && hr) && !he) && (alloc != 0);
	upycore_umod_seq #(.BPC(BPC)) modulo(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.start_i(launch),
		.a_i(h),
		.d_i(alloc),
		.done_o(done),
		.rem_o(rem),
		.busy_o()
	);
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			alloc <= 0;
			active <= 0;
			completed <= 0;
			stage_error <= 0;
			valid_o <= 0;
			error_o <= 0;
			slot_o <= 0;
		end
		else begin
			if (valid_i && ready_o)
				alloc <= alloc_i;
			if (valid_o && ready_i)
				valid_o <= 0;
			if (done)
				completed <= 1;
			if (retire) begin
				active <= 0;
				valid_o <= 1;
				error_o <= stage_error;
				slot_o <= (stage_error ? 32'd0 : rem);
			end
			if (hv && hr) begin
				active <= 1;
				stage_error <= he || (alloc == 0);
				completed <= he || (alloc == 0);
			end
		end
endmodule
module mpy_rehash_stream (
	hash_valid_o,
	hash_ready_i,
	hash_tag_o,
	hash_payload_o,
	hash_result_valid_i,
	hash_result_ready_o,
	hash_value_i,
	hash_error_i,
	hash_mem_req_i,
	hash_mem_addr_i,
	hash_mem_ack_o,
	clk_i,
	rst_n_i,
	valid_i,
	ready_o,
	set_i,
	src_i,
	sn_i,
	dst_i,
	dn_i,
	hashes_i,
	qstr_count_i,
	qstr_base_i,
	qstr_ext_i,
	done_o,
	fallback_o,
	fault_o,
	used_o,
	req_o,
	we_o,
	addr_o,
	wdata_o,
	wtag_o,
	gnt_i,
	ack_i,
	fault_i,
	rdata_i,
	rtag_i
);
	reg _sv2v_0;
	parameter [0:0] EXTERNAL_HASH = 0;
	output wire hash_valid_o;
	input wire hash_ready_i;
	output wire [3:0] hash_tag_o;
	output wire [31:0] hash_payload_o;
	input wire hash_result_valid_i;
	output wire hash_result_ready_o;
	input wire [31:0] hash_value_i;
	input wire hash_error_i;
	input wire hash_mem_req_i;
	input wire [31:0] hash_mem_addr_i;
	output wire hash_mem_ack_o;
	input wire clk_i;
	input wire rst_n_i;
	input wire valid_i;
	output wire ready_o;
	input wire set_i;
	input wire [31:0] src_i;
	input wire [31:0] sn_i;
	input wire [31:0] dst_i;
	input wire [31:0] dn_i;
	input wire [31:0] hashes_i;
	input wire [31:0] qstr_count_i;
	input wire [31:0] qstr_base_i;
	input wire [31:0] qstr_ext_i;
	output reg done_o;
	output reg fallback_o;
	output reg fault_o;
	output reg [31:0] used_o;
	output reg req_o;
	output reg we_o;
	output reg [31:0] addr_o;
	output reg [31:0] wdata_o;
	output reg [3:0] wtag_o;
	input wire gnt_i;
	input wire ack_i;
	input wire fault_i;
	input wire [31:0] rdata_i;
	input wire [3:0] rtag_i;
	reg [2:0] ps;
	reg [2:0] cs;
	reg active;
	reg aborting;
	reg is_set;
	reg override_valid;
	reg [31:0] src;
	reg [31:0] sn;
	reg [31:0] dst;
	reg [31:0] dn;
	reg [31:0] hashes;
	reg [31:0] idx;
	reg [31:0] pos;
	reg [31:0] start_pos;
	reg [31:0] override_hash;
	reg [31:0] qcount;
	reg [31:0] qbase;
	reg [31:0] qext;
	reg [35:0] skey;
	reg [35:0] svalue;
	reg [35:0] ckey;
	reg [35:0] cvalue;
	reg [35:0] key_fifo [0:3];
	reg [35:0] value_fifo [0:3];
	reg [1:0] wp;
	reg [1:0] rp;
	reg [2:0] count;
	wire push;
	wire pop;
	wire hin;
	wire hready;
	wire hout;
	wire herror;
	wire hreq;
	wire hack;
	wire [31:0] slot;
	wire [31:0] haddr;
	wire sreq;
	wire sack;
	wire creq;
	wire cack;
	wire cwe;
	wire [31:0] saddr;
	wire [31:0] caddr;
	wire [31:0] cdata;
	wire [3:0] ctag;
	reg pending;
	reg [1:0] owner;
	reg [1:0] turn;
	reg [1:0] selected;
	reg found;
	reg [2:0] requests;
	assign ready_o = !active;
	assign hin = ((active && !aborting) && (ps == 3'd3)) && (count < 4);
	assign push = hin && hready;
	assign pop = ((active && !aborting) && (cs == 3'd0)) && hout;
	assign sreq = (active && !aborting) && (((((ps == 3'd0) && (idx < sn)) && (count < 4)) || (ps == 3'd1)) || (ps == 3'd2));
	assign saddr = (ps == 3'd2 ? hashes + (idx << 2) : (src + (idx << (is_set ? 2 : 3))) + (ps == 3'd1 ? 32'd4 : 32'd0));
	assign creq = (active && !aborting) && (cs != 3'd0);
	assign cwe = (cs == 3'd2) || (cs == 3'd3);
	assign caddr = (dst + (pos << (is_set ? 2 : 3))) + (cs == 3'd3 ? 32'd4 : 32'd0);
	assign {ctag, cdata} = (cs == 3'd3 ? cvalue : ckey);
	assign sack = (pending && (owner == 0)) && ack_i;
	assign hack = (pending && (owner == 1)) && ack_i;
	assign cack = (pending && (owner == 2)) && ack_i;
	localparam [3:0] ABI_TAG_INT = 4'd1;
	mpy_hash_slot #(
		.DEPTH(1),
		.EXTERNAL_HASH(EXTERNAL_HASH)
	) pipeline(
		.hash_valid_o(hash_valid_o),
		.hash_ready_i(hash_ready_i),
		.hash_tag_o(hash_tag_o),
		.hash_payload_o(hash_payload_o),
		.hash_result_valid_i(hash_result_valid_i),
		.hash_result_ready_o(hash_result_ready_o),
		.hash_value_i(hash_value_i),
		.hash_error_i(hash_error_i),
		.hash_mem_req_i(hash_mem_req_i),
		.hash_mem_addr_i(hash_mem_addr_i),
		.hash_mem_ack_o(hash_mem_ack_o),
		.clk_i(clk_i),
		.rst_n_i(rst_n_i && active),
		.valid_i(hin),
		.ready_o(hready),
		.tag_i((override_valid ? ABI_TAG_INT : skey[35:32])),
		.payload_i((override_valid ? override_hash : skey[31:0])),
		.alloc_i(dn),
		.qstr_count_i(qcount),
		.qstr_base_i(qbase),
		.qstr_ext_i(qext),
		.valid_o(hout),
		.ready_i((active && !aborting) && (cs == 3'd0)),
		.slot_o(slot),
		.error_o(herror),
		.mem_req_o(hreq),
		.mem_addr_o(haddr),
		.mem_ack_i(hack),
		.mem_fault_i(fault_i),
		.mem_data_i(rdata_i),
		.mem_tag_i(rtag_i)
	);
	localparam [31:0] ABI_CTL_NULL = 32'd0;
	localparam [31:0] ABI_CTL_TOMB = 32'd3;
	localparam [3:0] ABI_TAG_CONTROL = 4'd0;
	function automatic vacant;
		input reg [3:0] t;
		input reg [31:0] d;
		vacant = (t == ABI_TAG_CONTROL) && ((d == ABI_CTL_NULL) || (d == ABI_CTL_TOMB));
	endfunction
	localparam [3:0] ABI_TAG_MUT = 4'd10;
	localparam [3:0] ABI_TAG_OBJECT = 4'd14;
	localparam [3:0] ABI_TAG_TUPLE = 4'd9;
	function automatic callback_key;
		input reg [3:0] t;
		callback_key = ((t == ABI_TAG_OBJECT) || (t == ABI_TAG_TUPLE)) || (t == ABI_TAG_MUT);
	endfunction
	task automatic next_source;
		begin
			idx <= idx + 1;
			ps <= 3'd0;
		end
	endtask
	task automatic source_ready;
		if (hashes != 0)
			ps <= 3'd2;
		else if (callback_key(skey[35:32])) begin
			fallback_o <= 1;
			aborting <= 1;
		end
		else
			ps <= 3'd3;
	endtask
	task automatic retire_key;
		begin
			used_o <= used_o + 1;
			cs <= 3'd0;
		end
	endtask
	function automatic signed [1:0] sv2v_cast_2_signed;
		input reg signed [1:0] inp;
		sv2v_cast_2_signed = inp;
	endfunction
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		requests = {creq, hreq, sreq};
		selected = 0;
		found = 0;
		begin : sv2v_autoblock_1
			reg signed [31:0] off;
			for (off = 0; off < 3; off = off + 1)
				begin : sv2v_autoblock_2
					reg signed [31:0] k;
					k = sv2v_cast_32_signed(turn) + off;
					if (k >= 3)
						k = k - 3;
					if (!found && requests[k]) begin
						selected = sv2v_cast_2_signed(k);
						found = 1;
					end
				end
		end
	end
	function automatic [2:0] sv2v_cast_3;
		input reg [2:0] inp;
		sv2v_cast_3 = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			active <= 0;
			aborting <= 0;
			is_set <= 0;
			ps <= 3'd4;
			cs <= 3'd0;
			src <= 0;
			sn <= 0;
			dst <= 0;
			dn <= 0;
			hashes <= 0;
			idx <= 0;
			pos <= 0;
			start_pos <= 0;
			qcount <= 0;
			qbase <= 0;
			qext <= 0;
			skey <= 0;
			svalue <= 0;
			ckey <= 0;
			cvalue <= 0;
			override_valid <= 0;
			override_hash <= 0;
			wp <= 0;
			rp <= 0;
			count <= 0;
			begin : sv2v_autoblock_3
				reg signed [31:0] i;
				for (i = 0; i < 4; i = i + 1)
					begin
						key_fifo[i] <= 0;
						value_fifo[i] <= 0;
					end
			end
			pending <= 0;
			owner <= 0;
			turn <= 0;
			req_o <= 0;
			we_o <= 0;
			addr_o <= 0;
			wdata_o <= 0;
			wtag_o <= 0;
			done_o <= 0;
			fallback_o <= 0;
			fault_o <= 0;
			used_o <= 0;
		end
		else begin
			done_o <= 0;
			if (req_o && gnt_i)
				req_o <= 0;
			if (pending && ack_i) begin
				pending <= 0;
				if (fault_i) begin
					fault_o <= 1;
					aborting <= 1;
				end
			end
			if (((active && !aborting) && !pending) && found) begin
				pending <= 1;
				owner <= selected;
				turn <= (selected == 2 ? 2'd0 : selected + 1);
				req_o <= 1;
				we_o <= (selected == 2) && cwe;
				addr_o <= (selected == 0 ? saddr : (selected == 1 ? haddr : caddr));
				wdata_o <= cdata;
				wtag_o <= ctag;
			end
			if (!active && valid_i) begin
				active <= 1;
				aborting <= 0;
				is_set <= set_i;
				ps <= 3'd0;
				cs <= 3'd0;
				src <= src_i;
				sn <= sn_i;
				dst <= dst_i;
				dn <= dn_i;
				hashes <= hashes_i;
				idx <= 0;
				qcount <= qstr_count_i;
				qbase <= qstr_base_i;
				qext <= qstr_ext_i;
				wp <= 0;
				rp <= 0;
				count <= 0;
				used_o <= 0;
				fallback_o <= 0;
				fault_o <= 0;
				override_valid <= 0;
				if ((((src_i == dst_i) || (src_i[1:0] != 0)) || (dst_i[1:0] != 0)) || ((dn_i == 0) && (sn_i != 0))) begin
					aborting <= 1;
					fallback_o <= 1;
				end
			end
			else if (active) begin
				count <= (count + sv2v_cast_3(push)) - sv2v_cast_3(pop);
				if (!aborting) begin
					if ((ps == 3'd0) && (idx == sn))
						ps <= 3'd4;
					if (sack && !fault_i)
						case (ps)
							3'd0:
								if (vacant(rtag_i, rdata_i))
									next_source;
								else begin
									skey <= {rtag_i, rdata_i};
									override_valid <= 0;
									if (!is_set)
										ps <= 3'd1;
									else if (hashes != 0)
										ps <= 3'd2;
									else if (callback_key(rtag_i)) begin
										fallback_o <= 1;
										aborting <= 1;
									end
									else
										ps <= 3'd3;
								end
							3'd1: begin
								svalue <= {rtag_i, rdata_i};
								source_ready;
							end
							3'd2:
								if (rtag_i == ABI_TAG_INT) begin
									override_valid <= 1;
									override_hash <= rdata_i;
									ps <= 3'd3;
								end
								else if (callback_key(skey[35:32])) begin
									fallback_o <= 1;
									aborting <= 1;
								end
								else
									ps <= 3'd3;
							default:
								;
						endcase
					if (push) begin
						key_fifo[wp] <= skey;
						value_fifo[wp] <= svalue;
						wp <= wp + 1;
						next_source;
					end
					if (pop) begin
						rp <= rp + 1;
						if (herror) begin
							fallback_o <= 1;
							aborting <= 1;
						end
						else begin
							ckey <= key_fifo[rp];
							cvalue <= value_fifo[rp];
							pos <= slot;
							start_pos <= slot;
							cs <= 3'd1;
						end
					end
					if (cack && !fault_i)
						case (cs)
							3'd1:
								if (vacant(rtag_i, rdata_i))
									cs <= 3'd2;
								else if (((pos + 1) == dn ? 32'd0 : pos + 1) == start_pos) begin
									fallback_o <= 1;
									aborting <= 1;
								end
								else
									pos <= ((pos + 1) == dn ? 32'd0 : pos + 1);
							3'd2:
								if (is_set)
									retire_key;
								else
									cs <= 3'd3;
							3'd3:
								retire_key;
							default:
								;
						endcase
				end
				if (!pending && (aborting || (((ps == 3'd4) && (count == 0)) && (cs == 3'd0)))) begin
					active <= 0;
					done_o <= 1;
				end
			end
		end
	initial _sv2v_0 = 0;
endmodule
module mpy_bytecopy (
	clk_i,
	rst_n_i,
	valid_i,
	reverse_i,
	ready_o,
	idle_o,
	src_i,
	dst_i,
	n_i,
	req_o,
	we_o,
	addr_o,
	wdata_o,
	wtag_o,
	gnt_i,
	ack_i,
	fault_i,
	rdata_i,
	rtag_i,
	fault_o,
	fault_addr_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_n_i;
	input wire valid_i;
	input wire reverse_i;
	output wire ready_o;
	output wire idle_o;
	input wire [31:0] src_i;
	input wire [31:0] dst_i;
	input wire [31:0] n_i;
	output wire req_o;
	output wire we_o;
	output wire [31:0] addr_o;
	output reg [31:0] wdata_o;
	output reg [3:0] wtag_o;
	input wire gnt_i;
	input wire ack_i;
	input wire fault_i;
	input wire [31:0] rdata_i;
	input wire [3:0] rtag_i;
	output reg fault_o;
	output reg [31:0] fault_addr_o;
	reg [3:0] state;
	reg back;
	reg reverse_words;
	reg [31:0] left_data;
	reg [3:0] left_tag;
	reg [31:0] source;
	reg [31:0] dest;
	reg [31:0] remaining;
	reg [31:0] sa;
	reg [31:0] da;
	reg [31:0] piece;
	reg [31:0] mask;
	reg [2:0] group_n;
	reg [2:0] next_n;
	reg [2:0] src_room;
	reg [2:0] dst_room;
	reg [1:0] src_offset;
	reg [1:0] dst_offset;
	assign ready_o = (state == 4'd0) && !fault_o;
	assign idle_o = state == 4'd0;
	assign req_o = (((state == 4'd2) || (state == 4'd4)) || (state == 4'd6)) || (state == 4'd8);
	assign we_o = (state == 4'd6) || (state == 4'd8);
	assign addr_o = (((state == 4'd2) || (state == 4'd3)) || (reverse_words && ((state == 4'd6) || (state == 4'd7))) ? {sa[31:2], 2'b00} : {da[31:2], 2'b00});
	function automatic [1:0] sv2v_cast_2;
		input reg [1:0] inp;
		sv2v_cast_2 = inp;
	endfunction
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		src_offset = (back ? sv2v_cast_2(source - 1) : source[1:0]);
		dst_offset = (back ? sv2v_cast_2(dest - 1) : dest[1:0]);
		src_room = (back ? {1'b0, src_offset} + 3'd1 : 3'd4 - {1'b0, src_offset});
		dst_room = (back ? {1'b0, dst_offset} + 3'd1 : 3'd4 - {1'b0, dst_offset});
		next_n = (src_room < dst_room ? src_room : dst_room);
		if (remaining < sv2v_cast_32(next_n))
			next_n = remaining[2:0];
	end
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			state <= 4'd0;
			back <= 0;
			reverse_words <= 0;
			left_data <= 0;
			left_tag <= 0;
			source <= 0;
			dest <= 0;
			remaining <= 0;
			sa <= 0;
			da <= 0;
			piece <= 0;
			mask <= 0;
			group_n <= 0;
			wdata_o <= 0;
			wtag_o <= 0;
			fault_o <= 0;
			fault_addr_o <= 0;
		end
		else if (ack_i && fault_i) begin
			fault_o <= 1;
			fault_addr_o <= addr_o;
			state <= 4'd0;
		end
		else
			case (state)
				4'd0:
					if (((valid_i && ready_o) && (n_i != 0)) && (!reverse_i || (n_i >= 8))) begin
						reverse_words <= reverse_i;
						back <= dst_i > src_i;
						source <= (!reverse_i && (dst_i > src_i) ? src_i + n_i : src_i);
						dest <= (reverse_i ? (dst_i + n_i) - 4 : (dst_i > src_i ? dst_i + n_i : dst_i));
						remaining <= (reverse_i ? n_i >> 3 : n_i);
						state <= 4'd1;
					end
				4'd1:
					if (reverse_words) begin
						sa <= source;
						da <= dest;
						state <= 4'd2;
					end
					else begin
						group_n <= next_n;
						sa <= (back ? source - sv2v_cast_32(next_n) : source);
						da <= (back ? dest - sv2v_cast_32(next_n) : dest);
						case (next_n)
							1: mask <= 32'h000000ff;
							2: mask <= 32'h0000ffff;
							3: mask <= 32'h00ffffff;
							default: mask <= 32'hffffffff;
						endcase
						state <= 4'd2;
					end
				4'd2:
					if (gnt_i)
						state <= 4'd3;
				4'd3:
					if (ack_i) begin
						left_data <= rdata_i;
						left_tag <= rtag_i;
						piece <= rdata_i >> (8 * sa[1:0]);
						state <= 4'd4;
					end
				4'd4:
					if (gnt_i)
						state <= 4'd5;
				4'd5:
					if (ack_i) begin
						wdata_o <= (reverse_words ? rdata_i : (rdata_i & ~(mask << (8 * da[1:0]))) | ((piece & mask) << (8 * da[1:0])));
						wtag_o <= rtag_i;
						state <= 4'd6;
					end
				4'd6:
					if (gnt_i)
						state <= 4'd7;
				4'd7:
					if (ack_i && reverse_words) begin
						wdata_o <= left_data;
						wtag_o <= left_tag;
						state <= 4'd8;
					end
					else if (ack_i) begin
						remaining <= remaining - sv2v_cast_32(group_n);
						source <= (back ? source - sv2v_cast_32(group_n) : source + sv2v_cast_32(group_n));
						dest <= (back ? dest - sv2v_cast_32(group_n) : dest + sv2v_cast_32(group_n));
						state <= (remaining == sv2v_cast_32(group_n) ? 4'd0 : 4'd1);
					end
				4'd8:
					if (gnt_i)
						state <= 4'd9;
				4'd9:
					if (ack_i) begin
						remaining <= remaining - 1;
						source <= source + 4;
						dest <= dest - 4;
						state <= (remaining == 1 ? 4'd0 : 4'd1);
					end
				default: state <= 4'd0;
			endcase
	initial _sv2v_0 = 0;
endmodule
module mpy_shortlist (
	clk_i,
	rst_n_i,
	valid_i,
	ready_o,
	src_i,
	dst_i,
	n_i,
	reverse_i,
	clear_i,
	clear_addr_i,
	put_i,
	put_addr_i,
	put_value_i,
	length_i,
	header_i,
	new_length_i,
	response_o,
	response_ready_i,
	idle_o,
	chk_addr_i,
	chk_we_i,
	chk_busy_o,
	req_o,
	we_o,
	addr_o,
	wdata_o,
	wtag_o,
	gnt_i,
	ack_i,
	fault_i,
	fault_reason_i,
	rdata_i,
	rtag_i,
	fault_o,
	fault_addr_o,
	fault_reason_o
);
	reg _sv2v_0;
	parameter signed [31:0] MAX_ELEMS = 16;
	input wire clk_i;
	input wire rst_n_i;
	input wire valid_i;
	output reg ready_o;
	input wire [31:0] src_i;
	input wire [31:0] dst_i;
	input wire [31:0] n_i;
	input wire reverse_i;
	input wire clear_i;
	input wire [31:0] clear_addr_i;
	input wire put_i;
	input wire [31:0] put_addr_i;
	input wire [35:0] put_value_i;
	input wire length_i;
	input wire [31:0] header_i;
	input wire [31:0] new_length_i;
	output reg response_o;
	input wire response_ready_i;
	output reg idle_o;
	input wire [31:0] chk_addr_i;
	input wire chk_we_i;
	output reg chk_busy_o;
	output reg req_o;
	output reg we_o;
	output reg [31:0] addr_o;
	output reg [31:0] wdata_o;
	output reg [3:0] wtag_o;
	input wire gnt_i;
	input wire ack_i;
	input wire fault_i;
	input wire [3:0] fault_reason_i;
	input wire [31:0] rdata_i;
	input wire [3:0] rtag_i;
	output reg fault_o;
	output reg [31:0] fault_addr_o;
	output reg [3:0] fault_reason_o;
	localparam signed [31:0] CW = $clog2(MAX_ELEMS + 1);
	localparam signed [31:0] IW = (MAX_ELEMS > 1 ? $clog2(MAX_ELEMS) : 1);
	reg [3:0] st;
	reg [35:0] buffer [0:MAX_ELEMS - 1];
	reg [CW - 1:0] count;
	reg [CW - 1:0] issued;
	reg [CW - 1:0] acked;
	reg [31:0] src;
	reg [31:0] dst;
	reg [31:0] read_addr;
	reg [31:0] write_addr;
	reg [31:0] clear_addr;
	reg [31:0] put_addr;
	reg [31:0] header;
	reg [31:0] new_length;
	reg reverse_words;
	reg clear_tail;
	reg put_value;
	reg write_length;
	reg [35:0] value;
	reg [32:0] source_end;
	reg [32:0] source_low;
	reg [32:0] dest_end;
	reg [32:0] header_end;
	reg [32:0] cmd_span;
	reg [32:0] cmd_low;
	reg [32:0] cmd_high;
	reg [32:0] cmd_dst_end;
	localparam [31:0] ABI_CTL_NULL = 32'd0;
	localparam [3:0] MPY_TAG_CONTROL = 4'b0000;
	localparam [3:0] MPY_TAG_INT = 4'b0001;
	function automatic [IW - 1:0] sv2v_cast_83959;
		input reg [IW - 1:0] inp;
		sv2v_cast_83959 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		cmd_span = (n_i == 0 ? 33'd0 : ({1'b0, n_i} - 33'd1) << 2);
		cmd_low = (reverse_i ? {1'b0, src_i} - cmd_span : {1'b0, src_i});
		cmd_high = (reverse_i ? {1'b0, src_i} + 33'd4 : {1'b0, src_i} + ({1'b0, n_i} << 2));
		cmd_dst_end = {1'b0, dst_i} + ({1'b0, n_i} << 2);
		ready_o = st == 4'd0;
		idle_o = st == 4'd0;
		response_o = st == 4'd9;
		req_o = (((((st == 4'd1) || (st == 4'd2)) && (issued != count)) || (st == 4'd3)) || (st == 4'd5)) || (st == 4'd7);
		we_o = st != 4'd1;
		addr_o = read_addr;
		wdata_o = 32'd0;
		wtag_o = 4'd0;
		case (st)
			4'd2: begin
				addr_o = write_addr;
				wdata_o = buffer[sv2v_cast_83959(issued)][31:0];
				wtag_o = buffer[sv2v_cast_83959(issued)][35:32];
			end
			4'd3, 4'd4: begin
				addr_o = clear_addr;
				wdata_o = ABI_CTL_NULL;
				wtag_o = MPY_TAG_CONTROL;
			end
			4'd5, 4'd6: begin
				addr_o = put_addr;
				wdata_o = value[31:0];
				wtag_o = value[35:32];
			end
			4'd7, 4'd8: begin
				addr_o = header;
				wdata_o = new_length;
				wtag_o = MPY_TAG_INT;
			end
			default:
				;
		endcase
		chk_busy_o = 0;
		if (st != 4'd0) begin
			if (({1'b0, chk_addr_i} >= {1'b0, dst}) && ({1'b0, chk_addr_i} < dest_end))
				chk_busy_o = 1;
			if ((chk_we_i && ({1'b0, chk_addr_i} >= source_low)) && ({1'b0, chk_addr_i} < source_end))
				chk_busy_o = 1;
			if (clear_tail && (chk_addr_i == clear_addr))
				chk_busy_o = 1;
			if (put_value && (chk_addr_i == put_addr))
				chk_busy_o = 1;
			if ((write_length && (chk_addr_i >= header)) && ({1'b0, chk_addr_i} < header_end))
				chk_busy_o = 1;
		end
	end
	task automatic finish_items;
		if (clear_tail)
			st <= 4'd3;
		else if (put_value)
			st <= 4'd5;
		else if (write_length)
			st <= 4'd7;
		else
			st <= 4'd9;
	endtask
	localparam [3:0] MPY_FAULT_BUS = 4'd3;
	function automatic [CW - 1:0] sv2v_cast_3D2D3;
		input reg [CW - 1:0] inp;
		sv2v_cast_3D2D3 = inp;
	endfunction
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			st <= 4'd0;
			count <= 0;
			issued <= 0;
			acked <= 0;
			src <= 0;
			dst <= 0;
			read_addr <= 0;
			write_addr <= 0;
			clear_addr <= 0;
			put_addr <= 0;
			header <= 0;
			new_length <= 0;
			reverse_words <= 0;
			clear_tail <= 0;
			put_value <= 0;
			write_length <= 0;
			value <= 0;
			source_low <= 0;
			source_end <= 0;
			dest_end <= 0;
			header_end <= 0;
			fault_o <= 0;
			fault_addr_o <= 0;
			fault_reason_o <= 0;
		end
		else
			case (st)
				4'd0:
					if (valid_i) begin
						src <= src_i;
						dst <= dst_i;
						count <= sv2v_cast_3D2D3(n_i);
						issued <= 0;
						acked <= 0;
						read_addr <= src_i;
						write_addr <= dst_i;
						reverse_words <= reverse_i;
						clear_tail <= clear_i;
						clear_addr <= clear_addr_i;
						put_value <= put_i;
						put_addr <= put_addr_i;
						value <= put_value_i;
						write_length <= length_i;
						header <= header_i;
						new_length <= new_length_i;
						header_end <= {1'b0, header_i} + 33'd12;
						source_low <= (n_i == 0 ? 33'd0 : cmd_low);
						source_end <= (n_i == 0 ? 33'd0 : cmd_high);
						dest_end <= cmd_dst_end;
						if (((((n_i > MAX_ELEMS) || ((n_i != 0) && (((((src_i[1:0] != 0) || (dst_i[1:0] != 0)) || cmd_low[32]) || cmd_high[32]) || cmd_dst_end[32]))) || (clear_i && (clear_addr_i[1:0] != 0))) || (put_i && (put_addr_i[1:0] != 0))) || (length_i && ((header_i[1:0] != 0) || (header_i > 32'hfffffff3)))) begin
							fault_o <= 1;
							fault_addr_o <= src_i;
							fault_reason_o <= MPY_FAULT_BUS;
							st <= 4'd10;
						end
						else if (n_i != 0)
							st <= 4'd1;
						else if (clear_i)
							st <= 4'd3;
						else if (put_i)
							st <= 4'd5;
						else if (length_i)
							st <= 4'd7;
						else
							st <= 4'd9;
					end
				4'd1: begin
					if (gnt_i && (issued != count)) begin
						issued <= issued + 1'b1;
						read_addr <= (reverse_words ? read_addr - 32'd4 : read_addr + 32'd4);
					end
					if (ack_i) begin
						if (fault_i) begin
							fault_o <= 1;
							fault_reason_o <= fault_reason_i;
							st <= 4'd10;
							fault_addr_o <= (reverse_words ? src - (sv2v_cast_32(acked) << 2) : src + (sv2v_cast_32(acked) << 2));
						end
						else begin
							buffer[sv2v_cast_83959(acked)] <= {rtag_i, rdata_i};
							acked <= acked + 1'b1;
							if ((acked + 1'b1) == count) begin
								issued <= 0;
								acked <= 0;
								st <= 4'd2;
							end
						end
					end
				end
				4'd2: begin
					if (gnt_i && (issued != count)) begin
						issued <= issued + 1'b1;
						write_addr <= write_addr + 32'd4;
					end
					if (ack_i) begin
						if (fault_i) begin
							fault_o <= 1;
							fault_reason_o <= fault_reason_i;
							st <= 4'd10;
							fault_addr_o <= dst + (sv2v_cast_32(acked) << 2);
						end
						else begin
							acked <= acked + 1'b1;
							if ((acked + 1'b1) == count)
								finish_items;
						end
					end
				end
				4'd3:
					if (gnt_i)
						st <= 4'd4;
				4'd4:
					if (ack_i) begin
						if (fault_i) begin
							fault_o <= 1;
							fault_addr_o <= clear_addr;
							fault_reason_o <= fault_reason_i;
							st <= 4'd10;
						end
						else if (put_value)
							st <= 4'd5;
						else if (write_length)
							st <= 4'd7;
						else
							st <= 4'd9;
					end
				4'd5:
					if (gnt_i)
						st <= 4'd6;
				4'd6:
					if (ack_i) begin
						if (fault_i) begin
							fault_o <= 1;
							fault_addr_o <= put_addr;
							fault_reason_o <= fault_reason_i;
							st <= 4'd10;
						end
						else if (write_length)
							st <= 4'd7;
						else
							st <= 4'd9;
					end
				4'd7:
					if (gnt_i)
						st <= 4'd8;
				4'd8:
					if (ack_i) begin
						if (fault_i) begin
							fault_o <= 1;
							fault_addr_o <= header;
							fault_reason_o <= fault_reason_i;
							st <= 4'd10;
						end
						else
							st <= 4'd9;
					end
				4'd9:
					if (response_ready_i)
						st <= 4'd0;
				4'd10:
					;
				default: st <= 4'd10;
			endcase
	initial _sv2v_0 = 0;
endmodule
module mpy_collection (
	cache_clear_i,
	cache_write_i,
	cache_addr_i,
	clk_i,
	rst_n_i,
	sl_valid_i,
	sl_ready_o,
	sl_src_i,
	sl_dst_i,
	sl_n_i,
	sl_reverse_i,
	sl_clear_i,
	sl_put_i,
	sl_length_i,
	sl_clear_addr_i,
	sl_put_addr_i,
	sl_header_i,
	sl_new_length_i,
	sl_put_value_i,
	sl_response_o,
	sl_response_ready_i,
	copy_valid_i,
	copy_byte_i,
	copy_reverse_i,
	copy_ready_o,
	copy_src_i,
	copy_dst_i,
	copy_n_i,
	bulk_valid_i,
	bulk_ready_o,
	bulk_op_i,
	bulk_set_i,
	bulk_src_i,
	bulk_sn_i,
	bulk_dst_i,
	bulk_dn_i,
	bulk_used_i,
	bulk_header_i,
	bulk_source_header_i,
	bulk_hashes_i,
	qstr_count_i,
	qstr_base_i,
	qstr_ext_i,
	bulk_return_o,
	bulk_ok_o,
	bulk_used_o,
	idle_o,
	chk_addr_i,
	chk_we_i,
	chk_busy_o,
	req_o,
	we_o,
	addr_o,
	wdata_o,
	wtag_o,
	gnt_i,
	ack_i,
	fault_i,
	fault_reason_i,
	rdata_i,
	rtag_i,
	fault_o,
	fault_reason_o,
	fault_addr_o,
	words_o,
	cmds_o
);
	reg _sv2v_0;
	parameter [0:0] TYPE_CACHE = 0;
	parameter signed [31:0] SHORTLIST_MAX = 16;
	input wire cache_clear_i;
	input wire cache_write_i;
	input wire [31:0] cache_addr_i;
	input wire clk_i;
	input wire rst_n_i;
	input wire sl_valid_i;
	output wire sl_ready_o;
	input wire [31:0] sl_src_i;
	input wire [31:0] sl_dst_i;
	input wire [31:0] sl_n_i;
	input wire sl_reverse_i;
	input wire sl_clear_i;
	input wire sl_put_i;
	input wire sl_length_i;
	input wire [31:0] sl_clear_addr_i;
	input wire [31:0] sl_put_addr_i;
	input wire [31:0] sl_header_i;
	input wire [31:0] sl_new_length_i;
	input wire [35:0] sl_put_value_i;
	output wire sl_response_o;
	input wire sl_response_ready_i;
	input wire copy_valid_i;
	input wire copy_byte_i;
	input wire copy_reverse_i;
	output wire copy_ready_o;
	input wire [31:0] copy_src_i;
	input wire [31:0] copy_dst_i;
	input wire [31:0] copy_n_i;
	input wire bulk_valid_i;
	output wire bulk_ready_o;
	input wire [2:0] bulk_op_i;
	input wire bulk_set_i;
	input wire [31:0] bulk_src_i;
	input wire [31:0] bulk_sn_i;
	input wire [31:0] bulk_dst_i;
	input wire [31:0] bulk_dn_i;
	input wire [31:0] bulk_used_i;
	input wire [31:0] bulk_header_i;
	input wire [31:0] bulk_source_header_i;
	input wire [31:0] bulk_hashes_i;
	input wire [31:0] qstr_count_i;
	input wire [31:0] qstr_base_i;
	input wire [31:0] qstr_ext_i;
	output wire bulk_return_o;
	output wire bulk_ok_o;
	output wire [31:0] bulk_used_o;
	output wire idle_o;
	input wire [31:0] chk_addr_i;
	input wire chk_we_i;
	output reg chk_busy_o;
	output wire req_o;
	output wire we_o;
	output wire [31:0] addr_o;
	output wire [31:0] wdata_o;
	output wire [3:0] wtag_o;
	input wire gnt_i;
	input wire ack_i;
	input wire fault_i;
	input wire [3:0] fault_reason_i;
	input wire [31:0] rdata_i;
	input wire [3:0] rtag_i;
	output wire fault_o;
	output wire [3:0] fault_reason_o;
	output wire [31:0] fault_addr_o;
	output wire [31:0] words_o;
	output wire [31:0] cmds_o;
	reg [585:0] queue [0:1];
	reg [1:0] occupied;
	reg head;
	wire tail;
	reg running;
	reg owner_bulk;
	reg owner_byte;
	wire by_launch;
	wire by_ready;
	wire by_idle;
	wire by_req;
	wire by_we;
	wire by_fault;
	wire [31:0] by_addr;
	wire [31:0] by_data;
	wire [31:0] by_fault_addr;
	wire [3:0] by_tag;
	reg [1:0] count;
	wire push;
	wire pop;
	wire dispatch;
	wire cp_launch;
	wire bm_launch;
	wire cp_ready;
	wire cp_idle;
	wire cp_busy;
	wire cp_req;
	wire cp_we;
	wire cp_fault;
	wire bm_ready;
	wire bm_idle;
	wire bm_req;
	wire bm_we;
	wire bm_fault;
	wire [31:0] cp_addr;
	wire [31:0] cp_data;
	wire [31:0] cp_fault_addr;
	wire [31:0] bm_addr;
	wire [31:0] bm_data;
	wire [31:0] bm_fault_addr;
	wire [3:0] cp_tag;
	wire [3:0] cp_reason;
	wire [3:0] bm_tag;
	wire sl_idle;
	wire sl_req;
	wire sl_we;
	wire sl_fault;
	wire sl_lock;
	wire [31:0] sl_addr;
	wire [31:0] sl_data;
	wire [31:0] sl_faddr;
	wire [3:0] sl_tag;
	wire [3:0] sl_reason;
	wire legacy_idle;
	wire [585:0] current;
	assign current = queue[head];
	assign tail = head ^ count[0];
	assign copy_ready_o = ((((count < 2) && !fault_o) && !bulk_valid_i) && sl_idle) && !sl_valid_i;
	assign bulk_ready_o = (((count < 2) && !fault_o) && sl_idle) && !sl_valid_i;
	assign push = (copy_valid_i && copy_ready_o) || (bulk_valid_i && bulk_ready_o);
	assign dispatch = ((count != 0) && !running) && !fault_o;
	assign cp_launch = ((dispatch && !current[585]) && !current[583]) && cp_ready;
	assign by_launch = ((dispatch && !current[585]) && current[583]) && by_ready;
	assign bm_launch = (dispatch && current[585]) && bm_ready;
	assign pop = (running && (owner_bulk ? bm_idle : (owner_byte ? by_idle : cp_idle))) && !fault_o;
	assign legacy_idle = ((((count == 0) && !running) && cp_idle) && bm_idle) && by_idle;
	assign sl_ready_o = (legacy_idle && sl_idle) && !fault_o;
	assign idle_o = (legacy_idle && sl_idle) && !sl_valid_i;
	assign req_o = (!sl_idle ? sl_req : !fault_o && (owner_bulk ? bm_req : (owner_byte ? by_req : cp_req)));
	assign we_o = (!sl_idle ? sl_we : (owner_bulk ? bm_we : (owner_byte ? by_we : cp_we)));
	assign addr_o = (!sl_idle ? sl_addr : (owner_bulk ? bm_addr : (owner_byte ? by_addr : cp_addr)));
	assign wdata_o = (!sl_idle ? sl_data : (owner_bulk ? bm_data : (owner_byte ? by_data : cp_data)));
	assign wtag_o = (!sl_idle ? sl_tag : (owner_bulk ? bm_tag : (owner_byte ? by_tag : cp_tag)));
	assign fault_o = ((cp_fault || bm_fault) || by_fault) || sl_fault;
	assign fault_addr_o = (sl_fault ? sl_faddr : (bm_fault ? bm_fault_addr : (by_fault ? by_fault_addr : cp_fault_addr)));
	localparam [3:0] MPY_FAULT_BUS = 4'd3;
	assign fault_reason_o = (sl_fault ? sl_reason : (bm_fault || by_fault ? MPY_FAULT_BUS : cp_reason));
	function automatic signed [0:0] sv2v_cast_1_signed;
		input reg signed [0:0] inp;
		sv2v_cast_1_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		chk_busy_o = cp_busy || sl_lock;
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < 2; i = i + 1)
				if (occupied[i] && !(((running && !owner_bulk) && !owner_byte) && (head == sv2v_cast_1_signed(i)))) begin
					if ((chk_addr_i >= queue[i][226-:32]) && (chk_addr_i < queue[i][290-:32]))
						chk_busy_o = 1;
					if ((chk_we_i && (chk_addr_i >= queue[i][258-:32])) && (chk_addr_i < queue[i][322-:32]))
						chk_busy_o = 1;
					if (((chk_we_i && queue[i][98]) && (chk_addr_i >= queue[i][354-:32])) && (chk_addr_i < queue[i][194-:32]))
						chk_busy_o = 1;
					if ((queue[i][97] && (chk_addr_i >= queue[i][418-:32])) && (chk_addr_i < queue[i][162-:32]))
						chk_busy_o = 1;
					if (((chk_we_i && queue[i][96]) && (chk_addr_i >= queue[i][386-:32])) && (chk_addr_i < queue[i][130-:32]))
						chk_busy_o = 1;
				end
		end
	end
	function automatic [1:0] sv2v_cast_2;
		input reg [1:0] inp;
		sv2v_cast_2 = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			occupied <= 0;
			head <= 0;
			count <= 0;
			running <= 0;
			owner_bulk <= 0;
			owner_byte <= 0;
			begin : sv2v_autoblock_2
				reg signed [31:0] i;
				for (i = 0; i < 2; i = i + 1)
					queue[i] <= 1'sb0;
			end
		end
		else begin
			if (push) begin
				occupied[tail] <= 1;
				queue[tail][585] <= bulk_valid_i;
				queue[tail][582] <= copy_reverse_i;
				queue[tail][583] <= !bulk_valid_i && copy_byte_i;
				queue[tail][584] <= bulk_set_i;
				queue[tail][581-:3] <= bulk_op_i;
				queue[tail][578-:32] <= (bulk_valid_i ? bulk_src_i : copy_src_i);
				queue[tail][546-:32] <= (bulk_valid_i ? bulk_sn_i : copy_n_i);
				queue[tail][514-:32] <= (bulk_valid_i ? bulk_dst_i : copy_dst_i);
				queue[tail][482-:32] <= bulk_dn_i;
				queue[tail][450-:32] <= bulk_used_i;
				queue[tail][354-:32] <= (bulk_valid_i ? bulk_hashes_i : 32'd0);
				queue[tail][418-:32] <= (bulk_valid_i ? bulk_header_i : 32'd0);
				queue[tail][386-:32] <= (bulk_valid_i ? bulk_source_header_i : 32'd0);
				queue[tail][322-:32] <= (bulk_valid_i ? bulk_src_i + (bulk_sn_i << (bulk_set_i ? 2 : 3)) : (copy_byte_i ? ((copy_src_i + copy_n_i) + 3) & 32'hfffffffc : copy_src_i + (copy_n_i << 2)));
				queue[tail][290-:32] <= (bulk_valid_i ? bulk_dst_i + (bulk_dn_i << (bulk_set_i ? 2 : 3)) : (copy_byte_i ? ((copy_dst_i + copy_n_i) + 3) & 32'hfffffffc : copy_dst_i + (copy_n_i << 2)));
				queue[tail][258-:32] <= (bulk_valid_i ? bulk_src_i : (copy_byte_i ? {copy_src_i[31:2], 2'b00} : copy_src_i));
				queue[tail][226-:32] <= (bulk_valid_i ? bulk_dst_i : (copy_byte_i ? {copy_dst_i[31:2], 2'b00} : copy_dst_i));
				queue[tail][98] <= bulk_valid_i && (bulk_hashes_i != 0);
				queue[tail][97] <= bulk_valid_i && (bulk_header_i != 0);
				queue[tail][96] <= bulk_valid_i && (bulk_source_header_i != 0);
				queue[tail][194-:32] <= bulk_hashes_i + (bulk_sn_i << 2);
				queue[tail][162-:32] <= bulk_header_i + 32'd16;
				queue[tail][130-:32] <= bulk_source_header_i + 32'd16;
				queue[tail][95-:32] <= qstr_count_i;
				queue[tail][63-:32] <= qstr_base_i;
				queue[tail][31-:32] <= qstr_ext_i;
			end
			if ((cp_launch || bm_launch) || by_launch) begin
				running <= 1;
				owner_bulk <= current[585];
				owner_byte <= current[583];
			end
			if (pop) begin
				occupied[head] <= 0;
				head <= !head;
				running <= 0;
			end
			count <= (count + sv2v_cast_2(push)) - sv2v_cast_2(pop);
			if (fault_o) begin
				occupied <= 0;
				count <= 0;
				running <= 0;
			end
		end
	mpy_shortlist #(.MAX_ELEMS(SHORTLIST_MAX)) short_engine(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.valid_i((sl_valid_i && legacy_idle) && !fault_o),
		.ready_o(),
		.src_i(sl_src_i),
		.dst_i(sl_dst_i),
		.n_i(sl_n_i),
		.reverse_i(sl_reverse_i),
		.clear_i(sl_clear_i),
		.clear_addr_i(sl_clear_addr_i),
		.put_i(sl_put_i),
		.put_addr_i(sl_put_addr_i),
		.put_value_i(sl_put_value_i),
		.length_i(sl_length_i),
		.header_i(sl_header_i),
		.new_length_i(sl_new_length_i),
		.response_o(sl_response_o),
		.response_ready_i(sl_response_ready_i),
		.idle_o(sl_idle),
		.chk_addr_i(chk_addr_i),
		.chk_we_i(chk_we_i),
		.chk_busy_o(sl_lock),
		.req_o(sl_req),
		.we_o(sl_we),
		.addr_o(sl_addr),
		.wdata_o(sl_data),
		.wtag_o(sl_tag),
		.gnt_i(gnt_i && !sl_idle),
		.ack_i(ack_i && !sl_idle),
		.fault_i(fault_i),
		.fault_reason_i(fault_reason_i),
		.rdata_i(rdata_i),
		.rtag_i(rtag_i),
		.fault_o(sl_fault),
		.fault_addr_o(sl_faddr),
		.fault_reason_o(sl_reason)
	);
	mpy_ca #(.QDEPTH(1)) copy_engine(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.cmd_valid_i(cp_launch),
		.cmd_ready_o(cp_ready),
		.cmd_src_i(current[578-:32]),
		.cmd_dst_i(current[514-:32]),
		.cmd_n_i(current[546-:32]),
		.idle_o(cp_idle),
		.chk_addr_i(chk_addr_i),
		.chk_we_i(chk_we_i),
		.chk_busy_o(cp_busy),
		.req_o(cp_req),
		.we_o(cp_we),
		.addr_o(cp_addr),
		.wdata_o(cp_data),
		.wtag_o(cp_tag),
		.gnt_i(((gnt_i && !owner_bulk) && !owner_byte) && sl_idle),
		.ack_i(((ack_i && !owner_bulk) && !owner_byte) && sl_idle),
		.fault_i(fault_i),
		.fault_reason_i(fault_reason_i),
		.rdata_i(rdata_i),
		.rtag_i(rtag_i),
		.fault_o(cp_fault),
		.fault_reason_o(cp_reason),
		.fault_addr_o(cp_fault_addr),
		.words_o(words_o),
		.cmds_o(cmds_o)
	);
	mpy_bytecopy byte_engine(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.valid_i(by_launch),
		.ready_o(by_ready),
		.idle_o(by_idle),
		.src_i(current[578-:32]),
		.dst_i(current[514-:32]),
		.n_i(current[546-:32]),
		.reverse_i(current[582]),
		.req_o(by_req),
		.we_o(by_we),
		.addr_o(by_addr),
		.wdata_o(by_data),
		.wtag_o(by_tag),
		.gnt_i(((gnt_i && owner_byte) && !owner_bulk) && sl_idle),
		.ack_i(((ack_i && owner_byte) && !owner_bulk) && sl_idle),
		.fault_i(fault_i),
		.rdata_i(rdata_i),
		.rtag_i(rtag_i),
		.fault_o(by_fault),
		.fault_addr_o(by_fault_addr)
	);
	mpy_bulk #(.TYPE_CACHE(TYPE_CACHE)) bulk_engine(
		.cache_clear_i(cache_clear_i),
		.cache_write_i(cache_write_i),
		.cache_addr_i(cache_addr_i),
		.cache_write2_i((req_o && gnt_i) && we_o),
		.cache_addr2_i(addr_o),
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.valid_i(bm_launch),
		.ready_o(bm_ready),
		.op_i(current[581-:3]),
		.set_i(current[584]),
		.src_i(current[578-:32]),
		.sn_i(current[546-:32]),
		.dst_i(current[514-:32]),
		.dn_i(current[482-:32]),
		.used_i(current[450-:32]),
		.header_i(current[418-:32]),
		.source_header_i(current[386-:32]),
		.hashes_i(current[354-:32]),
		.qstr_count_i(current[95-:32]),
		.qstr_base_i(current[63-:32]),
		.qstr_ext_i(current[31-:32]),
		.return_o(bulk_return_o),
		.ok_o(bulk_ok_o),
		.idle_o(bm_idle),
		.used_o(bulk_used_o),
		.chk_addr_i(chk_addr_i),
		.chk_we_i(chk_we_i),
		.busy_o(),
		.req_o(bm_req),
		.we_o(bm_we),
		.addr_o(bm_addr),
		.wdata_o(bm_data),
		.wtag_o(bm_tag),
		.gnt_i((gnt_i && owner_bulk) && sl_idle),
		.ack_i((ack_i && owner_bulk) && sl_idle),
		.fault_i(fault_i),
		.rdata_i(rdata_i),
		.rtag_i(rtag_i),
		.fault_o(bm_fault),
		.fault_addr_o(bm_fault_addr)
	);
	initial _sv2v_0 = 0;
endmodule
module mpy_mem (
	clk_i,
	rst_n_i,
	image_words_i,
	req_i,
	we_i,
	tag_we_i,
	be_i,
	addr_i,
	wdata_i,
	wtag_i,
	gnt_o,
	ack_o,
	rdata_o,
	rtag_o,
	fault_o,
	fault_reason_o,
	ld_we_i,
	ld_idx_i,
	ld_wdata_i,
	ld_wtag_i,
	init_done_o
);
	reg _sv2v_0;
	parameter signed [31:0] NP = 3;
	localparam signed [31:0] MPY_FLASH_WAIT_STATES = 0;
	parameter signed [31:0] FLASH_WAIT_STATES = MPY_FLASH_WAIT_STATES;
	localparam signed [31:0] MPY_SRAM_LATENCY = 1;
	parameter signed [31:0] SRAM_LATENCY = MPY_SRAM_LATENCY;
	input wire clk_i;
	input wire rst_n_i;
	input wire [31:0] image_words_i;
	input wire [NP - 1:0] req_i;
	input wire [NP - 1:0] we_i;
	input wire [NP - 1:0] tag_we_i;
	input wire [(NP * 4) - 1:0] be_i;
	input wire [(NP * 32) - 1:0] addr_i;
	input wire [(NP * 32) - 1:0] wdata_i;
	input wire [(NP * 4) - 1:0] wtag_i;
	output reg [NP - 1:0] gnt_o;
	output reg [NP - 1:0] ack_o;
	output reg [(NP * 32) - 1:0] rdata_o;
	output reg [(NP * 4) - 1:0] rtag_o;
	output reg [NP - 1:0] fault_o;
	output reg [(NP * 4) - 1:0] fault_reason_o;
	input wire ld_we_i;
	localparam signed [31:0] MPY_MEM_BLOCKS = 4;
	localparam signed [31:0] MPY_MEM_BLOCK_WORDS = 32768;
	localparam signed [31:0] MPY_MEM_WORDS = MPY_MEM_BLOCKS * MPY_MEM_BLOCK_WORDS;
	localparam signed [31:0] MPY_MEM_WORD_AW = $clog2(MPY_MEM_WORDS);
	localparam signed [31:0] MPY_FLASH_IDX_W = MPY_MEM_WORD_AW;
	input wire [MPY_FLASH_IDX_W - 1:0] ld_idx_i;
	input wire [31:0] ld_wdata_i;
	input wire [3:0] ld_wtag_i;
	output wire init_done_o;
	localparam signed [31:0] MPY_MEM_BLOCK_AW = 15;
	localparam signed [31:0] AW = MPY_MEM_BLOCK_AW;
	localparam signed [31:0] MPY_MEM_WIDTH = 36;
	localparam signed [31:0] W = MPY_MEM_WIDTH;
	localparam signed [31:0] NB = MPY_MEM_BLOCKS;
	localparam signed [31:0] BS = 2;
	localparam signed [31:0] SROWS = MPY_MEM_BLOCK_WORDS;
	localparam signed [31:0] CW = 15;
	reg [31:0] image_words;
	reg [31:0] data_words;
	wire [31:0] image_words_n;
	assign image_words_n = (image_words_i + 32'd7) & 32'hfffffff8;
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			image_words <= 32'd0;
			data_words <= MPY_MEM_WORDS;
		end
		else begin
			image_words <= image_words_n;
			data_words <= (image_words_n <= MPY_MEM_WORDS ? MPY_MEM_WORDS - image_words_n : 0);
		end
	reg blk_v [0:3];
	reg blk_w [0:3];
	reg [14:0] blk_addr [0:3];
	reg [35:0] blk_data [0:3];
	reg [35:0] blk_mask [0:3];
	wire [35:0] blk_q [0:3];
	genvar _gv_b_1;
	generate
		for (_gv_b_1 = 0; _gv_b_1 < NB; _gv_b_1 = _gv_b_1 + 1) begin : g_blk
			localparam b = _gv_b_1;
			bsg_mem_1rw_sync_mask_write_bit #(
				.width_p(W),
				.els_p(MPY_MEM_BLOCK_WORDS)
			) ram(
				.clk_i(clk_i),
				.reset_i(!rst_n_i),
				.data_i(blk_data[b]),
				.addr_i(blk_addr[b]),
				.v_i(blk_v[b]),
				.w_mask_i(blk_mask[b]),
				.w_i(blk_w[b]),
				.data_o(blk_q[b])
			);
		end
	endgenerate
	reg clr_busy;
	reg [CW:0] clr_idx;
	assign init_done_o = !clr_busy;
	reg [(NP * 8) - 1:0] phase_r;
	reg [(NP * 4) - 1:0] fault_r;
	reg [NP - 1:0] rd_r;
	reg [(NP * BS) - 1:0] rblk_r;
	reg [NP - 1:0] fresh_r;
	reg [(NP * W) - 1:0] hold_r;
	reg [NP - 1:0] ready;
	reg [(NP * 4) - 1:0] p_fault;
	reg [NP - 1:0] p_mem;
	reg [NP - 1:0] p_img;
	reg [(NP * BS) - 1:0] p_blk;
	reg [(NP * AW) - 1:0] p_row;
	reg [(NP * W) - 1:0] p_mask;
	localparam [3:0] MPY_FAULT_BUS = 4'd3;
	localparam [3:0] MPY_FAULT_FLASH_STORE = 4'd2;
	localparam [3:0] MPY_FAULT_NONE = 4'd0;
	localparam [3:0] MPY_FAULT_UNALIGNED = 4'd1;
	localparam [2:0] MPY_REGION_FLASH = 3'd1;
	localparam [2:0] MPY_REGION_SRAM = 3'd2;
	localparam [31:0] MPY_FLASH_BASE = 32'h00000000;
	function automatic [MPY_MEM_WORD_AW - 1:0] sv2v_cast_EA15C;
		input reg [MPY_MEM_WORD_AW - 1:0] inp;
		sv2v_cast_EA15C = inp;
	endfunction
	function automatic [MPY_MEM_WORD_AW - 1:0] mpy_flash_word_index;
		input reg [31:0] addr;
		mpy_flash_word_index = sv2v_cast_EA15C((addr - MPY_FLASH_BASE) >> 2);
	endfunction
	localparam signed [31:0] MPY_MEM_BYTES = MPY_MEM_WORDS * 4;
	localparam [31:0] MPY_FLASH_BYTES = MPY_MEM_BYTES;
	localparam [31:0] MPY_MMIO_BASE = 32'h40000000;
	localparam [31:0] MPY_MMIO_BYTES = 32'h00001000;
	localparam [2:0] MPY_REGION_MMIO = 3'd3;
	localparam [2:0] MPY_REGION_NONE = 3'd0;
	localparam [2:0] MPY_REGION_SIM = 3'd4;
	localparam [31:0] MPY_SIM_BASE = 32'he0000000;
	localparam [31:0] MPY_SIM_BYTES = 32'd256;
	localparam [31:0] MPY_SRAM_BASE = 32'h20000000;
	localparam [31:0] MPY_SRAM_BYTES = MPY_MEM_BYTES;
	function automatic [2:0] mpy_region_of;
		input reg [31:0] addr;
		if (addr < MPY_FLASH_BYTES)
			mpy_region_of = MPY_REGION_FLASH;
		else if ((addr >= MPY_SRAM_BASE) && ((addr - MPY_SRAM_BASE) < MPY_SRAM_BYTES))
			mpy_region_of = MPY_REGION_SRAM;
		else if ((addr >= MPY_MMIO_BASE) && ((addr - MPY_MMIO_BASE) < MPY_MMIO_BYTES))
			mpy_region_of = MPY_REGION_MMIO;
		else if ((addr >= MPY_SIM_BASE) && ((addr - MPY_SIM_BASE) < MPY_SIM_BYTES))
			mpy_region_of = MPY_REGION_SIM;
		else
			mpy_region_of = MPY_REGION_NONE;
	endfunction
	function automatic [MPY_MEM_WORD_AW - 1:0] mpy_sram_word_index;
		input reg [31:0] addr;
		mpy_sram_word_index = sv2v_cast_EA15C((addr - MPY_SRAM_BASE) >> 2);
	endfunction
	function automatic [MPY_FLASH_IDX_W - 1:0] sv2v_cast_6DF93;
		input reg [MPY_FLASH_IDX_W - 1:0] inp;
		sv2v_cast_6DF93 = inp;
	endfunction
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	function automatic [14:0] sv2v_cast_DE851;
		input reg [14:0] inp;
		sv2v_cast_DE851 = inp;
	endfunction
	function automatic [1:0] sv2v_cast_62836;
		input reg [1:0] inp;
		sv2v_cast_62836 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_1
			reg signed [31:0] p;
			for (p = 0; p < NP; p = p + 1)
				begin : sv2v_autoblock_2
					reg [2:0] region;
					reg [MPY_MEM_WORD_AW - 1:0] sw;
					reg [MPY_FLASH_IDX_W - 1:0] iw;
					region = mpy_region_of(addr_i[p * 32+:32]);
					sw = mpy_sram_word_index(addr_i[p * 32+:32]);
					iw = sv2v_cast_6DF93(mpy_flash_word_index(addr_i[p * 32+:32]));
					ready[p] = !clr_busy && (phase_r[p * 8+:8] <= 8'd1);
					if (addr_i[(p * 32) + 1-:2] != 2'b00)
						p_fault[p * 4+:4] = MPY_FAULT_UNALIGNED;
					else if (region == MPY_REGION_FLASH)
						p_fault[p * 4+:4] = (sv2v_cast_32(iw) >= image_words ? MPY_FAULT_BUS : (we_i[p] ? MPY_FAULT_FLASH_STORE : MPY_FAULT_NONE));
					else if (region == MPY_REGION_SRAM)
						p_fault[p * 4+:4] = (sv2v_cast_32(sw) >= data_words ? MPY_FAULT_BUS : MPY_FAULT_NONE);
					else
						p_fault[p * 4+:4] = MPY_FAULT_BUS;
					p_mem[p] = p_fault[p * 4+:4] == MPY_FAULT_NONE;
					p_img[p] = region == MPY_REGION_FLASH;
					if (p_img[p]) begin
						p_blk[p * BS+:BS] = iw[1:0];
						p_row[p * AW+:AW] = sv2v_cast_DE851(sv2v_cast_32(iw) >> BS);
					end
					else begin
						p_blk[p * BS+:BS] = sv2v_cast_62836(sw);
						p_row[p * AW+:AW] = sv2v_cast_DE851((sv2v_cast_32(sw) + image_words) >> BS);
					end
					begin : sv2v_autoblock_3
						reg signed [31:0] k;
						for (k = 0; k < 4; k = k + 1)
							p_mask[(p * W) + (8 * k)+:8] = {8 {be_i[(p * 4) + k]}};
					end
					p_mask[(p * W) + 35-:4] = {4 {tag_we_i[p]}};
				end
		end
	end
	wire [1:0] ld_blk;
	wire [14:0] ld_row;
	assign ld_blk = ld_idx_i[1:0];
	assign ld_row = sv2v_cast_DE851(sv2v_cast_32(ld_idx_i) >> BS);
	function automatic signed [1:0] sv2v_cast_62836_signed;
		input reg signed [1:0] inp;
		sv2v_cast_62836_signed = inp;
	endfunction
	always @(*) begin : sv2v_autoblock_4
		reg [3:0] taken;
		if (_sv2v_0)
			;
		gnt_o = 1'sb0;
		taken = 1'sb0;
		begin : sv2v_autoblock_5
			reg signed [31:0] b;
			for (b = 0; b < NB; b = b + 1)
				begin
					blk_v[b] = 1'b0;
					blk_w[b] = 1'b0;
					blk_addr[b] = 1'sb0;
					blk_data[b] = 1'sb0;
					blk_mask[b] = 1'sb0;
					if (clr_busy) begin
						blk_v[b] = 1'b1;
						blk_w[b] = 1'b1;
						blk_addr[b] = sv2v_cast_DE851(clr_idx[14:0]);
						blk_mask[b] = 1'sb1;
						taken[b] = 1'b1;
					end
					if (ld_we_i && (ld_blk == sv2v_cast_62836_signed(b))) begin
						blk_v[b] = 1'b1;
						blk_w[b] = 1'b1;
						blk_addr[b] = ld_row;
						blk_data[b] = {ld_wtag_i, ld_wdata_i};
						blk_mask[b] = 1'sb1;
						taken[b] = 1'b1;
					end
				end
		end
		begin : sv2v_autoblock_6
			reg signed [31:0] p;
			for (p = 0; p < NP; p = p + 1)
				if (req_i[p] && ready[p]) begin
					if (!p_mem[p])
						gnt_o[p] = 1'b1;
					else if (!taken[p_blk[p * BS+:BS]]) begin
						gnt_o[p] = 1'b1;
						taken[p_blk[p * BS+:BS]] = 1'b1;
						blk_v[p_blk[p * BS+:BS]] = 1'b1;
						blk_w[p_blk[p * BS+:BS]] = we_i[p];
						blk_addr[p_blk[p * BS+:BS]] = p_row[p * AW+:AW];
						blk_data[p_blk[p * BS+:BS]] = {wtag_i[p * 4+:4], wdata_i[p * 32+:32]};
						blk_mask[p_blk[p * BS+:BS]] = p_mask[p * W+:W];
					end
				end
		end
	end
	function automatic signed [15:0] sv2v_cast_89787_signed;
		input reg signed [15:0] inp;
		sv2v_cast_89787_signed = inp;
	endfunction
	function automatic signed [7:0] sv2v_cast_8_signed;
		input reg signed [7:0] inp;
		sv2v_cast_8_signed = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			clr_busy <= 1'b1;
			clr_idx <= 1'sb0;
			phase_r <= 1'sb0;
			fault_r <= 1'sb0;
			rd_r <= 1'sb0;
			rblk_r <= 1'sb0;
			fresh_r <= 1'sb0;
			hold_r <= 1'sb0;
			ack_o <= 1'sb0;
			rdata_o <= 1'sb0;
			rtag_o <= 1'sb0;
			fault_o <= 1'sb0;
			fault_reason_o <= 1'sb0;
		end
		else begin
			if (clr_busy && !ld_we_i) begin
				clr_idx <= clr_idx + 1'b1;
				if (clr_idx == sv2v_cast_89787_signed(32767))
					clr_busy <= 1'b0;
			end
			begin : sv2v_autoblock_7
				reg signed [31:0] p;
				for (p = 0; p < NP; p = p + 1)
					begin : sv2v_autoblock_8
						reg [35:0] word;
						word = (fresh_r[p] ? blk_q[rblk_r[p * BS+:BS]] : hold_r[p * W+:W]);
						ack_o[p] <= 1'b0;
						fault_o[p] <= 1'b0;
						fault_reason_o[p * 4+:4] <= MPY_FAULT_NONE;
						if (fresh_r[p]) begin
							fresh_r[p] <= 1'b0;
							hold_r[p * W+:W] <= blk_q[rblk_r[p * BS+:BS]];
						end
						if (phase_r[p * 8+:8] == 8'd1) begin
							phase_r[p * 8+:8] <= 1'sb0;
							ack_o[p] <= 1'b1;
							rdata_o[p * 32+:32] <= (rd_r[p] ? word[31:0] : 32'd0);
							rtag_o[p * 4+:4] <= (rd_r[p] ? word[35:32] : 4'd0);
							if (fault_r[p * 4+:4] != MPY_FAULT_NONE) begin
								fault_o[p] <= 1'b1;
								fault_reason_o[p * 4+:4] <= fault_r[p * 4+:4];
							end
						end
						else if (phase_r[p * 8+:8] != 8'd0)
							phase_r[p * 8+:8] <= phase_r[p * 8+:8] - 8'd1;
						if (gnt_o[p]) begin
							fault_r[p * 4+:4] <= p_fault[p * 4+:4];
							rd_r[p] <= p_mem[p] && !we_i[p];
							rblk_r[p * BS+:BS] <= p_blk[p * BS+:BS];
							fresh_r[p] <= p_mem[p] && !we_i[p];
							phase_r[p * 8+:8] <= (p_img[p] ? sv2v_cast_8_signed(SRAM_LATENCY + FLASH_WAIT_STATES) : sv2v_cast_8_signed(SRAM_LATENCY));
						end
					end
			end
		end
	initial _sv2v_0 = 0;
endmodule
module mpy_boot (
	clk_i,
	rst_n_i,
	sck_o,
	cs_n_o,
	mosi_o,
	miso_i,
	ld_we_o,
	ld_idx_o,
	ld_wdata_o,
	ld_wtag_o,
	ioc_we_o,
	ioc_data_o,
	ioc_stall_i,
	ioc_loaded_o,
	image_words_o,
	pool_bytes_o,
	done_o,
	err_o
);
	reg _sv2v_0;
	parameter signed [31:0] SPI_DIV = 2;
	parameter signed [31:0] PAGE_BYTES = 2048;
	parameter [15:0] FIRST_PAGE = 16'd0;
	parameter signed [31:0] POWERUP_CYCLES = 0;
	parameter signed [31:0] IOC_CODE_WORDS = 4096;
	parameter signed [31:0] IOC_DATA_WORDS = 1920;
	input wire clk_i;
	input wire rst_n_i;
	output reg sck_o;
	output reg cs_n_o;
	output reg mosi_o;
	input wire miso_i;
	output reg ld_we_o;
	localparam signed [31:0] MPY_MEM_BLOCKS = 4;
	localparam signed [31:0] MPY_MEM_BLOCK_WORDS = 32768;
	localparam signed [31:0] MPY_MEM_WORDS = MPY_MEM_BLOCKS * MPY_MEM_BLOCK_WORDS;
	localparam signed [31:0] MPY_MEM_WORD_AW = $clog2(MPY_MEM_WORDS);
	localparam signed [31:0] MPY_FLASH_IDX_W = MPY_MEM_WORD_AW;
	output reg [MPY_FLASH_IDX_W - 1:0] ld_idx_o;
	output reg [31:0] ld_wdata_o;
	output reg [3:0] ld_wtag_o;
	output reg ioc_we_o;
	output reg [48:0] ioc_data_o;
	input wire ioc_stall_i;
	output reg ioc_loaded_o;
	output wire [31:0] image_words_o;
	output reg [31:0] pool_bytes_o;
	output reg done_o;
	output wire err_o;
	wire src_v;
	wire [31:0] src_w;
	wire use_fast;
	wire fast_v;
	wire [31:0] fast_w;
	reg spi_v;
	reg [31:0] spi_w;
	wire stop;
	assign src_v = (use_fast ? fast_v : spi_v);
	assign src_w = (use_fast ? fast_w : spi_w);
	reg [3:0] cst;
	reg [15:0] ioc_nc;
	reg [15:0] ioc_nd;
	reg [15:0] ioc_i;
	reg ioc_sel;
	reg [31:0] nwords;
	reg [31:0] tagw;
	reg [2:0] k;
	reg [MPY_FLASH_IDX_W:0] widx;
	assign image_words_o = (nwords + 32'd7) & 32'hfffffff8;
	assign stop = (cst == 4'd4) || (cst == 4'd5);
	assign err_o = cst == 4'd5;
	localparam [31:0] MPY_BOOT_MAGIC = 32'h42595055;
	localparam [31:0] MPY_FRAME_RESERVE_BYTES = 32'h00008000;
	localparam [31:0] MPY_SRAM_BASE = 32'h20000000;
	localparam [31:0] MPY_SCHED_BASE = MPY_SRAM_BASE + MPY_FRAME_RESERVE_BYTES;
	localparam [31:0] MPY_SCHED_BYTES = 32'h00000040;
	localparam [31:0] MPY_HANDLER_BASE = MPY_SCHED_BASE + MPY_SCHED_BYTES;
	localparam [31:0] MPY_HANDLER_BYTES = 32'h00000040;
	localparam [31:0] MPY_SYSROOT_BASE = MPY_HANDLER_BASE + MPY_HANDLER_BYTES;
	localparam [31:0] MPY_ARGBUF_BASE = MPY_SYSROOT_BASE + 32'h00000080;
	localparam [31:0] MPY_GC_POOL_BASE = MPY_ARGBUF_BASE + 32'h00000400;
	localparam [31:0] MPY_IOCB_MAGIC = 32'h42434f49;
	localparam signed [31:0] MPY_MEM_BYTES = MPY_MEM_WORDS * 4;
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			cst <= 4'd0;
			nwords <= 1'sb0;
			pool_bytes_o <= 1'sb0;
			tagw <= 1'sb0;
			k <= 1'sb0;
			widx <= 1'sb0;
			ld_we_o <= 1'b0;
			ld_idx_o <= 1'sb0;
			ld_wdata_o <= 1'sb0;
			ld_wtag_o <= 1'sb0;
			done_o <= 1'b0;
			ioc_we_o <= 1'b0;
			ioc_data_o <= 1'sb0;
			ioc_loaded_o <= 1'b0;
			ioc_nc <= 1'sb0;
			ioc_nd <= 1'sb0;
			ioc_i <= 1'sb0;
			ioc_sel <= 1'b0;
		end
		else begin
			ld_we_o <= 1'b0;
			ioc_we_o <= 1'b0;
			if ((cst == 4'd4) && !ld_we_o)
				done_o <= 1'b1;
			if (src_v)
				(* full_case, parallel_case *)
				case (cst)
					4'd0: cst <= (src_w == MPY_BOOT_MAGIC ? 4'd1 : 4'd5);
					4'd1: begin
						nwords <= src_w;
						cst <= ((src_w < 32'd16) || (src_w > sv2v_cast_32((((MPY_MEM_BYTES - (MPY_GC_POOL_BASE - MPY_SRAM_BASE)) - 16) / 32) * 8)) ? 4'd5 : 4'd2);
					end
					4'd2: begin
						tagw <= src_w;
						k <= 1'sb0;
						cst <= 4'd3;
					end
					4'd3: begin
						if (widx == 14)
							pool_bytes_o <= src_w;
						ld_we_o <= 1'b1;
						ld_idx_o <= widx[MPY_FLASH_IDX_W - 1:0];
						ld_wdata_o <= src_w;
						ld_wtag_o <= tagw[4 * k+:4];
						widx <= widx + 1'b1;
						k <= k + 3'd1;
						if (k == 3'd7)
							cst <= ((sv2v_cast_32(widx) + 32'd1) >= nwords ? 4'd6 : 4'd2);
					end
					4'd6: cst <= (src_w == MPY_IOCB_MAGIC ? 4'd7 : 4'd4);
					4'd7: begin
						ioc_nc <= src_w[15:0];
						cst <= (src_w > IOC_CODE_WORDS ? 4'd10 : 4'd8);
					end
					4'd8: begin
						ioc_nd <= src_w[15:0];
						ioc_i <= 1'sb0;
						ioc_sel <= ioc_nc == 16'd0;
						cst <= (src_w > IOC_DATA_WORDS ? 4'd10 : ((ioc_nc == 16'd0) && (src_w == 32'd0) ? 4'd4 : 4'd9));
						if (src_w <= IOC_DATA_WORDS)
							ioc_loaded_o <= 1'b1;
					end
					4'd9: begin
						ioc_we_o <= 1'b1;
						ioc_data_o <= {ioc_sel, ioc_i, src_w};
						if ((ioc_i + 16'd1) == (ioc_sel ? ioc_nd : ioc_nc)) begin
							ioc_i <= 1'sb0;
							ioc_sel <= 1'b1;
							if (ioc_sel || (ioc_nd == 16'd0))
								cst <= 4'd4;
						end
						else
							ioc_i <= ioc_i + 16'd1;
					end
					default:
						;
				endcase
			if (cst == 4'd10)
				cst <= 4'd5;
		end
	localparam signed [31:0] DW = (SPI_DIV > 1 ? $clog2(SPI_DIV) : 1);
	reg start;
	reg [7:0] tx;
	reg busy;
	reg byte_done;
	reg [2:0] bit_i;
	reg [7:0] tx_sr;
	reg [7:0] rx_sr;
	reg [DW - 1:0] div;
	wire tick;
	assign tick = div == {DW {1'sb0}};
	function automatic signed [DW - 1:0] sv2v_cast_A0774_signed;
		input reg signed [DW - 1:0] inp;
		sv2v_cast_A0774_signed = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			busy <= 1'b0;
			byte_done <= 1'b0;
			bit_i <= 1'sb0;
			tx_sr <= 1'sb0;
			rx_sr <= 1'sb0;
			div <= 1'sb0;
			sck_o <= 1'b0;
			mosi_o <= 1'b0;
		end
		else begin
			byte_done <= 1'b0;
			div <= (tick ? sv2v_cast_A0774_signed(SPI_DIV - 1) : div - 1'b1);
			if (start) begin
				busy <= 1'b1;
				tx_sr <= tx;
				mosi_o <= tx[7];
				bit_i <= 1'sb0;
				sck_o <= 1'b0;
				div <= sv2v_cast_A0774_signed(SPI_DIV - 1);
			end
			else if (busy && tick) begin
				if (!sck_o) begin
					sck_o <= 1'b1;
					rx_sr <= {rx_sr[6:0], miso_i};
				end
				else begin
					sck_o <= 1'b0;
					if (bit_i == 3'd7) begin
						busy <= 1'b0;
						byte_done <= 1'b1;
					end
					else begin
						bit_i <= bit_i + 3'd1;
						tx_sr <= {tx_sr[6:0], 1'b0};
						mosi_o <= tx_sr[6];
					end
				end
			end
		end
	localparam signed [31:0] GAP_CYCLES = 4 * SPI_DIV;
	localparam signed [31:0] RD_HDR = 4;
	localparam signed [31:0] BI_W = $clog2(PAGE_BYTES + 5);
	reg [2:0] sst;
	reg [2:0] nxt;
	reg [2:0] poll_ret;
	reg pend;
	reg [BI_W - 1:0] bi;
	reg [31:0] wait_cnt;
	reg [15:0] page;
	reg [1:0] bsel;
	reg [23:0] wlo;
	function automatic signed [BI_W - 1:0] sv2v_cast_3D4D2_signed;
		input reg signed [BI_W - 1:0] inp;
		sv2v_cast_3D4D2_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (sst)
			3'd2: tx = 8'hff;
			3'd3: tx = (bi == {BI_W {1'sb0}} ? 8'h0f : (bi == sv2v_cast_3D4D2_signed(1) ? 8'hc0 : 8'h00));
			3'd4: tx = (bi == {BI_W {1'sb0}} ? 8'h13 : (bi == sv2v_cast_3D4D2_signed(1) ? 8'h00 : (bi == sv2v_cast_3D4D2_signed(2) ? page[15:8] : page[7:0])));
			3'd5: tx = (bi == {BI_W {1'sb0}} ? 8'h03 : 8'h00);
			default: tx = 8'h00;
		endcase
	end
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			sst <= 3'd0;
			nxt <= 3'd2;
			poll_ret <= 3'd4;
			pend <= 1'b0;
			start <= 1'b0;
			bi <= 1'sb0;
			wait_cnt <= POWERUP_CYCLES;
			page <= FIRST_PAGE;
			bsel <= 1'sb0;
			wlo <= 1'sb0;
			cs_n_o <= 1'b1;
			spi_v <= 1'b0;
			spi_w <= 1'sb0;
		end
		else begin
			start <= 1'b0;
			spi_v <= 1'b0;
			if (use_fast)
				sst <= 3'd6;
			else
				(* full_case, parallel_case *)
				case (sst)
					3'd0, 3'd1: begin
						cs_n_o <= 1'b1;
						if (stop)
							sst <= 3'd6;
						else if (wait_cnt == 32'd0) begin
							sst <= nxt;
							bi <= 1'sb0;
						end
						else
							wait_cnt <= wait_cnt - 32'd1;
					end
					3'd2, 3'd3, 3'd4, 3'd5: begin
						cs_n_o <= 1'b0;
						if ((!pend && !busy) && !byte_done) begin
							start <= 1'b1;
							pend <= 1'b1;
						end
						else if (byte_done) begin
							pend <= 1'b0;
							bi <= bi + 1'b1;
							(* full_case, parallel_case *)
							case (sst)
								3'd2: begin
									sst <= 3'd1;
									nxt <= 3'd3;
									poll_ret <= 3'd4;
									wait_cnt <= GAP_CYCLES;
								end
								3'd3:
									if (bi == sv2v_cast_3D4D2_signed(2)) begin
										sst <= 3'd1;
										nxt <= (rx_sr[0] ? 3'd3 : poll_ret);
										wait_cnt <= GAP_CYCLES;
									end
								3'd4:
									if (bi == sv2v_cast_3D4D2_signed(3)) begin
										sst <= 3'd1;
										nxt <= 3'd3;
										poll_ret <= 3'd5;
										wait_cnt <= GAP_CYCLES;
									end
								3'd5:
									if (bi >= sv2v_cast_3D4D2_signed(RD_HDR)) begin
										bsel <= bsel + 2'd1;
										if (bsel == 2'd3) begin
											spi_v <= 1'b1;
											spi_w <= {rx_sr, wlo};
										end
										else
											wlo <= {rx_sr, wlo[23:8]};
										if (bi == sv2v_cast_3D4D2_signed((RD_HDR + PAGE_BYTES) - 1)) begin
											sst <= 3'd1;
											nxt <= 3'd4;
											page <= page + 16'd1;
											wait_cnt <= GAP_CYCLES;
										end
									end
								default:
									;
							endcase
						end
						if ((stop && !busy) && !start) begin
							sst <= 3'd6;
							cs_n_o <= 1'b1;
							pend <= 1'b0;
							start <= 1'b0;
						end
					end
					default: cs_n_o <= 1'b1;
				endcase
		end
	assign use_fast = 1'b0;
	assign fast_v = 1'b0;
	assign fast_w = 1'sb0;
	initial _sv2v_0 = 0;
endmodule
module mpy_async_fifo (
	wclk,
	wrst_n,
	w_en,
	w_data,
	w_full,
	w_level,
	rclk,
	rrst_n,
	r_en,
	r_data,
	r_empty,
	r_level
);
	parameter signed [31:0] W = 32;
	parameter signed [31:0] AW = 4;
	input wire wclk;
	input wire wrst_n;
	input wire w_en;
	input wire [W - 1:0] w_data;
	output wire w_full;
	output wire [AW:0] w_level;
	input wire rclk;
	input wire rrst_n;
	input wire r_en;
	output wire [W - 1:0] r_data;
	output wire r_empty;
	output wire [AW:0] r_level;
	localparam signed [31:0] DEPTH = 1 << AW;
	reg [W - 1:0] mem [0:DEPTH - 1];
	reg [AW:0] wbin;
	reg [AW:0] wgray;
	reg [AW:0] rbin;
	reg [AW:0] rgray;
	reg [AW:0] rgray_w1;
	reg [AW:0] rgray_w2;
	reg [AW:0] wgray_r1;
	reg [AW:0] wgray_r2;
	function automatic [AW:0] bin2gray;
		input reg [AW:0] b;
		bin2gray = b ^ (b >> 1);
	endfunction
	function automatic [AW:0] gray2bin;
		input reg [AW:0] g;
		reg [AW:0] b;
		begin
			b[AW] = g[AW];
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = AW - 1; i >= 0; i = i - 1)
					b[i] = b[i + 1] ^ g[i];
			end
			gray2bin = b;
		end
	endfunction
	assign w_level = wbin - gray2bin(rgray_w2);
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	assign w_full = sv2v_cast_32(w_level) == DEPTH;
	always @(posedge wclk or negedge wrst_n)
		if (!wrst_n) begin
			wbin <= 1'sb0;
			wgray <= 1'sb0;
			rgray_w1 <= 1'sb0;
			rgray_w2 <= 1'sb0;
		end
		else begin
			rgray_w1 <= rgray;
			rgray_w2 <= rgray_w1;
			if (w_en && !w_full) begin
				wbin <= wbin + 1'b1;
				wgray <= bin2gray(wbin + 1'b1);
			end
		end
	always @(posedge wclk)
		if (w_en && !w_full)
			mem[wbin[AW - 1:0]] <= w_data;
	assign r_level = gray2bin(wgray_r2) - rbin;
	assign r_empty = r_level == {(AW >= 0 ? AW + 1 : 1 - AW) {1'sb0}};
	assign r_data = mem[rbin[AW - 1:0]];
	always @(posedge rclk or negedge rrst_n)
		if (!rrst_n) begin
			rbin <= 1'sb0;
			rgray <= 1'sb0;
			wgray_r1 <= 1'sb0;
			wgray_r2 <= 1'sb0;
		end
		else begin
			wgray_r1 <= wgray;
			wgray_r2 <= wgray_r1;
			if (r_en && !r_empty) begin
				rbin <= rbin + 1'b1;
				rgray <= bin2gray(rbin + 1'b1);
			end
		end
endmodule
module mpy_iobr (
	clk_i,
	rst_n_i,
	hart_rst_n_i,
	sys_reset_o,
	wdt_toggle_i,
	acc_i,
	we_i,
	off_i,
	wdata_i,
	rdata_o,
	acc_now_i,
	stall_o,
	con_push_i,
	con_data_i,
	con_mode_i,
	evt_pend_o,
	ld_push_i,
	ld_data_i,
	ld_idle_o,
	run_i,
	loaded_i,
	io_clk_i,
	io_rst_n_i,
	us_gray_i,
	ms_gray_i,
	cmd_pop_i,
	cmd_data_o,
	cmd_empty_o,
	cmd_level_o,
	rsp_push_i,
	rsp_data_i,
	rsp_full_o,
	evt_push_i,
	evt_data_i,
	evt_full_o,
	con_pop_i,
	con_data_o,
	con_empty_o,
	con_level_o,
	conrx_push_i,
	conrx_data_i,
	conrx_full_o,
	upd_push_i,
	upd_data_i,
	upd_full_o,
	dn_pop_i,
	dn_data_o,
	dn_empty_o,
	ld_pop_i,
	ld_data_o,
	ld_empty_o
);
	reg _sv2v_0;
	parameter signed [31:0] NUP = 32;
	parameter signed [31:0] NDN = 8;
	input wire clk_i;
	input wire rst_n_i;
	input wire hart_rst_n_i;
	output reg sys_reset_o;
	input wire wdt_toggle_i;
	input wire acc_i;
	input wire we_i;
	input wire [9:0] off_i;
	input wire [31:0] wdata_i;
	output reg [31:0] rdata_o;
	input wire acc_now_i;
	output reg stall_o;
	input wire con_push_i;
	input wire [8:0] con_data_i;
	input wire [1:0] con_mode_i;
	output reg evt_pend_o;
	input wire ld_push_i;
	input wire [48:0] ld_data_i;
	output wire ld_idle_o;
	input wire run_i;
	input wire loaded_i;
	input wire io_clk_i;
	input wire io_rst_n_i;
	input wire [31:0] us_gray_i;
	input wire [31:0] ms_gray_i;
	input wire cmd_pop_i;
	output wire [31:0] cmd_data_o;
	output wire cmd_empty_o;
	output wire [5:0] cmd_level_o;
	input wire rsp_push_i;
	input wire [31:0] rsp_data_i;
	output wire rsp_full_o;
	input wire evt_push_i;
	input wire [15:0] evt_data_i;
	output wire evt_full_o;
	input wire con_pop_i;
	output wire [8:0] con_data_o;
	output wire con_empty_o;
	output wire [6:0] con_level_o;
	input wire conrx_push_i;
	input wire [7:0] conrx_data_i;
	output wire conrx_full_o;
	input wire upd_push_i;
	input wire [36:0] upd_data_i;
	output wire upd_full_o;
	input wire dn_pop_i;
	output wire [34:0] dn_data_o;
	output wire dn_empty_o;
	input wire ld_pop_i;
	output wire [48:0] ld_data_o;
	output wire ld_empty_o;
	localparam [9:0] O_CMD = 10'h000;
	localparam [9:0] O_RSP = 10'h001;
	localparam [9:0] O_STATUS = 10'h002;
	localparam [9:0] O_EVT = 10'h003;
	localparam [9:0] O_EVT_EN = 10'h004;
	localparam [9:0] O_EVT_SET = 10'h005;
	localparam [9:0] O_EVT_MASK = 10'h006;
	localparam [9:0] O_IOC_CTRL = 10'h007;
	localparam [9:0] O_CON_RX = 10'h008;
	localparam [9:0] O_CON_MODE = 10'h009;
	localparam [9:0] O_CMD_SENT = 10'h00a;
	localparam [9:0] O_RESET_CAUSE = 10'h00b;
	localparam [9:0] O_SYS_RESET = 10'h00c;
	localparam [9:0] O_KEEP = 10'h00d;
	localparam [2:0] PWRON_RESET = 3'd1;
	localparam [2:0] HARD_RESET = 3'd2;
	localparam [2:0] WDT_RESET = 3'd3;
	localparam [2:0] SOFT_RESET = 3'd5;
	localparam [27:0] RESET_KEY = 28'h0b007ed;
	wire cmd_push;
	wire cmd_full;
	wire [5:0] cmd_wl;
	mpy_async_fifo #(
		.W(32),
		.AW(5)
	) u_cmd(
		.wclk(clk_i),
		.wrst_n(rst_n_i),
		.w_en(cmd_push),
		.w_data(wdata_i),
		.w_full(cmd_full),
		.w_level(cmd_wl),
		.rclk(io_clk_i),
		.rrst_n(io_rst_n_i),
		.r_en(cmd_pop_i),
		.r_data(cmd_data_o),
		.r_empty(cmd_empty_o),
		.r_level(cmd_level_o)
	);
	wire rsp_pop;
	wire rsp_empty;
	wire [31:0] rsp_head;
	wire [4:0] rsp_rl;
	wire [4:0] rsp_wl_unused;
	mpy_async_fifo #(
		.W(32),
		.AW(4)
	) u_rsp(
		.wclk(io_clk_i),
		.wrst_n(io_rst_n_i),
		.w_en(rsp_push_i),
		.w_data(rsp_data_i),
		.w_full(rsp_full_o),
		.w_level(rsp_wl_unused),
		.rclk(clk_i),
		.rrst_n(rst_n_i),
		.r_en(rsp_pop),
		.r_data(rsp_head),
		.r_empty(rsp_empty),
		.r_level(rsp_rl)
	);
	wire con_full;
	wire [6:0] con_wl;
	mpy_async_fifo #(
		.W(9),
		.AW(6)
	) u_con(
		.wclk(clk_i),
		.wrst_n(rst_n_i),
		.w_en(con_push_i),
		.w_data(con_data_i),
		.w_full(con_full),
		.w_level(con_wl),
		.rclk(io_clk_i),
		.rrst_n(io_rst_n_i),
		.r_en(con_pop_i),
		.r_data(con_data_o),
		.r_empty(con_empty_o),
		.r_level(con_level_o)
	);
	wire conrx_pop;
	wire conrx_empty;
	wire [7:0] conrx_head;
	wire [4:0] conrx_rl_unused;
	wire [4:0] conrx_wl_unused;
	mpy_async_fifo #(
		.W(8),
		.AW(4)
	) u_conrx(
		.wclk(io_clk_i),
		.wrst_n(io_rst_n_i),
		.w_en(conrx_push_i),
		.w_data(conrx_data_i),
		.w_full(conrx_full_o),
		.w_level(conrx_wl_unused),
		.rclk(clk_i),
		.rrst_n(rst_n_i),
		.r_en(conrx_pop),
		.r_data(conrx_head),
		.r_empty(conrx_empty),
		.r_level(conrx_rl_unused)
	);
	wire evt_empty;
	wire [15:0] evt_head;
	wire [2:0] evt_rl_unused;
	wire [2:0] evt_wl_unused;
	mpy_async_fifo #(
		.W(16),
		.AW(2)
	) u_evt(
		.wclk(io_clk_i),
		.wrst_n(io_rst_n_i),
		.w_en(evt_push_i),
		.w_data(evt_data_i),
		.w_full(evt_full_o),
		.w_level(evt_wl_unused),
		.rclk(clk_i),
		.rrst_n(rst_n_i),
		.r_en(!evt_empty),
		.r_data(evt_head),
		.r_empty(evt_empty),
		.r_level(evt_rl_unused)
	);
	wire upd_empty;
	wire [36:0] upd_head;
	wire [2:0] upd_rl_unused;
	wire [2:0] upd_wl_unused;
	mpy_async_fifo #(
		.W(37),
		.AW(2)
	) u_upd(
		.wclk(io_clk_i),
		.wrst_n(io_rst_n_i),
		.w_en(upd_push_i),
		.w_data(upd_data_i),
		.w_full(upd_full_o),
		.w_level(upd_wl_unused),
		.rclk(clk_i),
		.rrst_n(rst_n_i),
		.r_en(!upd_empty),
		.r_data(upd_head),
		.r_empty(upd_empty),
		.r_level(upd_rl_unused)
	);
	wire dn_push;
	wire [2:0] dn_wl;
	wire [2:0] dn_rl_unused;
	wire dn_full_unused;
	mpy_async_fifo #(
		.W(35),
		.AW(2)
	) u_dn(
		.wclk(clk_i),
		.wrst_n(rst_n_i),
		.w_en(dn_push),
		.w_data({off_i[2:0], wdata_i}),
		.w_full(dn_full_unused),
		.w_level(dn_wl),
		.rclk(io_clk_i),
		.rrst_n(io_rst_n_i),
		.r_en(dn_pop_i),
		.r_data(dn_data_o),
		.r_empty(dn_empty_o),
		.r_level(dn_rl_unused)
	);
	wire [2:0] ld_wl;
	wire [2:0] ld_rl_unused;
	wire ld_full_unused;
	mpy_async_fifo #(
		.W(49),
		.AW(2)
	) u_ld(
		.wclk(clk_i),
		.wrst_n(rst_n_i),
		.w_en(ld_push_i),
		.w_data(ld_data_i),
		.w_full(ld_full_unused),
		.w_level(ld_wl),
		.rclk(io_clk_i),
		.rrst_n(io_rst_n_i),
		.r_en(ld_pop_i),
		.r_data(ld_data_o),
		.r_empty(ld_empty_o),
		.r_level(ld_rl_unused)
	);
	assign ld_idle_o = ld_wl == {3 {1'sb0}};
	localparam signed [31:0] PG_MS = 3;
	localparam signed [31:0] PG_US = 4;
	reg [31:0] us_s1;
	reg [31:0] us_s2;
	reg [31:0] ms_s1;
	reg [31:0] ms_s2;
	reg [31:0] us_r;
	reg [31:0] ms_r;
	function automatic [31:0] g2b;
		input reg [31:0] g;
		reg [31:0] b;
		begin
			b = g;
			b = b ^ (b >> 1);
			b = b ^ (b >> 2);
			b = b ^ (b >> 4);
			b = b ^ (b >> 8);
			b = b ^ (b >> 16);
			g2b = b;
		end
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			us_s1 <= 1'sb0;
			us_s2 <= 1'sb0;
			ms_s1 <= 1'sb0;
			ms_s2 <= 1'sb0;
			us_r <= 1'sb0;
			ms_r <= 1'sb0;
		end
		else begin
			us_s1 <= us_gray_i;
			us_s2 <= us_s1;
			us_r <= g2b(us_s2);
			ms_s1 <= ms_gray_i;
			ms_s2 <= ms_s1;
			ms_r <= g2b(ms_s2);
		end
	reg [31:0] evt_r;
	reg [31:0] evt_en_r;
	reg [31:0] sent_r;
	reg [31:0] keep_r;
	reg [2:0] cause_r;
	reg [2:0] wdt_s;
	reg [1:0] mask_r;
	reg [31:0] up_r [0:NUP - 1];
	reg [31:0] dn_r [0:NDN - 1];
	wire is_up;
	wire is_dn;
	assign is_up = off_i[9:8] == 2'b10;
	assign is_dn = off_i[9:8] == 2'b11;
	assign cmd_push = (acc_i && we_i) && (off_i == O_CMD);
	assign dn_push = (acc_i && we_i) && is_dn;
	reg [31:0] stat_r;
	reg rsp_ne_r;
	reg conrx_ne_r;
	assign rsp_pop = ((acc_i && !we_i) && (off_i == O_RSP)) && rsp_ne_r;
	assign conrx_pop = ((acc_i && !we_i) && (off_i == O_CON_RX)) && conrx_ne_r;
	reg [31:0] rd_up;
	reg [31:0] rd_dn;
	reg [31:0] rd_reg;
	wire is_reg;
	assign is_reg = off_i[9:8] == 2'b00;
	function automatic [3:0] sv2v_cast_4;
		input reg [3:0] inp;
		sv2v_cast_4 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		if (off_i[$clog2(NUP) - 1:0] == PG_MS[$clog2(NUP) - 1:0])
			rd_up = ms_r;
		else if (off_i[$clog2(NUP) - 1:0] == PG_US[$clog2(NUP) - 1:0])
			rd_up = us_r;
		else
			rd_up = up_r[off_i[$clog2(NUP) - 1:0]];
		rd_dn = dn_r[off_i[$clog2(NDN) - 1:0]];
		case (off_i[3:0])
			sv2v_cast_4(O_RSP): rd_reg = (rsp_ne_r ? rsp_head : 32'h00000000);
			sv2v_cast_4(O_STATUS): rd_reg = stat_r;
			sv2v_cast_4(O_EVT): rd_reg = evt_r;
			sv2v_cast_4(O_EVT_EN): rd_reg = evt_en_r;
			sv2v_cast_4(O_EVT_MASK): rd_reg = {30'h00000000, mask_r};
			sv2v_cast_4(O_IOC_CTRL): rd_reg = {30'h00000000, loaded_i, run_i};
			sv2v_cast_4(O_CON_RX): rd_reg = {conrx_ne_r, 23'h000000, (conrx_ne_r ? conrx_head : 8'h00)};
			sv2v_cast_4(O_CON_MODE): rd_reg = {30'h00000000, con_mode_i};
			sv2v_cast_4(O_CMD_SENT): rd_reg = sent_r;
			sv2v_cast_4(O_RESET_CAUSE): rd_reg = {29'h00000000, cause_r};
			sv2v_cast_4(O_KEEP): rd_reg = keep_r;
			default: rd_reg = 32'h00000000;
		endcase
		rdata_o = (we_i ? 32'h00000000 : (({32 {is_up}} & rd_up) | ({32 {is_dn}} & rd_dn)) | ({32 {is_reg}} & rd_reg));
	end
	wire stall_n;
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	assign stall_n = (((acc_now_i || ((sv2v_cast_32(cmd_wl) + sv2v_cast_32(cmd_push)) >= 30)) || ((sv2v_cast_32(con_wl) + sv2v_cast_32(con_push_i)) >= 62)) || ((sv2v_cast_32(dn_wl) + sv2v_cast_32(dn_push)) >= 2)) || ((sv2v_cast_32(ld_wl) + sv2v_cast_32(ld_push_i)) >= 2);
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			sent_r <= 32'h00000000;
			keep_r <= 32'h00000000;
			cause_r <= PWRON_RESET;
			wdt_s <= 3'b000;
			sys_reset_o <= 1'b0;
			stall_o <= 1'b0;
			stat_r <= 32'h00000000;
			rsp_ne_r <= 1'b0;
			conrx_ne_r <= 1'b0;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < NUP; i = i + 1)
					up_r[i] <= 32'h00000000;
			end
			begin : sv2v_autoblock_2
				reg signed [31:0] i;
				for (i = 0; i < NDN; i = i + 1)
					dn_r[i] <= 32'h00000000;
			end
		end
		else begin
			wdt_s <= {wdt_s[1:0], wdt_toggle_i};
			sys_reset_o <= 1'b0;
			if (((acc_i && we_i) && (off_i == O_SYS_RESET)) && (wdata_i[31:4] == RESET_KEY)) begin
				sys_reset_o <= 1'b1;
				cause_r <= (wdata_i[0] ? SOFT_RESET : HARD_RESET);
			end
			if (wdt_s[2] != wdt_s[1]) begin
				sys_reset_o <= 1'b1;
				cause_r <= WDT_RESET;
			end
			if ((acc_i && we_i) && (off_i == O_KEEP))
				keep_r <= wdata_i;
			stall_o <= stall_n;
			stat_r <= {!rsp_empty, con_wl, 5'h00, !conrx_empty, con_full, cmd_full, 3'h0, rsp_rl, 2'h0, cmd_wl};
			rsp_ne_r <= !rsp_empty && !(rsp_pop && (rsp_rl == 5'd1));
			conrx_ne_r <= !conrx_empty && !conrx_pop;
			if (cmd_push)
				sent_r <= sent_r + 32'd1;
			if (!upd_empty)
				up_r[upd_head[32+:$clog2(NUP)]] <= upd_head[31:0];
			if (dn_push)
				dn_r[off_i[$clog2(NDN) - 1:0]] <= wdata_i;
		end
	always @(posedge clk_i or negedge hart_rst_n_i)
		if (!hart_rst_n_i) begin
			evt_r <= 32'h00000000;
			evt_en_r <= 32'h00000000;
			mask_r <= 2'b00;
			evt_pend_o <= 1'b0;
		end
		else begin
			evt_r <= ((evt_r & ~((acc_i && we_i) && (off_i == O_EVT) ? wdata_i : 32'h00000000)) | ((acc_i && we_i) && (off_i == O_EVT_SET) ? wdata_i : 32'h00000000)) | (!evt_empty ? {16'h0000, evt_head} : 32'h00000000);
			if ((acc_i && we_i) && (off_i == O_EVT_EN))
				evt_en_r <= wdata_i;
			if ((acc_i && we_i) && (off_i == O_EVT_MASK))
				mask_r <= wdata_i[1:0];
			evt_pend_o <= |(evt_r & evt_en_r) && (mask_r == 2'b00);
		end
	wire unused;
	assign unused = ^{rsp_wl_unused, conrx_rl_unused, conrx_wl_unused, evt_rl_unused, evt_wl_unused, upd_rl_unused, upd_wl_unused, dn_rl_unused, dn_full_unused, ld_rl_unused, ld_full_unused};
	initial _sv2v_0 = 0;
endmodule
module cve2_alu (
	operator_i,
	operand_a_i,
	operand_b_i,
	instr_first_cycle_i,
	multdiv_operand_a_i,
	multdiv_operand_b_i,
	multdiv_sel_i,
	imd_val_q_i,
	imd_val_d_o,
	imd_val_we_o,
	adder_result_o,
	adder_result_ext_o,
	result_o,
	comparison_result_o,
	is_equal_result_o
);
	reg _sv2v_0;
	parameter integer RV32B = 32'sd0;
	input wire [6:0] operator_i;
	input wire [31:0] operand_a_i;
	input wire [31:0] operand_b_i;
	input wire instr_first_cycle_i;
	input wire [32:0] multdiv_operand_a_i;
	input wire [32:0] multdiv_operand_b_i;
	input wire multdiv_sel_i;
	input wire [63:0] imd_val_q_i;
	output reg [63:0] imd_val_d_o;
	output reg [1:0] imd_val_we_o;
	output wire [31:0] adder_result_o;
	output wire [33:0] adder_result_ext_o;
	output reg [31:0] result_o;
	output wire comparison_result_o;
	output wire is_equal_result_o;
	wire [31:0] operand_a_rev;
	wire [32:0] operand_b_neg;
	genvar _gv_k_2;
	generate
		for (_gv_k_2 = 0; _gv_k_2 < 32; _gv_k_2 = _gv_k_2 + 1) begin : gen_rev_operand_a
			localparam k = _gv_k_2;
			assign operand_a_rev[k] = operand_a_i[31 - k];
		end
	endgenerate
	reg adder_op_a_shift1;
	reg adder_op_a_shift2;
	reg adder_op_a_shift3;
	reg adder_op_b_negate;
	reg [32:0] adder_in_a;
	reg [32:0] adder_in_b;
	wire [31:0] adder_result;
	always @(*) begin
		if (_sv2v_0)
			;
		adder_op_a_shift1 = 1'b0;
		adder_op_a_shift2 = 1'b0;
		adder_op_a_shift3 = 1'b0;
		adder_op_b_negate = 1'b0;
		(* full_case, parallel_case *)
		case (operator_i)
			7'd1, 7'd29, 7'd30, 7'd27, 7'd28, 7'd25, 7'd26, 7'd43, 7'd44, 7'd31, 7'd32, 7'd33, 7'd34: adder_op_b_negate = 1'b1;
			7'd22:
				if (RV32B != 32'sd0)
					adder_op_a_shift1 = 1'b1;
			7'd23:
				if (RV32B != 32'sd0)
					adder_op_a_shift2 = 1'b1;
			7'd24:
				if (RV32B != 32'sd0)
					adder_op_a_shift3 = 1'b1;
			default:
				;
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (1'b1)
			multdiv_sel_i: adder_in_a = multdiv_operand_a_i;
			adder_op_a_shift1: adder_in_a = {operand_a_i[30:0], 2'b01};
			adder_op_a_shift2: adder_in_a = {operand_a_i[29:0], 3'b001};
			adder_op_a_shift3: adder_in_a = {operand_a_i[28:0], 4'b0001};
			default: adder_in_a = {operand_a_i, 1'b1};
		endcase
	end
	assign operand_b_neg = {operand_b_i, 1'b0} ^ {33 {1'b1}};
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (1'b1)
			multdiv_sel_i: adder_in_b = multdiv_operand_b_i;
			adder_op_b_negate: adder_in_b = operand_b_neg;
			default: adder_in_b = {operand_b_i, 1'b0};
		endcase
	end
	assign adder_result_ext_o = $unsigned(adder_in_a) + $unsigned(adder_in_b);
	assign adder_result = adder_result_ext_o[32:1];
	assign adder_result_o = adder_result;
	wire is_equal;
	reg is_greater_equal;
	reg cmp_signed;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (operator_i)
			7'd27, 7'd25, 7'd43, 7'd31, 7'd33: cmp_signed = 1'b1;
			default: cmp_signed = 1'b0;
		endcase
	end
	assign is_equal = adder_result == 32'b00000000000000000000000000000000;
	assign is_equal_result_o = is_equal;
	always @(*) begin
		if (_sv2v_0)
			;
		if ((operand_a_i[31] ^ operand_b_i[31]) == 1'b0)
			is_greater_equal = adder_result[31] == 1'b0;
		else
			is_greater_equal = operand_a_i[31] ^ cmp_signed;
	end
	reg cmp_result;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (operator_i)
			7'd29: cmp_result = is_equal;
			7'd30: cmp_result = ~is_equal;
			7'd27, 7'd28, 7'd33, 7'd34: cmp_result = is_greater_equal;
			7'd25, 7'd26, 7'd31, 7'd32, 7'd43, 7'd44: cmp_result = ~is_greater_equal;
			default: cmp_result = is_equal;
		endcase
	end
	assign comparison_result_o = cmp_result;
	reg shift_left;
	wire shift_ones;
	wire shift_arith;
	wire shift_funnel;
	wire shift_sbmode;
	reg [5:0] shift_amt;
	wire [5:0] shift_amt_compl;
	reg [31:0] shift_operand;
	reg signed [32:0] shift_result_ext_signed;
	reg [32:0] shift_result_ext;
	reg unused_shift_result_ext;
	reg [31:0] shift_result;
	reg [31:0] shift_result_rev;
	wire bfp_op;
	wire [4:0] bfp_len;
	wire [4:0] bfp_off;
	wire [31:0] bfp_mask;
	wire [31:0] bfp_mask_rev;
	wire [31:0] bfp_result;
	assign bfp_op = (RV32B != 32'sd0 ? operator_i == 7'd55 : 1'b0);
	assign bfp_len = {~(|operand_b_i[27:24]), operand_b_i[27:24]};
	assign bfp_off = operand_b_i[20:16];
	assign bfp_mask = (RV32B != 32'sd0 ? ~(32'hffffffff << bfp_len) : {32 {1'sb0}});
	genvar _gv_i_2;
	generate
		for (_gv_i_2 = 0; _gv_i_2 < 32; _gv_i_2 = _gv_i_2 + 1) begin : gen_rev_bfp_mask
			localparam i = _gv_i_2;
			assign bfp_mask_rev[i] = bfp_mask[31 - i];
		end
	endgenerate
	assign bfp_result = (RV32B != 32'sd0 ? (~shift_result & operand_a_i) | ((operand_b_i & bfp_mask) << bfp_off) : {32 {1'sb0}});
	wire [1:1] sv2v_tmp_BA5F8;
	assign sv2v_tmp_BA5F8 = operand_b_i[5] & shift_funnel;
	always @(*) shift_amt[5] = sv2v_tmp_BA5F8;
	assign shift_amt_compl = 32 - operand_b_i[4:0];
	always @(*) begin
		if (_sv2v_0)
			;
		if (bfp_op)
			shift_amt[4:0] = bfp_off;
		else
			shift_amt[4:0] = (instr_first_cycle_i ? (operand_b_i[5] && shift_funnel ? shift_amt_compl[4:0] : operand_b_i[4:0]) : (operand_b_i[5] && shift_funnel ? operand_b_i[4:0] : shift_amt_compl[4:0]));
	end
	assign shift_sbmode = (RV32B != 32'sd0 ? ((operator_i == 7'd49) | (operator_i == 7'd50)) | (operator_i == 7'd51) : 1'b0);
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (operator_i)
			7'd10: shift_left = 1'b1;
			7'd12: shift_left = ((RV32B == 32'sd2) || (RV32B == 32'sd3) ? 1'b1 : 1'b0);
			7'd55: shift_left = (RV32B != 32'sd0 ? 1'b1 : 1'b0);
			7'd14: shift_left = (RV32B != 32'sd0 ? instr_first_cycle_i : 0);
			7'd13: shift_left = (RV32B != 32'sd0 ? ~instr_first_cycle_i : 0);
			7'd47: shift_left = (RV32B != 32'sd0 ? (shift_amt[5] ? ~instr_first_cycle_i : instr_first_cycle_i) : 1'b0);
			7'd48: shift_left = (RV32B != 32'sd0 ? (shift_amt[5] ? instr_first_cycle_i : ~instr_first_cycle_i) : 1'b0);
			default: shift_left = 1'b0;
		endcase
		if (shift_sbmode)
			shift_left = 1'b1;
	end
	assign shift_arith = operator_i == 7'd8;
	assign shift_ones = ((RV32B == 32'sd2) || (RV32B == 32'sd3) ? (operator_i == 7'd12) | (operator_i == 7'd11) : 1'b0);
	assign shift_funnel = (RV32B != 32'sd0 ? (operator_i == 7'd47) | (operator_i == 7'd48) : 1'b0);
	always @(*) begin
		if (_sv2v_0)
			;
		if (RV32B == 32'sd0)
			shift_operand = (shift_left ? operand_a_rev : operand_a_i);
		else
			(* full_case, parallel_case *)
			case (1'b1)
				bfp_op: shift_operand = bfp_mask_rev;
				shift_sbmode: shift_operand = 32'h80000000;
				default: shift_operand = (shift_left ? operand_a_rev : operand_a_i);
			endcase
		shift_result_ext_signed = $signed({shift_ones | (shift_arith & shift_operand[31]), shift_operand}) >>> shift_amt[4:0];
		shift_result_ext = $unsigned(shift_result_ext_signed);
		shift_result = shift_result_ext[31:0];
		unused_shift_result_ext = shift_result_ext[32];
		begin : sv2v_autoblock_1
			reg [31:0] i;
			for (i = 0; i < 32; i = i + 1)
				shift_result_rev[i] = shift_result[31 - i];
		end
		shift_result = (shift_left ? shift_result_rev : shift_result);
	end
	wire bwlogic_or;
	wire bwlogic_and;
	wire [31:0] bwlogic_operand_b;
	wire [31:0] bwlogic_or_result;
	wire [31:0] bwlogic_and_result;
	wire [31:0] bwlogic_xor_result;
	reg [31:0] bwlogic_result;
	reg bwlogic_op_b_negate;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (operator_i)
			7'd5, 7'd6, 7'd7: bwlogic_op_b_negate = (RV32B != 32'sd0 ? 1'b1 : 1'b0);
			7'd46: bwlogic_op_b_negate = (RV32B != 32'sd0 ? ~instr_first_cycle_i : 1'b0);
			default: bwlogic_op_b_negate = 1'b0;
		endcase
	end
	assign bwlogic_operand_b = (bwlogic_op_b_negate ? operand_b_neg[32:1] : operand_b_i);
	assign bwlogic_or_result = operand_a_i | bwlogic_operand_b;
	assign bwlogic_and_result = operand_a_i & bwlogic_operand_b;
	assign bwlogic_xor_result = operand_a_i ^ bwlogic_operand_b;
	assign bwlogic_or = (operator_i == 7'd3) | (operator_i == 7'd6);
	assign bwlogic_and = (operator_i == 7'd4) | (operator_i == 7'd7);
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (1'b1)
			bwlogic_or: bwlogic_result = bwlogic_or_result;
			bwlogic_and: bwlogic_result = bwlogic_and_result;
			default: bwlogic_result = bwlogic_xor_result;
		endcase
	end
	wire [5:0] bitcnt_result;
	wire [31:0] minmax_result;
	reg [31:0] pack_result;
	wire [31:0] sext_result;
	reg [31:0] singlebit_result;
	reg [31:0] rev_result;
	reg [31:0] shuffle_result;
	wire [31:0] xperm_result;
	reg [31:0] butterfly_result;
	reg [31:0] invbutterfly_result;
	reg [31:0] clmul_result;
	reg [31:0] multicycle_result;
	generate
		if (RV32B != 32'sd0) begin : g_alu_rvb
			wire zbe_op;
			wire bitcnt_ctz;
			wire bitcnt_clz;
			wire bitcnt_cz;
			reg [31:0] bitcnt_bits;
			wire [31:0] bitcnt_mask_op;
			reg [31:0] bitcnt_bit_mask;
			reg [191:0] bitcnt_partial;
			wire [31:0] bitcnt_partial_lsb_d;
			wire [31:0] bitcnt_partial_msb_d;
			assign bitcnt_ctz = operator_i == 7'd41;
			assign bitcnt_clz = operator_i == 7'd40;
			assign bitcnt_cz = bitcnt_ctz | bitcnt_clz;
			assign bitcnt_result = bitcnt_partial[0+:6];
			assign bitcnt_mask_op = (bitcnt_clz ? operand_a_rev : operand_a_i);
			always @(*) begin
				if (_sv2v_0)
					;
				bitcnt_bit_mask = bitcnt_mask_op;
				bitcnt_bit_mask = bitcnt_bit_mask | (bitcnt_bit_mask << 1);
				bitcnt_bit_mask = bitcnt_bit_mask | (bitcnt_bit_mask << 2);
				bitcnt_bit_mask = bitcnt_bit_mask | (bitcnt_bit_mask << 4);
				bitcnt_bit_mask = bitcnt_bit_mask | (bitcnt_bit_mask << 8);
				bitcnt_bit_mask = bitcnt_bit_mask | (bitcnt_bit_mask << 16);
				bitcnt_bit_mask = ~bitcnt_bit_mask;
			end
			assign zbe_op = (operator_i == 7'd53) | (operator_i == 7'd54);
			always @(*) begin
				if (_sv2v_0)
					;
				case (1'b1)
					zbe_op: bitcnt_bits = operand_b_i;
					bitcnt_cz: bitcnt_bits = bitcnt_bit_mask & ~bitcnt_mask_op;
					default: bitcnt_bits = operand_a_i;
				endcase
			end
			always @(*) begin
				if (_sv2v_0)
					;
				bitcnt_partial = {32 {6'b000000}};
				begin : sv2v_autoblock_2
					reg [31:0] i;
					for (i = 1; i < 32; i = i + 2)
						bitcnt_partial[(31 - i) * 6+:6] = {5'h00, bitcnt_bits[i]} + {5'h00, bitcnt_bits[i - 1]};
				end
				begin : sv2v_autoblock_3
					reg [31:0] i;
					for (i = 3; i < 32; i = i + 4)
						bitcnt_partial[(31 - i) * 6+:6] = bitcnt_partial[(33 - i) * 6+:6] + bitcnt_partial[(31 - i) * 6+:6];
				end
				begin : sv2v_autoblock_4
					reg [31:0] i;
					for (i = 7; i < 32; i = i + 8)
						bitcnt_partial[(31 - i) * 6+:6] = bitcnt_partial[(35 - i) * 6+:6] + bitcnt_partial[(31 - i) * 6+:6];
				end
				begin : sv2v_autoblock_5
					reg [31:0] i;
					for (i = 15; i < 32; i = i + 16)
						bitcnt_partial[(31 - i) * 6+:6] = bitcnt_partial[(39 - i) * 6+:6] + bitcnt_partial[(31 - i) * 6+:6];
				end
				bitcnt_partial[0+:6] = bitcnt_partial[96+:6] + bitcnt_partial[0+:6];
				bitcnt_partial[48+:6] = bitcnt_partial[96+:6] + bitcnt_partial[48+:6];
				begin : sv2v_autoblock_6
					reg [31:0] i;
					for (i = 11; i < 32; i = i + 8)
						bitcnt_partial[(31 - i) * 6+:6] = bitcnt_partial[(35 - i) * 6+:6] + bitcnt_partial[(31 - i) * 6+:6];
				end
				begin : sv2v_autoblock_7
					reg [31:0] i;
					for (i = 5; i < 32; i = i + 4)
						bitcnt_partial[(31 - i) * 6+:6] = bitcnt_partial[(33 - i) * 6+:6] + bitcnt_partial[(31 - i) * 6+:6];
				end
				bitcnt_partial[186+:6] = {5'h00, bitcnt_bits[0]};
				begin : sv2v_autoblock_8
					reg [31:0] i;
					for (i = 2; i < 32; i = i + 2)
						bitcnt_partial[(31 - i) * 6+:6] = bitcnt_partial[(32 - i) * 6+:6] + {5'h00, bitcnt_bits[i]};
				end
			end
			assign minmax_result = (cmp_result ? operand_a_i : operand_b_i);
			wire packu;
			wire packh;
			assign packu = operator_i == 7'd36;
			assign packh = operator_i == 7'd37;
			always @(*) begin
				if (_sv2v_0)
					;
				(* full_case, parallel_case *)
				case (1'b1)
					packu: pack_result = {operand_b_i[31:16], operand_a_i[31:16]};
					packh: pack_result = {16'h0000, operand_b_i[7:0], operand_a_i[7:0]};
					default: pack_result = {operand_b_i[15:0], operand_a_i[15:0]};
				endcase
			end
			assign sext_result = (operator_i == 7'd38 ? {{24 {operand_a_i[7]}}, operand_a_i[7:0]} : {{16 {operand_a_i[15]}}, operand_a_i[15:0]});
			always @(*) begin
				if (_sv2v_0)
					;
				(* full_case, parallel_case *)
				case (operator_i)
					7'd49: singlebit_result = operand_a_i | shift_result;
					7'd50: singlebit_result = operand_a_i & ~shift_result;
					7'd51: singlebit_result = operand_a_i ^ shift_result;
					default: singlebit_result = {31'h00000000, shift_result[0]};
				endcase
			end
			wire [4:0] zbp_shift_amt;
			wire gorc_op;
			assign gorc_op = operator_i == 7'd16;
			assign zbp_shift_amt[2:0] = ((RV32B == 32'sd2) || (RV32B == 32'sd3) ? shift_amt[2:0] : {3 {shift_amt[0]}});
			assign zbp_shift_amt[4:3] = ((RV32B == 32'sd2) || (RV32B == 32'sd3) ? shift_amt[4:3] : {2 {shift_amt[3]}});
			always @(*) begin
				if (_sv2v_0)
					;
				rev_result = operand_a_i;
				if (zbp_shift_amt[0])
					rev_result = ((gorc_op ? rev_result : 32'h00000000) | ((rev_result & 32'h55555555) << 1)) | ((rev_result & 32'haaaaaaaa) >> 1);
				if (zbp_shift_amt[1])
					rev_result = ((gorc_op ? rev_result : 32'h00000000) | ((rev_result & 32'h33333333) << 2)) | ((rev_result & 32'hcccccccc) >> 2);
				if (zbp_shift_amt[2])
					rev_result = ((gorc_op ? rev_result : 32'h00000000) | ((rev_result & 32'h0f0f0f0f) << 4)) | ((rev_result & 32'hf0f0f0f0) >> 4);
				if (zbp_shift_amt[3])
					rev_result = ((((RV32B == 32'sd2) || (RV32B == 32'sd3)) && gorc_op ? rev_result : 32'h00000000) | ((rev_result & 32'h00ff00ff) << 8)) | ((rev_result & 32'hff00ff00) >> 8);
				if (zbp_shift_amt[4])
					rev_result = ((((RV32B == 32'sd2) || (RV32B == 32'sd3)) && gorc_op ? rev_result : 32'h00000000) | ((rev_result & 32'h0000ffff) << 16)) | ((rev_result & 32'hffff0000) >> 16);
			end
			wire crc_hmode;
			wire crc_bmode;
			wire [31:0] clmul_result_rev;
			if ((RV32B == 32'sd2) || (RV32B == 32'sd3)) begin : gen_alu_rvb_otearlgrey_full
				localparam [127:0] SHUFFLE_MASK_L = 128'h00ff00000f000f003030303044444444;
				localparam [127:0] SHUFFLE_MASK_R = 128'h0000ff0000f000f00c0c0c0c22222222;
				localparam [127:0] FLIP_MASK_L = 128'h22001100004400004411000011000000;
				localparam [127:0] FLIP_MASK_R = 128'h00880044000022000000882200000088;
				wire [31:0] SHUFFLE_MASK_NOT [0:3];
				genvar _gv_i_3;
				for (_gv_i_3 = 0; _gv_i_3 < 4; _gv_i_3 = _gv_i_3 + 1) begin : gen_shuffle_mask_not
					localparam i = _gv_i_3;
					assign SHUFFLE_MASK_NOT[i] = ~(SHUFFLE_MASK_L[(3 - i) * 32+:32] | SHUFFLE_MASK_R[(3 - i) * 32+:32]);
				end
				wire shuffle_flip;
				assign shuffle_flip = operator_i == 7'd18;
				reg [3:0] shuffle_mode;
				always @(*) begin
					if (_sv2v_0)
						;
					shuffle_result = operand_a_i;
					if (shuffle_flip) begin
						shuffle_mode[3] = shift_amt[0];
						shuffle_mode[2] = shift_amt[1];
						shuffle_mode[1] = shift_amt[2];
						shuffle_mode[0] = shift_amt[3];
					end
					else
						shuffle_mode = shift_amt[3:0];
					if (shuffle_flip)
						shuffle_result = ((((((((shuffle_result & 32'h88224411) | ((shuffle_result << 6) & FLIP_MASK_L[96+:32])) | ((shuffle_result >> 6) & FLIP_MASK_R[96+:32])) | ((shuffle_result << 9) & FLIP_MASK_L[64+:32])) | ((shuffle_result >> 9) & FLIP_MASK_R[64+:32])) | ((shuffle_result << 15) & FLIP_MASK_L[32+:32])) | ((shuffle_result >> 15) & FLIP_MASK_R[32+:32])) | ((shuffle_result << 21) & FLIP_MASK_L[0+:32])) | ((shuffle_result >> 21) & FLIP_MASK_R[0+:32]);
					if (shuffle_mode[3])
						shuffle_result = (shuffle_result & SHUFFLE_MASK_NOT[0]) | (((shuffle_result << 8) & SHUFFLE_MASK_L[96+:32]) | ((shuffle_result >> 8) & SHUFFLE_MASK_R[96+:32]));
					if (shuffle_mode[2])
						shuffle_result = (shuffle_result & SHUFFLE_MASK_NOT[1]) | (((shuffle_result << 4) & SHUFFLE_MASK_L[64+:32]) | ((shuffle_result >> 4) & SHUFFLE_MASK_R[64+:32]));
					if (shuffle_mode[1])
						shuffle_result = (shuffle_result & SHUFFLE_MASK_NOT[2]) | (((shuffle_result << 2) & SHUFFLE_MASK_L[32+:32]) | ((shuffle_result >> 2) & SHUFFLE_MASK_R[32+:32]));
					if (shuffle_mode[0])
						shuffle_result = (shuffle_result & SHUFFLE_MASK_NOT[3]) | (((shuffle_result << 1) & SHUFFLE_MASK_L[0+:32]) | ((shuffle_result >> 1) & SHUFFLE_MASK_R[0+:32]));
					if (shuffle_flip)
						shuffle_result = ((((((((shuffle_result & 32'h88224411) | ((shuffle_result << 6) & FLIP_MASK_L[96+:32])) | ((shuffle_result >> 6) & FLIP_MASK_R[96+:32])) | ((shuffle_result << 9) & FLIP_MASK_L[64+:32])) | ((shuffle_result >> 9) & FLIP_MASK_R[64+:32])) | ((shuffle_result << 15) & FLIP_MASK_L[32+:32])) | ((shuffle_result >> 15) & FLIP_MASK_R[32+:32])) | ((shuffle_result << 21) & FLIP_MASK_L[0+:32])) | ((shuffle_result >> 21) & FLIP_MASK_R[0+:32]);
				end
				wire [23:0] sel_n;
				wire [7:0] vld_n;
				wire [7:0] sel_b;
				wire [3:0] vld_b;
				wire [1:0] sel_h;
				wire [1:0] vld_h;
				genvar _gv_i_4;
				for (_gv_i_4 = 0; _gv_i_4 < 8; _gv_i_4 = _gv_i_4 + 1) begin : gen_sel_vld_n
					localparam i = _gv_i_4;
					assign sel_n[i * 3+:3] = operand_b_i[i * 4+:3];
					assign vld_n[i] = ~|operand_b_i[(i * 4) + 3+:1];
				end
				genvar _gv_i_5;
				for (_gv_i_5 = 0; _gv_i_5 < 4; _gv_i_5 = _gv_i_5 + 1) begin : gen_sel_vld_b
					localparam i = _gv_i_5;
					assign sel_b[i * 2+:2] = operand_b_i[i * 8+:2];
					assign vld_b[i] = ~|operand_b_i[(i * 8) + 2+:6];
				end
				genvar _gv_i_6;
				for (_gv_i_6 = 0; _gv_i_6 < 2; _gv_i_6 = _gv_i_6 + 1) begin : gen_sel_vld_h
					localparam i = _gv_i_6;
					assign sel_h[i+:1] = operand_b_i[i * 16+:1];
					assign vld_h[i] = ~|operand_b_i[(i * 16) + 1+:15];
				end
				reg [23:0] sel;
				reg [7:0] vld;
				always @(*) begin
					if (_sv2v_0)
						;
					(* full_case, parallel_case *)
					case (operator_i)
						7'd19: begin
							sel = sel_n;
							vld = vld_n;
						end
						7'd20: begin : sv2v_autoblock_9
							reg signed [31:0] b;
							for (b = 0; b < 4; b = b + 1)
								begin
									sel[((b * 2) + 0) * 3+:3] = {sel_b[b * 2+:2], 1'b0};
									sel[((b * 2) + 1) * 3+:3] = {sel_b[b * 2+:2], 1'b1};
									vld[b * 2+:2] = {2 {vld_b[b]}};
								end
						end
						7'd21: begin : sv2v_autoblock_10
							reg signed [31:0] h;
							for (h = 0; h < 2; h = h + 1)
								begin
									sel[((h * 4) + 0) * 3+:3] = {sel_h[h+:1], 2'b00};
									sel[((h * 4) + 1) * 3+:3] = {sel_h[h+:1], 2'b01};
									sel[((h * 4) + 2) * 3+:3] = {sel_h[h+:1], 2'b10};
									sel[((h * 4) + 3) * 3+:3] = {sel_h[h+:1], 2'b11};
									vld[h * 4+:4] = {4 {vld_h[h]}};
								end
						end
						default: begin
							sel = sel_n;
							vld = 1'sb0;
						end
					endcase
				end
				wire [31:0] val_n;
				wire [31:0] xperm_n;
				assign val_n = operand_a_i;
				genvar _gv_i_7;
				for (_gv_i_7 = 0; _gv_i_7 < 8; _gv_i_7 = _gv_i_7 + 1) begin : gen_xperm_n
					localparam i = _gv_i_7;
					assign xperm_n[i * 4+:4] = (vld[i] ? val_n[sel[i * 3+:3] * 4+:4] : {4 {1'sb0}});
				end
				assign xperm_result = xperm_n;
				wire clmul_rmode;
				wire clmul_hmode;
				reg [31:0] clmul_op_a;
				reg [31:0] clmul_op_b;
				wire [31:0] operand_b_rev;
				wire [31:0] clmul_and_stage [0:31];
				wire [31:0] clmul_xor_stage1 [0:15];
				wire [31:0] clmul_xor_stage2 [0:7];
				wire [31:0] clmul_xor_stage3 [0:3];
				wire [31:0] clmul_xor_stage4 [0:1];
				wire [31:0] clmul_result_raw;
				genvar _gv_i_8;
				for (_gv_i_8 = 0; _gv_i_8 < 32; _gv_i_8 = _gv_i_8 + 1) begin : gen_rev_operand_b
					localparam i = _gv_i_8;
					assign operand_b_rev[i] = operand_b_i[31 - i];
				end
				assign clmul_rmode = operator_i == 7'd57;
				assign clmul_hmode = operator_i == 7'd58;
				localparam [31:0] CRC32_POLYNOMIAL = 32'h04c11db7;
				localparam [31:0] CRC32_MU_REV = 32'hf7011641;
				localparam [31:0] CRC32C_POLYNOMIAL = 32'h1edc6f41;
				localparam [31:0] CRC32C_MU_REV = 32'hdea713f1;
				wire crc_op;
				wire crc_cpoly;
				reg [31:0] crc_operand;
				wire [31:0] crc_poly;
				wire [31:0] crc_mu_rev;
				assign crc_op = (((((operator_i == 7'd64) | (operator_i == 7'd63)) | (operator_i == 7'd62)) | (operator_i == 7'd61)) | (operator_i == 7'd60)) | (operator_i == 7'd59);
				assign crc_cpoly = ((operator_i == 7'd64) | (operator_i == 7'd62)) | (operator_i == 7'd60);
				assign crc_hmode = (operator_i == 7'd61) | (operator_i == 7'd62);
				assign crc_bmode = (operator_i == 7'd59) | (operator_i == 7'd60);
				assign crc_poly = (crc_cpoly ? CRC32C_POLYNOMIAL : CRC32_POLYNOMIAL);
				assign crc_mu_rev = (crc_cpoly ? CRC32C_MU_REV : CRC32_MU_REV);
				always @(*) begin
					if (_sv2v_0)
						;
					(* full_case, parallel_case *)
					case (1'b1)
						crc_bmode: crc_operand = {operand_a_i[7:0], 24'h000000};
						crc_hmode: crc_operand = {operand_a_i[15:0], 16'h0000};
						default: crc_operand = operand_a_i;
					endcase
				end
				always @(*) begin
					if (_sv2v_0)
						;
					if (crc_op) begin
						clmul_op_a = (instr_first_cycle_i ? crc_operand : imd_val_q_i[32+:32]);
						clmul_op_b = (instr_first_cycle_i ? crc_mu_rev : crc_poly);
					end
					else begin
						clmul_op_a = (clmul_rmode | clmul_hmode ? operand_a_rev : operand_a_i);
						clmul_op_b = (clmul_rmode | clmul_hmode ? operand_b_rev : operand_b_i);
					end
				end
				genvar _gv_i_9;
				for (_gv_i_9 = 0; _gv_i_9 < 32; _gv_i_9 = _gv_i_9 + 1) begin : gen_clmul_and_op
					localparam i = _gv_i_9;
					assign clmul_and_stage[i] = (clmul_op_b[i] ? clmul_op_a << i : {32 {1'sb0}});
				end
				genvar _gv_i_10;
				for (_gv_i_10 = 0; _gv_i_10 < 16; _gv_i_10 = _gv_i_10 + 1) begin : gen_clmul_xor_op_l1
					localparam i = _gv_i_10;
					assign clmul_xor_stage1[i] = clmul_and_stage[2 * i] ^ clmul_and_stage[(2 * i) + 1];
				end
				genvar _gv_i_11;
				for (_gv_i_11 = 0; _gv_i_11 < 8; _gv_i_11 = _gv_i_11 + 1) begin : gen_clmul_xor_op_l2
					localparam i = _gv_i_11;
					assign clmul_xor_stage2[i] = clmul_xor_stage1[2 * i] ^ clmul_xor_stage1[(2 * i) + 1];
				end
				genvar _gv_i_12;
				for (_gv_i_12 = 0; _gv_i_12 < 4; _gv_i_12 = _gv_i_12 + 1) begin : gen_clmul_xor_op_l3
					localparam i = _gv_i_12;
					assign clmul_xor_stage3[i] = clmul_xor_stage2[2 * i] ^ clmul_xor_stage2[(2 * i) + 1];
				end
				genvar _gv_i_13;
				for (_gv_i_13 = 0; _gv_i_13 < 2; _gv_i_13 = _gv_i_13 + 1) begin : gen_clmul_xor_op_l4
					localparam i = _gv_i_13;
					assign clmul_xor_stage4[i] = clmul_xor_stage3[2 * i] ^ clmul_xor_stage3[(2 * i) + 1];
				end
				assign clmul_result_raw = clmul_xor_stage4[0] ^ clmul_xor_stage4[1];
				genvar _gv_i_14;
				for (_gv_i_14 = 0; _gv_i_14 < 32; _gv_i_14 = _gv_i_14 + 1) begin : gen_rev_clmul_result
					localparam i = _gv_i_14;
					assign clmul_result_rev[i] = clmul_result_raw[31 - i];
				end
				always @(*) begin
					if (_sv2v_0)
						;
					case (1'b1)
						clmul_rmode: clmul_result = clmul_result_rev;
						clmul_hmode: clmul_result = {1'b0, clmul_result_rev[31:1]};
						default: clmul_result = clmul_result_raw;
					endcase
				end
			end
			else begin : gen_alu_rvb_not_otearlgrey_full
				wire [32:1] sv2v_tmp_4A308;
				assign sv2v_tmp_4A308 = 1'sb0;
				always @(*) shuffle_result = sv2v_tmp_4A308;
				assign xperm_result = 1'sb0;
				wire [32:1] sv2v_tmp_31DA6;
				assign sv2v_tmp_31DA6 = 1'sb0;
				always @(*) clmul_result = sv2v_tmp_31DA6;
				assign clmul_result_rev = 1'sb0;
				assign crc_bmode = 1'sb0;
				assign crc_hmode = 1'sb0;
			end
			if (RV32B == 32'sd3) begin : gen_alu_rvb_full
				reg [191:0] bitcnt_partial_q;
				genvar _gv_i_15;
				for (_gv_i_15 = 0; _gv_i_15 < 32; _gv_i_15 = _gv_i_15 + 1) begin : gen_bitcnt_reg_in_lsb
					localparam i = _gv_i_15;
					assign bitcnt_partial_lsb_d[i] = bitcnt_partial[(31 - i) * 6];
				end
				genvar _gv_i_16;
				for (_gv_i_16 = 0; _gv_i_16 < 16; _gv_i_16 = _gv_i_16 + 1) begin : gen_bitcnt_reg_in_b1
					localparam i = _gv_i_16;
					assign bitcnt_partial_msb_d[i] = bitcnt_partial[((31 - ((2 * i) + 1)) * 6) + 1];
				end
				genvar _gv_i_17;
				for (_gv_i_17 = 0; _gv_i_17 < 8; _gv_i_17 = _gv_i_17 + 1) begin : gen_bitcnt_reg_in_b2
					localparam i = _gv_i_17;
					assign bitcnt_partial_msb_d[16 + i] = bitcnt_partial[((31 - ((4 * i) + 3)) * 6) + 2];
				end
				genvar _gv_i_18;
				for (_gv_i_18 = 0; _gv_i_18 < 4; _gv_i_18 = _gv_i_18 + 1) begin : gen_bitcnt_reg_in_b3
					localparam i = _gv_i_18;
					assign bitcnt_partial_msb_d[24 + i] = bitcnt_partial[((31 - ((8 * i) + 7)) * 6) + 3];
				end
				genvar _gv_i_19;
				for (_gv_i_19 = 0; _gv_i_19 < 2; _gv_i_19 = _gv_i_19 + 1) begin : gen_bitcnt_reg_in_b4
					localparam i = _gv_i_19;
					assign bitcnt_partial_msb_d[28 + i] = bitcnt_partial[((31 - ((16 * i) + 15)) * 6) + 4];
				end
				assign bitcnt_partial_msb_d[30] = bitcnt_partial[5];
				assign bitcnt_partial_msb_d[31] = 1'b0;
				always @(*) begin
					if (_sv2v_0)
						;
					bitcnt_partial_q = {32 {6'b000000}};
					begin : sv2v_autoblock_11
						reg [31:0] i;
						for (i = 0; i < 32; i = i + 1)
							begin : gen_bitcnt_reg_out_lsb
								bitcnt_partial_q[(31 - i) * 6] = imd_val_q_i[32 + i];
							end
					end
					begin : sv2v_autoblock_12
						reg [31:0] i;
						for (i = 0; i < 16; i = i + 1)
							begin : gen_bitcnt_reg_out_b1
								bitcnt_partial_q[((31 - ((2 * i) + 1)) * 6) + 1] = imd_val_q_i[0 + i];
							end
					end
					begin : sv2v_autoblock_13
						reg [31:0] i;
						for (i = 0; i < 8; i = i + 1)
							begin : gen_bitcnt_reg_out_b2
								bitcnt_partial_q[((31 - ((4 * i) + 3)) * 6) + 2] = imd_val_q_i[16 + i];
							end
					end
					begin : sv2v_autoblock_14
						reg [31:0] i;
						for (i = 0; i < 4; i = i + 1)
							begin : gen_bitcnt_reg_out_b3
								bitcnt_partial_q[((31 - ((8 * i) + 7)) * 6) + 3] = imd_val_q_i[24 + i];
							end
					end
					begin : sv2v_autoblock_15
						reg [31:0] i;
						for (i = 0; i < 2; i = i + 1)
							begin : gen_bitcnt_reg_out_b4
								bitcnt_partial_q[((31 - ((16 * i) + 15)) * 6) + 4] = imd_val_q_i[28 + i];
							end
					end
					bitcnt_partial_q[5] = imd_val_q_i[30];
				end
				wire [31:0] butterfly_mask_l [0:4];
				wire [31:0] butterfly_mask_r [0:4];
				wire [31:0] butterfly_mask_not [0:4];
				wire [31:0] lrotc_stage [0:4];
				genvar _gv_stg_1;
				for (_gv_stg_1 = 0; _gv_stg_1 < 5; _gv_stg_1 = _gv_stg_1 + 1) begin : gen_butterfly_ctrl_stage
					localparam stg = _gv_stg_1;
					genvar _gv_seg_1;
					for (_gv_seg_1 = 0; _gv_seg_1 < (2 ** stg); _gv_seg_1 = _gv_seg_1 + 1) begin : gen_butterfly_ctrl
						localparam seg = _gv_seg_1;
						assign lrotc_stage[stg][((2 * (16 >> stg)) * (seg + 1)) - 1:(2 * (16 >> stg)) * seg] = {{16 >> stg {1'b0}}, {16 >> stg {1'b1}}} << bitcnt_partial_q[((32 - ((16 >> stg) * ((2 * seg) + 1))) * 6) + ($clog2(16 >> stg) >= 0 ? $clog2(16 >> stg) : ($clog2(16 >> stg) + ($clog2(16 >> stg) >= 0 ? $clog2(16 >> stg) + 1 : 1 - $clog2(16 >> stg))) - 1)-:($clog2(16 >> stg) >= 0 ? $clog2(16 >> stg) + 1 : 1 - $clog2(16 >> stg))];
						assign butterfly_mask_l[stg][((16 >> stg) * ((2 * seg) + 2)) - 1:(16 >> stg) * ((2 * seg) + 1)] = ~lrotc_stage[stg][((16 >> stg) * ((2 * seg) + 2)) - 1:(16 >> stg) * ((2 * seg) + 1)];
						assign butterfly_mask_r[stg][((16 >> stg) * ((2 * seg) + 1)) - 1:(16 >> stg) * (2 * seg)] = ~lrotc_stage[stg][((16 >> stg) * ((2 * seg) + 2)) - 1:(16 >> stg) * ((2 * seg) + 1)];
						assign butterfly_mask_l[stg][((16 >> stg) * ((2 * seg) + 1)) - 1:(16 >> stg) * (2 * seg)] = 1'sb0;
						assign butterfly_mask_r[stg][((16 >> stg) * ((2 * seg) + 2)) - 1:(16 >> stg) * ((2 * seg) + 1)] = 1'sb0;
					end
				end
				genvar _gv_stg_2;
				for (_gv_stg_2 = 0; _gv_stg_2 < 5; _gv_stg_2 = _gv_stg_2 + 1) begin : gen_butterfly_not
					localparam stg = _gv_stg_2;
					assign butterfly_mask_not[stg] = ~(butterfly_mask_l[stg] | butterfly_mask_r[stg]);
				end
				always @(*) begin
					if (_sv2v_0)
						;
					butterfly_result = operand_a_i;
					butterfly_result = ((butterfly_result & butterfly_mask_not[0]) | ((butterfly_result & butterfly_mask_l[0]) >> 16)) | ((butterfly_result & butterfly_mask_r[0]) << 16);
					butterfly_result = ((butterfly_result & butterfly_mask_not[1]) | ((butterfly_result & butterfly_mask_l[1]) >> 8)) | ((butterfly_result & butterfly_mask_r[1]) << 8);
					butterfly_result = ((butterfly_result & butterfly_mask_not[2]) | ((butterfly_result & butterfly_mask_l[2]) >> 4)) | ((butterfly_result & butterfly_mask_r[2]) << 4);
					butterfly_result = ((butterfly_result & butterfly_mask_not[3]) | ((butterfly_result & butterfly_mask_l[3]) >> 2)) | ((butterfly_result & butterfly_mask_r[3]) << 2);
					butterfly_result = ((butterfly_result & butterfly_mask_not[4]) | ((butterfly_result & butterfly_mask_l[4]) >> 1)) | ((butterfly_result & butterfly_mask_r[4]) << 1);
					butterfly_result = butterfly_result & operand_b_i;
				end
				always @(*) begin
					if (_sv2v_0)
						;
					invbutterfly_result = operand_a_i & operand_b_i;
					invbutterfly_result = ((invbutterfly_result & butterfly_mask_not[4]) | ((invbutterfly_result & butterfly_mask_l[4]) >> 1)) | ((invbutterfly_result & butterfly_mask_r[4]) << 1);
					invbutterfly_result = ((invbutterfly_result & butterfly_mask_not[3]) | ((invbutterfly_result & butterfly_mask_l[3]) >> 2)) | ((invbutterfly_result & butterfly_mask_r[3]) << 2);
					invbutterfly_result = ((invbutterfly_result & butterfly_mask_not[2]) | ((invbutterfly_result & butterfly_mask_l[2]) >> 4)) | ((invbutterfly_result & butterfly_mask_r[2]) << 4);
					invbutterfly_result = ((invbutterfly_result & butterfly_mask_not[1]) | ((invbutterfly_result & butterfly_mask_l[1]) >> 8)) | ((invbutterfly_result & butterfly_mask_r[1]) << 8);
					invbutterfly_result = ((invbutterfly_result & butterfly_mask_not[0]) | ((invbutterfly_result & butterfly_mask_l[0]) >> 16)) | ((invbutterfly_result & butterfly_mask_r[0]) << 16);
				end
			end
			else begin : gen_alu_rvb_not_full
				wire [31:0] unused_imd_val_q_1;
				assign unused_imd_val_q_1 = imd_val_q_i[0+:32];
				wire [32:1] sv2v_tmp_98122;
				assign sv2v_tmp_98122 = 1'sb0;
				always @(*) butterfly_result = sv2v_tmp_98122;
				wire [32:1] sv2v_tmp_B39E0;
				assign sv2v_tmp_B39E0 = 1'sb0;
				always @(*) invbutterfly_result = sv2v_tmp_B39E0;
				assign bitcnt_partial_lsb_d = 1'sb0;
				assign bitcnt_partial_msb_d = 1'sb0;
			end
			always @(*) begin
				if (_sv2v_0)
					;
				(* full_case, parallel_case *)
				case (operator_i)
					7'd45: begin
						multicycle_result = (operand_b_i == 32'h00000000 ? operand_a_i : imd_val_q_i[32+:32]);
						imd_val_d_o = {operand_a_i, 32'h00000000};
						if (instr_first_cycle_i)
							imd_val_we_o = 2'b01;
						else
							imd_val_we_o = 2'b00;
					end
					7'd46: begin
						multicycle_result = imd_val_q_i[32+:32] | bwlogic_and_result;
						imd_val_d_o = {bwlogic_and_result, 32'h00000000};
						if (instr_first_cycle_i)
							imd_val_we_o = 2'b01;
						else
							imd_val_we_o = 2'b00;
					end
					7'd48, 7'd47, 7'd14, 7'd13: begin
						if (shift_amt[4:0] == 5'h00)
							multicycle_result = (shift_amt[5] ? operand_a_i : imd_val_q_i[32+:32]);
						else
							multicycle_result = imd_val_q_i[32+:32] | shift_result;
						imd_val_d_o = {shift_result, 32'h00000000};
						if (instr_first_cycle_i)
							imd_val_we_o = 2'b01;
						else
							imd_val_we_o = 2'b00;
					end
					7'd63, 7'd64, 7'd61, 7'd62, 7'd59, 7'd60:
						if ((RV32B == 32'sd2) || (RV32B == 32'sd3)) begin
							(* full_case, parallel_case *)
							case (1'b1)
								crc_bmode: multicycle_result = clmul_result_rev ^ (operand_a_i >> 8);
								crc_hmode: multicycle_result = clmul_result_rev ^ (operand_a_i >> 16);
								default: multicycle_result = clmul_result_rev;
							endcase
							imd_val_d_o = {clmul_result_rev, 32'h00000000};
							if (instr_first_cycle_i)
								imd_val_we_o = 2'b01;
							else
								imd_val_we_o = 2'b00;
						end
						else begin
							imd_val_d_o = {operand_a_i, 32'h00000000};
							imd_val_we_o = 2'b00;
							multicycle_result = 1'sb0;
						end
					7'd53, 7'd54:
						if (RV32B == 32'sd3) begin
							multicycle_result = (operator_i == 7'd54 ? butterfly_result : invbutterfly_result);
							imd_val_d_o = {bitcnt_partial_lsb_d, bitcnt_partial_msb_d};
							if (instr_first_cycle_i)
								imd_val_we_o = 2'b11;
							else
								imd_val_we_o = 2'b00;
						end
						else begin
							imd_val_d_o = {operand_a_i, 32'h00000000};
							imd_val_we_o = 2'b00;
							multicycle_result = 1'sb0;
						end
					default: begin
						imd_val_d_o = {operand_a_i, 32'h00000000};
						imd_val_we_o = 2'b00;
						multicycle_result = 1'sb0;
					end
				endcase
			end
		end
		else begin : g_no_alu_rvb
			wire [63:0] unused_imd_val_q;
			assign unused_imd_val_q = imd_val_q_i;
			wire [31:0] unused_butterfly_result;
			assign unused_butterfly_result = butterfly_result;
			wire [31:0] unused_invbutterfly_result;
			assign unused_invbutterfly_result = invbutterfly_result;
			assign bitcnt_result = 1'sb0;
			assign minmax_result = 1'sb0;
			wire [32:1] sv2v_tmp_A0513;
			assign sv2v_tmp_A0513 = 1'sb0;
			always @(*) pack_result = sv2v_tmp_A0513;
			assign sext_result = 1'sb0;
			wire [32:1] sv2v_tmp_75CE4;
			assign sv2v_tmp_75CE4 = 1'sb0;
			always @(*) singlebit_result = sv2v_tmp_75CE4;
			wire [32:1] sv2v_tmp_FA09A;
			assign sv2v_tmp_FA09A = 1'sb0;
			always @(*) rev_result = sv2v_tmp_FA09A;
			wire [32:1] sv2v_tmp_4A308;
			assign sv2v_tmp_4A308 = 1'sb0;
			always @(*) shuffle_result = sv2v_tmp_4A308;
			assign xperm_result = 1'sb0;
			wire [32:1] sv2v_tmp_98122;
			assign sv2v_tmp_98122 = 1'sb0;
			always @(*) butterfly_result = sv2v_tmp_98122;
			wire [32:1] sv2v_tmp_B39E0;
			assign sv2v_tmp_B39E0 = 1'sb0;
			always @(*) invbutterfly_result = sv2v_tmp_B39E0;
			wire [32:1] sv2v_tmp_31DA6;
			assign sv2v_tmp_31DA6 = 1'sb0;
			always @(*) clmul_result = sv2v_tmp_31DA6;
			wire [32:1] sv2v_tmp_BC1B9;
			assign sv2v_tmp_BC1B9 = 1'sb0;
			always @(*) multicycle_result = sv2v_tmp_BC1B9;
			wire [64:1] sv2v_tmp_42A49;
			assign sv2v_tmp_42A49 = {2 {32'b00000000000000000000000000000000}};
			always @(*) imd_val_d_o = sv2v_tmp_42A49;
			wire [2:1] sv2v_tmp_0E15E;
			assign sv2v_tmp_0E15E = {2 {1'b0}};
			always @(*) imd_val_we_o = sv2v_tmp_0E15E;
		end
	endgenerate
	always @(*) begin
		if (_sv2v_0)
			;
		result_o = 1'sb0;
		(* full_case, parallel_case *)
		case (operator_i)
			7'd2, 7'd5, 7'd3, 7'd6, 7'd4, 7'd7: result_o = bwlogic_result;
			7'd0, 7'd1, 7'd22, 7'd23, 7'd24: result_o = adder_result;
			7'd10, 7'd9, 7'd8, 7'd12, 7'd11: result_o = shift_result;
			7'd17, 7'd18: result_o = shuffle_result;
			7'd19, 7'd20, 7'd21: result_o = xperm_result;
			7'd29, 7'd30, 7'd27, 7'd28, 7'd25, 7'd26, 7'd43, 7'd44: result_o = {31'h00000000, cmp_result};
			7'd31, 7'd33, 7'd32, 7'd34: result_o = minmax_result;
			7'd40, 7'd41, 7'd42: result_o = {26'h0000000, bitcnt_result};
			7'd35, 7'd37, 7'd36: result_o = pack_result;
			7'd38, 7'd39: result_o = sext_result;
			7'd46, 7'd45, 7'd47, 7'd48, 7'd14, 7'd13, 7'd63, 7'd64, 7'd61, 7'd62, 7'd59, 7'd60, 7'd53, 7'd54: result_o = multicycle_result;
			7'd49, 7'd50, 7'd51, 7'd52: result_o = singlebit_result;
			7'd15, 7'd16: result_o = rev_result;
			7'd55: result_o = bfp_result;
			7'd56, 7'd57, 7'd58: result_o = clmul_result;
			default:
				;
		endcase
	end
	wire unused_shift_amt_compl;
	assign unused_shift_amt_compl = shift_amt_compl[5];
	initial _sv2v_0 = 0;
endmodule
module cve2_compressed_decoder (
	clk_i,
	rst_ni,
	valid_i,
	instr_i,
	instr_o,
	is_compressed_o,
	illegal_instr_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire valid_i;
	input wire [31:0] instr_i;
	output reg [31:0] instr_o;
	output wire is_compressed_o;
	output reg illegal_instr_o;
	wire unused_valid;
	assign unused_valid = valid_i;
	always @(*) begin
		if (_sv2v_0)
			;
		instr_o = instr_i;
		illegal_instr_o = 1'b0;
		(* full_case, parallel_case *)
		case (instr_i[1:0])
			2'b00:
				(* full_case, parallel_case *)
				case (instr_i[15:13])
					3'b000: begin
						instr_o = {2'b00, instr_i[10:7], instr_i[12:11], instr_i[5], instr_i[6], 12'h041, instr_i[4:2], 7'h13};
						if (instr_i[12:5] == 8'b00000000)
							illegal_instr_o = 1'b1;
					end
					3'b010: instr_o = {5'b00000, instr_i[5], instr_i[12:10], instr_i[6], 4'b0001, instr_i[9:7], 5'b01001, instr_i[4:2], 7'h03};
					3'b110: instr_o = {5'b00000, instr_i[5], instr_i[12], 2'b01, instr_i[4:2], 2'b01, instr_i[9:7], 3'b010, instr_i[11:10], instr_i[6], 9'h023};
					3'b001, 3'b011, 3'b100, 3'b101, 3'b111: illegal_instr_o = 1'b1;
					default: illegal_instr_o = 1'b1;
				endcase
			2'b01:
				(* full_case, parallel_case *)
				case (instr_i[15:13])
					3'b000: instr_o = {{6 {instr_i[12]}}, instr_i[12], instr_i[6:2], instr_i[11:7], 3'b000, instr_i[11:7], 7'h13};
					3'b001, 3'b101: instr_o = {instr_i[12], instr_i[8], instr_i[10:9], instr_i[6], instr_i[7], instr_i[2], instr_i[11], instr_i[5:3], {9 {instr_i[12]}}, 4'b0000, ~instr_i[15], 7'h6f};
					3'b010: instr_o = {{6 {instr_i[12]}}, instr_i[12], instr_i[6:2], 8'b00000000, instr_i[11:7], 7'h13};
					3'b011: begin
						instr_o = {{15 {instr_i[12]}}, instr_i[6:2], instr_i[11:7], 7'h37};
						if (instr_i[11:7] == 5'h02)
							instr_o = {{3 {instr_i[12]}}, instr_i[4:3], instr_i[5], instr_i[2], instr_i[6], 24'h010113};
						if ({instr_i[12], instr_i[6:2]} == 6'b000000)
							illegal_instr_o = 1'b1;
					end
					3'b100:
						(* full_case, parallel_case *)
						case (instr_i[11:10])
							2'b00, 2'b01: begin
								instr_o = {1'b0, instr_i[10], 5'b00000, instr_i[6:2], 2'b01, instr_i[9:7], 5'b10101, instr_i[9:7], 7'h13};
								if (instr_i[12] == 1'b1)
									illegal_instr_o = 1'b1;
							end
							2'b10: instr_o = {{6 {instr_i[12]}}, instr_i[12], instr_i[6:2], 2'b01, instr_i[9:7], 5'b11101, instr_i[9:7], 7'h13};
							2'b11:
								(* full_case, parallel_case *)
								case ({instr_i[12], instr_i[6:5]})
									3'b000: instr_o = {9'b010000001, instr_i[4:2], 2'b01, instr_i[9:7], 5'b00001, instr_i[9:7], 7'h33};
									3'b001: instr_o = {9'b000000001, instr_i[4:2], 2'b01, instr_i[9:7], 5'b10001, instr_i[9:7], 7'h33};
									3'b010: instr_o = {9'b000000001, instr_i[4:2], 2'b01, instr_i[9:7], 5'b11001, instr_i[9:7], 7'h33};
									3'b011: instr_o = {9'b000000001, instr_i[4:2], 2'b01, instr_i[9:7], 5'b11101, instr_i[9:7], 7'h33};
									3'b100, 3'b101, 3'b110, 3'b111: illegal_instr_o = 1'b1;
									default: illegal_instr_o = 1'b1;
								endcase
							default: illegal_instr_o = 1'b1;
						endcase
					3'b110, 3'b111: instr_o = {{4 {instr_i[12]}}, instr_i[6:5], instr_i[2], 7'b0000001, instr_i[9:7], 2'b00, instr_i[13], instr_i[11:10], instr_i[4:3], instr_i[12], 7'h63};
					default: illegal_instr_o = 1'b1;
				endcase
			2'b10:
				(* full_case, parallel_case *)
				case (instr_i[15:13])
					3'b000: begin
						instr_o = {7'b0000000, instr_i[6:2], instr_i[11:7], 3'b001, instr_i[11:7], 7'h13};
						if (instr_i[12] == 1'b1)
							illegal_instr_o = 1'b1;
					end
					3'b010: begin
						instr_o = {4'b0000, instr_i[3:2], instr_i[12], instr_i[6:4], 10'h012, instr_i[11:7], 7'h03};
						if (instr_i[11:7] == 5'b00000)
							illegal_instr_o = 1'b1;
					end
					3'b100:
						if (instr_i[12] == 1'b0) begin
							if (instr_i[6:2] != 5'b00000)
								instr_o = {7'b0000000, instr_i[6:2], 8'b00000000, instr_i[11:7], 7'h33};
							else begin
								instr_o = {12'b000000000000, instr_i[11:7], 15'h0067};
								if (instr_i[11:7] == 5'b00000)
									illegal_instr_o = 1'b1;
							end
						end
						else if (instr_i[6:2] != 5'b00000)
							instr_o = {7'b0000000, instr_i[6:2], instr_i[11:7], 3'b000, instr_i[11:7], 7'h33};
						else if (instr_i[11:7] == 5'b00000)
							instr_o = 32'h00100073;
						else
							instr_o = {12'b000000000000, instr_i[11:7], 15'h00e7};
					3'b110: instr_o = {4'b0000, instr_i[8:7], instr_i[12], instr_i[6:2], 8'h12, instr_i[11:9], 9'h023};
					3'b001, 3'b011, 3'b101, 3'b111: illegal_instr_o = 1'b1;
					default: illegal_instr_o = 1'b1;
				endcase
			2'b11:
				;
			default: illegal_instr_o = 1'b1;
		endcase
	end
	assign is_compressed_o = instr_i[1:0] != 2'b11;
	initial _sv2v_0 = 0;
endmodule
module cve2_controller (
	clk_i,
	rst_ni,
	fetch_enable_i,
	ctrl_busy_o,
	illegal_insn_i,
	ecall_insn_i,
	mret_insn_i,
	dret_insn_i,
	wfi_insn_i,
	ebrk_insn_i,
	csr_pipe_flush_i,
	xif_scoreboard_busy_i,
	instr_valid_i,
	instr_i,
	instr_compressed_i,
	instr_is_compressed_i,
	instr_fetch_err_i,
	instr_fetch_err_plus2_i,
	pc_id_i,
	instr_valid_clear_o,
	id_in_ready_o,
	controller_run_o,
	instr_req_o,
	pc_set_o,
	pc_mux_o,
	exc_pc_mux_o,
	exc_cause_o,
	lsu_addr_last_i,
	load_err_i,
	store_err_i,
	branch_set_i,
	jump_set_i,
	csr_mstatus_mie_i,
	irq_pending_i,
	irqs_i,
	irq_nm_i,
	nmi_mode_o,
	debug_req_i,
	debug_cause_o,
	debug_csr_save_o,
	debug_mode_o,
	debug_single_step_i,
	debug_ebreakm_i,
	debug_ebreaku_i,
	trigger_match_i,
	csr_save_if_o,
	csr_save_id_o,
	csr_restore_mret_id_o,
	csr_restore_dret_id_o,
	csr_save_cause_o,
	csr_mtval_o,
	priv_mode_i,
	csr_mstatus_tw_i,
	stall_id_i,
	flush_id_o,
	perf_jump_o,
	perf_tbranch_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire fetch_enable_i;
	output reg ctrl_busy_o;
	input wire illegal_insn_i;
	input wire ecall_insn_i;
	input wire mret_insn_i;
	input wire dret_insn_i;
	input wire wfi_insn_i;
	input wire ebrk_insn_i;
	input wire csr_pipe_flush_i;
	input wire xif_scoreboard_busy_i;
	input wire instr_valid_i;
	input wire [31:0] instr_i;
	input wire [15:0] instr_compressed_i;
	input wire instr_is_compressed_i;
	input wire instr_fetch_err_i;
	input wire instr_fetch_err_plus2_i;
	input wire [31:0] pc_id_i;
	output wire instr_valid_clear_o;
	output wire id_in_ready_o;
	output reg controller_run_o;
	output reg instr_req_o;
	output reg pc_set_o;
	output reg [2:0] pc_mux_o;
	output reg [1:0] exc_pc_mux_o;
	output reg [6:0] exc_cause_o;
	input wire [31:0] lsu_addr_last_i;
	input wire load_err_i;
	input wire store_err_i;
	input wire branch_set_i;
	input wire jump_set_i;
	input wire csr_mstatus_mie_i;
	input wire irq_pending_i;
	input wire [18:0] irqs_i;
	input wire irq_nm_i;
	output wire nmi_mode_o;
	input wire debug_req_i;
	output reg [2:0] debug_cause_o;
	output reg debug_csr_save_o;
	output wire debug_mode_o;
	input wire debug_single_step_i;
	input wire debug_ebreakm_i;
	input wire debug_ebreaku_i;
	input wire trigger_match_i;
	output reg csr_save_if_o;
	output reg csr_save_id_o;
	output reg csr_restore_mret_id_o;
	output reg csr_restore_dret_id_o;
	output reg csr_save_cause_o;
	output reg [31:0] csr_mtval_o;
	input wire [1:0] priv_mode_i;
	input wire csr_mstatus_tw_i;
	input wire stall_id_i;
	output wire flush_id_o;
	output reg perf_jump_o;
	output reg perf_tbranch_o;
	reg [3:0] ctrl_fsm_cs;
	reg [3:0] ctrl_fsm_ns;
	reg nmi_mode_q;
	reg nmi_mode_d;
	reg debug_mode_q;
	reg debug_mode_d;
	reg load_err_q;
	wire load_err_d;
	reg store_err_q;
	wire store_err_d;
	reg exc_req_q;
	wire exc_req_d;
	reg illegal_insn_q;
	wire illegal_insn_d;
	reg instr_fetch_err_prio;
	reg illegal_insn_prio;
	reg ecall_insn_prio;
	reg ebrk_insn_prio;
	reg store_err_prio;
	reg load_err_prio;
	wire stall;
	reg halt_if;
	reg retain_id;
	reg flush_id;
	wire illegal_dret;
	wire illegal_umode;
	wire exc_req_lsu;
	wire special_req;
	wire special_req_pc_change;
	wire special_req_flush_only;
	wire do_single_step_d;
	reg do_single_step_q;
	wire enter_debug_mode_prio_d;
	reg enter_debug_mode_prio_q;
	wire enter_debug_mode;
	wire ebreak_into_debug;
	wire handle_irq;
	reg [3:0] mfip_id;
	wire unused_irq_timer;
	wire ecall_insn;
	wire mret_insn;
	wire dret_insn;
	wire wfi_insn;
	wire ebrk_insn;
	wire csr_pipe_flush;
	wire instr_fetch_err;
	assign load_err_d = load_err_i;
	assign store_err_d = store_err_i;
	assign ecall_insn = ecall_insn_i & instr_valid_i;
	assign mret_insn = mret_insn_i & instr_valid_i;
	assign dret_insn = dret_insn_i & instr_valid_i;
	assign wfi_insn = wfi_insn_i & instr_valid_i;
	assign ebrk_insn = ebrk_insn_i & instr_valid_i;
	assign csr_pipe_flush = csr_pipe_flush_i & instr_valid_i;
	assign instr_fetch_err = instr_fetch_err_i & instr_valid_i;
	assign illegal_dret = dret_insn & ~debug_mode_q;
	assign illegal_umode = (priv_mode_i != 2'b11) & (mret_insn | (csr_mstatus_tw_i & wfi_insn));
	assign illegal_insn_d = ((illegal_insn_i | illegal_dret) | illegal_umode) & (ctrl_fsm_cs != 4'd6);
	assign exc_req_d = (((ecall_insn | ebrk_insn) | illegal_insn_d) | instr_fetch_err) & (ctrl_fsm_cs != 4'd6);
	assign exc_req_lsu = store_err_i | load_err_i;
	assign special_req_flush_only = wfi_insn | csr_pipe_flush;
	assign special_req_pc_change = ((mret_insn | dret_insn) | exc_req_d) | exc_req_lsu;
	assign special_req = special_req_pc_change | special_req_flush_only;
	always @(*) begin
		if (_sv2v_0)
			;
		instr_fetch_err_prio = 0;
		illegal_insn_prio = 0;
		ecall_insn_prio = 0;
		ebrk_insn_prio = 0;
		store_err_prio = 0;
		load_err_prio = 0;
		if (instr_fetch_err)
			instr_fetch_err_prio = 1'b1;
		else if (illegal_insn_q)
			illegal_insn_prio = 1'b1;
		else if (ecall_insn)
			ecall_insn_prio = 1'b1;
		else if (ebrk_insn)
			ebrk_insn_prio = 1'b1;
		else if (store_err_q)
			store_err_prio = 1'b1;
		else if (load_err_q)
			load_err_prio = 1'b1;
	end
	assign do_single_step_d = (instr_valid_i ? ~debug_mode_q & debug_single_step_i : do_single_step_q);
	assign enter_debug_mode_prio_d = (debug_req_i | do_single_step_d) & ~debug_mode_q;
	assign enter_debug_mode = enter_debug_mode_prio_d | (trigger_match_i & ~debug_mode_q);
	assign ebreak_into_debug = (priv_mode_i == 2'b11 ? debug_ebreakm_i : (priv_mode_i == 2'b00 ? debug_ebreaku_i : 1'b0));
	assign handle_irq = (~debug_mode_q & ~nmi_mode_q) & (irq_nm_i | (irq_pending_i & csr_mstatus_mie_i));
	always @(*) begin : gen_mfip_id
		if (_sv2v_0)
			;
		mfip_id = 4'd0;
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 15; i >= 0; i = i - 1)
				if (irqs_i[0 + i])
					mfip_id = i[3:0];
		end
	end
	assign unused_irq_timer = irqs_i[17];
	function automatic [6:0] sv2v_cast_7;
		input reg [6:0] inp;
		sv2v_cast_7 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		instr_req_o = 1'b1;
		csr_save_if_o = 1'b0;
		csr_save_id_o = 1'b0;
		csr_restore_mret_id_o = 1'b0;
		csr_restore_dret_id_o = 1'b0;
		csr_save_cause_o = 1'b0;
		csr_mtval_o = 1'sb0;
		pc_mux_o = 3'd0;
		pc_set_o = 1'b0;
		exc_pc_mux_o = 2'd1;
		exc_cause_o = 7'h00;
		ctrl_fsm_ns = ctrl_fsm_cs;
		ctrl_busy_o = 1'b1;
		halt_if = 1'b0;
		retain_id = 1'b0;
		flush_id = 1'b0;
		debug_csr_save_o = 1'b0;
		debug_cause_o = 3'h1;
		debug_mode_d = debug_mode_q;
		nmi_mode_d = nmi_mode_q;
		perf_tbranch_o = 1'b0;
		perf_jump_o = 1'b0;
		controller_run_o = 1'b0;
		(* full_case, parallel_case *)
		case (ctrl_fsm_cs)
			4'd0: begin
				instr_req_o = 1'b0;
				pc_mux_o = 3'd0;
				pc_set_o = 1'b1;
				if (fetch_enable_i == 1'b1)
					ctrl_fsm_ns = 4'd1;
			end
			4'd1: begin
				instr_req_o = 1'b1;
				pc_mux_o = 3'd0;
				pc_set_o = 1'b1;
				ctrl_fsm_ns = 4'd4;
			end
			4'd2: begin
				ctrl_busy_o = 1'b0;
				instr_req_o = 1'b0;
				halt_if = 1'b1;
				flush_id = 1'b1;
				ctrl_fsm_ns = 4'd3;
			end
			4'd3: begin
				instr_req_o = 1'b0;
				halt_if = 1'b1;
				flush_id = 1'b1;
				if ((((irq_nm_i || irq_pending_i) || debug_req_i) || debug_mode_q) || debug_single_step_i)
					ctrl_fsm_ns = 4'd4;
				else
					ctrl_busy_o = 1'b0;
			end
			4'd4: begin
				if (id_in_ready_o)
					ctrl_fsm_ns = 4'd5;
				if (handle_irq) begin
					ctrl_fsm_ns = 4'd7;
					halt_if = 1'b1;
				end
				if (enter_debug_mode) begin
					ctrl_fsm_ns = 4'd8;
					halt_if = 1'b1;
				end
			end
			4'd5: begin
				controller_run_o = 1'b1;
				pc_mux_o = 3'd1;
				if (special_req) begin
					retain_id = 1'b1;
					ctrl_fsm_ns = (xif_scoreboard_busy_i ? 4'd5 : 4'd6);
				end
				if (branch_set_i || jump_set_i) begin
					pc_set_o = 1'b1;
					perf_tbranch_o = branch_set_i;
					perf_jump_o = jump_set_i;
				end
				if ((enter_debug_mode || handle_irq) && (stall || instr_valid_i))
					halt_if = 1'b1;
				if ((!stall && !special_req) && !instr_valid_i) begin
					if (enter_debug_mode) begin
						ctrl_fsm_ns = (xif_scoreboard_busy_i ? 4'd5 : 4'd8);
						halt_if = 1'b1;
					end
					else if (handle_irq) begin
						ctrl_fsm_ns = (xif_scoreboard_busy_i ? 4'd5 : 4'd7);
						halt_if = 1'b1;
					end
				end
			end
			4'd7: begin
				pc_mux_o = 3'd2;
				exc_pc_mux_o = 2'd1;
				if (handle_irq) begin
					pc_set_o = 1'b1;
					csr_save_if_o = 1'b1;
					csr_save_cause_o = 1'b1;
					if (irq_nm_i && !nmi_mode_q) begin
						exc_cause_o = 7'h60;
						nmi_mode_d = 1'b1;
					end
					else if (irqs_i[15-:16] != 16'b0000000000000000)
						exc_cause_o = sv2v_cast_7({3'b101, mfip_id});
					else if (irqs_i[16])
						exc_cause_o = 7'h4b;
					else if (irqs_i[18])
						exc_cause_o = 7'h43;
					else
						exc_cause_o = 7'h47;
				end
				ctrl_fsm_ns = 4'd5;
			end
			4'd8: begin
				pc_mux_o = 3'd2;
				exc_pc_mux_o = 2'd2;
				flush_id = 1'b1;
				pc_set_o = 1'b1;
				csr_save_if_o = 1'b1;
				debug_csr_save_o = 1'b1;
				csr_save_cause_o = 1'b1;
				if (trigger_match_i)
					debug_cause_o = 3'h2;
				else if (debug_req_i)
					debug_cause_o = 3'h3;
				else
					debug_cause_o = 3'h4;
				debug_mode_d = 1'b1;
				ctrl_fsm_ns = 4'd5;
			end
			4'd9: begin
				flush_id = 1'b1;
				pc_mux_o = 3'd2;
				pc_set_o = 1'b1;
				exc_pc_mux_o = 2'd2;
				if (ebreak_into_debug && !debug_mode_q) begin
					csr_save_cause_o = 1'b1;
					csr_save_id_o = 1'b1;
					debug_csr_save_o = 1'b1;
					debug_cause_o = 3'h1;
				end
				debug_mode_d = 1'b1;
				ctrl_fsm_ns = 4'd5;
			end
			4'd6: begin
				halt_if = 1'b1;
				flush_id = 1'b1;
				ctrl_fsm_ns = 4'd5;
				if ((exc_req_q || store_err_q) || load_err_q) begin
					pc_set_o = 1'b1;
					pc_mux_o = 3'd2;
					exc_pc_mux_o = (debug_mode_q ? 2'd3 : 2'd0);
					begin : g_no_writeback_mepc_save
						csr_save_id_o = 1'b0;
					end
					csr_save_cause_o = 1'b1;
					(* full_case, parallel_case *)
					case (1'b1)
						instr_fetch_err_prio: begin
							exc_cause_o = 7'h01;
							csr_mtval_o = (instr_fetch_err_plus2_i ? pc_id_i + 32'd2 : pc_id_i);
						end
						illegal_insn_prio: begin
							exc_cause_o = 7'h02;
							csr_mtval_o = (instr_is_compressed_i ? {16'b0000000000000000, instr_compressed_i} : instr_i);
						end
						ecall_insn_prio: exc_cause_o = (priv_mode_i == 2'b11 ? 7'h0b : 7'h08);
						ebrk_insn_prio:
							if (debug_mode_q | ebreak_into_debug) begin
								pc_set_o = 1'b0;
								csr_save_id_o = 1'b0;
								csr_save_cause_o = 1'b0;
								ctrl_fsm_ns = 4'd9;
								flush_id = 1'b0;
							end
							else
								exc_cause_o = 7'h03;
						store_err_prio: begin
							exc_cause_o = 7'h07;
							csr_mtval_o = lsu_addr_last_i;
						end
						load_err_prio: begin
							exc_cause_o = 7'h05;
							csr_mtval_o = lsu_addr_last_i;
						end
						default:
							;
					endcase
				end
				else if (mret_insn) begin
					pc_mux_o = 3'd3;
					pc_set_o = 1'b1;
					csr_restore_mret_id_o = 1'b1;
					if (nmi_mode_q)
						nmi_mode_d = 1'b0;
				end
				else if (dret_insn) begin
					pc_mux_o = 3'd4;
					pc_set_o = 1'b1;
					debug_mode_d = 1'b0;
					csr_restore_dret_id_o = 1'b1;
				end
				else if (wfi_insn)
					ctrl_fsm_ns = 4'd2;
				if (enter_debug_mode_prio_q && !(ebrk_insn_prio && ebreak_into_debug))
					ctrl_fsm_ns = 4'd8;
			end
			default: begin
				instr_req_o = 1'b0;
				ctrl_fsm_ns = 4'd0;
			end
		endcase
	end
	assign flush_id_o = flush_id;
	assign debug_mode_o = debug_mode_q;
	assign nmi_mode_o = nmi_mode_q;
	assign stall = stall_id_i;
	assign id_in_ready_o = (~stall & ~halt_if) & ~retain_id;
	assign instr_valid_clear_o = ~(stall | retain_id) | flush_id;
	always @(posedge clk_i or negedge rst_ni) begin : update_regs
		if (!rst_ni) begin
			ctrl_fsm_cs <= 4'd0;
			nmi_mode_q <= 1'b0;
			do_single_step_q <= 1'b0;
			debug_mode_q <= 1'b0;
			enter_debug_mode_prio_q <= 1'b0;
			load_err_q <= 1'b0;
			store_err_q <= 1'b0;
			exc_req_q <= 1'b0;
			illegal_insn_q <= 1'b0;
		end
		else begin
			ctrl_fsm_cs <= ctrl_fsm_ns;
			nmi_mode_q <= nmi_mode_d;
			do_single_step_q <= do_single_step_d;
			debug_mode_q <= debug_mode_d;
			enter_debug_mode_prio_q <= enter_debug_mode_prio_d;
			load_err_q <= load_err_d;
			store_err_q <= store_err_d;
			exc_req_q <= exc_req_d;
			illegal_insn_q <= illegal_insn_d;
		end
	end
	initial _sv2v_0 = 0;
endmodule
module cve2_cs_registers (
	clk_i,
	rst_ni,
	hart_id_i,
	priv_mode_id_o,
	priv_mode_lsu_o,
	csr_mstatus_tw_o,
	csr_mtvec_o,
	csr_mtvec_init_i,
	boot_addr_i,
	csr_access_i,
	csr_addr_i,
	csr_wdata_i,
	csr_op_i,
	csr_op_en_i,
	csr_rdata_o,
	irq_software_i,
	irq_timer_i,
	irq_external_i,
	irq_fast_i,
	nmi_mode_i,
	irq_pending_o,
	irqs_o,
	csr_mstatus_mie_o,
	csr_mepc_o,
	csr_pmp_cfg_o,
	csr_pmp_addr_o,
	csr_pmp_mseccfg_o,
	debug_mode_i,
	debug_cause_i,
	debug_csr_save_i,
	csr_depc_o,
	debug_single_step_o,
	debug_ebreakm_o,
	debug_ebreaku_o,
	trigger_match_o,
	pc_if_i,
	pc_id_i,
	csr_save_if_i,
	csr_save_id_i,
	csr_restore_mret_i,
	csr_restore_dret_i,
	csr_save_cause_i,
	csr_mcause_i,
	csr_mtval_i,
	illegal_csr_insn_o,
	instr_ret_i,
	instr_ret_compressed_i,
	iside_wait_i,
	jump_i,
	branch_i,
	branch_taken_i,
	mem_load_i,
	mem_store_i,
	dside_wait_i,
	wfi_wait_i,
	div_wait_i
);
	reg _sv2v_0;
	parameter [0:0] DbgTriggerEn = 0;
	parameter [31:0] DbgHwBreakNum = 1;
	parameter [31:0] MHPMCounterNum = 10;
	parameter [31:0] MHPMCounterWidth = 40;
	parameter [0:0] PMPEnable = 0;
	parameter [31:0] PMPGranularity = 0;
	parameter [31:0] PMPNumRegions = 4;
	parameter [0:0] RV32E = 0;
	parameter integer RV32M = 32'sd2;
	parameter integer RV32B = 32'sd0;
	input wire clk_i;
	input wire rst_ni;
	input wire [31:0] hart_id_i;
	output wire [1:0] priv_mode_id_o;
	output wire [1:0] priv_mode_lsu_o;
	output wire csr_mstatus_tw_o;
	output wire [31:0] csr_mtvec_o;
	input wire csr_mtvec_init_i;
	input wire [31:0] boot_addr_i;
	input wire csr_access_i;
	input wire [11:0] csr_addr_i;
	input wire [31:0] csr_wdata_i;
	input wire [1:0] csr_op_i;
	input csr_op_en_i;
	output wire [31:0] csr_rdata_o;
	input wire irq_software_i;
	input wire irq_timer_i;
	input wire irq_external_i;
	input wire [15:0] irq_fast_i;
	input wire nmi_mode_i;
	output wire irq_pending_o;
	output wire [18:0] irqs_o;
	output wire csr_mstatus_mie_o;
	output wire [31:0] csr_mepc_o;
	output wire [(PMPNumRegions * 6) - 1:0] csr_pmp_cfg_o;
	output wire [(PMPNumRegions * 34) - 1:0] csr_pmp_addr_o;
	output wire [2:0] csr_pmp_mseccfg_o;
	input wire debug_mode_i;
	input wire [2:0] debug_cause_i;
	input wire debug_csr_save_i;
	output wire [31:0] csr_depc_o;
	output wire debug_single_step_o;
	output wire debug_ebreakm_o;
	output wire debug_ebreaku_o;
	output wire trigger_match_o;
	input wire [31:0] pc_if_i;
	input wire [31:0] pc_id_i;
	input wire csr_save_if_i;
	input wire csr_save_id_i;
	input wire csr_restore_mret_i;
	input wire csr_restore_dret_i;
	input wire csr_save_cause_i;
	input wire [6:0] csr_mcause_i;
	input wire [31:0] csr_mtval_i;
	output wire illegal_csr_insn_o;
	input wire instr_ret_i;
	input wire instr_ret_compressed_i;
	input wire iside_wait_i;
	input wire jump_i;
	input wire branch_i;
	input wire branch_taken_i;
	input wire mem_load_i;
	input wire mem_store_i;
	input wire dside_wait_i;
	input wire wfi_wait_i;
	input wire div_wait_i;
	localparam [31:0] RV32BEnabled = (RV32B == 32'sd0 ? 0 : 1);
	localparam [31:0] RV32MEnabled = (RV32M == 32'sd0 ? 0 : 1);
	localparam [31:0] PMPAddrWidth = (PMPGranularity > 0 ? 33 - PMPGranularity : 32);
	localparam [31:0] UmodeEnabled = 0;
	wire umode_control;
	function automatic [0:0] sv2v_cast_1;
		input reg [0:0] inp;
		sv2v_cast_1 = inp;
	endfunction
	assign umode_control = sv2v_cast_1(UmodeEnabled);
	localparam [1:0] cve2_pkg_CSR_MISA_MXL = 2'd1;
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	localparam [31:0] MISA_VALUE = (((((((((((0 | (RV32BEnabled << 1)) | 4) | 0) | (sv2v_cast_32(RV32E) << 4)) | 0) | (sv2v_cast_32(!RV32E) << 8)) | (RV32MEnabled << 12)) | 0) | 0) | (UmodeEnabled << 20)) | 0) | (sv2v_cast_32(cve2_pkg_CSR_MISA_MXL) << 30);
	reg [31:0] exception_pc;
	reg [1:0] priv_lvl_q;
	reg [1:0] priv_lvl_d;
	wire [5:0] mstatus_q;
	reg [5:0] mstatus_d;
	reg mstatus_en;
	wire [18:0] mie_q;
	wire [18:0] mie_d;
	reg mie_en;
	wire [31:0] mscratch_q;
	reg mscratch_en;
	wire [31:0] mepc_q;
	reg [31:0] mepc_d;
	reg mepc_en;
	wire [6:0] mcause_q;
	reg [6:0] mcause_d;
	reg mcause_en;
	wire [31:0] mtval_q;
	reg [31:0] mtval_d;
	reg mtval_en;
	wire [31:0] mtvec_q;
	reg [31:0] mtvec_d;
	reg mtvec_en;
	wire [18:0] mip;
	wire [31:0] dcsr_q;
	reg [31:0] dcsr_d;
	reg dcsr_en;
	wire [31:0] depc_q;
	reg [31:0] depc_d;
	reg depc_en;
	wire [31:0] dscratch0_q;
	wire [31:0] dscratch1_q;
	reg dscratch0_en;
	reg dscratch1_en;
	wire [2:0] mstack_q;
	reg [2:0] mstack_d;
	reg mstack_en;
	wire [31:0] mstack_epc_q;
	reg [31:0] mstack_epc_d;
	wire [6:0] mstack_cause_q;
	reg [6:0] mstack_cause_d;
	localparam [31:0] cve2_pkg_PMP_MAX_REGIONS = 16;
	reg [31:0] pmp_addr_rdata [0:15];
	localparam [31:0] cve2_pkg_PMP_CFG_W = 8;
	wire [7:0] pmp_cfg_rdata [0:15];
	wire [2:0] pmp_mseccfg;
	wire [31:0] mcountinhibit;
	reg [MHPMCounterNum + 2:0] mcountinhibit_d;
	reg [MHPMCounterNum + 2:0] mcountinhibit_q;
	reg mcountinhibit_we;
	wire [63:0] mhpmcounter [0:31];
	reg [31:0] mhpmcounter_we;
	reg [31:0] mhpmcounterh_we;
	reg [31:0] mhpmcounter_incr;
	reg [31:0] mhpmevent [0:31];
	wire [4:0] mhpmcounter_idx;
	wire unused_mhpmcounter_we_1;
	wire unused_mhpmcounterh_we_1;
	wire unused_mhpmcounter_incr_1;
	wire [63:0] minstret_raw;
	wire [31:0] tselect_rdata;
	wire [31:0] tmatch_control_rdata;
	wire [31:0] tmatch_value_rdata;
	reg [31:0] csr_wdata_int;
	reg [31:0] csr_rdata_int;
	wire csr_we_int;
	wire csr_wr;
	reg illegal_csr;
	wire illegal_csr_priv;
	wire illegal_csr_write;
	wire [7:0] unused_boot_addr;
	wire [2:0] unused_csr_addr;
	assign unused_boot_addr = boot_addr_i[7:0];
	wire [11:0] csr_addr;
	assign csr_addr = {csr_addr_i};
	assign unused_csr_addr = csr_addr[7:5];
	assign mhpmcounter_idx = csr_addr[4:0];
	assign illegal_csr_priv = csr_addr[9:8] > {priv_lvl_q};
	assign illegal_csr_write = (csr_addr[11:10] == 2'b11) && csr_wr;
	assign illegal_csr_insn_o = csr_access_i & ((illegal_csr | illegal_csr_write) | illegal_csr_priv);
	assign mip[18] = irq_software_i;
	assign mip[17] = irq_timer_i;
	assign mip[16] = irq_external_i;
	assign mip[15-:16] = irq_fast_i;
	localparam cve2_pkg_MARCHID = 32'd35;
	localparam [31:0] cve2_pkg_CSR_MARCHID_VALUE = cve2_pkg_MARCHID;
	localparam [31:0] cve2_pkg_CSR_MCONFIGPTR_VALUE = 32'b00000000000000000000000000000000;
	localparam [31:0] cve2_pkg_CSR_MEIX_BIT = 11;
	localparam [31:0] cve2_pkg_CSR_MFIX_BIT_HIGH = 31;
	localparam [31:0] cve2_pkg_CSR_MFIX_BIT_LOW = 16;
	localparam [31:0] cve2_pkg_CSR_MIMPID_VALUE = 32'b00000000000000000000000000000000;
	localparam [31:0] cve2_pkg_CSR_MSECCFG_MML_BIT = 0;
	localparam [31:0] cve2_pkg_CSR_MSECCFG_MMWP_BIT = 1;
	localparam [31:0] cve2_pkg_CSR_MSECCFG_RLB_BIT = 2;
	localparam [31:0] cve2_pkg_CSR_MSIX_BIT = 3;
	localparam [31:0] cve2_pkg_CSR_MSTATUS_MIE_BIT = 3;
	localparam [31:0] cve2_pkg_CSR_MSTATUS_MPIE_BIT = 7;
	localparam [31:0] cve2_pkg_CSR_MSTATUS_MPP_BIT_HIGH = 12;
	localparam [31:0] cve2_pkg_CSR_MSTATUS_MPP_BIT_LOW = 11;
	localparam [31:0] cve2_pkg_CSR_MSTATUS_MPRV_BIT = 17;
	localparam [31:0] cve2_pkg_CSR_MSTATUS_TW_BIT = 21;
	localparam [31:0] cve2_pkg_CSR_MTIX_BIT = 7;
	localparam cve2_pkg_MVENDORID_BANK = 25'h000000c;
	localparam cve2_pkg_MVENDORID_OFFSET = 7'h02;
	localparam [31:0] cve2_pkg_CSR_MVENDORID_VALUE = {cve2_pkg_MVENDORID_BANK, cve2_pkg_MVENDORID_OFFSET};
	always @(*) begin
		if (_sv2v_0)
			;
		csr_rdata_int = 1'sb0;
		illegal_csr = 1'b0;
		(* full_case, parallel_case *)
		case (csr_addr_i)
			12'hf11: csr_rdata_int = cve2_pkg_CSR_MVENDORID_VALUE;
			12'hf12: csr_rdata_int = cve2_pkg_CSR_MARCHID_VALUE;
			12'hf13: csr_rdata_int = cve2_pkg_CSR_MIMPID_VALUE;
			12'hf14: csr_rdata_int = hart_id_i;
			12'hf15: csr_rdata_int = cve2_pkg_CSR_MCONFIGPTR_VALUE;
			12'h300: begin
				csr_rdata_int = 1'sb0;
				csr_rdata_int[cve2_pkg_CSR_MSTATUS_MIE_BIT] = mstatus_q[5];
				csr_rdata_int[cve2_pkg_CSR_MSTATUS_MPIE_BIT] = mstatus_q[4];
				csr_rdata_int[cve2_pkg_CSR_MSTATUS_MPP_BIT_HIGH:cve2_pkg_CSR_MSTATUS_MPP_BIT_LOW] = mstatus_q[3-:2];
				csr_rdata_int[cve2_pkg_CSR_MSTATUS_MPRV_BIT] = mstatus_q[1];
				csr_rdata_int[cve2_pkg_CSR_MSTATUS_TW_BIT] = mstatus_q[0];
			end
			12'h310: csr_rdata_int = 1'sb0;
			12'h30a, 12'h31a:
				if (umode_control)
					csr_rdata_int = 1'sb0;
				else
					illegal_csr = 1'b1;
			12'h301: csr_rdata_int = MISA_VALUE;
			12'h304: begin
				csr_rdata_int = 1'sb0;
				csr_rdata_int[cve2_pkg_CSR_MSIX_BIT] = mie_q[18];
				csr_rdata_int[cve2_pkg_CSR_MTIX_BIT] = mie_q[17];
				csr_rdata_int[cve2_pkg_CSR_MEIX_BIT] = mie_q[16];
				csr_rdata_int[cve2_pkg_CSR_MFIX_BIT_HIGH:cve2_pkg_CSR_MFIX_BIT_LOW] = mie_q[15-:16];
			end
			12'h306:
				if (umode_control)
					csr_rdata_int = 1'sb0;
				else
					illegal_csr = 1'b1;
			12'h340: csr_rdata_int = mscratch_q;
			12'h305: csr_rdata_int = mtvec_q;
			12'h341: csr_rdata_int = mepc_q;
			12'h342: csr_rdata_int = {mcause_q[6], 25'b0000000000000000000000000, mcause_q[5:0]};
			12'h343: csr_rdata_int = mtval_q;
			12'h344: begin
				csr_rdata_int = 1'sb0;
				csr_rdata_int[cve2_pkg_CSR_MSIX_BIT] = mip[18];
				csr_rdata_int[cve2_pkg_CSR_MTIX_BIT] = mip[17];
				csr_rdata_int[cve2_pkg_CSR_MEIX_BIT] = mip[16];
				csr_rdata_int[cve2_pkg_CSR_MFIX_BIT_HIGH:cve2_pkg_CSR_MFIX_BIT_LOW] = mip[15-:16];
			end
			12'h747:
				if (PMPEnable) begin
					csr_rdata_int = 1'sb0;
					csr_rdata_int[cve2_pkg_CSR_MSECCFG_MML_BIT] = pmp_mseccfg[0];
					csr_rdata_int[cve2_pkg_CSR_MSECCFG_MMWP_BIT] = pmp_mseccfg[1];
					csr_rdata_int[cve2_pkg_CSR_MSECCFG_RLB_BIT] = pmp_mseccfg[2];
				end
				else
					illegal_csr = 1'b1;
			12'h757:
				if (PMPEnable)
					csr_rdata_int = 1'sb0;
				else
					illegal_csr = 1'b1;
			12'h3a0: csr_rdata_int = {pmp_cfg_rdata[3], pmp_cfg_rdata[2], pmp_cfg_rdata[1], pmp_cfg_rdata[0]};
			12'h3a1: csr_rdata_int = {pmp_cfg_rdata[7], pmp_cfg_rdata[6], pmp_cfg_rdata[5], pmp_cfg_rdata[4]};
			12'h3a2: csr_rdata_int = {pmp_cfg_rdata[11], pmp_cfg_rdata[10], pmp_cfg_rdata[9], pmp_cfg_rdata[8]};
			12'h3a3: csr_rdata_int = {pmp_cfg_rdata[15], pmp_cfg_rdata[14], pmp_cfg_rdata[13], pmp_cfg_rdata[12]};
			12'h3b0: csr_rdata_int = pmp_addr_rdata[0];
			12'h3b1: csr_rdata_int = pmp_addr_rdata[1];
			12'h3b2: csr_rdata_int = pmp_addr_rdata[2];
			12'h3b3: csr_rdata_int = pmp_addr_rdata[3];
			12'h3b4: csr_rdata_int = pmp_addr_rdata[4];
			12'h3b5: csr_rdata_int = pmp_addr_rdata[5];
			12'h3b6: csr_rdata_int = pmp_addr_rdata[6];
			12'h3b7: csr_rdata_int = pmp_addr_rdata[7];
			12'h3b8: csr_rdata_int = pmp_addr_rdata[8];
			12'h3b9: csr_rdata_int = pmp_addr_rdata[9];
			12'h3ba: csr_rdata_int = pmp_addr_rdata[10];
			12'h3bb: csr_rdata_int = pmp_addr_rdata[11];
			12'h3bc: csr_rdata_int = pmp_addr_rdata[12];
			12'h3bd: csr_rdata_int = pmp_addr_rdata[13];
			12'h3be: csr_rdata_int = pmp_addr_rdata[14];
			12'h3bf: csr_rdata_int = pmp_addr_rdata[15];
			12'h7b0: begin
				csr_rdata_int = dcsr_q;
				illegal_csr = ~debug_mode_i;
			end
			12'h7b1: begin
				csr_rdata_int = depc_q;
				illegal_csr = ~debug_mode_i;
			end
			12'h7b2: begin
				csr_rdata_int = dscratch0_q;
				illegal_csr = ~debug_mode_i;
			end
			12'h7b3: begin
				csr_rdata_int = dscratch1_q;
				illegal_csr = ~debug_mode_i;
			end
			12'h320: csr_rdata_int = mcountinhibit;
			12'h323, 12'h324, 12'h325, 12'h326, 12'h327, 12'h328, 12'h329, 12'h32a, 12'h32b, 12'h32c, 12'h32d, 12'h32e, 12'h32f, 12'h330, 12'h331, 12'h332, 12'h333, 12'h334, 12'h335, 12'h336, 12'h337, 12'h338, 12'h339, 12'h33a, 12'h33b, 12'h33c, 12'h33d, 12'h33e, 12'h33f: csr_rdata_int = mhpmevent[mhpmcounter_idx];
			12'hb00, 12'hb02, 12'hb03, 12'hb04, 12'hb05, 12'hb06, 12'hb07, 12'hb08, 12'hb09, 12'hb0a, 12'hb0b, 12'hb0c, 12'hb0d, 12'hb0e, 12'hb0f, 12'hb10, 12'hb11, 12'hb12, 12'hb13, 12'hb14, 12'hb15, 12'hb16, 12'hb17, 12'hb18, 12'hb19, 12'hb1a, 12'hb1b, 12'hb1c, 12'hb1d, 12'hb1e, 12'hb1f: csr_rdata_int = mhpmcounter[mhpmcounter_idx][31:0];
			12'hb80, 12'hb82, 12'hb83, 12'hb84, 12'hb85, 12'hb86, 12'hb87, 12'hb88, 12'hb89, 12'hb8a, 12'hb8b, 12'hb8c, 12'hb8d, 12'hb8e, 12'hb8f, 12'hb90, 12'hb91, 12'hb92, 12'hb93, 12'hb94, 12'hb95, 12'hb96, 12'hb97, 12'hb98, 12'hb99, 12'hb9a, 12'hb9b, 12'hb9c, 12'hb9d, 12'hb9e, 12'hb9f: csr_rdata_int = mhpmcounter[mhpmcounter_idx][63:32];
			12'h7a0: begin
				csr_rdata_int = tselect_rdata;
				illegal_csr = ~DbgTriggerEn;
			end
			12'h7a1: begin
				csr_rdata_int = tmatch_control_rdata;
				illegal_csr = ~DbgTriggerEn;
			end
			12'h7a2: begin
				csr_rdata_int = tmatch_value_rdata;
				illegal_csr = ~DbgTriggerEn;
			end
			12'h7a3: begin
				csr_rdata_int = 1'sb0;
				illegal_csr = ~DbgTriggerEn;
			end
			12'h7a8: begin
				csr_rdata_int = 1'sb0;
				illegal_csr = ~DbgTriggerEn;
			end
			12'h7aa: begin
				csr_rdata_int = 1'sb0;
				illegal_csr = ~DbgTriggerEn;
			end
			12'h7c1: csr_rdata_int = 1'sb0;
			default: illegal_csr = 1'b1;
		endcase
		if (!PMPEnable) begin
			if (|{csr_addr == 12'h3a0, csr_addr == 12'h3a1, csr_addr == 12'h3a2, csr_addr == 12'h3a3, csr_addr == 12'h3b0, csr_addr == 12'h3b1, csr_addr == 12'h3b2, csr_addr == 12'h3b3, csr_addr == 12'h3b4, csr_addr == 12'h3b5, csr_addr == 12'h3b6, csr_addr == 12'h3b7, csr_addr == 12'h3b8, csr_addr == 12'h3b9, csr_addr == 12'h3ba, csr_addr == 12'h3bb, csr_addr == 12'h3bc, csr_addr == 12'h3bd, csr_addr == 12'h3be, csr_addr == 12'h3bf})
				illegal_csr = 1'b1;
		end
	end
	function automatic [1:0] sv2v_cast_2;
		input reg [1:0] inp;
		sv2v_cast_2 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		exception_pc = pc_id_i;
		priv_lvl_d = priv_lvl_q;
		mstatus_en = 1'b0;
		mstatus_d = mstatus_q;
		mie_en = 1'b0;
		mscratch_en = 1'b0;
		mepc_en = 1'b0;
		mepc_d = {csr_wdata_int[31:1], 1'b0};
		mcause_en = 1'b0;
		mcause_d = {csr_wdata_int[31], csr_wdata_int[5:0]};
		mtval_en = 1'b0;
		mtval_d = csr_wdata_int;
		mtvec_en = csr_mtvec_init_i;
		mtvec_d = (csr_mtvec_init_i ? {boot_addr_i[31:8], 8'b00000001} : {csr_wdata_int[31:8], 8'b00000001});
		dcsr_en = 1'b0;
		dcsr_d = dcsr_q;
		depc_d = {csr_wdata_int[31:1], 1'b0};
		depc_en = 1'b0;
		dscratch0_en = 1'b0;
		dscratch1_en = 1'b0;
		mstack_en = 1'b0;
		mstack_d[2] = mstatus_q[4];
		mstack_d[1-:2] = mstatus_q[3-:2];
		mstack_epc_d = mepc_q;
		mstack_cause_d = mcause_q;
		mcountinhibit_we = 1'b0;
		mhpmcounter_we = 1'sb0;
		mhpmcounterh_we = 1'sb0;
		if (csr_we_int)
			(* full_case, parallel_case *)
			case (csr_addr_i)
				12'h300: begin
					mstatus_en = 1'b1;
					mstatus_d = {csr_wdata_int[cve2_pkg_CSR_MSTATUS_MIE_BIT], csr_wdata_int[cve2_pkg_CSR_MSTATUS_MPIE_BIT], sv2v_cast_2(csr_wdata_int[cve2_pkg_CSR_MSTATUS_MPP_BIT_HIGH:cve2_pkg_CSR_MSTATUS_MPP_BIT_LOW]), sv2v_cast_1(csr_wdata_int[cve2_pkg_CSR_MSTATUS_MPRV_BIT] & umode_control), sv2v_cast_1(csr_wdata_int[cve2_pkg_CSR_MSTATUS_TW_BIT] & umode_control)};
					if ((mstatus_d[3-:2] != 2'b11) && !(umode_control && (mstatus_d[3-:2] == 2'b00)))
						mstatus_d[3-:2] = 2'b11;
				end
				12'h304: mie_en = 1'b1;
				12'h340: mscratch_en = 1'b1;
				12'h341: mepc_en = 1'b1;
				12'h342: mcause_en = 1'b1;
				12'h343: mtval_en = 1'b1;
				12'h305: mtvec_en = 1'b1;
				12'h7b0: begin
					dcsr_d = csr_wdata_int;
					dcsr_d[31-:4] = 4'd4;
					if ((dcsr_d[1-:2] != 2'b11) && !(umode_control && (dcsr_d[1-:2] == 2'b00)))
						dcsr_d[1-:2] = 2'b11;
					dcsr_d[8-:3] = dcsr_q[8-:3];
					dcsr_d[11] = 1'b0;
					dcsr_d[3] = 1'b0;
					dcsr_d[4] = 1'b0;
					dcsr_d[10] = 1'b0;
					dcsr_d[9] = 1'b0;
					dcsr_d[5] = 1'b0;
					dcsr_d[14] = 1'b0;
					dcsr_d[27-:12] = 12'h000;
					dcsr_en = 1'b1;
				end
				12'h7b1: depc_en = 1'b1;
				12'h7b2: dscratch0_en = 1'b1;
				12'h7b3: dscratch1_en = 1'b1;
				12'h320: mcountinhibit_we = 1'b1;
				12'hb00, 12'hb02, 12'hb03, 12'hb04, 12'hb05, 12'hb06, 12'hb07, 12'hb08, 12'hb09, 12'hb0a, 12'hb0b, 12'hb0c, 12'hb0d, 12'hb0e, 12'hb0f, 12'hb10, 12'hb11, 12'hb12, 12'hb13, 12'hb14, 12'hb15, 12'hb16, 12'hb17, 12'hb18, 12'hb19, 12'hb1a, 12'hb1b, 12'hb1c, 12'hb1d, 12'hb1e, 12'hb1f: mhpmcounter_we[mhpmcounter_idx] = 1'b1;
				12'hb80, 12'hb82, 12'hb83, 12'hb84, 12'hb85, 12'hb86, 12'hb87, 12'hb88, 12'hb89, 12'hb8a, 12'hb8b, 12'hb8c, 12'hb8d, 12'hb8e, 12'hb8f, 12'hb90, 12'hb91, 12'hb92, 12'hb93, 12'hb94, 12'hb95, 12'hb96, 12'hb97, 12'hb98, 12'hb99, 12'hb9a, 12'hb9b, 12'hb9c, 12'hb9d, 12'hb9e, 12'hb9f: mhpmcounterh_we[mhpmcounter_idx] = 1'b1;
				default:
					;
			endcase
		(* full_case, parallel_case *)
		case (1'b1)
			csr_save_cause_i: begin
				(* full_case, parallel_case *)
				case (1'b1)
					csr_save_if_i: exception_pc = pc_if_i;
					csr_save_id_i: exception_pc = pc_id_i;
					default:
						;
				endcase
				priv_lvl_d = 2'b11;
				if (debug_csr_save_i) begin
					dcsr_d[1-:2] = priv_lvl_q;
					dcsr_d[8-:3] = debug_cause_i;
					dcsr_en = 1'b1;
					depc_d = exception_pc;
					depc_en = 1'b1;
				end
				else if (!debug_mode_i) begin
					mtval_en = 1'b1;
					mtval_d = csr_mtval_i;
					mstatus_en = 1'b1;
					mstatus_d[5] = 1'b0;
					mstatus_d[4] = mstatus_q[5];
					mstatus_d[3-:2] = priv_lvl_q;
					mepc_en = 1'b1;
					mepc_d = exception_pc;
					mcause_en = 1'b1;
					mcause_d = {csr_mcause_i};
					mstack_en = 1'b1;
				end
			end
			csr_restore_dret_i: priv_lvl_d = dcsr_q[1-:2];
			csr_restore_mret_i: begin
				priv_lvl_d = mstatus_q[3-:2];
				mstatus_en = 1'b1;
				mstatus_d[5] = mstatus_q[4];
				if (mstatus_q[3-:2] != 2'b11)
					mstatus_d[1] = 1'b0;
				if (nmi_mode_i) begin
					mstatus_d[4] = mstack_q[2];
					mstatus_d[3-:2] = mstack_q[1-:2];
					mepc_en = 1'b1;
					mepc_d = mstack_epc_q;
					mcause_en = 1'b1;
					mcause_d = mstack_cause_q;
				end
				else begin
					mstatus_d[4] = 1'b1;
					mstatus_d[3-:2] = (umode_control ? 2'b00 : 2'b11);
				end
			end
			default:
				;
		endcase
	end
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			priv_lvl_q <= 2'b11;
		else
			priv_lvl_q <= priv_lvl_d;
	assign priv_mode_id_o = priv_lvl_q;
	assign priv_mode_lsu_o = (mstatus_q[1] ? mstatus_q[3-:2] : priv_lvl_q);
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (csr_op_i)
			2'd1: csr_wdata_int = csr_wdata_i;
			2'd2: csr_wdata_int = csr_wdata_i | csr_rdata_o;
			2'd3: csr_wdata_int = ~csr_wdata_i & csr_rdata_o;
			2'd0: csr_wdata_int = csr_wdata_i;
			default: csr_wdata_int = csr_wdata_i;
		endcase
	end
	assign csr_wr = |{csr_op_i == 2'd1, csr_op_i == 2'd2, csr_op_i == 2'd3};
	assign csr_we_int = (csr_wr & csr_op_en_i) & ~illegal_csr_insn_o;
	assign csr_rdata_o = csr_rdata_int;
	assign csr_mepc_o = mepc_q;
	assign csr_depc_o = depc_q;
	assign csr_mtvec_o = mtvec_q;
	assign csr_mstatus_mie_o = mstatus_q[5];
	assign csr_mstatus_tw_o = mstatus_q[0];
	assign debug_single_step_o = dcsr_q[2];
	assign debug_ebreakm_o = dcsr_q[15];
	assign debug_ebreaku_o = dcsr_q[12];
	assign irqs_o = mip & mie_q;
	assign irq_pending_o = |irqs_o;
	localparam [5:0] MSTATUS_RST_VAL = 6'b001100;
	cve2_csr #(
		.Width(6),
		.ResetValue({MSTATUS_RST_VAL})
	) u_mstatus_csr(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.wr_data_i({mstatus_d}),
		.wr_en_i(mstatus_en),
		.rd_data_o(mstatus_q),
		.rd_error_o()
	);
	cve2_csr #(
		.Width(32),
		.ShadowCopy(1'b0),
		.ResetValue(1'sb0)
	) u_mepc_csr(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.wr_data_i(mepc_d),
		.wr_en_i(mepc_en),
		.rd_data_o(mepc_q),
		.rd_error_o()
	);
	assign mie_d[18] = csr_wdata_int[cve2_pkg_CSR_MSIX_BIT];
	assign mie_d[17] = csr_wdata_int[cve2_pkg_CSR_MTIX_BIT];
	assign mie_d[16] = csr_wdata_int[cve2_pkg_CSR_MEIX_BIT];
	assign mie_d[15-:16] = csr_wdata_int[cve2_pkg_CSR_MFIX_BIT_HIGH:cve2_pkg_CSR_MFIX_BIT_LOW];
	cve2_csr #(
		.Width(19),
		.ShadowCopy(1'b0),
		.ResetValue(1'sb0)
	) u_mie_csr(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.wr_data_i({mie_d}),
		.wr_en_i(mie_en),
		.rd_data_o(mie_q),
		.rd_error_o()
	);
	cve2_csr #(
		.Width(32),
		.ShadowCopy(1'b0),
		.ResetValue(1'sb0)
	) u_mscratch_csr(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.wr_data_i(csr_wdata_int),
		.wr_en_i(mscratch_en),
		.rd_data_o(mscratch_q),
		.rd_error_o()
	);
	cve2_csr #(
		.Width(7),
		.ShadowCopy(1'b0),
		.ResetValue(1'sb0)
	) u_mcause_csr(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.wr_data_i(mcause_d),
		.wr_en_i(mcause_en),
		.rd_data_o(mcause_q),
		.rd_error_o()
	);
	cve2_csr #(
		.Width(32),
		.ShadowCopy(1'b0),
		.ResetValue(1'sb0)
	) u_mtval_csr(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.wr_data_i(mtval_d),
		.wr_en_i(mtval_en),
		.rd_data_o(mtval_q),
		.rd_error_o()
	);
	cve2_csr #(
		.Width(32),
		.ResetValue(32'd1)
	) u_mtvec_csr(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.wr_data_i(mtvec_d),
		.wr_en_i(mtvec_en),
		.rd_data_o(mtvec_q),
		.rd_error_o()
	);
	localparam [31:0] DCSR_RESET_VAL = 32'h40000003;
	cve2_csr #(
		.Width(32),
		.ShadowCopy(1'b0),
		.ResetValue({DCSR_RESET_VAL})
	) u_dcsr_csr(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.wr_data_i({dcsr_d}),
		.wr_en_i(dcsr_en),
		.rd_data_o(dcsr_q),
		.rd_error_o()
	);
	cve2_csr #(
		.Width(32),
		.ShadowCopy(1'b0),
		.ResetValue(1'sb0)
	) u_depc_csr(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.wr_data_i(depc_d),
		.wr_en_i(depc_en),
		.rd_data_o(depc_q),
		.rd_error_o()
	);
	cve2_csr #(
		.Width(32),
		.ShadowCopy(1'b0),
		.ResetValue(1'sb0)
	) u_dscratch0_csr(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.wr_data_i(csr_wdata_int),
		.wr_en_i(dscratch0_en),
		.rd_data_o(dscratch0_q),
		.rd_error_o()
	);
	cve2_csr #(
		.Width(32),
		.ShadowCopy(1'b0),
		.ResetValue(1'sb0)
	) u_dscratch1_csr(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.wr_data_i(csr_wdata_int),
		.wr_en_i(dscratch1_en),
		.rd_data_o(dscratch1_q),
		.rd_error_o()
	);
	localparam [2:0] MSTACK_RESET_VAL = {1'b1, (UmodeEnabled ? 2'b00 : 2'b11)};
	cve2_csr #(
		.Width(3),
		.ShadowCopy(1'b0),
		.ResetValue({MSTACK_RESET_VAL})
	) u_mstack_csr(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.wr_data_i({mstack_d}),
		.wr_en_i(mstack_en),
		.rd_data_o(mstack_q),
		.rd_error_o()
	);
	cve2_csr #(
		.Width(32),
		.ShadowCopy(1'b0),
		.ResetValue(1'sb0)
	) u_mstack_epc_csr(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.wr_data_i(mstack_epc_d),
		.wr_en_i(mstack_en),
		.rd_data_o(mstack_epc_q),
		.rd_error_o()
	);
	cve2_csr #(
		.Width(7),
		.ShadowCopy(1'b0),
		.ResetValue(1'sb0)
	) u_mstack_cause_csr(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.wr_data_i(mstack_cause_d),
		.wr_en_i(mstack_en),
		.rd_data_o(mstack_cause_q),
		.rd_error_o()
	);
	localparam [11:0] cve2_pkg_CSR_OFF_PMP_ADDR = 12'h3b0;
	localparam [11:0] cve2_pkg_CSR_OFF_PMP_CFG = 12'h3a0;
	generate
		if (PMPEnable) begin : g_pmp_registers
			localparam [95:0] pmp_cfg_rst = 96'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
			localparam [543:0] pmp_addr_rst = 544'h0;
			localparam [2:0] pmp_mseccfg_rst = 3'b000;
			wire [2:0] pmp_mseccfg_q;
			wire [2:0] pmp_mseccfg_d;
			wire pmp_mseccfg_we;
			wire pmp_mseccfg_err;
			wire [5:0] pmp_cfg [0:PMPNumRegions - 1];
			wire [PMPNumRegions - 1:0] pmp_cfg_locked;
			reg [5:0] pmp_cfg_wdata [0:PMPNumRegions - 1];
			wire [PMPAddrWidth - 1:0] pmp_addr [0:PMPNumRegions - 1];
			wire [PMPNumRegions - 1:0] pmp_cfg_we;
			wire [PMPNumRegions - 1:0] pmp_cfg_err;
			wire [PMPNumRegions - 1:0] pmp_addr_we;
			wire [PMPNumRegions - 1:0] pmp_addr_err;
			wire any_pmp_entry_locked;
			genvar _gv_i_20;
			for (_gv_i_20 = 0; _gv_i_20 < cve2_pkg_PMP_MAX_REGIONS; _gv_i_20 = _gv_i_20 + 1) begin : g_exp_rd_data
				localparam i = _gv_i_20;
				if (i < PMPNumRegions) begin : g_implemented_regions
					assign pmp_cfg_rdata[i] = {pmp_cfg[i][5], 2'b00, pmp_cfg[i][4-:2], pmp_cfg[i][2], pmp_cfg[i][1], pmp_cfg[i][0]};
					if (PMPGranularity == 0) begin : g_pmp_g0
						wire [32:1] sv2v_tmp_2683A;
						assign sv2v_tmp_2683A = pmp_addr[i];
						always @(*) pmp_addr_rdata[i] = sv2v_tmp_2683A;
					end
					else if (PMPGranularity == 1) begin : g_pmp_g1
						always @(*) begin
							if (_sv2v_0)
								;
							pmp_addr_rdata[i] = pmp_addr[i];
							if ((pmp_cfg[i][4-:2] == 2'b00) || (pmp_cfg[i][4-:2] == 2'b01))
								pmp_addr_rdata[i][PMPGranularity - 1:0] = 1'sb0;
						end
					end
					else begin : g_pmp_g2
						always @(*) begin
							if (_sv2v_0)
								;
							pmp_addr_rdata[i] = {pmp_addr[i], {PMPGranularity - 1 {1'b1}}};
							if ((pmp_cfg[i][4-:2] == 2'b00) || (pmp_cfg[i][4-:2] == 2'b01))
								pmp_addr_rdata[i][PMPGranularity - 1:0] = 1'sb0;
						end
					end
				end
				else begin : g_other_regions
					assign pmp_cfg_rdata[i] = 1'sb0;
					wire [32:1] sv2v_tmp_D50E5;
					assign sv2v_tmp_D50E5 = 1'sb0;
					always @(*) pmp_addr_rdata[i] = sv2v_tmp_D50E5;
				end
			end
			genvar _gv_i_21;
			for (_gv_i_21 = 0; _gv_i_21 < PMPNumRegions; _gv_i_21 = _gv_i_21 + 1) begin : g_pmp_csrs
				localparam i = _gv_i_21;
				assign pmp_cfg_we[i] = (csr_we_int & ~pmp_cfg_locked[i]) & (csr_addr == (cve2_pkg_CSR_OFF_PMP_CFG + (i[11:0] >> 2)));
				wire [1:1] sv2v_tmp_46013;
				assign sv2v_tmp_46013 = csr_wdata_int[((i % 4) * cve2_pkg_PMP_CFG_W) + 7];
				always @(*) pmp_cfg_wdata[i][5] = sv2v_tmp_46013;
				always @(*) begin
					if (_sv2v_0)
						;
					(* full_case, parallel_case *)
					case (csr_wdata_int[((i % 4) * cve2_pkg_PMP_CFG_W) + 3+:2])
						2'b00: pmp_cfg_wdata[i][4-:2] = 2'b00;
						2'b01: pmp_cfg_wdata[i][4-:2] = 2'b01;
						2'b10: pmp_cfg_wdata[i][4-:2] = (PMPGranularity == 0 ? 2'b10 : 2'b00);
						2'b11: pmp_cfg_wdata[i][4-:2] = 2'b11;
						default: pmp_cfg_wdata[i][4-:2] = 2'b00;
					endcase
				end
				wire [1:1] sv2v_tmp_C83F1;
				assign sv2v_tmp_C83F1 = csr_wdata_int[((i % 4) * cve2_pkg_PMP_CFG_W) + 2];
				always @(*) pmp_cfg_wdata[i][2] = sv2v_tmp_C83F1;
				wire [1:1] sv2v_tmp_5352C;
				assign sv2v_tmp_5352C = (pmp_mseccfg_q[0] ? csr_wdata_int[((i % 4) * cve2_pkg_PMP_CFG_W) + 1] : &csr_wdata_int[(i % 4) * cve2_pkg_PMP_CFG_W+:2]);
				always @(*) pmp_cfg_wdata[i][1] = sv2v_tmp_5352C;
				wire [1:1] sv2v_tmp_113BD;
				assign sv2v_tmp_113BD = csr_wdata_int[(i % 4) * cve2_pkg_PMP_CFG_W];
				always @(*) pmp_cfg_wdata[i][0] = sv2v_tmp_113BD;
				cve2_csr #(
					.Width(6),
					.ResetValue(pmp_cfg_rst[(15 - i) * 6+:6])
				) u_pmp_cfg_csr(
					.clk_i(clk_i),
					.rst_ni(rst_ni),
					.wr_data_i({pmp_cfg_wdata[i]}),
					.wr_en_i(pmp_cfg_we[i]),
					.rd_data_o(pmp_cfg[i]),
					.rd_error_o(pmp_cfg_err[i])
				);
				assign pmp_cfg_locked[i] = pmp_cfg[i][5] & ~pmp_mseccfg_q[2];
				if (i < (PMPNumRegions - 1)) begin : g_lower
					assign pmp_addr_we[i] = ((csr_we_int & ~pmp_cfg_locked[i]) & (~pmp_cfg_locked[i + 1] | (pmp_cfg[i + 1][4-:2] != 2'b01))) & (csr_addr == (cve2_pkg_CSR_OFF_PMP_ADDR + i[11:0]));
				end
				else begin : g_upper
					assign pmp_addr_we[i] = (csr_we_int & ~pmp_cfg_locked[i]) & (csr_addr == (cve2_pkg_CSR_OFF_PMP_ADDR + i[11:0]));
				end
				cve2_csr #(
					.Width(PMPAddrWidth),
					.ResetValue(pmp_addr_rst[((15 - i) * 34) + 33-:PMPAddrWidth])
				) u_pmp_addr_csr(
					.clk_i(clk_i),
					.rst_ni(rst_ni),
					.wr_data_i(csr_wdata_int[31-:PMPAddrWidth]),
					.wr_en_i(pmp_addr_we[i]),
					.rd_data_o(pmp_addr[i]),
					.rd_error_o(pmp_addr_err[i])
				);
				assign csr_pmp_cfg_o[((PMPNumRegions - 1) - i) * 6+:6] = pmp_cfg[i];
				assign csr_pmp_addr_o[((PMPNumRegions - 1) - i) * 34+:34] = {pmp_addr_rdata[i], 2'b00};
			end
			assign pmp_mseccfg_we = csr_we_int & (csr_addr == 12'h747);
			assign pmp_mseccfg_d[0] = (pmp_mseccfg_q[0] ? 1'b1 : csr_wdata_int[cve2_pkg_CSR_MSECCFG_MML_BIT]);
			assign pmp_mseccfg_d[1] = (pmp_mseccfg_q[1] ? 1'b1 : csr_wdata_int[cve2_pkg_CSR_MSECCFG_MMWP_BIT]);
			assign any_pmp_entry_locked = |pmp_cfg_locked;
			assign pmp_mseccfg_d[2] = (any_pmp_entry_locked ? 1'b0 : csr_wdata_int[cve2_pkg_CSR_MSECCFG_RLB_BIT]);
			cve2_csr #(
				.Width(3),
				.ResetValue(pmp_mseccfg_rst)
			) u_pmp_mseccfg(
				.clk_i(clk_i),
				.rst_ni(rst_ni),
				.wr_data_i(pmp_mseccfg_d),
				.wr_en_i(pmp_mseccfg_we),
				.rd_data_o(pmp_mseccfg_q),
				.rd_error_o(pmp_mseccfg_err)
			);
			assign pmp_mseccfg = pmp_mseccfg_q;
		end
		else begin : g_no_pmp_tieoffs
			genvar _gv_i_22;
			for (_gv_i_22 = 0; _gv_i_22 < cve2_pkg_PMP_MAX_REGIONS; _gv_i_22 = _gv_i_22 + 1) begin : g_rdata
				localparam i = _gv_i_22;
				wire [32:1] sv2v_tmp_D50E5;
				assign sv2v_tmp_D50E5 = 1'sb0;
				always @(*) pmp_addr_rdata[i] = sv2v_tmp_D50E5;
				assign pmp_cfg_rdata[i] = 1'sb0;
			end
			genvar _gv_i_23;
			for (_gv_i_23 = 0; _gv_i_23 < PMPNumRegions; _gv_i_23 = _gv_i_23 + 1) begin : g_outputs
				localparam i = _gv_i_23;
				assign csr_pmp_cfg_o[((PMPNumRegions - 1) - i) * 6+:6] = 6'b000000;
				assign csr_pmp_addr_o[((PMPNumRegions - 1) - i) * 34+:34] = 1'sb0;
			end
			assign pmp_mseccfg = 1'sb0;
		end
	endgenerate
	assign csr_pmp_mseccfg_o = pmp_mseccfg;
	always @(*) begin : mcountinhibit_update
		if (_sv2v_0)
			;
		if (mcountinhibit_we == 1'b1)
			mcountinhibit_d = {csr_wdata_int[MHPMCounterNum + 2:2], 1'b0, csr_wdata_int[0]};
		else
			mcountinhibit_d = mcountinhibit_q;
	end
	always @(*) begin : gen_mhpmcounter_incr
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_1
			reg [31:0] i;
			for (i = 0; i < 32; i = i + 1)
				begin : gen_mhpmcounter_incr_inactive
					mhpmcounter_incr[i] = 1'b0;
				end
		end
		mhpmcounter_incr[0] = 1'b1;
		mhpmcounter_incr[1] = 1'b0;
		mhpmcounter_incr[2] = instr_ret_i;
		mhpmcounter_incr[3] = dside_wait_i;
		mhpmcounter_incr[4] = iside_wait_i;
		mhpmcounter_incr[5] = mem_load_i;
		mhpmcounter_incr[6] = mem_store_i;
		mhpmcounter_incr[7] = jump_i;
		mhpmcounter_incr[8] = branch_i;
		mhpmcounter_incr[9] = branch_taken_i;
		mhpmcounter_incr[10] = instr_ret_compressed_i;
		mhpmcounter_incr[11] = wfi_wait_i;
		mhpmcounter_incr[12] = div_wait_i;
	end
	always @(*) begin : gen_mhpmevent
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_2
			reg signed [31:0] i;
			for (i = 0; i < 32; i = i + 1)
				begin : gen_mhpmevent_active
					mhpmevent[i] = 1'sb0;
					mhpmevent[i][i] = 1'b1;
				end
		end
		mhpmevent[1] = 1'sb0;
		begin : sv2v_autoblock_3
			reg [31:0] i;
			for (i = 3 + MHPMCounterNum; i < 32; i = i + 1)
				begin : gen_mhpmevent_inactive
					mhpmevent[i] = 1'sb0;
				end
		end
	end
	cve2_counter #(.CounterWidth(64)) mcycle_counter_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.counter_inc_i(mhpmcounter_incr[0] & ~mcountinhibit[0]),
		.counterh_we_i(mhpmcounterh_we[0]),
		.counter_we_i(mhpmcounter_we[0]),
		.counter_val_i(csr_wdata_int),
		.counter_val_o(mhpmcounter[0]),
		.counter_val_upd_o()
	);
	cve2_counter #(
		.CounterWidth(64),
		.ProvideValUpd(1)
	) minstret_counter_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.counter_inc_i(mhpmcounter_incr[2] & ~mcountinhibit[2]),
		.counterh_we_i(mhpmcounterh_we[2]),
		.counter_we_i(mhpmcounter_we[2]),
		.counter_val_i(csr_wdata_int),
		.counter_val_o(minstret_raw),
		.counter_val_upd_o()
	);
	assign mhpmcounter[2] = minstret_raw;
	assign mhpmcounter[1] = 1'sb0;
	assign unused_mhpmcounter_we_1 = mhpmcounter_we[1];
	assign unused_mhpmcounterh_we_1 = mhpmcounterh_we[1];
	assign unused_mhpmcounter_incr_1 = mhpmcounter_incr[1];
	genvar _gv_i_24;
	generate
		for (_gv_i_24 = 0; _gv_i_24 < 29; _gv_i_24 = _gv_i_24 + 1) begin : gen_cntrs
			localparam i = _gv_i_24;
			localparam signed [31:0] Cnt = i + 3;
			if (i < MHPMCounterNum) begin : gen_imp
				wire [63:0] mhpmcounter_raw;
				wire [63:0] mhpmcounter_next;
				cve2_counter #(
					.CounterWidth(MHPMCounterWidth),
					.ProvideValUpd(Cnt == 10)
				) mcounters_variable_i(
					.clk_i(clk_i),
					.rst_ni(rst_ni),
					.counter_inc_i(mhpmcounter_incr[Cnt] & ~mcountinhibit[Cnt]),
					.counterh_we_i(mhpmcounterh_we[Cnt]),
					.counter_we_i(mhpmcounter_we[Cnt]),
					.counter_val_i(csr_wdata_int),
					.counter_val_o(mhpmcounter_raw),
					.counter_val_upd_o(mhpmcounter_next)
				);
				if (Cnt == 10) begin : gen_compressed_instr_cnt
					assign mhpmcounter[Cnt] = mhpmcounter_raw;
				end
				else begin : gen_other_cnts
					wire [63:0] unused_mhpmcounter_next;
					assign mhpmcounter[Cnt] = mhpmcounter_raw;
					assign unused_mhpmcounter_next = mhpmcounter_next;
				end
			end
			else begin : gen_unimp
				assign mhpmcounter[Cnt] = 1'sb0;
			end
		end
		if (MHPMCounterNum < 29) begin : g_mcountinhibit_reduced
			wire [(29 - MHPMCounterNum) - 1:0] unused_mhphcounter_we;
			wire [(29 - MHPMCounterNum) - 1:0] unused_mhphcounterh_we;
			wire [(29 - MHPMCounterNum) - 1:0] unused_mhphcounter_incr;
			assign mcountinhibit = {{29 - MHPMCounterNum {1'b1}}, mcountinhibit_q};
			assign unused_mhphcounter_we = mhpmcounter_we[31:MHPMCounterNum + 3];
			assign unused_mhphcounterh_we = mhpmcounterh_we[31:MHPMCounterNum + 3];
			assign unused_mhphcounter_incr = mhpmcounter_incr[31:MHPMCounterNum + 3];
		end
		else begin : g_mcountinhibit_full
			assign mcountinhibit = mcountinhibit_q;
		end
	endgenerate
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			mcountinhibit_q <= 1'sb0;
		else
			mcountinhibit_q <= mcountinhibit_d;
	generate
		if (DbgTriggerEn) begin : gen_trigger_regs
			localparam [31:0] DbgHwNumLen = (DbgHwBreakNum > 1 ? $clog2(DbgHwBreakNum) : 1);
			localparam [31:0] MaxTselect = DbgHwBreakNum - 1;
			wire [DbgHwNumLen - 1:0] tselect_d;
			wire [DbgHwNumLen - 1:0] tselect_q;
			wire tmatch_control_d;
			wire [DbgHwBreakNum - 1:0] tmatch_control_q;
			wire [31:0] tmatch_value_d;
			wire [31:0] tmatch_value_q [0:DbgHwBreakNum - 1];
			wire selected_tmatch_control;
			wire [31:0] selected_tmatch_value;
			wire tselect_we;
			wire [DbgHwBreakNum - 1:0] tmatch_control_we;
			wire [DbgHwBreakNum - 1:0] tmatch_value_we;
			wire [DbgHwBreakNum - 1:0] trigger_match;
			assign tselect_we = (csr_we_int & debug_mode_i) & (csr_addr_i == 12'h7a0);
			genvar _gv_i_25;
			for (_gv_i_25 = 0; _gv_i_25 < DbgHwBreakNum; _gv_i_25 = _gv_i_25 + 1) begin : g_dbg_tmatch_we
				localparam i = _gv_i_25;
				assign tmatch_control_we[i] = (((i[DbgHwNumLen - 1:0] == tselect_q) & csr_we_int) & debug_mode_i) & (csr_addr_i == 12'h7a1);
				assign tmatch_value_we[i] = (((i[DbgHwNumLen - 1:0] == tselect_q) & csr_we_int) & debug_mode_i) & (csr_addr_i == 12'h7a2);
			end
			assign tselect_d = (csr_wdata_int < DbgHwBreakNum ? csr_wdata_int[DbgHwNumLen - 1:0] : MaxTselect[DbgHwNumLen - 1:0]);
			assign tmatch_control_d = csr_wdata_int[2];
			assign tmatch_value_d = csr_wdata_int[31:0];
			cve2_csr #(
				.Width(DbgHwNumLen),
				.ShadowCopy(1'b0),
				.ResetValue(1'sb0)
			) u_tselect_csr(
				.clk_i(clk_i),
				.rst_ni(rst_ni),
				.wr_data_i(tselect_d),
				.wr_en_i(tselect_we),
				.rd_data_o(tselect_q),
				.rd_error_o()
			);
			genvar _gv_i_26;
			for (_gv_i_26 = 0; _gv_i_26 < DbgHwBreakNum; _gv_i_26 = _gv_i_26 + 1) begin : g_dbg_tmatch_reg
				localparam i = _gv_i_26;
				cve2_csr #(
					.Width(1),
					.ShadowCopy(1'b0),
					.ResetValue(1'sb0)
				) u_tmatch_control_csr(
					.clk_i(clk_i),
					.rst_ni(rst_ni),
					.wr_data_i(tmatch_control_d),
					.wr_en_i(tmatch_control_we[i]),
					.rd_data_o(tmatch_control_q[i]),
					.rd_error_o()
				);
				cve2_csr #(
					.Width(32),
					.ShadowCopy(1'b0),
					.ResetValue(1'sb0)
				) u_tmatch_value_csr(
					.clk_i(clk_i),
					.rst_ni(rst_ni),
					.wr_data_i(tmatch_value_d),
					.wr_en_i(tmatch_value_we[i]),
					.rd_data_o(tmatch_value_q[i]),
					.rd_error_o()
				);
			end
			localparam [31:0] TSelectRdataPadlen = (DbgHwNumLen >= 32 ? 0 : 32 - DbgHwNumLen);
			assign tselect_rdata = {{TSelectRdataPadlen {1'b0}}, tselect_q};
			if (DbgHwBreakNum > 1) begin : g_dbg_tmatch_multiple_select
				assign selected_tmatch_control = tmatch_control_q[tselect_q];
				assign selected_tmatch_value = tmatch_value_q[tselect_q];
			end
			else begin : g_dbg_tmatch_single_select
				assign selected_tmatch_control = tmatch_control_q[0];
				assign selected_tmatch_value = tmatch_value_q[0];
			end
			assign tmatch_control_rdata = {28'h2800104, umode_control, selected_tmatch_control, 2'b00};
			assign tmatch_value_rdata = selected_tmatch_value;
			genvar _gv_i_27;
			for (_gv_i_27 = 0; _gv_i_27 < DbgHwBreakNum; _gv_i_27 = _gv_i_27 + 1) begin : g_dbg_trigger_match
				localparam i = _gv_i_27;
				assign trigger_match[i] = tmatch_control_q[i] & (pc_if_i[31:0] == tmatch_value_q[i]);
			end
			assign trigger_match_o = |trigger_match;
		end
		else begin : gen_no_trigger_regs
			assign tselect_rdata = 'b0;
			assign tmatch_control_rdata = 'b0;
			assign tmatch_value_rdata = 'b0;
			assign trigger_match_o = 'b0;
		end
	endgenerate
	initial _sv2v_0 = 0;
endmodule
module cve2_csr (
	clk_i,
	rst_ni,
	wr_data_i,
	wr_en_i,
	rd_data_o,
	rd_error_o
);
	parameter [31:0] Width = 32;
	parameter [0:0] ShadowCopy = 1'b0;
	parameter [Width - 1:0] ResetValue = 1'sb0;
	input wire clk_i;
	input wire rst_ni;
	input wire [Width - 1:0] wr_data_i;
	input wire wr_en_i;
	output wire [Width - 1:0] rd_data_o;
	output wire rd_error_o;
	reg [Width - 1:0] rdata_q;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			rdata_q <= ResetValue;
		else if (wr_en_i)
			rdata_q <= wr_data_i;
	assign rd_data_o = rdata_q;
	generate
		if (ShadowCopy) begin : gen_shadow
			reg [Width - 1:0] shadow_q;
			always @(posedge clk_i or negedge rst_ni)
				if (!rst_ni)
					shadow_q <= ~ResetValue;
				else if (wr_en_i)
					shadow_q <= ~wr_data_i;
			assign rd_error_o = rdata_q != ~shadow_q;
		end
		else begin : gen_no_shadow
			assign rd_error_o = 1'b0;
		end
	endgenerate
endmodule
module cve2_counter (
	clk_i,
	rst_ni,
	counter_inc_i,
	counterh_we_i,
	counter_we_i,
	counter_val_i,
	counter_val_o,
	counter_val_upd_o
);
	reg _sv2v_0;
	parameter signed [31:0] CounterWidth = 32;
	parameter [0:0] ProvideValUpd = 0;
	input wire clk_i;
	input wire rst_ni;
	input wire counter_inc_i;
	input wire counterh_we_i;
	input wire counter_we_i;
	input wire [31:0] counter_val_i;
	output wire [63:0] counter_val_o;
	output wire [63:0] counter_val_upd_o;
	wire [63:0] counter;
	wire [CounterWidth - 1:0] counter_upd;
	reg [63:0] counter_load;
	reg we;
	reg [CounterWidth - 1:0] counter_d;
	assign counter_upd = counter[CounterWidth - 1:0] + {{CounterWidth - 1 {1'b0}}, 1'b1};
	always @(*) begin
		if (_sv2v_0)
			;
		we = counter_we_i | counterh_we_i;
		counter_load[63:32] = counter[63:32];
		counter_load[31:0] = counter_val_i;
		if (counterh_we_i) begin
			counter_load[63:32] = counter_val_i;
			counter_load[31:0] = counter[31:0];
		end
		if (we)
			counter_d = counter_load[CounterWidth - 1:0];
		else if (counter_inc_i)
			counter_d = counter_upd[CounterWidth - 1:0];
		else
			counter_d = counter[CounterWidth - 1:0];
	end
	reg [CounterWidth - 1:0] counter_q;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			counter_q <= 1'sb0;
		else
			counter_q <= counter_d;
	generate
		if (CounterWidth < 64) begin : g_counter_narrow
			wire [63:CounterWidth] unused_counter_load;
			assign counter[CounterWidth - 1:0] = counter_q;
			assign counter[63:CounterWidth] = 1'sb0;
			if (ProvideValUpd) begin : g_counter_val_upd_o
				assign counter_val_upd_o[CounterWidth - 1:0] = counter_upd;
			end
			else begin : g_no_counter_val_upd_o
				assign counter_val_upd_o[CounterWidth - 1:0] = 1'sb0;
			end
			assign counter_val_upd_o[63:CounterWidth] = 1'sb0;
			assign unused_counter_load = counter_load[63:CounterWidth];
		end
		else begin : g_counter_full
			assign counter = counter_q;
			if (ProvideValUpd) begin : g_counter_val_upd_o
				assign counter_val_upd_o = counter_upd;
			end
			else begin : g_no_counter_val_upd_o
				assign counter_val_upd_o = 1'sb0;
			end
		end
	endgenerate
	assign counter_val_o = counter;
	initial _sv2v_0 = 0;
endmodule
module cve2_decoder (
	clk_i,
	rst_ni,
	illegal_insn_o,
	ebrk_insn_o,
	mret_insn_o,
	dret_insn_o,
	ecall_insn_o,
	wfi_insn_o,
	jump_set_o,
	instr_first_cycle_i,
	instr_rdata_i,
	instr_rdata_alu_i,
	illegal_c_insn_i,
	imm_a_mux_sel_o,
	imm_b_mux_sel_o,
	imm_i_type_o,
	imm_s_type_o,
	imm_b_type_o,
	imm_u_type_o,
	imm_j_type_o,
	zimm_rs1_type_o,
	rf_wdata_sel_o,
	rf_we_o,
	rf_raddr_a_o,
	rf_raddr_b_o,
	rf_raddr_c_o,
	rf_waddr_o,
	rf_ren_a_o,
	rf_ren_b_o,
	rf_ren_c_o,
	alu_operator_o,
	alu_op_a_mux_sel_o,
	alu_op_b_mux_sel_o,
	alu_multicycle_o,
	mult_en_o,
	div_en_o,
	mult_sel_o,
	div_sel_o,
	multdiv_operator_o,
	multdiv_signed_mode_o,
	csr_access_o,
	csr_op_o,
	data_req_o,
	data_we_o,
	data_type_o,
	data_sign_extension_o,
	x_issue_resp_register_read_i,
	jump_in_dec_o,
	branch_in_dec_o
);
	reg _sv2v_0;
	parameter [0:0] RV32E = 0;
	parameter integer RV32M = 32'sd2;
	parameter integer RV32B = 32'sd0;
	parameter [0:0] XInterface = 1'b0;
	input wire clk_i;
	input wire rst_ni;
	output wire illegal_insn_o;
	output reg ebrk_insn_o;
	output reg mret_insn_o;
	output reg dret_insn_o;
	output reg ecall_insn_o;
	output reg wfi_insn_o;
	output reg jump_set_o;
	input wire instr_first_cycle_i;
	input wire [31:0] instr_rdata_i;
	input wire [31:0] instr_rdata_alu_i;
	input wire illegal_c_insn_i;
	output reg imm_a_mux_sel_o;
	output reg [2:0] imm_b_mux_sel_o;
	output wire [31:0] imm_i_type_o;
	output wire [31:0] imm_s_type_o;
	output wire [31:0] imm_b_type_o;
	output wire [31:0] imm_u_type_o;
	output wire [31:0] imm_j_type_o;
	output wire [31:0] zimm_rs1_type_o;
	output reg [XInterface:0] rf_wdata_sel_o;
	output wire rf_we_o;
	output wire [4:0] rf_raddr_a_o;
	output wire [4:0] rf_raddr_b_o;
	output wire [4:0] rf_raddr_c_o;
	output wire [4:0] rf_waddr_o;
	output reg rf_ren_a_o;
	output reg rf_ren_b_o;
	output reg rf_ren_c_o;
	output reg [6:0] alu_operator_o;
	output reg [1:0] alu_op_a_mux_sel_o;
	output reg alu_op_b_mux_sel_o;
	output reg alu_multicycle_o;
	output wire mult_en_o;
	output wire div_en_o;
	output reg mult_sel_o;
	output reg div_sel_o;
	output reg [1:0] multdiv_operator_o;
	output reg [1:0] multdiv_signed_mode_o;
	output reg csr_access_o;
	output reg [1:0] csr_op_o;
	output reg data_req_o;
	output reg data_we_o;
	output reg [1:0] data_type_o;
	output reg data_sign_extension_o;
	localparam [31:0] cve2_pkg_X_DUAL_READ = 0;
	localparam [31:0] cve2_pkg_X_NUM_RS = 3;
	input wire [(cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) - 1:0] x_issue_resp_register_read_i;
	output reg jump_in_dec_o;
	output reg branch_in_dec_o;
	reg illegal_insn;
	wire illegal_reg_rv32e;
	reg csr_illegal;
	reg rf_we;
	wire [31:0] instr;
	wire [31:0] instr_alu;
	wire [9:0] unused_instr_alu;
	wire [4:0] instr_rs1;
	wire [4:0] instr_rs2;
	wire [4:0] instr_rs3;
	wire [4:0] instr_rd;
	reg use_rs3_d;
	reg use_rs3_q;
	reg [1:0] csr_op;
	reg [6:0] opcode;
	reg [6:0] opcode_alu;
	assign instr = instr_rdata_i;
	assign instr_alu = instr_rdata_alu_i;
	assign imm_i_type_o = {{20 {instr[31]}}, instr[31:20]};
	assign imm_s_type_o = {{20 {instr[31]}}, instr[31:25], instr[11:7]};
	assign imm_b_type_o = {{19 {instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
	assign imm_u_type_o = {instr[31:12], 12'b000000000000};
	assign imm_j_type_o = {{12 {instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
	assign zimm_rs1_type_o = {27'b000000000000000000000000000, instr_rs1};
	generate
		if (RV32B != 32'sd0) begin : gen_rs3_flop
			always @(posedge clk_i or negedge rst_ni)
				if (!rst_ni)
					use_rs3_q <= 1'b0;
				else
					use_rs3_q <= use_rs3_d;
		end
		else begin : gen_no_rs3_flop
			wire unused_clk;
			wire unused_rst_n;
			assign unused_clk = clk_i;
			assign unused_rst_n = rst_ni;
			wire [1:1] sv2v_tmp_12378;
			assign sv2v_tmp_12378 = use_rs3_d;
			always @(*) use_rs3_q = sv2v_tmp_12378;
		end
	endgenerate
	assign instr_rs1 = instr[19:15];
	assign instr_rs2 = instr[24:20];
	assign instr_rs3 = instr[31:27];
	assign rf_raddr_a_o = (use_rs3_q & ~instr_first_cycle_i ? instr_rs3 : instr_rs1);
	assign rf_raddr_b_o = instr_rs2;
	assign rf_raddr_c_o = (XInterface ? instr_rs3 : {5 {1'sb0}});
	assign instr_rd = instr[11:7];
	assign rf_waddr_o = instr_rd;
	generate
		if (RV32E) begin : gen_rv32e_reg_check_active
			assign illegal_reg_rv32e = ((rf_raddr_a_o[4] & (alu_op_a_mux_sel_o == 2'd0)) | (rf_raddr_b_o[4] & (alu_op_b_mux_sel_o == 1'd0))) | (rf_waddr_o[4] & rf_we);
		end
		else begin : gen_rv32e_reg_check_inactive
			assign illegal_reg_rv32e = 1'b0;
		end
	endgenerate
	always @(*) begin : csr_operand_check
		if (_sv2v_0)
			;
		csr_op_o = csr_op;
		if (((csr_op == 2'd2) || (csr_op == 2'd3)) && (instr_rs1 == {5 {1'sb0}}))
			csr_op_o = 2'd0;
	end
	function automatic [(XInterface >= 0 ? XInterface + 1 : 1 - XInterface) - 1:0] sv2v_cast_020D8;
		input reg [(XInterface >= 0 ? XInterface + 1 : 1 - XInterface) - 1:0] inp;
		sv2v_cast_020D8 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		jump_in_dec_o = 1'b0;
		jump_set_o = 1'b0;
		branch_in_dec_o = 1'b0;
		multdiv_operator_o = 2'd0;
		multdiv_signed_mode_o = 2'b00;
		rf_wdata_sel_o = sv2v_cast_020D8(32'd0);
		rf_we = 1'b0;
		rf_ren_a_o = 1'b0;
		rf_ren_b_o = 1'b0;
		rf_ren_c_o = 1'b0;
		csr_access_o = 1'b0;
		csr_illegal = 1'b0;
		csr_op = 2'd0;
		data_we_o = 1'b0;
		data_type_o = 2'b00;
		data_sign_extension_o = 1'b0;
		data_req_o = 1'b0;
		illegal_insn = 1'b0;
		ebrk_insn_o = 1'b0;
		mret_insn_o = 1'b0;
		dret_insn_o = 1'b0;
		ecall_insn_o = 1'b0;
		wfi_insn_o = 1'b0;
		opcode = instr[6:0];
		(* full_case, parallel_case *)
		case (opcode)
			7'h6f: begin
				jump_in_dec_o = 1'b1;
				if (instr_first_cycle_i) begin
					rf_we = 1'b0;
					jump_set_o = 1'b1;
				end
				else
					rf_we = 1'b1;
			end
			7'h67: begin
				jump_in_dec_o = 1'b1;
				if (instr_first_cycle_i) begin
					rf_we = 1'b0;
					jump_set_o = 1'b1;
				end
				else
					rf_we = 1'b1;
				if (instr[14:12] != 3'b000)
					illegal_insn = 1'b1;
				rf_ren_a_o = 1'b1;
			end
			7'h63: begin
				branch_in_dec_o = 1'b1;
				(* full_case, parallel_case *)
				case (instr[14:12])
					3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111: illegal_insn = 1'b0;
					default: illegal_insn = 1'b1;
				endcase
				rf_ren_a_o = 1'b1;
				rf_ren_b_o = 1'b1;
			end
			7'h23: begin
				rf_ren_a_o = 1'b1;
				rf_ren_b_o = 1'b1;
				data_req_o = 1'b1;
				data_we_o = 1'b1;
				if (instr[14])
					illegal_insn = 1'b1;
				(* full_case, parallel_case *)
				case (instr[13:12])
					2'b00: data_type_o = 2'b10;
					2'b01: data_type_o = 2'b01;
					2'b10: data_type_o = 2'b00;
					default: illegal_insn = 1'b1;
				endcase
			end
			7'h03: begin
				rf_ren_a_o = 1'b1;
				data_req_o = 1'b1;
				data_type_o = 2'b00;
				data_sign_extension_o = ~instr[14];
				(* full_case, parallel_case *)
				case (instr[13:12])
					2'b00: data_type_o = 2'b10;
					2'b01: data_type_o = 2'b01;
					2'b10: begin
						data_type_o = 2'b00;
						if (instr[14])
							illegal_insn = 1'b1;
					end
					default: illegal_insn = 1'b1;
				endcase
			end
			7'h37: rf_we = 1'b1;
			7'h17: rf_we = 1'b1;
			7'h13: begin
				rf_ren_a_o = 1'b1;
				rf_we = 1'b1;
				(* full_case, parallel_case *)
				case (instr[14:12])
					3'b000, 3'b010, 3'b011, 3'b100, 3'b110, 3'b111: illegal_insn = 1'b0;
					3'b001:
						(* full_case, parallel_case *)
						case (instr[31:27])
							5'b00000: illegal_insn = (instr[26:25] == 2'b00 ? 1'b0 : 1'b1);
							5'b00100: illegal_insn = ((RV32B == 32'sd2) || (RV32B == 32'sd3) ? 1'b0 : 1'b1);
							5'b01001, 5'b00101, 5'b01101: illegal_insn = (RV32B != 32'sd0 ? 1'b0 : 1'b1);
							5'b00001:
								if (instr[26] == 1'b0)
									illegal_insn = ((RV32B == 32'sd2) || (RV32B == 32'sd3) ? 1'b0 : 1'b1);
								else
									illegal_insn = 1'b1;
							5'b01100:
								(* full_case, parallel_case *)
								case (instr[26:20])
									7'b0000000, 7'b0000001, 7'b0000010, 7'b0000100, 7'b0000101: illegal_insn = (RV32B != 32'sd0 ? 1'b0 : 1'b1);
									7'b0010000, 7'b0010001, 7'b0010010, 7'b0011000, 7'b0011001, 7'b0011010: illegal_insn = ((RV32B == 32'sd2) || (RV32B == 32'sd3) ? 1'b0 : 1'b1);
									default: illegal_insn = 1'b1;
								endcase
							default: illegal_insn = 1'b1;
						endcase
					3'b101:
						if (instr[26])
							illegal_insn = (RV32B != 32'sd0 ? 1'b0 : 1'b1);
						else
							(* full_case, parallel_case *)
							case (instr[31:27])
								5'b00000, 5'b01000: illegal_insn = (instr[26:25] == 2'b00 ? 1'b0 : 1'b1);
								5'b00100: illegal_insn = ((RV32B == 32'sd2) || (RV32B == 32'sd3) ? 1'b0 : 1'b1);
								5'b01100, 5'b01001: illegal_insn = (RV32B != 32'sd0 ? 1'b0 : 1'b1);
								5'b01101:
									if ((RV32B == 32'sd2) || (RV32B == 32'sd3))
										illegal_insn = 1'b0;
									else if (RV32B == 32'sd1)
										illegal_insn = (instr[24:20] == 5'b11000 ? 1'b0 : 1'b1);
									else
										illegal_insn = 1'b1;
								5'b00101:
									if ((RV32B == 32'sd2) || (RV32B == 32'sd3))
										illegal_insn = 1'b0;
									else if (instr[24:20] == 5'b00111)
										illegal_insn = (RV32B == 32'sd1 ? 1'b0 : 1'b1);
									else
										illegal_insn = 1'b1;
								5'b00001:
									if (instr[26] == 1'b0)
										illegal_insn = ((RV32B == 32'sd2) || (RV32B == 32'sd3) ? 1'b0 : 1'b1);
									else
										illegal_insn = 1'b1;
								default: illegal_insn = 1'b1;
							endcase
					default: illegal_insn = 1'b1;
				endcase
			end
			7'h33: begin
				rf_ren_a_o = 1'b1;
				rf_ren_b_o = 1'b1;
				rf_we = 1'b1;
				if ({instr[26], instr[13:12]} == 3'b101)
					illegal_insn = (RV32B != 32'sd0 ? 1'b0 : 1'b1);
				else
					(* full_case, parallel_case *)
					case ({instr[31:25], instr[14:12]})
						10'b0000000000, 10'b0100000000, 10'b0000000010, 10'b0000000011, 10'b0000000100, 10'b0000000110, 10'b0000000111, 10'b0000000001, 10'b0000000101, 10'b0100000101: illegal_insn = 1'b0;
						10'b0010000010, 10'b0010000100, 10'b0010000110, 10'b0100000111, 10'b0100000110, 10'b0100000100, 10'b0110000001, 10'b0110000101, 10'b0000101100, 10'b0000101110, 10'b0000101101, 10'b0000101111, 10'b0000100100, 10'b0100100100, 10'b0000100111, 10'b0100100001, 10'b0010100001, 10'b0110100001, 10'b0100100101, 10'b0100100111: illegal_insn = (RV32B != 32'sd0 ? 1'b0 : 1'b1);
						10'b0110100101, 10'b0010100101, 10'b0000100001, 10'b0000100101, 10'b0010100010, 10'b0010100100, 10'b0010100110, 10'b0010000001, 10'b0010000101, 10'b0000101001, 10'b0000101010, 10'b0000101011: illegal_insn = ((RV32B == 32'sd2) || (RV32B == 32'sd3) ? 1'b0 : 1'b1);
						10'b0100100110, 10'b0000100110: illegal_insn = (RV32B == 32'sd3 ? 1'b0 : 1'b1);
						10'b0000001000: begin
							multdiv_operator_o = 2'd0;
							multdiv_signed_mode_o = 2'b00;
							illegal_insn = (RV32M == 32'sd0 ? 1'b1 : 1'b0);
						end
						10'b0000001001: begin
							multdiv_operator_o = 2'd1;
							multdiv_signed_mode_o = 2'b11;
							illegal_insn = (RV32M == 32'sd0 ? 1'b1 : 1'b0);
						end
						10'b0000001010: begin
							multdiv_operator_o = 2'd1;
							multdiv_signed_mode_o = 2'b01;
							illegal_insn = (RV32M == 32'sd0 ? 1'b1 : 1'b0);
						end
						10'b0000001011: begin
							multdiv_operator_o = 2'd1;
							multdiv_signed_mode_o = 2'b00;
							illegal_insn = (RV32M == 32'sd0 ? 1'b1 : 1'b0);
						end
						10'b0000001100: begin
							multdiv_operator_o = 2'd2;
							multdiv_signed_mode_o = 2'b11;
							illegal_insn = (RV32M == 32'sd0 ? 1'b1 : 1'b0);
						end
						10'b0000001101: begin
							multdiv_operator_o = 2'd2;
							multdiv_signed_mode_o = 2'b00;
							illegal_insn = (RV32M == 32'sd0 ? 1'b1 : 1'b0);
						end
						10'b0000001110: begin
							multdiv_operator_o = 2'd3;
							multdiv_signed_mode_o = 2'b11;
							illegal_insn = (RV32M == 32'sd0 ? 1'b1 : 1'b0);
						end
						10'b0000001111: begin
							multdiv_operator_o = 2'd3;
							multdiv_signed_mode_o = 2'b00;
							illegal_insn = (RV32M == 32'sd0 ? 1'b1 : 1'b0);
						end
						default: illegal_insn = 1'b1;
					endcase
			end
			7'h0f:
				(* full_case, parallel_case *)
				case (instr[14:12])
					3'b000: rf_we = 1'b0;
					3'b001: begin
						jump_in_dec_o = 1'b1;
						rf_we = 1'b0;
						if (instr_first_cycle_i)
							jump_set_o = 1'b1;
					end
					default: illegal_insn = 1'b1;
				endcase
			7'h73:
				if (instr[14:12] == 3'b000) begin
					(* full_case, parallel_case *)
					case (instr[31:20])
						12'h000: ecall_insn_o = 1'b1;
						12'h001: ebrk_insn_o = 1'b1;
						12'h302: mret_insn_o = 1'b1;
						12'h7b2: dret_insn_o = 1'b1;
						12'h105: wfi_insn_o = 1'b1;
						default: illegal_insn = 1'b1;
					endcase
					if ((instr_rs1 != 5'b00000) || (instr_rd != 5'b00000))
						illegal_insn = 1'b1;
				end
				else begin
					csr_access_o = 1'b1;
					rf_wdata_sel_o = sv2v_cast_020D8(32'd1);
					rf_we = 1'b1;
					if (~instr[14])
						rf_ren_a_o = 1'b1;
					(* full_case, parallel_case *)
					case (instr[13:12])
						2'b01: csr_op = 2'd1;
						2'b10: csr_op = 2'd2;
						2'b11: csr_op = 2'd3;
						default: csr_illegal = 1'b1;
					endcase
					illegal_insn = csr_illegal;
				end
			default: illegal_insn = 1'b1;
		endcase
		if (illegal_c_insn_i)
			illegal_insn = 1'b1;
		if (illegal_insn) begin
			rf_we = 1'b0;
			data_req_o = 1'b0;
			data_we_o = 1'b0;
			jump_in_dec_o = 1'b0;
			jump_set_o = 1'b0;
			branch_in_dec_o = 1'b0;
			csr_access_o = 1'b0;
			if (XInterface) begin
				rf_ren_a_o = x_issue_resp_register_read_i[0];
				rf_ren_b_o = x_issue_resp_register_read_i[1];
				rf_ren_c_o = x_issue_resp_register_read_i[2];
				rf_wdata_sel_o = sv2v_cast_020D8(32'd2);
			end
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		alu_operator_o = 7'd44;
		alu_op_a_mux_sel_o = 2'd3;
		alu_op_b_mux_sel_o = 1'd1;
		imm_a_mux_sel_o = 1'd1;
		imm_b_mux_sel_o = 3'd0;
		opcode_alu = instr_alu[6:0];
		use_rs3_d = 1'b0;
		alu_multicycle_o = 1'b0;
		mult_sel_o = 1'b0;
		div_sel_o = 1'b0;
		(* full_case, parallel_case *)
		case (opcode_alu)
			7'h6f:
				if (instr_first_cycle_i) begin
					alu_op_a_mux_sel_o = 2'd2;
					alu_op_b_mux_sel_o = 1'd1;
					imm_b_mux_sel_o = 3'd4;
					alu_operator_o = 7'd0;
				end
				else begin
					alu_op_a_mux_sel_o = 2'd2;
					alu_op_b_mux_sel_o = 1'd1;
					imm_b_mux_sel_o = 3'd5;
					alu_operator_o = 7'd0;
				end
			7'h67:
				if (instr_first_cycle_i) begin
					alu_op_a_mux_sel_o = 2'd0;
					alu_op_b_mux_sel_o = 1'd1;
					imm_b_mux_sel_o = 3'd0;
					alu_operator_o = 7'd0;
				end
				else begin
					alu_op_a_mux_sel_o = 2'd2;
					alu_op_b_mux_sel_o = 1'd1;
					imm_b_mux_sel_o = 3'd5;
					alu_operator_o = 7'd0;
				end
			7'h63: begin
				(* full_case, parallel_case *)
				case (instr_alu[14:12])
					3'b000: alu_operator_o = 7'd29;
					3'b001: alu_operator_o = 7'd30;
					3'b100: alu_operator_o = 7'd25;
					3'b101: alu_operator_o = 7'd27;
					3'b110: alu_operator_o = 7'd26;
					3'b111: alu_operator_o = 7'd28;
					default:
						;
				endcase
				if (instr_first_cycle_i) begin
					alu_op_a_mux_sel_o = 2'd0;
					alu_op_b_mux_sel_o = 1'd0;
				end
				else begin
					alu_op_a_mux_sel_o = 2'd2;
					alu_op_b_mux_sel_o = 1'd1;
					imm_b_mux_sel_o = 3'd2;
					alu_operator_o = 7'd0;
				end
			end
			7'h23: begin
				alu_op_a_mux_sel_o = 2'd0;
				alu_op_b_mux_sel_o = 1'd0;
				alu_operator_o = 7'd0;
				if (!instr_alu[14]) begin
					imm_b_mux_sel_o = 3'd1;
					alu_op_b_mux_sel_o = 1'd1;
				end
			end
			7'h03: begin
				alu_op_a_mux_sel_o = 2'd0;
				alu_operator_o = 7'd0;
				alu_op_b_mux_sel_o = 1'd1;
				imm_b_mux_sel_o = 3'd0;
			end
			7'h37: begin
				alu_op_a_mux_sel_o = 2'd3;
				alu_op_b_mux_sel_o = 1'd1;
				imm_a_mux_sel_o = 1'd1;
				imm_b_mux_sel_o = 3'd3;
				alu_operator_o = 7'd0;
			end
			7'h17: begin
				alu_op_a_mux_sel_o = 2'd2;
				alu_op_b_mux_sel_o = 1'd1;
				imm_b_mux_sel_o = 3'd3;
				alu_operator_o = 7'd0;
			end
			7'h13: begin
				alu_op_a_mux_sel_o = 2'd0;
				alu_op_b_mux_sel_o = 1'd1;
				imm_b_mux_sel_o = 3'd0;
				(* full_case, parallel_case *)
				case (instr_alu[14:12])
					3'b000: alu_operator_o = 7'd0;
					3'b010: alu_operator_o = 7'd43;
					3'b011: alu_operator_o = 7'd44;
					3'b100: alu_operator_o = 7'd2;
					3'b110: alu_operator_o = 7'd3;
					3'b111: alu_operator_o = 7'd4;
					3'b001:
						if (RV32B != 32'sd0)
							(* full_case, parallel_case *)
							case (instr_alu[31:27])
								5'b00000: alu_operator_o = 7'd10;
								5'b00100:
									if ((RV32B == 32'sd2) || (RV32B == 32'sd3))
										alu_operator_o = 7'd12;
								5'b01001: alu_operator_o = 7'd50;
								5'b00101: alu_operator_o = 7'd49;
								5'b01101: alu_operator_o = 7'd51;
								5'b00001:
									if (instr_alu[26] == 0)
										alu_operator_o = 7'd17;
								5'b01100:
									(* full_case, parallel_case *)
									case (instr_alu[26:20])
										7'b0000000: alu_operator_o = 7'd40;
										7'b0000001: alu_operator_o = 7'd41;
										7'b0000010: alu_operator_o = 7'd42;
										7'b0000100: alu_operator_o = 7'd38;
										7'b0000101: alu_operator_o = 7'd39;
										7'b0010000:
											if ((RV32B == 32'sd2) || (RV32B == 32'sd3)) begin
												alu_operator_o = 7'd59;
												alu_multicycle_o = 1'b1;
											end
										7'b0010001:
											if ((RV32B == 32'sd2) || (RV32B == 32'sd3)) begin
												alu_operator_o = 7'd61;
												alu_multicycle_o = 1'b1;
											end
										7'b0010010:
											if ((RV32B == 32'sd2) || (RV32B == 32'sd3)) begin
												alu_operator_o = 7'd63;
												alu_multicycle_o = 1'b1;
											end
										7'b0011000:
											if ((RV32B == 32'sd2) || (RV32B == 32'sd3)) begin
												alu_operator_o = 7'd60;
												alu_multicycle_o = 1'b1;
											end
										7'b0011001:
											if ((RV32B == 32'sd2) || (RV32B == 32'sd3)) begin
												alu_operator_o = 7'd62;
												alu_multicycle_o = 1'b1;
											end
										7'b0011010:
											if ((RV32B == 32'sd2) || (RV32B == 32'sd3)) begin
												alu_operator_o = 7'd64;
												alu_multicycle_o = 1'b1;
											end
										default:
											;
									endcase
								default:
									;
							endcase
						else
							alu_operator_o = 7'd10;
					3'b101:
						if (RV32B != 32'sd0) begin
							if (instr_alu[26] == 1'b1) begin
								alu_operator_o = 7'd48;
								alu_multicycle_o = 1'b1;
								if (instr_first_cycle_i)
									use_rs3_d = 1'b1;
								else
									use_rs3_d = 1'b0;
							end
							else
								(* full_case, parallel_case *)
								case (instr_alu[31:27])
									5'b00000: alu_operator_o = 7'd9;
									5'b01000: alu_operator_o = 7'd8;
									5'b00100:
										if ((RV32B == 32'sd2) || (RV32B == 32'sd3))
											alu_operator_o = 7'd11;
									5'b01001: alu_operator_o = 7'd52;
									5'b01100: begin
										alu_operator_o = 7'd13;
										alu_multicycle_o = 1'b1;
									end
									5'b01101: alu_operator_o = 7'd15;
									5'b00101: alu_operator_o = 7'd16;
									5'b00001:
										if ((RV32B == 32'sd2) || (RV32B == 32'sd3)) begin
											if (instr_alu[26] == 1'b0)
												alu_operator_o = 7'd18;
										end
									default:
										;
								endcase
						end
						else if (instr_alu[31:27] == 5'b00000)
							alu_operator_o = 7'd9;
						else if (instr_alu[31:27] == 5'b01000)
							alu_operator_o = 7'd8;
					default:
						;
				endcase
			end
			7'h33: begin
				alu_op_a_mux_sel_o = 2'd0;
				alu_op_b_mux_sel_o = 1'd0;
				if (instr_alu[26]) begin
					if (RV32B != 32'sd0)
						(* full_case, parallel_case *)
						case ({instr_alu[26:25], instr_alu[14:12]})
							5'b11001: begin
								alu_operator_o = 7'd46;
								alu_multicycle_o = 1'b1;
								if (instr_first_cycle_i)
									use_rs3_d = 1'b1;
								else
									use_rs3_d = 1'b0;
							end
							5'b11101: begin
								alu_operator_o = 7'd45;
								alu_multicycle_o = 1'b1;
								if (instr_first_cycle_i)
									use_rs3_d = 1'b1;
								else
									use_rs3_d = 1'b0;
							end
							5'b10001: begin
								alu_operator_o = 7'd47;
								alu_multicycle_o = 1'b1;
								if (instr_first_cycle_i)
									use_rs3_d = 1'b1;
								else
									use_rs3_d = 1'b0;
							end
							5'b10101: begin
								alu_operator_o = 7'd48;
								alu_multicycle_o = 1'b1;
								if (instr_first_cycle_i)
									use_rs3_d = 1'b1;
								else
									use_rs3_d = 1'b0;
							end
							default:
								;
						endcase
				end
				else
					(* full_case, parallel_case *)
					case ({instr_alu[31:25], instr_alu[14:12]})
						10'b0000000000: alu_operator_o = 7'd0;
						10'b0100000000: alu_operator_o = 7'd1;
						10'b0000000010: alu_operator_o = 7'd43;
						10'b0000000011: alu_operator_o = 7'd44;
						10'b0000000100: alu_operator_o = 7'd2;
						10'b0000000110: alu_operator_o = 7'd3;
						10'b0000000111: alu_operator_o = 7'd4;
						10'b0000000001: alu_operator_o = 7'd10;
						10'b0000000101: alu_operator_o = 7'd9;
						10'b0100000101: alu_operator_o = 7'd8;
						10'b0110000001:
							if (RV32B != 32'sd0) begin
								alu_operator_o = 7'd14;
								alu_multicycle_o = 1'b1;
							end
						10'b0110000101:
							if (RV32B != 32'sd0) begin
								alu_operator_o = 7'd13;
								alu_multicycle_o = 1'b1;
							end
						10'b0000101100:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd31;
						10'b0000101110:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd33;
						10'b0000101101:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd32;
						10'b0000101111:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd34;
						10'b0000100100:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd35;
						10'b0100100100:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd36;
						10'b0000100111:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd37;
						10'b0100000100:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd5;
						10'b0100000110:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd6;
						10'b0100000111:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd7;
						10'b0010000010:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd22;
						10'b0010000100:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd23;
						10'b0010000110:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd24;
						10'b0100100001:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd50;
						10'b0010100001:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd49;
						10'b0110100001:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd51;
						10'b0100100101:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd52;
						10'b0100100111:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd55;
						10'b0110100101:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd15;
						10'b0010100101:
							if (RV32B != 32'sd0)
								alu_operator_o = 7'd16;
						10'b0000100001:
							if ((RV32B == 32'sd2) || (RV32B == 32'sd3))
								alu_operator_o = 7'd17;
						10'b0000100101:
							if ((RV32B == 32'sd2) || (RV32B == 32'sd3))
								alu_operator_o = 7'd18;
						10'b0010100010:
							if ((RV32B == 32'sd2) || (RV32B == 32'sd3))
								alu_operator_o = 7'd19;
						10'b0010100100:
							if ((RV32B == 32'sd2) || (RV32B == 32'sd3))
								alu_operator_o = 7'd20;
						10'b0010100110:
							if ((RV32B == 32'sd2) || (RV32B == 32'sd3))
								alu_operator_o = 7'd21;
						10'b0010000001:
							if ((RV32B == 32'sd2) || (RV32B == 32'sd3))
								alu_operator_o = 7'd12;
						10'b0010000101:
							if ((RV32B == 32'sd2) || (RV32B == 32'sd3))
								alu_operator_o = 7'd11;
						10'b0000101001:
							if ((RV32B == 32'sd2) || (RV32B == 32'sd3))
								alu_operator_o = 7'd56;
						10'b0000101010:
							if ((RV32B == 32'sd2) || (RV32B == 32'sd3))
								alu_operator_o = 7'd57;
						10'b0000101011:
							if ((RV32B == 32'sd2) || (RV32B == 32'sd3))
								alu_operator_o = 7'd58;
						10'b0100100110:
							if (RV32B == 32'sd3) begin
								alu_operator_o = 7'd54;
								alu_multicycle_o = 1'b1;
							end
						10'b0000100110:
							if (RV32B == 32'sd3) begin
								alu_operator_o = 7'd53;
								alu_multicycle_o = 1'b1;
							end
						10'b0000001000: begin
							alu_operator_o = 7'd0;
							mult_sel_o = (RV32M == 32'sd0 ? 1'b0 : 1'b1);
						end
						10'b0000001001: begin
							alu_operator_o = 7'd0;
							mult_sel_o = (RV32M == 32'sd0 ? 1'b0 : 1'b1);
						end
						10'b0000001010: begin
							alu_operator_o = 7'd0;
							mult_sel_o = (RV32M == 32'sd0 ? 1'b0 : 1'b1);
						end
						10'b0000001011: begin
							alu_operator_o = 7'd0;
							mult_sel_o = (RV32M == 32'sd0 ? 1'b0 : 1'b1);
						end
						10'b0000001100: begin
							alu_operator_o = 7'd0;
							div_sel_o = (RV32M == 32'sd0 ? 1'b0 : 1'b1);
						end
						10'b0000001101: begin
							alu_operator_o = 7'd0;
							div_sel_o = (RV32M == 32'sd0 ? 1'b0 : 1'b1);
						end
						10'b0000001110: begin
							alu_operator_o = 7'd0;
							div_sel_o = (RV32M == 32'sd0 ? 1'b0 : 1'b1);
						end
						10'b0000001111: begin
							alu_operator_o = 7'd0;
							div_sel_o = (RV32M == 32'sd0 ? 1'b0 : 1'b1);
						end
						default:
							;
					endcase
			end
			7'h0f:
				(* full_case, parallel_case *)
				case (instr_alu[14:12])
					3'b000: begin
						alu_operator_o = 7'd0;
						alu_op_a_mux_sel_o = 2'd0;
						alu_op_b_mux_sel_o = 1'd1;
					end
					3'b001: begin
						alu_op_a_mux_sel_o = 2'd2;
						alu_op_b_mux_sel_o = 1'd1;
						imm_b_mux_sel_o = 3'd5;
						alu_operator_o = 7'd0;
					end
					default:
						;
				endcase
			7'h73:
				if (instr_alu[14:12] == 3'b000) begin
					alu_op_a_mux_sel_o = 2'd0;
					alu_op_b_mux_sel_o = 1'd1;
				end
				else begin
					alu_op_b_mux_sel_o = 1'd1;
					imm_a_mux_sel_o = 1'd0;
					imm_b_mux_sel_o = 3'd0;
					if (instr_alu[14])
						alu_op_a_mux_sel_o = 2'd3;
					else
						alu_op_a_mux_sel_o = 2'd0;
				end
			default:
				;
		endcase
	end
	assign mult_en_o = (illegal_insn ? 1'b0 : mult_sel_o);
	assign div_en_o = (illegal_insn ? 1'b0 : div_sel_o);
	assign illegal_insn_o = illegal_insn | illegal_reg_rv32e;
	assign rf_we_o = rf_we & ~illegal_reg_rv32e;
	assign unused_instr_alu = {instr_alu[19:15], instr_alu[11:7]};
	initial _sv2v_0 = 0;
endmodule
module cve2_ex_block (
	clk_i,
	rst_ni,
	alu_operator_i,
	alu_operand_a_i,
	alu_operand_b_i,
	alu_instr_first_cycle_i,
	multdiv_operator_i,
	mult_en_i,
	div_en_i,
	mult_sel_i,
	div_sel_i,
	multdiv_signed_mode_i,
	multdiv_operand_a_i,
	multdiv_operand_b_i,
	imd_val_we_o,
	imd_val_d_o,
	imd_val_q_i,
	alu_adder_result_ex_o,
	result_ex_o,
	branch_target_o,
	branch_decision_o,
	ex_valid_o
);
	parameter integer RV32M = 32'sd2;
	parameter integer RV32B = 32'sd0;
	input wire clk_i;
	input wire rst_ni;
	input wire [6:0] alu_operator_i;
	input wire [31:0] alu_operand_a_i;
	input wire [31:0] alu_operand_b_i;
	input wire alu_instr_first_cycle_i;
	input wire [1:0] multdiv_operator_i;
	input wire mult_en_i;
	input wire div_en_i;
	input wire mult_sel_i;
	input wire div_sel_i;
	input wire [1:0] multdiv_signed_mode_i;
	input wire [31:0] multdiv_operand_a_i;
	input wire [31:0] multdiv_operand_b_i;
	output wire [1:0] imd_val_we_o;
	output wire [67:0] imd_val_d_o;
	input wire [67:0] imd_val_q_i;
	output wire [31:0] alu_adder_result_ex_o;
	output wire [31:0] result_ex_o;
	output wire [31:0] branch_target_o;
	output wire branch_decision_o;
	output wire ex_valid_o;
	wire [31:0] alu_result;
	wire [31:0] multdiv_result;
	wire [32:0] multdiv_alu_operand_b;
	wire [32:0] multdiv_alu_operand_a;
	wire [33:0] alu_adder_result_ext;
	wire alu_cmp_result;
	wire alu_is_equal_result;
	wire multdiv_valid;
	wire multdiv_sel;
	wire [63:0] alu_imd_val_q;
	wire [63:0] alu_imd_val_d;
	wire [1:0] alu_imd_val_we;
	wire [67:0] multdiv_imd_val_d;
	wire [1:0] multdiv_imd_val_we;
	generate
		if (RV32M != 32'sd0) begin : gen_multdiv_m
			assign multdiv_sel = mult_sel_i | div_sel_i;
		end
		else begin : gen_multdiv_no_m
			assign multdiv_sel = 1'b0;
		end
	endgenerate
	assign imd_val_d_o[34+:34] = (multdiv_sel ? multdiv_imd_val_d[34+:34] : {2'b00, alu_imd_val_d[32+:32]});
	assign imd_val_d_o[0+:34] = (multdiv_sel ? multdiv_imd_val_d[0+:34] : {2'b00, alu_imd_val_d[0+:32]});
	assign imd_val_we_o = (multdiv_sel ? multdiv_imd_val_we : alu_imd_val_we);
	assign alu_imd_val_q = {imd_val_q_i[65-:32], imd_val_q_i[31-:32]};
	assign result_ex_o = (multdiv_sel ? multdiv_result : alu_result);
	assign branch_decision_o = alu_cmp_result;
	assign branch_target_o = alu_adder_result_ex_o;
	cve2_alu #(.RV32B(RV32B)) alu_i(
		.operator_i(alu_operator_i),
		.operand_a_i(alu_operand_a_i),
		.operand_b_i(alu_operand_b_i),
		.instr_first_cycle_i(alu_instr_first_cycle_i),
		.imd_val_q_i(alu_imd_val_q),
		.imd_val_we_o(alu_imd_val_we),
		.imd_val_d_o(alu_imd_val_d),
		.multdiv_operand_a_i(multdiv_alu_operand_a),
		.multdiv_operand_b_i(multdiv_alu_operand_b),
		.multdiv_sel_i(multdiv_sel),
		.adder_result_o(alu_adder_result_ex_o),
		.adder_result_ext_o(alu_adder_result_ext),
		.result_o(alu_result),
		.comparison_result_o(alu_cmp_result),
		.is_equal_result_o(alu_is_equal_result)
	);
	generate
		if (RV32M == 32'sd1) begin : gen_multdiv_slow
			cve2_multdiv_slow multdiv_i(
				.clk_i(clk_i),
				.rst_ni(rst_ni),
				.mult_en_i(mult_en_i),
				.div_en_i(div_en_i),
				.mult_sel_i(mult_sel_i),
				.div_sel_i(div_sel_i),
				.operator_i(multdiv_operator_i),
				.signed_mode_i(multdiv_signed_mode_i),
				.op_a_i(multdiv_operand_a_i),
				.op_b_i(multdiv_operand_b_i),
				.alu_adder_ext_i(alu_adder_result_ext),
				.alu_adder_i(alu_adder_result_ex_o),
				.equal_to_zero_i(alu_is_equal_result),
				.valid_o(multdiv_valid),
				.alu_operand_a_o(multdiv_alu_operand_a),
				.alu_operand_b_o(multdiv_alu_operand_b),
				.imd_val_q_i(imd_val_q_i),
				.imd_val_d_o(multdiv_imd_val_d),
				.imd_val_we_o(multdiv_imd_val_we),
				.multdiv_ready_id_i(1'b1),
				.multdiv_result_o(multdiv_result)
			);
		end
		else if ((RV32M == 32'sd2) || (RV32M == 32'sd3)) begin : gen_multdiv_fast
			cve2_multdiv_fast #(.RV32M(RV32M)) multdiv_i(
				.clk_i(clk_i),
				.rst_ni(rst_ni),
				.mult_en_i(mult_en_i),
				.div_en_i(div_en_i),
				.mult_sel_i(mult_sel_i),
				.div_sel_i(div_sel_i),
				.operator_i(multdiv_operator_i),
				.signed_mode_i(multdiv_signed_mode_i),
				.op_a_i(multdiv_operand_a_i),
				.op_b_i(multdiv_operand_b_i),
				.alu_operand_a_o(multdiv_alu_operand_a),
				.alu_operand_b_o(multdiv_alu_operand_b),
				.alu_adder_ext_i(alu_adder_result_ext),
				.alu_adder_i(alu_adder_result_ex_o),
				.equal_to_zero_i(alu_is_equal_result),
				.imd_val_q_i(imd_val_q_i),
				.imd_val_d_o(multdiv_imd_val_d),
				.imd_val_we_o(multdiv_imd_val_we),
				.valid_o(multdiv_valid),
				.multdiv_result_o(multdiv_result)
			);
		end
		else begin : gen_no_multdiv
			assign multdiv_result = 1'sb0;
			assign multdiv_alu_operand_a = 1'sb0;
			assign multdiv_alu_operand_b = 1'sb0;
			assign multdiv_valid = 1'sb0;
			assign multdiv_imd_val_d = 68'b00000000000000000000000000000000000000000000000000000000000000000000;
			assign multdiv_imd_val_we = 1'sb0;
		end
	endgenerate
	assign ex_valid_o = (multdiv_sel ? multdiv_valid : ~(|alu_imd_val_we));
endmodule
module cve2_fetch_fifo (
	clk_i,
	rst_ni,
	clear_i,
	busy_o,
	in_valid_i,
	in_addr_i,
	in_rdata_i,
	in_err_i,
	out_valid_o,
	out_ready_i,
	out_addr_o,
	out_rdata_o,
	out_err_o,
	out_err_plus2_o
);
	reg _sv2v_0;
	parameter [31:0] NUM_REQS = 2;
	input wire clk_i;
	input wire rst_ni;
	input wire clear_i;
	output wire [NUM_REQS - 1:0] busy_o;
	input wire in_valid_i;
	input wire [31:0] in_addr_i;
	input wire [31:0] in_rdata_i;
	input wire in_err_i;
	output reg out_valid_o;
	input wire out_ready_i;
	output wire [31:0] out_addr_o;
	output reg [31:0] out_rdata_o;
	output reg out_err_o;
	output reg out_err_plus2_o;
	localparam [31:0] DEPTH = NUM_REQS + 1;
	wire [(DEPTH * 32) - 1:0] rdata_d;
	reg [(DEPTH * 32) - 1:0] rdata_q;
	wire [DEPTH - 1:0] err_d;
	reg [DEPTH - 1:0] err_q;
	wire [DEPTH - 1:0] valid_d;
	reg [DEPTH - 1:0] valid_q;
	wire [DEPTH - 1:0] lowest_free_entry;
	wire [DEPTH - 1:0] valid_pushed;
	wire [DEPTH - 1:0] valid_popped;
	wire [DEPTH - 1:0] entry_en;
	wire pop_fifo;
	wire [31:0] rdata;
	wire [31:0] rdata_unaligned;
	wire err;
	wire err_unaligned;
	wire err_plus2;
	wire valid;
	wire valid_unaligned;
	wire aligned_is_compressed;
	wire unaligned_is_compressed;
	wire addr_incr_two;
	wire [31:1] instr_addr_next;
	wire [31:1] instr_addr_d;
	reg [31:1] instr_addr_q;
	wire instr_addr_en;
	wire unused_addr_in;
	assign rdata = (valid_q[0] ? rdata_q[0+:32] : in_rdata_i);
	assign err = (valid_q[0] ? err_q[0] : in_err_i);
	assign valid = valid_q[0] | in_valid_i;
	assign rdata_unaligned = (valid_q[1] ? {rdata_q[47-:16], rdata[31:16]} : {in_rdata_i[15:0], rdata[31:16]});
	assign err_unaligned = (valid_q[1] ? (err_q[1] & ~unaligned_is_compressed) | err_q[0] : (valid_q[0] & err_q[0]) | (in_err_i & (~valid_q[0] | ~unaligned_is_compressed)));
	assign err_plus2 = (valid_q[1] ? err_q[1] & ~err_q[0] : (in_err_i & valid_q[0]) & ~err_q[0]);
	assign valid_unaligned = (valid_q[1] ? 1'b1 : valid_q[0] & in_valid_i);
	assign unaligned_is_compressed = (rdata[17:16] != 2'b11) & ~err;
	assign aligned_is_compressed = (rdata[1:0] != 2'b11) & ~err;
	always @(*) begin
		if (_sv2v_0)
			;
		if (out_addr_o[1]) begin
			out_rdata_o = rdata_unaligned;
			out_err_o = err_unaligned;
			out_err_plus2_o = err_plus2;
			if (unaligned_is_compressed)
				out_valid_o = valid;
			else
				out_valid_o = valid_unaligned;
		end
		else begin
			out_rdata_o = rdata;
			out_err_o = err;
			out_err_plus2_o = 1'b0;
			out_valid_o = valid;
		end
	end
	assign instr_addr_en = clear_i | (out_ready_i & out_valid_o);
	assign addr_incr_two = (instr_addr_q[1] ? unaligned_is_compressed : aligned_is_compressed);
	assign instr_addr_next = instr_addr_q[31:1] + {29'd0, ~addr_incr_two, addr_incr_two};
	assign instr_addr_d = (clear_i ? in_addr_i[31:1] : instr_addr_next);
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			instr_addr_q <= 1'sb0;
		else if (instr_addr_en)
			instr_addr_q <= instr_addr_d;
	assign out_addr_o = {instr_addr_q, 1'b0};
	assign unused_addr_in = in_addr_i[0];
	assign busy_o = valid_q[DEPTH - 1:DEPTH - NUM_REQS];
	assign pop_fifo = (out_ready_i & out_valid_o) & (~aligned_is_compressed | out_addr_o[1]);
	genvar _gv_i_28;
	generate
		for (_gv_i_28 = 0; _gv_i_28 < (DEPTH - 1); _gv_i_28 = _gv_i_28 + 1) begin : g_fifo_next
			localparam i = _gv_i_28;
			if (i == 0) begin : g_ent0
				assign lowest_free_entry[i] = ~valid_q[i];
			end
			else begin : g_ent_others
				assign lowest_free_entry[i] = ~valid_q[i] & valid_q[i - 1];
			end
			assign valid_pushed[i] = (in_valid_i & lowest_free_entry[i]) | valid_q[i];
			assign valid_popped[i] = (pop_fifo ? valid_pushed[i + 1] : valid_pushed[i]);
			assign valid_d[i] = valid_popped[i] & ~clear_i;
			assign entry_en[i] = (valid_pushed[i + 1] & pop_fifo) | ((in_valid_i & lowest_free_entry[i]) & ~pop_fifo);
			assign rdata_d[i * 32+:32] = (valid_q[i + 1] ? rdata_q[(i + 1) * 32+:32] : in_rdata_i);
			assign err_d[i] = (valid_q[i + 1] ? err_q[i + 1] : in_err_i);
		end
	endgenerate
	assign lowest_free_entry[DEPTH - 1] = ~valid_q[DEPTH - 1] & valid_q[DEPTH - 2];
	assign valid_pushed[DEPTH - 1] = valid_q[DEPTH - 1] | (in_valid_i & lowest_free_entry[DEPTH - 1]);
	assign valid_popped[DEPTH - 1] = (pop_fifo ? 1'b0 : valid_pushed[DEPTH - 1]);
	assign valid_d[DEPTH - 1] = valid_popped[DEPTH - 1] & ~clear_i;
	assign entry_en[DEPTH - 1] = in_valid_i & lowest_free_entry[DEPTH - 1];
	assign rdata_d[(DEPTH - 1) * 32+:32] = in_rdata_i;
	assign err_d[DEPTH - 1] = in_err_i;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			valid_q <= 1'sb0;
		else
			valid_q <= valid_d;
	genvar _gv_i_29;
	generate
		for (_gv_i_29 = 0; _gv_i_29 < DEPTH; _gv_i_29 = _gv_i_29 + 1) begin : g_fifo_regs
			localparam i = _gv_i_29;
			always @(posedge clk_i or negedge rst_ni)
				if (!rst_ni) begin
					rdata_q[i * 32+:32] <= 1'sb0;
					err_q[i] <= 1'sb0;
				end
				else if (entry_en[i]) begin
					rdata_q[i * 32+:32] <= rdata_d[i * 32+:32];
					err_q[i] <= err_d[i];
				end
		end
	endgenerate
	initial _sv2v_0 = 0;
endmodule
module cve2_id_stage (
	clk_i,
	rst_ni,
	fetch_enable_i,
	ctrl_busy_o,
	illegal_insn_o,
	instr_valid_i,
	instr_rdata_i,
	instr_rdata_alu_i,
	instr_rdata_c_i,
	instr_is_compressed_i,
	instr_req_o,
	instr_first_cycle_id_o,
	instr_valid_clear_o,
	id_in_ready_o,
	branch_decision_i,
	pc_set_o,
	pc_mux_o,
	exc_pc_mux_o,
	exc_cause_o,
	illegal_c_insn_i,
	instr_fetch_err_i,
	instr_fetch_err_plus2_i,
	pc_id_i,
	ex_valid_i,
	lsu_resp_valid_i,
	alu_operator_ex_o,
	alu_operand_a_ex_o,
	alu_operand_b_ex_o,
	imd_val_we_ex_i,
	imd_val_d_ex_i,
	imd_val_q_ex_o,
	mult_en_ex_o,
	div_en_ex_o,
	mult_sel_ex_o,
	div_sel_ex_o,
	multdiv_operator_ex_o,
	multdiv_signed_mode_ex_o,
	multdiv_operand_a_ex_o,
	multdiv_operand_b_ex_o,
	csr_access_o,
	csr_op_o,
	csr_op_en_o,
	csr_save_if_o,
	csr_save_id_o,
	csr_restore_mret_id_o,
	csr_restore_dret_id_o,
	csr_save_cause_o,
	csr_mtval_o,
	priv_mode_i,
	csr_mstatus_tw_i,
	illegal_csr_insn_i,
	lsu_req_o,
	lsu_we_o,
	lsu_type_o,
	lsu_sign_ext_o,
	lsu_wdata_o,
	lsu_addr_incr_req_i,
	lsu_addr_last_i,
	hart_id_i,
	x_issue_valid_o,
	x_issue_ready_i,
	x_issue_req_o,
	x_issue_resp_i,
	x_register_o,
	x_commit_valid_o,
	x_commit_o,
	x_result_valid_i,
	x_result_ready_o,
	x_result_i,
	csr_mstatus_mie_i,
	irq_pending_i,
	irqs_i,
	irq_nm_i,
	nmi_mode_o,
	lsu_load_err_i,
	lsu_store_err_i,
	debug_mode_o,
	debug_cause_o,
	debug_csr_save_o,
	debug_req_i,
	debug_single_step_i,
	debug_ebreakm_i,
	debug_ebreaku_i,
	trigger_match_i,
	result_ex_i,
	csr_rdata_i,
	rf_raddr_a_o,
	rf_rdata_a_i,
	rf_raddr_b_o,
	rf_rdata_b_i,
	rf_raddr_c_o,
	rf_rdata_c_i,
	rf_ren_a_o,
	rf_ren_b_o,
	rf_ren_c_o,
	rf_waddr_id_o,
	rf_wdata_id_o,
	rf_we_id_o,
	en_wb_o,
	instr_perf_count_id_o,
	perf_jump_o,
	perf_branch_o,
	perf_tbranch_o,
	perf_dside_wait_o,
	perf_wfi_wait_o,
	perf_div_wait_o,
	instr_id_done_o
);
	reg _sv2v_0;
	parameter [0:0] RV32E = 0;
	parameter integer RV32M = 32'sd2;
	parameter integer RV32B = 32'sd0;
	parameter [0:0] XInterface = 1'b0;
	input wire clk_i;
	input wire rst_ni;
	input wire fetch_enable_i;
	output wire ctrl_busy_o;
	output wire illegal_insn_o;
	input wire instr_valid_i;
	input wire [31:0] instr_rdata_i;
	input wire [31:0] instr_rdata_alu_i;
	input wire [15:0] instr_rdata_c_i;
	input wire instr_is_compressed_i;
	output wire instr_req_o;
	output wire instr_first_cycle_id_o;
	output wire instr_valid_clear_o;
	output wire id_in_ready_o;
	input wire branch_decision_i;
	output wire pc_set_o;
	output wire [2:0] pc_mux_o;
	output wire [1:0] exc_pc_mux_o;
	output wire [6:0] exc_cause_o;
	input wire illegal_c_insn_i;
	input wire instr_fetch_err_i;
	input wire instr_fetch_err_plus2_i;
	input wire [31:0] pc_id_i;
	input wire ex_valid_i;
	input wire lsu_resp_valid_i;
	output wire [6:0] alu_operator_ex_o;
	output wire [31:0] alu_operand_a_ex_o;
	output wire [31:0] alu_operand_b_ex_o;
	input wire [1:0] imd_val_we_ex_i;
	input wire [67:0] imd_val_d_ex_i;
	output wire [67:0] imd_val_q_ex_o;
	output wire mult_en_ex_o;
	output wire div_en_ex_o;
	output wire mult_sel_ex_o;
	output wire div_sel_ex_o;
	output wire [1:0] multdiv_operator_ex_o;
	output wire [1:0] multdiv_signed_mode_ex_o;
	output wire [31:0] multdiv_operand_a_ex_o;
	output wire [31:0] multdiv_operand_b_ex_o;
	output wire csr_access_o;
	output wire [1:0] csr_op_o;
	output wire csr_op_en_o;
	output wire csr_save_if_o;
	output wire csr_save_id_o;
	output wire csr_restore_mret_id_o;
	output wire csr_restore_dret_id_o;
	output wire csr_save_cause_o;
	output wire [31:0] csr_mtval_o;
	input wire [1:0] priv_mode_i;
	input wire csr_mstatus_tw_i;
	input wire illegal_csr_insn_i;
	output wire lsu_req_o;
	output wire lsu_we_o;
	output wire [1:0] lsu_type_o;
	output wire lsu_sign_ext_o;
	output wire [31:0] lsu_wdata_o;
	input wire lsu_addr_incr_req_i;
	input wire [31:0] lsu_addr_last_i;
	input wire [31:0] hart_id_i;
	output wire x_issue_valid_o;
	input wire x_issue_ready_i;
	localparam [31:0] cve2_pkg_X_HARTID_WIDTH = 32;
	localparam [31:0] cve2_pkg_X_ID_WIDTH = 4;
	output wire [67:0] x_issue_req_o;
	localparam [31:0] cve2_pkg_X_DUAL_READ = 0;
	localparam [31:0] cve2_pkg_X_NUM_RS = 3;
	localparam [31:0] cve2_pkg_X_DUAL_WRITE = 0;
	input wire [(2 + (cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ)) - 1:0] x_issue_resp_i;
	localparam [31:0] cve2_pkg_X_RFR_WIDTH = 32;
	output wire [(((cve2_pkg_X_HARTID_WIDTH + cve2_pkg_X_ID_WIDTH) + (cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH)) + (cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ)) - 1:0] x_register_o;
	output wire x_commit_valid_o;
	output wire [(cve2_pkg_X_HARTID_WIDTH + cve2_pkg_X_ID_WIDTH) + 0:0] x_commit_o;
	input wire x_result_valid_i;
	output wire x_result_ready_o;
	localparam [31:0] cve2_pkg_X_RFW_WIDTH = 32;
	input wire [((cve2_pkg_X_HARTID_WIDTH + cve2_pkg_X_ID_WIDTH) + cve2_pkg_X_RFW_WIDTH) + 5:0] x_result_i;
	input wire csr_mstatus_mie_i;
	input wire irq_pending_i;
	input wire [18:0] irqs_i;
	input wire irq_nm_i;
	output wire nmi_mode_o;
	input wire lsu_load_err_i;
	input wire lsu_store_err_i;
	output wire debug_mode_o;
	output wire [2:0] debug_cause_o;
	output wire debug_csr_save_o;
	input wire debug_req_i;
	input wire debug_single_step_i;
	input wire debug_ebreakm_i;
	input wire debug_ebreaku_i;
	input wire trigger_match_i;
	input wire [31:0] result_ex_i;
	input wire [31:0] csr_rdata_i;
	output wire [4:0] rf_raddr_a_o;
	input wire [31:0] rf_rdata_a_i;
	output wire [4:0] rf_raddr_b_o;
	input wire [31:0] rf_rdata_b_i;
	output wire [4:0] rf_raddr_c_o;
	input wire [31:0] rf_rdata_c_i;
	output wire rf_ren_a_o;
	output wire rf_ren_b_o;
	output wire rf_ren_c_o;
	output reg [4:0] rf_waddr_id_o;
	output reg [31:0] rf_wdata_id_o;
	output wire rf_we_id_o;
	output wire en_wb_o;
	output wire instr_perf_count_id_o;
	output wire perf_jump_o;
	output reg perf_branch_o;
	output wire perf_tbranch_o;
	output wire perf_dside_wait_o;
	output wire perf_wfi_wait_o;
	output wire perf_div_wait_o;
	output wire instr_id_done_o;
	wire illegal_insn_dec;
	wire ebrk_insn;
	wire mret_insn_dec;
	wire dret_insn_dec;
	wire ecall_insn_dec;
	wire wfi_insn_dec;
	wire branch_in_dec;
	wire branch_set;
	wire branch_set_raw;
	reg branch_set_raw_d;
	reg branch_jump_set_done_q;
	wire branch_jump_set_done_d;
	wire jump_in_dec;
	wire jump_set_dec;
	wire jump_set;
	reg jump_set_raw;
	wire instr_first_cycle;
	wire instr_executing_spec;
	wire instr_executing;
	wire instr_done;
	wire controller_run;
	wire stall_mem;
	reg stall_multdiv;
	reg stall_branch;
	reg stall_jump;
	wire stall_id;
	wire flush_id;
	wire multicycle_done;
	wire [31:0] imm_i_type;
	wire [31:0] imm_s_type;
	wire [31:0] imm_b_type;
	wire [31:0] imm_u_type;
	wire [31:0] imm_j_type;
	wire [31:0] zimm_rs1_type;
	wire [31:0] imm_a;
	reg [31:0] imm_b;
	wire [XInterface:0] rf_wdata_sel;
	wire rf_we_dec;
	reg rf_we_raw;
	wire rf_ren_a;
	wire rf_ren_b;
	wire rf_ren_c;
	wire rf_ren_a_dec;
	wire rf_ren_b_dec;
	wire rf_ren_c_dec;
	wire [4:0] rf_waddr_id;
	assign rf_ren_a = ((instr_valid_i & ~instr_fetch_err_i) & ~illegal_insn_o) & rf_ren_a_dec;
	assign rf_ren_b = ((instr_valid_i & ~instr_fetch_err_i) & ~illegal_insn_o) & rf_ren_b_dec;
	assign rf_ren_c = ((instr_valid_i & ~instr_fetch_err_i) & ~illegal_insn_o) & rf_ren_c_dec;
	assign rf_ren_a_o = rf_ren_a;
	assign rf_ren_b_o = rf_ren_b;
	assign rf_ren_c_o = (XInterface ? rf_ren_c : 1'b0);
	wire [31:0] rf_rdata_a_fwd;
	wire [31:0] rf_rdata_b_fwd;
	wire [31:0] rf_rdata_c_fwd;
	wire [6:0] alu_operator;
	wire [1:0] alu_op_a_mux_sel;
	wire [1:0] alu_op_a_mux_sel_dec;
	wire alu_op_b_mux_sel;
	wire alu_op_b_mux_sel_dec;
	wire alu_multicycle_dec;
	reg stall_alu;
	reg [67:0] imd_val_q;
	wire imm_a_mux_sel;
	wire [2:0] imm_b_mux_sel;
	wire [2:0] imm_b_mux_sel_dec;
	wire mult_en_id;
	wire mult_en_dec;
	wire div_en_id;
	wire div_en_dec;
	wire multdiv_en_dec;
	wire [1:0] multdiv_operator;
	wire [1:0] multdiv_signed_mode;
	wire lsu_we;
	wire [1:0] lsu_type;
	wire lsu_sign_ext;
	wire lsu_req;
	wire lsu_req_dec;
	wire data_req_allowed;
	reg csr_pipe_flush;
	reg [31:0] alu_operand_a;
	wire [31:0] alu_operand_b;
	reg stall_coproc;
	wire scoreboard_busy;
	reg id_fsm_q;
	reg id_fsm_d;
	always @(posedge clk_i or negedge rst_ni) begin : id_pipeline_reg
		if (!rst_ni)
			id_fsm_q <= 1'd0;
		else if (instr_executing)
			id_fsm_q <= id_fsm_d;
	end
	reg coproc_done;
	localparam [31:0] cve2_pkg_X_INSTR_INFLIGHT = 16;
	generate
		if (XInterface) begin : gen_xif
			reg [15:0] scoreboard_d;
			reg [15:0] scoreboard_q;
			reg [3:0] x_instr_id_d;
			reg [3:0] x_instr_id_q;
			wire scoreboard_free;
			assign scoreboard_free = ~scoreboard_q[x_instr_id_q];
			assign scoreboard_busy = scoreboard_q != {16 {1'sb0}};
			always @(*) begin
				if (_sv2v_0)
					;
				scoreboard_d = scoreboard_q;
				x_instr_id_d = x_instr_id_q;
				if ((x_issue_valid_o && x_issue_ready_i) && x_issue_resp_i[1 + ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) + 0)]) begin
					scoreboard_d[x_instr_id_q] = 1'b1;
					x_instr_id_d = x_instr_id_q + 1'b1;
				end
				if (x_result_valid_i)
					scoreboard_d[x_result_i[41-:4]] = 1'b0;
			end
			always @(posedge clk_i or negedge rst_ni) begin : x_scoreboard
				if (!rst_ni) begin
					scoreboard_q <= 1'sb0;
					x_instr_id_q <= 1'sb0;
				end
				else begin
					scoreboard_q <= scoreboard_d;
					x_instr_id_q <= x_instr_id_d;
				end
			end
			assign multicycle_done = (lsu_req_dec ? lsu_resp_valid_i : (illegal_insn_dec ? coproc_done : ex_valid_i));
			assign x_issue_valid_o = ((instr_executing & illegal_insn_dec) & (id_fsm_q == 1'd0)) & scoreboard_free;
			assign x_issue_req_o[67-:32] = instr_rdata_i;
			assign x_issue_req_o[3-:cve2_pkg_X_ID_WIDTH] = x_instr_id_q;
			assign x_issue_req_o[35-:32] = hart_id_i;
			assign x_register_o[((cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH) + ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) - 1)) - ((cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH) - 1)+:cve2_pkg_X_RFR_WIDTH] = rf_rdata_a_fwd;
			assign x_register_o[((cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH) + ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) - 1)) - (((cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH) - 1) - cve2_pkg_X_RFR_WIDTH)+:cve2_pkg_X_RFR_WIDTH] = rf_rdata_b_fwd;
			assign x_register_o[((cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH) + ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) - 1)) - ((cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH) - 65)+:cve2_pkg_X_RFR_WIDTH] = rf_rdata_c_fwd;
			assign x_register_o[(cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) - 1-:cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ] = 1'sb1;
			assign x_register_o[cve2_pkg_X_ID_WIDTH + ((cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH) + ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) - 1))-:((cve2_pkg_X_ID_WIDTH + ((cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH) + ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) - 1))) >= ((cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH) + ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) + 0)) ? ((cve2_pkg_X_ID_WIDTH + ((cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH) + ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) - 1))) - ((cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH) + ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) + 0))) + 1 : (((cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH) + ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) + 0)) - (cve2_pkg_X_ID_WIDTH + ((cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH) + ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) - 1)))) + 1)] = x_instr_id_q;
			assign x_register_o[cve2_pkg_X_HARTID_WIDTH + (cve2_pkg_X_ID_WIDTH + ((cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH) + ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) - 1)))-:(((32'd32 + 32'd4) + ((32'd3 * 32'd32) + ((32'd3 + 32'd0) - 1))) >= (32'd4 + ((32'd3 * 32'd32) + ((32'd3 + 32'd0) + 0))) ? ((cve2_pkg_X_HARTID_WIDTH + (cve2_pkg_X_ID_WIDTH + ((cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH) + ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) - 1)))) - (cve2_pkg_X_ID_WIDTH + ((cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH) + ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) + 0)))) + 1 : ((cve2_pkg_X_ID_WIDTH + ((cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH) + ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) + 0))) - (cve2_pkg_X_HARTID_WIDTH + (cve2_pkg_X_ID_WIDTH + ((cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH) + ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) - 1))))) + 1)] = hart_id_i;
			assign x_commit_valid_o = x_issue_valid_o & x_issue_ready_i;
			assign x_commit_o[0] = 1'b0;
			assign x_commit_o[4-:4] = x_instr_id_q;
			assign x_commit_o[36-:32] = hart_id_i;
			assign x_result_ready_o = 1'b1;
			assign illegal_insn_o = instr_valid_i & (illegal_csr_insn_i | ((x_issue_valid_o & x_issue_ready_i) & ~x_issue_resp_i[1 + ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) + 0)]));
		end
		else begin : no_gen_xif
			wire unused_x_issue_ready;
			wire [(2 + (cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ)) - 1:0] unused_x_issue_resp;
			wire unused_x_result_valid;
			wire [((cve2_pkg_X_HARTID_WIDTH + cve2_pkg_X_ID_WIDTH) + cve2_pkg_X_RFW_WIDTH) + 5:0] unused_x_result;
			wire unused_coproc_done;
			wire [31:0] unused_rf_rdata_c_fwd;
			assign unused_coproc_done = coproc_done;
			assign unused_rf_rdata_c_fwd = rf_rdata_c_fwd;
			assign multicycle_done = (lsu_req_dec ? lsu_resp_valid_i : ex_valid_i);
			assign scoreboard_busy = 1'b0;
			assign x_issue_valid_o = 1'b0;
			assign unused_x_issue_ready = x_issue_ready_i;
			assign x_issue_req_o = 1'sb0;
			assign unused_x_issue_resp = x_issue_resp_i;
			assign x_register_o = 1'sb0;
			assign x_commit_valid_o = 1'b0;
			assign x_commit_o = 1'sb0;
			assign x_result_ready_o = 1'b0;
			assign unused_x_result_valid = x_result_valid_i;
			assign unused_x_result = x_result_i;
			assign illegal_insn_o = instr_valid_i & (illegal_csr_insn_i | illegal_insn_dec);
		end
	endgenerate
	assign alu_op_a_mux_sel = (lsu_addr_incr_req_i ? 2'd1 : alu_op_a_mux_sel_dec);
	assign alu_op_b_mux_sel = (lsu_addr_incr_req_i ? 1'd1 : alu_op_b_mux_sel_dec);
	assign imm_b_mux_sel = (lsu_addr_incr_req_i ? 3'd6 : imm_b_mux_sel_dec);
	assign imm_a = (imm_a_mux_sel == 1'd0 ? zimm_rs1_type : {32 {1'sb0}});
	always @(*) begin : alu_operand_a_mux
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (alu_op_a_mux_sel)
			2'd0: alu_operand_a = rf_rdata_a_fwd;
			2'd1: alu_operand_a = lsu_addr_last_i;
			2'd2: alu_operand_a = pc_id_i;
			2'd3: alu_operand_a = imm_a;
			default: alu_operand_a = pc_id_i;
		endcase
	end
	wire [1:0] unused_a_mux_sel;
	wire [2:0] unused_b_mux_sel;
	always @(*) begin : immediate_b_mux
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (imm_b_mux_sel)
			3'd0: imm_b = imm_i_type;
			3'd1: imm_b = imm_s_type;
			3'd2: imm_b = imm_b_type;
			3'd3: imm_b = imm_u_type;
			3'd4: imm_b = imm_j_type;
			3'd5: imm_b = (instr_is_compressed_i ? 32'h00000002 : 32'h00000004);
			3'd6: imm_b = 32'h00000004;
			default: imm_b = 32'h00000004;
		endcase
	end
	assign alu_operand_b = (alu_op_b_mux_sel == 1'd1 ? imm_b : rf_rdata_b_fwd);
	genvar _gv_i_30;
	generate
		for (_gv_i_30 = 0; _gv_i_30 < 2; _gv_i_30 = _gv_i_30 + 1) begin : gen_intermediate_val_reg
			localparam i = _gv_i_30;
			always @(posedge clk_i or negedge rst_ni) begin : intermediate_val_reg
				if (!rst_ni)
					imd_val_q[(1 - i) * 34+:34] <= 1'sb0;
				else if (imd_val_we_ex_i[i])
					imd_val_q[(1 - i) * 34+:34] <= imd_val_d_ex_i[(1 - i) * 34+:34];
			end
		end
	endgenerate
	assign imd_val_q_ex_o = imd_val_q;
	assign rf_we_id_o = (rf_we_raw & instr_executing) & ~illegal_csr_insn_i;
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @(*) begin : rf_wdata_id_mux
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (sv2v_cast_32({rf_wdata_sel}))
			32'd0: rf_wdata_id_o = result_ex_i;
			32'd1: rf_wdata_id_o = csr_rdata_i;
			32'd2: rf_wdata_id_o = (XInterface ? x_result_i[37-:32] : result_ex_i);
			default: rf_wdata_id_o = result_ex_i;
		endcase
	end
	always @(*) begin : rf_waddr_id_mux
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (sv2v_cast_32({rf_wdata_sel}))
			32'd2: rf_waddr_id_o = (XInterface ? x_result_i[5-:5] : rf_waddr_id);
			default: rf_waddr_id_o = rf_waddr_id;
		endcase
	end
	cve2_decoder #(
		.RV32E(RV32E),
		.RV32M(RV32M),
		.RV32B(RV32B),
		.XInterface(XInterface)
	) decoder_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.illegal_insn_o(illegal_insn_dec),
		.ebrk_insn_o(ebrk_insn),
		.mret_insn_o(mret_insn_dec),
		.dret_insn_o(dret_insn_dec),
		.ecall_insn_o(ecall_insn_dec),
		.wfi_insn_o(wfi_insn_dec),
		.jump_set_o(jump_set_dec),
		.instr_first_cycle_i(instr_first_cycle),
		.instr_rdata_i(instr_rdata_i),
		.instr_rdata_alu_i(instr_rdata_alu_i),
		.illegal_c_insn_i(illegal_c_insn_i),
		.imm_a_mux_sel_o(imm_a_mux_sel),
		.imm_b_mux_sel_o(imm_b_mux_sel_dec),
		.imm_i_type_o(imm_i_type),
		.imm_s_type_o(imm_s_type),
		.imm_b_type_o(imm_b_type),
		.imm_u_type_o(imm_u_type),
		.imm_j_type_o(imm_j_type),
		.zimm_rs1_type_o(zimm_rs1_type),
		.rf_wdata_sel_o(rf_wdata_sel),
		.rf_we_o(rf_we_dec),
		.rf_raddr_a_o(rf_raddr_a_o),
		.rf_raddr_b_o(rf_raddr_b_o),
		.rf_raddr_c_o(rf_raddr_c_o),
		.rf_waddr_o(rf_waddr_id),
		.rf_ren_a_o(rf_ren_a_dec),
		.rf_ren_b_o(rf_ren_b_dec),
		.rf_ren_c_o(rf_ren_c_dec),
		.alu_operator_o(alu_operator),
		.alu_op_a_mux_sel_o(alu_op_a_mux_sel_dec),
		.alu_op_b_mux_sel_o(alu_op_b_mux_sel_dec),
		.alu_multicycle_o(alu_multicycle_dec),
		.mult_en_o(mult_en_dec),
		.div_en_o(div_en_dec),
		.mult_sel_o(mult_sel_ex_o),
		.div_sel_o(div_sel_ex_o),
		.multdiv_operator_o(multdiv_operator),
		.multdiv_signed_mode_o(multdiv_signed_mode),
		.csr_access_o(csr_access_o),
		.csr_op_o(csr_op_o),
		.data_req_o(lsu_req_dec),
		.data_we_o(lsu_we),
		.data_type_o(lsu_type),
		.data_sign_extension_o(lsu_sign_ext),
		.x_issue_resp_register_read_i(x_issue_resp_i[(cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) - 1-:cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ]),
		.jump_in_dec_o(jump_in_dec),
		.branch_in_dec_o(branch_in_dec)
	);
	always @(*) begin : csr_pipeline_flushes
		if (_sv2v_0)
			;
		csr_pipe_flush = 1'b0;
		if ((csr_op_en_o == 1'b1) && ((csr_op_o == 2'd1) || (csr_op_o == 2'd2))) begin
			if ((((instr_rdata_i[31:20] == 12'h300) || (instr_rdata_i[31:20] == 12'h304)) || (instr_rdata_i[31:20] == 12'h747)) || (instr_rdata_i[31:25] == 7'h1d))
				csr_pipe_flush = 1'b1;
		end
		else if ((csr_op_en_o == 1'b1) && (csr_op_o != 2'd0)) begin
			if ((((instr_rdata_i[31:20] == 12'h7b0) || (instr_rdata_i[31:20] == 12'h7b1)) || (instr_rdata_i[31:20] == 12'h7b2)) || (instr_rdata_i[31:20] == 12'h7b3))
				csr_pipe_flush = 1'b1;
		end
	end
	cve2_controller controller_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.fetch_enable_i(fetch_enable_i),
		.ctrl_busy_o(ctrl_busy_o),
		.illegal_insn_i(illegal_insn_o),
		.ecall_insn_i(ecall_insn_dec),
		.mret_insn_i(mret_insn_dec),
		.dret_insn_i(dret_insn_dec),
		.wfi_insn_i(wfi_insn_dec),
		.ebrk_insn_i(ebrk_insn),
		.csr_pipe_flush_i(csr_pipe_flush),
		.xif_scoreboard_busy_i(scoreboard_busy),
		.instr_valid_i(instr_valid_i),
		.instr_i(instr_rdata_i),
		.instr_compressed_i(instr_rdata_c_i),
		.instr_is_compressed_i(instr_is_compressed_i),
		.instr_fetch_err_i(instr_fetch_err_i),
		.instr_fetch_err_plus2_i(instr_fetch_err_plus2_i),
		.pc_id_i(pc_id_i),
		.instr_valid_clear_o(instr_valid_clear_o),
		.id_in_ready_o(id_in_ready_o),
		.controller_run_o(controller_run),
		.instr_req_o(instr_req_o),
		.pc_set_o(pc_set_o),
		.pc_mux_o(pc_mux_o),
		.exc_pc_mux_o(exc_pc_mux_o),
		.exc_cause_o(exc_cause_o),
		.lsu_addr_last_i(lsu_addr_last_i),
		.load_err_i(lsu_load_err_i),
		.store_err_i(lsu_store_err_i),
		.branch_set_i(branch_set),
		.jump_set_i(jump_set),
		.csr_mstatus_mie_i(csr_mstatus_mie_i),
		.irq_pending_i(irq_pending_i),
		.irqs_i(irqs_i),
		.irq_nm_i(irq_nm_i),
		.nmi_mode_o(nmi_mode_o),
		.csr_save_if_o(csr_save_if_o),
		.csr_save_id_o(csr_save_id_o),
		.csr_restore_mret_id_o(csr_restore_mret_id_o),
		.csr_restore_dret_id_o(csr_restore_dret_id_o),
		.csr_save_cause_o(csr_save_cause_o),
		.csr_mtval_o(csr_mtval_o),
		.priv_mode_i(priv_mode_i),
		.csr_mstatus_tw_i(csr_mstatus_tw_i),
		.debug_mode_o(debug_mode_o),
		.debug_cause_o(debug_cause_o),
		.debug_csr_save_o(debug_csr_save_o),
		.debug_req_i(debug_req_i),
		.debug_single_step_i(debug_single_step_i),
		.debug_ebreakm_i(debug_ebreakm_i),
		.debug_ebreaku_i(debug_ebreaku_i),
		.trigger_match_i(trigger_match_i),
		.stall_id_i(stall_id),
		.flush_id_o(flush_id),
		.perf_jump_o(perf_jump_o),
		.perf_tbranch_o(perf_tbranch_o)
	);
	assign multdiv_en_dec = mult_en_dec | div_en_dec;
	assign lsu_req = (instr_executing ? data_req_allowed & lsu_req_dec : 1'b0);
	assign mult_en_id = (instr_executing ? mult_en_dec : 1'b0);
	assign div_en_id = (instr_executing ? div_en_dec : 1'b0);
	assign lsu_req_o = lsu_req;
	assign lsu_we_o = lsu_we;
	assign lsu_type_o = lsu_type;
	assign lsu_sign_ext_o = lsu_sign_ext;
	assign lsu_wdata_o = rf_rdata_b_fwd;
	assign csr_op_en_o = (csr_access_o & instr_executing) & instr_id_done_o;
	assign alu_operator_ex_o = alu_operator;
	assign alu_operand_a_ex_o = alu_operand_a;
	assign alu_operand_b_ex_o = alu_operand_b;
	assign mult_en_ex_o = mult_en_id;
	assign div_en_ex_o = div_en_id;
	assign multdiv_operator_ex_o = multdiv_operator;
	assign multdiv_signed_mode_ex_o = multdiv_signed_mode;
	assign multdiv_operand_a_ex_o = rf_rdata_a_fwd;
	assign multdiv_operand_b_ex_o = rf_rdata_b_fwd;
	reg branch_set_raw_q;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			branch_set_raw_q <= 1'b0;
		else
			branch_set_raw_q <= branch_set_raw_d;
	assign branch_set_raw = branch_set_raw_q;
	assign branch_jump_set_done_d = ((branch_set_raw | jump_set_raw) | branch_jump_set_done_q) & ~instr_valid_clear_o;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			branch_jump_set_done_q <= 1'b0;
		else
			branch_jump_set_done_q <= branch_jump_set_done_d;
	assign jump_set = jump_set_raw & ~branch_jump_set_done_q;
	assign branch_set = branch_set_raw & ~branch_jump_set_done_q;
	always @(*) begin
		if (_sv2v_0)
			;
		id_fsm_d = id_fsm_q;
		rf_we_raw = rf_we_dec;
		stall_multdiv = 1'b0;
		stall_jump = 1'b0;
		stall_branch = 1'b0;
		stall_alu = 1'b0;
		stall_coproc = 1'b0;
		branch_set_raw_d = 1'b0;
		jump_set_raw = 1'b0;
		perf_branch_o = 1'b0;
		coproc_done = 1'b1;
		if (instr_executing_spec)
			(* full_case, parallel_case *)
			case (id_fsm_q)
				1'd0:
					(* full_case, parallel_case *)
					case (1'b1)
						lsu_req_dec: id_fsm_d = 1'd1;
						multdiv_en_dec:
							if (~ex_valid_i) begin
								id_fsm_d = 1'd1;
								rf_we_raw = 1'b0;
								stall_multdiv = 1'b1;
							end
						branch_in_dec: begin
							id_fsm_d = (branch_decision_i ? 1'd1 : 1'd0);
							stall_branch = branch_decision_i;
							branch_set_raw_d = branch_decision_i;
							perf_branch_o = 1'b1;
						end
						jump_in_dec: begin
							id_fsm_d = 1'd1;
							stall_jump = 1'b1;
							jump_set_raw = jump_set_dec;
						end
						alu_multicycle_dec: begin
							stall_alu = 1'b1;
							id_fsm_d = 1'd1;
							rf_we_raw = 1'b0;
						end
						illegal_insn_dec:
							if (XInterface) begin
								if (x_issue_valid_o && x_issue_ready_i) begin
									if (x_issue_resp_i[1 + ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) + 0)] && x_issue_resp_i[(cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) + 0-:(((32'd3 + 32'd0) + 0) >= ((32'd3 + 32'd0) + 0) ? (((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) + 0) - ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) + 0)) + 1 : (((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) + 0) - ((cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ) + 0)) + 1)]) begin
										id_fsm_d = 1'd1;
										stall_coproc = 1'b1;
										coproc_done = 1'b0;
									end
									else
										id_fsm_d = 1'd0;
								end
								else begin
									stall_coproc = 1'b1;
									id_fsm_d = 1'd0;
								end
							end
							else
								id_fsm_d = 1'd0;
						default: id_fsm_d = 1'd0;
					endcase
				1'd1: begin
					if (multdiv_en_dec)
						rf_we_raw = rf_we_dec & ex_valid_i;
					if (illegal_insn_dec && XInterface) begin
						coproc_done = x_result_valid_i & x_result_i[0-:1];
						rf_we_raw = x_result_valid_i & x_result_i[0-:1];
					end
					if (multicycle_done)
						id_fsm_d = 1'd0;
					else begin
						stall_multdiv = multdiv_en_dec;
						stall_branch = branch_in_dec;
						stall_jump = jump_in_dec;
						stall_coproc = XInterface & illegal_insn_dec;
					end
				end
				default: id_fsm_d = 1'd0;
			endcase
	end
	assign stall_id = ((((stall_mem | stall_multdiv) | stall_jump) | stall_branch) | stall_alu) | (XInterface & stall_coproc);
	assign instr_done = (~stall_id & ~flush_id) & instr_executing;
	assign instr_first_cycle = instr_valid_i & (id_fsm_q == 1'd0);
	assign instr_first_cycle_id_o = instr_first_cycle;
	assign data_req_allowed = instr_first_cycle;
	assign stall_mem = instr_valid_i & (lsu_req_dec & (~lsu_resp_valid_i | instr_first_cycle));
	assign instr_executing_spec = (instr_valid_i & ~instr_fetch_err_i) & controller_run;
	assign instr_executing = instr_executing_spec;
	assign rf_rdata_a_fwd = rf_rdata_a_i;
	assign rf_rdata_b_fwd = rf_rdata_b_i;
	assign rf_rdata_c_fwd = rf_rdata_c_i;
	wire unused_data_req_done_ex;
	assign perf_dside_wait_o = (instr_executing & lsu_req_dec) & ~lsu_resp_valid_i;
	assign instr_id_done_o = instr_done;
	assign instr_perf_count_id_o = ((((~ebrk_insn & ~ecall_insn_dec) & ~illegal_insn_dec) & ~(dret_insn_dec & ~debug_mode_o)) & ~illegal_csr_insn_i) & ~instr_fetch_err_i;
	assign en_wb_o = instr_done;
	assign perf_wfi_wait_o = wfi_insn_dec;
	assign perf_div_wait_o = stall_multdiv & div_en_dec;
	initial _sv2v_0 = 0;
endmodule
module cve2_if_stage (
	clk_i,
	rst_ni,
	boot_addr_i,
	req_i,
	instr_req_o,
	instr_addr_o,
	instr_gnt_i,
	instr_rvalid_i,
	instr_rdata_i,
	instr_err_i,
	instr_valid_id_o,
	instr_new_id_o,
	instr_rdata_id_o,
	instr_rdata_alu_id_o,
	instr_rdata_c_id_o,
	instr_is_compressed_id_o,
	instr_fetch_err_o,
	instr_fetch_err_plus2_o,
	illegal_c_insn_id_o,
	pc_if_o,
	pc_id_o,
	pmp_err_if_i,
	pmp_err_if_plus2_i,
	instr_valid_clear_i,
	pc_set_i,
	pc_mux_i,
	exc_pc_mux_i,
	exc_cause,
	branch_target_ex_i,
	csr_mepc_i,
	csr_depc_i,
	csr_mtvec_i,
	csr_mtvec_init_o,
	dm_halt_addr_i,
	dm_exception_addr_i,
	id_in_ready_i,
	if_busy_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire [31:0] boot_addr_i;
	input wire req_i;
	output wire instr_req_o;
	output wire [31:0] instr_addr_o;
	input wire instr_gnt_i;
	input wire instr_rvalid_i;
	input wire [31:0] instr_rdata_i;
	input wire instr_err_i;
	output wire instr_valid_id_o;
	output wire instr_new_id_o;
	output reg [31:0] instr_rdata_id_o;
	output reg [31:0] instr_rdata_alu_id_o;
	output reg [15:0] instr_rdata_c_id_o;
	output reg instr_is_compressed_id_o;
	output reg instr_fetch_err_o;
	output reg instr_fetch_err_plus2_o;
	output reg illegal_c_insn_id_o;
	output wire [31:0] pc_if_o;
	output reg [31:0] pc_id_o;
	input wire pmp_err_if_i;
	input wire pmp_err_if_plus2_i;
	input wire instr_valid_clear_i;
	input wire pc_set_i;
	input wire [2:0] pc_mux_i;
	input wire [1:0] exc_pc_mux_i;
	input wire [6:0] exc_cause;
	input wire [31:0] branch_target_ex_i;
	input wire [31:0] csr_mepc_i;
	input wire [31:0] csr_depc_i;
	input wire [31:0] csr_mtvec_i;
	output wire csr_mtvec_init_o;
	input wire [31:0] dm_halt_addr_i;
	input wire [31:0] dm_exception_addr_i;
	input wire id_in_ready_i;
	output wire if_busy_o;
	wire instr_valid_id_d;
	reg instr_valid_id_q;
	wire instr_new_id_d;
	reg instr_new_id_q;
	wire prefetch_busy;
	wire branch_req;
	reg [31:0] fetch_addr_n;
	wire unused_fetch_addr_n0;
	wire fetch_valid;
	wire fetch_ready;
	wire [31:0] fetch_rdata;
	wire [31:0] fetch_addr;
	wire fetch_err;
	wire fetch_err_plus2;
	wire [31:0] instr_decompressed;
	wire illegal_c_insn;
	wire instr_is_compressed;
	wire if_instr_pmp_err;
	wire if_instr_err;
	wire if_instr_err_plus2;
	reg [31:0] exc_pc;
	wire [6:0] irq_id;
	wire unused_irq_bit;
	wire if_id_pipe_reg_we;
	wire [2:0] pc_mux_internal;
	wire [1:0] unused_boot_addr;
	wire [7:0] unused_csr_mtvec;
	assign unused_boot_addr = boot_addr_i[1:0];
	assign unused_csr_mtvec = csr_mtvec_i[7:0];
	assign irq_id = {exc_cause};
	assign unused_irq_bit = irq_id[6];
	always @(*) begin : exc_pc_mux
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (exc_pc_mux_i)
			2'd0: exc_pc = {csr_mtvec_i[31:8], 8'h00};
			2'd1: exc_pc = {csr_mtvec_i[31:8], irq_id[5:0], 2'b00};
			2'd2: exc_pc = dm_halt_addr_i;
			2'd3: exc_pc = dm_exception_addr_i;
			default: exc_pc = {csr_mtvec_i[31:8], 8'h00};
		endcase
	end
	assign pc_mux_internal = pc_mux_i;
	always @(*) begin : fetch_addr_mux
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (pc_mux_internal)
			3'd0: fetch_addr_n = {boot_addr_i[31:2], 2'b00};
			3'd1: fetch_addr_n = branch_target_ex_i;
			3'd2: fetch_addr_n = exc_pc;
			3'd3: fetch_addr_n = csr_mepc_i;
			3'd4: fetch_addr_n = csr_depc_i;
			default: fetch_addr_n = {boot_addr_i[31:2], 2'b00};
		endcase
	end
	assign csr_mtvec_init_o = (pc_mux_i == 3'd0) & pc_set_i;
	cve2_prefetch_buffer prefetch_buffer_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.req_i(req_i),
		.branch_i(branch_req),
		.addr_i({fetch_addr_n[31:1], 1'b0}),
		.ready_i(fetch_ready),
		.valid_o(fetch_valid),
		.rdata_o(fetch_rdata),
		.addr_o(fetch_addr),
		.err_o(fetch_err),
		.err_plus2_o(fetch_err_plus2),
		.instr_req_o(instr_req_o),
		.instr_addr_o(instr_addr_o),
		.instr_gnt_i(instr_gnt_i),
		.instr_rvalid_i(instr_rvalid_i),
		.instr_rdata_i(instr_rdata_i),
		.instr_err_i(instr_err_i),
		.busy_o(prefetch_busy)
	);
	assign unused_fetch_addr_n0 = fetch_addr_n[0];
	assign branch_req = pc_set_i;
	assign pc_if_o = fetch_addr;
	assign if_busy_o = prefetch_busy;
	assign if_instr_pmp_err = pmp_err_if_i | ((fetch_addr[2] & ~instr_is_compressed) & pmp_err_if_plus2_i);
	assign if_instr_err = fetch_err | if_instr_pmp_err;
	assign if_instr_err_plus2 = (((fetch_addr[2] & ~instr_is_compressed) & pmp_err_if_plus2_i) | fetch_err_plus2) & ~pmp_err_if_i;
	cve2_compressed_decoder compressed_decoder_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.valid_i(fetch_valid & ~fetch_err),
		.instr_i(fetch_rdata),
		.instr_o(instr_decompressed),
		.is_compressed_o(instr_is_compressed),
		.illegal_instr_o(illegal_c_insn)
	);
	assign instr_valid_id_d = ((fetch_valid & id_in_ready_i) & ~pc_set_i) | (instr_valid_id_q & ~instr_valid_clear_i);
	assign instr_new_id_d = fetch_valid & id_in_ready_i;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			instr_valid_id_q <= 1'b0;
			instr_new_id_q <= 1'b0;
		end
		else begin
			instr_valid_id_q <= instr_valid_id_d;
			instr_new_id_q <= instr_new_id_d;
		end
	assign instr_valid_id_o = instr_valid_id_q;
	assign instr_new_id_o = instr_new_id_q;
	assign if_id_pipe_reg_we = instr_new_id_d;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			instr_rdata_id_o <= 1'sb0;
			instr_rdata_alu_id_o <= 1'sb0;
			instr_fetch_err_o <= 1'sb0;
			instr_fetch_err_plus2_o <= 1'sb0;
			instr_rdata_c_id_o <= 1'sb0;
			instr_is_compressed_id_o <= 1'sb0;
			illegal_c_insn_id_o <= 1'sb0;
			pc_id_o <= 1'sb0;
		end
		else if (if_id_pipe_reg_we) begin
			instr_rdata_id_o <= instr_decompressed;
			instr_rdata_alu_id_o <= instr_decompressed;
			instr_fetch_err_o <= if_instr_err;
			instr_fetch_err_plus2_o <= if_instr_err_plus2;
			instr_rdata_c_id_o <= fetch_rdata[15:0];
			instr_is_compressed_id_o <= instr_is_compressed;
			illegal_c_insn_id_o <= illegal_c_insn;
			pc_id_o <= pc_if_o;
		end
	assign fetch_ready = id_in_ready_i;
	initial _sv2v_0 = 0;
endmodule
module cve2_load_store_unit (
	clk_i,
	rst_ni,
	data_req_o,
	data_gnt_i,
	data_rvalid_i,
	data_err_i,
	data_pmp_err_i,
	data_addr_o,
	data_we_o,
	data_be_o,
	data_wdata_o,
	data_rdata_i,
	lsu_we_i,
	lsu_type_i,
	lsu_wdata_i,
	lsu_sign_ext_i,
	lsu_rdata_o,
	lsu_rdata_valid_o,
	lsu_req_i,
	adder_result_ex_i,
	addr_incr_req_o,
	addr_last_o,
	lsu_resp_valid_o,
	load_err_o,
	store_err_o,
	busy_o,
	perf_load_o,
	perf_store_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	output reg data_req_o;
	input wire data_gnt_i;
	input wire data_rvalid_i;
	input wire data_err_i;
	input wire data_pmp_err_i;
	output wire [31:0] data_addr_o;
	output wire data_we_o;
	output wire [3:0] data_be_o;
	output wire [31:0] data_wdata_o;
	input wire [31:0] data_rdata_i;
	input wire lsu_we_i;
	input wire [1:0] lsu_type_i;
	input wire [31:0] lsu_wdata_i;
	input wire lsu_sign_ext_i;
	output wire [31:0] lsu_rdata_o;
	output wire lsu_rdata_valid_o;
	input wire lsu_req_i;
	input wire [31:0] adder_result_ex_i;
	output reg addr_incr_req_o;
	output wire [31:0] addr_last_o;
	output wire lsu_resp_valid_o;
	output wire load_err_o;
	output wire store_err_o;
	output wire busy_o;
	output reg perf_load_o;
	output reg perf_store_o;
	wire [31:0] data_addr;
	wire [31:0] data_addr_w_aligned;
	reg [31:0] addr_last_q;
	wire [31:0] addr_last_d;
	reg addr_update;
	reg ctrl_update;
	reg rdata_update;
	reg [31:8] rdata_q;
	reg [1:0] rdata_offset_q;
	reg [1:0] data_type_q;
	reg data_sign_ext_q;
	reg data_we_q;
	wire [1:0] data_offset;
	reg [3:0] data_be;
	reg [31:0] data_wdata;
	reg [31:0] data_rdata_ext;
	reg [31:0] rdata_w_ext;
	reg [31:0] rdata_h_ext;
	reg [31:0] rdata_b_ext;
	wire split_misaligned_access;
	reg handle_misaligned_q;
	reg handle_misaligned_d;
	reg pmp_err_q;
	reg pmp_err_d;
	reg lsu_err_q;
	reg lsu_err_d;
	wire data_or_pmp_err;
	reg [2:0] ls_fsm_cs;
	reg [2:0] ls_fsm_ns;
	assign data_addr = adder_result_ex_i;
	assign data_offset = data_addr[1:0];
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (lsu_type_i)
			2'b00:
				if (!handle_misaligned_q)
					(* full_case, parallel_case *)
					case (data_offset)
						2'b00: data_be = 4'b1111;
						2'b01: data_be = 4'b1110;
						2'b10: data_be = 4'b1100;
						2'b11: data_be = 4'b1000;
						default: data_be = 4'b1111;
					endcase
				else
					(* full_case, parallel_case *)
					case (data_offset)
						2'b00: data_be = 4'b0000;
						2'b01: data_be = 4'b0001;
						2'b10: data_be = 4'b0011;
						2'b11: data_be = 4'b0111;
						default: data_be = 4'b1111;
					endcase
			2'b01:
				if (!handle_misaligned_q)
					(* full_case, parallel_case *)
					case (data_offset)
						2'b00: data_be = 4'b0011;
						2'b01: data_be = 4'b0110;
						2'b10: data_be = 4'b1100;
						2'b11: data_be = 4'b1000;
						default: data_be = 4'b1111;
					endcase
				else
					data_be = 4'b0001;
			2'b10, 2'b11:
				(* full_case, parallel_case *)
				case (data_offset)
					2'b00: data_be = 4'b0001;
					2'b01: data_be = 4'b0010;
					2'b10: data_be = 4'b0100;
					2'b11: data_be = 4'b1000;
					default: data_be = 4'b1111;
				endcase
			default: data_be = 4'b1111;
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (data_offset)
			2'b00: data_wdata = lsu_wdata_i[31:0];
			2'b01: data_wdata = {lsu_wdata_i[23:0], lsu_wdata_i[31:24]};
			2'b10: data_wdata = {lsu_wdata_i[15:0], lsu_wdata_i[31:16]};
			2'b11: data_wdata = {lsu_wdata_i[7:0], lsu_wdata_i[31:8]};
			default: data_wdata = lsu_wdata_i[31:0];
		endcase
	end
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			rdata_q <= 1'sb0;
		else if (rdata_update)
			rdata_q <= data_rdata_i[31:8];
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			rdata_offset_q <= 2'h0;
			data_type_q <= 2'h0;
			data_sign_ext_q <= 1'b0;
			data_we_q <= 1'b0;
		end
		else if (ctrl_update) begin
			rdata_offset_q <= data_offset;
			data_type_q <= lsu_type_i;
			data_sign_ext_q <= lsu_sign_ext_i;
			data_we_q <= lsu_we_i;
		end
	assign addr_last_d = (addr_incr_req_o ? data_addr_w_aligned : data_addr);
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			addr_last_q <= 1'sb0;
		else if (addr_update)
			addr_last_q <= addr_last_d;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (rdata_offset_q)
			2'b00: rdata_w_ext = data_rdata_i[31:0];
			2'b01: rdata_w_ext = {data_rdata_i[7:0], rdata_q[31:8]};
			2'b10: rdata_w_ext = {data_rdata_i[15:0], rdata_q[31:16]};
			2'b11: rdata_w_ext = {data_rdata_i[23:0], rdata_q[31:24]};
			default: rdata_w_ext = data_rdata_i[31:0];
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (rdata_offset_q)
			2'b00:
				if (!data_sign_ext_q)
					rdata_h_ext = {16'h0000, data_rdata_i[15:0]};
				else
					rdata_h_ext = {{16 {data_rdata_i[15]}}, data_rdata_i[15:0]};
			2'b01:
				if (!data_sign_ext_q)
					rdata_h_ext = {16'h0000, data_rdata_i[23:8]};
				else
					rdata_h_ext = {{16 {data_rdata_i[23]}}, data_rdata_i[23:8]};
			2'b10:
				if (!data_sign_ext_q)
					rdata_h_ext = {16'h0000, data_rdata_i[31:16]};
				else
					rdata_h_ext = {{16 {data_rdata_i[31]}}, data_rdata_i[31:16]};
			2'b11:
				if (!data_sign_ext_q)
					rdata_h_ext = {16'h0000, data_rdata_i[7:0], rdata_q[31:24]};
				else
					rdata_h_ext = {{16 {data_rdata_i[7]}}, data_rdata_i[7:0], rdata_q[31:24]};
			default: rdata_h_ext = {16'h0000, data_rdata_i[15:0]};
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (rdata_offset_q)
			2'b00:
				if (!data_sign_ext_q)
					rdata_b_ext = {24'h000000, data_rdata_i[7:0]};
				else
					rdata_b_ext = {{24 {data_rdata_i[7]}}, data_rdata_i[7:0]};
			2'b01:
				if (!data_sign_ext_q)
					rdata_b_ext = {24'h000000, data_rdata_i[15:8]};
				else
					rdata_b_ext = {{24 {data_rdata_i[15]}}, data_rdata_i[15:8]};
			2'b10:
				if (!data_sign_ext_q)
					rdata_b_ext = {24'h000000, data_rdata_i[23:16]};
				else
					rdata_b_ext = {{24 {data_rdata_i[23]}}, data_rdata_i[23:16]};
			2'b11:
				if (!data_sign_ext_q)
					rdata_b_ext = {24'h000000, data_rdata_i[31:24]};
				else
					rdata_b_ext = {{24 {data_rdata_i[31]}}, data_rdata_i[31:24]};
			default: rdata_b_ext = {24'h000000, data_rdata_i[7:0]};
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (data_type_q)
			2'b00: data_rdata_ext = rdata_w_ext;
			2'b01: data_rdata_ext = rdata_h_ext;
			2'b10, 2'b11: data_rdata_ext = rdata_b_ext;
			default: data_rdata_ext = rdata_w_ext;
		endcase
	end
	assign split_misaligned_access = ((lsu_type_i == 2'b00) && (data_offset != 2'b00)) || ((lsu_type_i == 2'b01) && (data_offset == 2'b11));
	always @(*) begin
		if (_sv2v_0)
			;
		ls_fsm_ns = ls_fsm_cs;
		data_req_o = 1'b0;
		addr_incr_req_o = 1'b0;
		handle_misaligned_d = handle_misaligned_q;
		pmp_err_d = pmp_err_q;
		lsu_err_d = lsu_err_q;
		addr_update = 1'b0;
		ctrl_update = 1'b0;
		rdata_update = 1'b0;
		perf_load_o = 1'b0;
		perf_store_o = 1'b0;
		(* full_case, parallel_case *)
		case (ls_fsm_cs)
			3'd0: begin
				pmp_err_d = 1'b0;
				if (lsu_req_i) begin
					data_req_o = 1'b1;
					pmp_err_d = data_pmp_err_i;
					lsu_err_d = 1'b0;
					perf_load_o = ~lsu_we_i;
					perf_store_o = lsu_we_i;
					if (data_gnt_i) begin
						ctrl_update = 1'b1;
						addr_update = 1'b1;
						handle_misaligned_d = split_misaligned_access;
						ls_fsm_ns = (split_misaligned_access ? 3'd2 : 3'd0);
					end
					else
						ls_fsm_ns = (split_misaligned_access ? 3'd1 : 3'd3);
				end
			end
			3'd1: begin
				data_req_o = 1'b1;
				if (data_gnt_i || pmp_err_q) begin
					addr_update = 1'b1;
					ctrl_update = 1'b1;
					handle_misaligned_d = 1'b1;
					ls_fsm_ns = 3'd2;
				end
			end
			3'd2: begin
				data_req_o = 1'b1;
				addr_incr_req_o = 1'b1;
				if (data_rvalid_i || pmp_err_q) begin
					pmp_err_d = data_pmp_err_i;
					lsu_err_d = data_err_i | pmp_err_q;
					rdata_update = ~data_we_q;
					ls_fsm_ns = (data_gnt_i ? 3'd0 : 3'd3);
					addr_update = data_gnt_i & ~(data_err_i | pmp_err_q);
					handle_misaligned_d = ~data_gnt_i;
				end
				else if (data_gnt_i) begin
					ls_fsm_ns = 3'd4;
					handle_misaligned_d = 1'b0;
				end
			end
			3'd3: begin
				addr_incr_req_o = handle_misaligned_q;
				data_req_o = 1'b1;
				if (data_gnt_i || pmp_err_q) begin
					ctrl_update = 1'b1;
					addr_update = ~lsu_err_q;
					ls_fsm_ns = 3'd0;
					handle_misaligned_d = 1'b0;
				end
			end
			3'd4: begin
				addr_incr_req_o = 1'b1;
				if (data_rvalid_i) begin
					pmp_err_d = data_pmp_err_i;
					lsu_err_d = data_err_i;
					addr_update = ~data_err_i;
					rdata_update = ~data_we_q;
					ls_fsm_ns = 3'd0;
				end
			end
			default: ls_fsm_ns = 3'd0;
		endcase
	end
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			ls_fsm_cs <= 3'd0;
			handle_misaligned_q <= 1'sb0;
			pmp_err_q <= 1'sb0;
			lsu_err_q <= 1'sb0;
		end
		else begin
			ls_fsm_cs <= ls_fsm_ns;
			handle_misaligned_q <= handle_misaligned_d;
			pmp_err_q <= pmp_err_d;
			lsu_err_q <= lsu_err_d;
		end
	assign data_or_pmp_err = (lsu_err_q | data_err_i) | pmp_err_q;
	assign lsu_resp_valid_o = (data_rvalid_i | pmp_err_q) & (ls_fsm_cs == 3'd0);
	assign lsu_rdata_valid_o = (((ls_fsm_cs == 3'd0) & data_rvalid_i) & ~data_or_pmp_err) & ~data_we_q;
	assign lsu_rdata_o = data_rdata_ext;
	assign data_addr_w_aligned = {data_addr[31:2], 2'b00};
	assign data_addr_o = data_addr_w_aligned;
	assign data_wdata_o = data_wdata;
	assign data_we_o = lsu_we_i;
	assign data_be_o = data_be;
	assign addr_last_o = addr_last_q;
	assign load_err_o = (data_or_pmp_err & ~data_we_q) & lsu_resp_valid_o;
	assign store_err_o = (data_or_pmp_err & data_we_q) & lsu_resp_valid_o;
	assign busy_o = ls_fsm_cs != 3'd0;
	initial _sv2v_0 = 0;
endmodule
module cve2_multdiv_fast (
	clk_i,
	rst_ni,
	mult_en_i,
	div_en_i,
	mult_sel_i,
	div_sel_i,
	operator_i,
	signed_mode_i,
	op_a_i,
	op_b_i,
	alu_adder_ext_i,
	alu_adder_i,
	equal_to_zero_i,
	alu_operand_a_o,
	alu_operand_b_o,
	imd_val_q_i,
	imd_val_d_o,
	imd_val_we_o,
	multdiv_result_o,
	valid_o
);
	reg _sv2v_0;
	parameter integer RV32M = 32'sd2;
	input wire clk_i;
	input wire rst_ni;
	input wire mult_en_i;
	input wire div_en_i;
	input wire mult_sel_i;
	input wire div_sel_i;
	input wire [1:0] operator_i;
	input wire [1:0] signed_mode_i;
	input wire [31:0] op_a_i;
	input wire [31:0] op_b_i;
	input wire [33:0] alu_adder_ext_i;
	input wire [31:0] alu_adder_i;
	input wire equal_to_zero_i;
	output reg [32:0] alu_operand_a_o;
	output reg [32:0] alu_operand_b_o;
	input wire [67:0] imd_val_q_i;
	output wire [67:0] imd_val_d_o;
	output wire [1:0] imd_val_we_o;
	output wire [31:0] multdiv_result_o;
	output wire valid_o;
	wire signed [34:0] mac_res_signed;
	wire [34:0] mac_res_ext;
	reg [33:0] accum;
	reg sign_a;
	reg sign_b;
	reg mult_valid;
	wire signed_mult;
	reg [33:0] mac_res_d;
	reg [33:0] op_remainder_d;
	wire [33:0] mac_res;
	wire div_sign_a;
	wire div_sign_b;
	reg is_greater_equal;
	wire div_change_sign;
	wire rem_change_sign;
	wire [31:0] one_shift;
	wire [31:0] op_denominator_q;
	reg [31:0] op_numerator_q;
	reg [31:0] op_quotient_q;
	reg [31:0] op_denominator_d;
	reg [31:0] op_numerator_d;
	reg [31:0] op_quotient_d;
	wire [31:0] next_remainder;
	wire [32:0] next_quotient;
	wire [31:0] res_adder_h;
	reg div_valid;
	reg [4:0] div_counter_q;
	reg [4:0] div_counter_d;
	wire multdiv_en;
	reg mult_hold;
	reg div_hold;
	reg div_by_zero_d;
	reg div_by_zero_q;
	wire mult_en_internal;
	wire div_en_internal;
	reg [2:0] md_state_q;
	reg [2:0] md_state_d;
	wire unused_mult_sel_i;
	assign unused_mult_sel_i = mult_sel_i;
	assign mult_en_internal = mult_en_i & ~mult_hold;
	assign div_en_internal = div_en_i & ~div_hold;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			div_counter_q <= 1'sb0;
			md_state_q <= 3'd0;
			op_numerator_q <= 1'sb0;
			op_quotient_q <= 1'sb0;
			div_by_zero_q <= 1'sb0;
		end
		else if (div_en_internal) begin
			div_counter_q <= div_counter_d;
			op_numerator_q <= op_numerator_d;
			op_quotient_q <= op_quotient_d;
			md_state_q <= md_state_d;
			div_by_zero_q <= div_by_zero_d;
		end
	assign multdiv_en = mult_en_internal | div_en_internal;
	assign imd_val_d_o[34+:34] = (div_sel_i ? op_remainder_d : mac_res_d);
	assign imd_val_we_o[0] = multdiv_en;
	assign imd_val_d_o[0+:34] = {2'b00, op_denominator_d};
	assign imd_val_we_o[1] = div_en_internal;
	assign op_denominator_q = imd_val_q_i[31-:32];
	wire [1:0] unused_imd_val;
	assign unused_imd_val = imd_val_q_i[33-:2];
	wire unused_mac_res_ext;
	assign unused_mac_res_ext = mac_res_ext[34];
	assign signed_mult = signed_mode_i != 2'b00;
	assign multdiv_result_o = (div_sel_i ? imd_val_q_i[65-:32] : mac_res_d[31:0]);
	generate
		if (RV32M == 32'sd3) begin : gen_mult_single_cycle
			reg mult_state_q;
			reg mult_state_d;
			wire signed [33:0] mult1_res;
			wire signed [33:0] mult2_res;
			wire signed [33:0] mult3_res;
			wire [33:0] mult1_res_uns;
			wire [33:32] unused_mult1_res_uns;
			wire [15:0] mult1_op_a;
			wire [15:0] mult1_op_b;
			wire [15:0] mult2_op_a;
			wire [15:0] mult2_op_b;
			reg [15:0] mult3_op_a;
			reg [15:0] mult3_op_b;
			wire mult1_sign_a;
			wire mult1_sign_b;
			wire mult2_sign_a;
			wire mult2_sign_b;
			reg mult3_sign_a;
			reg mult3_sign_b;
			reg [33:0] summand1;
			reg [33:0] summand2;
			reg [33:0] summand3;
			assign mult1_res = $signed({mult1_sign_a, mult1_op_a}) * $signed({mult1_sign_b, mult1_op_b});
			assign mult2_res = $signed({mult2_sign_a, mult2_op_a}) * $signed({mult2_sign_b, mult2_op_b});
			assign mult3_res = $signed({mult3_sign_a, mult3_op_a}) * $signed({mult3_sign_b, mult3_op_b});
			assign mac_res_signed = ($signed(summand1) + $signed(summand2)) + $signed(summand3);
			assign mult1_res_uns = $unsigned(mult1_res);
			assign mac_res_ext = $unsigned(mac_res_signed);
			assign mac_res = mac_res_ext[33:0];
			wire [1:1] sv2v_tmp_5ADA8;
			assign sv2v_tmp_5ADA8 = signed_mode_i[0] & op_a_i[31];
			always @(*) sign_a = sv2v_tmp_5ADA8;
			wire [1:1] sv2v_tmp_C5449;
			assign sv2v_tmp_C5449 = signed_mode_i[1] & op_b_i[31];
			always @(*) sign_b = sv2v_tmp_C5449;
			assign mult1_sign_a = 1'b0;
			assign mult1_sign_b = 1'b0;
			assign mult1_op_a = op_a_i[15:0];
			assign mult1_op_b = op_b_i[15:0];
			assign mult2_sign_a = 1'b0;
			assign mult2_sign_b = sign_b;
			assign mult2_op_a = op_a_i[15:0];
			assign mult2_op_b = op_b_i[31:16];
			wire [18:1] sv2v_tmp_6FF3F;
			assign sv2v_tmp_6FF3F = imd_val_q_i[67-:18];
			always @(*) accum[17:0] = sv2v_tmp_6FF3F;
			wire [16:1] sv2v_tmp_A7770;
			assign sv2v_tmp_A7770 = {16 {signed_mult & imd_val_q_i[67]}};
			always @(*) accum[33:18] = sv2v_tmp_A7770;
			always @(*) begin
				if (_sv2v_0)
					;
				mult3_sign_a = sign_a;
				mult3_sign_b = 1'b0;
				mult3_op_a = op_a_i[31:16];
				mult3_op_b = op_b_i[15:0];
				summand1 = {18'h00000, mult1_res_uns[31:16]};
				summand2 = $unsigned(mult2_res);
				summand3 = $unsigned(mult3_res);
				mac_res_d = {2'b00, mac_res[15:0], mult1_res_uns[15:0]};
				mult_valid = mult_en_i;
				mult_state_d = 1'd0;
				mult_hold = 1'b0;
				(* full_case, parallel_case *)
				case (mult_state_q)
					1'd0:
						if (operator_i != 2'd0) begin
							mac_res_d = mac_res;
							mult_valid = 1'b0;
							mult_state_d = 1'd1;
						end
						else
							mult_hold = 1'b0;
					1'd1: begin
						mult3_sign_a = sign_a;
						mult3_sign_b = sign_b;
						mult3_op_a = op_a_i[31:16];
						mult3_op_b = op_b_i[31:16];
						mac_res_d = mac_res;
						summand1 = 1'sb0;
						summand2 = accum;
						summand3 = $unsigned(mult3_res);
						mult_state_d = 1'd0;
						mult_valid = 1'b1;
						mult_hold = 1'b0;
					end
					default: mult_state_d = 1'd0;
				endcase
			end
			always @(posedge clk_i or negedge rst_ni)
				if (!rst_ni)
					mult_state_q <= 1'd0;
				else if (mult_en_internal)
					mult_state_q <= mult_state_d;
			assign unused_mult1_res_uns = mult1_res_uns[33:32];
		end
		else begin : gen_mult_fast
			reg [15:0] mult_op_a;
			reg [15:0] mult_op_b;
			reg [1:0] mult_state_q;
			reg [1:0] mult_state_d;
			assign mac_res_signed = ($signed({sign_a, mult_op_a}) * $signed({sign_b, mult_op_b})) + $signed(accum);
			assign mac_res_ext = $unsigned(mac_res_signed);
			assign mac_res = mac_res_ext[33:0];
			always @(*) begin
				if (_sv2v_0)
					;
				mult_op_a = op_a_i[15:0];
				mult_op_b = op_b_i[15:0];
				sign_a = 1'b0;
				sign_b = 1'b0;
				accum = imd_val_q_i[34+:34];
				mac_res_d = mac_res;
				mult_state_d = mult_state_q;
				mult_valid = 1'b0;
				mult_hold = 1'b0;
				(* full_case, parallel_case *)
				case (mult_state_q)
					2'd0: begin
						mult_op_a = op_a_i[15:0];
						mult_op_b = op_b_i[15:0];
						sign_a = 1'b0;
						sign_b = 1'b0;
						accum = 1'sb0;
						mac_res_d = mac_res;
						mult_state_d = 2'd1;
					end
					2'd1: begin
						mult_op_a = op_a_i[15:0];
						mult_op_b = op_b_i[31:16];
						sign_a = 1'b0;
						sign_b = signed_mode_i[1] & op_b_i[31];
						accum = {18'b000000000000000000, imd_val_q_i[65-:16]};
						if (operator_i == 2'd0)
							mac_res_d = {2'b00, mac_res[15:0], imd_val_q_i[49-:16]};
						else
							mac_res_d = mac_res;
						mult_state_d = 2'd2;
					end
					2'd2: begin
						mult_op_a = op_a_i[31:16];
						mult_op_b = op_b_i[15:0];
						sign_a = signed_mode_i[0] & op_a_i[31];
						sign_b = 1'b0;
						if (operator_i == 2'd0) begin
							accum = {18'b000000000000000000, imd_val_q_i[65-:16]};
							mac_res_d = {2'b00, mac_res[15:0], imd_val_q_i[49-:16]};
							mult_valid = 1'b1;
							mult_state_d = 2'd0;
							mult_hold = 1'b0;
						end
						else begin
							accum = imd_val_q_i[34+:34];
							mac_res_d = mac_res;
							mult_state_d = 2'd3;
						end
					end
					2'd3: begin
						mult_op_a = op_a_i[31:16];
						mult_op_b = op_b_i[31:16];
						sign_a = signed_mode_i[0] & op_a_i[31];
						sign_b = signed_mode_i[1] & op_b_i[31];
						accum[17:0] = imd_val_q_i[67-:18];
						accum[33:18] = {16 {signed_mult & imd_val_q_i[67]}};
						mac_res_d = mac_res;
						mult_valid = 1'b1;
						mult_state_d = 2'd0;
						mult_hold = 1'b0;
					end
					default: mult_state_d = 2'd0;
				endcase
			end
			always @(posedge clk_i or negedge rst_ni)
				if (!rst_ni)
					mult_state_q <= 2'd0;
				else if (mult_en_internal)
					mult_state_q <= mult_state_d;
		end
	endgenerate
	assign res_adder_h = alu_adder_ext_i[32:1];
	wire [1:0] unused_alu_adder_ext;
	assign unused_alu_adder_ext = {alu_adder_ext_i[33], alu_adder_ext_i[0]};
	assign next_remainder = (is_greater_equal ? res_adder_h[31:0] : imd_val_q_i[65-:32]);
	assign next_quotient = (is_greater_equal ? {1'b0, op_quotient_q} | {1'b0, one_shift} : {1'b0, op_quotient_q});
	assign one_shift = 32'b00000000000000000000000000000001 << div_counter_q;
	always @(*) begin
		if (_sv2v_0)
			;
		if ((imd_val_q_i[65] ^ op_denominator_q[31]) == 1'b0)
			is_greater_equal = res_adder_h[31] == 1'b0;
		else
			is_greater_equal = imd_val_q_i[65];
	end
	assign div_sign_a = op_a_i[31] & signed_mode_i[0];
	assign div_sign_b = op_b_i[31] & signed_mode_i[1];
	assign div_change_sign = (div_sign_a ^ div_sign_b) & ~div_by_zero_q;
	assign rem_change_sign = div_sign_a;
	always @(*) begin
		if (_sv2v_0)
			;
		div_counter_d = div_counter_q - 5'h01;
		op_remainder_d = imd_val_q_i[34+:34];
		op_quotient_d = op_quotient_q;
		md_state_d = md_state_q;
		op_numerator_d = op_numerator_q;
		op_denominator_d = op_denominator_q;
		alu_operand_a_o = 33'h000000001;
		alu_operand_b_o = {~op_b_i, 1'b1};
		div_valid = 1'b0;
		div_hold = 1'b0;
		div_by_zero_d = div_by_zero_q;
		(* full_case, parallel_case *)
		case (md_state_q)
			3'd0: begin
				if (operator_i == 2'd2) begin
					op_remainder_d = 1'sb1;
					md_state_d = (equal_to_zero_i ? 3'd6 : 3'd1);
					div_by_zero_d = equal_to_zero_i;
				end
				else begin
					op_remainder_d = {2'b00, op_a_i};
					md_state_d = (equal_to_zero_i ? 3'd6 : 3'd1);
				end
				alu_operand_a_o = 33'h000000001;
				alu_operand_b_o = {~op_b_i, 1'b1};
				div_counter_d = 5'd31;
			end
			3'd1: begin
				op_quotient_d = 1'sb0;
				op_numerator_d = (div_sign_a ? alu_adder_i : op_a_i);
				md_state_d = 3'd2;
				div_counter_d = 5'd31;
				alu_operand_a_o = 33'h000000001;
				alu_operand_b_o = {~op_a_i, 1'b1};
			end
			3'd2: begin
				op_remainder_d = {33'h000000000, op_numerator_q[31]};
				op_denominator_d = (div_sign_b ? alu_adder_i : op_b_i);
				md_state_d = 3'd3;
				div_counter_d = 5'd31;
				alu_operand_a_o = 33'h000000001;
				alu_operand_b_o = {~op_b_i, 1'b1};
			end
			3'd3: begin
				op_remainder_d = {1'b0, next_remainder[31:0], op_numerator_q[div_counter_d]};
				op_quotient_d = next_quotient[31:0];
				md_state_d = (div_counter_q == 5'd1 ? 3'd4 : 3'd3);
				alu_operand_a_o = {imd_val_q_i[65-:32], 1'b1};
				alu_operand_b_o = {~op_denominator_q[31:0], 1'b1};
			end
			3'd4: begin
				if (operator_i == 2'd2)
					op_remainder_d = {1'b0, next_quotient};
				else
					op_remainder_d = {2'b00, next_remainder[31:0]};
				alu_operand_a_o = {imd_val_q_i[65-:32], 1'b1};
				alu_operand_b_o = {~op_denominator_q[31:0], 1'b1};
				md_state_d = 3'd5;
			end
			3'd5: begin
				md_state_d = 3'd6;
				if (operator_i == 2'd2)
					op_remainder_d = (div_change_sign ? {2'h0, alu_adder_i} : imd_val_q_i[34+:34]);
				else
					op_remainder_d = (rem_change_sign ? {2'h0, alu_adder_i} : imd_val_q_i[34+:34]);
				alu_operand_a_o = 33'h000000001;
				alu_operand_b_o = {~imd_val_q_i[65-:32], 1'b1};
			end
			3'd6: begin
				md_state_d = 3'd0;
				div_hold = 1'b0;
				div_valid = 1'b1;
			end
			default: md_state_d = 3'd0;
		endcase
	end
	assign valid_o = mult_valid | div_valid;
	initial _sv2v_0 = 0;
endmodule
module cve2_multdiv_slow (
	clk_i,
	rst_ni,
	mult_en_i,
	div_en_i,
	mult_sel_i,
	div_sel_i,
	operator_i,
	signed_mode_i,
	op_a_i,
	op_b_i,
	alu_adder_ext_i,
	alu_adder_i,
	equal_to_zero_i,
	alu_operand_a_o,
	alu_operand_b_o,
	imd_val_q_i,
	imd_val_d_o,
	imd_val_we_o,
	multdiv_ready_id_i,
	multdiv_result_o,
	valid_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_ni;
	input wire mult_en_i;
	input wire div_en_i;
	input wire mult_sel_i;
	input wire div_sel_i;
	input wire [1:0] operator_i;
	input wire [1:0] signed_mode_i;
	input wire [31:0] op_a_i;
	input wire [31:0] op_b_i;
	input wire [33:0] alu_adder_ext_i;
	input wire [31:0] alu_adder_i;
	input wire equal_to_zero_i;
	output reg [32:0] alu_operand_a_o;
	output reg [32:0] alu_operand_b_o;
	input wire [67:0] imd_val_q_i;
	output wire [67:0] imd_val_d_o;
	output wire [1:0] imd_val_we_o;
	input wire multdiv_ready_id_i;
	output wire [31:0] multdiv_result_o;
	output wire valid_o;
	reg [2:0] md_state_q;
	reg [2:0] md_state_d;
	wire [32:0] accum_window_q;
	reg [32:0] accum_window_d;
	wire unused_imd_val0;
	wire [1:0] unused_imd_val1;
	wire [32:0] res_adder_l;
	wire [32:0] res_adder_h;
	reg [4:0] multdiv_count_q;
	reg [4:0] multdiv_count_d;
	reg [32:0] op_b_shift_q;
	reg [32:0] op_b_shift_d;
	reg [32:0] op_a_shift_q;
	reg [32:0] op_a_shift_d;
	wire [32:0] op_a_ext;
	wire [32:0] op_b_ext;
	wire [32:0] one_shift;
	wire [32:0] op_a_bw_pp;
	wire [32:0] op_a_bw_last_pp;
	wire [31:0] b_0;
	wire sign_a;
	wire sign_b;
	wire [32:0] next_quotient;
	wire [31:0] next_remainder;
	wire [31:0] op_numerator_q;
	reg [31:0] op_numerator_d;
	wire is_greater_equal;
	wire div_change_sign;
	wire rem_change_sign;
	reg div_by_zero_d;
	reg div_by_zero_q;
	reg multdiv_hold;
	wire multdiv_en;
	assign res_adder_l = alu_adder_ext_i[32:0];
	assign res_adder_h = alu_adder_ext_i[33:1];
	assign imd_val_d_o[34+:34] = {1'b0, accum_window_d};
	assign imd_val_we_o[0] = ~multdiv_hold;
	assign accum_window_q = imd_val_q_i[66-:33];
	assign unused_imd_val0 = imd_val_q_i[67];
	assign imd_val_d_o[0+:34] = {2'b00, op_numerator_d};
	assign imd_val_we_o[1] = multdiv_en;
	assign op_numerator_q = imd_val_q_i[31-:32];
	assign unused_imd_val1 = imd_val_q_i[33-:2];
	always @(*) begin
		if (_sv2v_0)
			;
		alu_operand_a_o = accum_window_q;
		(* full_case, parallel_case *)
		case (operator_i)
			2'd0: alu_operand_b_o = op_a_bw_pp;
			2'd1: alu_operand_b_o = (md_state_q == 3'd4 ? op_a_bw_last_pp : op_a_bw_pp);
			2'd2, 2'd3:
				(* full_case, parallel_case *)
				case (md_state_q)
					3'd0: begin
						alu_operand_a_o = 33'h000000001;
						alu_operand_b_o = {~op_b_i, 1'b1};
					end
					3'd1: begin
						alu_operand_a_o = 33'h000000001;
						alu_operand_b_o = {~op_a_i, 1'b1};
					end
					3'd2: begin
						alu_operand_a_o = 33'h000000001;
						alu_operand_b_o = {~op_b_i, 1'b1};
					end
					3'd5: begin
						alu_operand_a_o = 33'h000000001;
						alu_operand_b_o = {~accum_window_q[31:0], 1'b1};
					end
					default: begin
						alu_operand_a_o = {accum_window_q[31:0], 1'b1};
						alu_operand_b_o = {~op_b_shift_q[31:0], 1'b1};
					end
				endcase
			default: begin
				alu_operand_a_o = accum_window_q;
				alu_operand_b_o = {~op_b_shift_q[31:0], 1'b1};
			end
		endcase
	end
	assign b_0 = {32 {op_b_shift_q[0]}};
	assign op_a_bw_pp = {~(op_a_shift_q[32] & op_b_shift_q[0]), op_a_shift_q[31:0] & b_0};
	assign op_a_bw_last_pp = {op_a_shift_q[32] & op_b_shift_q[0], ~(op_a_shift_q[31:0] & b_0)};
	assign sign_a = op_a_i[31] & signed_mode_i[0];
	assign sign_b = op_b_i[31] & signed_mode_i[1];
	assign op_a_ext = {sign_a, op_a_i};
	assign op_b_ext = {sign_b, op_b_i};
	assign is_greater_equal = (accum_window_q[31] == op_b_shift_q[31] ? ~res_adder_h[31] : accum_window_q[31]);
	assign one_shift = 33'b000000000000000000000000000000001 << multdiv_count_q;
	assign next_remainder = (is_greater_equal ? res_adder_h[31:0] : accum_window_q[31:0]);
	assign next_quotient = (is_greater_equal ? op_a_shift_q | one_shift : op_a_shift_q);
	assign div_change_sign = (sign_a ^ sign_b) & ~div_by_zero_q;
	assign rem_change_sign = sign_a;
	always @(*) begin
		if (_sv2v_0)
			;
		multdiv_count_d = multdiv_count_q;
		accum_window_d = accum_window_q;
		op_b_shift_d = op_b_shift_q;
		op_a_shift_d = op_a_shift_q;
		op_numerator_d = op_numerator_q;
		md_state_d = md_state_q;
		multdiv_hold = 1'b0;
		div_by_zero_d = div_by_zero_q;
		if (mult_sel_i || div_sel_i)
			(* full_case, parallel_case *)
			case (md_state_q)
				3'd0: begin
					(* full_case, parallel_case *)
					case (operator_i)
						2'd0: begin
							op_a_shift_d = op_a_ext << 1;
							accum_window_d = {~(op_a_ext[32] & op_b_i[0]), op_a_ext[31:0] & {32 {op_b_i[0]}}};
							op_b_shift_d = op_b_ext >> 1;
							md_state_d = ((op_b_ext >> 1) == 0 ? 3'd4 : 3'd3);
						end
						2'd1: begin
							op_a_shift_d = op_a_ext;
							accum_window_d = {1'b1, ~(op_a_ext[32] & op_b_i[0]), op_a_ext[31:1] & {31 {op_b_i[0]}}};
							op_b_shift_d = op_b_ext >> 1;
							md_state_d = 3'd3;
						end
						2'd2: begin
							accum_window_d = {33 {1'b1}};
							md_state_d = (equal_to_zero_i ? 3'd6 : 3'd1);
							div_by_zero_d = equal_to_zero_i;
						end
						2'd3: begin
							accum_window_d = op_a_ext;
							md_state_d = (equal_to_zero_i ? 3'd6 : 3'd1);
						end
						default:
							;
					endcase
					multdiv_count_d = 5'd31;
				end
				3'd1: begin
					op_a_shift_d = 1'sb0;
					op_numerator_d = (sign_a ? alu_adder_i : op_a_i);
					md_state_d = 3'd2;
				end
				3'd2: begin
					accum_window_d = {32'h00000000, op_numerator_q[31]};
					op_b_shift_d = (sign_b ? {1'b0, alu_adder_i} : {1'b0, op_b_i});
					md_state_d = 3'd3;
				end
				3'd3: begin
					multdiv_count_d = multdiv_count_q - 5'h01;
					(* full_case, parallel_case *)
					case (operator_i)
						2'd0: begin
							accum_window_d = res_adder_l;
							op_a_shift_d = op_a_shift_q << 1;
							op_b_shift_d = op_b_shift_q >> 1;
							md_state_d = ((op_b_shift_d == 0) || (multdiv_count_q == 5'd1) ? 3'd4 : 3'd3);
						end
						2'd1: begin
							accum_window_d = res_adder_h;
							op_a_shift_d = op_a_shift_q;
							op_b_shift_d = op_b_shift_q >> 1;
							md_state_d = (multdiv_count_q == 5'd1 ? 3'd4 : 3'd3);
						end
						2'd2, 2'd3: begin
							accum_window_d = {next_remainder[31:0], op_numerator_q[multdiv_count_d]};
							op_a_shift_d = next_quotient;
							md_state_d = (multdiv_count_q == 5'd1 ? 3'd4 : 3'd3);
						end
						default:
							;
					endcase
				end
				3'd4:
					(* full_case, parallel_case *)
					case (operator_i)
						2'd0: begin
							accum_window_d = res_adder_l;
							md_state_d = 3'd0;
							multdiv_hold = ~multdiv_ready_id_i;
						end
						2'd1: begin
							accum_window_d = res_adder_l;
							md_state_d = 3'd0;
							md_state_d = 3'd0;
							multdiv_hold = ~multdiv_ready_id_i;
						end
						2'd2: begin
							accum_window_d = next_quotient;
							md_state_d = 3'd5;
						end
						2'd3: begin
							accum_window_d = {1'b0, next_remainder[31:0]};
							md_state_d = 3'd5;
						end
						default:
							;
					endcase
				3'd5: begin
					md_state_d = 3'd6;
					(* full_case, parallel_case *)
					case (operator_i)
						2'd2: accum_window_d = (div_change_sign ? {1'b0, alu_adder_i} : accum_window_q);
						2'd3: accum_window_d = (rem_change_sign ? {1'b0, alu_adder_i} : accum_window_q);
						default:
							;
					endcase
				end
				3'd6: begin
					md_state_d = 3'd0;
					multdiv_hold = ~multdiv_ready_id_i;
				end
				default: md_state_d = 3'd0;
			endcase
	end
	assign multdiv_en = (mult_en_i | div_en_i) & ~multdiv_hold;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			multdiv_count_q <= 5'h00;
			op_b_shift_q <= 33'h000000000;
			op_a_shift_q <= 33'h000000000;
			md_state_q <= 3'd0;
			div_by_zero_q <= 1'b0;
		end
		else if (multdiv_en) begin
			multdiv_count_q <= multdiv_count_d;
			op_b_shift_q <= op_b_shift_d;
			op_a_shift_q <= op_a_shift_d;
			md_state_q <= md_state_d;
			div_by_zero_q <= div_by_zero_d;
		end
	assign valid_o = (md_state_q == 3'd6) | ((md_state_q == 3'd4) & ((operator_i == 2'd0) | (operator_i == 2'd1)));
	assign multdiv_result_o = (div_en_i ? accum_window_q[31:0] : res_adder_l[31:0]);
	initial _sv2v_0 = 0;
endmodule
module cve2_prefetch_buffer (
	clk_i,
	rst_ni,
	req_i,
	branch_i,
	addr_i,
	ready_i,
	valid_o,
	rdata_o,
	addr_o,
	err_o,
	err_plus2_o,
	instr_req_o,
	instr_gnt_i,
	instr_addr_o,
	instr_rdata_i,
	instr_err_i,
	instr_rvalid_i,
	busy_o
);
	input wire clk_i;
	input wire rst_ni;
	input wire req_i;
	input wire branch_i;
	input wire [31:0] addr_i;
	input wire ready_i;
	output wire valid_o;
	output wire [31:0] rdata_o;
	output wire [31:0] addr_o;
	output wire err_o;
	output wire err_plus2_o;
	output wire instr_req_o;
	input wire instr_gnt_i;
	output wire [31:0] instr_addr_o;
	input wire [31:0] instr_rdata_i;
	input wire instr_err_i;
	input wire instr_rvalid_i;
	output wire busy_o;
	localparam [31:0] NUM_REQS = 2;
	wire valid_new_req;
	wire valid_req;
	wire valid_req_d;
	reg valid_req_q;
	wire discard_req_d;
	reg discard_req_q;
	wire [1:0] rdata_outstanding_n;
	wire [1:0] rdata_outstanding_s;
	reg [1:0] rdata_outstanding_q;
	wire [1:0] branch_discard_n;
	wire [1:0] branch_discard_s;
	reg [1:0] branch_discard_q;
	wire [1:0] rdata_outstanding_rev;
	wire [31:0] stored_addr_d;
	reg [31:0] stored_addr_q;
	wire stored_addr_en;
	wire [31:0] fetch_addr_d;
	reg [31:0] fetch_addr_q;
	wire fetch_addr_en;
	wire [31:0] instr_addr;
	wire [31:0] instr_addr_w_aligned;
	wire fifo_valid;
	wire [31:0] fifo_addr;
	wire fifo_ready;
	wire fifo_clear;
	wire [1:0] fifo_busy;
	wire valid_raw;
	assign busy_o = |rdata_outstanding_q | instr_req_o;
	assign fifo_clear = branch_i;
	genvar _gv_i_31;
	generate
		for (_gv_i_31 = 0; _gv_i_31 < NUM_REQS; _gv_i_31 = _gv_i_31 + 1) begin : gen_rd_rev
			localparam i = _gv_i_31;
			assign rdata_outstanding_rev[i] = rdata_outstanding_q[1 - i];
		end
	endgenerate
	assign fifo_ready = ~&(fifo_busy | rdata_outstanding_rev);
	cve2_fetch_fifo #(.NUM_REQS(NUM_REQS)) fifo_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.clear_i(fifo_clear),
		.busy_o(fifo_busy),
		.in_valid_i(fifo_valid),
		.in_addr_i(fifo_addr),
		.in_rdata_i(instr_rdata_i),
		.in_err_i(instr_err_i),
		.out_valid_o(valid_raw),
		.out_ready_i(ready_i),
		.out_rdata_o(rdata_o),
		.out_addr_o(addr_o),
		.out_err_o(err_o),
		.out_err_plus2_o(err_plus2_o)
	);
	assign valid_new_req = (req_i & (fifo_ready | branch_i)) & ~rdata_outstanding_q[1];
	assign valid_req = valid_req_q | valid_new_req;
	assign valid_req_d = valid_req & ~instr_gnt_i;
	assign discard_req_d = valid_req_q & (branch_i | discard_req_q);
	assign stored_addr_en = (valid_new_req & ~valid_req_q) & ~instr_gnt_i;
	assign stored_addr_d = instr_addr;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			stored_addr_q <= 1'sb0;
		else if (stored_addr_en)
			stored_addr_q <= stored_addr_d;
	assign fetch_addr_en = branch_i | (valid_new_req & ~valid_req_q);
	assign fetch_addr_d = (branch_i ? addr_i : {fetch_addr_q[31:2], 2'b00}) + {{29 {1'b0}}, valid_new_req & ~valid_req_q, 2'b00};
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			fetch_addr_q <= 1'sb0;
		else if (fetch_addr_en)
			fetch_addr_q <= fetch_addr_d;
	assign instr_addr = (valid_req_q ? stored_addr_q : (branch_i ? addr_i : fetch_addr_q));
	assign instr_addr_w_aligned = {instr_addr[31:2], 2'b00};
	genvar _gv_i_32;
	generate
		for (_gv_i_32 = 0; _gv_i_32 < NUM_REQS; _gv_i_32 = _gv_i_32 + 1) begin : g_outstanding_reqs
			localparam i = _gv_i_32;
			if (i == 0) begin : g_req0
				assign rdata_outstanding_n[i] = (valid_req & instr_gnt_i) | rdata_outstanding_q[i];
				assign branch_discard_n[i] = (((valid_req & instr_gnt_i) & discard_req_d) | (branch_i & rdata_outstanding_q[i])) | branch_discard_q[i];
			end
			else begin : g_reqtop
				assign rdata_outstanding_n[i] = ((valid_req & instr_gnt_i) & rdata_outstanding_q[i - 1]) | rdata_outstanding_q[i];
				assign branch_discard_n[i] = ((((valid_req & instr_gnt_i) & discard_req_d) & rdata_outstanding_q[i - 1]) | (branch_i & rdata_outstanding_q[i])) | branch_discard_q[i];
			end
		end
	endgenerate
	assign rdata_outstanding_s = (instr_rvalid_i ? {1'b0, rdata_outstanding_n[1:1]} : rdata_outstanding_n);
	assign branch_discard_s = (instr_rvalid_i ? {1'b0, branch_discard_n[1:1]} : branch_discard_n);
	assign fifo_valid = instr_rvalid_i & ~branch_discard_q[0];
	assign fifo_addr = addr_i;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			valid_req_q <= 1'b0;
			discard_req_q <= 1'b0;
			rdata_outstanding_q <= 'b0;
			branch_discard_q <= 'b0;
		end
		else begin
			valid_req_q <= valid_req_d;
			discard_req_q <= discard_req_d;
			rdata_outstanding_q <= rdata_outstanding_s;
			branch_discard_q <= branch_discard_s;
		end
	assign instr_req_o = valid_req;
	assign instr_addr_o = instr_addr_w_aligned;
	assign valid_o = valid_raw;
endmodule
module cve2_pmp (
	clk_i,
	rst_ni,
	csr_pmp_cfg_i,
	csr_pmp_addr_i,
	csr_pmp_mseccfg_i,
	priv_mode_i,
	pmp_req_addr_i,
	pmp_req_type_i,
	pmp_req_err_o
);
	reg _sv2v_0;
	parameter [31:0] PMPGranularity = 0;
	parameter [31:0] PMPNumChan = 2;
	parameter [31:0] PMPNumRegions = 4;
	input wire clk_i;
	input wire rst_ni;
	input wire [(PMPNumRegions * 6) - 1:0] csr_pmp_cfg_i;
	input wire [(PMPNumRegions * 34) - 1:0] csr_pmp_addr_i;
	input wire [2:0] csr_pmp_mseccfg_i;
	input wire [(PMPNumChan * 2) - 1:0] priv_mode_i;
	input wire [(PMPNumChan * 34) - 1:0] pmp_req_addr_i;
	input wire [(PMPNumChan * 2) - 1:0] pmp_req_type_i;
	output wire [0:PMPNumChan - 1] pmp_req_err_o;
	wire [33:0] region_start_addr [0:PMPNumRegions - 1];
	wire [33:PMPGranularity + 2] region_addr_mask [0:PMPNumRegions - 1];
	wire [(PMPNumChan * PMPNumRegions) - 1:0] region_match_gt;
	wire [(PMPNumChan * PMPNumRegions) - 1:0] region_match_lt;
	wire [(PMPNumChan * PMPNumRegions) - 1:0] region_match_eq;
	reg [(PMPNumChan * PMPNumRegions) - 1:0] region_match_all;
	wire [(PMPNumChan * PMPNumRegions) - 1:0] region_basic_perm_check;
	reg [(PMPNumChan * PMPNumRegions) - 1:0] region_mml_perm_check;
	reg [PMPNumChan - 1:0] access_fault;
	$warning("CVE2 does not officially support PMP, see rule PVL-40.");
	genvar _gv_r_1;
	generate
		for (_gv_r_1 = 0; _gv_r_1 < PMPNumRegions; _gv_r_1 = _gv_r_1 + 1) begin : g_addr_exp
			localparam r = _gv_r_1;
			if (r == 0) begin : g_entry0
				assign region_start_addr[r] = (csr_pmp_cfg_i[(((PMPNumRegions - 1) - r) * 6) + 4-:2] == 2'b01 ? 34'h000000000 : csr_pmp_addr_i[((PMPNumRegions - 1) - r) * 34+:34]);
			end
			else begin : g_oth
				assign region_start_addr[r] = (csr_pmp_cfg_i[(((PMPNumRegions - 1) - r) * 6) + 4-:2] == 2'b01 ? csr_pmp_addr_i[((PMPNumRegions - 1) - (r - 1)) * 34+:34] : csr_pmp_addr_i[((PMPNumRegions - 1) - r) * 34+:34]);
			end
			genvar _gv_b_2;
			for (_gv_b_2 = PMPGranularity + 2; _gv_b_2 < 34; _gv_b_2 = _gv_b_2 + 1) begin : g_bitmask
				localparam b = _gv_b_2;
				if (b == 2) begin : g_bit0
					assign region_addr_mask[r][b] = csr_pmp_cfg_i[(((PMPNumRegions - 1) - r) * 6) + 4-:2] != 2'b11;
				end
				else begin : g_others
					if (PMPGranularity == 0) begin : g_region_addr_mask_zero_granularity
						assign region_addr_mask[r][b] = (csr_pmp_cfg_i[(((PMPNumRegions - 1) - r) * 6) + 4-:2] != 2'b11) | ~&csr_pmp_addr_i[(((PMPNumRegions - 1) - r) * 34) + ((b - 1) >= 2 ? b - 1 : ((b - 1) + ((b - 1) >= 2 ? b - 2 : 4 - b)) - 1)-:((b - 1) >= 2 ? b - 2 : 4 - b)];
					end
					else begin : g_region_addr_mask_other_granularity
						assign region_addr_mask[r][b] = (csr_pmp_cfg_i[(((PMPNumRegions - 1) - r) * 6) + 4-:2] != 2'b11) | ~&csr_pmp_addr_i[(((PMPNumRegions - 1) - r) * 34) + ((b - 1) >= (PMPGranularity + 1) ? b - 1 : ((b - 1) + ((b - 1) >= (PMPGranularity + 1) ? ((b - 1) - (PMPGranularity + 1)) + 1 : ((PMPGranularity + 1) - (b - 1)) + 1)) - 1)-:((b - 1) >= (PMPGranularity + 1) ? ((b - 1) - (PMPGranularity + 1)) + 1 : ((PMPGranularity + 1) - (b - 1)) + 1)];
					end
				end
			end
		end
	endgenerate
	genvar _gv_c_1;
	generate
		for (_gv_c_1 = 0; _gv_c_1 < PMPNumChan; _gv_c_1 = _gv_c_1 + 1) begin : g_access_check
			localparam c = _gv_c_1;
			genvar _gv_r_2;
			for (_gv_r_2 = 0; _gv_r_2 < PMPNumRegions; _gv_r_2 = _gv_r_2 + 1) begin : g_regions
				localparam r = _gv_r_2;
				assign region_match_eq[(c * PMPNumRegions) + r] = (pmp_req_addr_i[(((PMPNumChan - 1) - c) * 34) + (33 >= (PMPGranularity + 2) ? 33 : (33 + (33 >= (PMPGranularity + 2) ? 34 - (PMPGranularity + 2) : PMPGranularity - 30)) - 1)-:(33 >= (PMPGranularity + 2) ? 34 - (PMPGranularity + 2) : PMPGranularity - 30)] & region_addr_mask[r]) == (region_start_addr[r][33:PMPGranularity + 2] & region_addr_mask[r]);
				assign region_match_gt[(c * PMPNumRegions) + r] = pmp_req_addr_i[(((PMPNumChan - 1) - c) * 34) + (33 >= (PMPGranularity + 2) ? 33 : (33 + (33 >= (PMPGranularity + 2) ? 34 - (PMPGranularity + 2) : PMPGranularity - 30)) - 1)-:(33 >= (PMPGranularity + 2) ? 34 - (PMPGranularity + 2) : PMPGranularity - 30)] > region_start_addr[r][33:PMPGranularity + 2];
				assign region_match_lt[(c * PMPNumRegions) + r] = pmp_req_addr_i[(((PMPNumChan - 1) - c) * 34) + (33 >= (PMPGranularity + 2) ? 33 : (33 + (33 >= (PMPGranularity + 2) ? 34 - (PMPGranularity + 2) : PMPGranularity - 30)) - 1)-:(33 >= (PMPGranularity + 2) ? 34 - (PMPGranularity + 2) : PMPGranularity - 30)] < csr_pmp_addr_i[(((PMPNumRegions - 1) - r) * 34) + (33 >= (PMPGranularity + 2) ? 33 : (33 + (33 >= (PMPGranularity + 2) ? 34 - (PMPGranularity + 2) : PMPGranularity - 30)) - 1)-:(33 >= (PMPGranularity + 2) ? 34 - (PMPGranularity + 2) : PMPGranularity - 30)];
				always @(*) begin
					if (_sv2v_0)
						;
					region_match_all[(c * PMPNumRegions) + r] = 1'b0;
					(* full_case, parallel_case *)
					case (csr_pmp_cfg_i[(((PMPNumRegions - 1) - r) * 6) + 4-:2])
						2'b00: region_match_all[(c * PMPNumRegions) + r] = 1'b0;
						2'b10: region_match_all[(c * PMPNumRegions) + r] = region_match_eq[(c * PMPNumRegions) + r];
						2'b11: region_match_all[(c * PMPNumRegions) + r] = region_match_eq[(c * PMPNumRegions) + r];
						2'b01: region_match_all[(c * PMPNumRegions) + r] = (region_match_eq[(c * PMPNumRegions) + r] | region_match_gt[(c * PMPNumRegions) + r]) & region_match_lt[(c * PMPNumRegions) + r];
						default: region_match_all[(c * PMPNumRegions) + r] = 1'b0;
					endcase
				end
				assign region_basic_perm_check[(c * PMPNumRegions) + r] = (((pmp_req_type_i[((PMPNumChan - 1) - c) * 2+:2] == 2'b00) & csr_pmp_cfg_i[(((PMPNumRegions - 1) - r) * 6) + 2]) | ((pmp_req_type_i[((PMPNumChan - 1) - c) * 2+:2] == 2'b01) & csr_pmp_cfg_i[(((PMPNumRegions - 1) - r) * 6) + 1])) | ((pmp_req_type_i[((PMPNumChan - 1) - c) * 2+:2] == 2'b10) & csr_pmp_cfg_i[((PMPNumRegions - 1) - r) * 6]);
				always @(*) begin
					if (_sv2v_0)
						;
					region_mml_perm_check[(c * PMPNumRegions) + r] = 1'b0;
					if (!csr_pmp_cfg_i[((PMPNumRegions - 1) - r) * 6] && csr_pmp_cfg_i[(((PMPNumRegions - 1) - r) * 6) + 1])
						(* full_case, parallel_case *)
						case ({csr_pmp_cfg_i[(((PMPNumRegions - 1) - r) * 6) + 5], csr_pmp_cfg_i[(((PMPNumRegions - 1) - r) * 6) + 2]})
							2'b00: region_mml_perm_check[(c * PMPNumRegions) + r] = (pmp_req_type_i[((PMPNumChan - 1) - c) * 2+:2] == 2'b10) | ((pmp_req_type_i[((PMPNumChan - 1) - c) * 2+:2] == 2'b01) & (priv_mode_i[((PMPNumChan - 1) - c) * 2+:2] == 2'b11));
							2'b01: region_mml_perm_check[(c * PMPNumRegions) + r] = (pmp_req_type_i[((PMPNumChan - 1) - c) * 2+:2] == 2'b10) | (pmp_req_type_i[((PMPNumChan - 1) - c) * 2+:2] == 2'b01);
							2'b10: region_mml_perm_check[(c * PMPNumRegions) + r] = pmp_req_type_i[((PMPNumChan - 1) - c) * 2+:2] == 2'b00;
							2'b11: region_mml_perm_check[(c * PMPNumRegions) + r] = (pmp_req_type_i[((PMPNumChan - 1) - c) * 2+:2] == 2'b00) | ((pmp_req_type_i[((PMPNumChan - 1) - c) * 2+:2] == 2'b10) & (priv_mode_i[((PMPNumChan - 1) - c) * 2+:2] == 2'b11));
							default:
								;
						endcase
					else if (((csr_pmp_cfg_i[((PMPNumRegions - 1) - r) * 6] & csr_pmp_cfg_i[(((PMPNumRegions - 1) - r) * 6) + 1]) & csr_pmp_cfg_i[(((PMPNumRegions - 1) - r) * 6) + 2]) & csr_pmp_cfg_i[(((PMPNumRegions - 1) - r) * 6) + 5])
						region_mml_perm_check[(c * PMPNumRegions) + r] = pmp_req_type_i[((PMPNumChan - 1) - c) * 2+:2] == 2'b10;
					else
						region_mml_perm_check[(c * PMPNumRegions) + r] = (priv_mode_i[((PMPNumChan - 1) - c) * 2+:2] == 2'b11 ? csr_pmp_cfg_i[(((PMPNumRegions - 1) - r) * 6) + 5] & region_basic_perm_check[(c * PMPNumRegions) + r] : ~csr_pmp_cfg_i[(((PMPNumRegions - 1) - r) * 6) + 5] & region_basic_perm_check[(c * PMPNumRegions) + r]);
				end
			end
			always @(*) begin
				if (_sv2v_0)
					;
				access_fault[c] = csr_pmp_mseccfg_i[1] | (priv_mode_i[((PMPNumChan - 1) - c) * 2+:2] != 2'b11);
				begin : sv2v_autoblock_1
					reg signed [31:0] r;
					for (r = PMPNumRegions - 1; r >= 0; r = r - 1)
						if (region_match_all[(c * PMPNumRegions) + r]) begin
							if (csr_pmp_mseccfg_i[0])
								access_fault[c] = ~region_mml_perm_check[(c * PMPNumRegions) + r];
							else
								access_fault[c] = (priv_mode_i[((PMPNumChan - 1) - c) * 2+:2] == 2'b11 ? csr_pmp_cfg_i[(((PMPNumRegions - 1) - r) * 6) + 5] & ~region_basic_perm_check[(c * PMPNumRegions) + r] : ~region_basic_perm_check[(c * PMPNumRegions) + r]);
						end
				end
			end
			assign pmp_req_err_o[c] = access_fault[c];
		end
	endgenerate
	wire unused_csr_pmp_mseccfg_rlb;
	assign unused_csr_pmp_mseccfg_rlb = csr_pmp_mseccfg_i[2];
	initial _sv2v_0 = 0;
endmodule
module cve2_register_file_ff (
	clk_i,
	rst_ni,
	test_en_i,
	raddr_a_i,
	rdata_a_o,
	raddr_b_i,
	rdata_b_o,
	raddr_c_i,
	rdata_c_o,
	waddr_a_i,
	wdata_a_i,
	we_a_i
);
	reg _sv2v_0;
	parameter [0:0] RV32E = 0;
	parameter [31:0] DataWidth = 32;
	parameter [DataWidth - 1:0] WordZeroVal = 1'sb0;
	parameter [0:0] XInterface = 1'b0;
	input wire clk_i;
	input wire rst_ni;
	input wire test_en_i;
	input wire [4:0] raddr_a_i;
	output wire [DataWidth - 1:0] rdata_a_o;
	input wire [4:0] raddr_b_i;
	output wire [DataWidth - 1:0] rdata_b_o;
	input wire [4:0] raddr_c_i;
	output wire [DataWidth - 1:0] rdata_c_o;
	input wire [4:0] waddr_a_i;
	input wire [DataWidth - 1:0] wdata_a_i;
	input wire we_a_i;
	localparam [31:0] ADDR_WIDTH = (RV32E ? 4 : 5);
	localparam [31:0] NUM_WORDS = 2 ** ADDR_WIDTH;
	wire [(NUM_WORDS * DataWidth) - 1:0] rf_reg;
	reg [((NUM_WORDS - 1) >= 1 ? ((NUM_WORDS - 1) * DataWidth) + (DataWidth - 1) : ((3 - NUM_WORDS) * DataWidth) + (((NUM_WORDS - 1) * DataWidth) - 1)):((NUM_WORDS - 1) >= 1 ? DataWidth : (NUM_WORDS - 1) * DataWidth)] rf_reg_q;
	reg [NUM_WORDS - 1:1] we_a_dec;
	function automatic [4:0] sv2v_cast_5;
		input reg [4:0] inp;
		sv2v_cast_5 = inp;
	endfunction
	always @(*) begin : we_a_decoder
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_1
			reg [31:0] i;
			for (i = 1; i < NUM_WORDS; i = i + 1)
				we_a_dec[i] = (waddr_a_i == sv2v_cast_5(i) ? we_a_i : 1'b0);
		end
	end
	genvar _gv_i_33;
	generate
		for (_gv_i_33 = 1; _gv_i_33 < NUM_WORDS; _gv_i_33 = _gv_i_33 + 1) begin : g_rf_flops
			localparam i = _gv_i_33;
			always @(posedge clk_i or negedge rst_ni)
				if (!rst_ni)
					rf_reg_q[((NUM_WORDS - 1) >= 1 ? i : 1 - (i - (NUM_WORDS - 1))) * DataWidth+:DataWidth] <= WordZeroVal;
				else if (we_a_dec[i])
					rf_reg_q[((NUM_WORDS - 1) >= 1 ? i : 1 - (i - (NUM_WORDS - 1))) * DataWidth+:DataWidth] <= wdata_a_i;
		end
	endgenerate
	assign rf_reg[0+:DataWidth] = WordZeroVal;
	assign rf_reg[DataWidth * (((NUM_WORDS - 1) >= 1 ? NUM_WORDS - 1 : ((NUM_WORDS - 1) + ((NUM_WORDS - 1) >= 1 ? NUM_WORDS - 1 : 3 - NUM_WORDS)) - 1) - (((NUM_WORDS - 1) >= 1 ? NUM_WORDS - 1 : 3 - NUM_WORDS) - 1))+:DataWidth * ((NUM_WORDS - 1) >= 1 ? NUM_WORDS - 1 : 3 - NUM_WORDS)] = rf_reg_q[DataWidth * ((NUM_WORDS - 1) >= 1 ? ((NUM_WORDS - 1) >= 1 ? ((NUM_WORDS - 1) >= 1 ? NUM_WORDS - 1 : ((NUM_WORDS - 1) + ((NUM_WORDS - 1) >= 1 ? NUM_WORDS - 1 : 3 - NUM_WORDS)) - 1) - (((NUM_WORDS - 1) >= 1 ? NUM_WORDS - 1 : 3 - NUM_WORDS) - 1) : ((NUM_WORDS - 1) >= 1 ? NUM_WORDS - 1 : ((NUM_WORDS - 1) + ((NUM_WORDS - 1) >= 1 ? NUM_WORDS - 1 : 3 - NUM_WORDS)) - 1)) : 1 - (((NUM_WORDS - 1) >= 1 ? ((NUM_WORDS - 1) >= 1 ? NUM_WORDS - 1 : ((NUM_WORDS - 1) + ((NUM_WORDS - 1) >= 1 ? NUM_WORDS - 1 : 3 - NUM_WORDS)) - 1) - (((NUM_WORDS - 1) >= 1 ? NUM_WORDS - 1 : 3 - NUM_WORDS) - 1) : ((NUM_WORDS - 1) >= 1 ? NUM_WORDS - 1 : ((NUM_WORDS - 1) + ((NUM_WORDS - 1) >= 1 ? NUM_WORDS - 1 : 3 - NUM_WORDS)) - 1)) - (NUM_WORDS - 1)))+:DataWidth * ((NUM_WORDS - 1) >= 1 ? NUM_WORDS - 1 : 3 - NUM_WORDS)];
	assign rdata_a_o = rf_reg[raddr_a_i * DataWidth+:DataWidth];
	assign rdata_b_o = rf_reg[raddr_b_i * DataWidth+:DataWidth];
	assign rdata_c_o = (XInterface ? rf_reg[raddr_c_i * DataWidth+:DataWidth] : {DataWidth {1'sb0}});
	wire unused_test_en;
	assign unused_test_en = test_en_i;
	initial _sv2v_0 = 0;
endmodule
module cve2_wb (
	clk_i,
	rst_ni,
	en_wb_i,
	instr_is_compressed_id_i,
	instr_perf_count_id_i,
	perf_instr_ret_wb_o,
	perf_instr_ret_compressed_wb_o,
	rf_waddr_id_i,
	rf_wdata_id_i,
	rf_we_id_i,
	rf_wdata_lsu_i,
	rf_we_lsu_i,
	rf_waddr_wb_o,
	rf_wdata_wb_o,
	rf_we_wb_o,
	lsu_resp_valid_i,
	lsu_resp_err_i
);
	input wire clk_i;
	input wire rst_ni;
	input wire en_wb_i;
	input wire instr_is_compressed_id_i;
	input wire instr_perf_count_id_i;
	output wire perf_instr_ret_wb_o;
	output wire perf_instr_ret_compressed_wb_o;
	input wire [4:0] rf_waddr_id_i;
	input wire [31:0] rf_wdata_id_i;
	input wire rf_we_id_i;
	input wire [31:0] rf_wdata_lsu_i;
	input wire rf_we_lsu_i;
	output wire [4:0] rf_waddr_wb_o;
	output wire [31:0] rf_wdata_wb_o;
	output wire rf_we_wb_o;
	input wire lsu_resp_valid_i;
	input wire lsu_resp_err_i;
	wire [31:0] rf_wdata_wb_mux [0:1];
	wire [1:0] rf_wdata_wb_mux_we;
	assign rf_waddr_wb_o = rf_waddr_id_i;
	assign rf_wdata_wb_mux[0] = rf_wdata_id_i;
	assign rf_wdata_wb_mux_we[0] = rf_we_id_i;
	assign perf_instr_ret_wb_o = (instr_perf_count_id_i & en_wb_i) & ~(lsu_resp_valid_i & lsu_resp_err_i);
	assign perf_instr_ret_compressed_wb_o = perf_instr_ret_wb_o & instr_is_compressed_id_i;
	assign rf_wdata_wb_mux[1] = rf_wdata_lsu_i;
	assign rf_wdata_wb_mux_we[1] = rf_we_lsu_i;
	assign rf_wdata_wb_o = ({32 {rf_wdata_wb_mux_we[0]}} & rf_wdata_wb_mux[0]) | ({32 {rf_wdata_wb_mux_we[1]}} & rf_wdata_wb_mux[1]);
	assign rf_we_wb_o = |rf_wdata_wb_mux_we;
endmodule
module cve2_core (
	clk_i,
	rst_ni,
	test_en_i,
	hart_id_i,
	boot_addr_i,
	instr_req_o,
	instr_gnt_i,
	instr_rvalid_i,
	instr_addr_o,
	instr_rdata_i,
	instr_err_i,
	data_req_o,
	data_gnt_i,
	data_rvalid_i,
	data_we_o,
	data_be_o,
	data_addr_o,
	data_wdata_o,
	data_rdata_i,
	data_err_i,
	x_issue_valid_o,
	x_issue_ready_i,
	x_issue_req_o,
	x_issue_resp_i,
	x_register_o,
	x_commit_valid_o,
	x_commit_o,
	x_result_valid_i,
	x_result_ready_o,
	x_result_i,
	irq_software_i,
	irq_timer_i,
	irq_external_i,
	irq_fast_i,
	irq_nm_i,
	irq_pending_o,
	debug_req_i,
	debug_halted_o,
	dm_halt_addr_i,
	dm_exception_addr_i,
	crash_dump_o,
	fetch_enable_i,
	core_busy_o
);
	parameter [0:0] PMPEnable = 1'b0;
	parameter [31:0] PMPGranularity = 0;
	parameter [31:0] PMPNumRegions = 4;
	parameter [31:0] MHPMCounterNum = 10;
	parameter [31:0] MHPMCounterWidth = 40;
	parameter [0:0] RV32E = 1'b0;
	parameter integer RV32M = 32'sd2;
	parameter integer RV32B = 32'sd0;
	parameter [0:0] DbgTriggerEn = 1'b0;
	parameter [31:0] DbgHwBreakNum = 1;
	parameter [0:0] XInterface = 1'b0;
	input wire clk_i;
	input wire rst_ni;
	input wire test_en_i;
	input wire [31:0] hart_id_i;
	input wire [31:0] boot_addr_i;
	output wire instr_req_o;
	input wire instr_gnt_i;
	input wire instr_rvalid_i;
	output wire [31:0] instr_addr_o;
	input wire [31:0] instr_rdata_i;
	input wire instr_err_i;
	output wire data_req_o;
	input wire data_gnt_i;
	input wire data_rvalid_i;
	output wire data_we_o;
	output wire [3:0] data_be_o;
	output wire [31:0] data_addr_o;
	output wire [31:0] data_wdata_o;
	input wire [31:0] data_rdata_i;
	input wire data_err_i;
	output wire x_issue_valid_o;
	input wire x_issue_ready_i;
	localparam [31:0] cve2_pkg_X_HARTID_WIDTH = 32;
	localparam [31:0] cve2_pkg_X_ID_WIDTH = 4;
	output wire [67:0] x_issue_req_o;
	localparam [31:0] cve2_pkg_X_DUAL_READ = 0;
	localparam [31:0] cve2_pkg_X_NUM_RS = 3;
	localparam [31:0] cve2_pkg_X_DUAL_WRITE = 0;
	input wire [(2 + (cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ)) - 1:0] x_issue_resp_i;
	localparam [31:0] cve2_pkg_X_RFR_WIDTH = 32;
	output wire [(((cve2_pkg_X_HARTID_WIDTH + cve2_pkg_X_ID_WIDTH) + (cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH)) + (cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ)) - 1:0] x_register_o;
	output wire x_commit_valid_o;
	output wire [(cve2_pkg_X_HARTID_WIDTH + cve2_pkg_X_ID_WIDTH) + 0:0] x_commit_o;
	input wire x_result_valid_i;
	output wire x_result_ready_o;
	localparam [31:0] cve2_pkg_X_RFW_WIDTH = 32;
	input wire [((cve2_pkg_X_HARTID_WIDTH + cve2_pkg_X_ID_WIDTH) + cve2_pkg_X_RFW_WIDTH) + 5:0] x_result_i;
	input wire irq_software_i;
	input wire irq_timer_i;
	input wire irq_external_i;
	input wire [15:0] irq_fast_i;
	input wire irq_nm_i;
	output wire irq_pending_o;
	input wire debug_req_i;
	output wire debug_halted_o;
	input wire [31:0] dm_halt_addr_i;
	input wire [31:0] dm_exception_addr_i;
	output wire [127:0] crash_dump_o;
	input wire fetch_enable_i;
	output wire core_busy_o;
	localparam [31:0] PMP_NUM_CHAN = 3;
	wire instr_valid_id;
	wire instr_new_id;
	wire [31:0] instr_rdata_id;
	wire [31:0] instr_rdata_alu_id;
	wire [15:0] instr_rdata_c_id;
	wire instr_is_compressed_id;
	wire instr_perf_count_id;
	wire instr_fetch_err;
	wire instr_fetch_err_plus2;
	wire illegal_c_insn_id;
	wire [31:0] pc_if;
	wire [31:0] pc_id;
	wire [67:0] imd_val_d_ex;
	wire [67:0] imd_val_q_ex;
	wire [1:0] imd_val_we_ex;
	wire instr_first_cycle_id;
	wire instr_valid_clear;
	wire pc_set;
	wire [2:0] pc_mux_id;
	wire [1:0] exc_pc_mux_id;
	wire [6:0] exc_cause;
	wire lsu_load_err;
	wire lsu_store_err;
	wire lsu_addr_incr_req;
	wire [31:0] lsu_addr_last;
	wire [31:0] branch_target_ex;
	wire branch_decision;
	wire ctrl_busy;
	wire if_busy;
	wire lsu_busy;
	wire [4:0] rf_raddr_a;
	wire [31:0] rf_rdata_a;
	wire [4:0] rf_raddr_b;
	wire [31:0] rf_rdata_b;
	wire [4:0] rf_raddr_c;
	wire [31:0] rf_rdata_c;
	wire rf_ren_a;
	wire rf_ren_b;
	wire rf_ren_c;
	wire [4:0] rf_waddr_wb;
	wire [31:0] rf_wdata_wb;
	wire [31:0] rf_wdata_lsu;
	wire rf_we_wb;
	wire rf_we_lsu;
	wire [4:0] rf_waddr_id;
	wire [31:0] rf_wdata_id;
	wire rf_we_id;
	wire [6:0] alu_operator_ex;
	wire [31:0] alu_operand_a_ex;
	wire [31:0] alu_operand_b_ex;
	wire [31:0] alu_adder_result_ex;
	wire [31:0] result_ex;
	wire mult_en_ex;
	wire div_en_ex;
	wire mult_sel_ex;
	wire div_sel_ex;
	wire [1:0] multdiv_operator_ex;
	wire [1:0] multdiv_signed_mode_ex;
	wire [31:0] multdiv_operand_a_ex;
	wire [31:0] multdiv_operand_b_ex;
	wire csr_access;
	wire [1:0] csr_op;
	wire csr_op_en;
	wire [11:0] csr_addr;
	wire [31:0] csr_rdata;
	wire [31:0] csr_wdata;
	wire illegal_csr_insn_id;
	wire lsu_we;
	wire [1:0] lsu_type;
	wire lsu_sign_ext;
	wire lsu_req;
	wire [31:0] lsu_wdata;
	wire id_in_ready;
	wire ex_valid;
	wire lsu_resp_valid;
	wire lsu_resp_err;
	wire instr_req_int;
	wire instr_req_gated;
	wire en_wb;
	wire nmi_mode;
	wire [18:0] irqs;
	wire csr_mstatus_mie;
	wire [31:0] csr_mepc;
	wire [31:0] csr_depc;
	wire [(PMPNumRegions * 34) - 1:0] csr_pmp_addr;
	wire [(PMPNumRegions * 6) - 1:0] csr_pmp_cfg;
	wire [2:0] csr_pmp_mseccfg;
	wire [0:2] pmp_req_err;
	wire data_req_out;
	wire csr_save_if;
	wire csr_save_id;
	wire csr_restore_mret_id;
	wire csr_restore_dret_id;
	wire csr_save_cause;
	wire csr_mtvec_init;
	wire [31:0] csr_mtvec;
	wire [31:0] csr_mtval;
	wire csr_mstatus_tw;
	wire [1:0] priv_mode_id;
	wire [1:0] priv_mode_lsu;
	wire debug_mode;
	wire [2:0] debug_cause;
	wire debug_csr_save;
	wire debug_single_step;
	wire debug_ebreakm;
	wire debug_ebreaku;
	wire trigger_match;
	wire instr_id_done;
	wire perf_instr_ret_wb;
	wire perf_instr_ret_compressed_wb;
	wire perf_iside_wait;
	wire perf_dside_wait;
	wire perf_wfi_wait;
	wire perf_div_wait;
	wire perf_jump;
	wire perf_branch;
	wire perf_tbranch;
	wire perf_load;
	wire perf_store;
	wire illegal_insn_id;
	wire unused_illegal_insn_id;
	assign core_busy_o = (ctrl_busy | if_busy) | lsu_busy;
	localparam [31:0] cve2_pkg_PMP_I = 0;
	localparam [31:0] cve2_pkg_PMP_I2 = 1;
	cve2_if_stage if_stage_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.boot_addr_i(boot_addr_i),
		.req_i(instr_req_gated),
		.instr_req_o(instr_req_o),
		.instr_addr_o(instr_addr_o),
		.instr_gnt_i(instr_gnt_i),
		.instr_rvalid_i(instr_rvalid_i),
		.instr_rdata_i(instr_rdata_i),
		.instr_err_i(instr_err_i),
		.instr_valid_id_o(instr_valid_id),
		.instr_new_id_o(instr_new_id),
		.instr_rdata_id_o(instr_rdata_id),
		.instr_rdata_alu_id_o(instr_rdata_alu_id),
		.instr_rdata_c_id_o(instr_rdata_c_id),
		.instr_is_compressed_id_o(instr_is_compressed_id),
		.instr_fetch_err_o(instr_fetch_err),
		.instr_fetch_err_plus2_o(instr_fetch_err_plus2),
		.illegal_c_insn_id_o(illegal_c_insn_id),
		.pc_if_o(pc_if),
		.pc_id_o(pc_id),
		.pmp_err_if_i(pmp_req_err[cve2_pkg_PMP_I]),
		.pmp_err_if_plus2_i(pmp_req_err[cve2_pkg_PMP_I2]),
		.instr_valid_clear_i(instr_valid_clear),
		.pc_set_i(pc_set),
		.pc_mux_i(pc_mux_id),
		.exc_pc_mux_i(exc_pc_mux_id),
		.exc_cause(exc_cause),
		.branch_target_ex_i(branch_target_ex),
		.csr_mepc_i(csr_mepc),
		.csr_depc_i(csr_depc),
		.csr_mtvec_i(csr_mtvec),
		.csr_mtvec_init_o(csr_mtvec_init),
		.dm_halt_addr_i(dm_halt_addr_i),
		.dm_exception_addr_i(dm_exception_addr_i),
		.id_in_ready_i(id_in_ready),
		.if_busy_o(if_busy)
	);
	assign perf_iside_wait = id_in_ready & ~instr_valid_id;
	assign instr_req_gated = instr_req_int;
	cve2_id_stage #(
		.RV32E(RV32E),
		.RV32M(RV32M),
		.RV32B(RV32B),
		.XInterface(XInterface)
	) id_stage_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.fetch_enable_i(fetch_enable_i),
		.ctrl_busy_o(ctrl_busy),
		.illegal_insn_o(illegal_insn_id),
		.instr_valid_i(instr_valid_id),
		.instr_rdata_i(instr_rdata_id),
		.instr_rdata_alu_i(instr_rdata_alu_id),
		.instr_rdata_c_i(instr_rdata_c_id),
		.instr_is_compressed_i(instr_is_compressed_id),
		.branch_decision_i(branch_decision),
		.instr_first_cycle_id_o(instr_first_cycle_id),
		.instr_valid_clear_o(instr_valid_clear),
		.id_in_ready_o(id_in_ready),
		.instr_req_o(instr_req_int),
		.pc_set_o(pc_set),
		.pc_mux_o(pc_mux_id),
		.exc_pc_mux_o(exc_pc_mux_id),
		.exc_cause_o(exc_cause),
		.instr_fetch_err_i(instr_fetch_err),
		.instr_fetch_err_plus2_i(instr_fetch_err_plus2),
		.illegal_c_insn_i(illegal_c_insn_id),
		.pc_id_i(pc_id),
		.ex_valid_i(ex_valid),
		.lsu_resp_valid_i(lsu_resp_valid),
		.alu_operator_ex_o(alu_operator_ex),
		.alu_operand_a_ex_o(alu_operand_a_ex),
		.alu_operand_b_ex_o(alu_operand_b_ex),
		.imd_val_q_ex_o(imd_val_q_ex),
		.imd_val_d_ex_i(imd_val_d_ex),
		.imd_val_we_ex_i(imd_val_we_ex),
		.mult_en_ex_o(mult_en_ex),
		.div_en_ex_o(div_en_ex),
		.mult_sel_ex_o(mult_sel_ex),
		.div_sel_ex_o(div_sel_ex),
		.multdiv_operator_ex_o(multdiv_operator_ex),
		.multdiv_signed_mode_ex_o(multdiv_signed_mode_ex),
		.multdiv_operand_a_ex_o(multdiv_operand_a_ex),
		.multdiv_operand_b_ex_o(multdiv_operand_b_ex),
		.csr_access_o(csr_access),
		.csr_op_o(csr_op),
		.csr_op_en_o(csr_op_en),
		.csr_save_if_o(csr_save_if),
		.csr_save_id_o(csr_save_id),
		.csr_restore_mret_id_o(csr_restore_mret_id),
		.csr_restore_dret_id_o(csr_restore_dret_id),
		.csr_save_cause_o(csr_save_cause),
		.csr_mtval_o(csr_mtval),
		.priv_mode_i(priv_mode_id),
		.csr_mstatus_tw_i(csr_mstatus_tw),
		.illegal_csr_insn_i(illegal_csr_insn_id),
		.lsu_req_o(lsu_req),
		.lsu_we_o(lsu_we),
		.lsu_type_o(lsu_type),
		.lsu_sign_ext_o(lsu_sign_ext),
		.lsu_wdata_o(lsu_wdata),
		.lsu_addr_incr_req_i(lsu_addr_incr_req),
		.lsu_addr_last_i(lsu_addr_last),
		.lsu_load_err_i(lsu_load_err),
		.lsu_store_err_i(lsu_store_err),
		.hart_id_i(hart_id_i),
		.x_issue_valid_o(x_issue_valid_o),
		.x_issue_ready_i(x_issue_ready_i),
		.x_issue_req_o(x_issue_req_o),
		.x_issue_resp_i(x_issue_resp_i),
		.x_register_o(x_register_o),
		.x_commit_valid_o(x_commit_valid_o),
		.x_commit_o(x_commit_o),
		.x_result_valid_i(x_result_valid_i),
		.x_result_ready_o(x_result_ready_o),
		.x_result_i(x_result_i),
		.csr_mstatus_mie_i(csr_mstatus_mie),
		.irq_pending_i(irq_pending_o),
		.irqs_i(irqs),
		.irq_nm_i(irq_nm_i),
		.nmi_mode_o(nmi_mode),
		.debug_mode_o(debug_mode),
		.debug_cause_o(debug_cause),
		.debug_csr_save_o(debug_csr_save),
		.debug_req_i(debug_req_i),
		.debug_single_step_i(debug_single_step),
		.debug_ebreakm_i(debug_ebreakm),
		.debug_ebreaku_i(debug_ebreaku),
		.trigger_match_i(trigger_match),
		.result_ex_i(result_ex),
		.csr_rdata_i(csr_rdata),
		.rf_raddr_a_o(rf_raddr_a),
		.rf_rdata_a_i(rf_rdata_a),
		.rf_raddr_b_o(rf_raddr_b),
		.rf_rdata_b_i(rf_rdata_b),
		.rf_raddr_c_o(rf_raddr_c),
		.rf_rdata_c_i(rf_rdata_c),
		.rf_ren_a_o(rf_ren_a),
		.rf_ren_b_o(rf_ren_b),
		.rf_ren_c_o(rf_ren_c),
		.rf_waddr_id_o(rf_waddr_id),
		.rf_wdata_id_o(rf_wdata_id),
		.rf_we_id_o(rf_we_id),
		.en_wb_o(en_wb),
		.instr_perf_count_id_o(instr_perf_count_id),
		.perf_jump_o(perf_jump),
		.perf_branch_o(perf_branch),
		.perf_tbranch_o(perf_tbranch),
		.perf_dside_wait_o(perf_dside_wait),
		.perf_wfi_wait_o(perf_wfi_wait),
		.perf_div_wait_o(perf_div_wait),
		.instr_id_done_o(instr_id_done)
	);
	assign unused_illegal_insn_id = illegal_insn_id;
	cve2_ex_block #(
		.RV32M(RV32M),
		.RV32B(RV32B)
	) ex_block_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.alu_operator_i(alu_operator_ex),
		.alu_operand_a_i(alu_operand_a_ex),
		.alu_operand_b_i(alu_operand_b_ex),
		.alu_instr_first_cycle_i(instr_first_cycle_id),
		.multdiv_operator_i(multdiv_operator_ex),
		.mult_en_i(mult_en_ex),
		.div_en_i(div_en_ex),
		.mult_sel_i(mult_sel_ex),
		.div_sel_i(div_sel_ex),
		.multdiv_signed_mode_i(multdiv_signed_mode_ex),
		.multdiv_operand_a_i(multdiv_operand_a_ex),
		.multdiv_operand_b_i(multdiv_operand_b_ex),
		.imd_val_we_o(imd_val_we_ex),
		.imd_val_d_o(imd_val_d_ex),
		.imd_val_q_i(imd_val_q_ex),
		.alu_adder_result_ex_o(alu_adder_result_ex),
		.result_ex_o(result_ex),
		.branch_target_o(branch_target_ex),
		.branch_decision_o(branch_decision),
		.ex_valid_o(ex_valid)
	);
	localparam [31:0] cve2_pkg_PMP_D = 2;
	assign data_req_o = data_req_out & ~pmp_req_err[cve2_pkg_PMP_D];
	assign lsu_resp_err = lsu_load_err | lsu_store_err;
	cve2_load_store_unit load_store_unit_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.data_req_o(data_req_out),
		.data_gnt_i(data_gnt_i),
		.data_rvalid_i(data_rvalid_i),
		.data_err_i(data_err_i),
		.data_pmp_err_i(pmp_req_err[cve2_pkg_PMP_D]),
		.data_addr_o(data_addr_o),
		.data_we_o(data_we_o),
		.data_be_o(data_be_o),
		.data_wdata_o(data_wdata_o),
		.data_rdata_i(data_rdata_i),
		.lsu_we_i(lsu_we),
		.lsu_type_i(lsu_type),
		.lsu_wdata_i(lsu_wdata),
		.lsu_sign_ext_i(lsu_sign_ext),
		.lsu_rdata_o(rf_wdata_lsu),
		.lsu_rdata_valid_o(rf_we_lsu),
		.lsu_req_i(lsu_req),
		.adder_result_ex_i(alu_adder_result_ex),
		.addr_incr_req_o(lsu_addr_incr_req),
		.addr_last_o(lsu_addr_last),
		.lsu_resp_valid_o(lsu_resp_valid),
		.load_err_o(lsu_load_err),
		.store_err_o(lsu_store_err),
		.busy_o(lsu_busy),
		.perf_load_o(perf_load),
		.perf_store_o(perf_store)
	);
	cve2_wb wb_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.en_wb_i(en_wb),
		.instr_is_compressed_id_i(instr_is_compressed_id),
		.instr_perf_count_id_i(instr_perf_count_id),
		.perf_instr_ret_wb_o(perf_instr_ret_wb),
		.perf_instr_ret_compressed_wb_o(perf_instr_ret_compressed_wb),
		.rf_waddr_id_i(rf_waddr_id),
		.rf_wdata_id_i(rf_wdata_id),
		.rf_we_id_i(rf_we_id),
		.rf_wdata_lsu_i(rf_wdata_lsu),
		.rf_we_lsu_i(rf_we_lsu),
		.rf_waddr_wb_o(rf_waddr_wb),
		.rf_wdata_wb_o(rf_wdata_wb),
		.rf_we_wb_o(rf_we_wb),
		.lsu_resp_valid_i(lsu_resp_valid),
		.lsu_resp_err_i(lsu_resp_err)
	);
	assign crash_dump_o[127-:32] = pc_id;
	assign crash_dump_o[95-:32] = pc_if;
	assign crash_dump_o[63-:32] = lsu_addr_last;
	assign crash_dump_o[31-:32] = csr_mepc;
	assign debug_halted_o = debug_mode;
	cve2_register_file_ff #(
		.RV32E(RV32E),
		.DataWidth(32),
		.WordZeroVal(32'h00000000),
		.XInterface(XInterface)
	) register_file_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.test_en_i(test_en_i),
		.raddr_a_i(rf_raddr_a),
		.rdata_a_o(rf_rdata_a),
		.raddr_b_i(rf_raddr_b),
		.rdata_b_o(rf_rdata_b),
		.raddr_c_i(rf_raddr_c),
		.rdata_c_o(rf_rdata_c),
		.waddr_a_i(rf_waddr_wb),
		.wdata_a_i(rf_wdata_wb),
		.we_a_i(rf_we_wb)
	);
	assign csr_wdata = alu_operand_a_ex;
	function automatic [11:0] sv2v_cast_12;
		input reg [11:0] inp;
		sv2v_cast_12 = inp;
	endfunction
	assign csr_addr = sv2v_cast_12((csr_access ? alu_operand_b_ex[11:0] : 12'b000000000000));
	cve2_cs_registers #(
		.DbgTriggerEn(DbgTriggerEn),
		.DbgHwBreakNum(DbgHwBreakNum),
		.MHPMCounterNum(MHPMCounterNum),
		.MHPMCounterWidth(MHPMCounterWidth),
		.PMPEnable(PMPEnable),
		.PMPGranularity(PMPGranularity),
		.PMPNumRegions(PMPNumRegions),
		.RV32E(RV32E),
		.RV32M(RV32M),
		.RV32B(RV32B)
	) cs_registers_i(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.hart_id_i(hart_id_i),
		.priv_mode_id_o(priv_mode_id),
		.priv_mode_lsu_o(priv_mode_lsu),
		.csr_mtvec_o(csr_mtvec),
		.csr_mtvec_init_i(csr_mtvec_init),
		.boot_addr_i(boot_addr_i),
		.csr_access_i(csr_access),
		.csr_addr_i(csr_addr),
		.csr_wdata_i(csr_wdata),
		.csr_op_i(csr_op),
		.csr_op_en_i(csr_op_en),
		.csr_rdata_o(csr_rdata),
		.irq_software_i(irq_software_i),
		.irq_timer_i(irq_timer_i),
		.irq_external_i(irq_external_i),
		.irq_fast_i(irq_fast_i),
		.nmi_mode_i(nmi_mode),
		.irq_pending_o(irq_pending_o),
		.irqs_o(irqs),
		.csr_mstatus_mie_o(csr_mstatus_mie),
		.csr_mstatus_tw_o(csr_mstatus_tw),
		.csr_mepc_o(csr_mepc),
		.csr_pmp_cfg_o(csr_pmp_cfg),
		.csr_pmp_addr_o(csr_pmp_addr),
		.csr_pmp_mseccfg_o(csr_pmp_mseccfg),
		.csr_depc_o(csr_depc),
		.debug_mode_i(debug_mode),
		.debug_cause_i(debug_cause),
		.debug_csr_save_i(debug_csr_save),
		.debug_single_step_o(debug_single_step),
		.debug_ebreakm_o(debug_ebreakm),
		.debug_ebreaku_o(debug_ebreaku),
		.trigger_match_o(trigger_match),
		.pc_if_i(pc_if),
		.pc_id_i(pc_id),
		.csr_save_if_i(csr_save_if),
		.csr_save_id_i(csr_save_id),
		.csr_restore_mret_i(csr_restore_mret_id),
		.csr_restore_dret_i(csr_restore_dret_id),
		.csr_save_cause_i(csr_save_cause),
		.csr_mcause_i(exc_cause),
		.csr_mtval_i(csr_mtval),
		.illegal_csr_insn_o(illegal_csr_insn_id),
		.instr_ret_i(perf_instr_ret_wb),
		.instr_ret_compressed_i(perf_instr_ret_compressed_wb),
		.iside_wait_i(perf_iside_wait),
		.jump_i(perf_jump),
		.branch_i(perf_branch),
		.branch_taken_i(perf_tbranch),
		.mem_load_i(perf_load),
		.mem_store_i(perf_store),
		.dside_wait_i(perf_dside_wait),
		.wfi_wait_i(perf_wfi_wait),
		.div_wait_i(perf_div_wait)
	);
	generate
		if (PMPEnable) begin : g_pmp
			wire [101:0] pmp_req_addr;
			wire [5:0] pmp_req_type;
			wire [5:0] pmp_priv_lvl;
			assign pmp_req_addr[68+:34] = {2'b00, pc_if};
			assign pmp_req_type[4+:2] = 2'b00;
			assign pmp_priv_lvl[4+:2] = priv_mode_id;
			assign pmp_req_addr[34+:34] = {2'b00, pc_if + 32'd2};
			assign pmp_req_type[2+:2] = 2'b00;
			assign pmp_priv_lvl[2+:2] = priv_mode_id;
			assign pmp_req_addr[0+:34] = {2'b00, data_addr_o[31:0]};
			assign pmp_req_type[0+:2] = (data_we_o ? 2'b01 : 2'b10);
			assign pmp_priv_lvl[0+:2] = priv_mode_lsu;
			cve2_pmp #(
				.PMPGranularity(PMPGranularity),
				.PMPNumChan(PMP_NUM_CHAN),
				.PMPNumRegions(PMPNumRegions)
			) pmp_i(
				.clk_i(clk_i),
				.rst_ni(rst_ni),
				.csr_pmp_cfg_i(csr_pmp_cfg),
				.csr_pmp_addr_i(csr_pmp_addr),
				.csr_pmp_mseccfg_i(csr_pmp_mseccfg),
				.priv_mode_i(pmp_priv_lvl),
				.pmp_req_addr_i(pmp_req_addr),
				.pmp_req_type_i(pmp_req_type),
				.pmp_req_err_o(pmp_req_err)
			);
		end
		else begin : g_no_pmp
			wire [1:0] unused_priv_lvl_ls;
			wire [(PMPNumRegions * 34) - 1:0] unused_csr_pmp_addr;
			wire [(PMPNumRegions * 6) - 1:0] unused_csr_pmp_cfg;
			wire [2:0] unused_csr_pmp_mseccfg;
			assign unused_priv_lvl_ls = priv_mode_lsu;
			assign unused_csr_pmp_addr = csr_pmp_addr;
			assign unused_csr_pmp_cfg = csr_pmp_cfg;
			assign unused_csr_pmp_mseccfg = csr_pmp_mseccfg;
			assign pmp_req_err[cve2_pkg_PMP_I] = 1'b0;
			assign pmp_req_err[cve2_pkg_PMP_I2] = 1'b0;
			assign pmp_req_err[cve2_pkg_PMP_D] = 1'b0;
		end
	endgenerate
	wire unused_instr_new_id;
	wire unused_instr_id_done;
	assign unused_instr_id_done = instr_id_done;
	assign unused_instr_new_id = instr_new_id;
endmodule
module cve2_clock_gate (
	clk_i,
	en_i,
	scan_cg_en_i,
	clk_o
);
	input wire clk_i;
	input wire en_i;
	input wire scan_cg_en_i;
	output wire clk_o;
	sky130_fd_sc_hd__dlclkp_1 u_icg(
		.CLK(clk_i),
		.GATE(en_i | scan_cg_en_i),
		.GCLK(clk_o)
	);
endmodule
module cve2_top (
	clk_i,
	rst_ni,
	test_en_i,
	ram_cfg_i,
	hart_id_i,
	boot_addr_i,
	instr_req_o,
	instr_gnt_i,
	instr_rvalid_i,
	instr_addr_o,
	instr_rdata_i,
	instr_err_i,
	data_req_o,
	data_gnt_i,
	data_rvalid_i,
	data_we_o,
	data_be_o,
	data_addr_o,
	data_wdata_o,
	data_rdata_i,
	data_err_i,
	x_issue_valid_o,
	x_issue_ready_i,
	x_issue_req_o,
	x_issue_resp_i,
	x_register_o,
	x_commit_valid_o,
	x_commit_o,
	x_result_valid_i,
	x_result_ready_o,
	x_result_i,
	irq_software_i,
	irq_timer_i,
	irq_external_i,
	irq_fast_i,
	irq_nm_i,
	debug_req_i,
	debug_halted_o,
	dm_halt_addr_i,
	dm_exception_addr_i,
	crash_dump_o,
	fetch_enable_i,
	core_sleep_o
);
	parameter [31:0] MHPMCounterNum = 10;
	parameter [31:0] MHPMCounterWidth = 40;
	parameter [0:0] RV32E = 1'b0;
	parameter integer RV32M = 32'sd2;
	parameter [0:0] XInterface = 1'b0;
	input wire clk_i;
	input wire rst_ni;
	input wire test_en_i;
	input wire [9:0] ram_cfg_i;
	input wire [31:0] hart_id_i;
	input wire [31:0] boot_addr_i;
	output wire instr_req_o;
	input wire instr_gnt_i;
	input wire instr_rvalid_i;
	output wire [31:0] instr_addr_o;
	input wire [31:0] instr_rdata_i;
	input wire instr_err_i;
	output wire data_req_o;
	input wire data_gnt_i;
	input wire data_rvalid_i;
	output wire data_we_o;
	output wire [3:0] data_be_o;
	output wire [31:0] data_addr_o;
	output wire [31:0] data_wdata_o;
	input wire [31:0] data_rdata_i;
	input wire data_err_i;
	output wire x_issue_valid_o;
	input wire x_issue_ready_i;
	localparam [31:0] cve2_pkg_X_HARTID_WIDTH = 32;
	localparam [31:0] cve2_pkg_X_ID_WIDTH = 4;
	output wire [67:0] x_issue_req_o;
	localparam [31:0] cve2_pkg_X_DUAL_READ = 0;
	localparam [31:0] cve2_pkg_X_NUM_RS = 3;
	localparam [31:0] cve2_pkg_X_DUAL_WRITE = 0;
	input wire [(2 + (cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ)) - 1:0] x_issue_resp_i;
	localparam [31:0] cve2_pkg_X_RFR_WIDTH = 32;
	output wire [(((cve2_pkg_X_HARTID_WIDTH + cve2_pkg_X_ID_WIDTH) + (cve2_pkg_X_NUM_RS * cve2_pkg_X_RFR_WIDTH)) + (cve2_pkg_X_NUM_RS + cve2_pkg_X_DUAL_READ)) - 1:0] x_register_o;
	output wire x_commit_valid_o;
	output wire [(cve2_pkg_X_HARTID_WIDTH + cve2_pkg_X_ID_WIDTH) + 0:0] x_commit_o;
	input wire x_result_valid_i;
	output wire x_result_ready_o;
	localparam [31:0] cve2_pkg_X_RFW_WIDTH = 32;
	input wire [((cve2_pkg_X_HARTID_WIDTH + cve2_pkg_X_ID_WIDTH) + cve2_pkg_X_RFW_WIDTH) + 5:0] x_result_i;
	input wire irq_software_i;
	input wire irq_timer_i;
	input wire irq_external_i;
	input wire [15:0] irq_fast_i;
	input wire irq_nm_i;
	input wire debug_req_i;
	output wire debug_halted_o;
	input wire [31:0] dm_halt_addr_i;
	input wire [31:0] dm_exception_addr_i;
	output wire [127:0] crash_dump_o;
	input wire fetch_enable_i;
	output wire core_sleep_o;
	localparam [31:0] NumAddrScrRounds = 0;
	localparam [0:0] PMPEnable = 1'b0;
	localparam [31:0] PMPGranularity = 0;
	localparam [31:0] PMPNumRegions = 4;
	localparam [0:0] DbgTriggerEn = 1'b1;
	localparam [31:0] DbgHwBreakNum = 1;
	localparam integer RV32B = 32'sd0;
	wire clk;
	wire core_busy_d;
	reg core_busy_q;
	wire clock_en;
	wire fetch_enable_d;
	reg fetch_enable_q;
	wire irq_pending;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni) begin
			core_busy_q <= 1'b0;
			fetch_enable_q <= 1'b0;
		end
		else begin
			core_busy_q <= core_busy_d;
			fetch_enable_q <= fetch_enable_d;
		end
	assign clock_en = fetch_enable_q & (((core_busy_q | debug_req_i) | irq_pending) | irq_nm_i);
	assign core_sleep_o = fetch_enable_q & !clock_en;
	assign fetch_enable_d = (fetch_enable_i ? 1'b1 : fetch_enable_q);
	cve2_clock_gate core_clock_gate_i(
		.clk_i(clk_i),
		.en_i(clock_en),
		.scan_cg_en_i(test_en_i),
		.clk_o(clk)
	);
	cve2_core #(
		.PMPEnable(PMPEnable),
		.PMPGranularity(PMPGranularity),
		.PMPNumRegions(PMPNumRegions),
		.MHPMCounterNum(MHPMCounterNum),
		.MHPMCounterWidth(MHPMCounterWidth),
		.RV32E(RV32E),
		.RV32M(RV32M),
		.RV32B(RV32B),
		.DbgTriggerEn(DbgTriggerEn),
		.DbgHwBreakNum(DbgHwBreakNum),
		.XInterface(XInterface)
	) u_cve2_core(
		.clk_i(clk),
		.rst_ni(rst_ni),
		.test_en_i(test_en_i),
		.hart_id_i(hart_id_i),
		.boot_addr_i(boot_addr_i),
		.instr_req_o(instr_req_o),
		.instr_gnt_i(instr_gnt_i),
		.instr_rvalid_i(instr_rvalid_i),
		.instr_addr_o(instr_addr_o),
		.instr_rdata_i(instr_rdata_i),
		.instr_err_i(instr_err_i),
		.data_req_o(data_req_o),
		.data_gnt_i(data_gnt_i),
		.data_rvalid_i(data_rvalid_i),
		.data_we_o(data_we_o),
		.data_be_o(data_be_o),
		.data_addr_o(data_addr_o),
		.data_wdata_o(data_wdata_o),
		.data_rdata_i(data_rdata_i),
		.data_err_i(data_err_i),
		.x_issue_valid_o(x_issue_valid_o),
		.x_issue_ready_i(x_issue_ready_i),
		.x_issue_req_o(x_issue_req_o),
		.x_issue_resp_i(x_issue_resp_i),
		.x_register_o(x_register_o),
		.x_commit_valid_o(x_commit_valid_o),
		.x_commit_o(x_commit_o),
		.x_result_valid_i(x_result_valid_i),
		.x_result_ready_o(x_result_ready_o),
		.x_result_i(x_result_i),
		.irq_software_i(irq_software_i),
		.irq_timer_i(irq_timer_i),
		.irq_external_i(irq_external_i),
		.irq_fast_i(irq_fast_i),
		.irq_nm_i(irq_nm_i),
		.irq_pending_o(irq_pending),
		.debug_req_i(debug_req_i),
		.debug_halted_o(debug_halted_o),
		.dm_halt_addr_i(dm_halt_addr_i),
		.dm_exception_addr_i(dm_exception_addr_i),
		.crash_dump_o(crash_dump_o),
		.fetch_enable_i(fetch_enable_q),
		.core_busy_o(core_busy_d)
	);
	wire [9:0] unused_ram_cfg;
	wire unused_ram_inputs;
	assign unused_ram_cfg = ram_cfg_i;
	assign unused_ram_inputs = |NumAddrScrRounds;
endmodule
module bsg_mem_1r1w_sync_mask_write_bit (
	clk_i,
	reset_i,
	w_v_i,
	w_mask_i,
	w_addr_i,
	w_data_i,
	r_v_i,
	r_addr_i,
	r_data_o
);
	parameter signed [31:0] width_p = 1;
	parameter signed [31:0] els_p = 1;
	parameter signed [31:0] read_write_same_addr_p = 0;
	parameter signed [31:0] addr_width_lp = (els_p > 1 ? $clog2(els_p) : 1);
	input wire clk_i;
	input wire reset_i;
	input wire w_v_i;
	input wire [width_p - 1:0] w_mask_i;
	input wire [addr_width_lp - 1:0] w_addr_i;
	input wire [width_p - 1:0] w_data_i;
	input wire r_v_i;
	input wire [addr_width_lp - 1:0] r_addr_i;
	output reg [width_p - 1:0] r_data_o;
	reg [width_p - 1:0] mem [0:els_p - 1];
	always @(posedge clk_i) begin
		if (w_v_i) begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < width_p; i = i + 1)
				if (w_mask_i[i])
					mem[w_addr_i][i] <= w_data_i[i];
		end
		if (r_v_i)
			r_data_o <= mem[r_addr_i];
	end
	wire unused;
	assign unused = reset_i;
endmodule
module iocore_usb_ram256x16 (
	clk_i,
	we_i,
	waddr_i,
	wmask_i,
	wdata_i,
	re_i,
	raddr_i,
	rdata_o
);
	input wire clk_i;
	input wire we_i;
	input wire [7:0] waddr_i;
	input wire [15:0] wmask_i;
	input wire [15:0] wdata_i;
	input wire re_i;
	input wire [7:0] raddr_i;
	output wire [15:0] rdata_o;
	bsg_mem_1r1w_sync_mask_write_bit #(
		.width_p(16),
		.els_p(256)
	) u_mem(
		.clk_i(clk_i),
		.reset_i(1'b0),
		.w_v_i(we_i),
		.w_mask_i(wmask_i),
		.w_addr_i(waddr_i),
		.w_data_i(wdata_i),
		.r_v_i(re_i),
		.r_addr_i(raddr_i),
		.r_data_o(rdata_o)
	);
endmodule
module SB_RAM40_4K (
	RDATA,
	RCLK,
	RCLKE,
	RE,
	RADDR,
	WCLK,
	WCLKE,
	WE,
	WADDR,
	MASK,
	WDATA
);
	parameter integer WRITE_MODE = 0;
	parameter integer READ_MODE = 0;
	parameter INIT_FILE = "";
	parameter [255:0] INIT_0 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
	parameter [255:0] INIT_1 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
	parameter [255:0] INIT_2 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
	parameter [255:0] INIT_3 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
	parameter [255:0] INIT_4 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
	parameter [255:0] INIT_5 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
	parameter [255:0] INIT_6 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
	parameter [255:0] INIT_7 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
	parameter [255:0] INIT_8 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
	parameter [255:0] INIT_9 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
	parameter [255:0] INIT_A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
	parameter [255:0] INIT_B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
	parameter [255:0] INIT_C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
	parameter [255:0] INIT_D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
	parameter [255:0] INIT_E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
	parameter [255:0] INIT_F = 256'h0000000000000000000000000000000000000000000000000000000000000000;
	output wire [15:0] RDATA;
	input wire RCLK;
	input wire RCLKE;
	input wire RE;
	input wire [10:0] RADDR;
	input wire WCLK;
	input wire WCLKE;
	input wire WE;
	input wire [10:0] WADDR;
	input wire [15:0] MASK;
	input wire [15:0] WDATA;
	function automatic [15:0] lane_mask;
		input integer mode;
		input [10:0] a;
		input [15:0] m0;
		case (mode)
			0: lane_mask = m0;
			1: lane_mask = ~(16'b0101010101010101 << a[8]);
			2: lane_mask = ~(16'b0001000100010001 << a[9:8]);
			default: lane_mask = ~(16'b0000000100000001 << a[10:8]);
		endcase
	endfunction
	wire [15:0] wmask = lane_mask(WRITE_MODE, WADDR, MASK);
	wire [15:0] rmask = lane_mask(READ_MODE, RADDR, 16'h0000);
	wire [15:0] wd = (WRITE_MODE == 0 ? WDATA : (WRITE_MODE == 1 ? {{2 {WDATA[14]}}, {2 {WDATA[12]}}, {2 {WDATA[10]}}, {2 {WDATA[8]}}, {2 {WDATA[6]}}, {2 {WDATA[4]}}, {2 {WDATA[2]}}, {2 {WDATA[0]}}} : (WRITE_MODE == 2 ? {{4 {WDATA[13]}}, {4 {WDATA[9]}}, {4 {WDATA[5]}}, {4 {WDATA[1]}}} : {{8 {WDATA[11]}}, {8 {WDATA[3]}}})));
	reg [15:0] rq;
	reg [15:0] rmask_q;
	wire [15:0] word;
	function automatic [15:0] usb_trans_mc;
		input reg [7:0] a;
		case (a)
			8'h00: usb_trans_mc = 16'h1000;
			8'h01: usb_trans_mc = 16'h80f0;
			8'h02: usb_trans_mc = 16'h600f;
			8'h03: usb_trans_mc = 16'h8010;
			8'h04: usb_trans_mc = 16'h1002;
			8'h05: usb_trans_mc = 16'h83f9;
			8'h06: usb_trans_mc = 16'h93f1;
			8'h07: usb_trans_mc = 16'h8efd;
			8'h08: usb_trans_mc = 16'h8000;
			8'h09: usb_trans_mc = 16'h8300;
			8'h0a: usb_trans_mc = 16'h8300;
			8'h0b: usb_trans_mc = 16'h8300;
			8'h0c: usb_trans_mc = 16'h1004;
			8'h0d: usb_trans_mc = 16'h8a71;
			8'h0e: usb_trans_mc = 16'h8070;
			8'h0f: usb_trans_mc = 16'ha211;
			8'h10: usb_trans_mc = 16'ha3ee;
			8'h11: usb_trans_mc = 16'h1006;
			8'h12: usb_trans_mc = 16'ha1f3;
			8'h13: usb_trans_mc = 16'he3f2;
			8'h14: usb_trans_mc = 16'h4013;
			8'h15: usb_trans_mc = 16'h8600;
			8'h16: usb_trans_mc = 16'h8600;
			8'h17: usb_trans_mc = 16'h8600;
			8'h18: usb_trans_mc = 16'h1000;
			8'h19: usb_trans_mc = 16'h8640;
			8'h1a: usb_trans_mc = 16'h6004;
			8'h1b: usb_trans_mc = 16'h7046;
			8'h1c: usb_trans_mc = 16'h1000;
			8'h1d: usb_trans_mc = 16'h87b0;
			8'h1e: usb_trans_mc = 16'h8910;
			8'h1f: usb_trans_mc = 16'h1002;
			8'h20: usb_trans_mc = 16'hc9f2;
			8'h21: usb_trans_mc = 16'h20a7;
			8'h22: usb_trans_mc = 16'h5000;
			8'h23: usb_trans_mc = 16'h8000;
			8'h24: usb_trans_mc = 16'h5008;
			8'h25: usb_trans_mc = 16'h8000;
			8'h26: usb_trans_mc = 16'h8a00;
			8'h27: usb_trans_mc = 16'h8a00;
			8'h28: usb_trans_mc = 16'h1006;
			8'h29: usb_trans_mc = 16'hcdf2;
			8'h2a: usb_trans_mc = 16'h4003;
			8'h2b: usb_trans_mc = 16'h8b00;
			8'h2c: usb_trans_mc = 16'h1000;
			8'h2d: usb_trans_mc = 16'h8b40;
			8'h2e: usb_trans_mc = 16'h6004;
			8'h2f: usb_trans_mc = 16'h20a6;
			8'h30: usb_trans_mc = 16'h5000;
			8'h31: usb_trans_mc = 16'h8000;
			8'h32: usb_trans_mc = 16'h8d00;
			8'h33: usb_trans_mc = 16'h8d00;
			8'h34: usb_trans_mc = 16'h3000;
			8'h35: usb_trans_mc = 16'h4003;
			8'h36: usb_trans_mc = 16'h8000;
			8'h37: usb_trans_mc = 16'h8e00;
			8'h38: usb_trans_mc = 16'h1004;
			8'h39: usb_trans_mc = 16'he5e6;
			8'h3a: usb_trans_mc = 16'h1006;
			8'h3b: usb_trans_mc = 16'he5f2;
			8'h3c: usb_trans_mc = 16'h7046;
			8'h3d: usb_trans_mc = 16'h9000;
			8'h3e: usb_trans_mc = 16'h9000;
			8'h3f: usb_trans_mc = 16'h9000;
			8'h40: usb_trans_mc = 16'h1000;
			8'h41: usb_trans_mc = 16'h90b0;
			8'h42: usb_trans_mc = 16'h9210;
			8'h43: usb_trans_mc = 16'h1002;
			8'h44: usb_trans_mc = 16'hd2f3;
			8'h45: usb_trans_mc = 16'h21a7;
			8'h46: usb_trans_mc = 16'h5000;
			8'h47: usb_trans_mc = 16'ha400;
			8'h48: usb_trans_mc = 16'h20ae;
			8'h49: usb_trans_mc = 16'h5009;
			8'h4a: usb_trans_mc = 16'h8000;
			8'h4b: usb_trans_mc = 16'h9300;
			8'h4c: usb_trans_mc = 16'h1004;
			8'h4d: usb_trans_mc = 16'h9c71;
			8'h4e: usb_trans_mc = 16'h8070;
			8'h4f: usb_trans_mc = 16'h9911;
			8'h50: usb_trans_mc = 16'h99ee;
			8'h51: usb_trans_mc = 16'h1006;
			8'h52: usb_trans_mc = 16'hd9f2;
			8'h53: usb_trans_mc = 16'h7046;
			8'h54: usb_trans_mc = 16'h1000;
			8'h55: usb_trans_mc = 16'h95b0;
			8'h56: usb_trans_mc = 16'h9a10;
			8'h57: usb_trans_mc = 16'h1003;
			8'h58: usb_trans_mc = 16'hda73;
			8'h59: usb_trans_mc = 16'h1004;
			8'h5a: usb_trans_mc = 16'ha211;
			8'h5b: usb_trans_mc = 16'ha3ee;
			8'h5c: usb_trans_mc = 16'h1003;
			8'h5d: usb_trans_mc = 16'ha4fb;
			8'h5e: usb_trans_mc = 16'h1006;
			8'h5f: usb_trans_mc = 16'he362;
			8'h60: usb_trans_mc = 16'ha1f3;
			8'h61: usb_trans_mc = 16'h20a7;
			8'h62: usb_trans_mc = 16'h5000;
			8'h63: usb_trans_mc = 16'ha400;
			8'h64: usb_trans_mc = 16'h3000;
			8'h65: usb_trans_mc = 16'h9500;
			8'h66: usb_trans_mc = 16'h9a00;
			8'h67: usb_trans_mc = 16'h9a00;
			8'h68: usb_trans_mc = 16'h1006;
			8'h69: usb_trans_mc = 16'hc062;
			8'h6a: usb_trans_mc = 16'h20ae;
			8'h6b: usb_trans_mc = 16'h5009;
			8'h6c: usb_trans_mc = 16'h8000;
			8'h6d: usb_trans_mc = 16'h9c00;
			8'h6e: usb_trans_mc = 16'h9c00;
			8'h6f: usb_trans_mc = 16'h9c00;
			8'h70: usb_trans_mc = 16'h1006;
			8'h71: usb_trans_mc = 16'he0f2;
			8'h72: usb_trans_mc = 16'h7046;
			8'h73: usb_trans_mc = 16'h9d00;
			8'h74: usb_trans_mc = 16'h1000;
			8'h75: usb_trans_mc = 16'h9db0;
			8'h76: usb_trans_mc = 16'h9f10;
			8'h77: usb_trans_mc = 16'h1002;
			8'h78: usb_trans_mc = 16'hdf73;
			8'h79: usb_trans_mc = 16'h20a6;
			8'h7a: usb_trans_mc = 16'h5000;
			8'h7b: usb_trans_mc = 16'h8000;
			8'h7c: usb_trans_mc = 16'h20ae;
			8'h7d: usb_trans_mc = 16'h5009;
			8'h7e: usb_trans_mc = 16'h8000;
			8'h7f: usb_trans_mc = 16'ha000;
			8'h80: usb_trans_mc = 16'ha500;
			8'h81: usb_trans_mc = 16'ha100;
			8'h82: usb_trans_mc = 16'ha100;
			8'h83: usb_trans_mc = 16'ha100;
			8'h84: usb_trans_mc = 16'h20a6;
			8'h85: usb_trans_mc = 16'h5000;
			8'h86: usb_trans_mc = 16'ha200;
			8'h87: usb_trans_mc = 16'ha200;
			8'h88: usb_trans_mc = 16'h3000;
			8'h89: usb_trans_mc = 16'h400e;
			8'h8a: usb_trans_mc = 16'h8000;
			8'h8b: usb_trans_mc = 16'ha300;
			8'h8c: usb_trans_mc = 16'h3000;
			8'h8d: usb_trans_mc = 16'h400a;
			8'h8e: usb_trans_mc = 16'h8000;
			8'h8f: usb_trans_mc = 16'ha400;
			8'h90: usb_trans_mc = 16'h3000;
			8'h91: usb_trans_mc = 16'h4002;
			8'h92: usb_trans_mc = 16'h8000;
			8'h93: usb_trans_mc = 16'ha500;
			8'h94: usb_trans_mc = 16'h3000;
			8'h95: usb_trans_mc = 16'h7046;
			8'h96: usb_trans_mc = 16'ha600;
			8'h97: usb_trans_mc = 16'ha600;
			8'h98: usb_trans_mc = 16'h1000;
			8'h99: usb_trans_mc = 16'ha6b0;
			8'h9a: usb_trans_mc = 16'h8000;
			default: usb_trans_mc = 16'h0000;
		endcase
	endfunction
	generate
		if (INIT_FILE == "usb_trans_mc.hex") begin : g_rom
			reg [15:0] rom_q;
			always @(posedge RCLK)
				if (RE && RCLKE)
					rom_q <= usb_trans_mc(RADDR[7:0]);
			assign word = rom_q;
		end
		else begin : g_ram
			iocore_usb_ram256x16 u_ram(
				.clk_i(RCLK),
				.we_i(WE && WCLKE),
				.waddr_i(WADDR[7:0]),
				.wmask_i(~wmask),
				.wdata_i(wd),
				.re_i(RE && RCLKE),
				.raddr_i(RADDR[7:0]),
				.rdata_o(word)
			);
		end
	endgenerate
	always @(posedge RCLK)
		if (RE && RCLKE)
			rmask_q <= rmask;
	always @(*) rq = word & ~rmask_q;
	assign RDATA = (READ_MODE == 0 ? rq : (READ_MODE == 1 ? {1'b0, |rq[15:14], 1'b0, |rq[13:12], 1'b0, |rq[11:10], 1'b0, |rq[9:8], 1'b0, |rq[7:6], 1'b0, |rq[5:4], 1'b0, |rq[3:2], 1'b0, |rq[1:0]} : (READ_MODE == 2 ? {2'b00, |rq[15:12], 3'b000, |rq[11:8], 3'b000, |rq[7:4], 3'b000, |rq[3:0], 1'b0} : {4'b0000, |rq[15:8], 7'b0000000, |rq[7:0], 3'b000})));
	wire unused = (WCLK ^ |INIT_0) ^ |INIT_F;
endmodule
module iocore_usb_pad (
	pad_io,
	oe_i,
	out_i,
	in_o
);
	inout wire pad_io;
	input wire oe_i;
	input wire out_i;
	output wire in_o;
	assign pad_io = (oe_i ? out_i : 1'bz);
	assign in_o = pad_io;
endmodule
module SB_IO (
	PACKAGE_PIN,
	LATCH_INPUT_VALUE,
	CLOCK_ENABLE,
	INPUT_CLK,
	OUTPUT_CLK,
	OUTPUT_ENABLE,
	D_OUT_0,
	D_OUT_1,
	D_IN_0,
	D_IN_1
);
	parameter [5:0] PIN_TYPE = 6'b110100;
	parameter [0:0] PULLUP = 1'b0;
	parameter [0:0] NEG_TRIGGER = 1'b0;
	parameter IO_STANDARD = "SB_LVCMOS";
	inout wire PACKAGE_PIN;
	input wire LATCH_INPUT_VALUE;
	input wire CLOCK_ENABLE;
	input wire INPUT_CLK;
	input wire OUTPUT_CLK;
	input wire OUTPUT_ENABLE;
	input wire D_OUT_0;
	input wire D_OUT_1;
	output wire D_IN_0;
	output wire D_IN_1;
	reg din0;
	reg din1;
	reg dout0;
	reg oe;
	wire pin_in;
	iocore_usb_pad u_pad(
		.pad_io(PACKAGE_PIN),
		.oe_i(oe),
		.out_i(dout0),
		.in_o(pin_in)
	);
	always @(posedge INPUT_CLK)
		if (CLOCK_ENABLE)
			din0 <= pin_in;
	always @(negedge INPUT_CLK)
		if (CLOCK_ENABLE)
			din1 <= pin_in;
	always @(posedge OUTPUT_CLK)
		if (CLOCK_ENABLE) begin
			dout0 <= D_OUT_0;
			oe <= OUTPUT_ENABLE;
		end
	assign D_IN_0 = din0;
	assign D_IN_1 = din1;
	wire unused = LATCH_INPUT_VALUE ^ D_OUT_1;
endmodule
`default_nettype none
module usb_crc (
	in_bit,
	in_first,
	in_valid,
	crc,
	crc_match,
	clk,
	rst
);
	parameter integer WIDTH = 5;
	parameter POLY = 5'b00011;
	parameter MATCH = 5'b00000;
	input wire in_bit;
	input wire in_first;
	input wire in_valid;
	output wire [WIDTH - 1:0] crc;
	output wire crc_match;
	input wire clk;
	input wire rst;
	reg [WIDTH - 1:0] state;
	wire [WIDTH - 1:0] state_fb_mux;
	wire [WIDTH - 1:0] state_upd_mux;
	wire [WIDTH - 1:0] state_nxt;
	assign state_fb_mux = state & {WIDTH {~in_first}};
	assign state_upd_mux = (state_fb_mux[WIDTH - 1] == in_bit ? POLY : 0);
	assign state_nxt = {state_fb_mux[WIDTH - 2:0], 1'b1} ^ state_upd_mux;
	always @(posedge clk)
		if (in_valid)
			state <= state_nxt;
	assign crc_match = state == ~MATCH;
	genvar _gv_i_34;
	generate
		for (_gv_i_34 = 0; _gv_i_34 < WIDTH; _gv_i_34 = _gv_i_34 + 1) begin : genblk1
			localparam i = _gv_i_34;
			assign crc[i] = state[(WIDTH - 1) - i];
		end
	endgenerate
endmodule
`default_nettype none
module usb_ep_buf (
	rd_addr_0,
	rd_data_1,
	rd_en_0,
	rd_clk,
	wr_addr_0,
	wr_data_0,
	wr_en_0,
	wr_clk
);
	parameter TARGET = "ICE40";
	parameter integer RWIDTH = 8;
	parameter integer WWIDTH = 8;
	parameter integer AWIDTH = 11;
	parameter integer ARW = AWIDTH - $clog2(RWIDTH / 8);
	parameter integer AWW = AWIDTH - $clog2(WWIDTH / 8);
	input wire [ARW - 1:0] rd_addr_0;
	output wire [RWIDTH - 1:0] rd_data_1;
	input wire rd_en_0;
	input wire rd_clk;
	input wire [AWW - 1:0] wr_addr_0;
	input wire [WWIDTH - 1:0] wr_data_0;
	input wire wr_en_0;
	input wire wr_clk;
	localparam WRITE_MODE = 3 - $clog2(WWIDTH / 8);
	localparam READ_MODE = 3 - $clog2(RWIDTH / 8);
	function [7:0] ram_rd_map8;
		input [15:0] rdata;
		ram_rd_map8 = {rdata[14], rdata[12], rdata[10], rdata[8], rdata[6], rdata[4], rdata[2], rdata[0]};
	endfunction
	function [15:0] ram_wr_map8;
		input [7:0] wdata;
		ram_wr_map8 = {1'b0, wdata[7], 1'b0, wdata[6], 1'b0, wdata[5], 1'b0, wdata[4], 1'b0, wdata[3], 1'b0, wdata[2], 1'b0, wdata[1], 1'b0, wdata[0]};
	endfunction
	function [3:0] ram_rd_map4;
		input [15:0] rdata;
		ram_rd_map4 = {rdata[13], rdata[9], rdata[5], rdata[1]};
	endfunction
	function [15:0] ram_wr_map4;
		input [3:0] wdata;
		ram_wr_map4 = {2'h0, wdata[3], 3'h0, wdata[2], 3'h0, wdata[1], 3'h0, wdata[0], 1'b0};
	endfunction
	function [1:0] ram_rd_map2;
		input [15:0] rdata;
		ram_rd_map2 = {rdata[11], rdata[3]};
	endfunction
	function [15:0] ram_wr_map2;
		input [1:0] wdata;
		ram_wr_map2 = {4'h0, wdata[1], 7'h00, wdata[0], 3'h0};
	endfunction
	function [63:0] ram_rd_shuffle_64;
		input [63:0] src;
		ram_rd_shuffle_64 = {src[63], src[55], src[47], src[39], src[31], src[23], src[15], src[7], src[59], src[51], src[43], src[35], src[27], src[19], src[11], src[3], src[61], src[53], src[45], src[37], src[29], src[21], src[13], src[5], src[57], src[49], src[41], src[33], src[25], src[17], src[9], src[1], src[62], src[54], src[46], src[38], src[30], src[22], src[14], src[6], src[58], src[50], src[42], src[34], src[26], src[18], src[10], src[2], src[60], src[52], src[44], src[36], src[28], src[20], src[12], src[4], src[56], src[48], src[40], src[32], src[24], src[16], src[8], src[0]};
	endfunction
	function [31:0] ram_rd_shuffle_32;
		input [31:0] src;
		ram_rd_shuffle_32 = {src[31], src[27], src[23], src[19], src[15], src[11], src[7], src[3], src[29], src[25], src[21], src[17], src[13], src[9], src[5], src[1], src[30], src[26], src[22], src[18], src[14], src[10], src[6], src[2], src[28], src[24], src[20], src[16], src[12], src[8], src[4], src[0]};
	endfunction
	function [15:0] ram_rd_shuffle_16;
		input [15:0] src;
		ram_rd_shuffle_16 = {src[15], src[13], src[11], src[9], src[7], src[5], src[3], src[1], src[14], src[12], src[10], src[8], src[6], src[4], src[2], src[0]};
	endfunction
	function [63:0] ram_wr_shuffle_64;
		input [63:0] src;
		ram_wr_shuffle_64 = {src[63], src[31], src[47], src[15], src[55], src[23], src[39], src[7], src[62], src[30], src[46], src[14], src[54], src[22], src[38], src[6], src[61], src[29], src[45], src[13], src[53], src[21], src[37], src[5], src[60], src[28], src[44], src[12], src[52], src[20], src[36], src[4], src[59], src[27], src[43], src[11], src[51], src[19], src[35], src[3], src[58], src[26], src[42], src[10], src[50], src[18], src[34], src[2], src[57], src[25], src[41], src[9], src[49], src[17], src[33], src[1], src[56], src[24], src[40], src[8], src[48], src[16], src[32], src[0]};
	endfunction
	function [31:0] ram_wr_shuffle_32;
		input [31:0] src;
		ram_wr_shuffle_32 = {src[31], src[15], src[23], src[7], src[30], src[14], src[22], src[6], src[29], src[13], src[21], src[5], src[28], src[12], src[20], src[4], src[27], src[11], src[19], src[3], src[26], src[10], src[18], src[2], src[25], src[9], src[17], src[1], src[24], src[8], src[16], src[0]};
	endfunction
	function [15:0] ram_wr_shuffle_16;
		input [15:0] src;
		ram_wr_shuffle_16 = {src[15], src[7], src[14], src[6], src[13], src[5], src[12], src[4], src[11], src[3], src[10], src[2], src[9], src[1], src[8], src[0]};
	endfunction
	initial begin
		$display("READ_MODE  : %d", READ_MODE);
		$display("WRITE_MODE : %d", WRITE_MODE);
	end
	wire [10:0] ram_raddr;
	wire [10:0] ram_waddr;
	wire [RWIDTH - 1:0] rd_data_1_ram;
	wire [WWIDTH - 1:0] wr_data_0_ram;
	genvar _gv_i_35;
	assign ram_raddr[7:0] = rd_addr_0[ARW - 1:ARW - 8];
	assign ram_waddr[7:0] = wr_addr_0[AWW - 1:AWW - 8];
	generate
		if (READ_MODE == 3) begin : genblk1
			assign ram_raddr[10:8] = {rd_addr_0[0], rd_addr_0[1], rd_addr_0[2]};
		end
		else if (READ_MODE == 2) begin : genblk1
			assign ram_raddr[10:8] = {1'b0, rd_addr_0[0], rd_addr_0[1]};
		end
		else if (READ_MODE == 1) begin : genblk1
			assign ram_raddr[10:8] = {2'b00, rd_addr_0[0]};
		end
		else begin : genblk1
			assign ram_raddr[10:8] = 3'b000;
		end
		if (WRITE_MODE == 3) begin : genblk2
			assign ram_waddr[10:8] = {wr_addr_0[0], wr_addr_0[1], wr_addr_0[2]};
		end
		else if (WRITE_MODE == 2) begin : genblk2
			assign ram_waddr[10:8] = {1'b0, wr_addr_0[0], wr_addr_0[1]};
		end
		else if (WRITE_MODE == 1) begin : genblk2
			assign ram_waddr[10:8] = {2'b00, wr_addr_0[0]};
		end
		else begin : genblk2
			assign ram_waddr[10:8] = 3'b000;
		end
		if (READ_MODE == 0) begin : genblk3
			assign rd_data_1 = ram_rd_shuffle_64(rd_data_1_ram);
		end
		else if (READ_MODE == 1) begin : genblk3
			assign rd_data_1 = ram_rd_shuffle_32(rd_data_1_ram);
		end
		else if (READ_MODE == 2) begin : genblk3
			assign rd_data_1 = ram_rd_shuffle_16(rd_data_1_ram);
		end
		else begin : genblk3
			assign rd_data_1 = rd_data_1_ram;
		end
		if (WRITE_MODE == 0) begin : genblk4
			assign wr_data_0_ram = ram_wr_shuffle_64(wr_data_0);
		end
		else if (WRITE_MODE == 1) begin : genblk4
			assign wr_data_0_ram = ram_wr_shuffle_32(wr_data_0);
		end
		else if (WRITE_MODE == 2) begin : genblk4
			assign wr_data_0_ram = ram_wr_shuffle_16(wr_data_0);
		end
		else begin : genblk4
			assign wr_data_0_ram = wr_data_0;
		end
		for (_gv_i_35 = 0; _gv_i_35 < 4; _gv_i_35 = _gv_i_35 + 1) begin : block
			localparam i = _gv_i_35;
			wire [15:0] ram_rdata;
			wire [15:0] ram_wdata;
			SB_RAM40_4K #(
				.WRITE_MODE(WRITE_MODE),
				.READ_MODE(READ_MODE)
			) ram_I(
				.RDATA(ram_rdata),
				.RCLK(rd_clk),
				.RCLKE(rd_en_0),
				.RE(1'b1),
				.RADDR(ram_raddr),
				.WCLK(wr_clk),
				.WCLKE(wr_en_0),
				.WE(1'b1),
				.WADDR(ram_waddr),
				.MASK(16'h0000),
				.WDATA(ram_wdata)
			);
			if (READ_MODE == 3) begin : genblk1
				assign rd_data_1_ram[i * 2+:2] = ram_rd_map2(ram_rdata);
			end
			else if (READ_MODE == 2) begin : genblk1
				assign rd_data_1_ram[i * 4+:4] = ram_rd_map4(ram_rdata);
			end
			else if (READ_MODE == 1) begin : genblk1
				assign rd_data_1_ram[i * 8+:8] = ram_rd_map8(ram_rdata);
			end
			else begin : genblk1
				assign rd_data_1_ram[i * 16+:16] = ram_rdata;
			end
			if (WRITE_MODE == 3) begin : genblk2
				assign ram_wdata = ram_wr_map2(wr_data_0_ram[i * 2+:2]);
			end
			else if (WRITE_MODE == 2) begin : genblk2
				assign ram_wdata = ram_wr_map4(wr_data_0_ram[i * 4+:4]);
			end
			else if (WRITE_MODE == 1) begin : genblk2
				assign ram_wdata = ram_wr_map8(wr_data_0_ram[i * 8+:8]);
			end
			else begin : genblk2
				assign ram_wdata = wr_data_0_ram[i * 16+:16];
			end
		end
	endgenerate
endmodule
`default_nettype none
module usb_ep_status (
	p_addr_0,
	p_read_0,
	p_zero_0,
	p_write_0,
	p_din_0,
	p_dout_3,
	s_addr_0,
	s_read_0,
	s_zero_0,
	s_write_0,
	s_din_0,
	s_dout_3,
	s_ready_0,
	clk,
	rst
);
	input wire [7:0] p_addr_0;
	input wire p_read_0;
	input wire p_zero_0;
	input wire p_write_0;
	input wire [15:0] p_din_0;
	output reg [15:0] p_dout_3;
	input wire [7:0] s_addr_0;
	input wire s_read_0;
	input wire s_zero_0;
	input wire s_write_0;
	input wire [15:0] s_din_0;
	output reg [15:0] s_dout_3;
	output wire s_ready_0;
	input wire clk;
	input wire rst;
	wire s_ready_0_i;
	reg [7:0] addr_1;
	reg [15:0] din_1;
	reg we_1;
	reg p_read_1;
	reg p_zero_1;
	reg s_read_1;
	reg s_zero_1;
	wire [15:0] dout_2;
	reg p_read_2;
	reg p_zero_2;
	reg s_read_2;
	reg s_zero_2;
	assign s_ready_0_i = ~p_read_0 & ~p_write_0;
	assign s_ready_0 = s_ready_0_i;
	always @(posedge clk) begin
		addr_1 <= (p_read_0 | p_write_0 ? p_addr_0 : s_addr_0);
		we_1 <= p_write_0 | (s_write_0 & s_ready_0_i);
		din_1 <= (p_write_0 ? p_din_0 : s_din_0);
		p_read_1 <= p_read_0;
		p_zero_1 <= p_zero_0;
		s_read_1 <= s_read_0 & s_ready_0_i;
		s_zero_1 <= s_zero_0 & s_ready_0_i;
	end
	always @(posedge clk) begin
		p_read_2 <= p_read_1 | p_zero_1;
		p_zero_2 <= p_zero_1;
		s_read_2 <= s_read_1 | s_zero_1;
		s_zero_2 <= s_zero_1;
	end
	always @(posedge clk)
		if (p_read_2)
			p_dout_3 <= (p_zero_2 ? 16'h0000 : dout_2);
	always @(posedge clk)
		if (s_read_2)
			s_dout_3 <= (s_zero_2 ? 16'h0000 : dout_2);
	SB_RAM40_4K #(
		.WRITE_MODE(0),
		.READ_MODE(0)
	) ebr_I(
		.RDATA(dout_2),
		.RADDR({3'b000, addr_1}),
		.RCLK(clk),
		.RCLKE(1'b1),
		.RE(1'b1),
		.WDATA(din_1),
		.WADDR({3'b000, addr_1}),
		.MASK(16'h0000),
		.WCLK(clk),
		.WCLKE(we_1),
		.WE(1'b1)
	);
endmodule
`default_nettype none
module usb_phy (
	pad_dp,
	pad_dn,
	rx_dp,
	rx_dn,
	rx_chg,
	tx_dp,
	tx_dn,
	tx_en,
	clk,
	rst
);
	parameter TARGET = "ICE40";
	inout wire pad_dp;
	inout wire pad_dn;
	output wire rx_dp;
	output wire rx_dn;
	output wire rx_chg;
	input wire tx_dp;
	input wire tx_dn;
	input wire tx_en;
	input wire clk;
	input wire rst;
	wire [1:0] rx_dp_i;
	wire [1:0] rx_dn_i;
	reg [2:0] dp_state;
	reg [2:0] dn_state;
	generate
		if (TARGET == "ICE40") begin : genblk1
			SB_IO #(
				.PIN_TYPE(6'b110100),
				.PULLUP(1'b0),
				.NEG_TRIGGER(1'b0),
				.IO_STANDARD("SB_LVCMOS")
			) io_dp_I(
				.PACKAGE_PIN(pad_dp),
				.CLOCK_ENABLE(1'b1),
				.INPUT_CLK(clk),
				.OUTPUT_CLK(clk),
				.OUTPUT_ENABLE(tx_en),
				.D_OUT_0(tx_dp),
				.D_OUT_1(1'b0),
				.D_IN_0(rx_dp_i[0]),
				.D_IN_1(rx_dp_i[1])
			);
			SB_IO #(
				.PIN_TYPE(6'b110100),
				.PULLUP(1'b0),
				.NEG_TRIGGER(1'b0),
				.IO_STANDARD("SB_LVCMOS")
			) io_dn_I(
				.PACKAGE_PIN(pad_dn),
				.CLOCK_ENABLE(1'b1),
				.INPUT_CLK(clk),
				.OUTPUT_CLK(clk),
				.OUTPUT_ENABLE(tx_en),
				.D_OUT_0(tx_dn),
				.D_OUT_1(1'b0),
				.D_IN_0(rx_dn_i[0]),
				.D_IN_1(rx_dn_i[1])
			);
		end
	endgenerate
	always @(posedge clk or posedge rst)
		if (rst) begin
			dp_state <= 3'b000;
			dn_state <= 3'b000;
		end
		else begin
			case ({dp_state[1:0], rx_dp_i})
				4'b0000: dp_state <= 3'b000;
				4'b0001: dp_state <= 3'b001;
				4'b0010: dp_state <= 3'b001;
				4'b0011: dp_state <= 3'b001;
				4'b0100: dp_state <= 3'b000;
				4'b0101: dp_state <= 3'b001;
				4'b0110: dp_state <= 3'b001;
				4'b0111: dp_state <= 3'b111;
				4'b1000: dp_state <= 3'b100;
				4'b1001: dp_state <= 3'b010;
				4'b1010: dp_state <= 3'b010;
				4'b1011: dp_state <= 3'b011;
				4'b1100: dp_state <= 3'b010;
				4'b1101: dp_state <= 3'b010;
				4'b1110: dp_state <= 3'b010;
				4'b1111: dp_state <= 3'b011;
				default: dp_state <= 3'bxxx;
			endcase
			case ({dn_state[1:0], rx_dn_i})
				4'b0000: dn_state <= 3'b000;
				4'b0001: dn_state <= 3'b001;
				4'b0010: dn_state <= 3'b001;
				4'b0011: dn_state <= 3'b001;
				4'b0100: dn_state <= 3'b000;
				4'b0101: dn_state <= 3'b001;
				4'b0110: dn_state <= 3'b001;
				4'b0111: dn_state <= 3'b111;
				4'b1000: dn_state <= 3'b100;
				4'b1001: dn_state <= 3'b010;
				4'b1010: dn_state <= 3'b010;
				4'b1011: dn_state <= 3'b011;
				4'b1100: dn_state <= 3'b010;
				4'b1101: dn_state <= 3'b010;
				4'b1110: dn_state <= 3'b010;
				4'b1111: dn_state <= 3'b011;
				default: dn_state <= 3'bxxx;
			endcase
		end
	assign rx_dp = dp_state[1];
	assign rx_dn = dn_state[1];
	assign rx_chg = dp_state[2] | dn_state[2];
endmodule
`default_nettype none
module usb_rx_ll (
	phy_rx_dp,
	phy_rx_dn,
	phy_rx_chg,
	ll_sym,
	ll_bit,
	ll_valid,
	ll_eop,
	ll_sync,
	ll_bs_skip,
	ll_bs_err,
	clk,
	rst
);
	input wire phy_rx_dp;
	input wire phy_rx_dn;
	input wire phy_rx_chg;
	output wire [1:0] ll_sym;
	output wire ll_bit;
	output wire ll_valid;
	output wire ll_eop;
	output wire ll_sync;
	output wire ll_bs_skip;
	output wire ll_bs_err;
	input wire clk;
	input wire rst;
	reg samp_active;
	(* keep = "true" *) wire samp_sync;
	reg [2:0] samp_cnt;
	wire [1:0] samp_sym_0;
	reg samp_valid_0;
	(* keep = "true" *) wire dec_sym_same_0;
	(* keep = "true" *) wire dec_sym_se_0;
	reg [2:0] dec_eop_state_1;
	reg [3:0] dec_sync_state_1;
	reg [3:0] dec_rep_state_1;
	reg [1:0] dec_sym_1 = 2'b00;
	reg dec_bit_1;
	reg dec_valid_1;
	wire dec_eop_1;
	wire dec_sync_1;
	wire [2:0] dec_rep_1;
	reg dec_bs_skip_1;
	wire dec_bs_err_1;
	always @(posedge clk or posedge rst)
		if (rst)
			samp_active <= 1'b0;
		else
			samp_active <= (samp_active | phy_rx_chg) & ~(dec_valid_1 & (dec_eop_1 | dec_bs_err_1));
	assign samp_sync = ~samp_active | (~samp_cnt[2] && phy_rx_chg);
	always @(posedge clk)
		if (samp_sync)
			samp_cnt <= 3'b101;
		else
			case (samp_cnt)
				3'b000: samp_cnt <= 3'b011;
				3'b001: samp_cnt <= 3'b000;
				3'b010: samp_cnt <= 3'b001;
				3'b011: samp_cnt <= 3'b010;
				3'b100: samp_cnt <= 3'b011;
				3'b101: samp_cnt <= 3'b100;
				3'b110: samp_cnt <= 3'b101;
				3'b111: samp_cnt <= 3'b110;
				default: samp_cnt <= 3'bxxx;
			endcase
	always @(posedge clk) samp_valid_0 <= (samp_active & (samp_cnt[1:0] == 2'b01)) & ~samp_valid_0;
	assign samp_sym_0 = {phy_rx_dp, phy_rx_dn};
	assign dec_sym_same_0 = samp_sym_0 == dec_sym_1;
	assign dec_sym_se_0 = ~^samp_sym_0;
	always @(posedge clk)
		if (samp_valid_0) begin
			dec_sym_1 <= samp_sym_0;
			dec_bit_1 <= ((samp_sym_0[0] ^ samp_sym_0[1]) & (dec_sym_1[0] ^ dec_sym_1[1])) & ~(samp_sym_0[1] ^ dec_sym_1[1]);
		end
	always @(posedge clk) dec_valid_1 <= samp_valid_0;
	always @(posedge clk)
		if (samp_valid_0)
			case ({dec_eop_state_1[1:0], samp_sym_0})
				4'b0000: dec_eop_state_1 <= 3'b001;
				4'b0100: dec_eop_state_1 <= 3'b010;
				4'b1000: dec_eop_state_1 <= 3'b010;
				4'b1010: dec_eop_state_1 <= 3'b111;
				default: dec_eop_state_1 <= 3'b000;
			endcase
	assign dec_eop_1 = dec_eop_state_1[2];
	always @(posedge clk)
		if (samp_valid_0) begin
			if (dec_sym_se_0)
				dec_sync_state_1 <= 4'b0000;
			else
				casez ({dec_sync_state_1[2:0], samp_sym_0[1]})
					4'b0000: dec_sync_state_1 <= 4'b0001;
					4'b0011: dec_sync_state_1 <= 4'b0010;
					4'b0100: dec_sync_state_1 <= 4'b0011;
					4'b0111: dec_sync_state_1 <= 4'b0100;
					4'b1000: dec_sync_state_1 <= 4'b0101;
					4'b1011: dec_sync_state_1 <= 4'b0110;
					4'b1100: dec_sync_state_1 <= 4'b0111;
					4'b1110: dec_sync_state_1 <= 4'b1001;
					4'bzzz0: dec_sync_state_1 <= 4'b0001;
					default: dec_sync_state_1 <= 4'b0000;
				endcase
		end
	assign dec_sync_1 = dec_sync_state_1[3];
	always @(posedge clk)
		if (samp_valid_0) begin
			if (dec_sym_same_0 == 1'b0)
				dec_rep_state_1 <= 4'b0000;
			else
				case (dec_rep_state_1[2:0])
					3'b000: dec_rep_state_1 <= 4'b0001;
					3'b001: dec_rep_state_1 <= 4'b0010;
					3'b010: dec_rep_state_1 <= 4'b0011;
					3'b011: dec_rep_state_1 <= 4'b0100;
					3'b100: dec_rep_state_1 <= 4'b0101;
					3'b101: dec_rep_state_1 <= 4'b0110;
					3'b110: dec_rep_state_1 <= 4'b1111;
					3'b111: dec_rep_state_1 <= 4'b1111;
					default: dec_rep_state_1 <= 4'bxxxx;
				endcase
		end
	assign dec_bs_err_1 = dec_rep_state_1[3];
	assign dec_rep_1 = dec_rep_state_1[2:0];
	always @(posedge clk)
		if (samp_valid_0)
			dec_bs_skip_1 <= dec_rep_state_1[2:0] == 3'b110;
	assign ll_sym = dec_sym_1;
	assign ll_bit = dec_bit_1;
	assign ll_valid = dec_valid_1;
	assign ll_eop = dec_eop_1;
	assign ll_sync = dec_sync_1;
	assign ll_bs_skip = dec_bs_skip_1;
	assign ll_bs_err = dec_bs_err_1;
endmodule
`default_nettype none
module usb_rx_pkt (
	ll_sym,
	ll_bit,
	ll_valid,
	ll_eop,
	ll_sync,
	ll_bs_skip,
	ll_bs_err,
	pkt_start,
	pkt_done_ok,
	pkt_done_err,
	pkt_pid,
	pkt_is_sof,
	pkt_is_token,
	pkt_is_data,
	pkt_is_handshake,
	pkt_frameno,
	pkt_addr,
	pkt_endp,
	pkt_data,
	pkt_data_stb,
	inhibit,
	clk,
	rst
);
	input wire [1:0] ll_sym;
	input wire ll_bit;
	input wire ll_valid;
	input wire ll_eop;
	input wire ll_sync;
	input wire ll_bs_skip;
	input wire ll_bs_err;
	output reg pkt_start;
	output reg pkt_done_ok;
	output reg pkt_done_err;
	output wire [3:0] pkt_pid;
	output wire pkt_is_sof;
	output wire pkt_is_token;
	output wire pkt_is_data;
	output wire pkt_is_handshake;
	output wire [10:0] pkt_frameno;
	output wire [6:0] pkt_addr;
	output wire [3:0] pkt_endp;
	output wire [7:0] pkt_data;
	output reg pkt_data_stb;
	input wire inhibit;
	input wire clk;
	input wire rst;
	localparam SYM_SE0 = 2'b00;
	localparam SYM_SE1 = 2'b11;
	localparam SYM_J = 2'b10;
	localparam SYM_K = 2'b01;
	localparam PID_OUT = 4'b0001;
	localparam PID_IN = 4'b1001;
	localparam PID_SOF = 4'b0101;
	localparam PID_SETUP = 4'b1101;
	localparam PID_DATA0 = 4'b0011;
	localparam PID_DATA1 = 4'b1011;
	localparam PID_ACK = 4'b0010;
	localparam PID_NAK = 4'b1010;
	localparam PID_STALL = 4'b1110;
	localparam PID_INVAL = 4'b0000;
	localparam ST_IDLE = 0;
	localparam ST_PID = 1;
	localparam ST_PID_CHECK = 2;
	localparam ST_ERROR = 3;
	localparam ST_TOKEN_1 = 4;
	localparam ST_TOKEN_2 = 5;
	localparam ST_WAIT_EOP = 6;
	localparam ST_DATA = 7;
	reg [3:0] state_nxt;
	reg [3:0] state;
	reg state_prev_idle;
	reg state_prev_error;
	wire llu_bit_stb;
	wire llu_byte_stb;
	wire [7:0] data_nxt;
	reg [7:0] data;
	reg [3:0] bit_cnt;
	reg bit_eop_ok;
	wire bit_last;
	wire crc_in_bit;
	wire crc_in_valid;
	reg crc_in_first;
	reg crc_cap;
	wire crc5_match;
	reg crc5_ok;
	wire crc16_match;
	reg crc16_ok;
	wire pid_cap;
	reg pid_cap_r;
	reg pid_valid;
	reg [3:0] pid;
	reg pid_is_sof;
	reg pid_is_token;
	reg pid_is_data;
	reg pid_is_handshake;
	reg [10:0] token_data;
	always @(*) begin
		state_nxt = state;
		case (state)
			ST_IDLE:
				if ((ll_valid && ll_sync) && ~inhibit)
					state_nxt = ST_PID;
			ST_PID:
				if (llu_byte_stb)
					state_nxt = ST_PID_CHECK;
			ST_PID_CHECK: begin
				state_nxt = ST_ERROR;
				if (pid_valid) begin
					if (pid_is_sof)
						state_nxt = ST_TOKEN_1;
					else if (pid_is_token)
						state_nxt = ST_TOKEN_1;
					else if (pid_is_data)
						state_nxt = ST_DATA;
					else if (pid_is_handshake)
						state_nxt = ST_WAIT_EOP;
				end
			end
			ST_ERROR:
				if (ll_valid && (ll_eop || (ll_bs_err && (ll_sym == SYM_J))))
					state_nxt = ST_IDLE;
			ST_TOKEN_1:
				if (ll_valid && ll_eop)
					state_nxt = ST_ERROR;
				else if (llu_byte_stb)
					state_nxt = ST_TOKEN_2;
			ST_TOKEN_2:
				if (ll_valid && ll_eop)
					state_nxt = ST_ERROR;
				else if (llu_byte_stb)
					state_nxt = ST_WAIT_EOP;
			ST_WAIT_EOP:
				if (ll_valid && ll_eop)
					state_nxt = (bit_eop_ok & (crc5_ok | pid_is_handshake) ? ST_IDLE : ST_ERROR);
				else if (llu_byte_stb)
					state_nxt = ST_ERROR;
			ST_DATA:
				if (ll_valid) begin
					if (ll_eop)
						state_nxt = (bit_eop_ok & crc16_ok ? ST_IDLE : ST_ERROR);
					else if (ll_bs_err)
						state_nxt = ST_ERROR;
				end
		endcase
	end
	always @(posedge clk or posedge rst)
		if (rst)
			state <= ST_IDLE;
		else
			state <= state_nxt;
	always @(posedge clk) begin
		state_prev_idle <= state == ST_IDLE;
		state_prev_error <= state == ST_ERROR;
	end
	assign llu_bit_stb = ll_valid & ~ll_bs_skip;
	assign llu_byte_stb = (ll_valid & ~ll_bs_skip) & bit_last;
	assign data_nxt = {ll_bit, data[7:1]};
	always @(posedge clk)
		if (llu_bit_stb)
			data <= data_nxt;
	always @(posedge clk)
		if (state == ST_IDLE)
			bit_cnt <= 4'b0110;
		else if (llu_bit_stb)
			bit_cnt <= {1'b0, bit_cnt[2:0]} - 1;
	assign bit_last = bit_cnt[3];
	always @(posedge clk)
		if (state == ST_IDLE)
			bit_eop_ok <= 1'b0;
		else if (llu_bit_stb)
			bit_eop_ok <= bit_cnt[2:1] == 2'b10;
	assign crc_in_bit = ll_bit;
	assign crc_in_valid = llu_bit_stb;
	always @(posedge clk)
		if (state == ST_PID)
			crc_in_first <= 1'b1;
		else if (crc_in_valid)
			crc_in_first <= 1'b0;
	usb_crc #(
		.WIDTH(5),
		.POLY(5'b00101),
		.MATCH(5'b01100)
	) crc_5_I(
		.in_bit(crc_in_bit),
		.in_first(crc_in_first),
		.in_valid(crc_in_valid),
		.crc(),
		.crc_match(crc5_match),
		.clk(clk),
		.rst(rst)
	);
	usb_crc #(
		.WIDTH(16),
		.POLY(16'h8005),
		.MATCH(16'h800d)
	) crc_16_I(
		.in_bit(crc_in_bit),
		.in_first(crc_in_first),
		.in_valid(crc_in_valid),
		.crc(),
		.crc_match(crc16_match),
		.clk(clk),
		.rst(rst)
	);
	always @(posedge clk) crc_cap <= llu_byte_stb;
	always @(posedge clk)
		if (state == ST_IDLE) begin
			crc5_ok <= 1'b0;
			crc16_ok <= 1'b0;
		end
		else if (crc_cap) begin
			crc5_ok <= crc5_match;
			crc16_ok <= crc16_match;
		end
	assign pid_cap = (state == ST_PID) & llu_byte_stb;
	always @(posedge clk)
		if (pid_cap)
			pid_valid <= (data_nxt[3:0] == ~data_nxt[7:4]) && (((((((((data_nxt[3:0] == PID_SOF) || (data_nxt[3:0] == PID_OUT)) || (data_nxt[3:0] == PID_IN)) || (data_nxt[3:0] == PID_SETUP)) || (data_nxt[3:0] == PID_DATA0)) || (data_nxt[3:0] == PID_DATA1)) || (data_nxt[3:0] == PID_ACK)) || (data_nxt[3:0] == PID_NAK)) || (data_nxt[3:0] == PID_STALL));
	always @(posedge clk) pid_cap_r <= pid_cap;
	always @(posedge clk)
		if ((state == ST_PID) && llu_byte_stb) begin
			pid <= data_nxt;
			pid_is_sof <= data_nxt[3:0] == PID_SOF;
			pid_is_token <= ((data_nxt[3:0] == PID_OUT) || (data_nxt[3:0] == PID_IN)) || (data_nxt[3:0] == PID_SETUP);
			pid_is_data <= (data_nxt[3:0] == PID_DATA0) || (data_nxt[3:0] == PID_DATA1);
			pid_is_handshake <= ((data_nxt[3:0] == PID_ACK) || (data_nxt[3:0] == PID_NAK)) || (data_nxt[3:0] == PID_STALL);
		end
	always @(posedge clk)
		if ((state == ST_TOKEN_1) && llu_byte_stb)
			token_data[7:0] <= data_nxt[7:0];
	always @(posedge clk)
		if ((state == ST_TOKEN_2) && llu_byte_stb)
			token_data[10:8] <= data_nxt[2:0];
	always @(posedge clk) pkt_start <= pid_cap_r & pid_valid;
	always @(posedge clk) begin
		pkt_done_ok <= ((state == ST_IDLE) && !state_prev_idle) && !state_prev_error;
		pkt_done_err <= (state == ST_ERROR) && !state_prev_error;
	end
	assign pkt_pid = pid;
	assign pkt_is_sof = pid_is_sof;
	assign pkt_is_token = pid_is_token;
	assign pkt_is_data = pid_is_data;
	assign pkt_is_handshake = pid_is_handshake;
	assign pkt_frameno = token_data;
	assign pkt_addr = token_data[6:0];
	assign pkt_endp = token_data[10:7];
	assign pkt_data = data;
	always @(posedge clk) pkt_data_stb <= (state == ST_DATA) && llu_byte_stb;
endmodule
`default_nettype none
module usb_trans (
	txpkt_start,
	txpkt_done,
	txpkt_pid,
	txpkt_len,
	txpkt_data,
	txpkt_data_ack,
	rxpkt_start,
	rxpkt_done_ok,
	rxpkt_done_err,
	rxpkt_pid,
	rxpkt_is_sof,
	rxpkt_is_token,
	rxpkt_is_data,
	rxpkt_is_handshake,
	rxpkt_frameno,
	rxpkt_addr,
	rxpkt_endp,
	rxpkt_data,
	rxpkt_data_stb,
	buf_tx_addr_0,
	buf_tx_data_1,
	buf_tx_rden_0,
	buf_rx_addr_0,
	buf_rx_data_0,
	buf_rx_wren_0,
	eps_read_0,
	eps_zero_0,
	eps_write_0,
	eps_addr_0,
	eps_wrdata_0,
	eps_rddata_3,
	cr_addr_chk,
	cr_addr,
	evt_data,
	evt_stb,
	cel_state,
	cel_rel,
	cel_ena,
	clk,
	rst
);
	parameter integer ADDR_MATCH = 1;
	output wire txpkt_start;
	input wire txpkt_done;
	output reg [3:0] txpkt_pid;
	output wire [9:0] txpkt_len;
	output wire [7:0] txpkt_data;
	input wire txpkt_data_ack;
	input wire rxpkt_start;
	input wire rxpkt_done_ok;
	input wire rxpkt_done_err;
	input wire [3:0] rxpkt_pid;
	input wire rxpkt_is_sof;
	input wire rxpkt_is_token;
	input wire rxpkt_is_data;
	input wire rxpkt_is_handshake;
	input wire [10:0] rxpkt_frameno;
	input wire [6:0] rxpkt_addr;
	input wire [3:0] rxpkt_endp;
	input wire [7:0] rxpkt_data;
	input wire rxpkt_data_stb;
	output wire [10:0] buf_tx_addr_0;
	input wire [7:0] buf_tx_data_1;
	output wire buf_tx_rden_0;
	output wire [10:0] buf_rx_addr_0;
	output wire [7:0] buf_rx_data_0;
	output wire buf_rx_wren_0;
	output wire eps_read_0;
	output wire eps_zero_0;
	output wire eps_write_0;
	output wire [7:0] eps_addr_0;
	output wire [15:0] eps_wrdata_0;
	input wire [15:0] eps_rddata_3;
	input wire cr_addr_chk;
	input wire [6:0] cr_addr;
	output wire [11:0] evt_data;
	output wire evt_stb;
	output wire cel_state;
	input wire cel_rel;
	input wire cel_ena;
	input wire clk;
	input wire rst;
	localparam SYM_SE0 = 2'b00;
	localparam SYM_SE1 = 2'b11;
	localparam SYM_J = 2'b10;
	localparam SYM_K = 2'b01;
	localparam PID_OUT = 4'b0001;
	localparam PID_IN = 4'b1001;
	localparam PID_SOF = 4'b0101;
	localparam PID_SETUP = 4'b1101;
	localparam PID_DATA0 = 4'b0011;
	localparam PID_DATA1 = 4'b1011;
	localparam PID_ACK = 4'b0010;
	localparam PID_NAK = 4'b1010;
	localparam PID_STALL = 4'b1110;
	localparam PID_INVAL = 4'b0000;
	reg [3:0] mc_a_reg;
	reg mc_rst_n;
	(* keep = "true" *) wire [3:0] mc_match_bits;
	wire mc_match;
	wire mc_jmp;
	wire [7:0] mc_pc;
	reg [7:0] mc_pc_nxt;
	wire [15:0] mc_opcode;
	(* keep = "true" *) wire mc_op_ld;
	(* keep = "true" *) wire mc_op_ep;
	(* keep = "true" *) wire mc_op_zlen;
	(* keep = "true" *) wire mc_op_tx;
	(* keep = "true" *) wire mc_op_notify;
	(* keep = "true" *) wire mc_op_evt_clr;
	(* keep = "true" *) wire mc_op_evt_rto;
	wire [3:0] evt_rst;
	wire [3:0] evt_set;
	reg [3:0] evt;
	reg [3:0] pkt_pid;
	wire rto_now;
	reg [9:0] rto_cnt;
	reg trans_is_setup;
	reg [3:0] trans_endp;
	reg trans_dir;
	reg trans_cel;
	reg [2:0] ep_type;
	reg ep_bd_dual;
	reg ep_bd_ctrl;
	reg ep_bd_idx_cur;
	reg ep_bd_idx_nxt;
	reg ep_data_toggle;
	reg [2:0] bd_state;
	localparam EPFW_IDLE = 4'b0000;
	localparam EPFW_RD_STATUS = 4'b0100;
	localparam EPFW_RD_BD_W0 = 4'b0110;
	localparam EPFW_RD_BD_W1 = 4'b0111;
	localparam EPFW_WR_STATUS = 4'b1000;
	localparam EPFW_WR_BD_W0 = 4'b1010;
	reg [3:0] epfw_state;
	reg [5:0] epfw_cap_dl;
	reg epfw_issue_wb;
	reg cel_state_i;
	reg txpkt_start_i;
	reg [10:0] addr;
	wire addr_inc;
	wire addr_ld;
	reg [10:0] bd_length;
	reg [9:0] xfer_length;
	wire len_ld;
	wire len_bd_dec;
	wire len_xf_inc;
	always @(posedge clk or posedge rst)
		if (rst)
			mc_rst_n <= 1'b0;
		else
			mc_rst_n <= 1'b1;
	assign mc_match_bits = (mc_a_reg[3:0] & mc_opcode[7:4]) ^ mc_opcode[3:0];
	assign mc_match = ~|mc_match_bits;
	assign mc_jmp = (mc_opcode[15] & mc_rst_n) & (mc_match ^ mc_opcode[14]);
	assign mc_pc = (mc_jmp ? {mc_opcode[13:8], 2'b00} : mc_pc_nxt);
	always @(posedge clk or posedge rst)
		if (rst)
			mc_pc_nxt <= 8'h00;
		else
			mc_pc_nxt <= mc_pc + 1;
	SB_RAM40_4K #(
		.INIT_FILE("usb_trans_mc.hex"),
		.WRITE_MODE(0),
		.READ_MODE(0)
	) mc_rom_I(
		.RDATA(mc_opcode),
		.RADDR({3'b000, mc_pc}),
		.RCLK(clk),
		.RCLKE(1'b1),
		.RE(1'b1),
		.WDATA(16'h0000),
		.WADDR(11'h000),
		.MASK(16'h0000),
		.WCLK(1'b0),
		.WCLKE(1'b0),
		.WE(1'b0)
	);
	assign mc_op_ld = mc_opcode[15:12] == 4'b0001;
	assign mc_op_ep = mc_opcode[15:12] == 4'b0010;
	assign mc_op_zlen = mc_opcode[15:12] == 4'b0011;
	assign mc_op_tx = mc_opcode[15:12] == 4'b0100;
	assign mc_op_notify = mc_opcode[15:12] == 4'b0101;
	assign mc_op_evt_clr = mc_opcode[15:12] == 4'b0110;
	assign mc_op_evt_rto = mc_opcode[15:12] == 4'b0111;
	always @(posedge clk)
		if (mc_op_ld)
			casez (mc_opcode[2:1])
				2'b00: mc_a_reg <= evt;
				2'b01: mc_a_reg <= pkt_pid ^ {ep_data_toggle & mc_opcode[0], 3'b000};
				2'b10: mc_a_reg <= {trans_cel, ep_type};
				2'b11: mc_a_reg <= {1'b0, bd_state};
				default: mc_a_reg <= 4'hx;
			endcase
	always @(posedge clk or posedge rst)
		if (rst)
			evt <= 4'h0;
		else
			evt <= (evt & ~evt_rst) | evt_set;
	assign evt_rst = {4 {mc_op_evt_clr}} & mc_opcode[3:0];
	assign evt_set = {rto_now, txpkt_done, rxpkt_done_err, rxpkt_done_ok};
	generate
		if (ADDR_MATCH) begin : genblk1
			always @(posedge clk)
				if (rxpkt_done_ok) begin
					if (rxpkt_is_token & cr_addr_chk)
						pkt_pid <= (rxpkt_addr == cr_addr ? rxpkt_pid : PID_INVAL);
					else
						pkt_pid <= rxpkt_pid;
				end
		end
		else begin : genblk1
			always @(*) pkt_pid = rxpkt_pid;
		end
	endgenerate
	always @(posedge clk or posedge rst)
		if (rst)
			rto_cnt <= 0;
		else if (mc_op_evt_rto)
			rto_cnt <= {2'b01, mc_opcode[7:0]};
		else
			rto_cnt <= {(rto_cnt[9] & rto_cnt[8]) & ~rxpkt_start, rto_cnt[8:0] - rto_cnt[9]};
	assign rto_now = rto_cnt[9] & ~rto_cnt[8];
	assign evt_stb = mc_op_notify;
	assign evt_data = {mc_opcode[3:0], trans_endp, trans_dir, trans_is_setup, ep_bd_idx_cur, 1'b0};
	always @(posedge clk)
		if (rxpkt_done_ok & rxpkt_is_token) begin
			trans_is_setup <= rxpkt_pid == PID_SETUP;
			trans_endp <= rxpkt_endp;
			trans_dir <= rxpkt_pid == PID_IN;
			trans_cel <= cel_state_i;
		end
	always @(posedge clk or posedge rst)
		if (rst)
			epfw_state <= EPFW_IDLE;
		else
			case (epfw_state)
				EPFW_IDLE:
					if (epfw_issue_wb)
						epfw_state <= EPFW_WR_STATUS;
					else if (rxpkt_done_ok & rxpkt_is_token)
						epfw_state <= EPFW_RD_STATUS;
					else if (epfw_cap_dl[1:0] == 2'b01)
						epfw_state <= EPFW_RD_BD_W0;
					else
						epfw_state <= EPFW_IDLE;
				EPFW_RD_STATUS: epfw_state <= EPFW_IDLE;
				EPFW_RD_BD_W0: epfw_state <= EPFW_RD_BD_W1;
				EPFW_RD_BD_W1: epfw_state <= EPFW_IDLE;
				EPFW_WR_STATUS: epfw_state <= EPFW_WR_BD_W0;
				EPFW_WR_BD_W0: epfw_state <= EPFW_IDLE;
				default: epfw_state <= EPFW_IDLE;
			endcase
	assign eps_zero_0 = 1'b0;
	assign eps_read_0 = epfw_state[2];
	assign eps_write_0 = epfw_state[3];
	assign eps_addr_0 = {trans_endp, trans_dir, epfw_state[1], epfw_state[1] & ep_bd_idx_cur, epfw_state[0]};
	assign eps_wrdata_0 = (epfw_state[1] ? {bd_state, trans_is_setup, 2'b00, xfer_length[9:0]} : {8'h00, ep_data_toggle, ep_bd_idx_nxt, ep_bd_ctrl, ep_bd_dual, 1'b0, ep_type});
	always @(posedge clk or posedge rst)
		if (rst)
			epfw_cap_dl <= 6'b000000;
		else
			epfw_cap_dl <= {epfw_state[1], epfw_state[2] & ~^epfw_state[1:0], epfw_cap_dl[5:2]};
	always @(posedge clk) begin
		if (epfw_cap_dl[1:0] == 2'b01) begin
			ep_type <= eps_rddata_3[2:0];
			ep_bd_dual <= eps_rddata_3[4];
			ep_bd_ctrl <= eps_rddata_3[5];
			ep_bd_idx_cur <= (eps_rddata_3[5] ? trans_is_setup : eps_rddata_3[6]);
			ep_bd_idx_nxt <= eps_rddata_3[6];
			ep_data_toggle <= eps_rddata_3[7] & ~trans_is_setup;
		end
		else begin
			ep_data_toggle <= ep_data_toggle ^ (mc_op_ep & mc_opcode[0]);
			ep_bd_idx_nxt <= ep_bd_idx_nxt ^ ((mc_op_ep & mc_opcode[1]) & ep_bd_dual);
		end
		if (epfw_cap_dl[1:0] == 2'b10)
			bd_state <= eps_rddata_3[15:13];
		else
			bd_state <= (mc_op_ep & mc_opcode[2] ? mc_opcode[5:3] : bd_state);
	end
	always @(posedge clk) epfw_issue_wb <= mc_op_ep & mc_opcode[7];
	always @(posedge clk or posedge rst)
		if (rst)
			cel_state_i <= 1'b0;
		else
			cel_state_i <= cel_ena & ((cel_state_i & ~cel_rel) | (mc_op_ep & mc_opcode[8]));
	assign cel_state = cel_state_i;
	always @(posedge clk)
		if (mc_op_tx)
			txpkt_pid <= mc_opcode[3:0] ^ {mc_opcode[4] & ep_data_toggle, 3'b000};
	always @(posedge clk) txpkt_start_i <= mc_op_tx;
	assign txpkt_start = txpkt_start_i;
	assign txpkt_len = bd_length[9:0];
	always @(posedge clk) addr <= (addr_ld ? eps_rddata_3[10:0] : addr + addr_inc);
	assign addr_ld = epfw_cap_dl[1:0] == 2'b11;
	assign addr_inc = (txpkt_data_ack | txpkt_start_i) | rxpkt_data_stb;
	always @(posedge clk)
		if (mc_op_zlen)
			bd_length <= 0;
		else
			bd_length <= (len_ld ? {1'b1, eps_rddata_3[9:0]} : bd_length - len_bd_dec);
	always @(posedge clk) xfer_length <= (len_ld ? 10'h000 : xfer_length + len_xf_inc);
	assign len_ld = epfw_cap_dl[1:0] == 2'b10;
	assign len_bd_dec = (rxpkt_data_stb | rxpkt_start) & bd_length[10];
	assign len_xf_inc = rxpkt_data_stb;
	assign buf_tx_addr_0 = addr;
	assign buf_tx_rden_0 = txpkt_data_ack | txpkt_start_i;
	assign txpkt_data = buf_tx_data_1;
	assign buf_rx_addr_0 = addr;
	assign buf_rx_data_0 = rxpkt_data;
	assign buf_rx_wren_0 = rxpkt_data_stb & bd_length[10];
endmodule
`default_nettype none
module usb_tx_ll (
	phy_tx_dp,
	phy_tx_dn,
	phy_tx_en,
	ll_start,
	ll_bit,
	ll_last,
	ll_ack,
	clk,
	rst
);
	output wire phy_tx_dp;
	output wire phy_tx_dn;
	output wire phy_tx_en;
	input wire ll_start;
	input wire ll_bit;
	input wire ll_last;
	output reg ll_ack;
	input wire clk;
	input wire rst;
	localparam SYM_SE0 = 2'b00;
	localparam SYM_SE1 = 2'b11;
	localparam SYM_J = 2'b10;
	localparam SYM_K = 2'b01;
	localparam PID_OUT = 4'b0001;
	localparam PID_IN = 4'b1001;
	localparam PID_SOF = 4'b0101;
	localparam PID_SETUP = 4'b1101;
	localparam PID_DATA0 = 4'b0011;
	localparam PID_DATA1 = 4'b1011;
	localparam PID_ACK = 4'b0010;
	localparam PID_NAK = 4'b1010;
	localparam PID_STALL = 4'b1110;
	localparam PID_INVAL = 4'b0000;
	reg [2:0] state;
	wire active;
	reg [2:0] br_cnt;
	wire br_now;
	reg [2:0] bs_cnt;
	reg bs_now;
	wire bs_bit;
	reg lvl_prev;
	reg out_active;
	wire [1:0] out_sym_nxt;
	reg [1:0] out_sym;
	always @(posedge clk or posedge rst)
		if (rst)
			state <= 3'b000;
		else if (ll_start)
			state <= 3'b100;
		else if (br_now & ~bs_now) begin
			if (ll_last)
				state <= 3'b101;
			else
				case (state[1:0])
					2'b00: state <= state;
					2'b01: state <= 3'b110;
					2'b10: state <= 3'b111;
					default: state <= 3'b000;
				endcase
		end
	assign active = state[2];
	always @(posedge clk) br_cnt <= {1'b0, (active ? br_cnt[1:0] : 2'b10)} + 1;
	assign br_now = br_cnt[2];
	always @(posedge clk or posedge ll_start)
		if (ll_start) begin
			bs_cnt <= 3'b000;
			bs_now <= 1'b0;
		end
		else if (br_now) begin
			bs_cnt <= (ll_bit & ~bs_now ? bs_cnt + 1 : 3'b000);
			bs_now <= ll_bit & (bs_cnt == 3'b101);
		end
	assign bs_bit = ~bs_now & ll_bit;
	always @(posedge clk) lvl_prev <= (active ? lvl_prev ^ (~bs_bit & br_now) : 1'b1);
	always @(posedge clk) ll_ack <= (br_now & ~bs_now) & (state[1:0] == 2'b00);
	assign out_sym_nxt = (bs_bit ^ lvl_prev ? SYM_K : SYM_J);
	always @(posedge clk or posedge rst)
		if (rst)
			out_sym <= SYM_J;
		else if (br_now)
			case (state[1:0])
				2'b00: out_sym <= out_sym_nxt;
				2'b01: out_sym <= (bs_now ? out_sym_nxt : SYM_SE0);
				2'b10: out_sym <= SYM_SE0;
				2'b11: out_sym <= SYM_J;
				default: out_sym <= 2'bxx;
			endcase
	always @(posedge clk) out_active <= active;
	assign phy_tx_dp = out_sym[1];
	assign phy_tx_dn = out_sym[0];
	assign phy_tx_en = out_active;
endmodule
`default_nettype none
module usb_tx_pkt (
	ll_start,
	ll_bit,
	ll_last,
	ll_ack,
	pkt_start,
	pkt_done,
	pkt_pid,
	pkt_len,
	pkt_data,
	pkt_data_ack,
	clk,
	rst
);
	output reg ll_start;
	output wire ll_bit;
	output wire ll_last;
	input wire ll_ack;
	input wire pkt_start;
	output reg pkt_done;
	input wire [3:0] pkt_pid;
	input wire [9:0] pkt_len;
	input wire [7:0] pkt_data;
	output reg pkt_data_ack;
	input wire clk;
	input wire rst;
	localparam SYM_SE0 = 2'b00;
	localparam SYM_SE1 = 2'b11;
	localparam SYM_J = 2'b10;
	localparam SYM_K = 2'b01;
	localparam PID_OUT = 4'b0001;
	localparam PID_IN = 4'b1001;
	localparam PID_SOF = 4'b0101;
	localparam PID_SETUP = 4'b1101;
	localparam PID_DATA0 = 4'b0011;
	localparam PID_DATA1 = 4'b1011;
	localparam PID_ACK = 4'b0010;
	localparam PID_NAK = 4'b1010;
	localparam PID_STALL = 4'b1110;
	localparam PID_INVAL = 4'b0000;
	localparam ST_IDLE = 0;
	localparam ST_SYNC = 1;
	localparam ST_PID = 2;
	localparam ST_DATA = 3;
	localparam ST_CRC_LSB = 4;
	localparam ST_CRC_MSB = 5;
	reg [3:0] state_nxt;
	reg [3:0] state;
	reg pid_is_handshake;
	wire next;
	reg [3:0] shift_bit;
	reg [7:0] shift_load;
	reg [7:0] shift_data;
	reg shift_data_crc;
	wire shift_last_bit;
	reg shift_last_byte;
	wire shift_do_load;
	wire shift_now;
	reg shift_new_bit;
	reg [10:0] len;
	wire len_last;
	wire len_dec;
	wire crc_in_bit;
	reg crc_in_first;
	wire crc_in_valid;
	wire [15:0] crc;
	always @(*) begin
		state_nxt = state;
		case (state)
			ST_IDLE:
				if (pkt_start)
					state_nxt = ST_SYNC;
			ST_SYNC: state_nxt = ST_PID;
			ST_PID:
				if (next) begin
					if (pid_is_handshake)
						state_nxt = ST_IDLE;
					else if (len_last)
						state_nxt = ST_CRC_LSB;
					else
						state_nxt = ST_DATA;
				end
			ST_DATA:
				if (next && len_last)
					state_nxt = ST_CRC_LSB;
			ST_CRC_LSB:
				if (next)
					state_nxt = ST_CRC_MSB;
			ST_CRC_MSB:
				if (next)
					state_nxt = ST_IDLE;
		endcase
	end
	always @(posedge clk or posedge rst)
		if (rst)
			state <= ST_IDLE;
		else
			state <= state_nxt;
	always @(posedge clk) pid_is_handshake <= ((pkt_pid == PID_ACK) || (pkt_pid == PID_NAK)) || (pkt_pid == PID_STALL);
	assign next = shift_last_bit & ll_ack;
	assign shift_do_load = (state == ST_SYNC) | (shift_last_bit & ll_ack);
	assign shift_now = (state == ST_SYNC) | ll_ack;
	always @(posedge clk)
		if (shift_now)
			shift_bit <= (shift_do_load ? 4'b0111 : shift_bit) - 1;
	assign shift_last_bit = shift_bit[3];
	always @(*)
		case (state)
			ST_SYNC: shift_load <= 8'h80;
			ST_PID: shift_load <= {~pkt_pid, pkt_pid};
			ST_DATA: shift_load <= pkt_data;
			ST_CRC_LSB: shift_load <= (crc_in_first ? 8'h00 : crc[7:0]);
			ST_CRC_MSB: shift_load <= (crc_in_first ? 8'h00 : crc[15:8]);
			default: shift_load <= 8'hxx;
		endcase
	always @(posedge clk)
		if (shift_now)
			shift_data <= (shift_do_load ? shift_load : {1'b0, shift_data[7:1]});
	always @(posedge clk)
		if (shift_now & shift_do_load) begin
			shift_data_crc <= state == ST_DATA;
			shift_last_byte <= (state == ST_CRC_MSB) | ((state == ST_PID) & pid_is_handshake);
		end
	always @(posedge clk) shift_new_bit <= shift_now;
	assign len_dec = pkt_start || (shift_do_load && ((state == ST_DATA) || (state == ST_PID)));
	always @(posedge clk)
		if (len_dec)
			len <= (pkt_start ? {1'b0, pkt_len} : len) - 1;
	assign len_last = len[10];
	always @(posedge clk) crc_in_first <= (crc_in_first & ~crc_in_valid) | (state == ST_IDLE);
	assign crc_in_bit = shift_data[0];
	assign crc_in_valid = shift_data_crc & shift_new_bit;
	usb_crc #(
		.WIDTH(16),
		.POLY(16'h8005),
		.MATCH(16'h800d)
	) crc_16_I(
		.in_bit(crc_in_bit),
		.in_first(crc_in_first),
		.in_valid(crc_in_valid),
		.crc(crc),
		.crc_match(),
		.clk(clk),
		.rst(rst)
	);
	always @(posedge clk) ll_start <= state == ST_SYNC;
	assign ll_bit = shift_data[0];
	assign ll_last = shift_last_bit & shift_last_byte;
	always @(posedge clk) begin
		pkt_done <= ll_ack && ll_last;
		pkt_data_ack <= (state == ST_DATA) && next;
	end
endmodule
`default_nettype none
module usb (
	pad_dp,
	pad_dn,
	pad_pu,
	ep_tx_addr_0,
	ep_tx_data_0,
	ep_tx_we_0,
	ep_rx_addr_0,
	ep_rx_data_1,
	ep_rx_re_0,
	ep_clk,
	wb_addr,
	wb_rdata,
	wb_wdata,
	wb_we,
	wb_cyc,
	wb_ack,
	irq,
	sof,
	clk,
	rst
);
	parameter TARGET = "ICE40";
	parameter integer EPDW = 16;
	parameter integer EVT_DEPTH = 0;
	parameter integer IRQ = 0;
	parameter integer EPAW = 11 - $clog2(EPDW / 8);
	inout wire pad_dp;
	inout wire pad_dn;
	output reg pad_pu;
	input wire [EPAW - 1:0] ep_tx_addr_0;
	input wire [EPDW - 1:0] ep_tx_data_0;
	input wire ep_tx_we_0;
	input wire [EPAW - 1:0] ep_rx_addr_0;
	output wire [EPDW - 1:0] ep_rx_data_1;
	input wire ep_rx_re_0;
	input wire ep_clk;
	input wire [11:0] wb_addr;
	output wire [15:0] wb_rdata;
	input wire [15:0] wb_wdata;
	input wire wb_we;
	input wire wb_cyc;
	output wire wb_ack;
	output reg irq;
	output wire sof;
	input wire clk;
	input wire rst;
	wire phy_rx_dp;
	wire phy_rx_dn;
	wire phy_rx_chg;
	wire phy_tx_dp;
	wire phy_tx_dn;
	wire phy_tx_en;
	wire txll_start;
	wire txll_bit;
	wire txll_last;
	wire txll_ack;
	wire txpkt_start;
	wire txpkt_done;
	wire [3:0] txpkt_pid;
	wire [9:0] txpkt_len;
	wire [7:0] txpkt_data;
	wire txpkt_data_ack;
	wire [1:0] rxll_sym;
	wire rxll_bit;
	wire rxll_valid;
	wire rxll_eop;
	wire rxll_sync;
	wire rxll_bs_skip;
	wire rxll_bs_err;
	wire rxpkt_start;
	wire rxpkt_done_ok;
	wire rxpkt_done_err;
	wire [3:0] rxpkt_pid;
	wire rxpkt_is_sof;
	wire rxpkt_is_token;
	wire rxpkt_is_data;
	wire rxpkt_is_handshake;
	wire [10:0] rxpkt_frameno;
	wire [6:0] rxpkt_addr;
	wire [3:0] rxpkt_endp;
	wire [7:0] rxpkt_data;
	wire rxpkt_data_stb;
	wire [10:0] buf_tx_addr_0;
	wire [7:0] buf_tx_data_1;
	wire buf_tx_rden_0;
	wire [10:0] buf_rx_addr_0;
	wire [7:0] buf_rx_data_0;
	wire buf_rx_wren_0;
	wire eps_read_0;
	wire eps_zero_0;
	wire eps_write_0;
	wire [7:0] eps_addr_0;
	wire [15:0] eps_wrdata_0;
	wire [15:0] eps_rddata_3;
	wire eps_bus_ready;
	reg eps_bus_read;
	wire eps_bus_zero;
	reg eps_bus_write;
	wire [15:0] eps_bus_dout;
	reg cr_pu_ena;
	reg cr_cel_ena;
	reg cr_addr_chk;
	reg [6:0] cr_addr;
	wire cel_state;
	reg cel_rel;
	reg ir_sfp;
	reg ir_evt;
	reg ir_bsa;
	reg ir_brr;
	reg ir_bra;
	reg ir_brp;
	reg csr_bus_req;
	wire csr_bus_clear;
	wire csr_bus_ack;
	reg [15:0] csr_bus_dout;
	wire [15:0] csr_readout;
	wire [15:0] ir_readout;
	reg cr_bus_we;
	reg ir_bus_we;
	reg eps_bus_req;
	wire eps_bus_clear;
	reg eps_bus_ack_wait;
	wire eps_bus_req_ok;
	reg [2:0] eps_bus_req_ok_dly;
	wire [15:0] evt_rd_data;
	wire evt_rd_rdy;
	reg evt_rd_ack;
	wire evt_pending;
	wire [11:0] evt_data;
	wire evt_stb;
	wire oob_se0;
	wire oob_sof;
	reg [19:0] timeout_suspend;
	reg [19:0] timeout_reset;
	wire usb_suspend;
	wire usb_reset;
	reg rst_pending;
	reg rst_clear;
	reg sof_ind;
	reg sof_pending;
	reg sof_clear;
	usb_phy #(.TARGET(TARGET)) phy_I(
		.pad_dp(pad_dp),
		.pad_dn(pad_dn),
		.rx_dp(phy_rx_dp),
		.rx_dn(phy_rx_dn),
		.rx_chg(phy_rx_chg),
		.tx_dp(phy_tx_dp),
		.tx_dn(phy_tx_dn),
		.tx_en(phy_tx_en),
		.clk(clk),
		.rst(rst)
	);
	usb_tx_ll tx_ll_I(
		.phy_tx_dp(phy_tx_dp),
		.phy_tx_dn(phy_tx_dn),
		.phy_tx_en(phy_tx_en),
		.ll_start(txll_start),
		.ll_bit(txll_bit),
		.ll_last(txll_last),
		.ll_ack(txll_ack),
		.clk(clk),
		.rst(rst)
	);
	usb_tx_pkt tx_pkt_I(
		.ll_start(txll_start),
		.ll_bit(txll_bit),
		.ll_last(txll_last),
		.ll_ack(txll_ack),
		.pkt_start(txpkt_start),
		.pkt_done(txpkt_done),
		.pkt_pid(txpkt_pid),
		.pkt_len(txpkt_len),
		.pkt_data(txpkt_data),
		.pkt_data_ack(txpkt_data_ack),
		.clk(clk),
		.rst(rst)
	);
	usb_rx_ll rx_ll_I(
		.phy_rx_dp(phy_rx_dp),
		.phy_rx_dn(phy_rx_dn),
		.phy_rx_chg(phy_rx_chg),
		.ll_sym(rxll_sym),
		.ll_bit(rxll_bit),
		.ll_valid(rxll_valid),
		.ll_eop(rxll_eop),
		.ll_sync(rxll_sync),
		.ll_bs_skip(rxll_bs_skip),
		.ll_bs_err(rxll_bs_err),
		.clk(clk),
		.rst(rst)
	);
	usb_rx_pkt rx_pkt_I(
		.ll_sym(rxll_sym),
		.ll_bit(rxll_bit),
		.ll_valid(rxll_valid),
		.ll_eop(rxll_eop),
		.ll_sync(rxll_sync),
		.ll_bs_skip(rxll_bs_skip),
		.ll_bs_err(rxll_bs_err),
		.pkt_start(rxpkt_start),
		.pkt_done_ok(rxpkt_done_ok),
		.pkt_done_err(rxpkt_done_err),
		.pkt_pid(rxpkt_pid),
		.pkt_is_sof(rxpkt_is_sof),
		.pkt_is_token(rxpkt_is_token),
		.pkt_is_data(rxpkt_is_data),
		.pkt_is_handshake(rxpkt_is_handshake),
		.pkt_frameno(rxpkt_frameno),
		.pkt_addr(rxpkt_addr),
		.pkt_endp(rxpkt_endp),
		.pkt_data(rxpkt_data),
		.pkt_data_stb(rxpkt_data_stb),
		.inhibit(phy_tx_en),
		.clk(clk),
		.rst(rst)
	);
	usb_trans trans_I(
		.txpkt_start(txpkt_start),
		.txpkt_done(txpkt_done),
		.txpkt_pid(txpkt_pid),
		.txpkt_len(txpkt_len),
		.txpkt_data(txpkt_data),
		.txpkt_data_ack(txpkt_data_ack),
		.rxpkt_start(rxpkt_start),
		.rxpkt_done_ok(rxpkt_done_ok),
		.rxpkt_done_err(rxpkt_done_err),
		.rxpkt_pid(rxpkt_pid),
		.rxpkt_is_sof(rxpkt_is_sof),
		.rxpkt_is_token(rxpkt_is_token),
		.rxpkt_is_data(rxpkt_is_data),
		.rxpkt_is_handshake(rxpkt_is_handshake),
		.rxpkt_frameno(rxpkt_frameno),
		.rxpkt_addr(rxpkt_addr),
		.rxpkt_endp(rxpkt_endp),
		.rxpkt_data(rxpkt_data),
		.rxpkt_data_stb(rxpkt_data_stb),
		.buf_tx_addr_0(buf_tx_addr_0),
		.buf_tx_data_1(buf_tx_data_1),
		.buf_tx_rden_0(buf_tx_rden_0),
		.buf_rx_addr_0(buf_rx_addr_0),
		.buf_rx_data_0(buf_rx_data_0),
		.buf_rx_wren_0(buf_rx_wren_0),
		.eps_read_0(eps_read_0),
		.eps_zero_0(eps_zero_0),
		.eps_write_0(eps_write_0),
		.eps_addr_0(eps_addr_0),
		.eps_wrdata_0(eps_wrdata_0),
		.eps_rddata_3(eps_rddata_3),
		.cr_addr_chk(cr_addr_chk),
		.cr_addr(cr_addr),
		.evt_data(evt_data),
		.evt_stb(evt_stb),
		.cel_state(cel_state),
		.cel_rel(cel_rel),
		.cel_ena(cr_cel_ena),
		.clk(clk),
		.rst(rst)
	);
	usb_ep_buf #(
		.TARGET(TARGET),
		.RWIDTH(8),
		.WWIDTH(EPDW)
	) tx_buf_I(
		.rd_addr_0(buf_tx_addr_0),
		.rd_data_1(buf_tx_data_1),
		.rd_en_0(buf_tx_rden_0),
		.rd_clk(clk),
		.wr_addr_0(ep_tx_addr_0),
		.wr_data_0(ep_tx_data_0),
		.wr_en_0(ep_tx_we_0),
		.wr_clk(ep_clk)
	);
	usb_ep_buf #(
		.TARGET(TARGET),
		.RWIDTH(EPDW),
		.WWIDTH(8)
	) rx_buf_I(
		.rd_addr_0(ep_rx_addr_0),
		.rd_data_1(ep_rx_data_1),
		.rd_en_0(ep_rx_re_0),
		.rd_clk(ep_clk),
		.wr_addr_0(buf_rx_addr_0),
		.wr_data_0(buf_rx_data_0),
		.wr_en_0(buf_rx_wren_0),
		.wr_clk(clk)
	);
	usb_ep_status ep_status_I(
		.p_addr_0(eps_addr_0),
		.p_read_0(eps_read_0),
		.p_zero_0(eps_zero_0),
		.p_write_0(eps_write_0),
		.p_din_0(eps_wrdata_0),
		.p_dout_3(eps_rddata_3),
		.s_addr_0(wb_addr[7:0]),
		.s_read_0(eps_bus_ready),
		.s_zero_0(eps_bus_zero),
		.s_write_0(eps_bus_write),
		.s_din_0(wb_wdata),
		.s_dout_3(eps_bus_dout),
		.s_ready_0(eps_bus_ready),
		.clk(clk),
		.rst(rst)
	);
	always @(posedge clk)
		if (csr_bus_clear) begin
			csr_bus_req <= 1'b0;
			cr_bus_we <= 1'b0;
			cel_rel <= 1'b0;
			rst_clear <= 1'b0;
			sof_clear <= 1'b0;
			evt_rd_ack <= 1'b0;
			ir_bus_we <= 1'b0;
		end
		else begin
			csr_bus_req <= 1'b1;
			cr_bus_we <= (wb_addr[1:0] == 2'b00) & wb_we;
			cel_rel <= ((wb_addr[1:0] == 2'b01) & wb_we) & wb_wdata[13];
			rst_clear <= ((wb_addr[1:0] == 2'b01) & wb_we) & wb_wdata[9];
			sof_clear <= ((wb_addr[1:0] == 2'b01) & wb_we) & wb_wdata[8];
			evt_rd_ack <= ((wb_addr[1:0] == 2'b10) & ~wb_we) & evt_rd_rdy;
			ir_bus_we <= (wb_addr[1:0] == 2'b11) & wb_we;
		end
	assign csr_readout = {cr_pu_ena, evt_pending, cel_state, cr_cel_ena, usb_suspend, usb_reset, rst_pending, sof_pending, cr_addr_chk, cr_addr};
	assign ir_readout = (IRQ ? {10'b0000000000, ir_sfp, ir_evt, ir_bsa, ir_brr, ir_bra, ir_brp} : 16'h0000);
	always @(*)
		if (csr_bus_ack)
			case (wb_addr[1:0])
				2'b00: csr_bus_dout = csr_readout;
				2'b10: csr_bus_dout = evt_rd_data;
				2'b11: csr_bus_dout = ir_readout;
				default: csr_bus_dout = 16'h0000;
			endcase
		else
			csr_bus_dout = 16'h0000;
	assign csr_bus_ack = csr_bus_req;
	assign csr_bus_clear = (~wb_cyc | csr_bus_ack) | wb_addr[11];
	always @(posedge clk or posedge rst)
		if (rst) begin
			cr_pu_ena <= 1'b0;
			cr_cel_ena <= 1'b0;
			cr_addr_chk <= 1'b0;
			cr_addr <= 7'd0;
		end
		else if (cr_bus_we) begin
			cr_pu_ena <= wb_wdata[15];
			cr_cel_ena <= wb_wdata[12];
			cr_addr_chk <= wb_wdata[7];
			cr_addr <= wb_wdata[6:0];
		end
	always @(posedge clk or posedge rst)
		if (IRQ) begin
			if (rst) begin
				ir_sfp <= 1'b0;
				ir_evt <= 1'b0;
				ir_bsa <= 1'b0;
				ir_brr <= 1'b0;
				ir_bra <= 1'b0;
				ir_brp <= 1'b0;
			end
			else if (ir_bus_we) begin
				ir_sfp <= wb_wdata[5];
				ir_evt <= wb_wdata[4];
				ir_bsa <= wb_wdata[3];
				ir_brr <= wb_wdata[2];
				ir_bra <= wb_wdata[1];
				ir_brp <= wb_wdata[0];
			end
		end
	always @(posedge clk)
		if (eps_bus_clear) begin
			eps_bus_read <= 1'b0;
			eps_bus_write <= 1'b0;
			eps_bus_req <= 1'b0;
		end
		else begin
			eps_bus_read <= wb_addr[11] & ~wb_we;
			eps_bus_write <= wb_addr[11] & wb_we;
			eps_bus_req <= wb_addr[11];
		end
	assign eps_bus_zero = ~eps_bus_read;
	assign eps_bus_clear = (~wb_cyc | eps_bus_ack_wait) | (eps_bus_req & eps_bus_ready);
	assign eps_bus_req_ok = eps_bus_req & eps_bus_ready;
	always @(posedge clk) eps_bus_req_ok_dly <= {eps_bus_req_ok_dly[1:0], eps_bus_req_ok & ~wb_we};
	always @(posedge clk or posedge rst)
		if (rst)
			eps_bus_ack_wait <= 1'b0;
		else
			eps_bus_ack_wait <= ((eps_bus_ack_wait & ~wb_we) | eps_bus_req_ok) & ~eps_bus_req_ok_dly[2];
	assign wb_ack = csr_bus_ack | (eps_bus_ack_wait & (wb_we | eps_bus_req_ok_dly[2]));
	assign wb_rdata = csr_bus_dout | eps_bus_dout;
	generate
		if (EVT_DEPTH == 0) begin : genblk1
			reg [3:0] evt_cnt;
			always @(posedge clk or posedge rst)
				if (rst)
					evt_cnt <= 4'h0;
				else
					evt_cnt <= (evt_rd_ack ? {3'b000, evt_stb} : evt_cnt + evt_stb);
			assign evt_rd_rdy = 1'b1;
			assign evt_rd_data = {evt_cnt, 12'h000};
			assign evt_pending = evt_cnt != 4'h0;
		end
		else if (EVT_DEPTH == 1) begin : genblk1
			reg [11:0] evt_last;
			reg [3:0] evt_cnt;
			always @(posedge clk or posedge rst)
				if (rst)
					evt_cnt <= 4'h0;
				else
					evt_cnt <= (evt_rd_ack ? {3'b000, evt_stb} : evt_cnt + evt_stb);
			always @(posedge clk)
				if (evt_stb)
					evt_last <= evt_data;
			assign evt_rd_rdy = 1'b1;
			assign evt_rd_data = {evt_cnt, evt_last};
			assign evt_pending = evt_cnt != 4'h0;
		end
		else if (EVT_DEPTH > 1) begin : genblk1
			wire [11:0] ef_wdata;
			wire [11:0] ef_rdata;
			wire ef_wren;
			wire ef_full;
			wire ef_rden;
			wire ef_empty;
			reg ef_overflow;
			assign ef_wdata = evt_data;
			assign ef_wren = evt_stb & ~ef_full;
			always @(posedge clk or posedge rst)
				if (rst)
					ef_overflow <= 1'b0;
				else
					ef_overflow <= (ef_overflow & ~evt_rd_ack) | (evt_stb & ef_full);
			assign evt_rd_rdy = ~ef_empty;
			assign evt_rd_data = {~ef_empty, ef_overflow, 2'b00, ef_rdata};
			assign ef_rden = evt_rd_ack;
			assign evt_pending = ~ef_empty;
			fifo_sync_shift #(
				.DEPTH(EVT_DEPTH),
				.WIDTH(12)
			) evt_fifo_I(
				.wr_data(ef_wdata),
				.wr_ena(ef_wren),
				.wr_full(ef_full),
				.rd_data(ef_rdata),
				.rd_ena(ef_rden),
				.rd_empty(ef_empty),
				.clk(clk),
				.rst(rst)
			);
		end
	endgenerate
	assign oob_se0 = ~phy_rx_dp & ~phy_rx_dn;
	assign oob_sof = rxpkt_start & rxpkt_is_sof;
	always @(posedge clk)
		if (oob_sof | usb_reset)
			timeout_suspend <= 20'hdcd80;
		else
			timeout_suspend <= timeout_suspend + timeout_suspend[19];
	assign usb_suspend = ~timeout_suspend[19];
	always @(posedge clk)
		if (~oob_se0)
			timeout_reset <= 20'h8ad00;
		else
			timeout_reset <= timeout_reset + timeout_reset[19];
	assign usb_reset = ~timeout_reset[19];
	always @(posedge clk or posedge rst)
		if (rst)
			rst_pending <= 1'b1;
		else
			rst_pending <= (rst_pending & ~rst_clear) | usb_reset;
	always @(posedge clk)
		if (rst)
			pad_pu <= 1'b0;
		else
			pad_pu <= cr_pu_ena;
	always @(posedge clk) sof_ind <= rxpkt_start & rxpkt_is_sof;
	always @(posedge clk) sof_pending <= (sof_pending & ~sof_clear) | (rxpkt_start & rxpkt_is_sof);
	assign sof = sof_ind;
	generate
		if (IRQ) begin : genblk2
			always @(posedge clk) begin
				irq <= 1'b0;
				if (ir_sfp & sof_pending)
					irq <= 1'b1;
				if (ir_evt & evt_pending)
					irq <= 1'b1;
				if (ir_bsa & usb_suspend)
					irq <= 1'b1;
				if ((ir_brr & rst_pending) & ~usb_reset)
					irq <= 1'b1;
				if (ir_bra & usb_reset)
					irq <= 1'b1;
				if (ir_brp & rst_pending)
					irq <= 1'b1;
			end
		end
		else begin : genblk2
			always @(*) irq = 1'b0;
		end
	endgenerate
endmodule
module iocore_usb (
	io_clk_i,
	rst_n_i,
	req_i,
	kind_i,
	we_i,
	addr_i,
	wdata_i,
	busy_o,
	done_o,
	rdata_o,
	irq_o,
	usb_clk_i,
	usb_dp_io,
	usb_dn_io,
	usb_pu_o
);
	input wire io_clk_i;
	input wire rst_n_i;
	input wire req_i;
	input wire [1:0] kind_i;
	input wire we_i;
	input wire [11:0] addr_i;
	input wire [31:0] wdata_i;
	output wire busy_o;
	output reg done_o;
	output reg [31:0] rdata_o;
	output wire irq_o;
	input wire usb_clk_i;
	inout wire usb_dp_io;
	inout wire usb_dn_io;
	output wire usb_pu_o;
	localparam [1:0] K_CSR = 2'd0;
	localparam [1:0] K_RX = 2'd1;
	localparam [1:0] K_TX = 2'd2;
	reg req_t;
	reg busy_r;
	reg [1:0] kind_r;
	reg we_r;
	reg [11:0] addr_r;
	reg [31:0] wdata_r;
	reg [2:0] ack_s;
	reg [1:0] irq_s;
	reg [31:0] ans_r;
	reg ack_t;
	wire u_irq;
	always @(posedge io_clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			req_t <= 1'b0;
			busy_r <= 1'b0;
			kind_r <= K_CSR;
			we_r <= 1'b0;
			addr_r <= 12'h000;
			wdata_r <= 32'h00000000;
			ack_s <= 3'b000;
			irq_s <= 2'b00;
			done_o <= 1'b0;
			rdata_o <= 32'h00000000;
		end
		else begin
			ack_s <= {ack_s[1:0], ack_t};
			irq_s <= {irq_s[0], u_irq};
			done_o <= 1'b0;
			if (req_i && !busy_r) begin
				kind_r <= kind_i;
				we_r <= we_i;
				addr_r <= addr_i;
				wdata_r <= wdata_i;
				req_t <= !req_t;
				busy_r <= 1'b1;
			end
			else if (busy_r && (ack_s[2] != ack_s[1])) begin
				busy_r <= 1'b0;
				done_o <= 1'b1;
				rdata_o <= ans_r;
			end
		end
	assign busy_o = busy_r;
	assign irq_o = irq_s[1];
	reg [1:0] rst_q;
	wire u_rst;
	always @(posedge usb_clk_i or negedge rst_n_i)
		if (!rst_n_i)
			rst_q <= 2'b00;
		else
			rst_q <= {rst_q[0], 1'b1};
	assign u_rst = !rst_q[1];
	reg [2:0] req_s;
	reg wb_cyc;
	reg rx_re;
	reg rx_wait;
	reg tx_we;
	wire [15:0] wb_rdata;
	wire wb_ack;
	wire [31:0] ep_rx_data;
	always @(posedge usb_clk_i or posedge u_rst)
		if (u_rst) begin
			req_s <= 3'b000;
			ack_t <= 1'b0;
			ans_r <= 32'h00000000;
			wb_cyc <= 1'b0;
			rx_re <= 1'b0;
			rx_wait <= 1'b0;
			tx_we <= 1'b0;
		end
		else begin
			req_s <= {req_s[1:0], req_t};
			rx_re <= 1'b0;
			tx_we <= 1'b0;
			if (req_s[2] != req_s[1])
				case (kind_r)
					K_CSR: wb_cyc <= 1'b1;
					K_RX: begin
						rx_re <= 1'b1;
						rx_wait <= 1'b1;
					end
					default: begin
						tx_we <= we_r;
						ans_r <= 32'h00000000;
						ack_t <= !ack_t;
					end
				endcase
			if (wb_cyc && wb_ack) begin
				wb_cyc <= 1'b0;
				ans_r <= {16'h0000, wb_rdata};
				ack_t <= !ack_t;
			end
			if (rx_wait && !rx_re) begin
				rx_wait <= 1'b0;
				ans_r <= ep_rx_data;
				ack_t <= !ack_t;
			end
		end
	usb #(
		.TARGET("ICE40"),
		.EPDW(32),
		.EVT_DEPTH(0),
		.IRQ(1)
	) u_usb(
		.pad_dp(usb_dp_io),
		.pad_dn(usb_dn_io),
		.pad_pu(usb_pu_o),
		.ep_tx_addr_0(addr_r[8:0]),
		.ep_tx_data_0(wdata_r),
		.ep_tx_we_0(tx_we),
		.ep_rx_addr_0(addr_r[8:0]),
		.ep_rx_data_1(ep_rx_data),
		.ep_rx_re_0(rx_re),
		.ep_clk(usb_clk_i),
		.wb_addr(addr_r),
		.wb_rdata(wb_rdata),
		.wb_wdata(wdata_r[15:0]),
		.wb_we(we_r),
		.wb_cyc(wb_cyc),
		.wb_ack(wb_ack),
		.irq(u_irq),
		.sof(),
		.clk(usb_clk_i),
		.rst(u_rst)
	);
endmodule
`default_nettype wire
module iocore_timer (
	clk_i,
	rst_n_i,
	sel_i,
	we_i,
	off_i,
	wdata_i,
	rdata_o,
	irq_o,
	us_tick_o,
	ms_tick_o,
	us_o,
	ms_o
);
	reg _sv2v_0;
	parameter [15:0] US_DIV_RESET = 16'd49;
	input wire clk_i;
	input wire rst_n_i;
	input wire sel_i;
	input wire we_i;
	input wire [7:0] off_i;
	input wire [31:0] wdata_i;
	output reg [31:0] rdata_o;
	output wire irq_o;
	output wire us_tick_o;
	output wire ms_tick_o;
	output wire [31:0] us_o;
	output wire [31:0] ms_o;
	localparam [7:0] O_CYCLES = 8'h00;
	localparam [7:0] O_DIV = 8'h04;
	localparam [7:0] O_US = 8'h08;
	localparam [7:0] O_MS = 8'h0c;
	localparam [7:0] O_CMP = 8'h10;
	localparam [7:0] O_CTRL = 8'h14;
	reg [31:0] cycles_r;
	reg [31:0] us_r;
	reg [31:0] ms_r;
	reg [31:0] cmp_r;
	reg [15:0] div_r;
	reg [15:0] dcnt_r;
	reg [9:0] ucnt_r;
	reg en_r;
	reg pend_r;
	wire us_tick;
	wire ms_tick;
	assign us_tick = dcnt_r == div_r;
	assign ms_tick = us_tick && (ucnt_r == 10'd999);
	assign us_tick_o = us_tick;
	assign ms_tick_o = ms_tick;
	assign us_o = us_r;
	assign ms_o = ms_r;
	assign irq_o = en_r && pend_r;
	always @(*) begin
		if (_sv2v_0)
			;
		case (off_i)
			O_CYCLES: rdata_o = cycles_r;
			O_DIV: rdata_o = {16'h0000, div_r};
			O_US: rdata_o = us_r;
			O_MS: rdata_o = ms_r;
			O_CMP: rdata_o = cmp_r;
			O_CTRL: rdata_o = {30'h00000000, pend_r, en_r};
			default: rdata_o = 32'h00000000;
		endcase
	end
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			cycles_r <= 32'h00000000;
			us_r <= 32'h00000000;
			ms_r <= 32'h00000000;
			cmp_r <= 32'h00000000;
			div_r <= US_DIV_RESET;
			dcnt_r <= 16'h0000;
			ucnt_r <= 10'h000;
			en_r <= 1'b0;
			pend_r <= 1'b0;
		end
		else begin
			cycles_r <= cycles_r + 32'd1;
			if ((sel_i && we_i) && (off_i == O_DIV)) begin
				div_r <= wdata_i[15:0];
				dcnt_r <= 16'h0000;
			end
			else
				dcnt_r <= (us_tick ? 16'h0000 : dcnt_r + 16'd1);
			if (us_tick) begin
				us_r <= us_r + 32'd1;
				ucnt_r <= (ms_tick ? 10'd0 : ucnt_r + 10'd1);
			end
			if (ms_tick)
				ms_r <= ms_r + 32'd1;
			if ((sel_i && we_i) && (off_i == O_CMP))
				cmp_r <= wdata_i;
			if ((sel_i && we_i) && (off_i == O_CTRL)) begin
				en_r <= wdata_i[0];
				if (wdata_i[1])
					pend_r <= 1'b0;
			end
			if (us_tick && ((us_r + 32'd1) == cmp_r))
				pend_r <= 1'b1;
		end
	initial _sv2v_0 = 0;
endmodule
module iocore_uart (
	clk_i,
	rst_n_i,
	sel_i,
	we_i,
	off_i,
	wdata_i,
	ready_o,
	rdata_o,
	rxd_i,
	txd_o,
	irq_o,
	rx_byte_o
);
	reg _sv2v_0;
	parameter signed [31:0] FIFO_DEPTH = 16;
	parameter [15:0] BAUD_RESET = 16'd0;
	input wire clk_i;
	input wire rst_n_i;
	input wire sel_i;
	input wire we_i;
	input wire [7:0] off_i;
	input wire [31:0] wdata_i;
	output wire ready_o;
	output reg [31:0] rdata_o;
	input wire rxd_i;
	output wire txd_o;
	output wire irq_o;
	output wire rx_byte_o;
	localparam signed [31:0] FD = FIFO_DEPTH;
	localparam signed [31:0] FPW = (FD > 1 ? $clog2(FD) : 1);
	localparam signed [31:0] FCW = $clog2(FD + 1);
	localparam [7:0] O_DATA = 8'h00;
	localparam [7:0] O_STATUS = 8'h04;
	localparam [7:0] O_BAUD = 8'h08;
	localparam [7:0] O_IRQEN = 8'h0c;
	localparam [7:0] O_CLR = 8'h10;
	reg [15:0] baud_r;
	wire [15:0] baud;
	reg [1:0] irqen_r;
	reg overrun_r;
	reg ferr_r;
	reg [7:0] rxq [0:FD - 1];
	reg [7:0] txq [0:FD - 1];
	reg [FPW - 1:0] rx_rd_r;
	reg [FPW - 1:0] rx_wr_r;
	reg [FPW - 1:0] tx_rd_r;
	reg [FPW - 1:0] tx_wr_r;
	reg [FCW - 1:0] rx_cnt_r;
	reg [FCW - 1:0] tx_cnt_r;
	wire rx_full;
	wire tx_full;
	wire rx_empty;
	wire tx_empty;
	reg txd_r;
	reg tx_busy_r;
	reg [8:0] tx_sh_r;
	reg [3:0] tx_bit_r;
	reg [15:0] tx_clk_r;
	reg rxd_s1_r;
	reg rxd_s2_r;
	reg rxd_d_r;
	reg rx_busy_r;
	reg [3:0] rx_bit_r;
	reg [15:0] rx_clk_r;
	reg [7:0] rx_sh_r;
	wire ser_valid;
	wire ser_ferr;
	wire take;
	wire drop;
	wire rx_pop;
	wire tx_push;
	wire tx_pop;
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	function automatic [FPW - 1:0] fnext;
		input reg [FPW - 1:0] p;
		fnext = (sv2v_cast_32(p) == (FD - 1) ? {FPW {1'sb0}} : p + 1'b1);
	endfunction
	assign baud = (baud_r < 16'd4 ? 16'd4 : baud_r);
	assign rx_full = sv2v_cast_32(rx_cnt_r) == FD;
	assign rx_empty = rx_cnt_r == {FCW {1'sb0}};
	assign tx_full = sv2v_cast_32(tx_cnt_r) == FD;
	assign tx_empty = tx_cnt_r == {FCW {1'sb0}};
	assign ready_o = !((we_i && (off_i == O_DATA)) && tx_full);
	assign tx_push = (sel_i && we_i) && (off_i == O_DATA);
	assign rx_pop = ((sel_i && !we_i) && (off_i == O_DATA)) && !rx_empty;
	assign tx_pop = !tx_busy_r && !tx_empty;
	assign ser_valid = ((rx_busy_r && (rx_bit_r == 4'd9)) && (rx_clk_r == 16'h0000)) && rxd_s2_r;
	assign ser_ferr = ((rx_busy_r && (rx_bit_r == 4'd9)) && (rx_clk_r == 16'h0000)) && !rxd_s2_r;
	assign take = ser_valid && !rx_full;
	assign drop = ser_valid && rx_full;
	assign rx_byte_o = take;
	assign txd_o = txd_r;
	assign irq_o = (irqen_r[0] && !rx_empty) || ((irqen_r[1] && tx_empty) && !tx_busy_r);
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		case (off_i)
			O_DATA: rdata_o = {!rx_empty, overrun_r, ferr_r, 21'h000000, (rx_empty ? 8'h00 : rxq[rx_rd_r])};
			O_STATUS: rdata_o = {12'h000, !rx_empty, tx_full, rx_full, tx_busy_r || !tx_empty, sv2v_cast_8(tx_cnt_r), sv2v_cast_8(rx_cnt_r)};
			O_BAUD: rdata_o = {16'h0000, baud_r};
			O_IRQEN: rdata_o = {30'h00000000, irqen_r};
			O_CLR: rdata_o = {1'b0, overrun_r, ferr_r, 29'h00000000};
			default: rdata_o = 32'h00000000;
		endcase
	end
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			baud_r <= BAUD_RESET;
			irqen_r <= 2'b00;
			overrun_r <= 1'b0;
			ferr_r <= 1'b0;
			rx_rd_r <= 1'sb0;
			rx_wr_r <= 1'sb0;
			rx_cnt_r <= 1'sb0;
			tx_rd_r <= 1'sb0;
			tx_wr_r <= 1'sb0;
			tx_cnt_r <= 1'sb0;
			txd_r <= 1'b1;
			tx_busy_r <= 1'b0;
			tx_sh_r <= 9'h1ff;
			tx_bit_r <= 4'h0;
			tx_clk_r <= 16'h0000;
			rxd_s1_r <= 1'b1;
			rxd_s2_r <= 1'b1;
			rxd_d_r <= 1'b1;
			rx_busy_r <= 1'b0;
			rx_bit_r <= 4'h0;
			rx_clk_r <= 16'h0000;
			rx_sh_r <= 8'h00;
		end
		else begin
			if (sel_i && we_i) begin
				if (off_i == O_BAUD)
					baud_r <= wdata_i[15:0];
				if (off_i == O_IRQEN)
					irqen_r <= wdata_i[1:0];
			end
			if (((sel_i && we_i) && (off_i == O_CLR)) && wdata_i[30])
				overrun_r <= 1'b0;
			if (((sel_i && we_i) && (off_i == O_CLR)) && wdata_i[29])
				ferr_r <= 1'b0;
			if (drop)
				overrun_r <= 1'b1;
			if (ser_ferr)
				ferr_r <= 1'b1;
			if (take) begin
				rxq[rx_wr_r] <= rx_sh_r;
				rx_wr_r <= fnext(rx_wr_r);
			end
			if (rx_pop)
				rx_rd_r <= fnext(rx_rd_r);
			if (take && !rx_pop)
				rx_cnt_r <= rx_cnt_r + 1'b1;
			else if (rx_pop && !take)
				rx_cnt_r <= rx_cnt_r - 1'b1;
			if (tx_push) begin
				txq[tx_wr_r] <= wdata_i[7:0];
				tx_wr_r <= fnext(tx_wr_r);
			end
			if (tx_pop)
				tx_rd_r <= fnext(tx_rd_r);
			if (tx_push && !tx_pop)
				tx_cnt_r <= tx_cnt_r + 1'b1;
			else if (tx_pop && !tx_push)
				tx_cnt_r <= tx_cnt_r - 1'b1;
			if (tx_pop) begin
				tx_busy_r <= 1'b1;
				txd_r <= 1'b0;
				tx_sh_r <= {1'b1, txq[tx_rd_r]};
				tx_bit_r <= 4'd0;
				tx_clk_r <= baud - 16'd1;
			end
			else if (tx_busy_r) begin
				if (tx_clk_r != 16'h0000)
					tx_clk_r <= tx_clk_r - 16'd1;
				else if (tx_bit_r == 4'd9) begin
					tx_busy_r <= 1'b0;
					txd_r <= 1'b1;
				end
				else begin
					txd_r <= tx_sh_r[0];
					tx_sh_r <= {1'b1, tx_sh_r[8:1]};
					tx_bit_r <= tx_bit_r + 4'd1;
					tx_clk_r <= baud - 16'd1;
				end
			end
			rxd_s1_r <= rxd_i;
			rxd_s2_r <= rxd_s1_r;
			rxd_d_r <= rxd_s2_r;
			if (!rx_busy_r) begin
				if (rxd_d_r && !rxd_s2_r) begin
					rx_busy_r <= 1'b1;
					rx_bit_r <= 4'd0;
					rx_clk_r <= (baud >> 1) - 16'd1;
				end
			end
			else if (rx_clk_r != 16'h0000)
				rx_clk_r <= rx_clk_r - 16'd1;
			else begin
				rx_clk_r <= baud - 16'd1;
				if (rx_bit_r == 4'd0) begin
					if (rxd_s2_r)
						rx_busy_r <= 1'b0;
					else
						rx_bit_r <= 4'd1;
				end
				else if (rx_bit_r == 4'd9)
					rx_busy_r <= 1'b0;
				else begin
					rx_sh_r <= {rxd_s2_r, rx_sh_r[7:1]};
					rx_bit_r <= rx_bit_r + 4'd1;
				end
			end
		end
	initial _sv2v_0 = 0;
endmodule
module iocore_bridge (
	clk_i,
	rst_n_i,
	sel_i,
	we_i,
	off_i,
	wdata_i,
	ready_o,
	rdata_o,
	irq_o,
	cmd_pop_o,
	cmd_data_i,
	cmd_empty_i,
	cmd_level_i,
	rsp_push_o,
	rsp_data_o,
	rsp_full_i,
	evt_push_o,
	evt_data_o,
	evt_full_i,
	con_pop_o,
	con_data_i,
	con_empty_i,
	con_level_i,
	conrx_push_o,
	conrx_data_o,
	conrx_full_i,
	upd_push_o,
	upd_data_o,
	upd_full_i,
	dn_pop_o,
	dn_data_i,
	dn_empty_i
);
	reg _sv2v_0;
	parameter signed [31:0] NUP = 32;
	parameter signed [31:0] NDN = 8;
	input wire clk_i;
	input wire rst_n_i;
	input wire sel_i;
	input wire we_i;
	input wire [11:0] off_i;
	input wire [31:0] wdata_i;
	output wire ready_o;
	output reg [31:0] rdata_o;
	output wire irq_o;
	output wire cmd_pop_o;
	input wire [31:0] cmd_data_i;
	input wire cmd_empty_i;
	input wire [5:0] cmd_level_i;
	output wire rsp_push_o;
	output wire [31:0] rsp_data_o;
	input wire rsp_full_i;
	output wire evt_push_o;
	output wire [15:0] evt_data_o;
	input wire evt_full_i;
	output wire con_pop_o;
	input wire [8:0] con_data_i;
	input wire con_empty_i;
	input wire [6:0] con_level_i;
	output wire conrx_push_o;
	output wire [7:0] conrx_data_o;
	input wire conrx_full_i;
	output wire upd_push_o;
	output wire [36:0] upd_data_o;
	input wire upd_full_i;
	output wire dn_pop_o;
	input wire [34:0] dn_data_i;
	input wire dn_empty_i;
	localparam [11:0] O_CMD = 12'h000;
	localparam [11:0] O_CMD_LEVEL = 12'h004;
	localparam [11:0] O_RSP = 12'h008;
	localparam [11:0] O_EVT = 12'h00c;
	localparam [11:0] O_CON = 12'h010;
	localparam [11:0] O_CONRX = 12'h014;
	localparam [11:0] O_STATUS = 12'h018;
	localparam [11:0] O_IRQEN = 12'h01c;
	localparam [11:0] O_DN_NEW = 12'h020;
	wire is_up;
	wire is_dn;
	reg [2:0] irqen_r;
	reg [31:0] dn_r [0:NDN - 1];
	reg [NDN - 1:0] dn_new_r;
	assign is_up = off_i[11:10] == 2'b10;
	assign is_dn = off_i[11:10] == 2'b11;
	assign ready_o = !(we_i && (((((off_i == O_RSP) && rsp_full_i) || ((off_i == O_EVT) && evt_full_i)) || ((off_i == O_CONRX) && conrx_full_i)) || (is_up && upd_full_i)));
	assign cmd_pop_o = ((sel_i && !we_i) && (off_i == O_CMD)) && !cmd_empty_i;
	assign con_pop_o = ((sel_i && !we_i) && (off_i == O_CON)) && !con_empty_i;
	assign rsp_push_o = (sel_i && we_i) && (off_i == O_RSP);
	assign rsp_data_o = wdata_i;
	assign evt_push_o = (sel_i && we_i) && (off_i == O_EVT);
	assign evt_data_o = wdata_i[15:0];
	assign conrx_push_o = (sel_i && we_i) && (off_i == O_CONRX);
	assign conrx_data_o = wdata_i[7:0];
	assign upd_push_o = (sel_i && we_i) && is_up;
	assign upd_data_o = {off_i[2+:5], wdata_i};
	assign dn_pop_o = !dn_empty_i;
	assign irq_o = ((irqen_r[0] && !cmd_empty_i) || (irqen_r[1] && !con_empty_i)) || (irqen_r[2] && |dn_new_r);
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		rdata_o = 32'h00000000;
		if (is_dn)
			rdata_o = dn_r[off_i[2+:$clog2(NDN)]];
		else
			case (off_i)
				O_CMD: rdata_o = (cmd_empty_i ? 32'h00000000 : cmd_data_i);
				O_CMD_LEVEL: rdata_o = {26'h0000000, cmd_level_i};
				O_CON: rdata_o = {!con_empty_i, 22'h000000, (con_empty_i ? 9'h000 : con_data_i)};
				O_STATUS: rdata_o = {1'b0, con_level_i, 2'h0, cmd_level_i, 9'h000, !dn_empty_i, upd_full_i, evt_full_i, conrx_full_i, rsp_full_i, !con_empty_i, !cmd_empty_i};
				O_IRQEN: rdata_o = {29'h00000000, irqen_r};
				O_DN_NEW: rdata_o = sv2v_cast_32(dn_new_r);
				default: rdata_o = 32'h00000000;
			endcase
	end
	function automatic signed [NDN - 1:0] sv2v_cast_000E2_signed;
		input reg signed [NDN - 1:0] inp;
		sv2v_cast_000E2_signed = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			irqen_r <= 3'h0;
			dn_new_r <= 1'sb0;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < NDN; i = i + 1)
					dn_r[i] <= 32'h00000000;
			end
		end
		else begin
			if ((sel_i && we_i) && (off_i == O_IRQEN))
				irqen_r <= wdata_i[2:0];
			dn_new_r <= (dn_new_r & ~((sel_i && !we_i) && (off_i == O_DN_NEW) ? dn_new_r : {NDN {1'sb0}})) | (!dn_empty_i ? sv2v_cast_000E2_signed(1) << dn_data_i[32+:$clog2(NDN)] : {NDN {1'sb0}});
			if (!dn_empty_i)
				dn_r[dn_data_i[32+:$clog2(NDN)]] <= dn_data_i[31:0];
		end
	initial _sv2v_0 = 0;
endmodule
module iocore_gpio (
	clk_i,
	rst_n_i,
	sel_i,
	we_i,
	off_i,
	wdata_i,
	rdata_o,
	irq_o,
	out_o,
	oe_o,
	pu_o,
	pd_o,
	in_i,
	level_o,
	hit_o
);
	reg _sv2v_0;
	parameter signed [31:0] NPINS = 16;
	input wire clk_i;
	input wire rst_n_i;
	input wire sel_i;
	input wire we_i;
	input wire [7:0] off_i;
	input wire [31:0] wdata_i;
	output reg [31:0] rdata_o;
	output wire irq_o;
	output wire [NPINS - 1:0] out_o;
	output wire [NPINS - 1:0] oe_o;
	output wire [NPINS - 1:0] pu_o;
	output wire [NPINS - 1:0] pd_o;
	input wire [NPINS - 1:0] in_i;
	output wire [NPINS - 1:0] level_o;
	output wire [NPINS - 1:0] hit_o;
	localparam [7:0] O_OUT = 8'h00;
	localparam [7:0] O_SET = 8'h04;
	localparam [7:0] O_CLR = 8'h08;
	localparam [7:0] O_XOR = 8'h0c;
	localparam [7:0] O_OE = 8'h10;
	localparam [7:0] O_PU = 8'h14;
	localparam [7:0] O_PD = 8'h18;
	localparam [7:0] O_IN = 8'h1c;
	localparam [7:0] O_EDGE = 8'h20;
	localparam [7:0] O_STATUS = 8'h24;
	localparam [7:0] O_IRQEN = 8'h28;
	reg [NPINS - 1:0] out_r;
	reg [NPINS - 1:0] oe_r;
	reg [NPINS - 1:0] pu_r;
	reg [NPINS - 1:0] pd_r;
	reg [NPINS - 1:0] s1_r;
	reg [NPINS - 1:0] s2_r;
	reg [NPINS - 1:0] in_r;
	reg [NPINS - 1:0] stat_r;
	reg [NPINS - 1:0] irqen_r;
	reg [NPINS - 1:0] hit;
	reg [(2 * NPINS) - 1:0] edge_r;
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < NPINS; i = i + 1)
				case (edge_r[2 * i+:2])
					2'd1: hit[i] = !in_r[i] && s2_r[i];
					2'd2: hit[i] = in_r[i] && !s2_r[i];
					2'd3: hit[i] = in_r[i] != s2_r[i];
					default: hit[i] = 1'b0;
				endcase
		end
	end
	assign out_o = out_r;
	assign oe_o = oe_r;
	assign pu_o = pu_r;
	assign pd_o = pd_r;
	assign level_o = in_r;
	assign hit_o = hit;
	assign irq_o = |(stat_r & irqen_r);
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		case (off_i)
			O_OUT: rdata_o = sv2v_cast_32(out_r);
			O_OE: rdata_o = sv2v_cast_32(oe_r);
			O_PU: rdata_o = sv2v_cast_32(pu_r);
			O_PD: rdata_o = sv2v_cast_32(pd_r);
			O_IN: rdata_o = sv2v_cast_32(in_r);
			O_EDGE: rdata_o = sv2v_cast_32(edge_r);
			O_STATUS: rdata_o = sv2v_cast_32(stat_r);
			O_IRQEN: rdata_o = sv2v_cast_32(irqen_r);
			default: rdata_o = 32'h00000000;
		endcase
	end
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			out_r <= 1'sb0;
			oe_r <= 1'sb0;
			pu_r <= 1'sb0;
			pd_r <= 1'sb0;
			s1_r <= 1'sb0;
			s2_r <= 1'sb0;
			in_r <= 1'sb0;
			stat_r <= 1'sb0;
			irqen_r <= 1'sb0;
			edge_r <= 1'sb0;
		end
		else begin
			s1_r <= in_i;
			s2_r <= s1_r;
			in_r <= s2_r;
			if (sel_i && we_i)
				case (off_i)
					O_OUT: out_r <= wdata_i[NPINS - 1:0];
					O_SET: out_r <= out_r | wdata_i[NPINS - 1:0];
					O_CLR: out_r <= out_r & ~wdata_i[NPINS - 1:0];
					O_XOR: out_r <= out_r ^ wdata_i[NPINS - 1:0];
					O_OE: oe_r <= wdata_i[NPINS - 1:0];
					O_PU: pu_r <= wdata_i[NPINS - 1:0];
					O_PD: pd_r <= wdata_i[NPINS - 1:0];
					O_EDGE: edge_r <= wdata_i[(2 * NPINS) - 1:0];
					O_IRQEN: irqen_r <= wdata_i[NPINS - 1:0];
					default:
						;
				endcase
			stat_r <= (stat_r & ~((sel_i && we_i) && (off_i == O_STATUS) ? wdata_i[NPINS - 1:0] : {NPINS {1'sb0}})) | hit;
		end
	initial _sv2v_0 = 0;
endmodule
module iocore_pwm (
	clk_i,
	rst_n_i,
	req_i,
	we_i,
	off_i,
	wdata_i,
	rdata_o,
	pwm_o,
	wrap_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_n_i;
	input wire req_i;
	input wire we_i;
	input wire [11:0] off_i;
	input wire [31:0] wdata_i;
	output reg [31:0] rdata_o;
	output reg [3:0] pwm_o;
	output wire wrap_o;
	localparam [11:0] PWM_PRESC = 12'h200;
	localparam [11:0] PWM_TOP = 12'h204;
	localparam [11:0] PWM_EN = 12'h208;
	localparam [11:0] PWM_COUNT = 12'h20c;
	localparam [11:0] PWM_DUTY0 = 12'h210;
	reg [15:0] presc_r;
	reg [15:0] top_r;
	reg [15:0] top_s;
	reg [3:0] en_r;
	reg [3:0] en_s;
	reg [16:0] duty_r [0:3];
	reg [16:0] duty_s [0:3];
	reg [15:0] pre_r;
	reg [15:0] cnt_r;
	reg running_r;
	wire step;
	wire wrap;
	wire wr;
	assign wr = req_i && we_i;
	assign step = running_r && (pre_r == presc_r);
	assign wrap = step && (cnt_r == top_s);
	assign wrap_o = wrap;
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_1
			reg signed [31:0] k;
			for (k = 0; k < 4; k = k + 1)
				pwm_o[k] = (running_r && en_s[k]) && ({1'b0, cnt_r} < duty_s[k]);
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		rdata_o = 32'h00000000;
		if (req_i && !we_i)
			case (off_i)
				PWM_PRESC: rdata_o = {16'h0000, presc_r};
				PWM_TOP: rdata_o = {16'h0000, top_r};
				PWM_EN: rdata_o = {28'h0000000, en_r};
				PWM_COUNT: rdata_o = {16'h0000, cnt_r};
				12'h210: rdata_o = {15'h0000, duty_r[0]};
				12'h214: rdata_o = {15'h0000, duty_r[1]};
				12'h218: rdata_o = {15'h0000, duty_r[2]};
				12'h21c: rdata_o = {15'h0000, duty_r[3]};
				default: rdata_o = 32'h00000000;
			endcase
	end
	function automatic signed [11:0] sv2v_cast_12_signed;
		input reg signed [11:0] inp;
		sv2v_cast_12_signed = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			presc_r <= 16'h0000;
			top_r <= 16'hffff;
			top_s <= 16'hffff;
			en_r <= 4'h0;
			en_s <= 4'h0;
			pre_r <= 16'h0000;
			cnt_r <= 16'h0000;
			running_r <= 1'b0;
			begin : sv2v_autoblock_2
				reg signed [31:0] k;
				for (k = 0; k < 4; k = k + 1)
					begin
						duty_r[k] <= 17'h00000;
						duty_s[k] <= 17'h00000;
					end
			end
		end
		else begin
			if (wr && (off_i == PWM_PRESC))
				presc_r <= wdata_i[15:0];
			if (wr && (off_i == PWM_TOP))
				top_r <= wdata_i[15:0];
			if (wr && (off_i == PWM_EN))
				en_r <= wdata_i[3:0];
			begin : sv2v_autoblock_3
				reg signed [31:0] k;
				for (k = 0; k < 4; k = k + 1)
					if (wr && (off_i == (PWM_DUTY0 + sv2v_cast_12_signed(4 * k))))
						duty_r[k] <= wdata_i[16:0];
			end
			if (!running_r) begin
				if (en_r != 4'h0) begin
					running_r <= 1'b1;
					pre_r <= 16'h0000;
					cnt_r <= 16'h0000;
					top_s <= top_r;
					en_s <= en_r;
					begin : sv2v_autoblock_4
						reg signed [31:0] k;
						for (k = 0; k < 4; k = k + 1)
							duty_s[k] <= duty_r[k];
					end
				end
			end
			else if (step) begin
				pre_r <= 16'h0000;
				if (wrap) begin
					cnt_r <= 16'h0000;
					top_s <= top_r;
					en_s <= en_r;
					begin : sv2v_autoblock_5
						reg signed [31:0] k;
						for (k = 0; k < 4; k = k + 1)
							duty_s[k] <= duty_r[k];
					end
					if (en_r == 4'h0)
						running_r <= 1'b0;
				end
				else
					cnt_r <= cnt_r + 16'd1;
			end
			else
				pre_r <= pre_r + 16'd1;
		end
	initial _sv2v_0 = 0;
endmodule
module iocore_spi (
	clk_i,
	rst_n_i,
	req_i,
	we_i,
	off_i,
	wdata_i,
	rdata_o,
	sck_o,
	mosi_o,
	miso_i,
	irq_o
);
	reg _sv2v_0;
	parameter signed [31:0] SPI_FIFO_DEPTH = 8;
	input wire clk_i;
	input wire rst_n_i;
	input wire req_i;
	input wire we_i;
	input wire [11:0] off_i;
	input wire [31:0] wdata_i;
	output reg [31:0] rdata_o;
	output wire sck_o;
	output wire mosi_o;
	input wire miso_i;
	output wire irq_o;
	localparam signed [31:0] FD = SPI_FIFO_DEPTH;
	localparam signed [31:0] FPW = (FD > 1 ? $clog2(FD) : 1);
	localparam signed [31:0] FCW = $clog2(FD + 1);
	localparam [11:0] SPI_CTRL = 12'h300;
	localparam [11:0] SPI_DATA = 12'h304;
	localparam [11:0] SPI_STATUS = 12'h308;
	localparam [11:0] SPI_IRQEN = 12'h30c;
	reg en_r;
	reg cpol_r;
	reg cpha_r;
	reg [15:0] div_r;
	reg [1:0] irqen_r;
	reg [7:0] txq [0:FD - 1];
	reg [7:0] rxq [0:FD - 1];
	reg [FPW - 1:0] tx_rd_r;
	reg [FPW - 1:0] tx_wr_r;
	reg [FPW - 1:0] rx_rd_r;
	reg [FPW - 1:0] rx_wr_r;
	reg [FCW - 1:0] tx_cnt_r;
	reg [FCW - 1:0] rx_cnt_r;
	reg ovr_r;
	reg busy_r;
	reg half_r;
	reg [2:0] bit_r;
	reg [15:0] hcnt_r;
	reg [7:0] tx_sh_r;
	reg [7:0] rx_sh_r;
	reg sck_r;
	reg mosi_r;
	wire tx_full;
	wire tx_empty;
	wire rx_full;
	wire rx_empty;
	wire wr_data;
	wire rd_data;
	wire tx_push;
	wire tx_pop;
	wire rx_push;
	wire rx_pop;
	wire half_end;
	wire byte_done;
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	function automatic [FPW - 1:0] fnext;
		input reg [FPW - 1:0] p;
		fnext = (sv2v_cast_32(p) == (FD - 1) ? {FPW {1'sb0}} : p + 1'b1);
	endfunction
	assign tx_full = sv2v_cast_32(tx_cnt_r) == FD;
	assign tx_empty = tx_cnt_r == {FCW {1'sb0}};
	assign rx_full = sv2v_cast_32(rx_cnt_r) == FD;
	assign rx_empty = rx_cnt_r == {FCW {1'sb0}};
	assign wr_data = (req_i && we_i) && (off_i == SPI_DATA);
	assign rd_data = (req_i && !we_i) && (off_i == SPI_DATA);
	assign tx_push = wr_data && !tx_full;
	assign tx_pop = (en_r && !busy_r) && !tx_empty;
	assign rx_pop = rd_data && !rx_empty;
	assign half_end = busy_r && (hcnt_r == div_r);
	assign byte_done = (half_end && half_r) && (bit_r == 3'd7);
	assign rx_push = byte_done && !rx_full;
	assign sck_o = (busy_r ? sck_r : cpol_r);
	assign mosi_o = mosi_r;
	assign irq_o = ((irqen_r[0] && tx_empty) && !busy_r) || (irqen_r[1] && !rx_empty);
	function automatic [4:0] sv2v_cast_5;
		input reg [4:0] inp;
		sv2v_cast_5 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		rdata_o = 32'h00000000;
		if (req_i && !we_i)
			case (off_i)
				SPI_CTRL: rdata_o = {8'h00, div_r, 5'h00, cpha_r, cpol_r, en_r};
				SPI_DATA: rdata_o = {!rx_empty, 23'h000000, (rx_empty ? 8'h00 : rxq[rx_rd_r])};
				SPI_STATUS: rdata_o = {12'h000, ovr_r, !rx_empty, tx_empty, busy_r || !tx_empty, 3'h0, sv2v_cast_5(rx_cnt_r), 3'h0, sv2v_cast_5(tx_cnt_r)};
				SPI_IRQEN: rdata_o = {30'h00000000, irqen_r};
				default: rdata_o = 32'h00000000;
			endcase
	end
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			en_r <= 1'b0;
			cpol_r <= 1'b0;
			cpha_r <= 1'b0;
			div_r <= 16'h0000;
			irqen_r <= 2'b00;
			tx_rd_r <= 1'sb0;
			tx_wr_r <= 1'sb0;
			tx_cnt_r <= 1'sb0;
			rx_rd_r <= 1'sb0;
			rx_wr_r <= 1'sb0;
			rx_cnt_r <= 1'sb0;
			ovr_r <= 1'b0;
			busy_r <= 1'b0;
			half_r <= 1'b0;
			bit_r <= 3'h0;
			hcnt_r <= 16'h0000;
			tx_sh_r <= 8'h00;
			rx_sh_r <= 8'h00;
			sck_r <= 1'b0;
			mosi_r <= 1'b0;
		end
		else begin
			if ((req_i && we_i) && (off_i == SPI_CTRL)) begin
				en_r <= wdata_i[0];
				cpol_r <= wdata_i[1];
				cpha_r <= wdata_i[2];
				div_r <= wdata_i[23:8];
			end
			if ((req_i && we_i) && (off_i == SPI_IRQEN))
				irqen_r <= wdata_i[1:0];
			if (((req_i && we_i) && (off_i == SPI_STATUS)) && wdata_i[19])
				ovr_r <= 1'b0;
			if (byte_done && rx_full)
				ovr_r <= 1'b1;
			if (!busy_r)
				sck_r <= cpol_r;
			if (tx_push) begin
				txq[tx_wr_r] <= wdata_i[7:0];
				tx_wr_r <= fnext(tx_wr_r);
			end
			if (tx_pop)
				tx_rd_r <= fnext(tx_rd_r);
			if (tx_push && !tx_pop)
				tx_cnt_r <= tx_cnt_r + 1'b1;
			else if (tx_pop && !tx_push)
				tx_cnt_r <= tx_cnt_r - 1'b1;
			if (rx_push) begin
				rxq[rx_wr_r] <= (cpha_r ? {rx_sh_r[6:0], miso_i} : rx_sh_r);
				rx_wr_r <= fnext(rx_wr_r);
			end
			if (rx_pop)
				rx_rd_r <= fnext(rx_rd_r);
			if (rx_push && !rx_pop)
				rx_cnt_r <= rx_cnt_r + 1'b1;
			else if (rx_pop && !rx_push)
				rx_cnt_r <= rx_cnt_r - 1'b1;
			if (tx_pop) begin
				busy_r <= 1'b1;
				half_r <= 1'b0;
				bit_r <= 3'd0;
				hcnt_r <= 16'h0000;
				tx_sh_r <= txq[tx_rd_r];
				sck_r <= cpol_r;
				if (!cpha_r)
					mosi_r <= txq[tx_rd_r][7];
			end
			else if (busy_r) begin
				if (!half_end)
					hcnt_r <= hcnt_r + 16'd1;
				else begin
					hcnt_r <= 16'h0000;
					sck_r <= !sck_r;
					if (!half_r) begin
						half_r <= 1'b1;
						if (!cpha_r)
							rx_sh_r <= {rx_sh_r[6:0], miso_i};
						else
							mosi_r <= tx_sh_r[3'd7 - bit_r];
					end
					else begin
						half_r <= 1'b0;
						if (cpha_r)
							rx_sh_r <= {rx_sh_r[6:0], miso_i};
						if (bit_r == 3'd7)
							busy_r <= 1'b0;
						else begin
							bit_r <= bit_r + 3'd1;
							if (!cpha_r)
								mosi_r <= tx_sh_r[3'd6 - bit_r];
						end
					end
				end
			end
		end
	initial _sv2v_0 = 0;
endmodule
module iocore_i2c (
	clk_i,
	rst_n_i,
	req_i,
	we_i,
	off_i,
	wdata_i,
	rdata_o,
	scl_low_o,
	sda_low_o,
	scl_i,
	sda_i,
	irq_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_n_i;
	input wire req_i;
	input wire we_i;
	input wire [11:0] off_i;
	input wire [31:0] wdata_i;
	output reg [31:0] rdata_o;
	output wire scl_low_o;
	output wire sda_low_o;
	input wire scl_i;
	input wire sda_i;
	output wire irq_o;
	localparam [11:0] I2C_DIV = 12'h400;
	localparam [11:0] I2C_CMD = 12'h404;
	localparam [11:0] I2C_STATUS = 12'h408;
	localparam [11:0] I2C_TIMEOUT = 12'h40c;
	localparam [11:0] I2C_CTRL = 12'h410;
	localparam [3:0] C_START = 4'd1;
	localparam [3:0] C_STOP = 4'd2;
	localparam [3:0] C_WRITE = 4'd3;
	localparam [3:0] C_READ = 4'd4;
	reg en_r;
	reg [15:0] div_r;
	reg [31:0] tmo_r;
	reg [2:0] kind_r;
	reg [3:0] cmd_r;
	reg rd_nack_r;
	reg [3:0] bit_r;
	reg [1:0] q_r;
	reg [15:0] cnt_r;
	reg [31:0] wait_r;
	reg waiting_r;
	reg [7:0] sh_r;
	reg [7:0] rx_r;
	reg nack_r;
	reg tmo_hit_r;
	reg held_r;
	reg scl_low_r;
	reg sda_low_r;
	wire busy;
	wire start_cmd;
	assign busy = kind_r != 3'd0;
	assign start_cmd = (((req_i && we_i) && (off_i == I2C_CMD)) && !busy) && en_r;
	assign scl_low_o = en_r && scl_low_r;
	assign sda_low_o = en_r && sda_low_r;
	assign irq_o = 1'b0;
	always @(*) begin
		if (_sv2v_0)
			;
		rdata_o = 32'h00000000;
		if (req_i && !we_i)
			case (off_i)
				I2C_DIV: rdata_o = {16'h0000, div_r};
				I2C_STATUS: rdata_o = {16'h0000, rx_r, 4'h0, held_r, tmo_hit_r, nack_r, busy};
				I2C_TIMEOUT: rdata_o = tmo_r;
				I2C_CTRL: rdata_o = {31'h00000000, en_r};
				default: rdata_o = 32'h00000000;
			endcase
	end
	function automatic data_bit;
		input reg [3:0] b;
		input reg [7:0] sh;
		input reg [3:0] cmd;
		input reg nack;
		if (b == 4'd8)
			data_bit = (cmd == C_WRITE ? 1'b1 : nack);
		else
			data_bit = (cmd == C_WRITE ? sh[3'd7 - b[2:0]] : 1'b1);
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			en_r <= 1'b0;
			div_r <= 16'h0000;
			tmo_r <= 32'h00100000;
			kind_r <= 3'd0;
			cmd_r <= 4'h0;
			rd_nack_r <= 1'b0;
			bit_r <= 4'h0;
			q_r <= 2'h0;
			cnt_r <= 16'h0000;
			wait_r <= 32'h00000000;
			waiting_r <= 1'b0;
			sh_r <= 8'h00;
			rx_r <= 8'h00;
			nack_r <= 1'b0;
			tmo_hit_r <= 1'b0;
			held_r <= 1'b0;
			scl_low_r <= 1'b0;
			sda_low_r <= 1'b0;
		end
		else begin
			if ((req_i && we_i) && (off_i == I2C_DIV))
				div_r <= wdata_i[15:0];
			if ((req_i && we_i) && (off_i == I2C_TIMEOUT))
				tmo_r <= wdata_i;
			if ((req_i && we_i) && (off_i == I2C_CTRL)) begin
				en_r <= wdata_i[0];
				if (!wdata_i[0]) begin
					kind_r <= 3'd0;
					held_r <= 1'b0;
					scl_low_r <= 1'b0;
					sda_low_r <= 1'b0;
				end
			end
			if (start_cmd) begin
				cmd_r <= wdata_i[3:0];
				rd_nack_r <= wdata_i[16];
				sh_r <= wdata_i[15:8];
				q_r <= 2'd0;
				cnt_r <= 16'h0000;
				waiting_r <= 1'b0;
				wait_r <= 32'h00000000;
				bit_r <= 4'd0;
				case (wdata_i[3:0])
					C_START: begin
						kind_r <= (held_r ? 3'd2 : 3'd1);
						tmo_hit_r <= 1'b0;
					end
					C_STOP: kind_r <= 3'd4;
					C_WRITE, C_READ: kind_r <= 3'd3;
					default: kind_r <= 3'd0;
				endcase
			end
			else if (busy) begin
				if (waiting_r) begin
					if (scl_i)
						waiting_r <= 1'b0;
					else if (wait_r >= tmo_r) begin
						tmo_hit_r <= 1'b1;
						kind_r <= 3'd0;
						held_r <= 1'b0;
						scl_low_r <= 1'b0;
						sda_low_r <= 1'b0;
					end
					else
						wait_r <= wait_r + 32'd1;
				end
				else if (cnt_r != div_r)
					cnt_r <= cnt_r + 16'd1;
				else begin
					cnt_r <= 16'h0000;
					q_r <= q_r + 2'd1;
					case (kind_r)
						3'd1:
							case (q_r)
								2'd0: sda_low_r <= 1'b1;
								2'd1: scl_low_r <= 1'b1;
								2'd2:
									;
								default: begin
									kind_r <= 3'd0;
									held_r <= 1'b1;
								end
							endcase
						3'd2:
							case (q_r)
								2'd0: begin
									scl_low_r <= 1'b0;
									waiting_r <= 1'b1;
									wait_r <= 32'h00000000;
								end
								2'd1: sda_low_r <= 1'b1;
								2'd2: scl_low_r <= 1'b1;
								default: kind_r <= 3'd0;
							endcase
						3'd4:
							case (q_r)
								2'd0: begin
									scl_low_r <= 1'b0;
									waiting_r <= 1'b1;
									wait_r <= 32'h00000000;
								end
								2'd1: sda_low_r <= 1'b0;
								2'd2:
									;
								default: begin
									kind_r <= 3'd0;
									held_r <= 1'b0;
								end
							endcase
						3'd3:
							case (q_r)
								2'd0: begin
									scl_low_r <= 1'b0;
									waiting_r <= 1'b1;
									wait_r <= 32'h00000000;
								end
								2'd1:
									if (bit_r == 4'd8) begin
										if (cmd_r == C_WRITE)
											nack_r <= sda_i;
									end
									else if (cmd_r == C_READ)
										rx_r <= {rx_r[6:0], sda_i};
								2'd2: scl_low_r <= 1'b1;
								default:
									if (bit_r == 4'd8) begin
										kind_r <= 3'd0;
										sda_low_r <= 1'b0;
									end
									else begin
										bit_r <= bit_r + 4'd1;
										sda_low_r <= !data_bit(bit_r + 4'd1, sh_r, cmd_r, rd_nack_r);
									end
							endcase
						default: kind_r <= 3'd0;
					endcase
				end
			end
			if (start_cmd && ((wdata_i[3:0] == C_WRITE) || (wdata_i[3:0] == C_READ)))
				sda_low_r <= (wdata_i[3:0] == C_WRITE ? !wdata_i[15] : 1'b0);
			if (start_cmd && (wdata_i[3:0] == C_STOP))
				sda_low_r <= 1'b1;
			if ((start_cmd && (wdata_i[3:0] == C_START)) && held_r)
				sda_low_r <= 1'b0;
			if ((start_cmd && (wdata_i[3:0] == C_START)) && !held_r) begin
				scl_low_r <= 1'b0;
				sda_low_r <= 1'b0;
			end
		end
	initial _sv2v_0 = 0;
endmodule
module iocore_wdt (
	clk_i,
	rst_n_i,
	req_i,
	we_i,
	off_i,
	wdata_i,
	rdata_o,
	tick_i,
	wdt_reset_o
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_n_i;
	input wire req_i;
	input wire we_i;
	input wire [11:0] off_i;
	input wire [31:0] wdata_i;
	output reg [31:0] rdata_o;
	input wire tick_i;
	output reg wdt_reset_o;
	localparam [11:0] WDT_LOAD = 12'h500;
	localparam [11:0] WDT_CTRL = 12'h504;
	localparam [11:0] WDT_KICK = 12'h508;
	localparam [11:0] WDT_COUNT = 12'h50c;
	localparam [31:0] KEY = 32'h6b1df00d;
	localparam [31:0] STOP_KEY = 32'h5709dead;
	reg [31:0] load_r;
	reg [31:0] count_r;
	reg started_r;
	wire wr;
	assign wr = req_i && we_i;
	wire [31:0] cur;
	assign cur = ((wr && (off_i == WDT_KICK)) && (wdata_i == KEY) ? load_r : count_r);
	always @(*) begin
		if (_sv2v_0)
			;
		rdata_o = 32'h00000000;
		if (req_i && !we_i)
			case (off_i)
				WDT_LOAD: rdata_o = load_r;
				WDT_CTRL: rdata_o = {31'h00000000, started_r};
				WDT_COUNT: rdata_o = count_r;
				default: rdata_o = 32'h00000000;
			endcase
	end
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			load_r <= 32'h00000000;
			count_r <= 32'h00000000;
			started_r <= 1'b0;
			wdt_reset_o <= 1'b0;
		end
		else begin
			wdt_reset_o <= 1'b0;
			if ((wr && (off_i == WDT_LOAD)) && !started_r)
				load_r <= wdata_i;
			if (!started_r) begin
				if ((wr && (off_i == WDT_CTRL)) && wdata_i[0]) begin
					started_r <= 1'b1;
					count_r <= load_r;
				end
			end
			else if ((wr && (off_i == WDT_KICK)) && (wdata_i == STOP_KEY)) begin
				started_r <= 1'b0;
				count_r <= 32'h00000000;
			end
			else if (tick_i) begin
				if (cur <= 32'd1) begin
					count_r <= 32'h00000000;
					started_r <= 1'b0;
					wdt_reset_o <= 1'b1;
				end
				else
					count_r <= cur - 32'd1;
			end
			else
				count_r <= cur;
		end
	initial _sv2v_0 = 0;
endmodule
module iocore_adc (
	clk_i,
	rst_n_i,
	req_i,
	we_i,
	off_i,
	wdata_i,
	rdata_o,
	adc_start_o,
	adc_chan_o,
	adc_done_i,
	adc_code_i
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_n_i;
	input wire req_i;
	input wire we_i;
	input wire [11:0] off_i;
	input wire [31:0] wdata_i;
	output reg [31:0] rdata_o;
	output reg adc_start_o;
	output reg [3:0] adc_chan_o;
	input wire adc_done_i;
	input wire [11:0] adc_code_i;
	localparam [11:0] ADC_CTRL = 12'h800;
	localparam [11:0] ADC_DATA = 12'h804;
	localparam [11:0] ADC_STATUS = 12'h808;
	reg busy_r;
	reg valid_r;
	reg [15:0] data_r;
	wire start;
	assign start = (((req_i && we_i) && (off_i == ADC_CTRL)) && wdata_i[8]) && !busy_r;
	always @(*) begin
		if (_sv2v_0)
			;
		rdata_o = 32'h00000000;
		if (req_i && !we_i)
			case (off_i)
				ADC_CTRL: rdata_o = {28'h0000000, adc_chan_o};
				ADC_DATA: rdata_o = {valid_r, 15'h0000, data_r};
				ADC_STATUS: rdata_o = {31'h00000000, busy_r};
				default: rdata_o = 32'h00000000;
			endcase
	end
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			busy_r <= 1'b0;
			valid_r <= 1'b0;
			data_r <= 16'h0000;
			adc_start_o <= 1'b0;
			adc_chan_o <= 4'h0;
		end
		else begin
			adc_start_o <= 1'b0;
			if (start) begin
				busy_r <= 1'b1;
				valid_r <= 1'b0;
				adc_chan_o <= wdata_i[3:0];
				adc_start_o <= 1'b1;
			end
			else if (busy_r && adc_done_i) begin
				busy_r <= 1'b0;
				valid_r <= 1'b1;
				data_r <= {adc_code_i, 4'h0};
			end
		end
	initial _sv2v_0 = 0;
endmodule
module iocore_pinmux (
	clk_i,
	rst_n_i,
	req_i,
	we_i,
	off_i,
	wdata_i,
	rdata_o,
	gpio_out_i,
	gpio_oe_i,
	pwm_i,
	spi_sck_i,
	spi_mosi_i,
	i2c_scl_low_i,
	i2c_sda_low_i,
	uart_txd_i,
	uart_rxd_pin_i,
	spi_miso_o,
	i2c_scl_o,
	i2c_sda_o,
	uart_rxd_o,
	pad_out_o,
	pad_oe_o,
	pad_in_i
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_n_i;
	input wire req_i;
	input wire we_i;
	input wire [11:0] off_i;
	input wire [31:0] wdata_i;
	output reg [31:0] rdata_o;
	input wire [15:0] gpio_out_i;
	input wire [15:0] gpio_oe_i;
	input wire [3:0] pwm_i;
	input wire spi_sck_i;
	input wire spi_mosi_i;
	input wire i2c_scl_low_i;
	input wire i2c_sda_low_i;
	input wire uart_txd_i;
	input wire uart_rxd_pin_i;
	output reg spi_miso_o;
	output reg i2c_scl_o;
	output reg i2c_sda_o;
	output reg uart_rxd_o;
	output reg [15:0] pad_out_o;
	output reg [15:0] pad_oe_o;
	input wire [15:0] pad_in_i;
	localparam [11:0] PINMUX0 = 12'h900;
	localparam [11:0] PINMUX1 = 12'h904;
	localparam [3:0] F_GPIO = 4'd0;
	localparam [3:0] F_SCK = 4'd5;
	localparam [3:0] F_MOSI = 4'd6;
	localparam [3:0] F_MISO = 4'd7;
	localparam [3:0] F_SCL = 4'd8;
	localparam [3:0] F_SDA = 4'd9;
	localparam [3:0] F_TX = 4'd10;
	localparam [3:0] F_RX = 4'd11;
	reg [31:0] mux_r [0:1];
	reg [3:0] fn [0:15];
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < 16; i = i + 1)
				fn[i] = mux_r[i / 8][4 * (i % 8)+:4];
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		rdata_o = 32'h00000000;
		if (req_i && !we_i) begin
			if (off_i == PINMUX0)
				rdata_o = mux_r[0];
			if (off_i == PINMUX1)
				rdata_o = mux_r[1];
		end
	end
	always @(*) begin : sv2v_autoblock_2
		reg miso_seen;
		reg scl_seen;
		reg sda_seen;
		reg rx_seen;
		if (_sv2v_0)
			;
		miso_seen = 1'b0;
		scl_seen = 1'b0;
		sda_seen = 1'b0;
		rx_seen = 1'b0;
		spi_miso_o = 1'b0;
		i2c_scl_o = 1'b1;
		i2c_sda_o = 1'b1;
		uart_rxd_o = uart_rxd_pin_i;
		begin : sv2v_autoblock_3
			reg signed [31:0] i;
			for (i = 0; i < 16; i = i + 1)
				begin
					case (fn[i])
						F_GPIO: begin
							pad_out_o[i] = gpio_out_i[i];
							pad_oe_o[i] = gpio_oe_i[i];
						end
						4'd1, 4'd2, 4'd3, 4'd4: begin
							pad_out_o[i] = pwm_i[fn[i] - 4'd1];
							pad_oe_o[i] = 1'b1;
						end
						F_SCK: begin
							pad_out_o[i] = spi_sck_i;
							pad_oe_o[i] = 1'b1;
						end
						F_MOSI: begin
							pad_out_o[i] = spi_mosi_i;
							pad_oe_o[i] = 1'b1;
						end
						F_SCL: begin
							pad_out_o[i] = 1'b0;
							pad_oe_o[i] = i2c_scl_low_i;
						end
						F_SDA: begin
							pad_out_o[i] = 1'b0;
							pad_oe_o[i] = i2c_sda_low_i;
						end
						F_TX: begin
							pad_out_o[i] = uart_txd_i;
							pad_oe_o[i] = 1'b1;
						end
						default: begin
							pad_out_o[i] = 1'b0;
							pad_oe_o[i] = 1'b0;
						end
					endcase
					if ((fn[i] == F_MISO) && !miso_seen) begin
						spi_miso_o = pad_in_i[i];
						miso_seen = 1'b1;
					end
					if ((fn[i] == F_SCL) && !scl_seen) begin
						i2c_scl_o = pad_in_i[i];
						scl_seen = 1'b1;
					end
					if ((fn[i] == F_SDA) && !sda_seen) begin
						i2c_sda_o = pad_in_i[i];
						sda_seen = 1'b1;
					end
					if ((fn[i] == F_RX) && !rx_seen) begin
						uart_rxd_o = pad_in_i[i];
						rx_seen = 1'b1;
					end
				end
		end
	end
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			mux_r[0] <= 32'h00000000;
			mux_r[1] <= 32'h00000000;
		end
		else if (req_i && we_i) begin
			if (off_i == PINMUX0)
				mux_r[0] <= wdata_i;
			if (off_i == PINMUX1)
				mux_r[1] <= wdata_i;
		end
	initial _sv2v_0 = 0;
endmodule
module iocore_ahb2obi (
	clk_i,
	rst_n_i,
	haddr_i,
	hwrite_i,
	htrans_i,
	hsize_i,
	hwdata_i,
	hready_o,
	hresp_o,
	hrdata_o,
	req_o,
	gnt_i,
	we_o,
	be_o,
	addr_o,
	wdata_o,
	rvalid_i,
	rdata_i,
	err_i
);
	reg _sv2v_0;
	input wire clk_i;
	input wire rst_n_i;
	input wire [31:0] haddr_i;
	input wire hwrite_i;
	input wire [1:0] htrans_i;
	input wire [2:0] hsize_i;
	input wire [31:0] hwdata_i;
	output wire hready_o;
	output wire hresp_o;
	output wire [31:0] hrdata_o;
	output reg req_o;
	input wire gnt_i;
	output reg we_o;
	output reg [3:0] be_o;
	output reg [31:0] addr_o;
	output wire [31:0] wdata_o;
	input wire rvalid_i;
	input wire [31:0] rdata_i;
	input wire err_i;
	reg dp;
	reg dp_we;
	reg need;
	reg err2;
	reg [31:0] dp_addr;
	reg [2:0] dp_size;
	wire aph_go;
	wire aph_rd;
	function automatic [3:0] be_of;
		input reg [2:0] sz;
		input reg [1:0] a;
		case (sz)
			3'd0: be_of = 4'b0001 << a;
			3'd1: be_of = (a[1] ? 4'b1100 : 4'b0011);
			default: be_of = 4'b1111;
		endcase
	endfunction
	assign hready_o = !dp || ((!need && rvalid_i) && !err_i);
	assign hresp_o = err2 || (((dp && !need) && rvalid_i) && err_i);
	assign hrdata_o = rdata_i;
	assign aph_go = htrans_i[1] && hready_o;
	assign aph_rd = aph_go && !hwrite_i;
	always @(*) begin
		if (_sv2v_0)
			;
		if (dp && need) begin
			req_o = 1'b1;
			we_o = dp_we;
			addr_o = dp_addr;
			be_o = be_of(dp_size, dp_addr[1:0]);
		end
		else begin
			req_o = aph_rd;
			we_o = 1'b0;
			addr_o = haddr_i;
			be_o = be_of(hsize_i, haddr_i[1:0]);
		end
	end
	assign wdata_o = hwdata_i;
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			dp <= 1'b0;
			dp_we <= 1'b0;
			need <= 1'b0;
			err2 <= 1'b0;
			dp_addr <= 32'h00000000;
			dp_size <= 3'd0;
		end
		else begin
			err2 <= ((dp && !need) && rvalid_i) && err_i;
			if (dp && need) begin
				if (gnt_i)
					need <= 1'b0;
			end
			else begin
				if ((dp && !need) && rvalid_i)
					dp <= 1'b0;
				if (aph_go) begin
					dp <= 1'b1;
					dp_we <= hwrite_i;
					dp_addr <= haddr_i;
					dp_size <= hsize_i;
					need <= hwrite_i || !gnt_i;
				end
			end
		end
	initial _sv2v_0 = 0;
endmodule
module iocore_cpu (
	clk_i,
	rst_n_i,
	i_req_o,
	i_gnt_i,
	i_addr_o,
	i_rvalid_i,
	i_rdata_i,
	i_err_i,
	d_req_o,
	d_gnt_i,
	d_we_o,
	d_be_o,
	d_addr_o,
	d_wdata_o,
	d_rvalid_i,
	d_rdata_i,
	d_err_i,
	irq_timer_i,
	irq_ext_i,
	core_sleep_o
);
	parameter signed [31:0] CORE = 0;
	parameter signed [31:0] MUL = 0;
	input wire clk_i;
	input wire rst_n_i;
	output wire i_req_o;
	input wire i_gnt_i;
	output wire [31:0] i_addr_o;
	input wire i_rvalid_i;
	input wire [31:0] i_rdata_i;
	input wire i_err_i;
	output wire d_req_o;
	input wire d_gnt_i;
	output wire d_we_o;
	output wire [3:0] d_be_o;
	output wire [31:0] d_addr_o;
	output wire [31:0] d_wdata_o;
	input wire d_rvalid_i;
	input wire [31:0] d_rdata_i;
	input wire d_err_i;
	input wire irq_timer_i;
	input wire irq_ext_i;
	output wire core_sleep_o;
	localparam [31:0] BOOT = 32'h00000080;
	generate
		if (CORE == 0) begin : g_cve2
			localparam [9:0] sv2v_uu_u_core_ext_ram_cfg_i_0 = 1'sb0;
			localparam [31:0] sv2v_uu_u_core_cve2_pkg_X_DUAL_READ = 0;
			localparam [31:0] sv2v_uu_u_core_cve2_pkg_X_DUAL_WRITE = 0;
			localparam [31:0] sv2v_uu_u_core_cve2_pkg_X_NUM_RS = 3;
			localparam [(2 + (sv2v_uu_u_core_cve2_pkg_X_NUM_RS + sv2v_uu_u_core_cve2_pkg_X_DUAL_READ)) - 1:0] sv2v_uu_u_core_ext_x_issue_resp_i_0 = 1'sb0;
			localparam [31:0] sv2v_uu_u_core_cve2_pkg_X_HARTID_WIDTH = 32;
			localparam [31:0] sv2v_uu_u_core_cve2_pkg_X_ID_WIDTH = 4;
			localparam [31:0] sv2v_uu_u_core_cve2_pkg_X_RFW_WIDTH = 32;
			localparam [((sv2v_uu_u_core_cve2_pkg_X_HARTID_WIDTH + sv2v_uu_u_core_cve2_pkg_X_ID_WIDTH) + sv2v_uu_u_core_cve2_pkg_X_RFW_WIDTH) + 5:0] sv2v_uu_u_core_ext_x_result_i_0 = 1'sb0;
			cve2_top #(
				.MHPMCounterNum(0),
				.RV32E(1'b1),
				.RV32M((MUL != 0 ? 32'sd2 : 32'sd1))
			) u_core(
				.clk_i(clk_i),
				.rst_ni(rst_n_i),
				.test_en_i(1'b0),
				.ram_cfg_i(sv2v_uu_u_core_ext_ram_cfg_i_0),
				.hart_id_i(32'h00000000),
				.boot_addr_i(BOOT),
				.instr_req_o(i_req_o),
				.instr_gnt_i(i_gnt_i),
				.instr_rvalid_i(i_rvalid_i),
				.instr_addr_o(i_addr_o),
				.instr_rdata_i(i_rdata_i),
				.instr_err_i(i_err_i),
				.data_req_o(d_req_o),
				.data_gnt_i(d_gnt_i),
				.data_rvalid_i(d_rvalid_i),
				.data_we_o(d_we_o),
				.data_be_o(d_be_o),
				.data_addr_o(d_addr_o),
				.data_wdata_o(d_wdata_o),
				.data_rdata_i(d_rdata_i),
				.data_err_i(d_err_i),
				.x_issue_valid_o(),
				.x_issue_ready_i(1'b0),
				.x_issue_req_o(),
				.x_issue_resp_i(sv2v_uu_u_core_ext_x_issue_resp_i_0),
				.x_register_o(),
				.x_commit_valid_o(),
				.x_commit_o(),
				.x_result_valid_i(1'b0),
				.x_result_ready_o(),
				.x_result_i(sv2v_uu_u_core_ext_x_result_i_0),
				.irq_software_i(1'b0),
				.irq_timer_i(irq_timer_i),
				.irq_external_i(irq_ext_i),
				.irq_fast_i(16'h0000),
				.irq_nm_i(1'b0),
				.debug_req_i(1'b0),
				.debug_halted_o(),
				.dm_halt_addr_i(32'h00000000),
				.dm_exception_addr_i(32'h00000000),
				.crash_dump_o(),
				.fetch_enable_i(1'b1),
				.core_sleep_o(core_sleep_o)
			);
		end
		else begin : g_hazard3
			wire [31:0] ih_addr;
			wire [31:0] dh_addr;
			wire [31:0] dh_wdata;
			wire [31:0] ih_rdata;
			wire [31:0] dh_rdata;
			wire [1:0] ih_trans;
			wire [1:0] dh_trans;
			wire [2:0] ih_size;
			wire [2:0] dh_size;
			wire dh_write;
			wire ih_ready;
			wire dh_ready;
			wire ih_resp;
			wire dh_resp;
			wire clk_en;
			hazard3_cpu_2port #(
				.RESET_VECTOR(BOOT),
				.MTVEC_INIT(32'h00000001),
				.EXTENSION_A(0),
				.EXTENSION_C(1),
				.EXTENSION_E(1),
				.EXTENSION_M(1),
				.EXTENSION_ZBA(0),
				.EXTENSION_ZBB(0),
				.EXTENSION_ZBC(0),
				.EXTENSION_ZBKB(0),
				.EXTENSION_ZBKX(0),
				.EXTENSION_ZBS(0),
				.EXTENSION_ZCB(0),
				.EXTENSION_ZCLSD(0),
				.EXTENSION_ZCMP(0),
				.EXTENSION_ZIFENCEI(0),
				.EXTENSION_ZILSD(0),
				.EXTENSION_XH3BEXTM(0),
				.EXTENSION_XH3IRQ(0),
				.EXTENSION_XH3PMPM(0),
				.EXTENSION_XH3POWER(0),
				.CSR_M_MANDATORY(1),
				.CSR_M_TRAP(1),
				.CSR_COUNTER(0),
				.U_MODE(0),
				.PMP_REGIONS(0),
				.DEBUG_SUPPORT(0),
				.BREAKPOINT_TRIGGERS(0),
				.NUM_IRQS(1),
				.MUL_FAST((MUL != 0 ? 1 : 0)),
				.MULH_FAST(0)
			) u_core(
				.clk(clk_i),
				.clk_always_on(clk_i),
				.rst_n(rst_n_i),
				.pwrup_req(),
				.pwrup_ack(1'b1),
				.clk_en(clk_en),
				.unblock_out(),
				.unblock_in(1'b0),
				.i_haddr(ih_addr),
				.i_hwrite(),
				.i_htrans(ih_trans),
				.i_hsize(ih_size),
				.i_hburst(),
				.i_hprot(),
				.i_hmastlock(),
				.i_hmaster(),
				.i_hready(ih_ready),
				.i_hresp(ih_resp),
				.i_hwdata(),
				.i_hrdata(ih_rdata),
				.d_haddr(dh_addr),
				.d_hwrite(dh_write),
				.d_htrans(dh_trans),
				.d_hsize(dh_size),
				.d_hburst(),
				.d_hprot(),
				.d_hmastlock(),
				.d_hmaster(),
				.d_hexcl(),
				.d_hready(dh_ready),
				.d_hresp(dh_resp),
				.d_hexokay(1'b1),
				.d_hwdata(dh_wdata),
				.d_hrdata(dh_rdata),
				.fence_i_vld(),
				.fence_d_vld(),
				.fence_rdy(1'b1),
				.dbg_req_halt(1'b0),
				.dbg_req_halt_on_reset(1'b0),
				.dbg_req_resume(1'b0),
				.dbg_halted(),
				.dbg_running(),
				.dbg_data0_rdata(32'h00000000),
				.dbg_data0_wdata(),
				.dbg_data0_wen(),
				.dbg_instr_data(32'h00000000),
				.dbg_instr_data_vld(1'b0),
				.dbg_instr_data_rdy(),
				.dbg_instr_caught_exception(),
				.dbg_instr_caught_ebreak(),
				.dbg_sbus_addr(32'h00000000),
				.dbg_sbus_write(1'b0),
				.dbg_sbus_size(2'b00),
				.dbg_sbus_vld(1'b0),
				.dbg_sbus_rdy(),
				.dbg_sbus_err(),
				.dbg_sbus_wdata(32'h00000000),
				.dbg_sbus_rdata(),
				.mhartid_val(32'h00000000),
				.eco_version(4'h0),
				.irq(irq_ext_i),
				.soft_irq(1'b0),
				.timer_irq(irq_timer_i)
			);
			assign core_sleep_o = !clk_en;
			iocore_ahb2obi u_iad(
				.clk_i(clk_i),
				.rst_n_i(rst_n_i),
				.haddr_i(ih_addr),
				.hwrite_i(1'b0),
				.htrans_i(ih_trans),
				.hsize_i(ih_size),
				.hwdata_i(32'h00000000),
				.hready_o(ih_ready),
				.hresp_o(ih_resp),
				.hrdata_o(ih_rdata),
				.req_o(i_req_o),
				.gnt_i(i_gnt_i),
				.we_o(),
				.be_o(),
				.addr_o(i_addr_o),
				.wdata_o(),
				.rvalid_i(i_rvalid_i),
				.rdata_i(i_rdata_i),
				.err_i(i_err_i)
			);
			iocore_ahb2obi u_dad(
				.clk_i(clk_i),
				.rst_n_i(rst_n_i),
				.haddr_i(dh_addr),
				.hwrite_i(dh_write),
				.htrans_i(dh_trans),
				.hsize_i(dh_size),
				.hwdata_i(dh_wdata),
				.hready_o(dh_ready),
				.hresp_o(dh_resp),
				.hrdata_o(dh_rdata),
				.req_o(d_req_o),
				.gnt_i(d_gnt_i),
				.we_o(d_we_o),
				.be_o(d_be_o),
				.addr_o(d_addr_o),
				.wdata_o(d_wdata_o),
				.rvalid_i(d_rvalid_i),
				.rdata_i(d_rdata_i),
				.err_i(d_err_i)
			);
		end
	endgenerate
endmodule
module iocore_top (
	io_clk_i,
	io_rst_n_i,
	run_i,
	con_mode_i,
	ld_valid_i,
	ld_data_i,
	ld_pop_o,
	cmd_pop_o,
	cmd_data_i,
	cmd_empty_i,
	cmd_level_i,
	rsp_push_o,
	rsp_data_o,
	rsp_full_i,
	evt_push_o,
	evt_data_o,
	evt_full_i,
	con_pop_o,
	con_data_i,
	con_empty_i,
	con_level_i,
	conrx_push_o,
	conrx_data_o,
	conrx_full_i,
	upd_push_o,
	upd_data_o,
	upd_full_i,
	dn_pop_o,
	dn_data_i,
	dn_empty_i,
	uart_rxd_i,
	uart_txd_o,
	gpio_o,
	gpio_oe_o,
	gpio_pu_o,
	gpio_pd_o,
	gpio_i,
	adc_start_o,
	adc_chan_o,
	adc_done_i,
	adc_code_i,
	wdt_toggle_o,
	usb_clk_i,
	usb_dp_io,
	usb_dn_io,
	usb_pu_o,
	us_gray_o,
	ms_gray_o,
	dbg_valid_o,
	dbg_byte_o,
	halt_o,
	halt_value_o,
	sleep_o
);
	reg _sv2v_0;
	parameter signed [31:0] CORE = 0;
	parameter signed [31:0] MUL = 0;
	parameter signed [31:0] CODE_WORDS = 4096;
	parameter signed [31:0] DATA_WORDS = 1920;
	parameter [15:0] US_DIV_RESET = 16'd49;
	parameter [15:0] BAUD_RESET = 16'd0;
	parameter signed [31:0] NPINS = 16;
	parameter signed [31:0] IOCLK_HZ = 50000000;
	input wire io_clk_i;
	input wire io_rst_n_i;
	input wire run_i;
	input wire [1:0] con_mode_i;
	input wire ld_valid_i;
	input wire [48:0] ld_data_i;
	output wire ld_pop_o;
	output wire cmd_pop_o;
	input wire [31:0] cmd_data_i;
	input wire cmd_empty_i;
	input wire [5:0] cmd_level_i;
	output wire rsp_push_o;
	output wire [31:0] rsp_data_o;
	input wire rsp_full_i;
	output wire evt_push_o;
	output wire [15:0] evt_data_o;
	input wire evt_full_i;
	output wire con_pop_o;
	input wire [8:0] con_data_i;
	input wire con_empty_i;
	input wire [6:0] con_level_i;
	output wire conrx_push_o;
	output wire [7:0] conrx_data_o;
	input wire conrx_full_i;
	output wire upd_push_o;
	output wire [36:0] upd_data_o;
	input wire upd_full_i;
	output wire dn_pop_o;
	input wire [34:0] dn_data_i;
	input wire dn_empty_i;
	input wire uart_rxd_i;
	output wire uart_txd_o;
	output wire [NPINS - 1:0] gpio_o;
	output wire [NPINS - 1:0] gpio_oe_o;
	output wire [NPINS - 1:0] gpio_pu_o;
	output wire [NPINS - 1:0] gpio_pd_o;
	input wire [NPINS - 1:0] gpio_i;
	output wire adc_start_o;
	output wire [3:0] adc_chan_o;
	input wire adc_done_i;
	input wire [11:0] adc_code_i;
	output reg wdt_toggle_o;
	input wire usb_clk_i;
	inout wire usb_dp_io;
	inout wire usb_dn_io;
	output wire usb_pu_o;
	output reg [31:0] us_gray_o;
	output reg [31:0] ms_gray_o;
	output reg dbg_valid_o;
	output reg [7:0] dbg_byte_o;
	output reg halt_o;
	output reg [31:0] halt_value_o;
	output wire sleep_o;
	localparam signed [31:0] CAW = $clog2(CODE_WORDS);
	localparam signed [31:0] DAW = $clog2(DATA_WORDS);
	localparam [31:0] ID = 32'h494f4301;
	reg [1:0] run_q;
	wire core_rst_n;
	always @(posedge io_clk_i or negedge io_rst_n_i)
		if (!io_rst_n_i)
			run_q <= 2'b00;
		else
			run_q <= {run_q[0], run_i};
	assign core_rst_n = run_q[1];
	wire i_req;
	wire i_gnt;
	reg i_rvalid;
	reg i_err;
	wire [31:0] i_addr;
	wire [31:0] i_rdata;
	wire d_req;
	wire d_gnt;
	reg d_rvalid;
	wire d_we;
	reg d_err;
	wire [3:0] d_be;
	wire [31:0] d_addr;
	wire [31:0] d_wdata;
	wire [31:0] d_rdata;
	wire irq_timer;
	wire irq_ext;
	iocore_cpu #(
		.CORE(CORE),
		.MUL(MUL)
	) u_cpu(
		.clk_i(io_clk_i),
		.rst_n_i(core_rst_n),
		.i_req_o(i_req),
		.i_gnt_i(i_gnt),
		.i_addr_o(i_addr),
		.i_rvalid_i(i_rvalid),
		.i_rdata_i(i_rdata),
		.i_err_i(i_err),
		.d_req_o(d_req),
		.d_gnt_i(d_gnt),
		.d_we_o(d_we),
		.d_be_o(d_be),
		.d_addr_o(d_addr),
		.d_wdata_o(d_wdata),
		.d_rvalid_i(d_rvalid),
		.d_rdata_i(d_rdata),
		.d_err_i(d_err),
		.irq_timer_i(irq_timer),
		.irq_ext_i(irq_ext),
		.core_sleep_o(sleep_o)
	);
	wire ld_we;
	wire ld_data;
	wire [15:0] ld_idx_i;
	wire [31:0] ld_wdata_i;
	assign ld_we = ld_valid_i;
	assign ld_pop_o = ld_valid_i;
	assign ld_data = ld_data_i[48];
	assign ld_idx_i = ld_data_i[47:32];
	assign ld_wdata_i = ld_data_i[31:0];
	wire c_v;
	wire c_w;
	wire [CAW - 1:0] c_a;
	wire [31:0] c_d;
	wire [31:0] c_q;
	wire i_bad;
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	assign i_bad = i_addr >= sv2v_cast_32_signed(CODE_WORDS * 4);
	assign i_gnt = i_req && core_rst_n;
	assign c_v = (ld_we ? !ld_data : (i_req && i_gnt) && !i_bad);
	assign c_w = ld_we;
	function automatic [CAW - 1:0] sv2v_cast_5C013;
		input reg [CAW - 1:0] inp;
		sv2v_cast_5C013 = inp;
	endfunction
	assign c_a = (ld_we ? sv2v_cast_5C013(ld_idx_i) : i_addr[CAW + 1:2]);
	assign c_d = ld_wdata_i;
	bsg_mem_1rw_sync_mask_write_bit #(
		.width_p(32),
		.els_p(CODE_WORDS)
	) u_code(
		.clk_i(io_clk_i),
		.reset_i(1'b0),
		.data_i(c_d),
		.addr_i(c_a),
		.v_i(c_v),
		.w_mask_i(32'hffffffff),
		.w_i(c_w),
		.data_o(c_q)
	);
	always @(posedge io_clk_i or negedge core_rst_n)
		if (!core_rst_n) begin
			i_rvalid <= 1'b0;
			i_err <= 1'b0;
		end
		else begin
			i_rvalid <= i_req && i_gnt;
			i_err <= (i_req && i_gnt) && i_bad;
		end
	assign i_rdata = c_q;
	localparam [3:0] R_NONE = 4'd0;
	localparam [3:0] R_DATA = 4'd1;
	localparam [3:0] R_SYS = 4'd2;
	localparam [3:0] R_TIMER = 4'd3;
	localparam [3:0] R_UART = 4'd4;
	localparam [3:0] R_BRIDGE = 4'd5;
	localparam [3:0] R_GPIO = 4'd6;
	localparam [3:0] R_PWM = 4'd7;
	localparam [3:0] R_SPI = 4'd8;
	localparam [3:0] R_I2C = 4'd9;
	localparam [3:0] R_WDT = 4'd10;
	localparam [3:0] R_ADC = 4'd11;
	localparam [3:0] R_MUX = 4'd12;
	localparam [3:0] R_USB = 4'd13;
	localparam [3:0] R_USB_RX = 4'd14;
	localparam [3:0] R_USB_TX = 4'd15;
	function automatic [17:0] sv2v_cast_18;
		input reg [17:0] inp;
		sv2v_cast_18 = inp;
	endfunction
	function automatic [20:0] sv2v_cast_21;
		input reg [20:0] inp;
		sv2v_cast_21 = inp;
	endfunction
	function automatic [3:0] region;
		input reg [31:0] a;
		reg [0:1] _sv2v_jump;
		begin
			_sv2v_jump = 2'b00;
			if ((a >= 32'h00010000) && (a < (32'h00010000 + sv2v_cast_32_signed(DATA_WORDS * 4)))) begin
				region = R_DATA;
				_sv2v_jump = 2'b11;
			end
			if (_sv2v_jump == 2'b00) begin
				if (a[31:12] == 20'h80000) begin
					region = R_SYS;
					_sv2v_jump = 2'b11;
				end
				if (_sv2v_jump == 2'b00) begin
					if (a[31:12] == 20'h80001) begin
						region = R_TIMER;
						_sv2v_jump = 2'b11;
					end
					if (_sv2v_jump == 2'b00) begin
						if (a[31:12] == 20'h80002) begin
							region = R_UART;
							_sv2v_jump = 2'b11;
						end
						if (_sv2v_jump == 2'b00) begin
							if (a[31:12] == 20'h80003) begin
								region = R_BRIDGE;
								_sv2v_jump = 2'b11;
							end
							if (_sv2v_jump == 2'b00) begin
								if (a[31:12] == 20'h80004) begin
									region = R_GPIO;
									_sv2v_jump = 2'b11;
								end
								if (_sv2v_jump == 2'b00) begin
									if (a[31:12] == 20'h80005) begin
										region = R_PWM;
										_sv2v_jump = 2'b11;
									end
									if (_sv2v_jump == 2'b00) begin
										if (a[31:12] == 20'h80006) begin
											region = R_SPI;
											_sv2v_jump = 2'b11;
										end
										if (_sv2v_jump == 2'b00) begin
											if (a[31:12] == 20'h80007) begin
												region = R_I2C;
												_sv2v_jump = 2'b11;
											end
											if (_sv2v_jump == 2'b00) begin
												if (a[31:12] == 20'h80008) begin
													region = R_WDT;
													_sv2v_jump = 2'b11;
												end
												if (_sv2v_jump == 2'b00) begin
													if (a[31:12] == 20'h80009) begin
														region = R_ADC;
														_sv2v_jump = 2'b11;
													end
													if (_sv2v_jump == 2'b00) begin
														if (a[31:12] == 20'h8000a) begin
															region = R_MUX;
															_sv2v_jump = 2'b11;
														end
														if (_sv2v_jump == 2'b00) begin
															if (a[31:14] == sv2v_cast_18(32'h80010000 >> 14)) begin
																region = R_USB;
																_sv2v_jump = 2'b11;
															end
															if (_sv2v_jump == 2'b00) begin
																if (a[31:11] == sv2v_cast_21(32'h80020000 >> 11)) begin
																	region = R_USB_RX;
																	_sv2v_jump = 2'b11;
																end
																if (_sv2v_jump == 2'b00) begin
																	if (a[31:11] == sv2v_cast_21(32'h80030000 >> 11)) begin
																		region = R_USB_TX;
																		_sv2v_jump = 2'b11;
																	end
																	if (_sv2v_jump == 2'b00) begin
																		region = R_NONE;
																		_sv2v_jump = 2'b11;
																	end
																end
															end
														end
													end
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	endfunction
	wire [3:0] rgn;
	reg [3:0] sel_q;
	wire take;
	wire uart_ready;
	wire br_ready;
	reg [31:0] rdata_q;
	wire [31:0] timer_rdata;
	wire [31:0] uart_rdata;
	reg [31:0] sys_rdata;
	wire [31:0] br_rdata;
	wire [31:0] gpio_rdata;
	wire [31:0] pwm_rdata;
	wire [31:0] spi_rdata;
	wire [31:0] i2c_rdata;
	wire [31:0] wdt_rdata;
	wire [31:0] adc_rdata;
	wire [31:0] mux_rdata;
	wire uart_irq;
	wire br_irq;
	wire gpio_irq;
	wire spi_irq;
	wire i2c_irq;
	wire [7:0] off;
	wire bad_size;
	assign rgn = region(d_addr);
	assign off = d_addr[7:0];
	assign bad_size = (rgn != R_DATA) && ((d_be != 4'hf) || (d_addr[1:0] != 2'b00));
	reg pw_v;
	reg pw_we;
	reg [3:0] pw_rgn;
	reg [7:0] pw_off;
	reg [31:0] pw_wdata;
	wire ep_take;
	wire usb_busy;
	wire usb_done;
	wire usb_take;
	wire usb_irq;
	wire [31:0] usb_rdata;
	assign d_gnt = ((d_req && !pw_v) && !usb_busy) && ((((rgn != R_UART) || uart_ready) && ((rgn != R_BRIDGE) || br_ready)) || bad_size);
	assign take = d_req && d_gnt;
	assign ep_take = ((take && !bad_size) && (rgn >= R_PWM)) && (rgn <= R_MUX);
	assign usb_take = (take && !bad_size) && (rgn >= R_USB);
	always @(posedge io_clk_i or negedge core_rst_n)
		if (!core_rst_n) begin
			pw_v <= 1'b0;
			pw_we <= 1'b0;
			pw_rgn <= R_NONE;
			pw_off <= 8'h00;
			pw_wdata <= 32'h00000000;
		end
		else begin
			pw_v <= ep_take;
			pw_we <= d_we;
			pw_rgn <= rgn;
			pw_off <= off;
			pw_wdata <= d_wdata;
		end
	function automatic ep_req;
		input reg [3:0] r;
		ep_req = pw_v && (pw_rgn == r);
	endfunction
	reg m_v;
	reg m_w;
	reg [DAW - 1:0] m_a;
	reg [31:0] m_d;
	reg [31:0] m_mask;
	wire [31:0] m_q;
	function automatic [DAW - 1:0] sv2v_cast_99844;
		input reg [DAW - 1:0] inp;
		sv2v_cast_99844 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		if (ld_we) begin
			m_v = ld_data;
			m_w = 1'b1;
			m_a = sv2v_cast_99844(ld_idx_i);
			m_d = ld_wdata_i;
			m_mask = 1'sb1;
		end
		else begin
			m_v = take && (rgn == R_DATA);
			m_w = d_we;
			m_a = d_addr[DAW + 1:2];
			m_d = d_wdata;
			m_mask = {{8 {d_be[3]}}, {8 {d_be[2]}}, {8 {d_be[1]}}, {8 {d_be[0]}}};
		end
	end
	bsg_mem_1rw_sync_mask_write_bit #(
		.width_p(32),
		.els_p(DATA_WORDS)
	) u_data(
		.clk_i(io_clk_i),
		.reset_i(1'b0),
		.data_i(m_d),
		.addr_i(m_a),
		.v_i(m_v),
		.w_mask_i(m_mask),
		.w_i(m_w),
		.data_o(m_q)
	);
	localparam [7:0] S_ID = 8'h00;
	localparam [7:0] S_DEBUG = 8'h04;
	localparam [7:0] S_HALT = 8'h08;
	localparam [7:0] S_IRQ_PEND = 8'h0c;
	localparam [7:0] S_IRQ_EN = 8'h10;
	localparam [7:0] S_SCRATCH = 8'h14;
	localparam [7:0] S_FREQ = 8'h18;
	localparam [7:0] S_CON_MODE = 8'h1c;
	reg [1:0] cm_s1;
	reg [1:0] cm_s2;
	always @(posedge io_clk_i or negedge io_rst_n_i)
		if (!io_rst_n_i) begin
			cm_s1 <= 2'd0;
			cm_s2 <= 2'd0;
		end
		else begin
			cm_s1 <= con_mode_i;
			cm_s2 <= cm_s1;
		end
	wire [31:0] freq;
	assign freq = IOCLK_HZ;
	localparam signed [31:0] NIRQ = 8;
	wire [7:0] irq_src;
	reg [7:0] irq_en_r;
	reg [31:0] scratch_r;
	wire sys_sel;
	wire timer_sel;
	wire uart_sel;
	wire br_sel;
	wire gpio_sel;
	assign sys_sel = (take && !bad_size) && (rgn == R_SYS);
	assign timer_sel = (take && !bad_size) && (rgn == R_TIMER);
	assign uart_sel = (take && !bad_size) && (rgn == R_UART);
	assign br_sel = (take && !bad_size) && (rgn == R_BRIDGE);
	assign gpio_sel = (take && !bad_size) && (rgn == R_GPIO);
	assign irq_src = {{2 {1'b0}}, usb_irq, i2c_irq, spi_irq, gpio_irq, br_irq, uart_irq};
	assign irq_ext = |(irq_src & irq_en_r);
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		case (off)
			S_ID: sys_rdata = ID;
			S_IRQ_PEND: sys_rdata = sv2v_cast_32(irq_src);
			S_IRQ_EN: sys_rdata = sv2v_cast_32(irq_en_r);
			S_SCRATCH: sys_rdata = scratch_r;
			S_FREQ: sys_rdata = freq;
			S_CON_MODE: sys_rdata = {30'h00000000, cm_s2};
			default: sys_rdata = 32'h00000000;
		endcase
	end
	always @(posedge io_clk_i or negedge core_rst_n)
		if (!core_rst_n) begin
			irq_en_r <= 1'sb0;
			scratch_r <= 32'h00000000;
			dbg_valid_o <= 1'b0;
			dbg_byte_o <= 8'h00;
			halt_o <= 1'b0;
			halt_value_o <= 32'h00000000;
		end
		else begin
			dbg_valid_o <= 1'b0;
			if (sys_sel && d_we)
				case (off)
					S_DEBUG: begin
						dbg_valid_o <= 1'b1;
						dbg_byte_o <= d_wdata[7:0];
					end
					S_HALT: begin
						halt_o <= 1'b1;
						halt_value_o <= d_wdata;
					end
					S_IRQ_EN: irq_en_r <= d_wdata[7:0];
					S_SCRATCH: scratch_r <= d_wdata;
					default:
						;
				endcase
		end
	wire [31:0] us_bin;
	wire [31:0] ms_bin;
	wire ms_tick;
	iocore_timer #(.US_DIV_RESET(US_DIV_RESET)) u_timer(
		.clk_i(io_clk_i),
		.rst_n_i(core_rst_n),
		.sel_i(timer_sel),
		.we_i(d_we),
		.off_i(off),
		.wdata_i(d_wdata),
		.rdata_o(timer_rdata),
		.irq_o(irq_timer),
		.us_tick_o(),
		.ms_tick_o(ms_tick),
		.us_o(us_bin),
		.ms_o(ms_bin)
	);
	always @(posedge io_clk_i or negedge core_rst_n)
		if (!core_rst_n) begin
			us_gray_o <= 32'h00000000;
			ms_gray_o <= 32'h00000000;
		end
		else begin
			us_gray_o <= us_bin ^ (us_bin >> 1);
			ms_gray_o <= ms_bin ^ (ms_bin >> 1);
		end
	wire [NPINS - 1:0] g_out;
	wire [NPINS - 1:0] g_oe;
	iocore_gpio #(.NPINS(NPINS)) u_gpio(
		.clk_i(io_clk_i),
		.rst_n_i(core_rst_n),
		.sel_i(gpio_sel),
		.we_i(d_we),
		.off_i(off),
		.wdata_i(d_wdata),
		.rdata_o(gpio_rdata),
		.irq_o(gpio_irq),
		.out_o(g_out),
		.oe_o(g_oe),
		.pu_o(gpio_pu_o),
		.pd_o(gpio_pd_o),
		.in_i(gpio_i),
		.level_o(),
		.hit_o()
	);
	wire [3:0] pwm;
	wire spi_sck;
	wire spi_mosi;
	wire spi_miso;
	wire scl_low;
	wire sda_low;
	wire scl_in;
	wire sda_in;
	wire uart_rxd_mux;
	wire uart_txd;
	wire wdt_reset;
	iocore_pwm u_pwm(
		.clk_i(io_clk_i),
		.rst_n_i(core_rst_n),
		.req_i(ep_req(R_PWM)),
		.we_i(pw_we),
		.off_i({4'h2, pw_off}),
		.wdata_i(pw_wdata),
		.rdata_o(pwm_rdata),
		.pwm_o(pwm),
		.wrap_o()
	);
	iocore_spi u_spi(
		.clk_i(io_clk_i),
		.rst_n_i(core_rst_n),
		.req_i(ep_req(R_SPI)),
		.we_i(pw_we),
		.off_i({4'h3, pw_off}),
		.wdata_i(pw_wdata),
		.rdata_o(spi_rdata),
		.sck_o(spi_sck),
		.mosi_o(spi_mosi),
		.miso_i(spi_miso),
		.irq_o(spi_irq)
	);
	iocore_i2c u_i2c(
		.clk_i(io_clk_i),
		.rst_n_i(core_rst_n),
		.req_i(ep_req(R_I2C)),
		.we_i(pw_we),
		.off_i({4'h4, pw_off}),
		.wdata_i(pw_wdata),
		.rdata_o(i2c_rdata),
		.scl_low_o(scl_low),
		.sda_low_o(sda_low),
		.scl_i(scl_in),
		.sda_i(sda_in),
		.irq_o(i2c_irq)
	);
	iocore_wdt u_wdt(
		.clk_i(io_clk_i),
		.rst_n_i(core_rst_n),
		.req_i(ep_req(R_WDT)),
		.we_i(pw_we),
		.off_i({4'h5, pw_off}),
		.wdata_i(pw_wdata),
		.rdata_o(wdt_rdata),
		.tick_i(ms_tick),
		.wdt_reset_o(wdt_reset)
	);
	iocore_adc u_adc(
		.clk_i(io_clk_i),
		.rst_n_i(core_rst_n),
		.req_i(ep_req(R_ADC)),
		.we_i(pw_we),
		.off_i({4'h8, pw_off}),
		.wdata_i(pw_wdata),
		.rdata_o(adc_rdata),
		.adc_start_o(adc_start_o),
		.adc_chan_o(adc_chan_o),
		.adc_done_i(adc_done_i),
		.adc_code_i(adc_code_i)
	);
	iocore_pinmux u_mux(
		.clk_i(io_clk_i),
		.rst_n_i(core_rst_n),
		.req_i(ep_req(R_MUX)),
		.we_i(pw_we),
		.off_i({4'h9, pw_off}),
		.wdata_i(pw_wdata),
		.rdata_o(mux_rdata),
		.gpio_out_i(g_out),
		.gpio_oe_i(g_oe),
		.pwm_i(pwm),
		.spi_sck_i(spi_sck),
		.spi_mosi_i(spi_mosi),
		.i2c_scl_low_i(scl_low),
		.i2c_sda_low_i(sda_low),
		.uart_txd_i(uart_txd),
		.uart_rxd_pin_i(uart_rxd_i),
		.spi_miso_o(spi_miso),
		.i2c_scl_o(scl_in),
		.i2c_sda_o(sda_in),
		.uart_rxd_o(uart_rxd_mux),
		.pad_out_o(gpio_o),
		.pad_oe_o(gpio_oe_o),
		.pad_in_i(gpio_i)
	);
	assign uart_txd_o = uart_txd;
	always @(posedge io_clk_i or negedge io_rst_n_i)
		if (!io_rst_n_i)
			wdt_toggle_o <= 1'b0;
		else if (wdt_reset)
			wdt_toggle_o <= !wdt_toggle_o;
	iocore_uart #(.BAUD_RESET(BAUD_RESET)) u_uart(
		.clk_i(io_clk_i),
		.rst_n_i(core_rst_n),
		.sel_i(uart_sel),
		.we_i(d_we),
		.off_i(off),
		.wdata_i(d_wdata),
		.ready_o(uart_ready),
		.rdata_o(uart_rdata),
		.rxd_i(uart_rxd_mux),
		.txd_o(uart_txd),
		.irq_o(uart_irq),
		.rx_byte_o()
	);
	iocore_bridge u_bridge(
		.clk_i(io_clk_i),
		.rst_n_i(core_rst_n),
		.sel_i(br_sel),
		.we_i(d_we),
		.off_i(d_addr[11:0]),
		.wdata_i(d_wdata),
		.ready_o(br_ready),
		.rdata_o(br_rdata),
		.irq_o(br_irq),
		.cmd_pop_o(cmd_pop_o),
		.cmd_data_i(cmd_data_i),
		.cmd_empty_i(cmd_empty_i),
		.cmd_level_i(cmd_level_i),
		.rsp_push_o(rsp_push_o),
		.rsp_data_o(rsp_data_o),
		.rsp_full_i(rsp_full_i),
		.evt_push_o(evt_push_o),
		.evt_data_o(evt_data_o),
		.evt_full_i(evt_full_i),
		.con_pop_o(con_pop_o),
		.con_data_i(con_data_i),
		.con_empty_i(con_empty_i),
		.con_level_i(con_level_i),
		.conrx_push_o(conrx_push_o),
		.conrx_data_o(conrx_data_o),
		.conrx_full_i(conrx_full_i),
		.upd_push_o(upd_push_o),
		.upd_data_o(upd_data_o),
		.upd_full_i(upd_full_i),
		.dn_pop_o(dn_pop_o),
		.dn_data_i(dn_data_i),
		.dn_empty_i(dn_empty_i)
	);
	iocore_usb u_usb(
		.io_clk_i(io_clk_i),
		.rst_n_i(core_rst_n),
		.req_i(usb_take),
		.kind_i((rgn == R_USB ? 2'd0 : (rgn == R_USB_RX ? 2'd1 : 2'd2))),
		.we_i(d_we),
		.addr_i(d_addr[13:2]),
		.wdata_i(d_wdata),
		.busy_o(usb_busy),
		.done_o(usb_done),
		.rdata_o(usb_rdata),
		.irq_o(usb_irq),
		.usb_clk_i(usb_clk_i),
		.usb_dp_io(usb_dp_io),
		.usb_dn_io(usb_dn_io),
		.usb_pu_o(usb_pu_o)
	);
	always @(posedge io_clk_i or negedge core_rst_n)
		if (!core_rst_n) begin
			d_rvalid <= 1'b0;
			d_err <= 1'b0;
			sel_q <= R_NONE;
			rdata_q <= 32'h00000000;
		end
		else begin
			d_rvalid <= (((take && !ep_take) && !usb_take) || pw_v) || usb_done;
			d_err <= take && ((rgn == R_NONE) || bad_size);
			sel_q <= (pw_v ? pw_rgn : (usb_done ? R_USB : rgn));
			if (usb_done)
				rdata_q <= usb_rdata;
			else if (pw_v)
				case (pw_rgn)
					R_PWM: rdata_q <= pwm_rdata;
					R_SPI: rdata_q <= spi_rdata;
					R_I2C: rdata_q <= i2c_rdata;
					R_WDT: rdata_q <= wdt_rdata;
					R_ADC: rdata_q <= adc_rdata;
					default: rdata_q <= mux_rdata;
				endcase
			else
				case (rgn)
					R_SYS: rdata_q <= sys_rdata;
					R_TIMER: rdata_q <= timer_rdata;
					R_UART: rdata_q <= uart_rdata;
					R_BRIDGE: rdata_q <= br_rdata;
					R_GPIO: rdata_q <= gpio_rdata;
					default: rdata_q <= 32'h00000000;
				endcase
		end
	assign d_rdata = (sel_q == R_DATA ? m_q : rdata_q);
	initial _sv2v_0 = 0;
endmodule
module mpy_soc (
	clk_i,
	rst_n_i,
	con_valid_o,
	con_err_o,
	con_byte_o,
	halted_o,
	halt_code_o,
	halt_value_o,
	cycles_o,
	ops_o,
	gc_collections_o,
	gc_free_o,
	trace_o,
	trace_pc_o,
	trace_op_o,
	trace_sp_o,
	nand_sck_o,
	nand_cs_n_o,
	nand_mosi_o,
	nand_miso_i,
	boot_done_o,
	boot_err_o,
	io_clk_i,
	console_sel_i,
	uart0_rxd_i,
	uart0_txd_o,
	gpio_o,
	gpio_oe_o,
	gpio_pu_o,
	gpio_pd_o,
	gpio_i,
	adc_start_o,
	adc_chan_o,
	adc_done_i,
	adc_code_i,
	usb_clk_i,
	usb_dp_io,
	usb_dn_io,
	usb_pu_o,
	ioc_dbg_valid_o,
	ioc_dbg_byte_o
);
	localparam signed [31:0] MPY_SRAM_LATENCY = 1;
	parameter signed [31:0] SRAM_LATENCY = MPY_SRAM_LATENCY;
	parameter [0:0] CA_TYPE_CACHE = 0;
	parameter signed [31:0] SHORTLIST_MAX = 16;
	parameter signed [31:0] SHORTLIST_MODE = 2;
	localparam signed [31:0] MPY_FLASH_WAIT_STATES = 0;
	parameter signed [31:0] FLASH_WAIT_STATES = MPY_FLASH_WAIT_STATES;
	input wire clk_i;
	input wire rst_n_i;
	output wire con_valid_o;
	output reg con_err_o;
	output reg [7:0] con_byte_o;
	output wire halted_o;
	output wire [3:0] halt_code_o;
	output wire [31:0] halt_value_o;
	output wire [31:0] cycles_o;
	output wire [31:0] ops_o;
	output wire [31:0] gc_collections_o;
	output wire [31:0] gc_free_o;
	output wire trace_o;
	output wire [31:0] trace_pc_o;
	output wire [7:0] trace_op_o;
	output wire [6:0] trace_sp_o;
	output wire nand_sck_o;
	output wire nand_cs_n_o;
	output wire nand_mosi_o;
	input wire nand_miso_i;
	output wire boot_done_o;
	output wire boot_err_o;
	input wire io_clk_i;
	input wire [1:0] console_sel_i;
	input wire uart0_rxd_i;
	output wire uart0_txd_o;
	output wire [15:0] gpio_o;
	output wire [15:0] gpio_oe_o;
	output wire [15:0] gpio_pu_o;
	output wire [15:0] gpio_pd_o;
	input wire [15:0] gpio_i;
	output wire adc_start_o;
	output wire [3:0] adc_chan_o;
	input wire adc_done_i;
	input wire [11:0] adc_code_i;
	input wire usb_clk_i;
	inout wire usb_dp_io;
	inout wire usb_dn_io;
	output wire usb_pu_o;
	output wire ioc_dbg_valid_o;
	output wire [7:0] ioc_dbg_byte_o;
	wire c_req;
	wire c_we;
	wire c_tag_we;
	wire [3:0] c_be;
	wire [3:0] c_wtag;
	wire [31:0] c_addr;
	wire [31:0] c_wdata;
	wire c_ack;
	wire c_fault;
	reg c_pend;
	wire p_req;
	wire p_sim;
	wire p_we;
	wire p_tag_we;
	wire p_taken;
	wire sim_go;
	wire [3:0] p_be;
	wire [3:0] p_wtag;
	wire [31:0] p_addr;
	wire [31:0] p_wdata;
	wire [31:0] c_rdata;
	wire [3:0] c_rtag;
	wire [3:0] c_fault_reason;
	wire g_alloc_req;
	wire g_alloc_done;
	wire g_alloc_ok;
	wire g_collect_req;
	wire g_collect_done;
	wire [31:0] g_alloc_nbytes;
	wire [31:0] g_alloc_addr;
	wire [31:0] g_r0lo;
	wire [31:0] g_r0hi;
	wire [31:0] g_r1lo;
	wire [31:0] g_r1hi;
	wire [31:0] g_free;
	wire [31:0] g_total;
	wire [31:0] g_coll;
	wire [31:0] g_ovf;
	wire g_busy;
	wire gm_req;
	wire gm_we;
	wire gm_tag_we;
	wire gm_ack;
	wire [31:0] gm_addr;
	wire [31:0] gm_wdata;
	wire [31:0] gm_rdata;
	wire [3:0] gm_wtag;
	wire [3:0] gm_rtag;
	localparam signed [31:0] P_GC = 0;
	localparam signed [31:0] P_CORE = 1;
	localparam signed [31:0] P_FETCH = 2;
	localparam signed [31:0] P_CA = 3;
	wire [3:0] m_req;
	wire [3:0] m_we;
	wire [3:0] m_tag_we;
	wire [3:0] m_gnt;
	wire [3:0] m_ack;
	wire [3:0] m_fault;
	wire [15:0] m_be;
	wire [15:0] m_wtag;
	wire [15:0] m_rtag;
	wire [15:0] m_fault_reason;
	wire [127:0] m_addr;
	wire [127:0] m_wdata;
	wire [127:0] m_rdata;
	wire f_req;
	wire [31:0] f_addr;
	wire sl_valid;
	wire sl_ready;
	wire sl_reverse;
	wire sl_clear;
	wire sl_put;
	wire sl_length;
	wire sl_response;
	wire sl_response_ready;
	wire [31:0] sl_src;
	wire [31:0] sl_dst;
	wire [31:0] sl_n;
	wire [31:0] sl_clear_addr;
	wire [31:0] sl_put_addr;
	wire [31:0] sl_header;
	wire [31:0] sl_new_length;
	wire [35:0] sl_put_value;
	wire ca_byte;
	wire ca_reverse;
	wire ca_valid;
	wire ca_ready;
	wire ca_idle;
	wire ca_busy;
	wire ca_fault;
	wire [31:0] ca_dst;
	wire [31:0] ca_src;
	wire [31:0] ca_n;
	wire [31:0] ca_fault_addr;
	wire [31:0] ca_words;
	wire [31:0] ca_cmds;
	wire [3:0] ca_fault_reason;
	wire mb_valid;
	wire mb_ready;
	wire mb_return;
	wire mb_ok;
	wire mb_set;
	wire [2:0] mb_op;
	wire [31:0] mb_src;
	wire [31:0] mb_sn;
	wire [31:0] mb_dst;
	wire [31:0] mb_dn;
	wire [31:0] mb_used;
	wire [31:0] mb_result;
	wire [31:0] mb_header;
	wire [31:0] mb_source_header;
	wire [31:0] mb_hashes;
	wire [31:0] mb_qcount;
	wire [31:0] mb_qbase;
	wire [31:0] mb_qext;
	wire am_req;
	wire am_we;
	wire am_gnt;
	wire am_ack;
	wire [31:0] am_addr;
	wire [31:0] am_wdata;
	wire [3:0] am_wtag;
	wire core_halted;
	wire io_evt_pend;
	wire [3:0] core_hcode;
	wire [31:0] core_hval;
	wire [31:0] core_cycles;
	wire mem_ready;
	wire boot_done;
	wire [31:0] image_words;
	wire [31:0] requested_pool;
	wire [31:0] physical_pool;
	wire [31:0] active_pool;
	reg layout_error;
	localparam [31:0] ABI_GC_POOL_BASE = 32'h20008500;
	localparam signed [31:0] MPY_MEM_BLOCKS = 4;
	localparam signed [31:0] MPY_MEM_BLOCK_WORDS = 32768;
	localparam signed [31:0] MPY_MEM_WORDS = MPY_MEM_BLOCKS * MPY_MEM_BLOCK_WORDS;
	localparam signed [31:0] MPY_MEM_BYTES = MPY_MEM_WORDS * 4;
	localparam [31:0] MPY_SRAM_BASE = 32'h20000000;
	assign physical_pool = (MPY_MEM_BYTES - (image_words << 2)) - (ABI_GC_POOL_BASE - MPY_SRAM_BASE);
	assign active_pool = (requested_pool == 0 ? physical_pool : requested_pool);
	reg layout_chk;
	wire boot_error;
	assign boot_err_o = boot_error || layout_error;
	reg sys_rst_n;
	wire ld_we;
	localparam signed [31:0] MPY_MEM_WORD_AW = $clog2(MPY_MEM_WORDS);
	localparam signed [31:0] MPY_FLASH_IDX_W = MPY_MEM_WORD_AW;
	wire [MPY_FLASH_IDX_W - 1:0] ld_idx;
	wire [31:0] ld_wdata;
	wire [3:0] ld_wtag;
	reg [1:0] por_q;
	wire pwr_n;
	reg por_n;
	reg boot_rst_n;
	reg gc_rst_n;
	wire sys_req;
	reg [4:0] sys_hold;
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i)
			por_q <= 2'b00;
		else
			por_q <= {por_q[0], 1'b1};
	assign pwr_n = por_q[1];
	always @(posedge clk_i or negedge pwr_n)
		if (!pwr_n) begin
			por_n <= 1'b0;
			sys_hold <= 5'd0;
		end
		else begin
			if (sys_req)
				sys_hold <= 5'd31;
			else if (sys_hold != 5'd0)
				sys_hold <= sys_hold - 5'd1;
			por_n <= !sys_req && (sys_hold == 5'd0);
		end
	always @(posedge clk_i or negedge por_n)
		if (!por_n) begin
			layout_error <= 1'b0;
			layout_chk <= 1'b0;
		end
		else if (boot_done) begin
			layout_error <= ((requested_pool > physical_pool) || (active_pool < 16)) || (active_pool[3:0] != 0);
			layout_chk <= 1'b1;
		end
	always @(posedge clk_i or negedge por_n)
		if (!por_n) begin
			boot_rst_n <= 1'b0;
			gc_rst_n <= 1'b0;
			sys_rst_n <= 1'b0;
		end
		else begin
			if (mem_ready)
				boot_rst_n <= 1'b1;
			if ((boot_done && layout_chk) && !boot_err_o)
				gc_rst_n <= 1'b1;
			if ((((mem_ready && boot_done) && !boot_err_o) && gc_rst_n) && !g_busy)
				sys_rst_n <= 1'b1;
		end
	assign boot_done_o = sys_rst_n;
	wire ioc_we;
	wire ioc_stall;
	wire ioc_loaded;
	wire ioc_ld_idle;
	wire [48:0] ioc_data;
	mpy_boot u_boot(
		.clk_i(clk_i),
		.rst_n_i(boot_rst_n),
		.sck_o(nand_sck_o),
		.cs_n_o(nand_cs_n_o),
		.mosi_o(nand_mosi_o),
		.miso_i(nand_miso_i),
		.ld_we_o(ld_we),
		.ld_idx_o(ld_idx),
		.ld_wdata_o(ld_wdata),
		.ld_wtag_o(ld_wtag),
		.ioc_we_o(ioc_we),
		.ioc_data_o(ioc_data),
		.ioc_stall_i(ioc_stall),
		.ioc_loaded_o(ioc_loaded),
		.image_words_o(image_words),
		.pool_bytes_o(requested_pool),
		.done_o(boot_done),
		.err_o(boot_error)
	);
	mpy_core #(
		.SHORTLIST_MAX(SHORTLIST_MAX),
		.SHORTLIST_MODE(SHORTLIST_MODE)
	) u_core(
		.clk_i(clk_i),
		.rst_n_i(sys_rst_n),
		.m_req_o(c_req),
		.m_we_o(c_we),
		.m_tag_we_o(c_tag_we),
		.m_be_o(c_be),
		.m_addr_o(c_addr),
		.m_wdata_o(c_wdata),
		.m_wtag_o(c_wtag),
		.m_busy_i(c_pend),
		.m_ack_i(c_ack),
		.m_rdata_i(c_rdata),
		.m_rtag_i(c_rtag),
		.m_fault_i(c_fault),
		.m_fault_reason_i(c_fault_reason),
		.f_req_o(f_req),
		.f_addr_o(f_addr),
		.f_gnt_i(m_gnt[P_FETCH]),
		.f_ack_i(m_ack[P_FETCH]),
		.f_rdata_i(m_rdata[64+:32]),
		.f_fault_i(m_fault[P_FETCH]),
		.f_fault_reason_i(m_fault_reason[8+:4]),
		.gc_alloc_req_o(g_alloc_req),
		.gc_alloc_nbytes_o(g_alloc_nbytes),
		.gc_alloc_done_i(g_alloc_done),
		.gc_alloc_ok_i(g_alloc_ok),
		.gc_alloc_addr_i(g_alloc_addr),
		.gc_collect_req_o(g_collect_req),
		.gc_root0_lo_o(g_r0lo),
		.gc_root0_hi_o(g_r0hi),
		.gc_root1_lo_o(g_r1lo),
		.gc_root1_hi_o(g_r1hi),
		.gc_collect_done_i(g_collect_done),
		.gc_free_i(g_free),
		.gc_total_i(g_total),
		.gc_collections_i(g_coll),
		.mb_valid_o(mb_valid),
		.mb_ready_i(mb_ready),
		.mb_return_i(mb_return),
		.mb_ok_i(mb_ok),
		.mb_used_i(mb_result),
		.mb_op_o(mb_op),
		.mb_set_o(mb_set),
		.mb_src_o(mb_src),
		.mb_sn_o(mb_sn),
		.mb_dst_o(mb_dst),
		.mb_dn_o(mb_dn),
		.mb_used_o(mb_used),
		.mb_header_o(mb_header),
		.mb_source_header_o(mb_source_header),
		.mb_hashes_o(mb_hashes),
		.mb_qcount_o(mb_qcount),
		.mb_qbase_o(mb_qbase),
		.mb_qext_o(mb_qext),
		.ca_reverse_o(ca_reverse),
		.ca_byte_o(ca_byte),
		.ca_valid_o(ca_valid),
		.ca_ready_i(ca_ready),
		.sl_valid_o(sl_valid),
		.sl_ready_i(sl_ready),
		.sl_src_o(sl_src),
		.sl_dst_o(sl_dst),
		.sl_n_o(sl_n),
		.sl_reverse_o(sl_reverse),
		.sl_clear_o(sl_clear),
		.sl_put_o(sl_put),
		.sl_length_o(sl_length),
		.sl_clear_addr_o(sl_clear_addr),
		.sl_put_addr_o(sl_put_addr),
		.sl_header_o(sl_header),
		.sl_new_length_o(sl_new_length),
		.sl_put_value_o(sl_put_value),
		.sl_response_i(sl_response),
		.sl_response_ready_o(sl_response_ready),
		.ca_dst_o(ca_dst),
		.ca_src_o(ca_src),
		.ca_n_o(ca_n),
		.ca_idle_i(ca_idle),
		.ca_fault_i(ca_fault),
		.ca_fault_reason_i(ca_fault_reason),
		.ca_fault_addr_i(ca_fault_addr),
		.evt_pend_i(io_evt_pend),
		.halted_o(core_halted),
		.halt_code_o(core_hcode),
		.halt_value_o(core_hval),
		.cycles_o(core_cycles),
		.ops_o(ops_o),
		.trace_o(trace_o),
		.trace_pc_o(trace_pc_o),
		.trace_op_o(trace_op_o),
		.trace_sp_o(trace_sp_o)
	);
	localparam signed [31:0] ABI_GC_TABLE_BYTES = 307200;
	mpy_gc #(
		.POOL_BASE(ABI_GC_POOL_BASE),
		.POOL_BYTES(ABI_GC_TABLE_BYTES)
	) u_gc(
		.clk_i(clk_i),
		.rst_n_i(gc_rst_n),
		.pool_bytes_i(active_pool),
		.alloc_req_i(g_alloc_req),
		.alloc_nbytes_i(g_alloc_nbytes),
		.alloc_done_o(g_alloc_done),
		.alloc_ok_o(g_alloc_ok),
		.alloc_addr_o(g_alloc_addr),
		.collect_req_i(g_collect_req),
		.root0_lo_i(g_r0lo),
		.root0_hi_i(g_r0hi),
		.root1_lo_i(g_r1lo),
		.root1_hi_i(g_r1hi),
		.collect_done_o(g_collect_done),
		.busy_o(g_busy),
		.free_blocks_o(g_free),
		.total_blocks_o(g_total),
		.collections_o(g_coll),
		.overflows_o(g_ovf),
		.mem_req_o(gm_req),
		.mem_we_o(gm_we),
		.mem_tag_we_o(gm_tag_we),
		.mem_addr_o(gm_addr),
		.mem_wdata_o(gm_wdata),
		.mem_wtag_o(gm_wtag),
		.mem_gnt_i(m_gnt[P_GC]),
		.mem_ack_i(gm_ack),
		.mem_rdata_i(gm_rdata),
		.mem_rtag_i(gm_rtag)
	);
	mpy_collection #(
		.TYPE_CACHE(CA_TYPE_CACHE),
		.SHORTLIST_MAX(SHORTLIST_MAX)
	) u_ca(
		.cache_clear_i(g_collect_req || g_collect_done),
		.cache_write_i(m_gnt[P_CORE] && p_we),
		.cache_addr_i(p_addr),
		.clk_i(clk_i),
		.rst_n_i(sys_rst_n),
		.copy_reverse_i(ca_reverse),
		.copy_byte_i(ca_byte),
		.copy_valid_i(ca_valid),
		.copy_ready_o(ca_ready),
		.copy_src_i(ca_src),
		.copy_dst_i(ca_dst),
		.copy_n_i(ca_n),
		.bulk_valid_i(mb_valid),
		.bulk_ready_o(mb_ready),
		.bulk_op_i(mb_op),
		.bulk_set_i(mb_set),
		.bulk_src_i(mb_src),
		.bulk_sn_i(mb_sn),
		.bulk_dst_i(mb_dst),
		.bulk_dn_i(mb_dn),
		.bulk_used_i(mb_used),
		.bulk_header_i(mb_header),
		.bulk_source_header_i(mb_source_header),
		.bulk_hashes_i(mb_hashes),
		.qstr_count_i(mb_qcount),
		.qstr_base_i(mb_qbase),
		.qstr_ext_i(mb_qext),
		.bulk_return_o(mb_return),
		.bulk_ok_o(mb_ok),
		.bulk_used_o(mb_result),
		.sl_valid_i(sl_valid),
		.sl_ready_o(sl_ready),
		.sl_src_i(sl_src),
		.sl_dst_i(sl_dst),
		.sl_n_i(sl_n),
		.sl_reverse_i(sl_reverse),
		.sl_clear_i(sl_clear),
		.sl_put_i(sl_put),
		.sl_length_i(sl_length),
		.sl_clear_addr_i(sl_clear_addr),
		.sl_put_addr_i(sl_put_addr),
		.sl_header_i(sl_header),
		.sl_new_length_i(sl_new_length),
		.sl_put_value_i(sl_put_value),
		.sl_response_o(sl_response),
		.sl_response_ready_i(sl_response_ready),
		.idle_o(ca_idle),
		.chk_addr_i(p_addr),
		.chk_we_i(p_we),
		.chk_busy_o(ca_busy),
		.req_o(am_req),
		.we_o(am_we),
		.addr_o(am_addr),
		.wdata_o(am_wdata),
		.wtag_o(am_wtag),
		.gnt_i(am_gnt),
		.ack_i(am_ack),
		.fault_i(m_fault[P_CA]),
		.fault_reason_i(m_fault_reason[12+:4]),
		.rdata_i(m_rdata[96+:32]),
		.rtag_i(m_rtag[12+:4]),
		.fault_o(ca_fault),
		.fault_reason_o(ca_fault_reason),
		.fault_addr_o(ca_fault_addr),
		.words_o(ca_words),
		.cmds_o(ca_cmds)
	);
	mpy_mem #(
		.NP(4),
		.FLASH_WAIT_STATES(FLASH_WAIT_STATES),
		.SRAM_LATENCY(SRAM_LATENCY)
	) u_mem(
		.clk_i(clk_i),
		.rst_n_i(por_n),
		.image_words_i(image_words),
		.req_i(m_req),
		.we_i(m_we),
		.tag_we_i(m_tag_we),
		.be_i(m_be),
		.addr_i(m_addr),
		.wdata_i(m_wdata),
		.wtag_i(m_wtag),
		.gnt_o(m_gnt),
		.ack_o(m_ack),
		.rdata_o(m_rdata),
		.rtag_o(m_rtag),
		.fault_o(m_fault),
		.fault_reason_o(m_fault_reason),
		.ld_we_i(ld_we),
		.ld_idx_i(ld_idx),
		.ld_wdata_i(ld_wdata),
		.ld_wtag_i(ld_wtag),
		.init_done_o(mem_ready)
	);
	wire c_sim;
	wire c_io;
	wire c_simpage;
	localparam [31:0] MPY_SIM_BASE = 32'he0000000;
	assign c_simpage = c_addr[31:8] == MPY_SIM_BASE[31:8];
	localparam [31:0] MPY_MMIO_BASE = 32'h40000000;
	assign c_io = ((c_addr[31:12] == MPY_MMIO_BASE[31:12]) && (c_addr[1:0] == 2'b00)) && ((((c_addr[11:6] == 6'd0) && (c_addr[5:2] <= 4'd13)) || (c_addr[11:7] == 5'b10000)) || (c_addr[11:5] == 7'b1100000));
	assign c_sim = c_simpage || c_io;
	reg k_we;
	reg k_tag_we;
	reg k_sim;
	reg k_io;
	wire p_io;
	wire io_acc;
	wire io_stall;
	wire [31:0] io_rdata;
	reg [3:0] k_be;
	reg [3:0] k_wtag;
	reg [31:0] k_addr;
	reg [31:0] k_wdata;
	reg [2:0] c_out;
	assign p_req = c_pend || c_req;
	assign p_sim = (c_pend ? k_sim : c_sim);
	assign p_io = (c_pend ? k_io : c_io);
	assign p_we = (c_pend ? k_we : c_we);
	assign p_tag_we = (c_pend ? k_tag_we : c_tag_we);
	assign p_be = (c_pend ? k_be : c_be);
	assign p_wtag = (c_pend ? k_wtag : c_wtag);
	assign p_addr = (c_pend ? k_addr : c_addr);
	assign p_wdata = (c_pend ? k_wdata : c_wdata);
	assign sim_go = ((p_req && !io_stall) && (c_out == 3'd0)) && p_sim;
	assign io_acc = sim_go && p_io;
	assign p_taken = m_gnt[P_CORE] || sim_go;
	always @(posedge clk_i or negedge por_n)
		if (!por_n) begin
			c_pend <= 1'b0;
			c_out <= 3'd0;
			k_we <= 1'b0;
			k_tag_we <= 1'b0;
			k_sim <= 1'b0;
			k_io <= 1'b0;
			k_be <= 4'd0;
			k_wtag <= 4'd0;
			k_addr <= 32'd0;
			k_wdata <= 32'd0;
		end
		else begin
			if (c_pend) begin
				if (p_taken)
					c_pend <= 1'b0;
			end
			else if (c_req && !p_taken) begin
				c_pend <= 1'b1;
				k_we <= c_we;
				k_tag_we <= c_tag_we;
				k_sim <= c_sim;
				k_io <= c_io;
				k_be <= c_be;
				k_wtag <= c_wtag;
				k_addr <= c_addr;
				k_wdata <= c_wdata;
			end
			c_out <= (c_out + (m_gnt[P_CORE] ? 3'd1 : 3'd0)) - (m_ack[P_CORE] ? 3'd1 : 3'd0);
		end
	reg sim_ack;
	reg con_valid_r;
	reg [31:0] sim_rdata;
	reg [1:0] con_sel_q;
	reg [1:0] con_mode;
	wire con_redir;
	always @(posedge clk_i or negedge por_n)
		if (!por_n) begin
			con_sel_q <= 2'd0;
			con_mode <= 2'd0;
		end
		else begin
			con_sel_q <= console_sel_i;
			con_mode <= con_sel_q;
		end
	assign con_redir = con_mode != 2'd0;
	assign con_valid_o = con_valid_r && !con_redir;
	reg io_q_v;
	reg io_q_we;
	reg [9:0] io_q_off;
	reg [31:0] io_q_wdata;
	always @(posedge clk_i or negedge por_n)
		if (!por_n) begin
			io_q_v <= 1'b0;
			io_q_we <= 1'b0;
			io_q_off <= 1'sb0;
			io_q_wdata <= 1'sb0;
		end
		else begin
			io_q_v <= io_acc;
			io_q_we <= p_we;
			io_q_off <= p_addr[11:2];
			io_q_wdata <= p_wdata;
		end
	reg sim_halt;
	reg [31:0] sim_halt_val;
	localparam [31:0] ABI_SIM_BASE = 32'he0000000;
	localparam [7:0] ABI_SIM_CYCLES = 8'd3;
	localparam [7:0] ABI_SIM_HALT = 8'd0;
	localparam [7:0] ABI_SIM_STDERR = 8'd1;
	localparam [7:0] ABI_SIM_STDOUT = 8'd2;
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @(posedge clk_i or negedge por_n)
		if (!por_n) begin
			sim_ack <= 1'b0;
			sim_rdata <= 32'd0;
			con_valid_r <= 1'b0;
			con_err_o <= 1'b0;
			con_byte_o <= 8'd0;
			sim_halt <= 1'b0;
			sim_halt_val <= 32'd0;
		end
		else begin
			sim_ack <= 1'b0;
			con_valid_r <= 1'b0;
			if (sim_go) begin
				sim_ack <= !p_io;
				sim_rdata <= 32'd0;
				if (p_we)
					case ((p_addr - ABI_SIM_BASE) >> 2)
						sv2v_cast_32(ABI_SIM_STDOUT): begin
							con_valid_r <= 1'b1;
							con_err_o <= 1'b0;
							con_byte_o <= p_wdata[7:0];
						end
						sv2v_cast_32(ABI_SIM_STDERR): begin
							con_valid_r <= 1'b1;
							con_err_o <= 1'b1;
							con_byte_o <= p_wdata[7:0];
						end
						sv2v_cast_32(ABI_SIM_HALT): begin
							sim_halt <= 1'b1;
							sim_halt_val <= p_wdata;
						end
						default:
							;
					endcase
				else if (((p_addr - ABI_SIM_BASE) >> 2) == sv2v_cast_32(ABI_SIM_CYCLES))
					sim_rdata <= core_cycles;
			end
			if (io_q_v) begin
				sim_ack <= 1'b1;
				sim_rdata <= io_rdata;
			end
		end
	reg g_pend;
	wire c_want;
	wire g_want;
	assign c_want = p_req && !p_sim;
	assign g_want = g_pend || gm_req;
	assign m_req = {am_req, f_req && sys_rst_n, c_want && !ca_busy, g_want};
	assign m_we = {am_we, 1'b0, p_we, gm_we};
	assign m_tag_we = {am_we, 1'b0, p_tag_we, gm_tag_we};
	assign m_be = {8'hff, p_be, 4'hf};
	assign m_addr = {am_addr, f_addr, p_addr, gm_addr};
	assign m_wdata = {am_wdata, 32'd0, p_wdata, gm_wdata};
	assign m_wtag = {am_wtag, 4'd0, p_wtag, gm_wtag};
	assign am_gnt = m_gnt[P_CA];
	always @(posedge clk_i or negedge por_n)
		if (!por_n)
			g_pend <= 1'b0;
		else
			g_pend <= g_want && !m_gnt[P_GC];
	assign gm_ack = m_ack[P_GC];
	assign am_ack = m_ack[P_CA];
	assign gm_rdata = m_rdata[0+:32];
	assign gm_rtag = m_rtag[0+:4];
	assign c_ack = m_ack[P_CORE] || sim_ack;
	assign c_rdata = (sim_ack ? sim_rdata : m_rdata[32+:32]);
	assign c_rtag = (sim_ack ? 4'd0 : m_rtag[4+:4]);
	assign c_fault = !sim_ack && m_fault[P_CORE];
	assign c_fault_reason = m_fault_reason[4+:4];
	reg [1:0] io_por_q;
	wire io_por_n;
	always @(posedge io_clk_i or negedge rst_n_i)
		if (!rst_n_i)
			io_por_q <= 2'b00;
		else
			io_por_q <= {io_por_q[0], 1'b1};
	assign io_por_n = io_por_q[1];
	reg ioc_run;
	always @(posedge clk_i or negedge pwr_n)
		if (!pwr_n)
			ioc_run <= 1'b0;
		else if (((boot_done && ioc_loaded) && ioc_ld_idle) && !ioc_we)
			ioc_run <= 1'b1;
	wire b_cmd_pop;
	wire b_cmd_empty;
	wire b_rsp_push;
	wire b_rsp_full;
	wire b_evt_push;
	wire b_evt_full;
	wire b_con_pop;
	wire b_con_empty;
	wire b_conrx_push;
	wire b_conrx_full;
	wire b_upd_push;
	wire b_upd_full;
	wire b_dn_pop;
	wire b_dn_empty;
	wire b_ld_pop;
	wire b_ld_empty;
	wire [31:0] b_cmd_data;
	wire [31:0] b_rsp_data;
	wire [5:0] b_cmd_level;
	wire [15:0] b_evt_data;
	wire [8:0] b_con_data;
	wire [6:0] b_con_level;
	wire [7:0] b_conrx_data;
	wire [36:0] b_upd_data;
	wire [34:0] b_dn_data;
	wire [48:0] b_ld_data;
	wire [31:0] b_us_gray;
	wire [31:0] b_ms_gray;
	wire b_wdt_toggle;
	mpy_iobr u_iobr(
		.clk_i(clk_i),
		.rst_n_i(pwr_n),
		.hart_rst_n_i(por_n),
		.sys_reset_o(sys_req),
		.wdt_toggle_i(b_wdt_toggle),
		.acc_i(io_q_v),
		.we_i(io_q_we),
		.off_i(io_q_off),
		.wdata_i(io_q_wdata),
		.rdata_o(io_rdata),
		.acc_now_i(io_acc),
		.stall_o(io_stall),
		.con_push_i(con_valid_r && con_redir),
		.con_data_i({con_err_o, con_byte_o}),
		.con_mode_i(con_mode),
		.evt_pend_o(io_evt_pend),
		.ld_push_i(ioc_we && !ioc_run),
		.ld_data_i(ioc_data),
		.ld_idle_o(ioc_ld_idle),
		.run_i(ioc_run),
		.loaded_i(ioc_loaded),
		.io_clk_i(io_clk_i),
		.io_rst_n_i(io_por_n),
		.us_gray_i(b_us_gray),
		.ms_gray_i(b_ms_gray),
		.cmd_pop_i(b_cmd_pop),
		.cmd_data_o(b_cmd_data),
		.cmd_empty_o(b_cmd_empty),
		.cmd_level_o(b_cmd_level),
		.rsp_push_i(b_rsp_push),
		.rsp_data_i(b_rsp_data),
		.rsp_full_o(b_rsp_full),
		.evt_push_i(b_evt_push),
		.evt_data_i(b_evt_data),
		.evt_full_o(b_evt_full),
		.con_pop_i(b_con_pop),
		.con_data_o(b_con_data),
		.con_empty_o(b_con_empty),
		.con_level_o(b_con_level),
		.conrx_push_i(b_conrx_push),
		.conrx_data_i(b_conrx_data),
		.conrx_full_o(b_conrx_full),
		.upd_push_i(b_upd_push),
		.upd_data_i(b_upd_data),
		.upd_full_o(b_upd_full),
		.dn_pop_i(b_dn_pop),
		.dn_data_o(b_dn_data),
		.dn_empty_o(b_dn_empty),
		.ld_pop_i(b_ld_pop),
		.ld_data_o(b_ld_data),
		.ld_empty_o(b_ld_empty)
	);
	assign ioc_stall = io_stall;
	iocore_top u_ioc(
		.io_clk_i(io_clk_i),
		.io_rst_n_i(io_por_n),
		.run_i(ioc_run),
		.con_mode_i(console_sel_i),
		.ld_valid_i(!b_ld_empty),
		.ld_data_i(b_ld_data),
		.ld_pop_o(b_ld_pop),
		.cmd_pop_o(b_cmd_pop),
		.cmd_data_i(b_cmd_data),
		.cmd_empty_i(b_cmd_empty),
		.cmd_level_i(b_cmd_level),
		.rsp_push_o(b_rsp_push),
		.rsp_data_o(b_rsp_data),
		.rsp_full_i(b_rsp_full),
		.evt_push_o(b_evt_push),
		.evt_data_o(b_evt_data),
		.evt_full_i(b_evt_full),
		.con_pop_o(b_con_pop),
		.con_data_i(b_con_data),
		.con_empty_i(b_con_empty),
		.con_level_i(b_con_level),
		.conrx_push_o(b_conrx_push),
		.conrx_data_o(b_conrx_data),
		.conrx_full_i(b_conrx_full),
		.upd_push_o(b_upd_push),
		.upd_data_o(b_upd_data),
		.upd_full_i(b_upd_full),
		.dn_pop_o(b_dn_pop),
		.dn_data_i(b_dn_data),
		.dn_empty_i(b_dn_empty),
		.uart_rxd_i(uart0_rxd_i),
		.uart_txd_o(uart0_txd_o),
		.gpio_o(gpio_o),
		.gpio_oe_o(gpio_oe_o),
		.gpio_pu_o(gpio_pu_o),
		.gpio_pd_o(gpio_pd_o),
		.gpio_i(gpio_i),
		.us_gray_o(b_us_gray),
		.ms_gray_o(b_ms_gray),
		.adc_start_o(adc_start_o),
		.adc_chan_o(adc_chan_o),
		.adc_done_i(adc_done_i),
		.adc_code_i(adc_code_i),
		.wdt_toggle_o(b_wdt_toggle),
		.usb_clk_i(usb_clk_i),
		.usb_dp_io(usb_dp_io),
		.usb_dn_io(usb_dn_io),
		.usb_pu_o(usb_pu_o),
		.dbg_valid_o(ioc_dbg_valid_o),
		.dbg_byte_o(ioc_dbg_byte_o),
		.halt_o(),
		.halt_value_o(),
		.sleep_o()
	);
	assign halted_o = core_halted || sim_halt;
	localparam [3:0] ABI_HALT_SYSEXIT = 4'd10;
	assign halt_code_o = (core_halted ? core_hcode : ABI_HALT_SYSEXIT);
	assign halt_value_o = (core_halted ? core_hval : sim_halt_val);
	assign cycles_o = core_cycles;
	assign gc_collections_o = g_coll;
	assign gc_free_o = g_free;
	wire unused;
	assign unused = ^{g_total, g_ovf, g_busy, ca_words, ca_cmds};
endmodule
