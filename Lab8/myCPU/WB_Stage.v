`include "mycpu_head.h"

module WB_Stage(
    input  wire        clk,
    input  wire        resetn,
    // mem and wb state interface
    output wire        wb_allowin,
    input  wire [ `MEM_TO_WB_DATA_WIDTH-1:0] mem_to_wb_data,
    input  wire [`MEM_TO_WB_EXCEP_WIDTH-1:0] mem_to_wb_excep,
    input  wire [  `MEM_TO_WB_TLB_WIDTH-1:0] mem_to_wb_tlb,
    input  wire        mem_to_wb_valid,  
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    // id and wb stage interface
    output wire [37:0] wb_rf_zip,
    output wire [`WB_TO_IF_CSR_DATA_WIDTH -1:0] wb_to_if_csr_data,
    //flush
    output wire        wb_flush,

    //exp13 csr
    output wire [13:0] wb_csr_num,
    output wire        wb_csr_we,
    output wire [31:0] wb_csr_wmask,
    output wire [31:0] wb_csr_wvalue,
    output wire        wb_ertn_flush_valid,
    output wire        wb_excep_valid,
    output wire [ 5:0] wb_csr_ecode,
    output wire [ 8:0] wb_csr_esubcode,
    output wire [31:0] wb_pc,

    input  wire [31:0] csr_rvalue,
    input  wire [31:0] ex_entry,

    output wire        ipi_int_in,
    output wire [ 7:0] hw_int_in,
    output wire [31:0] coreid_in,
    output wire [31:0] wb_vaddr,
    input  wire        has_int,

    //exp18
    output wire         wb_csr_tlbrd,
    input  wire  [ 3:0] csr_tlbidx_index, // from csr
    // tlbrd
    output wire         tlbrd_we, // to csr
    output wire  [ 3:0] r_index,  // to tlb
    
    // tlbwr and tlbfill, to tlb
    output wire  [ 3:0] w_index,
    output wire         tlb_we,

    // tlbsrch, to csr
    output wire         tlbsrch_we,
    output wire         tlbsrch_hit,
    output wire  [ 3:0] tlbsrch_hit_index,

    input  wire  [ 3:0] ex_to_wb_rand
);    
    reg  [ `MEM_TO_WB_DATA_WIDTH-1:0] mem_to_wb_data_reg;
    reg  [`MEM_TO_WB_EXCEP_WIDTH-1:0] mem_to_wb_excep_reg; 
    reg  [  `MEM_TO_WB_TLB_WIDTH-1:0] mem_to_wb_tlb_reg;
    
    wire        wb_ready_go;
    reg         wb_valid;
    wire [31:0] wb_rf_result;
    wire [31:0] wb_rf_wdata;
    wire [ 4:0] wb_rf_waddr;
    wire        wb_rf_we;

    wire        wb_res_from_csr;
    wire        wb_ertn_flush;
    wire        wb_excep;

    wire        wb_has_int;
    wire        wb_excp_adef;
    wire        wb_excp_syscall;
    wire        wb_excp_break;
    wire        wb_excp_ale;
    wire        wb_excp_ine;

    wire        wb_inst_tlbsrch;
    wire        wb_inst_tlbwr;
    wire        wb_inst_tlbfill;
    wire        wb_inst_tlbrd;
    wire        wb_inst_invtlb;

    wire        wb_tlb_refetch;

    wire        wb_tlbwr_valid;
    wire        wb_tlbfill_valid;
    wire        wb_tlbrd_valid;
    wire        wb_invtlb_valid;

    wire        wb_csr_tlbwr;
    wire        wb_s1_found;
    wire [ 3:0] wb_s1_index;

//-----stage control signal-----
    assign wb_ready_go      = 1'b1;
    assign wb_allowin       = ~wb_valid | wb_ready_go ;     

    always @(posedge clk) begin
        if(~resetn)
            wb_valid <= 1'b0;
        else if(wb_allowin)
            wb_valid <= mem_to_wb_valid; 
    end

