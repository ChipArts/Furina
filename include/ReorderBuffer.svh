// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : ReorderBuffer.svh
// Create  : 2024-03-13 21:02:26
// Revise  : 2024-03-13 23:18:13
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

`ifndef _REORDER_BUFFER_SVH_
`define _REORDER_BUFFER_SVH_

`include "config.svh"

typedef struct packed {
  logic complete;
  logic [4:0] arch_reg;
  logic [$clog2(`PHY_REG_NUM) - 1:0] phy_reg;
  logic [$clog2(`PHY_REG_NUM) - 1:0] old_phy_reg;
  logic [`PROC_VALEN - 1:0] pc;
  logic exception;  // TODO
  logic [1:0] inst_type;  // TODO
} ROB_EntrySt;

typedef struct packed {
  logic valid;
  logic ready;
  ROB_EntrySt [`DECODE_WIDTH - 1:0] rob_entry;
} ROB_DispatchReqSt;

typedef struct packed {
  logic valid;
  logic ready;
} ROB_DispatchRspSt;


`endif  // _REORDER_BUFFER_SVH_
