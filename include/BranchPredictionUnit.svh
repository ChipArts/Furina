// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : BranchPredictionUnit.svh
// Create  : 2024-02-12 18:06:30
// Revise  : 2024-02-14 16:26:12
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
  logic [`PROC_BIT_WIDTH - 1:0] pc;
  logic [`PROC_DECODE_WIDTH - 1:0] valid;
} BPU2FAQSt;

`endif  // _BRANCH_PREDICTION_UNIT_SVH_