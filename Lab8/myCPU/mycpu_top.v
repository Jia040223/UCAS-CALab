module mycpu_top(
    input  wire        aclk,
    input  wire        aresetn,
    // read request interface
    output wire [ 3:0] arid   ,
    output wire [31:0] araddr ,
    output wire [ 7:0] arlen  ,
    output wire [ 2:0] arsize ,
    output wire [ 1:0] arburst,
    output wire [ 1:0] arlock ,
    output wire [ 3:0] arcache,
    output wire [ 2:0] arprot ,
    output wire        arvalid,
    input  wire        arready,
    // read response interface
    input  wire [ 3:0] rid    ,
    input  wire [31:0] rdata  ,
    input  wire [ 1:0] rresp  ,
    input  wire        rlast  ,
    input  wire        rvalid ,
    output wire        rready ,
    // write request interface
    output wire [ 3:0] awid   ,
    output wire [31:0] awaddr ,
    output wire [ 7:0] awlen  ,
    output wire [ 2:0] awsize ,
    output wire [ 1:0] awburst,
    output wire [ 1:0] awlock ,
    output wire [ 3:0] awcache,
    output wire [ 2:0] awprot ,
    output wire        awvalid,
    input  wire        awready,
    // write data interface
    output wire [ 3:0] wid    ,
    output wire [31:0] wdata  ,
    output wire [ 3:0] wstrb  ,
    output wire        wlast  ,
    output wire        wvalid ,
    input  wire        wready ,
    // write response interface
    input  wire [ 3:0] bid    ,
    input  wire [ 1:0] bresp  ,
    input  wire        bvalid ,
    output wire        bready ,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    wire        id_allowin;
    wire        ex_allowin;
    wire        mem_allowin;
    wire        wb_allowin;

    wire        if_to_id_valid;
    wire        id_to_ex_valid;
    wire        ex_to_mem_valid;
    wire        mem_to_wb_valid;
    
    wire [`IF_TO_ID_DATA_WIDTH  - 1:0] if_to_id_data;
    wire [`ID_TO_EX_DATA_WIDTH  - 1:0] id_to_ex_data;
    wire [`EX_TO_MEM_DATA_WIDTH - 1:0] ex_to_mem_data;
    wire [`MEM_TO_WB_DATA_WIDTH - 1:0] mem_to_wb_data;

    wire [`IF_TO_ID_EXCEP_WIDTH  - 1:0] if_to_id_excep;
    wire [`ID_TO_EX_EXCEP_WIDTH  - 1:0] id_to_ex_excep;
    wire [`EX_TO_MEM_EXCEP_WIDTH - 1:0] ex_to_mem_excep;
    wire [`MEM_TO_WB_EXCEP_WIDTH - 1:0] mem_to_wb_excep;

    wire [`ID_TO_EX_TLB_WIDTH  - 1:0] id_to_ex_tlb;
    wire [`EX_TO_MEM_TLB_WIDTH - 1:0] ex_to_mem_tlb;
    wire [`MEM_TO_WB_TLB_WIDTH - 1:0] mem_to_wb_tlb;

    wire        ex_mem_we;
    wire        ex_res_from_mem;
    wire [31:0] ex_rkd_value;
    wire [31:0] ex_alu_result;
    wire [63:0] mul_result;
    
    wire [37:0] wb_rf_zip;
    wire [39:0] mem_rf_zip;
    wire [39:0] ex_rf_zip;

    wire        br_taken;
    wire        br_stall;
    wire [31:0] br_target;
    
    wire        if_flush;
    wire        id_flush;
    wire        ex_flush;
    wire        mem_flush;
    wire        wb_flush;
    wire        mem_to_ex_excep;
    wire [ 3:0] ex_to_wb_rand;

    wire [`WB_TO_IF_CSR_DATA_WIDTH -1:0]  wb_to_if_csr_data;

    wire        inst_sram_req;
    wire        inst_sram_wr;
    wire [ 1:0] inst_sram_size;
    wire [ 3:0] inst_sram_wstrb;
    wire [31:0] inst_sram_addr;
    wire [31:0] inst_sram_wdata;
    wire        inst_sram_addr_ok;
    wire        inst_sram_data_ok;
    wire [31:0] inst_sram_rdata;
    
    wire        data_sram_req;
    wire        data_sram_wr;
    wire [ 1:0] data_sram_size;
    wire [ 3:0] data_sram_wstrb;
    wire [31:0] data_sram_addr;
    wire [31:0] data_sram_wdata;
    wire        data_sram_addr_ok;
    wire        data_sram_data_ok;
    wire [31:0] data_sram_rdata;

    //exp13 csr
    wire [13:0] wb_csr_num;
    wire        wb_csr_we;
    wire [31:0] wb_csr_wmask;
    wire [31:0] wb_csr_wvalue;
    wire        wb_ertn_flush_valid;
    wire        wb_excep_valid;
    wire [ 5:0] wb_csr_ecode;
    wire [ 8:0] wb_csr_esubcode;
    wire [31:0] wb_pc;

    wire [31:0] csr_rvalue;
    wire [31:0] ex_entry;

    wire        ipi_int_in;
    wire [ 7:0] hw_int_in;
    wire [31:0] coreid_in;
    wire [31:0] wb_vaddr;
    wire        has_int;

    //exp18
    wire [ 9:0] csr_asid_asid;
    wire [18:0] csr_tlbehi_vppn;
    wire [ 3:0] csr_tlbidx_index;

    wire        mem_csr_tlbrd;
    wire        wb_csr_tlbrd;

    wire tlbrd_we;
    wire tlbsrch_we;
    // wire tlbwr_we;
    // wire tlbfill_we;
    wire tlbsrch_hit;
    wire [ 3:0] tlbsrch_hit_index;

    // TLB ports
    wire [18:0] s0_vppn;
    wire        s0_va_bit12;
    wire [ 9:0] s0_asid;
    wire        s0_found;
    wire [ 3:0] s0_index;
    wire [19:0] s0_ppn;
    wire [ 5:0] s0_ps;
    wire [ 1:0] s0_plv;
    wire [ 1:0] s0_mat;
    wire        s0_d;
    wire        s0_v;

    wire [18:0] s1_vppn;
    wire        s1_va_bit12;
    wire [ 9:0] s1_asid;
    wire        s1_found;
    wire [ 3:0] s1_index;
    wire [19:0] s1_ppn;
    wire [ 5:0] s1_ps;
    wire [ 1:0] s1_plv;
    wire [ 1:0] s1_mat;
    wire        s1_d;
    wire        s1_v;

    wire [ 4:0] invtlb_op;
    wire        invtlb_valid;

    wire        tlb_we;
    wire [ 3:0] w_index;
    wire        w_e;
    wire [18:0] w_vppn;
    wire [ 5:0] w_ps;
    wire [ 9:0] w_asid;
    wire        w_g;

    wire [19:0] w_ppn0;
    wire [ 1:0] w_plv0;
    wire [ 1:0] w_mat0;
    wire        w_d0;
    wire        w_v0;

    wire [19:0] w_ppn1;
    wire [ 1:0] w_plv1;
    wire [ 1:0] w_mat1;
    wire        w_d1;
    wire        w_v1;

    wire [ 3:0] r_index;
    wire        r_e;
    wire [18:0] r_vppn;
    wire [ 5:0] r_ps;
    wire [ 9:0] r_asid;
    wire        r_g;

    wire [19:0] r_ppn0;
    wire [ 1:0] r_plv0;
    wire [ 1:0] r_mat0;
    wire        r_d0;
    wire        r_v0;

    wire [19:0] r_ppn1;
    wire [ 1:0] r_plv1;
    wire [ 1:0] r_mat1;
    wire        r_d1;
    wire        r_v1;

    wire [31:0] csr_crmd_rvalue;
    wire [31:0] csr_asid_rvalue;
    wire [31:0] csr_dmw0_rvalue;
    wire [31:0] csr_dmw1_rvalue; 

    wire        inst_page_invalid;
    wire        inst_ppi_except;
    wire        inst_page_fault;
    wire        inst_page_clean;

    wire        data_page_invalid;
    wire        data_ppi_except;
    wire        data_page_fault;
    wire        data_page_clean;

    wire [ 9:0] if_asid;
    wire [ 9:0] ex_asid;

    wire [31:0] inst_va;
    wire [31:0] inst_pa;
    wire [31:0] data_va;
    wire [31:0] data_pa;

    AXI_bridge my_AXI_bridge(
        .aclk(aclk),
        .aresetn(aresetn),
        .arid(arid),
        .araddr(araddr),
        .arlen(arlen),
        .arsize(arsize),
        .arburst(arburst),
        .arlock(arlock),
        .arcache(arcache),
        .arprot(arprot),
        .arvalid(arvalid),
        .arready(arready),

        .rid(rid),
        .rdata(rdata),
        .rresp(rresp),
        .rlast(rlast),
        .rvalid(rvalid),
        .rready(rready),

        .awid(awid),
        .awaddr(awaddr),
        .awlen(awlen),
        .awsize(awsize),
        .awburst(awburst),
        .awlock(awlock),
        .awcache(awcache),
        .awprot(awprot),
        .awvalid(awvalid),
        .awready(awready),

        .wid(wid),
        .wdata(wdata),
        .wstrb(wstrb),
        .wlast(wlast),
        .wvalid(wvalid),
        .wready(wready),

        .bid(bid),
        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready),

        .inst_sram_req(inst_sram_req),
        .inst_sram_wr(inst_sram_wr),
        .inst_sram_size(inst_sram_size),
        .inst_sram_wstrb(inst_sram_wstrb),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_addr_ok(inst_sram_addr_ok),
        .inst_sram_data_ok(inst_sram_data_ok),
        .inst_sram_rdata(inst_sram_rdata),
        
        .data_sram_req(data_sram_req),
        .data_sram_wr(data_sram_wr),
        .data_sram_size(data_sram_size),
        .data_sram_wstrb(data_sram_wstrb),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_addr_ok(data_sram_addr_ok),
        .data_sram_data_ok(data_sram_data_ok),
        .data_sram_rdata(data_sram_rdata)
    );

    IF_Stage my_IF_Stage
    (
        .clk(aclk),
        .resetn(aresetn),

        .inst_sram_req(inst_sram_req),
        .inst_sram_wr(inst_sram_wr),
        .inst_sram_size(inst_sram_size),
        .inst_sram_wstrb(inst_sram_wstrb),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_addr_ok(inst_sram_addr_ok),
        .inst_sram_data_ok(inst_sram_data_ok),
        .inst_sram_rdata(inst_sram_rdata),
        .axi_arid(arid),

        .id_allowin(id_allowin),
        .br_taken(br_taken),
        .br_stall(br_stall),
        .br_target(br_target),
        
        .if_to_id_valid(if_to_id_valid),
        .if_to_id_data(if_to_id_data),
        .if_to_id_excep(if_to_id_excep),

        .wb_to_if_csr_data(wb_to_if_csr_data),
        .if_flush(wb_flush),

        .csr_asid_rvalue(csr_asid_rvalue),
        .va         (inst_va),
        .pa         (inst_pa),
        .if_asid    (if_asid),

        .page_invalid   (inst_page_invalid),
        .ppi_except     (inst_ppi_except),
        .page_fault     (inst_page_fault),
        .page_clean     (inst_page_clean)
    );

    ID_Stage my_ID_Stage
    (
        .clk(aclk),
        .resetn(aresetn),

        .id_allowin(id_allowin),
        .br_taken(br_taken),
        .br_stall(br_stall),
        .br_target(br_target),
        .if_to_id_valid(if_to_id_valid),
        .if_to_id_data(if_to_id_data),
        .if_to_id_excep(if_to_id_excep),

        .ex_allowin(ex_allowin),
        .id_to_ex_valid(id_to_ex_valid),
        .id_to_ex_data(id_to_ex_data),
        .id_to_ex_excep(id_to_ex_excep),
        .id_to_ex_tlb(id_to_ex_tlb),
      
        .wb_rf_zip(wb_rf_zip),
        .mem_rf_zip(mem_rf_zip),
        .ex_rf_zip(ex_rf_zip),

        .id_flush(wb_flush),
        .has_int(has_int)
    );

    EX_Stage my_EX_Stage
    (
        .clk(aclk),
        .resetn(aresetn),
        
        .ex_allowin(ex_allowin),
        .id_to_ex_valid(id_to_ex_valid),
        .id_to_ex_data(id_to_ex_data),
        .id_to_ex_excep(id_to_ex_excep),
        .id_to_ex_tlb(id_to_ex_tlb),
        
        .mem_allowin(mem_allowin),
        .ex_to_mem_valid(ex_to_mem_valid),
        .ex_to_mem_data(ex_to_mem_data),
        .ex_to_mem_excep(ex_to_mem_excep),
        .ex_to_mem_tlb(ex_to_mem_tlb),
        .mul_result(mul_result),
   
        .data_sram_req(data_sram_req),
        .data_sram_wr(data_sram_wr),
        .data_sram_size(data_sram_size),
        .data_sram_wstrb(data_sram_wstrb),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_addr_ok(data_sram_addr_ok),
        
        .ex_rf_zip(ex_rf_zip),
        .ex_flush(wb_flush),
        .mem_to_ex_excep(mem_to_ex_excep),

        .s1_va_highbits   ({s1_vppn, s1_va_bit12}),
        .s1_asid          (s1_asid),
        .invtlb_valid     (invtlb_valid),
        .invtlb_op        (invtlb_op),
        .csr_asid_asid    (csr_asid_asid),
        .csr_tlbehi_vppn  (csr_tlbehi_vppn),
        .mem_csr_tlbrd    (mem_csr_tlbrd),
        .wb_csr_tlbrd     (wb_csr_tlbrd),
        .s1_found         (s1_found),
        .s1_index         (s1_index),

        .ex_to_wb_rand    (ex_to_wb_rand),

        .csr_asid_rvalue(csr_asid_rvalue),
        .va             (data_va),
        .pa             (data_pa),
        .ex_asid        (ex_asid),

        .page_invalid   (data_page_invalid),
        .ppi_except     (data_ppi_except),
        .page_fault     (data_page_fault),
        .page_clean     (data_page_clean)
     );

    MEM_Stage my_MEM_Stage
    (
        .clk(aclk),
        .resetn(aresetn),

        .mem_allowin(mem_allowin),
        .ex_to_mem_valid(ex_to_mem_valid),
        .ex_to_mem_data(ex_to_mem_data),
        .ex_to_mem_excep(ex_to_mem_excep),
        .ex_to_mem_tlb(ex_to_mem_tlb),
        
        .wb_allowin(wb_allowin),
        .mem_to_wb_valid(mem_to_wb_valid),
        .mem_to_wb_data(mem_to_wb_data),
        .mem_to_wb_excep(mem_to_wb_excep),
        .mem_to_wb_tlb(mem_to_wb_tlb),

        .mul_result(mul_result),
        
        .data_sram_data_ok(data_sram_data_ok),
        .data_sram_rdata(data_sram_rdata),
        
        .mem_rf_zip(mem_rf_zip),
        .mem_flush(wb_flush),
        .mem_to_ex_excep(mem_to_ex_excep),

        .mem_csr_tlbrd    (mem_csr_tlbrd)
    ) ;

    WB_Stage my_WB_Stage
    (
        .clk(aclk),
        .resetn(aresetn),

        .wb_allowin(wb_allowin),
        .mem_to_wb_valid(mem_to_wb_valid),
        .mem_to_wb_data(mem_to_wb_data),
        .mem_to_wb_excep(mem_to_wb_excep),
        .mem_to_wb_tlb(mem_to_wb_tlb),

        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata),

        .wb_rf_zip(wb_rf_zip),

        .wb_to_if_csr_data(wb_to_if_csr_data),
        .wb_flush(wb_flush),

        .wb_csr_num(wb_csr_num),
        .wb_csr_we(wb_csr_we),
        .wb_csr_wmask(wb_csr_wmask),
        .wb_csr_wvalue(wb_csr_wvalue),
        .wb_ertn_flush_valid(wb_ertn_flush_valid),
        .wb_excep_valid(wb_excep_valid),
        .wb_csr_ecode(wb_csr_ecode), 
        .wb_csr_esubcode(wb_csr_esubcode), 
        .wb_pc(wb_pc),
        .csr_rvalue(csr_rvalue),
        .ex_entry(ex_entry),

        .has_int(has_int),
        .ipi_int_in(ipi_int_in),
        .hw_int_in(hw_int_in),
        .coreid_in(coreid_in),
        .wb_vaddr(wb_vaddr),

        .r_index         (r_index),
        .tlbrd_we        (tlbrd_we),
        .csr_tlbidx_index(csr_tlbidx_index),

        .w_index         (w_index),
        .tlb_we          (tlb_we),
        
        .tlbsrch_we      (tlbsrch_we),
        .tlbsrch_hit     (tlbsrch_hit),
        .tlbsrch_hit_index(tlbsrch_hit_index),

        .wb_csr_tlbrd(wb_csr_tlbrd),
        .ex_to_wb_rand(ex_to_wb_rand)
    );

    csr my_csr(
        .clk        (aclk  ),
        .resetn      (aresetn),
        .csr_num(wb_csr_num),
        .csr_we(wb_csr_we),
        .csr_wmask(wb_csr_wmask),
        .csr_wvalue(wb_csr_wvalue),
        .ertn_flush(wb_ertn_flush_valid),
        .wb_ex(wb_excep_valid),
        .wb_ecode(wb_csr_ecode), 
        .wb_esubcode(wb_csr_esubcode), 
        .wb_pc(wb_pc),
        .csr_rvalue(csr_rvalue),
        .ex_entry(ex_entry),

        .has_int(has_int),
        .ipi_int_in(ipi_int_in),
        .hw_int_in(hw_int_in),
        .coreid_in(coreid_in),
        .wb_vaddr(wb_vaddr),

        .csr_asid_asid   (csr_asid_asid),
        .csr_tlbehi_vppn (csr_tlbehi_vppn),
        .csr_tlbidx_index(csr_tlbidx_index),

        .tlbsrch_we        (tlbsrch_we),
        .tlbsrch_hit       (tlbsrch_hit),
        .tlbsrch_hit_index (tlbsrch_hit_index),
        .tlbrd_we          (tlbrd_we),

        .r_tlb_e         (r_e),
        .r_tlb_ps        (r_ps),
        .r_tlb_vppn      (r_vppn),
        .r_tlb_asid      (r_asid),
        .r_tlb_g         (r_g),
        .r_tlb_ppn0      (r_ppn0),
        .r_tlb_plv0      (r_plv0),
        .r_tlb_mat0      (r_mat0),
        .r_tlb_d0        (r_d0),
        .r_tlb_v0        (r_v0),
        .r_tlb_ppn1      (r_ppn1),
        .r_tlb_plv1      (r_plv1),
        .r_tlb_mat1      (r_mat1),
        .r_tlb_d1        (r_d1),
        .r_tlb_v1        (r_v1),

        .w_tlb_e         (w_e),
        .w_tlb_ps        (w_ps),
        .w_tlb_vppn      (w_vppn),
        .w_tlb_asid      (w_asid),
        .w_tlb_g         (w_g),
        .w_tlb_ppn0      (w_ppn0),
        .w_tlb_plv0      (w_plv0),
        .w_tlb_mat0      (w_mat0),
        .w_tlb_d0        (w_d0),
        .w_tlb_v0        (w_v0),
        .w_tlb_ppn1      (w_ppn1),
        .w_tlb_plv1      (w_plv1),
        .w_tlb_mat1      (w_mat1),
        .w_tlb_d1        (w_d1),
        .w_tlb_v1        (w_v1),

        .csr_crmd_rvalue(csr_crmd_rvalue),
        .csr_asid_rvalue(csr_asid_rvalue),
        .csr_dmw0_rvalue(csr_dmw0_rvalue),
        .csr_dmw1_rvalue(csr_dmw1_rvalue)
    );

    tlb my_tlb(
        .clk        (aclk),
        
        .s0_vppn    (s0_vppn),
        .s0_va_bit12(s0_va_bit12),
        .s0_asid    (s0_asid),
        .s0_found   (s0_found),
        .s0_index   (s0_index),
        .s0_ppn     (s0_ppn),
        .s0_ps      (s0_ps),
        .s0_plv     (s0_plv),
        .s0_mat     (s0_mat),
        .s0_d       (s0_d),
        .s0_v       (s0_v),

        .s1_vppn    (s1_vppn),
        .s1_va_bit12(s1_va_bit12),
        .s1_asid    (s1_asid),
        .s1_found   (s1_found),
        .s1_index   (s1_index),
        .s1_ppn     (s1_ppn),
        .s1_ps      (s1_ps),
        .s1_plv     (s1_plv),
        .s1_mat     (s1_mat),
        .s1_d       (s1_d),
        .s1_v       (s1_v),

        .invtlb_op  (invtlb_op),
        .invtlb_valid(invtlb_valid),
        
        .we         (tlb_we),
        .w_index    (w_index),
        .w_e        (w_e),
        .w_vppn     (w_vppn),
        .w_ps       (w_ps),
        .w_asid     (w_asid),
        .w_g        (w_g),
        .w_ppn0     (w_ppn0),
        .w_plv0     (w_plv0),
        .w_mat0     (w_mat0),
        .w_d0       (w_d0),
        .w_v0       (w_v0),
        .w_ppn1     (w_ppn1),
        .w_plv1     (w_plv1),
        .w_mat1     (w_mat1),
        .w_d1       (w_d1),
        .w_v1       (w_v1),

        .r_index    (r_index),
        .r_e        (r_e),
        .r_vppn     (r_vppn),
        .r_ps       (r_ps),
        .r_asid     (r_asid),
        .r_g        (r_g),

        .r_ppn0     (r_ppn0),
        .r_plv0     (r_plv0),
        .r_mat0     (r_mat0),
        .r_d0       (r_d0),
        .r_v0       (r_v0),

        .r_ppn1     (r_ppn1),
        .r_plv1     (r_plv1),
        .r_mat1     (r_mat1),
        .r_d1       (r_d1),
        .r_v1       (r_v1)
    );

    MMU inst_mmu(
        .s_vppn     (s0_vppn),
        .s_va_bit12 (s0_va_bit12),
        .s_asid     (s0_asid),
        .s_found    (s0_found),
        .s_ppn      (s0_ppn),
        .s_ps       (s0_ps),
        .s_plv      (s0_plv),
        .s_mat      (s0_mat),
        .s_d        (s0_d),
        .s_v        (s0_v),

        .va         (inst_va),
        .pa         (inst_pa),
        .asid_input  (if_asid),

        .csr_crmd_rvalue(csr_crmd_rvalue),
        .csr_dmw0_rvalue(csr_dmw0_rvalue),
        .csr_dmw1_rvalue(csr_dmw1_rvalue),

        .page_invalid   (inst_page_invalid),
        .ppi_except     (inst_ppi_except),
        .page_fault     (inst_page_fault),
        .page_clean     (inst_page_clean)
    );

    MMU data_mmu(
        .s_vppn     (s1_vppn),
        .s_va_bit12 (s1_va_bit12),
        .s_asid     (s1_asid),
        .s_found    (s1_found),
        .s_ppn      (s1_ppn),
        .s_ps       (s1_ps),
        .s_plv      (s1_plv),
        .s_mat      (s1_mat),
        .s_d        (s1_d),
        .s_v        (s1_v),

        .va         (data_va),
        .pa         (data_pa),
        .asid_input  (ex_asid),

        .csr_crmd_rvalue(csr_crmd_rvalue),
        .csr_dmw0_rvalue(csr_dmw0_rvalue),
        .csr_dmw1_rvalue(csr_dmw1_rvalue),

        .page_invalid   (data_page_invalid),
        .ppi_except     (data_ppi_except),
        .page_fault     (data_page_fault),
        .page_clean     (data_page_clean)
    );
    
endmodule