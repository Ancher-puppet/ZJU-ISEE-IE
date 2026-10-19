module debouncer(in,clk,reset,v0);
	parameter sim=0;
	input clk,in,reset;
	output v0;
	
	wire pulse1kHz,timer_done;
	reg timer_clr,v0;
	reg[1:0] state,next_state;
	counter_n #(.n(sim?32:10**5),.counter_bits(17))DivI(.clk(clk),.r(1'b0),.en(1'b1),.co(pulse1kHz),.q());//分频器
	timer #(.n(10),.counter_bits(4))TimerInst(.clk(clk),.r(timer_clr),.en(pulse1kHz),.done(timer_done));//10ms计时器
	
	//对状态进行编码
	parameter LOW=0,WAIT_HIGH=1,HIGH=2,WAIT_LOW=3;
	//判断异步置0端
	always @(posedge clk)
		begin
			if(reset) state=LOW;
			else state=next_state;
		end
		
	//控制器部分,根据in，现态，timer_done决定次态
	always@(*)
		begin	
			timer_clr=0;
			v0=0;
		case(state)
			LOW:
				begin
					timer_clr=1;
					v0=0;
					next_state=(in==1)?WAIT_HIGH:LOW;
				end
			WAIT_HIGH:
				begin
					timer_clr=0;
					v0=1;
					next_state=(timer_done==1)?HIGH:WAIT_HIGH;
				end
			HIGH:
				begin
					timer_clr=1;
					v0=1;
					next_state=(in==1)?HIGH:WAIT_LOW;
				end
			WAIT_LOW:
				begin
					timer_clr=0;
					v0=1;
					next_state=(timer_done==1)?LOW:WAIT_LOW;
				end
		endcase
		end
endmodule