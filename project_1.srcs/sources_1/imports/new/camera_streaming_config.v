module camera_streaming_config #(	parameter DATA_WIDTH 		= 24,
							parameter ADDR_WIDTH 		= 8,
							parameter IMAGE_WIDTH 		= 1280,
							parameter IMAGE_HEIGHT 		= 720,
							parameter IMAGE_FLIP_EN 		= 0,
							parameter IMAGE_MIRROR_EN 	= 0,
							parameter SYS_CLK 			= 50_000_000,
							parameter I2C_CLK 			= 100_000
) (
	clk, rstn,
	done,
	camera_rstn,
	camera_pwdn,
	i2c_scl,
	i2c_sda
);

	input clk, rstn;
	output reg done;
	output camera_rstn;
	output camera_pwdn;
	output i2c_scl;
	inout i2c_sda;

	reg [7:0] cnt;
	wire [23:0] lut;
	wire [7:0] lut_size;

	reg wr_reg_req;
	wire [15:0] addr;
	wire addr_mode;
	wire [7:0] wr_data, rd_data;
	wire [7:0] i2c_addr;
	wire rw_done;
	wire ack_flag;
	reg [31:0] delay_cnt_max;

	assign camera_pwdn = 0;
	assign camera_rstn = 1;

	//ov5640
	assign i2c_addr = 8'h78;
	assign addr_mode = 1;
	assign addr = lut[23:8];
	assign wr_data = lut[7:0];
	//RGB
	assign lut_size = 252;
	ov5640_rgb_init_table #(	.DATA_WIDTH (DATA_WIDTH),
						.ADDR_WIDTH (ADDR_WIDTH),
						.IMAGE_WIDTH (IMAGE_WIDTH),
						.IMAGE_HEIGHT (IMAGE_HEIGHT),
						.IMAGE_FLIP_EN (IMAGE_FLIP_EN),
						.IMAGE_MIRROR_EN (IMAGE_MIRROR_EN )
	) ov5640_rgb_init_table_inst (
		.clk (clk),
		.addr (cnt),
		.q (lut)
	);

	i2c_controller #(	.SYS_CLK(SYS_CLK),
					.I2C_CLK(I2C_CLK)
	) i2c_controller_inst (
		.clk (clk),
		.rstn (rstn),
		.wr_reg_req (wr_reg_req),
		.rd_reg_req (0),
		.addr (addr),
		.addr_mode (addr_mode),
		.wr_data (wr_data),
		.rd_data (rd_data),
		.i2c_addr (i2c_addr),
		.rw_done (rw_done),
		.ack_flag (ack_flag),
		.delay_cnt_max (delay_cnt_max),
		.i2c_scl (i2c_scl),
		.i2c_sda (i2c_sda)
	);

	reg [20:0] delay_cnt;

	always@(posedge clk or negedge rstn) begin
		if (!rstn)
			delay_cnt <= 0;
		else begin
			if (delay_cnt == 21'h100800)
				delay_cnt <= 21'h100800;
			else
				delay_cnt <= delay_cnt + 1;
		end
	end

	wire start = (delay_cnt == 21'h1007ff) ? 1 : 0;

	always@(posedge clk or negedge rstn) begin
		if (!rstn)
			cnt <= 0;
		else begin
			if (start)
				cnt <= 0;
			else if (cnt < lut_size) begin
				if (rw_done && (!ack_flag))
					cnt <= cnt + 1;
				else
					cnt <= cnt;
			end
			else
				cnt <= 0;
		end
	end

	always@(posedge clk or negedge rstn) begin
		if (!rstn)
			done <= 0;
		else begin
			if (start)
				done <= 0;
			else if (cnt == lut_size)
				done <= 1;
		end
	end

	reg [1:0] state;

	always@(posedge clk or negedge rstn) begin
		if (!rstn) begin
			state <= 0;
			wr_reg_req <= 0;
			delay_cnt_max <= 0;
		end
		else begin
			if (cnt < lut_size) begin
				case (state)
					0 : begin
						if (start)
							state <= 1;
						else
							state <= 0;
					end
					1 : begin
						wr_reg_req <= 1;
						state <= 2;
						if (cnt == 1)
							delay_cnt_max <= 32'h40000; // delay 5ms
						else
							delay_cnt_max <= 0;
					end
					2 : begin
						wr_reg_req <= 0;
						if (rw_done)
							state <= 1;
						else
							state <= 2;
					end
					default : state <= 0;
				endcase
			end
			else
				state <= 0;
		end
	end

endmodule