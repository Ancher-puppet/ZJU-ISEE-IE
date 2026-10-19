module Registers(clk,RegWrite,ReadRegister1,ReadRegister2,WriteRegister,WriteData,ReadData1,ReadData2);
	input clk;
	input RegWrite; //允写信号
	input [4:0] ReadRegister1,ReadRegister2; //rs1，rs2
	input [4:0] WriteRegister; //rd
	input [31:0] WriteData;
	output [31:0] ReadData1,ReadData2;

	reg[31:0]regs[31:0]; //32*32存储器
		assign ReadData1=(ReadRegister1 == 5'b0)?32'b0:regs[ReadRegister1]; //端口1，判断是否为reg0
		assign ReadData2=(ReadRegister2 == 5'b0)?32'b0:regs[ReadRegister2]; //端口2
		always@(posedge clk) if(RegWrite) regs[WriteRegister]<=WriteData;
		
endmodule

module RAWRegisters(clk,RegWrite,rs1Addr,rs2Addr,WriteAddr,WriteData,rs1Data,rs2Data);
	input clk;
	input RegWrite; //允写信号
	input [4:0] rs1Addr,rs2Addr;//rs1，rs2
	input [4:0] WriteAddr;//rd
	input [31:0] WriteData;
	output [31:0] rs1Data,rs2Data;

	//转发检测模块
	wire rs1Sel,rs2Sel;
	assign rs1Sel=RegWrite&&(WriteAddr!=0)&&(WriteAddr==rs1Addr);
	assign rs2Sel=RegWrite&&(WriteAddr!=0)&&(WriteAddr==rs2Addr);
	
	//RBW模块
	wire [31:0] ReadData1,ReadData2;
	Registers RAW_Registers(
        .clk(clk),
        .ReadRegister1(rs1Addr),
        .ReadRegister2(rs2Addr),
        .WriteRegister(WriteAddr),
        .RegWrite(RegWrite),
        .WriteData(WriteData),
        .ReadData1(ReadData1),
        .ReadData2(ReadData2)
    );
	mux_2to1 #(.n(32))muxrs1(.out(rs1Data), .in0(ReadData1), .in1(WriteData), .addr(rs1Sel));
	mux_2to1 #(.n(32))muxrs2(.out(rs2Data), .in0(ReadData2), .in1(WriteData), .addr(rs2Sel));
endmodule