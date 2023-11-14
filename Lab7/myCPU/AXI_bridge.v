module AXI_bridge(
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
    output wire [31:0] debug_wb_rf_wdata,

    // inst sram interface
    input  wire        inst_sram_req,
    input  wire        inst_sram_wr,
    input  wire [ 1:0] inst_sram_size,
    input  wire [ 3:0] inst_sram_wstrb,
    input  wire [31:0] inst_sram_addr,
    input  wire [31:0] inst_sram_wdata,
    output wire        inst_sram_addr_ok,
    output wire        inst_sram_data_ok,
    output wire [31:0] inst_sram_rdata,
    // data sram interface
    input  wire        data_sram_req,
    input  wire        data_sram_wr,
    input  wire [ 1:0] data_sram_size,
    input  wire [ 3:0] data_sram_wstrb,
    input  wire [31:0] data_sram_addr,
    input  wire [31:0] data_sram_wdata,
    output wire        data_sram_addr_ok,
    output wire        data_sram_data_ok,
    output wire [31:0] data_sram_rdata,
    // trace debug interface
    input wire [31:0] debug_wb_pc,
    input wire [ 3:0] debug_wb_rf_we,
    input wire [ 4:0] debug_wb_rf_wnum,
    input wire [31:0] debug_wb_rf_wdata
);

    assign arid    = (data_sram_req)? 4'b1 : 4'b0;
    assign araddr  = (arid)? data_sram_addr : inst_sram_addr;
    assign arlen   = 8'b0;
    assign arsize  = (arid)? data_sram_size : inst_sram_size;
    assign arburst = 2'b01;
    assign arlock  = 2'b0;
    assign arcache = 4'b0;
    assign arprot  = 3'b0;
    assign arvalid = inst_sram_req | data_sram_req;
    
    assign rready  =
    
    assign awid    = 4'b1;
    assign awaddr  = (arid)? data_sram_addr : inst_sram_addr;
    assign awlen   = 8'b0;
    assign awsize  = (arid)? data_sram_size : inst_sram_size;
    assign awburst = 2'b01;
    assign awlock  = 2'b0;
    assign awcache = 4'b0;
    assign awprot  = 3'b0;
    assign awvalid = inst_sram_wr | data_sram_wr;
    
    assign wid     = 1'b1;
    assign wdata   = (arid)? data_sram_wdata : inst_sram_wdata;
    assign wstrb   = (arid)? data_sram_wstrb : inst_sram_wstrb;
    assign wlast   = 1'b1;
    assign wvalid  = inst_sram_wr | data_sram_wr;
    
    assign bready  =

    assign inst_sram_addr_ok =
    assign inst_sram_data_ok =
    assign inst_sram_rdata   = 
    assign data_sram_addr_ok =
    assign data_sram_data_ok =
    assign data_sram_rdata   =

endmodule