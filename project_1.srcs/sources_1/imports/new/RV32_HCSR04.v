module RV32_HCSR04 #(parameter CLK_FREQ = 10_000_000) (
	input clk, rstn,
	// HC-SR04
	input echo,
	output trigger,
	// TF LIGHT
	output [2:0] tf_light,
	output [1:0] kathode,
	output [6:0] seg,
	// OBJECT DETECT
	input done_cap,
	output reg obj_dct
);

	wire object_detected;

	RV32_top #(.CLK_FREQ (CLK_FREQ)) RV32_top_inst (
		.clk (clk),
		.rstn (rstn),
		.GPIO_x ({4'b0, kathode, seg, tf_light})
	);

	HC_SR04 #(.CLK_FREQ (CLK_FREQ)) HC_SR04_inst (
		.clk (clk),
		.rstn (rstn),
		.echo (echo),
		.trigger (trigger),
		.object_detected (object_detected)
	);

	always@(posedge clk or negedge rstn) begin
		if (!rstn)
			obj_dct <= 0;
		else begin
			if (object_detected & (tf_light == 3'b100))
				obj_dct <= 1;
			else if (done_cap)
				obj_dct <= 0;
			else
				obj_dct <= obj_dct;
		end
	end

endmodule