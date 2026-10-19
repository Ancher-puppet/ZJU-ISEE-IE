module pulse_variation(in,clk,out);
	input in,clk;
	output out;
	wire temp;
	dffre #(.n(1))ff(.d(in),.en(1'b1),.r(1'b0),.clk(clk),.q(temp));
	assign out=in&(~temp);
endmodule
