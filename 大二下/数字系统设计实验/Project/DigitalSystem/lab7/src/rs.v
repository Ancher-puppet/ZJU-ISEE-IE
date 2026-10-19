module  rsff(clk,r,s,q);
	input clk,r,s;
	output reg q;
	always @(posedge clk)
		if(r) q=0;
		else if(s) q=1;
endmodule