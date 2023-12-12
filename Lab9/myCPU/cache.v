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
    input  wire         ret_valid,
    input  wire  [ 1:0] ret_last,
    input  wire  [31:0] ret_data,
    //write
    output wire         wr_req,
    output wire  [ 2:0] wr_type,
    output wire  [31:0] wr_addr,
    output wire  [ 3:0] wr_wstrb,
    output wire [127:0] wr_data,
    input  wire         wr_rdy
);

/* ------buffers------ */
    // request buffer
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

    // write buffer
    reg  [48:0] write_buffer;
    wire        wrbuf_way;
    wire [ 7:0] wrbuf_index;
    wire [ 3:0] wrbuf_offset;
    wire [ 3:0] wrbuf_wstrb;
    wire [31:0] wrbuf_wdata;

    always @(posedge clk) begin
        if(~resetn) begin
            write_buffer <= 49'b0;
        end
        else if(hit_write) begin
            write_buffer <= {hit_way[1], index_reg, offset_reg, wstrb_reg, wdata_reg, wdata_reg};
        end
    end

    assign {wrbuf_way, wrbuf_index, wrbuf_offset, wrbuf_wstrb, wrbuf_wdata} = write_buffer;

    // burst data counter
    reg  [ 1:0] ret_cnt;
    always @(posedge clk) begin
        if(~resetn) begin
            ret_cnt <= 2'b0;
        end
        else if(ret_valid) begin
            if(~ret_last) begin
                ret_cnt <= ret_cnt + 1'b1;
            end
            else begin
                ret_cnt <= 2'b0;
            end
        end
    end

/* ------tag match------ */
    wire        hit_write;
    wire        hit_write_conflict;
    wire        cache_hit;
    wire [ 1:0] hit_way;
    wire [31:0] hit_result;

    assign hit_way[0] = valid_arr_0[index_reg] & tag_rdata_0 == tag_reg;
    assign hit_way[1] = valid_arr_1[index_reg] & tag_rdata_1 == tag_reg;
    assign cache_hit = hit_way[0] || hit_way[1];
    assign hit_write = current_state[LOOKUP] & cache_hit & op_reg;
    assign hit_write_conflict = (hit_write | wr_current_state[WR_WRITE]) & valid & ~op & {index, offset[3:2]} == {index_reg, offset_reg[3:2]};
    assign hit_result = {32{hit_way[0]}} & data_bank_rdata_0[offset_reg[3:2]] |
                        {32{hit_way[1]}} & data_bank_rdata_1[offset_reg[3:2]];
    
    // random replace way
    wire replace_way = $random[0];

/* ------main state machine------ */
    parameter state_IDLE    = 5'b00001;
    parameter state_LOOKUP  = 5'b00010;
    parameter state_MISS    = 5'b00100;
    parameter state_REPLACE = 5'b01000;
    parameter state_REFILL  = 5'b10000;
    parameter IDLE    = 0;
    parameter LOOKUP  = 1;
    parameter MISS    = 2;
    parameter REPLACE = 3;
    parameter REFILL  = 4;

    reg [4:0] current_state;
    reg [4:0] next_state;

    always @(posedge clk) begin
        if(~resetn) begin
            current_state <= state_IDLE;
        end
        else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        case (current_state)
            state_IDLE: 
                if(valid & ~hit_write_conflict) begin
                    next_state = state_LOOKUP;
                end
                else begin
                    next_state = state_IDLE;
                end

            state_LOOKUP:
                if(cache_hit & (~valid || hit_write_conflict)) begin
                    next_state = state_IDLE;
                end
                else if(cache_hit & valid & hit_write_conflict) begin
                    next_state = state_LOOKUP;
                end
                else if(~cache_hit) begin
                    next_state = state_MISS;
                end

            state_MISS:
                if(~wr_rdy) begin
                    next_state = state_MISS;
                end
                else begin
                    next_state = state_REPLACE;
                end

            state_REPLACE:
                if(~rd_rdy) begin
                    next_state = state_REPLACE;
                end
                else begin
                    next_state = state_REFILL;
                end

            state_REFILL:
                if(ret_valid & ret_last[0]) begin
                    next_state = state_IDLE;
                end
                else begin
                    next_state = state_REFILL;
                end

            default: 
                next_state = state_IDLE;
        endcase
    end

