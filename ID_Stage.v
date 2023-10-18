`include "mycpu_head.h"

module ID_Stage(
    input  wire        clk,
    input  wire        resetn,
    // if and id state interface
    output wire        id_allowin,
    output wire        br_taken,
    output wire [31:0] br_target,
    input  wire        if_to_id_valid,
    input  wire [`IF_TO_ID_WIDTH-1:0] if_to_id_wire,
    // id and exe state interface
    input  wire        ex_allowin,
    output wire [`ID_TO_EX_WIDTH-1:0] id_to_ex_wire,
    output wire        id_to_ex_valid,  
    // id and wb state interface
    input  wire [37:0] wb_rf_zip, // {wb_rf_we, wb_rf_waddr, wb_rf_wdata}
    input wire  [37:0] mem_rf_zip,
    input wire  [38:0] ex_rf_zip
);
    reg  [`IF_TO_ID_WIDTH-1:0] if_to_id_reg; 
    
    wire [31:0] id_pc;
    wire [31:0] id_rkd_value;
    
    wire        id_ready_go;
    reg         id_valid;
    wire [31:0] inst;

    wire [11:0] alu_op;
    wire [31:0] alu_src1;
    wire [31:0] alu_src2;
    wire        src1_is_pc;
    wire        src2_is_imm;
    wire [ 3:0] res_from_mem;
    wire        dst_is_r1;
    wire        gr_we;
    wire        src_reg_is_rd;
    wire        rj_eq_rd;
    wire        rj_lt_rd_signed;
    wire        rj_lt_rd_unsigned;
    wire [4: 0] dest;
    wire [31:0] rj_value;
    wire [31:0] rkd_value;
    wire [31:0] imm;
    wire [31:0] br_offs;
    wire [31:0] jirl_offs;

    wire [ 5:0] op_31_26;
    wire [ 3:0] op_25_22;
    wire [ 1:0] op_21_20;
    wire [ 4:0] op_19_15;
    wire [ 4:0] rd;
    wire [ 4:0] rj;
    wire [ 4:0] rk;
    wire [11:0] i12;
    wire [19:0] i20;
    wire [15:0] i16;
    wire [25:0] i26;

    wire [31:0] op_31_26_d;
    wire [15:0] op_25_22_d;
    wire [ 3:0] op_21_20_d;
    wire [31:0] op_19_15_d;

    wire        need_ui5;
    wire        need_ui12;
    wire        need_si12;
    wire        need_si16;
    wire        need_si20;
    wire        need_si26;
    wire        src2_is_4;
    
    wire [ 4:0] rf_raddr1;
    wire [31:0] rf_rdata1;
    wire [ 4:0] rf_raddr2;
    wire [31:0] rf_rdata2;

    wire        wb_rf_we   ;
    wire [ 4:0] wb_rf_waddr;
    wire [31:0] wb_rf_wdata;
    
    wire        mem_rf_we   ;
    wire [ 4:0] mem_rf_waddr;
    wire [31:0] mem_rf_wdata;
    
    wire        ex_rf_we   ;
    wire [ 4:0] ex_rf_waddr;
    wire [31:0] ex_rf_wdata;
    
    wire        id_rf_we   ;
    wire [ 4:0] id_rf_waddr;

    wire        conflict_r1_wb;
    wire        conflict_r2_wb;
    wire        conflict_r1_mem;
    wire        conflict_r2_mem;
    wire        conflict_r1_ex;
    wire        conflict_r2_ex;
    
    wire        id_delay;
    wire        conflict;
    
    wire        need_r1;
    wire        need_r2;

    wire        res_from_mul;
    wire        res_from_div;
    wire        mul_signed;
    wire        div_signed;
    wire        div_r;
    wire        mul_h;
        
//stage control signal
    assign id_ready_go      = ~conflict;
    
    assign conflict         =  id_delay & (conflict_r1_ex & need_r1|conflict_r2_ex & need_r2);  
    
    assign id_allowin       = ~id_valid | id_ready_go & ex_allowin;     
    assign id_to_ex_valid  = id_valid & id_ready_go;
    always @(posedge clk) begin
        if(~resetn)
            id_valid <= 1'b0;
        else if(br_taken)
            id_valid <= 1'b0;
        else if(id_allowin)
            id_valid <= if_to_id_valid;
    end

//if to id stage signal
    always @(posedge clk) begin
        if(if_to_id_valid & id_allowin) begin
            if_to_id_reg <= if_to_id_wire;
        end
    end
    
    assign {inst, id_pc} = if_to_id_reg;
                                           
