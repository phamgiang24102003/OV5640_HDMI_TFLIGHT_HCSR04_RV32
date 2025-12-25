module image_process(
	input			clk			,	// Clock signal
	input			rst_n		  ,	// Reset signal (Low active)
	input			pre_frame_vsync,
	input			pre_frame_hsync,
	input			pre_frame_de   ,
	input	[15:0] pre_rgb		,
	output		  post_frame_vsync,  // Field sync signal
	output		  post_frame_hsync,  // Line sync signal
	output		  post_frame_de   ,  // Data enable
	output   [15:0] post_rgb		   // RGB565 color data
);

//RGB to YCbCr
wire				  ycbcr_vsync;
wire				  ycbcr_hsync;
wire				  ycbcr_de   ;
wire   [ 7:0]		  img_y	  ;
wire   [ 7:0]		  img_cb	 ;
wire   [ 7:0]		  img_cr	 ;
wire   [ 7:0]		  img_cw	 ;

//Binarization
wire				  binarization_vsync;
wire				  binarization_hsync;
wire				  binarization_de   ;
wire				  binarization_bit  ;
//Erosion
wire				  erosion_vsync;
wire				  erosion_hsync;
wire				  erosion_de   ;
wire				  erosion_bit  ;
//Median Filter 1
wire				  median1_vsync;
wire				  median1_hsync;
wire				  median1_de   ;
wire				  median1_bit  ;
//Sobel Edge Detection
wire				  sobel_vsync;
wire				  sobel_hsync;
wire				  sobel_de   ;
wire				  sobel_bit  ;
//Median Filter 2
wire				  median2_vsync;
wire				  median2_hsync;
wire				  median2_de   ;
wire				  median2_bit  ;
//Dilation
wire				  dilation_vsync;
wire				  dilation_hsync;
wire				  dilation_de   ;
wire				  dilation_bit  ;
//Projection
wire				  projection_vsync;
wire				  projection_hsync;
wire				  projection_de   ;
wire				  projection_bit  ;
wire [9:0] max_line_up  ;//Horizontal projection result
wire [9:0] max_line_down;
wire [9:0] max_line_left ;//Vertical projection result
wire [9:0] max_line_right;
//Adjust plate width and height
wire [9:0] plate_boarder_up   ;
wire [9:0] plate_boarder_down ;
wire [9:0] plate_boarder_left ;
wire [9:0] plate_boarder_right;
wire	   plate_exist_flag   ;
//-----------------Part 2-----------------
//Character Binarization
wire				  char_bin_vsync;
wire				  char_bin_hsync;
wire				  char_bin_de   ;
wire				  char_bin_bit  ;
//Erosion
wire				  char_ero_vsync;
wire				  char_ero_hsync;
wire				  char_ero_de   ;
wire				  char_ero_bit  ;
//Dilation
wire				  char_dila_vsync;
wire				  char_dila_hsync;
wire				  char_dila_de   ;
wire				  char_dila_bit  ;
//Projection
wire char_proj_vsync;
wire char_proj_hsync;
wire char_proj_de   ;
wire char_proj_bit  ;
wire [9:0] char_line_up  ;//Horizontal projection result
wire [9:0] char_line_down;
wire [9:0] char1_line_left ;//Vertical projection result
wire [9:0] char1_line_right;
wire [9:0] char2_line_left ;
wire [9:0] char2_line_right;
wire [9:0] char3_line_left ;
wire [9:0] char3_line_right;
wire [9:0] char4_line_left ;
wire [9:0] char4_line_right;
wire [9:0] char5_line_left ;
wire [9:0] char5_line_right;
wire [9:0] char6_line_left ;
wire [9:0] char6_line_right;
wire [9:0] char7_line_left ;
wire [9:0] char7_line_right;

