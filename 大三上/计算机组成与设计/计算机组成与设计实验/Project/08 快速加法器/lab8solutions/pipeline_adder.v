module pipeline_adder(a,b,ci,clk,s,co);
	input ci,clk;
	input [31:0] a,b;
	output reg [31:0] s;
	output reg co;

	// 第0级锁存
    reg [31:0] a_reg0, b_reg0;
    reg ci_reg0;
	
    always @(posedge clk) begin
        a_reg0 <= a;
        b_reg0 <= b;
        ci_reg0 <= ci;
    end
	
	
    // 第1级锁存
	reg [31:8] a_reg1, b_reg1;
    reg [7:0] sum_reg1;
	reg ci_reg1;
	
    wire [7:0] sum0_7;
    wire co0_7;
    adder_8bits adder1(.a(a_reg0[7:0]),.b(b_reg0[7:0]),.ci(ci_reg0),.s(sum0_7),.co(co0_7));

    always @(posedge clk) begin
        a_reg1 <= a_reg0[31:8];
        b_reg1 <= b_reg0[31:8];
        s[7:0] <= sum0_7;
        ci_reg1 <= co0_7;
    end

    // 第2级锁存
	reg [31:16] a_reg2, b_reg2;
    reg [15:0] sum_reg2;
	reg ci_reg2;
	
    wire [7:0] sum8_15;
    wire co8_15;
    adder_8bits adder2(.a(a_reg1[15:8]),.b(b_reg1[15:8]),.ci(ci_reg1),.s(sum8_15),.co(co8_15));

    always @(posedge clk) begin
        a_reg2 <= a_reg1[31:16];
        b_reg2 <= b_reg1[31:16];
        s[15:8] <= sum8_15;
        ci_reg2 <= co8_15;
    end

    // 第3级锁存
	reg [31:24] a_reg3, b_reg3;
    reg [23:0] sum_reg3;
	reg ci_reg3;
	
    wire [7:0] sum16_23;
    wire co16_23;
    adder_8bits adder3(.a(a_reg2[23:16]),.b(b_reg2[23:16]),.ci(ci_reg2),.s(sum16_23),.co(co16_23));

    always @(posedge clk) begin
        a_reg3 <= a_reg2[31:24];
        b_reg3 <= b_reg2[31:24];
        s[23:16] <= sum16_23;
        ci_reg3 <= co16_23;
    end

    // 第4级锁存
	reg [31:0] a_reg4, b_reg4;
    reg [31:0] sum_reg4;
	reg ci_reg4;
	
    wire [7:0] sum24_31;
    wire co24_31;
    adder_8bits adder4(.a(a_reg3[31:24]),.b(b_reg3[31:24]),.ci(ci_reg3),.s(sum24_31),.co(co24_31));

    always @(posedge clk) begin
        s[31:24] <= sum24_31;
        ci_reg4 <= co24_31;
		co <= ci_reg4;
    end


endmodule