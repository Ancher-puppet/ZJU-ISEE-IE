`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
//////////////////////////////////////////////////////////////////////////////////
module ID(clk,Instruction_id, PC_id, RegWrite_wb, rdAddr_wb, RegWriteData_wb, MemRead_ex, 
          rdAddr_ex, MemtoReg_id, RegWrite_id, MemWrite_id, MemRead_id, ALUCode_id, 
			 ALUSrcA_id, ALUSrcB_id,  Stall, Branch, Jump, IFWrite,  JumpAddr, Imm_id,
			 rs1Data_id, rs2Data_id,rs1Addr_id,rs2Addr_id,rdAddr_id);
    input clk;
    input [31:0] Instruction_id;
    input [31:0] PC_id;
    input RegWrite_wb;
    input [4:0] rdAddr_wb;
    input [31:0] RegWriteData_wb;
    input MemRead_ex;
    input [4:0] rdAddr_ex;
	
    output MemtoReg_id;
    output RegWrite_id;
    output MemWrite_id;
    output MemRead_id;
    output [3:0] ALUCode_id;
    output ALUSrcA_id;
    output [1:0]ALUSrcB_id;
    output Stall;
    output Branch;
    output Jump;
    output IFWrite;
    output [31:0] JumpAddr;
    output [31:0] Imm_id;
    output [31:0] rs1Data_id;
    output [31:0] rs2Data_id;
	output[4:0] rs1Addr_id,rs2Addr_id,rdAddr_id;
 
	//Decode+Imm模块
	wire JALR;
	wire [31:0]offset_id;
    Decode Decode_id(
        .Instruction(Instruction_id),
		
        .JALR(JALR),
        .MemtoReg(MemtoReg_id),
        .RegWrite(RegWrite_id),
        .MemWrite(MemWrite_id),
        .MemRead(MemRead_id),
        .ALUCode(ALUCode_id),
        .ALUSrcA(ALUSrcA_id),
        .ALUSrcB(ALUSrcB_id),
        .Imm(Imm_id),
        .Jump(Jump),
        .offset(offset_id)
    );
	//寄存器堆Registers
	//寄存器地址
	assign rs1Addr_id = Instruction_id[19:15];
    assign rs2Addr_id = Instruction_id[24:20];
    assign rdAddr_id = Instruction_id[11:7];
	RAWRegisters RAWRegisters_id(
        .clk(clk),
        .rs1Addr(rs1Addr_id),
        .rs2Addr(rs2Addr_id),
        .WriteAddr(rdAddr_wb),
        .RegWrite(RegWrite_wb),
        .WriteData(RegWriteData_wb),
		
        .rs1Data(rs1Data_id),
        .rs2Data(rs2Data_id)
    );
	// 分支检测
	wire SB_type;
	assign SB_type=(Instruction_id[6:0]==7'b1100011);
	wire [2:0] funct3_id;
	assign funct3_id=Instruction_id[14:12];
	BranchTest BranchTest_id(
        .rs1Data(rs1Data_id),
        .rs2Data(rs2Data_id),
        .SB_type(SB_type),
        .funct3(funct3_id),
		
        .Branch(Branch)
    );
	//冒险检测
	assign Stall=((rdAddr_ex==rs1Addr_id)||(rdAddr_ex==rs2Addr_id))&&MemRead_ex;
    assign IFWrite=~Stall;
	
	//跳转判断
	mux_2to1 #(.n(32)) mux_JALR_id(.out(JumpAddr), .in0(PC_id+offset_id), .in1(rs1Data_id+offset_id), .addr(JALR));
endmodule
