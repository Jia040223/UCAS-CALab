`include "mycpu_head.h"

module MEM_Stage(
    input  wire        clk,
    input  wire        resetn,
    // exe and mem state interface
    output wire        mem_allowin,
    input  wire [ `EX_TO_MEM_DATA_WIDTH-1:0] ex_to_mem_data,
    input  wire [`EX_TO_MEM_EXCEP_WIDTH-1:0] ex_to_mem_excep, 
    input  wire [  `EX_TO_MEM_TLB_WIDTH-1:0] ex_to_mem_tlb,
    input  wire        ex_to_mem_valid,

    // mem and wb state interface
    input  wire        wb_allowin,
    output wire [ `MEM_TO_WB_DATA_WIDTH-1:0] mem_to_wb_data,
    output wire [`MEM_TO_WB_EXCEP_WIDTH-1:0] mem_to_wb_excep,
    output wire [ `MEM_TO_WB_TLB_WIDTH-1:0 ] mem_to_wb_tlb,
    output wire        mem_to_wb_valid,  
   
    input  wire        data_sram_data_ok,
    input  wire [31:0] data_sram_rdata,
    
    input  wire [63:0] mul_result,
    output wire [39:0] mem_rf_zip,

    input  wire        mem_flush,
    output wire        mem_to_ex_excep,

    output wire        mem_csr_tlbrd  
);
    reg  [ `EX_TO_MEM_DATA_WIDTH-1:0] ex_to_mem_data_reg;
    reg  [`EX_TO_MEM_EXCEP_WIDTH-1:0] ex_to_mem_excep_reg;
    reg  [  `EX_TO_MEM_TLB_WIDTH-1:0] ex_to_mem_tlb_reg;

    wire [31:0] mem_pc;
    wire        mem_ready_go;
    wire [31:0] mem_result;
    reg         mem_valid;
    wire [31:0] mem_rf_wdata;
    wire        mem_rf_we;
    wire [ 4:0] mem_rf_waddr;
    wire [31:0] mem_final_result;

    wire        mem_data_sram_req;
    wire        res_from_mem;
    wire        mem_inst_ld_b;
    wire        mem_inst_ld_bu;
    wire        mem_inst_ld_h;
    wire        mem_inst_ld_hu;
    wire        mem_inst_ld_w;

    wire [31:0] div_result;
    wire        mul_h;

    wire [31:0] shift_rdata;

    wire        mem_res_from_mem;
    wire        mem_res_from_csr;
    wire        res_from_mul;
    wire        res_from_div;
    wire [13:0] mem_csr_num;
    wire        mem_csr_we;
    wire [31:0] mem_csr_wmask;
    wire [31:0] mem_csr_wvalue;
    wire [31:0] mem_vaddr;
    wire        mem_ertn_flush;
    wire        mem_excep;
    wire        mem_has_int;
    wire        mem_excp_adef;
    wire        mem_excp_syscall;
    wire        mem_excp_break;
    wire        mem_excp_ale;
    wire        mem_excp_ine;

    wire        mem_inst_pif_excep;
    wire        mem_inst_ppi_excep;
    wire        mem_inst_tlbr_excep;
    wire        mem_data_ppi_excep;
    wire        mem_data_tlbr_excep;
    wire        mem_data_pil_excep;
    wire        mem_data_pis_excep;
    wire        mem_data_pme_excep;
    
    wire        mem_inst_tlbsrch;
    wire        mem_inst_tlbwr;
    wire        mem_inst_tlbfill;
    wire        mem_inst_tlbrd;
    wire        mem_inst_invtl;

    wire        mem_s1_found;
    wire [ 3:0] mem_s1_index;

//-----stage control signal-----
    assign mem_ready_go     = mem_data_sram_req & data_sram_data_ok | ~mem_data_sram_req;
    assign mem_allowin      = ~mem_valid | mem_ready_go & wb_allowin | mem_flush;     
    assign mem_to_wb_valid  = mem_valid & mem_ready_go & ~mem_flush;

    always @(posedge clk) begin
        if(~resetn)
            mem_valid <= 1'b0;
        else if(mem_allowin)
            mem_valid <= ex_to_mem_valid; 
    end

