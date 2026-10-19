module timer(clk,r,en,done);
	parameter n=10;
	parameter counter_bits=4;
	input clk,r,en;
	output done;
	reg [counter_bits:1] q=0;
	assign done=(q==(n-1))&&en; //进位
	always @(posedge clk)
		begin
			if(r) q=0;
			else if(en) q=q+1;
		end
endmodule