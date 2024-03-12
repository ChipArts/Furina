// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Cache.svh
// Create  : 2024-03-01 21:28:47
// Revise  : 2024-03-12 17:13:51
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
// | Tag | Index |    BYTE    |
// ----------------------------
//       |       |            |
//       |       |            0  
//       |       DCacheIndexOffset
//       DCacheTagOffset
// 地址偏移
`define ICACHE_INDEX_OFFSET $clog2(`ICACHE_SIZE / `ICACHE_ASSOCIATIVITY / `ICACHE_BLOCK_SIZE)
`define ICACHE_TAG_OFFSET $clog2(`ICACHE_SIZE / `ICACHE_ASSOCIATIVITY)
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
  logic [`PROC_FETCH_WIDTH - 1:0] valid;  // 请求有效
  logic ready;  // 请求方可接收数据
  logic [`PROC_VALEN - 1:0] vaddr;  // 请求地址
} ICacheReqSt;

typedef struct packed {
  logic [`PROC_FETCH_WIDTH - 1:0] valid;
  logic ready;  // 接收fetch请求
  logic [`PROC_FETCH_WIDTH - 1:0][`PROC_VALEN - 1:0] vaddr;
  logic [`PROC_FETCH_WIDTH - 1:0][31:0] instructions;  // 指令
} ICacheRspSt;

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
`define DCACHE_BANK_NUM 8  // 不要修改
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
  
  logic [`PROC_VALEN - 1:0] vaddr;  // 请求地址
  logic [2:0] align_type;  // 对齐类型(b/h/w/ub/uh)
} DCacheLoadReqSt;

typedef struct packed {
  logic valid;  // 请求有效
  logic ready;  // 可以接收读数据请求
  
  // DCache Info
  logic [`PROC_VALEN - 1:0] vaddr;  // 请求地址
  logic [31:0] data;  // 写数据
  logic [2:0] align_type;  // 对齐类型(b/h/w/ub/uh)
} DCacheStoreReqSt;

typedef struct packed {
  logic valid;  // 读数据有效
  logic ready;  // DCache接收读请求

  logic [31:0] data;  // 读取的数据
} DCacheLoadRspSt;

typedef struct packed {
  logic valid;
  logic ready;  // DCache接收读请求
  logic okay;  // DCache完成写入
} DCacheStoreRspSt;



// LoadPipe对外接口
typedef struct packed {
  logic valid;  // 请求有效
  logic [`PROC_VALEN - 1:0] vaddr;  // 请求地址
  logic [2:0] align_type;  // 对齐类型(b/h/w/ub/uh)
} LoadPipeStage0InputSt;

typedef struct packed {
  logic ready;  // 接收请求
  logic valid;  // 读tag/meta/tlb请求有效
  logic [`PROC_VALEN - 1:0] vaddr;  // 虚拟地址
} LoadPipeStage0OutputSt;


typedef struct packed {
  logic valid;  // 数据有效
  logic bank_conflict;  // bank冲突
  // TLB Info
  logic [`PROC_PALEN - 1:0] paddr;  // 物理页号
  // DCache Info
  DCacheMetaInfoSt [`DCACHE_ASSOCIATIVITY - 1:0] meta;
  logic [`DCACHE_ASSOCIATIVITY - 1:0][`DCACHE_TAG_WIDTH - 1:0] tag;  // cache tag
  logic [`DCACHE_ASSOCIATIVITY - 2:0] plru;  // 伪LRU
} LoadPipeStage1InputSt;

typedef struct packed {
  logic valid;  // 读数据请求有效
  logic miss;
  logic [`PROC_PALEN - 1:0] paddr;  // 物理地址
  // miss时的替换信息
  DCacheMetaInfoSt  replaced_meta;
  logic [`PROC_PALEN - 1:0] replaced_paddr;
  logic [$clog2(`DCACHE_ASSOCIATIVITY) - 1:0] replaced_way;  // 被替换的way的索引
  // plru
  logic [`DCACHE_ASSOCIATIVITY - 2:0] plru;  // 新的伪LRU内容
} LoadPipeStage1OutputSt;


typedef struct packed {
  logic valid;  // 数据有效
  logic [`DCACHE_ASSOCIATIVITY - 1:0][`DCACHE_BANK_NUM - 1:0][`BANK_BYTE_NUM - 1:0][7:0] data;  // DCache读取的数据
} LoadPipeStage2InputSt;

typedef struct packed {
  logic valid;
  logic [31:0] data;  // 读出对齐的数据
} LoadPipeStage2OutputSt;



// MainPipe对外接口
typedef struct packed {
  // logic probe_valid;
  // logic replace_valid;  // 替换请求
  logic store_valid;  // 存储请求
  // logic atomic_req;  // 原子操作请求
  // logic [`PROC_VALEN - 1:0] replace_paddr;  // 替换请求地址
  logic [`PROC_VALEN - 1:0] vaddr;  // 存储请求地址
  logic [31:0] data;  // 存储请求数据
  logic [2:0] align_type;  // 对齐类型(b/h/w/ub/uh)
} MainPipeStage0InputSt;

typedef struct packed {
  logic valid;  //读tag/meta/tlb请求有效
  // logic probe_ready;
  // logic replace_ready;  // 接收替换请求
  logic store_ready;  // 接受存储请求
  // logic atomic_req;  // 原子操作请求
  logic [`PROC_VALEN - 1:0] vaddr;  // 虚地址(查询tlb/tag/meta)
} MainPipeStage0OutputSt;


typedef struct packed {
  logic valid;
  // TLB Info
  logic [`PROC_PALEN - 1:12] paddr;  // 物理地址
  // DCache Info
  DCacheMetaInfoSt [`DCACHE_ASSOCIATIVITY - 1:0] meta;
  logic [`DCACHE_ASSOCIATIVITY - 1:0][`DCACHE_TAG_WIDTH - 1:0] tag;  // cache tag
} MainPipeStage1InputSt;

typedef struct packed {
  logic valid;
  logic miss;
  logic [`PROC_PALEN - 1:0] paddr;  // 物理地址
  // miss时的替换信息
  DCacheMetaInfoSt  replaced_meta;
  logic [`PROC_PALEN - 1:0] replaced_paddr;
  logic [$clog2(`DCACHE_ASSOCIATIVITY) - 1:0] replaced_way;  // 被替换的way的索引
  // plru
  logic [`DCACHE_ASSOCIATIVITY - 2:0] plru;  // 新的伪LRU内容
} MainPipeStage1OutputSt;


typedef struct packed {
  logic valid;  // 数据有效
  logic [`DCACHE_ASSOCIATIVITY - 1:0][`DCACHE_BLOCK_SIZE - 1:0][7:0] data;  // DCache读取的数据
} MainPipeStage2InputSt;

typedef struct packed {
  logic valid;
  DCacheMetaInfoSt meta;  // 要写入的meta信息
  logic [`DCACHE_ASSOCIATIVITY - 1:0] we;
  logic [`DCACHE_BANK_NUM - 1:0][`BANK_BYTE_NUM - 1:0][7:0] data;
} MainPipeStage2OutputSt;


typedef struct packed {
  logic valid;
} MainPipeStage3InputSt;

typedef struct packed {
  logic valid;
} MainPipeStage3OutputSt;


`endif  // _CACHE_SVH_