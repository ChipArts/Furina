// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : TranslationLookasideBuffer.svh
// Create  : 2024-02-17 21:38:07
// Revise  : 2024-03-30 15:48:11
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

typedef struct packed {
  // TLB比较信息
  logic exist;  // 存在位(E)
  logic [9:0] asid;  // 地址空间标识(ASID)
  logic glo;  // 全局标志位(G)
  logic [5:0] page_size;  // 页大小(PS)
  logic [`PROC_VALEN - 1:13] vppn;  // 双虚拟页号(VPPN)
  // TLB转换信息
  logic [1:0] valid;  // 有效位(V)
  logic [1:0] dirty;  // 脏位(D)
  logic [1:0][1:0] mat;  // 存储访问类型(MAT)
  logic [1:0][1:0] plv;  // 特权等级(PLV)
  logic [1:0][`PROC_PALEN - 1:12] ppn;  // 物理页号(PPN)
} TlbEntrySt;

// TLB查询请求
typedef struct packed {
  logic valid;  // 请求有效
  logic [`PROC_VALEN - 1:12] vpn;
  logic [9:0] asid;
} TlbSearchReqSt;

typedef struct packed {
  logic valid;  // 查询结果有效
  logic ready;  // TLB 可以进行查询操作

  logic found;   // TLB 查询结果命中
  logic [$clog2(`TLB_ENTRY_NUM) - 1:0] idx;  // TLB命中项的索引值
  logic [5:0] page_size;  // 页大小
  logic dirty;  // 查询结果脏位
  logic [`PROC_PALEN - 1:12] ppn;  // 物理页号
  logic [1:0] mat;  // 存储访问类型(MAT)
  logic [1:0] plv;  // 特权等级(PLV)
} TlbSearchRspSt;

// TLB读取请求
typedef struct packed {
  logic valid;  // 请求有效
  logic [$clog2(`TLB_ENTRY_NUM) - 1:0] idx;  // 读取的索引值
} TlbReadReqSt;

typedef struct packed {
  logic ready;  // TLB 可以进行读取操作
  TlbEntrySt tlb_entry_st;  // 读取的表项
} TlbReadRspSt;

// TLB写入请求
typedef struct packed {
  logic valid;  // 请求有效
  logic [$clog2(`TLB_ENTRY_NUM) - 1:0] idx;  // 写入的索引值
  TlbEntrySt tlb_entry_st;  // 写入的表项
} TlbWriteReqSt;

typedef struct packed {
  logic ready;  // TLB 可以进行写入操作
} TlbWriteRspSt;

// TLB无效化请求
typedef logic [4:0] TlbInvOptionType;
`define TLB_INV_ALL0         (5'd0)
`define TLB_INV_ALL1         (5'd1)
`define TLB_INV_GLO1         (5'd2)
`define TLB_INV_GLO0         (5'd3)
`define TLB_INV_GLO0_ASID    (5'd4)
`define TLB_INV_GLO0_ASID_VA (5'd5)
`define TLB_INV_GLO1_ASID_VA (5'd6)

typedef struct packed {
  logic valid;  // 请求有效
  TlbInvOptionType op;  // 无效化选项
  logic [9:0] asid;
  logic [`PROC_VALEN - 1:13] vppn;
} TlbInvReqSt;

typedef struct packed {
  logic ready;  // TLB 可以进行无效化操作
} TlbInvRspSt;


`endif  // _TRANSLATION_LOOKASIDE_BUFFER_SVH_
