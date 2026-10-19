//流水线寄存器模块
// 流水线寄存器负责将流水线的各部分分开，共有 IF/ID、ID/EX、EX/MEM、MEM/WB 四组，对四组
// 流水线寄存器要求不完全相同，因此设计也有不同考虑。
// EX/MEM、MEM/WB 两组流水线寄存器只是普通的 D 型寄存器。
// 当流水线发生数据冒险时，需要清空 ID/EX 流水线寄存器而插入一个气泡，因此 ID/EX 流水线寄存
// 器是一个带同步清零功能的 D 型寄存器。
// 当流水线发生数据冒险时，需要阻塞 IF/ID 流水线寄存器；若跳转指令或分支成立，则还需要清空
// ID/EX 流水线寄存器。因此，IF/ID 流水线寄存器除同步清零功能外，还需要具有保持功能（即具有使能
// EN 信号输入）。

// IFID寄存器模块
module IF_ID (
    input clk,                // 时钟信号
    input reset,              // 复位信号，高电平有效
    input EN,                 // 使能信号
    input [31:0] Instruction_if, // 输入指令
    input [31:0] PC_if,       // 输入PC值
    output reg [31:0] Instruction_id, // 输出指令
    output reg [31:0] PC_id   // 输出PC值
);

    // 在时钟上升沿时触发
    always @(posedge clk) begin
        if (reset) begin
            Instruction_id <= 32'b0; // 复位
            PC_id <= 32'b0;          
        end else if (EN) begin
            Instruction_id <= Instruction_if; // 使能信号有效时更新
            PC_id <= PC_if;                   
        end else begin
            Instruction_id <= Instruction_id; // 使能信号无效时保持
            PC_id <= PC_id;                  
        end
    end

endmodule

//IDEX寄存器模块
module ID_EX (
    input clk,                // 时钟信号
    input reset,              // 复位信号，高电平有效
    input [31:0] PC_id,       // 输入PC值
    input [31:0] rs1Data_id,  // 输入源寄存器1数据
    input [31:0] rs2Data_id,  // 输入源寄存器2数据
    input [31:0] Imm_id,      // 输入立即数
    input [4:0] rdAddr_id,        // 输入目的寄存器地址
    input [4:0] rs1Addr_id,       // 输入源寄存器1地址
    input [4:0] rs2Addr_id,       // 输入源寄存器2地址
    input [3:0] ALUCode_id,   // 输入ALU控制信号
    input ALUSrcA_id,         // 输入ALU源操作数A选择信号
    input [1:0] ALUSrcB_id,   // 输入ALU源操作数B选择信号
    input MemRead_id,         // 输入内存读信号
    input MemWrite_id,        // 输入内存写信号
    input RegWrite_id,        // 输入寄存器写信号
    input MemtoReg_id,  // 输入内存到寄存器信号
    //拓展lhu等指令需要额外的控制信号
    input [2:0] LWCode_id,    // 输入LW指令控制信号
    input [1:0] SWCode_id,    // 输入SW指令控制信号


    output reg [31:0] PC_ex,          // 输出PC值
    output reg [31:0] rs1Data_ex,     // 输出源寄存器1数据
    output reg [31:0] rs2Data_ex,     // 输出源寄存器2数据
    output reg [31:0] Imm_ex,         // 输出立即数
    output reg [4:0] rdAddr_ex,           // 输出目的寄存器地址
    output reg [4:0] rs1Addr_ex,          // 输出源寄存器1地址
    output reg [4:0] rs2Addr_ex,          // 输出源寄存器2地址
    output reg [3:0] ALUCode_ex,      // 输出ALU控制信号
    output reg ALUSrcA_ex,            // 输出ALU源操作数A选择信号
    output reg [1:0] ALUSrcB_ex,      // 输出ALU源操作数B选择信号
    output reg MemRead_ex,            // 输出内存读信号
    output reg MemWrite_ex,           // 输出内存写信号
    output reg RegWrite_ex,           // 输出寄存器写信号
    output reg MemtoReg_ex,      // 输出内存到寄存器信号
    //拓展lhu等指令需要额外的控制信号
    output reg [2:0] LWCode_ex,      // 输出LW指令控制信号
    output reg [1:0] SWCode_ex       // 输出SW指令控制信号
);

    // 在时钟上升沿时触发
    always @(posedge clk) begin
        if (reset) begin
            PC_ex <= 32'b0;          // 复位
            rs1Data_ex <= 32'b0;     
            rs2Data_ex <= 32'b0;     
            Imm_ex <= 32'b0;        
            rdAddr_ex <= 5'b0;       
            rs1Addr_ex <= 5'b0;      
            rs2Addr_ex <= 5'b0;     
            ALUCode_ex <= 4'b0;      
            ALUSrcA_ex <= 1'b0;     
            ALUSrcB_ex <= 2'b0;    
            MemRead_ex <= 1'b0;      
            MemWrite_ex <= 1'b0;   
            RegWrite_ex <= 1'b0;     
            MemtoReg_ex <= 1'b0;
            LWCode_ex <= 3'b0;
            SWCode_ex <= 2'b0;     
        end else begin
            PC_ex <= PC_id;          // 更新
            rs1Data_ex <= rs1Data_id; 
            rs2Data_ex <= rs2Data_id; 
            Imm_ex <= Imm_id;         
            rdAddr_ex <= rdAddr_id;  
            rs1Addr_ex <= rs1Addr_id;
            rs2Addr_ex <= rs2Addr_id; 
            ALUCode_ex <= ALUCode_id;
            ALUSrcA_ex <= ALUSrcA_id;
            ALUSrcB_ex <= ALUSrcB_id; 
            MemRead_ex <= MemRead_id;
            MemWrite_ex <= MemWrite_id; 
            RegWrite_ex <= RegWrite_id; 
            MemtoReg_ex <= MemtoReg_id;
            LWCode_ex <= LWCode_id;
            SWCode_ex <= SWCode_id;
        end
    end

