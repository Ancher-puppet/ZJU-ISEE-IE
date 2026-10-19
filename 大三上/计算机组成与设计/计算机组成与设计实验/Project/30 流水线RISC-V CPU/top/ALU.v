//******************************************************************************
// MIPS verilog model
//
// ALU.v
//******************************************************************************
`include "adder_32bits.v"

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

   wire Binvert;
   wire [31:0] b,sum,d3,d4,d5,d6,d7,d8,d9,d10;
   reg signed [31:0] A_reg;
   reg [31:0]out;
   //加减控制  
   assign Binvert = ~(ALUCode==0);
   //位拓展
   assign b = {32{Binvert}} ^ B;
   //加法器
   adder_32bits adder_32bits_ALUinst (
      .a(A),
      .b(b),
      .ci(Binvert),
      .s(sum),
      .co()
   );
   //d3 and
   assign d3=A&B;
   //d4 xor
   assign d4=A^B;
   //d5 or
   assign d5=A|B;
   //d6 sll
   assign d6=A<<B[4:0];
   //d7 srl
   assign d7=A>>B[4:0];
   //d8 sra
   always @(*) begin A_reg=A; end
   assign d8=A_reg>>>B[4:0];
   //d9 slt
   assign d9=A[31] && (~B[31]) || (A[31]~^B[31]) && sum[31];
   //d10 sltu
   assign d10=(~A[31]) && B[31] || (A[31]~^B[31]) && sum[31];

   //多路选择器
   always @(*) begin
      if (ALUCode==alu_add) begin
         out=sum;
      end else if (ALUCode==alu_sub) begin
         out=sum;
      end else if (ALUCode==alu_lui) begin
         out=B;
      end else if (ALUCode==alu_and) begin
         out=d3;
      end else if (ALUCode==alu_xor) begin
         out=d4;
      end else if (ALUCode==alu_or) begin
         out=d5;
      end else if (ALUCode==alu_sll) begin
         out=d6;
      end else if (ALUCode==alu_srl) begin
         out=d7;
      end else if (ALUCode==alu_sra) begin
         out=d8;
      end else if (ALUCode==alu_slt) begin
         out=d9;
      end else if (ALUCode==alu_sltu) begin
         out=d10;
      end
      else begin
         out=sum;
      end
   end
   assign ALUResult=out;

endmodule