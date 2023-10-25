`include "mycpu_head.h"

module WB_Stage(
    input  wire        clk,
    input  wire        resetn,
    // mem and wb state interface
    output wire        wb_allowin,
    input  wire [`MEM_TO_WB_DATA_WIDTH-1:0] mem_to_wb_data,
    input  wire [`MEM_TO_WB_EXCEP_WIDTH-1:0] mem_to_wb_excep,
    input  wire        mem_to_wb_valid,  
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    // id and wb state interface
    output wire [37:0] wb_rf_zip,

    output wire [`WB_TO_CSR_WIDTH-1:0] wb_to_csr_excep
);    
    reg  [`MEM_TO_WB_DATA_WIDTH-1:0] mem_to_wb_data_reg;
    reg  [`MEM_TO_WB_EXCEP_WIDTH-1:0] mem_to_wb_excep_reg; 
    
    wire        wb_ready_go;
    reg         wb_valid;
    wire [31:0] wb_pc;
    wire [31:0] wb_rf_wdata;
    wire [ 4:0] wb_rf_waddr;
    wire        wb_rf_we;
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
        if(mem_to_wb_valid & wb_allowin)begin
            mem_to_wb_data_reg <= mem_to_wb_data;
            mem_to_wb_excep_reg <= mem_to_wb_excep;
        end
    end
    
    assign {wb_rf_we,
            wb_rf_waddr,
            wb_rf_wdata,
            wb_pc
           } = mem_to_wb_data_reg;

//id and wb state interface
    assign wb_rf_zip = {wb_rf_we & wb_valid,
                        wb_rf_waddr,
                        wb_rf_wdata};
                        
//trace debug interface
    assign debug_wb_pc = wb_pc;
    assign debug_wb_rf_wdata = wb_rf_wdata;
    assign debug_wb_rf_we = {4{wb_rf_we & wb_valid}};
    assign debug_wb_rf_wnum = wb_rf_waddr;

modu
    
endmodule
