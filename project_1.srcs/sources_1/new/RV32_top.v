module RV32_top #(parameter CLK_FREQ = 10_000_000) (
	input clk, rstn,
	inout [15:0] GPIO_x
);

	wire clksys = clk;

	wire [31:0] peri_addr;
	wire [31:0] peri_wdata;
	wire [3:0] peri_wmask;
	wire [31:0] peri_rdata;
	wire peri_wen;
	wire peri_ren;
	reg [31:0] peri_rdatafn;
	wire s4_sel_gpio = peri_addr[30];
	wire [31:0] rdata_uart;
	wire pready_uart;
	wire pslverr_uart;
	wire [2:0] peri_burst;
	wire [1:0] peri_htrans;
	wire peri_err;
	wire peri_rvalid;
	wire peri_wdone;
	reg peri_rvalidfn;
	reg peri_wdonefn;
	wire [3:0] HWSTRB;
	wire HCLK = clksys;
	wire [31:0] HADDR;
	wire [1:0] HTRANS;
	wire HWRITE;
	wire [2:0] HSIZE;
	wire [2:0] HBURST;
	wire [3:0] HPROT;
	wire HMASTLOCK;
	wire [31:0] HWDATA;
	wire [31:0] HRDATA;
	wire HREADY;
	wire HRESP;
	wire PCLK;
	wire PSEL;
	wire [31:0] PADDR;
	wire PWRITE;
	wire [31:0] PWDATA;
	wire [31:0] PWDATAT;
	wire [3:0] PSTRB;
	wire PENABLE;
	reg [31:0] PRDATA; 
	reg PREADY;
	reg PSLVERR;
	wire irq_out;
	wire [5:0] claim_id;
	wire irq_external_pending;
	wire trap_en;
	wire [31:0] rdata_plic;
	wire pready_plic;
	wire pslverr_plic; 
	wire [31:0] rdata_gpio;
	wire pready_gpio;
	wire pslverr_gpio;
	wire [31:0] rdata_uflash;
	wire err_uflash = 1'b0;
	wire ready_uflash = 1'b1;
	wire irqs1_rxuart;  
	wire irqs2_txuart;  
	wire [15:0] irqsx_gpio_pedge;
	wire [15:0] irqsx_gpio_nedge;   

	always@(*) begin
		PRDATA = (s4_sel_gpio)?rdata_gpio:32'h0;
	end

	always@(*) begin
		PREADY = (s4_sel_gpio)?pready_gpio:1'h0;
	end

	always @(*) begin
		PSLVERR = (s4_sel_gpio)?pslverr_gpio:1'h0;
	end

	always @(*) begin
		peri_rvalidfn = peri_rvalid;
		peri_wdonefn = peri_wdone;
		peri_rdatafn = peri_rdata;
		end

	RV32 #(.CLK_FREQ (CLK_FREQ)) RV32_isnt (
		.clk				(clksys),
		.rstn				(rstn),
		.peri_addr			(peri_addr),
		.peri_wdata		(peri_wdata),
		.peri_wmask		(peri_wmask),
		.peri_rdata		(peri_rdatafn),
		.peri_wen			(peri_wen),
		.peri_ren			(peri_ren),
		.peri_burst		(peri_burst),
		.peri_htrans		(peri_htrans),
		.peri_rvalid		(peri_rvalidfn),
		.peri_wdone		(peri_wdonefn),
		.peri_err			(peri_err),
		.irq_flag			(irq_out),
		.irq_external_pending(irq_external_pending),
		.trap_en        		(trap_en)
	);

	ahb3lite_master_adapter ahb3lite_master_adapter_inst (
		.HCLK			(HCLK),
		.HRESETn		(rstn),
		.peri_addr			(peri_addr),
		.peri_wdata		(peri_wdata),
		.peri_wmask		(peri_wmask),
		.peri_wen			(peri_wen),
		.peri_ren			(peri_ren),
		.peri_burst		(peri_burst),
		.peri_htrans		(peri_htrans),
		.peri_rvalid		(peri_rvalid),
		.peri_wdone		(peri_wdone),
		.peri_rdata		(peri_rdata),
		.peri_err			(peri_err),
		.PWDATAT		(PWDATAT),
		.HWSTRB		(HWSTRB),
		.HADDR			(HADDR),
		.HTRANS		(HTRANS),
		.HWRITE		(HWRITE),
		.HSIZE			(HSIZE),
		.HBURST		(HBURST),
		.HWDATA		(HWDATA),
		.HRDATA		(HRDATA),
		.HREADY		(HREADY),
		.HRESP			(HRESP)
	);

	ahb3lite_to_apb_bridge ahb3lite_to_apb_bridge_inst (
		.HCLK			(HCLK),
		.HRESETn		(rstn),
		.PWDATAT		(PWDATAT),
		.HWSTRB		(HWSTRB),
		.HADDR			(HADDR),
		.HTRANS		(HTRANS),
		.HWRITE		(HWRITE),
		.HBURST		(HBURST),
		.HSIZE			(HSIZE),
		.HWDATA		(HWDATA),
		.HRDATA		(HRDATA),
		.HREADY		(HREADY),
		.HRESP			(HRESP),
		.PCLK			(PCLK),
		.PADDR			(PADDR),
		.PWRITE			(PWRITE),
		.PWDATA		(PWDATA),
		.PSTRB			(PSTRB),
		.PSEL			(PSEL),
		.PENABLE		(PENABLE),
		.PRDATA		(PRDATA),
		.PREADY		(PREADY),
		.PSLVERR		(PSLVERR)
	);

	gpio_ip gpio_ip_inst(
		.PCLK			(PCLK),
		.PRESETn		(rstn),
		.PSEL			(s4_sel_gpio && PSEL),
		.PADDR			({4'h0, PADDR[27:0]}),
		.PENABLE		(PENABLE),
		.PWRITE			(PWRITE),
		.PWDATA		(PWDATA),
		.PSTRB			(PSTRB),
		.PRDATA		(rdata_gpio),
		.PREADY		(pready_gpio),
		.PSLVERR		(pslverr_gpio),
		.GPIO_x			(GPIO_x)
	);

endmodule
