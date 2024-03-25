// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : MemoryManagementUnit.svh
// Create  : 2024-03-11 19:21:56
// Revise  : 2024-03-25 15:39:17
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

`ifndef _MEMORY_MANAGEMENT_UNIT_SVH_
`define _MEMORY_MANAGEMENT_UNIT_SVH_

`include "config.svh"

typedef struct packed {
  logic valid;  // 请求有效
  logic ready;  // 请求方可接收返回数据
  logic [`PROC_VALEN - 1:0] vaddr;
} MmuAddrTransReqSt;

typedef struct packed {
  logic valid;  // 数据有效
  logic ready;  // mmu可接收请求
  logic miss;   // TLB 查询结果未命中

  logic [`PROC_PALEN - 1:0] paddr;
  logic uncache;
  logic tlb_valid;
  logic tlb_dirty;  // 查询结果脏位
  logic tlb_mat;  // 存储访问类型(MAT)
  logic tlb_plv;  // 特权等级(PLV)
} MmuAddrTransRspSt;

`endif  // _MEMORY_MANAGEMENT_UNIT_SVH_