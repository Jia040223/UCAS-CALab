module mul(
    input  wire         mul_clk,
    input  wire         resetn,
    input  wire         mul_signed,
    input  wire [31:0]  x,
    input  wire [31:0]  y,
    output wire [63:0]  result
);

    reg reset;
    always @(posedge mul_clk) begin
            reset <= ~resetn;
    end

    wire [67:0] p [16:0];
    wire [16:0] c;
    reg  [16:0] c_reg;

    wire [14:0] cout [67:0];
    wire [67:0] c_wal;
    wire [67:0] s;
    wire [63:0] add_B;

    wire [33:0] A;
    wire [33:0] B;

    wire [63:0] result_adder_64; 

    assign A = mul_signed ? {{2{x[31]}}, x}: {{2{1'b0}}, x};
    assign B = mul_signed ? {{2{y[31]}}, y}: {{2{1'b0}}, y};

    always @(posedge mul_clk) begin
        if (~resetn)
            c_reg <= 17'b0;
        else
            c_reg <= c;
    end

    assign add_B = {c_wal[62:0], c_reg[15]};
    adder_64 adder_64(
        .Cin(c_reg[16]),
        .A(s[63:0]),
        .B(add_B),
        .S(result_adder_64),
        .Cout()
    );

    assign result = (~resetn | reset) ? 0 : result_adder_64;

    booth_2 b0(.y2(B[1]), .y1(B[0]), .y0(1'b0), .x({{34{A[33]}}, A[33:0]}), .p(p[0]), .c(c[0]));

    genvar i_mul;
    generate
        for (i_mul = 1;  i_mul < 17; i_mul = i_mul + 1) begin: mul_booth
            booth_2 b(.y2(B[2 * i_mul + 1]), .y1(B[2 * i_mul]), .y0(B[2 * i_mul - 1]), 
            .x({{(34 - 2 * i_mul){A[33]}}, A[33:0], {(2 * i_mul){1'b0}}}), .p(p[i_mul]), .c(c[i_mul]));
        end
    endgenerate

    Wallace wallace0(.mul_clk(mul_clk), .resetn(resetn), .n({p[16][0], p[15][0],
            p[14][0], p[13][0], p[12][0], p[11][0], p[10][0], p[9][0], p[8][0], 
            p[7][0], p[6][0], p[5][0], p[4][0], p[3][0], p[2][0], p[1][0], p[0][0]}), 
            .Cin({c_reg[14:11], c[10:0]}), .Cout({s[0], c_wal[0], cout[0]}));
    genvar i_wal;
    generate
        for (i_wal = 1; i_wal < 68; i_wal = i_wal + 1) begin: mul_wal
            Wallace wallace(.mul_clk(mul_clk), .resetn(resetn), .n({p[16][i_wal], p[15][i_wal], 
            p[14][i_wal], p[13][i_wal], p[12][i_wal], p[11][i_wal], p[10][i_wal], p[9][i_wal], 
            p[8][i_wal], p[7][i_wal], p[6][i_wal], p[5][i_wal], p[4][i_wal], p[3][i_wal], p[2][i_wal], 
            p[1][i_wal], p[0][i_wal]}), .Cin(cout[i_wal - 1]), .Cout({s[i_wal], c_wal[i_wal], cout[i_wal]}));
        end
    endgenerate

endmodule

module booth_2(             //booth��λһ������pi��cģ��
    input y2,
    input y1,
    input y0,
    input [67:0] x,
    output [67:0] p,
    output c
);

    wire addx, add2x, subx, sub2x;
    assign addx = ~y2 & y1 & ~y0 | ~y2 & ~y1 & y0;
    assign add2x = ~y2 & y1 & y0;
    assign subx = y2 & y1 & ~y0 | y2 & ~y1 & y0;
    assign sub2x = y2 & ~y1 && ~y0;
    assign c = subx | sub2x;
    assign p[0] = subx & ~x[0] | addx & x[0] | sub2x;

    genvar i_booth;
    generate
        for (i_booth = 1; i_booth < 68; i_booth = i_booth + 1) begin: booth_calc
            assign p[i_booth] = subx & ~x[i_booth] | sub2x & ~x[i_booth - 1] |
                addx & x[i_booth] | add2x & x[i_booth - 1]; 
        end
    endgenerate

endmodule

module Wallace(             //����ʿ��
    input mul_clk,
    input resetn,
    input [16:0] n,
    input [14:0] Cin,
    output [16:0] Cout
);

    wire [4:0] s1;
    wire [3:0] s2;
    wire [1:0] s3;

    reg [1:0] s3_reg;
    reg [3:0] c10_7_reg;

    wire [1:0] s4;
    wire s5;
    wire s6;

    genvar i_w1;
    generate
        for (i_w1 = 0; i_w1 < 5; i_w1 = i_w1 + 1) begin: wallace1
            Full_Adder adder(.A(n[i_w1 * 3]), .B(n[i_w1 * 3 + 1]), .Cin(n[i_w1 * 3 + 2]),
            .S(s1[i_w1]), .Cout(Cout[i_w1]));
        end
    endgenerate

    Full_Adder add2_5(.A(s1[0]), .B(s1[1]), .Cin(s1[2]),
    .S(s2[0]), .Cout(Cout[5]));

    Full_Adder add2_6(.A(s1[3]), .B(s1[4]), .Cin(n[15]),
    .S(s2[1]), .Cout(Cout[6]));

    Full_Adder add2_7(.A(Cin[0]), .B(Cin[1]), .Cin(Cin[2]),
    .S(s2[2]), .Cout(Cout[7]));

    Full_Adder add2_8(.A(Cin[3]), .B(Cin[4]), .Cin(n[16]),
    .S(s2[3]), .Cout(Cout[8]));

    Full_Adder add3_9(.A(s2[0]), .B(s2[1]), .Cin(s2[2]),
    .S(s3[0]), .Cout(Cout[9]));

    Full_Adder add3_10(.A(s2[3]), .B(Cin[5]), .Cin(Cin[6]),
    .S(s3[1]), .Cout(Cout[10]));

    always @(posedge mul_clk) begin
        if (~resetn)
            {c10_7_reg, s3_reg} <= 6'b0;
        else
            {c10_7_reg, s3_reg} <= {Cin[10:7], s3};
    end

    Full_Adder add4_11(.A(s3_reg[0]), .B(s3_reg[1]), .Cin(c10_7_reg[0]),
    .S(s4[0]), .Cout(Cout[11]));

    Full_Adder add4_12(.A(c10_7_reg[1]), .B(c10_7_reg[2]), .Cin(c10_7_reg[3]),
    .S(s4[1]), .Cout(Cout[12]));

    Full_Adder add5_13(.A(s4[0]), .B(s4[1]), .Cin(Cin[11]),
    .S(s5), .Cout(Cout[13]));

    Full_Adder add6_14(.A(s5), .B(Cin[12]), .Cin(Cin[13]),
    .S(s6), .Cout(Cout[14]));

    Full_Adder add7_15(.A(s6), .B(Cin[14]), .Cin(0),
    .S(Cout[16]), .Cout(Cout[15]));

endmodule

module Full_Adder(              //ȫ����
    input A,
    input B,
    input Cin,
    output S,
    output Cout
);
    assign S = ~A &~B & Cin | ~A & B & ~Cin | A & ~B & ~Cin | A & B & Cin;
    assign Cout = A & B | A & Cin | B & Cin;

endmodule

module adder_4(                 //4λ�ӷ���
    input c0,
    input [3:0] p,
    input [3:0] g,
    output c1,
    output c2,
    output c3,
    output P,
    output G
);
    assign c1 = g[0] | p[0] & c0;
    assign c2 = g[1] | p[1] & g[0] | p[1] & p[0] & c0;
    assign c3 = g[2] | p[2] & g[1] | p[2] & p[1] & g[0] | p[2] & p[1] & p[0] & c0;
    assign P = &p;
    assign G = g[3] | p[3] & g[2] | p[3] & p[2] & g[1] | p[3] & p[2] & p[1] & g[0];

endmodule

module adder_64(                //64λ�ӷ���
    input Cin,
    input [63:0] A,
    input [63:0] B,
    output [63:0] S,
    output Cout
);

    wire [63:0] p0;
    wire [63:0] g0;
    wire [63:0] c1;
    wire [15:0] p1;
    wire [15:0] g1;
    wire [15:0] c2;
    wire [3:0] p2;
    wire [3:0] g2;
    wire [3:0] c3;
    wire p3;
    wire g3;

    assign p0 = A | B;
    assign g0 = A & B;
    assign c1[0] = Cin;
    assign c2[0] = Cin;
    assign c3[0] = Cin;

    assign Cout = p3 & Cin | g3;

    genvar ic1;
    generate
        for (ic1 = 1; ic1 < 4; ic1 = ic1 + 1) begin: value_c2
            assign c2[ic1 * 4] = c3[ic1];
        end
    endgenerate

    genvar ic0;
    generate
        for (ic0 = 1; ic0 < 16; ic0 = ic0 + 1) begin: value_c1
            assign c1[ic0 * 4] = c2[ic0];
        end
    endgenerate

    genvar i0;
    generate
        for (i0 = 0; i0 < 16; i0 = i0 + 1) begin: floor0
            adder_4 adder_floor0(.c0(c2[i0]), .p(p0[i0 * 4 + 3 : i0 * 4]), .g(g0[i0 * 4 + 3 : i0 * 4]),
            .c1(c1[i0 * 4 + 1]), .c2(c1[i0 * 4 + 2]), .c3(c1[i0 * 4 + 3]), .P(p1[i0]), .G(g1[i0]));
        end
    endgenerate

    genvar i1;
    generate
        for (i1 = 0; i1 < 4; i1 = i1 + 1) begin: floor1
            adder_4 adder_floor1(.c0(c3[i1]), .p(p1[i1 * 4 + 3 : i1 * 4]), .g(g1[i1 * 4 + 3 : i1 * 4]),
            .c1(c2[i1 * 4 + 1]), .c2(c2[i1 * 4 + 2]), .c3(c2[i1 * 4 + 3]), .P(p2[i1]), .G(g2[i1]));
        end
    endgenerate

    adder_4 adder_floor2 (.c0(Cin), .p(p2), .g(g2),
            .c1(c3[1]), .c2(c3[2]), .c3(c3[3]), .P(p3), .G(g3));

    genvar i_result;
    generate
        for (i_result = 0; i_result < 64; i_result = i_result + 1) begin: calc_Sum
            Full_Adder sum(.Cin(c1[i_result]), .A(A[i_result]), .B(B[i_result]), .S(S[i_result]), .Cout());
        end
    endgenerate

endmodule