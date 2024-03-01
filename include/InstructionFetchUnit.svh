// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : InstructionFetchUnit.svh
// Create  : 2024-02-14 17:31:32
// Revise  : 2024-03-01 16:00:24
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


`ifndef _INSTRUCTION_FETCH_UNIT_SVH_
`define _INSTRUCTION_FETCH_UNIT_SVH_

`include "config.svh"

`define ICACHE_FECTH_WIDTH `PROC_FETCH_WIDTH

typedef struct packed {
  logic fetch_valid;
} IFU2FAQSt;

typedef struct packed {
  logic fetch_valid;  // fetch请求有效
  logic [`PROC_BIT_WIDTH - 1:0] vpc;
} IFU2ICacheSt;


`endif  // _INSTRUCTION_FETCH_UNIT_SVH_