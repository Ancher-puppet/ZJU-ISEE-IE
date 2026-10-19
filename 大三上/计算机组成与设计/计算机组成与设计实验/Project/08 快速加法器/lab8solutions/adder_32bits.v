module adder_32bits(a,b,ci,s,co);
	input [31:0] a,b;
	input ci;
	output [31:0] s;
	output co;
	
	wire c3;
	adder_4bits adder1(.a(a[3:0]),.b(b[3:0]),.ci(ci),.s(s[3:0]),.co(c3));
	
	wire [3:0] s2_0,s2_1;
	wire c7,c7_1,c7_0;
	adder_4bits adder2_1(.a(a[7:4]),.b(b[7:4]),.ci(1'b1),.s(s2_1[3:0]),.co(c7_1));
	adder_4bits adder2_2(.a(a[7:4]),.b(b[7:4]),.ci(1'b0),.s(s2_0[3:0]),.co(c7_0));
	mux_2to1 #(.n(4))mux1(.out(s[7:4]), .in0(s2_0[3:0]), .in1(s2_1[3:0]), .addr(c3));
	assign c7=(c3&c7_1)|c7_0;
	
	wire [3:0] s3_0,s3_1;
	wire c11,c11_1,c11_0;
	adder_4bits adder3_1(.a(a[11:8]),.b(b[11:8]),.ci(1'b1),.s(s3_1[3:0]),.co(c11_1));
	adder_4bits adder3_2(.a(a[11:8]),.b(b[11:8]),.ci(1'b0),.s(s3_0[3:0]),.co(c11_0));
	mux_2to1 #(.n(4))mux2(.out(s[11:8]), .in0(s3_0[3:0]), .in1(s3_1[3:0]), .addr(c7));
	assign c11=(c7&c11_1)|c11_0;
	
	wire [3:0] s4_0,s4_1;
	wire c15,c15_1,c15_0;
	adder_4bits adder4_1(.a(a[15:12]),.b(b[15:12]),.ci(1'b1),.s(s4_1[3:0]),.co(c15_1));
	adder_4bits adder4_2(.a(a[15:12]),.b(b[15:12]),.ci(1'b0),.s(s4_0[3:0]),.co(c15_0));
	mux_2to1 #(.n(4))mux3(.out(s[15:12]), .in0(s4_0[3:0]), .in1(s4_1[3:0]), .addr(c11));
	assign c15=(c11&c15_1)|c15_0;
	
	wire [3:0] s5_0,s5_1;
	wire c19,c19_1,c19_0;
	adder_4bits adder5_1(.a(a[19:16]),.b(b[19:16]),.ci(1'b1),.s(s5_1[3:0]),.co(c19_1));
	adder_4bits adder5_2(.a(a[19:16]),.b(b[19:16]),.ci(1'b0),.s(s5_0[3:0]),.co(c19_0));
	mux_2to1 #(.n(4))mux4(.out(s[19:16]), .in0(s5_0[3:0]), .in1(s5_1[3:0]), .addr(c15));
	assign c19=(c15&c19_1)|c19_0;
	
	wire [3:0] s6_0,s6_1;
	wire c23,c23_1,c23_0;
	adder_4bits adder6_1(.a(a[23:20]),.b(b[23:20]),.ci(1'b1),.s(s6_1[3:0]),.co(c23_1));
	adder_4bits adder6_2(.a(a[23:20]),.b(b[23:20]),.ci(1'b0),.s(s6_0[3:0]),.co(c23_0));
	mux_2to1 #(.n(4))mux5(.out(s[23:20]), .in0(s6_0[3:0]), .in1(s6_1[3:0]), .addr(c19));
	assign c23=(c19&c23_1)|c23_0;
	
	wire [3:0] s7_0,s7_1;
	wire c27,c27_1,c27_0;
	adder_4bits adder7_1(.a(a[27:24]),.b(b[27:24]),.ci(1'b1),.s(s7_1[3:0]),.co(c27_1));
	adder_4bits adder7_2(.a(a[27:24]),.b(b[27:24]),.ci(1'b0),.s(s7_0[3:0]),.co(c27_0));
	mux_2to1 #(.n(4))mux6(.out(s[27:24]), .in0(s7_0[3:0]), .in1(s7_1[3:0]), .addr(c23));
	assign c27=(c23&c27_1)|c27_0;

	wire [3:0] s8_0,s8_1;
	wire c31,c31_1,c31_0;
	adder_4bits adder8_1(.a(a[31:28]),.b(b[31:28]),.ci(1'b1),.s(s8_1[3:0]),.co(c31_1));
	adder_4bits adder8_2(.a(a[31:28]),.b(b[31:28]),.ci(1'b0),.s(s8_0[3:0]),.co(c31_0));
	mux_2to1 #(.n(4))mux7(.out(s[31:28]), .in0(s8_0[3:0]), .in1(s8_1[3:0]), .addr(c27));
	assign c31=(c27&c31_1)|c31_0;
	
	assign co=c31;
	
	endmodule