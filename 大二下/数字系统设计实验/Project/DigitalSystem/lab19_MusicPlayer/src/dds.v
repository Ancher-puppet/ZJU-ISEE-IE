module dds(k,clk,reset,sampling_pulse,sample,new_sample_ready);
	input [21:0] k;
	input clk,reset,sampling_pulse;
	output [15:0] sample;
	output new_sample_ready;
	
	//相位累加器
	wire [21:0] raw_addr;
	wire [21:0] temp1;
	adder #(.n(22)) adder1(.a(raw_addr),.b(k),.s(temp1),.ci(1'b0),.co());
	dffre #(.n(22))ff1(.d(temp1),.en(sampling_pulse),.r(reset),.clk(clk),.q(raw_addr));
	
	//地址处理
	wire [9:0] rom_addr;
	assign rom_addr[9:0]=(raw_addr[20]==0)?raw_addr[19:10]:((raw_addr[20:10]==1024)?1023:(~raw_addr[19:10]+1));
	
	//sine_rom调用
	wire [15:0] raw_data;
	sine_rom sine_rom_inst(.clk(clk), .addr(rom_addr), .dout(raw_data));
	
	//area产生
	wire area;
	dffre #(.n(1))ff2(.d(raw_addr[21]),.en(1'b1),.r(1'b0),.clk(clk),.q(area));
	
	//数据处理
	wire [15:0] data;
	assign data[15:0]=(area==0)?raw_data[15:0]:(~raw_data[15:0]+1);
	
	dffre #(.n(16))ff3(.d(data),.en(sampling_pulse),.r(1'b0),.clk(clk),.q(sample));
	dffre #(.n(1))ff4(.d(sampling_pulse),.en(1'b1),.r(1'b0),.clk(clk),.q(new_sample_ready));
endmodule