//decode instruction
    assign op_31_26  = inst[31:26];
    assign op_25_22  = inst[25:22];
    assign op_21_20  = inst[21:20];
    assign op_19_15  = inst[19:15];

    assign rd   = inst[ 4: 0];
    assign rj   = inst[ 9: 5];
    assign rk   = inst[14:10];

    assign i12  = inst[21:10];
    assign i20  = inst[24: 5];
    assign i16  = inst[25:10];
    assign i26  = {inst[ 9: 0], inst[25:10]};

    decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
    decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
    decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
    decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));
   
    //inst_calculate_register
    wire inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
    wire inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
    wire inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
    wire inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
    wire inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
    wire inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
    wire inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
    wire inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];

    //inst_calculate_immediate
    wire inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
    wire inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
    wire inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
    wire inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
    wire inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];
    
    //inst_shift_register
    wire inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
    wire inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
    wire inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];

    //inst_shift_immediate
    wire inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
    wire inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
    wire inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
    wire inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];

    //inst_mul&div&mod
    wire inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
    wire inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
    wire inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
    wire inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
    wire inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
    wire inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
    wire inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
    
    //inst_load
    wire inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
    wire inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
    wire inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
    wire inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
    wire inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];

    //inst_store
    wire inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
    wire inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
    wire inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];

    //inst_branch
    wire inst_jirl   = op_31_26_d[6'h13];
    wire inst_b      = op_31_26_d[6'h14];
    wire inst_bl     = op_31_26_d[6'h15];
    wire inst_beq    = op_31_26_d[6'h16];
    wire inst_bne    = op_31_26_d[6'h17];
    wire inst_blt    = op_31_26_d[6'h18];
    wire inst_bge    = op_31_26_d[6'h19];
    wire inst_bltu   = op_31_26_d[6'h1a];
    wire inst_bgeu   = op_31_26_d[6'h1b];

    //inst_u12i
    wire inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];
    wire inst_pcaddul2i = op_31_26_d[6'h07] & ~inst[25];

    wire [31:0] adder_src1 = rj_value;
    wire [31:0] adder_src2 = ~rkd_value;
    wire        adder_IN = 1'b1;
    wire        adder_SF;
    wire        adder_ZF;
    wire        adder_CF;
    wire        adder_OF;
    wire        adder_res;
    
    adder_32 instance_adder32(
        .A(adder_src1),
        .B(adder_src2),
        .IN(adder_IN),
        .SF(adder_SF),    
        .ZF(adder_ZF),     
        .CF(adder_CF),        
        .OF(adder_OF),        
        .S(adder_res)  
    );

    assign rj_eq_rd = (rj_value == rkd_value);
    assign rj_lt_rd_signed = ($signed(rj_value) < $signed(rkd_value));
    assign rj_lt_rd_unsigned = (rj_value < rkd_value);
    //assign rj_eq_rd = adder_ZF;
    //assign rj_lt_rd_signed = adder_OF ^ adder_SF;
    //assign rj_lt_rd_unsigned = ~adder_CF;
    assign br_taken = conflict ? 1'b0 :
                      (inst_beq  &&  rj_eq_rd
                    || inst_bne  && !rj_eq_rd
                    || inst_blt  &&  rj_lt_rd_signed
                    || inst_bge  && !rj_lt_rd_signed
                    || inst_bltu &&  rj_lt_rd_unsigned
                    || inst_bgeu && !rj_lt_rd_unsigned
                    || inst_jirl
                    || inst_bl
                    || inst_b
                    ) && id_valid;
    assign br_target = (inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_bl | inst_b) ? (id_pc + br_offs) :
                                                                                                /*inst_jirl*/ (rj_value + jirl_offs);
    
    assign alu_op[ 0] = inst_add_w | inst_addi_w | 
                        inst_ld_b | inst_ld_h | inst_ld_w | inst_ld_bu | inst_ld_hu | 
                        inst_st_b | inst_st_h | inst_st_w |
                        | inst_jirl | inst_bl | inst_pcaddul2i;
    assign alu_op[ 1] = inst_sub_w;
    assign alu_op[ 2] = inst_slt | inst_slti;
    assign alu_op[ 3] = inst_sltu | inst_sltui;
    assign alu_op[ 4] = inst_and | inst_andi;
    assign alu_op[ 5] = inst_nor;
    assign alu_op[ 6] = inst_or | inst_ori;
    assign alu_op[ 7] = inst_xor | inst_xori;
    assign alu_op[ 8] = inst_slli_w | inst_sll_w;
    assign alu_op[ 9] = inst_srli_w | inst_srl_w;
    assign alu_op[10] = inst_srai_w | inst_sra_w;
    assign alu_op[11] = inst_lu12i_w;
    
    assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
    assign need_ui12  =  inst_andi | inst_ori | inst_xori;
    assign need_si12  =  inst_addi_w | 
                         inst_ld_b | inst_ld_h | inst_ld_w | inst_ld_bu | inst_ld_hu | 
                         inst_st_b | inst_st_h | inst_st_w |
                         inst_slti | inst_sltui;
    assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
    assign need_si20  =  inst_lu12i_w | inst_pcaddul2i;
    assign need_si26  =  inst_b | inst_bl;
    assign src2_is_4  =  inst_jirl | inst_bl;

    assign imm = src2_is_4 ? 32'h4                      :
                 need_si20 ? {i20[19:0], 12'b0}         :
                (need_ui5 || need_si12) ? {{20{i12[11]}}, i12[11:0]} :
                 {20'b0, i12[11:0]};

   assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                                {{14{i16[15]}}, i16[15:0], 2'b0} ;

    assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

    assign src_reg_is_rd = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu |
                           inst_st_b | inst_st_h | inst_st_w;

    assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddul2i;

    assign src2_is_imm   = inst_slli_w | inst_srli_w | inst_srai_w |
                           inst_addi_w |
                           inst_ld_b | inst_ld_h | inst_ld_w | inst_ld_bu | inst_ld_hu | 
                           inst_st_b | inst_st_h | inst_st_w |
                           inst_lu12i_w|
                           inst_jirl |
                           inst_bl |
                           inst_pcaddul2i|
                           inst_andi |
                           inst_ori |
                           inst_xori |
                           inst_slti |
                           inst_sltui;

    assign alu_src1 = src1_is_pc  ? id_pc[31:0] : rj_value;
    assign alu_src2 = src2_is_imm ? imm : rkd_value;

    assign res_from_mem  = {3'b0, inst_ld_b} |
                           {3'b0, inst_ld_bu} |
                           {2'b0, {2{inst_ld_h}}} |
                           {2'b0, {2{inst_ld_hu}}} |
                           {4{inst_ld_w}};
    assign load_unsigned = inst_ld_bu || inst_ld_hu;

    assign dst_is_r1     = inst_bl;
    assign gr_we         = ~(inst_st_b | inst_st_h | inst_st_w | 
                             inst_beq | inst_bne | inst_b | inst_blt | inst_bge | inst_bltu | inst_bgeu);
    assign dest          = dst_is_r1 ? 5'd1 : rd;

//regfile control
    assign rf_raddr1 = rj;
    assign rf_raddr2 = src_reg_is_rd ? rd :rk;
    assign id_rf_we    = gr_we ; 
    assign id_rf_waddr = dest; 
    
    assign {wb_rf_we, 
            wb_rf_waddr, 
            wb_rf_wdata} = wb_rf_zip;
            
    assign {mem_rf_we, 
            mem_rf_waddr,
            mem_rf_wdata} = mem_rf_zip;
            
    assign {id_delay,
            ex_rf_we, 
            ex_rf_waddr, 
            ex_rf_wdata} = ex_rf_zip;
    
    assign conflict_r1_wb  = (|rf_raddr1) & (rf_raddr1 == wb_rf_waddr)  & wb_rf_we;
    assign conflict_r2_wb  = (|rf_raddr2) & (rf_raddr2 == wb_rf_waddr)  & wb_rf_we;
    assign conflict_r1_mem = (|rf_raddr1) & (rf_raddr1 == mem_rf_waddr) & mem_rf_we;
    assign conflict_r2_mem = (|rf_raddr2) & (rf_raddr2 == mem_rf_waddr) & mem_rf_we;
    assign conflict_r1_ex  = (|rf_raddr1) & (rf_raddr1 == ex_rf_waddr)  & ex_rf_we;
    assign conflict_r2_ex  = (|rf_raddr2) & (rf_raddr2 == ex_rf_waddr)  & ex_rf_we;
    
    assign need_r1 = inst_add_w | inst_sub_w | inst_slt | inst_addi_w | inst_sltu | inst_nor | inst_and | inst_or | inst_xor | 
                     inst_srli_w | inst_slli_w | inst_srai_w | inst_sll_w | inst_srl_w | inst_sra_w |
                     inst_slti | inst_sltui | inst_andi | inst_ori |inst_xori |
                     inst_mul_w | inst_mulh_w | inst_mulh_wu | inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu |
                     inst_ld_b | inst_ld_h | inst_ld_w | inst_ld_bu | inst_ld_hu |
                     inst_st_b | inst_st_h | inst_st_w |
                     inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
                    
    assign need_r2 = inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_and | inst_or | inst_nor | inst_xor | 
                     inst_st_b | inst_st_h | inst_st_w | inst_sll_w | inst_srl_w | inst_sra_w | 
                     inst_mul_w | inst_mulh_w | inst_mulh_wu | inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu |
                     inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;

    regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (wb_rf_we    ),
    .waddr  (wb_rf_waddr ),
    .wdata  (wb_rf_wdata )
    );

    assign rj_value  =  conflict_r1_ex ? ex_rf_wdata:
                        conflict_r1_mem ? mem_rf_wdata:
                        conflict_r1_wb  ? wb_rf_wdata : rf_rdata1; 
                        
    assign rkd_value =  conflict_r2_ex ? ex_rf_wdata:
                        conflict_r2_mem ? mem_rf_wdata:
                        conflict_r2_wb  ? wb_rf_wdata : rf_rdata2; 

    assign id_rkd_value = rkd_value;
    assign id_res_from_mem = res_from_mem;

    assign res_from_mul = inst_mul_w | inst_mulh_w | inst_mulh_wu;
    assign res_from_div = inst_div_w | inst_div_wu | inst_mod_w | inst_mod_wu;

    assign mul_signed = inst_mul_w | inst_mulh_w;
    assign div_signed = inst_div_w | inst_mod_w;
    assign div_r      = inst_mod_w | inst_mod_wu;
    
    assign mul_h      = inst_mulh_w | inst_mulh_wu;
        
    assign id_to_ex_wire = {alu_op, alu_src1, alu_src2,
                            id_rf_we, id_rf_waddr,
                            id_pc,
                            inst_st_b, inst_st_h, inst_st_w,
                            id_rkd_value,
                            inst_ld_b, inst_ld_bu, inst_ld_h, inst_ld_hu, inst_ld_w,
                            res_from_mul, mul_signed, mul_h, res_from_div, div_signed, div_r};                            
    
endmodule

module adder_32(                
        input [31:0] A,
        input [31:0] B,
        input IN,
        output SF,        //����??
        output ZF,        //���־λ
        output CF,        //Carryout��־??
        output OF,        //Overflow��־??
        output [31:0] S  
);

        wire [31:0] p0;
        wire [31:0] g0;
        wire [31:0] c1;
        wire [7:0] p1;
        wire [7:0] g1;
        wire [7:0] c2;
        wire [1:0] p2;
        wire [1:0] g2;
        wire [1:0] c3;
        wire p3;
        wire g3;

        wire CIN;
        wire COUT;

        assign p0 = A | B;
        assign g0 = A & B;
        assign c1[0] = IN;
        assign c2[0] = IN;
        assign c3[0] = IN;

        genvar ic1;
        generate
            for (ic1 = 1; ic1 < 2; ic1 = ic1 + 1) begin: value_c2
                assign c2[ic1 * 4] = c3[ic1];
            end
        endgenerate

        genvar ic0;
        generate
            for (ic0 = 1; ic0 < 8; ic0 = ic0 + 1) begin: value_c1
                assign c1[ic0 * 4] = c2[ic0];
            end
        endgenerate

        genvar i0;
        generate
            for (i0 = 0; i0 < 8; i0 = i0 + 1) begin: floor0
                adder_4 adder_floor0(.c0(c2[i0]), .p(p0[i0 * 4 + 3 : i0 * 4]), .g(g0[i0 * 4 + 3 : i0 * 4]),
                .c1(c1[i0 * 4 + 1]), .c2(c1[i0 * 4 + 2]), .c3(c1[i0 * 4 + 3]), .P(p1[i0]), .G(g1[i0]));
            end
        endgenerate

        genvar i1;
        generate
            for (i1 = 0; i1 < 2; i1 = i1 + 1) begin: floor1
                adder_4 adder_floor1(.c0(c3[i1]), .p(p1[i1 * 4 + 3 : i1 * 4]), .g(g1[i1 * 4 + 3 : i1 * 4]),
                .c1(c2[i1 * 4 + 1]), .c2(c2[i1 * 4 + 2]), .c3(c2[i1 * 4 + 3]), .P(p2[i1]), .G(g2[i1]));
            end
        endgenerate

        adder_2 adder_floor2 (.c0(IN), .p(p2), .g(g2),
                .c1(c3[1]), .P(p3), .G(g3));

        genvar i_result;
        generate
            for (i_result = 0; i_result < 32; i_result = i_result + 1) begin: calc_Sum
                Full_Adder sum(.Cin(c1[i_result]), .A(A[i_result]), .B(B[i_result]), .S(S[i_result]), .Cout());
            end
        endgenerate

        assign COUT = p3 & IN | g3;
        assign CIN = c1[31];

        //SF:����?? ZF:���?? CF:��λ��׼ OF:�����׼       
        assign SF = S[31];
        assign ZF = ~|S;
        assign CF = ~COUT;
        assign OF =  CIN ^ COUT;

endmodule

module adder_2(                 //4λ�ӷ���
    input c0,
    input [1:0] p,
    input [1:0] g,
    output c1,
    output P,
    output G
);
    assign c1 = g[0] | p[0] & c0;
    assign P = &p;
    assign G = g[1] | p[1] & g[0];

endmodule