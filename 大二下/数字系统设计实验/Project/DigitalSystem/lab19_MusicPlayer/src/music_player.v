module music_player(clk,reset,play_pause,next,NewFrame,sample,play,song);
	input clk,next,play_pause,reset,NewFrame;
	output [15:0] sample;
	output [1:0] song;
	output play;
	//input和output 默认类型都是wire output还可以被指定为reg型
	
	parameter sim=0;
	//调用主控制器mcu
	wire song_done,reset_play;
	mcu mcu_inst(.play_pause(play_pause),.next(next),.song_done(song_done),.reset(reset),.clk(clk),.play(play),.reset_play(reset_play),.song(song));
	
	//调用乐曲读取
	wire new_note,note_done;
	wire [5:0] note,duration;
	song_reader song_reader_inst(.song(song),.clk(clk),.reset(reset_play),.note_done(note_done),.play(play),.note(note),.duration(duration),.song_done(song_done),.new_note(new_note));
	
	//调用音符播放
	wire ready,beat;
	//同步化电路
	wire temp1,temp2;
	dffre #(.n(1))mff1(.d(NewFrame),.en(1'b1),.r(1'b0),.clk(clk),.q(temp1));
	dffre #(.n(1))mff2(.d(temp1),.en(1'b1),.r(1'b0),.clk(clk),.q(temp2));
	assign ready=temp1&(~temp2);
	//时钟管理模块DCM（1000分频）
	counter_n #(.n(sim?64:10**3),.counter_bits(sim?6:10))mcounter(.clk(clk),.r(1'b0),.en(ready),.co(beat),.q());//分频器
	note_player note_player_inst(.clk(clk),.reset(reset_play),.play_enable(play),.note_to_load(note),.duration_to_load(duration),.load_new_note(new_note),.note_done(note_done),.sampling_pulse(ready),.beat(beat),.sample(sample),.sample_ready());
endmodule