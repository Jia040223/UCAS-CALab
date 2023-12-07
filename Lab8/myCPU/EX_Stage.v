`include "mycpu_head.h"

module EX_Stage(
    input  wire        clk,
    input  wire        resetn,
    // id and exe state interface
    output wire        ex_allowin,
    input  wire [ `ID_TO_EX_DATA_WIDTH-1:0] id_to_ex_data,
    input  wire [`ID_TO_EX_EXCEP_WIDTH-1:0] id_to_ex_excep,
    input  wire [  `ID_TO_EX_TLB_WIDTH-1:0] id_to_ex_tlb,
    input  wire        id_to_ex_valid,
    // exe and mem state interface
    input  wire        mem_allowin,
    output wire [ `EX_TO_MEM_DATA_WIDTH-1:0] ex_to_mem_data,
    output wire [`EX_TO_MEM_EXCEP_WIDTH-1:0] ex_to_mem_excep, 
    output wire [  `EX_TO_MEM_TLB_WIDTH-1:0] ex_to_mem_tlb,
    output wire        ex_to_mem_valid,
    
    output wire  [39:0] ex_rf_zip,
    output wire  [63:0] mul_result,
    
// data sram interface
    output wire        data_sram_req,
    output wire        data_sram_wr,
    output wire [ 1:0] data_sram_size,
    output wire [ 3:0] data_sram_wstrb,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire        data_sram_addr_ok,

    input  wire        ex_flush,
    input  wire        mem_to_ex_excep,
    
    // to tlb
    output wire [19:0] s1_va_highbits,
    output wire [ 9:0] s1_asid,
    output wire        invtlb_valid,
    output wire [ 4:0] invtlb_op,
    // from csr, used for tlbsrch
    input  wire [ 9:0] csr_asid_asid,
    input  wire [18:0] csr_tlbehi_vppn,
    //from tlb
    input  wire        s1_found,
    input  wire [ 3:0] s1_index,

    // blk tlbsrch
    input  wire        mem_csr_tlbrd,
    input  wire        wb_csr_tlbrd,

    output wire [ 3:0] ex_to_wb_rand,

    //to mmu
    output wire [31:0] data_va,
    input  wire [31:0] data_pa,
    output wire [ 9:0] ex_asid,

    //from mmu
    input  wire        data_page_invalid,
    input  wire        data_ppi_except,
    input  wire        data_page_fault,
    input  wire        data_page_clean
);
    reg  [ `ID_TO_EX_DATA_WIDTH-1:0] id_to_ex_data_reg;
    reg  [`ID_TO_EX_EXCEP_WIDTH-1:0] id_to_ex_excep_reg;
    reg  [  `ID_TO_EX_TLB_WIDTH-1:0] id_to_ex_tlb_reg;

    wire        ex_ready_go;
    reg         ex_valid;

    wire        ex_rf_we;
    wire [ 4:0] ex_rf_waddr;
    wire [31:0] ex_pc;    

    wire [11:0] ex_alu_op;
    wire [31:0] ex_alu_src1;
    wire [31:0] ex_alu_src2;

    wire [31:0] ex_alu_result; 
    wire [ 3:0] ex_mem_strb;
    wire [31:0] ex_rkd_value;

    wire        ex_inst_st_b;
    wire        ex_inst_st_h;
    wire        ex_inst_st_w;

    wire        ex_inst_ld_b;
    wire        ex_inst_ld_bu;
    wire        ex_inst_ld_h;
    wire        ex_inst_ld_hu;
    wire        ex_inst_ld_w;

    wire        ex_res_from_mem;
    wire        ex_res_from_mul;
    wire        ex_res_from_div;
    wire        ex_mul_signed;
    wire        ex_mul_h;

    wire        ex_div_r;
    wire        ex_div_signed;
    wire [31:0] ex_div_s_result;
    wire [31:0] ex_div_r_result;
    wire        ex_div_complete;
    wire [31:0] ex_div_result;
    wire [31:0] ex_final_result;
    reg         ex_div_complete_reg;

    wire        ex_res_from_csr;
    wire [13:0] ex_csr_num;
    wire        ex_csr_we;
    wire [31:0] ex_csr_wmask;
    wire [31:0] ex_csr_wvalue;
    wire        ex_ertn_flush;
    wire        ex_excp_adef;
    wire        ex_excp_syscall;
    wire        ex_excp_break;
    wire        ex_excp_ale;
    wire        ex_excp_ine;

    wire        ex_inst_pif_excep;
    wire        ex_inst_ppi_excep;
    wire        ex_inst_tlbr_excep;

    wire        ex_data_ppi_excep;
    wire        ex_data_tlbr_excep;
    wire        ex_data_pil_excep;
    wire        ex_data_pis_excep;
    wire        ex_data_pme_excep;

    wire        ex_pif_excep;
    wire        ex_ppi_excep;
    wire        ex_tlbr_excep;
    wire        ex_pil_excep;
    wire        ex_pis_excep;
    wire        ex_pme_excep;

    reg  [63:0] counter;
    wire        ex_mem_wait;
    wire [ 1:0] ex_sram_size;
    
    wire        ex_inst_rdcntvl;
    wire        ex_inst_rdcntvh;
    wire        ex_inst_rdcntid;
    wire        ex_has_int;

    wire        ex_inst_tlbsrch;
    wire        ex_inst_tlbwr;
    wire        ex_inst_tlbfill;
    wire        ex_inst_tlbrd;
    wire        ex_inst_invtlb;
    wire [ 4:0] ex_invtl_op;

