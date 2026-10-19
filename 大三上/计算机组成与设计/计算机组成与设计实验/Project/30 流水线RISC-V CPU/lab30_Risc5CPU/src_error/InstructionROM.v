module InstructionROM(addr,dout);
    input [5 : 0] addr;
    output [31 : 0] dout;
    reg [31 : 0] dout;
    always @(*)
        case (addr)
            // 0x00: 复位后执行的第一条指令。跳过异常处理程序，直接跳到 0x10 (Main)
            // jal x0, 16 (offset=0x10) -> 机器码 0x0100006f
            6'd0:   dout=32'h0100_006f ; 

            // 异常处理程序 (Trap Handler)
            // 硬件固定入口地址 0x04 (CSR.v 中定义的 TRAP_VECTOR_ADDR)
            // addi x31, x0, 1
            6'd1:   dout=32'h0010_0f93 ; 
            
            // 0x08: 从异常返回。恢复 PC = mepc
            // mret (System指令)
            6'd2:   dout=32'h3020_0073 ; 
            
            // 0x0C: 填充空指令
            6'd3:   dout=32'h0000_0000 ; // nop

            // 主程序 (Main)
            // 0x10: 正常初始化一些数据
            // addi x1, x0, 5
            6'd4:   dout=32'h0050_0093 ; 

            // 0x14: 【测试核心】
            // 0xFFFFFFFF 不是 RISC-V 的合法指令，Opcode 全是 1
            // 预期：CPU 应该立即把 PC 变成 0x04，并把 0x14 存入 mepc
            6'd5:   dout=32'hFFFF_FFFF ; 

            // 0x18: 正常情况下这条指令会被跳过
            6'd6:   dout=32'h0020_0113 ; // addi x2, x0, 2
            
            // 结束
            default: dout=32'h0000_0000 ; // nop
        endcase 
endmodule

/*
module InstructionROM(addr,dout);
	input [5 : 0] addr;
	output [31 : 0] dout;
	reg [31 : 0] dout;
	always @(*)
		case (addr)
			6'd0:   dout=32'h0000_3f37 ;//           lui X30,0x3000
			6'd1:   dout=32'h0200_0fE7 ;//           jalr X31 later(X0)
			6'd2:   dout=32'h01c0_2623 ;// earlier: sw  X28, 0C(X0) 
			6'd3:   dout=32'h0043_2e83 ;//           lw  X29, 4(X6) 
			6'd4:   dout=32'h002e_9293 ;//           sll  X5, X29, 2 
			6'd5:   dout=32'h0043_2e03 ;//           lw   X28, 4(X6)
			6'd6:   dout=32'h0073_3e33 ;//		     sltu X28,X6,X7 
			6'd7:   dout=32'h0000_0fef ;//	done:   jal X31,done
			6'd8:   dout=32'h0000_1c63 ;//	later:	bne X0, X0, end  		// 分支条件不成立
			6'd9:   dout=32'h042f_0293;//	        addi X5, X30, 42
			6'd10:  dout=32'h01f0_0333 ;//          add  X6, X0, X31 
			6'd11:  dout=32'h4062_83b3 ;//           sub X7, X5, X6
			6'd12:  dout=32'h0053_ee33 ;//       	or	 X28, X7, X5 
			6'd13:  dout=32'hfc00_0ae3 ;//          beq X0, X0, earlier
			6'd14: dout=32'h00000000 ;// end:  	nop
			default:dout=32'h00000000 ;//nop
		endcase	
endmodule
*/