//-----EX and MEM state interface-----
    always @(posedge clk) begin
        if(ex_to_mem_valid & mem_allowin) begin
            ex_to_mem_data_reg  <= ex_to_mem_data;
            ex_to_mem_excep_reg <= ex_to_mem_excep;
            ex_to_mem_tlb_reg   <= ex_to_mem_tlb;
        end
    end
    
    assign {mem_rf_we, mem_rf_waddr,
            mem_pc,
            mem_final_result,
            mem_inst_ld_b, mem_inst_ld_bu, mem_inst_ld_h, mem_inst_ld_hu, mem_inst_ld_w,
            mem_data_sram_req,
            res_from_mul, mul_h, res_from_div
            } = ex_to_mem_data_reg;

    assign {mem_res_from_csr, mem_csr_num, mem_csr_we, mem_csr_wmask, mem_csr_wvalue, 
            mem_ertn_flush, mem_has_int, mem_excp_adef, mem_excp_syscall, mem_excp_break,
            mem_excp_ale, mem_excp_ine, 
            mem_inst_pif_excep, mem_inst_ppi_excep, mem_inst_tlbr_excep,
            mem_data_ppi_excep, mem_data_tlbr_excep, mem_data_pil_excep, mem_data_pis_excep, mem_data_pme_excep     
            } = ex_to_mem_excep_reg;
    
    assign {mem_s1_found, mem_s1_index,
            mem_inst_tlbsrch, mem_inst_tlbwr, mem_inst_tlbfill, mem_inst_tlbrd, mem_inst_invtl
            } = ex_to_mem_tlb_reg;

    //exception signal to EX
    assign mem_to_ex_excep =  (mem_ertn_flush | mem_excep) & mem_valid;

//-----final rf_wdata-----
    assign shift_rdata   = {24'b0, data_sram_rdata} >> {mem_final_result[1:0], 3'b0};
    
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
                              {32{~res_from_mul & ~res_from_mem}} & mem_final_result;

//-----TLB relavant signals-----
    //to EX
    assign mem_csr_tlbrd = ((mem_csr_num == `CSR_ASID || mem_csr_num == `CSR_TLBEHI) && mem_csr_we
                     || mem_inst_tlbrd) && mem_valid;

//-----MEM to ID data(backward)----- 
    assign mem_res_from_mem = res_from_mem & ~mem_to_wb_valid & mem_valid;
                             
    assign mem_rf_zip      = {mem_res_from_mem,
                              mem_res_from_csr,
                              mem_rf_we & mem_valid,
                              mem_rf_waddr,
                              mem_rf_wdata};

//-----MEM and WB state interface-----
    assign mem_to_wb_data = {mem_rf_we,
                             mem_rf_waddr,
                             mem_rf_wdata,
                             mem_pc};
                          
    //exception
    assign mem_excep = mem_has_int | mem_excp_adef | mem_excp_syscall | mem_excp_break | mem_excp_ale | mem_excp_ine |
                       mem_inst_pif_excep | mem_inst_ppi_excep | mem_inst_tlbr_excep |
                       mem_data_ppi_excep | mem_data_tlbr_excep | mem_data_pil_excep | mem_data_pis_excep | mem_data_pme_excep;

    assign mem_vaddr = (mem_inst_tlbr | mem_inst_ppi) ? mem_pc : mem_final_result;

    assign mem_to_wb_excep = {mem_res_from_csr, mem_csr_num, mem_csr_we, mem_csr_wmask, mem_csr_wvalue, 
                              mem_ertn_flush, mem_has_int, mem_excp_adef, mem_excp_syscall, mem_excp_break,
                              mem_excp_ale, mem_vaddr, mem_excp_ine, 
                              mem_inst_pif_excep, mem_inst_ppi_excep, mem_inst_tlbr_excep,
                              mem_data_ppi_excep, mem_data_tlbr_excep, mem_data_pil_excep, mem_data_pis_excep, mem_data_pme_excep};
    
    assign mem_to_wb_tlb = {mem_s1_found, mem_s1_index,
                            mem_inst_tlbsrch, mem_inst_tlbwr, mem_inst_tlbfill, mem_inst_tlbrd, mem_inst_invtl};
  
endmodule