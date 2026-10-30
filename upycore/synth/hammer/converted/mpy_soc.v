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
	reg signed [13:0] r_exp;
	reg [52:0] r_sig;
	reg r_g;
	reg r_r;
	reg r_s;
	reg [5:0] rem_lz;
	reg p_valid_r;
	reg p_special_r;
	reg p_sign_r;
	reg p_g_r;
	reg p_r_r;
	reg p_s_r;
	reg [63:0] p_special_val_r;
	reg signed [13:0] p_exp_r;
	reg [52:0] p_sig_r;
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
		end
		else begin
			p_valid_r <= core_done || fin_r;
			if (core_done || fin_r) begin
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
	assign result_o = (p_special_r ? p_special_val_r : upycore_f64_pack_round(p_sign_r, p_exp_r, p_sig_r, p_g_r, p_r_r, p_s_r));
	assign done_o = p_valid_r;
	assign busy_o = (((s1_valid_r | core_busy) | core_done) | fin_r) | p_valid_r;
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
	assign in_log = state_r == 4'd4;
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
			4'd3: begin
				pf_k = j0_r;
				pf_sh = 7'd0;
			end
			4'd4: begin
				pf_k = j_r + 8'd1;
				pf_sh = i_r + 7'd1;
			end
			4'd11: begin
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
	assign mul_start_o = state_r == 4'd9;
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
						j0_r <= j0_sel;
						rz_r <= r_mag == {88 {1'sb0}};
						state_r <= 4'd3;
					end
					4'd3: begin
						r_r <= -r_r <<< j0_r;
						j_r <= j0_r;
						i_r <= 1'sb0;
						cpos_r <= pf_pos;
						cneg_r <= pf_neg;
						state_r <= (rz_r ? 4'd5 : 4'd4);
					end
					4'd4: begin
						r_r <= w_next;
						acc_r <= acc_next;
						j_r <= j_r + 8'd1;
						i_r <= i_r + 7'd1;
						cpos_r <= pf_pos;
						cneg_r <= pf_neg;
						if (i_r == sv2v_cast_7_signed(79))
							state_r <= 4'd5;
					end
					4'd5: begin
						v_r <= v_sum;
						lscale_r <= (e_r == 13'sd0 ? j0_r : 8'd0);
						state_r <= 4'd6;
					end
					4'd6: begin
						lsign_r <= v_r[LW];
						lmag_r <= sv2v_cast_4587C_signed((v_r[LW] ? -v_r : v_r));
						state_r <= 4'd7;
					end
					4'd7: begin
						lz_r <= lmag_clz;
						state_r <= 4'd8;
					end
					4'd8: begin
						lm_r <= lmag_norm[100:LW - LMW];
						el_r <= ((sv2v_cast_13_signed(LW - LMW) - sv2v_cast_13(lz_r)) - sv2v_cast_13_signed(FW)) - sv2v_cast_13(lscale_r);
						psign_r <= ysign_r ^ lsign_r;
						state_r <= 4'd9;
					end
					4'd9:
						if (mul_done)
							state_r <= 4'd10;
					4'd10: begin
						pfix_r <= q_shifted[91:0];
						huge_r <= p_huge;
						state_r <= 4'd11;
					end
					4'd11: begin
						i_int_r <= pfix_s[PW:FP];
						f_r <= {pfix_s[79:0], {FW - FP {1'b0}}};
						z_r <= {1'b1, {FW {1'b0}}};
						i_r <= 7'd1;
						cpos_r <= pf_pos;
						state_r <= (huge_r ? 4'd13 : 4'd12);
					end
					4'd12: begin
						if (exp_take) begin
							f_r <= f_r - exp_c;
							z_r <= z_r + z_sh;
						end
						i_r <= i_r + 7'd1;
						cpos_r <= pf_pos;
						if (i_r == sv2v_cast_7_signed(NEXP))
							state_r <= 4'd13;
					end
					4'd13: begin
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
	reg [63:0] fa64_r;
	reg [63:0] fb64_r;
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
		.start_i(st == 3'd4),
		.op_i(fop),
		.complex_i(1'b0),
		.op_a_i({64'd0, fa64_r}),
		.op_b_i({64'd0, fb64_r}),
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
	assign dop = (st == 3'd6 ? op : op_i);
	assign dxa = (st == 3'd6 ? fa : a_i[31:0]);
	assign dxb = (st == 3'd6 ? fb : b_i[31:0]);
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
			fres_r <= 1'sb0;
			fa64_r <= 1'sb0;
			fb64_r <= 1'sb0;
		end
		else begin
			done_o <= 1'b0;
			case (st)
				3'd0:
					if (start_i) begin : sv2v_autoblock_2
						reg [31:0] xa;
						reg [31:0] xb;
						reg isf;
						reg conv;
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
						fa64_r <= fa64;
						fb64_r <= fb64;
						err_o <= mpy_alu_pkg_AE_NONE;
						res_o <= 1'sb0;
						rkind_o <= mpy_alu_pkg_AK_INT;
						isf = a_flt_i || b_flt_i;
						conv = !a_flt_i || !b_flt_i;
						if (op_i == mpy_alu_pkg_ALU_I2F) begin
							res_o <= {32'd0, xa};
							rkind_o <= mpy_alu_pkg_AK_FLOAT;
							st <= 3'd7;
						end
						else if (op_i == mpy_alu_pkg_ALU_F2I) begin
							v = mpy_alu_pkg_mpy_f32_to_i64(a_i[31:0], ok);
							res_o <= v;
							if (!ok)
								err_o <= mpy_alu_pkg_AE_FTOI;
							st <= 3'd7;
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
								st <= 3'd7;
							end
							else begin
								if ((op_i == mpy_alu_pkg_ALU_ABS) && !a_i[63])
									op <= mpy_alu_pkg_ALU_POS;
								else if (op_i == mpy_alu_pkg_ALU_ABS)
									op <= mpy_alu_pkg_ALU_NEG;
								st <= 3'd7;
							end
						end
						else if (op_i <= mpy_alu_pkg_ALU_NE) begin
							if (isf && conv)
								st <= 3'd6;
							else if (isf) begin
								rkind_o <= mpy_alu_pkg_AK_BOOL;
								res_o <= {63'd0, f_cmp};
								st <= 3'd7;
							end
							else
								st <= 3'd7;
						end
						else if ((isf || (op_i == mpy_alu_pkg_ALU_TDIV)) || ((op_i == mpy_alu_pkg_ALU_POW) && b_i[63])) begin
							rkind_o <= mpy_alu_pkg_AK_FLOAT;
							if (conv)
								st <= 3'd6;
							else begin
								err_o <= f_err;
								st <= (f_fpu ? 3'd4 : 3'd7);
							end
						end
						else
							case (op_i)
								mpy_alu_pkg_ALU_MUL: st <= 3'd1;
								mpy_alu_pkg_ALU_FLOOR, mpy_alu_pkg_ALU_MOD:
									if (b_i == 64'd0) begin
										err_o <= mpy_alu_pkg_AE_ZERO_DIV;
										st <= 3'd7;
									end
									else
										st <= 3'd2;
								mpy_alu_pkg_ALU_POW: st <= 3'd3;
								mpy_alu_pkg_ALU_MATMUL: begin
									err_o <= mpy_alu_pkg_AE_UNSUPPORTED;
									st <= 3'd7;
								end
								default: st <= 3'd7;
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
						if (fexc) begin
							res_o <= {32'd0, fa[31] && mpy_alu_pkg_mpy_f32_odd(fb), 31'h7f800000};
							st <= 3'd0;
							done_o <= 1'b1;
						end
						else begin
							fres_r <= fres[63:0];
							st <= 3'd5;
						end
					end
				3'd6: begin
					fa64_r <= fa64;
					fb64_r <= fb64;
					if (op <= mpy_alu_pkg_ALU_NE) begin
						rkind_o <= mpy_alu_pkg_AK_BOOL;
						res_o <= {63'd0, f_cmp};
						st <= 3'd7;
					end
					else begin
						err_o <= f_err;
						st <= (f_fpu ? 3'd4 : 3'd7);
					end
				end
				3'd5: begin
					res_o <= {32'd0, fnarrow};
					st <= 3'd0;
					done_o <= 1'b1;
				end
				3'd7: begin
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
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @(*) begin : sv2v_autoblock_2
		reg [32:0] t;
		if (_sv2v_0)
			;
		r_nx = r_r;
		q_nx = q_r;
		begin : sv2v_autoblock_3
			reg signed [31:0] j;
			for (j = 0; j < BPC; j = j + 1)
				begin
					t = {r_nx, q_nx[31]};
					q_nx = {q_nx[30:0], 1'b0};
					r_nx = (t >= {1'b0, d_r} ? sv2v_cast_32(t - {1'b0, d_r}) : t[31:0]);
				end
		end
	end
	assign busy_o = n_r != 6'd0;
	function automatic [63:0] sv2v_cast_64;
		input reg [63:0] inp;
		sv2v_cast_64 = inp;
	endfunction
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			d_r <= 1'sb0;
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
	m_ack_i,
	m_rdata_i,
	m_rtag_i,
	m_fault_i,
	m_fault_reason_i,
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
	ca_valid_o,
	ca_ready_i,
	ca_dst_o,
	ca_src_o,
	ca_n_o,
	ca_idle_i,
	ca_fault_i,
	ca_fault_reason_i,
	ca_fault_addr_i,
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
	input wire m_ack_i;
	input wire [31:0] m_rdata_i;
	input wire [3:0] m_rtag_i;
	input wire m_fault_i;
	input wire [3:0] m_fault_reason_i;
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
	output wire ca_valid_o;
	input wire ca_ready_i;
	output wire [31:0] ca_dst_o;
	output wire [31:0] ca_src_o;
	output wire [31:0] ca_n_o;
	input wire ca_idle_i;
	input wire ca_fault_i;
	input wire [3:0] ca_fault_reason_i;
	input wire [31:0] ca_fault_addr_i;
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
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < 34; i = i + 1)
					ge[i] = t[(33 - i) * 32+:32] >= x;
			end
			first = ge & ~{ge[32:0], 1'b0};
			r = (ge[33] ? 32'd0 : (x + (x >> 1)) | 32'd1);
			begin : sv2v_autoblock_2
				reg signed [31:0] i;
				for (i = 0; i < 34; i = i + 1)
					if (first[i])
						r = r | t[(33 - i) * 32+:32];
			end
			next_alloc = r;
		end
	endfunction
	localparam [7:0] ABI_MSGT_ASSERT = 8'd41;
	localparam [7:0] ABI_MSGT_BYTES_INDEX = 8'd47;
	localparam [7:0] ABI_MSGT_DIV_ZERO = 8'd62;
	localparam [7:0] ABI_MSGT_EMPTY = 8'd39;
	localparam [7:0] ABI_MSGT_GEN_IGNORED = 8'd56;
	localparam [7:0] ABI_MSGT_GEN_RUNNING = 8'd61;
	localparam [7:0] ABI_MSGT_GEN_SEND = 8'd60;
	localparam [7:0] ABI_MSGT_GEN_STOP = 8'd56;
	localparam [7:0] ABI_MSGT_HEAP_LOCKED = 8'd51;
	localparam [7:0] ABI_MSGT_KBD = 8'd49;
	localparam [7:0] ABI_MSGT_LIST_INDEX = 8'd47;
	localparam [7:0] ABI_MSGT_LOCAL_UNBOUND = 8'd52;
	localparam [7:0] ABI_MSGT_MEMORY = 8'd51;
	localparam [7:0] ABI_MSGT_NEG_SHIFT = 8'd61;
	localparam [7:0] ABI_MSGT_NO_ACTIVE_EXC = 8'd56;
	localparam [7:0] ABI_MSGT_OVERFLOW = 8'd55;
	localparam [7:0] ABI_MSGT_POP_EMPTY = 8'd47;
	localparam [7:0] ABI_MSGT_RANGE_INDEX = 8'd47;
	localparam [7:0] ABI_MSGT_RECURSION = 8'd56;
	localparam [7:0] ABI_MSGT_SCHED_FULL = 8'd56;
	localparam [7:0] ABI_MSGT_STOP_ITER = 8'd57;
	localparam [7:0] ABI_MSGT_STR_INDEX = 8'd47;
	localparam [7:0] ABI_MSGT_TUPLE_INDEX = 8'd47;
	localparam [7:0] ABI_MSGT_ZERO_STEP = 8'd61;
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
	reg [3:0] m_be;
	reg [3:0] m_wtag;
	reg [31:0] m_addr;
	reg [31:0] m_wdata;
	reg [31:0] md;
	reg [3:0] mt;
	wire [35:0] mv;
	assign mv = {mt, md};
	reg [31:0] h_qdesc;
	reg [31:0] h_builtins;
	reg [31:0] h_hooks;
	reg [31:0] h_msgs;
	reg [31:0] h_chars;
	reg [31:0] h_empty;
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
	reg [31:0] fbase;
	reg [31:0] fprev;
	reg [31:0] rc;
	reg [31:0] pc;
	reg [31:0] op_pc;
	reg [31:0] qbase;
	reg [31:0] cbase;
	reg [6:0] sp;
	reg [7:0] nloc;
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
	reg [35:0] rf_pend_v;
	reg [9:0] rf_resume;
	reg [31:0] spill_addr;
	reg [5:0] spill_n;
	reg [5:0] spill_ntag;
	reg [31:0] spill_words;
	reg spill_had_link;
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
	reg [7:0] lc_ix [0:7];
	reg [35:0] lc_d [0:7];
	wire [3:0] cfg_lc_n;
	wire cfg_lc_wb;
	wire cfg_lc_dm;
	wire cfg_ca;
	wire cfg_aalu;
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
		begin : sv2v_autoblock_3
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
	reg [7:0] srd_hops;
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
	reg trace;
	reg [95:0] fwin;
	reg [31:0] fw_base;
	reg fw_ok;
	reg [1:0] fw_i;
	reg [31:0] x0;
	reg [31:0] x1;
	reg [31:0] x2;
	reg [31:0] x3;
	reg [31:0] x4;
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
	reg [35:0] at_v;
	reg [35:0] tr_v;
	reg tr_r;
	reg tr_x;
	reg tb_src;
	reg tb_nz;
	reg [7:0] tb_from;
	reg [7:0] tb_n;
	reg [7:0] tb_i;
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
	wire in_win;
	assign f_off = pc - fw_base;
	assign in_win = (fw_ok && (pc >= fw_base)) && (f_off < 32'd12);
	function automatic [63:0] sv2v_cast_64;
		input reg [63:0] inp;
		sv2v_cast_64 = inp;
	endfunction
	assign d_bytes = sv2v_cast_64(fwin >> {f_off[3:0], 3'b000});
	function automatic [3:0] sv2v_cast_4;
		input reg [3:0] inp;
		sv2v_cast_4 = inp;
	endfunction
	assign d_n = (f_off[3:0] > 4'd4 ? sv2v_cast_4(4'd12 - f_off[3:0]) : 4'd8);
	mpy_decode u_dec(
		.instr_valid_i(1'b1),
		.bytes_i(d_bytes),
		.nbytes_i(d_n),
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
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	assign ftop = fbase + (((32'd17 + sv2v_cast_32(nloc)) + (32'd3 * {27'd0, nexc})) << 2);
	function automatic [31:0] loc_ptr;
		input reg [7:0] idx;
		loc_ptr = (fbase + 32'h00000044) + {22'd0, idx, 2'b00};
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
	function automatic lc_is_hit;
		input reg [7:0] idx;
		begin
			lc_is_hit = 1'b0;
			begin : sv2v_autoblock_4
				reg signed [31:0] k;
				for (k = 0; k < 8; k = k + 1)
					if (((k < cfg_lc_n) && lc_v[k]) && (lc_ix[k] == idx))
						lc_is_hit = 1'b1;
			end
		end
	endfunction
	function automatic [2:0] lc_hit_way;
		input reg [7:0] idx;
		begin
			lc_hit_way = 3'd0;
			begin : sv2v_autoblock_5
				reg signed [31:0] k;
				for (k = 0; k < 8; k = k + 1)
					if (((k < cfg_lc_n) && lc_v[k]) && (lc_ix[k] == idx))
						lc_hit_way = k[2:0];
			end
		end
	endfunction
	function automatic [2:0] lc_pick;
		input reg [7:0] idx;
		reg [2:0] best;
		reg any_inv;
		begin
			best = 3'd0;
			any_inv = 1'b0;
			if (cfg_lc_dm && (cfg_lc_n != 4'd0))
				lc_pick = idx[2:0] & (cfg_lc_n[2:0] - 3'd1);
			else begin
				begin : sv2v_autoblock_6
					reg signed [31:0] k;
					for (k = 0; k < 8; k = k + 1)
						if (((k < cfg_lc_n) && !lc_v[k]) && !any_inv) begin
							best = k[2:0];
							any_inv = 1'b1;
						end
				end
				if (!any_inv) begin : sv2v_autoblock_7
					reg signed [31:0] k;
					for (k = 1; k < 8; k = k + 1)
						if ((k < cfg_lc_n) && (lc_age[k] < lc_age[best]))
							best = k[2:0];
				end
				lc_pick = best;
			end
		end
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
	localparam [7:0] ABI_SR_FW7 = 8'd27;
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
			m_req <= 1'b1;
			if (a == (ABI_SYSROOT_BASE + (4 * ABI_SR_FW7)))
				bov <= v;
			wret <= nxt;
			st <= 10'd2;
		end
	endtask
	task automatic lc_fill;
		input reg [7:0] idx;
		input reg [35:0] v;
		input reg dirty;
		input reg set_st;
		input reg [9:0] done;
		reg [2:0] w;
		reg hit;
		begin
			hit = lc_is_hit(idx);
			w = (hit ? lc_hit_way(idx) : lc_pick(idx));
			if (cfg_lc_n == 4'd0) begin
				if (set_st)
					st <= done;
			end
			else if ((((hit || !lc_v[w]) || !lc_dirty[w]) || !cfg_lc_wb) || (lc_ix[w] == idx)) begin
				lc_v[w] <= 1'b1;
				lc_ix[w] <= idx;
				lc_d[w] <= v;
				lc_dirty[w] <= dirty && cfg_lc_wb;
				lc_note(w);
				if (set_st)
					st <= done;
			end
			else begin
				lc_ev_way <= w;
				lc_ev_idx <= idx;
				lc_ev_val <= v;
				lc_ev_dirty <= dirty && cfg_lc_wb;
				wr(loc_ptr(lc_ix[w]), lc_d[w], 10'd469);
			end
		end
	endtask
	assign cfg_grow = GROW_CHUNK[5:0];
	assign cfg_adapt = GROW_ADAPT != 0;
	assign cfg_lc_n = LC_N[3:0];
	assign cfg_lc_wb = LC_WB != 0;
	assign cfg_lc_dm = 1'b0;
	assign cfg_ca = CA_EN != 0;
	assign cfg_aalu = AALU != 0;
	function automatic [35:0] hdr_word;
		input reg [31:0] i;
		case (i)
			4'd0: hdr_word = {4'd0, fprev};
			4'd1: hdr_word = {4'd0, rc};
			4'd2: hdr_word = {4'd0, pc};
			4'd3: hdr_word = {4'd0, op_pc};
			4'd4: hdr_word = {4'd0, fflags, 1'b0, nloc[6:0], 3'b000, xsp, 1'b0, sp};
			4'd5: hdr_word = {15'h0000, nexc, fcont, 4'd0, frk};
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
			32'd16: hdr_word = {6'h00, spilled_reals, nloc, rf_base};
			default: hdr_word = VNULL;
		endcase
	endfunction
	wire has_link;
	wire [15:0] resident_reals;
	wire [15:0] stk_depth;
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
	assign has_link = (sp != 7'd0) && mpy_is_rf_link(rf[rf_base[3:0] + 4'd0]);
	function automatic [15:0] sv2v_cast_16;
		input reg [15:0] inp;
		sv2v_cast_16 = inp;
	endfunction
	assign resident_reals = (has_link ? sv2v_cast_16(sp) - 16'd1 : sv2v_cast_16(sp));
	assign stk_depth = spilled_reals + resident_reals;
	function automatic stk_hit;
		input reg [15:0] g;
		stk_hit = (g >= spilled_reals) && (g < stk_depth);
	endfunction
	function automatic [6:0] sv2v_cast_7;
		input reg [6:0] inp;
		sv2v_cast_7 = inp;
	endfunction
	function automatic [6:0] stk_slot;
		input reg [15:0] g;
		stk_slot = sv2v_cast_7(g - spilled_reals) + (has_link ? 7'd1 : 7'd0);
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
	assign gc_alloc_nbytes_o = al_n << 2;
	localparam [31:0] ABI_FRAME_BASE = 32'h20000000;
	assign gc_root0_lo_o = ABI_FRAME_BASE;
	assign gc_root0_hi_o = (noframe ? ABI_FRAME_BASE : ftop + {23'd0, sp, 2'b00});
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
	assign ca_valid_o = ca_valid;
	assign ca_dst_o = ca_dst;
	assign ca_src_o = ca_src;
	assign ca_n_o = ca_n;
	assign ca_ok = ca_ready_i && !ca_valid;
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
			m_req <= 1'b1;
			wret <= nxt;
			st <= 10'd2;
		end
	endtask
	localparam [31:0] MPY_CORE_SCRATCH_BYTES = 32'd512;
	localparam [31:0] MPY_SRAM_BASE = 32'h20000000;
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
			st <= 10'd622;
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
			scr_ret <= back;
			st <= 10'd622;
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
			st <= 10'd622;
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
	task automatic raise_msg;
		input reg [7:0] id;
		begin
			rm_id <= id;
			rsp <= 5'd0;
			st <= 10'd377;
		end
	endtask
	task automatic raise_val;
		input reg [35:0] v;
		begin
			xc <= v;
			rx_from <= 1'b0;
			rsp <= 5'd0;
			st <= 10'd358;
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
			st <= 10'd507;
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
			st <= 10'd507;
		end
	endtask
	task automatic deliver;
		input reg [35:0] v;
		input reg [3:0] rk;
		begin
			t[7] <= v;
			d_rk <= rk;
			st <= 10'd105;
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
			gosub(10'd460, back);
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
			gosub_scr(SCR_LK, 10'd249, back);
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
			ca_valid <= 1'b1;
			ca_dst <= dst;
			ca_src <= src;
			ca_n <= n;
		end
	endtask
	localparam [7:0] ABI_BINOP_EQUAL = 8'd2;
	localparam [7:0] ABI_BINOP_EXCEPTION_MATCH = 8'd8;
	localparam [7:0] ABI_BINOP_IN = 8'd6;
	localparam [7:0] ABI_BINOP_INPLACE_OR = 8'd9;
	localparam [7:0] ABI_BINOP_IS = 8'd7;
	localparam [7:0] ABI_BINOP_NOT_EQUAL = 8'd5;
	localparam [7:0] ABI_BINOP_OR = 8'd22;
	localparam [7:0] ABI_BINOP_POWER = 8'd34;
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
	localparam [3:0] ABI_HALT_BUS = 4'd6;
	localparam [3:0] ABI_HALT_CLEAN = 4'd0;
	localparam [3:0] ABI_HALT_FLASH_STORE = 4'd4;
	localparam [3:0] ABI_HALT_INTERNAL = 4'd9;
	localparam [3:0] ABI_HALT_SYSEXIT = 4'd10;
	localparam [3:0] ABI_HALT_UNALIGNED = 4'd5;
	localparam [3:0] ABI_HALT_UNCAUGHT = 4'd1;
	localparam [31:0] ABI_HDR_BUILTINS = 32'd6;
	localparam [31:0] ABI_HDR_CHARS = 32'd11;
	localparam [31:0] ABI_HDR_EMPTY_TUPLE = 32'd12;
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
	localparam [1:0] ABI_MUT_BYTEARRAY = 2'd3;
	localparam [1:0] ABI_MUT_DICT = 2'd1;
	localparam [1:0] ABI_MUT_LIST = 2'd0;
	localparam [1:0] ABI_MUT_SET = 2'd2;
	localparam [7:0] ABI_N_ALLOC = 8'd14;
	localparam [7:0] ABI_N_BASEEXCEPTION_INIT = 8'd37;
	localparam [7:0] ABI_N_BCMP = 8'd28;
	localparam [7:0] ABI_N_BCOPY = 8'd18;
	localparam [7:0] ABI_N_CALLNS = 8'd16;
	localparam [7:0] ABI_N_DATA = 8'd30;
	localparam [7:0] ABI_N_FGET = 8'd32;
	localparam [7:0] ABI_N_FLOC = 8'd33;
	localparam [7:0] ABI_N_FTOI = 8'd25;
	localparam [7:0] ABI_N_GC = 8'd23;
	localparam [7:0] ABI_N_GCINFO = 8'd24;
	localparam [7:0] ABI_N_GRESUME = 8'd27;
	localparam [7:0] ABI_N_HALT = 8'd5;
	localparam [7:0] ABI_N_HASH = 8'd29;
	localparam [7:0] ABI_N_ID = 8'd2;
	localparam [7:0] ABI_N_INEXT = 8'd26;
	localparam [7:0] ABI_N_ISINSTANCE = 8'd1;
	localparam [7:0] ABI_N_LD = 8'd9;
	localparam [7:0] ABI_N_LEN = 8'd0;
	localparam [7:0] ABI_N_LIST_APPEND = 8'd35;
	localparam [7:0] ABI_N_LOOKUP = 8'd21;
	localparam [7:0] ABI_N_MK = 8'd8;
	localparam [7:0] ABI_N_NEW_OBJECT = 8'd39;
	localparam [7:0] ABI_N_NEW_RANGE = 8'd38;
	localparam [7:0] ABI_N_OBJECT_INIT = 8'd36;
	localparam [7:0] ABI_N_PAY = 8'd7;
	localparam [7:0] ABI_N_PEEK32 = 8'd13;
	localparam [7:0] ABI_N_PEEK8 = 8'd11;
	localparam [7:0] ABI_N_POKE8 = 8'd12;
	localparam [7:0] ABI_N_QXSET = 8'd34;
	localparam [7:0] ABI_N_SLEN = 8'd31;
	localparam [7:0] ABI_N_ST = 8'd10;
	localparam [7:0] ABI_N_STRFIN = 8'd20;
	localparam [7:0] ABI_N_STRNEW = 8'd19;
	localparam [7:0] ABI_N_TAG = 8'd6;
	localparam [7:0] ABI_N_TICKS = 8'd22;
	localparam [7:0] ABI_N_TYPEOF = 8'd15;
	localparam [7:0] ABI_N_WCOPY = 8'd17;
	localparam [7:0] ABI_N_WE = 8'd4;
	localparam [7:0] ABI_N_WR = 8'd3;
	localparam [31:0] ABI_OB_BOUND_METHOD = 32'd7;
	localparam [31:0] ABI_OB_BUILTIN = 32'd8;
	localparam [31:0] ABI_OB_CELL = 32'd4;
	localparam [31:0] ABI_OB_CLASSMETHOD = 32'd13;
	localparam [31:0] ABI_OB_DICT_VIEW = 32'd15;
	localparam [31:0] ABI_OB_EXCEPTION = 32'd3;
	localparam [31:0] ABI_OB_FUNCTION = 32'd5;
	localparam [31:0] ABI_OB_GENERATOR = 32'd6;
	localparam [31:0] ABI_OB_INSTANCE = 32'd1;
	localparam [31:0] ABI_OB_MODULE = 32'd9;
	localparam [31:0] ABI_OB_PROPERTY = 32'd11;
	localparam [31:0] ABI_OB_SLICE = 32'd14;
	localparam [31:0] ABI_OB_STATICMETHOD = 32'd12;
	localparam [31:0] ABI_OB_TYPE = 32'd2;
	localparam [1:0] ABI_OVR_FALSE = 2'd3;
	localparam [1:0] ABI_OVR_NONE = 2'd0;
	localparam [1:0] ABI_OVR_PYOBJ = 2'd1;
	localparam [1:0] ABI_OVR_TRUE = 2'd2;
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
	localparam [7:0] ABI_SR_T0 = 8'd1;
	localparam [7:0] ABI_SR_T1 = 8'd2;
	localparam [7:0] ABI_SR_T2 = 8'd3;
	localparam [7:0] ABI_SR_T3 = 8'd4;
	localparam [7:0] ABI_SR_T4 = 8'd8;
	localparam [7:0] ABI_SR_T5 = 8'd9;
	localparam [7:0] ABI_SR_T6 = 8'd10;
	localparam [7:0] ABI_SR_T7 = 8'd11;
	localparam [31:0] ABI_STR_NONASCII = 32'h40000000;
	localparam [3:0] ABI_TAG_BYTES = 4'd13;
	localparam [3:0] ABI_TAG_COMPLEX = 4'd4;
	localparam [3:0] ABI_TAG_CONT = 4'd15;
	localparam [3:0] ABI_TAG_ITER = 4'd12;
	localparam [3:0] ABI_TAG_RANGE = 4'd11;
	localparam [3:0] ABI_TAG_TUPLE = 4'd9;
	localparam [31:0] ABI_TF_DESC = 32'd128;
	localparam [31:0] ABI_TF_EXC = 32'd2;
	localparam [31:0] ABI_TF_INST = 32'd1;
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
	localparam [7:0] ABI_T_GENERATOREXIT = 8'd44;
	localparam [7:0] ABI_T_INT = 8'd5;
	localparam [7:0] ABI_T_ITERATOR = 8'd18;
	localparam [7:0] ABI_T_LIST = 8'd12;
	localparam [7:0] ABI_T_MEMORYERROR = 8'd51;
	localparam [7:0] ABI_T_NONETYPE = 8'd3;
	localparam [7:0] ABI_T_OBJECT = 8'd1;
	localparam [7:0] ABI_T_RANGE = 8'd16;
	localparam [7:0] ABI_T_SET = 8'd14;
	localparam [7:0] ABI_T_SLICE = 8'd17;
	localparam [7:0] ABI_T_STOPITERATION = 8'd57;
	localparam [7:0] ABI_T_STR = 8'd8;
	localparam [7:0] ABI_T_TUPLE = 8'd11;
	localparam [7:0] ABI_UNOP_INVERT = 8'd2;
	localparam [7:0] ABI_UNOP_NEGATIVE = 8'd1;
	localparam [7:0] ABI_UNOP_NOT = 8'd3;
	localparam [7:0] ABI_UNOP_POSITIVE = 8'd0;
	localparam [3:0] MPY_FAULT_FLASH_STORE = 4'd2;
	localparam [3:0] MPY_FAULT_UNALIGNED = 4'd1;
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
	localparam [5:0] mpy_alu_pkg_ALU_F2I = 6'd45;
	localparam [5:0] mpy_alu_pkg_ALU_INVERT = 6'd42;
	localparam [5:0] mpy_alu_pkg_ALU_NEG = 6'd40;
	localparam [5:0] mpy_alu_pkg_ALU_POS = 6'd41;
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
	function automatic [5:0] sv2v_cast_6;
		input reg [5:0] inp;
		sv2v_cast_6 = inp;
	endfunction
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
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
			gc_alloc_req <= 1'b0;
			gc_collect_req <= 1'b0;
			alu_start <= 1'b0;
			hm_start <= 1'b0;
			aalu_pend <= 1'b0;
			aalu_ready <= 1'b0;
			aalu_slot <= 4'd0;
			aalu_ret <= 10'd118;
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
			fw_ok <= 1'b0;
			fw_base <= 32'd0;
			h_nq <= 32'd0;
			h_qext <= 32'd0;
			h_qextn <= 32'd0;
			qd_nxt <= 10'd0;
			sp <= 7'd0;
			nloc <= 8'd0;
			rf_base <= 6'd0;
			spilled_reals <= 16'd0;
			spill_hp <= MPY_CORE_SCRATCH_BASE;
			rf_pend <= 1'b0;
			scr_id <= SCR_NONE;
			scr_i <= 4'd0;
			scr_storing <= 1'b0;
			scr_gosub_p <= 1'b0;
			begin : sv2v_autoblock_8
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
			gen <= VNULL;
			inj <= VNONE;
			fl_img <= 1'b0;
			spill_to_img <= 1'b0;
			lc_fl_ret <= 10'd423;
			begin : sv2v_autoblock_9
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
			begin : sv2v_autoblock_10
				reg signed [31:0] k;
				for (k = 0; k < 4; k = k + 1)
					ab_s[k] <= VNULL;
			end
			begin : sv2v_autoblock_11
				reg signed [31:0] k;
				for (k = 0; k < MPY_RF_DEPTH; k = k + 1)
					rf[k] <= VNULL;
			end
			begin : sv2v_autoblock_12
				reg signed [31:0] k;
				for (k = 0; k < 8; k = k + 1)
					begin
						lc_v[k] <= 1'b0;
						lc_dirty[k] <= 1'b0;
						lc_age[k] <= 3'd0;
					end
			end
			lc_fi <= 4'd0;
		end
		else begin
			m_req <= 1'b0;
			gc_alloc_req <= 1'b0;
			gc_collect_req <= 1'b0;
			alu_start <= 1'b0;
			hm_start <= 1'b0;
			ca_valid <= 1'b0;
			trace <= 1'b0;
			if (!halted)
				cyc <= cyc + 32'd1;
			if (sp_hold)
				sp_hold <= 1'b0;
			else if (sp < sp_d)
				rf_mono <= 1'b0;
			else if (sp > sp_d)
				rf_mono <= 1'b1;
			sp_d <= sp;
			if (aalu_pend && alu_done)
				aalu_ready <= 1'b1;
			if (((((((rf_pend && (st != 10'd2)) && (st != 10'd637)) && (st != 10'd478)) && (st != 10'd479)) && (st != 10'd480)) && (st != 10'd481)) && (st != 10'd482)) begin
				if (sp >= sv2v_cast_7_signed(MPY_RF_DEPTH)) begin
					rf_resume <= st;
					st <= 10'd478;
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
						if (m_ack_i) begin
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
					10'd622:
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
								wr(scr_addr(scr_cmd, scr_i), sV[scr_i[2:0]], 10'd622);
							else
								wr(scr_addr(scr_cmd, scr_i), {4'd0, sA[scr_i[2:0]]}, 10'd622);
							scr_i <= scr_i + 4'd1;
						end
						else
							rd(scr_addr(scr_cmd, scr_i), 10'd623);
					10'd623: begin
						if (scr_tag(scr_cmd, scr_i))
							sV[scr_i[2:0]] <= mv;
						else
							sA[scr_i[2:0]] <= md;
						scr_i <= scr_i + 4'd1;
						st <= 10'd622;
					end
					10'd0:
						rd(32'd0, 10'd37);
					10'd37:
						if (md != ABI_IMAGE_MAGIC)
							halt(ABI_HALT_BAD_IMAGE, md);
						else
							rd(16, 10'd45);
					10'd45: begin
						h_qdesc <= md;
						h_qext <= 32'd0;
						h_qextn <= 32'd0;
						rd(12, 10'd46);
					end
					10'd46: begin
						h_nq <= md;
						rd(24, 10'd47);
					end
					10'd47: begin
						h_builtins <= md;
						rd(36, 10'd48);
					end
					10'd48: begin
						h_hooks <= md;
						rd(40, 10'd49);
					end
					10'd49: begin
						h_msgs <= md;
						rd(44, 10'd50);
					end
					10'd50: begin
						h_chars <= md;
						rd(48, 10'd51);
					end
					10'd51: begin
						h_empty <= md;
						rd(TT + (4 * ABI_T_FUNCTION), 10'd52);
					end
					10'd52: begin
						ty_fun <= mv;
						rd(TT + (4 * ABI_T_BOUND_METHOD), 10'd53);
					end
					10'd53: begin
						ty_bm <= mv;
						rd(TT + (4 * ABI_T_CELL), 10'd38);
					end
					10'd38: begin
						ty_cell <= mv;
						rd(TT + (4 * ABI_T_OBJECT), 10'd39);
					end
					10'd39: begin
						ty_obj <= mv;
						rd(TT + (4 * ABI_T_STOPITERATION), 10'd40);
					end
					10'd40: begin
						ty_stop <= mv;
						rd(TT + (4 * ABI_T_MEMORYERROR), 10'd41);
					end
					10'd41: begin
						ty_mem <= mv;
						rd(TT + (4 * ABI_T_SLICE), 10'd42);
					end
					10'd42: begin
						ty_slice <= mv;
						rd(h_msgs + (4 * ABI_MSG_MEMORY), 10'd43);
					end
					10'd43: begin
						wb_v[0] <= vint(ABI_OB_EXCEPTION);
						wb_v[1] <= ty_mem;
						wb_v[2] <= mv;
						wb_v[3] <= VNULL;
						wb_v[4] <= VNULL;
						wblock(EMERG_ADDR, 4'd5, 10'd44);
					end
					10'd44: begin
						ab_lo <= 8'd32;
						ab_pe <= 8'd32;
						ab_nkw <= 8'd0;
						crk <= ABI_RK_HALT;
						hk_id <= ABI_HOOK_BOOT;
						st <= 10'd203;
					end
					10'd507: begin
						wr(ab_ptr(8'd32 + i0), ab_s[i0[1:0]], (i0 == 8'd3 ? 10'd203 : 10'd507));
						i0 <= i0 + 8'd1;
					end
					10'd203:
						rd(h_hooks + (4 * hk_id), 10'd204);
					10'd204:
						if (mv == VNULL)
							halt(ABI_HALT_INTERNAL, {24'd0, hk_id});
						else
							wr(ab_ptr(8'd0), mv, 10'd60);
					10'd60:
						rd(ab_ptr(8'd0), 10'd508);
					10'd508: begin
						ab_q <= mv;
						if (tg(mv) != ABI_TAG_OBJECT)
							st <= 10'd202;
						else
							rd(adr(mv), 10'd63);
					end
					10'd63:
						case (md)
							ABI_OB_FUNCTION: begin
								c_ismod <= 1'b0;
								st <= 10'd75;
							end
							ABI_OB_BOUND_METHOD:
								rd(adr(ab_q) + 12, 10'd62);
							ABI_OB_BUILTIN:
								rd(adr(ab_q) + 8, 10'd65);
							ABI_OB_TYPE:
								rd(adr(ab_q) + 28, 10'd66);
							default: st <= 10'd202;
						endcase
					10'd62:
						if (ab_chunked)
							st <= 10'd566;
						else if (ab_lo <= 8'd2)
							raise_err(ABI_ERR_STAR_ARGS, VNULL, VNULL);
						else begin
							wr(ab_ptr(ab_lo - 8'd1), mv, 10'd509);
							ab_lo <= ab_lo - 8'd1;
						end
					10'd509:
						rd(adr(ab_q) + 8, 10'd61);
					10'd61:
						wr(ab_ptr(8'd0), mv, 10'd60);
					10'd65: begin
						nid <= md[7:0];
						st <= 10'd290;
					end
					10'd66: begin
						c_tflags <= md;
						if (md & ABI_TF_INST)
							st <= 10'd294;
						else
							rd(adr(ab_q) + 32, 10'd64);
					end
					10'd64:
						if (mv == VNULL)
							raise_err(ABI_ERR_CANT_CREATE, ab_q, VNULL);
						else if (ab_lo <= 8'd2)
							raise_err(ABI_ERR_STAR_ARGS, VNULL, VNULL);
						else begin
							ab_s[0] <= mv;
							wr(ab_ptr(ab_lo - 8'd1), ab_q, 10'd510);
							ab_lo <= ab_lo - 8'd1;
						end
					10'd510:
						wr(ab_ptr(8'd0), ab_s[0], 10'd60);
					10'd202: begin
						tb_src <= 1'b0;
						tb_nz <= 1'b0;
						tb_from <= ab_lo;
						tb_n <= ab_pe - ab_lo;
						gosub(10'd442, 10'd200);
					end
					10'd200: begin
						t[0] <= tb_v;
						tb_src <= 1'b0;
						tb_nz <= 1'b1;
						tb_from <= ab_pe;
						tb_n <= {ab_nkw[6:0], 1'b0};
						gosub(10'd442, 10'd201);
					end
					10'd201:
						hook(ABI_HOOK_CALL, crk, 8'd3, ab_q, t[0], tb_v, VNULL);
					10'd294:
						if (c_tflags & ABI_TF_EXC) begin
							tb_src <= 1'b0;
							tb_nz <= 1'b0;
							tb_from <= ab_lo;
							tb_n <= ab_pe - ab_lo;
							gosub(10'd442, 10'd298);
						end
						else
							alloc(32'd3, 10'd295);
					10'd298: begin
						t[0] <= tb_v;
						alloc(32'd5, 10'd299);
					end
					10'd299: begin
						wb_v[0] <= vint(ABI_OB_EXCEPTION);
						wb_v[1] <= ab_q;
						wb_v[2] <= t[0];
						wb_v[3] <= VNULL;
						wb_v[4] <= VNULL;
						t[1] <= vobj(al_a);
						wblock(al_a, 4'd5, 10'd296);
					end
					10'd295: begin
						wb_v[0] <= vint(ABI_OB_INSTANCE);
						wb_v[1] <= ab_q;
						wb_v[2] <= VNULL;
						t[1] <= vobj(al_a);
						wblock(al_a, 4'd3, 10'd296);
					end
					10'd296:
						if (scr_id != SCR_AT)
							scr_ensure(SCR_AT, 10'd296);
						else begin
							sV[6] <= ab_q;
							at_ty <= 1'b1;
							at_objd <= 1'b0;
							at_q <= ABI_Q_INIT_D;
							gosub(10'd20, 10'd297);
						end
					10'd297:
						if (at_kind == 2'd1) begin
							wr(ab_ptr(ab_lo - 8'd1), t[1], 10'd511);
							ab_lo <= ab_lo - 8'd1;
							aux <= t[1];
							aux2 <= vint({28'd0, crk});
							aux3 <= vint({24'd0, fcont});
							fcont <= ABI_CONT_INIT;
							crk <= ABI_RK_CONT;
						end
						else
							deliver(t[1], crk);
					10'd511:
						wr(ab_ptr(8'd0), at_v, 10'd60);
					10'd75: begin
						ab_lo0 <= ab_lo;
						rd(adr(ab_q) + 8, 10'd76);
					end
					10'd76: begin
						c_rc <= md;
						rd(adr(ab_q) + 12, 10'd77);
					end
					10'd77: begin
						c_clos <= mv;
						rd(adr(ab_q) + 16, 10'd78);
					end
					10'd78: begin
						c_defs <= mv;
						rd(adr(ab_q) + 24, 10'd79);
					end
					10'd79: begin
						c_glob <= mv;
						if (c_clos != VNULL)
							rd(adr(c_clos), 10'd84);
						else
							st <= 10'd89;
					end
					10'd84: begin
						c_cn <= md[7:0];
						st <= 10'd83;
					end
					10'd83:
						if (c_cn == 8'd0)
							st <= 10'd89;
						else if (ab_lo <= 8'd2)
							raise_err(ABI_ERR_STAR_ARGS, VNULL, VNULL);
						else
							rd(adr(c_clos) + (4 * c_cn), 10'd85);
					10'd85: begin
						wr(ab_ptr(ab_lo - 8'd1), mv, 10'd83);
						ab_lo <= ab_lo - 8'd1;
						c_cn <= c_cn - 8'd1;
					end
					10'd89:
						rd(c_rc + 4, 10'd90);
					10'd90: begin
						c_nst <= md[7:0];
						c_nexc <= md[15:8];
						c_scope <= md[23:16];
						c_rcf <= md[31:24];
						rd(c_rc + 8, 10'd80);
					end
					10'd80: begin
						c_npos <= md[7:0];
						c_nkwo <= md[15:8];
						c_ndef <= md[23:16];
						c_ncell <= md[31:24];
						rd(c_rc + 16, 10'd82);
					end
					10'd82: begin
						c_cells <= md;
						v0 = (noframe ? ABI_FRAME_BASE : ftop + {23'd0, sp, 2'b00});
						v1 = v0 + (((32'd17 + c_nst) + (32'd3 * c_nexc)) << 2);
						v2 = ab_pe - ab_lo;
						c_fast <= (((!ab_chunked && (ab_nkw == 8'd0)) && (c_nkwo == 8'd0)) && ((v2 + c_ndef) >= c_npos)) && ((v2 <= c_npos) || (c_scope & ABI_SCOPE_VARARGS));
						x3 <= v0;
						if (v1 > spill_hp)
							raise_msg(ABI_MSG_RECURSION);
						else if (noframe)
							st <= 10'd91;
						else
							gosub(10'd423, 10'd91);
					end
					10'd91: begin
						fprev <= (noframe ? 32'd0 : fbase);
						fbase <= x3;
						noframe <= 1'b0;
						rc <= c_rc;
						nloc <= c_nst;
						nexc <= c_nexc[4:0];
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
						begin : sv2v_autoblock_13
							reg signed [31:0] k;
							for (k = 0; k < MPY_RF_DEPTH; k = k + 1)
								rf[k] <= VNULL;
						end
						lc_inval;
						st <= 10'd464;
					end
					10'd464:
						if (i0 == nloc)
							rd(c_rc + 0, 10'd87);
						else
							wr(loc_ptr(i0), VNULL, 10'd465);
					10'd465: begin
						i0 <= i0 + 8'd1;
						st <= 10'd464;
					end
					10'd87: begin
						pc <= md;
						op_pc <= md;
						rd(c_rc + 20, 10'd86);
					end
					10'd86: begin
						c_md <= md;
						rd(md + 0, 10'd88);
					end
					10'd88: begin
						qbase <= md;
						rd(c_md + 4, 10'd81);
					end
					10'd81: begin
						cbase <= md;
						if (c_fast)
							st <= 10'd25;
						else
							st <= 10'd54;
					end
					10'd25: begin
						i0 <= ab_pe - ab_lo;
						i1 <= 8'd0;
						st <= 10'd473;
					end
					10'd473:
						if ((i1 >= c_npos) || (i1 >= i0))
							st <= 10'd26;
						else
							rd(ab_ptr(ab_lo + i1), 10'd513);
					10'd513:
						wr(loc_ptr(i1), mv, 10'd474);
					10'd474: begin
						i1 <= i1 + 8'd1;
						st <= 10'd473;
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
							tb_n <= ((ab_pe - ab_lo) > c_npos ? (ab_pe - ab_lo) - c_npos : 8'd0);
							gosub(10'd442, 10'd31);
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
							st <= 10'd72;
					end
					10'd29: begin
						wb_v[0] <= vint(32'd0);
						wb_v[1] <= vint(32'd0);
						wb_v[2] <= VNULL;
						wb_v[3] <= vint(32'd0);
						i1 <= (c_npos + c_nkwo) + (c_scope & ABI_SCOPE_VARARGS ? 8'd1 : 8'd0);
						wblock(al_a, 4'd4, 10'd475);
					end
					10'd475:
						wr(loc_ptr(i1), vmut(al_a, ABI_MUT_DICT), 10'd72);
					10'd72:
						if (c_ci == c_ncell) begin
							fflags <= fflags & ~FF_NOTB;
							if (fflags & FF_GEN)
								st <= 10'd136;
							else
								st <= 10'd118;
						end
						else
							rd(c_cells + (4 * c_ci), 10'd74);
					10'd74: begin
						i1 <= md[7:0];
						rd(loc_ptr(md[7:0]), 10'd476);
					end
					10'd476: begin
						t[3] <= mv;
						alloc(32'd3, 10'd73);
					end
					10'd73: begin
						wb_v[0] <= vint(ABI_OB_CELL);
						wb_v[1] <= ty_cell;
						wb_v[2] <= t[3];
						c_ci <= c_ci + 32'd1;
						wblock(al_a, 4'd3, 10'd477);
					end
					10'd477:
						wr(loc_ptr(i1), vobj(al_a), 10'd72);
					10'd54:
						if (ab_chunked)
							st <= 10'd574;
						else
							rd(ab_ptr(8'd0), 10'd512);
					10'd512: begin
						fflags <= fflags | FF_NOTB;
						fcont <= ABI_CONT_BIND;
						t[2] <= mv;
						tb_src <= 1'b0;
						tb_nz <= 1'b0;
						tb_from <= ab_lo;
						tb_n <= ab_pe - ab_lo;
						gosub(10'd442, 10'd55);
					end
					10'd55: begin
						t[0] <= tb_v;
						tb_src <= 1'b0;
						tb_nz <= 1'b1;
						tb_from <= ab_pe;
						tb_n <= {ab_nkw[6:0], 1'b0};
						gosub(10'd442, 10'd56);
					end
					10'd56:
						hook(ABI_HOOK_BIND, ABI_RK_CONT, 8'd3, t[2], t[0], tb_v, VNULL);
					10'd92: begin
						c_rc <= md;
						c_defs <= VNULL;
						c_clos <= VNULL;
						st <= 10'd89;
					end
					10'd423:
						if (lc_dirty_any) begin
							lc_fi <= 4'd0;
							lc_fl_ret <= 10'd423;
							st <= 10'd470;
						end
						else begin
							sw_i <= 32'd0;
							sw_k <= 2'd0;
							gosub(10'd503, 10'd424);
						end
					10'd424:
						if (sw_i == 32'd17) begin
							sw_i <= 32'd0;
							sw_k <= 2'd0;
							st <= (spill_to_img ? 10'd425 : 10'd427);
						end
						else begin
							wr(fbase + (sw_i << 2), hdr_word(sw_i), 10'd424);
							sw_i <= sw_i + 32'd1;
						end
					10'd425:
						if (sw_i == nloc) begin
							sw_i <= 32'd0;
							sw_k <= 2'd0;
							st <= 10'd428;
						end
						else
							rd((x4 + 32'h00000044) + (sw_i << 2), 10'd426);
					10'd426: begin
						wr((fbase + 32'h00000044) + (sw_i << 2), mv, 10'd425);
						sw_i <= sw_i + 32'd1;
					end
					10'd428:
						if (sw_i == (sv2v_cast_32(xsp) * 32'd3)) begin
							sw_i <= 32'd0;
							st <= 10'd427;
						end
						else if (sw_k == 2'd0) begin
							rd(exc_words(x4) + (sw_i << 2), 10'd428);
							sw_k <= 2'd1;
						end
						else begin
							wr(exc_words(fbase) + (sw_i << 2), mv, 10'd428);
							sw_k <= 2'd0;
							sw_i <= sw_i + 32'd1;
						end
					10'd427:
						if (sw_i == sp)
							ret;
						else begin
							wr(ftop + (sw_i << 2), rf[rf_base[3:0] + sv2v_cast_4(sw_i[6:0])], 10'd427);
							sw_i <= sw_i + 32'd1;
						end
					10'd119: begin
						fl_i <= 32'd0;
						fw_ok <= 1'b0;
						lc_inval;
						if (!fl_img)
							fbase <= fl_base;
						rd(fl_base, 10'd127);
					end
					10'd127: begin
						case (fl_i)
							4'd0:
								if (!fl_img)
									fprev <= md;
							4'd1: rc <= md;
							4'd2: pc <= md;
							4'd3: op_pc <= md;
							4'd4: begin
								sp <= md[6:0];
								xsp <= md[12:8];
								fflags <= md[31:24];
							end
							4'd5: begin
								frk <= md[3:0];
								fcont <= md[15:8];
								nexc <= md[20:16];
							end
							4'd6: glb <= mv;
							4'd7: loc <= mv;
							4'd8: fun <= mv;
							4'd9: aux <= mv;
							4'd10: aux2 <= mv;
							4'd11: aux3 <= mv;
							4'd12: qbase <= md;
							4'd13: cbase <= md;
							4'd14: gen <= mv;
							4'd15: spill_hp <= md;
							default:
								if (fl_i == 32'd16) begin
									rf_base <= md[5:0];
									nloc <= md[13:6];
									spilled_reals <= md[29:14];
									exc_base <= (fl_base + 32'h00000044) + ({24'd0, md[13:6]} << 2);
									stack_base <= fl_base + (((32'd17 + {24'd0, md[13:6]}) + (32'd3 * {27'd0, nexc})) << 2);
								end
						endcase
						if (fl_i == 32'd16) begin
							fl_i <= 32'd0;
							fl_k <= 2'd0;
							if (fl_img)
								st <= 10'd497;
							else begin
								sw_k <= 2'd0;
								gosub(10'd504, 10'd499);
							end
						end
						else begin
							fl_i <= fl_i + 32'd1;
							rd(fl_base + ((fl_i + 32'd1) << 2), 10'd127);
						end
					end
					10'd497:
						if (fl_i == nloc) begin
							fl_i <= 32'd0;
							fl_k <= 2'd0;
							st <= 10'd130;
						end
						else
							rd((fl_base + 32'h00000044) + (fl_i << 2), 10'd498);
					10'd498: begin
						wr((fbase + 32'h00000044) + (fl_i << 2), mv, 10'd497);
						fl_i <= fl_i + 32'd1;
					end
					10'd130:
						if (fl_i == (sv2v_cast_32(xsp) * 32'd3)) begin
							fl_i <= 32'd0;
							fl_img <= 1'b0;
							sw_k <= 2'd0;
							gosub(10'd504, 10'd499);
						end
						else
							rd(exc_base + (fl_i << 2), 10'd129);
					10'd129: begin
						wr(exc_words(fbase) + (fl_i << 2), mv, 10'd130);
						fl_i <= fl_i + 32'd1;
					end
					10'd499:
						if (fl_i == sp)
							ret;
						else
							rd(stack_base + (fl_i << 2), 10'd500);
					10'd500: begin
						rf[rf_base[3:0] + sv2v_cast_4(fl_i[6:0])] <= mv;
						fl_i <= fl_i + 32'd1;
						st <= 10'd499;
					end
					10'd359:
						if (frk == ABI_RK_HALT)
							halt(ABI_HALT_CLEAN, 32'd0);
						else begin
							r_rk <= frk;
							fl_base <= fprev;
							gosub(10'd119, 10'd360);
						end
					10'd360: begin
						d_rk <= r_rk;
						st <= 10'd105;
					end
					10'd105:
						case (d_rk)
							ABI_RK_PUSH: begin
								push(t[7]);
								st <= 10'd118;
							end
							ABI_RK_DISCARD: st <= 10'd118;
							ABI_RK_PUSH_NULL: begin
								rf[rf_base[3:0] + sv2v_cast_4(sp)] <= t[7];
								rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd1))] <= VNULL;
								sp <= sp + 7'd2;
								st <= 10'd118;
							end
							ABI_RK_CONT: st <= 10'd93;
							default:
								halt(ABI_HALT_CLEAN, 32'd0);
						endcase
					10'd93:
						case (fcont)
							ABI_CONT_REDISPATCH: begin
								op <= aux[7:0];
								st <= 10'd110;
							end
							ABI_CONT_REPLACE: begin
								rf[rf_base[3:0] + sv2v_cast_4(aux[6:0])] <= t[7];
								pc <= op_pc;
								st <= 10'd118;
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
								gosub(10'd501, 10'd118);
							end
							ABI_CONT_WITH_NONE: begin
								push(VNONE);
								st <= 10'd118;
							end
							ABI_CONT_WITH_UNWIND: begin
								rf[rf_base[3:0] + sv2v_cast_4(sp)] <= aux;
								rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd1))] <= aux2;
								sp <= sp + 7'd2;
								st <= 10'd118;
							end
							ABI_CONT_WITH_EXC: begin
								tr_v <= t[7];
								gosub(10'd438, 10'd463);
							end
							ABI_CONT_UNPACK:
								rd(adr(t[7]), 10'd452);
							ABI_CONT_RAISE:
								raise_val(t[7]);
							ABI_CONT_TRUTH: begin
								ovr <= (t[7] == VTRUE ? ABI_OVR_TRUE : ABI_OVR_FALSE);
								pc <= op_pc;
								st <= 10'd118;
							end
							ABI_CONT_WITH_TRUTH: begin
								push((t[7] == VTRUE ? VNONE : aux));
								st <= 10'd118;
							end
							ABI_CONT_WITH_ATTR: begin
								t[0] <= aux3;
								jt <= aux[31:0];
								if (aux2 == vint(32'd0)) begin
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= t[7];
									rf[rf_base[3:0] + sv2v_cast_4(sp)] <= VNULL;
									sp <= sp + 7'd1;
									at_q <= ABI_Q_ENTER_D;
									gosub_scr(SCR_AT, 10'd9, 10'd436);
								end
								else begin
									at_v <= t[7];
									at_kind <= 2'd1;
									st <= 10'd436;
								end
							end
							ABI_CONT_FOR_NEXT:
								if (t[7] == VSTOP) begin
									sp <= sp - 7'd4;
									pc <= aux[31:0];
									st <= 10'd118;
								end
								else begin
									push(t[7]);
									st <= 10'd118;
								end
							ABI_CONT_GETITER: begin
								rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= t[7];
								ovr <= ABI_OVR_PYOBJ;
								pc <= op_pc;
								st <= 10'd118;
							end
							ABI_CONT_BIND:
								rd(adr(t[7]), 10'd70);
							ABI_CONT_YFROM:
								if (fflags & FF_YFAST) begin
									fflags <= fflags & ~FF_YFAST;
									push(t[7]);
									pc <= op_pc;
									st <= 10'd165;
								end
								else
									rd(adr(t[7]) + 4, 10'd168);
							ABI_CONT_SPILL_REPLACE:
								if (!has_link)
									halt(ABI_HALT_INTERNAL, 32'h0000c0c0);
								else begin
									srd_g <= aux[15:0];
									srd_addr <= mpy_rf_link_addr(rf[rf_base[3:0] + 4'd0]);
									srd_off <= (spilled_reals - 16'd1) - aux[15:0];
									srd_hops <= 8'd0;
									st <= 10'd526;
								end
							default:
								halt(ABI_HALT_INTERNAL, {24'd0, fcont});
						endcase
					10'd463:
						if (tr_x) begin
							fcont <= ABI_CONT_WITH_TRUTH;
							hook(ABI_HOOK_TRUTH, ABI_RK_CONT, 8'd1, tr_v, VNULL, VNULL, VNULL);
						end
						else begin
							push((tr_r ? VNONE : aux));
							st <= 10'd118;
						end
					10'd452: begin
						x1 <= md;
						st <= 10'd451;
					end
					10'd451:
						if (x1 == 32'd0)
							st <= 10'd118;
						else
							rd(adr(t[7]) + (x1 << 2), 10'd453);
					10'd453: begin
						x1 <= x1 - 32'd1;
						push(mv);
						st <= 10'd451;
					end
					10'd70: begin
						x1 <= md;
						i0 <= 8'd0;
						st <= 10'd69;
					end
					10'd69:
						if (i0 == x1[7:0])
							rd(rc + 8, 10'd67);
						else
							rd((adr(t[7]) + 4) + (4 * i0), 10'd71);
					10'd71: begin
						wr(loc_ptr(i0), mv, 10'd69);
						i0 <= i0 + 8'd1;
					end
					10'd67: begin
						c_ncell <= md[31:24];
						rd(rc + 16, 10'd68);
					end
					10'd68: begin
						c_cells <= md;
						c_ci <= 32'd0;
						fcont <= 8'd0;
						st <= 10'd72;
					end
					10'd377:
						if (aalu_pend) begin
							if (aalu_go) begin
								aalu_ret <= 10'd377;
								st <= 10'd637;
							end
						end
						else
							alloc(32'd5, 10'd378);
					10'd378:
						rd(h_msgs + (4 * rm_id), 10'd379);
					10'd379: begin
						t[0] <= mv;
						rd(TT + (4 * msg_type(rm_id)), 10'd380);
					end
					10'd380: begin
						wb_v[0] <= vint(ABI_OB_EXCEPTION);
						wb_v[1] <= mv;
						wb_v[2] <= t[0];
						wb_v[3] <= VNULL;
						wb_v[4] <= VNULL;
						xc <= vobj(al_a);
						wblock(al_a, 4'd5, 10'd381);
					end
					10'd381: begin
						rx_from <= 1'b0;
						rsp <= 5'd0;
						st <= 10'd358;
					end
					10'd358:
						if (aalu_pend) begin
							if (aalu_go) begin
								aalu_ret <= 10'd358;
								st <= 10'd637;
							end
						end
						else if (((rx_from && (rx_crk == ABI_RK_CONT)) && (fcont == ABI_CONT_FOR_NEXT)) || (!rx_from && (op == 8'h4b)))
							rd(adr(xc) + 4, 10'd387);
						else if ((rx_from && (rx_crk == ABI_RK_CONT)) && (fcont == ABI_CONT_YFROM))
							rd(adr(xc) + 4, 10'd176);
						else
							st <= 10'd389;
					10'd387: begin
						is_t <= mv;
						is_c <= ty_stop;
						gosub(10'd207, 10'd388);
					end
					10'd388:
						if (is_r) begin
							sp <= sp - 7'd4;
							pc <= aux[31:0];
							st <= 10'd118;
						end
						else
							st <= 10'd389;
					10'd389:
						if ((fflags & (FF_NOTB | FF_FW)) || (!rx_from && ((op == 8'h5d) || (op == 8'h64))))
							st <= 10'd385;
						else
							rd(rc + 0, 10'd390);
					10'd390: begin
						rx_off <= op_pc - md;
						rd(adr(xc) + 12, 10'd391);
					end
					10'd391:
						if (mv == VNULL) begin
							al_soft <= 1'b1;
							alloc(32'd7, 10'd396);
						end
						else begin
							t[2] <= mv;
							st <= 10'd392;
						end
					10'd396:
						if (!al_ok) begin
							al_soft <= 1'b0;
							st <= 10'd385;
						end
						else begin
							wb_v[0] <= vint(32'd0);
							wb_v[1] <= vint(32'd4);
							wb_v[2] <= {ABI_TAG_CONT, al_a + 32'd12};
							t[2] <= vmut(al_a, ABI_MUT_LIST);
							wblock(al_a, 4'd3, 10'd395);
						end
					10'd395:
						wr(adr(xc) + 12, t[2], 10'd392);
					10'd392: begin
						t[3] <= vint(rc);
						al_soft <= 1'b1;
						gosub_scr(SCR_LA, 10'd233, 10'd393);
					end
					10'd393: begin
						t[3] <= vint(rx_off);
						gosub_scr(SCR_LA, 10'd233, 10'd394);
					end
					10'd394: begin
						al_soft <= 1'b0;
						st <= 10'd385;
					end
					10'd385:
						if ((xsp != 5'd0) && (xh <= op_pc)) begin
							sw_k <= 2'd0;
							gosub(10'd502, 10'd385);
						end
						else if (xsp != 5'd0) begin
							pc <= xh;
							xp <= xc;
							drop_left <= (stk_depth > xv ? stk_depth - xv : 16'd0);
							drop_push_en <= 1'b1;
							drop_push_v <= xc;
							drop_then <= 10'd118;
							st <= 10'd494;
						end
						else if ((gen != VNULL) && (fprev != 32'd0)) begin
							pc <= 32'd0;
							st <= 10'd142;
						end
						else if (fprev == 32'd0)
							halt(ABI_HALT_UNCAUGHT, xc[31:0]);
						else begin
							rx_crk <= frk;
							fl_base <= fprev;
							gosub(10'd119, 10'd386);
						end
					10'd386: begin
						rx_from <= 1'b1;
						st <= 10'd358;
					end
					10'd118:
						if (ca_fault_i)
							case (ca_fault_reason_i)
								MPY_FAULT_UNALIGNED:
									halt(ABI_HALT_UNALIGNED, ca_fault_addr_i);
								MPY_FAULT_FLASH_STORE:
									halt(ABI_HALT_FLASH_STORE, ca_fault_addr_i);
								default:
									halt(ABI_HALT_BUS, ca_fault_addr_i);
							endcase
						else if (aalu_pend && ((sp >= sv2v_cast_7_signed(RF_SPILL_AT)) || (has_link && (sp <= sv2v_cast_7_signed(RF_RELOAD_AT))))) begin
							if (aalu_go) begin
								aalu_ret <= 10'd118;
								st <= 10'd637;
							end
						end
						else if (sp >= sv2v_cast_7_signed(RF_SPILL_AT)) begin
							rf_resume <= 10'd118;
							st <= 10'd478;
						end
						else if (has_link && (sp <= sv2v_cast_7_signed(RF_RELOAD_AT))) begin
							rf_resume <= 10'd118;
							st <= 10'd480;
						end
						else if (in_win)
							st <= 10'd103;
						else begin
							fw_base <= {pc[31:2], 2'b00};
							fw_i <= 2'd0;
							fw_ok <= 1'b0;
							rd({pc[31:2], 2'b00}, 10'd131);
						end
					10'd131: begin
						fwin[32 * fw_i+:32] <= md;
						if (fw_i == 2'd2) begin
							fw_ok <= 1'b1;
							st <= 10'd103;
						end
						else begin
							fw_i <= fw_i + 2'd1;
							rd(fw_base + (4 * (fw_i + 2'd1)), 10'd131);
						end
					end
					10'd103:
						if (d_trunc) begin
							if (fw_base == {pc[31:2], 2'b00})
								halt(ABI_HALT_BAD_OPCODE, pc);
							else begin
								fw_ok <= 1'b0;
								st <= 10'd118;
							end
						end
						else if (d_illegal || !d_valid)
							halt(ABI_HALT_BAD_OPCODE, pc);
						else begin
							op <= d_op;
							arg <= d_arg;
							ext <= d_ext;
							op_pc <= pc;
							pc <= pc + d_len;
							jt <= ((pc + d_len) - (d_extv ? 32'd1 : 32'd0)) + d_arg;
							nops <= nops + 32'd1;
							trace <= 1'b1;
							st <= 10'd110;
						end
					10'd110:
						if (aalu_pend && !aalu_pass(op)) begin
							if (aalu_go) begin
								aalu_ret <= 10'd110;
								st <= 10'd637;
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
									st <= 10'd118;
								end
							end
							else begin
								i0 <= vi;
								rd(loc_ptr(vi), 10'd468);
							end
						end
						else if (((op >= 8'hc0) && (op < 8'hd0)) || (op == 8'h26)) begin
							vi = (op == 8'h26 ? arg[7:0] : op - 8'hc0);
							if ((cfg_lc_n != 4'd0) && cfg_lc_wb) begin
								sp <= sp - 7'd1;
								lc_fill(vi, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], 1'b1, 1'b1, 10'd118);
							end
							else begin
								wr(loc_ptr(vi), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], 10'd118);
								sp <= sp - 7'd1;
								if (cfg_lc_n != 4'd0)
									lc_fill(vi, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], 1'b0, 1'b0, 10'd118);
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
									rd(adr(lc_d[vs0[2:0]]) + 8, 10'd106);
								else if (op == 8'h27) begin
									wr(adr(lc_d[vs0[2:0]]) + 8, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], 10'd118);
									sp <= sp - 7'd1;
								end
								else if (op == 8'h29)
									rd(adr(lc_d[vs0[2:0]]) + 8, 10'd104);
								else begin
									wr(loc_ptr(vi), VNULL, 10'd118);
									lc_v[vs0[2:0]] <= 1'b0;
									lc_dirty[vs0[2:0]] <= 1'b0;
								end
							end
							else begin
								i0 <= vi;
								if (op == 8'h25)
									rd(loc_ptr(vi), 10'd467);
								else if (op == 8'h27)
									rd(loc_ptr(vi), 10'd472);
								else if (op == 8'h29)
									rd(loc_ptr(vi), 10'd471);
								else
									rd(loc_ptr(vi), 10'd466);
							end
						end
						else if ((op >= 8'h70) && (op < 8'hb0)) begin
							push(vint(sv2v_cast_32(op) - 32'h00000080));
							st <= 10'd118;
						end
						else if ((op >= 8'hd0) && (op < 8'hd7)) begin
							n_o <= op - 8'hd0;
							st <= 10'd450;
						end
						else if ((op >= 8'hd7) && (op < 8'hfa)) begin
							n_o <= op - 8'hd7;
							st <= 10'd32;
						end
						else
							case (op)
								8'h10:
									rd(qbase + (4 * arg), 10'd248);
								8'h22: begin
									push(vint(arg));
									st <= 10'd118;
								end
								8'h23:
									rd(cbase + (4 * arg), 10'd247);
								8'h50: begin
									push(VFALSE);
									st <= 10'd118;
								end
								8'h51: begin
									push(VNONE);
									st <= 10'd118;
								end
								8'h52: begin
									push(VTRUE);
									st <= 10'd118;
								end
								8'h53: begin
									push(VNULL);
									st <= 10'd118;
								end
								8'h24, 8'h25, 8'h26, 8'h27, 8'h28, 8'h29:
									halt(ABI_HALT_INTERNAL, 32'h000010ca);
								8'h11, 8'h12, 8'h16, 8'h17, 8'h19, 8'h1a, 8'h13, 8'h14, 8'h18, 8'h15, 8'h1b, 8'h1c:
									rd(qbase + (4 * arg), 10'd357);
								8'h54:
									rd(h_hooks + (4 * ABI_HOOK_BUILD_CLASS), 10'd247);
								8'h55: begin
									t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))];
									t[1] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									st <= 10'd275;
								end
								8'h56: begin
									t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))];
									t[1] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									t[6] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))];
									st <= 10'd429;
								end
								8'h57: begin
									push(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]);
									st <= 10'd118;
								end
								8'h58: begin
									rf[rf_base[3:0] + sv2v_cast_4(sp)] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))];
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd1))] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									sp <= sp + 7'd2;
									st <= 10'd118;
								end
								8'h59: begin
									sp <= sp - 7'd1;
									st <= 10'd118;
								end
								8'h5a: begin
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))];
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									st <= 10'd118;
								end
								8'h5b: begin
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))];
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))];
									st <= 10'd118;
								end
								8'h42: begin
									pc <= jt;
									st <= 10'd118;
								end
								8'h43, 8'h44, 8'h45, 8'h46: begin
									tr_v <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									gosub(10'd438, 10'd225);
								end
								8'h47: begin
									t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									at_q <= ABI_Q_EXIT_D;
									gosub_scr(SCR_AT, 10'd9, 10'd437);
								end
								8'h48, 8'h49:
									if (xsp >= nexc)
										halt(ABI_HALT_INTERNAL, op_pc);
									else begin
										x0 <= jt;
										b0 <= op == 8'h49;
										x1 <= {16'd0, stk_depth};
										sw_k <= 2'd0;
										gosub(10'd501, 10'd118);
									end
								8'h4a: begin
									pc <= jt;
									sw_k <= 2'd0;
									gosub(10'd502, 10'd118);
								end
								8'h40: begin
									rf[rf_base[3:0] + sv2v_cast_4(sp)] <= vint(jt);
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd1))] <= vint({24'd0, ext});
									sp <= sp + 7'd2;
									st <= 10'd448;
								end
								8'h5c: st <= 10'd461;
								8'h5d: begin
									sw_k <= 2'd0;
									gosub(10'd502, 10'd506);
								end
								8'h63: st <= 10'd458;
								8'h64:
									if ((xsp != 5'd0) && (xp != VNULL)) begin
										xc <= xp;
										rx_from <= 1'b0;
										rsp <= 5'd0;
										st <= 10'd358;
									end
									else if (xsp < 5'd2)
										raise_msg(ABI_MSG_NO_ACTIVE_EXC);
									else begin
										sw_i <= sv2v_cast_32(xsp - 5'd2);
										sw_k <= 2'd0;
										st <= 10'd505;
									end
								8'h65: begin
									t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									sp <= sp - 7'd1;
									st <= 10'd382;
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
									sp <= sp - 7'd1;
									hook(ABI_HOOK_GETITER, ABI_RK_PUSH, 8'd1, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], VNULL, VNULL, VNULL);
								end
								8'h5f: begin
									t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									b1 <= ovr == ABI_OVR_PYOBJ;
									ovr <= ABI_OVR_NONE;
									st <= 10'd186;
								end
								8'h4b: st <= 10'd628;
								8'h2a: begin
									tb_src <= 1'b1;
									tb_nz <= 1'b0;
									tb_from <= sv2v_cast_8(sp - sv2v_cast_7(arg));
									stk_from <= stk_depth - sv2v_cast_16(arg);
									tb_n <= arg[7:0];
									gosub(10'd442, 10'd59);
								end
								8'h2b:
									alloc(32'd3 + (arg < 32'd4 ? 32'd4 : arg), 10'd34);
								8'h2c:
									alloc(32'd4 + (2 * arg), 10'd36);
								8'h2d: begin
									tb_src <= 1'b1;
									tb_nz <= 1'b0;
									tb_from <= sv2v_cast_8(sp - sv2v_cast_7(arg));
									stk_from <= stk_depth - sv2v_cast_16(arg);
									tb_n <= arg[7:0];
									gosub(10'd442, 10'd57);
								end
								8'h2e:
									alloc(32'd5, 10'd421);
								8'h2f: begin
									vs0 = sv2v_cast_7((sp - 7'd1) - sv2v_cast_7(arg >> 2));
									case (arg[1:0])
										2'd0: begin
											t[2] <= rf[rf_base[3:0] + sv2v_cast_4(vs0)];
											t[3] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
											gosub_scr(SCR_LA, 10'd233, 10'd408);
										end
										2'd1:
											lookup(rf[rf_base[3:0] + sv2v_cast_4(vs0)], rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))], LK_ADD, 1'b0, 10'd407);
										default:
											lookup(rf[rf_base[3:0] + sv2v_cast_4(vs0)], rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], VNULL, LK_ADD, 1'b1, 10'd409);
									endcase
								end
								8'h62:
									lookup(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))], rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))], LK_ADD, 1'b0, 10'd434);
								8'h30: begin
									t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
									if ((tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]) == ABI_TAG_TUPLE) || is_mut(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], ABI_MUT_LIST))
										rd(adr(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]), 10'd455);
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
									rd(rc + 24, 10'd285);
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
										wr(ab_ptr(8'd0), rf[rf_base[3:0] + sv2v_cast_4(vs1)], 10'd514);
									end
									else if ((has_link && !rf_reload_miss) && (v2 <= MPY_RF_DEPTH)) begin
										rf_resume <= 10'd110;
										st <= 10'd480;
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
										st <= 10'd487;
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
									st <= 10'd98;
								end
								8'h67:
									if (gen == VNULL)
										raise_err(ABI_ERR_GENERATOR, VNULL, VNULL);
									else
										st <= 10'd165;
								8'h68: begin
									fflags <= fflags & ~FF_YFAST;
									if (((inj == VNONE) && (rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] == VNONE)) && (tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))]) == ABI_TAG_OBJECT))
										rd(adr(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))]), 10'd169);
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
					10'd248: begin
						push({ABI_TAG_QSTR, md});
						st <= 10'd118;
					end
					10'd247: begin
						push(mv);
						st <= 10'd118;
					end
					10'd468:
						if ((mv == VNULL) && !(fflags & FF_FW))
							raise_msg(ABI_MSG_LOCAL_UNBOUND);
						else begin
							push(mv);
							lc_fill(i0, mv, 1'b0, 1'b1, 10'd118);
						end
					10'd469: begin
						lc_v[lc_ev_way] <= 1'b1;
						lc_ix[lc_ev_way] <= lc_ev_idx;
						lc_d[lc_ev_way] <= lc_ev_val;
						lc_dirty[lc_ev_way] <= lc_ev_dirty;
						lc_note(lc_ev_way);
						st <= 10'd118;
					end
					10'd470:
						if (lc_fi >= cfg_lc_n) begin
							lc_fi <= 4'd0;
							st <= lc_fl_ret;
						end
						else if (lc_v[lc_fi[2:0]] && lc_dirty[lc_fi[2:0]]) begin
							lc_dirty[lc_fi[2:0]] <= 1'b0;
							wr(loc_ptr(lc_ix[lc_fi[2:0]]), lc_d[lc_fi[2:0]], 10'd470);
							lc_fi <= lc_fi + 4'd1;
						end
						else
							lc_fi <= lc_fi + 4'd1;
					10'd466:
						if (mv == VNULL)
							raise_msg(ABI_MSG_LOCAL_UNBOUND);
						else
							wr(loc_ptr(i0), VNULL, 10'd118);
					10'd467:
						if ((mv == VNULL) && !(fflags & FF_FW))
							raise_msg(ABI_MSG_LOCAL_UNBOUND);
						else begin
							rd(adr(mv) + 8, 10'd106);
							if (cfg_lc_n != 4'd0) begin
								vs0 = {4'd0, lc_pick(i0)};
								if (!lc_v[vs0[2:0]] || !lc_dirty[vs0[2:0]])
									lc_fill(i0, mv, 1'b0, 1'b0, 10'd106);
							end
						end
					10'd472:
						if (mv == VNULL)
							raise_msg(ABI_MSG_LOCAL_UNBOUND);
						else begin
							wr(adr(mv) + 8, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], 10'd118);
							sp <= sp - 7'd1;
						end
					10'd471:
						if (mv == VNULL)
							raise_msg(ABI_MSG_LOCAL_UNBOUND);
						else
							rd(adr(mv) + 8, 10'd104);
					10'd106:
						if (mv == VNULL)
							raise_msg(ABI_MSG_LOCAL_UNBOUND);
						else begin
							push(mv);
							st <= 10'd118;
						end
					10'd104:
						if (mv == VNULL)
							raise_msg(ABI_MSG_LOCAL_UNBOUND);
						else
							wr(m_addr, VNULL, 10'd118);
					10'd357: begin
						at_q <= md;
						case (op)
							8'h11, 8'h12: begin
								b0 <= ((op == 8'h11) && (loc != VNULL) ? 1'b0 : 1'b1);
								i2 <= ((op == 8'h11) && (loc != VNULL) ? 8'd0 : 8'd1);
								st <= 10'd273;
							end
							8'h16, 8'h17:
								lookup(((op == 8'h16) && (loc != VNULL) ? loc : glb), {ABI_TAG_QSTR, md}, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], LK_ADD, 1'b0, 10'd422);
							8'h19, 8'h1a:
								lookup(((op == 8'h19) && (loc != VNULL) ? loc : glb), {ABI_TAG_QSTR, md}, VNULL, LK_REMOVE, 1'b0, 10'd107);
							8'h13, 8'h14: begin
								t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
								gosub_scr(SCR_AT, 10'd9, 10'd245);
							end
							8'h18: begin
								t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
								t[6] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))];
								st <= 10'd397;
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
					10'd273:
						if ((i2 == 8'd2) && (bov != VNULL))
							lookup(bov, {ABI_TAG_QSTR, at_q}, VNULL, LK_FIND, 1'b0, 10'd274);
						else
							lookup((i2 == 8'd0 ? loc : (i2 == 8'd1 ? glb : vmut(h_builtins, ABI_MUT_DICT))), {ABI_TAG_QSTR, at_q}, VNULL, LK_FIND, 1'b0, 10'd274);
					10'd274:
						if (lk_found) begin
							push(lk_res);
							st <= 10'd118;
						end
						else if ((i2 == 8'd2) && (bov != VNULL)) begin
							i2 <= 8'd3;
							lookup(vmut(h_builtins, ABI_MUT_DICT), {ABI_TAG_QSTR, at_q}, VNULL, LK_FIND, 1'b0, 10'd274);
						end
						else if (i2 >= 8'd2)
							raise_err(ABI_ERR_NAME, {ABI_TAG_QSTR, at_q}, VNULL);
						else begin
							i2 <= i2 + 8'd1;
							st <= 10'd273;
						end
					10'd422:
						if (lk_ro || lk_cx)
							raise_err(ABI_ERR_INTERNAL, t[4], VNULL);
						else begin
							sp <= sp - 7'd1;
							st <= 10'd118;
						end
					10'd107:
						if (!lk_found)
							raise_err(ABI_ERR_NAME, {ABI_TAG_QSTR, at_q}, VNULL);
						else
							st <= 10'd118;
					10'd245:
						case (at_kind)
							2'd1: begin
								rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= at_v;
								if (op == 8'h14)
									push(VNULL);
								st <= 10'd118;
							end
							2'd2:
								if (op == 8'h14) begin
									rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= at_v;
									push(t[0]);
									st <= 10'd118;
								end
								else begin
									t[1] <= at_v;
									alloc(32'd4, 10'd235);
								end
							default: begin
								sp <= sp - 7'd1;
								hook(ABI_HOOK_GETATTR, (op == 8'h14 ? ABI_RK_PUSH_NULL : ABI_RK_PUSH), 8'd2, t[0], {ABI_TAG_QSTR, at_q}, VNULL, VNULL);
							end
						endcase
					10'd235: begin
						wb_v[0] <= vint(ABI_OB_BOUND_METHOD);
						wb_v[1] <= ty_bm;
						wb_v[2] <= t[1];
						wb_v[3] <= t[0];
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= vobj(al_a);
						wblock(al_a, 4'd4, 10'd118);
					end
					10'd397:
						if (tg(t[0]) == ABI_TAG_OBJECT)
							rd(adr(t[0]), 10'd400);
						else
							st <= 10'd399;
					10'd400:
						if ((scr_id == SCR_NONE) || (scr_id == SCR_AT)) begin
							scr_id <= SCR_AT;
							sA[3] <= md;
							if ((md == ABI_OB_INSTANCE) || (md == ABI_OB_EXCEPTION))
								rd(adr(t[0]) + 4, 10'd406);
							else if ((md == ABI_OB_TYPE) || (md == ABI_OB_MODULE))
								rd(adr(t[0]) + 8, 10'd398);
							else
								st <= 10'd399;
						end
						else
							wr(scr_addr(SCR_AT, 4'd3), {4'd0, md}, 10'd630);
					10'd630:
						if (scr_id != SCR_AT)
							scr_ensure(SCR_AT, 10'd630);
						else if ((sA[3] == ABI_OB_INSTANCE) || (sA[3] == ABI_OB_EXCEPTION))
							rd(adr(t[0]) + 4, 10'd406);
						else if ((sA[3] == ABI_OB_TYPE) || (sA[3] == ABI_OB_MODULE))
							rd(adr(t[0]) + 8, 10'd398);
						else
							st <= 10'd399;
					10'd406:
						rd(adr(mv) + 28, 10'd405);
					10'd405:
						if (md & (ABI_TF_SETATTR | ABI_TF_DESC))
							st <= 10'd399;
						else
							rd(adr(t[0]) + (sA[3] == ABI_OB_EXCEPTION ? 16 : 8), 10'd398);
					10'd398:
						if (mv == VNULL) begin
							if ((t[6] == VNULL) || !((sA[3] == ABI_OB_INSTANCE) || (sA[3] == ABI_OB_EXCEPTION)))
								st <= 10'd399;
							else
								alloc(32'd4, 10'd401);
						end
						else
							lookup(mv, {ABI_TAG_QSTR, at_q}, t[6], (t[6] == VNULL ? LK_REMOVE : LK_ADD), 1'b0, 10'd404);
					10'd401: begin
						wb_v[0] <= vint(32'd0);
						wb_v[1] <= vint(32'd0);
						wb_v[2] <= VNULL;
						wb_v[3] <= vint(32'd0);
						t[4] <= vmut(al_a, ABI_MUT_DICT);
						wblock(al_a, 4'd4, 10'd402);
					end
					10'd402:
						wr(adr(t[0]) + (sA[3] == ABI_OB_EXCEPTION ? 16 : 8), t[4], 10'd403);
					10'd403:
						lookup(t[4], {ABI_TAG_QSTR, at_q}, t[6], LK_ADD, 1'b0, 10'd404);
					10'd404:
						if ((lk_ro || lk_cx) || ((lk_mode == LK_REMOVE) && !lk_found))
							st <= 10'd399;
						else begin
							sp <= sp - 7'd2;
							st <= 10'd118;
						end
					10'd399: begin
						sp <= sp - 7'd2;
						hook(ABI_HOOK_SETATTR, ABI_RK_DISCARD, 8'd3, t[0], {ABI_TAG_QSTR, at_q}, t[6], VNULL);
					end
					10'd275:
						if ((is_mut(t[0], ABI_MUT_LIST) || (tg(t[0]) == ABI_TAG_TUPLE)) && intlike(t[1]))
							rd(adr(t[0]), 10'd279);
						else if (is_mut(t[0], ABI_MUT_DICT))
							lookup(t[0], t[1], VNULL, LK_FIND, 1'b0, 10'd276);
						else if ((strlike(t[0]) || (tg(t[0]) == ABI_TAG_BYTES)) && intlike(t[1])) begin
							si_v <= t[0];
							gosub(10'd415, 10'd281);
						end
						else
							st <= 10'd277;
					10'd279: begin
						v0 = ival(t[1]);
						if (v0[31])
							v0 = v0 + md;
						x1 <= v0;
						if (v0[31] || (v0 >= md))
							raise_msg((tg(t[0]) == ABI_TAG_TUPLE ? ABI_MSG_TUPLE_INDEX : ABI_MSG_LIST_INDEX));
						else if (tg(t[0]) == ABI_TAG_TUPLE)
							rd((adr(t[0]) + 4) + (v0 << 2), 10'd280);
						else
							rd(adr(t[0]) + 8, 10'd278);
					end
					10'd278:
						rd(md + (x1 << 2), 10'd280);
					10'd280: begin
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= mv;
						sp <= sp - 7'd1;
						st <= 10'd118;
					end
					10'd276:
						if (lk_cx)
							st <= 10'd277;
						else if (lk_found) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= lk_res;
							sp <= sp - 7'd1;
							st <= 10'd118;
						end
						else
							raise_err(ABI_ERR_KEY, t[1], VNULL);
					10'd281: begin
						v0 = ival(t[1]);
						if (v0[31])
							v0 = v0 + si_len;
						x1 <= v0;
						if (si_na)
							st <= 10'd277;
						else if (v0[31] || (v0 >= si_len))
							raise_msg((tg(t[0]) == ABI_TAG_BYTES ? ABI_MSG_BYTES_INDEX : ABI_MSG_STR_INDEX));
						else
							rd(si_addr + {v0[31:2], 2'b00}, 10'd282);
					end
					10'd282:
						if (tg(t[0]) == ABI_TAG_BYTES) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= vint({24'd0, byte_of(md, x1[1:0])});
							sp <= sp - 7'd1;
							st <= 10'd118;
						end
						else
							rd(h_chars + (4 * byte_of(md, x1[1:0])), 10'd283);
					10'd283: begin
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= {ABI_TAG_QSTR, md};
						sp <= sp - 7'd1;
						st <= 10'd118;
					end
					10'd277: begin
						sp <= sp - 7'd2;
						hook(ABI_HOOK_SUBSCR, ABI_RK_PUSH, 8'd2, t[0], t[1], VNULL, VNULL);
					end
					10'd429:
						if (t[6] == VNULL)
							st <= 10'd431;
						else if (is_mut(t[0], ABI_MUT_LIST) && intlike(t[1]))
							rd(adr(t[0]), 10'd433);
						else if (is_mut(t[0], ABI_MUT_DICT))
							lookup(t[0], t[1], t[6], LK_ADD, 1'b0, 10'd430);
						else
							st <= 10'd431;
					10'd433: begin
						v0 = ival(t[1]);
						if (v0[31])
							v0 = v0 + md;
						x1 <= v0;
						if (v0[31] || (v0 >= md))
							raise_msg(ABI_MSG_LIST_INDEX);
						else
							rd(adr(t[0]) + 8, 10'd432);
					end
					10'd432: begin
						wr(md + (x1 << 2), t[6], 10'd118);
						sp <= sp - 7'd3;
					end
					10'd430:
						if (lk_cx || lk_ro)
							st <= 10'd431;
						else begin
							sp <= sp - 7'd3;
							st <= 10'd118;
						end
					10'd431: begin
						sp <= sp - 7'd3;
						hook(ABI_HOOK_SETSUBSCR, ABI_RK_DISCARD, 8'd3, t[0], t[1], t[6], VNULL);
					end
					10'd225:
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
							st <= 10'd118;
						end
					10'd437: begin
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
							gosub_scr(SCR_AT, 10'd9, 10'd436);
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
					10'd436:
						if ((at_kind == 2'd2) || (at_kind == 2'd1)) begin
							ab_lo <= (at_kind == 2'd2 ? 8'd31 : 8'd32);
							ab_pe <= 8'd32;
							ab_nkw <= 8'd0;
							crk <= ABI_RK_CONT;
							fcont <= ABI_CONT_WITH_ENTER;
							aux <= vint(jt);
							wr(ab_ptr(8'd0), at_v, 10'd516);
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
					10'd516:
						wr(ab_ptr(8'd31), t[0], 10'd60);
					10'd461: begin
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
						st <= 10'd517;
					end
					10'd517:
						case (i0)
							8'd0: begin
								wr(ab_ptr(8'd34), VNONE, 10'd517);
								i0 <= 8'd1;
							end
							8'd1:
								if (x0 == 32'd2)
									i0 <= 8'd2;
								else begin
									wr(ab_ptr(8'd32), VNONE, 10'd517);
									i0 <= 8'd2;
								end
							8'd2: begin
								if (x0 == 32'd2)
									wr(ab_ptr(8'd33), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))], 10'd517);
								else
									wr(ab_ptr(8'd33), VNONE, 10'd517);
								i0 <= 8'd3;
							end
							8'd3: begin
								if (x0 == 32'd1)
									wr(ab_ptr(8'd0), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd4))], 10'd517);
								else
									wr(ab_ptr(8'd0), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))], 10'd517);
								i0 <= 8'd4;
							end
							8'd4: begin
								if (x0 == 32'd1)
									wr(ab_ptr(8'd31), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))], 10'd517);
								else
									wr(ab_ptr(8'd31), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))], 10'd517);
								i0 <= 8'd5;
							end
							default:
								if (x0 == 32'd2)
									rd(adr(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]) + 4, 10'd462);
								else
									st <= 10'd518;
						endcase
					10'd462:
						wr(ab_ptr(8'd32), mv, 10'd518);
					10'd518: begin
						if (x0 == 32'd1)
							sp <= sp - 7'd4;
						else
							sp <= sp - 7'd3;
						st <= 10'd60;
					end
					10'd501:
						if ((xsp != 5'd0) && (sw_k != 2'd3)) begin
							v0 = exc_ptr(fbase, xsp - 5'd1) + {28'd0, sw_k, 2'b00};
							case (sw_k)
								2'd0:
									wr(v0, {4'd0, xh}, 10'd501);
								2'd1:
									wr(v0, {4'd0, xf, 15'd0, xv}, 10'd501);
								default:
									wr(v0, xp, 10'd501);
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
					10'd502:
						if (sw_k == 2'd0) begin
							if (xsp <= 5'd1) begin
								if (xsp == 5'd1)
									xsp <= 5'd0;
								ret;
							end
							else begin
								rd(exc_ptr(fbase, xsp - 5'd2), 10'd502);
								xsp <= xsp - 5'd1;
								sw_k <= 2'd1;
							end
						end
						else if (sw_k == 2'd1) begin
							xh <= md;
							rd(exc_ptr(fbase, xsp - 5'd1) + 32'd4, 10'd502);
							sw_k <= 2'd2;
						end
						else if (sw_k == 2'd2) begin
							xv <= md[15:0];
							xf <= md[31];
							rd(exc_ptr(fbase, xsp - 5'd1) + 32'd8, 10'd502);
							sw_k <= 2'd3;
						end
						else begin
							xp <= mv;
							ret;
						end
					10'd503:
						if ((xsp == 5'd0) || (sw_k == 2'd3))
							ret;
						else begin
							v0 = exc_ptr((spill_to_img ? x4 : fbase), xsp - 5'd1) + {28'd0, sw_k, 2'b00};
							case (sw_k)
								2'd0:
									wr(v0, {4'd0, xh}, 10'd503);
								2'd1:
									wr(v0, {4'd0, xf, 15'd0, xv}, 10'd503);
								default:
									wr(v0, xp, 10'd503);
							endcase
							sw_k <= sw_k + 2'd1;
						end
					10'd504:
						if (xsp == 5'd0)
							ret;
						else if (sw_k == 2'd0) begin
							rd(exc_ptr(fbase, xsp - 5'd1), 10'd504);
							sw_k <= 2'd1;
						end
						else if (sw_k == 2'd1) begin
							xh <= md;
							rd(exc_ptr(fbase, xsp - 5'd1) + 32'd4, 10'd504);
							sw_k <= 2'd2;
						end
						else if (sw_k == 2'd2) begin
							xv <= md[15:0];
							xf <= md[31];
							rd(exc_ptr(fbase, xsp - 5'd1) + 32'd8, 10'd504);
							sw_k <= 2'd3;
						end
						else begin
							xp <= mv;
							ret;
						end
					10'd505:
						if (sw_k == 2'd0) begin
							rd(exc_ptr(fbase, sw_i[4:0]) + 32'd8, 10'd505);
							sw_k <= 2'd1;
						end
						else if (mv != VNULL) begin
							xc <= mv;
							rx_from <= 1'b0;
							rsp <= 5'd0;
							st <= 10'd358;
						end
						else if (sw_i == 32'd0)
							raise_msg(ABI_MSG_NO_ACTIVE_EXC);
						else begin
							rd(exc_ptr(fbase, sw_i[4:0] - 5'd1) + 32'd8, 10'd505);
							sw_i <= sw_i - 32'd1;
						end
					10'd506:
						if (rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] == VNONE) begin
							sp <= sp - 7'd1;
							st <= 10'd118;
						end
						else if (tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]) == ABI_TAG_INT) begin
							if (rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))][31]) begin
								sp <= sp - 7'd1;
								st <= 10'd458;
							end
							else
								st <= 10'd448;
						end
						else
							raise_val(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]);
					10'd458:
						if (has_link && (sp <= sv2v_cast_7_signed(RF_RELOAD_AT))) begin
							rf_resume <= 10'd458;
							st <= 10'd480;
						end
						else if (xsp == 5'd0) begin
							t[7] <= rf[rf_base[3:0] + sv2v_cast_4(sp - 7'd1)];
							if (gen != VNULL) begin
								pc <= 32'd0;
								st <= 10'd148;
							end
							else
								st <= 10'd359;
						end
						else if (xf && (xh >= pc)) begin
							if ((((spilled_reals != 16'd0) || has_link) || (rf_base != 6'd0)) || ((sv2v_cast_32(xv) + 32'd2) > MPY_RF_DEPTH)) begin
								ur_target <= xv;
								ur_val <= rf[rf_base[3:0] + sv2v_cast_4(sp - 7'd1)];
								pc <= xh;
								st <= 10'd459;
							end
							else begin
								rf[rf_base[3:0] + sv2v_cast_4(xv[6:0])] <= rf[rf_base[3:0] + sv2v_cast_4(sp - 7'd1)];
								rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(xv[6:0] + 7'd1))] <= vint(32'hffffffff);
								sp <= xv[6:0] + 7'd2;
								pc <= xh;
								st <= 10'd118;
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
							gosub(10'd502, 10'd458);
						end
					10'd448: begin
						uj <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))][31:0];
						sp <= sp - 7'd1;
						st <= 10'd449;
					end
					10'd449:
						if (uj[6:0] == 7'd0) begin
							pc <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))][31:0];
							sp <= (sp - 7'd1) - (uj[7] ? 7'd4 : 7'd0);
							st <= 10'd118;
						end
						else if (xsp == 5'd0)
							uj <= uj - 32'd1;
						else if (xf && (xh >= pc)) begin
							uj <= uj - 32'd1;
							push(vint(uj - 32'd1));
							pc <= xh;
							st <= 10'd118;
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
							gosub(10'd502, 10'd449);
						end
					10'd382:
						if (tg(t[0]) != ABI_TAG_OBJECT)
							raise_err(ABI_ERR_NOT_EXC, t[0], VNULL);
						else
							rd(adr(t[0]), 10'd383);
					10'd383:
						if (md == ABI_OB_EXCEPTION)
							raise_val(t[0]);
						else if (md == ABI_OB_TYPE)
							rd(adr(t[0]) + 28, 10'd384);
						else
							raise_err(ABI_ERR_NOT_EXC, t[0], VNULL);
					10'd384:
						if (md & ABI_TF_EXC) begin
							wr(ab_ptr(8'd0), t[0], 10'd60);
							ab_lo <= 8'd32;
							ab_pe <= 8'd32;
							ab_nkw <= 8'd0;
							crk <= ABI_RK_CONT;
							fcont <= ABI_CONT_RAISE;
						end
						else
							raise_err(ABI_ERR_NOT_EXC, t[0], VNULL);
					10'd186: begin
						vs0 = sp - 7'd1;
						if ((((((((tg(t[0]) == ABI_TAG_TUPLE) || (tg(t[0]) == ABI_TAG_BYTES)) || is_mut(t[0], ABI_MUT_LIST)) || is_mut(t[0], ABI_MUT_DICT)) || is_mut(t[0], ABI_MUT_SET)) || is_mut(t[0], ABI_MUT_BYTEARRAY)) || (tg(t[0]) == ABI_TAG_ITER)) || ((tg(t[0]) == ABI_TAG_OBJECT) && b1)) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(vs0 + 7'd1))] <= vint(32'd0);
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(vs0 + 7'd2))] <= vint(32'd0);
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(vs0 + 7'd3))] <= vint((tg(t[0]) == ABI_TAG_ITER ? ABI_IT_HEAPITER : (tg(t[0]) == ABI_TAG_OBJECT ? ABI_IT_PYOBJ : (is_mut(t[0], ABI_MUT_DICT) ? ABI_IT_DICT : (is_mut(t[0], ABI_MUT_SET) ? ABI_IT_SET : ABI_IT_SEQ)))));
							sp <= sp + 7'd3;
							st <= 10'd118;
						end
						else if (tg(t[0]) == ABI_TAG_RANGE)
							rd(adr(t[0]), 10'd190);
						else if (strlike(t[0])) begin
							si_v <= t[0];
							gosub(10'd415, 10'd193);
						end
						else if (tg(t[0]) == ABI_TAG_OBJECT)
							rd(adr(t[0]), 10'd189);
						else
							st <= 10'd188;
					end
					10'd190: begin
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= mv;
						rd(adr(t[0]) + 4, 10'd191);
					end
					10'd191: begin
						rf[rf_base[3:0] + sv2v_cast_4(sp)] <= mv;
						rd(adr(t[0]) + 8, 10'd192);
					end
					10'd192: begin
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd1))] <= mv;
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd2))] <= vint(ABI_IT_RANGE);
						sp <= sp + 7'd3;
						st <= 10'd118;
					end
					10'd193:
						if (si_na)
							st <= 10'd188;
						else begin
							rf[rf_base[3:0] + sv2v_cast_4(sp)] <= vint(32'd0);
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd1))] <= vint(32'd0);
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd2))] <= vint(ABI_IT_STR);
							sp <= sp + 7'd3;
							st <= 10'd118;
						end
					10'd189:
						if (md == ABI_OB_DICT_VIEW)
							rd(adr(t[0]) + 8, 10'd194);
						else begin
							at_q <= ABI_Q_ITER_D;
							gosub_scr(SCR_AT, 10'd9, 10'd187);
						end
					10'd194: begin
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= mv;
						rd(adr(t[0]) + 12, 10'd195);
					end
					10'd195: begin
						rf[rf_base[3:0] + sv2v_cast_4(sp)] <= vint(32'd0);
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd1))] <= mv;
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp + 7'd2))] <= vint(ABI_IT_DICT);
						sp <= sp + 7'd3;
						st <= 10'd118;
					end
					10'd187:
						if ((at_kind == 2'd2) || (at_kind == 2'd1)) begin
							ab_lo <= (at_kind == 2'd2 ? 8'd31 : 8'd32);
							ab_pe <= 8'd32;
							ab_nkw <= 8'd0;
							crk <= ABI_RK_CONT;
							fcont <= ABI_CONT_GETITER;
							pc <= op_pc;
							wr(ab_ptr(8'd0), at_v, 10'd516);
						end
						else
							st <= 10'd188;
					10'd188: begin
						fcont <= ABI_CONT_GETITER;
						pc <= op_pc;
						hook(ABI_HOOK_GETITER, ABI_RK_CONT, 8'd1, t[0], VNULL, VNULL, VNULL);
					end
					10'd628:
						if ((scr_id != SCR_NONE) && (scr_id != SCR_IT))
							scr_go_store(scr_id, 10'd628);
						else begin
							begin : sv2v_autoblock_14
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
									st <= 10'd123;
								end
								else begin
									t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))];
									if (tg(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))]) == ABI_TAG_OBJECT)
										rd(adr(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))]), 10'd122);
									else begin
										at_q <= ABI_Q_NEXT_D;
										scr_go_store_gosub(SCR_IT, 10'd9, 10'd120);
									end
								end
							end
							else if (rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] == vint(ABI_IT_HEAPITER)) begin
								it_h <= 1'b1;
								t[3] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd4))];
								i0 <= 8'd0;
								st <= 10'd123;
							end
							else begin
								it_h <= 1'b0;
								gosub(10'd212, 10'd125);
							end
						end
					10'd123:
						if (((i0 == 8'd0) && (scr_id != SCR_NONE)) && (scr_id != SCR_IT))
							scr_go_store(scr_id, 10'd123);
						else begin
							if (scr_id != SCR_IT)
								scr_id <= SCR_IT;
							if (i0 == 8'd4)
								gosub(10'd212, 10'd125);
							else
								rd(adr(t[3]) + (4 * i0), 10'd124);
						end
					10'd124: begin
						sV[i0[1:0]] <= mv;
						i0 <= i0 + 8'd1;
						st <= 10'd123;
					end
					10'd125:
						if (it_py) begin
							t[0] <= sV[0];
							if (tg(sV[0]) == ABI_TAG_OBJECT)
								rd(adr(sV[0]), 10'd122);
							else begin
								at_q <= ABI_Q_NEXT_D;
								gosub_scr(SCR_AT, 10'd9, 10'd120);
							end
						end
						else if (it_h)
							wr(adr(t[3]), sV[0], 10'd126);
						else begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd4))] <= sV[0];
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd3))] <= sV[1];
							st <= 10'd121;
						end
					10'd126:
						wr(adr(t[3]) + 4, sV[1], 10'd121);
					10'd121: begin
						if (it_stop) begin
							sp <= sp - 7'd4;
							pc <= jt;
						end
						else
							push(it_val);
						st <= 10'd118;
					end
					10'd120:
						if ((at_kind == 2'd2) || (at_kind == 2'd1)) begin
							ab_lo <= (at_kind == 2'd2 ? 8'd31 : 8'd32);
							ab_pe <= 8'd32;
							ab_nkw <= 8'd0;
							crk <= ABI_RK_CONT;
							fcont <= ABI_CONT_FOR_NEXT;
							aux <= vint(jt);
							wr(ab_ptr(8'd0), at_v, 10'd516);
						end
						else
							raise_err(ABI_ERR_NOT_ITERATOR, t[0], VNULL);
					10'd122:
						if (md == ABI_OB_GENERATOR) begin
							t[1] <= VNONE;
							t[2] <= VNONE;
							r_rk <= ABI_RK_CONT;
							fcont <= ABI_CONT_FOR_NEXT;
							aux <= vint(jt);
							st <= 10'd152;
						end
						else begin
							at_q <= ABI_Q_NEXT_D;
							gosub_scr(SCR_AT, 10'd9, 10'd120);
						end
					10'd59: begin
						drop_left <= {8'd0, tb_n};
						drop_push_en <= 1'b1;
						drop_push_v <= tb_v;
						drop_then <= 10'd118;
						st <= 10'd494;
					end
					10'd34: begin
						v0 = (arg < 32'd4 ? 32'd4 : arg);
						wb_v[0] <= vint(arg);
						wb_v[1] <= vint(v0);
						wb_v[2] <= {ABI_TAG_CONT, al_a + 32'd12};
						t[0] <= vmut(al_a, ABI_MUT_LIST);
						i0 <= 8'd0;
						wblock(al_a, 4'd3, 10'd35);
					end
					10'd35:
						if (i0 == arg[7:0]) begin
							drop_left <= {8'd0, arg[7:0]};
							drop_push_en <= 1'b1;
							drop_push_v <= t[0];
							drop_then <= 10'd118;
							st <= 10'd494;
						end
						else begin
							v0 = (sv2v_cast_32(stk_depth) - arg) + sv2v_cast_32(i0);
							if (stk_hit(v0[15:0])) begin
								wr((adr(t[0]) + 12) + (4 * i0), stk_val(v0[15:0]), 10'd35);
								i0 <= i0 + 8'd1;
							end
							else begin
								srd_g <= v0[15:0];
								gosub(10'd483, 10'd495);
							end
						end
					10'd495: begin
						wr((adr(t[0]) + 12) + (4 * i0), srd_v, 10'd35);
						i0 <= i0 + 8'd1;
					end
					10'd36: begin
						wb_v[0] <= vint(32'd0);
						wb_v[1] <= vint(arg);
						wb_v[2] <= (arg == 32'd0 ? VNULL : {ABI_TAG_CONT, al_a + 32'd16});
						wb_v[3] <= vint(32'd0);
						rf[rf_base[3:0] + sv2v_cast_4(sp)] <= vmut(al_a, ABI_MUT_DICT);
						sp <= sp + 7'd1;
						wblock(al_a, 4'd4, 10'd118);
					end
					10'd57:
						if ({8'd0, tb_n} > resident_reals) begin
							drop_left <= {8'd0, tb_n};
							drop_push_en <= 1'b0;
							drop_then <= 10'd58;
							st <= 10'd494;
						end
						else begin
							sp <= sp - sv2v_cast_7(tb_n);
							hook(ABI_HOOK_DICTOP, ABI_RK_PUSH, 8'd4, vint(32'd0), tb_v, VNULL, VNULL);
						end
					10'd58:
						hook(ABI_HOOK_DICTOP, ABI_RK_PUSH, 8'd4, vint(32'd0), tb_v, VNULL, VNULL);
					10'd421: begin
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
						wblock(al_a, 4'd5, 10'd118);
					end
					10'd408: begin
						sp <= sp - 7'd1;
						st <= 10'd118;
					end
					10'd407:
						if (lk_cx || lk_ro) begin
							sp <= sp - 7'd2;
							hook(ABI_HOOK_DICTOP, ABI_RK_DISCARD, 8'd4, vint(32'd1), t[4], t[5], t[6]);
						end
						else begin
							sp <= sp - 7'd2;
							st <= 10'd118;
						end
					10'd409:
						if (lk_cx || lk_ro) begin
							sp <= sp - 7'd1;
							hook(ABI_HOOK_DICTOP, ABI_RK_DISCARD, 8'd4, vint(32'd2), t[4], t[5], VNULL);
						end
						else begin
							sp <= sp - 7'd1;
							st <= 10'd118;
						end
					10'd434:
						if (lk_cx || lk_ro) begin
							sp <= sp - 7'd2;
							hook(ABI_HOOK_DICTOP, ABI_RK_DISCARD, 8'd4, vint(32'd1), t[4], t[5], t[6]);
						end
						else begin
							sp <= sp - 7'd2;
							st <= 10'd118;
						end
					10'd455:
						if (md != arg) begin
							sp <= sp - 7'd1;
							fcont <= ABI_CONT_UNPACK;
							hook(ABI_HOOK_UNPACK, ABI_RK_CONT, 8'd3, t[0], vint(arg), vint(32'd0), VNULL);
						end
						else if (tg(t[0]) == ABI_TAG_TUPLE) begin
							x2 <= adr(t[0]) + 4;
							x1 <= arg;
							sp <= sp - 7'd1;
							st <= 10'd454;
						end
						else
							rd(adr(t[0]) + 8, 10'd456);
					10'd456: begin
						x2 <= md;
						x1 <= arg;
						sp <= sp - 7'd1;
						st <= 10'd454;
					end
					10'd454:
						if (x1 == 32'd0)
							st <= 10'd118;
						else
							rd((x2 + (x1 << 2)) - 32'd4, 10'd457);
					10'd457: begin
						x1 <= x1 - 32'd1;
						push(mv);
						st <= 10'd454;
					end
					10'd285:
						rd(md + (4 * arg), 10'd287);
					10'd287: begin
						c_rc <= md;
						if ((op == 8'h20) || (op == 8'h21)) begin
							tb_src <= 1'b1;
							tb_nz <= 1'b0;
							tb_from <= sv2v_cast_8(sp - sv2v_cast_7(ext));
							stk_from <= stk_depth - sv2v_cast_16(ext);
							tb_n <= ext;
							gosub(10'd442, 10'd286);
						end
						else begin
							t[0] <= VNULL;
							st <= 10'd288;
						end
					end
					10'd286: begin
						t[0] <= tb_v;
						st <= 10'd288;
					end
					10'd288:
						if (fun == VNULL) begin
							t[1] <= VNULL;
							alloc(32'd8, 10'd284);
						end
						else
							rd(adr(fun) + 32'd28, 10'd289);
					10'd289: begin
						t[1] <= mv;
						alloc(32'd8, 10'd284);
					end
					10'd284: begin
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
						wblock(al_a, 4'd8, 10'd118);
					end
					10'd98:
						if (cv_wide)
							st <= 10'd521;
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
							wr(ab_ptr(8'd0), rf[rf_base[3:0] + sv2v_cast_4(cv_fidx)], 10'd519);
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
					10'd519:
						if (b1)
							wr(ab_ptr(8'd31), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(cv_fidx + 7'd1))], 10'd94);
						else
							st <= 10'd94;
					10'd521:
						if (cv_i == cv_n) begin
							cv_g <= cv_fun_g;
							cv_ret <= 10'd522;
							st <= 10'd532;
						end
						else begin
							cv_g <= cv_pos_g + {8'd0, cv_i};
							cv_ret <= 10'd525;
							st <= 10'd532;
						end
					10'd522:
						if (op == 8'h37) begin
							t[2] <= t[3];
							cv_g <= cv_fun_g + 16'd1;
							cv_ret <= 10'd523;
							st <= 10'd532;
						end
						else begin
							b1 <= 1'b0;
							ab_lo <= 8'd32;
							ab_pe <= 8'd32;
							cv_i <= 8'd0;
							wr(ab_ptr(8'd0), t[3], 10'd94);
						end
					10'd523: begin
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
						wr(ab_ptr(8'd0), t[2], 10'd524);
					end
					10'd524:
						if (b1)
							wr(ab_ptr(8'd31), t[6], 10'd94);
						else
							st <= 10'd94;
					10'd525: begin
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
							st <= 10'd521;
						end
					end
					10'd526:
						rd(srd_addr, 10'd527);
					10'd527: begin
						v0 = sv2v_cast_32(mpy_rf_chunk_count(mt, md));
						v1 = mpy_rf_chunk_prev(md);
						if ((v0 != 32'd0) && (srd_off < v0[15:0])) begin
							x1 <= (v0 - 32'd1) - sv2v_cast_32(srd_off);
							x0 <= ((srd_addr + 32'd4) + (sv2v_cast_32((v0[5:0] + 6'd7) >> 3) << 2)) + (((v0 - 32'd1) - sv2v_cast_32(srd_off)) << 2);
							st <= 10'd528;
						end
						else if ((v1 == 32'd0) || (srd_hops == 8'd64))
							halt(ABI_HALT_INTERNAL, 32'h0000c0c1);
						else begin
							srd_off <= srd_off - v0[15:0];
							srd_addr <= v1;
							srd_hops <= srd_hops + 8'd1;
							st <= 10'd526;
						end
					end
					10'd528:
						rd((srd_addr + 32'd4) + ((x1 >> 3) << 2), 10'd529);
					10'd529: begin
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
						wr((srd_addr + 32'd4) + ((x1 >> 3) << 2), {4'd0, v3}, 10'd530);
					end
					10'd530:
						wr(x0, t[7], 10'd531);
					10'd531: begin
						pc <= op_pc;
						st <= 10'd118;
					end
					10'd532:
						if (stk_hit(cv_g)) begin
							t[3] <= stk_val(cv_g);
							st <= cv_ret;
						end
						else begin
							srd_g <= cv_g;
							gosub(10'd483, 10'd533);
						end
					10'd533: begin
						t[3] <= srd_v;
						st <= cv_ret;
					end
					10'd94:
						if (cv_i == cv_n) begin
							ab_nkw <= cv_j;
							crk <= ABI_RK_PUSH;
							gi <= 32'd0;
							if (ab_chunked)
								ab_npos <= ab_nitems;
							if (!cv_wide)
								sp <= cv_fidx;
							st <= 10'd520;
						end
						else if (cv_wide) begin
							cv_g <= cv_pos_g + {8'd0, cv_i};
							cv_ret <= (cv_bm[cv_i[4:0]] ? 10'd535 : 10'd534);
							st <= 10'd532;
						end
						else if (!cv_bm[cv_i[4:0]]) begin
							wr(ab_ptr(ab_pe), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(cv_base + sv2v_cast_7(cv_i)))], 10'd94);
							ab_pe <= ab_pe + 8'd1;
							cv_i <= cv_i + 8'd1;
						end
						else begin
							t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(cv_base + sv2v_cast_7(cv_i)))];
							rd(adr(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(cv_base + sv2v_cast_7(cv_i)))]), 10'd97);
						end
					10'd534:
						if (ab_chunked) begin
							cv_i <= cv_i + 8'd1;
							cv_ret <= 10'd94;
							st <= 10'd543;
						end
						else begin
							wr(ab_ptr(ab_pe), t[3], 10'd94);
							ab_pe <= ab_pe + 8'd1;
							cv_i <= cv_i + 8'd1;
						end
					10'd535: begin
						t[0] <= t[3];
						rd(adr(t[3]), 10'd97);
					end
					10'd97: begin
						x4 <= md;
						gi <= 32'd0;
						if (tg(t[0]) == ABI_TAG_TUPLE) begin
							cv_items <= adr(t[0]) + 4;
							st <= 10'd96;
						end
						else
							rd(adr(t[0]) + 8, 10'd95);
					end
					10'd95: begin
						cv_items <= md;
						st <= 10'd96;
					end
					10'd96:
						if (gi == x4) begin
							cv_i <= cv_i + 8'd1;
							st <= 10'd94;
						end
						else if (ab_chunked)
							rd(cv_items + (gi << 2), 10'd538);
						else if (ab_pe >= 8'd200) begin
							cv_kw <= 1'b0;
							st <= 10'd539;
						end
						else
							rd(cv_items + (gi << 2), 10'd99);
					10'd538: begin
						t[3] <= mv;
						gi <= gi + 32'd1;
						cv_ret <= 10'd96;
						st <= 10'd543;
					end
					10'd99: begin
						wr(ab_ptr(ab_pe), mv, 10'd96);
						ab_pe <= ab_pe + 8'd1;
						gi <= gi + 32'd1;
					end
					10'd520:
						if ((!ab_chunked && (gi == 32'd0)) && (({24'd0, ab_pe} + {23'd0, cv_j, 1'b0}) > 32'd256)) begin
							cv_kw <= 1'b1;
							st <= 10'd539;
						end
						else if (gi == {23'd0, cv_j, 1'b0}) begin
							if (cv_wide) begin
								drop_left <= stk_depth - cv_fun_g;
								drop_push_en <= 1'b0;
								drop_then <= (ab_chunked ? 10'd558 : 10'd60);
								st <= 10'd494;
							end
							else
								st <= (ab_chunked ? 10'd558 : 10'd60);
						end
						else if (cv_wide) begin
							cv_g <= (cv_pos_g + {8'd0, cv_n}) + gi[15:0];
							cv_ret <= 10'd536;
							st <= 10'd532;
						end
						else if (ab_chunked) begin
							t[3] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6((cv_base + sv2v_cast_7(cv_n)) + gi[6:0]))];
							st <= 10'd536;
						end
						else begin
							wr(ab_ptr(ab_pe + gi[7:0]), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6((cv_base + sv2v_cast_7(cv_n)) + gi[6:0]))], 10'd520);
							gi <= gi + 32'd1;
						end
					10'd536: begin
						if ((t[3] == VNULL) && !gi[0])
							t[3] <= vint(32'd0);
						st <= 10'd537;
					end
					10'd537: begin
						gi <= gi + 32'd1;
						if (ab_chunked) begin
							cv_ret <= 10'd520;
							st <= 10'd543;
						end
						else
							wr(ab_ptr(ab_pe + gi[7:0]), t[3], 10'd520);
					end
					10'd539: begin
						ab_chunked <= 1'b1;
						ab_ovf <= 1'b0;
						ab_npos <= {24'd0, ab_pe} - {24'd0, ab_lo};
						ab_nitems <= 32'd0;
						ab_nblk <= 32'd0;
						ab_fill <= 5'd0;
						ab_blk <= VNULL;
						t[5] <= VNULL;
						cv_k <= 32'd0;
						wr(ab_ptr(8'd1), vint(32'd1), 10'd540);
					end
					10'd540:
						wr(ab_ptr(8'd4), VNULL, 10'd541);
					10'd541:
						if (cv_k == ab_npos)
							st <= (cv_kw ? 10'd520 : 10'd96);
						else
							rd(ab_ptr(sv2v_cast_8({24'd0, ab_lo} + cv_k)), 10'd542);
					10'd542: begin
						t[3] <= mv;
						cv_k <= cv_k + 32'd1;
						cv_ret <= 10'd541;
						st <= 10'd543;
					end
					10'd543:
						if ((ab_nblk != 32'd0) && (ab_fill != 5'd16))
							wr((adr(ab_blk) + 32'd4) + {25'd0, ab_fill, 2'b00}, t[3], 10'd544);
						else
							alloc(32'd17, 10'd546);
					10'd544: begin
						wr(adr(ab_blk), vint({27'd0, ab_fill} + 32'd1), 10'd545);
						ab_fill <= ab_fill + 5'd1;
						ab_nitems <= ab_nitems + 32'd1;
					end
					10'd545: st <= cv_ret;
					10'd546: begin
						ab_blk <= {ABI_TAG_TUPLE, al_a};
						t[2] <= {ABI_TAG_TUPLE, al_a};
						if (ab_ovf || (ab_nblk >= 32'd251))
							st <= 10'd549;
						else begin
							wr(ab_ptr(sv2v_cast_8(32'd5 + ab_nblk)), {ABI_TAG_TUPLE, al_a}, 10'd547);
							ab_nblk <= ab_nblk + 32'd1;
							ab_fill <= 5'd0;
						end
					end
					10'd547:
						wr(adr(ab_blk) + 32'd4, t[3], 10'd548);
					10'd548: begin
						wr(adr(ab_blk), vint(32'd1), 10'd545);
						ab_fill <= 5'd1;
						ab_nitems <= ab_nitems + 32'd1;
					end
					10'd549:
						if (!ab_ovf)
							alloc(32'd253, 10'd550);
						else
							rd(adr(t[5]), 10'd554);
					10'd550: begin
						t[4] <= {ABI_TAG_TUPLE, al_a};
						cv_k <= 32'd0;
						wr(al_a, vint(32'd252), 10'd551);
					end
					10'd551:
						if (cv_k == 32'd251) begin
							x0 <= 32'd252;
							wr((adr(t[4]) + 32'd4) + (32'd251 << 2), t[2], 10'd553);
						end
						else
							rd(ab_ptr(sv2v_cast_8(32'd5 + cv_k)), 10'd552);
					10'd552: begin
						wr((adr(t[4]) + 32'd4) + (cv_k << 2), mv, 10'd551);
						cv_k <= cv_k + 32'd1;
					end
					10'd553: begin
						wr(ab_ptr(8'd4), t[4], 10'd547);
						t[5] <= t[4];
						ab_ovf <= 1'b1;
						ab_nblk <= x0;
						ab_fill <= 5'd0;
					end
					10'd554: begin
						x1 <= md;
						alloc(md + 32'd2, 10'd555);
					end
					10'd555: begin
						t[4] <= {ABI_TAG_TUPLE, al_a};
						cv_k <= 32'd0;
						wr(al_a, vint(x1 + 32'd1), 10'd556);
					end
					10'd556:
						if (cv_k == x1) begin
							x0 <= ab_nblk + 32'd1;
							wr((adr(t[4]) + 32'd4) + (x1 << 2), t[2], 10'd553);
						end
						else
							rd((adr(t[5]) + 32'd4) + (cv_k << 2), 10'd557);
					10'd557: begin
						wr((adr(t[4]) + 32'd4) + (cv_k << 2), mv, 10'd556);
						cv_k <= cv_k + 32'd1;
					end
					10'd558:
						rd(ab_ptr(8'd0), 10'd559);
					10'd559: begin
						t[0] <= mv;
						if (ab_ovf) begin
							t[1] <= t[5];
							cv_k <= 32'd5;
							x1 <= 32'd256;
							st <= 10'd563;
						end
						else if (ab_nblk == 32'd0) begin
							t[1] <= {ABI_TAG_TUPLE, h_empty};
							cv_k <= 32'd5;
							x1 <= 32'd5;
							st <= 10'd563;
						end
						else
							alloc(32'd1 + ab_nblk, 10'd560);
					end
					10'd560: begin
						t[1] <= {ABI_TAG_TUPLE, al_a};
						cv_k <= 32'd0;
						wr(al_a, vint(ab_nblk), 10'd561);
					end
					10'd561:
						if (cv_k == ab_nblk) begin
							cv_k <= 32'd5;
							x1 <= 32'd5 + ab_nblk;
							st <= 10'd563;
						end
						else
							rd(ab_ptr(sv2v_cast_8(32'd5 + cv_k)), 10'd562);
					10'd562: begin
						wr((adr(t[1]) + 32'd4) + (cv_k << 2), mv, 10'd561);
						cv_k <= cv_k + 32'd1;
					end
					10'd563:
						if (cv_k == x1)
							st <= 10'd564;
						else begin
							wr(ab_ptr(cv_k[7:0]), VNULL, 10'd563);
							cv_k <= cv_k + 32'd1;
						end
					10'd564:
						if (ab_ovf)
							wr(ab_ptr(8'd4), VNULL, 10'd565);
						else
							st <= 10'd565;
					10'd565:
						wr(ab_ptr(8'd1), VNULL, 10'd60);
					10'd566: begin
						t[2] <= mv;
						alloc(32'd2, 10'd567);
					end
					10'd567: begin
						t[3] <= {ABI_TAG_TUPLE, al_a};
						wr(al_a, vint(32'd1), 10'd568);
					end
					10'd568:
						wr(al_a + 32'd4, t[2], 10'd569);
					10'd569:
						alloc(32'd2 + ab_nblk, 10'd570);
					10'd570: begin
						t[4] <= {ABI_TAG_TUPLE, al_a};
						x0 <= al_a;
						cv_k <= 32'd0;
						wr(al_a, vint(ab_nblk + 32'd1), 10'd571);
					end
					10'd571:
						wr(x0 + 32'd4, t[3], 10'd572);
					10'd572:
						if (cv_k == ab_nblk) begin
							t[1] <= t[4];
							ab_npos <= ab_npos + 32'd1;
							ab_nblk <= ab_nblk + 32'd1;
							rd(adr(ab_q) + 8, 10'd61);
						end
						else
							rd((adr(t[1]) + 32'd4) + (cv_k << 2), 10'd573);
					10'd573: begin
						wr((x0 + 32'd8) + (cv_k << 2), mv, 10'd572);
						cv_k <= cv_k + 32'd1;
					end
					10'd574:
						if (ab_lo0 != ab_lo) begin
							x1 <= {24'd0, ab_lo0} - {24'd0, ab_lo};
							cv_k <= 32'd0;
							alloc(32'd1 + ({24'd0, ab_lo0} - {24'd0, ab_lo}), 10'd575);
						end
						else
							st <= 10'd583;
					10'd575: begin
						t[3] <= {ABI_TAG_TUPLE, al_a};
						x0 <= al_a;
						wr(al_a, vint(x1), 10'd576);
					end
					10'd576:
						if (cv_k == x1)
							st <= 10'd579;
						else
							rd(ab_ptr(ab_lo + cv_k[7:0]), 10'd577);
					10'd577: begin
						wr((x0 + 32'd4) + (cv_k << 2), mv, 10'd576);
						cv_k <= cv_k + 32'd1;
					end
					10'd579: begin
						cv_k <= 32'd0;
						alloc(32'd2 + ab_nblk, 10'd578);
					end
					10'd578: begin
						t[4] <= {ABI_TAG_TUPLE, al_a};
						x0 <= al_a;
						wr(al_a, vint(ab_nblk + 32'd1), 10'd580);
					end
					10'd580:
						wr(x0 + 32'd4, t[3], 10'd581);
					10'd581:
						if (cv_k == ab_nblk) begin
							t[1] <= t[4];
							ab_npos <= ab_npos + x1;
							ab_nblk <= ab_nblk + 32'd1;
							ab_lo <= ab_lo0;
							st <= 10'd583;
						end
						else
							rd((adr(t[1]) + 32'd4) + (cv_k << 2), 10'd582);
					10'd582: begin
						wr((x0 + 32'd8) + (cv_k << 2), mv, 10'd581);
						cv_k <= cv_k + 32'd1;
					end
					10'd583:
						rd(ab_ptr(8'd0), 10'd584);
					10'd584: begin
						fflags <= fflags | FF_NOTB;
						fcont <= ABI_CONT_BIND;
						hook(ABI_HOOK_BIND_WIDE, ABI_RK_CONT, 8'd3, mv, vint(ab_npos), t[1], VNULL);
					end
					10'd450: begin
						v0 = sv2v_cast_32(n_o);
						if (v0 == ABI_UNOP_NOT) begin
							tr_v <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
							gosub(10'd438, 10'd225);
						end
						else if (numlike(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]) && (v0 <= ABI_UNOP_INVERT)) begin
							n_un <= 1'b1;
							alu_op <= (v0 == ABI_UNOP_POSITIVE ? mpy_alu_pkg_ALU_POS : (v0 == ABI_UNOP_NEGATIVE ? mpy_alu_pkg_ALU_NEG : mpy_alu_pkg_ALU_INVERT));
							t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
							t[1] <= vint(32'd0);
							st <= 10'd300;
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
							st <= 10'd118;
						end
						else if (v0 == ABI_BINOP_EXCEPTION_MATCH)
							st <= 10'd111;
						else if (v0 == ABI_BINOP_IN)
							st <= 10'd205;
						else if ((numlike(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))]) && numlike(rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))])) && ((v0 <= ABI_BINOP_NOT_EQUAL) || ((v0 >= ABI_BINOP_INPLACE_OR) && (v0 <= ABI_BINOP_POWER)))) begin
							alu_op <= ((v0 >= ABI_BINOP_INPLACE_OR) && (v0 < ABI_BINOP_OR) ? sv2v_cast_6(v0 + 32'd13) : sv2v_cast_6(v0));
							st <= 10'd300;
						end
						else if ((v0 == ABI_BINOP_EQUAL) || (v0 == ABI_BINOP_NOT_EQUAL))
							st <= 10'd108;
						else
							st <= 10'd33;
					end
					10'd33: begin
						sp <= sp - 7'd2;
						hook(ABI_HOOK_BINOP, ABI_RK_PUSH, 8'd3, vint(sv2v_cast_32(n_o)), t[0], t[1], VNULL);
					end
					10'd108: begin
						vb = sv2v_cast_32(n_o) == ABI_BINOP_NOT_EQUAL;
						if (((t[0] == t[1]) && (tg(t[0]) != ABI_TAG_OBJECT)) && (tg(t[0]) != ABI_TAG_COMPLEX)) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= vbool(!vb);
							sp <= sp - 7'd1;
							st <= 10'd118;
						end
						else if (strlike(t[0]) && strlike(t[1])) begin
							se_a <= t[0];
							se_b <= t[1];
							gosub_scr(SCR_SE, 10'd435, 10'd109);
						end
						else if (((strlike(t[0]) || strlike(t[1])) || ((tg(t[0]) == ABI_TAG_CONTROL) && (tg(t[1]) != ABI_TAG_OBJECT))) || ((tg(t[1]) == ABI_TAG_CONTROL) && (tg(t[0]) != ABI_TAG_OBJECT))) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= vbool(vb);
							sp <= sp - 7'd1;
							st <= 10'd118;
						end
						else
							st <= 10'd33;
					end
					10'd109: begin
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= vbool(se_eq ^ (sv2v_cast_32(n_o) == ABI_BINOP_NOT_EQUAL));
						sp <= sp - 7'd1;
						st <= 10'd118;
					end
					10'd205:
						if (is_mut(t[1], ABI_MUT_DICT) || is_mut(t[1], ABI_MUT_SET))
							lookup(t[1], t[0], VNULL, LK_FIND, is_mut(t[1], ABI_MUT_SET), 10'd206);
						else
							st <= 10'd33;
					10'd206:
						if (lk_cx)
							st <= 10'd33;
						else begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= vbool(lk_found);
							sp <= sp - 7'd1;
							st <= 10'd118;
						end
					10'd111:
						if (tg(t[0]) != ABI_TAG_OBJECT)
							st <= 10'd33;
						else
							rd(adr(t[0]) + 4, 10'd113);
					10'd113: begin
						is_t <= mv;
						if (tg(t[1]) == ABI_TAG_OBJECT) begin
							is_c <= t[1];
							gosub(10'd207, 10'd112);
						end
						else if (tg(t[1]) == ABI_TAG_TUPLE)
							rd(adr(t[1]), 10'd116);
						else
							st <= 10'd33;
					end
					10'd112: begin
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= vbool(is_r);
						sp <= sp - 7'd1;
						st <= 10'd118;
					end
					10'd116: begin
						x4 <= md;
						gi <= 32'd0;
						st <= 10'd115;
					end
					10'd115:
						if (gi == x4) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= VFALSE;
							sp <= sp - 7'd1;
							st <= 10'd118;
						end
						else
							rd((adr(t[1]) + 4) + (gi << 2), 10'd114);
					10'd114: begin
						is_c <= mv;
						gosub(10'd207, 10'd117);
					end
					10'd117:
						if (is_r) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= VTRUE;
							sp <= sp - 7'd1;
							st <= 10'd118;
						end
						else begin
							gi <= gi + 32'd1;
							st <= 10'd115;
						end
					10'd300: begin
						na_f <= tg(t[0]) == ABI_TAG_FLOAT;
						if (tg(t[0]) == ABI_TAG_INT64)
							rd(adr(t[0]), 10'd302);
						else begin
							na <= sx64(ival(t[0]));
							st <= 10'd303;
						end
					end
					10'd302: begin
						na[31:0] <= md;
						rd(adr(t[0]) + 4, 10'd301);
					end
					10'd301: begin
						na[63:32] <= md;
						st <= 10'd303;
					end
					10'd303: begin
						nb_f <= tg(t[1]) == ABI_TAG_FLOAT;
						if (tg(t[1]) == ABI_TAG_INT64)
							rd(adr(t[1]), 10'd305);
						else begin
							nb <= sx64(ival(t[1]));
							st <= 10'd307;
						end
					end
					10'd305: begin
						nb[31:0] <= md;
						rd(adr(t[1]) + 4, 10'd304);
					end
					10'd304: begin
						nb[63:32] <= md;
						st <= 10'd307;
					end
					10'd307: begin
						n_small <= ((!na_f && !nb_f) && fits31(na)) && fits31(nb);
						alu_start <= 1'b1;
						if (cfg_aalu && aalu_safe(alu_op, n_un, na_f, nb_f, na, nb)) begin
							aalu_pend <= 1'b1;
							aalu_slot <= rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2));
							sp <= sp - 7'd1;
							st <= 10'd118;
						end
						else
							st <= 10'd309;
					end
					10'd309:
						if (alu_done)
							case (alu_err)
								mpy_alu_pkg_AE_NONE:
									if (alu_kind == mpy_alu_pkg_AK_BOOL) begin
										t[2] <= vbool(alu_res[0]);
										st <= 10'd308;
									end
									else if (alu_kind == mpy_alu_pkg_AK_FLOAT) begin
										t[2] <= {ABI_TAG_FLOAT, alu_res[31:0]};
										st <= 10'd308;
									end
									else if (fits32(alu_res)) begin
										t[2] <= vint(alu_res[31:0]);
										st <= 10'd308;
									end
									else
										alloc(32'd2, 10'd306);
								mpy_alu_pkg_AE_ZERO_DIV:
									raise_msg(ABI_MSG_DIV_ZERO);
								mpy_alu_pkg_AE_OVERFLOW:
									raise_msg(ABI_MSG_OVERFLOW);
								mpy_alu_pkg_AE_NEG_SHIFT:
									raise_msg(ABI_MSG_NEG_SHIFT);
								default:
									if (n_un) begin
										sp <= sp - 7'd1;
										hook(ABI_HOOK_UNOP, ABI_RK_PUSH, 8'd2, vint(sv2v_cast_32(n_o)), t[0], VNULL, VNULL);
									end
									else
										st <= 10'd33;
							endcase
					10'd306: begin
						wb_v[0] <= vint(alu_res[31:0]);
						wb_v[1] <= vint(alu_res[63:32]);
						t[2] <= {ABI_TAG_INT64, al_a};
						wblock(al_a, 4'd2, 10'd308);
					end
					10'd637: begin
						rf[aalu_slot] <= (alu_kind == mpy_alu_pkg_AK_BOOL ? vbool(alu_res[0]) : (alu_kind == mpy_alu_pkg_AK_FLOAT ? {ABI_TAG_FLOAT, alu_res[31:0]} : vint(alu_res[31:0])));
						aalu_pend <= 1'b0;
						aalu_ready <= 1'b0;
						st <= aalu_ret;
					end
					10'd308: begin
						if (n_un)
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= t[2];
						else begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))] <= t[2];
							sp <= sp - 7'd1;
						end
						st <= 10'd118;
					end
					10'd290:
						if (ab_nkw != 8'd0)
							st <= 10'd291;
						else
							rd(ab_ptr(ab_lo), 10'd587);
					10'd587: begin
						ab_q <= mv;
						v0 = sv2v_cast_32(ab_pe - ab_lo);
						v1 = mv[31:0];
						case (nid)
							ABI_N_LEN:
								if (v0 != 32'd1)
									st <= 10'd291;
								else if (strlike(mv) || (tg(mv) == ABI_TAG_BYTES)) begin
									si_v <= mv;
									gosub(10'd415, 10'd335);
								end
								else if ((((tg(mv) == ABI_TAG_TUPLE) || is_mut(mv, ABI_MUT_LIST)) || is_mut(mv, ABI_MUT_DICT)) || is_mut(mv, ABI_MUT_SET))
									rd(adr(mv), 10'd341);
								else
									st <= 10'd291;
							ABI_N_ISINSTANCE:
								if (v0 != 32'd2)
									st <= 10'd291;
								else
									rd(ab_ptr(ab_lo + 8'd1), 10'd589);
							ABI_N_ID:
								deliver(vint(v1), crk);
							ABI_N_WR, ABI_N_WE: begin
								x4 <= ABI_SIM_BASE + (4 * (nid == ABI_N_WR ? ABI_SIM_STDOUT : ABI_SIM_STDERR));
								if (tg(mv) == ABI_TAG_INT)
									wr(ABI_SIM_BASE + (4 * (nid == ABI_N_WR ? ABI_SIM_STDOUT : ABI_SIM_STDERR)), mv, 10'd337);
								else begin
									si_v <= mv;
									gosub(10'd415, 10'd353);
								end
							end
							ABI_N_HALT:
								halt((v1 == 32'd0 ? ABI_HALT_CLEAN : ABI_HALT_SYSEXIT), v1);
							ABI_N_TAG:
								deliver(vint({28'd0, tg(mv)}), crk);
							ABI_N_PAY:
								deliver(vint(v1), crk);
							ABI_N_MK:
								rd(ab_ptr(ab_lo + 8'd1), 10'd590);
							ABI_N_LD:
								rd(ab_ptr(ab_lo + 8'd1), 10'd591);
							ABI_N_ST:
								rd(ab_ptr(ab_lo + 8'd1), 10'd592);
							ABI_N_PEEK8:
								rd(ab_ptr(ab_lo + 8'd1), 10'd594);
							ABI_N_POKE8:
								rd(ab_ptr(ab_lo + 8'd1), 10'd595);
							ABI_N_PEEK32:
								rd(v1, 10'd341);
							ABI_N_ALLOC:
								alloc(v1, 10'd310);
							ABI_N_TYPEOF: begin
								ty_v <= mv;
								gosub(10'd445, 10'd350);
							end
							ABI_N_CALLNS:
								if (tg(mv) == ABI_TAG_INT)
									rd(ab_ptr(ab_lo + 8'd1), 10'd597);
								else
									wr(ab_ptr(8'd0), mv, 10'd598);
							ABI_N_WCOPY:
								rd(ab_ptr(ab_lo + 8'd1), 10'd600);
							ABI_N_BCOPY:
								rd(ab_ptr(ab_lo + 8'd2), 10'd605);
							ABI_N_STRNEW:
								alloc(32'd3 + ((v1 + 32'd3) >> 2), 10'd348);
							ABI_N_STRFIN:
								rd(adr(mv), 10'd343);
							ABI_N_LOOKUP:
								rd(ab_ptr(ab_lo + 8'd1), 10'd606);
							ABI_N_TICKS:
								deliver(vint({2'b00, cyc[29:0]}), crk);
							ABI_N_GC:
								gosub(10'd181, 10'd337);
							ABI_N_GCINFO:
								deliver(vint((v1 == 32'd0 ? gc_free_i << 4 : (v1 == 32'd1 ? gc_total_i << 4 : gc_collections_i))), crk);
							ABI_N_FTOI: begin
								t[0] <= mv;
								t[1] <= vint(32'd0);
								n_un <= 1'b1;
								alu_op <= mpy_alu_pkg_ALU_F2I;
								st <= 10'd323;
							end
							ABI_N_INEXT:
								if (tg(mv) != ABI_TAG_ITER)
									deliver(VNULL, crk);
								else begin
									t[3] <= mv;
									i0 <= 8'd0;
									st <= 10'd328;
								end
							ABI_N_GRESUME:
								if (v0 != 32'd3)
									st <= 10'd291;
								else begin
									r_rk <= crk;
									t[0] <= mv;
									rd(ab_ptr(ab_lo + 8'd1), 10'd607);
								end
							ABI_N_BCMP: begin
								si_v <= mv;
								gosub(10'd415, 10'd318);
							end
							ABI_N_HASH: begin
								hk <= mv;
								gosub(10'd196, 10'd326);
							end
							ABI_N_DATA: begin
								si_v <= mv;
								gosub(10'd100, 10'd321);
							end
							ABI_N_FGET:
								if (fprev == 32'd0)
									deliver(VNULL, crk);
								else begin
									x3 <= v1;
									rd(fprev + (v1 << 2), 10'd322);
								end
							ABI_N_FLOC:
								if (fprev == 32'd0)
									deliver(VNULL, crk);
								else
									rd((fprev + 32'd64) + (v1 << 2), 10'd342);
							ABI_N_QXSET: begin
								h_qext <= mv[31:0];
								rd(ab_ptr(ab_lo + 8'd1), 10'd610);
							end
							ABI_N_SLEN:
								if ((tg(mv) == ABI_TAG_MUT) || (tg(mv) == ABI_TAG_TUPLE))
									rd(adr(mv), 10'd341);
								else begin
									si_v <= mv;
									gosub(10'd415, 10'd335);
								end
							ABI_N_LIST_APPEND:
								if ((v0 != 32'd2) || !is_mut(mv, ABI_MUT_LIST))
									st <= 10'd291;
								else begin
									t[2] <= mv;
									rd(ab_ptr(ab_lo + 8'd1), 10'd609);
								end
							ABI_N_OBJECT_INIT:
								if (v0 != 32'd1)
									st <= 10'd291;
								else
									deliver(VNONE, crk);
							ABI_N_BASEEXCEPTION_INIT:
								if ((v0 < 32'd1) || (tg(mv) != ABI_TAG_OBJECT))
									st <= 10'd291;
								else begin
									t[0] <= mv;
									tb_src <= 1'b0;
									tb_nz <= 1'b0;
									tb_from <= ab_lo + 8'd1;
									tb_n <= (ab_pe - ab_lo) - 8'd1;
									gosub(10'd442, 10'd320);
								end
							ABI_N_NEW_RANGE:
								if ((v0 < 32'd2) || (v0 > 32'd4))
									st <= 10'd291;
								else begin
									x0 <= v0;
									rd(ab_ptr(ab_lo + 8'd1), 10'd611);
								end
							ABI_N_NEW_OBJECT:
								if (v0 != 32'd1)
									st <= 10'd291;
								else begin
									t[0] <= mv;
									alloc(32'd3, 10'd338);
								end
							default: st <= 10'd291;
						endcase
					end
					10'd589:
						if (tg(mv) != ABI_TAG_OBJECT)
							st <= 10'd291;
						else begin
							ab_s[0] <= mv;
							rd(adr(mv), 10'd332);
						end
					10'd590:
						deliver({ab_q[3:0], mv[31:0]}, crk);
					10'd591:
						rd(padr(ab_q) + (mv[31:0] << 2), 10'd342);
					10'd592: begin
						x0 <= mv[31:0];
						rd(ab_ptr(ab_lo + 8'd2), 10'd593);
					end
					10'd593:
						wr(padr(ab_q) + (x0 << 2), mv, 10'd337);
					10'd594: begin
						v2 = padr(ab_q) + mv[31:0];
						x3 <= v2;
						rd({v2[31:2], 2'b00}, 10'd339);
					end
					10'd595: begin
						x0 <= mv[31:0];
						rd(ab_ptr(ab_lo + 8'd2), 10'd596);
					end
					10'd596:
						wrb(padr(ab_q) + x0, mv[7:0], 10'd337);
					10'd597: begin
						c_ismod <= 1'b1;
						c_md <= ab_q[31:0];
						cl_loc <= mv;
						ab_lo <= 8'd32;
						ab_pe <= 8'd32;
						rd(ab_q[31:0] + 12, 10'd92);
					end
					10'd598:
						rd(ab_ptr(ab_lo + 8'd1), 10'd599);
					10'd599: begin
						cl_loc <= mv;
						ab_lo <= 8'd32;
						ab_pe <= 8'd32;
						st <= 10'd60;
					end
					10'd600: begin
						x1 <= mv[31:0];
						rd(ab_ptr(ab_lo + 8'd2), 10'd601);
					end
					10'd601: begin
						ab_s[0] <= mv;
						rd(ab_ptr(ab_lo + 8'd3), 10'd602);
					end
					10'd602: begin
						x2 <= mv[31:0];
						rd(ab_ptr(ab_lo + 8'd4), 10'd603);
					end
					10'd603: begin
						x3 <= mv[31:0];
						if (cfg_ca)
							st <= 10'd635;
						else if (scr_id != SCR_LA)
							scr_adopt(SCR_LA, 10'd604);
						else
							st <= 10'd604;
					end
					10'd635:
						if (x3 == 32'd0)
							deliver(VNONE, crk);
						else if (ca_ok) begin
							ca_ship(padr(ab_q) + (x1 << 2), padr(ab_s[0]) + (x2 << 2), x3);
							deliver(VNONE, crk);
						end
					10'd604: begin
						v2 = padr(ab_q) + (x1 << 2);
						v3 = padr(ab_s[0]) + (x2 << 2);
						sA[3] <= v2;
						sA[2] <= v3;
						sA[0] <= x3;
						b1 <= v2 > v3;
						sA[4] <= 32'd0;
						st <= 10'd351;
					end
					10'd605: begin
						si_v <= mv;
						gosub(10'd100, 10'd312);
					end
					10'd606:
						lookup(ab_q, mv, VNULL, LK_FIND, is_mut(ab_q, ABI_MUT_SET), 10'd336);
					10'd607: begin
						t[1] <= mv;
						rd(ab_ptr(ab_lo + 8'd2), 10'd608);
					end
					10'd608: begin
						t[2] <= mv;
						st <= 10'd152;
					end
					10'd609: begin
						t[3] <= mv;
						gosub(10'd233, 10'd337);
					end
					10'd610: begin
						h_qextn <= mv[31:0];
						deliver(VNONE, crk);
					end
					10'd611:
						if (!intlike(mv))
							st <= 10'd291;
						else if (x0 == 32'd2) begin
							wb_v[0] <= vint(32'd0);
							wb_v[1] <= vint(ival(mv));
							wb_v[2] <= vint(32'd1);
							alloc(32'd3, 10'd340);
						end
						else begin
							ab_s[0] <= mv;
							rd(ab_ptr(ab_lo + 8'd2), 10'd612);
						end
					10'd612:
						if (!intlike(mv))
							st <= 10'd291;
						else if (x0 == 32'd3) begin
							wb_v[0] <= vint(ival(ab_s[0]));
							wb_v[1] <= vint(ival(mv));
							wb_v[2] <= vint(32'd1);
							alloc(32'd3, 10'd340);
						end
						else begin
							ab_s[1] <= mv;
							rd(ab_ptr(ab_lo + 8'd3), 10'd613);
						end
					10'd613:
						if (!intlike(mv))
							st <= 10'd291;
						else if (ival(mv) == 32'd0)
							raise_msg(ABI_MSG_ZERO_STEP);
						else begin
							wb_v[0] <= vint(ival(ab_s[0]));
							wb_v[1] <= vint(ival(ab_s[1]));
							wb_v[2] <= vint(ival(mv));
							alloc(32'd3, 10'd340);
						end
					10'd291:
						rd(ab_ptr(8'd0), 10'd588);
					10'd588: begin
						ab_q <= mv;
						rd(adr(mv) + 12, 10'd292);
					end
					10'd292:
						if (mv == VNULL)
							rd(adr(ab_q) + 16, 10'd293);
						else
							wr(ab_ptr(8'd0), mv, 10'd60);
					10'd293:
						raise_err(ABI_ERR_BUILTIN_ARGS, mv, vint(sv2v_cast_32(ab_pe - ab_lo)));
					10'd337:
						deliver(VNONE, crk);
					10'd341:
						deliver(vint(md), crk);
					10'd342:
						deliver(mv, crk);
					10'd335:
						if ((si_na && (tg(si_v) != ABI_TAG_BYTES)) && (nid == ABI_N_LEN))
							st <= 10'd291;
						else
							deliver(vint(si_len), crk);
					10'd332:
						if (md != ABI_OB_TYPE)
							st <= 10'd291;
						else begin
							ty_v <= ab_q;
							is_c <= ab_s[0];
							gosub(10'd445, 10'd333);
						end
					10'd333: begin
						is_t <= ty_t;
						gosub(10'd207, 10'd334);
					end
					10'd334:
						deliver(vbool(is_r), crk);
					10'd353: begin
						x2 <= si_addr;
						x1 <= 32'd0;
						st <= 10'd355;
					end
					10'd355:
						if (x1 == si_len)
							deliver(VNONE, crk);
						else
							rd(x2 + {x1[31:2], 2'b00}, 10'd354);
					10'd354: begin
						wr(x4, vint({24'd0, byte_of(md, x1[1:0])}), 10'd355);
						x1 <= x1 + 32'd1;
					end
					10'd339:
						deliver(vint({24'd0, byte_of(md, x3[1:0])}), crk);
					10'd310:
						rd(ab_ptr(ab_lo + 8'd1), 10'd614);
					10'd614: begin
						ab_q <= mv;
						rd(ab_ptr(ab_lo + 8'd2), 10'd615);
					end
					10'd615:
						deliver({ab_q[3:0], al_a | mv[31:0]}, crk);
					10'd350:
						deliver(ty_t, crk);
					10'd351:
						if (sA[4] == sA[0])
							deliver(VNONE, crk);
						else
							rd((b1 ? sA[2] + (((sA[0] - 32'd1) - sA[4]) << 2) : sA[2] + (sA[4] << 2)), 10'd352);
					10'd352: begin
						wr((b1 ? sA[3] + (((sA[0] - 32'd1) - sA[4]) << 2) : sA[3] + (sA[4] << 2)), mv, 10'd351);
						sA[4] <= sA[4] + 32'd1;
					end
					10'd312:
						if (scr_id != SCR_LA)
							scr_adopt(SCR_LA, 10'd312);
						else
							rd(ab_ptr(ab_lo + 8'd3), 10'd616);
					10'd616: begin
						sA[2] <= si_addr + mv[31:0];
						si_v <= ab_q;
						gosub(10'd100, 10'd313);
					end
					10'd313:
						rd(ab_ptr(ab_lo + 8'd1), 10'd617);
					10'd617: begin
						x0 <= mv[31:0];
						rd(ab_ptr(ab_lo + 8'd4), 10'd618);
					end
					10'd618: begin
						sA[3] <= si_addr + x0;
						sA[0] <= mv[31:0];
						b1 <= (si_addr + x0) > sA[2];
						sA[4] <= 32'd0;
						st <= 10'd311;
					end
					10'd311:
						if (sA[4] == sA[0])
							deliver(VNONE, crk);
						else begin
							v2 = (b1 ? ((sA[2] + sA[0]) - 32'd1) - sA[4] : sA[2] + sA[4]);
							x3 <= v2;
							rd({v2[31:2], 2'b00}, 10'd314);
						end
					10'd314: begin
						wrb((b1 ? ((sA[3] + sA[0]) - 32'd1) - sA[4] : sA[3] + sA[4]), byte_of(md, x3[1:0]), 10'd311);
						sA[4] <= sA[4] + 32'd1;
					end
					10'd348:
						rd(ab_ptr(ab_lo), 10'd620);
					10'd620: begin
						wb_v[0] <= vint(mv[31:0]);
						wb_v[1] <= vint(32'd0);
						wb_v[2] <= {ABI_TAG_CONT, al_a + 32'd12};
						rd(ab_ptr(ab_lo + 8'd1), 10'd621);
					end
					10'd621: begin
						t[0] <= {mv[3:0], al_a};
						wblock(al_a, 4'd3, 10'd349);
					end
					10'd349:
						deliver(t[0], crk);
					10'd343:
						if ((scr_id == SCR_NONE) || (scr_id == SCR_LA)) begin
							scr_id <= SCR_LA;
							sA[0] <= md;
							rd(adr(ab_q) + 8, 10'd344);
						end
						else
							wr(scr_addr(SCR_LA, 4'd0), {4'd0, md}, 10'd629);
					10'd629:
						if (scr_id != SCR_LA)
							scr_ensure(SCR_LA, 10'd629);
						else
							rd(adr(ab_q) + 8, 10'd344);
					10'd344: begin
						sA[2] <= md;
						sA[4] <= 32'd0;
						x2 <= 32'd5381;
						b1 <= 1'b0;
						st <= 10'd347;
					end
					10'd347:
						if (sA[4] == sA[0]) begin
							v3 = {16'd0, x2[15:0]};
							if (v3 == 32'd0)
								v3 = 32'd1;
							wr(adr(ab_q) + 4, vint(v3 | (b1 ? ABI_STR_NONASCII : 32'd0)), 10'd345);
						end
						else
							rd(sA[2] + {sA[4][31:2], 2'b00}, 10'd346);
					10'd346: begin
						v3 = {24'd0, byte_of(md, sA[4][1:0])};
						x2 <= (x2 * 32'd33) ^ v3;
						if (v3[7])
							b1 <= 1'b1;
						sA[4] <= sA[4] + 32'd1;
						st <= 10'd347;
					end
					10'd345:
						deliver(ab_q, crk);
					10'd336:
						deliver((lk_cx ? VSTOP : (lk_found ? lk_res : VNULL)), crk);
					10'd323: begin
						na_f <= 1'b1;
						na <= {32'd0, t[0][31:0]};
						nb_f <= 1'b0;
						nb <= 64'd0;
						n_small <= 1'b0;
						alu_start <= 1'b1;
						st <= 10'd325;
					end
					10'd325:
						if (alu_done) begin
							if (alu_err != mpy_alu_pkg_AE_NONE)
								deliver(VSTOP, crk);
							else if (fits32(alu_res))
								deliver(vint(alu_res[31:0]), crk);
							else
								alloc(32'd2, 10'd324);
						end
					10'd324: begin
						wb_v[0] <= vint(alu_res[31:0]);
						wb_v[1] <= vint(alu_res[63:32]);
						t[0] <= {ABI_TAG_INT64, al_a};
						wblock(al_a, 4'd2, 10'd349);
					end
					10'd328:
						if (((i0 == 8'd0) && (scr_id != SCR_NONE)) && (scr_id != SCR_IT))
							scr_go_store(scr_id, 10'd328);
						else begin
							if (scr_id != SCR_IT)
								scr_id <= SCR_IT;
							if (i0 == 8'd4) begin
								it_h <= 1'b1;
								gosub(10'd212, 10'd330);
							end
							else
								rd(adr(t[3]) + (4 * i0), 10'd329);
						end
					10'd329: begin
						sV[i0[1:0]] <= mv;
						i0 <= i0 + 8'd1;
						st <= 10'd328;
					end
					10'd330:
						if (it_py)
							deliver(VNULL, crk);
						else
							wr(adr(t[3]), sV[0], 10'd331);
					10'd331:
						wr(adr(t[3]) + 4, sV[1], 10'd327);
					10'd327:
						deliver((it_stop ? VSTOP : it_val), crk);
					10'd318:
						if (scr_id != SCR_SE)
							scr_ensure(SCR_SE, 10'd318);
						else begin
							sA[0] <= si_len;
							sA[2] <= si_addr;
							rd(ab_ptr(ab_lo + 8'd1), 10'd619);
						end
					10'd619: begin
						si_v <= mv;
						gosub(10'd415, 10'd319);
					end
					10'd319: begin
						sA[3] <= si_addr;
						sA[6] <= si_len;
						sA[7] <= 32'd0;
						st <= 10'd631;
					end
					10'd631:
						wr(scr_addr(SCR_LA, 4'd0), {4'd0, sA[6]}, 10'd632);
					10'd632:
						wr(scr_addr(SCR_LA, 4'd4), {4'd0, sA[7]}, 10'd317);
					10'd317:
						if ((sA[7] == sA[0]) || (sA[7] == sA[6])) begin
							t[7] <= vint(sA[0] - sA[6]);
							d_rk <= crk;
							st <= 10'd634;
						end
						else
							rd(sA[2] + {sA[7][31:2], 2'b00}, 10'd315);
					10'd315: begin
						sA[5] <= md;
						rd(sA[3] + {sA[7][31:2], 2'b00}, 10'd316);
					end
					10'd316:
						if (byte_of(sA[5], sA[7][1:0]) != byte_of(md, sA[7][1:0])) begin
							t[7] <= vint({24'd0, byte_of(sA[5], sA[7][1:0])} - {24'd0, byte_of(md, sA[7][1:0])});
							d_rk <= crk;
							st <= 10'd634;
						end
						else begin
							sA[7] <= sA[7] + 32'd1;
							st <= 10'd633;
						end
					10'd633:
						wr(scr_addr(SCR_LA, 4'd4), {4'd0, sA[7]}, 10'd317);
					10'd634:
						wr(scr_addr(SCR_LA, 4'd4), {4'd0, sA[7]}, 10'd105);
					10'd326:
						deliver((hok ? vint(hh) : VSTOP), crk);
					10'd321:
						deliver(vint(si_addr), crk);
					10'd322:
						if ((x3 >= 32'd6) && (x3 <= 32'd11))
							deliver(mv, crk);
						else
							deliver(vint(md), crk);
					10'd320:
						wr(adr(t[0]) + 8, tb_v, 10'd337);
					10'd340: begin
						t[0] <= {ABI_TAG_RANGE, al_a};
						wblock(al_a, 4'd3, 10'd349);
					end
					10'd338: begin
						wb_v[0] <= vint(ABI_OB_INSTANCE);
						wb_v[1] <= t[0];
						wb_v[2] <= VNULL;
						t[0] <= vobj(al_a);
						wblock(al_a, 4'd3, 10'd349);
					end
					10'd132:
						rd(adr(gen) + 20, 10'd133);
					10'd133: begin
						x4 <= fbase;
						x0 <= md;
						spill_to_img <= 1'b1;
						if (lc_dirty_any) begin
							lc_fi <= 4'd0;
							lc_fl_ret <= 10'd134;
							st <= 10'd470;
						end
						else
							st <= 10'd134;
					end
					10'd134: begin
						fbase <= x0;
						gosub(10'd423, 10'd135);
					end
					10'd135: begin
						fbase <= x4;
						spill_to_img <= 1'b0;
						ret;
					end
					10'd136:
						rd(TT + (4 * ABI_T_GENERATOR), 10'd137);
					10'd137: begin
						t[3] <= mv;
						alloc(32'd6, 10'd138);
					end
					10'd138: begin
						t[0] <= vobj(al_a);
						alloc(((32'd17 + sv2v_cast_32(nloc)) + (32'd3 * {27'd0, nexc})) + 32'd64, 10'd139);
					end
					10'd139: begin
						wb_v[0] <= vint(ABI_OB_GENERATOR);
						wb_v[1] <= t[3];
						wb_v[2] <= fun;
						wb_v[3] <= vint(32'd0);
						wb_v[4] <= VNONE;
						wb_v[5] <= {ABI_TAG_CONT, al_a};
						gen <= t[0];
						wblock(adr(t[0]), 4'd6, 10'd140);
					end
					10'd140:
						gosub(10'd132, 10'd141);
					10'd141: begin
						t[7] <= gen;
						st <= 10'd359;
					end
					10'd148:
						wr(adr(gen) + 12, vint(32'd0), 10'd149);
					10'd149:
						gosub(10'd132, 10'd150);
					10'd150: begin
						fl_base <= fprev;
						gosub(10'd119, 10'd151);
					end
					10'd151:
						if (fflags & FF_YFAST) begin
							fflags <= fflags & ~FF_YFAST;
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= t[7];
							st <= 10'd118;
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
							wr(ab_ptr(8'd0), ty_stop, 10'd585);
						end
					10'd585:
						wr(ab_ptr(8'd32), t[7], 10'd60);
					10'd142:
						wr(adr(gen) + 12, vint(32'd0), 10'd143);
					10'd143:
						gosub(10'd132, 10'd144);
					10'd144:
						rd(adr(xc) + 4, 10'd145);
					10'd145: begin
						is_t <= mv;
						is_c <= ty_stop;
						gosub(10'd207, 10'd146);
					end
					10'd146: begin
						b0 <= is_r;
						rx_crk <= frk;
						fl_base <= fprev;
						gosub(10'd119, 10'd147);
					end
					10'd147: begin
						fflags <= fflags & ~FF_YFAST;
						if (b0)
							raise_msg(ABI_MSG_GEN_STOP);
						else begin
							rx_from <= 1'b1;
							st <= 10'd358;
						end
					end
					10'd152:
						rd(adr(t[0]) + 20, 10'd153);
					10'd153: begin
						x4 <= md;
						rd(md + 8, 10'd154);
					end
					10'd154:
						if (md == 32'd0) begin
							if (fflags & FF_YFAST) begin
								fflags <= fflags & ~FF_YFAST;
								rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= VNONE;
								st <= 10'd118;
							end
							else
								raise_msg(ABI_MSG_STOP_ITER);
						end
						else
							rd(adr(t[0]) + 12, 10'd155);
					10'd155:
						if (md[0]) begin
							fflags <= fflags & ~FF_YFAST;
							raise_msg(ABI_MSG_GEN_RUNNING);
						end
						else
							rd(adr(t[0]) + 16, 10'd156);
					10'd156: begin
						if (mv != VNONE)
							t[2] <= mv;
						rd(x4 + 16, 10'd157);
					end
					10'd157: begin
						x1 <= md;
						rd(x4 + 20, 10'd158);
					end
					10'd158: begin
						v0 = (noframe ? ABI_FRAME_BASE : ftop + {23'd0, sp, 2'b00});
						v1 = v0 + (((32'd17 + {25'd0, x1[22:16]}) + (32'd3 * {27'd0, md[20:16]})) << 2);
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
							wr(adr(t[0]) + 16, VNONE, 10'd159);
						end
					end
					10'd159:
						wr(adr(t[0]) + 12, vint(32'd1), 10'd164);
					10'd164:
						if (noframe)
							st <= 10'd161;
						else
							gosub(10'd423, 10'd161);
					10'd161: begin
						fprev <= (noframe ? 32'd0 : fbase);
						fbase <= x3;
						noframe <= 1'b0;
						fl_base <= x4;
						fl_img <= 1'b1;
						gosub(10'd119, 10'd160);
					end
					10'd160: begin
						frk <= r_rk;
						gen <= t[0];
						if (b1)
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= t[1];
						if (t[2] != VNONE)
							st <= 10'd163;
						else begin
							inj <= VNONE;
							st <= 10'd118;
						end
					end
					10'd163:
						rd({pc[31:2], 2'b00}, 10'd162);
					10'd162:
						if (byte_of(md, pc[1:0]) == 8'h68) begin
							inj <= t[2];
							st <= 10'd118;
						end
						else begin
							inj <= VNONE;
							t[0] <= t[2];
							op <= 8'h65;
							op_pc <= pc;
							st <= 10'd382;
						end
					10'd165: begin
						t[7] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))];
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= VNONE;
						wr(adr(gen) + 12, vint(32'd0), 10'd166);
					end
					10'd166:
						gosub(10'd132, 10'd167);
					10'd167: st <= 10'd359;
					10'd169:
						if (md == ABI_OB_GENERATOR) begin
							fflags <= fflags | FF_YFAST;
							t[0] <= rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))];
							t[1] <= VNONE;
							t[2] <= VNONE;
							r_rk <= ABI_RK_CONT;
							fcont <= ABI_CONT_YFROM;
							sp <= sp - 7'd1;
							st <= 10'd152;
						end
						else begin
							aux <= inj;
							fcont <= ABI_CONT_YFROM;
							hook(ABI_HOOK_YFROM, ABI_RK_CONT, 8'd3, rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd2))], (inj != VNONE ? VNONE : rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))]), (inj != VNONE ? inj : VNONE), VNULL);
							inj <= VNONE;
							sp <= sp - 7'd1;
						end
					10'd168: begin
						b0 <= mv == VTRUE;
						rd(adr(t[7]) + 8, 10'd170);
					end
					10'd170: begin
						fcont <= 8'd0;
						if (b0) begin
							aux <= VNONE;
							push(mv);
							pc <= op_pc;
							st <= 10'd165;
						end
						else begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= mv;
							if (aux != VNONE)
								st <= 10'd171;
							else
								st <= 10'd118;
						end
					end
					10'd171:
						if (tg(aux) != ABI_TAG_OBJECT) begin
							aux <= VNONE;
							st <= 10'd118;
						end
						else
							rd(adr(aux), 10'd172);
					10'd172:
						if (md == ABI_OB_EXCEPTION)
							rd(adr(aux) + 4, 10'd173);
						else if (md == ABI_OB_TYPE) begin
							is_t <= aux;
							rd(TT + (4 * ABI_T_GENERATOREXIT), 10'd174);
						end
						else begin
							aux <= VNONE;
							st <= 10'd118;
						end
					10'd173: begin
						is_t <= mv;
						rd(TT + (4 * ABI_T_GENERATOREXIT), 10'd174);
					end
					10'd174: begin
						is_c <= mv;
						gosub(10'd207, 10'd175);
					end
					10'd175: begin
						if (is_r) begin
							t[0] <= aux;
							st <= 10'd382;
						end
						else
							st <= 10'd118;
						aux <= VNONE;
					end
					10'd176: begin
						is_t <= mv;
						is_c <= ty_stop;
						fcont <= 8'd0;
						gosub(10'd207, 10'd177);
					end
					10'd177:
						if (is_r)
							rd(adr(xc) + 8, 10'd178);
						else begin
							sp <= sp - 7'd1;
							st <= 10'd389;
						end
					10'd178: begin
						t[6] <= mv;
						rd(adr(mv), 10'd179);
					end
					10'd179:
						if (md == 32'd0) begin
							rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= VNONE;
							st <= 10'd118;
						end
						else
							rd(adr(t[6]) + 4, 10'd180);
					10'd180: begin
						rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(sp - 7'd1))] <= mv;
						st <= 10'd118;
					end
					10'd460:
						if (wb_i == wb_n)
							ret;
						else begin
							wr(wb_a + (4 * wb_i), wb_v[wb_i[2:0]], 10'd460);
							wb_i <= wb_i + 4'd1;
						end
					10'd3: begin
						gc_alloc_req <= 1'b1;
						al_gc <= 1'b0;
						st <= 10'd8;
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
								gosub(10'd181, 10'd7);
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
									wr(EMERG_ADDR + 20, vint(al_n << 2), 10'd4);
							end
						end
					10'd7: begin
						gc_alloc_req <= 1'b1;
						st <= 10'd8;
					end
					10'd4:
						wr(EMERG_ADDR + 12, VNULL, 10'd5);
					10'd5:
						raise_val(vobj(EMERG_ADDR));
					10'd6:
						if (cv_k == x1)
							wr(EMERG_ADDR + 20, vint(al_n << 2), 10'd4);
						else begin
							wr(ab_ptr(cv_k[7:0]), VNULL, 10'd6);
							cv_k <= cv_k + 32'd1;
						end
					10'd181:
						if (aalu_pend) begin
							if (aalu_go) begin
								aalu_ret <= 10'd181;
								st <= 10'd637;
							end
						end
						else if (noframe) begin
							gi <= 32'd0;
							st <= 10'd184;
						end
						else
							gosub(10'd423, 10'd182);
					10'd182: begin
						gi <= 32'd0;
						st <= 10'd184;
					end
					10'd183: begin
						gi <= 32'd0;
						st <= 10'd184;
					end
					10'd184:
						if (gi == 32'd9) begin
							if (ca_idle_i) begin
								gc_collect_req <= 1'b1;
								st <= 10'd185;
							end
						end
						else begin
							case (gi[3:0])
								4'd0:
									wr(ABI_SYSROOT_BASE + (4 * ABI_SR_CUR_EXC), xc, 10'd184);
								4'd1:
									wr(ABI_SYSROOT_BASE + (4 * ABI_SR_T0), t[0], 10'd184);
								4'd2:
									wr(ABI_SYSROOT_BASE + (4 * ABI_SR_T1), t[1], 10'd184);
								4'd3:
									wr(ABI_SYSROOT_BASE + (4 * ABI_SR_T2), t[2], 10'd184);
								4'd4:
									wr(ABI_SYSROOT_BASE + (4 * ABI_SR_T3), t[3], 10'd184);
								4'd5:
									wr(ABI_SYSROOT_BASE + (4 * ABI_SR_T4), t[4], 10'd184);
								4'd6:
									wr(ABI_SYSROOT_BASE + (4 * ABI_SR_T5), t[5], 10'd184);
								4'd7:
									wr(ABI_SYSROOT_BASE + (4 * ABI_SR_T6), t[6], 10'd184);
								default:
									wr(ABI_SYSROOT_BASE + (4 * ABI_SR_T7), t[7], 10'd184);
							endcase
							gi <= gi + 32'd1;
						end
					10'd185:
						if (gc_collect_done_i)
							ret;
					10'd445:
						case (tg(ty_v))
							ABI_TAG_CONTROL:
								rd(TT + (4 * (is_bool(ty_v) ? ABI_T_BOOL : ABI_T_NONETYPE)), 10'd447);
							ABI_TAG_INT, ABI_TAG_INT64:
								rd(TT + (4 * ABI_T_INT), 10'd447);
							ABI_TAG_FLOAT:
								rd(TT + (4 * ABI_T_FLOAT), 10'd447);
							ABI_TAG_COMPLEX:
								rd(TT + (4 * ABI_T_COMPLEX), 10'd447);
							ABI_TAG_QSTR, ABI_TAG_STR:
								rd(TT + (4 * ABI_T_STR), 10'd447);
							ABI_TAG_BYTES:
								rd(TT + (4 * ABI_T_BYTES), 10'd447);
							ABI_TAG_TUPLE:
								rd(TT + (4 * ABI_T_TUPLE), 10'd447);
							ABI_TAG_RANGE:
								rd(TT + (4 * ABI_T_RANGE), 10'd447);
							ABI_TAG_ITER:
								rd(TT + (4 * ABI_T_ITERATOR), 10'd447);
							ABI_TAG_OBJECT:
								rd(adr(ty_v) + 4, 10'd447);
							ABI_TAG_MUT:
								case (ty_v[1:0])
									ABI_MUT_LIST:
										rd(TT + (4 * ABI_T_LIST), 10'd447);
									ABI_MUT_DICT:
										rd(TT + (4 * ABI_T_DICT), 10'd447);
									ABI_MUT_SET:
										rd(adr(ty_v) + 12, 10'd446);
									default:
										rd(TT + (4 * ABI_T_BYTEARRAY), 10'd447);
								endcase
							default:
								rd(TT + (4 * ABI_T_OBJECT), 10'd447);
						endcase
					10'd446:
						rd(TT + (4 * (md & ABI_SET_FLAG_FROZEN ? ABI_T_FROZENSET : ABI_T_SET)), 10'd447);
					10'd447: begin
						ty_t <= mv;
						ret;
					end
					10'd196: begin
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
								qd_nxt <= 10'd199;
								st <= 10'd356;
							end
							ABI_TAG_STR, ABI_TAG_BYTES:
								rd(adr(hk) + 4, 10'd199);
							ABI_TAG_INT64:
								rd(adr(hk), 10'd197);
							ABI_TAG_OBJECT:
								rd(adr(hk), 10'd198);
							default: begin
								hok <= 1'b0;
								ret;
							end
						endcase
					end
					10'd199: begin
						hh <= {16'd0, md[15:0]};
						ret;
					end
					10'd197: begin
						hh <= sx31(md);
						ret;
					end
					10'd198: begin
						if ((md == ABI_OB_INSTANCE) || (md == ABI_OB_EXCEPTION))
							hok <= 1'b0;
						else
							hh <= {1'b0, hk[31:1]};
						ret;
					end
					10'd356:
						rd((qid < h_nq ? h_qdesc + (qid << 3) : h_qext + ((qid - h_nq) << 3)), qd_nxt);
					10'd415:
						if (tg(si_v) == ABI_TAG_QSTR) begin
							qid <= si_v[31:0];
							qd_nxt <= 10'd416;
							st <= 10'd356;
						end
						else
							rd(adr(si_v), 10'd418);
					10'd416: begin
						si_hash <= {16'd0, md[15:0]};
						si_len <= {16'd0, md[31:16]};
						rd(m_addr + 4, 10'd417);
					end
					10'd417: begin
						si_addr <= {1'b0, md[30:0]};
						si_na <= md[31];
						ret;
					end
					10'd418: begin
						si_len <= md;
						rd(adr(si_v) + 4, 10'd419);
					end
					10'd419: begin
						si_hash <= {16'd0, md[15:0]};
						si_na <= md[30];
						rd(adr(si_v) + 8, 10'd420);
					end
					10'd420: begin
						si_addr <= md;
						ret;
					end
					10'd100:
						if (tg(si_v) == ABI_TAG_QSTR)
							gosub(10'd415, 10'd102);
						else if (tg(si_v) == ABI_TAG_INT) begin
							si_addr <= si_v[31:0];
							ret;
						end
						else
							rd(adr(si_v) + 8, 10'd101);
					10'd101: begin
						si_addr <= md;
						ret;
					end
					10'd102:
						ret;
					10'd435:
						if (scr_id != SCR_SE)
							scr_adopt(SCR_SE, 10'd435);
						else if (se_a == se_b) begin
							se_eq <= 1'b1;
							ret;
						end
						else begin
							si_v <= se_a;
							gosub(10'd415, 10'd410);
						end
					10'd410: begin
						sA[0] <= si_len;
						sA[1] <= si_hash;
						sA[2] <= si_addr;
						si_v <= se_b;
						gosub(10'd415, 10'd411);
					end
					10'd411:
						if ((si_len != sA[0]) || (si_hash != sA[1])) begin
							se_eq <= 1'b0;
							ret;
						end
						else begin
							sA[3] <= si_addr;
							sA[4] <= 32'd0;
							st <= 10'd414;
						end
					10'd414:
						if (sA[4] >= sA[0]) begin
							se_eq <= 1'b1;
							ret;
						end
						else
							rd(sA[2] + sA[4], 10'd412);
					10'd412: begin
						sA[5] <= md;
						rd(sA[3] + sA[4], 10'd413);
					end
					10'd413: begin
						v0 = sA[0] - sA[4];
						v1 = (v0 >= 32'd4 ? 32'hffffffff : (32'd1 << (v0 << 3)) - 32'd1);
						if (((sA[5] ^ md) & v1) != 32'd0) begin
							se_eq <= 1'b0;
							ret;
						end
						else begin
							sA[4] <= sA[4] + 32'd4;
							st <= 10'd414;
						end
					end
					10'd226: begin
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
							gosub_scr(SCR_SE, 10'd435, 10'd232);
						end
						else if ((tg(ke_a) == ABI_TAG_BYTES) && (tg(ke_b) == ABI_TAG_BYTES)) begin
							se_a <= ke_a;
							se_b <= ke_b;
							gosub_scr(SCR_SE, 10'd435, 10'd232);
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
								scr_adopt(SCR_KE, 10'd226);
							else
								rd(adr(ke_a), 10'd227);
						end
						else if ((tg(ke_a) == ABI_TAG_FLOAT) || (tg(ke_a) == ABI_TAG_COMPLEX)) begin
							ke_eq <= 1'b0;
							ke_cx <= numlike(ke_b);
							ret;
						end
						else if ((tg(ke_a) == ABI_TAG_OBJECT) || (tg(ke_a) == ABI_TAG_TUPLE))
							rd(adr(ke_a), 10'd231);
						else begin
							ke_eq <= 1'b0;
							ret;
						end
					end
					10'd232: begin
						ke_eq <= se_eq;
						ret;
					end
					10'd227: begin
						sA[0] <= md;
						rd(adr(ke_a) + 4, 10'd228);
					end
					10'd228: begin
						sA[1] <= md;
						rd(adr(ke_b), 10'd229);
					end
					10'd229:
						if (md != sA[0]) begin
							ke_eq <= 1'b0;
							ret;
						end
						else
							rd(adr(ke_b) + 4, 10'd230);
					10'd230: begin
						ke_eq <= md == sA[1];
						ret;
					end
					10'd231: begin
						ke_eq <= 1'b0;
						ke_cx <= (tg(ke_a) == ABI_TAG_TUPLE ? tg(ke_b) == ABI_TAG_TUPLE : (md == ABI_OB_INSTANCE) || (md == ABI_OB_EXCEPTION));
						ret;
					end
					10'd249:
						if (scr_id != SCR_LK)
							scr_adopt(SCR_LK, 10'd249);
						else begin
							lk_found <= 1'b0;
							lk_cx <= 1'b0;
							lk_ro <= 1'b0;
							lk_res <= VNULL;
							rd(adr(t[4]) + 12, 10'd252);
						end
					10'd252:
						if ((lk_mode != LK_FIND) && (md & ABI_DICT_FLAG_ROM)) begin
							lk_ro <= 1'b1;
							ret;
						end
						else
							rd(adr(t[4]) + 4, 10'd250);
					10'd250: begin
						sA[0] <= md;
						rd(adr(t[4]) + 8, 10'd271);
					end
					10'd271: begin
						sA[1] <= md;
						if (sA[0] == 32'd0) begin
							if (lk_mode == LK_ADD)
								gosub_scr(SCR_RH, 10'd361, 10'd265);
							else
								ret;
						end
						else begin
							hk <= t[5];
							gosub(10'd196, 10'd253);
						end
					end
					10'd265:
						if (lk_cx)
							ret;
						else
							st <= 10'd249;
					10'd253:
						if (!hok) begin
							lk_cx <= 1'b1;
							ret;
						end
						else if (hh < sA[0]) begin
							sA[2] <= hh;
							sA[3] <= hh;
							lk_hasav <= 1'b0;
							st <= 10'd263;
						end
						else begin
							hm_start <= 1'b1;
							st <= 10'd254;
						end
					10'd254:
						if (hm_done) begin
							sA[2] <= hm_rem;
							sA[3] <= hm_rem;
							lk_hasav <= 1'b0;
							st <= 10'd263;
						end
					10'd263: begin
						sA[5] <= sA[1] + (lk_set ? sA[2] << 2 : sA[2] << 3);
						rd(sA[1] + (lk_set ? sA[2] << 2 : sA[2] << 3), 10'd260);
					end
					10'd260:
						if (mv == VNULL) begin
							if (lk_mode == LK_ADD) begin
								if (lk_hasav)
									sA[5] <= sA[4];
								st <= 10'd257;
							end
							else
								ret;
						end
						else if (mv == VTOMB) begin
							if (!lk_hasav) begin
								lk_hasav <= 1'b1;
								sA[4] <= sA[5];
							end
							st <= 10'd262;
						end
						else if (mv == t[5])
							st <= 10'd255;
						else begin
							ke_a <= mv;
							ke_b <= t[5];
							gosub(10'd226, 10'd261);
						end
					10'd261:
						if (ke_cx) begin
							lk_cx <= 1'b1;
							ret;
						end
						else if (scr_id != SCR_LK)
							scr_ensure(SCR_LK, 10'd261);
						else if (ke_eq)
							st <= 10'd255;
						else
							st <= 10'd262;
					10'd262: begin
						v0 = ((sA[2] + 32'd1) == sA[0] ? 32'd0 : sA[2] + 32'd1);
						if (v0 == sA[3]) begin
							if (lk_mode == LK_ADD) begin
								if (lk_hasav) begin
									sA[5] <= sA[4];
									st <= 10'd257;
								end
								else
									gosub_scr(SCR_RH, 10'd361, 10'd265);
							end
							else
								ret;
						end
						else begin
							sA[2] <= v0;
							st <= 10'd263;
						end
					end
					10'd255: begin
						lk_found <= 1'b1;
						case (lk_mode)
							LK_FIND:
								if (lk_set) begin
									lk_res <= t[5];
									ret;
								end
								else
									rd(sA[5] + 4, 10'd272);
							LK_ADD:
								if (lk_set)
									ret;
								else
									wr(sA[5] + 4, t[6], 10'd264);
							default:
								if (lk_set)
									st <= 10'd266;
								else
									rd(sA[5] + 4, 10'd270);
						endcase
					end
					10'd272: begin
						lk_res <= mv;
						ret;
					end
					10'd264:
						ret;
					10'd270: begin
						lk_res <= mv;
						st <= 10'd266;
					end
					10'd266: begin
						v0 = ((sA[2] + 32'd1) == sA[0] ? 32'd0 : sA[2] + 32'd1);
						rd(sA[1] + (lk_set ? v0 << 2 : v0 << 3), 10'd267);
					end
					10'd267:
						wr(sA[5], (mv == VNULL ? VNULL : VTOMB), 10'd268);
					10'd268:
						if (lk_set)
							rd(adr(t[4]), 10'd251);
						else
							wr(sA[5] + 4, VNULL, 10'd269);
					10'd269:
						rd(adr(t[4]), 10'd251);
					10'd251:
						wr(adr(t[4]), vint(md - 32'd1), 10'd264);
					10'd257:
						wr(sA[5], t[5], (lk_set ? 10'd259 : 10'd258));
					10'd258:
						wr(sA[5] + 4, t[6], 10'd259);
					10'd259:
						rd(adr(t[4]), 10'd256);
					10'd256:
						wr(adr(t[4]), vint(md + 32'd1), 10'd264);
					10'd361:
						if (scr_id != SCR_RH)
							scr_adopt(SCR_RH, 10'd361);
						else
							st <= 10'd624;
					10'd624:
						rd(scr_addr(SCR_LK, 4'd0), 10'd625);
					10'd625: begin
						sA[0] <= md + 32'd1;
						st <= 10'd626;
					end
					10'd626: begin
						sA[0] <= next_alloc(sA[0]);
						alloc(next_alloc(sA[0]) << (lk_set ? 0 : 1), 10'd362);
					end
					10'd362: begin
						sA[1] <= al_a;
						sA[2] <= 32'd0;
						sA[4] <= 32'd0;
						rd(adr(t[4]) + 4, 10'd363);
					end
					10'd363: begin
						sA[5] <= md;
						rd(adr(t[4]) + 8, 10'd364);
					end
					10'd364: begin
						sA[6] <= md;
						st <= 10'd371;
					end
					10'd371:
						if (sA[2] == sA[5])
							wr(adr(t[4]) + 4, vint(sA[0]), 10'd365);
						else
							rd(sA[6] + (lk_set ? sA[2] << 2 : sA[2] << 3), 10'd370);
					10'd370:
						if ((mv == VNULL) || (mv == VTOMB)) begin
							sA[2] <= sA[2] + 32'd1;
							st <= 10'd371;
						end
						else begin
							sV[7] <= mv;
							hk <= mv;
							gosub(10'd196, 10'd368);
						end
					10'd368:
						if (!hok) begin
							lk_cx <= 1'b1;
							ret;
						end
						else if (hh < sA[0]) begin
							sA[3] <= hh;
							st <= 10'd373;
						end
						else begin
							hm_start <= 1'b1;
							st <= 10'd369;
						end
					10'd369:
						if (hm_done) begin
							sA[3] <= hm_rem;
							st <= 10'd373;
						end
					10'd373:
						rd(sA[1] + (lk_set ? sA[3] << 2 : sA[3] << 3), 10'd374);
					10'd374:
						if (mv != VNULL) begin
							sA[3] <= ((sA[3] + 32'd1) == sA[0] ? 32'd0 : sA[3] + 32'd1);
							st <= 10'd373;
						end
						else
							wr(sA[1] + (lk_set ? sA[3] << 2 : sA[3] << 3), sV[7], (lk_set ? 10'd372 : 10'd375));
					10'd375:
						rd((sA[6] + (sA[2] << 3)) + 4, 10'd376);
					10'd376:
						wr((sA[1] + (sA[3] << 3)) + 4, mv, 10'd372);
					10'd372: begin
						sA[4] <= sA[4] + 32'd1;
						sA[2] <= sA[2] + 32'd1;
						st <= 10'd371;
					end
					10'd365:
						wr(adr(t[4]) + 8, {ABI_TAG_CONT, sA[1]}, 10'd366);
					10'd366:
						wr(adr(t[4]), vint(sA[4]), 10'd367);
					10'd367:
						wr(scr_addr(SCR_LK, 4'd0), {4'd0, sA[0]}, 10'd627);
					10'd627:
						wr(scr_addr(SCR_LK, 4'd1), {4'd0, sA[1]}, 10'd264);
					10'd233:
						if (scr_id != SCR_LA)
							scr_adopt(SCR_LA, 10'd233);
						else
							rd(adr(t[2]), 10'd244);
					10'd244: begin
						sA[0] <= md;
						rd(adr(t[2]) + 4, 10'd234);
					end
					10'd234: begin
						sA[1] <= md;
						rd(adr(t[2]) + 8, 10'd242);
					end
					10'd242: begin
						sA[2] <= md;
						if (sA[0] < sA[1])
							wr(md + (sA[0] << 2), t[3], 10'd243);
						else
							alloc((sA[1] == 32'd0 ? 32'd4 : sA[1] << 1), 10'd238);
					end
					10'd238:
						if (!al_ok)
							ret;
						else begin
							sA[3] <= al_a;
							sA[4] <= 32'd0;
							rd(adr(t[2]) + 8, 10'd239);
						end
					10'd239: begin
						sA[2] <= md;
						st <= (cfg_ca && (sA[0] != 32'd0) ? 10'd636 : 10'd236);
					end
					10'd636:
						if (ca_ok) begin
							ca_ship(sA[3], sA[2], sA[0]);
							sA[4] <= sA[0];
							st <= 10'd236;
						end
					10'd236:
						if (sA[4] == sA[0])
							wr(adr(t[2]) + 4, vint((sA[1] == 32'd0 ? 32'd4 : sA[1] << 1)), 10'd240);
						else
							rd(sA[2] + (sA[4] << 2), 10'd237);
					10'd237: begin
						wr(sA[3] + (sA[4] << 2), mv, 10'd236);
						sA[4] <= sA[4] + 32'd1;
					end
					10'd240:
						wr(adr(t[2]) + 8, {ABI_TAG_CONT, sA[3]}, 10'd241);
					10'd241:
						wr(sA[3] + (sA[0] << 2), t[3], 10'd243);
					10'd243:
						wr(adr(t[2]), vint(sA[0] + 32'd1), 10'd246);
					10'd246:
						ret;
					10'd442:
						if (tb_n == 8'd0) begin
							tb_v <= {ABI_TAG_TUPLE, h_empty};
							ret;
						end
						else
							alloc(32'd1 + tb_n, 10'd443);
					10'd443: begin
						tb_a <= al_a;
						tb_i <= 8'd0;
						wr(al_a, vint(sv2v_cast_32(tb_n)), 10'd444);
					end
					10'd444:
						if (tb_i == tb_n) begin
							tb_v <= {ABI_TAG_TUPLE, tb_a};
							ret;
						end
						else if (!tb_src)
							rd(ab_ptr(tb_from + tb_i), 10'd586);
						else begin
							v0 = {16'd0, stk_from} + sv2v_cast_32(tb_i);
							if (stk_hit(v0[15:0])) begin
								wr((tb_a + 4) + (4 * tb_i), stk_val(v0[15:0]), 10'd444);
								tb_i <= tb_i + 8'd1;
							end
							else begin
								srd_g <= v0[15:0];
								gosub(10'd483, 10'd496);
							end
						end
					10'd586: begin
						if (tb_nz && (mv == VNULL))
							wr((tb_a + 4) + (4 * tb_i), vint(32'd0), 10'd444);
						else
							wr((tb_a + 4) + (4 * tb_i), mv, 10'd444);
						tb_i <= tb_i + 8'd1;
					end
					10'd496: begin
						wr((tb_a + 4) + (4 * tb_i), srd_v, 10'd444);
						tb_i <= tb_i + 8'd1;
					end
					10'd207:
						if ((is_c == ty_obj) || (is_c == is_t)) begin
							is_r <= 1'b1;
							ret;
						end
						else
							rd(adr(is_t) + 20, 10'd210);
					10'd210: begin
						is_m <= adr(mv);
						rd(adr(mv), 10'd211);
					end
					10'd211: begin
						is_n <= md;
						is_i <= 32'd0;
						st <= 10'd209;
					end
					10'd209:
						if (is_i == is_n) begin
							is_r <= 1'b0;
							ret;
						end
						else
							rd((is_m + 4) + (is_i << 2), 10'd208);
					10'd208:
						if (mv == is_c) begin
							is_r <= 1'b1;
							ret;
						end
						else begin
							is_i <= is_i + 32'd1;
							st <= 10'd209;
						end
					10'd438: begin
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
									rd(adr(tr_v), 10'd440);
								ABI_TAG_OBJECT:
									rd(adr(tr_v) + 4, 10'd441);
								default: begin
									tr_x <= 1'b1;
									ret;
								end
							endcase
					end
					10'd440: begin
						tr_r <= md != 32'd0;
						ret;
					end
					10'd441:
						rd(adr(mv) + 28, 10'd439);
					10'd439: begin
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
								gosub(10'd445, 10'd22);
							end
						end
					10'd12:
						if (md == ABI_OB_INSTANCE)
							rd(adr(t[0]) + 8, 10'd10);
						else if (md == ABI_OB_EXCEPTION)
							rd(adr(t[0]) + 16, 10'd10);
						else if (md == ABI_OB_TYPE) begin
							sV[6] <= t[0];
							at_ty <= 1'b1;
							st <= 10'd20;
						end
						else if (md == ABI_OB_MODULE)
							rd(adr(t[0]) + 8, 10'd17);
						else
							rd(adr(t[0]) + 4, 10'd23);
					10'd10:
						if (mv == VNULL)
							rd(adr(t[0]) + 4, 10'd23);
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
							rd(adr(t[0]) + 4, 10'd23);
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
						rd(adr(sV[6]) + 20, 10'd13);
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
								rd(adr(ty_obj) + 8, 10'd15);
							end
							else begin
								at_kind <= 2'd0;
								ret;
							end
						end
						else
							rd((sA[0] + 4) + (sA[2] << 2), 10'd21);
					10'd21:
						rd(adr(mv) + 8, 10'd15);
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
					10'd212:
						if (scr_id != SCR_IT)
							scr_ensure(SCR_IT, 10'd212);
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
										rd(adr(sV[0]), 10'd223);
									else begin
										si_v <= sV[0];
										gosub(10'd415, 10'd214);
									end
								ABI_IT_DICT, ABI_IT_SET:
									rd(adr(sV[0]) + 4, 10'd215);
								ABI_IT_STR: begin
									si_v <= sV[0];
									gosub(10'd415, 10'd214);
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
					10'd223:
						if (sA[4] >= md) begin
							it_stop <= 1'b1;
							ret;
						end
						else if (tg(sV[0]) == ABI_TAG_TUPLE)
							rd((adr(sV[0]) + 4) + (sA[4] << 2), 10'd224);
						else
							rd(adr(sV[0]) + 8, 10'd221);
					10'd221:
						rd(md + (sA[4] << 2), 10'd224);
					10'd224: begin
						it_val <= mv;
						sV[1] <= vint(sA[4] + 32'd1);
						ret;
					end
					10'd214:
						if (sA[4] >= si_len) begin
							it_stop <= 1'b1;
							ret;
						end
						else
							rd(si_addr + {sA[4][31:2], 2'b00}, 10'd213);
					10'd213:
						if ((tg(sV[0]) == ABI_TAG_BYTES) || is_mut(sV[0], ABI_MUT_BYTEARRAY)) begin
							it_val <= vint({24'd0, byte_of(md, sA[4][1:0])});
							sV[1] <= vint(sA[4] + 32'd1);
							ret;
						end
						else
							rd(h_chars + (4 * byte_of(md, sA[4][1:0])), 10'd222);
					10'd222: begin
						it_val <= {ABI_TAG_QSTR, md};
						sV[1] <= vint(sA[4] + 32'd1);
						ret;
					end
					10'd215: begin
						sA[5] <= md;
						rd(adr(sV[0]) + 8, 10'd219);
					end
					10'd219: begin
						sA[6] <= md;
						st <= 10'd218;
					end
					10'd218:
						if (sA[4] >= sA[5]) begin
							it_stop <= 1'b1;
							sV[1] <= vint(sA[4]);
							ret;
						end
						else
							rd(sA[6] + (sV[3][31:0] == ABI_IT_SET ? sA[4] << 2 : sA[4] << 3), 10'd217);
					10'd217:
						if ((mv == VNULL) || (mv == VTOMB)) begin
							sA[4] <= sA[4] + 32'd1;
							st <= 10'd218;
						end
						else if ((sV[3][31:0] == ABI_IT_SET) || (sV[2][31:0] == 32'd0)) begin
							it_val <= mv;
							sV[1] <= vint(sA[4] + 32'd1);
							ret;
						end
						else if (sV[2][31:0] == 32'd1)
							rd(m_addr + 4, 10'd224);
						else begin
							t[2] <= mv;
							rd(m_addr + 4, 10'd220);
						end
					10'd220: begin
						t[1] <= mv;
						alloc(32'd3, 10'd216);
					end
					10'd216: begin
						wb_v[0] <= vint(32'd2);
						wb_v[1] <= t[2];
						wb_v[2] <= t[1];
						it_val <= {ABI_TAG_TUPLE, al_a};
						sV[1] <= vint(sA[4] + 32'd1);
						wblock(al_a, 4'd3, 10'd246);
					end
					10'd478:
						if (aalu_pend) begin
							if (aalu_go) begin
								aalu_ret <= 10'd478;
								st <= 10'd637;
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
							v2 = mpy_rf_block_bytes(v0[5:0]);
							if (v0 < MPY_RF_CHUNK_MIN)
								st <= rf_resume;
							else if (spill_hp < (ftop + v2))
								raise_msg(ABI_MSG_RECURSION);
							else begin
								spill_n <= v0[5:0];
								spill_ntag <= sv2v_cast_6((v0[5:0] + 6'd7) >> 3);
								spill_words <= (32'd1 + sv2v_cast_32((v0[5:0] + 6'd7) >> 3)) + v0;
								spill_addr <= spill_hp - v2;
								spill_had_link <= has_link;
								spill_prev <= (has_link ? mpy_rf_link_addr(rf[rf_base[3:0] + 4'd0]) : 32'd0);
								sw_i <= 32'd0;
								st <= 10'd479;
							end
						end
					10'd479:
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
							wr(spill_addr, mpy_rf_chunk_hdr(spill_prev, spill_n), 10'd479);
							sw_i <= 32'd1;
						end
						else if (sw_i <= sv2v_cast_32(spill_ntag)) begin
							v3 = 32'd0;
							begin : sv2v_autoblock_15
								reg signed [31:0] k;
								for (k = 0; k < 8; k = k + 1)
									begin
										vs0 = sv2v_cast_7((sw_i[5:0] - 6'd1) << 3) + sv2v_cast_7_signed(k);
										if (vs0 < {1'b0, spill_n})
											v3[4 * k+:4] = rf[rf_base[3:0] + sv2v_cast_4((spill_had_link ? vs0 + 7'd1 : vs0))][35:32];
									end
							end
							wr(spill_addr + (sw_i << 2), {4'd0, v3}, 10'd479);
							sw_i <= sw_i + 32'd1;
						end
						else begin
							vs0 = (spill_had_link ? sw_i[6:0] - {1'b0, spill_ntag} : (sw_i[6:0] - 7'd1) - {1'b0, spill_ntag});
							wr(spill_addr + (sw_i << 2), rf[rf_base[3:0] + sv2v_cast_4(vs0)], 10'd479);
							sw_i <= sw_i + 32'd1;
						end
					10'd480:
						if (aalu_pend) begin
							if (aalu_go) begin
								aalu_ret <= 10'd480;
								st <= 10'd637;
							end
						end
						else if (!has_link)
							st <= rf_resume;
						else begin
							spill_addr <= mpy_rf_link_addr(rf[rf_base[3:0] + 4'd0]);
							sw_i <= 32'd0;
							st <= 10'd481;
						end
					10'd481:
						if ((sw_i != 32'd0) && (sw_i == spill_words)) begin
							spilled_reals <= (spilled_reals >= {10'd0, spill_n} ? spilled_reals - {10'd0, spill_n} : 16'd0);
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
							rd(spill_addr + (sw_i << 2), 10'd482);
					10'd482:
						if (sw_i == 32'd0) begin
							v0 = sv2v_cast_32(mpy_rf_chunk_count(mt, md));
							v1 = mpy_rf_chunk_prev(md);
							v2 = sv2v_cast_32(sp) + (v1 != 32'd0 ? v0 : v0 - 32'd1);
							spill_n <= v0[5:0];
							spill_prev <= v1;
							spill_ntag <= sv2v_cast_6((v0[5:0] + 6'd7) >> 3);
							spill_words <= (32'd1 + sv2v_cast_32((v0[5:0] + 6'd7) >> 3)) + v0;
							if (((v0 < MPY_RF_CHUNK_MIN) || (v0 > MPY_RF_CHUNK_MAX)) || (v2 > MPY_RF_DEPTH)) begin
								if (rf_resume == 10'd110) begin
									rf_reload_miss <= 1'b1;
									st <= 10'd110;
								end
								else
									halt(ABI_HALT_INTERNAL, 32'h00005f01);
							end
							else begin
								sw_i <= 32'd1 + sv2v_cast_32((v0[5:0] + 6'd7) >> 3);
								st <= 10'd481;
							end
						end
						else begin
							v0 = (sw_i - 32'd1) - sv2v_cast_32(spill_ntag);
							rf[sv2v_cast_4(((rf_base - spill_n) + v0) + 32'd1)] <= mv;
							sw_i <= sw_i + 32'd1;
							st <= 10'd481;
						end
					10'd483:
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
							srd_hops <= 8'd0;
							st <= 10'd484;
						end
					10'd484:
						rd(srd_addr, 10'd485);
					10'd485: begin
						v0 = sv2v_cast_32(mpy_rf_chunk_count(mt, md));
						v1 = mpy_rf_chunk_prev(md);
						if ((v0 != 32'd0) && (srd_off < v0[15:0]))
							rd(((srd_addr + 32'd4) + (sv2v_cast_32((v0[5:0] + 6'd7) >> 3) << 2)) + (((v0 - 32'd1) - sv2v_cast_32(srd_off)) << 2), 10'd486);
						else if ((v1 == 32'd0) || (srd_hops == 8'd64)) begin
							srd_v <= VNULL;
							ret;
						end
						else begin
							srd_off <= srd_off - v0[15:0];
							srd_addr <= v1;
							srd_hops <= srd_hops + 8'd1;
							st <= 10'd484;
						end
					end
					10'd486: begin
						srd_v <= mv;
						ret;
					end
					10'd514:
						if (b1)
							wr(ab_ptr(8'd31), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(s1 + 7'd1))], 10'd515);
						else
							st <= 10'd515;
					10'd515:
						if (sv2v_cast_32(i0) == x1)
							st <= 10'd60;
						else begin
							wr(ab_ptr(8'd32 + i0), rf[rf_base[3:0] + sv2v_cast_4(sv2v_cast_6(s0 + sv2v_cast_7(i0)))], 10'd515);
							i0 <= i0 + 8'd1;
						end
					10'd487:
						if (stk_hit(x0[15:0]))
							wr(ab_ptr(8'd0), stk_val(x0[15:0]), 10'd489);
						else begin
							srd_g <= x0[15:0];
							gosub(10'd483, 10'd488);
						end
					10'd488:
						wr(ab_ptr(8'd0), srd_v, 10'd489);
					10'd489:
						if (!b0) begin
							ab_lo <= 8'd32;
							st <= 10'd491;
						end
						else if (stk_hit(x0[15:0] + 16'd1)) begin
							if (stk_val(x0[15:0] + 16'd1) != VNULL) begin
								wr(ab_ptr(8'd31), stk_val(x0[15:0] + 16'd1), 10'd491);
								ab_lo <= 8'd31;
							end
							else begin
								ab_lo <= 8'd32;
								st <= 10'd491;
							end
						end
						else begin
							srd_g <= x0[15:0] + 16'd1;
							gosub(10'd483, 10'd490);
						end
					10'd490:
						if (srd_v != VNULL) begin
							wr(ab_ptr(8'd31), srd_v, 10'd491);
							ab_lo <= 8'd31;
						end
						else begin
							ab_lo <= 8'd32;
							st <= 10'd491;
						end
					10'd491:
						if (gi == x1)
							st <= 10'd493;
						else if (stk_hit(x2[15:0] + gi[15:0])) begin
							wr(ab_ptr(sv2v_cast_8(32 + gi)), stk_val(x2[15:0] + gi[15:0]), 10'd491);
							gi <= gi + 32'd1;
						end
						else begin
							srd_g <= x2[15:0] + gi[15:0];
							gosub(10'd483, 10'd492);
						end
					10'd492: begin
						wr(ab_ptr(sv2v_cast_8(32 + gi)), srd_v, 10'd491);
						gi <= gi + 32'd1;
					end
					10'd493: begin
						ab_pe <= sv2v_cast_8(32 + x4);
						crk <= ABI_RK_PUSH;
						drop_left <= x3[15:0];
						drop_push_en <= 1'b0;
						drop_then <= 10'd60;
						st <= 10'd494;
					end
					10'd494:
						if (drop_left == 16'd0) begin
							if (drop_push_en) begin
								if (sp >= sv2v_cast_7_signed(MPY_RF_DEPTH)) begin
									rf_pend <= 1'b1;
									rf_pend_v <= drop_push_v;
									rf_resume <= drop_then;
									st <= 10'd478;
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
							rf_resume <= 10'd494;
							st <= 10'd480;
						end
						else if (sp == 7'd0)
							drop_left <= 16'd0;
						else begin
							sp <= sp - 7'd1;
							drop_left <= drop_left - 16'd1;
						end
					10'd459:
						if (stk_depth <= ur_target) begin
							if (sp >= sv2v_cast_7_signed(14)) begin
								rf_resume <= 10'd459;
								st <= 10'd478;
							end
							else begin
								rf[rf_base[3:0] + sv2v_cast_4(sp)] <= ur_val;
								rf[rf_base[3:0] + sv2v_cast_4(sp + 7'd1)] <= vint(32'hffffffff);
								sp <= sp + 7'd2;
								st <= 10'd118;
							end
						end
						else if (has_link && (sp <= 7'd1)) begin
							rf_resume <= 10'd459;
							st <= 10'd480;
						end
						else if (sp != 7'd0)
							sp <= sp - 7'd1;
						else
							st <= 10'd118;
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
	localparam [31:0] MPY_SRAM_BYTES = 32'h00010000;
	localparam [31:0] MPY_GC_POOL_BYTES = MPY_SRAM_BYTES - (MPY_GC_POOL_BASE - MPY_SRAM_BASE);
	parameter signed [31:0] POOL_BYTES = MPY_GC_POOL_BYTES;
	parameter signed [31:0] STACK_DEPTH = 64;
	input wire clk_i;
	input wire rst_n_i;
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
	input wire mem_ack_i;
	input wire [31:0] mem_rdata_i;
	input wire [3:0] mem_rtag_i;
	localparam signed [31:0] NB = POOL_BYTES / 16;
	localparam signed [31:0] BW = $clog2(NB + 1);
	localparam signed [31:0] SW = $clog2(STACK_DEPTH + 1);
	localparam [1:0] A_FREE = 2'd0;
	localparam [1:0] A_HEAD = 2'd1;
	localparam [1:0] A_TAIL = 2'd2;
	localparam [1:0] A_MARK = 2'd3;
	reg [4:0] st;
	reg [1:0] atb [0:NB - 1];
	reg [BW - 1:0] stk [0:STACK_DEPTH - 1];
	reg [SW - 1:0] ssp;
	reg ovf;
	reg [BW - 1:0] rover;
	reg [BW - 1:0] idx;
	reg [BW - 1:0] run_start;
	reg [BW - 1:0] run_len;
	reg [BW - 1:0] need;
	reg [BW - 1:0] scanned;
	reg huge;
	wire [32:0] need_full;
	assign need_full = ({1'b0, alloc_nbytes_i} + 33'd15) >> 4;
	reg [31:0] zaddr;
	reg [31:0] zend;
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
	function automatic [BW - 1:0] sv2v_cast_F35F2;
		input reg [BW - 1:0] inp;
		sv2v_cast_F35F2 = inp;
	endfunction
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
		if ((cand_addr < POOL_BASE) || (cand_off >= POOL_BYTES))
			cand_ptr = 1'b0;
	end
	wire [BW - 1:0] run_first;
	assign run_first = (run_len == {BW {1'sb0}} ? idx : run_start);
	assign busy_o = st != 5'd1;
	assign free_blocks_o = free_cnt;
	assign total_blocks_o = NB;
	assign collections_o = ncoll;
	assign overflows_o = novf;
	function automatic signed [SW - 1:0] sv2v_cast_6C2E3_signed;
		input reg signed [SW - 1:0] inp;
		sv2v_cast_6C2E3_signed = inp;
	endfunction
	task automatic try_mark;
		input reg [BW - 1:0] b;
		if (atb[b] == A_HEAD) begin
			atb[b] <= A_MARK;
			if (ssp < sv2v_cast_6C2E3_signed(STACK_DEPTH)) begin
				stk[ssp] <= b;
				ssp <= ssp + 1'b1;
			end
			else begin
				ovf <= 1'b1;
				novf <= novf + 32'd1;
			end
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
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
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
	function automatic signed [BW - 1:0] sv2v_cast_F35F2_signed;
		input reg signed [BW - 1:0] inp;
		sv2v_cast_F35F2_signed = inp;
	endfunction
	function automatic signed [32:0] sv2v_cast_33_signed;
		input reg signed [32:0] inp;
		sv2v_cast_33_signed = inp;
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
			huge <= 1'b0;
			scanned <= 1'sb0;
			zaddr <= 1'sb0;
			zend <= 1'sb0;
			raddr <= 1'sb0;
			rhi <= 1'sb0;
			rsel <= 1'b0;
			oblk <= 1'sb0;
			oword <= 1'sb0;
			rescanning <= 1'b0;
			freeing <= 1'b0;
			free_cnt <= NB;
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
		end
		else begin
			alloc_done_o <= 1'b0;
			collect_done_o <= 1'b0;
			mem_req_o <= 1'b0;
			(* full_case, parallel_case *)
			case (st)
				5'd0: begin
					atb[idx] <= A_FREE;
					idx <= idx + 1'b1;
					if (idx == sv2v_cast_F35F2_signed(NB - 1)) begin
						idx <= 1'sb0;
						st <= 5'd1;
					end
				end
				5'd1:
					if (alloc_req_i) begin
						need <= (alloc_nbytes_i == 32'd0 ? sv2v_cast_F35F2_signed(1) : sv2v_cast_F35F2(need_full));
						huge <= need_full > sv2v_cast_33_signed(NB);
						idx <= rover;
						run_len <= 1'sb0;
						scanned <= 1'sb0;
						st <= 5'd2;
					end
					else if (collect_req_i) begin
						raddr <= root0_lo_i;
						rhi <= root0_hi_i;
						rsel <= 1'b0;
						ssp <= 1'sb0;
						ovf <= 1'b0;
						st <= 5'd6;
					end
				5'd2:
					if ((huge || (need > sv2v_cast_F35F2_signed(NB))) || (scanned == sv2v_cast_F35F2_signed(NB))) begin
						alloc_done_o <= 1'b1;
						alloc_ok_o <= 1'b0;
						st <= 5'd1;
					end
					else begin
						scanned <= scanned + 1'b1;
						if ((atb[idx] == A_FREE) && ((run_len + 1'b1) == need)) begin
							run_start <= run_first;
							st <= 5'd3;
						end
						else begin
							if (atb[idx] == A_FREE) begin
								run_start <= run_first;
								run_len <= run_len + 1'b1;
							end
							else
								run_len <= 1'sb0;
							if (idx == sv2v_cast_F35F2_signed(NB - 1)) begin
								idx <= 1'sb0;
								run_len <= 1'sb0;
							end
							else
								idx <= idx + 1'b1;
						end
					end
				5'd3:
					if (idx == run_start) begin
						atb[idx] <= A_HEAD;
						zaddr <= POOL_BASE + {run_start, 4'b0000};
						zend <= (POOL_BASE + {run_start, 4'b0000}) + {need, 4'b0000};
						free_cnt <= free_cnt - sv2v_cast_32(need);
						rover <= ((run_start + need) >= sv2v_cast_F35F2_signed(NB) ? {BW {1'sb0}} : run_start + need);
						st <= 5'd4;
					end
					else begin
						atb[idx] <= A_TAIL;
						idx <= idx - 1'b1;
					end
				5'd4:
					if (zaddr == zend) begin
						alloc_done_o <= 1'b1;
						alloc_ok_o <= 1'b1;
						alloc_addr_o <= POOL_BASE + {run_start, 4'b0000};
						st <= 5'd1;
					end
					else begin
						mem_req_o <= 1'b1;
						mem_we_o <= 1'b1;
						mem_tag_we_o <= 1'b1;
						mem_addr_o <= zaddr;
						mem_wdata_o <= 1'sb0;
						mem_wtag_o <= 1'sb0;
						st <= 5'd5;
					end
				5'd5:
					if (mem_ack_i) begin
						zaddr <= zaddr + 32'd4;
						st <= 5'd4;
					end
				5'd6:
					if (raddr >= rhi) begin
						if (!rsel) begin
							raddr <= root1_lo_i;
							rhi <= root1_hi_i;
							rsel <= 1'b1;
						end
						else begin
							rescanning <= 1'b0;
							st <= 5'd8;
						end
					end
					else begin
						mem_read(raddr);
						st <= 5'd7;
					end
				5'd7:
					if (mem_ack_i) begin
						if ((((mem_rtag_i == MPY_TAG_CONTROL) && (mem_rdata_i[3:0] == MPY_CTL_RF_LINK)) && ({mem_rdata_i[31:4], 4'b0000} >= MPY_SRAM_BASE)) && (({mem_rdata_i[31:4], 4'b0000} + 32'd4) <= (MPY_SRAM_BASE + MPY_FRAME_RESERVE_BYTES))) begin
							lnk_addr <= {mem_rdata_i[31:4], 4'b0000};
							lnk_hops <= 8'd0;
							raddr <= raddr + 32'd4;
							st <= 5'd13;
						end
						else begin
							if (cand_ptr)
								try_mark(cand_blk);
							raddr <= raddr + 32'd4;
							st <= 5'd6;
						end
					end
				5'd13: begin
					lnk_follow <= 1'b0;
					mem_read(lnk_addr);
					st <= 5'd14;
				end
				5'd14:
					if (mem_ack_i) begin
						lnk_n <= mpy_rf_chunk_count(mem_rtag_i, mem_rdata_i);
						if ((mpy_rf_chunk_prev(mem_rdata_i) != 32'd0) && (lnk_hops != 8'd64)) begin
							lnk_next <= mpy_rf_chunk_prev(mem_rdata_i);
							lnk_follow <= 1'b1;
						end
						lnk_ntag <= sv2v_cast_3((mpy_rf_chunk_count(mem_rtag_i, mem_rdata_i) + 8'd7) >> 3);
						lnk_tw <= 3'd0;
						if (((mpy_rf_chunk_count(mem_rtag_i, mem_rdata_i) < sv2v_cast_8_signed(MPY_RF_CHUNK_MIN)) || (mpy_rf_chunk_count(mem_rtag_i, mem_rdata_i) > sv2v_cast_8_signed(MPY_RF_CHUNK_MAX))) || ((lnk_addr + mpy_rf_block_bytes(sv2v_cast_6(mpy_rf_chunk_count(mem_rtag_i, mem_rdata_i)))) > (MPY_SRAM_BASE + MPY_FRAME_RESERVE_BYTES)))
							st <= 5'd6;
						else begin
							mem_read(lnk_addr + 32'd4);
							st <= 5'd15;
						end
					end
				5'd15:
					if (mem_ack_i) begin
						begin : sv2v_autoblock_1
							reg signed [31:0] k;
							for (k = 0; k < 8; k = k + 1)
								lnk_tags[(8 * lnk_tw) + k] <= mem_rdata_i[4 * k+:4];
						end
						if ((lnk_tw + 3'd1) < lnk_ntag) begin
							lnk_tw <= lnk_tw + 3'd1;
							mem_read((lnk_addr + 32'd8) + ({29'd0, lnk_tw} << 2));
							st <= 5'd15;
						end
						else begin
							lnk_i <= 6'd0;
							mem_read((lnk_addr + 32'd4) + ({29'd0, lnk_ntag} << 2));
							st <= 5'd17;
						end
					end
				5'd16: st <= 5'd6;
				5'd17:
					if (mem_ack_i) begin
						if (mpy_tag_is_pointer(lnk_tags[lnk_i])) begin
							if (lnk_tags[lnk_i] == MPY_TAG_MUT_COLLEC) begin
								if (({mem_rdata_i[31:2], 2'b00} >= POOL_BASE) && (({mem_rdata_i[31:2], 2'b00} - POOL_BASE) < POOL_BYTES))
									try_mark(sv2v_cast_F35F2(({mem_rdata_i[31:2], 2'b00} - POOL_BASE) >> 4));
							end
							else if ((mem_rdata_i >= POOL_BASE) && ((mem_rdata_i - POOL_BASE) < POOL_BYTES))
								try_mark(sv2v_cast_F35F2((mem_rdata_i - POOL_BASE) >> 4));
						end
						if (({2'b00, lnk_i} + 8'd1) == lnk_n) begin
							if (lnk_follow && (lnk_hops != 8'd64)) begin
								lnk_addr <= lnk_next;
								lnk_hops <= lnk_hops + 8'd1;
								st <= 5'd13;
							end
							else
								st <= 5'd6;
						end
						else begin
							lnk_i <= lnk_i + 6'd1;
							mem_read(((lnk_addr + 32'd8) + ({29'd0, lnk_ntag} << 2)) + ({26'd0, lnk_i} << 2));
							st <= 5'd17;
						end
					end
				5'd8:
					if (ssp != {SW {1'sb0}}) begin
						oblk <= stk[ssp - 1'b1];
						oword <= 1'sb0;
						ssp <= ssp - 1'b1;
						st <= 5'd9;
					end
					else if (rescanning) begin
						idx <= idx + 1'b1;
						st <= 5'd11;
					end
					else if (ovf) begin
						ovf <= 1'b0;
						rescanning <= 1'b1;
						idx <= 1'sb0;
						st <= 5'd11;
					end
					else begin
						idx <= 1'sb0;
						freeing <= 1'b0;
						st <= 5'd12;
					end
				5'd9: begin
					mem_read((POOL_BASE + {oblk, 4'b0000}) + {28'b0000000000000000000000000000, oword, 2'b00});
					st <= 5'd10;
				end
				5'd10:
					if (mem_ack_i) begin
						if (cand_ptr)
							try_mark(cand_blk);
						if (oword != 2'd3) begin
							oword <= oword + 1'b1;
							st <= 5'd9;
						end
						else if (((oblk + 1'b1) < sv2v_cast_F35F2_signed(NB)) && (atb[oblk + 1'b1] == A_TAIL)) begin
							oblk <= oblk + 1'b1;
							oword <= 1'sb0;
							st <= 5'd9;
						end
						else
							st <= 5'd8;
					end
				5'd11:
					if (idx == sv2v_cast_F35F2_signed(NB)) begin
						if (ovf) begin
							ovf <= 1'b0;
							idx <= 1'sb0;
						end
						else begin
							rescanning <= 1'b0;
							idx <= 1'sb0;
							freeing <= 1'b0;
							st <= 5'd12;
						end
					end
					else if (atb[idx] == A_MARK) begin
						oblk <= idx;
						oword <= 1'sb0;
						st <= 5'd9;
					end
					else
						idx <= idx + 1'b1;
				5'd12:
					if (idx == sv2v_cast_F35F2_signed(NB))
						st <= 5'd18;
					else begin
						(* full_case, parallel_case *)
						case (atb[idx])
							A_HEAD: begin
								atb[idx] <= A_FREE;
								freeing <= 1'b1;
								free_cnt <= free_cnt + 32'd1;
							end
							A_TAIL:
								if (freeing) begin
									atb[idx] <= A_FREE;
									free_cnt <= free_cnt + 32'd1;
								end
							A_MARK: begin
								atb[idx] <= A_HEAD;
								freeing <= 1'b0;
							end
							default: freeing <= 1'b0;
						endcase
						idx <= idx + 1'b1;
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
	assign idle_o = cnt == {(QW >= 0 ? QW + 1 : 1 - QW) {1'sb0}};
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
module mpy_mem (
	clk_i,
	rst_n_i,
	req_i,
	we_i,
	tag_we_i,
	be_i,
	addr_i,
	wdata_i,
	wtag_i,
	id_i,
	rdy_o,
	ack_o,
	id_o,
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
	localparam signed [31:0] MPY_FLASH_WAIT_STATES = 1;
	parameter signed [31:0] FLASH_WAIT_STATES = MPY_FLASH_WAIT_STATES;
	localparam signed [31:0] MPY_SRAM_LATENCY = 1;
	parameter signed [31:0] SRAM_LATENCY = MPY_SRAM_LATENCY;
	input wire clk_i;
	input wire rst_n_i;
	input wire req_i;
	input wire we_i;
	input wire tag_we_i;
	input wire [3:0] be_i;
	input wire [31:0] addr_i;
	input wire [31:0] wdata_i;
	input wire [3:0] wtag_i;
	input wire [1:0] id_i;
	output wire rdy_o;
	output reg ack_o;
	output reg [1:0] id_o;
	output reg [31:0] rdata_o;
	output reg [3:0] rtag_o;
	output reg fault_o;
	output reg [3:0] fault_reason_o;
	input wire ld_we_i;
	localparam signed [31:0] MPY_FLASH_IDX_W = 16;
	input wire [15:0] ld_idx_i;
	input wire [31:0] ld_wdata_i;
	input wire [3:0] ld_wtag_i;
	output wire init_done_o;
	localparam signed [31:0] MPY_MEM_BLOCK_AW = 14;
	localparam signed [31:0] AW = MPY_MEM_BLOCK_AW;
	localparam signed [31:0] MPY_MEM_WIDTH = 36;
	localparam signed [31:0] W = MPY_MEM_WIDTH;
	localparam signed [31:0] MPY_IMAGE_BLOCKS = 3;
	localparam signed [31:0] MPY_SRAM_BLOCKS = 1;
	localparam signed [31:0] MPY_MEM_BLOCKS = MPY_SRAM_BLOCKS + MPY_IMAGE_BLOCKS;
	localparam signed [31:0] NB = MPY_MEM_BLOCKS;
	localparam signed [31:0] SB = $clog2(NB);
	reg blk_v [0:NB - 1];
	reg blk_w [0:NB - 1];
	reg [13:0] blk_addr [0:NB - 1];
	reg [35:0] blk_data [0:NB - 1];
	reg [35:0] blk_mask [0:NB - 1];
	wire [35:0] blk_q [0:NB - 1];
	genvar _gv_b_1;
	localparam signed [31:0] MPY_MEM_BLOCK_WORDS = 16384;
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
	reg [7:0] phase_r;
	reg [1:0] id_r;
	reg [3:0] fault_r;
	reg rd_r;
	reg [SB - 1:0] rblk_r;
	reg fresh_r;
	reg [35:0] hold_r;
	reg clr_busy;
	reg [AW:0] clr_idx;
	assign rdy_o = !clr_busy && (phase_r <= 8'd1);
	assign init_done_o = !clr_busy;
	wire take;
	wire [2:0] a_region;
	wire a_aligned;
	reg [3:0] a_fault;
	reg a_sram;
	reg a_img;
	wire [15:0] a_sw;
	wire [15:0] a_iw;
	reg [SB - 1:0] a_blk;
	reg [35:0] a_mask;
	assign take = req_i && rdy_o;
	localparam [31:0] MPY_FLASH_BYTES = 32'h00030000;
	localparam [31:0] MPY_MMIO_BASE = 32'h40000000;
	localparam [31:0] MPY_MMIO_BYTES = 32'h00001000;
	localparam [2:0] MPY_REGION_FLASH = 3'd1;
	localparam [2:0] MPY_REGION_MMIO = 3'd3;
	localparam [2:0] MPY_REGION_NONE = 3'd0;
	localparam [2:0] MPY_REGION_SIM = 3'd4;
	localparam [2:0] MPY_REGION_SRAM = 3'd2;
	localparam [31:0] MPY_SIM_BASE = 32'he0000000;
	localparam [31:0] MPY_SIM_BYTES = 32'd256;
	localparam [31:0] MPY_SRAM_BASE = 32'h20000000;
	localparam [31:0] MPY_SRAM_BYTES = 32'h00010000;
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
	assign a_region = mpy_region_of(addr_i);
	assign a_aligned = addr_i[1:0] == 2'b00;
	function automatic [15:0] sv2v_cast_16;
		input reg [15:0] inp;
		sv2v_cast_16 = inp;
	endfunction
	function automatic [15:0] mpy_sram_word_index;
		input reg [31:0] addr;
		mpy_sram_word_index = sv2v_cast_16((addr - MPY_SRAM_BASE) >> 2);
	endfunction
	assign a_sw = mpy_sram_word_index(addr_i);
	localparam [31:0] MPY_FLASH_BASE = 32'h00000000;
	function automatic [16:0] sv2v_cast_17;
		input reg [16:0] inp;
		sv2v_cast_17 = inp;
	endfunction
	function automatic [16:0] mpy_flash_word_index;
		input reg [31:0] addr;
		mpy_flash_word_index = sv2v_cast_17((addr - MPY_FLASH_BASE) >> 2);
	endfunction
	assign a_iw = sv2v_cast_16(mpy_flash_word_index(addr_i));
	localparam [3:0] MPY_FAULT_BUS = 4'd3;
	localparam [3:0] MPY_FAULT_FLASH_STORE = 4'd2;
	localparam [3:0] MPY_FAULT_NONE = 4'd0;
	localparam [3:0] MPY_FAULT_UNALIGNED = 4'd1;
	function automatic [SB - 1:0] sv2v_cast_C2F86;
		input reg [SB - 1:0] inp;
		sv2v_cast_C2F86 = inp;
	endfunction
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		if (!a_aligned)
			a_fault = MPY_FAULT_UNALIGNED;
		else if (a_region == MPY_REGION_FLASH)
			a_fault = (we_i ? MPY_FAULT_FLASH_STORE : MPY_FAULT_NONE);
		else if (a_region == MPY_REGION_SRAM)
			a_fault = MPY_FAULT_NONE;
		else
			a_fault = MPY_FAULT_BUS;
		a_sram = (take && (a_fault == MPY_FAULT_NONE)) && (a_region == MPY_REGION_SRAM);
		a_img = (take && (a_fault == MPY_FAULT_NONE)) && (a_region == MPY_REGION_FLASH);
		a_blk = (a_region == MPY_REGION_SRAM ? sv2v_cast_C2F86(a_sw >> AW) : sv2v_cast_C2F86(MPY_SRAM_BLOCKS + (sv2v_cast_32(a_iw) >> AW)));
		begin : sv2v_autoblock_1
			reg signed [31:0] k;
			for (k = 0; k < 4; k = k + 1)
				a_mask[8 * k+:8] = {8 {be_i[k]}};
		end
		a_mask[35:32] = {4 {tag_we_i}};
	end
	wire [SB - 1:0] ld_blk;
	assign ld_blk = sv2v_cast_C2F86(MPY_SRAM_BLOCKS + (sv2v_cast_32(ld_idx_i) >> AW));
	function automatic signed [SB - 1:0] sv2v_cast_C2F86_signed;
		input reg signed [SB - 1:0] inp;
		sv2v_cast_C2F86_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_2
			reg signed [31:0] b;
			for (b = 0; b < NB; b = b + 1)
				begin
					blk_v[b] = 1'b0;
					blk_w[b] = 1'b0;
					blk_addr[b] = (b < MPY_SRAM_BLOCKS ? a_sw[13:0] : a_iw[13:0]);
					blk_data[b] = {wtag_i, wdata_i};
					blk_mask[b] = a_mask;
					if (b < MPY_SRAM_BLOCKS) begin
						if (clr_busy) begin
							blk_v[b] = 1'b1;
							blk_w[b] = 1'b1;
							blk_addr[b] = clr_idx[13:0];
							blk_data[b] = 1'sb0;
							blk_mask[b] = 1'sb1;
						end
						else if (a_sram && (a_blk == sv2v_cast_C2F86_signed(b))) begin
							blk_v[b] = 1'b1;
							blk_w[b] = we_i;
						end
					end
					else if (ld_we_i && (ld_blk == sv2v_cast_C2F86_signed(b))) begin
						blk_v[b] = 1'b1;
						blk_w[b] = 1'b1;
						blk_addr[b] = ld_idx_i[13:0];
						blk_data[b] = {ld_wtag_i, ld_wdata_i};
						blk_mask[b] = 1'sb1;
					end
					else if (a_img && (a_blk == sv2v_cast_C2F86_signed(b)))
						blk_v[b] = 1'b1;
				end
		end
	end
	wire [35:0] word_q;
	assign word_q = (fresh_r ? blk_q[rblk_r] : hold_r);
	function automatic signed [14:0] sv2v_cast_15_signed;
		input reg signed [14:0] inp;
		sv2v_cast_15_signed = inp;
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
			id_r <= 1'sb0;
			fault_r <= MPY_FAULT_NONE;
			rd_r <= 1'b0;
			rblk_r <= 1'sb0;
			fresh_r <= 1'b0;
			hold_r <= 1'sb0;
			id_o <= 1'sb0;
			ack_o <= 1'b0;
			rdata_o <= 1'sb0;
			rtag_o <= 1'sb0;
			fault_o <= 1'b0;
			fault_reason_o <= MPY_FAULT_NONE;
		end
		else begin
			if (clr_busy) begin
				clr_idx <= clr_idx + 1'b1;
				if (clr_idx == sv2v_cast_15_signed(16383))
					clr_busy <= 1'b0;
			end
			ack_o <= 1'b0;
			fault_o <= 1'b0;
			fault_reason_o <= MPY_FAULT_NONE;
			if (fresh_r) begin
				fresh_r <= 1'b0;
				hold_r <= blk_q[rblk_r];
			end
			if (phase_r == 8'd1) begin
				phase_r <= 1'sb0;
				ack_o <= 1'b1;
				id_o <= id_r;
				rdata_o <= (rd_r ? word_q[31:0] : 32'd0);
				rtag_o <= (rd_r ? word_q[35:32] : 4'd0);
				if (fault_r != MPY_FAULT_NONE) begin
					fault_o <= 1'b1;
					fault_reason_o <= fault_r;
				end
			end
			else if (phase_r != 8'd0)
				phase_r <= phase_r - 8'd1;
			if (take) begin
				id_r <= id_i;
				fault_r <= a_fault;
				rd_r <= (a_sram || a_img) && !we_i;
				rblk_r <= a_blk;
				fresh_r <= (a_sram || a_img) && !we_i;
				if (a_region == MPY_REGION_FLASH)
					phase_r <= sv2v_cast_8_signed(SRAM_LATENCY + FLASH_WAIT_STATES);
				else
					phase_r <= sv2v_cast_8_signed(SRAM_LATENCY);
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
	done_o,
	err_o
);
	reg _sv2v_0;
	parameter signed [31:0] SPI_DIV = 2;
	parameter signed [31:0] PAGE_BYTES = 2048;
	parameter [15:0] FIRST_PAGE = 16'd0;
	parameter signed [31:0] POWERUP_CYCLES = 0;
	input wire clk_i;
	input wire rst_n_i;
	output reg sck_o;
	output reg cs_n_o;
	output reg mosi_o;
	input wire miso_i;
	output reg ld_we_o;
	localparam signed [31:0] MPY_FLASH_IDX_W = 16;
	output reg [15:0] ld_idx_o;
	output reg [31:0] ld_wdata_o;
	output reg [3:0] ld_wtag_o;
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
	reg [2:0] cst;
	reg [31:0] nwords;
	reg [31:0] tagw;
	reg [2:0] k;
	reg [MPY_FLASH_IDX_W:0] widx;
	assign stop = (cst == 3'd4) || (cst == 3'd5);
	assign err_o = cst == 3'd5;
	localparam [31:0] MPY_BOOT_MAGIC = 32'h42595055;
	localparam signed [31:0] MPY_IMAGE_BLOCKS = 3;
	localparam signed [31:0] MPY_MEM_BLOCK_WORDS = 16384;
	localparam signed [31:0] MPY_FLASH_WORDS = MPY_IMAGE_BLOCKS * MPY_MEM_BLOCK_WORDS;
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			cst <= 3'd0;
			nwords <= 1'sb0;
			tagw <= 1'sb0;
			k <= 1'sb0;
			widx <= 1'sb0;
			ld_we_o <= 1'b0;
			ld_idx_o <= 1'sb0;
			ld_wdata_o <= 1'sb0;
			ld_wtag_o <= 1'sb0;
			done_o <= 1'b0;
		end
		else begin
			ld_we_o <= 1'b0;
			if ((cst == 3'd4) && !ld_we_o)
				done_o <= 1'b1;
			if (src_v)
				(* full_case, parallel_case *)
				case (cst)
					3'd0: cst <= (src_w == MPY_BOOT_MAGIC ? 3'd1 : 3'd5);
					3'd1: begin
						nwords <= src_w;
						cst <= ((src_w == 32'd0) || (src_w > MPY_FLASH_WORDS) ? 3'd5 : 3'd2);
					end
					3'd2: begin
						tagw <= src_w;
						k <= 1'sb0;
						cst <= 3'd3;
					end
					3'd3: begin
						ld_we_o <= 1'b1;
						ld_idx_o <= widx[15:0];
						ld_wdata_o <= src_w;
						ld_wtag_o <= tagw[4 * k+:4];
						widx <= widx + 1'b1;
						k <= k + 3'd1;
						if (k == 3'd7)
							cst <= ((sv2v_cast_32(widx) + 32'd1) >= nwords ? 3'd4 : 3'd2);
					end
					default:
						;
				endcase
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
	boot_err_o
);
	reg _sv2v_0;
	localparam signed [31:0] MPY_SRAM_LATENCY = 1;
	parameter signed [31:0] SRAM_LATENCY = MPY_SRAM_LATENCY;
	localparam signed [31:0] MPY_FLASH_WAIT_STATES = 1;
	parameter signed [31:0] FLASH_WAIT_STATES = MPY_FLASH_WAIT_STATES;
	input wire clk_i;
	input wire rst_n_i;
	output reg con_valid_o;
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
	wire c_req;
	wire c_we;
	wire c_tag_we;
	wire [3:0] c_be;
	wire [3:0] c_wtag;
	wire [31:0] c_addr;
	wire [31:0] c_wdata;
	wire c_ack;
	wire c_fault;
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
	reg m_req;
	reg m_we;
	reg m_tag_we;
	wire m_rdy;
	wire m_ack;
	wire m_fault;
	reg [3:0] m_be;
	reg [3:0] m_wtag;
	wire [3:0] m_rtag;
	wire [3:0] m_fault_reason;
	reg [31:0] m_addr;
	reg [31:0] m_wdata;
	wire [31:0] m_rdata;
	wire [1:0] m_id;
	wire [1:0] m_ack_id;
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
	wire am_req;
	wire am_we;
	wire am_gnt;
	wire am_ack;
	wire [31:0] am_addr;
	wire [31:0] am_wdata;
	wire [3:0] am_wtag;
	wire core_halted;
	wire [3:0] core_hcode;
	wire [31:0] core_hval;
	wire [31:0] core_cycles;
	wire mem_ready;
	wire boot_done;
	reg sys_rst_n;
	wire ld_we;
	localparam signed [31:0] MPY_FLASH_IDX_W = 16;
	wire [15:0] ld_idx;
	wire [31:0] ld_wdata;
	wire [3:0] ld_wtag;
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i)
			sys_rst_n <= 1'b0;
		else if ((mem_ready && boot_done) && !g_busy)
			sys_rst_n <= 1'b1;
	assign boot_done_o = sys_rst_n;
	mpy_boot u_boot(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.sck_o(nand_sck_o),
		.cs_n_o(nand_cs_n_o),
		.mosi_o(nand_mosi_o),
		.miso_i(nand_miso_i),
		.ld_we_o(ld_we),
		.ld_idx_o(ld_idx),
		.ld_wdata_o(ld_wdata),
		.ld_wtag_o(ld_wtag),
		.done_o(boot_done),
		.err_o(boot_err_o)
	);
	mpy_core u_core(
		.clk_i(clk_i),
		.rst_n_i(sys_rst_n),
		.m_req_o(c_req),
		.m_we_o(c_we),
		.m_tag_we_o(c_tag_we),
		.m_be_o(c_be),
		.m_addr_o(c_addr),
		.m_wdata_o(c_wdata),
		.m_wtag_o(c_wtag),
		.m_ack_i(c_ack),
		.m_rdata_i(c_rdata),
		.m_rtag_i(c_rtag),
		.m_fault_i(c_fault),
		.m_fault_reason_i(c_fault_reason),
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
		.ca_valid_o(ca_valid),
		.ca_ready_i(ca_ready),
		.ca_dst_o(ca_dst),
		.ca_src_o(ca_src),
		.ca_n_o(ca_n),
		.ca_idle_i(ca_idle),
		.ca_fault_i(ca_fault),
		.ca_fault_reason_i(ca_fault_reason),
		.ca_fault_addr_i(ca_fault_addr),
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
	localparam [31:0] ABI_GC_POOL_BASE = 32'h20008500;
	localparam signed [31:0] ABI_GC_POOL_BYTES = 31488;
	mpy_gc #(
		.POOL_BASE(ABI_GC_POOL_BASE),
		.POOL_BYTES(ABI_GC_POOL_BYTES)
	) u_gc(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
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
		.mem_ack_i(gm_ack),
		.mem_rdata_i(gm_rdata),
		.mem_rtag_i(gm_rtag)
	);
	mpy_ca u_ca(
		.clk_i(clk_i),
		.rst_n_i(sys_rst_n),
		.cmd_valid_i(ca_valid),
		.cmd_ready_o(ca_ready),
		.cmd_dst_i(ca_dst),
		.cmd_src_i(ca_src),
		.cmd_n_i(ca_n),
		.idle_o(ca_idle),
		.chk_addr_i(c_addr),
		.chk_we_i(c_we),
		.chk_busy_o(ca_busy),
		.req_o(am_req),
		.we_o(am_we),
		.addr_o(am_addr),
		.wdata_o(am_wdata),
		.wtag_o(am_wtag),
		.gnt_i(am_gnt),
		.ack_i(am_ack),
		.fault_i(m_fault),
		.fault_reason_i(m_fault_reason),
		.rdata_i(m_rdata),
		.rtag_i(m_rtag),
		.fault_o(ca_fault),
		.fault_reason_o(ca_fault_reason),
		.fault_addr_o(ca_fault_addr),
		.words_o(ca_words),
		.cmds_o(ca_cmds)
	);
	mpy_mem #(
		.FLASH_WAIT_STATES(FLASH_WAIT_STATES),
		.SRAM_LATENCY(SRAM_LATENCY)
	) u_mem(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		.req_i(m_req),
		.we_i(m_we),
		.tag_we_i(m_tag_we),
		.be_i(m_be),
		.addr_i(m_addr),
		.wdata_i(m_wdata),
		.wtag_i(m_wtag),
		.id_i(m_id),
		.rdy_o(m_rdy),
		.ack_o(m_ack),
		.id_o(m_ack_id),
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
	localparam [2:0] MPY_REGION_SIM = 3'd4;
	localparam [31:0] MPY_FLASH_BYTES = 32'h00030000;
	localparam [31:0] MPY_MMIO_BASE = 32'h40000000;
	localparam [31:0] MPY_MMIO_BYTES = 32'h00001000;
	localparam [2:0] MPY_REGION_FLASH = 3'd1;
	localparam [2:0] MPY_REGION_MMIO = 3'd3;
	localparam [2:0] MPY_REGION_NONE = 3'd0;
	localparam [2:0] MPY_REGION_SRAM = 3'd2;
	localparam [31:0] MPY_SIM_BASE = 32'he0000000;
	localparam [31:0] MPY_SIM_BYTES = 32'd256;
	localparam [31:0] MPY_SRAM_BASE = 32'h20000000;
	localparam [31:0] MPY_SRAM_BYTES = 32'h00010000;
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
	assign c_sim = mpy_region_of(c_addr) == MPY_REGION_SIM;
	reg sim_ack;
	reg [31:0] sim_rdata;
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
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			sim_ack <= 1'b0;
			sim_rdata <= 32'd0;
			con_valid_o <= 1'b0;
			con_err_o <= 1'b0;
			con_byte_o <= 8'd0;
			sim_halt <= 1'b0;
			sim_halt_val <= 32'd0;
		end
		else begin
			sim_ack <= 1'b0;
			con_valid_o <= 1'b0;
			if (c_req && c_sim) begin
				sim_ack <= 1'b1;
				sim_rdata <= 32'd0;
				if (c_we)
					case ((c_addr - ABI_SIM_BASE) >> 2)
						sv2v_cast_32(ABI_SIM_STDOUT): begin
							con_valid_o <= 1'b1;
							con_err_o <= 1'b0;
							con_byte_o <= c_wdata[7:0];
						end
						sv2v_cast_32(ABI_SIM_STDERR): begin
							con_valid_o <= 1'b1;
							con_err_o <= 1'b1;
							con_byte_o <= c_wdata[7:0];
						end
						sv2v_cast_32(ABI_SIM_HALT): begin
							sim_halt <= 1'b1;
							sim_halt_val <= c_wdata;
						end
						default:
							;
					endcase
				else if (((c_addr - ABI_SIM_BASE) >> 2) == sv2v_cast_32(ABI_SIM_CYCLES))
					sim_rdata <= core_cycles;
			end
		end
	localparam [1:0] P_NONE = 2'd0;
	localparam [1:0] P_GC = 2'd1;
	localparam [1:0] P_CORE = 2'd2;
	localparam [1:0] P_CA = 2'd3;
	reg c_pend;
	reg g_pend;
	wire c_want;
	wire g_want;
	reg [1:0] pick;
	assign c_want = c_pend || (c_req && !c_sim);
	assign g_want = g_pend || gm_req;
	always @(*) begin
		if (_sv2v_0)
			;
		if (!m_rdy)
			pick = P_NONE;
		else if (g_want)
			pick = P_GC;
		else if (c_want && !ca_busy)
			pick = P_CORE;
		else if (am_req)
			pick = P_CA;
		else
			pick = P_NONE;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		case (pick)
			P_GC: begin
				m_req = 1'b1;
				m_we = gm_we;
				m_tag_we = gm_tag_we;
				m_be = 4'hf;
				m_addr = gm_addr;
				m_wdata = gm_wdata;
				m_wtag = gm_wtag;
			end
			P_CA: begin
				m_req = 1'b1;
				m_we = am_we;
				m_tag_we = am_we;
				m_be = 4'hf;
				m_addr = am_addr;
				m_wdata = am_wdata;
				m_wtag = am_wtag;
			end
			default: begin
				m_req = pick == P_CORE;
				m_we = c_we;
				m_tag_we = c_tag_we;
				m_be = c_be;
				m_addr = c_addr;
				m_wdata = c_wdata;
				m_wtag = c_wtag;
			end
		endcase
	end
	assign m_id = pick;
	assign am_gnt = pick == P_CA;
	always @(posedge clk_i or negedge rst_n_i)
		if (!rst_n_i) begin
			c_pend <= 1'b0;
			g_pend <= 1'b0;
		end
		else begin
			c_pend <= c_want && (pick != P_CORE);
			g_pend <= g_want && (pick != P_GC);
		end
	assign gm_ack = m_ack && (m_ack_id == P_GC);
	assign am_ack = m_ack && (m_ack_id == P_CA);
	assign gm_rdata = m_rdata;
	assign gm_rtag = m_rtag;
	assign c_ack = (m_ack && (m_ack_id == P_CORE)) || sim_ack;
	assign c_rdata = (sim_ack ? sim_rdata : m_rdata);
	assign c_rtag = (sim_ack ? 4'd0 : m_rtag);
	assign c_fault = (!sim_ack && m_fault) && (m_ack_id == P_CORE);
	assign c_fault_reason = m_fault_reason;
	assign halted_o = core_halted || sim_halt;
	localparam [3:0] ABI_HALT_SYSEXIT = 4'd10;
	assign halt_code_o = (core_halted ? core_hcode : ABI_HALT_SYSEXIT);
	assign halt_value_o = (core_halted ? core_hval : sim_halt_val);
	assign cycles_o = core_cycles;
	assign gc_collections_o = g_coll;
	assign gc_free_o = g_free;
	wire unused;
	assign unused = ^{g_total, g_ovf, g_busy, ca_words, ca_cmds};
	initial _sv2v_0 = 0;
endmodule
