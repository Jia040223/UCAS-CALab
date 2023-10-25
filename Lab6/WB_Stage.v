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

    output wire [`WB_TO_IF_CSR_DATA_WIDTH -1:0] wb_to_if_csr_data,
    //flush
    output wire        wb_flush
);    
    reg  [`MEM_TO_WB_DATA_WIDTH-1:0] mem_to_wb_data_reg;
    reg  [`MEM_TO_WB_EXCEP_WIDTH-1:0] mem_to_wb_excep_reg; 
    
    wire        wb_ready_go;
    reg         wb_valid;
    wire [31:0] wb_pc;
    wire [31:0] wb_rf_result;
    wire [31:0] wb_rf_wdata;
    wire [ 4:0] wb_rf_waddr;
    wire        wb_rf_we;

    wire        wb_inst_csrrd;
    wire        wb_inst_csrwr;
    wire        wb_inst_csrxchg;
    wire [13:0] wb_csr_num;
    wire        wb_csr_ex;
    wire [31:0] wb_rj_value;
    wire [31:0] wb_rkd_value;

    wire        wb_res_from_csr;
    wire [13:0] wb_csr_num;
    wire        wb_csr_we;
    wire [31:0] wb_csr_wmask;
    wire [31:0] wb_csr_wvalue;
    wire        wb_ertn_flush;
    wire        wb_csr_ex;
    wire [ 5:0] wb_csr_ecode;
    wire [ 8:0] wb_csr_esubcode;

    wire [31:0] csr_rvalue;
    wire [31:0] ex_entry;
    wire        wb_ertn_flush_valid;
    wire        wb_csr_ex_valid;
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
            wb_rf_result,
            wb_pc
           } = mem_to_wb_data_reg;
    
    assign {wb_res_from_csr, wb_csr_num, wb_csr_we, wb_csr_wmask, wb_csr_wvalue, 
            wb_ertn_flush, wb_csr_ex, wb_csr_ecode, wb_csr_esubcode
            } = mem_to_wb_excep_reg;

//id and wb state interface
    assign wb_rf_wdata = (wb_res_from_csr)? csr_rvalue : wb_rf_result;

    assign wb_rf_zip = {wb_rf_we & wb_valid,
                        wb_rf_waddr,
                        wb_rf_wdata};
                        
//csr
    assign wb_ertn_flush_valid = wb_ertn_flush & wb_valid;
    assign wb_csr_ex_valid = wb_csr_ex & wb_valid;

    csr my_csr(
        .clk(clk),
        .resetn(resetn),
        .csr_num(wb_csr_num),
        .csr_we(wb_csr_we),
        .csr_wmask(wb_csr_wmask),
        .csr_wvalue(wb_csr_wvalue),
        .ertn_flush(wb_ertn_flush_valid),
        .wb_ex(wb_csr_ex_valid),
        .wb_ecode(wb_csr_ecode), 
        .wb_esubcode(wb_csr_esubcode), 
        .wb_pc(wb_pc),
        .csr_rvalue(csr_rvalue),
        .ex_entry(ex_entry)
    );

    assign wb_flush = wb_ertn_flush_valid | wb_csr_ex_valid;

    assign wb_to_if_csr_data = {wb_ertn_flush_valid, wb_csr_ex_valid, ex_entry, csr_rvalue};

//trace debug interface
    assign debug_wb_pc = wb_pc;
    assign debug_wb_rf_wdata = wb_rf_wdata;
    assign debug_wb_rf_we = {4{wb_rf_we & wb_valid}};
    assign debug_wb_rf_wnum = wb_rf_waddr;
    
endmodule
