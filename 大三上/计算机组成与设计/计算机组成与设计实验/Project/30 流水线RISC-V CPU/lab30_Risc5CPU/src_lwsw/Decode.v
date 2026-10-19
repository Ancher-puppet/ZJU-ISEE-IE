//******************************************************************************
// //
// Decode.v
//******************************************************************************

module Decode(   
	// Outputs
	MemtoReg, RegWrite, MemWrite, MemRead,ALUCode,ALUSrcA,ALUSrcB,Jump,JALR,Imm,offset,Load_funct3,Store_funct3,
	// Inputs
    Instruction);
	input [31:0]	Instruction;	// current instruction
	output		   MemtoReg;		// use memory output as data to write into register
	output		   RegWrite;		// enable writing back to the register
	output		   MemWrite;		// write to memory
	output         MemRead;
	output [3:0]   ALUCode;         // ALU operation select
	output      	ALUSrcA;
	output [1:0]   ALUSrcB;
	output         Jump;
	output         JALR;
	output[31:0]   Imm,offset;
	output [2:0]   Load_funct3;
	output [2:0]   Store_funct3;
	
//******************************************************************************
//  instruction type decode
//******************************************************************************
	parameter  R_type_op=   7'b0110011;
	parameter  I_type_op=   7'b0010011;
	parameter  SB_type_op=  7'b1100011;
	parameter  LW_op=       7'b0000011;
	parameter  JALR_op=     7'b1100111;
	parameter  SW_op=       7'b0100011;
	parameter  LUI_op=      7'b0110111;
	parameter  AUIPC_op=    7'b0010111;	
	parameter  JAL_op=      7'b1101111;	
//
  //
   parameter  ADD_funct3 =     3'b000 ;
   parameter  SUB_funct3 =     3'b000 ;
   parameter  SLL_funct3 =     3'b001 ;
   parameter  SLT_funct3 =     3'b010 ;
   parameter  SLTU_funct3 =    3'b011 ;
   parameter  XOR_funct3 =     3'b100 ;
   parameter  SRL_funct3 =     3'b101 ;
   parameter  SRA_funct3 =     3'b101 ;
   parameter  OR_funct3 =      3'b110 ;
   parameter  AND_funct3 =     3'b111;
   //
   parameter  ADDI_funct3 =     3'b000 ;
   parameter  SLLI_funct3 =     3'b001 ;
   parameter  SLTI_funct3 =     3'b010 ;
   parameter  SLTIU_funct3 =    3'b011 ;
   parameter  XORI_funct3 =     3'b100 ;
   parameter  SRLI_funct3 =     3'b101 ;
   parameter  SRAI_funct3 =     3'b101 ;
   parameter  ORI_funct3 =      3'b101 ;
   parameter  ANDI_funct3 =     3'b111;
   
   parameter  LB_funct3   =     3'b000; // lb (Load Byte, Sign-extend)
   parameter  LH_funct3   =     3'b001; //lh (Load Half, Sign-extend)
   parameter  LW_funct3   =     3'b010; //lw (Load Word)
   parameter  LBU_funct3  =     3'b100; //lbu (Load Byte, Zero-extend)
   parameter  LHU_funct3  =     3'b101; //lhu (Load Half, Zero-extend)
   
   parameter  SB_funct3   =     3'b000; //sb (Store Byte)
   parameter  SH_funct3   =     3'b001; //sh (Store Half)
   parameter  SW_funct3   =     3'b010; //sw (Store Word) - 已有
   //
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

