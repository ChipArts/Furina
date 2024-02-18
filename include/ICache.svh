// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : ICache.svh
// Create  : 2024-02-16 12:19:32
// Revise  : 2024-02-18 20:01:47
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

`ifndef _ICACHE_SVH_
`define _ICACHE_SVH_

`include "config.svh"
`include "InstructionFetchUnit.svh"

typedef struct packed {
  logic fetch_valid;
  logic [`PROC_BIT_WIDTH - $clog2(`PROC_PAGE_SIZE) - 1:0] vpn; 
} ICache2TLBSt;

typedef struct packed {
  logic fetch_ready;  // 接收fetch请求
  logic miss;
  logic [`ICACHE_FECTH_WIDTH - 1:0][31:0] instructions;  // 指令
} ICache2IFUSt;

`endif  // _ICACHE_SVH_