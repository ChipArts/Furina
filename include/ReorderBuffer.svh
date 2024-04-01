// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : ReorderBuffer.svh
// Create  : 2024-03-13 21:02:26
// Revise  : 2024-04-01 17:35:53
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
  logic [`PROC_VALEN - 1:0] pc;
  InstType inst_type;
  logic [4:0] arch_reg;
  logic phy_reg_valid;
  logic [$clog2(`PHY_REG_NUM) - 1:0] phy_reg;
  logic [$clog2(`PHY_REG_NUM) - 1:0] old_phy_reg;
  // 分支预测失败处理
  logic redirect;
  logic [`PROC_VALEN - 1:0] br_target;
  // 异常/例外处理
  logic exception;
  ExcCodeType ecode;
  SubEcodeType sub_ecode;
  logic [`PROC_VALEN - 1:0] error_vaddr;
`ifdef DEBUG
  logic [31:0] inst;
  logic [31:0] rf_wdata;
`endif
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
  logic redirect;
  logic [`PROC_VALEN - 1:0] br_target;
  logic exception;
  ExcCodeType ecode;
  SubEcodeType sub_ecode;
  logic [`PROC_VALEN - 1:0] error_vaddr;
} RobCmtReqSt;

typedef struct packed {
  logic ready;
} RobCmtRspSt;

typedef struct packed {
  logic [`RETIRE_WIDTH - 1:0] valid;
  RobEntrySt [`RETIRE_WIDTH - 1:0] rob_entry;
} RobRetireSt;


`endif  // _REORDER_BUFFER_SVH_
