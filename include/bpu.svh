// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : bpu.svh
// Create  : 2024-02-12 18:06:30
// Revise  : 2024-02-12 18:18:31
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

`ifndef _BPU_SVH_
`define _BPI_SVH_

`include "config.svh"

typedef struct packed {
  logic [`PROC_BIT_WIDTH - 1:0] pc;
  logic [`PROC_DECODE_WIDTH - 1:0] valid;
} BPU2FAQSt;


`endif  // _BPU_SVH