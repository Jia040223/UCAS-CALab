module tlb
#(
    parameter TLBNUM = 16
)
(
    input  wire        clk,

    //search port 0 (for inst fetch)
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

    wire [TLBNUM-1:0] match0;

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

    assign s0_found = (|match0);
    assign s0_index = 
    assign s0_ppn = (s0_found)?
                    {20{match0[ 0]}} & tlb_ppn0[ 0] | {20{match0[ 1]}} & tlb_ppn0[ 1] | {20{match0[ 2]}} & tlb_ppn0[ 2] | {20{match0[ 3]}} & tlb_ppn0[ 3] |
                    {20{match0[ 4]}} & tlb_ppn0[ 4] | {20{match0[ 5]}} & tlb_ppn0[ 5] | {20{match0[ 6]}} & tlb_ppn0[ 6] | {20{match0[ 7]}} & tlb_ppn0[ 7] |
                    {20{match0[ 8]}} & tlb_ppn0[ 8] | {20{match0[ 9]}} & tlb_ppn0[ 9] | {20{match0[10]}} & tlb_ppn0[10] | {20{match0[11]}} & tlb_ppn0[11] |
                    {20{match0[12]}} & tlb_ppn0[12] | {20{match0[13]}} & tlb_ppn0[13] | {20{match0[14]}} & tlb_ppn0[14] | {20{match0[15]}} & tlb_ppn0[15] 
                    :
    assign s0_ps =
    assign s0_plv = (s0_found)?
                    {2{match0[ 0]}} & tlb_plv0[ 0] | {2{match0[ 1]}} & tlb_plv0[ 1] | {2{match0[ 2]}} & tlb_plv0[ 2] | {2{match0[ 3]}} & tlb_plv0[ 3] |
                    {2{match0[ 4]}} & tlb_plv0[ 4] | {2{match0[ 5]}} & tlb_plv0[ 5] | {2{match0[ 6]}} & tlb_plv0[ 6] | {2{match0[ 7]}} & tlb_plv0[ 7] |
                    {2{match0[ 8]}} & tlb_plv0[ 8] | {2{match0[ 9]}} & tlb_plv0[ 9] | {2{match0[10]}} & tlb_plv0[10] | {2{match0[11]}} & tlb_plv0[11] |
                    {2{match0[12]}} & tlb_plv0[12] | {2{match0[13]}} & tlb_plv0[13] | {2{match0[14]}} & tlb_plv0[14] | {2{match0[15]}} & tlb_plv0[15] 
                    :
    assign s0_mat = (s0_found)?
                    {2{match0[ 0]}} & tlb_mat0[ 0] | {2{match0[ 1]}} & tlb_mat0[ 1] | {2{match0[ 2]}} & tlb_mat0[ 2] | {2{match0[ 3]}} & tlb_mat0[ 3] |
                    {2{match0[ 4]}} & tlb_mat0[ 4] | {2{match0[ 5]}} & tlb_mat0[ 5] | {2{match0[ 6]}} & tlb_mat0[ 6] | {2{match0[ 7]}} & tlb_mat0[ 7] |
                    {2{match0[ 8]}} & tlb_mat0[ 8] | {2{match0[ 9]}} & tlb_mat0[ 9] | {2{match0[10]}} & tlb_mat0[10] | {2{match0[11]}} & tlb_mat0[11] |
                    {2{match0[12]}} & tlb_mat0[12] | {2{match0[13]}} & tlb_mat0[13] | {2{match0[14]}} & tlb_mat0[14] | {2{match0[15]}} & tlb_mat0[15] 
                    :
    assign s0_d = (s0_found)?
                  match0[ 0] & tlb_d0[ 0] | match0[ 1] & tlb_d0[ 1] | match0[ 2] & tlb_d0[ 2] | match0[ 3] & tlb_d0[ 3] |
                  match0[ 4] & tlb_d0[ 4] | match0[ 5] & tlb_d0[ 5] | match0[ 6] & tlb_d0[ 6] | match0[ 7] & tlb_d0[ 7] |
                  match0[ 8] & tlb_d0[ 8] | match0[ 9] & tlb_d0[ 9] | match0[10] & tlb_d0[10] | match0[11] & tlb_d0[11] |
                  match0[12] & tlb_d0[12] | match0[13] & tlb_d0[13] | match0[14] & tlb_d0[14] | match0[15] & tlb_d0[15] 
                  :
    assign s0_v = (s0_found)?
                  match0[ 0] & tlb_v0[ 0] | match0[ 1] & tlb_v0[ 1] | match0[ 2] & tlb_v0[ 2] | match0[ 3] & tlb_v0[ 3] |
                  match0[ 4] & tlb_v0[ 4] | match0[ 5] & tlb_v0[ 5] | match0[ 6] & tlb_v0[ 6] | match0[ 7] & tlb_v0[ 7] |
                  match0[ 8] & tlb_v0[ 8] | match0[ 9] & tlb_v0[ 9] | match0[10] & tlb_v0[10] | match0[11] & tlb_v0[11] |
                  match0[12] & tlb_v0[12] | match0[13] & tlb_v0[13] | match0[14] & tlb_v0[14] | match0[15] & tlb_v0[15] 
                  :


    wire [TLBNUM-1:0] match1;

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
    
    assign s1_found = (|match1);
    assign s1_index = 
    assign s1_ppn = (s1_found)?
                    {20{match1[ 0]}} & tlb_ppn1[ 0] | {20{match1[ 1]}} & tlb_ppn1[ 1] | {20{match1[ 2]}} & tlb_ppn1[ 2] | {20{match1[ 3]}} & tlb_ppn1[ 3] |
                    {20{match1[ 4]}} & tlb_ppn1[ 4] | {20{match1[ 5]}} & tlb_ppn1[ 5] | {20{match1[ 6]}} & tlb_ppn1[ 6] | {20{match1[ 7]}} & tlb_ppn1[ 7] |
                    {20{match1[ 8]}} & tlb_ppn1[ 8] | {20{match1[ 9]}} & tlb_ppn1[ 9] | {20{match1[10]}} & tlb_ppn1[10] | {20{match1[11]}} & tlb_ppn1[11] |
                    {20{match1[12]}} & tlb_ppn1[12] | {20{match1[13]}} & tlb_ppn1[13] | {20{match1[14]}} & tlb_ppn1[14] | {20{match1[15]}} & tlb_ppn1[15] 
                    :
    assign s1_ps =
    assign s1_plv = (s1_found)?
                    {2{match1[ 0]}} & tlb_plv1[ 0] | {2{match1[ 1]}} & tlb_plv1[ 1] | {2{match1[ 2]}} & tlb_plv1[ 2] | {2{match1[ 3]}} & tlb_plv1[ 3] |
                    {2{match1[ 4]}} & tlb_plv1[ 4] | {2{match1[ 5]}} & tlb_plv1[ 5] | {2{match1[ 6]}} & tlb_plv1[ 6] | {2{match1[ 7]}} & tlb_plv1[ 7] |
                    {2{match1[ 8]}} & tlb_plv1[ 8] | {2{match1[ 9]}} & tlb_plv1[ 9] | {2{match1[10]}} & tlb_plv1[10] | {2{match1[11]}} & tlb_plv1[11] |
                    {2{match1[12]}} & tlb_plv1[12] | {2{match1[13]}} & tlb_plv1[13] | {2{match1[14]}} & tlb_plv1[14] | {2{match1[15]}} & tlb_plv1[15] 
                    :
    assign s1_mat = (s1_found)?
                    {2{match1[ 0]}} & tlb_mat1[ 0] | {2{match1[ 1]}} & tlb_mat1[ 1] | {2{match1[ 2]}} & tlb_mat1[ 2] | {2{match1[ 3]}} & tlb_mat1[ 3] |
                    {2{match1[ 4]}} & tlb_mat1[ 4] | {2{match1[ 5]}} & tlb_mat1[ 5] | {2{match1[ 6]}} & tlb_mat1[ 6] | {2{match1[ 7]}} & tlb_mat1[ 7] |
                    {2{match1[ 8]}} & tlb_mat1[ 8] | {2{match1[ 9]}} & tlb_mat1[ 9] | {2{match1[10]}} & tlb_mat1[10] | {2{match1[11]}} & tlb_mat1[11] |
                    {2{match1[12]}} & tlb_mat1[12] | {2{match1[13]}} & tlb_mat1[13] | {2{match1[14]}} & tlb_mat1[14] | {2{match1[15]}} & tlb_mat1[15] 
                    :
    assign s1_d = (s1_found)?
                  match1[ 0] & tlb_d1[ 0] | match1[ 1] & tlb_d1[ 1] | match1[ 2] & tlb_d1[ 2] | match1[ 3] & tlb_d1[ 3] |
                  match1[ 4] & tlb_d1[ 4] | match1[ 5] & tlb_d1[ 5] | match1[ 6] & tlb_d1[ 6] | match1[ 7] & tlb_d1[ 7] |
                  match1[ 8] & tlb_d1[ 8] | match1[ 9] & tlb_d1[ 9] | match1[10] & tlb_d1[10] | match1[11] & tlb_d1[11] |
                  match1[12] & tlb_d1[12] | match1[13] & tlb_d1[13] | match1[14] & tlb_d1[14] | match1[15] & tlb_d1[15] 
                  :
    assign s1_v = (s1_found)?
                  match1[ 0] & tlb_v1[ 0] | match1[ 1] & tlb_v1[ 1] | match1[ 2] & tlb_v1[ 2] | match1[ 3] & tlb_v1[ 3] |
                  match1[ 4] & tlb_v1[ 4] | match1[ 5] & tlb_v1[ 5] | match1[ 6] & tlb_v1[ 6] | match1[ 7] & tlb_v1[ 7] |
                  match1[ 8] & tlb_v1[ 8] | match1[ 9] & tlb_v1[ 9] | match1[10] & tlb_v1[10] | match1[11] & tlb_v1[11] |
                  match1[12] & tlb_v1[12] | match1[13] & tlb_v1[13] | match1[14] & tlb_v1[14] | match1[15] & tlb_v1[15] 
                  :

endmodule