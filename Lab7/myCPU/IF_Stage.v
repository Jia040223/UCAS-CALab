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

    input  wire [ 3:0] axi_arid,
    // id to if stage signal
    input  wire        id_allowin,
    input  wire        br_taken,
    input  wire        br_stall,
    input  wire [31:0] br_target,
    //if to id stage signal
    output wire        if_to_id_valid,
    output wire [`IF_TO_ID_DATA_WIDTH-1:0] if_to_id_data,
    output wire [`IF_TO_ID_EXCEP_WIDTH-1:0] if_to_id_excep,

    input  wire [`WB_TO_IF_CSR_DATA_WIDTH -1:0] wb_to_if_csr_data,
    input  wire        if_flush
);
    wire [31:0] if_inst;
    wire [31:0] if_to_id_inst;
    reg  [31:0] if_pc;
    wire [31:0] seq_pc;
    wire [31:0] nextpc;

    reg  [31:0] if_inst_reg;
    reg         if_inst_reg_valid;
    reg [3:0]   inst_cancel_num; 
    wire        inst_cancel;   
    reg         preif_cancel;

    wire        if_ready_go;
    reg         if_valid;
    wire        if_allowin;

    wire        preif_ready_go;
    wire        to_if_valid;

    wire [31:0] csr_rvalue;
    wire [31:0] ex_entry;
    wire        wb_ertn_flush_valid;
    wire        wb_csr_ex_valid;
    wire        if_adef_excep;
    
    reg [31:0] csr_rvalue_reg;
    reg [31:0] ex_entry_reg;
    reg [31:0] br_target_reg;

    reg        wb_ertn_flush_valid_reg;
    reg        wb_csr_ex_valid_reg;
    reg        br_taken_reg;
    
//IF statge control signal
    assign preif_ready_go   = inst_sram_req & inst_sram_addr_ok;
    assign to_if_valid      = preif_ready_go & if_allowin & ~preif_cancel & ~if_flush;

    assign if_ready_go      = (inst_sram_data_ok | if_inst_reg_valid) & ~inst_cancel;
    assign if_allowin       = ~if_valid | if_ready_go & id_allowin | if_flush;     
    assign if_to_id_valid   = if_valid & if_ready_go & ~if_flush;
    
    always @(posedge clk) begin
        if(~resetn)
            if_valid <= 0; 
        else if(if_allowin)
            if_valid <= to_if_valid;            
        else if(br_taken | br_taken_reg)
            if_valid <= 0;
    end
       
//inst sram signal
    assign inst_sram_req = if_allowin & resetn & ~br_stall & ~preif_cancel;
    assign inst_sram_wr = 1'b0;
    assign inst_sram_size = 2'b10;
    assign inst_sram_wstrb = 4'b0;
    assign inst_sram_addr = nextpc;
    assign inst_sram_wdata = 32'b0;

//pc relevant signals
    assign seq_pc           = if_pc + 3'h4; 
    assign nextpc           =   wb_ertn_flush_valid_reg ? csr_rvalue_reg
                              : wb_ertn_flush_valid ? csr_rvalue  //era
                              : wb_csr_ex_valid_reg ? ex_entry_reg
                              : wb_csr_ex_valid ? ex_entry
                              : br_taken_reg ? br_target_reg
                              : br_taken ? br_target 
                              : seq_pc; 
    assign if_adef_excep    = if_valid & (|nextpc[1:0]);

// store pc relevant pc if preif_ready_go isn't high and next_pc shouldnt'be pc + 4
    always @(posedge clk) begin
        if (~resetn) begin
            csr_rvalue_reg <= 32'b0;
            wb_ertn_flush_valid_reg <= 1'b0;
        end
        else if(wb_ertn_flush_valid) begin
            csr_rvalue_reg <= csr_rvalue;
            wb_ertn_flush_valid_reg <= 1'b1;
        end
        else if (preif_ready_go)
            wb_ertn_flush_valid_reg <= 1'b0;
    end

    always @(posedge clk) begin
        if (~resetn) begin
            ex_entry_reg <= 32'b0;
            wb_csr_ex_valid_reg <= 1'b0;
        end
        else if(wb_csr_ex_valid) begin
            ex_entry_reg <= ex_entry;
            wb_csr_ex_valid_reg <= 1'b1;
        end
        else if (preif_ready_go)
            wb_csr_ex_valid_reg <= 1'b0;
    end

    always @(posedge clk) begin
        if (~resetn) begin
            br_target_reg <= 32'b0;
            br_taken_reg <= 1'b0;
        end
        else if(br_taken & ~br_stall) begin
            br_target_reg <= br_target;
            br_taken_reg <= 1'b1;
        end
        else if (preif_ready_go)
            br_taken_reg <= 1'b0;
    end

//if to id stage signal
    always @(posedge clk) begin
        if(~resetn)
            if_pc <= 32'h1BFF_FFFC;
        else if(to_if_valid & if_allowin)
            if_pc <= nextpc;
    end
    
    assign {wb_ertn_flush_valid, wb_csr_ex_valid, ex_entry, csr_rvalue} = wb_to_if_csr_data;

    reg if_flush_reg;

    always @(posedge clk) begin
        if(~resetn)
            if_flush_reg <= 1'b0;
        else if(if_flush)
            if_flush_reg <= 1'b1;
        else if(to_if_valid & if_allowin)
            if_flush_reg <= 1'b0;
    end
    assign inst_cancel = if_flush | if_flush_reg | br_taken & ~br_stall | br_taken_reg;

    always @(posedge clk) begin
        if (reset) begin
            br_stall_reg <= 1'b0;
        end else if (br_stall) begin
            br_stall_reg <= br_stall;
        end else if (to_fs_valid && fs_allowin)begin
            br_stall_reg <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (~resetn)
            preif_cancel <= 1'b0;
        else if (inst_sram_req & (wb_csr_ex_valid | wb_ertn_flush_valid | br_taken | (br_stall | br_stall_reg) & inst_sram_addr_ok ) & ~preif_cancel & ~axi_arid[0])
            preif_cancel <= 1'b1;
        else if (inst_sram_data_ok)
            preif_cancel <= 1'b0;
    end


    always @(posedge clk) begin
        if (~resetn) begin
            if_inst_reg <= 32'b0;
            if_inst_reg_valid <= 1'b0;
        end
        else if (if_to_id_valid & id_allowin | (wb_csr_ex_valid | wb_ertn_flush_valid | br_taken)) //inst has been passed to ID or canceled
            if_inst_reg_valid <= 1'b0;
        else if (~if_inst_reg_valid & inst_sram_data_ok & ~inst_cancel) begin
            if_inst_reg_valid <= 1'b1;
            if_inst_reg <= if_to_id_inst;
        end
    end

    assign if_inst          = (inst_sram_data_ok & ~inst_cancel) ? inst_sram_rdata : if_inst_reg;
    assign if_to_id_inst    = (if_inst_reg_valid)? if_inst_reg : if_inst;
    
    assign if_to_id_data    = {if_to_id_inst,     // 32-63
                               if_pc};      // 0-31   

    assign if_to_id_excep = if_adef_excep;

endmodule