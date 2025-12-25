module DECODE (
	//Instruction
	input [31:0] instr_data,
	//decode comm
	output [31:0] Immediate,
	output insALUImm, insALUReg, insLUI, insAUIPC, insJAL, insJALR, insBRA, insLOAD, insSTORE, insSYS, insFENCE,
	output [2:0] funct3,
	output [7:0] funct3oh,
	output [6:0] funct7,
	output [4:0] regrs2,		//Shamt,
	output [4:0] regrs1,		//Zimm,
	output [4:0] regrd,
	output en_rs1,
	output en_rs2,
	output en_rd,
	//decode CSR,
	output [3:0] pred,
	output [3:0] succ,
	output [11:0] csr_addr,
	output insMRET
);

	`define COMPRESSED_EXTENTIONS

	wire [31:0] Iimm = {{21{instr_data[31]}}, instr_data[30:20]};
	wire [31:0] Simm = {{21{instr_data[31]}}, instr_data[30:25], instr_data[11:8], instr_data[7]}; 
	wire [31:0] Bimm = {{20{instr_data[31]}}, instr_data[7], instr_data[30:25], instr_data[11:8], 1'b0};
	wire [31:0] Uimm = {instr_data[31], instr_data[30:12], 12'd0};
	wire [31:0] Jimm = {{12{instr_data[31]}}, instr_data[19:12], instr_data[20], instr_data[30:21], 1'b0};

	wire [31:0] Imm =	(insLUI | insAUIPC) ? Uimm:
					(insJAL) ? Jimm:
					(insJALR|insLOAD|insALUImm|insFENCE|insSYS) ? Iimm:
					(insBRA) ? Bimm:
					(insALUReg) ? 32'd0:
					(insSTORE) ? Simm:32'd0;

	assign Immediate = Imm;

	//Instructions - opcode
	assign insALUImm = (instr_data[6:2] == 5'b00100);	// rd <- rs1 OP Iimm
	assign insALUReg = (instr_data[6:2] == 5'b01100);	// rd <- rs1 OP rs2
	assign insLUI = (instr_data[6:2] == 5'b01101);		// rd <- Uimm
	assign insAUIPC = (instr_data[6:2] == 5'b00101);	// rd <- PC + Uimm
	assign insJAL = (instr_data[6:2] == 5'b11011);		// rd <- PC+4; PC<-PC+Jimm
	assign insJALR = (instr_data[6:2] == 5'b11001);	// rd <- PC+4; PC<-rs1+Iimm
	assign insBRA = (instr_data[6:2] == 5'b11000);		// if(rs1 OP rs2) PC<-PC+Bimm
	assign insLOAD = (instr_data[6:2] == 5'b00000);	// rd <- mem[rs1+Iimm]
	assign insSTORE = (instr_data[6:2] == 5'b01000);	// mem[rs1+Simm] <- rs2
	assign insSYS = (instr_data[6:2] == 5'b11100);
	assign insFENCE = (instr_data[6:2] == 5'b00011);

	//funct3, funct7, rs2, rs1, rd, csr, shamt
	assign funct3oh = 8'b0000_0001 << instr_data[14:12];
	assign funct3 = instr_data[14:12];
	assign funct7 = instr_data[31:25];
	assign regrs2 = instr_data[24:20];
	assign regrs1 = instr_data[19:15];
	assign regrd = instr_data[11:7];

	//FENCE: pred, succ; CSR;
	assign pred = instr_data[27:24];
	assign succ = instr_data[23:20];
	assign csr_addr = instr_data[31:20];

	//Enable rs1, rs2, rd
	assign en_rd = (!insBRA)&(!insSTORE)&(!insFENCE)&(!(insSYS&funct3oh[0]));
	assign en_rs1 = ((!insAUIPC)&(!insLUI)&(!insJAL)&(!insFENCE))|(insSYS&(funct3oh[1]|funct3oh[2]|funct3oh[3]));
	assign en_rs2 = insALUReg|insSTORE|insBRA;

	assign insMRET = instr_data == 32'h30200073;

	`ifdef COMPRESSED_EXTENTIONS
    	`endif

endmodule