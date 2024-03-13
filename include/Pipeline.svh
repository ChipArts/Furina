// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Pipeline.svh
// Create  : 2024-03-13 22:53:51
// Revise  : 2024-03-13 22:55:19
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

`ifndef __PIPELINE_SVH__
`define __PIPELINE_SVH__

`include "config.svh"

typedef struct packed {
  logic valid;
  logic [`PROC_VALEN - 1:0] vaddr;
  logic [25:0] operand;
  GeneralCtrlSignalSt general_ctrl_signal_st;
} InstInfoSt;

`endif