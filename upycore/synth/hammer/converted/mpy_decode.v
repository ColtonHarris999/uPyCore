// Generated from the uPyCore RTL by mpy_dc_unit.py and sv2v v0.0.13
// (see ../README.md). Do not edit; regenerate with convert_rtl.sh.
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
