module uart_controller #(
    parameter INPUT_WIDTH       = 1280,
    parameter INPUT_HEIGHT      = 720,
    parameter BYTES_PER_PIXEL   = 2,
    parameter BLOCK_SIZE        = 61440,
    parameter CROP_X_START      = 320,
    parameter CROP_X_END        = 959,
    parameter CROP_Y_START      = 240,
    parameter CROP_Y_END        = 719,
    parameter OUTPUT_WIDTH      = 320,
    parameter OUTPUT_HEIGHT     = 240
) (
    input clk, rstn,
    input i_rxd,
    output o_txd,
    output reg rdfifo_rden,
    input [15:0] rdfifo_dout,
    input rdfifo_empty,
    input snapshot_done,
    output reg uart_tx_active
);

    localparam CROP_WIDTH  = CROP_X_END - CROP_X_START + 1; 
    localparam CROP_HEIGHT = CROP_Y_END - CROP_Y_START + 1; 
    localparam TOTAL_PIXELS = INPUT_WIDTH * INPUT_HEIGHT;
    localparam FIFO_TIMEOUT = 24'd10_000_000;

    localparam  CMD_REQ_BLOCK  = 8'hFF,
                CMD_FPGA_READY = 8'h0F,
                CMD_ESP_ACK    = 8'hF0,
                CMD_FRAME_DONE = 8'hEE;

    wire [7:0] rx_data;
    wire rx_done;
    wire tx_busy;
    wire tx_done;
    
    reg [7:0]  tx_data_reg;
    reg tx_en_reg;
    
    reg [11:0] x_cnt; 
    reg [11:0] y_cnt; 
    reg [20:0] read_pixel_cnt; 

    reg [9:0] out_x_cnt; 
    reg [9:0] out_y_cnt; 

    reg [16:0] block_byte_count; 
    reg [15:0] pixel_data;
    reg byte_select; 
    reg frame_pending;
    reg [23:0] fifo_timeout_cnt;

    reg [15:0] acc_x;    
    reg [15:0] acc_y;    
    reg keep_row;        

    localparam [4:0] ST_IDLE            = 5'd0,
                     ST_WAIT_SNAPSHOT   = 5'd1,
                     ST_WAIT_REQ        = 5'd2,
                     ST_SEND_HS         = 5'd3,
                     ST_WAIT_HS_DONE    = 5'd4,
                     ST_WAIT_ACK        = 5'd5,
                     ST_READ_FIFO       = 5'd6,
                     ST_WAIT_FIFO_VALID = 5'd7,
                     ST_CHECK_ROI       = 5'd8, 
                     ST_PREP_DATA       = 5'd9,
                     ST_WAIT_TX_FREE    = 5'd10,
                     ST_TRIGGER_TX      = 5'd11,
                     ST_UPDATE_BYTE     = 5'd12, 
                     ST_NEXT_PIXEL      = 5'd13, 
                     ST_SEND_DONE       = 5'd14,
                     ST_WAIT_DONE_TX    = 5'd15,
                     ST_STOP            = 5'd16;
                     
    reg [4:0] state;

    reg snapshot_done_sync1, snapshot_done_sync2, snapshot_done_sync3;
    wire snapshot_done_rise;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            snapshot_done_sync1 <= 1'b0;
            snapshot_done_sync2 <= 1'b0;
            snapshot_done_sync3 <= 1'b0;
        end else begin
            snapshot_done_sync1 <= snapshot_done;
            snapshot_done_sync2 <= snapshot_done_sync1;
            snapshot_done_sync3 <= snapshot_done_sync2;
        end
    end
    assign snapshot_done_rise = snapshot_done_sync2 & ~snapshot_done_sync3;

    uart_tx uart_tx_inst (
        .i_clk(clk), .i_tx_data(tx_data_reg), .i_tx_en(tx_en_reg),
        .o_txd(o_txd), .o_tx_busy(tx_busy), .o_tx_done(tx_done)
    );
    uart_rx uart_rx_inst (
        .i_clk(clk), .i_rxd(i_rxd), .o_rx_done(rx_done), .o_rx_data(rx_data)
    );

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= ST_IDLE;
            tx_en_reg <= 1'b0;
            rdfifo_rden <= 1'b0;
            uart_tx_active <= 1'b0;
            
            x_cnt <= 12'd0;
            y_cnt <= 12'd0;
            read_pixel_cnt <= 21'd0;
            block_byte_count <= 17'd0;
            byte_select <= 1'b0;
            
            acc_x <= 16'd0;
            acc_y <= 16'd0;
            keep_row <= 1'b0;
            out_x_cnt <= 10'd0;
            out_y_cnt <= 10'd0;
            
            frame_pending <= 1'b0; 

        end else begin
            tx_en_reg <= 1'b0;
            rdfifo_rden <= 1'b0;

            if (snapshot_done_rise) 
                frame_pending <= 1'b1;

            case (state)
                ST_IDLE: begin
                    uart_tx_active <= 1'b0;
                    x_cnt <= 12'd0;
                    y_cnt <= 12'd0;
                    read_pixel_cnt <= 21'd0;
                    block_byte_count <= 17'd0;
                    fifo_timeout_cnt <= 24'd0;
                    
                    acc_x <= 16'd0;
                    acc_y <= 16'd0;
                    keep_row <= 1'b0;
                    out_x_cnt <= 10'd0;
                    out_y_cnt <= 10'd0;
                    
                    state <= ST_WAIT_SNAPSHOT;
                end

                ST_WAIT_SNAPSHOT: begin
                    if (frame_pending) begin
                        frame_pending <= 1'b0;
                        uart_tx_active <= 1'b1;
                        state <= ST_WAIT_REQ;
                    end
                end

                ST_WAIT_REQ: begin
                    block_byte_count <= 17'd0;
                    if (rx_done && rx_data == CMD_REQ_BLOCK) state <= ST_SEND_HS;
                end

                ST_SEND_HS: begin
                    if (!tx_busy) begin
                        tx_data_reg <= CMD_FPGA_READY;
                        tx_en_reg <= 1'b1;
                        state <= ST_WAIT_HS_DONE;
                    end
                end

                ST_WAIT_HS_DONE: if (tx_done) state <= ST_WAIT_ACK;

                ST_WAIT_ACK: begin
                    if (rx_done && rx_data == CMD_ESP_ACK) begin
                        fifo_timeout_cnt <= 24'd0;
                        state <= ST_READ_FIFO;
                    end
                end

                ST_READ_FIFO: begin
                    if (!rdfifo_empty) begin
                        rdfifo_rden <= 1'b1;
                        fifo_timeout_cnt <= 24'd0;
                        state <= ST_WAIT_FIFO_VALID;
                    end else begin
                        fifo_timeout_cnt <= fifo_timeout_cnt + 1'b1;
                        if (fifo_timeout_cnt >= FIFO_TIMEOUT) state <= ST_WAIT_REQ;
                    end
                end

                ST_WAIT_FIFO_VALID: begin
                    byte_select <= 1'b0;
                    pixel_data <= rdfifo_dout;
                    state <= ST_CHECK_ROI;
                end

                ST_CHECK_ROI: begin
                    if (x_cnt == 0) begin
                        acc_x <= 16'd0;
                        out_x_cnt <= 10'd0;
                        
                        if (y_cnt >= CROP_Y_START && y_cnt <= CROP_Y_END) begin
                            if ((acc_y + OUTPUT_HEIGHT >= CROP_HEIGHT) && (out_y_cnt < OUTPUT_HEIGHT)) begin
                                keep_row <= 1'b1;
                                acc_y <= acc_y + OUTPUT_HEIGHT - CROP_HEIGHT;
                            end else begin
                                keep_row <= 1'b0;
                                acc_y <= acc_y + OUTPUT_HEIGHT;
                            end
                        end else begin
                            keep_row <= 1'b0;
                            if (y_cnt < CROP_Y_START) acc_y <= 16'd0; 
                        end
                    end

                    if (x_cnt >= CROP_X_START && x_cnt <= CROP_X_END && keep_row) begin
                        if ((acc_x + OUTPUT_WIDTH >= CROP_WIDTH) && (out_x_cnt < OUTPUT_WIDTH)) begin
                            acc_x <= acc_x + OUTPUT_WIDTH - CROP_WIDTH;
                            out_x_cnt <= out_x_cnt + 1'b1; 
                            state <= ST_PREP_DATA;
                        end else begin
                            acc_x <= acc_x + OUTPUT_WIDTH;
                            state <= ST_NEXT_PIXEL;
                        end
                    end else begin
                        state <= ST_NEXT_PIXEL;
                    end
                end

                ST_PREP_DATA: begin
                    if (byte_select == 0) tx_data_reg <= pixel_data[7:0];
                    else tx_data_reg <= pixel_data[15:8];
                    state <= ST_WAIT_TX_FREE;
                end

                ST_WAIT_TX_FREE: if (!tx_busy) begin tx_en_reg <= 1'b1; state <= ST_TRIGGER_TX; end
                ST_TRIGGER_TX: if (tx_done) state <= ST_UPDATE_BYTE;

                ST_UPDATE_BYTE: begin
                    block_byte_count <= block_byte_count + 1'b1;
                    if (byte_select == 0) begin
                        byte_select <= 1'b1;
                        state <= ST_PREP_DATA;
                    end else begin
                        state <= ST_NEXT_PIXEL;
                    end
                end

                ST_NEXT_PIXEL: begin
                    read_pixel_cnt <= read_pixel_cnt + 1'b1;
                    
                    if (x_cnt == INPUT_WIDTH - 1) begin
                        x_cnt <= 12'd0;
                        
                        if (keep_row && out_y_cnt < OUTPUT_HEIGHT) begin
                             out_y_cnt <= out_y_cnt + 1'b1;
                        end

                        if (y_cnt == INPUT_HEIGHT - 1) y_cnt <= 12'd0;
                        else y_cnt <= y_cnt + 1'b1;
                    end else begin
                        x_cnt <= x_cnt + 1'b1;
                    end

                    if (read_pixel_cnt >= TOTAL_PIXELS - 1) state <= ST_SEND_DONE;
                    else if (block_byte_count >= BLOCK_SIZE) state <= ST_WAIT_REQ;
                    else state <= ST_READ_FIFO;
                end

                ST_SEND_DONE: if (!tx_busy) begin tx_data_reg <= CMD_FRAME_DONE; tx_en_reg <= 1'b1; state <= ST_WAIT_DONE_TX; end
                ST_WAIT_DONE_TX: if (tx_done) state <= ST_STOP;
                ST_STOP: begin uart_tx_active <= 1'b0; state <= ST_IDLE; end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule