`include "mycpu_head.h"

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
    
    input  wire [63:0] mul_result,
    output wire [37:0] mem_rf_zip
);
    reg  [`EX_TO_MEM_WIDTH-1:0] ex_to_mem_reg;
    
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

    wire [31:0] div_result;
    wire        mul_h;

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
        if(ex_to_mem_valid & mem_allowin)
            ex_to_mem_reg <= ex_to_mem_wire;
    end
    
    assign {mem_rf_we, mem_rf_waddr,
            mem_pc,
            mem_alu_result,
            mem_inst_ld_b, mem_inst_ld_bu, mem_inst_ld_h, mem_inst_ld_hu, mem_inst_ld_w,
            res_from_mul, mul_h, res_from_div, div_result
            } = ex_to_mem_reg;
    
//mem and wb state interface
    wire ld_addr00 = mem_alu_result[1:0] == 2'b00;
    wire ld_addr01 = mem_alu_result[1:0] == 2'b01;
    wire ld_addr10 = mem_alu_result[1:0] == 2'b10;
    wire ld_addr11 = mem_alu_result[1:0] == 2'b11;

    wire [ 7:0] data_sram_rdata_8bit = {8{ld_addr00}} & data_sram_rdata[ 7: 0] |
                                       {8{ld_addr01}} & data_sram_rdata[15: 8] |
                                       {8{ld_addr10}} & data_sram_rdata[23:16] |
                                       {8{ld_addr11}} & data_sram_rdata[31:24];

    wire [15:0] data_sram_rdata_16bit = {16{ld_addr00}} & data_sram_rdata[15: 0] |
                                        {16{ld_addr10}} & data_sram_rdata[31: 16];

    assign res_from_mem = mem_inst_ld_b || mem_inst_ld_bu || mem_inst_ld_h || mem_inst_ld_hu || mem_inst_ld_w;
    assign mem_result = {32{mem_inst_ld_b}} & {{24{data_sram_rdata_8bit[7]}}, data_sram_rdata_8bit} |
                        {32{mem_inst_ld_bu}} & {24'b0, data_sram_rdata_8bit} |
                        {32{mem_inst_ld_h}} & {{16{data_sram_rdata_16bit[15]}}, data_sram_rdata_16bit} |
                        {32{mem_inst_ld_hu}} & {16'b0, data_sram_rdata_16bit} |
                        {32{mem_inst_ld_w}} & data_sram_rdata;

    assign mem_rf_wdata     = res_from_mem ? mem_result : 
                              mul_h        ? mul_result[63:32] :
                              res_from_mul ? mul_result[31:0] :
                              res_from_div ? div_result :
                              mem_alu_result;
    
    assign mem_to_wb_wire = {mem_rf_we,
                             mem_rf_waddr,
                             mem_rf_wdata,
                             mem_pc};
                             
    assign mem_rf_zip      = {mem_rf_we & mem_valid,
                              mem_rf_waddr,
                              mem_rf_wdata};
    
endmodule

