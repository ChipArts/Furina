// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Cache.svh
// Create  : 2024-03-01 21:28:47
// Revise  : 2024-03-08 18:27:40
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

// ICache
typedef struct packed {
  logic valid;  // 请求有效
  logic [`PROC_VALEN - 1:0] vaddr;  // 请求地址
  logic uncached;  // 非缓存请求
} ICacheReadReqSt;

typedef struct packed {
  logic ready;  // 接收fetch请求
  logic miss;
  logic [`PROC_FETCH_WIDTH - 1:0][31:0] instructions;  // 指令
  logic [`PROC_FETCH_WIDTH - 1:0] valid;
} ICacheReadRspSt;

/* DCache */
//       Virtual Address
// -----------------------------
// | Tag | Index | Bank | BTYE |
// -----------------------------
//       |       |      |      |
//       |       |      |      0
//       |       |      DCacheBankOffset
//       |       DCacheIndexOffset
//       DCacheTagOffset
// DCache 的索引长度小于页内偏移长度
`define DCACHE_BANK_NUM 8
// 地址偏移
`define DCACHE_BANK_OFFSET $clog2(`DCACHE_SIZE / `DCACHE_ASSOCIATIVITY / `DCACHE_BLOCK_SIZE / `DCACHE_BANK_NUM)
`define DCACHE_INDEX_OFFSET $clog2(`DCACHE_SIZE / `DCACHE_ASSOCIATIVITY / `DCACHE_BLOCK_SIZE)
`define DCACHE_TAG_OFFSET $clog2(`DCACHE_SIZE / `DCACHE_ASSOCIATIVITY)
// 地址位宽
`define DCACHE_BYTE_WIDTH `DCACHE_BANK_OFFSET
`define DCACHE_BANK_WIDTH $clog2(`DCACHE_BANK_NUM)
`define DCACHE_INDEX_WIDTH (`DCACHE_TAG_OFFSET - `DCACHE_TAG_OFFSET)
// 存储器数据位宽
`define DCACHE_TAG_WIDTH (`PROC_VALEN - `DCACHE_TAG_OFFSET)
`define BANK_BYTE_NUM (`DCACHE_BLOCK_SIZE / `DCACHE_BANK_NUM)

`define DCACHE_BYTE_OF(ADDR) ADDR[`DCACHE_BYTE_WIDTH - 1:0]
`define DCACHE_BANK_OF(ADDR) ADDR[`DCACHE_INDEX_OFFSET - 1:`DCACHE_BANK_OFFSET]
`define DCACHE_INDEX_OF(ADDR) ADDR[`DCACHE_TAG_OFFSET - 1:`DCACHE_INDEX_OFFSET]
`define DCACHE_TAG_OF(ADDR) ADDR[`PROC_VALEN - 1:`DCACHE_TAG_OFFSET]


typedef struct packed {
  logic valid;
  logic dirty;
} DCacheMetaInfoSt;

typedef struct packed {
  logic valid;  // 请求有效
  logic [`PROC_PALEN - 1:12] ppn;  // 物理页号
  logic [`PROC_VALEN - 1:0] vaddr;  // 请求地址
  logic uncached;  // 非缓存请求
  logic [5:0] page_size;
} DCacheLoadReqSt;

typedef struct packed {
  logic valid;  // 请求有效
  logic [`PROC_PALEN - 1:12] ppn;  // 物理页号
  logic [`PROC_VALEN - 1:0] vaddr;  // 请求地址
  logic uncached;  // 非缓存请求
  logic [`DCACHE_BLOCK_SIZE:0] data;  // 写数据
} DCacheStoreReqSt;

typedef struct packed {
  logic ready; // DCache接收读请求

  logic miss;  // DCache未命中
  logic valid; // 读数据有效
  logic [31:0] data;  // 读取的数据
} DcacheLoadRspSt;

typedef struct packed {
  logic ready; // DCache接收写请求
  logic miss;  // DCache未命中
  logic resp;  // 写响应(写入成功)
} DcacheStoreRspSt;

// LoadPipe对外接口
typedef struct packed {
  logic valid;  // 请求有效
  logic [`PROC_VALEN - 1:0] vaddr;  // 请求地址
  logic [2:0] load_type;
} LoadPipeStage0InputSt;

typedef struct packed {
  logic bank_conflict;  // bank冲突
  logic [`PROC_PALEN - 1:12] ppn;  // 物理页号
  logic [5:0] page_size; // 页大小
  logic [`DCACHE_ASSOCIATIVITY - 1:0][`DCACHE_TAG_WIDTH - 1:0] tag;  // cache tag
  logic [`DCACHE_ASSOCIATIVITY - 1:0] valid;  // Cache行有效
  logic [$clog2(`DCACHE_ASSOCIATIVITY) - 1:0] replace_way;  // 替换way的标号
} LoadPipeStage1InputSt;

typedef struct packed {
  logic [`DCACHE_ASSOCIATIVITY - 1:0][`BANK_BYTE_NUM - 1:0][7:0] data;  // DCache读取的数据
} LoadPipeStage2InputSt;

typedef struct packed {
  logic ready;  // 接收请求
  logic [`DCACHE_INDEX_WIDTH - 1:0] vidx;  // 虚地址索引
} LoadPipeStage0OutputSt;

typedef struct packed {
  logic miss;
  logic update_replace_way;  // 更新替换way
  logic [`DCACHE_INDEX_WIDTH - 1:0] pidx;  // 物理址索引
  logic [$clog2(`DCACHE_ASSOCIATIVITY) - 1:0] replace_way;  // 时钟算法新的替换way
} LoadPipeStage1OutputSt;

typedef struct packed {
  logic [31:0] data;  // 读出对齐的数据
} LoadPipeStage2OutputSt;

// MainPipe对外接口
typedef struct packed {
  logic replace_valid;  // 替换请求
  logic store_valid;  // 存储请求
  // logic atomic_req;  // 原子操作请求
  logic [`PROC_VALEN - 1:0] vaddr;  // 请求地址
  logic [1:0] store_type;  // 存储类型
} MainPipeStage0InputSt;

typedef struct packed {
  logic bank_conflict;  // bank冲突
  logic [`PROC_PALEN - 1:12] ppn;  // 物理页号
  logic [5:0] page_size; // 页大小
  logic [`DCACHE_ASSOCIATIVITY - 1:0][`DCACHE_TAG_WIDTH - 1:0] tag;  // cache tag
  logic [`DCACHE_ASSOCIATIVITY - 1:0] valid;  // Cache行有效
  logic [$clog2(`DCACHE_ASSOCIATIVITY) - 1:0] replace_way;  // 替换way的标号 
} MainPipeStage1InputSt;


typedef struct packed {
  logic replace_ready;  // 接收替换请求
  logic store_ready;  // 接受存储请求
  logic [`PROC_VALEN - 1:0] vaddr;  // 虚地址
} MainPipeStage0OutputSt;


`endif  // _CACHE_SVH_