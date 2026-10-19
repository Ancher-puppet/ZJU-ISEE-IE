module BranchTest(rs1Data,rs2Data,SB_type,funct3,Branch);
    input [31:0] rs1Data;
    input [31:0] rs2Data;
    input SB_type;
    input [2:0] funct3;
    output Branch;
	
    wire [31:0] sum;
	adder_32bits adder(.a(rs1Data),.b(~rs2Data),.ci(1'b1),.s(sum),.co());
    
	wire isLT, isLTU;
    assign isLT = rs1Data[31] && (~rs2Data[31]) || (rs1Data[31] ~^ rs2Data[31]) && sum[31];
    assign isLTU = (~rs1Data[31]) && rs2Data[31] || (rs1Data[31] ~^ rs2Data[31]) && sum[31];

    // funct3
    parameter beq_funct3 = 3'b000;
    parameter bne_funct3 = 3'b001;
    parameter blt_funct3 = 3'b100;
    parameter bge_funct3 = 3'b101;
    parameter bltu_funct3 = 3'b110;
    parameter bgeu_funct3 = 3'b111;

	reg Branch_temp;
    always @(*) begin
        if (SB_type == 1 && funct3 == beq_funct3) begin
            Branch_temp = ~(|sum[31:0]);
        end
        else if (SB_type == 1 && funct3 == bne_funct3) begin
            Branch_temp = |sum[31:0];
        end
        else if (SB_type == 1 && funct3 == blt_funct3) begin
            Branch_temp = isLT;
        end
        else if (SB_type == 1 && funct3 == bge_funct3) begin
            Branch_temp = ~isLT;
        end
        else if (SB_type == 1 && funct3 == bltu_funct3) begin
            Branch_temp = isLTU;
        end
        else if (SB_type == 1 && funct3 == bgeu_funct3) begin
            Branch_temp = ~isLTU;
        end
        else begin
            Branch_temp = 0;
        end
    end
	// 输出Branch
    assign Branch = Branch_temp;
endmodule