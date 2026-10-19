`timescale 1ns / 1ps
`include "IF.v"
`include "ID.v"
`include "EX.v"
`include "MEM.v"
`include "PipelineReg.v"
//////////////////////////////////////////////////////////////////////////////////
// Company: zju
// Engineer: qmj
//////////////////////////////////////////////////////////////////////////////////
module Risc5CPU(clk, reset, JumpFlag, Instruction_id, ALU_A, 
                     ALU_B, ALUResult_ex, PC, MemDout_mem,Stall,Imm_id_test,Imm_ex_test,ALUSrcB_ex_test);
    input clk;
    input reset;//PC寄存器的复位信号
    output[1:0] JumpFlag;
    output [31:0] Instruction_id;
    output [31:0] ALU_A;
    output [31:0] ALU_B;
    output [31:0] ALUResult_ex;
    output [31:0] PC;
    output [31:0] MemDout_mem;
    output Stall;



    //测试output
    output [31:0]Imm_id_test,Imm_ex_test;
    output [1:0]ALUSrcB_ex_test;


    //IF模块
    wire Branch,Jump,IFWrite,IF_flush;
    wire [31:0] JumpAddr,Instruction_if;
    assign JumpFlag[1]=Jump;
    assign JumpFlag[0]=Branch;
    // wire [31:0] PC;//已经在顶层定义

    IF1 IF1_ints(
        .clk(clk),
        .reset(reset),
        .Branch(Branch),
        .Jump(Jump),
        .IFWrite(IFWrite),
        .JumpAddr(JumpAddr),
        .Instruction_if(Instruction_if),
        .PC(PC),
        .IF_flush(IF_flush)
    );

    //IFID寄存器
    wire [31:0] PC_id;
    // wire [31:0] Instruction_id;//已经在顶层定义
    IF_ID IF_ID_ints(
        .clk(clk),
        .reset(IF_flush),
        .EN(IFWrite),
        .Instruction_if(Instruction_if),
        .PC_if(PC),
        .Instruction_id(Instruction_id),
        .PC_id(PC_id)
    );


    //ID模块
    //输入信号
    wire RegWrite_wb;
    wire [4:0] rdAddr_wb;
    wire [31:0] RegWriteData_wb;
    wire MemRead_ex;
    wire [4:0] rdAddr_ex;
    //输出信号
    wire MemtoReg_id;
    wire RegWrite_id;
    wire MemWrite_id;
    wire MemRead_id;
    wire [3:0] ALUCode_id;
    wire ALUSrcA_id;
    wire [1:0]ALUSrcB_id;
    // wire Stall;//已经在顶层定义
    wire [31:0] Imm_id;
    wire [31:0] rs1Data_id;
    wire [31:0] rs2Data_id;
    wire[4:0] rs1Addr_id,rs2Addr_id,rdAddr_id;
    //拓展lhu等指令需要额外的控制信号
    wire [2:0] LWCode_id;
    wire [1:0] SWCode_id;

    ID ID_inst(
        .clk(clk),
        .Instruction_id(Instruction_id),
        .PC_id(PC_id),
        .RegWrite_wb(RegWrite_wb),
        .rdAddr_wb(rdAddr_wb),
        .RegWriteData_wb(RegWriteData_wb),
        .MemRead_ex(MemRead_ex),
        .rdAddr_ex(rdAddr_ex),
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
        .LWCode_id(LWCode_id),
        .SWCode_id(SWCode_id)
    );

    //IDEX寄存器
    wire [31:0] PC_ex;
    wire [31:0] rs1Data_ex;
    wire [31:0] rs2Data_ex;
    wire [31:0] Imm_ex;
    // wire [4:0] rdAddr_ex;//已经在ID模块定义
    wire [4:0] rs1Addr_ex;
    wire [4:0] rs2Addr_ex;
    wire [3:0] ALUCode_ex;
    wire ALUSrcA_ex;
    wire [1:0] ALUSrcB_ex;
    // wire MemRead_ex;//已经在ID模块定义
    wire MemWrite_ex;
    wire RegWrite_ex;
    wire MemtoReg_ex;
    //拓展lhu等指令需要额外的控制信号
    wire [2:0] LWCode_ex;
    wire [1:0] SWCode_ex;

    ID_EX ID_EX_inst(
        .clk(clk),
        .reset(reset),
        .PC_id(PC_id),
        .rs1Data_id(rs1Data_id),
        .rs2Data_id(rs2Data_id),
        .Imm_id(Imm_id),
        .rdAddr_id(rdAddr_id),
        .rs1Addr_id(rs1Addr_id),
        .rs2Addr_id(rs2Addr_id),
        .ALUCode_id(ALUCode_id),
        .ALUSrcA_id(ALUSrcA_id),
        .ALUSrcB_id(ALUSrcB_id),
        .MemRead_id(MemRead_id),
        .MemWrite_id(MemWrite_id),
        .RegWrite_id(RegWrite_id),
        .MemtoReg_id(MemtoReg_id),
        .LWCode_id(LWCode_id),
        .SWCode_id(SWCode_id),
        .PC_ex(PC_ex),
        .rs1Data_ex(rs1Data_ex),
        .rs2Data_ex(rs2Data_ex),
        .Imm_ex(Imm_ex),
        .rdAddr_ex(rdAddr_ex),
        .rs1Addr_ex(rs1Addr_ex),
        .rs2Addr_ex(rs2Addr_ex),
        .ALUCode_ex(ALUCode_ex),
        .ALUSrcA_ex(ALUSrcA_ex),
        .ALUSrcB_ex(ALUSrcB_ex),
        .MemRead_ex(MemRead_ex),
        .MemWrite_ex(MemWrite_ex),
        .RegWrite_ex(RegWrite_ex),
        .MemtoReg_ex(MemtoReg_ex),
        .LWCode_ex(LWCode_ex),
        .SWCode_ex(SWCode_ex)
    );

    //EX模块
    // wire [31:0] ALUResult_ex;//已经在顶层定义
    wire [31:0] MemWriteData_ex;
    // wire [31:0] ALU_A;//已经在顶层定义
    // wire [31:0] ALU_B;//已经在顶层定义

    // wire [31:0] RegWriteData_wb;//已经在ID模块定义
    wire [31:0] ALUResult_mem;
    wire [4:0] rdAddr_mem;
    // wire [4:0] rdAddr_wb;//已经在ID模块定义
    wire RegWrite_mem;
    // wire RegWrite_wb;//已经在ID模块定义

    EX EX_inst(
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
        .ALUResult_ex(ALUResult_ex),
        .MemWriteData_ex(MemWriteData_ex),
        .ALU_A(ALU_A),
        .ALU_B(ALU_B)
    );

    //EXMEM寄存器
    wire MemWrite_mem;
    // wire RegWrite_mem;//已经在EX模块定义
    wire MemtoReg_mem;
    // wire [31:0] ALUResult_mem;//已经在EX模块定义
    wire [31:0] MemWriteData_mem;
    // wire [4:0] rdAddr_mem;//已经在EX模块定义
    //拓展lhu等指令需要额外的控制信号
    wire [2:0] LWCode_mem;
    wire [1:0] SWCode_mem;

    EX_MEM EX_MEM_inst(
        .clk(clk),
        .MemWrite_ex(MemWrite_ex),
        .RegWrite_ex(RegWrite_ex),
        .MemtoReg_ex(MemtoReg_ex),
        .ALUResult_ex(ALUResult_ex),
        .MemWriteData_ex(MemWriteData_ex),
        .rdAddr_ex(rdAddr_ex),
        .LWCode_ex(LWCode_ex),
        .SWCode_ex(SWCode_ex),
        .MemWrite_mem(MemWrite_mem),
        .RegWrite_mem(RegWrite_mem),
        .MemtoReg_mem(MemtoReg_mem),
        .ALUResult_mem(ALUResult_mem),
        .MemWriteData_mem(MemWriteData_mem),
        .rdAddr_mem(rdAddr_mem),
        .LWCode_mem(LWCode_mem),
        .SWCode_mem(SWCode_mem)
    );

    //MEM模块
    wire [31:0] MemDout_mem;
    MEM MEM_inst(
        .ALUResult_mem(ALUResult_mem),
        .MemWriteData_mem(MemWriteData_mem),
        .clk(clk),
        .MemWrite_mem(MemWrite_mem),
        .LWCode_mem(LWCode_mem),
        .SWCode_mem(SWCode_mem),
        .MemDout_mem(MemDout_mem)
    );


    //MEMWB寄存器
    // wire RegWrite_wb;//已经在ID模块定义
    wire MemtoReg_wb;
    wire [31:0] ALUResult_wb;
    wire [31:0 ]MemDout_wb;
    // wire [4:0] rdAddr_wb;//已经在ID模块定义

    MEM_WB MEM_WB_inst(
        .clk(clk),
        .RegWrite_mem(RegWrite_mem),
        .MemtoReg_mem(MemtoReg_mem),
        .ALUResult_mem(ALUResult_mem),
        .MemDout_mem(MemDout_mem),
        .rdAddr_mem(rdAddr_mem),
        .RegWrite_wb(RegWrite_wb),
        .MemtoReg_wb(MemtoReg_wb),
        .ALUResult_wb(ALUResult_wb),
        .MemDout_wb(MemDout_wb),
        .rdAddr_wb(rdAddr_wb)
    );

    //WB模块
    assign RegWriteData_wb=MemtoReg_wb?MemDout_wb:ALUResult_wb;


    //测试信号赋值
    assign Imm_id_test=Imm_id;
    assign ALUSrcB_ex_test=ALUSrcB_ex;
    assign Imm_ex_test=Imm_ex;
endmodule
