module CSR (
	input clk, rstn,
	input [11:0] csr_addrr,
	input [11:0] csr_addrw,
	input [31:0] csr_wdata,
	input csr_we,
	output reg [31:0] csr_rdata,
	input trap_taken,
	input trap_complete,
	input updateMEPC,
	input [31:0] trap_pc,
	output [31:0] trap_addr,
	output [31:0] trap_rpc,
	input [31:0] trap_cause,
	input [63:0] real_mtime,
	input [63:0] csr_instret,
	input irq_software,
	input irq_timer,
	input irq_external,
	output global_ie
);

	reg [31:0] mstatus;
	reg [31:0] mie;
	reg [31:0] mtvec;
	reg [31:0] mepc;
	reg [31:0] mcause;
	reg [31:0] mip;
	reg [63:0] cycle;
	reg [63:0] instret;
	reg [63:0] mtime;

	assign global_ie = mstatus[3] && mie[11];
	assign trap_rpc  = mepc;
	assign trap_addr = {mtvec[31:2], 2'b00};

	always @(posedge clk) begin
		if (!rstn) begin
			cycle   <= 64'd0;
			instret <= 64'd0;
			mtime   <= 64'd0;
		end
		else begin
			cycle   <= cycle + 1;
			instret <= csr_instret;
			mtime   <= real_mtime;
		end
	end

	reg mask;

	always @(posedge clk) begin
		if (!rstn) begin
			mstatus <= 32'h0;
			mie <= 32'h0;
			mtvec <= 32'h0;
			mepc <= 32'h0;
			mcause <= 32'h0;
			mip <= 32'h0;
			mask <= 1'b0;
		end
		else begin
			mip[3]  <= irq_software;
			mip[7]  <= irq_timer;
			mip[11] <= irq_external;
			if (csr_we) begin
				case (csr_addrw)
					12'h300: mstatus <= csr_wdata;
					12'h304: mie <= csr_wdata;
					12'h305: mtvec <= csr_wdata;
					12'h341: mepc <= csr_wdata;
					12'h342: mcause <= csr_wdata;
					12'h344: mip <= csr_wdata;
				endcase
			end

			if (trap_taken && !mask) begin
				mask <= 1'b1;
				mepc <= trap_pc;
				mcause <= trap_cause;
				mstatus[7] <= mstatus[3];
				mstatus[3] <= 1'b0;
				mstatus[12:11] <= 2'b11;
			end

			if (updateMEPC)
				mepc <= trap_pc;

			if (trap_complete) begin
				mask <= 1'b0;
				mstatus[3] <= mstatus[7];
			end
		end
	end

	always @(*) begin
		case (csr_addrr)
			12'h300: csr_rdata = mstatus;
			12'h304: csr_rdata = mie;
			12'h305: csr_rdata = mtvec;
			12'h341: csr_rdata = mepc;
			12'h342: csr_rdata = mcause;
			12'h344: csr_rdata = mip;
			12'hC00: csr_rdata = cycle[31:0];
			12'hC80: csr_rdata = cycle[63:32];
			12'hC01: csr_rdata = mtime[31:0];
			12'hC81: csr_rdata = mtime[63:32];
			12'hC02: csr_rdata = instret[31:0];
			12'hC82: csr_rdata = instret[63:32];
			default: csr_rdata = 32'h0;
		endcase
	end

endmodule