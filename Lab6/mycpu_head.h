`define IF_TO_ID_DATA_WIDTH 64
`define ID_TO_EX_DATA_WIDTH 160
`define EX_TO_MEM_DATA_WIDTH 110
`define MEM_TO_WB_DATA_WIDTH 70

`define IF_TO_ID_EXCEP_WIDTH 15
`define ID_TO_EX_EXCEP_WIDTH 97
`define EX_TO_MEM_EXCEP_WIDTH 97
`define MEM_TO_WB_EXCEP_WIDTH 97

`define ECODE_ADEF 0x8
`define ECODE_ALE 0x9
`define ECODE_SYS 0xb
`define ECODE_BRK 0xc
`define ECODE_INE 0xd

// exp12
`define CSR_CRMD        14'h0
`define CSR_PRMD        14'h1
`define CSR_ESTAT       14'h5
`define CSR_ERA         14'h6
`define CSR_EENTRY      14'hc
`define CSR_SAVE0       14'h30
`define CSR_SAVE1       14'h31
`define CSR_SAVE2       14'h32
`define CSR_SAVE3       14'h33

`define CSR_CRMD_PLV    1:0
`define CSR_CRMD_PIE    2
`define CSR_PRMD_PPLV   1:0
`define CSR_PRMD_PIE    2    
`define CSR_ESTAT_IS10  1:0
`define CSR_ERA_PC      31:0
`define CSR_EENTRY_VA   31:6
`define CSR_SAVE_DATA   31:0

// `define CSR_ECFG        14'h4
// `define CSR_BADV        14'h7
// `define CSR_TID         14'h40   
// `define CSR_TCFG        14'h41
// `define CSR_TVAL        14'h42
// `define CSR_TICLR       14'h44

// `define CSR_ECFG_LIE    12:0
// `define CSR_TICLR_CLR   0
// `define CSR_TID_TID     31:0
// `define CSR_TCFG_EN     0
// `define CSR_TCFG_PERIOD 1
// `define CSR_TCFG_INITV  31:2

