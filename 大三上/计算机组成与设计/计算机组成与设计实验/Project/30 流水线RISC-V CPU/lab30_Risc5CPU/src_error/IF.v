`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:  zju
// Engineer: qmj
//////////////////////////////////////////////////////////////////////////////////
module IF1(clk, reset, Branch,Jump, IFWrite, JumpAddr,trap, trap_addr, mepc, is_mret,
			Instruction_if,PC,IF_flush);
    input clk;
    input reset;
    input Branch;
    input Jump;
    input IFWrite;
    input [31:0] JumpAddr;
	//新增
	input trap;
	input [31:0] trap_addr;
	input is_mret;
	input [31:0] mepc;
	
    output [31:0] Instruction_if;
    output [31:0] PC;
    output IF_flush;

	//指令指针寄存
	wire PCsource;
	assign PCsource=Jump || Branch;
	assign IF_flush=PCsource || trap || is_mret;
	wire [31:0] NextPC_if;
	assign NextPC_if = 
          (trap == 1) ? trap_addr :       // 1. 发生异常，跳到入口 (0x0004)
          (is_mret == 1) ? mepc :         // 2. 执行 mret，跳回断点
          (PCsource) ? JumpAddr :    // 3. 原有的分支/跳转
          (PC + 4);                  // 4. 顺序执行
	
	//处理PC，复位信号，写入信号
	reg [31:0] PC;
	always @(posedge clk) begin
        if (reset) begin
            PC <= 32'b0; 
        end else if (IFWrite) begin
            PC <= NextPC_if; 
        end else begin
            PC <= PC; //保持
        end
    end
	
	//读取指令存储器
	InstructionROM InstructionROM_if(
        .addr(PC[7:2]),
		
        .dout(Instruction_if)
    );
endmodule