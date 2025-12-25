module disp_driver #(parameter	Red_Bits = 8,
							Green_Bits = 8,
							Blue_Bits = 8,
							H_Sync_Time = 96,
							H_Back_Porch = 40,
							H_Left_Border = 8,
							H_Total_Time = 800,
							H_Right_Border = 8,
							H_Front_Porch = 8,
							V_Sync_Time = 2,
							V_Back_Porch = 25,
							V_Top_Border = 8,
							V_Total_Time = 525,
							V_Bottom_Border = 8,
							V_Front_Porch = 2) (
	clk_disp, rstn,
	data,
	data_req,
	addr_hs, addr_vs,
	disp_hs, disp_vs,
	disp_red,
	disp_green,
	disp_blue,
	frame_begin,
	disp_de,
	disp_pclk
);

	input clk_disp, rstn;
	input [Red_Bits + Green_Bits + Blue_Bits - 1:0] data;
	output data_req;
	output [11:0] addr_hs, addr_vs;
	output reg disp_hs, disp_vs;
	output reg [Red_Bits - 1:0] disp_red;
	output reg [Green_Bits - 1:0] disp_green;
	output reg [Blue_Bits - 1:0] disp_blue;
	output reg frame_begin;
	output reg disp_de;
	output disp_pclk;

	reg [11:0] h_cnt_r, v_cnt_r;

	`ifdef HW_VGA
		assign disp_pclk = ~clk_disp;
	`else
		assign disp_pclk = clk_disp;
	`endif

	assign data_req = disp_de;

	localparam 	hdat_begin = H_Sync_Time + H_Back_Porch + H_Left_Border - 1'b1,
				hdat_end = H_Total_Time - H_Right_Border - H_Front_Porch - 1'b1,
				vdat_begin = V_Sync_Time + V_Back_Porch + V_Top_Border - 1'b1,
				vdat_end = V_Total_Time - V_Bottom_Border - V_Front_Porch - 1'b1;

	assign addr_hs = disp_de ? (h_cnt_r - hdat_begin) : 0;
	assign addr_vs = disp_de ? (v_cnt_r - vdat_begin) : 0;

	wire h_end = (h_cnt_r >= H_Total_Time - 1);

	always@(posedge clk_disp or negedge rstn) begin
		if (!rstn)
			h_cnt_r <= 0;
		else begin
			if (h_end)
				h_cnt_r <= 0;
			else
				h_cnt_r <= h_cnt_r + 1;
		end
	end

	wire v_end = (v_cnt_r >= V_Total_Time - 1);

	always@(posedge clk_disp or negedge rstn) begin
		if (!rstn)
			v_cnt_r <= 0;
		else begin
			if (h_end) begin
				if (v_end)
					v_cnt_r <= 0;
				else
					v_cnt_r <= v_cnt_r + 1;
			end
			else
				v_cnt_r <= v_cnt_r;
		end
	end

	always@(posedge clk_disp) begin
		disp_de <= ((h_cnt_r >= hdat_begin) && (h_cnt_r < hdat_end)) && ((v_cnt_r >= vdat_begin) && (v_cnt_r < vdat_end));
	end

	always@(posedge clk_disp) begin
		disp_hs <= (h_cnt_r > H_Sync_Time - 1);
		disp_vs <= (v_cnt_r > V_Sync_Time - 1);
		{disp_red, disp_green, disp_blue} <= (disp_de) ? data : 1'd0;
	end

	reg disp_vs_delay;

	always@(posedge clk_disp) begin
		disp_vs_delay <= disp_vs;
	end

	always@(posedge clk_disp or negedge rstn) begin
		if (!rstn)
			frame_begin <= 0;
		else begin
			if (!disp_vs_delay && disp_vs)
				frame_begin <= 1;
			else
				frame_begin <= 0;
		end
	end

endmodule