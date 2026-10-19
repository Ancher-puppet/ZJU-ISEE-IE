//IF/ID Reg
module IF_ID(clk,EN,R,PC_if,Instruction_if,PC_id,Instruction_id);
	//input
	input clk;
	input EN; //使能端
	input R;  //阻塞与清空
	input [31:0] PC_if;
	input [31:0] Instruction_if;
	
	//output
	output reg [31:0] PC_id;
	output reg [31:0] Instruction_id;

    always @(posedge clk) begin
        if (R) begin
            Instruction_id <= 32'b0; 
            PC_id <= 32'b0;          
        end 
		else if (EN !== 1'b0) begin
            Instruction_id <= Instruction_if; 
            PC_id <= PC_if;                   
        end 
		else begin
            Instruction_id <= Instruction_id; // 保持
            PC_id <= PC_id;                  
        end
    end

endmodule

//ID/EX Reg
module ID_EX(clk,R,MemtoReg_id,RegWrite_id,MemWrite_id,MemRead_id,ALUCode_id,ALUSrcA_id,ALUSrcB_id,PC_id,Imm_id,
			rdAddr_id,rs1Addr_id,rs2Addr_id,rs1Data_id,rs2Data_id,MemtoReg_ex,RegWrite_ex,MemWrite_ex,MemRead_ex,
			ALUCode_ex,ALUSrcA_ex,ALUSrcB_ex,PC_ex,Imm_ex,rdAddr_ex,rs1Addr_ex,rs2Addr_ex,rs1Data_ex,rs2Data_ex);

	//input
	input clk;
	input R;//冒险检测

	input MemtoReg_id;//Decode信号输出
	input RegWrite_id;
	input MemWrite_id;
	input MemRead_id;
	input [3:0] ALUCode_id;
	input ALUSrcA_id;
	input [1:0] ALUSrcB_id;
	
	input [31:0] PC_id;//PC
	
	input [31:0] Imm_id;//Imm
	
	input [4:0] rdAddr_id;//寄存器地址
	input [4:0] rs1Addr_id;
	input [4:0] rs2Addr_id;
	
	input [31:0] rs1Data_id; //数据
    input [31:0] rs2Data_id;
	
	//output
	output reg MemtoReg_ex;//WB
	output reg RegWrite_ex;
	output reg MemWrite_ex;//MEM
	output reg MemRead_ex;
	output reg [3:0] ALUCode_ex;//EX
	output reg ALUSrcA_ex;
	output reg [1:0] ALUSrcB_ex;
	
	output reg [31:0] PC_ex;//PC
	
	output reg [31:0] Imm_ex;//Imm
	output reg [4:0] rdAddr_ex;//寄存器地址
	output reg [4:0] rs1Addr_ex;
	output reg [4:0] rs2Addr_ex;
	
	output reg [31:0] rs1Data_ex; //数据
    output reg [31:0] rs2Data_ex;
	
    always @(posedge clk) begin
        if (R) begin//复位
            MemtoReg_ex <= 1'b0;  
			RegWrite_ex <= 1'b0;
			MemWrite_ex <= 1'b0; 
			MemRead_ex <= 1'b0; 
			
			ALUSrcA_ex <= 1'b0;
			ALUSrcB_ex <= 2'b0;
			ALUCode_ex <= 4'b0;
			
			PC_ex <= 32'b0; 
			Imm_ex <= 32'b0;
			
			rdAddr_ex <= 5'b0;       
            rs1Addr_ex <= 5'b0;      
            rs2Addr_ex <= 5'b0;
			rs1Data_ex <= 32'b0;     
            rs2Data_ex <= 32'b0; 
        end 
		else begin
            MemtoReg_ex <= MemtoReg_id;  
			RegWrite_ex <= RegWrite_id;
			MemWrite_ex <= MemWrite_id; 
			MemRead_ex <= MemRead_id; 
			
			ALUSrcA_ex <= ALUSrcA_id;
			ALUSrcB_ex <= ALUSrcB_id;
			ALUCode_ex <= ALUCode_id;
			
			PC_ex <= PC_id; 
			Imm_ex <= Imm_id;
			
			rdAddr_ex <= rdAddr_id;       
            rs1Addr_ex <= rs1Addr_id;      
            rs2Addr_ex <= rs2Addr_id;
			rs1Data_ex <= rs1Data_id;     
            rs2Data_ex <= rs2Data_id; 
        end
    end
endmodule

//EX/MEM Reg
module EX_MEM(clk,MemtoReg_ex,RegWrite_ex,MemWrite_ex,ALUResult_ex,MemWriteData_ex,rdAddr_ex,MemtoReg_mem,
			RegWrite_mem,MemWrite_mem,ALUResult_mem,MemWriteData_mem,rdAddr_mem);
	//input
	input clk;
	input MemtoReg_ex;//WB
	input RegWrite_ex;
	input MemWrite_ex;//MEM
	input [31:0] ALUResult_ex;//ALU
	input [31:0] MemWriteData_ex;
	input [4:0] rdAddr_ex;
	
	//output
	output reg MemtoReg_mem;//WB
	output reg RegWrite_mem;
	output reg MemWrite_mem;//MEM
	output reg [31:0] ALUResult_mem;
	output reg [31:0] MemWriteData_mem;
	output reg [4:0] rdAddr_mem;

    always @(posedge clk) begin    
        MemtoReg_mem <= MemtoReg_ex;//WB
		RegWrite_mem <= RegWrite_ex;
        MemWrite_mem <= MemWrite_ex;//MEM	
        ALUResult_mem <= ALUResult_ex;    
        MemWriteData_mem <= MemWriteData_ex; 
        rdAddr_mem <= rdAddr_ex;        
    end

endmodule

//MEM/WB Reg
module MEM_WB(clk,MemtoReg_mem,RegWrite_mem,ALUResult_mem,MemDout_mem,rdAddr_mem,MemtoReg_wb,RegWrite_wb,
				ALUResult_wb,MemDout_wb,rdAddr_wb);
				
	input clk;
	input MemtoReg_mem;//WB
	input RegWrite_mem;
	input [31:0] ALUResult_mem;
	input [31:0] MemDout_mem;//MEM
	input [4:0] rdAddr_mem;
	
	//output
	output reg MemtoReg_wb;//WB
	output reg RegWrite_wb;
	output reg [31:0] ALUResult_wb;
	output reg [31:0] MemDout_wb;
	output reg [4:0] rdAddr_wb;

    always @(posedge clk) begin
        MemtoReg_wb <= MemtoReg_mem;
		RegWrite_wb <= RegWrite_mem;		
        ALUResult_wb <= ALUResult_mem;     
        MemDout_wb <= MemDout_mem;         
        rdAddr_wb <= rdAddr_mem;           
    end
	
endmodule