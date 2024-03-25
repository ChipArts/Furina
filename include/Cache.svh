// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Cache.svh
// Create  : 2024-03-01 21:28:47
// Revise  : 2024-03-25 17:46:43
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

/* ICache */
//       Virtual Address
// ----------------------------
// | Tag | Index |   Offset   |
// ----------------------------
//       |       |            |
//       |       |            0  
//       |       ICacheIndexOffset
//       ICacheTagOffset
// 地址偏移
`define ICACHE_INDEX_OFFSET $clog2(`ICACHE_SIZE / `DCACHE_WAY_NUM / `ICACHE_BLOCK_SIZE)
`define ICACHE_TAG_OFFSET $clog2(`ICACHE_SIZE / `DCACHE_WAY_NUM)
// 地址位宽
`define ICACHE_BYTE_WIDTH `ICACHE_INDEX_OFFSET
`define ICACHE_INDEX_WIDTH (`ICACHE_TAG_OFFSET - `ICACHE_TAG_OFFSET)
// 存储器数据位宽
`define ICACHE_TAG_WIDTH (`PROC_VALEN - `ICACHE_TAG_OFFSET)

`define ICACHE_WORD_OF(ADDR) ADDR[`ICACHE_INDEX_OFFSET - 1:2]
`define ICACHE_INDEX_OF(ADDR) ADDR[`ICACHE_TAG_OFFSET - 1:`ICACHE_INDEX_OFFSET]
`define ICACHE_TAG_OF(ADDR) ADDR[`PROC_PALEN - 1:`ICACHE_TAG_OFFSET]

// 要保证每次请求的指令在同一Cache行即idx相同
typedef struct packed {
  logic [`FETCH_WIDTH - 1:0] valid;  // 请求有效
  logic ready;  // 请求方可接收相应(暂时无用)
  logic [`PROC_VALEN - 1:0] vaddr;  // 请求地址
} ICacheFetchReqSt;

typedef struct packed {
  logic [`FETCH_WIDTH - 1:0] valid;
  logic ready;  // 接收fetch请求

  logic [`FETCH_WIDTH - 1:0][`PROC_VALEN - 1:0] vaddr;
  logic [`FETCH_WIDTH - 1:0][31:0] instructions;  // 指令
} ICacheFetchRspSt;

/* DCache */
//       Virtual Address
// ----------------------------
// | Tag | Index |   Offset   |
// ----------------------------
// |     |       |            |
// |     |       |            0  
// |     |       DCacheIndexOffset
// |     DCacheTagOffset
// VALEN
// 地址偏移
`define DCACHE_IDX_OFFSET $clog2(`DCACHE_SIZE / `DCACHE_WAY_NUM / `DCACHE_BLOCK_SIZE)
`define DCACHE_TAG_OFFSET $clog2(`DCACHE_SIZE / `DCACHE_WAY_NUM)
// 地址位宽
`define DCACHE_OFS_WIDTH `DCACHE_IDX_OFFSET
`define DCACHE_IDX_WIDTH (`DCACHE_TAG_OFFSET - `DCACHE_TAG_OFFSET)
// 存储器数据位宽
`define DCACHE_TAG_WIDTH (`PROC_VALEN - `DCACHE_TAG_OFFSET)

`define DCACHE_OFS_OF(ADDR) ADDR[`DCACHE_IDX_OFFSET - 1:0]
`define DCACHE_IDX_OF(ADDR) ADDR[`DCACHE_TAG_OFFSET - 1:`DCACHE_IDX_OFFSET]
`define DCACHE_TAG_OF(ADDR) ADDR[`PROC_VALEN - 1:`DCACHE_TAG_OFFSET]

typedef struct packed {
  logic valid;
  logic dirty;
} DCacheMetaSt;

typedef struct packed {
  logic                     valid;
  logic                     ready;
  MemType                   mem_type;
  logic [`PROC_VALEN - 1:0] vaddr;
  AlignOpType               align_op;
  logic [31:0]              wdata;

  logic [$clog2(`PHY_REG_NUM) - 1:0] pdest;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
} DCacheReqSt;

typedef struct packed {
  logic valid;
  logic ready;

  logic [31:0] rdata;
  MemType mem_type;
  logic [$clog2(`PHY_REG_NUM) - 1:0] pdest;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  logic exception;  // 是否异常
  ExcCodeType ecode;
} DCacheRspSt;


`endif  // _CACHE_SVH_