//-----------------Part 3-----------------
//Calculate Eigenvalues
wire [39:0] char1_eigenvalue;
wire [39:0] char2_eigenvalue;
wire [39:0] char3_eigenvalue;
wire [39:0] char4_eigenvalue;
wire [39:0] char5_eigenvalue;
wire [39:0] char6_eigenvalue;
wire [39:0] char7_eigenvalue;
wire	   cal_eigen_vsync;
wire	   cal_eigen_hsync;
wire	   cal_eigen_de   ;
wire	   cal_eigen_bit  ;
//Template Matching
wire	   template_vsync;
wire	   template_hsync;
wire	   template_de   ;
wire	   template_bit  ;
wire [5:0]  match_index_char1;
wire [5:0]  match_index_char2;
wire [5:0]  match_index_char3;
wire [5:0]  match_index_char4;
wire [5:0]  match_index_char5;
wire [5:0]  match_index_char6;
wire [5:0]  match_index_char7;
//Add Grid
wire		   add_grid_vsync;
wire		   add_grid_href ;
wire		   add_grid_de   ;
wire   [15:0]  add_grid_rgb  ;

//*****************************************************
//**					 main code
//*****************************************************

//---------------------------Part 1-----------------------------
//Part 1: Identify the plate area in the image based on blue color and output boundaries.
//In order:
//  1.1 RGB to YCbCr
//  1.2 Binarization
//  1.3 Erosion
//  1.4 Sobel Edge Detection
//  1.5 Dilation
//  1.6 Horizontal & Vertical Projection --> Output plate boundary

//RGB to YCbCr Module
rgb2ycbcr u1_rgb2ycbcr(
	//module clock
	.clk			 (clk	),			// Clock signal
	.rst_n			(rst_n  ),			// Reset signal (Low active)
	//Data interface before image processing
	.pre_frame_vsync (pre_frame_vsync),	// vsync signal
	.pre_frame_hsync (pre_frame_hsync),	// href signal
	.pre_frame_de	(pre_frame_de   ),	// data enable signal
	.img_red		 (pre_rgb[15:11] ),
	.img_green	   (pre_rgb[10:5 ] ),
	.img_blue		(pre_rgb[ 4:0 ] ),
	//Data interface after image processing
	.post_frame_vsync(ycbcr_vsync),   // vsync signal
	.post_frame_hsync(ycbcr_hsync),   // href signal
	.post_frame_de   (ycbcr_de   ),   // data enable signal
	.img_y			(img_y ),
	.img_cb		  (img_cb),
	.img_cr		  (img_cr),
	.img_cw       (img_cw)
);

//Binarization
binarization u1_binarization(
	.clk	 (clk	),   // Clock signal
	.rst_n   (rst_n  ),   // Reset signal (Low active)

	.per_frame_vsync   (ycbcr_vsync),
	.per_frame_href	(ycbcr_hsync),	
	.per_frame_clken   (ycbcr_de   ),
	.per_img_Y		 (img_cw	 ),		

	.post_frame_vsync  (binarization_vsync),	
	.post_frame_href   (binarization_hsync),	
	.post_frame_clken  (binarization_de   ),	
	.post_img_Bit	  (binarization_bit  ),		

	.Binary_Threshold  (8'd100)//This threshold setting is very important
);

//Erosion
VIP_Bit_Erosion_Detector # (
	.IMG_HDISP (1280),	//640*480
	.IMG_VDISP (720)
)u1_VIP_Bit_Erosion_Detector(
	//Global Clock
	.clk	 (clk	),   //cmos video pixel clock
	.rst_n   (rst_n  ),   //global reset

	//Image data prepared to be processed
	.per_frame_vsync   (binarization_vsync), //Prepared Image data vsync valid signal
	.per_frame_href	(binarization_hsync), //Prepared Image data href valid signal
	.per_frame_clken   (binarization_de   ), //Prepared Image data output/capture enable clock
	.per_img_Bit	   (binarization_bit  ), //Prepared Image Bit flag output (1: Value, 0: inValid)
	
	//Image data has been processed
	.post_frame_vsync  (erosion_vsync),	//Processed Image data vsync valid signal
	.post_frame_href   (erosion_hsync),	//Processed Image data href valid signal
	.post_frame_clken  (erosion_de   ),	//Processed Image data output/capture enable clock
	.post_img_Bit	  (erosion_bit  )	 //Processed Image Bit flag output (1: Value, 0: inValid)
);

////Median filtering to remove noise
//VIP_Gray_Median_Filter # (
//	.IMG_HDISP(10'd640),	//640*480
//	.IMG_VDISP(10'd480)
//)u1_Gray_Median_Filter(
//	//global clock
//	.clk   (clk	), 				//100MHz
//	.rst_n (rst_n  ),				//global reset

