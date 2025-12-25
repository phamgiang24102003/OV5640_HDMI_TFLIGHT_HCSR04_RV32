module i2c_bit_shift #(	parameter SYS_CLK = 50_000_000,
					parameter I2C_CLK = 100_000)
(
	clk, rstn,
	cmd,
	start,
	rx_data,
	tx_data,
	done,
	ack,
	i2c_sda, i2c_scl
);

	input clk, rstn;
	input [5:0] cmd;
	input start;
	output reg [7:0] rx_data;
	input [7:0] tx_data;
	output reg done;
	output reg ack;
	inout i2c_sda;
	output reg i2c_scl;

	localparam CNT_HALF_SCL = SYS_CLK/I2C_CLK/4 - 1;

	localparam 	WRITE 	= 6'b000001,
				START 	= 6'b000010,
				READ 	= 6'b000100,
				STOP 	= 6'b001000,
				ACK 	= 6'b010000,
				NACK 	= 6'b100000;

	reg [7:0] div_cnt;
	reg en_div_cnt;

	always@(posedge clk or negedge rstn) begin
		if (!rstn)
			div_cnt <= 8'd0;
		else begin
			if (en_div_cnt) begin
				if (div_cnt == CNT_HALF_SCL)
					div_cnt <= 8'd0;
				else
					div_cnt <= div_cnt + 8'd1;
			end
			else
				div_cnt <= 0;
		end
	end

	wire scl_p = (div_cnt == CNT_HALF_SCL);

	reg r_sda, en_sda;

	assign i2c_sda = en_sda ? r_sda : 1'bz;

	reg [6:0] state;

	localparam	IDLE 		= 7'b0000001,
				GEN_START 	= 7'b0000010,
				WR_DATA 	= 7'b0000100,
				RD_DATA 	= 7'b0001000,
				CHECK_ACK 	= 7'b0010000,
				GEN_ACK 	= 7'b0100000,
				GEN_STOP 	= 7'b1000000;

	reg [4:0] cnt;

	always@(posedge clk or negedge rstn) begin
		if (!rstn) begin
			i2c_scl <= 1'b0;
			rx_data <= 8'b0;
			en_sda <= 1'b0;
			en_div_cnt <= 1'b0;
			r_sda <= 1'b1;
			done <= 1'b0;
			ack <= 1'b0;
			state <= IDLE;
			cnt <= 5'b0;
		end
		else begin
			case (state)
				IDLE : begin
					done <= 1'b0;
					en_sda <= 1'b1;
					if (start) begin
						en_div_cnt <= 1'b1;
						if (cmd & START)
							state <= GEN_START;
						else if (cmd & WRITE)
							state <= WR_DATA;
						else if (cmd & READ)
							state <= RD_DATA;
						else
							state <= IDLE;
					end
					else begin
						state <= IDLE;
						en_div_cnt <= 1'b0;
					end
				end

				GEN_START : begin
					if (scl_p) begin
						if (cnt == 5'd3)
							cnt <= 5'b0;
						else
							cnt <= cnt + 5'b1;

						case (cnt)
							0 : begin
								r_sda <= 1;
								en_sda <= 1;
							end
							1 : i2c_scl <= 1;
							2 : begin
								r_sda <= 0;
								i2c_scl <= 1;
							end
							3 : i2c_scl <= 0;
							default : begin
								r_sda <= 1;
								i2c_scl <= 1;
							end
						endcase

						if (cnt == 3) begin
							if (cmd & WRITE)
								state <= WR_DATA;
							else if (cmd & READ)
								state <= RD_DATA;
						end
					end
				end

				WR_DATA : begin
					if (scl_p) begin
						if (cnt == 31)
							cnt <= 0;
						else
							cnt <= cnt + 1;

						case (cnt)
							0, 4, 8, 12, 16, 20, 24, 28 : begin
								r_sda <= tx_data [7-cnt[4:2]];
								en_sda <= 1;
							end
							1, 5, 9, 13, 17, 21, 25, 29 : i2c_scl <= 1;
							2, 6, 10, 14, 18, 22, 26, 30 : i2c_scl <= 1;
							3, 7, 11, 15, 19, 23, 27, 31 : i2c_scl <= 0;
							default : begin
								r_sda <= 1;
								i2c_scl <= 1;
							end
						endcase

						if (cnt == 31)
							state <= CHECK_ACK;
					end
				end

				RD_DATA : begin
					if (scl_p) begin
						if (cnt == 31)
							cnt <= 0;
						else
							cnt <= cnt + 1;

						case (cnt)
							0, 4, 8, 12, 16, 20, 24, 28 : begin
								i2c_scl <= 0;
								en_sda <= 0;
							end
							1, 5, 9, 13, 17, 21, 25, 29 : i2c_scl <= 1;
							2, 6, 10, 14, 18, 22, 26, 30 : begin
								i2c_scl <= 1;
								rx_data <= {rx_data[6:0], i2c_sda};
							end
							3, 7, 11, 15, 19, 23, 27, 31 : i2c_scl <= 0;
							default : begin
								r_sda <= 1;
								i2c_scl <= 1;
							end
						endcase

						if (cnt == 31)
							state <= GEN_ACK;
					end
				end

				CHECK_ACK : begin
					if (scl_p) begin
						if (cnt == 5'd3)
							cnt <= 5'b0;
						else
							cnt <= cnt + 5'b1;

						case (cnt)
							0 : begin
								i2c_scl <= 0;
								en_sda <= 0;
							end
							1 : i2c_scl <= 1;
							2 : begin
								ack <= i2c_sda;
								i2c_scl <= 1;
							end
							3 : i2c_scl <= 0;
							default : begin
								r_sda <= 1;
								i2c_scl <= 1;
							end
						endcase

						if (cnt == 3) begin
							if (cmd & STOP)
								state <= GEN_STOP;
							else begin
								state <= IDLE;
								done <= 1;
							end
						end
					end
				end

				GEN_ACK : begin
					if (scl_p) begin
						if (cnt == 5'd3)
							cnt <= 5'b0;
						else
							cnt <= cnt + 5'b1;

						case (cnt)
							0 : begin
								i2c_scl <= 0;
								en_sda <= 1;
								if (cmd & ACK)
									r_sda <= 0;
								else if (cmd & NACK)
									r_sda <= 1;
							end
							1 : i2c_scl <= 1;
							2 : i2c_scl <= 1;
							3 : i2c_scl <= 0;
							default : begin
								r_sda <= 1;
								i2c_scl <= 1;
							end
						endcase

						if (cnt == 3) begin
							if (cmd & STOP)
								state <= GEN_STOP;
							else begin
								state <= IDLE;
								done <= 1;
							end
						end
					end
				end

				GEN_STOP : begin
					if (scl_p) begin
						if (cnt == 5'd3)
							cnt <= 5'b0;
						else
							cnt <= cnt + 5'b1;

						case (cnt)
							0 : begin
								r_sda <= 0;
								en_sda <= 1;
							end
							1 : i2c_scl <= 1;
							2 : begin
								i2c_scl <= 1;
								r_sda <= 1;
							end
							3 : i2c_scl <= 1;
							default : begin
								r_sda <= 1;
								i2c_scl <= 1;
							end
						endcase

						if (cnt == 3) begin
							done <= 1;
							state <= IDLE;
						end
					end
				end

				default : state <= IDLE;
			endcase
		end
	end

endmodule