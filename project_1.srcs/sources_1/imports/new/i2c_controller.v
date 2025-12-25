module i2c_controller #(	parameter SYS_CLK = 50_000_000,
					parameter I2C_CLK = 100_000)
(
	clk, rstn,
	wr_reg_req, rd_reg_req,
	addr,
	addr_mode,
	wr_data,
	rd_data,
	i2c_addr,
	rw_done,
	ack_flag,
	delay_cnt_max,
	i2c_scl,
	i2c_sda
);

	input clk, rstn;
	input wr_reg_req, rd_reg_req;
	input [15:0] addr;
	input addr_mode;
	input [7:0] wr_data;
	output reg [7:0] rd_data;
	input [7:0] i2c_addr;
	output reg rw_done;
	output reg ack_flag;
	input [31:0] delay_cnt_max;
	output i2c_scl;
	inout i2c_sda;

	reg [5:0] cmd;
	reg [7:0] tx_data;
	wire [7:0] rx_data;
	wire done;
	wire ack;
	reg start;

	wire [15:0] reg_addr = addr_mode ? addr : {addr[7:0], addr[15:8]};

	localparam 	WRITE 	= 6'b000001,
				START 	= 6'b000010,
				READ 	= 6'b000100,
				STOP 	= 6'b001000,
				ACK 	= 6'b010000,
				NACK 	= 6'b100000;

	i2c_bit_shift #(	.SYS_CLK(SYS_CLK),
				.I2C_CLK(I2C_CLK)
	) i2c_bit_shift_inst (
		.clk (clk),
		.rstn (rstn),
		.cmd (cmd),
		.start (start),
		.rx_data (rx_data),
		.tx_data (tx_data),
		.done (done),
		.ack (ack),
		.i2c_scl (i2c_scl),
		.i2c_sda (i2c_sda)
	);

	reg [7:0] state;
	reg [7:0] cnt;
	reg [31:0] delay_cnt;

	localparam	IDLE 			= 8'b00000001,
				WR_REG 		= 8'b00000010,
				WAIT_WR_DONE 	= 8'b00000100,
				WR_REG_DONE 	= 8'b00001000,
				RD_REG 		= 8'b00010000,
				WAIT_RD_DONE 	= 8'b00100000,
				RD_REG_DONE	= 8'b01000000,
				WAIT_DELAY 	= 8'b10000000;

	task read_byte;
		input [5:0] ctrl_cmd;
		begin
			cmd <= ctrl_cmd;
			start <= 1;
		end
	endtask

	task write_byte;
		input [5:0] ctrl_cmd;
		input [7:0] wr_byte_data;
		begin
			cmd <= ctrl_cmd;
			tx_data <= wr_byte_data;
			start <= 1;
		end
	endtask

	always@(posedge clk or negedge rstn) begin
		if (!rstn) begin
			cmd <= 0;
			tx_data <= 0;
			start <= 0;
			rd_data <= 0;
			state <= IDLE;
			ack_flag <= 0;
			delay_cnt <= 0;
			cnt <= 0;
		end
		else begin
			case (state)
				IDLE : begin
					cnt <= 0;
					delay_cnt <= 0;
					ack_flag <= 0;
					rw_done <= 0;
					if (wr_reg_req)
						state <= WR_REG;
					else if (rd_reg_req)
						state <= RD_REG;
					else
						state <= IDLE;
				end

				WR_REG : begin
					state <= WAIT_WR_DONE;
					case (cnt)
						0 : write_byte  (WRITE | START, i2c_addr);
						1 : write_byte  (WRITE , reg_addr[15:8]);
						2 : write_byte  (WRITE , reg_addr[7:0]);
						3 : write_byte  (WRITE | STOP, wr_data);
					endcase
				end

				WAIT_WR_DONE : begin
					start <= 0;
					if (done) begin
						ack_flag <= ack_flag | ack;
						case (cnt)
							0 : begin
								cnt <= 1;
								state <= WR_REG;
							end
							1 : begin
								state <= WR_REG;
								if (addr_mode)
									cnt <= 2;
								else
									cnt <= 3;
							end
							2 : begin
								cnt <= 3;
								state <= WR_REG;
							end
							3 : state <= WR_REG_DONE;
							default : state <= IDLE;
						endcase
					end
				end

				WR_REG_DONE : begin
					state <= WAIT_DELAY;
				end

				RD_REG : begin
					state <= WAIT_RD_DONE;
					case (cnt)
						0 : write_byte  (WRITE | START, i2c_addr);
						1 : write_byte  (WRITE , reg_addr[15:8]);
						2 : write_byte  (WRITE , reg_addr[7:0]);
						3 : write_byte  (WRITE | START, i2c_addr | 1);
						4 : read_byte (READ | NACK | STOP);
					endcase
				end

				WAIT_RD_DONE : begin
					start <= 0;
					if (done) begin
						if (cnt <= 3)
							ack_flag <= ack_flag | ack;
						case (cnt)
							0 : begin
								cnt <= 1;
								state <= RD_REG;
							end
							1 : begin
								state <= RD_REG;
								if (addr_mode)
									cnt <= 2;
								else
									cnt <= 3;
							end
							2 : begin
								cnt <= 3;
								state <= RD_REG;
							end
							3 : begin
								cnt <= 4;
								state <= RD_REG;
							end
							4 : state <= RD_REG_DONE;
							default : state <= IDLE;
						endcase
					end
				end

				RD_REG_DONE : begin
					rd_data <= rx_data;
					state <= WAIT_DELAY;
				end

				WAIT_DELAY : begin
					if (delay_cnt <= delay_cnt_max) begin
						delay_cnt <= delay_cnt + 1;
						state <= WAIT_DELAY;
					end
					else begin
						delay_cnt <= 0;
						rw_done <= 1;
						state <= IDLE;
					end
				end
			endcase
		end
	end

endmodule