`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Company: ZJU
// Engineer: tangyi
 ////////////////////////////////////////////////////////////////////////////////
module Decode_tb;

	// Inputs
	reg [31:0] Instruction;

	// Outputs
	wire MemtoReg;
	wire RegWrite;
	wire MemWrite;
	wire MemRead;
	wire [3:0] ALUCode;
	wire ALUSrcA;
	wire [1:0] ALUSrcB;
	wire Jump;
	wire JALR;
	wire [31:0] Imm,offset;
	wire [2:0] Load_funct3;
	wire [2:0] Store_funct3;

	// Instantiate the Unit Under Test (UUT)
	Decode uut (
		.MemtoReg(MemtoReg), 
		.RegWrite(RegWrite), 
		.MemWrite(MemWrite), 
		.MemRead(MemRead), 
		.ALUCode(ALUCode), 
		.ALUSrcA(ALUSrcA), 
		.ALUSrcB(ALUSrcB), 		
		.Jump(Jump), 
		.JALR(JALR),
		.Imm(Imm),
		.offset(offset), 
		.Load_funct3(Load_funct3),
		.Store_funct3(Store_funct3),
		
		.Instruction(Instruction)
	);

	initial begin
		// Initialize Inputs
		Instruction = 32'h00003f37;//lui  X30, 0x3000	
        
		// Add stimulus here		
		#200 Instruction = 32'h02000fe7;//jalr X31, later(X0)
		#200 Instruction = 32'h00001c63;//bne  X0, X0, end
		#200 Instruction = 32'h042f0293;//addi X5, X30, 42
		#200 Instruction = 32'h01f00333;//add  X6, X0, X31
		#200 Instruction  = 32'h406283b3;//sub  X7, X5, X6		
		#200 Instruction = 32'h0053ee33;//or	 X28, X7, X5		
		#200 Instruction = 32'hfc000ae3;//beq X0, X0, earlier
		
		#200 Instruction = 32'h001c2623;//sw  X28, 0C(X0)
		#200 Instruction = 32'h0010_0623 ;//sb  X1, 0C(X0)  (funct3=000)
		#200 Instruction = 32'h0020_1623 ;//sh  X2, 0C(X0)  (funct3=001)
		
		#200 Instruction = 32'h00432e83;//lw X29, 04(X6)
		#200 Instruction = 32'h0043_0183;//lb X3, 4(X6)
		#200 Instruction = 32'h0043_1203;//lh X4, 4(X6)
		#200 Instruction = 32'h0043_4503;//lbu X10, 4(X6)
		#200 Instruction = 32'h0043_5583;//lhu X11, 4(X6)
		
		#200 Instruction = 32'h002e9293;//sll X5, X29,2
		#200 Instruction = 32'h00733e33;//sltu X28, X6,X7
		#200 Instruction = 32'h0000f6f;//jal  X31, done
		
        #200 $stop;
	end
      
endmodule

