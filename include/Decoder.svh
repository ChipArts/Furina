// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Decoder.svh
// Create  : 2024-03-01 16:04:57
// Revise  : 2024-03-18 23:33:53
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

typedef logic [1:0] InstType;

`define ALU_INST (2'd0)
`define BRANCH_INST (2'd1)
`define PRIV_INST (2'd2)
`define MEMORY_INST (2'd3)

`define MEM_STROE (1'd0)
`define MEM_LOAD (1'd1)

`define CALC_OP_ADD (4'd0)
`define CALC_OP_SUB (4'd1)
`define CALC_OP_SLT (4'd2)
`define CALC_OP_AND (4'd3)
`define CALC_OP_OR (4'd4)
`define CALC_OP_XOR (4'd5)
`define CALC_OP_NOR (4'd6)
`define CALC_OP_SL (4'd7)
`define CALC_OP_SR (4'd8)
`define CALC_OP_LUI (4'd9)
`define CALC_OP_MUL (4'd10)
`define CALC_OP_MULH (4'd11)
`define CALC_OP_DIV (4'd12)
`define CALC_OP_MOD (4'd13)

typedef logic[3:0] CalcOpType;

`define ALIGN_TYPE_B  (3'd0)
`define ALIGN_TYPE_H  (3'd1)
`define ALIGN_TYPE_W  (3'd2)
`define ALIGN_TYPE_BU (3'd3)
`define ALIGN_TYPE_HU (3'd4)


typedef logic[3:0] BranchOpType;

`define BRANCH_EQ (3'd0)
`define BRANCH_NE (3'd1)
`define BRANCH_LT (3'd2)
`define BRANCH_GE (3'd3)
`define BRANCH_NC (3'd4)

typedef struct packed {
  logic mem_type;
} MemoryOptionCodeSt;

typedef struct packed {
  CalcOpType calc_op;
  logic unsigned_op;
  logic use_imm;
} AluOptionCodeSt;

typedef struct packed {
  InstType inst_type;
  logic unsigned_op;
  BranchOpType branch_op;
  logic br_indirect;
} MiscOptionCodeSt;

typedef struct packed {
  InstType inst_type;
} OptionCodeSt;

function MiscOptionCodeSt gen2misc(OptionCodeSt option_code);
  
endfunction : gen2misc

function AluOptionCodeSt gen2alu(OptionCodeSt option_code);

endfunction : gen2alu

function MemoryOptionCodeSt gen2mem(OptionCodeSt option_code);

endfunction : gen2mem

`endif  // _DECODER_SVH_