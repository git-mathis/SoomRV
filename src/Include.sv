typedef struct packed
{
    logic ce;
    logic we;
    logic[9:0] sramAddr;
    logic[29:0] extAddr;
} IF_MemoryController;

typedef logic[4:0] RegNm;
typedef logic[6:0] Tag;
typedef logic[6:0] SqN;
typedef logic[11:0] BrID;
typedef logic[4:0] FetchID_t;
typedef logic[2:0] FetchOff_t;
typedef logic[15:0] BHist_t;
typedef logic[2:0] TageUseful_t;

typedef enum logic[5:0]
{
    INT_ADD,
    INT_XOR,
    INT_OR,
    INT_AND,
    INT_SLL,
    INT_SRL,
    INT_SLT,
    INT_SLTU,
    INT_SUB,
    INT_SRA,
    INT_BEQ,
    INT_BNE,
    INT_BLT,
    INT_BGE,
    INT_BLTU,
    INT_BGEU,
    INT_LUI,
    INT_AUIPC,
    INT_JAL,
    INT_JALR,
    INT_SYS,
    INT_UNDEFINED,
    INT_SH1ADD,
    INT_SH2ADD,
    INT_SH3ADD,
    INT_XNOR,
    INT_ANDN,
    INT_ORN,
    INT_CLZ,
    INT_CTZ,
    INT_CPOP,
    INT_MAX,
    INT_MAXU,
    INT_MIN,
    INT_MINU,
    INT_SE_B,
    INT_SE_H,
    INT_ZE_H,
    INT_ROL,
    INT_ROR,
    INT_ORC_B,
    INT_REV8,
    INT_BCLR,
    INT_BEXT,
    INT_BINV,
    INT_BSET,
    INT_F_ADDI_BEQ,
    INT_F_ADDI_BNE,
    INT_F_ADDI_BLT,
    INT_F_ADDI_BGE,
    INT_F_ADDI_BLTU,
    INT_F_ADDI_BGEU,
    INT_V_RET,
    INT_V_JR
} OPCode_INT;

typedef enum logic[5:0]
{
    MUL_MUL,
    MUL_MULH,
    MUL_MULSU,
    MUL_MULU
} OPCode_MUL;

typedef enum logic[5:0]
{
    DIV_DIV,
    DIV_DIVU,
    DIV_REM,
    DIV_REMU
} OPCode_DIV;

typedef enum logic[5:0]
{
    LSU_LB, 
    LSU_LH, 
    LSU_LW, 
    LSU_LBU,
    LSU_LHU,
    //LSU_FLW,
    LSU_LB_RR, 
    LSU_LH_RR, 
    LSU_LW_RR, 
    LSU_LBU_RR,
    LSU_LHU_RR
    
} OPCode_LSU;

typedef enum logic[5:0]
{
    LSU_SB,
    LSU_SH,
    LSU_SW,
    //LSU_FSW,
    
    LSU_CBO_CLEAN,
    LSU_CBO_INVAL,
    LSU_CBO_FLUSH,
    
    LSU_F_ADDI_SW,
    
    LSU_SB_I,
    LSU_SH_I,
    LSU_SW_I
    
} OPCode_ST;

typedef enum logic[5:0]
{
    FPU_FMADD_S,
    FPU_FMSUB_S,
    FPU_FNMSUB_S,
    FPU_FNMADD_S,
    FPU_FADD_S,
    FPU_FSUB_S,
    FPU_FMUL_S,
    FPU_FSGNJ_S,
    FPU_FSGNJN_S,
    FPU_FSGNJX_S,
    FPU_FMIN_S,
    FPU_FMAX_S,
    FPU_FCVTWS,
    FPU_FCVTWUS,
    FPU_FMVXW,
    FPU_FEQ_S,
    FPU_FLE_S,
    FPU_FLT_S,
    FPU_FCLASS_S,
    FPU_FCVTSW,
    FPU_FCVTSWU,
    FPU_FMVWX
} OPCode_FPU;

typedef enum logic[5:0]
{
    FPU_FDIV_S,
    FPU_FSQRT_S
} OPCode_FDIV;

typedef enum logic[3:0] {FU_INT, FU_LSU, FU_ST, FU_MUL, FU_DIV, FU_FPU, FU_FDIV, FU_FMUL, FU_RN} FuncUnit;
typedef enum bit[2:0] {FLAGS_NONE, FLAGS_BRANCH, FLAGS_PRED_TAKEN, FLAGS_PRED_NTAKEN, FLAGS_BRK, FLAGS_EXCEPT, FLAGS_FENCE, FLAGS_ORDERING} Flags;

