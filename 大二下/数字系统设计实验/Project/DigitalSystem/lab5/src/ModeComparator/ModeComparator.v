module ModeComparator(aIn,bIn,m,out);
	input [7:0] aIn,bIn;
	input m;
	output [7:0] out;
	
	//比较器示例
	wire agb;
	comp #(.n(8))comp_inst(.a(aIn), .b(bIn), .agb(agb), .aeb(), .alb());
	
	//数据选择器
	mux_2to1 #(.n(8))mux(.out(out), .in0(aIn), .in1(bIn), .addr(~agb^m));
endmodule