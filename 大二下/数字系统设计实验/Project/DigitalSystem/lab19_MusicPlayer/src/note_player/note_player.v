module note_player(clk,reset,play_enable,note_to_load,duration_to_load,load_new_note,note_done,sampling_pulse,beat,sample,sample_ready);
	input clk,reset,play_enable,load_new_note,sampling_pulse,beat;
	input [5:0] note_to_load,duration_to_load;
	output note_done,sample_ready;
	output [15:0] sample;
	
	//控制器
	reg timer_clear,load,note_done;
	reg [1:0] state,next_state;
	reg timer_done;
	
	parameter RESET=0, WAIT=1, DONE=2, LOAD=3;//编码
	always@(posedge clk) begin
        if(reset) state=RESET;
        else state=next_state;
    end
	always@(*) begin
        timer_clear=0;
		load=0;
		note_done=0;//默认为0
        case (state)
            RESET:
                begin
                    timer_clear=1;
					load=0;
					note_done=0;
                    next_state=WAIT;
                end
            WAIT:
                begin
                    timer_clear=0;
					load=0;
					note_done=0;
                    if(!play_enable) next_state=RESET;
                    else if(timer_done) next_state=DONE;
                    else if(load_new_note) next_state=LOAD;
                    else next_state=WAIT;
                end
            DONE:
                begin
                    timer_clear=1;
					load=0;
					note_done=1;
                    next_state=WAIT;
                end
            LOAD:
                begin
                    timer_clear=1;
					load=1;
					note_done=0;
                    next_state=WAIT;
                end
        endcase
    end
	
	//节拍定时器(实则为定时器 n=duration_to_load counter_bits=6
	reg [5:0] q=0; 
	always @(posedge clk)
		begin
			timer_done=(q==(duration_to_load-1))&&beat;//定时结束
			if(timer_clear) q=0;
			else if(beat) q=q+1; 
			else q=q;
		end
		
	//其他功能单元
	//注意r后面是按位或 不是条件或
	wire [5:0] temp_q;
	dffre #(.n(6))ff1(.d(note_to_load),.en(load),.r(~play_enable|reset),.clk(clk),.q(temp_q));
	wire [19:0] temp_dout;
	frequency_rom frequency_rom_inst(.clk(clk),.dout(temp_dout),.addr(temp_q));
	dds dds_inst(.k({2'b00,temp_dout}),.clk(clk),.reset(1'b0),.sampling_pulse(sampling_pulse),.sample(sample),.new_sample_ready(sample_ready));
endmodule
	
	
	