//	//Image data prepared to be processed
//	.per_frame_vsync   (erosion_vsync   ),	//Prepared Image data vsync valid signal
//	.per_frame_href	(erosion_hsync   ),	//Prepared Image data href valid signal
//	.per_frame_clken   (erosion_de	  ),	//Prepared Image data output/capture enable clock
//	.per_img_Y		 ({8{erosion_bit}}),	//Prepared Image brightness input
	
//	//Image data has been processed
//	.post_frame_vsync  (median1_vsync),	//Processed Image data vsync valid signal
//	.post_frame_href   (median1_hsync),	//Processed Image data href valid signal
//	.post_frame_clken  (median1_de   ),	//Processed Image data output/capture enable clock
//	.post_img_Y		  (median1_bit  )	//Processed Image brightness input
//);

//Sobel Edge Detection
Sobel_Edge_Detector #(
	.SOBEL_THRESHOLD   (8'd128) //Sobel Threshold
) u1_Sobel_Edge_Detector (
	//global clock
	.clk			   (clk	),			  //cmos video pixel clock
	.rst_n			 (rst_n  ),				 //global reset
	//Image data prepared to be processed
	.per_frame_vsync  (erosion_vsync   ),	//Prepared Image data vsync valid signal
	.per_frame_href   (erosion_hsync   ),	//Prepared Image data href valid signal
	.per_frame_clken  (erosion_de	  ),	//Prepared Image data output/capture enable clock
	.per_img_y		({8{erosion_bit}}),	//Prepared Image brightness input  
	//Image data has been processed
	.post_frame_vsync (sobel_vsync),	//Processed Image data vsync valid signal
	.post_frame_href  (sobel_hsync),	//Processed Image data href valid signal
	.post_frame_clken (sobel_de   ),	//Processed Image data output/capture enable clock
	.post_img_bit	 (sobel_bit  )	 //Processed Image Bit flag output (1: Value, 0 inValid)
);

//////Median filtering to remove noise
////VIP_Gray_Median_Filter # (
////	.IMG_HDISP(10'd640),	//640*480
////	.IMG_VDISP(10'd480)
////)u2_Gray_Median_Filter(
////	//global clock
////	.clk   (clk	), 				//100MHz
////	.rst_n (rst_n  ),				//global reset

////	//Image data prepared to be processed
////	.per_frame_vsync   (sobel_vsync   ),	//Prepared Image data vsync valid signal
////	.per_frame_href	(sobel_hsync   ),	//Prepared Image data href valid signal
////	.per_frame_clken   (sobel_de	  ),	//Prepared Image data output/capture enable clock
////	.per_img_Y		 ({8{sobel_bit}}),	//Prepared Image brightness input
	
////	//Image data has been processed
////	.post_frame_vsync  (post_frame_vsync),	//Processed Image data vsync valid signal
////	.post_frame_href   (post_frame_hsync),	//Processed Image data href valid signal
////	.post_frame_clken  (post_frame_de   ),	//Processed Image data output/capture enable clock
////	.post_img_Y		  (post_img_bit	)	//Processed Image brightness input
////);

//Dilation
VIP_Bit_Dilation_Detector#(
	.IMG_HDISP(1280),	//640*480
	.IMG_VDISP(720)
)u1_VIP_Bit_Dilation_Detector(
	//global clock
	.clk   (clk	), 				//cmos video pixel clock
	.rst_n (rst_n  ),				//global reset

	//Image data prepared to be processed
	.per_frame_vsync   (sobel_vsync   ),	//Prepared Image data vsync valid signal
	.per_frame_href	(sobel_hsync   ),	//Prepared Image data href valid signal
	.per_frame_clken   (sobel_de	  ),	//Prepared Image data output/capture enable clock
	.per_img_Bit	   (sobel_bit	 ),	//Prepared Image Bit flag output (1: Value, 0: inValid)
	
	//Image data has been processed
	.post_frame_vsync  (dilation_vsync),	//Processed Image data vsync valid signal
	.post_frame_href   (dilation_hsync),	//Processed Image data href valid signal
	.post_frame_clken  (dilation_de   ),	//Processed Image data output/capture enable clock
	.post_img_Bit	  (dilation_bit  )	//Processed Image Bit flag output (1: Value, 0: inValid)
);

