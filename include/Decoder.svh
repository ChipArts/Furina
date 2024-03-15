// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Decoder.svh
// Create  : 2024-03-01 16:04:57
// Revise  : 2024-03-15 16:56:04
// Description :
//   ...
//   ...
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

`define ALU_INST (3'd0)
`define MDU_INST (3'd1)
`define BRANCH_INST (3'd2)
`define PRIV_INST (3'd3)
`define MEMORY_INST (3'd4)

`define ALU_TYPE_NIL (4'd0)
`define ALU_TYPE_ADD (4'd1)
`define ALU_TYPE_SUB (4'd2)
`define ALU_TYPE_SLT (4'd3)
`define ALU_TYPE_AND (4'd4)
`define ALU_TYPE_OR (4'd5)
`define ALU_TYPE_XOR (4'd6)
`define ALU_TYPE_NOR (4'd7)
`define ALU_TYPE_SL (4'd8)
`define ALU_TYPE_SR (4'd9)
`define ALU_TYPE_MUL (4'd10)
`define ALU_TYPE_MULH (4'd11)
`define ALU_TYPE_DIV (4'd12)
`define ALU_TYPE_MOD (4'd13)
`define ALU_TYPE_LUI (4'd14)



`define ALIGN_TYPE_B  (3'd0)
`define ALIGN_TYPE_H  (3'd1)
`define ALIGN_TYPE_W  (3'd2)
`define ALIGN_TYPE_BU (3'd3)
`define ALIGN_TYPE_HU (3'd4)

typedef struct packed {
  logic ctrl_signal;
} LoadCtrlSignalSt;

typedef struct packed {
  logic ctrl_signal;
} StoreCtrlSignalSt;

typedef struct packed {
  logic mem_type;
  LoadCtrlSignalSt load_ctrl_signal;
  StoreCtrlSignalSt store_ctrl_signal;
} MemoryCtrlSignalSt;

typedef struct packed {
  logic [3:0] alu_type;
} ALU_CtrlSignalSt;

typedef struct packed {
  logic branch_type;
} BranchCtrlSignalSt;

typedef struct packed {
  logic ctrl_signal;
} PrivCtrlSignalSt;

// 整数指令的合集
typedef struct packed {
  logic [1:0] inst_type;
  ALU_CtrlSignalSt alu_ctrl_signal;
  BranchCtrlSignalSt branch_ctrl_signal;
  PrivCtrlSignalSt priv_ctrl_signal;
} IntegerCtrlSignalSt;

typedef struct packed {
  logic [2:0] inst_type;
  logic [2:0] reg_valid;  // 记录reg使用情况{src1, src0, dest}
  MemoryCtrlSignalSt mem_ctrl_signal;
  IntegerCtrlSignalSt int_ctrl_signal;
} GeneralCtrlSignalSt;







`endif  // _DECODER_SVH_