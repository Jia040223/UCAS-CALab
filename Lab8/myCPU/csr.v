`include "mycpu_head.h"
module csr(
    input  wire              clk,
    input  wire              resetn,
    input  wire [13:0]       csr_num,
    input  wire              csr_we,
    input  wire [31:0]       csr_wmask,
    input  wire [31:0]       csr_wvalue,
    input  wire              ertn_flush,
    input  wire              wb_ex,
    input  wire [5:0]        wb_ecode,      //csr_estate:21-16
    input  wire [8:0]        wb_esubcode,   //csr_estate:30-22
    input  wire [31:0]       wb_pc,
    output wire [31:0]       csr_rvalue,
    output wire [31:0]       ex_entry,

    // exp13
    output wire             has_int    ,
    input  wire             ipi_int_in ,
    input  wire [ 7:0]      hw_int_in  ,
    input  wire [31:0]      coreid_in  ,
    input  wire [31:0]      wb_vaddr   ,

    // exp18
    output reg  [ 9:0]      csr_asid_asid,
    output reg  [18:0]      csr_tlbehi_vppn,
    output reg  [ 3:0]      csr_tlbidx_index,

    input  wire             tlbsrch_we,
    input  wire             tlbsrch_hit,
    input  wire             tlbrd_we,
    input  wire [ 3:0]      tlbsrch_hit_index,
    
    input  wire             r_tlb_e,
    input  wire [ 5:0]      r_tlb_ps,
    input  wire [18:0]      r_tlb_vppn,
    input  wire [ 9:0]      r_tlb_asid,
    input  wire             r_tlb_g,

    input  wire [19:0]      r_tlb_ppn0,
    input  wire [ 1:0]      r_tlb_plv0,
    input  wire [ 1:0]      r_tlb_mat0,
    input  wire             r_tlb_d0,
    input  wire             r_tlb_v0,

    input  wire [19:0]      r_tlb_ppn1,
    input  wire [ 1:0]      r_tlb_plv1,
    input  wire [ 1:0]      r_tlb_mat1,
    input  wire             r_tlb_d1,
    input  wire             r_tlb_v1,

    output wire             w_tlb_e,
    output wire [ 5:0]      w_tlb_ps,
    output wire [18:0]      w_tlb_vppn,
    output wire [ 9:0]      w_tlb_asid,
    output wire             w_tlb_g,

    output wire [19:0]      w_tlb_ppn0,
    output wire [ 1:0]      w_tlb_plv0,
    output wire [ 1:0]      w_tlb_mat0,
    output wire             w_tlb_d0,
    output wire             w_tlb_v0,

    output wire [19:0]      w_tlb_ppn1,
    output wire [ 1:0]      w_tlb_plv1,
    output wire [ 1:0]      w_tlb_mat1,
    output wire             w_tlb_d1,
    output wire             w_tlb_v1,

    //exp19
    output wire [31:0] csr_crmd_rvalue,
    output wire [31:0] csr_asid_rvalue,
    output wire [31:0] csr_dmw0_rvalue,
    output wire [31:0] csr_dmw1_rvalue  
);
    // CRMD
    reg [ 1:0]  csr_crmd_plv;
    reg         csr_crmd_ie;
    reg         csr_crmd_da;
    reg         csr_crmd_pg;
    reg [ 1:0]  csr_crmd_datf;
    reg [ 1:0]  csr_crmd_datm;

    // PRMD
    reg [1:0] csr_prmd_pplv;
    reg csr_prmd_pie;
    wire [31:0] csr_prmd_rvalue;

    // ESTAT
    reg  [12:0] csr_estat_is;
    reg  [ 5:0] csr_estat_ecode;
    reg  [ 8:0] csr_estat_esubcode;
    wire [31:0] csr_estat_rvalue;

    // ERA
    reg [31:0] csr_era_pc;
    wire [31:0] csr_era_rvalue;

    // EENTRY
    reg [25:0] csr_eentry_va; // entry address for exception
    wire [31:0] csr_eentry_rvalue;

    // SAVE0-3
    reg [31:0] csr_save0_data;
    reg [31:0] csr_save1_data;
    reg [31:0] csr_save2_data;
    reg [31:0] csr_save3_data;
    wire [31:0] csr_save0_rvalue;
    wire [31:0] csr_save1_rvalue;
    wire [31:0] csr_save2_rvalue;
    wire [31:0] csr_save3_rvalue;

    // ECFG
    reg [12:0] csr_ecfg_lie;
    wire [31:0] csr_ecfg_rvalue;
    
    // BADV
    wire wb_ex_addr_err;
    reg [31:0] csr_badv_vaddr;
    wire [31:0] csr_badv_rvalue;

    // TID 
    reg [31:0] csr_tid_tid ;
    wire [31:0] csr_tid_rvalue;

    // TCFG
    reg csr_tcfg_en ; 
    reg csr_tcfg_periodic ;
    reg [29:0] csr_tcfg_initval ;
    wire [31:0] csr_tcfg_rvalue ;

    // TVAL
    wire [31:0] tcfg_next_value ;
    reg  [31:0] timer_cnt ;
    wire [31:0] csr_tval_timeval;
    wire [31:0] csr_tval_rvalue ;

    // TICLR
    wire csr_ticlr_clr ;
    wire [31:0] csr_ticlr_rvalue ;

    // TLBIDX
    reg  [ 5:0] csr_tlbidx_ps;
    reg         csr_tlbidx_ne;
    wire [31:0] csr_tlbidx_rvalue;

    // TLBEHI
    wire [31:0] csr_tlbehi_rvalue;

    // TLELO0
    reg         csr_tlbelo0_v;
    reg         csr_tlbelo0_d;
    reg  [ 1:0] csr_tlbelo0_plv;
    reg  [ 1:0] csr_tlbelo0_mat;
    reg         csr_tlbelo0_g;
    reg  [23:0] csr_tlbelo0_ppn;
    wire [31:0] csr_tlbelo0_rvalue;

    // TLELO1
    reg         csr_tlbelo1_v;
    reg         csr_tlbelo1_d;
    reg  [ 1:0] csr_tlbelo1_plv;
    reg  [ 1:0] csr_tlbelo1_mat;
    reg         csr_tlbelo1_g;
    reg  [23:0] csr_tlbelo1_ppn;
    wire [31:0] csr_tlbelo1_rvalue;

    // ASID
    wire [ 7:0] csr_asid_asidbits;

    // TLBRENTRY
    reg  [25:0] csr_tlbrentry_pa;
    wire [31:0] csr_tlbrentry_rvalue;
    wire        tlb_excep;
    wire        tlb_tlbr_excep;

    //DMW0-1
    reg         csr_dmw0_plv0;
    reg         csr_dmw0_plv3;
    reg  [ 1:0] csr_dmw0_mat ;
    reg  [ 2:0] csr_dmw0_pseg;
    reg  [ 2:0] csr_dmw0_vseg;

    reg         csr_dmw1_plv0;
    reg         csr_dmw1_plv3;
    reg  [ 1:0] csr_dmw1_mat ;
    reg  [ 2:0] csr_dmw1_pseg;
    reg  [ 2:0] csr_dmw1_vseg;

//-----CSR Registers-----
    // CRMD
    // CRMD: PLV IE
    always @(posedge clk) begin
        if(~resetn) begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie  <= 1'b0;
        end
        else if(wb_ex) begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie <= 1'b0;
        end
        else if(ertn_flush) begin
            csr_crmd_plv <= csr_prmd_pplv;
            csr_crmd_ie <= csr_prmd_pie;
        end
        else if(csr_we && csr_num == `CSR_CRMD) begin
            csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV] | ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
            csr_crmd_ie <= csr_wmask[`CSR_CRMD_PIE] & csr_wvalue[`CSR_CRMD_PIE] | ~csr_wmask[`CSR_CRMD_PIE] & csr_crmd_ie; 
        end    
    end

    // CRMD: DA PG DATF DATM
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_crmd_da <= 1'b1;
            csr_crmd_pg <= 1'b0;
            csr_crmd_datf <= 2'b0;
            csr_crmd_datm <= 2'b0;
        end 
        else if (wb_ex && wb_ecode == `ECODE_TLBR) begin
            csr_crmd_da <= 1'b1;
            csr_crmd_pg <= 1'b0;
        end 
        else if (ertn_flush && csr_estat_ecode == `ECODE_TLBR) begin
            csr_crmd_da <= 1'b0;
            csr_crmd_pg <= 1'b1;
        end 
        else if (csr_we && csr_num == `CSR_CRMD) begin
            csr_crmd_da <= csr_wmask[`CSR_CRMD_DA] & csr_wvalue[`CSR_CRMD_DA] |
                          ~csr_wmask[`CSR_CRMD_DA] & csr_crmd_da;
            csr_crmd_pg <= csr_wmask[`CSR_CRMD_PG] & csr_wvalue[`CSR_CRMD_PG] |
                          ~csr_wmask[`CSR_CRMD_PG] & csr_crmd_pg;
            csr_crmd_datf <= csr_wmask[`CSR_CRMD_DATF] & csr_wvalue[`CSR_CRMD_DATF] |
                            ~csr_wmask[`CSR_CRMD_DATF] & csr_crmd_datf;
            csr_crmd_datm <= csr_wmask[`CSR_CRMD_DATM] & csr_wvalue[`CSR_CRMD_DATM] |
                            ~csr_wmask[`CSR_CRMD_DATM] & csr_crmd_datm;
        end
    end

    //PRMD
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie <= csr_crmd_ie;
        end
        else if (csr_we && csr_num==`CSR_PRMD) begin
            csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV] | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
            csr_prmd_pie <= csr_wmask[`CSR_PRMD_PIE] & csr_wvalue[`CSR_PRMD_PIE] | ~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie;
        end
    end
    
    // ESTAT
    always @(posedge clk) begin
        if (~resetn) begin
            csr_estat_is[1:0] <= 2'b0;
        end
        else if (csr_we && csr_num==`CSR_ESTAT) begin
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10] | ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[1:0];
        end   

        csr_estat_is[9:2] <= hw_int_in[7:0];
        csr_estat_is[10]  <= 1'b0;

        if (csr_tcfg_en && timer_cnt[31:0] == 32'b0)
            csr_estat_is[11] <= 1'b1;
        else if (csr_we && csr_num == `CSR_TICLR 
                        && csr_wmask[`CSR_TICLR_CLR] 
                        && csr_wvalue[`CSR_TICLR_CLR]) 
            csr_estat_is[11] <= 1'b0;              
        csr_estat_is[12] <= ipi_int_in;   

    end

    always @(posedge clk) begin
        if (wb_ex) begin
            csr_estat_ecode    <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end

    // ERA
    always @(posedge clk) begin
        if (wb_ex)
            csr_era_pc <= wb_pc;
        else if (csr_we && csr_num==`CSR_ERA)
            csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC] | ~csr_wmask[`CSR_ERA_PC] & csr_era_pc;
    end
 

    // EENTRY
    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_EENTRY)
            csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA] | ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
    end

    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_SAVE0)
            csr_save0_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save0_data;
        if (csr_we && csr_num==`CSR_SAVE1)
            csr_save1_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save1_data;
        if (csr_we && csr_num==`CSR_SAVE2)
            csr_save2_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save2_data;
        if (csr_we && csr_num==`CSR_SAVE3)
            csr_save3_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save3_data;
    end

   // ECFG
    always @(posedge clk) begin
        if(~resetn)
            csr_ecfg_lie <= 13'b0;
        else if(csr_we && csr_num == `CSR_ECFG)
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_wvalue[`CSR_ECFG_LIE]
                        | ~csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_ecfg_lie;
    end

    // BADV
    assign wb_ex_addr_err = wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE || wb_ecode==`ECODE_PIF
                         || wb_ecode==`ECODE_PPI || wb_ecode==`ECODE_PIL || wb_ecode==`ECODE_PIS
                         || wb_ecode==`ECODE_PME || wb_ecode==`ECODE_TLBR;
    always @(posedge clk) begin
        if (wb_ex && wb_ex_addr_err)
            csr_badv_vaddr <= ((wb_ecode == `ECODE_ADE & wb_esubcode == `ESUBCODE_ADEF) | 
                               wb_ecode == `ECODE_PIF) ? wb_pc : wb_vaddr;
    end

    // TID
    always @(posedge clk) begin
        if (~resetn)
            csr_tid_tid <= coreid_in;
        else if (csr_we && csr_num==`CSR_TID)
            csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID]
                        | ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
    end

    // TCFG
    always @(posedge clk) begin
        if (~resetn)
            csr_tcfg_en <= 1'b0;
        else if (csr_we && csr_num==`CSR_TCFG)
            csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN] 
                        | ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;

        if (csr_we && csr_num==`CSR_TCFG) begin
            csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD] & csr_wvalue[`CSR_TCFG_PERIOD]
                              | ~csr_wmask[`CSR_TCFG_PERIOD] & csr_tcfg_periodic;
            csr_tcfg_initval  <= csr_wmask[`CSR_TCFG_INITV] & csr_wvalue[`CSR_TCFG_INITV]
                              | ~csr_wmask[`CSR_TCFG_INITV] & csr_tcfg_initval;
        end
    end

    // TVAL
    assign tcfg_next_value =  csr_wmask[31:0] & csr_wvalue[31:0]
                            | ~csr_wmask[31:0] & {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

    always @(posedge clk) begin
        if (~resetn)
            timer_cnt <= 32'hffffffff;
        else if (csr_we && csr_num == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
            timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITV], 2'b0};
        else if (csr_tcfg_en && timer_cnt != 32'hffffffff) begin
            if (timer_cnt[31:0] == 32'b0 && csr_tcfg_periodic)
                timer_cnt <= {csr_tcfg_initval, 2'b0};
            else
                timer_cnt <= timer_cnt - 1'b1;
        end
    end

    //TVAL
    assign csr_tval_timeval = timer_cnt[31:0];
    
    //TICLR
    assign csr_ticlr_clr = 1'b0;

    // TLBIDX
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_tlbidx_index <= 4'b0;
            csr_tlbidx_ps    <= 6'b0;
            csr_tlbidx_ne    <= 1'b1;
        end 
        else if (tlbrd_we) begin
            if (r_tlb_e)
                csr_tlbidx_ps <= r_tlb_ps;
            else
                csr_tlbidx_ps <= 6'b0;

            csr_tlbidx_ne <= ~r_tlb_e;
        end 
        else if (tlbsrch_we) begin
            if(tlbsrch_hit) begin
                csr_tlbidx_index <= tlbsrch_hit_index;
                csr_tlbidx_ne <= 1'b0;
            end
            else
                csr_tlbidx_ne <= 1'b1;
        end 
        else if (csr_we && csr_num == `CSR_TLBIDX) begin
            csr_tlbidx_index <= csr_wmask[`CSR_TLBIDX_INDEX] & csr_wvalue[`CSR_TLBIDX_INDEX] |
                               ~csr_wmask[`CSR_TLBIDX_INDEX] & csr_tlbidx_index;
            csr_tlbidx_ps <= csr_wmask[`CSR_TLBIDX_PS] & csr_wvalue[`CSR_TLBIDX_PS] |
                            ~csr_wmask[`CSR_TLBIDX_PS] & csr_tlbidx_ps;
            csr_tlbidx_ne <= csr_wmask[`CSR_TLBIDX_NE] & csr_wvalue[`CSR_TLBIDX_NE] |
                            ~csr_wmask[`CSR_TLBIDX_NE] & csr_tlbidx_ne;
        end
    end

    // TLBEHI
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_tlbehi_vppn <= 19'b0;
        end 
        else if (tlbrd_we) begin
            if(r_tlb_e)
                csr_tlbehi_vppn <= r_tlb_vppn;
            else    
                csr_tlbehi_vppn <= 19'b0;
        end 
        else if (tlb_excep) begin
            csr_tlbehi_vppn <= wb_vaddr[31:13];
        end
        else if (csr_we && csr_num == `CSR_TLBEHI) begin
            csr_tlbehi_vppn <= csr_wmask[`CSR_TLBEHI_VPPN] & csr_wvalue[`CSR_TLBEHI_VPPN] |
                              ~csr_wmask[`CSR_TLBEHI_VPPN] & csr_tlbehi_vppn;
        end
    end

    // TLBELO0 and TLBELO1
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_tlbelo0_v   <= 1'b0;
            csr_tlbelo0_d   <= 1'b0;
            csr_tlbelo0_plv <= 2'b0;
            csr_tlbelo0_mat <= 2'b0;
            csr_tlbelo0_g   <= 1'b0;
            csr_tlbelo0_ppn <= 24'b0;

            csr_tlbelo1_v   <= 1'b0;
            csr_tlbelo1_d   <= 1'b0;
            csr_tlbelo1_plv <= 2'b0;
            csr_tlbelo1_mat <= 2'b0;
            csr_tlbelo1_g   <= 1'b0;
            csr_tlbelo1_ppn <= 24'b0;
        end 
        else if (tlbrd_we) begin
            if(r_tlb_e) begin
                csr_tlbelo0_v   <= r_tlb_v0;
                csr_tlbelo0_d   <= r_tlb_d0;
                csr_tlbelo0_plv <= r_tlb_plv0;
                csr_tlbelo0_mat <= r_tlb_mat0;
                csr_tlbelo0_g   <= r_tlb_g;
                csr_tlbelo0_ppn <= {4'b0, r_tlb_ppn0};

                csr_tlbelo1_v   <= r_tlb_v1;
                csr_tlbelo1_d   <= r_tlb_d1;
                csr_tlbelo1_plv <= r_tlb_plv1;
                csr_tlbelo1_mat <= r_tlb_mat1;
                csr_tlbelo1_g   <= r_tlb_g;
                csr_tlbelo1_ppn <= {4'b0, r_tlb_ppn1};
            end
            else begin
                csr_tlbelo0_v   <= 1'b0;
                csr_tlbelo0_d   <= 1'b0;
                csr_tlbelo0_plv <= 2'b0;
                csr_tlbelo0_mat <= 2'b0;
                csr_tlbelo0_g   <= 1'b0;
                csr_tlbelo0_ppn <= 24'b0;

                csr_tlbelo1_v   <= 1'b0;
                csr_tlbelo1_d   <= 1'b0;
                csr_tlbelo1_plv <= 2'b0;
                csr_tlbelo1_mat <= 2'b0;
                csr_tlbelo1_g   <= 1'b0;
                csr_tlbelo1_ppn <= 24'b0;
            end
        end 
        else if (csr_we) begin
            if (csr_num == `CSR_TLBELO0) begin
                csr_tlbelo0_v   <= csr_wmask[`CSR_TLBELO_V]   & csr_wvalue[`CSR_TLBELO_V]   |
                                  ~csr_wmask[`CSR_TLBELO_V]   & csr_tlbelo0_v;
                csr_tlbelo0_d   <= csr_wmask[`CSR_TLBELO_D]   & csr_wvalue[`CSR_TLBELO_D]   |
                                  ~csr_wmask[`CSR_TLBELO_D]   & csr_tlbelo0_d;
                csr_tlbelo0_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV] |
                                  ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo0_plv;
                csr_tlbelo0_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT] |
                                  ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo0_mat;
                csr_tlbelo0_g   <= csr_wmask[`CSR_TLBELO_G]   & csr_wvalue[`CSR_TLBELO_G]   |
                                  ~csr_wmask[`CSR_TLBELO_G]   & csr_tlbelo0_g;
                csr_tlbelo0_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN] |
                                  ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo0_ppn;
            end 
            else if (csr_num == `CSR_TLBELO1) begin
                csr_tlbelo1_v   <= csr_wmask[`CSR_TLBELO_V]   & csr_wvalue[`CSR_TLBELO_V]   |
                                  ~csr_wmask[`CSR_TLBELO_V]   & csr_tlbelo1_v;
                csr_tlbelo1_d   <= csr_wmask[`CSR_TLBELO_D]   & csr_wvalue[`CSR_TLBELO_D]   |
                                  ~csr_wmask[`CSR_TLBELO_D]   & csr_tlbelo1_d;
                csr_tlbelo1_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV] |
                                  ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo1_plv;
                csr_tlbelo1_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT] |
                                  ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo1_mat;
                csr_tlbelo1_g   <= csr_wmask[`CSR_TLBELO_G]   & csr_wvalue[`CSR_TLBELO_G]   |
                                  ~csr_wmask[`CSR_TLBELO_G]   & csr_tlbelo1_g;
                csr_tlbelo1_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN] |
                                  ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo1_ppn;
            end
        end
    end

    // ASID
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_asid_asid <= 10'b0;
        end 
        else if (tlbrd_we) begin
            if(r_tlb_e)
                csr_asid_asid <= r_tlb_asid;
            else
                csr_asid_asid <= 10'b0;
        end 
        else if (csr_we && csr_num == `CSR_ASID) begin
            csr_asid_asid <= csr_wmask[`CSR_ASID_ASID] & csr_wvalue[`CSR_ASID_ASID] |
                            ~csr_wmask[`CSR_ASID_ASID] & csr_asid_asid;
        end
    end

    assign csr_asid_asidbits = 8'd10;

    // TLBRENTRY
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_tlbrentry_pa <= 26'b0;
        end 
        else if (csr_we && csr_num == `CSR_TLBRENTRY) begin
            csr_tlbrentry_pa <= csr_wmask[`CSR_TLBRENTRY_PA] & csr_wvalue[`CSR_TLBRENTRY_PA] |
                               ~csr_wmask[`CSR_TLBRENTRY_PA] & csr_tlbrentry_pa;
        end
    end

    //DMW0-1
    always @(posedge clk ) begin
        if(~resetn) begin
            csr_dmw0_plv0 <= 1'b0;
            csr_dmw0_plv3 <= 1'b0;
            csr_dmw0_mat  <= 2'b0;
            csr_dmw0_pseg <= 3'b0;
            csr_dmw0_vseg <= 3'b0;
        end
        else if(csr_we && csr_num == `CSR_DMW0)begin
            csr_dmw0_plv0  <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]
                        | ~csr_wmask[`CSR_DMW_PLV0] & csr_dmw0_plv0; 
            csr_dmw0_plv3  <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]
                        | ~csr_wmask[`CSR_DMW_PLV3] & csr_dmw0_plv3; 
            csr_dmw0_mat   <= csr_wmask[`CSR_DMW_MAT] & csr_wvalue[`CSR_DMW_MAT]
                        | ~csr_wmask[`CSR_DMW_MAT] & csr_dmw0_mat; 
            csr_dmw0_pseg  <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]
                        | ~csr_wmask[`CSR_DMW_PSEG] & csr_dmw0_pseg;
            csr_dmw0_vseg  <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]
                        | ~csr_wmask[`CSR_DMW_VSEG] & csr_dmw0_vseg;   
        end
    end

    always @(posedge clk ) begin
        if(~resetn) begin
            csr_dmw1_plv0 <= 1'b0;
            csr_dmw1_plv3 <= 1'b0;
            csr_dmw1_mat  <= 2'b0;
            csr_dmw1_pseg <= 3'b0;
            csr_dmw1_vseg <= 3'b0;
        end
        else if(csr_we && csr_num == `CSR_DMW1)begin
            csr_dmw1_plv0  <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]
                        | ~csr_wmask[`CSR_DMW_PLV0] & csr_dmw1_plv0; 
            csr_dmw1_plv3  <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]
                        | ~csr_wmask[`CSR_DMW_PLV3] & csr_dmw1_plv3; 
            csr_dmw1_mat   <= csr_wmask[`CSR_DMW_MAT] & csr_wvalue[`CSR_DMW_MAT]
                        | ~csr_wmask[`CSR_DMW_MAT] & csr_dmw1_mat; 
            csr_dmw1_pseg  <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]
                        | ~csr_wmask[`CSR_DMW_PSEG] & csr_dmw1_pseg;
            csr_dmw1_vseg  <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]
                        | ~csr_wmask[`CSR_DMW_VSEG] & csr_dmw1_vseg;   
        end
    end
    
//---rvalue and output---
    //exp13
    assign ex_entry = {32{~tlb_tlbr_excep}} & csr_eentry_rvalue |
                      {32{tlb_tlbr_excep}}  & csr_tlbrentry_rvalue;
    assign csr_crmd_rvalue = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
    assign csr_prmd_rvalue = {29'b0, csr_prmd_pie, csr_prmd_pplv};
    assign csr_estat_rvalue =  {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
    assign csr_era_rvalue =  csr_era_pc;
    assign csr_eentry_rvalue =  {csr_eentry_va, 6'b0};
    assign csr_save0_rvalue  =  csr_save0_data;
    assign csr_save1_rvalue  =  csr_save1_data;
    assign csr_save2_rvalue  =  csr_save2_data;
    assign csr_save3_rvalue  =  csr_save3_data;

    assign csr_ecfg_rvalue   =  {19'b0, csr_ecfg_lie};
    assign csr_badv_rvalue   =  csr_badv_vaddr;
    assign csr_tid_rvalue    =  csr_tid_tid ;
    assign csr_tcfg_rvalue   =  {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
    assign csr_tval_rvalue   =  csr_tval_timeval;
    assign csr_ticlr_rvalue  =  {31'b0, csr_ticlr_clr};

    //exp18
    assign csr_tlbidx_rvalue = {csr_tlbidx_ne, 1'b0, csr_tlbidx_ps, 20'b0, csr_tlbidx_index};
    assign csr_tlbehi_rvalue = {csr_tlbehi_vppn, 13'b0};
    assign csr_tlbelo0_rvalue = {csr_tlbelo0_ppn, 1'b0, csr_tlbelo0_g, csr_tlbelo0_mat, csr_tlbelo0_plv, csr_tlbelo0_d, csr_tlbelo0_v};
    assign csr_tlbelo1_rvalue = {csr_tlbelo1_ppn, 1'b0, csr_tlbelo1_g, csr_tlbelo1_mat, csr_tlbelo1_plv, csr_tlbelo1_d, csr_tlbelo1_v};
    assign csr_asid_rvalue = {8'b0, csr_asid_asidbits, 6'b0, csr_asid_asid};
    assign csr_tlbrentry_rvalue = {csr_tlbrentry_pa, 6'b0};

    //exp19
    assign csr_dmw0_rvalue = {csr_dmw0_vseg, 1'b0, csr_dmw0_pseg, 19'b0, csr_dmw0_mat, csr_dmw0_plv3, 2'b0, csr_dmw0_plv0};
    assign csr_dmw1_rvalue = {csr_dmw1_vseg, 1'b0, csr_dmw1_pseg, 19'b0, csr_dmw1_mat, csr_dmw1_plv3, 2'b0, csr_dmw1_plv0};
    assign tlb_excep       = wb_ecode == `ECODE_PIF | wb_ecode == `ECODE_PPI | wb_ecode == `ECODE_PIL | 
                             wb_ecode == `ECODE_PIS | wb_ecode == `ECODE_PME | wb_ecode == `ECODE_TLBR;
    assign tlb_tlbr_excep  = wb_ecode == `ECODE_TLBR;

    assign csr_rvalue =   {32{csr_num == `CSR_CRMD  }} & csr_crmd_rvalue
                        | {32{csr_num == `CSR_PRMD  }} & csr_prmd_rvalue 
                        | {32{csr_num == `CSR_ESTAT }} & csr_estat_rvalue
                        | {32{csr_num == `CSR_ERA   }} & csr_era_rvalue
                        | {32{csr_num == `CSR_EENTRY}} & csr_eentry_rvalue
                        | {32{csr_num == `CSR_SAVE0 }} & csr_save0_rvalue
                        | {32{csr_num == `CSR_SAVE1 }} & csr_save1_rvalue
                        | {32{csr_num == `CSR_SAVE2 }} & csr_save2_rvalue
                        | {32{csr_num == `CSR_SAVE3 }} & csr_save3_rvalue
                        | {32{csr_num == `CSR_ECFG  }} & csr_ecfg_rvalue
                        | {32{csr_num == `CSR_BADV  }} & csr_badv_rvalue
                        | {32{csr_num == `CSR_TID   }} & csr_tid_rvalue
                        | {32{csr_num == `CSR_TCFG  }} & csr_tcfg_rvalue
                        | {32{csr_num == `CSR_TVAL  }} & csr_tval_rvalue
                        | {32{csr_num == `CSR_TICLR }} & csr_ticlr_rvalue 
                        | {32{csr_num == `CSR_TLBIDX}} & csr_tlbidx_rvalue
                        | {32{csr_num == `CSR_TLBEHI}} & csr_tlbehi_rvalue
                        | {32{csr_num == `CSR_TLBELO0}} & csr_tlbelo0_rvalue
                        | {32{csr_num == `CSR_TLBELO1}} & csr_tlbelo1_rvalue
                        | {32{csr_num == `CSR_ASID  }} & csr_asid_rvalue
                        | {32{csr_num == `CSR_TLBRENTRY}} & csr_tlbrentry_rvalue
                        | {32{csr_num == `CSR_DMW0  }} & csr_dmw0_rvalue
                        | {32{csr_num == `CSR_DMW1  }} & csr_dmw1_rvalue;
                  
    assign has_int = (|(csr_estat_is[12:0] & csr_ecfg_lie[12:0])) && (csr_crmd_ie == 1'b1);

    // TLB entry
    assign w_tlb_e    = csr_estat_ecode == `ECODE_TLBR ? 1'b1 : ~csr_tlbidx_ne;
    assign w_tlb_ps   =  csr_tlbidx_ps;
    assign w_tlb_vppn =  csr_tlbehi_vppn;
    assign w_tlb_asid =  csr_asid_asid;
    assign w_tlb_g    =  csr_tlbelo0_g & csr_tlbelo1_g;

    assign w_tlb_ppn0 = csr_tlbelo0_ppn[19:0];
    assign w_tlb_plv0 = csr_tlbelo0_plv;
    assign w_tlb_mat0 = csr_tlbelo0_mat;
    assign w_tlb_d0   = csr_tlbelo0_d;
    assign w_tlb_v0   = csr_tlbelo0_v;

    assign w_tlb_ppn1 = csr_tlbelo1_ppn[19:0];
    assign w_tlb_plv1 = csr_tlbelo1_plv;
    assign w_tlb_mat1 = csr_tlbelo1_mat;
    assign w_tlb_d1   = csr_tlbelo1_d;
    assign w_tlb_v1   = csr_tlbelo1_v;
                  
                   
endmodule