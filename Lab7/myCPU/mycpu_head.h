`define IF_TO_ID_DATA_WIDTH     64
`define ID_TO_EX_DATA_WIDTH     163
`define EX_TO_MEM_DATA_WIDTH    79
`define MEM_TO_WB_DATA_WIDTH    70

`define IF_TO_ID_EXCEP_WIDTH    1
`define ID_TO_EX_EXCEP_WIDTH    86
`define EX_TO_MEM_EXCEP_WIDTH   87
`define MEM_TO_WB_EXCEP_WIDTH   119

`define WB_TO_IF_CSR_DATA_WIDTH 66

`define ECODE_INT   6'h0
`define ECODE_ADEF  6'h8
`define ECODE_ALE   6'h9
`define ECODE_SYS   6'hb
`define ECODE_BRK   6'hc
`define ECODE_INE   6'hd

`define ESUBCODE_ADEF 9'h0

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

//exp13
`define CSR_ECFG        14'h4
`define CSR_BADV        14'h7
`define CSR_TID         14'h40   
`define CSR_TCFG        14'h41
`define CSR_TVAL        14'h42
`define CSR_TICLR       14'h44

`define CSR_ECFG_LIE    12:0
`define CSR_TICLR_CLR   0
`define CSR_TID_TID     31:0
`define CSR_TCFG_EN     0
`define CSR_TCFG_PERIOD 1
`define CSR_TCFG_INITV  31:2

`define ECODE_INT       6'h0
`define ECODE_ADE       6'h8
`define ECODE_ALE       6'h9
`define ECODE_BRK       6'hc
`define ECODE_INE       6'hd
`define ESUBCODE_ADEF   9'h0


