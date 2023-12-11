`include "mycpu_head.h"
module cache(
    input  wire         clk,
    input  wire         resetn,
    /* CPU interface */
    input  wire         valid,
    input  wire         op,
    input  wire  [ 7:0] index,
    input  wire  [19:0] tag,
    input  wire  [ 3:0] offset,
    input  wire  [ 3:0] wstrb,
    input  wire  [31:0] wdata,
    output wire         addr_ok,
    output wire         data_ok,
    output wire  [31:0] rdata,

    /* AXI interface */
    //read
    output wire         rd_req,
    output wire  [ 2:0] rd_type,
    output wire  [31:0] rd_addr,
    input  wire         rd_rdy,
    input  wire  [ 1:0] ret_last,
    input  wire  [31:0] ret_data,
    //write
    output wire         wr_req,
    output wire  [ 2:0] wr_type,
    output wire  [31:0] wr_addr,
    output wire  [ 3:0] wr_strb,
    output wire [127:0] wr_data,
    input  wire         wr_rdy
);

    //request buffer
    reg  [68:0] req_buffer;
    wire        op_reg;
    wire [ 7:0] index_reg;
    wire [19:0] tag_reg;
    wire [ 3:0] offset_reg;
    wire [ 3:0] wstrb_reg;
    wire [31:0] wdata_reg;

    always @(posedge clk) begin
        if(!resetn) begin
            req_buffer <= 69'b0;
        end
        else if(valid & addr_ok) begin
            req_buffer <= {op, index, tag, offset, wstrb, wdata};
        end
    end

    assign {op_reg, index_reg, tag_reg, offset_reg, wstrb_reg, wdata_reg} = req_buffer;

    /* cache data */
    wire        tag_we_0;
    wire [ 7:0] tag_addr_0;
    wire [19:0] tag_wdata_0;
    wire [19:0] tag_rdata_0;
    wire [ 3:0] data_bank_we_0 [3:0];
    wire [ 7:0] data_bank_addr_0 [3:0];
    wire [31:0] data_bank_wdata_0 [3:0];
    wire [31:0] data_bank_rdata_0 [3:0];
    reg [255:0] dirty_arr_0;
    reg [255:0] valid_arr_0;

    wire        tag_we_1;
    wire [ 7:0] tag_addr_1;
    wire [19:0] tag_wdata_1;
    wire [19:0] tag_rdata_1;
    wire [ 3:0] data_bank_we_1 [3:0];
    wire [ 7:0] data_bank_addr_1 [3:0];
    wire [31:0] data_bank_wdata_1 [3:0];
    wire [31:0] data_bank_rdata_1 [3:0];
    reg  [255:0] dirty_arr_1;
    reg  [255:0] valid_arr_1;

    /* tag match */
    wire        hit_write;
    wire        hit_write_conflict;
    wire        cache_hit;
    wire [ 1:0] way_hit;


    /* main state machine */
    parameter IDLE = 5'b00001;
    parameter LOOKUP = 5'b00010;
    parameter MISS = 5'b00100;
    parameter REPLACE = 5'b01000;
    parameter REFILL = 5'b10000;

    reg [4:0] current_state;
    reg [4:0] next_state;

    always @(posedge clk) begin
        if(!resetn) begin
            current_state <= IDLE;
        end
        else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        case (current_state)
            IDLE: 

            LOOKUP:

            MISS:

            REFILL:

            default: 
                next_state = IDLE;
        endcase
    end

    /* write state machine */
    parameter WR_IDLE = 2'b01;
    parameter WR_WRITE = 2'b10;

    reg [1:0] wr_current_state;
    reg [1:0] wr_next_state;

    always @(posedge clk) begin
        if(!resetn) begin
            wr_current_state <= WR_IDLE;
        end
        else begin
            wr_current_state <= wr_next_state;
        end
    end

    always @(*) begin
        case (wr_current_state)
            WR_IDLE: 

            WR_WRITE:

            default: 
                wr_next_state = WR_IDLE;
        endcase
    end

endmodule