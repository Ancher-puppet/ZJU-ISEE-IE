`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: zju
// Engineer: qmj
//////////////////////////////////////////////////////////////////////////////////
module Risc5CPU(clk, reset, JumpFlag, Instruction_id, ALU_A, 
                     ALU_B, ALUResult_ex, PC, MemDout_mem,Stall);
    input clk;
    input reset;
    output[1:0] JumpFlag; //跳转标志，由Jump和Branch拼接
    output [31:0] Instruction_id;
    output [31:0] ALU_A;
    output [31:0] ALU_B;
    output [31:0] ALUResult_ex;
    output [31:0] PC;
    output [31:0] MemDout_mem;
    output Stall;

	//IF阶段
	wire Branch,Jump,IFWrite,IF_flush;
	assign JumpFlag[0]=Branch;
	assign JumpFlag[1]=Jump;
	wire [31:0] JumpAddr,Instruction_if;
	IF1 IF1_inst(
		//input
		.clk(clk), 
		.reset(reset), 
		.Branch(Branch),
		.Jump(Jump), 
		.IFWrite(IFWrite), 
		.JumpAddr(JumpAddr),
		
		//output
		.Instruction_if(Instruction_if),
		.PC(PC),
		.IF_flush(IF_flush)
	);
	//IF/ID
	wire [31:0] PC_id;
	IF_ID IF_ID_inst(
		//input
		.clk(clk),
		.EN(IFWrite),
		.R(IF_flush),
		.PC_if(PC),
		.Instruction_if(Instruction_if),
		
		//output
		.PC_id(PC_id),
		.Instruction_id(Instruction_id)
	);
	//ID阶段
	wire RegWrite_wb;
	wire [4:0] rdAddr_wb;
    wire [31:0] RegWriteData_wb;
    wire MemRead_ex;
    wire [4:0] rdAddr_ex;
	
	wire MemtoReg_id;
    wire RegWrite_id;
    wire MemWrite_id;
    wire MemRead_id;
    wire [3:0] ALUCode_id;
    wire ALUSrcA_id;
    wire [1:0]ALUSrcB_id;
    wire [31:0] Imm_id;
    wire [31:0] rs1Data_id,rs2Data_id;
    wire[4:0] rs1Addr_id,rs2Addr_id,rdAddr_id;
	
	wire [2:0] Load_funct3_id;
    wire [2:0] Store_funct3_id;
	ID ID_inst(
		//input
		.clk(clk),
		.Instruction_id(Instruction_id), 
		.PC_id(PC_id), 
		.RegWrite_wb(RegWrite_wb), 
		.rdAddr_wb(rdAddr_wb), 
		.RegWriteData_wb(RegWriteData_wb), 
		.MemRead_ex(MemRead_ex), 
        .rdAddr_ex(rdAddr_ex), 
		
		//output
		.MemtoReg_id(MemtoReg_id), 
		.RegWrite_id(RegWrite_id), 
		.MemWrite_id(MemWrite_id), 
		.MemRead_id(MemRead_id), 
		.ALUCode_id(ALUCode_id),		
		.ALUSrcA_id(ALUSrcA_id), 
		.ALUSrcB_id(ALUSrcB_id),
		.Stall(Stall), 
		.Branch(Branch), 
		.Jump(Jump), 
		.IFWrite(IFWrite),  
		.JumpAddr(JumpAddr), 
		.Imm_id(Imm_id),
		.rs1Data_id(rs1Data_id), 
		.rs2Data_id(rs2Data_id),
		.rs1Addr_id(rs1Addr_id),
		.rs2Addr_id(rs2Addr_id),
		.rdAddr_id(rdAddr_id),
		.Load_funct3_id(Load_funct3_id),
		.Store_funct3_id(Store_funct3_id)
	);
	
	//ID/EX
	wire MemtoReg_ex;
	wire RegWrite_ex;
	wire MemWrite_ex;
	wire [3:0] ALUCode_ex;
	wire ALUSrcA_ex;
    wire [1:0] ALUSrcB_ex;
	wire [31:0] PC_ex;
	wire [31:0] Imm_ex;
	wire [4:0] rs1Addr_ex;
    wire [4:0] rs2Addr_ex;
    wire [31:0] rs1Data_ex;
    wire [31:0] rs2Data_ex;
	
	wire [2:0] Load_funct3_ex;
    wire [2:0] Store_funct3_ex;
	ID_EX ID_EX_inst(
		//input
		.clk(clk),
		.R(Stall),
		.MemtoReg_id(MemtoReg_id),
		.RegWrite_id(RegWrite_id),
		.MemWrite_id(MemWrite_id),
		.MemRead_id(MemRead_id),
		.ALUCode_id(ALUCode_id),
		.ALUSrcA_id(ALUSrcA_id),
		.ALUSrcB_id(ALUSrcB_id),
		.PC_id(PC_id),
		.Imm_id(Imm_id),
		.rdAddr_id(rdAddr_id),
		.rs1Addr_id(rs1Addr_id),
		.rs2Addr_id(rs2Addr_id),
		.rs1Data_id(rs1Data_id),
		.rs2Data_id(rs2Data_id),
		.Load_funct3_id(Load_funct3_id),
		.Store_funct3_id(Store_funct3_id),
		
		//output
		.MemtoReg_ex(MemtoReg_ex),
		.RegWrite_ex(RegWrite_ex),
		.MemWrite_ex(MemWrite_ex),
		.MemRead_ex(MemRead_ex),
		.ALUCode_ex(ALUCode_ex),
		.ALUSrcA_ex(ALUSrcA_ex),
		.ALUSrcB_ex(ALUSrcB_ex),
		.PC_ex(PC_ex),
		.Imm_ex(Imm_ex),
		.rdAddr_ex(rdAddr_ex),
		.rs1Addr_ex(rs1Addr_ex),
		.rs2Addr_ex(rs2Addr_ex),
		.rs1Data_ex(rs1Data_ex),
		.rs2Data_ex(rs2Data_ex),
		.Load_funct3_ex(Load_funct3_ex),
		.Store_funct3_ex(Store_funct3_ex)
	);
	//EX阶段
    wire [31:0] MemWriteData_ex;
    wire [31:0] ALUResult_mem;
    wire [4:0] rdAddr_mem;
    wire RegWrite_mem;

    EX EX_inst(
		//input
        .ALUCode_ex(ALUCode_ex),
        .ALUSrcA_ex(ALUSrcA_ex),
        .ALUSrcB_ex(ALUSrcB_ex),
        .Imm_ex(Imm_ex),
        .rs1Addr_ex(rs1Addr_ex),
        .rs2Addr_ex(rs2Addr_ex),
        .rs1Data_ex(rs1Data_ex),
        .rs2Data_ex(rs2Data_ex),
        .PC_ex(PC_ex),
        .RegWriteData_wb(RegWriteData_wb),
        .ALUResult_mem(ALUResult_mem),
        .rdAddr_mem(rdAddr_mem),
        .rdAddr_wb(rdAddr_wb),
        .RegWrite_mem(RegWrite_mem),
        .RegWrite_wb(RegWrite_wb),

		//output
        .ALUResult_ex(ALUResult_ex),
        .MemWriteData_ex(MemWriteData_ex),
        .ALU_A(ALU_A),
		.ALU_B(ALU_B)
	);
	//EX/Mem
	wire MemtoReg_mem;
	wire MemWrite_mem;
	wire [31:0] MemWriteData_mem;
	wire [2:0] Load_funct3_mem;
    wire [2:0] Store_funct3_mem;
	EX_MEM EX_MEM_inst(
		//input
		.clk(clk),
		.MemtoReg_ex(MemtoReg_ex),
		.RegWrite_ex(RegWrite_ex),
		.MemWrite_ex(MemWrite_ex),
		.ALUResult_ex(ALUResult_ex),
		.MemWriteData_ex(MemWriteData_ex),
		.rdAddr_ex(rdAddr_ex),
		.Load_funct3_ex(Load_funct3_ex),
		.Store_funct3_ex(Store_funct3_ex),
		//output
		.MemtoReg_mem(MemtoReg_mem),
		.RegWrite_mem(RegWrite_mem),
		.MemWrite_mem(MemWrite_mem),
		.ALUResult_mem(ALUResult_mem),
		.MemWriteData_mem(MemWriteData_mem),
		.rdAddr_mem(rdAddr_mem),
		.Load_funct3_mem(Load_funct3_mem),
		.Store_funct3_mem(Store_funct3_mem)
	);
	//MEM
	reg [31:0] d_reg;
    //根据Store_funct3_mem选择写入数据
	always @(*) begin
	  case (Store_funct3_mem)
		  3'b000: d_reg = {24'b0, MemWriteData_mem[7:0]};//3'b000; sb
		  3'b001: d_reg = {16'b0, MemWriteData_mem[15:0]};//3'b001;sh
		  3'b010: d_reg = MemWriteData_mem;//3'b010; sw
		  default: d_reg = MemWriteData_mem;//默认为sw
	  endcase
	end
	
	wire [31:0] MemDout_mem_wire;//暂存lw取出的数据，后续根据指令改变格式
    DataRAM DataRAM_inst(
        .a(ALUResult_mem[7:2]),
        .d(d_reg),
        .clk(clk),
        .we(MemWrite_mem),
        .spo(MemDout_mem_wire)
    );
	
	reg [31:0] MemDout_mem_reg;
	always @(*) begin
	  case (Load_funct3_mem)
		  3'b000: MemDout_mem_reg = {{24{MemDout_mem_wire[7]}}, MemDout_mem_wire[7:0]};//3'b000; lb
		  3'b001: MemDout_mem_reg = {{16{MemDout_mem_wire[15]}}, MemDout_mem_wire[15:0]};//3'b001; lh 
		  3'b010: MemDout_mem_reg = MemDout_mem_wire;//3'b010; lw
		  3'b100: MemDout_mem_reg = {24'b0, MemDout_mem_wire[7:0]};//3'b100; lbu
		  3'b101: MemDout_mem_reg = {16'b0, MemDout_mem_wire[15:0]};//3'b101;lhu
		  default: MemDout_mem_reg = MemDout_mem_wire; //默认为lw
	  endcase
	end
	
    assign MemDout_mem = MemDout_mem_reg;
	//MEM/WB
	wire MemtoReg_wb;
    wire [31:0] ALUResult_wb;
    wire [31:0 ]MemDout_wb;
	MEM_WB MEM_WB_inst(
		//input
		.clk(clk),
		.MemtoReg_mem(MemtoReg_mem),
		.RegWrite_mem(RegWrite_mem),
		.ALUResult_mem(ALUResult_mem),
		.MemDout_mem(MemDout_mem),
		.rdAddr_mem(rdAddr_mem),
		//output
		.MemtoReg_wb(MemtoReg_wb),
		.RegWrite_wb(RegWrite_wb),
		.ALUResult_wb(ALUResult_wb),
		.MemDout_wb(MemDout_wb),
		.rdAddr_wb(rdAddr_wb)
	);
	//WB
	mux_2to1 #(.n(32)) mux_WB(.out(RegWriteData_wb), .in0(ALUResult_wb), .in1(MemDout_wb), .addr(MemtoReg_wb));
	
endmodule
