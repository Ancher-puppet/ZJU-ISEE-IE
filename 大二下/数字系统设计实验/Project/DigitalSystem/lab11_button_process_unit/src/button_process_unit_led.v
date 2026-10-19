module button_process_unit_led(reset,ButtonIn,clk,led);
	input clk,reset,ButtonIn;
	output led;
	parameter sim=100000;
	
	//调用同步器模�?
	wire temp1;
	synch synch_inst(.asynch_in(ButtonIn),.clk(clk),.synch_out(temp1));
	//调用防颤电路
	wire temp2;
	debouncer #(.sim(sim)) debouncer_inst(.in(temp1),.clk(clk),.reset(reset),.v0(temp2));
	//调用脉冲变宽
	wire ButtonOut;
	pulse_variation pulse_variation_inst(.in(temp2),.clk(clk),.out(ButtonOut));
	//外界测试电路
	dffre #(.n(1))ff(.d(~led),.en(ButtonOut),.r(1'b0),.clk(clk),.q(led));
endmodule