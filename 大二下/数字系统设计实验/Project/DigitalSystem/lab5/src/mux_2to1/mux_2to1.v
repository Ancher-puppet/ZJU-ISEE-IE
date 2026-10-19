module mux_2to1(out, in0,in1, addr);

	parameter n=1;//输入输出数据位数
	
	output[n-1:0] out;
	input[n-1:0] in0,in1;
	input addr;
	reg[n-1:0] out;
	
	
	always @(in0 or in1 or addr)
		begin
			if(addr) out=in1;
			else out=in0;
		end
endmodule