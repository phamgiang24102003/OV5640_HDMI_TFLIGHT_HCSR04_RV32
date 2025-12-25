module axi42fifo #(	parameter RD_AXI_BYTE_ADDR_BEGIN	= 0,
				parameter RD_AXI_BYTE_ADDR_END		= 200,
				parameter AXI_DATA_WIDTH			= 128,
				parameter AXI_ADDR_WIDTH			= 28,
				parameter AXI_ID_WIDTH				= 4,
				parameter AXI_ID						= 4'b0000,
				parameter AXI_BURST_LEN				= 8'd31	// burst length = 32
) (
	clk, rstn,
	addr_clr,
	fifo_wrreq,
	fifo_wrdata,
	fifo_alfull,
	fifo_wr_cnt,
	fifo_rst_busy,
	m_axi_arid,
	m_axi_araddr,
	m_axi_arlen,
	m_axi_arsize,
	m_axi_arburst,
	m_axi_arlock,
	m_axi_arcache,
	m_axi_arprot,
	m_axi_arqos,
	m_axi_arregion,
	m_axi_arvalid,
	m_axi_arready,
	m_axi_rid,
	m_axi_rdata,
	m_axi_rresp,
	m_axi_rlast,
	m_axi_rvalid,
	m_axi_rready
);

	input clk, rstn;
	// Read FIFO Write Interface
	input addr_clr;
	output reg fifo_wrreq;
	output reg [AXI_DATA_WIDTH-1:0] fifo_wrdata;
	input fifo_alfull;
	input [8:0] fifo_wr_cnt;
	input fifo_rst_busy;
	// AXI4 Master Read Address Channel
	output [AXI_ID_WIDTH-1:0] m_axi_arid;
	output reg [AXI_ADDR_WIDTH-1:0] m_axi_araddr;
	output [7:0] m_axi_arlen;
	output [2:0] m_axi_arsize;
	output [1:0] m_axi_arburst;
	output m_axi_arlock;
	output [3:0] m_axi_arcache;
	output [2:0] m_axi_arprot;
	output [3:0] m_axi_arqos;
	output [3:0] m_axi_arregion;
	output reg	m_axi_arvalid;
	input m_axi_arready;
	// AXI4 Master Read Data Channel
	input [AXI_ID_WIDTH-1:0] m_axi_rid;
	input [AXI_DATA_WIDTH-1:0] m_axi_rdata;
	input [1:0] m_axi_rresp;
	input m_axi_rlast;
	input m_axi_rvalid;
	output m_axi_rready;

	localparam 	S_IDLE		= 3'b001,
				S_RD_ADDR	= 3'b010,
				S_RD_RESP	= 3'b100;

	function integer clogb2;
		input integer axi_data_byte;
		begin
			for (clogb2 = 0; axi_data_byte > 0; clogb2 = clogb2 + 1)
				axi_data_byte = axi_data_byte >> 1;
		end
	endfunction

	localparam DATA_SIZE = clogb2(AXI_DATA_WIDTH / 8 - 1);

	wire [8:0] rd_req_cnt_thresh;
	wire rd_ddr3_req;
	reg axi_araddr_clr;
	reg [2:0] curr_state;
	reg [2:0] next_state;

	// AXI4 Read Address Channel Default Assignments
	assign m_axi_arid = AXI_ID[AXI_ID_WIDTH-1:0];
	assign m_axi_arsize = DATA_SIZE;
	assign m_axi_arburst = 2'b01;	// INCR mode
	assign m_axi_arlock = 1'b0;
	assign m_axi_arcache = 4'b0000;
	assign m_axi_arprot = 3'b000;
	assign m_axi_arqos = 4'b0000;
	assign m_axi_arregion = 4'b0000;
	assign m_axi_arlen = AXI_BURST_LEN[7:0];

	// AXI Read Data Channel ready when FIFO is not almost full
	assign m_axi_rready = ~fifo_alfull;
	assign rd_req_cnt_thresh = AXI_BURST_LEN[7:0];
	assign rd_ddr3_req = (fifo_rst_busy == 1'b0) && (fifo_wr_cnt < rd_req_cnt_thresh - 1'b1) ? 1'b1 : 1'b0;

	// AXI address clear logic
	always@(posedge clk or negedge rstn) begin
		if (!rstn)
			axi_araddr_clr <= 1'b0;
		else begin
			if (m_axi_rready && m_axi_rvalid && m_axi_rlast)
				axi_araddr_clr <= 1'b0;
			else if (addr_clr && (m_axi_arvalid || m_axi_rvalid))
				axi_araddr_clr <= 1'b1;
			else
				axi_araddr_clr <= axi_araddr_clr;
		end
	end

	// AXI Read Address generation (m_axi_araddr)
	always @(posedge clk or negedge rstn) begin
		if (!rstn)
			m_axi_araddr <= RD_AXI_BYTE_ADDR_BEGIN;
		else begin
			if (addr_clr || axi_araddr_clr)
				m_axi_araddr <= RD_AXI_BYTE_ADDR_BEGIN;
			else if (m_axi_araddr >= RD_AXI_BYTE_ADDR_END)
				m_axi_araddr <= RD_AXI_BYTE_ADDR_BEGIN;
			else if ((curr_state == S_RD_RESP) && m_axi_rready && m_axi_rvalid && m_axi_rlast && (m_axi_rresp == 2'b00) && (m_axi_rid == AXI_ID[AXI_ID_WIDTH-1:0]))
				m_axi_araddr <= m_axi_araddr + ((m_axi_arlen + 1'b1) * (AXI_DATA_WIDTH / 8));
			else
				m_axi_araddr <= m_axi_araddr;
		end
	end

	// AXI Read Address valid signal (m_axi_arvalid)
	always @(posedge clk or negedge rstn) begin
		if (!rstn)
			m_axi_arvalid <= 1'b0;
		else begin
			if ((curr_state == S_RD_ADDR) && m_axi_arready && m_axi_arvalid)
				m_axi_arvalid <= 1'b0;
			else if (curr_state == S_RD_ADDR)
				m_axi_arvalid <= 1'b1;
			else
				m_axi_arvalid <= m_axi_arvalid;
		end
	end

	// FIFO write data from AXI read data
	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			fifo_wrreq  <= 1'b0;
			fifo_wrdata <= {AXI_DATA_WIDTH{1'b0}};
		end
		else begin
			if (addr_clr || axi_araddr_clr) begin
				fifo_wrreq  <= 1'b0;
				fifo_wrdata <= {AXI_DATA_WIDTH{1'b0}};
			end
			else if (m_axi_rvalid && m_axi_rready) begin
				fifo_wrreq  <= 1'b1;
				fifo_wrdata <= m_axi_rdata;
			end
			else begin
				fifo_wrreq  <= 1'b0;
				fifo_wrdata <= {AXI_DATA_WIDTH{1'b0}};
			end
		end
	end

	// Read State Machine
	always @(posedge clk or negedge rstn) begin
		if (!rstn)
			curr_state <= S_IDLE;
		else
			curr_state <= next_state;
	end

	always @(*) begin
		case (curr_state)
			S_IDLE: begin
				if (rd_ddr3_req)
					next_state = S_RD_ADDR;
				else
					next_state = S_IDLE;
			end

			S_RD_ADDR: begin
				if (m_axi_arready && m_axi_arvalid)
					next_state = S_RD_RESP;
				else
					next_state = S_RD_ADDR;
			end

			S_RD_RESP: begin
				if (m_axi_rready && m_axi_rvalid && m_axi_rlast &&
					(m_axi_rresp == 2'b00) && (m_axi_rid == AXI_ID[AXI_ID_WIDTH-1:0]))
					next_state = S_IDLE;
				else
					next_state = S_RD_RESP;
			end

			default: next_state = S_IDLE;
		endcase
	end

endmodule