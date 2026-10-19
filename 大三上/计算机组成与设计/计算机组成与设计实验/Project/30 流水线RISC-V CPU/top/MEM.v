`include "DataRAM.v"
module MEM (
    input [31:0] ALUResult_mem, // 输入ALU计算结果
    input [31:0] MemWriteData_mem, // 输入内存数据
    input clk,            // 时钟输入
    input MemWrite_mem,   // 写使能输入
    input [2:0] LWCode_mem, // 输入LW指令控制信号
    input [1:0] SWCode_mem, // 输入SW指令控制信号
    output [31:0] MemDout_mem // 数据输出
);  
    wire [31:0] MemDout_mem_wire;
    reg [31:0] MemDout_mem_reg;
    reg [31:0] d_reg;
    //根据SWCode_mem选择写入的数据00:sb 01:sh 10:sw
    always @(*) begin
        if (SWCode_mem == 2'b00) begin
            d_reg = {24'b0, MemWriteData_mem[7:0]};
        end
        else if (SWCode_mem == 2'b01) begin
            d_reg = {16'b0, MemWriteData_mem[15:0]};
        end
        else begin
            d_reg = MemWriteData_mem;
        end
    end

    DataRAM DataRAM_inst(
        .a(ALUResult_mem[7:2]),
        .d(d_reg),
        .clk(clk),
        .we(MemWrite_mem),
        .spo(MemDout_mem_wire)
    );
    //根据LWCode_mem选择读出的数据000:lb 001:lh 010:lw 100:lbu 101:lhu
    always @(*) begin
        if (LWCode_mem == 3'b000) begin
            MemDout_mem_reg = {{24{MemDout_mem_wire[7]}}, MemDout_mem_wire[7:0]};
        end
        else if (LWCode_mem == 3'b001) begin
            MemDout_mem_reg = {{16{MemDout_mem_wire[15]}}, MemDout_mem_wire[15:0]};
        end
        else if (LWCode_mem == 3'b100) begin
            MemDout_mem_reg = {24'b0, MemDout_mem_wire[7:0]};
        end
        else if (LWCode_mem == 3'b101) begin
            MemDout_mem_reg = {16'b0, MemDout_mem_wire[15:0]};
        end
        else begin
            MemDout_mem_reg = MemDout_mem_wire;
        end
    end
    assign MemDout_mem = MemDout_mem_reg;


endmodule