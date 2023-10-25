`include "mycpu_head.h"

module MEM_Stage(
    input  wire        clk,
    input  wire        resetn,
    // exe and mem state interface
    output wire        mem_allowin,
    input  wire [`EX_TO_MEM_DATA_WIDTH-1:0] ex_to_mem_data
    input  wire [`EX_TO_MEM_EXCEP_WIDTH-1:0] ex_to_mem_excep, 
    input  wire        ex_to_mem_valid,

    // mem and wb state interface
    input  wire        wb_allowin,
    output wire [`MEM_TO_WB_DATA_WIDTH-1:0] mem_to_wb_data,
    output wire [`MEM_TO_WB_EXCEP_WIDTH-1:0] mem_to_wb_excep,
    output wire        mem_to_wb_valid,  
   
    input  wire [31:0] data_sram_rdata,
    
    input  wire [63:0] mul_result,
    output wire [37:0] mem_rf_zip
);
    reg  [`EX_TO_MEM_DATA_WIDTH-1:0] ex_to_mem_data_reg;
    reg  [`EX_TO_MEM_EXCEP_WIDTH-1:0] ex_to_mem_excep_reg;

    wire [31:0] mem_pc;
    wire        mem_ready_go;
    wire [31:0] mem_result;
    reg         mem_valid;
    wire [31:0] mem_rf_wdata;
    wire        mem_rf_we;
    wire [ 4:0] mem_rf_waddr;
    wire [31:0] mem_alu_result;

    wire        res_from_mem;
    wire        mem_inst_ld_b;
    wire        mem_inst_ld_bu;
    wire        mem_inst_ld_h;
    wire        mem_inst_ld_hu;
    wire        mem_inst_ld_w;

    wire [31:0] mem_ld_b_res;
    wire [31:0] mem_ld_h_res;
    wire [31:0] mem_ld_w_res;

    wire [31:0] div_result;
    wire        mul_h;

    wire [31:0] shift_rdata;

//stage control signal
    assign mem_ready_go     = 1'b1;
    assign mem_allowin      = ~mem_valid | mem_ready_go & wb_allowin;     
    assign mem_to_wb_valid  = mem_valid & mem_ready_go;

    always @(posedge clk) begin
        if(~resetn)
            mem_valid <= 1'b0;
        else if(mem_allowin)
            mem_valid <= ex_to_mem_valid; 
    end

//exe and mem state interface
    always @(posedge clk) begin
        if(ex_to_mem_valid & mem_allowin) begin
            ex_to_mem_data_reg <= ex_to_mem_data;
            ex_to_mem_excep_reg <= ex_to_mem_excep;
        end
    end
    
    assign {mem_rf_we, mem_rf_waddr,
            mem_pc,
            mem_alu_result,
            mem_inst_ld_b, mem_inst_ld_bu, mem_inst_ld_h, mem_inst_ld_hu, mem_inst_ld_w,
            res_from_mul, mul_h, res_from_div, div_result
            } = ex_to_mem_data_reg;
    
//mem and wb state interface
    assign shift_rdata   = {24'b0, data_sram_rdata} >> {mem_alu_result[1:0], 3'b0};

    assign mem_result[ 7: 0]   =  shift_rdata[ 7: 0];

    assign mem_result[15: 8]   =  {8{mem_inst_ld_b & shift_rdata[7]}} |
                                  {8{~mem_inst_ld_b & ~mem_inst_ld_bu}} & shift_rdata[15: 8];

    assign mem_result[31:16]   =  {16{mem_inst_ld_b & shift_rdata[7]}} |
                                  {16{mem_inst_ld_h & shift_rdata[15]}} |
                                  {16{mem_inst_ld_w}} & shift_rdata[31:16];

    assign res_from_mem = mem_inst_ld_b || mem_inst_ld_bu || mem_inst_ld_h || mem_inst_ld_hu || mem_inst_ld_w;

    assign mem_rf_wdata     = {32{res_from_mem}} & mem_result |
                              {32{mul_h}} & mul_result[63:32] |
                              {32{~mul_h & res_from_mul}} & mul_result[31:0] |
                              {32{res_from_div}} & div_result |
                              {32{~res_from_div & ~res_from_mul & ~res_from_mem}} & mem_alu_result;
    
    assign mem_to_wb_data = {mem_rf_we,
                             mem_rf_waddr,
                             mem_rf_wdata,
                             mem_pc};
                             
    assign mem_rf_zip      = {mem_rf_we & mem_valid,
                              mem_rf_waddr,
                              mem_rf_wdata};
    
endmodule

