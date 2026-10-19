// Testbench for the priority encoder
`timescale 1ns / 1ps

module encode_tb;
    //inputs
    reg  [3:0] d;

    //outputs  
    wire x, y, v;

	// Instantiate the Unit Under Test (UUT)
    encode uut (
        .d(d),
        .x(x),
        .y(y),
        .v(v)
    );

    initial begin
    //encoder
    d = 4'b0000; 
    #100; // x=0,y=0,v=0
    d = 4'b0001; 
    #100; // x=0,y=0,v=1
    d = 4'b0010; 
    #100; // x=0,y=1,v=1
    d = 4'b0100; 
    #100; // x=1,y=0,v=1
    d = 4'b1000; 
    #100; // x=1,y=1,v=1

    //priority encoder
    d = 4'b1001;
    #100; // x=1,y=1,v=1 
    d = 4'b1100;
    #100; // x=1,y=1,v=1
    d = 4'b1110;
    #100; // x=1,y=1,v=1
    $stop;
  end
endmodule