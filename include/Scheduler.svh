// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Scheduler.svh
// Create  : 2024-03-12 23:17:37
// Revise  : 2024-03-15 18:17:14
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
  logic [`DECODE_WIDTH - 1:0] valid;
  logic ready;  // 请求方可接收rsp响应(暂时无用恒为1)
  logic [`DECODE_WIDTH - 1:0][`PROC_VALEN:0] vaddr;
  logic [`DECODE_WIDTH - 1:0][25:0] operand;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] psrc0, psrc1, pdest;
  GeneralCtrlSignalSt [`DECODE_WIDTH - 1:0] general_ctrl_signal;
} ScheduleReqSt;

typedef struct packed {
  logic valid;  // rsp信息有效(暂时无用恒为1)
  logic ready;  // 接收req请求
} ScheduleRspSt;

typedef struct packed {
  logic [`PROC_VALEN:0] vaddr;
  logic [25:0] operand;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  logic [$clog2(`PHY_REG_NUM) - 1:0] psrc0, psrc1, pdest;
  IntegerCtrlSignalSt int_ctrl_signal;
} IntegerDispatchQueueEntrySt;

typedef struct packed {
  logic [`PROC_VALEN:0] vaddr;
  logic [25:0] operand;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  logic [$clog2(`PHY_REG_NUM) - 1:0] psrc0, psrc1, pdest;
  MemoryCtrlSignalSt memory_ctrl_signal;
} MemoryDispatchQueueEntrySt;

typedef struct packed {
  logic [`PROC_VALEN:0] vaddr;
  logic [25:0] operand;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  logic [$clog2(`PHY_REG_NUM) - 1:0] psrc0, psrc1, pdest;
  ALU_CtrlSignalSt alu_ctrl_signal;
} ALU_IssueQueueEntrySt;

typedef struct packed {
  logic [`PROC_VALEN:0] vaddr;
  logic [25:0] operand;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  logic [$clog2(`PHY_REG_NUM) - 1:0] psrc0, psrc1, pdst;
  ALU_CtrlSignalSt alu_ctrl_signal;
} MDU_IssueQueueEntrySt;

typedef struct packed {
  logic [`PROC_VALEN:0] vaddr;
  logic [25:0] operand;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  logic [$clog2(`PHY_REG_NUM) - 1:0] psrc0, psrc1, pdst;
  BranchCtrlSignalSt branch_ctrl_signal;
  PrivCtrlSignalSt priv_ctrl_signal;
} MISC_IssueQueueEntrySt;

typedef struct packed {
  logic [`PROC_VALEN:0] vaddr;
  logic [25:0] operand;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  logic [$clog2(`PHY_REG_NUM) - 1:0] psrc0, pdst;
  LoadCtrlSignalSt load_ctrl_signal;
} LoadIssueQueueEntrySt;

typedef struct packed {
  logic [`PROC_VALEN:0] vaddr;
  logic [25:0] operand;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  logic [$clog2(`PHY_REG_NUM) - 1:0] psrc0, pdst;
  StoreCtrlSignalSt store_ctrl_signal;
} StoreIssueQueueEntrySt;



`endif // __SCHEDULER_SVH__
