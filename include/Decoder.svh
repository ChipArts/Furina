// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Decoder.svh
// Create  : 2024-03-01 16:04:57
// Revise  : 2024-03-20 15:27:13
// Description :
//   特权指令：与手册的定义有区别，这里的含义为有特殊控制功能的指令
//      - 整数杂项指令
//      - CSR访问指令
//      - Cache维护指令
//      - TLB维护指令
//      - 其它杂项指令(IDEL/ERTN)
// Parameter   :
//   ...
//   ...
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// xx-xx-xx |            |     0.1     |    Original Version
// ...
// ==============================================================================

`ifndef _DECODER_SVH_
`define _DECODER_SVH_

`include "config.svh"

/*================================ Pre Decoder ================================*/

typedef logic [1:0] SrcType;
`define SRC_R0  (2'd0)  // 0寄存器（src无效的默认值）
`define SRC_RD  (2'd1)
`define SRC_RJ  (2'd2)
`define SRC_RK  (2'd3)


typedef logic [1:0] DestType;
`define DEST_R0  (2'd0)
`define DEST_RD  (2'd0)
`define DEST_JD  (2'd1)  // 处理rdtime[l/h]指令
`define DEST_RA  (2'd2)  // 返回地址寄存器

typedef struct packed {
  SrcType src0_type;
  SrcType src1_type;
  DestType dest_type;
} PreOptionCodeSt;

/*================================== Decoder ==================================*/

typedef logic [2:0] ImmType;
`define IMM_UI5    (3'd0)
`define IMM_UI12   (3'd1)
`define IMM_SI12   (3'd2)
`define IMM_SI14   (3'd3)
`define IMM_SI16   (3'd4)
`define IMM_SI20   (3'd5)
`define IMM_SI26   (3'd6)
`define IMM_PC     (3'd7)  // 特殊处理PCADDR指令

typedef logic [2:0] InstrType;
`define ALU_INSTR    (3'd0)  // ALU指令
`define MDU_INSTR    (3'd1)  // MDU指令
`define BR_INSTR     (3'd2)  // 控制流指令
`define PRIV_INSTR   (3'd3)  // 特权指令
`define MEM_INSTR    (3'd4)  // 访存指令

typedef logic MemOpType;
`define MEM_LOAD (1'd0)
`define MEM_STORE (1'd1)

typedef logic[3:0] AluOpType;
`define ALU_ADD (4'd0)
`define ALU_SUB (4'd1)
`define ALU_SLT (4'd2)
`define ALU_AND (4'd3)
`define ALU_OR (4'd4)
`define ALU_XOR (4'd5)
`define ALU_NOR (4'd6)
`define ALU_SL (4'd7)
`define ALU_SR (4'd8)
`define ALU_LUI (4'd9)

typedef logic [1:0] MduOpType;
`define MDU_MUL (2'd0)
`define MDU_MULH (2'd1)
`define MDU_DIV (2'd2)
`define MDU_MOD (2'd3)

typedef logic [2:0] AlignOpType;
`define ALIGN_B  (3'd0)
`define ALIGN_H  (3'd1)
`define ALIGN_W  (3'd2)
`define ALIGN_BU (3'd3)
`define ALIGN_HU (3'd4)

typedef logic[2:0] BranchOpType;
`define BRANCH_EQ (3'd0)
`define BRANCH_NE (3'd1)
`define BRANCH_LT (3'd2)
`define BRANCH_GE (3'd3)
`define BRANCH_NC (3'd4)

typedef logic[3:0] PrivOpType;
`define PRIV_CSR_READ  (4'd0)
`define PRIV_CSR_WRITE (4'd1)
`define PRIV_CSR_XCHG  (4'd2)
`define PRIV_CACOP     (4'd3)
`define PRIV_TLBSRCH   (4'd4)
`define PRIV_TLBRD     (4'd5)
`define PRIV_TLBWR     (4'd6)
`define PRIV_TLBFILL   (4'd7)
`define PRIV_TLBINV    (4'd8)
`define PRIV_ERTN      (4'd9)
`define PRIV_IDEL      (4'd10)
`define PRIV_SYSCALL   (4'd11)
`define PRIV_BREAK     (4'd12)
`define PRIV_RDCNTVL   (4'd13)
`define PRIV_RDCNTVH   (4'd14)
`define PRIV_RDCNTID   (4'd15)

typedef logic SignedOpType;
typedef logic ImmOpType;
typedef logic WriteBackOpType;
typedef logic IndirectBrOpType;

typedef logic [31:0] DebugInstrType;
typedef logic InvalidInstType;

typedef struct packed {
  MemOpType mem_op;
  AlignOpType align_op;
} MemOpCodeSt;

typedef struct packed {
  AluOpType alu_op;
  SignedOpType signed_op;
  ImmOpType imm_op;
} AluOpCodeSt;

typedef struct packed {
  MduOpType mdu_op;
  SignedOpType signed_op;
} MduOpCodeSt;

typedef struct packed {
  InstType instr_type;
  BranchOpType branch_op;
  PrivOpType priv_op;
  SignedOpType signed_op;
  IndirectBrOpType indirect_br_op;  // 特殊处理JILR指令
} MiscOpCodeSt;

typedef struct packed {
    DebugInstrType debug_inst;
    ImmValidType imm_valid;
    SignedOpType signed_op;
    BranchOpType branch_op;
    MduOpType mdu_op;
    AluOpType alu_op;
    PrivOpType priv_op;
    AlignOpType align_op;
    MemTypeType mem_type;
    InstrTypeType instr_type;
    InvalidInstType invalid_inst;
    WriteBackOpType wb_op;
} OptionCodeSt;

function MiscOpCodeSt gen2misc(OptionCodeSt option_code);
  
endfunction : gen2misc

function AluOpCodeSt gen2alu(OptionCodeSt option_code);

endfunction : gen2alu

function MemOpCodeSt gen2mem(OptionCodeSt option_code);

endfunction : gen2mem

function MduOpCodeSt gen2mdu(OptionCodeSt option_code);

endfunction : gen2mdu

`endif  // _DECODER_SVH_