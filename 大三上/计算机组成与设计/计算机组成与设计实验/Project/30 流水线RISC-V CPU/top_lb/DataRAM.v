module DataRAM (
    input [5:0] a,        // 地址输入
    input [31:0] d,       // 数据输入
    input clk,            // 时钟输入
    input we,             // 写使能输入
    output [31:0] spo     // 数据输出
);

    // 定义一个64x32位的RAM
    reg [31:0] ram [63:0];

    // 在时钟上升沿时触发写操作
    always @(posedge clk) begin
        if (we) begin
            ram[a] <= d; // 写入数据到RAM
        end
    end

    // 组合逻辑读取数据
    assign spo = ram[a]; // 读取数据从RAM

endmodule