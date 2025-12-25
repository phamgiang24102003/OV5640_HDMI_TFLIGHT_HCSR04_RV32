module IMEM #(parameter	MEM_FILE = "",
						SIZE = 1024
) (
	input clk,
	//Bus
	input [31:0] mem_addrpred1,
	output [31:0] mem_rdata_pred1,
	input mem_renablepred
);

	`define ENABLE_READ_INSTR_MEM;
	wire [31:0] addr_word1;
	assign addr_word1 = mem_addrpred1[31:2];
	//Boot
	(* ram_style = "block" *) reg [31:0] MEM_co [0:SIZE-1];
	initial begin
		$readmemh(MEM_FILE,MEM_co);
	end

	//read instr
	`ifdef ENABLE_READ_INSTR_MEM
	reg [31:0] rdata1;
	assign mem_rdata_pred1 = rdata1;

	always @(posedge clk) begin
		if(mem_renablepred) begin
			rdata1 <= MEM_co[addr_word1];
		end
	end
	`endif

endmodule