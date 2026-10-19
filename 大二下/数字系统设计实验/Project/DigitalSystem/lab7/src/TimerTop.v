module TimerTop(clk,reset,start,LED1,LED0);
	input clk,reset,start;
	output LED1,LED0;
	parameter sim=1'b0;
	//sim=1时候，分频器1的分频比设为2，减少了仿真时间？
	//中间变量
	wire pulse10Hz,pulse1Hz;
	wire TimerEn,TimerOut;
	wire clr;
	//输出
	assign LED1=TimerEn;
	//分频器实例
	counter_n #(.n(sim?2:10**7),.counter_bits(sim?1:24))DivI(.clk(clk),.r(0),.en(1'b1),.co(pulse10Hz),.q());
	counter_n #(.n(10),.counter_bits(4))DivII(.clk(clk),.r(0),.en(pulse10Hz),.co(pulse1Hz),.q());
	//定时计数器实例
	timer #(.n(12),.counter_bits(4))TimerInst(.clk(clk),.r(reset||start),.en(pulse1Hz&&TimerEn),.done(TimerOut));
	//RS触发器
	rsff ff1(.clk(clk),.r(reset||TimerOut),.s(start),.q(TimerEn));
	rsff ff2(.clk(clk),.r(TimerOut),.s(reset||start),.q(clr));
	//D触发器实例
	dffre #(.n(1))ff3(.d(~LED0),.en(pulse10Hz),.r(clr),.clk(clk),.q(LED0));
endmodule