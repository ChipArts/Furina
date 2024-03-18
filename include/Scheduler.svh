// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Scheduler.svh
// Create  : 2024-03-12 23:17:37
// Revise  : 2024-03-18 23:27:58
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
  logic [`DECODE_WIDTH - 1:0][`PROC_VALEN:0] vaddr;
  logic [`DECODE_WIDTH - 1:0][31:0] imm;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] psrc0, psrc1, pdest;
  OptionCodeSt [`DECODE_WIDTH - 1:0] option_code;
  logic [`DECODE_WIDTH - 1:0] src0_valid, src1_valid, dest_valid;
} ScheduleReqSt;

typedef struct packed {
  logic ready;  // 接收req请求
} ScheduleRspSt;

typedef struct packed {
  logic [$clog2(`PHY_REG_NUM) - 1:0] psrc0, psrc1, pdest;
  logic psrc0_valid, psrc1_valid, pdest_valid;
  logic psrc0_ready, psrc1_ready;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  logic position_bit;
  logic issued;
  logic valid;
  logic [31:0] imm;
  OptionCodeSt option_code;
} RS_EntrySt;

typedef struct packed {
 logic [31:0] imm;
 logic pdest_valid;
 logic [$clog2(`PHY_REG_NUM) - 1:0] psrc0;
 logic [$clog2(`PHY_REG_NUM) - 1:0] psrc1;
 logic [$clog2(`PHY_REG_NUM) - 1:0] pdest;
} IssueBaseInfoSt;

typedef struct packed {
  logic valid;
  IssueBaseInfoSt base_info;
  MiscOptionCodeSt option_code;
} MiscIssueInfoSt;

typedef struct packed {
  logic valid;
  IssueBaseInfoSt base_info;
  AluOptionCodeSt option_code;
} AluIssueInfoSt;

typedef struct packed {
  logic valid;
  IssueBaseInfoSt base_info;
  MemoryOptionCodeSt option_code;
} MemoryIssueInfoSt;



`endif // __SCHEDULER_SVH__
