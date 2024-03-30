// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : ReorderBuffer.svh
// Create  : 2024-03-13 21:02:26
// Revise  : 2024-03-29 17:56:37
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
  logic phy_reg_valid;
  logic [$clog2(`PHY_REG_NUM) - 1:0] phy_reg;
  logic [$clog2(`PHY_REG_NUM) - 1:0] old_phy_reg;
  logic [`PROC_VALEN - 1:0] pc;
  logic redirect;
  logic [`PROC_VALEN - 1:0] br_target;
  logic exception;
  ExcCodeType ecode;
  InstType inst_type;
  MemType mem_type;
} RobEntrySt;

typedef struct packed {
  logic [`DECODE_WIDTH - 1:0] valid;
  RobEntrySt [`DECODE_WIDTH - 1:0] rob_entry;
} RobAllocReqSt;

typedef struct packed {
  logic ready;
  logic [`DECODE_WIDTH - 1:0] position_bit;
  logic [`DECODE_WIDTH - 1:0][$clog2(`ROB_DEPTH) - 1:0] rob_idx;
} RobAllocRspSt;

typedef struct packed {
  logic valid;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  logic exception;
  ExcCodeType ecode;
} RobCmtReqSt;

typedef struct packed {
  logic ready;
} RobCmtRspSt;

typedef struct packed {
  logic [`RETIRE_WIDTH - 1:0] valid;
  RobEntrySt [`RETIRE_WIDTH - 1:0] rob_entry;
} RobRetireBcstSt;


`endif  // _REORDER_BUFFER_SVH_