//Horizontal Projection
VIP_horizon_projection # (
	.IMG_HDISP(1280),	//640*480
	.IMG_VDISP(720)
)u1_VIP_horizon_projection(
	//global clock
	.clk   (clk	), 				//cmos video pixel clock
	.rst_n (rst_n  ),				//global reset

	//Image data prepared to be processed
	.per_frame_vsync   (dilation_vsync),//Prepared Image data vsync valid signal
	.per_frame_href	(dilation_hsync),//Prepared Image data href valid signal
	.per_frame_clken   (dilation_de   ),//Prepared Image data output/capture enable clock
	.per_img_Bit	   (dilation_bit  ),//Prepared Image Bit flag output (1: Value, 0: inValid)
	
	//Image data has been processed
	.post_frame_vsync  (projection_vsync),//Processed Image data vsync valid signal
	.post_frame_href   (projection_hsync),//Processed Image data href valid signal
	.post_frame_clken  (projection_de   ),//Processed Image data output/capture enable clock
	.post_img_Bit	  (projection_bit  ),//Processed Image Bit flag output (1: Value, 0: inValid)

	.max_line_up  (max_line_up  ),//Edge coordinates
	.max_line_down(max_line_down),
	
	.horizon_start  (320),//Projection start column
	.horizon_end	(959) //Projection end column  
);

//Vertical Projection
VIP_vertical_projection # (
	.IMG_HDISP(1280),	//640*480
	.IMG_VDISP(720)
)u1_VIP_vertical_projection(
	//global clock
	.clk   (clk	),//cmos video pixel clock
	.rst_n (rst_n  ),//global reset

	//Image data prepared to be processed
	.per_frame_vsync   (dilation_vsync),//Prepared Image data vsync valid signal
	.per_frame_href	(dilation_hsync),//Prepared Image data href valid signal
	.per_frame_clken   (dilation_de   ),//Prepared Image data output/capture enable clock
	.per_img_Bit	   (dilation_bit  ),//Prepared Image Bit flag output (1: Value, 0: inValid)
	
	//Image data has been processed
	.post_frame_vsync  (),//Processed Image data vsync valid signal
	.post_frame_href   (),//Processed Image data href valid signal
	.post_frame_clken  (),//Processed Image data output/capture enable clock
	.post_img_Bit	  (),//Processed Image Bit flag output (1: Value, 0: inValid)

	.max_line_left (max_line_left ),		//Edge coordinates
	.max_line_right(max_line_right),
	
	.vertical_start(240),//Projection start row
	.vertical_end  (719) //Projection end row	     
);

////Adjust license plate border, only include characters after adjustment
//plate_boarder_adjust u_plate_boarder_adjust(
//	//global clock
//	.clk   (clk	),				  
//	.rst_n (rst_n  ),				

//	.per_frame_vsync (post_frame_vsync),	

//	.max_line_up	 (max_line_up   ), //Input candidate plate area
//	.max_line_down   (max_line_down ),
//	.max_line_left   (max_line_left ),	 
//	.max_line_right  (max_line_right),
	 
//	.plate_boarder_up	 (plate_boarder_up   ), //Adjusted border
//	.plate_boarder_down   (plate_boarder_down ), 
//	.plate_boarder_left   (plate_boarder_left ),
//	.plate_boarder_right  (plate_boarder_right),
//	.plate_exist_flag	 (plate_exist_flag   )  //Determine if plate exists based on width/height ratio	 
//);
//----------------------------------------------------------------


//---------------------------Part 2-----------------------------
//Part 2: Use the plate boundary from Part 1 to extract individual character areas.
//In order:
//  2.1 Binarization
//  2.2 Erosion
//  2.3 Dilation
//  2.4 Horizontal & Vertical Projection --> Output all character boundaries

