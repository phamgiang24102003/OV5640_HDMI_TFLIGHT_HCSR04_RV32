module serdes_4b_10to1 (
	clk_x5,
	data_in0, data_in1, data_in2, data_in3,
	data_out0_p, data_out0_n, data_out1_p, data_out1_n, data_out2_p, data_out2_n, data_out3_p, data_out3_n
);

	input clk_x5;
	input [9:0] data_in0, data_in1, data_in2, data_in3;
	output data_out0_p, data_out0_n, data_out1_p, data_out1_n, data_out2_p, data_out2_n, data_out3_p, data_out3_n; 

	reg [2:0] TMDS_mod5 = 0;
	reg [4:0] TMDS_shift_0h = 0, TMDS_shift_0l = 0;
	reg [4:0] TMDS_shift_1h = 0, TMDS_shift_1l = 0;
	reg [4:0] TMDS_shift_2h = 0, TMDS_shift_2l = 0;
	reg [4:0] TMDS_shift_3h = 0, TMDS_shift_3l = 0;

	wire [4:0] TMDS_0_l = {data_in0[9], data_in0[7], data_in0[5], data_in0[3], data_in0[1]};
	wire [4:0] TMDS_0_h = {data_in0[8], data_in0[6], data_in0[4], data_in0[2], data_in0[0]};

	wire [4:0] TMDS_1_l = {data_in1[9], data_in1[7], data_in1[5], data_in1[3], data_in1[1]};
	wire [4:0] TMDS_1_h = {data_in1[8], data_in1[6], data_in1[4], data_in1[2], data_in1[0]};

	wire [4:0] TMDS_2_l = {data_in2[9], data_in2[7], data_in2[5], data_in2[3], data_in2[1]};
	wire [4:0] TMDS_2_h = {data_in2[8], data_in2[6], data_in2[4], data_in2[2], data_in2[0]};

	wire [4:0] TMDS_3_l = {data_in3[9], data_in3[7], data_in3[5], data_in3[3], data_in3[1]};
	wire [4:0] TMDS_3_h = {data_in3[8], data_in3[6], data_in3[4], data_in3[2], data_in3[0]};

	// 5x speed shift register serialization
	always @(posedge clk_x5) begin
		TMDS_mod5 <= (TMDS_mod5[2]) ? 3'd0 : TMDS_mod5 + 3'd1;

		TMDS_shift_0h <= TMDS_mod5[2] ? TMDS_0_h : TMDS_shift_0h[4:1];
		TMDS_shift_0l <= TMDS_mod5[2] ? TMDS_0_l : TMDS_shift_0l[4:1];

		TMDS_shift_1h <= TMDS_mod5[2] ? TMDS_1_h : TMDS_shift_1h[4:1];
		TMDS_shift_1l <= TMDS_mod5[2] ? TMDS_1_l : TMDS_shift_1l[4:1];

		TMDS_shift_2h <= TMDS_mod5[2] ? TMDS_2_h : TMDS_shift_2h[4:1];
		TMDS_shift_2l <= TMDS_mod5[2] ? TMDS_2_l : TMDS_shift_2l[4:1];

		TMDS_shift_3h <= TMDS_mod5[2] ? TMDS_3_h : TMDS_shift_3h[4:1];
		TMDS_shift_3l <= TMDS_mod5[2] ? TMDS_3_l : TMDS_shift_3l[4:1];
	end

	ODDR #(
		.DDR_CLK_EDGE("SAME_EDGE"),	// "OPPOSITE_EDGE" or "SAME_EDGE"
		.INIT(1'b0),						// Initial output value
		.SRTYPE("SYNC")					// Synchronous reset
	) ODDR_0 (
		.Q  (dataout_0),					// 1-bit DDR output
		.C  (clk_x5),
		.CE (1'b1),
		.D1 (TMDS_shift_0h[0]),				// Output on rising edge
		.D2 (TMDS_shift_0l[0]),				// Output on falling edge
		.R  (1'b0),
		.S  (1'b0)
	);

	OBUFDS #(
		.IOSTANDARD("DEFAULT"),
		.SLEW("SLOW")
	) OBUFDS_0 (
		.O  (data_out0_p),
		.OB (data_out0_n),
		.I  (dataout_0)
	);

	ODDR #(
		.DDR_CLK_EDGE("SAME_EDGE"),
		.INIT(1'b0),
		.SRTYPE("SYNC")
	) ODDR_1 (
		.Q  (dataout_1),
		.C  (clk_x5),
		.CE (1'b1),
		.D1 (TMDS_shift_1h[0]),
		.D2 (TMDS_shift_1l[0]),
		.R  (1'b0),
		.S  (1'b0)
	);

	OBUFDS #(
		.IOSTANDARD("DEFAULT"),
		.SLEW("SLOW")
	) OBUFDS_1 (
		.O  (data_out1_p),
		.OB (data_out1_n),
		.I  (dataout_1)
	);

	ODDR #(
		.DDR_CLK_EDGE("SAME_EDGE"),
		.INIT(1'b0),
		.SRTYPE("SYNC")
	) ODDR_2 (
		.Q  (dataout_2),
		.C  (clk_x5),
		.CE (1'b1),
		.D1 (TMDS_shift_2h[0]),
		.D2 (TMDS_shift_2l[0]),
		.R  (1'b0),
		.S  (1'b0)
	);

	OBUFDS #(
		.IOSTANDARD("DEFAULT"),
		.SLEW("SLOW")
	) OBUFDS_2 (
		.O  (data_out2_p),
		.OB (data_out2_n),
		.I  (dataout_2)
	);

	ODDR #(
		.DDR_CLK_EDGE("SAME_EDGE"),
		.INIT(1'b0),
		.SRTYPE("SYNC")
	) ODDR_3 (
		.Q  (dataout_3),
		.C  (clk_x5),
		.CE (1'b1),
		.D1 (TMDS_shift_3h[0]),
		.D2 (TMDS_shift_3l[0]),
		.R  (1'b0),
		.S  (1'b0)
	);

	OBUFDS #(
		.IOSTANDARD("DEFAULT"),
		.SLEW("SLOW")
	) OBUFDS_3 (
		.O  (data_out3_p),
		.OB (data_out3_n),
		.I  (dataout_3)
	);

endmodule