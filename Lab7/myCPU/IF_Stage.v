`include "mycpu_head.h"

module IF_Stage(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [ 1:0] inst_sram_size,
    output wire [ 3:0] inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,
    input  wire [31:0] inst_sram_rdata,
    // id to if stage signal
    input  wire        id_allowin,
    input  wire        br_taken,
    input  wire        br_stall,
    input  wire [31:0] br_target,
    //if to id stage signal
    output wire        if_to_id_valid,
    output wire [`IF_TO_ID_DATA_WIDTH-1:0] if_to_id_data,
    output wire [`IF_TO_ID_EXCEP_WIDTH-1:0] if_to_id_excep,

    input wire [`WB_TO_IF_CSR_DATA_WIDTH -1:0] wb_to_if_csr_data,
    input  wire        if_flush
);
    wire [31:0] if_inst;
    wire [31:0] if_to_id_inst;
    reg  [31:0] if_pc;
    wire [31:0] seq_pc;
    wire [31:0] nextpc;

    reg  [31:0] if_inst_reg;
    reg         if_inst_reg_valid;
    
    wire        if_ready_go;
    reg         if_valid;
    wire        if_allowin;

    reg         preif_valid;
    wire        preif_allowin;
    wire        preif_ready_go;
    wire        to_if_valid;

    wire [31:0] csr_rvalue;
    wire [31:0] ex_entry;
    wire        wb_ertn_flush_valid;
    wire        wb_csr_ex_valid;
    wire        if_adef_excep;
    
//IF statge control signal
    assign preif_allowin    = ~preif_valid | preif_ready_go & if_allowin | if_flush;
    assign preif_ready_go   = inst_sram_req & inst_sram_addr_ok | preif_valid;
    assign to_if_valid      = preif_ready_go & if_allowin & ~if_flush;

    assign if_ready_go      = inst_sram_data_ok | if_inst_reg_valid;
    assign if_allowin       = ~if_valid | if_ready_go & id_allowin | if_flush;     
    assign if_to_id_valid   = if_valid & if_ready_go & ~if_flush;
    
    always @(posedge clk) begin
        if(~resetn)
            preif_valid <= 0; 
        else if(preif_allowin)
            preif_valid <= inst_sram_addr_ok;
        else if(br_taken)
            preif_valid <= 0;    
    end
    
    always @(posedge clk) begin
        if(~resetn)
            if_valid <= 0; 
        else if(if_allowin)
            if_valid <= to_if_valid;// ��reset��������һ��ʱ�������زſ�ʼȡָ
        else if(br_taken)
            if_valid <= 0;
    end
    
//inst sram signal
    assign inst_sram_req = preif_allowin & if_allowin & resetn & ~br_stall;
    assign inst_sram_wr = 1'b0;
    assign inst_sram_size = 2'b10;
    assign inst_sram_wstrb = 4'b0;
    assign inst_sram_addr = nextpc;
    assign inst_sram_wdata = 32'b0;

//pc relavant signals
    assign seq_pc           = (to_if_valid) ? (if_pc + 3'h4) : if_pc; 
    assign nextpc           =   wb_ertn_flush_valid ? csr_rvalue  //era
                              : wb_csr_ex_valid ? ex_entry
                              : br_taken ? br_target 
                              : seq_pc; 
    assign if_adef_excep    = if_valid & (|nextpc[1:0]);

//if to id stage signal
    always @(posedge clk) begin
        if(~resetn)
            if_pc <= 32'h1BFF_FFFC;
        else if(if_allowin)
            if_pc <= nextpc;
    end

    always @(posedge clk) begin
        if(~resetn)
            if_inst_reg <= 32'b0;
        else if(inst_sram_data_ok)
            if_inst_reg <= if_inst;
    end

    always @(posedge clk) begin
        if(~resetn)
            if_inst_reg_valid <= 1'b0;
        else
            if_inst_reg_valid <= if_ready_go & ~id_allowin;
    end 
    
    assign {wb_ertn_flush_valid, wb_csr_ex_valid, ex_entry, csr_rvalue} = wb_to_if_csr_data;

    assign if_inst          = inst_sram_rdata;
    assign if_to_id_inst    = (if_inst_reg_valid)? if_inst_reg : if_inst;
    
    assign if_to_id_data    = {if_to_id_inst,     // 32-63
                               if_pc};      // 0-31   

    assign if_to_id_excep = if_adef_excep;

endmodule
