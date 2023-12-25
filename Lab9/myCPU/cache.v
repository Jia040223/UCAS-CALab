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
    reg         op_reg;
    reg  [ 7:0] index_reg;
    reg  [19:0] tag_reg;
    reg  [ 3:0] offset_reg;
    reg  [ 3:0] wstrb_reg;
    reg  [31:0] wdata_reg;

    // write buffer
    reg         wrbuf_way;
    reg  [ 7:0] wrbuf_index;
    reg  [ 3:0] wrbuf_offset;
    reg  [ 3:0] wrbuf_wstrb;
    reg  [31:0] wrbuf_wdata;

/* ------tag match------ */
    wire                    hit_write;
    wire                    hit_write_conflict;
    wire                    cache_hit;
    wire [`CACHE_WAY - 1:0] hit_way;
    wire [            31:0] hit_result;

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

/* ------write state machine------ */
    parameter state_WR_IDLE = 2'b01;
    parameter state_WR_WRITE = 2'b10;
    parameter WR_IDLE = 0;
    parameter WR_WRITE = 1;

    reg [1:0] wr_current_state;
    reg [1:0] wr_next_state;

/* ------cache data & control------ */
    wire         tagv_we          [`CACHE_WAY - 1:0];
    wire [ 7:0]  tagv_addr;
    wire [20:0]  tagv_wdata;
    wire [20:0]  tagv_rdata       [`CACHE_WAY - 1:0];
    wire [ 3:0]  data_bank_we    [`CACHE_WAY - 1:0][3:0];
    wire [ 7:0]  data_bank_addr  [3:0];
    wire [31:0]  data_bank_wdata [3:0];
    wire [31:0]  data_bank_rdata [`CACHE_WAY - 1:0][3:0];
    reg  [255:0] dirty_arr       [`CACHE_WAY - 1:0];
    
    reg  [ 7:0] call_cnt         [`CACHE_WAY - 1:0][255:0];
    reg  replace_way;

    reg  [ 1:0] ret_cnt;

    genvar i, way;

/* ------main state machine------ */
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
                if(valid & ~hit_write_conflict)
                    next_state = state_LOOKUP;
                else
                    next_state = state_IDLE;

            state_LOOKUP:
                if(cache_hit & (~valid | hit_write_conflict))
                    next_state = state_IDLE;
                else if(cache_hit & valid & ~hit_write_conflict)
                    next_state = state_LOOKUP;
                else if (~dirty_arr[replace_way][index_reg] | ~tagv_rdata[replace_way][0])
                    next_state = state_REPLACE;
                else if(~cache_hit)
                    next_state = state_MISS;

            state_MISS:
                if(~wr_rdy)
                    next_state = state_MISS;
                else
                    next_state = state_REPLACE;

            state_REPLACE:
                if(~rd_rdy)
                    next_state = state_REPLACE;
                else
                    next_state = state_REFILL;

            state_REFILL:
                if(ret_valid & ret_last[0])
                    next_state = state_IDLE;
                else
                    next_state = state_REFILL;

            default: 
                next_state = state_IDLE;
        endcase
    end

/* ------write state machine------ */
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
                if(hit_write)
                    wr_next_state = state_WR_WRITE;
                else
                    wr_next_state = state_WR_IDLE;

            state_WR_WRITE:
                if(hit_write)
                    wr_next_state = state_WR_WRITE;
                else
                    wr_next_state = state_WR_IDLE;

            default: 
                wr_next_state = state_WR_IDLE;
        endcase
    end

    // request buffer
    always @(posedge clk) begin
        if(~resetn)
            {op_reg, index_reg, tag_reg, offset_reg, wstrb_reg, wdata_reg} <= 69'b0;
        else if(valid & addr_ok)
            {op_reg, index_reg, tag_reg, offset_reg, wstrb_reg, wdata_reg}
                                 <= {op, index, tag, offset, wstrb, wdata};
    end

    // write buffer
    always @(posedge clk) begin
        if(~resetn)
            {wrbuf_way, wrbuf_index, wrbuf_offset, wrbuf_wstrb, wrbuf_wdata} <= 49'b0;
        else if(hit_write)
            {wrbuf_way, wrbuf_index, wrbuf_offset, wrbuf_wstrb, wrbuf_wdata}
            <= {hit_way[1], index_reg, offset_reg, wstrb_reg, wdata_reg};
    end
    
    // burst data counter
    always @(posedge clk) begin
        if(~resetn)
            ret_cnt <= 2'b0;
        else if(ret_valid) begin
            if(~ret_last)
                ret_cnt <= ret_cnt + 1'b1;
            else
                ret_cnt <= 2'b0;
        end
    end

/* ------tag match/update------ */
    generate
        for(way = 0; way < `CACHE_WAY; way = way + 1) begin: tag_value
            assign hit_way[way] = tagv_rdata[way][0] & tagv_rdata[way][20:1] == tag_reg;
            assign tagv_we[way] = ret_valid & ret_last[0] & replace_way == way;
        end
    endgenerate
    assign cache_hit = |hit_way;

    assign tagv_addr  = (current_state[IDLE] | current_state[LOOKUP])? index : index_reg;
    assign tagv_wdata = {tag_reg, 1'b1};

    assign hit_write = current_state[LOOKUP] & cache_hit & op_reg;
    assign hit_write_conflict = (hit_write | wr_current_state[WR_WRITE]) & valid & ~op & {index, offset[3:2]} == {index_reg, offset_reg[3:2]};
    assign hit_result = {32{hit_way[0]}} & data_bank_rdata[0][offset_reg[3:2]] |
                        {32{hit_way[1]}} & data_bank_rdata[1][offset_reg[3:2]];
    
    // random replace way
	integer i_call;
	always @ (posedge clk) begin
		if (~resetn) begin
			for (i_call = 0; i_call < 256; i_call = i_call + 1) begin
				call_cnt[0][i_call] <= 8'b0;
				call_cnt[1][i_call] <= 8'b0;
			end
		end
		else if (current_state[LOOKUP])begin
			if (~hit_way[0] & valid) call_cnt[0][index_reg] <= call_cnt[0][index_reg] + 1;
			if (~hit_way[1] & valid) call_cnt[1][index_reg] <= call_cnt[1][index_reg] + 1;
		end
		else if (state_REFILL) call_cnt[replace_way][index_reg] <= 8'b0;
	end

    always @(posedge clk) begin
        if (~resetn)
            replace_way <= 1'b0;
        else if (current_state[LOOKUP])
            replace_way <= (~tagv_rdata[0][0])? 1'd0 :
						 (~tagv_rdata[1][0])? 1'd1 :
						 (call_cnt[0][index_reg] >= call_cnt[1][index_reg])? 1'd0 : 1'd1;
    end

/* ------cache data & control------ */
    // dirty array
    always @(posedge clk) begin
        if(~resetn)
            {dirty_arr[1], dirty_arr[0]} <= {256'b0, 256'b0};
        else if(wr_current_state[WR_WRITE])
            dirty_arr[wrbuf_way][wrbuf_index] <= 1'b1;
        else if(ret_valid & ret_last[0])
            dirty_arr[wrbuf_way][wrbuf_index] <= op_reg;
    end

    // RAM port
    generate
        for (i=0; i<4; i=i+1) begin: data_bank
            for (way = 0; way < `CACHE_WAY; way = way + 1) begin: data_bank_we_value
                assign data_bank_we[way][i] = {4{wr_current_state[WR_WRITE] & (wrbuf_offset[3:2] == i) & wrbuf_way == way}} & wrbuf_wstrb |
                                              {4{ret_valid & (ret_cnt == i) & replace_way == way}} & 4'hf;
            end
            
            assign data_bank_addr[i]  = (current_state[IDLE] | current_state[LOOKUP])? index : index_reg;
            assign data_bank_wdata[i] = (wr_current_state[WR_WRITE])? wrbuf_wdata :
                                          (offset_reg[3:2] != i || ~op_reg)? ret_data :
                                          {wstrb_reg[3] ? wdata_reg[31:24] : ret_data[31:24],
                                           wstrb_reg[2] ? wdata_reg[23:16] : ret_data[23:16],
                                           wstrb_reg[1] ? wdata_reg[15: 8] : ret_data[15: 8],
                                           wstrb_reg[0] ? wdata_reg[ 7: 0] : ret_data[ 7: 0]};  
        end
    endgenerate

    // RAM instance 
    generate
        for (way = 0; way < `CACHE_WAY; way = way + 1) begin: ram_generate
            TAG_RAM tagv_ram (
                .clka (clk),
                .wea  (tagv_we[way]),
                .addra(tagv_addr),
                .dina (tagv_wdata),
                .douta(tagv_rdata[way]) 
            );
            for(i = 0; i < 4; i = i + 1) begin: bank_ram_generate
                DATA_Bank_RAM data_bank_ram(
                    .clka (clk),
                    .wea  (data_bank_we[way][i]),
                    .addra(data_bank_addr[i]),
                    .dina (data_bank_wdata[i]),
                    .douta(data_bank_rdata[way][i])
                );
            end
        end
    endgenerate

/* ------CPU interface------ */
    assign addr_ok = current_state[IDLE] | 
                     (current_state[LOOKUP] & valid & cache_hit & (op | ~op & ~hit_write_conflict));

    assign data_ok = (current_state[LOOKUP] & (cache_hit | op_reg)) | 
                     (current_state[REFILL] & ~op_reg & ret_valid & ret_cnt==offset_reg[3:2]);

    assign rdata = (ret_valid)? ret_data : hit_result;
    
/* ------AXI interface------ */
    // read port
    assign rd_type = 3'b100;
    assign rd_addr = {tag_reg, index_reg, 4'b0};
    assign rd_req = current_state[REPLACE];

    // write port
    assign wr_req   = current_state[MISS] & next_state[REPLACE];
    assign wr_type  = 3'b100;
    assign wr_addr  = {tagv_rdata[replace_way][20:1], index_reg, 4'b0};
    assign wr_wstrb = 4'hf;
    assign wr_data  = {data_bank_rdata[replace_way][3], data_bank_rdata[replace_way][2],
                       data_bank_rdata[replace_way][1], data_bank_rdata[replace_way][0]};

endmodule