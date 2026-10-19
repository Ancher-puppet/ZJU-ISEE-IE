`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: zju
// Engineer: qmj
//////////////////////////////////////////////////////////////////////////////////
module EX(ALUCode_ex, ALUSrcA_ex, ALUSrcB_ex,Imm_ex, rs1Addr_ex, rs2Addr_ex, rs1Data_ex, 
          rs2Data_ex, PC_ex, RegWriteData_wb, ALUResult_mem,rdAddr_mem, rdAddr_wb, 
		  RegWrite_mem, RegWrite_wb, ALUResult_ex, MemWriteData_ex, ALU_A, ALU_B);
    input [3:0] ALUCode_ex;
    input ALUSrcA_ex;
    input [1:0]ALUSrcB_ex;
    input [31:0] Imm_ex;
    input [4:0]  rs1Addr_ex;
    input [4:0]  rs2Addr_ex;
    input [31:0] rs1Data_ex;
    input [31:0] rs2Data_ex;
	input [31:0] PC_ex;
    input [31:0] RegWriteData_wb;
    input [31:0] ALUResult_mem;
	input [4:0]rdAddr_mem;
    input [4:0] rdAddr_wb;
    input RegWrite_mem;
    input RegWrite_wb;
	
    output [31:0] ALUResult_ex;
    output [31:0] MemWriteData_ex;
    output [31:0] ALU_A;
    output [31:0] ALU_B;

    //数据前推电路
    wire [1:0]ForwardA,ForwardB;
    assign ForwardA[0]=RegWrite_wb && (rdAddr_wb!=0) && (rdAddr_mem!=rs1Addr_ex) && (rdAddr_wb==rs1Addr_ex);
    assign ForwardA[1]=RegWrite_mem && (rdAddr_mem!=0) && (rdAddr_mem==rs1Addr_ex);
    assign ForwardB[0]=RegWrite_wb && (rdAddr_wb!=0) && (rdAddr_mem!=rs2Addr_ex) && (rdAddr_wb==rs2Addr_ex);
    assign ForwardB[1]=RegWrite_mem && (rdAddr_mem!=0) && (rdAddr_mem==rs2Addr_ex);
    //数据转发MUX结果
    reg [31:0] A,B;
    always @(*) begin
        if (ForwardA == 2'b00) begin
            A = rs1Data_ex;
        end
        else if (ForwardA == 2'b01) begin
            A = RegWriteData_wb;
        end
        else begin
            A = ALUResult_mem;
        end

        if (ForwardB == 2'b00) begin
            B = rs2Data_ex;
        end
        else if (ForwardB == 2'b01) begin
            B = RegWriteData_wb;
        end
        else begin
            B = ALUResult_mem;
        end
    end

    // ALU操作数MUX
    reg [31:0]ALU_B_reg;
    assign ALU_A = ALUSrcA_ex ? PC_ex : A;
    always @(*) begin
        if (ALUSrcB_ex == 2'b00) begin
            ALU_B_reg = B;
        end
        else if (ALUSrcB_ex == 2'b01) begin
            ALU_B_reg = Imm_ex;
        end
        else begin
            ALU_B_reg = 32'h00000004;
        end
    end
    assign ALU_B=ALU_B_reg;
    assign MemWriteData_ex=B;//MemWriteData_ex输出
    //实例化ALU
    ALU ALU_inst(
        .ALUCode(ALUCode_ex),
        .A(ALU_A),
        .B(ALU_B),
        .ALUResult(ALUResult_ex)
    );
    

endmodule