/* ------write state machine------ */
    parameter state_WR_IDLE = 2'b01;
    parameter state_WR_WRITE = 2'b10;
    parameter WR_IDLE = 0;
    parameter WR_WRITE = 1;

    reg [1:0] wr_current_state;
    reg [1:0] wr_next_state;

    always @(posedge clk) begin
        if(~resetn) begin
            wr_current_state <= state_WR_IDLE;
        end
        else begin
            wr_current_state <= wr_next_state;
        end
    end

    always @(*) begin
        case (wr_current_state)
            state_WR_IDLE: 
                if(hit_write) begin
                    wr_next_state = state_WR_WRITE;
                end
                else begin
                    wr_next_state = state_WR_IDLE;
                end

            state_WR_WRITE:
                if(hit_write) begin
                    wr_next_state = state_WR_WRITE;
                end
                else begin
                    wr_next_state = state_WR_IDLE;
                end

            default: 
                wr_next_state = state_WR_IDLE;
        endcase
    end

/* ------cache data & control------ */
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

    // dirty array
    always @(posedge clk) begin
        if(~resetn) begin
            dirty_arr_0 <= 256'b0;
        end
        else if(wr_current_state[WR_WRITE] & ~wrbuf_way) begin
            if(wrbuf_way) begin
                dirty_arr_1[wrbuf_index] <= 1'b1;
            end
            else begin
                dirty_arr_0[wrbuf_index] <= 1'b1;
            end
        end
        else if(ret_valid & ret_last[0] & ~replace_way) begin
            if(replace_way) begin
                dirty_arr_1[index_reg] <= op_reg;
            end
            else begin
                dirty_arr_0[index_reg] <= op_reg;
            end
        end
    end

    // valid array
    always @(posedge clk) begin
        if(~resetn) begin
            valid_arr_0 <= 256'b0;
            valid_arr_1 <= 256'b0;
        end
        else if(ret_valid & ret_last[0]) begin
            if(replace_way) begin
                valid_arr_1[index_reg] <= 1'b1;
            end
            else begin
                valid_arr_0[index_reg] <= 1'b1;
            end
        end
    end

    // RAM port
    assign tag_we_0 = ret_valid & ret_last[0] & ~replace_way;
    assign tag_we_1 = ret_valid & ret_last[0] & replace_way;
    assign tag_addr_0 = (current_state[IDLE] | current_state[LOOKUP])? index : index_reg;
    assign tag_addr_1 = (current_state[IDLE] | current_state[LOOKUP])? index : index_reg;
    assign tag_wdata_0 = tag_reg;
    assign tag_wdata_1 = tag_reg;

    genvar i;
    generate
        for (i=0; i<4; i=i+1) begin
            assign data_bank_we_0[i] = {4{wr_current_state[WR_WRITE] & (wrbuf_offset[3:2] == i) & ~wrbuf_way}} & wrbuf_wstrb
                                     | {4{ret_valid & (ret_cnt == i) & ~replace_way}} & 4'hf;
            assign data_bank_we_1[i] = {4{wr_current_state[WR_WRITE] & (wrbuf_offset[3:2] == i) & wrbuf_way}} & wrbuf_wstrb
                                     | {4{ret_valid & (ret_cnt == i) & replace_way}} & 4'hf;
            
            assign data_bank_addr_0[i] = (current_state[IDLE] | current_state[LOOKUP])? index : index_reg;
            assign data_bank_addr_1[i] = (current_state[IDLE] | current_state[LOOKUP])? index : index_reg;

            assign data_bank_wdata_0[i] = (wr_current_state[WR_WRITE])? wrbuf_wdata :
                                          (offset_reg[3:2] != i || ~op_reg)? ret_data : 
                                          {wstrb_r[3] ? wdata_r[31:24] : ret_data[31:24],
                                           wstrb_r[2] ? wdata_r[23:16] : ret_data[23:16],
                                           wstrb_r[1] ? wdata_r[15: 8] : ret_data[15: 8],
                                           wstrb_r[0] ? wdata_r[ 7: 0] : ret_data[ 7: 0]};  
            assign data_bank_wdata_1[i] = (wr_current_state[WR_WRITE])? wrbuf_wdata :
                                          (offset_reg[3:2] != i || ~op_reg)? ret_data : 
                                          {wstrb_r[3] ? wdata_r[31:24] : ret_data[31:24],
                                           wstrb_r[2] ? wdata_r[23:16] : ret_data[23:16],
                                           wstrb_r[1] ? wdata_r[15: 8] : ret_data[15: 8],
                                           wstrb_r[0] ? wdata_r[ 7: 0] : ret_data[ 7: 0]};
        end
    endgenerate

    // RAM instance 
    TAG_RAM TAG_RAM[0] (
        .clka (clk),
        .wea  (tag_we_0),
        .addra(tag_addr_0),
        .dina (tag_wdata_0),
        .douta(tag_rdata_0) 
    );
    TAG_RAM tag_ram[1] (
        .clka (clk),
        .wea  (tag_we_1),
        .addra(tag_addr_1),
        .dina (tag_wdata_1),
        .douta(tag_rdata_1) 
    );
    
    generate
        for(i=0; i<4; i=i+1) begin
            DATA_Bank_RAM data_bank_ram_0[i](
                .clka (clk),
                .wea  (data_bank_we_0[i]),
                .addra(data_bank_addr_0[i]),
                .dina (data_bank_wdata_0[i]),
                .douta(data_bank_rdata_0[i])
            );
            DATA_Bank_RAM data_bank_ram_1[i](
                .clka (clk),
                .wea  (data_bank_we_1[i]),
                .addra(data_bank_addr_1[i]),
                .dina (data_bank_wdata_1[i]),
                .douta(data_bank_rdata_1[i])
            );
        end
    endgenerate

