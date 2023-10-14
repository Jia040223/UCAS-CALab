`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/09/22 00:04:35
// Design Name: 
// Module Name: Wallace32
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


module Wallace32(
    input [31:0] mul1,
    input [31:0] mul2,
    output [63:0] ans,
    output cmp
    );
    
    wire [63:0]  cmpans;
    wire [63:0]  ex_A;
    wire [63:0]  ex_B;
    assign ex_A = {{32{mul1[31]}},mul1};
    assign ex_B = {{32{mul2[31]}},mul2};

    assign cmp = (cmpans == ans); //�ȽϽ���Ƿ���ȷ

    wire [31: 0] A;  
    wire [31: 0] A_w;   
    wire [32: 0] A_2; 
    wire [31: 0] revA;
    wire [32: 0] rev2A;
    wire [31: 0] B;
    wire [31: 0] B_w;
    wire [63: 0] Nsum [15: 0];  //�洢booth�Ĳ��ֻ�
    wire [64: 0] Csum [16: 0];  //�洢����ʿ�е�C
    wire [63: 0] Ssum [16: 0];  //�洢����ʿ�е�S
    wire [ 2: 0] y[31: 0];      
    
    assign A = mul1;
    assign revA = ~A;       //A����
    assign A_2  = (A<<1);   //2A
    assign rev2A= ~A_2;     // 2A����
    assign B = mul2;
    genvar i;
    genvar j;
    generate 
        assign y[1] = {B[1],B[0],1'b0};
        for(i=3;i<=31;i=i+2)begin
            assign y[i]= {B[i],B[i-1],B[i-2]};
        end
    endgenerate
    generate 
        for(i=1;i<=16;i=i+1)begin
            assign  Nsum[i-1] = {64{(y[2*i-1]==3'b000) | (y[2*i-1]==3'b111)}} & 64'b0                                          |  //0
                                {64{(y[2*i-1]==3'b001) | (y[2*i-1]==3'b010)}} & {{34-2*i{    A[31]}},    A,{2*i-2{1'b0}}}      |  //A
                                {64{(y[2*i-1]==3'b011)}}                      & {{33-2*i{    A[31]}},    A,{2*i-1{1'b0}}}      |  //2A
                                {64{(y[2*i-1]==3'b100)}}                      & {{33-2*i{rev2A[32]}},rev2A,{2*i-2{1'b1}}}      |  //-2A
                                {64{(y[2*i-1]==3'b101) | (y[2*i-1]==3'b110)}} & {{34-2*i{ revA[31]}}, revA,{2*i-2{1'b1}}};        //-A
                                            
            assign  Csum[i-1][0] = ((y[2*i-1]==3'b100) | (y[2*i-1]==3'b101) | (y[2*i-1]==3'b110)) & 1'b1;      //�����1����һ������ʿ����λ����            
        end
    endgenerate
    
    assign Csum[16][0] = 1'b0;  //���������C������һλ
    
    //����ʿ��
    generate 
        for(i=1;i<=64;i=i+1)begin
            addr  addr0(.a(Nsum[  0][i-1]),.b(Nsum[  1][i-1]),.cin(Nsum[  2][i-1]),.s(Ssum[ 0][i-1]),.cout(Csum[ 0][i]));
            addr  addr1(.a(Nsum[  3][i-1]),.b(Nsum[  4][i-1]),.cin(Nsum[  5][i-1]),.s(Ssum[ 1][i-1]),.cout(Csum[ 1][i]));
            addr  addr2(.a(Nsum[  6][i-1]),.b(Nsum[  7][i-1]),.cin(Nsum[  8][i-1]),.s(Ssum[ 2][i-1]),.cout(Csum[ 2][i]));
            addr  addr3(.a(Nsum[  9][i-1]),.b(Nsum[ 10][i-1]),.cin(Nsum[ 11][i-1]),.s(Ssum[ 3][i-1]),.cout(Csum[ 3][i]));
            addr  addr4(.a(Nsum[ 12][i-1]),.b(Nsum[ 13][i-1]),.cin(Nsum[ 14][i-1]),.s(Ssum[ 4][i-1]),.cout(Csum[ 4][i]));
            addr  addr5(.a(Nsum[ 15][i-1]),.b(1'b0          ),.cin(1'b0          ),.s(Ssum[ 5][i-1]),.cout(Csum[ 5][i]));
            addr  addr6(.a(Ssum[  0][i-1]),.b(Ssum[  1][i-1]),.cin(Ssum[  2][i-1]),.s(Ssum[ 6][i-1]),.cout(Csum[ 6][i]));             
            addr  addr7(.a(Ssum[  3][i-1]),.b(Ssum[  4][i-1]),.cin(Ssum[  5][i-1]),.s(Ssum[ 7][i-1]),.cout(Csum[ 7][i]));
            addr  addr8(.a(Csum[  0][i-1]),.b(Csum[  1][i-1]),.cin(Csum[  2][i-1]),.s(Ssum[ 8][i-1]),.cout(Csum[ 8][i]));
            addr  addr9(.a(Csum[  3][i-1]),.b(Csum[  4][i-1]),.cin(Csum[  5][i-1]),.s(Ssum[ 9][i-1]),.cout(Csum[ 9][i]));
            addr addr10(.a(Ssum[  6][i-1]),.b(Ssum[  7][i-1]),.cin(Ssum[  8][i-1]),.s(Ssum[10][i-1]),.cout(Csum[10][i]));
            addr addr11(.a(Ssum[  9][i-1]),.b(Csum[  6][i-1]),.cin(Csum[  7][i-1]),.s(Ssum[11][i-1]),.cout(Csum[11][i]));
            addr addr12(.a(Csum[  8][i-1]),.b(Csum[  9][i-1]),.cin(1'b0          ),.s(Ssum[12][i-1]),.cout(Csum[12][i]));
            addr addr13(.a(Ssum[ 10][i-1]),.b(Ssum[ 11][i-1]),.cin(Ssum[ 12][i-1]),.s(Ssum[13][i-1]),.cout(Csum[13][i]));
            addr addr14(.a(Csum[ 10][i-1]),.b(Csum[ 11][i-1]),.cin(Csum[ 12][i-1]),.s(Ssum[14][i-1]),.cout(Csum[14][i]));
            addr addr15(.a(Ssum[ 13][i-1]),.b(Ssum[ 14][i-1]),.cin(Csum[ 13][i-1]),.s(Ssum[15][i-1]),.cout(Csum[15][i]));
            addr addr16(.a(Ssum[ 15][i-1]),.b(Csum[ 14][i-1]),.cin(Csum[ 15][i-1]),.s(Ssum[16][i-1]),.cout(Csum[16][i]));
        end
    endgenerate
    assign ans = (Ssum[16] + Csum[16]);
    
endmodule

//ȫ����
module addr(
    input a,
    input b,
    input cin,
    output s,
    output cout
);
    assign {cout,s} = a+b+cin;
endmodule
