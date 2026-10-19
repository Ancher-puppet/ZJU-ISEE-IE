`timescale 1ns / 1ps
`include "InstructionROM.v"
//////////////////////////////////////////////////////////////////////////////////
// Company:  zju
// Engineer: qmj
//////////////////////////////////////////////////////////////////////////////////
module IF1(clk, reset, Branch,Jump, IFWrite, JumpAddr,Instruction_if,PC,IF_flush);
    input clk;//系统时钟
    input reset;//系统复位信号，高电平有效
    input Branch;//条件分支指令的条件判断结果
    input Jump;//无条件分支指令的条件判断结果
    input IFWrite;//流水线阻塞信号
    input [31:0] JumpAddr;//分支地址
    output [31:0] Instruction_if;
    output [31:0] PC;
    output IF_flush;

    // PC寄存器
    reg [31:0] PC_in, PC_out;
    wire PCSoure;
    assign PCSoure = Jump || Branch;
    assign IF_flush=PCSoure;
    // 计算PC_in的值
    always @(*) begin
        if (PCSoure) begin
            PC_in = JumpAddr;
        end else begin
            PC_in = PC + 32'h00000004;
        end
    end
    // 在时钟上升沿时触发
    always @(posedge clk) begin
        if (reset) begin
            PC_out <= 32'b0; // 复位时将PC值重置为0
        end else if (IFWrite) begin
            PC_out <= PC_in; // 使能信号有效时更新PC值
        end else begin
            PC_out <= PC_out; // 使能信号无效时保持PC值不变
        end
    end
    assign PC = PC_out;
    //InstructionROM
    InstructionROM InstructionROM_ints(
        .addr(PC[7:2]),
        .dout(Instruction_if)
    );
endmodule

