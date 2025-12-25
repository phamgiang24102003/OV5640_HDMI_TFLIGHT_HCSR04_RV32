module fifo2axi4 #(	parameter WR_AXI_BYTE_ADDR_BEGIN	= 0,
				parameter WR_AXI_BYTE_ADDR_END	= 200,
				parameter AXI_DATA_WIDTH			= 128,
				parameter AXI_ADDR_WIDTH			= 28,
				parameter AXI_ID_WIDTH				= 4,
				parameter AXI_ID						= 4'b0000,
				parameter AXI_BURST_LEN				= 8'd31	// burst length = 32
) (
	clk, rstn,
	addr_clr,
	fifo_rdreq,
	fifo_rddata,
	fifo_empty,
	fifo_rd_cnt,
	fifo_rst_busy,
	m_axi_awid,
	m_axi_awaddr,
	m_axi_awlen,
	m_axi_awsize,
	m_axi_awburst,
	m_axi_awlock,
	m_axi_awcache,
	m_axi_awprot,
	m_axi_awqos,
	m_axi_awregion,
	m_axi_awvalid,
	m_axi_awready,
	m_axi_wdata,
	m_axi_wstrb,
	m_axi_wlast,
	m_axi_wvalid,
	m_axi_wready,
	m_axi_bid,
	m_axi_bresp,
	m_axi_bvalid,
	m_axi_bready
);

	input clk, rstn;
	// FIFO Read Interface (write to AXI)
	input addr_clr;							// Synchronous clear signal
	output reg fifo_rdreq;					// FIFO read request
	input	[AXI_DATA_WIDTH-1:0] fifo_rddata;	// FIFO read data
	input fifo_empty;						// FIFO empty flag
	input	[8:0] fifo_rd_cnt;					// FIFO read count
	input fifo_rst_busy;						// FIFO reset busy flag
	// AXI4 Master Write Address Channel
	output [AXI_ID_WIDTH-1:0] m_axi_awid;
	output reg [AXI_ADDR_WIDTH-1:0] m_axi_awaddr;
	output [7:0] m_axi_awlen;
	output [2:0] m_axi_awsize;
	output [1:0] m_axi_awburst;
	output m_axi_awlock;
	output [3:0] m_axi_awcache;
	output [2:0] m_axi_awprot;
	output [3:0] m_axi_awqos;
	output [3:0] m_axi_awregion;
	output reg m_axi_awvalid;
	input m_axi_awready;
	// AXI4 Master Write Data Channel
	output [AXI_DATA_WIDTH-1:0] m_axi_wdata;
	output [AXI_DATA_WIDTH/8-1:0] m_axi_wstrb;
	output reg m_axi_wlast;
	output reg m_axi_wvalid;
	input m_axi_wready;
	// AXI4 Master Write Response Channel
	input	[AXI_ID_WIDTH-1:0] m_axi_bid;
	input	[1:0] m_axi_bresp;
	input m_axi_bvalid;
	output m_axi_bready;

	localparam	S_IDLE				= 5'b00001,
				S_WR_ADDR			= 5'b00010,
				S_WR_DATA_PRE	= 5'b00100,
				S_WR_DATA			= 5'b01000,
				S_WR_RESP			= 5'b10000;

	function integer clogb2;
		input integer axi_data_byte;
		begin
			for (clogb2 = 0; axi_data_byte > 0; clogb2 = clogb2 + 1)
				axi_data_byte = axi_data_byte >> 1;
		end
	endfunction

	localparam DATA_SIZE = clogb2(AXI_DATA_WIDTH / 8 - 1);

	wire [8:0] wr_req_cnt_thresh;
	wire wr_ddr3_req;
	reg axi_awaddr_clr;
	reg fifo_rddata_valid;
	reg [AXI_DATA_WIDTH-1:0] fifo_rddata_latch;
	reg [4:0] curr_wr_state;
	reg [4:0] next_wr_state;
	reg [7:0] wr_data_cnt;

	assign m_axi_awid = AXI_ID[AXI_ID_WIDTH-1:0];
	assign m_axi_awsize	= DATA_SIZE;
	assign m_axi_awburst = 2'b01;						// INCR burst
	assign m_axi_awlock = 1'b0;
	assign m_axi_awcache = 4'b0000;
	assign m_axi_awprot = 3'b000;
	assign m_axi_awqos = 4'b0000;
	assign m_axi_awregion = 4'b0000;
	assign m_axi_awlen = AXI_BURST_LEN[7:0];
	assign m_axi_wstrb = {AXI_DATA_WIDTH/8{1'b1}};
	assign m_axi_bready = 1'b1;						// Always ready to accept response

	assign wr_req_cnt_thresh = (m_axi_awlen == 'd0) ? 1'b1 : (AXI_BURST_LEN[7:0] + 1'b1);
	assign wr_ddr3_req = (!fifo_rst_busy && !fifo_empty && (fifo_rd_cnt >= wr_req_cnt_thresh)) ? 1'b1 : 1'b0;

	// AXI address clear logic
	always @(posedge clk or negedge rstn) begin
		if (!rstn)
			axi_awaddr_clr <= 1'b0;
		else begin
			if (m_axi_wready && m_axi_wvalid && m_axi_wlast)
				axi_awaddr_clr <= 1'b0;
			else if (addr_clr && (m_axi_awvalid || m_axi_wvalid))
				axi_awaddr_clr <= 1'b1;
		end
	end

	// AXI Write Address generation
	always @(posedge clk or negedge rstn) begin
		if (!rstn)
			m_axi_awaddr <= WR_AXI_BYTE_ADDR_BEGIN;
		else begin
			if (addr_clr || axi_awaddr_clr)
				m_axi_awaddr <= WR_AXI_BYTE_ADDR_BEGIN;
			else if (m_axi_awaddr >= WR_AXI_BYTE_ADDR_END)
				m_axi_awaddr <= WR_AXI_BYTE_ADDR_BEGIN;
			else if ((curr_wr_state == S_WR_RESP) && m_axi_bready && m_axi_bvalid && (m_axi_bresp == 2'b00) && (m_axi_bid == AXI_ID[AXI_ID_WIDTH-1:0]))
				m_axi_awaddr <= m_axi_awaddr + ((m_axi_awlen + 1'b1) * (AXI_DATA_WIDTH / 8));
		end
	end

	// AXI Write Address valid signal
	always @(posedge clk or negedge rstn) begin
		if (!rstn)
			m_axi_awvalid <= 1'b0;
		else begin
			if ((curr_wr_state == S_WR_ADDR) && m_axi_awready && m_axi_awvalid)
				m_axi_awvalid <= 1'b0;
			else if (curr_wr_state == S_WR_ADDR)
				m_axi_awvalid <= 1'b1;
		end
	end

	// FIFO read control
	always @(posedge clk or negedge rstn) begin
		if (!rstn)
			fifo_rdreq <= 1'b0;
		else begin
			if ((curr_wr_state == S_WR_ADDR) && m_axi_awready && m_axi_awvalid)
				fifo_rdreq <= 1'b1;
			else if ((curr_wr_state == S_WR_DATA) && m_axi_wready && m_axi_wvalid && !m_axi_wlast)
				fifo_rdreq <= 1'b1;
			else
				fifo_rdreq <= 1'b0;
		end
	end

	always @(posedge clk) begin
		fifo_rddata_valid <= fifo_rdreq;
	end

	// FIFO read data latch
	always @(posedge clk or negedge rstn) begin
		if (!rstn)
			fifo_rddata_latch <= {AXI_DATA_WIDTH{1'b0}};
		else begin
			if (fifo_rddata_valid)
				fifo_rddata_latch <= fifo_rddata;
		end
	end

	assign m_axi_wdata = fifo_rddata_latch;

	// AXI Write data valid
	always @(posedge clk or negedge rstn) begin
		if (!rstn)
			m_axi_wvalid <= 1'b0;
		else begin
			if (m_axi_wready && m_axi_wvalid)
				m_axi_wvalid <= 1'b0;
			else if (fifo_rddata_valid)
				m_axi_wvalid <= 1'b1;
		end
	end

	// Write data counter
	always @(posedge clk or negedge rstn) begin
		if (!rstn)
			wr_data_cnt <= 0;
		else begin
			if (curr_wr_state == S_IDLE)
				wr_data_cnt <= 0;
			else if (m_axi_wready && m_axi_wvalid)
				wr_data_cnt <= wr_data_cnt + 1'b1;
		end
	end

	// AXI Write last signal
	always @(posedge clk or negedge rstn) begin
		if (!rstn)
			m_axi_wlast <= 1'b0;
		else begin
			if (m_axi_wready && m_axi_wvalid && m_axi_wlast)
				m_axi_wlast <= 1'b0;
			else if (m_axi_awlen == 8'd0)
				m_axi_wlast <= 1'b1;
			else if (m_axi_wready && m_axi_wvalid && (wr_data_cnt == m_axi_awlen - 1'b1))
				m_axi_wlast <= 1'b1;
		end
	end

	// AXI Write FSM
	always @(posedge clk or negedge rstn) begin
		if (!rstn)
			curr_wr_state <= S_IDLE;
		else
			curr_wr_state <= next_wr_state;
	end

	always @(*) begin
		case (curr_wr_state)
			S_IDLE : begin
				if (wr_ddr3_req)
					next_wr_state = S_WR_ADDR;
				else
					next_wr_state = S_IDLE;
			end

			S_WR_ADDR : begin
				if (m_axi_awready && m_axi_awvalid)
					next_wr_state = S_WR_DATA_PRE;
				else
					next_wr_state = S_WR_ADDR;
			end

			S_WR_DATA_PRE : next_wr_state = S_WR_DATA;

			S_WR_DATA : begin
				if (m_axi_wready && m_axi_wvalid && m_axi_wlast)
					next_wr_state = S_WR_RESP;
				else if (m_axi_wready && m_axi_wvalid)
					next_wr_state = S_WR_DATA_PRE;
				else
					next_wr_state = S_WR_DATA;
			end

			S_WR_RESP : begin
				if (m_axi_bready && m_axi_bvalid && (m_axi_bresp == 2'b00) &&
					(m_axi_bid == AXI_ID[AXI_ID_WIDTH-1:0]))
					next_wr_state = S_IDLE;
				else
					next_wr_state = S_WR_RESP;
			end

			default : next_wr_state = S_IDLE;
		endcase
	end

endmodule