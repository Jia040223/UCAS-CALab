`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/09/22 19:31:42
// Design Name: 
// Module Name: WB_Stage
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


module WB_Stage(
    input  wire        clk,
    input  wire        resetn,
    // mem and wb state interface
    output wire        wb_allowin,
    input  wire [69:0] mem_to_wb_wire, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata}
    input  wire        mem_to_wb_valid,  
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    // id and wb state interface
    output wire [37:0] wb_rf_zip  // {rf_we, rf_waddr, rf_wdata}
);    
    reg [69:0] mem_to_wb_reg;
    
    wire        wb_ready_go;
    reg         wb_valid;
    wire  [31:0] wb_pc;
    wire  [31:0] wb_rf_wdata;
    wire  [4 :0] wb_rf_waddr;
    wire         wb_rf_we;
//stage control signal

    assign wb_ready_go      = 1'b1;
    assign wb_allowin       = ~wb_valid | wb_ready_go ;     

    always @(posedge clk) begin
        if(~resetn)
            wb_valid <= 1'b0;
        else if(wb_allowin)
            wb_valid <= mem_to_wb_valid; 
    end

//mem and wb state interface
    always @(posedge clk) begin
        if(mem_to_wb_valid & wb_allowin)
            mem_to_wb_reg <= mem_to_wb_wire;
    end
    
    assign {wb_rf_we,
            wb_rf_waddr,
            wb_rf_wdata,
            wb_pc
           } = mem_to_wb_reg;

//id and wb state interface
    assign wb_rf_zip = {wb_rf_we & wb_valid,
                        wb_rf_waddr,
                        wb_rf_wdata};
                        
//trace debug interface
    assign debug_wb_pc = wb_pc;
    assign debug_wb_rf_wdata = wb_rf_wdata;
    assign debug_wb_rf_we = {4{wb_rf_we & wb_valid}};
    assign debug_wb_rf_wnum = wb_rf_waddr;
    
endmodule
