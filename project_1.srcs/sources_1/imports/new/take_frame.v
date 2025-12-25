module take_frame #(parameter	IMAGE_WIDTH 	= 1280,
						IMAGE_HEIGHT 	= 720
) (
	input pclk,
	input rstn,
	input vsync,
	input data_valid,
	input snapshot_req,
	output reg snapshot_active,
	output reg snapshot_done
);

	localparam PIX_MAX = IMAGE_WIDTH * IMAGE_HEIGHT;
	reg [20:0] pix_cnt;

	// Sync snapshot_req to pclk
	reg snap_sync1, snap_sync2, snap_sync_d;
	wire snap_sync = snap_sync2;
	wire snapshot_req_rise = snap_sync & ~snap_sync_d;

	// Detect vsync edges in pclk domain
	reg vsync_d;
	wire vsync_fall = ~vsync &  vsync_d;
	wire vsync_rise =  vsync & ~vsync_d;

	// Latch pending trigger so vsync_fall and trigger need not coincide
	reg snap_pending;
	wire arm = snap_pending && vsync_fall;

	always @(posedge pclk or negedge rstn) begin
		if (!rstn) begin
			snap_sync1       <= 1'b0;
			snap_sync2       <= 1'b0;
			snap_sync_d      <= 1'b0;
			vsync_d          <= 1'b0;
			snap_pending     <= 1'b0;
			snapshot_active  <= 1'b0;
			snapshot_done    <= 1'b0;
			pix_cnt          <= 21'd0;
		end
		else begin
			// sync inputs
			snap_sync1  <= snapshot_req;
			snap_sync2  <= snap_sync1;
			snap_sync_d <= snap_sync2;
			vsync_d     <= vsync;

			// latch request
			if (snapshot_req_rise)
				snap_pending <= 1'b1;
			if (arm)
				snap_pending <= 1'b0;

			// clear done only on new request
			if (snapshot_req_rise)
				snapshot_done <= 1'b0;

			// arm at vsync_fall when pending
			if (arm) begin
				snapshot_active <= 1'b1;
				pix_cnt         <= 21'd0;
			end

			// count pixels
			if (snapshot_active && data_valid) begin
				pix_cnt <= pix_cnt + 1'b1;
				if (pix_cnt == PIX_MAX-1) begin
					snapshot_active <= 1'b0;
					snapshot_done   <= 1'b1;
				end
			end

			// end frame on vsync rising early
			if (snapshot_active && vsync_rise) begin
				snapshot_active <= 1'b0;
				snapshot_done   <= 1'b1;
			end
		end
	end

endmodule