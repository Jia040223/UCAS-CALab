module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    wire        id_allowin;
    wire        ex_allowin;
    wire        mem_allowin;
    wire        wb_allowin;

    wire        if_to_id_valid;
    wire        id_to_ex_valid;
    wire        ex_to_mem_valid;
    wire        mem_to_wb_valid;
    
    wire [63:0] if_to_id_wire;
    wire [147:0] id_to_ex_wire;
    wire [103:0] ex_to_mem_wire;
    wire [69:0] mem_to_wb_wire;
    
    wire        ex_mem_we;
    wire        ex_res_from_mem;
    wire [31:0] ex_rkd_value;
    wire [31:0] ex_alu_result;
    
    wire [37:0] wb_rf_zip;
    wire [37:0] mem_rf_zip;
    wire [38:0] ex_rf_zip;

    wire        br_taken;
    wire [31:0] br_target;

    IF_Stage my_IF_Stage
    (
        .clk(clk),
        .resetn(resetn),

        .inst_sram_en(inst_sram_en),
        .inst_sram_we(inst_sram_we),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_rdata(inst_sram_rdata),
        
        .id_allowin(id_allowin),
        .br_taken(br_taken),
        .br_target(br_target),
        
        .if_to_id_valid(if_to_id_valid),
        .if_to_id_wire(if_to_id_wire)
    );

    ID_Stage my_ID_Stage
    (
        .clk(clk),
        .resetn(resetn),

        .id_allowin(id_allowin),
        .br_taken(br_taken),
        .br_target(br_target),
        .if_to_id_valid(if_to_id_valid),
        .if_to_id_wire(if_to_id_wire),

        .ex_allowin(ex_allowin),
        .id_to_ex_wire(id_to_ex_wire),
        .id_to_ex_valid(id_to_ex_valid),
      
        .wb_rf_zip(wb_rf_zip),
        .mem_rf_zip(mem_rf_zip),
        .ex_rf_zip(ex_rf_zip)
    );

    EX_Stage my_EX_Stage
    (
        .clk(clk),
        .resetn(resetn),
        
        .ex_allowin(ex_allowin),
        .id_to_ex_wire(id_to_ex_wire),
        .id_to_ex_valid(id_to_ex_valid),
        
        .mem_allowin(mem_allowin),
        .ex_to_mem_valid(ex_to_mem_valid),
        .ex_to_mem_wire(ex_to_mem_wire),
   
        .data_sram_en(data_sram_en),
        .data_sram_we(data_sram_we),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        
        .ex_rf_zip(ex_rf_zip)
     );

    MEM_Stage my_MEM_Stage
    (
        .clk(clk),
        .resetn(resetn),

        .mem_allowin(mem_allowin),
        .ex_to_mem_wire(ex_to_mem_wire),
        .ex_to_mem_valid(ex_to_mem_valid),
        
        .wb_allowin(wb_allowin),
        .mem_to_wb_wire(mem_to_wb_wire),
        .mem_to_wb_valid(mem_to_wb_valid),
        
        .data_sram_rdata(data_sram_rdata),
        
        .mem_rf_zip(mem_rf_zip)
    ) ;

    WB_Stage my_WB_Stage
    (
        .clk(clk),
        .resetn(resetn),

        .wb_allowin(wb_allowin),
        .mem_to_wb_wire(mem_to_wb_wire),
        .mem_to_wb_valid(mem_to_wb_valid),

        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata),

        .wb_rf_zip(wb_rf_zip)
    );
    
endmodule