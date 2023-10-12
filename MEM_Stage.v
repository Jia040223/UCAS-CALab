`timescale 1ns / 1ps
`include "mycpu_head.h"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/09/22 19:32:00
// Design Name: 
// Module Name: MEM_Stage
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


module MEM_Stage(
    input  wire        clk,
    input  wire        resetn,
    // exe and mem state interface
    output wire        mem_allowin,
    input  wire [`EX_TO_MEM_WIDTH-1:0] ex_to_mem_wire,
    input  wire        ex_to_mem_valid,

    // mem and wb state interface
    input  wire        wb_allowin,
    output wire [`MEM_TO_WB_WIDTH-1:0] mem_to_wb_wire,
    output wire        mem_to_wb_valid,  
   
    input  wire [31:0] data_sram_rdata,
    
    output wire [37:0] mem_rf_zip
);
    reg  [`EX_TO_MEM_WIDTH - 1:0] ex_to_mem_reg;
    
    wire [31:0] mem_pc;
    wire        mem_ready_go;
    wire [31:0] mem_result;
    reg         mem_valid;
    wire [31:0] mem_rf_wdata;
    wire [ 4:0] mem_rf_waddr;
    wire [31:0] mem_alu_result;
    wire        mem_res_from_mem;

//stage control signal
    assign mem_ready_go      = 1'b1;
    assign mem_allowin       = ~mem_valid | mem_ready_go & wb_allowin;     
    assign mem_to_wb_valid  = mem_valid & mem_ready_go;
    assign mem_rf_wdata     = mem_res_from_mem ? mem_result : mem_alu_result;

    always @(posedge clk) begin
        if(~resetn)
            mem_valid <= 1'b0;
        else if(mem_allowin)
            mem_valid <= ex_to_mem_valid; 
    end

//exe and mem state interface
    

    always @(posedge clk) begin
        if(ex_to_mem_valid & mem_allowin)
            ex_to_mem_reg <= ex_to_mem_wire;
    end
    
    assign {mem_rf_we,
            mem_rf_waddr,
            mem_pc,
            mem_alu_result,
            mem_res_from_mem
            } = ex_to_mem_reg;
    
//mem and wb state interface
    assign mem_result   = data_sram_rdata;
    
    assign mem_to_wb_wire = {mem_rf_we,
                             mem_rf_waddr,
                             mem_rf_wdata,
                             mem_pc};
                             
    assign mem_rf_zip      = {mem_rf_we & mem_valid,
                              mem_rf_waddr,
                              mem_rf_wdata};
    
endmodule
