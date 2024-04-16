// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : FetchAddressQueue.svh
// Create  : 2024-02-14 17:37:54
// Revise  : 2024-03-17 22:24:58
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


`ifndef _FETCH_ADDRESS_QUEUE_SVH_
`define _FETCH_ADDRESS_QUEUE_SVH_

`include "config.svh"

typedef struct packed {
  logic [`FETCH_WIDTH - 1:0] valid;  // push请求有效
  logic [`PROC_VALEN - 1:0] vaddr; 
} FaqPushReqSt;

typedef struct packed {
  logic ready;  // faq可接收push请求
} FaqPushRspSt;

typedef struct packed {
  logic valid;  // pop请求有效
  logic ready;  // 请求方可接收pop应答
} FaqPopReqSt;

typedef struct packed {
  logic [`FETCH_WIDTH - 1:0] valid;
  logic ready;  // faq接收pop请求
  logic [`PROC_VALEN - 1:0] vaddr;
} FaqPopRspSt;


`endif  // _FETCH_ADDRESS_QUEUE_SVH_
