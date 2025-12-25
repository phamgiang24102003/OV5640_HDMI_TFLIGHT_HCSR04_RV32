module ahb3lite_master_adapter (
	input HCLK,
	input HRESETn,
	// Simple CPU/DMAC request interface
	input [31:0] peri_addr,
	input [31:0] peri_wdata,
	input [3:0] peri_wmask,		// 0000=read; otherwise write strobes,
	input peri_wen,
	input peri_ren,
	input [2:0] peri_burst,
	input [1:0] peri_htrans,
	// Read return (per beat)
	output peri_rvalid,        
	output peri_wdone,
	output [31:0] peri_rdata,
	output peri_err,
	output [31:0] PWDATAT,
	// AHB Litete master bus
    	output reg [3:0] HWSTRB,
	output reg [31:0] HADDR,
	output reg [1:0] HTRANS,
	output reg HWRITE,
	output reg [2:0] HSIZE,
	output [2:0] HBURST,
	output reg [31:0] HWDATA,
	input [31:0] HRDATA,
	input HREADY,
	input HRESP
);

	localparam	HTRANS_IDLE = 2'b00,
				HTRANS_BUSY = 2'b01,
				HTRANS_NONSEQ = 2'b10,
				HTRANS_SEQ = 2'b11;

	reg [1:0] state;
	reg [4:0] count_burst;
	reg [4:0] cnt_burst_max;
	reg burst_done;
	reg [2:0] plus;

	function [2:0] f_plus_from_wstrb;
		input [3:0] wstrb;
	begin
		case (wstrb)
			4'b0001,4'b0010,4'b0100,4'b1000: f_plus_from_wstrb = 3'd1;	// byte
			4'b0011,4'b1100: f_plus_from_wstrb = 3'd2; 				// half
			4'b1111: f_plus_from_wstrb = 3'd4; 						// word
			default: f_plus_from_wstrb = 3'd4;
		endcase
	end
	endfunction

	function [2:0] f_hsize_from_wstrb;
		input [3:0] wstrb;
	begin
		case (wstrb)
			4'b0001,4'b0010,4'b0100,4'b1000: f_hsize_from_wstrb = 3'b000;	// byte
			4'b0011,4'b1100: f_hsize_from_wstrb = 3'b001;				// half
			4'b1111: f_hsize_from_wstrb = 3'b010; 						// word
			default: f_hsize_from_wstrb = 3'b010;
		endcase
	end
	endfunction

	function [4:0] f_count_from_burst;
		input [2:0] burst;
	begin
		case (burst)
			3'b000: f_count_from_burst = 5'd1; 			// Single transfer
			3'b001: f_count_from_burst = 5'd0; 			// Incrementing burst of undefined length
			3'b010, 3'b011: f_count_from_burst = 5'd4; 	// 4-beat burst
			3'b100, 3'b101: f_count_from_burst = 5'd8; 	// 8-beat burst 
			3'b110, 3'b111: f_count_from_burst = 5'd16; 	// 16-beat burst               
			default: f_count_from_burst = 5'b1;
		endcase
	end
	endfunction

	assign HBURST = peri_burst;
	assign peri_rdata = HRDATA;
	assign peri_rvalid = HREADY && peri_ren;
	assign peri_wdone = HREADY && peri_wen;
	assign peri_err = HRESP;
	assign PWDATAT = peri_wdata;

	reg [31:0] HWDATA_ff;

	always @(posedge HCLK) begin
		if (!HRESETn)
			HWDATA_ff <= 32'h0;
		else
            HWDATA_ff <= peri_wdata;
	end

	reg [31:0] t_addr;

	always @(*) begin
		HWSTRB = peri_wmask;
		HTRANS = peri_htrans;
		HWDATA = HWDATA_ff;
		HSIZE  = f_hsize_from_wstrb(peri_wmask);
		HWRITE = |peri_wmask && peri_wen;
		HADDR  = (peri_htrans == HTRANS_SEQ)?peri_addr + f_plus_from_wstrb(peri_wmask)*count_burst:peri_addr;
		if (state == 0) begin
			HWSTRB = HWSTRB;   HTRANS = HTRANS;
			HWDATA = HWDATA;   HSIZE  = HSIZE;
			HWRITE = HWRITE;   HADDR  = HADDR;
		end
	end

	always @(posedge HCLK) begin
		if (!HRESETn) begin
			state <= 2'b00;
			count_burst <= 0;
		end
		else begin            
			case (peri_htrans)
				HTRANS_IDLE: state <= 2'b0;
				HTRANS_BUSY: state <= 2'b0;
				HTRANS_NONSEQ: state <= 2'b0;
				HTRANS_SEQ: begin 
					count_burst <= count_burst + 1;
					case(state) 
						2'b00: begin
							case (f_count_from_burst(peri_burst)) 
								4'd0: state <= 2'b10;
								4'd1: begin
									count_burst <= count_burst;
									state <= 2'b11;
								end
								default: begin
									cnt_burst_max <= f_count_from_burst(peri_burst)-1;
									state <= 2'b01;		//4 8 16
								end
							endcase

						end
						2'b01: begin
							if (count_burst == cnt_burst_max - 1)
								state <= 2'b11;
						end
						2'b10: begin
						end
						2'b11: count_burst <= count_burst;
					endcase
				end
			endcase
		end
	end
endmodule