//-----MEM and WB state interface-----
    always @(posedge clk) begin
        if(mem_to_wb_valid & wb_allowin) begin
            mem_to_wb_data_reg  <= mem_to_wb_data;
            mem_to_wb_excep_reg <= mem_to_wb_excep;
            mem_to_wb_tlb_reg   <= mem_to_wb_tlb;
        end
    end
    
    assign {wb_rf_we,
            wb_rf_waddr,
            wb_rf_result,
            wb_pc
           } = mem_to_wb_data_reg;

    //exception
    assign wb_excep = wb_excp_adef | wb_excp_syscall | wb_excp_break | wb_excp_ale | wb_excp_ine | wb_has_int;
    
    assign {wb_res_from_csr, wb_csr_num, wb_csr_we, wb_csr_wmask, wb_csr_wvalue, 
            wb_ertn_flush, wb_has_int, wb_excp_adef, wb_excp_syscall, wb_excp_break,
            wb_excp_ale, wb_vaddr, wb_excp_ine
            } = mem_to_wb_excep_reg;
    
    assign {wb_s1_found, wb_s1_index, 
            wb_inst_tlbsrch, wb_inst_tlbwr, wb_inst_tlbfill, wb_inst_tlbrd, wb_inst_invtlb} = mem_to_wb_tlb_reg;

//-----WB to ID data(backward)----- 
    assign wb_rf_wdata = (wb_res_from_csr)? csr_rvalue : wb_rf_result;

    assign wb_rf_zip = {wb_rf_we & wb_valid & ~wb_excep,
                        wb_rf_waddr,
                        wb_rf_wdata};
                        
//-----CSR relavant signals and data----- 
    assign wb_csr_ecode = wb_has_int        ? `ECODE_INT :
                          wb_excp_adef      ? `ECODE_ADEF :
                          wb_excp_ine       ? `ECODE_INE :
                          wb_excp_syscall   ? `ECODE_SYS :
                          wb_excp_break     ? `ECODE_BRK :
                          wb_excp_ale       ? `ECODE_ALE :
                          6'b0;
    assign wb_csr_esubcode = 9'b0;

    assign wb_ertn_flush_valid  = wb_ertn_flush & wb_valid;
    assign wb_excep_valid       = wb_excep & wb_valid;

    assign wb_tlbwr_valid       = wb_inst_tlbwr & wb_valid;
    assign wb_tlbfill_valid     = wb_inst_tlbfill & wb_valid;
    assign wb_tlbrd_valid       = wb_inst_tlbrd & wb_valid;
    assign wb_invtlb_valid      = wb_inst_invtlb & wb_valid;
    assign wb_csr_tlbwr         = ((wb_csr_num == `CSR_ASID || wb_csr_num == `CSR_CRMD) 
                                    && wb_csr_we) && wb_valid;
    
    assign wb_tlb_refetch       = wb_tlbwr_valid | wb_tlbfill_valid | wb_tlbrd_valid | wb_invtlb_valid | wb_csr_tlbwr;

    assign wb_csr_tlbrd = ((wb_csr_num == `CSR_ASID || wb_csr_num == `CSR_TLBEHI) && wb_csr_we
                            || wb_inst_tlbrd) && wb_valid;


    assign ipi_int_in   = 1'b0;
    assign hw_int_in    = 8'b0;
    assign coreid_in    = 32'b0;

    //WB to IF data
    assign wb_to_if_csr_data = {wb_ertn_flush_valid, wb_excep_valid, wb_tlb_refetch, ex_entry, csr_rvalue, wb_pc};


    //flush pipline
    assign wb_flush = wb_ertn_flush_valid | wb_excep_valid | wb_tlb_refetch;

//-----TLB relavant signals-----
    // tlbrd
    assign tlbrd_we = wb_inst_tlbrd;
    assign r_index = csr_tlbidx_index;

    // tlbwr and tlbfill
    assign w_index = wb_inst_tlbwr ? csr_tlbidx_index : ex_to_wb_rand;
    assign tlb_we = wb_inst_tlbwr | wb_inst_tlbfill;

    // tlbsrch
    assign tlbsrch_we = wb_inst_tlbsrch;
    assign tlbsrch_hit = wb_s1_found;
    assign tlbsrch_hit_index = wb_s1_index;
    
//-----trace debug interface-----
    assign debug_wb_pc = wb_pc;
    assign debug_wb_rf_wdata = wb_rf_wdata;
    assign debug_wb_rf_we = {4{wb_rf_we & wb_valid & ~wb_excep}};
    assign debug_wb_rf_wnum = wb_rf_waddr;
    
endmodule
