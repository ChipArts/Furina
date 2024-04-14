// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : BranchPredictionUnit.svh
// Create  : 2024-02-12 18:06:30
// Revise  : 2024-03-13 17:57:36
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

`ifndef _BRANCH_PREDICTION_UNIT_SVH_
`define _BRANCH_PREDICTION_UNIT_SVH_

`include "config.svh"

typedef struct packed {
  logic next;  // 下一个pc
  logic redirect;  // 重定向请求
  logic [`PROC_VALEN:0] target;
} BpuReqSt;


typedef struct packed {
  logic [31:0] pc;
  logic [`FETCH_WIDTH - 1:0] valid;  // 表明pc~pc+7中哪几个是有效的
} BpuRspSt;

`endif  // _BRANCH_PREDICTION_UNIT_SVH_