`include "mycpu_head.h"

module MMU(
    //search port 0 (for inst fetch)
    output wire [18:0] s_vppn,
    output wire        s_va_bit12,
    output wire [ 9:0] s_asid,
    input  wire        s_found,
    input  wire [19:0] s_ppn,
    input  wire [ 5:0] s_ps,
    input  wire [ 1:0] s_plv,
    input  wire [ 1:0] s_mat,
    input  wire        s_d,
    input  wire        s_v,

    //virtual addr and physical addr
    input  wire [31:0] va,
    output wire [31:0] pa,

    //from csr
    input  wire [31:0] csr_crmd_rvalue,
    input  wire [31:0] csr_asid_rvalue,
    input  wire [31:0] csr_dmw0_rvalue,
    input  wire [31:0] csr_dmw1_rvalue,

    //for except  
    output wire        page_invalid,
    output wire        ppi_except,
    output wire        page_fault,
    output wire        page_dirty
)
    wire        csr_crmd_da;
    wire        csr_crmd_pg;
    wire [1:0]  csr_crmd_plv;
    wire [9:0]  csr_asid_asid;

    wire        dmw_hit0;
    wire        dmw_hit1;
    wire [31:0] dmw_pa0;
    wire [31:0] dmw_pa1;
    wire [31:0] tlb_pa;

    wire        direct_map;

//vitual addr to physical addr
    //direct mapping
    assign csr_crmd_da   = csr_crmd_rvalue[`CSR_CRMD_DA];
    assign csr_crmd_pg   = csr_crmd_rvalue[`CSR_CRMD_PG];
    assign csr_crmd_plv  = csr_crmd_rvalue[`CSR_CRMD_PLV];
    assign csr_asid_asid = csr_asid_rvalue[`CSR_ASID_ASID];

    assign direct_map   = csr_crmd_da && ~csr_crmd_pg;

    assign dwm0_hit =   ~csr_crmd_da && csr_crmd_pg 
                     && csr_dmw0_rvalue[csr_crmd_plv] && (csr_dmw0_rvalue[CSR_DMW_VSEG] == nextpc[CSR_DMW_VSEG]);
    assign dwm1_hit =   ~csr_crmd_da && csr_crmd_pg
                     && csr_dmw1_rvalue[csr_crmd_plv] && (csr_dmw1_rvalue[CSR_DMW_VSEG] == nextpc[CSR_DMW_VSEG]);

    assign dmw_pa0  =   {csr_dmw0_rvalue[`CSR_DMW_PSEG], va[28:0]}; //csr_dmw_rvalue[27:25] = csr_dmw_pseg
    assign dmw_pa1  =   {csr_dmw1_rvalue[`CSR_DMW_PSEG], va[28:0]}; 

    //tlb mapping
    assign tlb_map  =   ~dwm0_hit & ~dwm1_hit & ~direct_map;

    assign {s_vppn, s_va_bit12} = va[31:12];
    assign s_asid  =   csr_asid_asid;

    assign tlb_pa   =  {32{s_ps == 6'd12}} & {s_ppn[19:0], va[11:0]} |
                       {32{s_ps == 6'd21}} & {s_ppn[19:9], va[20:0]};

    //physical addr
    assign pa    =  direct_map ? va
                  : dmw_hit0   ? dmw_paddr0
                  : dmw_hit1   ? dmw_paddr1
                  : tlb_paddr; 
    
    //for exception
    assign page_invalid =   tlb_map & ~s_v;
    assign ppi_except   =   tlb_map & (csr_crmd_plv > s_plv);
    assign page_fault   =   tlb_map & ~s_found;
    assign page_dirty   =   tlb_map & s_d;

endmodule