typedef enum logic[2:0]
{
    MODE_USER,
    MODE_WMASK,
    MODE_RMASK,
    MODE_NO_CREGS_RD,
    MODE_NO_CREGS_WR,
    MODE_TMR,
    MODE_NO_FP,
    MODE_NO_EXT
} ModeFlagsIDs;
    


typedef logic[7:0] ModeFlags;

typedef struct packed
{
    bit predicted;
    bit taken;
    bit[2:0] tageID;
    TageUseful_t tageUseful;
    bit isJump;
} BranchPredInfo;

typedef struct packed
{
    bit[30:0] src;
    bit[30:0] dst;
    bit valid;
} IndirBranchInfo;

typedef struct packed
{
    bit[30:0] pc;
    bit[2:0] branchPos;
    BranchPredInfo bpi;
    BHist_t hist;
} PCFileEntry;

typedef struct packed
{
    logic[15:0] instr;
    logic[30:0] pc;
    FetchID_t fetchID;
    logic predTaken;
    logic valid;
} IF_Instr;

typedef struct packed
{
    logic[31:0] instr;
    logic[30:0] pc;
    FetchID_t fetchID;
    logic predTaken;
    logic valid;
} PD_Instr;

typedef struct packed
{
    //logic[31:0] pc;
    logic[31:0] imm;
    logic[4:0] rs0;
    //logic rs0_fp;
    logic[4:0] rs1;
    //logic rs1_fp;
   //logic[4:0] rs2;
    logic immB;
    logic[4:0] rd;
    //logic rd_fp;
    logic[5:0] opcode;
    FuncUnit fu;
    FetchID_t fetchID;
    FetchOff_t fetchOffs;
    logic compressed;
    logic valid;
} D_UOp;

typedef struct packed
{
    //logic[31:0] pc; 10044
    logic[31:0] imm;
    logic availA;
    Tag tagA;
    logic availB;
    Tag tagB;
    logic immB;
    SqN sqN;
    Tag tagDst;
    RegNm nmDst;
    logic[5:0] opcode;
    FetchID_t fetchID;
    FetchOff_t fetchOffs;
    SqN storeSqN;
    SqN loadSqN;
    FuncUnit fu;
    logic compressed;
} R_UOp;

typedef struct packed
{
    logic[31:0] srcA;
    logic[31:0] srcB;
    logic[31:0] pc;
    logic[31:0] imm;
    logic[5:0] opcode;
    Tag tagDst;
    RegNm nmDst;
    SqN sqN;
    FetchID_t fetchID;
    BranchPredInfo bpi;
    BHist_t history;
    SqN storeSqN;
    SqN loadSqN;
    logic compressed;
    logic valid;
} EX_UOp;

typedef struct packed
{
    bit[31:0] result;
    Tag tagDst;
    RegNm nmDst;
    SqN sqN;
    bit[31:0] pc;
    Flags flags;
    logic compressed;
    bit valid;
} RES_UOp;

typedef struct packed
{
    bit[31:0] dstPC;
    SqN sqN;
    SqN storeSqN;
    SqN loadSqN;
    bit flush;
    FetchID_t fetchID;
    BHist_t history;
    bit taken;
} BranchProv;

typedef struct packed
{
    bit[31:0] src;
    bit[31:0] dst;
    bit isJump;
    bit compressed;
    bit valid;
} BTUpdate;

typedef struct packed
{
    logic[31:0] addr;
    logic[31:0] data;
    // could union some of these fields
    logic[3:0] wmask;
    logic signExtend;
    logic[1:0] shamt;
    logic[1:0] size;
    logic isLoad;
    logic[31:0] pc;
    Tag tagDst;
    RegNm nmDst;
    SqN sqN;
    SqN storeSqN;
    SqN loadSqN;
    FetchID_t fetchID;
    BHist_t history;
    logic exception;
    logic compressed;
    logic valid;
} AGU_UOp;

typedef struct packed
{
    logic[31:0] addr;
    logic[31:0] data;
    logic[3:0] wmask;
    logic valid;
} ST_UOp;


typedef struct packed
{
    RegNm nmDst;
    Tag tagDst;
    SqN sqN;
    logic isBranch;
    logic branchTaken;
    logic compressed;
    logic valid;
} CommitUOp;

typedef struct packed
{
    logic[30:0] pc;
    logic compressed;
    BranchPredInfo bpi;
    BHist_t history;
    logic branchTaken;
    logic valid;
} BPUpdate;

typedef struct packed
{
    logic[31:0] result;
    Tag tag;
    logic valid;
} ZCForward;
