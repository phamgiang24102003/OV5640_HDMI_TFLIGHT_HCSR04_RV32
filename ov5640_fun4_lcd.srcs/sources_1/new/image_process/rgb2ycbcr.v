module rgb2ycbcr
(
    input               clk             ,   // Module driving clock
    input               rst_n           ,   // Reset signal, active low
    // Input Image Interface (RGB565)
    input               pre_frame_vsync ,   // Vertical sync signal
    input               pre_frame_hsync ,   // Horizontal sync signal
    input               pre_frame_de    ,   // Data enable signal
    input       [4:0]   img_red         ,   // Input image R (5-bit)
    input       [5:0]   img_green       ,   // Input image G (6-bit)
    input       [4:0]   img_blue        ,   // Input image B (5-bit)
    // Output Image Interface (YCbCr + Binary)
    output              post_frame_vsync,   // Output vsync
    output              post_frame_hsync,   // Output hsync
    output              post_frame_de   ,   // Output data enable
    output      [7:0]   img_y           ,   // Output Y (Luminance)
    output      [7:0]   img_cb          ,   // Output Cb (Chrominance)
    output      [7:0]   img_cr          ,   // Output Cr (Chrominance)
    output      [7:0]   img_cw              // Output Binary (White/Black)

);
// Parameters for Binarization

localparam [7:0] THRESHOLD = 8'd100;

// Internal Registers
reg  [15:0]   rgb_r_m0, rgb_r_m1, rgb_r_m2;
reg  [15:0]   rgb_g_m0, rgb_g_m1, rgb_g_m2;
reg  [15:0]   rgb_b_m0, rgb_b_m1, rgb_b_m2;
reg  [15:0]   img_y0 ;
reg  [15:0]   img_cb0;
reg  [15:0]   img_cr0;
reg  [ 7:0]   img_y1 ;
reg  [ 7:0]   img_cb1;
reg  [ 7:0]   img_cr1;
reg  [ 7:0]   img_cw1;
reg  [ 2:0]   pre_frame_vsync_d;
reg  [ 2:0]   pre_frame_hsync_d;
reg  [ 2:0]   pre_frame_de_d   ;
// Internal Wires
wire [ 7:0]   rgb888_r;
wire [ 7:0]   rgb888_g;
wire [ 7:0]   rgb888_b;
// Convert RGB565 to RGB888 by padding lower bits
assign rgb888_r = {img_red  , img_red[4:2]  };
assign rgb888_g = {img_green, img_green[5:4]};
assign rgb888_b = {img_blue , img_blue[4:2] };
// Synchronize control signals with 3-clock pipeline delay
assign post_frame_vsync = pre_frame_vsync_d[2];
assign post_frame_hsync = pre_frame_hsync_d[2];
assign post_frame_de    = pre_frame_de_d[2]   ;
// Final Output Assignment (Gate data with Hsync/DE)
assign img_y  = post_frame_de ? img_y1  : 8'd0;
assign img_cb = post_frame_de ? img_cb1 : 8'd0;
assign img_cr = post_frame_de ? img_cr1 : 8'd0;
assign img_cw = post_frame_de ? img_cw1 : 8'd0;
//--------------------------------------------
// RGB 888 to YCbCr Conversion Logic
/*
    Y  = (77 *R  + 150*G + 29 *B) >> 8
    Cb = (-43*R  - 85 *G + 128*B + 32768) >> 8
    Cr = (128*R  - 107*G - 21 *B + 32768) >> 8
*/
// Stage 1: Multiplication (Pipeline Step 1)
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rgb_r_m0 <= 16'd0; rgb_r_m1 <= 16'd0; rgb_r_m2 <= 16'd0;
        rgb_g_m0 <= 16'd0; rgb_g_m1 <= 16'd0; rgb_g_m2 <= 16'd0;
        rgb_b_m0 <= 16'd0; rgb_b_m1 <= 16'd0; rgb_b_m2 <= 16'd0;
    end
    else begin
        rgb_r_m0 <= rgb888_r * 8'd77 ;
        rgb_r_m1 <= rgb888_r * 8'd43 ;
        rgb_r_m2 <= rgb888_r << 3'd7 ; // Equivalent to * 128
        rgb_g_m0 <= rgb888_g * 8'd150;
        rgb_g_m1 <= rgb888_g * 8'd85 ;
        rgb_g_m2 <= rgb888_g * 8'd107;
        rgb_b_m0 <= rgb888_b * 8'd29 ;
        rgb_b_m1 <= rgb888_b << 3'd7 ; // Equivalent to * 128
        rgb_b_m2 <= rgb888_b * 8'd21 ;
    end
end
// Stage 2: Addition and Constant Offsets (Pipeline Step 2)
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        img_y0  <= 16'd0;
        img_cb0 <= 16'd0;
        img_cr0 <= 16'd0;
    end
    else begin
        img_y0  <= rgb_r_m0 + rgb_g_m0 + rgb_b_m0;
        img_cb0 <= rgb_b_m1 - rgb_r_m1 - rgb_g_m1 + 16'd32768;
        img_cr0 <= rgb_r_m2 - rgb_g_m2 - rgb_b_m2 + 16'd32768;
    end
end
// Stage 3: Division (Shifting) and Binarization (Pipeline Step 3)
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        img_y1  <= 8'd0;
        img_cb1 <= 8'd0;
        img_cr1 <= 8'd0;
        img_cw1 <= 8'd0;
    end
    else begin
        img_y1  <= img_y0 [15:8];
        img_cb1 <= img_cb0[15:8];
        img_cr1 <= img_cr0[15:8];
        // Binarization logic: If Luminance > Threshold, result is White (255)
        if (img_y0[15:8] > THRESHOLD)
            img_cw1 <= 8'hFF;
        else
            img_cw1 <= 8'h00;
    end
end
// Synchronize control signals by delaying them 3 cycles
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        pre_frame_vsync_d <= 3'd0;
        pre_frame_hsync_d <= 3'd0;
        pre_frame_de_d    <= 3'd0;
    end
    else begin
        pre_frame_vsync_d <= {pre_frame_vsync_d[1:0], pre_frame_vsync};
        pre_frame_hsync_d <= {pre_frame_hsync_d[1:0], pre_frame_hsync};
        pre_frame_de_d    <= {pre_frame_de_d[1:0]   , pre_frame_de   };
    end
end

endmodule