module ahb3lite_to_apb_bridge (
	input HCLK,
	input HRESETn,
	input [31:0] PWDATAT,
	//AHB-Lite slave interface,
	input [3:0] HWSTRB,
	input [31:0] HADDR,
	input [1:0] HTRANS,
	input HWRITE,
	input [2:0] HBURST,
	input [2:0] HSIZE,
	input [31:0] HWDATA,
	output reg [31:0] HRDATA,
	output reg HREADY,
	output reg HRESP,
	//APB master interface,
	output PCLK,
	output reg [31:0] PADDR,
	output reg PWRITE,
	output reg [31:0] PWDATA,
	output reg [3:0] PSTRB,
	output reg PSEL,
	output reg PENABLE,
	input [31:0] PRDATA,
	input PREADY,
	input PSLVERR
);

	localparam	ST_IDLE = 2'b00,
				ST_SETUP = 2'b01,
				ST_ACCESS = 2'b10;

	`ifndef DIVCLK
		assign PCLK = HCLK;
	`endif
	`ifdef  DIVCLK
		Gowin_CLKDIV CLKDIV8 (
			.clkout(PCLK),			//output clkout
			.hclkin(HCLK),			//input hclkin
			.resetn(HRESETn)		//input resetn
		);
		clk_div8 CLKDIV8 (
			.clk_out(PCLK),
			.clk_in (HCLK),
			.rstn   (HRESETn)
		);
	`endif

	reg [2:0] state = ST_IDLE;
	reg [2:0] next_state = ST_IDLE;
	reg apb_done = 1'b0;
	reg PENABLE_shift1 = 1'b0;

	`ifdef DIVCLK
		always @(posedge PCLK) begin
			HREADY <= apb_done && PENABLE_shift1;
		end

		always @(posedge HCLK) begin
			PENABLE_shift1 <= PENABLE;
		end

		always @(posedge PCLK) begin
			if (!HRESETn)
				apb_done <= 1'b0;
			else if (state == ST_ACCESS && PREADY)
				apb_done <= 1'b1;
			else
				apb_done <= 1'b0;
		end
	`endif
	`ifndef DIVCLK
		always @(posedge PCLK) begin
			HREADY <= PENABLE && PREADY;
		end
	`endif

	always @(posedge PCLK) begin
		if (!HRESETn) begin
			PSEL <= 0;
			PENABLE <= 0;
			state <= ST_IDLE;
			PADDR <= HADDR;
			PWRITE <= HWRITE;
			PWDATA <= PWDATAT;
			PSTRB <= HWSTRB;
			HRDATA <= PRDATA;
			HRESP <= PSLVERR; 
		end
		PSEL    <= 0;
		PENABLE <= 0;
		PADDR <= HADDR;
		PWRITE <= HWRITE;
		PWDATA <= PWDATAT;
		PSTRB <= HWSTRB;
		HRDATA <= PRDATA;
		HRESP <= PSLVERR;
		//HREADY <= PENABLE && PREADY;
		case(state)
			ST_IDLE: begin
				if (HTRANS[1] && !HREADY) begin	// NONSEQ/SEQ
					PSEL <= 1;
					state <= ST_SETUP;
				end
			end

			ST_SETUP: begin
				PSEL <= 1;
				PENABLE <= 0;
				state <= ST_ACCESS;
				end

			ST_ACCESS: begin
				if (PREADY && PENABLE)
					state <= ST_IDLE;
				else begin
					PSEL <= 1;
					PENABLE <= 1;
				end
			end
		endcase
	end

endmodule