module RV32 #(parameter CLK_FREQ = 50_000_000) (
	input clk, rstn,
	output [31:0] peri_addr,
	output [31:0] peri_wdata,
	output [3:0] peri_wmask,
	input [31:0] peri_rdata,
	output peri_wen,
	output peri_ren,
	output [2:0] peri_burst,
	output [1:0] peri_htrans,
	input peri_rvalid,
	input peri_wdone,
	input peri_err,
	input irq_flag,
	input irq_external_pending,
	output trap_en
);

	localparam	INSTR_FIRST = 32'h00000000,
				INSTR_NOP = 32'h00000013,
				VALUE_RESET32 = 32'h00000000,
				VALUE_RESET = 0;

	localparam	IF = 0,
				ID = 1,
				EX = 2,
				MEM = 3,
				WB = 4;

	localparam	Fetchoh = 5'b00001 <<  IF,		//Fetch
				Decodeoh = 5'b00001 <<  ID,		//Decode
				Executeoh = 5'b00001 <<  EX,		//Execute
				MemoryAoh = 5'b00001 <<  MEM,	//Memory access
				WriteBoh = 5'b00001 <<  WB;		//Write back

	localparam CLOCKSYS = CLK_FREQ / 1_000_000;

	wire [31:0] memd_ldata, memins_rdata;
	reg [31:0] mem_addr;
	wire [31:0] memins_addr;

	reg [31:0] processor_data;
	wire s0_sel_mem = (mem_addr[31:28] == 4'h2);
	wire s1_sel_uflash = (mem_addr[31:28] == 4'h1);
	wire clksys = clk;

	always @(*) begin
		case(s0_sel_mem)
			1'b1: processor_data = memd_ldata;
			1'b0: processor_data = peri_rdata;
			default: processor_data = 32'h00000000;
		endcase
	end

	reg [31:0] instr_data;
	wire [31:0] Immediate;
	wire	insALUImm, insALUReg, insLUI,
		insAUIPC, insJAL, insJALR,
		insBRA, insLOAD, insSTORE,
		insSYS, insFENCE;
	wire [2:0] funct3;
	wire [7:0] funct3oh;
	wire [6:0] funct7;
	wire [4:0] regrs2;
	wire [4:0] regrs1;
	wire [4:0] regrd;
	wire en_rs1;
	wire en_rs2;
	wire en_rd;
	wire [3:0] pred;
	wire [3:0] succ;
	wire [11:0] csr_addr;
	wire insMRET;

	DECODE DECODE_inst(
		.instr_data	(instr_data),
		.Immediate	(Immediate),
		.insALUImm	(insALUImm),
		.insALUReg	(insALUReg),
		.insLUI		(insLUI),
		.insAUIPC	(insAUIPC),
		.insJAL		(insJAL),
		.insJALR		(insJALR),
		.insBRA		(insBRA),
		.insLOAD		(insLOAD),
		.insSTORE	(insSTORE),
		.insSYS		(insSYS),
		.insFENCE	(insFENCE),
		.funct3		(funct3),
		.funct3oh		(funct3oh),
		.funct7		(funct7),
		.regrs2		(regrs2),
		.regrs1		(regrs1),
		.regrd		(regrd),
		.en_rs1		(en_rs1),
		.en_rs2		(en_rs2),
		.en_rd		(en_rd),
		.pred		(pred),
		.succ		(succ),
		.csr_addr		(csr_addr),
		.insMRET	(insMRET)
);

	reg [31:0] memd_sdata;
	wire [31:0] memd_sdatafn;
	assign  memd_sdatafn = memd_sdata << (mem_addr[1:0]*8);    //Shift data for store byte or haftw
	reg memd_lready; 
	wire memins_read;
	wire [3:0] memd_mask;
	reg memd_senable = 1'b0;
	wire flag_branch;
	reg predict_taken2 = VALUE_RESET;
	reg [31:0] PCnext = INSTR_FIRST;
	reg [31:0] PCnext_fast = INSTR_FIRST;
	reg [31:0] PCnext_actual = INSTR_FIRST;
	wire [31:0] memins_rdata_pred;
	wire isRAW_Hazardrs1_2cyc_forJALR;
	wire wait_peri_as;
	wire mem_renablepred;
	wire memins_rdatacom1;
	wire memins_rdatacom2;

	IMEM #(	.MEM_FILE	("C:/Users/phamg/Downloads/firmware_instr.hex"),
			.SIZE		(8192)
	) IMEM_isnt (
		.clk 				(clksys),
		.mem_addrpred1  	(memins_addr),
		.mem_rdata_pred1	(memins_rdata),
		.mem_renablepred	(1)
	);

	wire [3:0] memd_maskfn_mem;
	wire memd_lenfn_mem;
	assign memd_maskfn_mem = memd_mask & {4{memd_senable}} & {4{s0_sel_mem}} & {4{insSTORE}};
	assign memd_lenfn_mem = memd_lready & insLOAD;

	DMEM #(	.MEM_FILE	("C:/Users/phamg/Downloads/firmware_data.hex"),
			.SIZE		(8192)
	) DMEM_isnt (
		.clk			(clksys),
		.mem_addr	({4'h0, mem_addr[27:0]}),
		.mem_ldata	(memd_ldata),
		.mem_sdata	(memd_sdatafn),    
		.mem_lenable	(memd_lenfn_mem),
		.mem_mask	(memd_maskfn_mem)
	);

	wire [31:0] mem_addrforl; 
	//load, store 8bit, 16bit or 32bit
	wire lsByte;
	wire lsHaftW;
	wire lsWord;
	wire lsSign;
	wire lsBytefn;
	wire lsHaftWfn;
	wire lsWordfn;
	wire lsSignfn;

	assign lsByte = (funct3[1:0] == 2'b00);
	assign lsHaftW = (funct3[0]);
	assign lsWord = (funct3[1]);
	assign lsSign = (!funct3[2]);

	assign lsBytefn = lsByte;
	assign lsHaftWfn = lsHaftW;
	assign lsWordfn = lsWord;
	assign lsSignfn = lsSign;

	assign mem_addrforl = mem_addr;

	//gen mem_mask and make load data 8bit, 16bit or 32bit
	assign memd_mask =	lsWord ? 4'b1111:
						lsHaftW ? (mem_addr[1] ? 4'b1100:4'b0011):
						lsByte ? (mem_addr[1]?(mem_addr[0] ? 4'b1000:4'b0100):
						(mem_addr[0]?4'b0010:4'b0001)) : 4'b0;

	wire [31:0] byte_data;
	wire [31:0] halfw_data;

	assign byte_data =	(mem_addrforl[1:0] == 2'b00) ? processor_data[7:0]:
					(mem_addrforl[1:0] == 2'b01) ? processor_data[15:8]:
					(mem_addrforl[1:0] == 2'b10) ? processor_data[23:16]:
					processor_data[31:24];
	assign halfw_data = mem_addrforl[1] ? processor_data[31:16] : processor_data[15:0];

	wire [31:0] mem_ldmask;     //Mem load data(mask)

	assign mem_ldmask = 	lsWordfn ? processor_data :
						lsHaftWfn ? (lsSignfn ? {{16{halfw_data[15]}}, halfw_data[15:0]} : {16'b0, halfw_data[15:0]}) :
						lsBytefn  ? (lsSignfn ? {{24{byte_data[7]}}, byte_data[7:0]} : {24'b0, byte_data[7:0]}) : 32'b0;

	wire [31:0] result_ALU;
	wire [31:0] data_rs1;
	wire [31:0] data_rs1fn;
	wire [31:0] data_rs2;   
	wire [31:0] data_rs2fn;
	wire [31:0] temphz;
	//Hazard RAW
	reg [4:0] regrd_shifthz1 = 5'h00;
	reg [4:0] regrd_shifthz2 = 5'h00;
	reg [4:0] regrd_shifthz3 = 5'h00;
	reg [4:0] regrs1_shifthz1 = 5'h00;
	reg [4:0] regrs1_shifthz2 = 5'h00;
	reg [4:0] regrs1_shifthz3 = 5'h00;
	reg [11:0] csr_addr_shift1 = 5'h00;
	reg [11:0] csr_addr_shift2 = 5'h00;
	reg [11:0] csr_addr_shift3 = 5'h00;


	wire isRAW_Hazardrs1_1cyc_forWB;
	wire isRAW_Hazardrs2_1cyc_forWB;
	wire isRAW_Hazardrs1_2cyc_forWB;
	wire isRAW_Hazardrs2_2cyc_forWB;
	wire isRAW_Hazardrs1_3cyc_forWB;
	wire isRAW_Hazardrs2_3cyc_forWB;

	reg en_rdhz1 = VALUE_RESET;
	reg en_rdhz2 = VALUE_RESET;
	reg en_rdhz3 = VALUE_RESET;
	reg en_rs1hz1 = VALUE_RESET;
	reg en_rs1hz2 = VALUE_RESET;

	//Result of ins
	reg [31:0] result;
	wire [31:0] resulthz_1cyc;
	wire [31:0] resulthz_2cyc;
	wire [31:0] resulthz_3cyc;

	assign data_rs2fn = (insALUImm)?(((!funct3[1])&funct3[0])?regrs2:Immediate):data_rs2;
	assign data_rs1fn = (insSYS)?((funct3[2])?regrs1:data_rs1):data_rs1;

	wire [31:0] csr_rdata;

	ALU ALU_isnt (
		.isALUimm	(insALUImm),
		.isALUreg		(insALUReg),
		.isBranch		(insBRA),
		.isSYS		(insSYS),
		.funct3oh		(funct3oh),
		.funct3		(funct3),
		.funct7		(funct7),
		.rs1			(data_rs1fn),
		.rs2			(data_rs2fn),
		.csr_rdata		(csr_rdata),
		.result		(result_ALU),
		.correct		(flag_branch)
	);

	wire [31:0] data_desfn;
	wire [4:0] regrdfn;
	reg [31:0] data_des;
	reg [4:0] regrd_shiftpl = 5'h00;
	assign data_desfn = data_des;
	assign regrdfn = regrd;

	reg data_valid;

	reg csr_we;
	reg [31:0] csr_wdata = VALUE_RESET32;

	REG REG_inst(
		.clk			(clksys), 
		.rs1			(regrs1),
		.rs2			(regrs2),
		.rd			(regrdfn),
		.data_des		(data_desfn),
		.data_valid	(data_valid),
		.data_rs1		(data_rs1),
		.data_rs2		(data_rs2)
	);

	reg [11:0] csr_addrpl;
	reg [63:0] csr_instret = 64'b0;
	reg [63:0] csr_real_mtime = 64'd0;
	reg [7:0] cnt = 8'b1;

	reg csr_trap_taken = 1'b0;
	reg [31:0] csr_trap_pc = 32'd0;
	wire [31:0] csr_trap_rpc;
	wire [31:0] csr_trap_addr;
	reg [31:0] csr_trap_cause = 32'd0;

	CSR CSR_inst(
		.clk			(clksys), 
		.rstn			(rstn), 
		.csr_addrr	(csr_addr), 
		.csr_addrw	(csr_addr), 
		.csr_wdata	(csr_wdata), 
		.csr_we		(csr_we), 
		.csr_rdata		(csr_rdata), 
		.csr_instret	(csr_instret), 
		.real_mtime	(csr_real_mtime),    //tick), 
		.trap_taken	(csr_trap_taken), 
		.trap_complete	(insMRET), 
		.updateMEPC	(UpdateMEPC), 
		.trap_pc		(csr_trap_pc), 
		.trap_rpc		(csr_trap_rpc), 
		.trap_addr	(csr_trap_addr), 
		.trap_cause	(csr_trap_cause), 
		.irq_software	(1'b0), 
		.irq_timer		(1'b0), 
		.irq_external	(irq_external_pending), 
		.global_ie		(irq_en)
	);

	assign trap_en = irq_en;
	//Count time (1tick = 1us)
	always @(posedge clksys) begin
		if (!rstn) begin
			cnt <= 1;
			csr_real_mtime <= 64'b0;
		end
		else begin
			cnt <= cnt + 1;
			if (cnt == CLOCKSYS) begin
				cnt <= 1;
				csr_real_mtime <= csr_real_mtime + 1;
			end
		end
	end

	assign peri_burst = 3'b000;
	assign peri_htrans = ((peri_ren || peri_wen) && !s0_sel_mem)?2'b10:2'b00;
	assign peri_addr = mem_addr;
	assign peri_wdata = memd_sdata;
	assign peri_wmask = memd_mask;
	assign peri_wen = insSTORE && memd_senable;
	assign peri_ren = memd_lready & insLOAD;
	wire peri_trans_done = (peri_ren && peri_rvalid) || (peri_wen && peri_wdone);
	reg [31:0] PC = INSTR_FIRST;
	reg [4:0] state = 5'b00001;
	reg [31:0] load_data;
	wire insALU = insALUImm || insALUReg;

	assign memins_read = state[IF]; //only Instruction Fetch
	assign memins_addr = PC;

	reg irq_flagh = 0;
	reg irq_active = 0;
	always @(posedge clksys) begin
		if (!rstn)
			irq_flagh <= 1'b0;
		else begin
			if (irq_flag)
				irq_flagh <= 1'b1;
			if (irq_active)
				irq_flagh <= 1'b0;
		end
	end

	reg [31:0] PCreturnIRQ;
	always @(*) begin
		if (!rstn)
			PCreturnIRQ = INSTR_FIRST;
		else begin
			(*parallel_case*)
			case(1'b1)
				insBRA:     PCreturnIRQ = flag_branch ? PC + Immediate : PC+4;
				insJAL:     PCreturnIRQ = PC + Immediate;
				insJALR:    PCreturnIRQ = (data_rs1 + Immediate) & ~32'h1;
				default:    PCreturnIRQ = PC + 4;
			endcase
		end
	end

	always @(posedge clksys) begin
		if (!rstn) begin
			PC <= INSTR_FIRST;
			PCnext <= INSTR_FIRST;
			data_valid <= VALUE_RESET;
			memd_lready <= VALUE_RESET;
			memd_senable <= VALUE_RESET;
			data_des <= VALUE_RESET32;
			memd_sdata <= VALUE_RESET32;
			state <= Fetchoh;
		end
		else begin
			(*parallel_case*)
			case(1'b1)
				state[IF] : begin
					data_valid <= 1'b0;
					csr_we <= 1'b0;
					state <= Decodeoh;    //ID
              			end
				state[ID] : begin
					instr_data <= memins_rdata;
					state <= Executeoh;   //EX
				end
				state[EX] : begin
					(*parallel_case*)
					case(1'b1)
						insBRA: PCnext <= flag_branch ? PC + Immediate : PC+4;
						insLOAD: begin
							memd_lready <= 1'b1;
							mem_addr <= data_rs1 + Immediate;
						end
						insSTORE: mem_addr <= data_rs1 + Immediate;
						insALU: result <= result_ALU;
						insLUI: result <= Immediate;
						insAUIPC: result <= PC + Immediate;
						insJAL: begin
							result <= PC + 4;
							PCnext <= PC + Immediate;
						end
						insJALR: begin
							result <= PC + 4;
							PCnext <= (data_rs1 + Immediate) & ~32'h1;
						end
						insSYS: result <= result_ALU;
						default: state <= Fetchoh;
					endcase
					state <= (insLOAD || insSTORE) ? MemoryAoh : WriteBoh;
					if (!(insBRA||insJAL||insJALR))
						PCnext <= PC + 4;
					csr_trap_taken <= 1'b0;
					irq_active <= 1'b0;
					if (irq_flagh) begin
						irq_active <= 1'b1;
						PCnext <= csr_trap_addr;
						csr_trap_taken <= 1'b1;
						csr_trap_pc <= PCreturnIRQ;
						csr_trap_cause <= 32'h8000000B;
					end
					if (insMRET)
						PCnext <= csr_trap_rpc;
				end
				state[MEM]  : begin
					if (insLOAD)
						load_data <= mem_ldmask;
					else begin
						memd_sdata <= data_rs2;
						memd_senable <= 1'b1;
					end
					if (s0_sel_mem || peri_trans_done) begin
						memd_lready <= 1'b0;
						memd_senable <= s0_sel_mem;
						state <= WriteBoh;
					end
				end
				state[WB] : begin
					memd_senable <= 1'b0;
					case(1'b1)
						insLOAD: begin
							data_des <= mem_ldmask;
							data_valid <= 1'b1;
						end
						insALU | insLUI | insAUIPC | insJAL | insJALR: begin
							data_des <= result;
							data_valid <= 1'b1;
						end
						insSYS: begin
							data_valid <= 1'b1;
							data_des <= csr_rdata;
							csr_we <= !(regrs1 == 5'h00 && en_rs1);
							csr_wdata <= result;
						end
					endcase
					state <= Fetchoh;
					PC <= PCnext;
					csr_instret <= csr_instret + 1;
				end
			endcase
		end
	end

endmodule