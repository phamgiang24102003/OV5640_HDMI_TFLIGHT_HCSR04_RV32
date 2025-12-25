module cmos_capture_data(
	input				  rst_n			,  // Reset signal
	// Camera Interface
	input				  cam_pclk		 ,  // CMOS data pixel clock
	input				  cam_vsync		,  // CMOS field sync signal
	input				  cam_href		 ,  // CMOS line sync signal
	input  [7:0]		  cam_data		 ,
	// User Interface
	output				cmos_frame_vsync ,  // Frame valid signal
	output				cmos_frame_href  ,  // Line valid signal
	output				cmos_frame_valid ,  // Data valid enable signal
	output	   [15:0]   cmos_frame_data	 // Valid data
	);

// Wait for 10 frames after register configuration is complete
// Start capturing images after registers take effect
parameter	 WAIT_FRAME = 4'd10	;			// Number of frames to wait for data stability

// reg define
reg			 cam_vsync_d0	 ;
reg			 cam_vsync_d1	 ;
reg			 cam_href_d0	  ;
reg			 cam_href_d1	  ;
reg	[3:0]	cmos_ps_cnt	  ;			// Counter for waiting stable frames
reg	[7:0]	cam_data_d0	  ;
reg	[15:0]   cmos_data_t	  ;			// Temporary register for 8-bit to 16-bit conversion
reg			 byte_flag		;			// Flag for 16-bit RGB data conversion completion
reg			 byte_flag_d0	 ;
reg			 frame_val_flag   ;			// Frame valid flag

wire			pos_vsync		;			// Rising edge of input field sync signal

//*****************************************************
//**					 main code
//*****************************************************

// Capture the rising edge of input field sync signal
assign pos_vsync = (~cam_vsync_d1) & cam_vsync_d0;

// Output frame valid signal
assign	cmos_frame_vsync = frame_val_flag  ?  cam_vsync_d1  :  1'b0;

// Output line valid signal
assign	cmos_frame_href  = frame_val_flag  ?  cam_href_d1   :  1'b0;

// Output data valid enable signal
assign	cmos_frame_valid = frame_val_flag  ?  byte_flag_d0  :  1'b0;

// Output data
assign	cmos_frame_data  = frame_val_flag  ?  cmos_data_t   :  1'b0;

always @(posedge cam_pclk or negedge rst_n) begin
	if(!rst_n) begin
		cam_vsync_d0 <= 1'b0;
		cam_vsync_d1 <= 1'b0;
		cam_href_d0 <= 1'b0;
		cam_href_d1 <= 1'b0;
	end
	else begin
		cam_vsync_d0 <= cam_vsync;
		cam_vsync_d1 <= cam_vsync_d0;
		cam_href_d0 <= cam_href;
		cam_href_d1 <= cam_href_d0;
	end
end

// Count the number of frames
always @(posedge cam_pclk or negedge rst_n) begin
	if(!rst_n)
		cmos_ps_cnt <= 4'd0;
	else if(pos_vsync && (cmos_ps_cnt < WAIT_FRAME))
		cmos_ps_cnt <= cmos_ps_cnt + 4'd1;
end

// Frame valid flag logic
always @(posedge cam_pclk or negedge rst_n) begin
	if(!rst_n)
		frame_val_flag <= 1'b0;
	else if((cmos_ps_cnt == WAIT_FRAME) && pos_vsync)
		frame_val_flag <= 1'b1;
	else;
end

// 8-bit data to 16-bit RGB565 data conversion
always @(posedge cam_pclk or negedge rst_n) begin
	if(!rst_n) begin
		cmos_data_t <= 16'd0;
		cam_data_d0 <= 8'd0;
		byte_flag <= 1'b0;
	end
	else if(cam_href) begin
		byte_flag <= ~byte_flag;
		cam_data_d0 <= cam_data;
		if(byte_flag)
			cmos_data_t <= {cam_data_d0,cam_data};
		else;
	end
	else begin
		byte_flag <= 1'b0;
		cam_data_d0 <= 8'b0;
	end
end

// Generate data valid signal (cmos_frame_valid)
always @(posedge cam_pclk or negedge rst_n) begin
	if(!rst_n)
		byte_flag_d0 <= 1'b0;
	else
		byte_flag_d0 <= byte_flag;
end

endmodule