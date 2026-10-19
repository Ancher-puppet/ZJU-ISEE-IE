module button_process_unit(reset,ButtonIn,clk,ButtonOut);
	input clk,reset,ButtonIn;
	output ButtonOut;
	parameter sim=100000;
	
	//调用同步器模块
	wire temp1;
	synch synch_inst(.asynch_in(ButtonIn),.clk(clk),.synch_out(temp1));
	//调用防颤电路
	wire temp2;
	debouncer #(.sim(sim)) debouncer_inst(.in(temp1),.clk(clk),.reset(reset),.v0(temp2));
	//调用脉冲变宽
	pulse_variation pulse_variation_inst(.in(temp2),.clk(clk),.out(ButtonOut));
endmodule
