`include "disp_parameter_cfg.v"

module top #(	parameter	IMAGE_WIDTH			= 1280,
							IMAGE_HEIGHT			= 720,
							STREAM_ADDR_BEGIN	= 32'h1800000,
							CAPTURE_ADDR_BEGIN 	= 32'h1A00000
) (
	input rstn,
	output led,
	// Camera interface
	output camera_scl,
	inout camera_sda,
	input camera_vsync,
	input camera_href,
	input camera_pclk,
	input [7:0] camera_data,
	output camera_rst,
	output camera_pwdn,
	// HC-SR04
	input echo,
	output trigger,
	// TF LIGHT
	output [2:0] tf_light,
	output [1:0] kathode,
	output [6:0] seg,
	//UART
	input RX,
	output TX,
	// HDMI interface
	output hdmi_clk_p,
	output hdmi_clk_n,
	output [2:0] hdmi_dat_p,
	output [2:0] hdmi_dat_n,
	// DDR3 interface
	inout [31:0] ddr3_dq,
	inout [3:0] ddr3_dqs_n,
	inout [3:0] ddr3_dqs_p,
	output [14:0] ddr3_addr,
	output[2:0] ddr3_ba,
	output ddr3_ras_n,
	output ddr3_cas_n,
	output ddr3_we_n,
	output ddr3_reset_n,
	output ddr3_ck_p,
	output ddr3_ck_n,
	output ddr3_cke,
	output ddr3_cs_n,
	output [3:0] ddr3_dm,
	output ddr3_odt,
	inout FIXED_IO_ddr_vrn,
	inout FIXED_IO_ddr_vrp,
	inout [53:0] FIXED_IO_mio,
	inout FIXED_IO_ps_clk,
	inout FIXED_IO_ps_porb,
	inout FIXED_IO_ps_srstb
);

	// Clock & reset
	wire ps2pl_clk50m_0;
	wire ps2pl_resetn_0;
	wire pll_locked;
	wire clk_100Mhz, clk_200Mhz, clk_10Mhz, clk_40Mhz;
	wire disp_clk;
	wire disp_clk5x;
	wire reset;
	// Camera
	wire done;
	wire pclk_bufg_o;
	wire [15:0] image_data;
	wire image_data_valid;
	wire image_data_hs;
	wire image_data_vs;
	// Display
	wire frame_begin;
	wire disp_data_req;
	wire [23:0] disp_data;
	// VGA
	wire [23:0] vga_rgb;
	wire vga_hs;
	wire vga_vs;
	wire vga_clk;
	wire vga_de;
	wire [4:0]	Disp_Red;
	wire [5:0]	Disp_Green;
	wire [4:0]	Disp_Blue;
	// FIFO interfaces
	wire wrfifo_clr;
	wire [15:0] wrfifo_din;
	wire wrfifo_wren_capture, wrfifo_wren_streaming;
	wire rdfifo_clr_streaming, rdfifo_clr_capture;
	wire rdfifo_rden;
	wire [15:0] rdfifo_dout;
	// AXI signals (PL <-> PS)
	wire [3:0]	s_axi_awid_0, s_axi_awid_1;
	wire [31:0] s_axi_awaddr_0, s_axi_awaddr_1;
	wire [7:0]	s_axi_awlen_0, s_axi_awlen_1;
	wire [2:0]	s_axi_awsize_0, s_axi_awsize_1;
	wire [1:0]	s_axi_awburst_0, s_axi_awburst_1;
	wire s_axi_awlock_0, s_axi_awlock_1;
	wire [3:0]	s_axi_awcache_0, s_axi_awcache_1;
	wire [2:0]	s_axi_awprot_0, s_axi_awprot_1;
	wire [3:0]	s_axi_awqos_0, s_axi_awqos_1;
	wire [3:0]	s_axi_awregion_0, s_axi_awregion_1;
	wire s_axi_awvalid_0, s_axi_awvalid_1;
	wire s_axi_awready_0, s_axi_awready_1;
	wire [63:0] s_axi_wdata_0, s_axi_wdata_1;
	wire [7:0]	s_axi_wstrb_0, s_axi_wstrb_1;
	wire s_axi_wlast_0, s_axi_wlast_1;
	wire s_axi_wvalid_0, s_axi_wvalid_1;
	wire s_axi_wready_0, s_axi_wready_1;
	wire [3:0]	s_axi_bid_0, s_axi_bid_1;
	wire [1:0]	s_axi_bresp_0, s_axi_bresp_1;
	wire s_axi_bvalid_0, s_axi_bvalid_1;
	wire s_axi_bready_0, s_axi_bready_1;
	wire [3:0]	s_axi_arid_0, s_axi_arid_1;
	wire [31:0] s_axi_araddr_0, s_axi_araddr_1;
	wire [7:0]	s_axi_arlen_0, s_axi_arlen_1;
	wire [2:0]	s_axi_arsize_0, s_axi_arsize_1;
	wire [1:0]	s_axi_arburst_0, s_axi_arburst_1;
	wire [0:0]	s_axi_arlock_0, s_axi_arlock_1;
	wire [3:0]	s_axi_arcache_0, s_axi_arcache_1;
	wire [2:0]	s_axi_arprot_0, s_axi_arprot_1;
	wire [3:0]	s_axi_arqos_0, s_axi_arqos_1;
	wire [3:0]	s_axi_arregion_0, s_axi_arregion_1;
	wire s_axi_arvalid_0 , s_axi_arvalid_1;
	wire s_axi_arready_0, s_axi_arready_1;
	wire [3:0] s_axi_rid_0, s_axi_rid_1;
	wire [63:0] s_axi_rdata_0, s_axi_rdata_1;
	wire [1:0]	s_axi_rresp_0, s_axi_rresp_1;
	wire s_axi_rlast_0, s_axi_rlast_1;
	wire s_axi_rvalid_0, s_axi_rvalid_1;
	wire s_axi_rready_0, s_axi_rready_1;
	wire s_axi_aclk_0, s_axi_aclk_1;
	wire s_axi_resetn_0, s_axi_resetn_1;

	wire pl_reset_n;
	wire reset_pre;
	reg [19:0] reset_sync;

	wire snapshot_req;
	wire snapshot_active;
	wire snapshot_done;

	wire cap_rdfifo_rden;
	wire [15:0] cap_rdfifo_dout;
	wire cap_rdfifo_empty;
	
	wire uart_tx_active;
	
	wire data_valid;
	wire [15:0] image_data_in;

	assign s_axi_aclk_0 = clk_200Mhz;
	assign s_axi_aclk_1 = clk_200Mhz;
	assign led = done;

	assign pl_reset_n = ps2pl_resetn_0 & rstn;
	assign reset_pre = ~pll_locked;

	// Delay PL reset by 20 cycles after PLL lock
	always @(posedge clk_200Mhz or posedge reset_pre) begin
		if (reset_pre)
			reset_sync <= {20{1'b1}};
		else
			reset_sync <= reset_sync << 1;
	end

	assign reset = reset_sync[19];
	assign s_axi_resetn_0 = pll_locked;
	assign s_axi_resetn_1 = pll_locked;

	assign wrfifo_clr = reset;
	assign wrfifo_wren_streaming = image_data_valid;
	assign wrfifo_wren_capture = image_data_valid & snapshot_active;
	assign wrfifo_din  = image_data;

	assign rdfifo_clr_streaming = reset || frame_begin;
	assign rdfifo_clr_capture = reset;
	assign rdfifo_rden = disp_data_req;
	assign disp_data = {	rdfifo_dout[15:11], 3'd0,
					rdfifo_dout[10:05], 2'd0,
					rdfifo_dout[04:00], 3'd0};

	assign camera_pwdn = 1'b0;

	wire obj_dct;

	reg [4:0] ready_cnt;
	reg ready_seen;
	reg vsync_d;
	wire vsync_fall = ~camera_vsync & vsync_d;

	always @(posedge pclk_bufg_o or negedge rstn) begin
		if (!rstn) begin
			ready_cnt <= 0;
			ready_seen <= 0;
			vsync_d <= 0;
		end
		else begin
			vsync_d <= camera_vsync;
			if (done && !ready_seen && vsync_fall) begin
				if (ready_cnt == 5'd12)
					ready_seen <= 1'b1;
				else
					ready_cnt <= ready_cnt + 1'b1;
			end
		end
	end

	reg obj_s1, obj_s2, obj_s2_d;
	wire obj_sync = obj_s2;
	wire obj_rise = obj_sync & ~obj_s2_d;

	always @(posedge pclk_bufg_o or negedge rstn) begin
		if (!rstn) begin
			obj_s1 <= 0;
			obj_s2 <= 0;
			obj_s2_d <= 0;
		end
		else begin
			obj_s1 <= obj_dct;
			obj_s2 <= obj_s1;
			obj_s2_d <= obj_s2;
		end
	end

	reg snap_pending;
	reg snap_pulse;
	reg uart_tx_active_s1, uart_tx_active_s2;
	wire uart_tx_active_sync;

	always @(posedge pclk_bufg_o or negedge rstn) begin
		if (!rstn) begin
			snap_pending <= 0;
			snap_pulse <= 0;
		end
		else begin
			snap_pulse <= 0;
			if (obj_rise && ready_seen && !uart_tx_active_sync)
				snap_pending <= 1'b1;
			if (snap_pending && vsync_fall) begin
				snap_pulse <= 1'b1;
				snap_pending <= 0;
			end
		end
	end
	
	always @(posedge pclk_bufg_o or negedge rstn) begin
		if (!rstn) begin
			uart_tx_active_s1 <= 1'b0;
			uart_tx_active_s2 <= 1'b0;
		end
		else begin
			uart_tx_active_s1 <= uart_tx_active;
			uart_tx_active_s2 <= uart_tx_active_s1;
		end
	end
	
	assign uart_tx_active_sync = uart_tx_active_s2;

	assign snapshot_req = snap_pulse;

	take_frame #(	.IMAGE_WIDTH (IMAGE_WIDTH),
				.IMAGE_HEIGHT(IMAGE_HEIGHT)
	) take_frame_inst (
		.pclk				(pclk_bufg_o),
		.rstn				(~reset),
		.vsync			(camera_vsync),
		.data_valid		(image_data_valid),
		.snapshot_req		(snapshot_req),
		.snapshot_active	(snapshot_active),
		.snapshot_done	(snapshot_done)
	);

	RV32_HCSR04 #(.CLK_FREQ(10_000_000)) RV32_HCSR04_inst (
		.clk				(clk_10Mhz),
		.rstn				(~reset),
		.echo 			(echo),
		.trigger 			(trigger),
		.tf_light 			(tf_light),
		.kathode 			(kathode),
		.seg 				(seg),
		.done_cap 		(snapshot_done),
		.obj_dct 			(obj_dct)
	);

	pll pll_inst (
		.clk_in1 	(ps2pl_clk50m_0),
		.resetn 	(pl_reset_n),
		.locked 	(pll_locked),
		.clk_out1 	(clk_200Mhz),
		.clk_out2 	(clk_100Mhz),
		.clk_out3	(clk_10Mhz),
		.clk_out4	(clk_40Mhz)
	);

	dvi_pll dvi_pll_inst (
		.clk_in1 	(clk_100Mhz),
		.resetn 	(~reset),
		.locked 	(),
		.clk_out1 	(disp_clk),	// 74.25Mhz
		.clk_out2 	(disp_clk5x)	// 371.25Mhz
	);

	camera_streaming_config #(	.DATA_WIDTH 		(24),
							.ADDR_WIDTH 		(8),
							.IMAGE_WIDTH 		(IMAGE_WIDTH),
							.IMAGE_HEIGHT 		(IMAGE_HEIGHT),
							.IMAGE_FLIP_EN 		(1),				// 0: no flip, 1: vertical flip
							.IMAGE_MIRROR_EN 	(1)				// 0: normal, 1: mirror
	) camera_streaming_config_inst (
		.clk 			(ps2pl_clk50m_0),
		.rstn 		(~reset),
		.done 		(done),
		.camera_rstn 	(~camera_rst),
		.camera_pwdn 	(),
		.i2c_scl 		(camera_scl),
		.i2c_sda 		(camera_sda)
	);

	BUFG BUFG_inst (
		.O 			(pclk_bufg_o),
		.I 			(camera_pclk)
	);
	
	cmos_capture_data u_cmos_capture_data(
        .rst_n              (~reset),
        .cam_pclk           (pclk_bufg_o),
        .cam_vsync          (camera_vsync),
        .cam_href           (camera_href),
        .cam_data           (camera_data),         
        .cmos_frame_vsync   (image_data_vs),
        .cmos_frame_href    (image_data_hs ),
        .cmos_frame_valid   (data_valid),
        .cmos_frame_data    (image_data_in)
    );
    
    image_process u_image_process(
        .clk              (pclk_bufg_o),
        .rst_n            (~reset    ),
        .pre_frame_vsync  (image_data_vs   ),
        .pre_frame_hsync  (image_data_hs   ),
        .pre_frame_de     (data_valid   ),
        .pre_rgb          (image_data_in),
        .post_frame_vsync ( ),
        .post_frame_hsync ( ),
        .post_frame_de    (image_data_valid ),
        .post_rgb         (image_data)
    );
    
	disp_driver #(	.Red_Bits (`Red_Bits),
				.Green_Bits (`Green_Bits),
				.Blue_Bits (`Blue_Bits),
				.H_Sync_Time (`H_Sync_Time),
				.H_Back_Porch (`H_Back_Porch),
				.H_Left_Border (`H_Left_Border),
				.H_Total_Time (`H_Total_Time),
				.H_Right_Border (`H_Right_Border),
				.H_Front_Porch (`H_Front_Porch),
				.V_Sync_Time (`V_Sync_Time),
				.V_Back_Porch (`V_Back_Porch),
				.V_Top_Border (`V_Top_Border),
				.V_Total_Time (`V_Total_Time),
				.V_Bottom_Border (`V_Bottom_Border),
				.V_Front_Porch (`V_Front_Porch)) disp_driver_inst (
		.clk_disp 		(disp_clk),
		.rstn 		(~reset),
		.data 		(disp_data),
		.data_req 		(rdfifo_rden),
		.addr_hs 		(),
		.addr_vs 		(),
		.disp_hs 		(vga_hs),
		.disp_vs 		(vga_vs),
		.disp_red 		(vga_rgb[23:16]),
		.disp_green 	(vga_rgb[15:8]),
		.disp_blue 	(vga_rgb[7:0]),
		.frame_begin 	(frame_begin),
		.disp_de 		(vga_de),
		.disp_pclk 	(vga_clk)
	);

	dvi_encoder dvi_encoder_inst (
		.pixel_clk 		(disp_clk),
		.pixel_clk_x5 	(disp_clk5x),
		.rstn 		(~reset),
		.red_din 		(vga_rgb[23:16]),
		.green_din 	(vga_rgb[15:8]),
		.blue_din 		(vga_rgb[7:0]),
		.hsync 		(vga_hs),
		.vsync 		(vga_vs),
		.de 			(vga_de),
		.tmds_clk_p 	(hdmi_clk_p),
		.tmds_clk_n 	(hdmi_clk_n),
		.tmds_data_p 	(hdmi_dat_p),
		.tmds_data_n 	(hdmi_dat_n)
	);

	uart_controller #(	.INPUT_WIDTH		(1280),
					.INPUT_HEIGHT		(720),
					.BYTES_PER_PIXEL	(2),
					.BLOCK_SIZE			(51200),
					.CROP_X_START		(320),
					.CROP_X_END		(959),
					.CROP_Y_START		(240),
					.CROP_Y_END		(719),
					.OUTPUT_WIDTH		(320),
					.OUTPUT_HEIGHT	(240)
	) uart_controller_inst (
		.clk			(ps2pl_clk50m_0),
		.rstn			(~reset),
		.i_rxd		(RX),
		.o_txd		(TX),
		.rdfifo_rden	(cap_rdfifo_rden),
		.rdfifo_dout	(cap_rdfifo_dout),
		.rdfifo_empty	(cap_rdfifo_empty),
		.snapshot_done(snapshot_done),
		.uart_tx_active	(uart_tx_active)
	);

	fifo_axi4_adapter #(	.FIFO_DW 					(16),
					.WR_AXI_BYTE_ADDR_BEGIN	(STREAM_ADDR_BEGIN + 1'b1),
					.WR_AXI_BYTE_ADDR_END	(STREAM_ADDR_BEGIN + IMAGE_WIDTH*IMAGE_HEIGHT*2),
					.RD_AXI_BYTE_ADDR_BEGIN	(STREAM_ADDR_BEGIN + 1'b1),
					.RD_AXI_BYTE_ADDR_END	(STREAM_ADDR_BEGIN + IMAGE_WIDTH*IMAGE_HEIGHT*2),
					.AXI_DATA_WIDTH 			(64),
					.AXI_ADDR_WIDTH 			(32),
					.AXI_ID_WIDTH				(4),
					.AXI_ID 						(4'b0000),
					.AXI_BURST_LEN				(15)
	) fifo_axi4_streaming_inst (
		//clock reset
		.clk 				(clk_200Mhz),
		.rstn 			(~reset),
		//wr_fifo Interface
		.wrfifo_clr 		(wrfifo_clr),
		.wrfifo_clk 		(pclk_bufg_o),
		.wrfifo_wren 		(wrfifo_wren_streaming),
		.wrfifo_din 		(wrfifo_din),
		.wrfifo_full 		(),
		.wrfifo_wr_cnt 		(),
		//rd_fifo Interface
		.rdfifo_clr 		(rdfifo_clr_streaming),
		.rdfifo_clk 		(disp_clk),
		.rdfifo_rden 		(rdfifo_rden),
		.rdfifo_dout 		(rdfifo_dout),
		.rdfifo_empty 		(),
		.rdfifo_rd_cnt 		(),
		// Master Interface Write Address Ports
		.m_axi_awid 		(s_axi_awid_0),
		.m_axi_awaddr 	(s_axi_awaddr_0),
		.m_axi_awlen 		(s_axi_awlen_0),
		.m_axi_awsize 		(s_axi_awsize_0),
		.m_axi_awburst 	(s_axi_awburst_0),
		.m_axi_awlock 	(s_axi_awlock_0),
		.m_axi_awcache 	(s_axi_awcache_0),
		.m_axi_awprot 		(s_axi_awprot_0),
		.m_axi_awqos 		(s_axi_awqos_0),
		.m_axi_awregion 	(s_axi_awregion_0),
		.m_axi_awvalid 	(s_axi_awvalid_0),
		.m_axi_awready 	(s_axi_awready_0),
		// Master Interface Write Data Ports
		.m_axi_wdata 		(s_axi_wdata_0),
		.m_axi_wstrb 		(s_axi_wstrb_0),
		.m_axi_wlast 		(s_axi_wlast_0),
		.m_axi_wvalid 		(s_axi_wvalid_0),
		.m_axi_wready 	(s_axi_wready_0),
		// Master Interface Write Response Ports
		.m_axi_bid 		(0),
		.m_axi_bresp 		(s_axi_bresp_0),
		.m_axi_bvalid 		(s_axi_bvalid_0),
		.m_axi_bready 		(s_axi_bready_0),
		// Master Interface Read Address Ports
		.m_axi_arid 		(s_axi_arid_0),
		.m_axi_araddr 		(s_axi_araddr_0),
		.m_axi_arlen 		(s_axi_arlen_0),
		.m_axi_arsize 		(s_axi_arsize_0),
		.m_axi_arburst 		(s_axi_arburst_0),
		.m_axi_arlock 		(s_axi_arlock_0),
		.m_axi_arcache 	(s_axi_arcache_0),
		.m_axi_arprot 		(s_axi_arprot_0),
		.m_axi_arqos 		(s_axi_arqos_0),
		.m_axi_arregion 	(s_axi_arregion_0),
		.m_axi_arvalid 		(s_axi_arvalid_0),
		.m_axi_arready 	(s_axi_arready_0),
		// Master Interface Read Data Ports
		.m_axi_rid 		(0),
		.m_axi_rdata 		(s_axi_rdata_0),
		.m_axi_rresp 		(s_axi_rresp_0),
		.m_axi_rlast 		(s_axi_rlast_0),
		.m_axi_rvalid 		(s_axi_rvalid_0),
		.m_axi_rready 		(s_axi_rready_0)
	);

	fifo_axi4_adapter #(	.FIFO_DW 					(16),
					.WR_AXI_BYTE_ADDR_BEGIN	(CAPTURE_ADDR_BEGIN + 1'b1),
					.WR_AXI_BYTE_ADDR_END	(CAPTURE_ADDR_BEGIN + IMAGE_WIDTH*IMAGE_HEIGHT*2),
					.RD_AXI_BYTE_ADDR_BEGIN	(CAPTURE_ADDR_BEGIN + 1'b1),
					.RD_AXI_BYTE_ADDR_END	(CAPTURE_ADDR_BEGIN + IMAGE_WIDTH*IMAGE_HEIGHT*2),
					.AXI_DATA_WIDTH 			(64),
					.AXI_ADDR_WIDTH 			(32),
					.AXI_ID_WIDTH				(4),
					.AXI_ID 						(4'b0000),
					.AXI_BURST_LEN				(15)
	) fifo_axi4_capture_inst (
		//clock reset
		.clk 				(clk_200Mhz),
		.rstn 			(~reset),
		//wr_fifo Interface
		.wrfifo_clr 		(wrfifo_clr),
		.wrfifo_clk 		(pclk_bufg_o),
		.wrfifo_wren 		(wrfifo_wren_capture),
		.wrfifo_din 		(wrfifo_din),
		.wrfifo_full 		(),
		.wrfifo_wr_cnt 		(),
		//rd_fifo Interface
		.rdfifo_clr 		(rdfifo_clr_capture),
		.rdfifo_clk 		(ps2pl_clk50m_0),
		.rdfifo_rden 		(cap_rdfifo_rden),
		.rdfifo_dout 		(cap_rdfifo_dout),
		.rdfifo_empty 		(cap_rdfifo_empty),
		.rdfifo_rd_cnt 		(),
		// Master Interface Write Address Ports
		.m_axi_awid 		(s_axi_awid_1),
		.m_axi_awaddr 	(s_axi_awaddr_1),
		.m_axi_awlen 		(s_axi_awlen_1),
		.m_axi_awsize 		(s_axi_awsize_1),
		.m_axi_awburst 	(s_axi_awburst_1),
		.m_axi_awlock 	(s_axi_awlock_1),
		.m_axi_awcache 	(s_axi_awcache_1),
		.m_axi_awprot 		(s_axi_awprot_1),
		.m_axi_awqos 		(s_axi_awqos_1),
		.m_axi_awregion 	(s_axi_awregion_1),
		.m_axi_awvalid 	(s_axi_awvalid_1),
		.m_axi_awready 	(s_axi_awready_1),
		// Master Interface Write Data Ports
		.m_axi_wdata 		(s_axi_wdata_1),
		.m_axi_wstrb 		(s_axi_wstrb_1),
		.m_axi_wlast 		(s_axi_wlast_1),
		.m_axi_wvalid 		(s_axi_wvalid_1),
		.m_axi_wready 	(s_axi_wready_1),
		// Master Interface Write Response Ports
		.m_axi_bid 		(0),
		.m_axi_bresp 		(s_axi_bresp_1),
		.m_axi_bvalid 		(s_axi_bvalid_1),
		.m_axi_bready 		(s_axi_bready_1),
		// Master Interface Read Address Ports
		.m_axi_arid 		(s_axi_arid_1),
		.m_axi_araddr 		(s_axi_araddr_1),
		.m_axi_arlen 		(s_axi_arlen_1),
		.m_axi_arsize 		(s_axi_arsize_1),
		.m_axi_arburst 		(s_axi_arburst_1),
		.m_axi_arlock 		(s_axi_arlock_1),
		.m_axi_arcache 	(s_axi_arcache_1),
		.m_axi_arprot 		(s_axi_arprot_1),
		.m_axi_arqos 		(s_axi_arqos_1),
		.m_axi_arregion 	(s_axi_arregion_1),
		.m_axi_arvalid 		(s_axi_arvalid_1),
		.m_axi_arready 	(s_axi_arready_1),
		// Master Interface Read Data Ports
		.m_axi_rid 		(0),
		.m_axi_rdata 		(s_axi_rdata_1),
		.m_axi_rresp 		(s_axi_rresp_1),
		.m_axi_rlast 		(s_axi_rlast_1),
		.m_axi_rvalid 		(s_axi_rvalid_1),
		.m_axi_rready 		(s_axi_rready_1)
	);

	system_wrapper system_wrapper_inst (
		.DDR_addr			(ddr3_addr),
		.DDR_ba				(ddr3_ba),
		.DDR_cas_n			(ddr3_cas_n),
		.DDR_ck_n			(ddr3_ck_n),
		.DDR_ck_p			(ddr3_ck_p),
		.DDR_cke			(ddr3_cke),
		.DDR_cs_n			(ddr3_cs_n),
		.DDR_dm			(ddr3_dm),
		.DDR_dq				(ddr3_dq),
		.DDR_dqs_n			(ddr3_dqs_n),
		.DDR_dqs_p			(ddr3_dqs_p),
		.DDR_odt			(ddr3_odt),
		.DDR_ras_n			(ddr3_ras_n),
		.DDR_reset_n			(ddr3_reset_n),
		.DDR_we_n			(ddr3_we_n),
		.FIXED_IO_ddr_vrn	(FIXED_IO_ddr_vrn),
		.FIXED_IO_ddr_vrp	(FIXED_IO_ddr_vrp),
		.FIXED_IO_mio		(FIXED_IO_mio),
		.FIXED_IO_ps_clk		(FIXED_IO_ps_clk),
		.FIXED_IO_ps_porb	(FIXED_IO_ps_porb),
		.FIXED_IO_ps_srstb	(FIXED_IO_ps_srstb),
		.ps2pl_clk50m_0		(ps2pl_clk50m_0),
		.ps2pl_resetn_0		(ps2pl_resetn_0),
		//Slave Interface Read Address Ports
		.pl2ps_axi_0_araddr		(s_axi_araddr_0),
		.pl2ps_axi_0_arburst	(s_axi_arburst_0),
		.pl2ps_axi_0_arcache	(s_axi_arcache_0),
		.pl2ps_axi_0_arlen		(s_axi_arlen_0),
		.pl2ps_axi_0_arlock		(s_axi_arlock_0),
		.pl2ps_axi_0_arprot		(s_axi_arprot_0),
		.pl2ps_axi_0_arqos		(s_axi_arqos_0),
		//pl2ps_axi_0_arregion(s_axi_arregion),
		.pl2ps_axi_0_arready	(s_axi_arready_0),
		.pl2ps_axi_0_arsize		(s_axi_arsize_0),
		.pl2ps_axi_0_arvalid		(s_axi_arvalid_0),
		//Slave Interface Write Address Ports
		.pl2ps_axi_0_awaddr	(s_axi_awaddr_0),
		.pl2ps_axi_0_awburst	(s_axi_awburst_0),
		.pl2ps_axi_0_awcache	(s_axi_awcache_0),
		.pl2ps_axi_0_awlen		(s_axi_awlen_0),
		.pl2ps_axi_0_awlock	(s_axi_awlock_0),
		.pl2ps_axi_0_awprot	(s_axi_awprot_0),
		.pl2ps_axi_0_awqos		(s_axi_awqos_0),
		//pl2ps_axi_0_awregion(s_axi_awregion),
		.pl2ps_axi_0_awready	(s_axi_awready_0),
		.pl2ps_axi_0_awsize		(s_axi_awsize_0),
		.pl2ps_axi_0_awvalid	(s_axi_awvalid_0),
		//Slave Interface Write Response Ports
		.pl2ps_axi_0_bready		(s_axi_bready_0),
		.pl2ps_axi_0_bresp		(s_axi_bresp_0),
		.pl2ps_axi_0_bvalid		(s_axi_bvalid_0),
		//Slave Interface Read Data Ports
		.pl2ps_axi_0_rdata		(s_axi_rdata_0),
		.pl2ps_axi_0_rlast		(s_axi_rlast_0),
		.pl2ps_axi_0_rready		(s_axi_rready_0),
		.pl2ps_axi_0_rresp		(s_axi_rresp_0),
		.pl2ps_axi_0_rvalid		(s_axi_rvalid_0),
		//Slave Interface Write Data Ports
		.pl2ps_axi_0_wdata		(s_axi_wdata_0),
		.pl2ps_axi_0_wlast		(s_axi_wlast_0),
		.pl2ps_axi_0_wready	(s_axi_wready_0),
		.pl2ps_axi_0_wstrb		(s_axi_wstrb_0),
		.pl2ps_axi_0_wvalid		(s_axi_wvalid_0),
		//Slave Interface ACLK RESET
		.pl2ps_axi_aclk_0		(s_axi_aclk_0),
		.pl2ps_axi_resetn_0		(s_axi_resetn_0),

		//Slave Interface Read Address Ports
		.pl2ps_axi_1_araddr		(s_axi_araddr_1),
		.pl2ps_axi_1_arburst	(s_axi_arburst_1),
		.pl2ps_axi_1_arcache	(s_axi_arcache_1),
		.pl2ps_axi_1_arlen		(s_axi_arlen_1),
		.pl2ps_axi_1_arlock		(s_axi_arlock_1),
		.pl2ps_axi_1_arprot		(s_axi_arprot_1),
		.pl2ps_axi_1_arqos		(s_axi_arqos_1),
		//pl2ps_axi_0_arregion	(s_axi_arregion),
		.pl2ps_axi_1_arready	(s_axi_arready_1),
		.pl2ps_axi_1_arsize		(s_axi_arsize_1),
		.pl2ps_axi_1_arvalid		(s_axi_arvalid_1),
		//Slave Interface Write Address Ports
		.pl2ps_axi_1_awaddr	(s_axi_awaddr_1),
		.pl2ps_axi_1_awburst	(s_axi_awburst_1),
		.pl2ps_axi_1_awcache	(s_axi_awcache_1),
		.pl2ps_axi_1_awlen		(s_axi_awlen_1),
		.pl2ps_axi_1_awlock	(s_axi_awlock_1),
		.pl2ps_axi_1_awprot	(s_axi_awprot_1),
		.pl2ps_axi_1_awqos		(s_axi_awqos_1),
		//pl2ps_axi_1_awregion	(s_axi_awregion),
		.pl2ps_axi_1_awready	(s_axi_awready_1),
		.pl2ps_axi_1_awsize		(s_axi_awsize_1),
		.pl2ps_axi_1_awvalid	(s_axi_awvalid_1),
		//Slave Interface Write Response Ports
		.pl2ps_axi_1_bready		(s_axi_bready_1),
		.pl2ps_axi_1_bresp		(s_axi_bresp_1),
		.pl2ps_axi_1_bvalid		(s_axi_bvalid_1),
		//Slave Interface Read Data Ports
		.pl2ps_axi_1_rdata		(s_axi_rdata_1),
		.pl2ps_axi_1_rlast		(s_axi_rlast_1),
		.pl2ps_axi_1_rready		(s_axi_rready_1),
		.pl2ps_axi_1_rresp		(s_axi_rresp_1),
		.pl2ps_axi_1_rvalid		(s_axi_rvalid_1),
		//Slave Interface Write Data Ports
		.pl2ps_axi_1_wdata		(s_axi_wdata_1),
		.pl2ps_axi_1_wlast		(s_axi_wlast_1),
		.pl2ps_axi_1_wready	(s_axi_wready_1),
		.pl2ps_axi_1_wstrb		(s_axi_wstrb_1),
		.pl2ps_axi_1_wvalid		(s_axi_wvalid_1),
		//Slave Interface ACLK RESET
		.pl2ps_axi_aclk_1		(s_axi_aclk_1),
		.pl2ps_axi_resetn_1		(s_axi_resetn_1)
	);

endmodule