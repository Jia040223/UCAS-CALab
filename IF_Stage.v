`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/09/22 19:30:38
// Design Name: 
// Module Name: IF_Stage
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


module IF_Stage(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire         inst_sram_en,
    output wire [ 3:0]  inst_sram_we,
    output wire [31:0]  inst_sram_addr,
    output wire [31:0]  inst_sram_wdata,
    input  wire [31:0]  inst_sram_rdata,
    // id to if stage signal
    input  wire         id_allowin,
    input  wire         br_taken,
    input  wire [31:0]  br_target,
    //if to id stage signal
    output wire         if_to_id_valid,
    output wire [63:0]  if_to_id_wire
);
    wire [31:0]  if_inst;
    reg  [31:0]  if_pc;
    
    wire                if_ready_go;
    reg                 if_valid;
    wire        [31:0]  seq_pc;
    wire         [31:0]  nextpc;
    
    wire                if_allowin;
    wire                to_if_valid;
    
//IF statge control signal

    assign if_ready_go      = 1'b1;
    assign if_allowin       = ~if_valid | if_ready_go & id_allowin;     
    assign if_to_id_valid   = if_valid & if_ready_go;
    assign to_if_valid      = resetn;
    
    always @(posedge clk) begin
        if(~resetn)
            if_valid <= 0; 
        else if(if_allowin)
            if_valid <= to_if_valid;// 在reset撤销的下一个时钟上升沿才开始取指
        else if(br_taken)
            if_valid <= 0;
    end
    
//inst sram signal
    assign inst_sram_en     = if_allowin & resetn;
    assign inst_sram_we     = 4'b0;
    assign inst_sram_addr   = nextpc;
    assign inst_sram_wdata  = 32'b0;

//pc relavant signals
    assign seq_pc           = if_pc + 3'h4; 
    assign nextpc           = br_taken ? br_target : seq_pc; 

//if to id stage signal
    always @(posedge clk) begin
        if(~resetn)
            if_pc <= 32'h1BFF_FFFC;
        else if(if_allowin)
            if_pc <= nextpc;
    end
    
    assign if_inst          = inst_sram_rdata;
    
    assign if_to_id_wire    = {if_inst, // 32-63
                               if_pc     // 0-31
                               };
    
endmodule
