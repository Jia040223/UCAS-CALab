`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/14 18:23:00
// Design Name: 
// Module Name: divide
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module div(
    input  wire         div_clk,
    input  wire         resetn,
    input  wire         div,
    input  wire         div_signed,
    input  wire [31:0]  x,
    input  wire [31:0]  y,
    output wire [31:0]  s,
    output wire [31:0]  r,
    output wire         complete
    );

    wire        s_sign;
    wire        r_sign;

    wire [31:0] abs_x;
    wire [31:0] abs_y;
    reg  [63:0] A;
    reg  [32:0] B;

    reg  [31:0] s_reg;
    reg  [32:0] r_reg;

    wire        start;
    reg  [5:0]  counter;

    wire [32:0] test_div_r;
    wire [32:0] final_r;

    always @(posedge div_clk) begin
        if (~resetn)
            counter <= 6'b0;
        else if (div) begin
            if (complete)
                counter <= 6'b0;
            else
                counter <= counter + 6'b1;
        end
    end

    assign start = counter == 6'b0;
    assign complete = counter == 6'd33;

    //确定符号，计算被除数和除数的绝对值
    assign s_sign = div_signed & (x[31] ^ y[31]);
    assign r_sign = div_signed & x[31];
    assign abs_x = (div_signed & x[31]) ? (~x + 1'b1) : x;
    assign abs_y = (div_signed & y[31]) ? (~y + 1'b1) : y;

    //迭代运算得到商和余数的绝对值
    //准备A和B
    always @(posedge div_clk) begin
        if (~resetn)
            A <= 64'b0;
        else if (div & start)
            A <= {32'b0, abs_x};
    end

    always @(posedge div_clk) begin
        if (~resetn)
            B <= 33'b0;
        else if (div & start)
            B <= {1'b0, abs_y};
    end

    //迭代运算
    always @(posedge div_clk) begin
        if (~resetn)
            r_reg <= 33'b0;
        else if (div & ~complete) begin
            if (start)
                r_reg <= {32'b0, abs_x[31]};
            else if (counter == 6'd32)
                r_reg <= final_r;
            else
                r_reg <= {final_r[31:0], A[31 - counter]};
        end
    end

    always @(posedge div_clk) begin
        if (~resetn)
            s_reg <= 32'b0;
        else if (div & ~complete & ~start)
            s_reg[32 - counter] <= ~test_div_r[32];
    end

    assign test_div_r = r_reg - B;
    assign final_r = test_div_r[32] ? r_reg : test_div_r;


    //调整最终的商和余数
    assign r = div_signed & r_sign ? (~r_reg + 1'b1) : r_reg;
    assign s = div_signed & s_sign ? (~s_reg + 1'b1) : s_reg;
endmodule