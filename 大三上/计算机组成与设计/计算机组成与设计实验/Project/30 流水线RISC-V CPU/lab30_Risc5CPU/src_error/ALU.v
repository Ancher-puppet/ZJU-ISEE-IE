//******************************************************************************
// MIPS verilog model
//
// ALU.v
//******************************************************************************

module ALU (
	// Outputs
	   ALUResult,
	// Inputs
	   ALUCode, A, B);
	input [3:0]	ALUCode;				// Operation select
	input [31:0]	A, B;
	output [31:0]	ALUResult;
	
// Decoded ALU operation select (ALUsel) signals
   parameter	 alu_add=  4'b0000;
   parameter	 alu_sub=  4'b0001;
   parameter	 alu_lui=  4'b0010;
   parameter	 alu_and=  4'b0011;
   parameter	 alu_xor=  4'b0100;
   parameter	 alu_or =  4'b0101;
   parameter 	 alu_sll=  4'b0110;
   parameter	 alu_srl=  4'b0111;
   parameter	 alu_sra=  4'b1000;
   parameter	 alu_slt=  4'b1001;
   parameter	 alu_sltu= 4'b1010; 	

	//除加法外均处于减法状态，低电平加法
	wire Binvert;
	assign Binvert=~(ALUCode==0);
	//d0_d1 加减
	wire [31:0] d0_d1;
	adder_32bits adder_32bits_ALU (
      .a(A),
      .b({32{Binvert}} ^ B),
      .ci(Binvert),
      .s(d0_d1),
      .co()
   );
   //d2 B的值
   wire [31:0] d2;
   assign d2=B;
   //d3 与门
   wire [31:0] d3;
   assign d3=A&B;
   //d4 异或门
   wire [31:0] d4;
   assign d4=A^B;
   //d5 或门
   wire [31:0] d5;
   assign d5=A|B;
   
   //d6 左移
   wire [31:0] d6;
   //A最多移动32位，只需要B的低五位
   assign d6=A<<B[4:0];
   //d7 右移
   wire [31:0] d7;
   assign d7=A>>B[4:0];
   
   //d8 算术右移
   wire [31:0] d8;
   reg signed [31:0] A_reg;
   always @(*) begin A_reg=A; end
   assign d8=A_reg>>>B[4:0];
   
   //d9 有符号小于 slt
   wire [31:0] d9;
   assign d9=A[31] && (~B[31]) || (A[31]~^B[31]) && d0_d1[31];
   //d10 无符号小于 sltu
   wire [31:0] d10;
   assign d10=(~A[31]) && B[31] || (A[31]~^B[31]) && d0_d1[31];
   
	reg [31:0] ALU_out;
	always @(*) begin
	  case (ALUCode)
		  alu_add: ALU_out=d0_d1;
		  alu_sub: ALU_out=d0_d1;
		  alu_lui: ALU_out=d2;
		  alu_and: ALU_out=d3;
		  alu_xor: ALU_out=d4;
		  alu_or: ALU_out=d5;
		  alu_sll: ALU_out=d6;
		  alu_srl: ALU_out=d7;
		  alu_sra: ALU_out=d8;
		  alu_slt: ALU_out=d9;
		  alu_sltu: ALU_out=d10;
		  default: ALU_out=d0_d1 ; //其他为加
	  endcase
	end
	
	assign ALUResult=ALU_out;
	

endmodule