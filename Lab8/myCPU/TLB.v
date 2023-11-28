module tlb
#(
    parameter TLBNUM = 16
)
(
    input  wire        clk,

    //search port 0 (for fetch)
    input  wire [18:0] s0_vppn,
    input  wire        s0_va_bit12,
    input  wire [ 9:0] s0_asid,
    output wire        s0_found,
    output wire [$clog2(TLBNUM)-1:0] s0_index,
    output wire [19:0] s0_ppn,
    output wire [ 5:0] s0_ps,
    output wire [ 1:0] s0_plv,
    output wire [ 1:0] s0_mat,
    output wire        s0_d,
    output wire        s0_v,

    //search port 1 (for load/store)
    input  wire [18:0] s1_vppn,
    input  wire        s1_va_bit12,
    input  wire [ 9:0] s1_asid,
    output wire        s1_found,
    output wire [$clog2(TLBNUM)-1:0] s1_index,
    output wire [19:0] s1_ppn,
    output wire [ 5:0] s1_ps,
    output wire [ 1:0] s1_plv,
    output wire [ 1:0] s1_mat,
    output wire        s1_d,
    output wire        s1_v,

    //invtlb opcode
    input  wire        invtlb_valid,
    input  wire [ 4:0] invtlb_op,

    //write port
    input  wire        we, //write enable
    input  wire [$clog2(TLBNUM)-1:0] w_index,
    input  wire        w_e,
    input  wire [18:0] w_vppn,
    input  wire [ 5:0] w_ps,
    input  wire [ 9:0] w_asid,
    input  wire        w_g,
    input  wire [19:0] w_ppn0,
    input  wire [ 1:0] w_plv0,
    input  wire [ 1:0] w_mat0,
    input  wire        w_d0,
    input  wire        w_v0,
    input  wire [19:0] w_ppn1,
    input  wire [ 1:0] w_plv1,
    input  wire [ 1:0] w_mat1,
    input  wire        w_d1,
    input  wire        w_v1,

    //read port
    input  wire [$clog2(TLBNUM)-1:0] r_index,
    output wire        r_e,
    output wire [18:0] r_vppn,
    output wire [ 5:0] r_ps,
    output wire [ 9:0] r_asid,
    output wire        r_g,
    output wire [19:0] r_ppn0,
    output wire [ 1:0] r_plv0,
    output wire [ 1:0] r_mat0,
    output wire        r_d0,
    output wire        r_v0,
    output wire [19:0] r_ppn1,
    output wire [ 1:0] r_plv1,
    output wire [ 1:0] r_mat1,
    output wire        r_d1,
    output wire        r_v1,
)

    reg  [TLBNUM-1:0] tlb_e;
    reg  [TLBNUM-1:0] tlb_ps4MB; //pagesize 1:4MB 0:4KB
    reg  [18:0] tlb_vppn;
    reg  [ 9:0] tlb_asid;
    reg         tlb_g;

    reg  [19:0] tlb_ppn0 [TLBNUM-1:0];
    reg  [ 1:0] tlb_plv0 [TLBNUM-1:0];
    reg  [ 1:0] tlb_mat0 [TLBNUM-1:0];
    reg         tlb_d0   [TLBNUM-1:0];
    reg         tlb_v0   [TLBNUM-1:0];

    reg  [19:0] tlb_ppn1 [TLBNUM-1:0];
    reg  [ 1:0] tlb_plv1 [TLBNUM-1:0];
    reg  [ 1:0] tlb_mat1 [TLBNUM-1:0];
    reg         tlb_d1   [TLBNUM-1:0];
    reg         tlb_v1   [TLBNUM-1:0];

    wire [15:0] match0;
    wire [15:0] match1;

    assign match0[ 0] = (s0_vppn[18:10] == tlb_vppn[ 0][18:10])
                     && (tlb_ps4MB[ 0] || s0_vppn[9:0] == tlb_vppn[ 0][9:0])
                     && ((s0_asid == tlb_asid[ 0]) || tlb_g[ 0]);
    assign match0[ 1] = (s0_vppn[18:10] == tlb_vppn[ 1][18:10])
                     && (tlb_ps4MB[ 1] || s0_vppn[9:0] == tlb_vppn[ 1][9:0])
                     && ((s0_asid == tlb_asid[ 1]) || tlb_g[ 1]);
    assign match0[ 2] = (s0_vppn[18:10] == tlb_vppn[ 2][18:10])
                     && (tlb_ps4MB[ 2] || s0_vppn[9:0] == tlb_vppn[ 2][9:0])
                     && ((s0_asid == tlb_asid[ 2]) || tlb_g[ 2]);
    assign match0[ 3] = (s0_vppn[18:10] == tlb_vppn[ 3][18:10])
                     && (tlb_ps4MB[ 3] || s0_vppn[9:0] == tlb_vppn[ 3][9:0])
                     && ((s0_asid == tlb_asid[ 3]) || tlb_g[ 3]);
    assign match0[ 4] = (s0_vppn[18:10] == tlb_vppn[ 4][18:10])
                     && (tlb_ps4MB[ 4] || s0_vppn[9:0] == tlb_vppn[ 4][9:0])
                     && ((s0_asid == tlb_asid[ 4]) || tlb_g[ 4]);
    assign match0[ 5] = (s0_vppn[18:10] == tlb_vppn[ 5][18:10])
                     && (tlb_ps4MB[ 5] || s0_vppn[9:0] == tlb_vppn[ 5][9:0])
                     && ((s0_asid == tlb_asid[ 5]) || tlb_g[ 5]);
    assign match0[ 6] = (s0_vppn[18:10] == tlb_vppn[ 6][18:10])
                     && (tlb_ps4MB[ 6] || s0_vppn[9:0] == tlb_vppn[ 6][9:0])
                     && ((s0_asid == tlb_asid[ 6]) || tlb_g[ 6]);
    assign match0[ 7] = (s0_vppn[18:10] == tlb_vppn[ 7][18:10])
                     && (tlb_ps4MB[ 7] || s0_vppn[9:0] == tlb_vppn[ 7][9:0])
                     && ((s0_asid == tlb_asid[ 7]) || tlb_g[ 7]);
    assign match0[ 8] = (s0_vppn[18:10] == tlb_vppn[ 8][18:10])
                     && (tlb_ps4MB[ 8] || s0_vppn[9:0] == tlb_vppn[ 8][9:0])
                     && ((s0_asid == tlb_asid[ 8]) || tlb_g[ 8]);
    assign match0[ 9] = (s0_vppn[18:10] == tlb_vppn[ 9][18:10])
                     && (tlb_ps4MB[ 9] || s0_vppn[9:0] == tlb_vppn[ 9][9:0])
                     && ((s0_asid == tlb_asid[ 9]) || tlb_g[ 9]);
    assign match0[10] = (s0_vppn[18:10] == tlb_vppn[10][18:10])
                     && (tlb_ps4MB[10] || s0_vppn[9:0] == tlb_vppn[10][9:0])
                     && ((s0_asid == tlb_asid[10]) || tlb_g[10]);
    assign match0[11] = (s0_vppn[18:10] == tlb_vppn[11][18:10])
                     && (tlb_ps4MB[11] || s0_vppn[9:0] == tlb_vppn[11][9:0])
                     && ((s0_asid == tlb_asid[11]) || tlb_g[11]);
    assign match0[12] = (s0_vppn[18:10] == tlb_vppn[12][18:10])
                     && (tlb_ps4MB[12] || s0_vppn[9:0] == tlb_vppn[12][9:0])
                     && ((s0_asid == tlb_asid[12]) || tlb_g[12]);
    assign match0[13] = (s0_vppn[18:10] == tlb_vppn[13][18:10])
                     && (tlb_ps4MB[13] || s0_vppn[9:0] == tlb_vppn[13][9:0])
                     && ((s0_asid == tlb_asid[13]) || tlb_g[13]);
    assign match0[14] = (s0_vppn[18:10] == tlb_vppn[14][18:10])
                     && (tlb_ps4MB[14] || s0_vppn[9:0] == tlb_vppn[14][9:0])
                     && ((s0_asid == tlb_asid[14]) || tlb_g[14]);
    assign match0[15] = (s0_vppn[18:10] == tlb_vppn[15][18:10])
                     && (tlb_ps4MB[15] || s0_vppn[9:0] == tlb_vppn[15][9:0])
                     && ((s0_asid == tlb_asid[15]) || tlb_g[15]);

    assign match1[ 0] = (s1_vppn[18:10] == tlb_vppn[ 0][18:10])
                     && (tlb_ps4MB[ 0] || s1_vppn[9:0] == tlb_vppn[ 0][9:0])
                     && ((s1_asid == tlb_asid[ 0]) || tlb_g[ 0]);
    assign match1[ 1] = (s1_vppn[18:10] == tlb_vppn[ 1][18:10])
                     && (tlb_ps4MB[ 1] || s1_vppn[9:0] == tlb_vppn[ 1][9:0])
                     && ((s1_asid == tlb_asid[ 1]) || tlb_g[ 1]);
    assign match1[ 2] = (s1_vppn[18:10] == tlb_vppn[ 2][18:10])
                     && (tlb_ps4MB[ 2] || s1_vppn[9:0] == tlb_vppn[ 2][9:0])
                     && ((s1_asid == tlb_asid[ 2]) || tlb_g[ 2]);
    assign match1[ 3] = (s1_vppn[18:10] == tlb_vppn[ 3][18:10])
                     && (tlb_ps4MB[ 3] || s1_vppn[9:0] == tlb_vppn[ 3][9:0])
                     && ((s1_asid == tlb_asid[ 3]) || tlb_g[ 3]);
    assign match1[ 4] = (s1_vppn[18:10] == tlb_vppn[ 4][18:10])
                     && (tlb_ps4MB[ 4] || s1_vppn[9:0] == tlb_vppn[ 4][9:0])
                     && ((s1_asid == tlb_asid[ 4]) || tlb_g[ 4]);
    assign match1[ 5] = (s1_vppn[18:10] == tlb_vppn[ 5][18:10])
                     && (tlb_ps4MB[ 5] || s1_vppn[9:0] == tlb_vppn[ 5][9:0])
                     && ((s1_asid == tlb_asid[ 5]) || tlb_g[ 5]);
    assign match1[ 6] = (s1_vppn[18:10] == tlb_vppn[ 6][18:10])
                     && (tlb_ps4MB[ 6] || s1_vppn[9:0] == tlb_vppn[ 6][9:0])
                     && ((s1_asid == tlb_asid[ 6]) || tlb_g[ 6]);
    assign match1[ 7] = (s1_vppn[18:10] == tlb_vppn[ 7][18:10])
                     && (tlb_ps4MB[ 7] || s1_vppn[9:0] == tlb_vppn[ 7][9:0])
                     && ((s1_asid == tlb_asid[ 7]) || tlb_g[ 7]);
    assign match1[ 8] = (s1_vppn[18:10] == tlb_vppn[ 8][18:10])
                     && (tlb_ps4MB[ 8] || s1_vppn[9:0] == tlb_vppn[ 8][9:0])
                     && ((s1_asid == tlb_asid[ 8]) || tlb_g[ 8]);
    assign match1[ 9] = (s1_vppn[18:10] == tlb_vppn[ 9][18:10])
                     && (tlb_ps4MB[ 9] || s1_vppn[9:0] == tlb_vppn[ 9][9:0])
                     && ((s1_asid == tlb_asid[ 9]) || tlb_g[ 9]);
    assign match1[10] = (s1_vppn[18:10] == tlb_vppn[10][18:10])
                     && (tlb_ps4MB[10] || s1_vppn[9:0] == tlb_vppn[10][9:0])
                     && ((s1_asid == tlb_asid[10]) || tlb_g[10]);
    assign match1[11] = (s1_vppn[18:10] == tlb_vppn[11][18:10])
                     && (tlb_ps4MB[11] || s1_vppn[9:0] == tlb_vppn[11][9:0])
                     && ((s1_asid == tlb_asid[11]) || tlb_g[11]);
    assign match1[12] = (s1_vppn[18:10] == tlb_vppn[12][18:10])
                     && (tlb_ps4MB[12] || s1_vppn[9:0] == tlb_vppn[12][9:0])
                     && ((s1_asid == tlb_asid[12]) || tlb_g[12]);
    assign match1[13] = (s1_vppn[18:10] == tlb_vppn[13][18:10])
                     && (tlb_ps4MB[13] || s1_vppn[9:0] == tlb_vppn[13][9:0])
                     && ((s1_asid == tlb_asid[13]) || tlb_g[13]);
    assign match1[14] = (s1_vppn[18:10] == tlb_vppn[14][18:10])
                     && (tlb_ps4MB[14] || s1_vppn[9:0] == tlb_vppn[14][9:0])
                     && ((s1_asid == tlb_asid[14]) || tlb_g[14]);
    assign match1[15] = (s1_vppn[18:10] == tlb_vppn[15][18:10])
                     && (tlb_ps4MB[15] || s1_vppn[9:0] == tlb_vppn[15][9:0])
                     && ((s1_asid == tlb_asid[15]) || tlb_g[15]);
    

endmodule