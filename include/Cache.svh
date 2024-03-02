// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Cache.svh
// Create  : 2024-03-01 21:28:47
// Revise  : 2024-03-02 21:18:27
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

`ifndef _CACHE_SVH_
`define _CACHE_SVH_

`include "config.svh"

/** ICache **/
// ICache与IFU之间的接口
typedef struct packed {
  logic ready;  // 接收fetch请求
  logic miss;
  logic [`PROC_FETCH_WIDTH - 1:0][31:0] instructions;  // 指令
} ICache2IFUSt;

// DCache

`endif  // _CACHE_SVH_