/* ------CPU interface------ */
    assign addr_ok = current_state[IDLE] | (current_state[LOOKUP] & valid & cache_hit & (op | ~op & hit_write_conflict));

    assign data_ok = (current_state[LOOKUP] & cache_hit) | (current_state[LOOKUP] & op_reg) 
                   | (current_state[REFILL] & ~op_reg & ret_valid & ret_cnt==offset_r[3:2]);

    assign rdata = (ret_valid)? ret_data : hit_result;
    
/* ------AXI interface------ */
    // read port
    assign rd_type = 3'b100;
    assign rd_addr = {tag_reg, index_reg, offset_reg};
    assign rd_req = current_state[REPLACE];

    // write port
    reg wr_req_reg;
    always @(posedge clk) begin
        if(~resetn) begin
            wr_req_reg <= 1'b0;
        end
        else if(current_state[MISS] & next_state[REPLACE]) begin
            wr_req_reg <= 1'b1;
        end
        else if(wr_rdy) begin
            wr_req_reg <= 1'b0;
        end
    end

    assign wr_req = wr_req_reg;
    assign wr_type = 3'b100;
    assign wr_addr = (replace_way)? {tag_rdata_1, index_reg, offset_reg} : {tag_rdata_0, index_reg, offset_reg};
    assign wr_wstrb = 4'hf;
    assign wr_data = (replace_way)? {data_bank_rdata_1[3], data_bank_rdata_1[2], data_bank_rdata_1[1], data_bank_rdata_1[0]}:
                                    {data_bank_rdata_0[3], data_bank_rdata_0[2], data_bank_rdata_0[1], data_bank_rdata_0[0]};

endmodule