// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Decoder.svh
// Create  : 2024-03-01 16:04:57
// Revise  : 2024-03-13 22:54:55
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
} GeneralCtrlSignalSt;

`endif  // _DECODER_SVH_