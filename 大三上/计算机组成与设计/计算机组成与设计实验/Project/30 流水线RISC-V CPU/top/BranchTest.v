module BranchTest (
    input wire [31:0] rs1Data,
    input wire [31:0] rs2Data,
    input wire SB_type,
    input wire [2:0] funct3,
    output wire Branch
);
    wire isLT, isLTU;
    wire [31:0] sum;
    assign sum = rs1Data + ~rs2Data + 1;
    assign isLT = rs1Data[31] && (~rs2Data[31]) || (rs1Data[31] ~^ rs2Data[31]) && sum[31];
    assign isLTU = (~rs1Data[31]) && rs2Data[31] || (rs1Data[31] ~^ rs2Data[31]) && sum[31];
    reg Branch_temp;

    // 定义 funct3 的值
    localparam beq_funct3 = 3'b000;
    localparam bne_funct3 = 3'b001;
    localparam blt_funct3 = 3'b100;
    localparam bge_funct3 = 3'b101;
    localparam bltu_funct3 = 3'b110;
    localparam bgeu_funct3 = 3'b111;

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

    assign Branch = Branch_temp;
endmodule