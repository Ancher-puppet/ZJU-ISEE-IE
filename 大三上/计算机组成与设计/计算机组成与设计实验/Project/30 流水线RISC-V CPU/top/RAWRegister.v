//RBW寄存器堆
module Register (
    input wire clk,
    input [4:0] ReadRegister1,ReadRegister2,//读取寄存器的地址
    input [4:0] WriteRegister, //写入寄存器的地址
    input RegWrite, //写使能信号
    input [31:0] WriteData, //写入数据
    output [31:0] ReadData1,ReadData2 //读取数据
);
    reg[31:0] regs[31:0];//寄存器堆
    assign ReadData1 = (ReadRegister1==5'b0)?32'b0:regs[ReadRegister1];//x0寄存器始终为0,端口1读取
    assign ReadData2 = (ReadRegister2==5'b0)?32'b0:regs[ReadRegister2];//x0寄存器始终为0,端口2读取
    always @(posedge clk) begin
        if(RegWrite) begin
            regs[WriteRegister] <= WriteData;
        end
    end
endmodule

//RAW寄存器堆
module RAWRegister(
    input wire clk,
    input [4:0] rs1Addr,rs2Addr,//读取寄存器的地址`
    input [4:0] WriteAddr, //写入寄存器的地址
    input RegWrite, //写使能信号
    input [31:0] WriteData, //写入数据
    output [31:0] rs1Data,rs2Data //读取数据
);
    wire rs1Sel,rs2Sel;
    assign rs1Sel = RegWrite && (WriteAddr != 5'b0) && (WriteAddr == rs1Addr);
    assign rs2Sel = RegWrite && (WriteAddr != 5'b0) && (WriteAddr == rs2Addr);
    wire [31:0] RBW_rdData1,RBW_rdData2;
    Register RBW_Register(
        .clk(clk),
        .ReadRegister1(rs1Addr),
        .ReadRegister2(rs2Addr),
        .WriteRegister(WriteAddr),
        .RegWrite(RegWrite),
        .WriteData(WriteData),
        .ReadData1(RBW_rdData1),
        .ReadData2(RBW_rdData2)
    );    
    assign rs1Data = rs1Sel?WriteData:RBW_rdData1;
    assign rs2Data = rs2Sel?WriteData:RBW_rdData2;
endmodule