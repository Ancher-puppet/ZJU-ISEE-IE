module CSR(clk,reset,PC,interrupt,illegal_inst,is_mret,mepc,trap,trap_addr);
    input clk, reset;
    input [31:0] PC;      // 当前指令的PC
    input interrupt;      // 外部中断请求（如按键）
    input illegal_inst;   // 非法指令信号
    input is_mret;        // mret指令信号
    
    output reg [31:0] mepc;    // 输出 mepc 的值用于返回
    output trap;              // 发生中断/异常
    output [31:0] trap_addr;   // 异常处理程序的入口地址


    reg [31:0] mcause; // 记录原因 (1:中断, 0:非法指令)

    // 固定的异常入口地址
    localparam TRAP_VECTOR_ADDR = 32'h0000_0004; 

	// trap!
	assign trap = illegal_inst | interrupt;
	assign trap_addr = TRAP_VECTOR_ADDR;
	
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mepc <= 0;
            mcause <= 0;
        end 
		else begin
            // 优先级：复位 > 外部中断 > 内部异常
            if (interrupt) begin
                mepc <= PC;        // 保存断点
                mcause <= 32'd1;           // 标记为中断
            end 
            else if (illegal_inst) begin
                mepc <= PC;
                mcause <= 32'd0;           // 标记为非法指令
            end 
        end
    end
endmodule