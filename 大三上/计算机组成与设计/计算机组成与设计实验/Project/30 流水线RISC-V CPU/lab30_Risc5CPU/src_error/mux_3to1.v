module mux_3to1(out, in0,in1,in2,addr);

	parameter n=1;//输入输出数据位数
	
	output[n-1:0] out;
	input[n-1:0] in0,in1,in2;
	input [1:0] addr;
	reg[n-1:0] out;

    always @(*)
    begin
        case (addr)
            2'b00: out = in0;  
            2'b01: out = in1;  
            2'b10: out = in2;  
            default: out = in0; 
        endcase
    end

endmodule