module mcu(play_pause,next,song_done,reset,clk,play,reset_play,song);
	input clk,reset,play_pause,next,song_done;
	output play,reset_play;
	output [1:0] song;
	//控制器部分
	parameter RESET=0,PAUSE=1,PLAY=2,NEXT=3;//编码
	reg [1:0] state,next_state;
	reg play,reset_play,NextSong;
	//控制器异步置零
	always @(posedge clk)
		begin
			if(reset) state=RESET;
			else state=next_state;
		end
		
	//控制器部分,根据现态和输入变量决定次态
	always@(*)
		begin	
			play=0;
			NextSong=0;
			reset_play=1;
		case(state)
			RESET:
				begin
					play=0;
					NextSong=0;
					reset_play=1;
					next_state=PAUSE;
				end
			PAUSE:
				begin
					play=0;
					NextSong=0;
					reset_play=0;
					next_state=(play_pause==1)?PLAY:((next==1)?NEXT:PAUSE);
				end
			PLAY:
				begin
					play=1;
					NextSong=0;
					reset_play=0;
					next_state=(play_pause==1)?PAUSE:((next==1)?NEXT:((song_done==1)?RESET:PLAY));
				end
			NEXT:
				begin
					play=0;
					NextSong=1;
					reset_play=1;
					next_state=PLAY;
				end
		endcase
		end
	//2位2进制计数器
	counter_n #(.n(4),.counter_bits(2)) counter1(.clk(clk),.r(reset),.en(NextSong),.co(),.q(song));
endmodule