module full_adder(a, b, s, ci, co);
	input a,b,ci;
	output s,co;
	
	assign s=a^b^ci;
	assign co=(a&b)|(b&ci)|(a&ci);
	
	endmodule