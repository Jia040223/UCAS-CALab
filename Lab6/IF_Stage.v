`include "mycpu_head.h"

module IF_Stage(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // id to if stage signal
    input  wire        id_allowin,
    input  wire        br_taken,
    input  wire [31:0] br_target,
    //if to id stage signal
    output wire        if_to_id_valid,
    output wire [`IF_TO_ID_DATA_WIDTH-1:0] if_to_id_data,
    output wire [`IF_TO_ID_EXCEP_WIDTH-1:0] if_to_id_excep
);
    wire [31:0] if_inst;
    reg  [31:0] if_pc;
    
    wire        if_ready_go;
    reg         if_valid;
    wire [31:0] seq_pc;
    wire [31:0] nextpc;
    
    wire        if_allowin;
    wire        to_if_valid;
    
//IF statge control signal
    assign if_ready_go      = 1'b1;
    assign if_allowin       = ~if_valid | if_ready_go & id_allowin;     
    assign if_to_id_valid   = if_valid & if_ready_go;
    assign to_if_valid      = resetn;
    
    always @(posedge clk) begin
        if(~resetn)
            if_valid <= 0; 
        else if(if_allowin)
            if_valid <= to_if_valid;// ��reset��������һ��ʱ�������زſ�ʼȡָ
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
    
    assign if_to_id_data    = {if_inst,     // 32-63
                               if_pc};      // 0-31
                               
    assign if_to_id_excep = 0;

endmodule
