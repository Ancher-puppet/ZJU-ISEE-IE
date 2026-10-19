module full_adder(a, b, s, ci, co);
	input a,b,ci;
	output s,co;
	
	wire g,p;
	assign g=a&b;
	assign p=a|b;
	
	assign s=(p&(~g))^ci;
	assign co=g|(p&ci);
	
	endmodule