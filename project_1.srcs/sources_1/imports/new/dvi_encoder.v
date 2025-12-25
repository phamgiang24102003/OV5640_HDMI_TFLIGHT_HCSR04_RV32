module dvi_encoder (
	pixel_clk, pixel_clk_x5, rstn,
	red_din, green_din, blue_din,
	hsync, vsync, de,
	tmds_clk_p, tmds_clk_n,
	tmds_data_p, tmds_data_n
);

	input pixel_clk, pixel_clk_x5, rstn;
	input [7:0] red_din, green_din, blue_din;
	input hsync, vsync, de;
	output tmds_clk_p, tmds_clk_n;
	output [2:0] tmds_data_p, tmds_data_n;

	wire [9:0] red, green, blue;

	encode encode_red (
		.clk (pixel_clk),
		.rstn (rstn),
		.din (red_din),
		.c0 (0),
		.c1 (0),
		.de (de),
		.dout (red)
	);

	encode encode_green (
		.clk (pixel_clk),
		.rstn (rstn),
		.din (green_din),
		.c0 (0),
		.c1 (0),
		.de (de),
		.dout (green)
	);

	encode encode_blue (
		.clk (pixel_clk),
		.rstn (rstn),
		.din (blue_din),
		.c0 (hsync),
		.c1 (vsync),
		.de (de),
		.dout (blue)
	);

	serdes_4b_10to1 serdes_4b_10to1_inst (
		.clk_x5 (pixel_clk_x5),
		.data_in0 (blue),				// Blue channel (with HSYNC/VSYNC)
		.data_in1 (green),				// Green channel
		.data_in2 (red),					// Red channel
		.data_in3 (10'b1111100000),		// TMDS clock pattern (101010... pair)
		.data_out0_p (tmds_data_p[0]),	// TMDS Blue +
		.data_out0_n (tmds_data_n[0]),	// TMDS Blue -
		.data_out1_p (tmds_data_p[1]),	// TMDS Green +
		.data_out1_n (tmds_data_n[1]),	// TMDS Green -
		.data_out2_p (tmds_data_p[2]),	// TMDS Red +
		.data_out2_n (tmds_data_n[2]),	// TMDS Red -
		.data_out3_p (tmds_clk_p),		// TMDS Clock +
		.data_out3_n (tmds_clk_n)		// TMDS Clock -
	);

endmodule