//2.1 Binarize R channel in RGB within the plate border, ignore outside.
char_binarization # (
	.BIN_THRESHOLD   (8'd160	) //Binarization Threshold
)u2_char_binarization(
	.clk			 (clk	   ),   // Clock signal
	.rst_n			(rst_n	 ),   // Reset signal (Low active)
	//Input video stream
	.per_frame_vsync(pre_frame_vsync),
	.per_frame_href (pre_frame_hsync),	
	.per_frame_clken(pre_frame_de   ),
	.per_frame_Red  ({pre_rgb[15:11],3'b111} ),
	//Plate boundary
	.plate_boarder_up 	 (max_line_up   +10'd10),//Input candidate plate area
	.plate_boarder_down  (max_line_down -10'd10),
	.plate_boarder_left  (max_line_left +10'd10),   
	.plate_boarder_right (max_line_right-10'd10),
	.plate_exist_flag	(1'b1   ),
	//Output video stream
	.post_frame_vsync(char_bin_vsync),	
	.post_frame_href (char_bin_hsync),	
	.post_frame_clken(char_bin_de   ),	
	.post_frame_Bit  (char_bin_bit  )
);

//2.2 Erosion
VIP_Bit_Erosion_Detector # (
	.IMG_HDISP (1280),	//640*480
	.IMG_VDISP (720)
)u2_VIP_Bit_Erosion_Detector(
	//Global Clock
	.clk	 (clk	),   //cmos video pixel clock
	.rst_n   (rst_n  ),   //global reset

	//Image data prepared to be processed
	.per_frame_vsync   (char_bin_vsync), //Prepared Image data vsync valid signal
	.per_frame_href	(char_bin_hsync), //Prepared Image data href valid signal
	.per_frame_clken   (char_bin_de   ), //Prepared Image data output/capture enable clock
	.per_img_Bit	   (char_bin_bit  ), //Prepared Image Bit flag output (1: Value, 0: inValid)
	
	//Image data has been processed
	.post_frame_vsync  (char_ero_vsync),	//Processed Image data vsync valid signal
	.post_frame_href   (char_ero_hsync),	//Processed Image data href valid signal
	.post_frame_clken  (char_ero_de   ),	//Processed Image data output/capture enable clock
	.post_img_Bit	  (char_ero_bit  )	 //Processed Image Bit flag output (1: Value, 0: inValid)
);

//2.3 Dilation
VIP_Bit_Dilation_Detector#(
	.IMG_HDISP(1280),	//640*480
	.IMG_VDISP(720)
)u2_VIP_Bit_Dilation_Detector(
	//global clock
	.clk   (clk	), 				//cmos video pixel clock
	.rst_n (rst_n  ),				//global reset

	//Image data prepared to be processed
	.per_frame_vsync   (char_ero_vsync ),	//Prepared Image data vsync valid signal
	.per_frame_href	(char_ero_hsync ),	//Prepared Image data href valid signal
	.per_frame_clken   (char_ero_de	),	//Prepared Image data output/capture enable clock
	.per_img_Bit	   (char_ero_bit   ),	//Prepared Image Bit flag output (1: Value, 0: inValid)
	
	//Image data has been processed
	.post_frame_vsync  (char_dila_vsync),	//Processed Image data vsync valid signal
	.post_frame_href   (char_dila_hsync),	//Processed Image data href valid signal
	.post_frame_clken  (char_dila_de   ),	//Processed Image data output/capture enable clock
	.post_img_Bit	  (char_dila_bit  )	//Processed Image Bit flag output (1: Value, 0: inValid)
);


//2.4.1 Horizontal Projection of character area
char_horizon_projection # (
	.IMG_HDISP(1280),	//640*480
	.IMG_VDISP(720)
)u2_char_horizon_projection(
	//global clock
	.clk   (clk		 ), 			//cmos video pixel clock
	.rst_n (rst_n		),				//global reset

	//Image data prepared to be processed
	.per_frame_vsync   (char_dila_vsync),//Prepared Image data vsync valid signal
	.per_frame_href	(char_dila_hsync),//Prepared Image data href valid signal
	.per_frame_clken   (char_dila_de   ),//Prepared Image data output/capture enable clock
	.per_img_Bit	   (char_dila_bit  ),//Prepared Image Bit flag output (1: Value, 0: inValid)
	
	//Image data has been processed
	.post_frame_vsync  (char_proj_vsync),//Processed Image data vsync valid signal
	.post_frame_href   (char_proj_hsync),//Processed Image data href valid signal
	.post_frame_clken  (char_proj_de   ),//Processed Image data output/capture enable clock
	.post_img_Bit	  (char_proj_bit   ),//Processed Image Bit flag output (1: Value, 0: inValid)

	.max_line_up	(char_line_up  ),//Edge coordinates
	.max_line_down  (char_line_down),
	
	.horizon_start  (320),//Projection start column
	.horizon_end	(959) //Projection end column  
);


//2.4.2 Vertical Projection of character area
char_vertical_projection # (
	.IMG_HDISP(1280),	//640*480
	.IMG_VDISP(720)
)u2_char_vertical_projection(
	//global clock
	.clk   (clk	),//cmos video pixel clock
	.rst_n (rst_n  ),//global reset
	//Image data prepared to be processed
	.per_frame_vsync   (char_dila_vsync),//Prepared Image data vsync valid signal
	.per_frame_href	(char_dila_hsync),//Prepared Image data href valid signal
	.per_frame_clken   (char_dila_de   ),//Prepared Image data output/capture enable clock
	.per_img_Bit	   (char_dila_bit  ),//Prepared Image Bit flag output (1: Value, 0: inValid)
	//Edge detection range
	.vertical_start  (240),//Projection start column
	.vertical_end	(719),//Projection end column	   
	//Output edge coordinates
	.char1_line_left   (char1_line_left ),
	.char1_line_right  (char1_line_right),
	.char2_line_left   (char2_line_left ),
	.char2_line_right  (char2_line_right),
	.char3_line_left   (char3_line_left ),
	.char3_line_right  (char3_line_right),
	.char4_line_left   (char4_line_left ),
	.char4_line_right  (char4_line_right),
	.char5_line_left   (char5_line_left ),
	.char5_line_right  (char5_line_right),
	.char6_line_left   (char6_line_left ),
	.char6_line_right  (char6_line_right),
	.char7_line_left   (char7_line_left ),
	.char7_line_right  (char7_line_right),
	//Image data has been processed
	.post_frame_vsync  (),//Processed Image data vsync valid signal
	.post_frame_href   (),//Processed Image data href valid signal
	.post_frame_clken  (),//Processed Image data output/capture enable clock
	.post_img_Bit	  () //Processed Image Bit flag output (1: Value, 0: inValid)   
);

//----------------------------------------------------------------


//---------------------------Part 3-----------------------------
//Part 3: Template matching based on the boundaries of each character provided in Part 2.
//In order:
//  3.1 Extract Eigenvalues
//  3.2 Template Matching
//  3.3 Add Borders
//  3.4 Add Characters

// 3.1 Extract Eigenvalues
Get_EigenValue#(
	.HOR_SPLIT(8), //Horizontal splits
	.VER_SPLIT(5)  //Vertical splits
)u3_Get_EigenValue(
	//Clock and reset
	.clk			 (clk	 ),   // Clock signal
	.rst_n			(rst_n   ),   // Reset signal (Low active)
	//Input video stream
	.per_frame_vsync	 (char_dila_vsync	),//char_dila_vsync
	.per_frame_href	  (char_dila_hsync	),//char_dila_hsync
	.per_frame_clken	 (char_dila_de	   ),//char_dila_de   
	.per_frame_bit	   (char_dila_bit	  ),//char_dila_bit  
	//Input character boundaries
	.char_line_up 	   (char_line_up	   ),
	.char_line_down	  (char_line_down	 ),
	.char1_line_left	 (char1_line_left	),
	.char1_line_right	(char1_line_right   ),
	.char2_line_left	 (char2_line_left	),
	.char2_line_right	(char2_line_right   ),
	.char3_line_left	 (char3_line_left	),
	.char3_line_right	(char3_line_right   ),
	.char4_line_left	 (char4_line_left	),
	.char4_line_right	(char4_line_right   ),
	.char5_line_left	 (char5_line_left	),
	.char5_line_right	(char5_line_right   ),
	.char6_line_left	 (char6_line_left	),
	.char6_line_right	(char6_line_right   ),
	.char7_line_left	 (char7_line_left	),
	.char7_line_right	(char7_line_right   ),
	//Output video stream
	.post_frame_vsync	(cal_eigen_vsync	),	
	.post_frame_href	 (cal_eigen_hsync	),	
	.post_frame_clken	(cal_eigen_de	   ),	
	.post_frame_bit	  (cal_eigen_bit	  ),
	//Output 7 eigenvalues
	.char1_eigenvalue	(char1_eigenvalue   ),
	.char2_eigenvalue	(char2_eigenvalue   ),
	.char3_eigenvalue	(char3_eigenvalue   ),
	.char4_eigenvalue	(char4_eigenvalue   ),
	.char5_eigenvalue	(char5_eigenvalue   ),
	.char6_eigenvalue	(char6_eigenvalue   ),
	.char7_eigenvalue	(char7_eigenvalue   ) 
);

//3.2 Template matching
template_matching#(
	.HOR_SPLIT(8), //Horizontal splits
	.VER_SPLIT(5)  //Vertical splits
)u3_template_matching(
	//Clock and reset
	.clk			 (clk	 ),   // Clock signal
	.rst_n			(rst_n   ),   // Reset signal (Low active)
	//Input video stream
	.per_frame_vsync	 (cal_eigen_vsync),
	.per_frame_href	  (cal_eigen_hsync),
	.per_frame_clken	 (cal_eigen_de   ),
	.per_frame_bit	   (cal_eigen_bit  ),
	//Plate boundary
	.plate_boarder_up	(max_line_up   ),
	.plate_boarder_down  (max_line_down ),
	.plate_boarder_left  (max_line_left ),   
	.plate_boarder_right (max_line_right),
	.plate_exist_flag	(1'b1  ),         
	//Input 7 character eigenvalues
	.char1_eigenvalue  (char1_eigenvalue),
	.char2_eigenvalue  (char2_eigenvalue),
	.char3_eigenvalue  (char3_eigenvalue),
	.char4_eigenvalue  (char4_eigenvalue),
	.char5_eigenvalue  (char5_eigenvalue),
	.char6_eigenvalue  (char6_eigenvalue),
	.char7_eigenvalue  (char7_eigenvalue),
	//Output video stream
	.post_frame_vsync  (template_vsync  ), 
	.post_frame_href   (template_hsync  ), 
	.post_frame_clken  (template_de	 ), 
	.post_frame_bit	(template_bit	), 
	//Output template matching results
	.match_index_char1 (match_index_char1),//Matched Char 1 ID
	.match_index_char2 (match_index_char2),//Matched Char 2 ID
	.match_index_char3 (match_index_char3),//Matched Char 3 ID
	.match_index_char4 (match_index_char4),//Matched Char 4 ID
	.match_index_char5 (match_index_char5),//Matched Char 5 ID
	.match_index_char6 (match_index_char6),//Matched Char 6 ID
	.match_index_char7 (match_index_char7) //Matched Char 7 ID
);

//ila_eigenvalue u_ila_eigenvalue (
//	.clk(clk), // input wire clk
//	.probe0 (match_index_char1), // input wire [5:0]  probe0  
//	.probe1 (match_index_char2), // input wire [5:0]  probe1 
//	.probe2 (match_index_char3), // input wire [5:0]  probe2 
//	.probe3 (match_index_char4), // input wire [5:0]  probe3 
//	.probe4 (match_index_char5), // input wire [5:0]  probe4 
//	.probe5 (match_index_char6), // input wire [5:0]  probe5 
//	.probe6 (match_index_char7), // input wire [5:0]  probe6
//	.probe7 (char1_eigenvalue ), // input wire [39:0]  probe7 
//	.probe8 (char2_eigenvalue ), // input wire [39:0]  probe8 
//	.probe9 (char3_eigenvalue ), // input wire [39:0]  probe9 
//	.probe10(char4_eigenvalue ), // input wire [39:0]  probe10 
//	.probe11(char5_eigenvalue ), // input wire [39:0]  probe11 
//	.probe12(char6_eigenvalue ), // input wire [39:0]  probe12 
//	.probe13(char7_eigenvalue )  // input wire [39:0]  probe13
//);

//Add plate and character borders to image
add_grid # (
	.PLATE_WIDTH(10'd5),
	.CHAR_WIDTH (10'd2)
)u4_add_grid(
	.clk			 (clk   ),   // Clock signal
	.rst_n			(rst_n ),   // Reset signal (Low active)
	//Input video stream
	.per_frame_vsync	 (pre_frame_vsync),//char_dila_vsync     //pre_frame_vsync
	.per_frame_href	  (pre_frame_hsync),//char_dila_hsync     //pre_frame_hsync	
	.per_frame_clken	 (pre_frame_de   ),//char_dila_de         //pre_frame_de   
	.per_frame_rgb	   (pre_rgb		),//{16{char_dila_bit}} //pre_rgb        		
	//Plate boundary
	.plate_boarder_up 	 (max_line_up   ),//(10'd200),
	.plate_boarder_down	 (max_line_down ),//(10'd300),
	.plate_boarder_left  (max_line_left ),//(10'd200),   
	.plate_boarder_right (max_line_right),//(10'd500),
	.plate_exist_flag	(1'b1  ),        //(1'b1   ),
	//Character boundary
	.char_line_up 	   (char_line_up	),//(10'd210),
	.char_line_down	   (char_line_down  ),//(10'd290),
	.char1_line_left	  (char1_line_left ),//(10'd210),
	.char1_line_right	 (char1_line_right),//(10'd230),
	.char2_line_left	  (char2_line_left ),//(10'd250),
	.char2_line_right	 (char2_line_right),//(10'd270),
	.char3_line_left	  (char3_line_left ),//(10'd290),
	.char3_line_right	 (char3_line_right),//(10'd310),
	.char4_line_left	  (char4_line_left ),//(10'd330),
	.char4_line_right	 (char4_line_right),//(10'd350),
	.char5_line_left	  (char5_line_left ),//(10'd370),
	.char5_line_right	 (char5_line_right),//(10'd390),
	.char6_line_left	  (char6_line_left ),//(10'd410),
	.char6_line_right	 (char6_line_right),//(10'd430),
	.char7_line_left	  (char7_line_left ),//(10'd450),
	.char7_line_right	 (char7_line_right),//(10'd470),
	//Output video stream
	.post_frame_vsync	 (add_grid_vsync),	
	.post_frame_href	  (add_grid_href ),	
	.post_frame_clken	 (add_grid_de   ),	
	.post_frame_rgb	   (add_grid_rgb  )
);

add_char u4_add_char(
	//Clock and reset
	.clk			 (clk	 ),   // Clock signal
	.rst_n			(rst_n   ),   // Reset signal (Low active)
	//Input video stream
	.per_frame_vsync	 (add_grid_vsync),
	.per_frame_href	  (add_grid_href ),
	.per_frame_clken	 (add_grid_de   ),
	.per_frame_rgb	   (add_grid_rgb  ),
	//Plate boundary
	.plate_boarder_up	(max_line_up   ),
	.plate_boarder_down  (max_line_down ),
	.plate_boarder_left  (max_line_left ),   
	.plate_boarder_right (max_line_right),
	.plate_exist_flag	(1'b1		  ),         
	//Input template matching results
	.match_index_char1   (match_index_char1),//(6'd2),//(match_index_char1)//(char1_eigenvalue[5:0])
	.match_index_char2   (match_index_char2),//(6'd2),//(match_index_char2)//(char2_eigenvalue[5:0])
	.match_index_char3   (match_index_char3),//(6'd2),//(match_index_char3)//(char3_eigenvalue[5:0])
	.match_index_char4   (match_index_char4),//(6'd2),//(match_index_char4)//(char4_eigenvalue[5:0])
	.match_index_char5   (match_index_char5),//(6'd2),//(match_index_char5)//(char5_eigenvalue[5:0])
	.match_index_char6   (match_index_char6),//(6'd2),//(match_index_char6)//(char6_eigenvalue[5:0])
	.match_index_char7   (match_index_char7),//(6'd2),//(match_index_char7)//(char7_eigenvalue[5:0])
	//Output video stream
	.post_frame_vsync	(post_frame_vsync ),  // Field sync signal
	.post_frame_href	 (post_frame_hsync ),  // Line sync signal
	.post_frame_clken	(post_frame_de	),  // Data enable
	.post_frame_rgb	  (post_rgb		 )   // RGB565 color data
);


//----------------------------------------------------------------

endmodule