//-----stage control signal-----
    assign ex_ready_go      = (data_sram_req & data_sram_addr_ok) | 
                              (ex_res_from_div & ex_div_complete) |
                              (ex_inst_tlbsrch & ~(mem_csr_tlbrd | wb_csr_tlbrd)) | 
                              ~(data_sram_req | ex_res_from_div | ex_inst_tlbsrch);
    assign ex_allowin       = ~ex_valid | ex_ready_go & mem_allowin | ex_flush;     
    assign ex_to_mem_valid  = ex_valid & ex_ready_go & ~ex_flush;
    always @(posedge clk) begin
        if(~resetn)
            ex_valid <= 1'b0;
        else if(ex_allowin)
            ex_valid <= id_to_ex_valid; 
    end

//-----ID and EX state interface-----
    always @(posedge clk) begin
        if(id_to_ex_valid & ex_allowin) begin
            id_to_ex_data_reg   <= id_to_ex_data;
            id_to_ex_excep_reg  <= id_to_ex_excep;
            id_to_ex_tlb_reg    <= id_to_ex_tlb;
        end
    end
    
    assign {ex_alu_op, ex_alu_src1, ex_alu_src2,
            ex_rf_we, ex_rf_waddr,
            ex_pc,
            ex_inst_st_b, ex_inst_st_h, ex_inst_st_w,
            ex_rkd_value,
            ex_inst_ld_b, ex_inst_ld_bu, ex_inst_ld_h, ex_inst_ld_hu, ex_inst_ld_w,
            ex_inst_rdcntvl, ex_inst_rdcntvh, ex_inst_rdcntid,
            ex_res_from_mul, ex_mul_signed, ex_mul_h, ex_res_from_div, ex_div_signed, ex_div_r
            } = id_to_ex_data_reg;   

    assign {ex_res_from_csr, ex_csr_num, ex_csr_we, ex_csr_wmask, ex_csr_wvalue, 
            ex_ertn_flush, ex_has_int, ex_excp_adef, ex_excp_syscall, ex_excp_break,
            ex_excp_ine, ex_inst_pif_excep, ex_inst_ppi_excep, ex_inst_tlbr_excep
            } = id_to_ex_excep_reg;


    assign {ex_invtl_op,
            ex_inst_tlbsrch, ex_inst_tlbwr, ex_inst_tlbfill, ex_inst_tlbrd, ex_inst_invtlb
            } = id_to_ex_tlb_reg;

//-----alu & mul & div-----
    alu u_alu(
        .alu_op     (ex_alu_op    ),
        .alu_src1   (ex_alu_src1  ),
        .alu_src2   (ex_alu_src2  ),
        .alu_result (ex_alu_result   )
    );


    mul u_mul(
        .mul_clk    (clk          ),
        .resetn     (resetn       ),
        .mul_signed (ex_mul_signed),
        .x          (ex_alu_src1  ),
        .y          (ex_alu_src2),
        .result     (mul_result   )
    );
   
    always @(posedge clk) begin
        if (~resetn)
            ex_div_complete_reg <= 0;
        else if (id_to_ex_valid & ex_allowin)
            ex_div_complete_reg <= 0;
        else if (ex_div_complete)
            ex_div_complete_reg <= 1;
    end

    div u_div(
        .div_clk    (clk          ),
        .resetn     (resetn & ~ex_flush),
        .div        (ex_res_from_div & ~ex_div_complete_reg),
        .div_signed (ex_div_signed),
        .x          (ex_alu_src1  ),
        .y          (ex_alu_src2  ),
        .s          (ex_div_s_result),
        .r          (ex_div_r_result),
        .complete   (ex_div_complete)
    );

    assign ex_div_result = ex_div_r ? ex_div_r_result : ex_div_s_result;

//-----counter(for rdcntvh and rdcntvl)-----
    always @(posedge clk) begin
        if(~resetn)
            counter <= 64'b0;
        else
            counter <= counter + 1;
    end

    assign ex_to_wb_rand = counter[3:0];
    
    //final calculate data    
    assign ex_final_result = ex_res_from_div ? ex_div_result  :
                             ex_inst_rdcntvh ? counter[63:32] :
                             ex_inst_rdcntvl ? counter[31:0]  :
                             ex_alu_result;
    
