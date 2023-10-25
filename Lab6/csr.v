`include "csr.h"
module csr(
    input  wire              clk,
    input  wire              reset,
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
    output wire [31:0]       ex_entry
);
    // CRMD
    reg [1:0]   csr_crmd_plv;
    reg         csr_crmd_ie;
    wire [31:0] csr_crmd_rvalue;
    wire         csr_crmd_da;       //CRMD的直接地址翻译使能
    wire         csr_crmd_pg;
    wire [1:0]   csr_crmd_datf;
    wire [1:0]   csr_crmd_datm;

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


    //CRMD
    always @(posedge clk) begin
        if(reset) begin
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

    assign csr_crmd_da    = 1'b1;
    assign csr_crmd_pg    = 1'b0;
    assign csr_crmd_datf  = 2'b0;
    assign csr_crmd_datm  = 2'b0;

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
        if (reset) begin
            csr_estat_is[1:0] <= 2'b0;
        end
        else if (csr_we && csr_num==`CSR_ESTAT) begin
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10] | ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[1:0];
        end   

        csr_estat_is[12:2] <= 10'b0;  

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

   


    assign ex_entry = csr_eentry_rvalue;
    assign csr_crmd_rvalue = {23'b0, csr_crmd_datm, csr_crmd_datm, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
    assign csr_prmd_rvalue = {29'b0, csr_prmd_pie, csr_prmd_pplv};
    assign csr_estat_rvalue =  {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
    assign csr_era_rvalue =  csr_era_pc;
    assign csr_eentry_rvalue =  {csr_eentry_va, 6'b0};
    assign csr_save0_rvalue  =  csr_save0_data;
    assign csr_save1_rvalue  =  csr_save1_data;
    assign csr_save2_rvalue  =  csr_save2_data;
    assign csr_save3_rvalue  =  csr_save3_data;

    assign csr_rvalue = {32{csr_num == `CSR_CRMD  }} & csr_crmd_rvalue
                      | {32{csr_num == `CSR_PRMD  }} & csr_prmd_rvalue 
                      | {32{csr_num == `CSR_ESTAT }} & csr_estat_rvalue
                      | {32{csr_num == `CSR_ERA   }} & csr_era_rvalue
                      | {32{csr_num == `CSR_EENTRY}} & csr_eentry_rvalue
                      | {32{csr_num == `CSR_SAVE0 }} & csr_save0_rvalue
                      | {32{csr_num == `CSR_SAVE1 }} & csr_save1_rvalue
                      | {32{csr_num == `CSR_SAVE2 }} & csr_save2_rvalue
                      | {32{csr_num == `CSR_SAVE3 }} & csr_save3_rvalue;
                  
                   
endmodule