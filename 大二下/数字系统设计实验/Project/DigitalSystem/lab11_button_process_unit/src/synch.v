module synch(asynch_in,clk,synch_out);
	input clk,asynch_in;
	output synch_out;
	wire temp;
	dffre #(.n(1))ff1(.d(asynch_in),.en(1),.r(1'b0),.clk(clk),.q(temp));
	dffre #(.n(1))ff2(.d(temp),.en(1'b1),.r(1'b0),.clk(clk),.q(synch_out));
endmodule