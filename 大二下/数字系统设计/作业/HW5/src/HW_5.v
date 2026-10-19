module encode(d,x,y,v);
    input [3:0] d; // 4-bit input
    output reg x,y,v;
    always @(*)
        if(d[3])
            {x,y,v} = 3'b111;
        else if(d[2])
            {x,y,v} = 3'b101;
        else if(d[1])
            {x,y,v} = 3'b011;
        else if(d[0])
            {x,y,v} = 3'b001;
        else
            {x,y,v} = 3'b000;   
endmodule