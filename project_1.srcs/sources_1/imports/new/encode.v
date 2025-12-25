module encode (
	clk, rstn,
	din,
	c0, c1,
	de,
	dout
);

	input clk, rstn;
	input [7:0] din;
	input c0, c1;
	input de;				// Data enable input (1 = data period, 0 = control period)
	output reg [9:0] dout;	// 10-bit encoded data output

	localparam 	CTL0 = 10'b1101010100,
				CTL1 = 10'b0010101011,
				CTL2 = 10'b0101010100,
				CTL3 = 10'b1010101011;

	reg [3:0] n1d;
	reg [7:0] din_q;

	always@(posedge clk) begin
		din_q <= din;
		n1d <= din[0] + din[1] + din[2] + din[3] + din[4] + din[5] + din[6] + din[7];
	end

	// Step 1: 8-bit to 9-bit conversion
	wire decision1 = (n1d > 4'h4) | ((n1d == 4'h4) & (din_q[0] == 1'b0));

	wire [8:0] q_m;
	assign q_m[0] = din_q[0];
	assign q_m[1] = (decision1) ? ~(q_m[0] ^ din_q[1]) : (q_m[0] ^ din_q[1]);
	assign q_m[2] = (decision1) ? ~(q_m[1] ^ din_q[2]) : (q_m[1] ^ din_q[2]);
	assign q_m[3] = (decision1) ? ~(q_m[2] ^ din_q[3]) : (q_m[2] ^ din_q[3]);
	assign q_m[4] = (decision1) ? ~(q_m[3] ^ din_q[4]) : (q_m[3] ^ din_q[4]);
	assign q_m[5] = (decision1) ? ~(q_m[4] ^ din_q[5]) : (q_m[4] ^ din_q[5]);
	assign q_m[6] = (decision1) ? ~(q_m[5] ^ din_q[6]) : (q_m[5] ^ din_q[6]);
	assign q_m[7] = (decision1) ? ~(q_m[6] ^ din_q[7]) : (q_m[6] ^ din_q[7]);
	assign q_m[8] = (decision1) ? 1'b0 : 1'b1;

	// Step 2: 9-bit to 10-bit conversion
	reg [3:0] n1q_m, n0q_m;

	always@(posedge clk) begin
		n1q_m <= q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7];
		n0q_m <= 4'h8 - (q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7]);
	end

	reg [4:0] cnt;

	wire decision2 = (cnt == 5'h0) | (n1q_m == n0q_m);
	wire decision3 = (~cnt[4] & (n1q_m > n0q_m)) | (cnt[4] & (n0q_m > n1q_m));

	// Pipeline delay registers (2 stages)
	reg [1:0] de_reg;
	reg [1:0] c0_reg;
	reg [1:0] c1_reg;
	reg [8:0] q_m_reg;

	always @ (posedge clk) begin
		de_reg  <= {de_reg[0], de};
		c0_reg  <= {c0_reg[0], c0};
		c1_reg  <= {c1_reg[0], c1};
		q_m_reg <= q_m;
	end

	// 10-bit TMDS Output Encoding
	always@(posedge clk or negedge rstn) begin
		if (!rstn) begin
			dout <= 0;
			cnt <= 0;
		end
		else begin
			if (de_reg[1]) begin // Data period: send encoded pixel data
				if (decision2) begin
					dout[9]   <= ~q_m_reg[8]; 
					dout[8]   <= q_m_reg[8]; 
					dout[7:0] <= (q_m_reg[8]) ? q_m_reg[7:0] : ~q_m_reg[7:0];
					cnt <= (~q_m_reg[8]) ? (cnt + n0q_m - n1q_m) : (cnt + n1q_m - n0q_m);
				end 
				else if (decision3) begin
					dout[9]   <= 1'b1;
					dout[8]   <= q_m_reg[8];
					dout[7:0] <=  ~q_m_reg[7:0];
					cnt <= cnt + {q_m_reg[8], 1'b0} + (n0q_m - n1q_m);
				end 
				else begin
					dout[9]   <= 1'b0;
					dout[8]   <= q_m_reg[8];
					dout[7:0] <= q_m_reg[7:0];
					cnt <= cnt - {~q_m_reg[8], 1'b0} + (n1q_m - n0q_m);
				end
			end 
			else begin // Control period: send TMDS control symbols
				cnt <= 5'd0;
				case ({c1_reg[1], c0_reg[1]})
					2'b00 : dout <= CTL0;
					2'b01 : dout <= CTL1;
					2'b10 : dout <= CTL2;
					default : dout <= CTL3;
				endcase
			end
		end
	end

endmodule