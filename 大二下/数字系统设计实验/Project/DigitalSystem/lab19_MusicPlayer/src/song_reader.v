module song_reader(song,clk,reset,note_done,play,note,duration,song_done,new_note);
	input [1:0] song;
	input clk,reset,note_done,play;
	output [5:0] note,duration;
	output song_done,new_note;
	
	reg [5:0] note,duration;
	//初始化赋值（观察到一开始是红线）
	initial begin
        note=0;
        duration=0;
    end
	//控制器部分
	parameter RESET=0,NEW_NOTE=1,WAIT=2,NEXT_NOTE=3;//编码
	reg [1:0] state,next_state;
	reg new_note;
	//控制器异步置零
	always @(posedge clk)
		begin
			if(reset) state=RESET;
			else state=next_state;
		end
		
	//控制器部分,根据现态和输入变量决定次态
	always@(*)
		begin	
			new_note=0;
		case(state)
			RESET:
				begin
					new_note=0;
					next_state=(play==1)?NEW_NOTE:RESET;
				end
			NEW_NOTE:
				begin
					new_note=1;
					next_state=WAIT;
				end
			WAIT:
				begin
					new_note=0;
					next_state=(play==1)?((note_done==1)?NEXT_NOTE:WAIT):RESET;
				end
			NEXT_NOTE:
				begin
					new_note=0;
					next_state=NEW_NOTE;
				end
		endcase
		end
	//地址计数器
	wire co;
	wire [6:0] addr;
	wire [11:0] dout;
	//addr低5位 计数器状态q
	counter_n #(.n(32),.counter_bits(5)) counter2(.clk(clk),.r(reset),.en(note_done),.co(co),.q(addr[4:0]));
	//高两位song地址
	assign addr[6:5]=song[1:0];
	//不太理解为什么dout后面不能直接跟{note,duration} 会报错！
	song_rom song_rom1(.clk(clk),.dout(dout),.addr(addr));
	always@(*) {note,duration}=dout;
	//结束判断
	pulse_variation pulse_variation1(.in(co==1||duration==0),.clk(clk),.out(song_done));
endmodule