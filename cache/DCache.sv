// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : DCache.sv
// Create  : 2024-03-03 15:28:53
// Revise  : 2024-03-03 15:29:07
// Description :
//   数据缓存
//   对核内访存组件暴露两个位宽为64的读端口和一个与一级数据缓存行宽度相同的写端口
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
`include "config.svh"
`include "common.svh"
`include "Cache.svh"

module DCache #(
localparam
  int unsigned OFFSET_WIDTH = $clog2(`DCACHE_BLOCK_SIZE),
  int unsigned INDEX_WIDTH = $clog2(`DCACHE_SIZE / `DCACHE_ASSOCIATIVITY / `DCACHE_BLOCK_SIZE),
  int unsigned TAG_WIDTH = 32 - OFFSET_WIDTH - INDEX_WIDTH
)(
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input DCacheReadReqSt [1:0] dcache_read_req_st_i,
  input DCacheWriteReqSt dcache_write_req_st_i
);

  `RESET_LOGIC(clk, a_rst_n, s_rst_n);

endmodule : DCache
