`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:  zju
// Engineer: qmj
//////////////////////////////////////////////////////////////////////////////////
module IF1(clk, reset, Branch,Jump, IFWrite, JumpAddr,Instruction_if,PC,IF_flush);
    input clk;
    input reset;
    input Branch;
    input Jump;
    input IFWrite;
    input [31:0] JumpAddr;
    output [31:0] Instruction_if;
    output [31:0] PC;
    output IF_flush;

	//指令指针寄存
	wire PCsource;
	assign PCsource=Jump || Branch;
	assign IF_flush=PCsource;
	wire [31:0] NextPC_if;
	mux_2to1 #(.n(32)) mux_PC_if(.out(NextPC_if), .in0(PC + 32'h00000004), .in1(JumpAddr), .addr(PCsource));
	
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