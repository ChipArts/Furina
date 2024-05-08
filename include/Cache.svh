// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Cache.svh
// Create  : 2024-03-01 21:28:47
// Revise  : 2024-04-01 15:09:20
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
`include "ControlStatusRegister.svh"
`include "BranchPredictionUnit.svh"
`include "Decoder.svh"

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
`define ICACHE_IDX_OFFSET $clog2(`ICACHE_BLOCK_SIZE)
`define ICACHE_TAG_OFFSET $clog2(`ICACHE_SIZE / `ICACHE_WAY_NUM)
// 地址位宽
`define ICACHE_OFS_WIDTH `ICACHE_IDX_OFFSET
`define ICACHE_IDX_WIDTH (`ICACHE_TAG_OFFSET - `ICACHE_IDX_OFFSET)
// 存储器数据位宽
`define ICACHE_TAG_WIDTH (`PROC_VALEN - `ICACHE_TAG_OFFSET)

`define ICACHE_OFS_OF(ADDR) ADDR[`ICACHE_IDX_OFFSET - 1:0]
`define ICACHE_IDX_OF(ADDR) ADDR[`ICACHE_TAG_OFFSET - 1:`ICACHE_IDX_OFFSET]
`define ICACHE_TAG_OF(ADDR) ADDR[`PROC_PALEN - 1:`ICACHE_TAG_OFFSET]

`define FETCH_OFS ($clog2(`FETCH_WIDTH) + 2)
`define FETCH_ALIGN(ADDR) {ADDR[`PROC_VALEN - 1:`FETCH_OFS],  {`FETCH_OFS{1'b0}}}
`define ICACHE_PADDR_ALIGN(PADDR) {PADDR[`PROC_PALEN - 1:`ICACHE_IDX_OFFSET], {`ICACHE_IDX_OFFSET{1'b0}}}

// 要保证每次请求的指令在同一Cache行即idx相同
typedef struct packed {
  logic valid;  // 请求有效
  logic ready;  // 请求方可接收相应(暂时无用)
  logic [`PROC_VALEN - 1:0] vaddr;  // 请求地址
  // logic [31:0] npc;  // 最后一条有效指令的下一个pc
  logic has_int;     // 有中断
} ICacheReqSt;

typedef struct packed {
  logic valid;
  logic ready;  // 接收fetch请求

  logic [`FETCH_WIDTH - 1:0][`PROC_VALEN - 1:0] vaddr;
  // logic [`FETCH_WIDTH - 1:0][31:0] npc;  // 最后一条有效指令的下一个pc
  logic [`FETCH_WIDTH - 1:0][31:0] instr;  // 指令

  ExcpSt excp;
} ICacheRspSt;

typedef struct packed {
  logic valid;
  logic ready;
  logic [`PROC_VALEN - 1:0] vaddr;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  logic [4:3] cacop_mode;
} IcacopReqSt;

typedef struct packed {
  logic valid;
  logic ready;
  ExcpSt excp;
  logic [`PROC_VALEN - 1:0] vaddr;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
} IcacopRspSt;

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
`define DCACHE_IDX_OFFSET $clog2(`DCACHE_BLOCK_SIZE)
`define DCACHE_TAG_OFFSET $clog2(`DCACHE_SIZE / `DCACHE_WAY_NUM)
// 地址位宽
`define DCACHE_OFS_WIDTH `DCACHE_IDX_OFFSET
`define DCACHE_IDX_WIDTH (`DCACHE_TAG_OFFSET - `DCACHE_IDX_OFFSET)
// 存储器数据位宽
`define DCACHE_TAG_WIDTH (`PROC_VALEN - `DCACHE_TAG_OFFSET)

`define DCACHE_OFS_OF(ADDR) ADDR[`DCACHE_IDX_OFFSET - 1:0]
`define DCACHE_IDX_OF(ADDR) ADDR[`DCACHE_TAG_OFFSET - 1:`DCACHE_IDX_OFFSET]
`define DCACHE_TAG_OF(ADDR) ADDR[`PROC_VALEN - 1:`DCACHE_TAG_OFFSET]

`define DCACHE_PADDR_ALIGN(PADDR) {PADDR[`PROC_PALEN - 1:`DCACHE_IDX_OFFSET], {`DCACHE_IDX_OFFSET{1'b0}}}

typedef struct packed {
  logic valid;
  logic dirty;
} DCacheMetaSt;

typedef struct packed {
  // stage 0;
  logic                     valid;
  MemOpType                 mem_op;
  logic [4:0]               code;  // for cacop and preld
  logic                     llbit;
  logic                     atomic;
  logic                     preld;
  logic [`PROC_VALEN - 1:0] vaddr;
  AlignOpType               align_op;
  logic [31:0]              wdata;
  logic                     pdest_valid;
  logic [$clog2(`PHY_REG_NUM) - 1:0] pdest;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;

  // stage 2
  logic                     ready;  // 请求方可接收响应
} DCacheReqSt;

typedef struct packed {
  // stage 0
  logic ready;   // cache接收请求
  // stage 2
  logic valid;
  logic [31:0] rdata;
  MemOpType mem_op;
  logic atomic;
  logic llbit;
  logic pdest_valid;
  logic [$clog2(`PHY_REG_NUM) - 1:0] pdest;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  ExcpSt excp;
  logic [`PROC_VALEN - 1:0] vaddr;
  // diff
  logic [`PROC_VALEN - 1:0] paddr;
  logic [31:0] store_data;
} DCacheRspSt;


`endif  // _CACHE_SVH_
