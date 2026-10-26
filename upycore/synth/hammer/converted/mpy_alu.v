// Generated from the uPyCore RTL by mpy_dc_unit.py and sv2v v0.0.13
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
	wire [AW - 1:0] a_cur;
	wire [BWP - 1:0] b_cur;
	wire [ACC_W - 1:0] acc_cur;
	wire [STEP - 1:0] chunk;
	wire [(AW + STEP) - 1:0] pp;
	wire [ACC_W - 1:0] sum;
	wire [BWP - 1:0] lo_next;
	wire accept;
	wire last_step;
	assign accept = (start_i && !busy_r) && !done_r;
	assign a_cur = (busy_r ? a_r : op_a_i);
	function automatic [BWP - 1:0] sv2v_cast_EDFA3;
		input reg [BWP - 1:0] inp;
		sv2v_cast_EDFA3 = inp;
	endfunction
	assign b_cur = (busy_r ? b_r : sv2v_cast_EDFA3(op_b_i));
	assign acc_cur = (busy_r ? acc_r : {ACC_W {1'sb0}});
	assign chunk = b_cur[STEP - 1:0];
	assign pp = a_cur * chunk;
	function automatic [ACC_W - 1:0] sv2v_cast_60BB9;
		input reg [ACC_W - 1:0] inp;
		sv2v_cast_60BB9 = inp;
	endfunction
	assign sum = (acc_cur >> STEP) + sv2v_cast_60BB9(pp);
	assign lo_next = sv2v_cast_EDFA3(lo_r >> STEP) | (sv2v_cast_EDFA3(sum[STEP - 1:0]) << (BWP - STEP));
	function automatic signed [CNT_W - 1:0] sv2v_cast_7B3D1_signed;
		input reg signed [CNT_W - 1:0] inp;
		sv2v_cast_7B3D1_signed = inp;
	endfunction
	assign last_step = (busy_r ? cnt_r == sv2v_cast_7B3D1_signed(NSTEP - 1) : NSTEP == 1);
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
			if (accept || busy_r) begin
				if (busy_r && !start_i)
					busy_r <= 1'b0;
				else begin
					a_r <= a_cur;
					b_r <= b_cur >> STEP;
					acc_r <= sum;
					lo_r <= lo_next;
					if (last_step) begin
						busy_r <= 1'b0;
						done_r <= 1'b1;
						cnt_r <= 1'sb0;
						product_r <= sv2v_cast_074AA({sum[ACC_W - 1:STEP], lo_next});
					end
					else begin
						busy_r <= 1'b1;
						cnt_r <= (busy_r ? cnt_r + 1'b1 : sv2v_cast_7B3D1_signed(1));
					end
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
	localparam signed [31:0] CNT_W = (NSTEP > 1 ? $clog2(NSTEP) : 1);
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
	wire [63:0] a_cur;
	wire [63:0] b_cur;
	wire signed [ACC_W - 1:0] acc_cur;
	wire last_step;
	wire signed [STEP:0] chunk_s;
	wire signed [64:0] a_s;
	wire signed [(64 + STEP) + 1:0] pp;
	wire signed [ACC_W - 1:0] sum;
	wire [63:0] lo_next;
	wire accept;
	assign accept = (start_i && !busy_r) && !done_r;
	assign a_cur = (busy_r ? a_r : op_a_i);
	assign b_cur = (busy_r ? b_r : op_b_i);
	assign acc_cur = (busy_r ? acc_r : {ACC_W {1'sb0}});
	function automatic signed [CNT_W - 1:0] sv2v_cast_7B3D1_signed;
		input reg signed [CNT_W - 1:0] inp;
		sv2v_cast_7B3D1_signed = inp;
	endfunction
	assign last_step = (busy_r ? cnt_r == sv2v_cast_7B3D1_signed(NSTEP - 1) : NSTEP == 1);
	assign chunk_s = {(last_step ? b_cur[STEP - 1] : 1'b0), b_cur[STEP - 1:0]};
	assign a_s = {a_cur[63], a_cur};
	assign pp = a_s * chunk_s;
	function automatic signed [ACC_W - 1:0] sv2v_cast_60BB9_signed;
		input reg signed [ACC_W - 1:0] inp;
		sv2v_cast_60BB9_signed = inp;
	endfunction
	assign sum = (acc_cur >>> STEP) + sv2v_cast_60BB9_signed(pp);
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
			if (accept || busy_r) begin
				if (busy_r && !start_i)
					busy_r <= 1'b0;
				else begin
					a_r <= a_cur;
					b_r <= b_cur >> STEP;
					acc_r <= sum;
					lo_r <= lo_next;
					if (last_step) begin
						busy_r <= 1'b0;
						done_r <= 1'b1;
						cnt_r <= 1'sb0;
						lo_result_r <= lo_next;
						hi_result_r <= sv2v_cast_64_signed(sum >>> STEP);
					end
					else begin
						busy_r <= 1'b1;
						cnt_r <= (busy_r ? cnt_r + 1'b1 : sv2v_cast_7B3D1_signed(1));
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
	reg [1:0] state_r;
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
	wire [7:0] bits_a;
	wire [7:0] bits_b;
	wire signed [8:0] n_q;
	reg [7:0] n_pad;
	reg [63:0] rem_init;
	reg [63:0] bits;
	reg [15:0] nsteps;
	function automatic signed [6:0] sv2v_cast_7_signed;
		input reg signed [6:0] inp;
		sv2v_cast_7_signed = inp;
	endfunction
	function automatic [6:0] upycore_clz64;
		input reg [63:0] v;
		begin
			upycore_clz64 = 7'd64;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < 64; i = i + 1)
					if (v[i])
						upycore_clz64 = sv2v_cast_7_signed(63 - i);
			end
		end
	endfunction
	assign lz_a = upycore_clz64(a_mag_r);
	assign lz_b = upycore_clz64(b_mag_r);
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
	endfunction
	assign bits_a = 8'd64 - sv2v_cast_8(lz_a);
	assign bits_b = 8'd64 - sv2v_cast_8(lz_b);
	function automatic [8:0] sv2v_cast_9;
		input reg [8:0] inp;
		sv2v_cast_9 = inp;
	endfunction
	assign n_q = ($signed(sv2v_cast_9(bits_a)) - $signed(sv2v_cast_9(bits_b))) + 9'sd1;
	function automatic [15:0] sv2v_cast_16;
		input reg [15:0] inp;
		sv2v_cast_16 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		if (n_q <= 9'sd0)
			n_pad = 8'd0;
		else if (RL == 2)
			n_pad = (n_q[7:0] + 8'd1) & 8'hfe;
		else
			n_pad = n_q[7:0];
		rem_init = a_mag_r >> n_pad;
		bits = a_mag_r << (8'd64 - n_pad);
		nsteps = (RL == 2 ? sv2v_cast_16(n_pad >> 1) : sv2v_cast_16(n_pad));
	end
	wire core_start;
	wire core_done;
	wire core_busy;
	wire [63:0] q_mag;
	wire [63:0] r_mag;
	assign core_start = start_i && ((state_r == 2'd1) || (state_r == 2'd2));
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
			state_r <= 2'd0;
			sa_r <= 1'b0;
			sb_r <= 1'b0;
			a_mag_r <= 1'sb0;
			b_mag_r <= 1'sb0;
			quot_r <= 1'sb0;
			rem_r <= 1'sb0;
		end
		else if (!start_i)
			state_r <= 2'd0;
		else
			(* full_case, parallel_case *)
			case (state_r)
				2'd0:
					if (!div_zero_o) begin
						sa_r <= op_a_i[63];
						sb_r <= op_b_i[63];
						a_mag_r <= a_mag;
						b_mag_r <= b_mag;
						state_r <= 2'd1;
					end
				2'd1: state_r <= 2'd2;
				2'd2:
					if (core_done) begin
						quot_r <= q_floor;
						rem_r <= r_floor;
						state_r <= 2'd3;
					end
				2'd3: state_r <= 2'd0;
				default: state_r <= 2'd0;
			endcase
	assign quot_o = quot_r;
	assign rem_o = rem_r;
	assign done_o = state_r == 2'd3;
	assign stall_o = (start_i && !done_o) && !div_zero_o;
	assign busy_o = state_r != 2'd0;
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
	function automatic signed [6:0] sv2v_cast_7_signed;
		input reg signed [6:0] inp;
		sv2v_cast_7_signed = inp;
	endfunction
	function automatic [6:0] upycore_clz64;
		input reg [63:0] v;
		begin
			upycore_clz64 = 7'd64;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < 64; i = i + 1)
					if (v[i])
						upycore_clz64 = sv2v_cast_7_signed(63 - i);
			end
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
	reg [10:0] s1_exp_small_r;
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
	wire [10:0] exp_diff;
	wire [55:0] ext_big;
	wire [55:0] ext_small;
	reg [55:0] aligned;
	reg [55:0] lost_mask;
	reg sticky;
	reg [56:0] sum;
	assign exp_diff = s1_exp_big_r - s1_exp_small_r;
	assign ext_big = {s1_sig_big_r, 3'b000};
	assign ext_small = {s1_sig_small_r, 3'b000};
	always @(*) begin
		if (_sv2v_0)
			;
		lost_mask = 1'sb0;
		sticky = 1'b0;
		if (exp_diff > 11'd55)
			aligned = {55'd0, |ext_small};
		else begin
			lost_mask = (56'd1 << exp_diff[5:0]) - 56'd1;
			sticky = |(ext_small & lost_mask);
			aligned = ext_small >> exp_diff[5:0];
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
	function automatic signed [5:0] sv2v_cast_6_signed;
		input reg signed [5:0] inp;
		sv2v_cast_6_signed = inp;
	endfunction
	function automatic [5:0] upycore_clz56;
		input reg [55:0] v;
		begin
			upycore_clz56 = 6'd56;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < 56; i = i + 1)
					if (v[i])
						upycore_clz56 = sv2v_cast_6_signed(55 - i);
			end
		end
	endfunction
	function automatic [13:0] sv2v_cast_14;
		input reg [13:0] inp;
		sv2v_cast_14 = inp;
	endfunction
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
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
	function automatic [10:0] upycore_f64_exp_eff;
		input reg [63:0] v;
		upycore_f64_exp_eff = (v[62:52] == 11'd0 ? 11'd1 : v[62:52]);
	endfunction
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
			s1_exp_small_r <= 1'sb0;
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
				s1_exp_big_r <= upycore_f64_exp_eff(op_a_i);
				s1_exp_small_r <= upycore_f64_exp_eff(op_b_i);
				s1_sig_big_r <= upycore_f64_sig(op_a_i);
				s1_sig_small_r <= upycore_f64_sig(op_b_i);
			end
			else begin
				s1_sign_big_r <= b_sign_eff;
				s1_sign_small_r <= op_a_i[63];
				s1_exp_big_r <= upycore_f64_exp_eff(op_b_i);
				s1_exp_small_r <= upycore_f64_exp_eff(op_a_i);
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
	assign result_o = (s3_special_r ? s3_special_val_r : upycore_f64_pack_round(s3_sign_r, s3_exp_r, s3_sig_r, s3_g_r, s3_r_r, s3_s_r));
	assign done_o = s3_valid_r;
	assign busy_o = (s1_valid_r | s2_valid_r) | s3_valid_r;
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
	function automatic signed [5:0] sv2v_cast_6_signed;
		input reg signed [5:0] inp;
		sv2v_cast_6_signed = inp;
	endfunction
	function automatic [5:0] upycore_clz53;
		input reg [52:0] v;
		begin
			upycore_clz53 = 6'd53;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < 53; i = i + 1)
					if (v[i])
						upycore_clz53 = sv2v_cast_6_signed(52 - i);
			end
		end
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
			s1_sig_a_r <= 1'sb0;
			s1_sig_b_r <= 1'sb0;
			s1_special_r <= 1'b0;
			s1_special_val_r <= 1'sb0;
		end
		else if (!start_i)
			s1_valid_r <= 1'b0;
		else begin
			s1_valid_r <= start_i && !busy_o;
			if (start_i && !busy_o) begin
				s1_sign_r <= sign;
				s1_exp_r <= (exp_a_n + exp_b_n) - 14'sd1023;
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
	assign result_o = (s1_special_r ? s1_special_val_r : upycore_f64_pack_round(s1_sign_r, r_exp, r_sig, r_g, r_r, r_s));
	assign done_o = mul_done;
	assign busy_o = (s1_valid_r | mul_busy) | mul_done;
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
	function automatic signed [5:0] sv2v_cast_6_signed;
		input reg signed [5:0] inp;
		sv2v_cast_6_signed = inp;
	endfunction
	function automatic [5:0] upycore_clz53;
		input reg [52:0] v;
		begin
			upycore_clz53 = 6'd53;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < 53; i = i + 1)
					if (v[i])
						upycore_clz53 = sv2v_cast_6_signed(52 - i);
			end
		end
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
		end
		else if (!start_i) begin
			s1_valid_r <= 1'b0;
			fin_r <= 1'b0;
		end
		else begin
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
	reg signed [13:0] r_exp;
	reg [52:0] r_sig;
	reg r_g;
	reg r_r;
	reg r_s;
	reg [5:0] rem_lz;
	always @(*) begin
		if (_sv2v_0)
			;
		rem_lz = upycore_clz53(rem[52:0]);
		if (s2_fmod_r) begin
			r_exp = s2_exp_r - $signed(sv2v_cast_14(rem_lz));
			r_sig = rem[52:0] << rem_lz;
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
	assign result_o = (s2_special_r ? s2_special_val_r : upycore_f64_pack_round(s2_sign_r, r_exp, r_sig, r_g, r_r, r_s));
	assign done_o = core_done | fin_r;
	assign busy_o = ((s1_valid_r | core_busy) | core_done) | fin_r;
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
	wire [52:0] x_sig;
	wire [52:0] y_sig;
	wire [5:0] x_lz;
	wire [5:0] y_lz;
	wire [10:0] x_exp;
	wire [10:0] y_exp;
	function automatic [52:0] upycore_f64_sig;
		input reg [63:0] v;
		upycore_f64_sig = {v[62:52] != 11'd0, v[51:0]};
	endfunction
	assign x_sig = upycore_f64_sig(op_x_i);
	assign y_sig = upycore_f64_sig(op_y_i);
	function automatic signed [5:0] sv2v_cast_6_signed;
		input reg signed [5:0] inp;
		sv2v_cast_6_signed = inp;
	endfunction
	function automatic [5:0] upycore_clz53;
		input reg [52:0] v;
		begin
			upycore_clz53 = 6'd53;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < 53; i = i + 1)
					if (v[i])
						upycore_clz53 = sv2v_cast_6_signed(52 - i);
			end
		end
	endfunction
	assign x_lz = upycore_clz53(x_sig);
	assign y_lz = upycore_clz53(y_sig);
	function automatic [10:0] upycore_f64_exp_eff;
		input reg [63:0] v;
		upycore_f64_exp_eff = (v[62:52] == 11'd0 ? 11'd1 : v[62:52]);
	endfunction
	assign x_exp = upycore_f64_exp_eff(op_x_i);
	assign y_exp = upycore_f64_exp_eff(op_y_i);
	wire halve;
	wire signed [89:0] r_red;
	wire [87:0] r_mag;
	reg [7:0] r_clz;
	wire [7:0] j0_sel;
	wire [52:0] r_delta;
	assign halve = mx_r > FOUR_THIRDS;
	function automatic [53:0] sv2v_cast_54;
		input reg [53:0] inp;
		sv2v_cast_54 = inp;
	endfunction
	function automatic [52:0] sv2v_cast_53;
		input reg [52:0] inp;
		sv2v_cast_53 = inp;
	endfunction
	assign r_delta = sv2v_cast_53((54'd1 << 53) - sv2v_cast_54(mx_r));
	assign r_red = (halve ? -$signed({{WW - FW {1'b0}}, r_delta, {35 {1'b0}}}) : $signed({{WW - FW {1'b0}}, mx_r[51:0], {36 {1'b0}}}));
	function automatic signed [87:0] sv2v_cast_88_signed;
		input reg signed [87:0] inp;
		sv2v_cast_88_signed = inp;
	endfunction
	assign r_mag = (r_r[89] ? sv2v_cast_88_signed(-r_r) : r_r[87:0]);
	function automatic signed [7:0] sv2v_cast_8_signed;
		input reg signed [7:0] inp;
		sv2v_cast_8_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		r_clz = sv2v_cast_8_signed(FW);
		begin : sv2v_autoblock_2
			reg signed [31:0] b;
			for (b = 0; b < FW; b = b + 1)
				if (r_mag[b])
					r_clz = sv2v_cast_8_signed(87 - b);
		end
	end
	assign j0_sel = (r_clz < 8'd2 ? 8'd2 : r_clz);
	wire in_log;
	wire [7:0] k_idx;
	wire d_pos;
	wire d_neg;
	wire signed [89:0] w_sh;
	wire [FW:0] z_sh;
	reg signed [89:0] w_next;
	reg signed [90:0] acc_next;
	wire [87:0] exp_c;
	wire exp_take;
	assign in_log = state_r == 4'd3;
	assign k_idx = (in_log ? j_r : {1'b0, i_r});
	assign d_pos = !r_r[89] && (r_r[88:87] != 2'b00);
	assign d_neg = r_r[89] && (r_r[88:87] != 2'b11);
	wire signed [89:0] w_sh_full;
	assign w_sh_full = r_r >>> k_idx[6:0];
	assign w_sh = (k_idx >= sv2v_cast_8_signed(WW) ? $signed({WW {r_r[89]}}) : w_sh_full);
	assign z_sh = z_r >> k_idx[6:0];
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
			4'd2: begin
				pf_k = j0_sel;
				pf_sh = 7'd0;
			end
			4'd3: begin
				pf_k = j_r + 8'd1;
				pf_sh = i_r + 7'd1;
			end
			4'd10: begin
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
	reg [6:0] lmag_clz;
	wire [100:0] lmag_norm;
	function automatic signed [6:0] sv2v_cast_7_signed;
		input reg signed [6:0] inp;
		sv2v_cast_7_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		if (e_r == 13'sd0)
			v_sum = $signed({{11 {acc_r[90]}}, acc_r});
		else begin
			v_sum = $signed({{89 {e_r[12]}}, e_r}) <<< FW;
			v_sum = v_sum + ($signed({{11 {acc_r[90]}}, acc_r}) >>> j0_r);
		end
		lmag_clz = sv2v_cast_7_signed(LW);
		begin : sv2v_autoblock_3
			reg signed [31:0] b;
			for (b = 0; b < LW; b = b + 1)
				if (lmag_r[b])
					lmag_clz = sv2v_cast_7_signed(100 - b);
		end
	end
	assign lmag_norm = lmag_r << lz_r;
	assign mul_start_o = state_r == 4'd8;
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
	assign q_shifted = (p_sh >= 14'sd0 ? q_prod : (t_amt >= sv2v_cast_14_signed(QW) ? {QW {1'sb0}} : q_prod >> t_amt[7:0]));
	assign p_huge = (p_sh >= 14'sd0 ? q_prod != {QW {1'sb0}} : q_shifted[QW - 1:91] != {((QW - 1) >= 91 ? QW - 91 : 93 - QW) * 1 {1'sb0}});
	assign pfix_s = (psign_r ? -$signed({1'b0, pfix_r}) : $signed({1'b0, pfix_r}));
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
	assign pack_res = upycore_f64_pack_round(1'b0, $signed({i_int_r[12], i_int_r}) + 14'sd1023, z_r[FW:36], z_r[35], z_r[34], |z_r[33:0]);
	localparam [63:0] UPY_F64_PZERO = 64'h0000000000000000;
	function automatic [12:0] sv2v_cast_13;
		input reg [12:0] inp;
		sv2v_cast_13 = inp;
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
							mx_r <= x_sig << x_lz;
							ex_r <= (sv2v_cast_13(x_exp) - sv2v_cast_13(x_lz)) - 13'sd1023;
							my_r <= y_sig << y_lz;
							ey_r <= (sv2v_cast_13(y_exp) - sv2v_cast_13(y_lz)) - 13'sd1023;
							ysign_r <= op_y_i[63];
							state_r <= 4'd1;
						end
					4'd1: begin
						r_r <= r_red;
						e_r <= (halve ? ex_r + 13'sd1 : ex_r);
						acc_r <= 1'sb0;
						state_r <= 4'd2;
					end
					4'd2: begin
						r_r <= -r_r <<< j0_sel;
						j0_r <= j0_sel;
						j_r <= j0_sel;
						i_r <= 1'sb0;
						cpos_r <= pf_pos;
						cneg_r <= pf_neg;
						state_r <= (r_mag == {88 {1'sb0}} ? 4'd4 : 4'd3);
					end
					4'd3: begin
						r_r <= w_next;
						acc_r <= acc_next;
						j_r <= j_r + 8'd1;
						i_r <= i_r + 7'd1;
						cpos_r <= pf_pos;
						cneg_r <= pf_neg;
						if (i_r == sv2v_cast_7_signed(79))
							state_r <= 4'd4;
					end
					4'd4: begin
						v_r <= v_sum;
						lscale_r <= (e_r == 13'sd0 ? j0_r : 8'd0);
						state_r <= 4'd5;
					end
					4'd5: begin
						lsign_r <= v_r[LW];
						lmag_r <= sv2v_cast_4587C_signed((v_r[LW] ? -v_r : v_r));
						state_r <= 4'd6;
					end
					4'd6: begin
						lz_r <= lmag_clz;
						state_r <= 4'd7;
					end
					4'd7: begin
						lm_r <= lmag_norm[100:LW - LMW];
						el_r <= ((sv2v_cast_13_signed(LW - LMW) - sv2v_cast_13(lz_r)) - sv2v_cast_13_signed(FW)) - sv2v_cast_13(lscale_r);
						psign_r <= ysign_r ^ lsign_r;
						state_r <= 4'd8;
					end
					4'd8:
						if (mul_done)
							state_r <= 4'd9;
					4'd9: begin
						pfix_r <= q_shifted[91:0];
						huge_r <= p_huge;
						state_r <= 4'd10;
					end
					4'd10: begin
						i_int_r <= pfix_s[PW:FP];
						f_r <= {pfix_s[79:0], {FW - FP {1'b0}}};
						z_r <= {1'b1, {FW {1'b0}}};
						i_r <= 7'd1;
						cpos_r <= pf_pos;
						state_r <= (huge_r ? 4'd12 : 4'd11);
					end
					4'd11: begin
						if (exp_take) begin
							f_r <= f_r - exp_c;
							z_r <= z_r + z_sh;
						end
						i_r <= i_r + 7'd1;
						cpos_r <= pf_pos;
						if (i_r == sv2v_cast_7_signed(NEXP))
							state_r <= 4'd12;
					end
					4'd12: begin
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
	complex_i,
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
	input wire complex_i;
	input wire [127:0] op_a_i;
	input wire [127:0] op_b_i;
	output reg [127:0] result_o;
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
	reg cdiv_b_r;
	reg [127:0] res_r;
	reg mul_run;
	wire [63:0] ar;
	wire [63:0] ai;
	wire [63:0] br;
	wire [63:0] bi;
	assign ar = op_a_i[63:0];
	assign ai = op_a_i[127:64];
	assign br = op_b_i[63:0];
	assign bi = op_b_i[127:64];
	reg [1:0] dec_kind;
	reg [127:0] dec_result;
	reg [5:0] dec_next;
	reg dec_sub;
	reg dec_div;
	reg dec_mul;
	reg dec_cdiv_b;
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
	reg [63:0] b_trunc_int;
	reg b_trunc_ok;
	wire [63:0] br_abs;
	wire [63:0] bi_abs;
	wire [3:0] cmp_rb;
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
	localparam [63:0] UPY_F64_NONE = 64'hbff0000000000000;
	localparam [63:0] UPY_F64_PZERO = 64'h0000000000000000;
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
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
	function automatic upycore_f64_is_finite;
		input reg [63:0] v;
		upycore_f64_is_finite = v[62:52] != 11'h7ff;
	endfunction
	assign b_int = upycore_f64_is_finite(br) && (upycore_f64_floor(br) == br);
	function automatic upycore_f64_is_odd_integer;
		input reg [63:0] v;
		reg [10:0] e;
		begin
			e = v[62:52];
			if (((e < 11'd1023) || (e >= 11'd1076)) || !upycore_f64_is_finite(v))
				upycore_f64_is_odd_integer = 1'b0;
			else if (upycore_f64_floor(v) != v)
				upycore_f64_is_odd_integer = 1'b0;
			else
				upycore_f64_is_odd_integer = (e == 11'd1023 ? 1'b1 : v[sv2v_cast_6(11'd1075 - e)]);
		end
	endfunction
	assign b_odd = upycore_f64_is_odd_integer(br);
	assign b_gt0 = upycore_f64_gt(br, UPY_F64_PZERO);
	function automatic upycore_f64_lt_zero;
		input reg [63:0] v;
		upycore_f64_lt_zero = (v[63] && !upycore_f64_is_zero(v)) && !upycore_f64_is_nan(v);
	endfunction
	assign b_lt0 = upycore_f64_lt_zero(br);
	assign br_abs = {1'b0, br[62:0]};
	assign bi_abs = {1'b0, bi[62:0]};
	assign cmp_rb = upycore_f64_cmp(br_abs, bi_abs);
	wire [63:0] ai_abs;
	wire [3:0] cmp_hyp;
	wire [63:0] hyp_x;
	wire [63:0] hyp_y;
	assign ai_abs = {1'b0, ai[62:0]};
	assign cmp_hyp = upycore_f64_cmp(a_abs, ai_abs);
	assign hyp_x = (cmp_hyp[2] || cmp_hyp[1] ? a_abs : ai_abs);
	assign hyp_y = (cmp_hyp[2] || cmp_hyp[1] ? ai_abs : a_abs);
	wire a_has_inf;
	wire b_has_inf;
	wire a_fin;
	wire b_fin;
	wire crec_cand;
	wire crec_b;
	wire [62:0] crec_r1m;
	wire [62:0] crec_r2m;
	wire [62:0] crec_i1m;
	wire [62:0] crec_i2m;
	wire [63:0] crec_r1;
	wire [63:0] crec_r2;
	wire [63:0] crec_i1;
	wire [63:0] crec_i2;
	assign a_has_inf = upycore_f64_is_inf(ar) || upycore_f64_is_inf(ai);
	assign b_has_inf = upycore_f64_is_inf(br) || upycore_f64_is_inf(bi);
	assign a_fin = upycore_f64_is_finite(ar) && upycore_f64_is_finite(ai);
	assign b_fin = upycore_f64_is_finite(br) && upycore_f64_is_finite(bi);
	assign crec_cand = (a_has_inf && b_fin) || (b_has_inf && a_fin);
	assign crec_b = b_has_inf && a_fin;
	assign crec_r1m = (crec_b ? (upycore_f64_is_inf(br) ? ar[62:0] : 63'd0) : (upycore_f64_is_inf(ar) ? br[62:0] : 63'd0));
	assign crec_r2m = (crec_b ? (upycore_f64_is_inf(bi) ? ai[62:0] : 63'd0) : (upycore_f64_is_inf(ai) ? bi[62:0] : 63'd0));
	assign crec_i1m = (crec_b ? (upycore_f64_is_inf(br) ? ai[62:0] : 63'd0) : (upycore_f64_is_inf(ai) ? br[62:0] : 63'd0));
	assign crec_i2m = (crec_b ? (upycore_f64_is_inf(bi) ? ar[62:0] : 63'd0) : (upycore_f64_is_inf(ar) ? bi[62:0] : 63'd0));
	assign crec_r1 = {ar[63] ^ br[63], crec_r1m};
	assign crec_r2 = {ai[63] ^ bi[63], crec_r2m};
	assign crec_i1 = {ai[63] ^ br[63], crec_i1m};
	assign crec_i2 = {ar[63] ^ bi[63], crec_i2m};
	localparam [63:0] UPY_F64_PINF = 64'h7ff0000000000000;
	localparam [63:0] UPY_F64_QNAN = 64'h7ff8000000000000;
	function automatic [63:0] crec_scale;
		input reg [63:0] s;
		input reg by_zero;
		if (by_zero)
			crec_scale = (upycore_f64_is_inf(s) ? UPY_F64_QNAN : {s[63], 63'd0});
		else
			crec_scale = (upycore_f64_is_zero(s) ? UPY_F64_QNAN : {s[63], UPY_F64_PINF[62:0]});
	endfunction
	wire [63:0] b_trunc_abs;
	wire pow_n_small;
	function automatic upycore_float_trunc_int64;
		input reg [63:0] value;
		output reg [63:0] out_int;
		reg f_sign;
		reg [10:0] f_exp;
		reg [51:0] f_frac;
		reg [10:0] f_uexp;
		reg [52:0] f_sig;
		reg [63:0] f_mag;
		begin
			f_sign = value[63];
			f_exp = value[62:52];
			f_frac = value[51:0];
			f_uexp = f_exp - 11'd1023;
			f_sig = {1'b1, f_frac};
			f_mag = 64'd0;
			out_int = 64'd0;
			upycore_float_trunc_int64 = 1'b0;
			if (f_exp == 11'h7ff)
				;
			else if (f_exp < 11'd1023) begin
				out_int = 64'd0;
				upycore_float_trunc_int64 = 1'b1;
			end
			else if (f_uexp >= 11'd63)
				;
			else begin
				if (f_uexp < 11'd52)
					f_mag = {11'b00000000000, f_sig} >> (11'd52 - f_uexp);
				else
					f_mag = {11'b00000000000, f_sig} << (f_uexp - 11'd52);
				out_int = (f_sign ? ~f_mag + 64'd1 : f_mag);
				upycore_float_trunc_int64 = 1'b1;
			end
		end
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		b_trunc_ok = upycore_float_trunc_int64(br, b_trunc_int);
	end
	assign b_trunc_abs = (b_trunc_int[63] ? ~b_trunc_int + 64'd1 : b_trunc_int);
	function automatic signed [63:0] sv2v_cast_64_signed;
		input reg signed [63:0] inp;
		sv2v_cast_64_signed = inp;
	endfunction
	assign pow_n_small = b_trunc_abs <= sv2v_cast_64_signed(POW_CHAIN_MAX);
	localparam [4:0] UPY_ALU_ABS = 5'd24;
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
	function automatic upycore_f64_eq;
		input reg [63:0] a;
		input reg [63:0] b;
		reg [3:0] c;
		begin
			c = upycore_f64_cmp(a, b);
			upycore_f64_eq = c[1];
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
		dec_cdiv_b = 1'b0;
		dec_pow_neg = 1'b0;
		dec_pow_recip = 1'b0;
		dec_pow_n = 1'sb0;
		if (!complex_i)
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
						dec_result = {64'd0, UPY_F64_ONE};
					else if (a_nan)
						dec_result = {64'd0, ar};
					else if (b_nan)
						dec_result = {64'd0, (ar == UPY_F64_ONE ? UPY_F64_ONE : br)};
					else if (b_inf) begin
						if (a_abs_one)
							dec_result = {64'd0, UPY_F64_ONE};
						else if (b_gt0 == a_abs_gt_one)
							dec_result = {64'd0, UPY_F64_PINF};
						else
							dec_result = {64'd0, UPY_F64_PZERO};
					end
					else if (a_inf) begin
						if (b_gt0)
							dec_result = {64'd0, (b_odd ? ar : a_abs)};
						else
							dec_result = {64'd0, (b_odd ? {ar[63], 63'd0} : UPY_F64_PZERO)};
					end
					else if (a_zero) begin
						if (b_lt0)
							dec_kind = 2'd1;
						else
							dec_result = {64'd0, (b_odd ? ar : UPY_F64_PZERO)};
					end
					else if (!b_int && ar[63])
						dec_kind = 2'd1;
					else if (a_abs_one)
						dec_result = {64'd0, (ar[63] && b_odd ? UPY_F64_NONE : UPY_F64_ONE)};
					else if (br == UPY_F64_HALF) begin
						dec_kind = 2'd3;
						dec_next = 6'd23;
					end
					else if ((b_int && b_trunc_ok) && pow_n_small) begin
						dec_kind = 2'd3;
						dec_next = 6'd14;
						dec_pow_neg = ar[63] && b_odd;
						dec_pow_recip = b_lt0;
						dec_pow_n = b_trunc_abs;
					end
					else begin
						dec_kind = 2'd3;
						dec_next = 6'd22;
						dec_pow_neg = ar[63] && b_odd;
					end
				end
				UPY_ALU_NEG: begin
					dec_kind = 2'd0;
					dec_result = {64'd0, ~ar[63], ar[62:0]};
				end
				UPY_ALU_POS, UPY_ALU_PASS: begin
					dec_kind = 2'd0;
					dec_result = {64'd0, ar};
				end
				UPY_ALU_NOT: begin
					dec_kind = 2'd0;
					dec_result = {127'd0, a_zero};
				end
				UPY_ALU_EQ, UPY_ALU_NE, UPY_ALU_LT, UPY_ALU_LE, UPY_ALU_GT, UPY_ALU_GE: begin
					dec_kind = 2'd0;
					dec_result = {127'd0, upycore_f64_compare_op(op_i, ar, br)};
				end
				default: dec_kind = 2'd1;
			endcase
		else
			(* full_case, parallel_case *)
			case (op_i)
				UPY_ALU_ADD: begin
					dec_kind = 2'd3;
					dec_next = 6'd24;
				end
				UPY_ALU_SUB: begin
					dec_kind = 2'd3;
					dec_next = 6'd24;
					dec_sub = 1'b1;
				end
				UPY_ALU_MUL: begin
					dec_kind = 2'd3;
					dec_next = 6'd26;
				end
				UPY_ALU_TRUE_DIV:
					if (cmp_rb[2] || cmp_rb[1]) begin
						dec_kind = (br_abs == 64'd0 ? 2'd1 : 2'd3);
						dec_next = 6'd32;
					end
					else if (cmp_rb[0]) begin
						dec_kind = 2'd3;
						dec_next = 6'd32;
						dec_cdiv_b = 1'b1;
					end
					else if (crec_cand) begin
						dec_kind = 2'd3;
						dec_next = 6'd42;
					end
					else begin
						dec_kind = 2'd0;
						dec_result = {UPY_F64_QNAN, UPY_F64_QNAN};
					end
				UPY_ALU_NEG: begin
					dec_kind = 2'd0;
					dec_result = {~ai[63], ai[62:0], ~ar[63], ar[62:0]};
				end
				UPY_ALU_POS, UPY_ALU_PASS: begin
					dec_kind = 2'd0;
					dec_result = op_a_i;
				end
				UPY_ALU_NOT: begin
					dec_kind = 2'd0;
					dec_result = {127'd0, upycore_f64_is_zero(ar) && upycore_f64_is_zero(ai)};
				end
				UPY_ALU_EQ: begin
					dec_kind = 2'd0;
					dec_result = {127'd0, upycore_f64_eq(ar, br) && upycore_f64_eq(ai, bi)};
				end
				UPY_ALU_NE: begin
					dec_kind = 2'd0;
					dec_result = {127'd0, !(upycore_f64_eq(ar, br) && upycore_f64_eq(ai, bi))};
				end
				UPY_ALU_ABS:
					if (upycore_f64_is_inf(ar) || upycore_f64_is_inf(ai)) begin
						dec_kind = 2'd0;
						dec_result = {64'd0, UPY_F64_PINF};
					end
					else if (upycore_f64_is_nan(ar) || upycore_f64_is_nan(ai)) begin
						dec_kind = 2'd0;
						dec_result = {64'd0, UPY_F64_QNAN};
					end
					else if (upycore_f64_is_zero(a_abs) || upycore_f64_is_zero(ai_abs)) begin
						dec_kind = 2'd0;
						dec_result = {64'd0, hyp_x};
					end
					else begin
						dec_kind = 2'd3;
						dec_next = 6'd44;
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
			6'd11: begin
				u_add_start = 1'b1;
				u_sub = 1'b1;
				u_a = t1_r;
				u_b = t2_r;
			end
			6'd13: begin
				u_add_start = 1'b1;
				u_a = t2_r;
				u_b = UPY_F64_ONE;
			end
			6'd16: begin
				u_mul_start = 1'b1;
				u_a = t0_r;
				u_b = t0_r;
			end
			6'd17: begin
				u_mul_start = 1'b1;
				u_a = t0_r;
				u_b = t1_r;
			end
			6'd19: begin
				u_div_start = 1'b1;
				u_a = UPY_F64_ONE;
				u_b = t0_r;
			end
			6'd20: begin
				u_div_start = 1'b1;
				u_a = UPY_F64_ONE;
				u_b = t1_r;
			end
			6'd22: begin
				u_pow_start = 1'b1;
				u_a = a_abs;
				u_b = br;
			end
			6'd23: begin
				u_div_start = 1'b1;
				u_sqrt = 1'b1;
				u_a = a_abs;
			end
			6'd24: begin
				u_add_start = 1'b1;
				u_sub = op_i == UPY_ALU_SUB;
				u_a = ar;
				u_b = br;
			end
			6'd25: begin
				u_add_start = 1'b1;
				u_sub = op_i == UPY_ALU_SUB;
				u_a = ai;
				u_b = bi;
			end
			6'd26: begin
				u_mul_start = 1'b1;
				u_a = ar;
				u_b = br;
			end
			6'd27: begin
				u_mul_start = 1'b1;
				u_a = ai;
				u_b = bi;
			end
			6'd28: begin
				u_mul_start = 1'b1;
				u_a = ar;
				u_b = bi;
			end
			6'd29: begin
				u_mul_start = 1'b1;
				u_a = ai;
				u_b = br;
			end
			6'd30: begin
				u_add_start = 1'b1;
				u_sub = 1'b1;
				u_a = t0_r;
				u_b = t1_r;
			end
			6'd31: begin
				u_add_start = 1'b1;
				u_a = t2_r;
				u_b = t3_r;
			end
			6'd32: begin
				u_div_start = 1'b1;
				u_a = (cdiv_b_r ? br : bi);
				u_b = (cdiv_b_r ? bi : br);
			end
			6'd33: begin
				u_mul_start = 1'b1;
				u_a = (cdiv_b_r ? br : bi);
				u_b = t0_r;
			end
			6'd34: begin
				u_add_start = 1'b1;
				u_a = (cdiv_b_r ? t1_r : br);
				u_b = (cdiv_b_r ? bi : t1_r);
			end
			6'd35: begin
				u_mul_start = 1'b1;
				u_a = (cdiv_b_r ? ar : ai);
				u_b = t0_r;
			end
			6'd36: begin
				u_add_start = 1'b1;
				u_a = (cdiv_b_r ? t2_r : ar);
				u_b = (cdiv_b_r ? ai : t2_r);
			end
			6'd37: begin
				u_div_start = 1'b1;
				u_a = t2_r;
				u_b = t1_r;
			end
			6'd38: begin
				u_mul_start = 1'b1;
				u_a = (cdiv_b_r ? ai : ar);
				u_b = t0_r;
			end
			6'd39: begin
				u_add_start = 1'b1;
				u_sub = 1'b1;
				u_a = (cdiv_b_r ? t3_r : ai);
				u_b = (cdiv_b_r ? ar : t3_r);
			end
			6'd40: begin
				u_div_start = 1'b1;
				u_a = t3_r;
				u_b = t1_r;
			end
			6'd42: begin
				u_add_start = 1'b1;
				u_a = crec_r1;
				u_b = crec_r2;
			end
			6'd43: begin
				u_add_start = 1'b1;
				u_sub = 1'b1;
				u_a = crec_i1;
				u_b = crec_i2;
			end
			6'd44: begin
				u_div_start = 1'b1;
				u_a = t0_r;
				u_b = t1_r;
			end
			6'd45: begin
				u_mul_start = 1'b1;
				u_a = t0_r;
				u_b = t0_r;
			end
			6'd46: begin
				u_add_start = 1'b1;
				u_a = UPY_F64_ONE;
				u_b = t0_r;
			end
			6'd47: begin
				u_div_start = 1'b1;
				u_sqrt = 1'b1;
				u_a = t0_r;
			end
			6'd48: begin
				u_mul_start = 1'b1;
				u_a = t0_r;
				u_b = t1_r;
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
	assign mod_fix_add = !upycore_f64_eq(t0_r, UPY_F64_PZERO) && (b_lt0 != upycore_f64_lt_zero(t0_r));
	assign fd_div_nonzero = !upycore_f64_eq(t1_r, UPY_F64_PZERO);
	assign fd_floor = upycore_f64_floor(t1_r);
	assign fd_half_up = upycore_f64_gt(t3_r, UPY_F64_HALF);
	assign pow_overflow = upycore_f64_is_inf(t0_r);
	function automatic signed [6:0] sv2v_cast_7_signed;
		input reg signed [6:0] inp;
		sv2v_cast_7_signed = inp;
	endfunction
	function automatic [6:0] upycore_clz64;
		input reg [63:0] v;
		begin
			upycore_clz64 = 7'd64;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < 64; i = i + 1)
					if (v[i])
						upycore_clz64 = sv2v_cast_7_signed(63 - i);
			end
		end
	endfunction
	assign pow_lz = upycore_clz64(pow_n_r);
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
			cdiv_b_r <= 1'b0;
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
						cdiv_b_r <= dec_cdiv_b;
						pow_neg_r <= dec_pow_neg;
						pow_recip_r <= dec_pow_recip;
						pow_n_r <= dec_pow_n;
						pow_n0_r <= dec_pow_n;
						t0_r <= UPY_F64_ONE;
						t1_r <= a_abs;
						if (complex_i && (op_i == UPY_ALU_ABS)) begin
							t0_r <= hyp_y;
							t1_r <= hyp_x;
						end
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
						res_r <= {64'd0, (upycore_f64_eq(t0_r, UPY_F64_PZERO) ? {br[63], 63'd0} : t0_r)};
						state_r <= 6'd49;
					end
				6'd4:
					if (u_done) begin
						res_r <= {64'd0, u_res};
						state_r <= 6'd49;
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
				6'd8: state_r <= (mod_fix_add ? 6'd9 : 6'd10);
				6'd9:
					if (u_done) begin
						t1_r <= u_res;
						state_r <= 6'd10;
					end
				6'd10:
					if (fd_div_nonzero) begin
						t2_r <= fd_floor;
						state_r <= 6'd11;
					end
					else begin
						res_r <= {64'd0, ar[63] ^ br[63], 63'd0};
						state_r <= 6'd49;
					end
				6'd11:
					if (u_done) begin
						t3_r <= u_res;
						state_r <= 6'd12;
					end
				6'd12:
					if (fd_half_up)
						state_r <= 6'd13;
					else begin
						res_r <= {64'd0, t2_r};
						state_r <= 6'd49;
					end
				6'd13:
					if (u_done) begin
						res_r <= {64'd0, u_res};
						state_r <= 6'd49;
					end
				6'd14: begin
					t0_r <= t1_r;
					pow_n_r <= pow_n_r << (pow_lz + 7'd1);
					pow_cnt_r <= 7'd63 - pow_lz;
					state_r <= 6'd15;
				end
				6'd15: state_r <= (pow_cnt_r == 7'd0 ? 6'd18 : 6'd16);
				6'd16:
					if (u_done) begin
						t0_r <= u_res;
						if (pow_n_r[63])
							state_r <= 6'd17;
						else begin
							pow_n_r <= pow_n_r << 1;
							pow_cnt_r <= pow_cnt_r - 7'd1;
							state_r <= 6'd15;
						end
					end
				6'd17:
					if (u_done) begin
						t0_r <= u_res;
						pow_n_r <= pow_n_r << 1;
						pow_cnt_r <= pow_cnt_r - 7'd1;
						state_r <= 6'd15;
					end
				6'd18:
					if (!pow_recip_r)
						state_r <= 6'd21;
					else if (pow_overflow)
						state_r <= 6'd20;
					else
						state_r <= 6'd19;
				6'd19:
					if (u_done) begin
						t0_r <= u_res;
						state_r <= 6'd21;
					end
				6'd20:
					if (u_done) begin
						t1_r <= u_res;
						pow_n_r <= pow_n0_r;
						pow_recip_r <= 1'b0;
						state_r <= 6'd14;
					end
				6'd21:
					if (pow_overflow)
						state_r <= 6'd50;
					else begin
						res_r <= {64'd0, t0_r[63] ^ pow_neg_r, t0_r[62:0]};
						state_r <= 6'd49;
					end
				6'd22:
					if (u_done) begin
						t0_r <= u_res;
						state_r <= 6'd21;
					end
				6'd23:
					if (u_done) begin
						t0_r <= u_res;
						state_r <= 6'd21;
					end
				6'd24:
					if (u_done) begin
						t0_r <= u_res;
						state_r <= 6'd25;
					end
				6'd25:
					if (u_done) begin
						res_r <= {u_res, t0_r};
						state_r <= 6'd49;
					end
				6'd26:
					if (u_done) begin
						t0_r <= u_res;
						state_r <= 6'd27;
					end
				6'd27:
					if (u_done) begin
						t1_r <= u_res;
						state_r <= 6'd28;
					end
				6'd28:
					if (u_done) begin
						t2_r <= u_res;
						state_r <= 6'd29;
					end
				6'd29:
					if (u_done) begin
						t3_r <= u_res;
						state_r <= 6'd30;
					end
				6'd30:
					if (u_done) begin
						t0_r <= u_res;
						state_r <= 6'd31;
					end
				6'd31:
					if (u_done) begin
						res_r <= {u_res, t0_r};
						state_r <= 6'd49;
					end
				6'd32:
					if (u_done) begin
						t0_r <= u_res;
						state_r <= 6'd33;
					end
				6'd33:
					if (u_done) begin
						t1_r <= u_res;
						state_r <= 6'd34;
					end
				6'd34:
					if (u_done) begin
						t1_r <= u_res;
						state_r <= 6'd35;
					end
				6'd35:
					if (u_done) begin
						t2_r <= u_res;
						state_r <= 6'd36;
					end
				6'd36:
					if (u_done) begin
						t2_r <= u_res;
						state_r <= 6'd37;
					end
				6'd37:
					if (u_done) begin
						t2_r <= u_res;
						state_r <= 6'd38;
					end
				6'd38:
					if (u_done) begin
						t3_r <= u_res;
						state_r <= 6'd39;
					end
				6'd39:
					if (u_done) begin
						t3_r <= u_res;
						state_r <= 6'd40;
					end
				6'd40:
					if (u_done) begin
						if (crec_cand) begin
							t3_r <= u_res;
							state_r <= 6'd41;
						end
						else begin
							res_r <= {u_res, t2_r};
							state_r <= 6'd49;
						end
					end
				6'd41:
					if (upycore_f64_is_nan(t2_r) && upycore_f64_is_nan(t3_r))
						state_r <= 6'd42;
					else begin
						res_r <= {t3_r, t2_r};
						state_r <= 6'd49;
					end
				6'd42:
					if (u_done) begin
						t2_r <= crec_scale(u_res, crec_b);
						state_r <= 6'd43;
					end
				6'd43:
					if (u_done) begin
						res_r <= {crec_scale(u_res, crec_b), t2_r};
						state_r <= 6'd49;
					end
				6'd44:
					if (u_done) begin
						t0_r <= u_res;
						state_r <= 6'd45;
					end
				6'd45:
					if (u_done) begin
						t0_r <= u_res;
						state_r <= 6'd46;
					end
				6'd46:
					if (u_done) begin
						t0_r <= u_res;
						state_r <= 6'd47;
					end
				6'd47:
					if (u_done) begin
						t0_r <= u_res;
						state_r <= 6'd48;
					end
				6'd48:
					if (u_done) begin
						res_r <= {64'd0, u_res};
						state_r <= 6'd49;
					end
				6'd49, 6'd50: state_r <= 6'd0;
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
				result_o = {64'd0, u_res};
			end
			6'd49: done_o = 1'b1;
			6'd50: exception_o = 1'b1;
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
	wire [52:0] shifted;
	wire [52:0] below;
	wire [23:0] mag;
	assign sign = d_i[63];
	assign exp = d_i[62:52];
	assign frac = d_i[51:0];
	assign exp32 = $signed({2'b00, exp}) - 13'sd896;
	assign round_up = d_i[28] && (|d_i[27:0] || d_i[29]);
	assign sumf = {1'b0, d_i[51:29]} + {23'b00000000000000000000000, round_up};
	assign sig = {1'b1, frac};
	assign sh = 12'd926 - {1'b0, exp};
	assign shifted = sig >> sh[5:0];
	assign below = (sh <= 12'd1 ? 53'd0 : sig & ((53'd1 << (sh[5:0] - 6'd1)) - 53'd1));
	assign mag = {1'b0, shifted[22:0]} + {23'd0, ((sh != 12'd0) && sig[sh[5:0] - 6'd1]) && (|below || shifted[0])};
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
	reg [2:0] st;
	reg [5:0] op;
	reg small_r;
	reg [63:0] a;
	reg [63:0] b;
	reg [31:0] fa;
	reg [31:0] fb;
	wire [63:0] fa64;
	wire [63:0] fb64;
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
	assign mul_a = (st == 3'd3 ? pow_mul_a : a);
	assign mul_b = (st == 3'd3 ? pow_mul_b : b);
	upycore_mul u_mul(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.start_i((st == 3'd1) || ((st == 3'd3) && pow_mul_start)),
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
		.start_i(st == 3'd3),
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
		.start_i(st == 3'd2),
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
	wire [127:0] fres;
	wire [31:0] fnarrow;
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
		.start_i(st == 3'd4),
		.op_i(fop),
		.complex_i(1'b0),
		.op_a_i({64'd0, fa64}),
		.op_b_i({64'd0, fb64}),
		.result_o(fres),
		.exception_o(fexc),
		.done_o(fdone),
		.stall_o(fstall),
		.busy_o(fbusy)
	);
	mpy_f32_widen u_wa(
		.f_i(fa),
		.d_o(fa64)
	);
	mpy_f32_widen u_wb(
		.f_i(fb),
		.d_o(fb64)
	);
	mpy_f32_narrow u_narrow(
		.d_i(fres[63:0]),
		.q_o(fnarrow)
	);
	localparam [2:0] mpy_alu_pkg_AE_COMPLEX = 3'd5;
	localparam [2:0] mpy_alu_pkg_AE_FTOI = 3'd6;
	localparam [2:0] mpy_alu_pkg_AE_NEG_SHIFT = 3'd3;
	localparam [2:0] mpy_alu_pkg_AE_NONE = 3'd0;
	localparam [2:0] mpy_alu_pkg_AE_OVERFLOW = 3'd2;
	localparam [2:0] mpy_alu_pkg_AE_UNSUPPORTED = 3'd4;
	localparam [2:0] mpy_alu_pkg_AE_ZERO_DIV = 3'd1;
	localparam [1:0] mpy_alu_pkg_AK_BOOL = 2'd3;
	localparam [1:0] mpy_alu_pkg_AK_FLOAT = 2'd1;
	localparam [1:0] mpy_alu_pkg_AK_INT = 2'd0;
	localparam [5:0] mpy_alu_pkg_ALU_ABS = 6'd43;
	localparam [5:0] mpy_alu_pkg_ALU_F2I = 6'd45;
	localparam [5:0] mpy_alu_pkg_ALU_I2F = 6'd44;
	localparam [5:0] mpy_alu_pkg_ALU_MATMUL = 6'd30;
	localparam [5:0] mpy_alu_pkg_ALU_POS = 6'd41;
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
	function automatic signed [8:0] sv2v_cast_9_signed;
		input reg signed [8:0] inp;
		sv2v_cast_9_signed = inp;
	endfunction
	function automatic [31:0] mpy_alu_pkg_mpy_i64_to_f32;
		input reg [63:0] v;
		reg s;
		reg [63:0] m;
		reg [63:0] mant;
		reg [63:0] rem;
		reg [63:0] half;
		reg signed [31:0] msb;
		reg signed [31:0] sh;
		reg [8:0] e;
		begin
			s = v[63];
			m = (s ? ~v + 64'd1 : v);
			msb = 0;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < 64; i = i + 1)
					if (m[i])
						msb = i;
			end
			if (m == 64'd0)
				mpy_alu_pkg_mpy_i64_to_f32 = 32'd0;
			else if (msb <= 23) begin
				mant = m << (23 - msb);
				e = sv2v_cast_9_signed(msb + 127);
				mpy_alu_pkg_mpy_i64_to_f32 = {s, e[7:0], mant[22:0]};
			end
			else begin
				sh = msb - 23;
				mant = m >> sh;
				rem = m & ((64'd1 << sh) - 64'd1);
				half = 64'd1 << (sh - 1);
				e = sv2v_cast_9_signed(msb + 127);
				if ((rem > half) || ((rem == half) && mant[0]))
					mant = mant + 64'd1;
				if (mant[24]) begin
					mant = mant >> 1;
					e = e + 9'd1;
				end
				mpy_alu_pkg_mpy_i64_to_f32 = {s, e[7:0], mant[22:0]};
			end
		end
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			st <= 3'd0;
			done_o <= 1'b0;
			res_o <= 1'sb0;
			rkind_o <= mpy_alu_pkg_AK_INT;
			err_o <= mpy_alu_pkg_AE_NONE;
			op <= 1'sb0;
			small_r <= 1'b0;
			a <= 1'sb0;
			b <= 1'sb0;
			fa <= 1'sb0;
			fb <= 1'sb0;
		end
		else begin
			done_o <= 1'b0;
			case (st)
				3'd0:
					if (start_i) begin : sv2v_autoblock_2
						reg [31:0] xa;
						reg [31:0] xb;
						reg isf;
						reg ok;
						reg [63:0] v;
						op <= op_i;
						small_r <= small_i;
						a <= a_i;
						b <= b_i;
						xa = (a_flt_i ? a_i[31:0] : mpy_alu_pkg_mpy_i64_to_f32(a_i));
						xb = (b_flt_i ? b_i[31:0] : mpy_alu_pkg_mpy_i64_to_f32(b_i));
						fa <= xa;
						fb <= xb;
						err_o <= mpy_alu_pkg_AE_NONE;
						res_o <= 1'sb0;
						rkind_o <= mpy_alu_pkg_AK_INT;
						isf = a_flt_i || b_flt_i;
						if (op_i == mpy_alu_pkg_ALU_I2F) begin
							res_o <= {32'd0, xa};
							rkind_o <= mpy_alu_pkg_AK_FLOAT;
							st <= 3'd5;
						end
						else if (op_i == mpy_alu_pkg_ALU_F2I) begin
							v = mpy_alu_pkg_mpy_f32_to_i64(a_i[31:0], ok);
							res_o <= v;
							if (!ok)
								err_o <= mpy_alu_pkg_AE_FTOI;
							st <= 3'd5;
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
								st <= 3'd5;
							end
							else begin
								if ((op_i == mpy_alu_pkg_ALU_ABS) && !a_i[63])
									op <= mpy_alu_pkg_ALU_POS;
								else if (op_i == mpy_alu_pkg_ALU_ABS)
									op <= mpy_alu_pkg_ALU_NEG;
								st <= 3'd5;
							end
						end
						else if (op_i <= mpy_alu_pkg_ALU_NE) begin
							if (isf) begin
								rkind_o <= mpy_alu_pkg_AK_BOOL;
								case (op_i)
									mpy_alu_pkg_ALU_LT: res_o <= {63'd0, mpy_alu_pkg_mpy_f32_lt(xa, xb)};
									mpy_alu_pkg_ALU_GT: res_o <= {63'd0, mpy_alu_pkg_mpy_f32_lt(xb, xa)};
									mpy_alu_pkg_ALU_LE: res_o <= {63'd0, mpy_alu_pkg_mpy_f32_lt(xa, xb) || mpy_alu_pkg_mpy_f32_eq(xa, xb)};
									mpy_alu_pkg_ALU_GE: res_o <= {63'd0, mpy_alu_pkg_mpy_f32_lt(xb, xa) || mpy_alu_pkg_mpy_f32_eq(xa, xb)};
									mpy_alu_pkg_ALU_EQ: res_o <= {63'd0, mpy_alu_pkg_mpy_f32_eq(xa, xb)};
									default: res_o <= {63'd0, !mpy_alu_pkg_mpy_f32_eq(xa, xb)};
								endcase
							end
							st <= 3'd5;
						end
						else if ((isf || (op_i == mpy_alu_pkg_ALU_TDIV)) || ((op_i == mpy_alu_pkg_ALU_POW) && b_i[63])) begin
							rkind_o <= mpy_alu_pkg_AK_FLOAT;
							case (op_i)
								mpy_alu_pkg_ALU_ADD, mpy_alu_pkg_ALU_SUB, mpy_alu_pkg_ALU_MUL: st <= 3'd4;
								mpy_alu_pkg_ALU_TDIV, mpy_alu_pkg_ALU_FLOOR, mpy_alu_pkg_ALU_MOD:
									if (mpy_alu_pkg_mpy_f32_zero(xb)) begin
										err_o <= mpy_alu_pkg_AE_ZERO_DIV;
										st <= 3'd5;
									end
									else
										st <= 3'd4;
								mpy_alu_pkg_ALU_POW:
									if ((mpy_alu_pkg_mpy_f32_zero(xa) && xb[31]) && !((xb[30:23] == 8'hff) && (xb[22:0] == 23'd0))) begin
										err_o <= mpy_alu_pkg_AE_ZERO_DIV;
										st <= 3'd5;
									end
									else if (((((xa[31] && !mpy_alu_pkg_mpy_f32_zero(xa)) && !mpy_alu_pkg_mpy_f32_nan(xa)) && !mpy_alu_pkg_mpy_f32_integral(xb)) && !mpy_alu_pkg_mpy_f32_nan(xb)) && (xb[30:23] != 8'hff)) begin
										err_o <= mpy_alu_pkg_AE_COMPLEX;
										st <= 3'd5;
									end
									else
										st <= 3'd4;
								default: begin
									err_o <= mpy_alu_pkg_AE_UNSUPPORTED;
									st <= 3'd5;
								end
							endcase
						end
						else
							case (op_i)
								mpy_alu_pkg_ALU_MUL: st <= 3'd1;
								mpy_alu_pkg_ALU_FLOOR, mpy_alu_pkg_ALU_MOD:
									if (b_i == 64'd0) begin
										err_o <= mpy_alu_pkg_AE_ZERO_DIV;
										st <= 3'd5;
									end
									else
										st <= 3'd2;
								mpy_alu_pkg_ALU_POW: st <= 3'd3;
								mpy_alu_pkg_ALU_MATMUL: begin
									err_o <= mpy_alu_pkg_AE_UNSUPPORTED;
									st <= 3'd5;
								end
								default: st <= 3'd5;
							endcase
					end
				3'd1:
					if (mul_done) begin
						res_o <= mul_lo;
						if (mul_hi != {64 {mul_lo[63]}})
							err_o <= mpy_alu_pkg_AE_OVERFLOW;
						st <= 3'd0;
						done_o <= 1'b1;
					end
				3'd2:
					if (div_done) begin
						if ((!small_r && (rem != 64'd0)) && (a[63] != b[63]))
							res_o <= (op == mpy_alu_pkg_ALU_FLOOR ? quot + 64'd1 : rem - b);
						else
							res_o <= (op == mpy_alu_pkg_ALU_FLOOR ? quot : rem);
						st <= 3'd0;
						done_o <= 1'b1;
					end
				3'd3:
					if (pow_done || pow_trap) begin
						res_o <= pow_res;
						if (pow_trap)
							err_o <= mpy_alu_pkg_AE_OVERFLOW;
						st <= 3'd0;
						done_o <= 1'b1;
					end
				3'd4:
					if (fdone || fexc) begin
						if (fexc)
							res_o <= {32'd0, fa[31] && mpy_alu_pkg_mpy_f32_odd(fb), 31'h7f800000};
						else
							res_o <= {32'd0, fnarrow};
						st <= 3'd0;
						done_o <= 1'b1;
					end
				3'd5: begin
					if (((rkind_o == mpy_alu_pkg_AK_INT) && (err_o == mpy_alu_pkg_AE_NONE)) && (op != mpy_alu_pkg_ALU_F2I)) begin
						res_o <= ires;
						if (op <= mpy_alu_pkg_ALU_NE)
							rkind_o <= mpy_alu_pkg_AK_BOOL;
						else if (iverr)
							err_o <= mpy_alu_pkg_AE_NEG_SHIFT;
						else if (iovf)
							err_o <= mpy_alu_pkg_AE_OVERFLOW;
					end
					st <= 3'd0;
					done_o <= 1'b1;
				end
				default: st <= 3'd0;
			endcase
		end
	wire unused;
	assign unused = ^{izero, mul_stall, mul_busy, pow_stall, pow_busy, div_zero, div_stall, div_busy, fstall, fbusy, fres[127:64]};
	initial _sv2v_0 = 0;
endmodule