//-----EX to ID data(backward)-----         
    assign ex_res_from_mem = ex_inst_ld_b || ex_inst_ld_bu || ex_inst_ld_h || ex_inst_ld_hu || ex_inst_ld_w;

    assign ex_rf_zip       = {ex_res_from_csr,
                              (ex_res_from_mem | ex_res_from_mul) & ex_valid,
                              ex_rf_we & ex_valid,
                              ex_rf_waddr,
                              ex_final_result};
    
//-----EX to MEM data bus------    
    assign ex_to_mem_data = {ex_rf_we, ex_rf_waddr,
                             ex_pc,
                             ex_final_result,
                             ex_inst_ld_b, ex_inst_ld_bu, ex_inst_ld_h, ex_inst_ld_hu, ex_inst_ld_w,
                             ex_mem_wait,
                             ex_res_from_mul, ex_mul_h, ex_res_from_div};
    
    //ALE exception
    assign ex_excp_ale     = ex_valid & ((ex_inst_ld_h | ex_inst_ld_hu | ex_inst_st_h) & ex_alu_result[0] |
                                         (ex_inst_ld_w | ex_inst_st_w) & (|ex_alu_result[1:0]));

    assign ex_to_mem_excep = {ex_res_from_csr, ex_csr_num, ex_csr_we, ex_csr_wmask, ex_csr_wvalue, 
                              ex_ertn_flush, ex_has_int, ex_excp_adef, ex_excp_syscall, ex_excp_break,
                              ex_excp_ale, ex_excp_ine, 
                              ex_inst_pif_excep, ex_inst_ppi_excep, ex_inst_tlbr_excep,
                              ex_data_ppi_excep, ex_data_tlbr_excep, ex_data_pil_excep, ex_data_pis_excep, ex_data_pme_excep};

    
    assign ex_to_mem_tlb = {s1_found, s1_index, ex_inst_tlbsrch, ex_inst_tlbwr, ex_inst_tlbfill, ex_inst_tlbrd, ex_inst_invtlb};

//-----tlb------   
    assign invtlb_op = ex_invtl_op;
    assign invtlb_valid = ex_inst_invtlb & ex_valid;

//-----mmu-----
    assign data_va  = {32{ex_inst_tlbsrch}} & {csr_tlbehi_vppn, 13'b0} |
                      {32{ex_inst_invtlb}}  & {ex_rkd_value} | 
                      {32{~(ex_inst_invtlb | ex_inst_tlbsrch)}} & ex_alu_result;

    assign ex_asid  = {10{~ex_inst_invtlb}} & csr_asid_asid |
                      {10{ex_inst_invtlb}}  & ex_alu_src1[9:0];
    
    assign ex_data_ppi_excep = data_ppi_except && ex_mem_wait;
    assign ex_data_tlbr_excep = data_page_fault && ex_mem_wait;
    assign ex_data_pil_excep = data_page_invalid && ex_mem_wait && ~data_sram_wr;
    assign ex_data_pis_excep = data_page_invalid && ex_mem_wait && data_sram_wr;
    assign ex_data_pme_excep = data_page_clean && ex_mem_wait && data_sram_wr; 

//------data sram interface------
    wire st_addr00 = ex_alu_result[1:0] == 2'b00;
    wire st_addr01 = ex_alu_result[1:0] == 2'b01;
    wire st_addr10 = ex_alu_result[1:0] == 2'b10;
    wire st_addr11 = ex_alu_result[1:0] == 2'b11;
    
    assign ex_mem_strb = {4{ex_inst_st_b}} & {st_addr11, st_addr10, st_addr01, st_addr00} |
                       {4{ex_inst_st_h}} & {{2{st_addr10}}, {2{st_addr00}}} |
                       {4{ex_inst_st_w}};

    assign ex_mem_wait = (ex_inst_ld_b || ex_inst_ld_bu || ex_inst_ld_h || ex_inst_ld_hu || ex_inst_ld_w || (|ex_mem_strb)) 
                        & ~mem_to_ex_excep & ~ex_flush 
                        & ~(ex_excp_ale | ex_inst_pif_excep | ex_inst_ppi_excep | ex_inst_tlbr_excep);
    assign ex_sram_size = {ex_inst_ld_w | ex_inst_st_w, (ex_inst_ld_h | ex_inst_ld_hu |ex_inst_st_h)};
    assign data_sram_req = ex_mem_wait & ex_valid & mem_allowin;
    assign data_sram_wr = ex_inst_st_b | ex_inst_st_h | ex_inst_st_w;
    assign data_sram_size = ex_sram_size;
    assign data_sram_wstrb = ex_mem_strb;
    assign data_sram_addr = ex_alu_result;
    assign data_sram_wdata = (ex_inst_st_b)? {4{ex_rkd_value[ 7:0]}} :
                             (ex_inst_st_h)? {2{ex_rkd_value[15:0]}} :
                              ex_rkd_value;
                                
endmodule

