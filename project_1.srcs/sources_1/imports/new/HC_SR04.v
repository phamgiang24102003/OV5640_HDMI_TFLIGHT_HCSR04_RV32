module HC_SR04 #(parameter CLK_FREQ = 50_000_000) (
	clk, rstn,
	echo,
	trigger,
	object_detected
);

	input clk, rstn;
	//HC-SR04 signal
	input echo;
	output reg trigger;
	output reg object_detected;

	localparam	ONE_US = CLK_FREQ / 1_000_000,
				TEN_US = CLK_FREQ / 100_000,
				FORTY_MS = CLK_FREQ * 40 / 1_000,
				WINDOW_SIZE = 600 / 40,
				REQUIRE_DETECT = 400 / 40;

	reg [6:0] distance_mm;
	reg [32:0] r_distance;
	reg [32:0] us_cnt;
	reg [9:0] one_us_cnt;
	wire one_us;
	reg [9:0] ten_us_cnt;
	wire ten_us;
	reg [21:0] forty_ms_cnt;
	wire forty_ms;

	reg [7:0] detect_counter;
	reg [7:0] window_counter;

	assign one_us = (one_us_cnt == 0);
	assign ten_us = (ten_us_cnt == 0);
	assign forty_ms = (forty_ms_cnt == 0);

	always@(posedge clk or negedge rstn) begin
		if (!rstn) begin
			us_cnt <= 0;
			one_us_cnt <= 0;
			ten_us_cnt <= 0;
			forty_ms_cnt <= 0;

			trigger <= 0;
			distance_mm <= 0;

			detect_counter <= 0;
			window_counter <= 0;
			object_detected <= 0;
		end
		else begin
			one_us_cnt <= (one_us ? ONE_US : one_us_cnt) - 1;
			ten_us_cnt <= (ten_us ? TEN_US : ten_us_cnt) - 1;
			forty_ms_cnt <= (forty_ms ? FORTY_MS : forty_ms_cnt) - 1;

			if (ten_us && trigger)
				trigger <= 0;

			if (one_us) begin
				if (echo)
					us_cnt <= us_cnt + 1;
				else if (us_cnt) begin
					r_distance <= us_cnt * 340 / 2000;
					if (r_distance <= 75)
						distance_mm <= r_distance;
					else
						distance_mm <= 0;
					us_cnt <= 0;
				end
			end

			if (forty_ms) begin
				trigger <= 1;
				if (distance_mm > 10)
					detect_counter <= detect_counter + 1;

				window_counter <= window_counter + 1;

				if (window_counter >= WINDOW_SIZE) begin
					if (detect_counter >= REQUIRE_DETECT)
						object_detected <= 1;
					else
						object_detected <= 0;

					window_counter <= 0;
					detect_counter <= 0;
				end
			end
		end
	end

endmodule