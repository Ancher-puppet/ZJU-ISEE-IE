//******************************************************************************
// //
// Decode.v
//******************************************************************************

module Decode(   
	// Outputs
	MemtoReg, RegWrite, MemWrite, MemRead,ALUCode,ALUSrcA,ALUSrcB,Jump,JALR,Imm,offset,LWCode,SWCode,
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
  //拓展lhu等指令需要额外的控制信号
  output[2:0]    LWCode;//000:lb 001:lh 010:lw 100:lbu 101:lhu
  output[1:0]    SWCode;//00:sb 01:sh 10:sw
	
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
	
  //
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
  //只有LW读取内存写回寄存器
  assign MemtoReg = LW;
  assign MemRead = LW;
  //只有SW写内存
  assign MemWrite = SW;

  //拓展lhu等指令需要额外的控制信号*****************************
  assign LWCode=funct3;
  assign SWCode=funct3[1:0];
  //******************************************************************************


  //需要写回的指令
  assign RegWrite = R_type || I_type || LW || JALR || LUI || AUIPC || JAL;
  //无条件跳转
  assign Jump = JAL || JALR;
  //ALU操作数
  assign ALUSrcA = JALR || JAL || AUIPC;
  assign ALUSrcB[1]=JAL || JALR;
  assign ALUSrcB[0]=~(R_type || JAL || JALR);
  //ALU操作码
  reg [3:0] ALUCode_temp;
  always @(*) begin
      casez ({R_type,I_type,LUI,funct3,funct6_7})
          7'b100_000_0: ALUCode_temp = 4'd0; //ADD
          7'b100_000_1: ALUCode_temp = 4'd1; //SUB
          7'b100_001_0: ALUCode_temp = 4'd6; //left shift
          7'b100_010_0: ALUCode_temp = 4'd9; //set signcompare less than
          7'b100_011_0: ALUCode_temp = 4'd10; //set unsigncompare less than
          7'b100_100_0: ALUCode_temp = 4'd4; //XOR
          7'b100_101_0: ALUCode_temp = 4'd7; //right shift
          7'b100_101_1: ALUCode_temp = 4'd8; //arithmetic right shift
          7'b100_110_0: ALUCode_temp = 4'd5; //OR
          7'b100_111_0: ALUCode_temp = 4'd3; //AND
          7'b010_000_?: ALUCode_temp = 4'd0; //ADDI
          7'b010_001_?: ALUCode_temp = 4'd6; //left shift immediate
          7'b010_010_?: ALUCode_temp = 4'd9; //set signcompare less than immediate
          7'b010_011_?: ALUCode_temp = 4'd10; //set unsigncompare less than immediate
          7'b010_100_?: ALUCode_temp = 4'd4; //XOR immediate
          7'b010_101_0: ALUCode_temp = 4'd7; //right shift immediate
          7'b010_101_1: ALUCode_temp = 4'd8; //arithmetic right shift immediate
          7'b010_110_?: ALUCode_temp = 4'd5; //OR immediate
          7'b010_111_?: ALUCode_temp = 4'd3; //AND immediate
          7'b001_???_?: ALUCode_temp = 4'd2; //ALUResult=B
          default: ALUCode_temp = 4'd0; //ADD
      endcase
  end
  assign ALUCode = ALUCode_temp;
  //立即数
  //TODO:要拓展lhu等指令需要修改立即数
  wire Shift;
  assign Shift=(funct3==3'b001)||(funct3==3'b101);
  reg [31:0] Imm_temp,offset_temp;
  //Imm
  always @(*) begin
    if (I_type==1 && Shift==1)begin
      Imm_temp = { 27'd0, Instruction[24:20] }; //shift
    end
    else if (I_type==1 && Shift==0)begin
      Imm_temp = { {20{Instruction[31]}}, Instruction[31:20] };//immediate
    end
    else if (LW==1) begin
      Imm_temp = { {20{Instruction[31]}}, Instruction[31:20] };//load
    end
    else if (SW==1)begin
      Imm_temp = { {20{Instruction[31]}}, Instruction[31:25], Instruction[11:7] }; //store
    end
    else if (LUI==1)begin
      Imm_temp = { Instruction[31:12], 12'd0 }; //LUI
    end
    else if (AUIPC==1)begin
      Imm_temp = { Instruction[31:12], 12'd0 }; //AUIPC
    end
    else begin
      Imm_temp = 32'b0;//default
    end
  end
  //offset
  always @(*) begin
    if (JALR==1) begin
      offset_temp = { {20{Instruction[31]}}, Instruction[31:20] };//JALR
    end
    else if (JAL==1) begin
      offset_temp = { {11{Instruction[31]}}, Instruction[31], Instruction[19:12], Instruction[20], Instruction[30:21], 1'b0 };//JAL
    end
    else if (SB_type==1) begin
      offset_temp = { {19{Instruction[31]}}, Instruction[31], Instruction[7], Instruction[30:25], Instruction[11:8], 1'b0 };//SB
    end
    else begin
      offset_temp = 32'b0;//default
    end
  end
  assign Imm=Imm_temp;
  assign offset=offset_temp;





	 
endmodule