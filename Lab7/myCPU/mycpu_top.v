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
    wire [31:0] ex_entry;

    wire        ex_mem_we;
    wire        ex_res_from_mem;
    wire [31:0] ex_rkd_value;
    wire [31:0] ex_alu_result;
    wire [63:0] mul_result;
    
    wire [37:0] wb_rf_zip;
    wire [38:0] mem_rf_zip;
    wire [39:0] ex_rf_zip;

    wire        br_taken;
    wire        br_stall;
    wire [31:0] br_target;
    
    wire if_flush;
    wire id_flush;
    wire ex_flush;
    wire mem_flush;
    wire wb_flush;
    wire mem_to_ex_excep;

    wire has_int;
    
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

        .id_allowin(id_allowin),
        .br_taken(br_taken),
        .br_stall(br_stall),
        .br_target(br_target),
        
        .if_to_id_valid(if_to_id_valid),
        .if_to_id_data(if_to_id_data),
        .if_to_id_excep(if_to_id_excep),

        .wb_to_if_csr_data(wb_to_if_csr_data),
        .if_flush(wb_flush)
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
        
        .mem_allowin(mem_allowin),
        .ex_to_mem_valid(ex_to_mem_valid),
        .ex_to_mem_data(ex_to_mem_data),
        .ex_to_mem_excep(ex_to_mem_excep),
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
        .mem_to_ex_excep(mem_to_ex_excep)
     );

    MEM_Stage my_MEM_Stage
    (
        .clk(aclk),
        .resetn(aresetn),

        .mem_allowin(mem_allowin),
        .ex_to_mem_valid(ex_to_mem_valid),
        .ex_to_mem_data(ex_to_mem_data),
        .ex_to_mem_excep(ex_to_mem_excep),
        
        .wb_allowin(wb_allowin),
        .mem_to_wb_valid(mem_to_wb_valid),
        .mem_to_wb_data(mem_to_wb_data),
        .mem_to_wb_excep(mem_to_wb_excep),
        
        .mul_result(mul_result),
        
        .data_sram_data_ok(data_sram_data_ok),
        .data_sram_rdata(data_sram_rdata),
        
        .mem_rf_zip(mem_rf_zip),
        .mem_flush(wb_flush),
        .mem_to_ex_excep(mem_to_ex_excep)
    ) ;

    WB_Stage my_WB_Stage
    (
        .clk(aclk),
        .resetn(aresetn),

        .wb_allowin(wb_allowin),
        .mem_to_wb_valid(mem_to_wb_valid),
        .mem_to_wb_data(mem_to_wb_data),
        .mem_to_wb_excep(mem_to_wb_excep),

        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata),

        .wb_rf_zip(wb_rf_zip),

        .wb_to_if_csr_data(wb_to_if_csr_data),
        .wb_flush(wb_flush),
        .has_int(has_int)
    );
    
endmodule