// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Cache.svh
// Create  : 2024-03-01 21:28:47
// Revise  : 2024-03-03 17:42:39
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

// DCache
typedef struct packed {
  logic valid;  // 请求有效
  logic [`PROC_PALEN - 1:12] ppn;  // 物理页号
  logic [`PROC_VALEN - 1:0] vaddr;  // 请求地址
  logic uncached;  // 非缓存请求
} DCacheReadReqSt;

typedef struct packed {
  logic valid;  // 请求有效
  logic [`PROC_PALEN - 1:12] ppn;  // 物理页号
  logic [`PROC_VALEN - 1:0] vaddr;  // 请求地址
  logic uncached;  // 非缓存请求
  logic [31:0] data;  // 写数据
} DCacheWriteReqSt;

typedef struct packed {
  logic ready; // DCache接收读请求
  logic miss;  // DCache未命中
  logic valid; // 读数据有效
  logic [31:0] data;  // 读取的数据
} DcacheReadRspSt;

typedef struct packed {
  logic ready; // DCache接收写请求
  logic miss;  // DCache未命中
  logic resp;  // 写响应(写入成功)
} DcacheWriteRspSt;


// L2Cache
typedef struct packed {
  logic valid;  // 请求有效
  logic [`PROC_PALEN - 1:0] paddr;  // 请求地址
  logic uncached;  // 非缓存请求
} L2CacheReadReqSt;

typedef struct packed {
  logic valid;  // 请求有效
  logic [`PROC_PALEN - 1:0] paddr;  // 请求地址
  logic uncached;  // 非缓存请求
  logic [31:0] data;  // 写数据
} L2CacheWriteReqSt;

typedef struct packed {
  logic ready; // L2Cache接收读请求
  logic miss;  // L2Cache未命中
  logic valid; // 读数据有效
  logic [31:0] data;  // 读取的数据
} L2cacheReadRspSt;

typedef struct packed {
  logic ready; // L2Cache接收写请求
  logic miss;  // L2Cache未命中
  logic resp;  // 写响应(写入成功)
} L2cacheWriteRspSt;



`endif  // _CACHE_SVH_