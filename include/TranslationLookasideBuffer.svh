// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : TranslationLookasideBuffer.svh
// Create  : 2024-02-17 21:38:07
// Revise  : 2024-02-17 21:41:24
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

`ifndef _TRANSLATION_LOOKASIDE_BUFFER_SVH_
`define _TRANSLATION_LOOKASIDE_BUFFER_SVH_

`include "config.svh"
`include "InstructionFetchUnit.svh"


typedef struct packed {
  logic fetch_ready;
  logic [`PROC_BIT_WIDTH - $clog2(`PROC_PAGE_SIZE) - 1:0] ppn;  // 物理页号
} TLB2ICacheSt;


`endif  // _TRANSLATION_LOOKASIDE_BUFFER_SVH_