endmodule


// EXMEM寄存器模块
module EX_MEM (
    input clk,                // 时钟信号
    input MemWrite_ex,        // 输入内存写信号
    input RegWrite_ex,        // 输入寄存器写信号
    input MemtoReg_ex,        // 输入内存到寄存器信号
    input [31:0] ALUResult_ex,// 输入ALU计算结果
    input [31:0] MemWriteData_ex, // 输入内存数据
    input [4:0] rdAddr_ex,    // 输入目的寄存器地址
    //拓展lhu等指令需要额外的控制信号
    input [2:0] LWCode_ex,    // 输入LW指令控制信号
    input [1:0] SWCode_ex,    // 输入SW指令控制信号

    output reg MemWrite_mem,  // 输出内存写信号
    output reg RegWrite_mem,  // 输出寄存器写信号
    output reg MemtoReg_mem,  // 输出内存到寄存器信号
    output reg [31:0] ALUResult_mem, // 输出ALU计算结果
    output reg [31:0] MemWriteData_mem, // 输出内存数据
    output reg [4:0] rdAddr_mem, // 输出目的寄存器地址
    //拓展lhu等指令需要额外的控制信号
    output reg [2:0] LWCode_mem, // 输出LW指令控制信号
    output reg [1:0] SWCode_mem  // 输出SW指令控制信号
);

    // 在时钟上升沿时触发
    always @(posedge clk) begin
        MemWrite_mem <= MemWrite_ex;       // 更新
        RegWrite_mem <= RegWrite_ex;       
        MemtoReg_mem <= MemtoReg_ex;       
        ALUResult_mem <= ALUResult_ex;    
        MemWriteData_mem <= MemWriteData_ex; 
        rdAddr_mem <= rdAddr_ex;        
        LWCode_mem <= LWCode_ex;
        SWCode_mem <= SWCode_ex;
    end

endmodule

// MEMWB寄存器模块
module MEM_WB (
    input clk,                // 时钟信号
    input RegWrite_mem,       // 输入寄存器写信号
    input MemtoReg_mem,       // 输入内存到寄存器信号
    input [31:0] ALUResult_mem, // 输入ALU计算结果
    input [31:0] MemDout_mem, // 输入内存数据
    input [4:0] rdAddr_mem,   // 输入目的寄存器地址

    output reg RegWrite_wb,   // 输出寄存器写信号
    output reg MemtoReg_wb,   // 输出内存到寄存器信号
    output reg [31:0] ALUResult_wb, // 输出ALU计算结果
    output reg [31:0] MemDout_wb, // 输出内存数据
    output reg [4:0] rdAddr_wb // 输出目的寄存器地址
);

    // 在时钟上升沿时触发
    always @(posedge clk) begin
        RegWrite_wb <= RegWrite_mem;       // 更新
        MemtoReg_wb <= MemtoReg_mem;       
        ALUResult_wb <= ALUResult_mem;     
        MemDout_wb <= MemDout_mem;         
        rdAddr_wb <= rdAddr_mem;           
    end

endmodule