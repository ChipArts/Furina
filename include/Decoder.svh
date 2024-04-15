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
    SrcType src1_type;
    DestType dest_type;
    SrcType src0_type;
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
`define MEM_INSTR    (3'd2)  // 存储相关指令（（原子）访存、栅障、预取、cacop）
`define BR_INSTR     (3'd3)  // 控制流指令
`define PRIV_INSTR   (3'd4)  // 特权指令
`define MISC_INSTR   (3'd5)  // 整数杂项

typedef logic[2:0] MemOpType;
`define MEM_LOAD  (3'd0)
`define MEM_STORE (3'd1)
`define MEM_CACOP (3'd2)
`define MEM_PRELD (3'd3)
`define MEM_IBAR  (3'd4)
`define MEM_DBAR  (3'd5)
// `define MEM_LL    (3'd3)
// `define MEM_SC    (3'd4)



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
`define PRIV_TLBSRCH   (4'd3)
`define PRIV_TLBRD     (4'd4)
`define PRIV_TLBWR     (4'd5)
`define PRIV_TLBFILL   (4'd6)
`define PRIV_TLBINV    (4'd7)
`define PRIV_ERTN      (4'd8)
`define PRIV_IDLE      (4'd9)
// `define PRIV_CACOP     (4'd10)  Memory Block中处理

typedef logic [2:0] MiscOpType;
`define MISC_SYSCALL   (3'd0)
`define MISC_BREAK     (3'd1)
`define MISC_RDCNTVL   (3'd2)
`define MISC_RDCNTVH   (3'd3)
`define MISC_RDCNTID   (3'd4)


typedef logic SignedOpType;
typedef logic ImmOpType;
typedef logic WriteBackOpType;
typedef logic IndirectBrOpType;
typedef logic MicroOpType;  // 原子操作

typedef logic [31:0] DebugInstrType;
typedef logic InvalidInstType;

typedef struct packed {
  MemOpType mem_op;
  AlignOpType align_op;
  MicroOpType micro_op;
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
  InstrType instr_type;
  BranchOpType branch_op;
  PrivOpType priv_op;
  MiscOpType misc_op;
  SignedOpType signed_op;
  IndirectBrOpType indirect_br_op;  // 特殊处理JILR指令
} MiscOpCodeSt;

typedef struct packed {
    DebugInstrType debug_instr;
    IndirectBrOpType indirect_br_op;
    MicroOpType micro_op;
    SignedOpType signed_op;
    BranchOpType branch_op;
    MduOpType mdu_op;
    MiscOpType misc_op;
    AluOpType alu_op;
    ImmOpType imm_op;
    ImmType imm_type;
    PrivOpType priv_op;
    AlignOpType align_op;
    MemOpType mem_op;
    InstrType instr_type;
    InvalidInstType invalid_inst;
} OptionCodeSt;

function MiscOpCodeSt gen2misc(OptionCodeSt option_code);
  MiscOpCodeSt misc_op_code;
  misc_op_code.signed_op = option_code.signed_op;
  misc_op_code.branch_op = option_code.branch_op;
  misc_op_code.misc_op = option_code.misc_op;
  misc_op_code.instr_type = option_code.instr_type;
  misc_op_code.indirect_br_op = option_code.indirect_br_op;
  return misc_op_code;
endfunction : gen2misc

function AluOpCodeSt gen2alu(OptionCodeSt option_code);
  AluOpCodeSt alu_op_code;
  alu_op_code.alu_op = option_code.alu_op;
  alu_op_code.signed_op = option_code.signed_op;
  alu_op_code.imm_op = option_code.imm_op;
  return alu_op_code;
endfunction : gen2alu

function MemOpCodeSt gen2mem(OptionCodeSt option_code);
  MemOpCodeSt mem_op_code;
  mem_op_code.mem_op = option_code.mem_op;
  mem_op_code.align_op = option_code.align_op;
  mem_op_code.micro_op = option_code.micro_op;
  return mem_op_code;

endfunction : gen2mem

function MduOpCodeSt gen2mdu(OptionCodeSt option_code);
  MduOpCodeSt mdu_op_code;
  mdu_op_code.mdu_op = option_code.mdu_op;
  mdu_op_code.signed_op = option_code.signed_op;
  return mdu_op_code;

endfunction : gen2mdu

`endif  // _DECODER_SVH_