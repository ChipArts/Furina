// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Scheduler.svh
// Create  : 2024-03-12 23:17:37
// Revise  : 2024-03-13 23:18:18
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

`ifndef __SCHEDULER_SVH__
`define __SCHEDULER_SVH__

`include "config.svh"
`include "Decoder.svh"

typedef struct packed {
  logic valid;
  logic ready;  // 请求方可接收rsp响应(暂时无用恒为1)
  InstInfoSt [`DECODE_WIDTH - 1:0] inst_info;
} ScheduleReqSt;

typedef struct packed {
  logic valid;  // rsp信息有效(暂时无用恒为1)
  logic ready;  // 接收req请求
} ScheduleRspSt;


`endif // __SCHEDULER_SVH__
