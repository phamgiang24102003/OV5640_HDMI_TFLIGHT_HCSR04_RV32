/*
Usage Instructions:
Select two predefined parameters according to actual requirements.

Parameter 1: MODE_RGBxxx
Used to determine whether the driver works in 16-bit mode or 24-bit mode.
	 MODE_RGB888: 24-bit mode
	 MODE_RGB565: 16-bit mode
For different display devices, choose the appropriate color mode:
	 4.3-inch TFT display ---- use 16-bit RGB565
	 5-inch TFT display  ----- use 16-bit RGB565
	 GM7123 module ---------- use 24-bit RGB888

Parameter 2: Resolution_xxxx
Used to determine the resolution of the display device. Common resolutions:

4.3-inch TFT display:
	 Resolution_480x272

5-inch TFT display:
	 Resolution_800x480

Common resolutions:
	 Resolution_640x480
	 Resolution_800x600
	 Resolution_1024x600
	 Resolution_1024x768
	 Resolution_1280x720
	 Resolution_1920x1080
*/

// You can also define the display type via macro definitions below.
// Enable one option and comment out others as needed.

// Use 4.3-inch 480x272 TFT display
//`define HW_TFT480x272

// Use 5-inch 800x480 TFT display
//`define HW_TFT800x480

// Default 640x480 resolution, 24-bit mode.
// Other resolutions or 16-bit mode can be reconfigured at line 63?75.
`define HW_HDMI1280x720

//=====================================
// The following defines color depth and resolution parameters
// based on selected display type
//=====================================
`ifdef HW_TFT480x272
	`define MODE_RGB565
	`define Resolution_480x272 1	// Pixel clock = 9MHz

`elsif HW_TFT800x480
	`define MODE_RGB565
	`define Resolution_800x480 1	// Pixel clock = 33MHz

`elsif HW_HDMI640x480
	`define MODE_RGB888
	`define Resolution_640x480 1	// Pixel clock = 25.2MHz

`elsif HW_HDMI800x450
	`define MODE_RGB888
	`define Resolution_800x450 1	// Pixel clock = 33MHz

`elsif HW_HDMI1280x720
	`define MODE_RGB888
	`define Resolution_1280x720   1// Pixel clock = 74.25MHz
`endif

//=====================================
// Below section usually doesn?t need modification
//=====================================
// Define color depth
`ifdef MODE_RGB888
	`define Red_Bits	8
	`define Green_Bits	8
	`define Blue_Bits	8
	
`elsif MODE_RGB565
	`define Red_Bits	5
	`define Green_Bits	6
	`define Blue_Bits	5
`endif

// Define timing parameters for different resolutions
`ifdef Resolution_480x272
	`define H_Total_Time	12'd525
	`define H_Right_Border	12'd0
	`define H_Front_Porch	12'd2
	`define H_Sync_Time	12'd41
	`define H_Back_Porch	12'd2
	`define H_Left_Border	12'd0

	`define V_Total_Time	12'd286
	`define V_Bottom_Border	12'd0
	`define V_Front_Porch	12'd2
	`define V_Sync_Time	12'd10
	`define V_Back_Porch	12'd2
	`define V_Top_Border	12'd0
	
`elsif Resolution_640x480
	`define H_Total_Time	12'd800
	`define H_Right_Border	12'd8
	`define H_Front_Porch	12'd8
	`define H_Sync_Time	12'd96
	`define H_Back_Porch	12'd40
	`define H_Left_Border	12'd8

	`define V_Total_Time	12'd525
	`define V_Bottom_Border	12'd8
	`define V_Front_Porch	12'd2
	`define V_Sync_Time	12'd2
	`define V_Back_Porch	12'd25
	`define V_Top_Border	12'd8

`elsif Resolution_800x480
	`define H_Total_Time	12'd1056
	`define H_Right_Border	12'd0
	`define H_Front_Porch	12'd40
	`define H_Sync_Time	12'd128
	`define H_Back_Porch	12'd88
	`define H_Left_Border	12'd0

	`define V_Total_Time	12'd525
	`define V_Bottom_Border	12'd8
	`define V_Front_Porch	12'd2
	`define V_Sync_Time	12'd2
	`define V_Back_Porch	12'd25
	`define V_Top_Border	12'd8

`elsif Resolution_800x450
	`define H_Total_Time	12'd1056
	`define H_Right_Border	12'd0
	`define H_Front_Porch	12'd40
	`define H_Sync_Time	12'd128
	`define H_Back_Porch	12'd88
	`define H_Left_Border	12'd0

	`define V_Total_Time	12'd525
	`define V_Bottom_Border	12'd23
	`define V_Front_Porch	12'd2
	`define V_Sync_Time	12'd2
	`define V_Back_Porch	12'd25
	`define V_Top_Border	12'd23

`elsif Resolution_800x600
	`define H_Total_Time	12'd1056
	`define H_Right_Border	12'd0
	`define H_Front_Porch	12'd40
	`define H_Sync_Time	12'd128
	`define H_Back_Porch	12'd88
	`define H_Left_Border	12'd0

	`define V_Total_Time	12'd628
	`define V_Bottom_Border	12'd0
	`define V_Front_Porch	12'd1
	`define V_Sync_Time	12'd4
	`define V_Back_Porch	12'd23
	`define V_Top_Border	12'd0

`elsif Resolution_1024x600
	`define H_Total_Time	12'd1344
	`define H_Right_Border	12'd0
	`define H_Front_Porch	12'd24
	`define H_Sync_Time	12'd136
	`define H_Back_Porch	12'd160
	`define H_Left_Border	12'd0

	`define V_Total_Time	12'd628
	`define V_Bottom_Border	12'd0
	`define V_Front_Porch	12'd1
	`define V_Sync_Time	12'd4
	`define V_Back_Porch	12'd23
	`define V_Top_Border	12'd0

`elsif Resolution_1024x768
	`define H_Total_Time	12'd1344
	`define H_Right_Border	12'd0
	`define H_Front_Porch	12'd24
	`define H_Sync_Time	12'd136
	`define H_Back_Porch	12'd160
	`define H_Left_Border	12'd0

	`define V_Total_Time	12'd806
	`define V_Bottom_Border	12'd0
	`define V_Front_Porch	12'd3
	`define V_Sync_Time	12'd6
	`define V_Back_Porch	12'd29
	`define V_Top_Border	12'd0

`elsif Resolution_1280x720
	`define H_Total_Time	12'd1650
	`define H_Right_Border	12'd0
	`define H_Front_Porch	12'd110
	`define H_Sync_Time	12'd40
	`define H_Back_Porch	12'd220
	`define H_Left_Border	12'd0

	`define V_Total_Time	12'd750
	`define V_Bottom_Border	12'd0
	`define V_Front_Porch	12'd5
	`define V_Sync_Time	12'd5
	`define V_Back_Porch	12'd20
	`define V_Top_Border	12'd0
	
`elsif Resolution_1920x1080
	`define H_Total_Time	12'd2200
	`define H_Right_Border	12'd0
	`define H_Front_Porch	12'd88
	`define H_Sync_Time	12'd44
	`define H_Back_Porch	12'd148
	`define H_Left_Border	12'd0

	`define V_Total_Time	12'd1125
	`define V_Bottom_Border	12'd0
	`define V_Front_Porch	12'd4
	`define V_Sync_Time	12'd5
	`define V_Back_Porch	12'd36
	`define V_Top_Border	12'd0
`endif