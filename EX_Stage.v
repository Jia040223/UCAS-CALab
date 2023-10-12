module EX_Stage(
    input  wire        clk,
    input  wire        resetn,
    // id and exe state interface
    output wire        ex_allowin,
    input  wire [`ID_TO_EX_WIDTH-1:0] id_to_ex_wire,
    input  wire        id_to_ex_valid,
    // exe and mem state interface
    input  wire        mem_allowin,
    output wire [`EX_TO_MEM_WIDTH-1:0] ex_to_mem_wire, 
    output wire        ex_to_mem_valid,
    
    input wire  [38:0] ex_rf_zip,
    
// data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata
);
    reg  [`ID_TO_EX_WIDTH-1:0] id_to_ex_reg;
    
    wire        ex_ready_go;
    reg         ex_valid;

    wire        ex_rf_we;
    wire [ 4:0] ex_rf_waddr;
    wire [31:0] ex_pc;    

    wire [11:0] ex_alu_op;
    wire [31:0] ex_alu_src1;
    wire [31:0] ex_alu_src2;

    wire [31:0] ex_alu_result; 
    wire [ 3:0] ex_mem_we;
    wire [31:0] ex_rkd_value;

    wire        ex_inst_st_b;
    wire        ex_inst_st_h;
    wire        ex_inst_st_w;

    wire        ex_inst_ld_b;
    wire        ex_inst_ld_bu;
    wire        ex_inst_ld_h;
    wire        ex_inst_ld_hu;
    wire        ex_inst_ld_w;

//stage control signal
    assign ex_ready_go      = 1'b1;
    assign ex_allowin       = ~ex_valid | ex_ready_go & mem_allowin;     
    assign ex_to_mem_valid  = ex_valid & ex_ready_go;
    always @(posedge clk) begin
        if(~resetn)
            ex_valid <= 1'b0;
        else if(ex_allowin)
            ex_valid <= id_to_ex_valid; 
    end

//id and exe state interface
    always @(posedge clk) begin
        if(id_to_ex_valid & ex_allowin)
            id_to_ex_reg <= id_to_ex_wire;
    end
    
    assign {ex_alu_op, alu_src1, alu_src2,
            ex_rf_we, id_rf_waddr,
            ex_pc,
            ex_inst_st_b, ex_inst_st_h, ex_inst_st_w,
            ex_rkd_value,
            ex_load_unsigned,
            ex_inst_ld_b, ex_inst_ld_bu, ex_inst_ld_h, ex_inst_ld_hu, ex_inst_ld_w
            }; = id_to_ex_reg;   

    alu u_alu(
        .alu_op     (ex_alu_op    ),
        .alu_src1   (ex_alu_src1  ),
        .alu_src2   (ex_alu_src2  ),
        .alu_result (ex_alu_result)
    );

    wire addr00 = ex_alu_result[1:0] == 2'b00;
    wire addr01 = ex_alu_result[1:0] == 2'b01;
    wire addr10 = ex_alu_result[1:0] == 2'b10;
    wire addr11 = ex_alu_result[1:0] == 2'b11;
    
    assign ex_mem_we = {4{ex_inst_st_b}} & {addr11, addr10, addr01, addr00} |
                       {4{ex_inst_st_h}} & {{2{addr10}}, {2{addr00}}} |
                       {4{ex_inst_st_w}};

    assign ex_to_mem_wire = {ex_rf_we, ex_rf_waddr,
                             ex_pc,
                             ex_alu_result,
                             ex_inst_ld_b, ex_inst_ld_bu, ex_inst_ld_h, ex_inst_ld_hu, ex_inst_ld_w};
                             
    assign ex_rf_zip       = {ex_res_from_mem & ex_valid,
                              ex_rf_we & ex_valid,
                              ex_rf_waddr,
                              ex_alu_result};
    
    //data sram interface
    assign data_sram_en    = ex_inst_ld_b || ex_inst_ld_bu || ex_inst_ld_h || ex_inst_ld_hu || ex_inst_ld_w || (|ex_mem_we);
    assign data_sram_we    = ex_mem_we;
    assign data_sram_addr  = {ex_alu_result[31:2], 2'b0};
    assign data_sram_wdata = (ex_inst_st_b)? {4{ex_rkd_value[ 7:0]}} :
                             (ex_inst_st_h)? {2{ex_rkd_value[15:0]}} :
                              ex_rkd_value;
                                
endmodule

