// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : FetchAddressQueue.svh
// Create  : 2024-02-14 17:37:54
// Revise  : 2024-02-16 17:08:44
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

`define FAQ_DEPTH 16

typedef struct packed {
  logic fetch_valid;
} FAQ2BPUSt;

typedef struct packed {
  logic [`PROC_BIT_WIDTH - 1:0] pc;
  logic [`PROC_DECODE_WIDTH - 1:0] valid;
  logic [$clog2(`FAQ_DEPTH) - 1:0] faq_head;
  logic [$clog2(`FAQ_DEPTH) - 1:0] faq_tail;
  logic [$clog2(`FAQ_DEPTH + 1) - 1:0] faq_cnt;
} FAQ2IFUSt;

`endif  // _FETCH_ADDRESS_QUEUE_SVH_