//******************************************************************************
// instruction field
//******************************************************************************
	wire [6:0]		op;
	wire  	 	    funct6_7;
	wire [2:0]		funct3;
	assign op			= Instruction[6:0];
	assign funct6_7		= Instruction[30];
 	assign funct3		= Instruction[14:12];
	assign Load_funct3  = funct3;
	assign Store_funct3 = funct3;
	
	//指令类型
	wire R_type, I_type, SB_type, LW, SW, LUI, AUIPC, JAL;
	assign R_type = (op == R_type_op);
	assign I_type = (op == I_type_op);
	assign SB_type = (op == SB_type_op);
	assign LW = (op == LW_op);
	assign JALR = (op == JALR_op);
	assign SW = (op == SW_op);
	assign LUI = (op == LUI_op);
	assign AUIPC = (op == AUIPC_op);
	assign JAL = (op == JAL_op);
	
	//指令部分操作
	
	//只有LW读取存储器，并写回数据
	assign MemtoReg = LW;
	assign MemRead = LW;
	
	//只有SW写入存储器
	assign MemWrite = SW;
	
	//需要回写的指令
	assign RegWrite = R_type || I_type || LW || JALR || LUI || AUIPC || JAL;
	
	//无条件分支指令
	assign Jump = JAL || JALR;
	
	//操作数A和B的选择
	// A:rs or pc
	assign ALUSrcA = JALR || JAL || AUIPC;
	// B:rs or imm or 4
	assign ALUSrcB[1]=JAL || JALR;
	assign ALUSrcB[0]=~(R_type || JAL || JALR);
	
	//ALUCode
	reg [3:0] ALUCode_temp;
	always @(*) begin
	  casez ({R_type,I_type,LUI,funct3,funct6_7})
		  7'b100_000_0: ALUCode_temp = 4'd0; //加
		  7'b100_000_1: ALUCode_temp = 4'd1; //减
		  7'b100_001_0: ALUCode_temp = 4'd6; //左移
		  7'b100_010_0: ALUCode_temp = 4'd9; //小于
		  7'b100_011_0: ALUCode_temp = 4'd10; //无符号小于
		  7'b100_100_0: ALUCode_temp = 4'd4; //异或
		  7'b100_101_0: ALUCode_temp = 4'd7; //右移
		  7'b100_101_1: ALUCode_temp = 4'd8; //算术右移
		  7'b100_110_0: ALUCode_temp = 4'd5; //或
		  7'b100_111_0: ALUCode_temp = 4'd3; //与
		  7'b010_000_?: ALUCode_temp = 4'd0; //立即数加
		  7'b010_001_?: ALUCode_temp = 4'd6; //立即数左移
		  7'b010_010_?: ALUCode_temp = 4'd9; //立即数小于
		  7'b010_011_?: ALUCode_temp = 4'd10; //立即数无符号小于
		  7'b010_100_?: ALUCode_temp = 4'd4; //立即数异或
		  7'b010_101_0: ALUCode_temp = 4'd7; //立即数右移
		  7'b010_101_1: ALUCode_temp = 4'd8; //立即数算术右移
		  7'b010_110_?: ALUCode_temp = 4'd5; //立即数或
		  7'b010_111_?: ALUCode_temp = 4'd3; //立即数与
		  7'b001_???_?: ALUCode_temp = 4'd2; //送数
		  default: ALUCode_temp = 4'd0; //其他为加
	  endcase
	end
	//输出ALUCode
	assign ALUCode = ALUCode_temp;

	//立即数产生
	wire Shift;
	assign Shift=(funct3==1)||(funct3==5);
	reg [31:0] Imm_temp;
	//Imm 需要拓展位对齐运算
	always @(*) begin
		if (I_type==1 && Shift==1)begin
		  Imm_temp = {27'd0, Instruction[24:20]};
		end
		else if (I_type==1 && Shift==0)begin
		  Imm_temp = {{20{Instruction[31]}}, Instruction[31:20]};
		end
		else if (LW==1) begin
		  Imm_temp = {{20{Instruction[31]}}, Instruction[31:20]};
		end
		else if (SW==1)begin
		  Imm_temp = {{20{Instruction[31]}}, Instruction[31:25], Instruction[11:7]}; 
		end
		else if (LUI==1)begin
		  Imm_temp = {Instruction[31:12], 12'd0}; 
		end
		else if (AUIPC==1)begin
		  Imm_temp = {Instruction[31:12], 12'd0}; 
		end
		else begin
		  Imm_temp = 32'b0;//其他
		end
	end
	//输出Immt
	assign Imm=Imm_temp;
	
	//offset
	reg [31:0] offset_temp;
	always @(*) begin
		if (JALR==1) begin
		  offset_temp = {{20{Instruction[31]}}, Instruction[31:20]};
		end
		else if (JAL==1) begin
		  offset_temp = {{11{Instruction[31]}}, Instruction[31], Instruction[19:12], Instruction[20], Instruction[30:21], 1'b0};
		end
		else if (SB_type==1) begin
		  offset_temp = {{19{Instruction[31]}}, Instruction[31], Instruction[7], Instruction[30:25], Instruction[11:8], 1'b0};
		end
		else begin
		  offset_temp = 32'b0;//default
		end
	end
	
	//输出offset
	assign offset=offset_temp;
	 
endmodule