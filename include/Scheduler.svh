// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Scheduler.svh
// Create  : 2024-03-12 23:17:37
// Revise  : 2024-03-21 23:38:19
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
  logic valid;
  logic [`PROC_VALEN - 1:0] pc;
  logic [`PROC_VALEN - 1:0] npc;
  logic [31:0] imm;
  logic src0_valid;
  logic src1_valid;
  logic dest_valid;
  logic [$clog2(`PHY_REG_NUM) - 1:0]src0;
  logic [$clog2(`PHY_REG_NUM) - 1:0]src1;
  logic [$clog2(`PHY_REG_NUM) - 1:0]dest;
  OptionCodeSt oc;
  logic position_bit;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
} DqEntrySt;

typedef struct packed {
  logic [$clog2(`PHY_REG_NUM) - 1:0] psrc0, psrc1, pdest;
  logic psrc0_valid, psrc1_valid, pdest_valid;
  logic psrc0_ready, psrc1_ready;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  logic position_bit;
  logic issued;
  logic valid;
  logic [31:0] imm;
  logic [`PROC_VALEN - 1:0] pc;
  logic [`PROC_VALEN - 1:0] npc;
} RsBaseSt;

function RsBaseSt dq2rs(DqEntrySt dq);
  RsBaseSt rs;
  rs.psrc0 = dq.psrc0;
  rs.psrc1 = dq.psrc1;
  rs.pdest = dq.pdest;
  rs.psrc0_valid = dq.psrc0_valid;
  rs.psrc1_valid = dq.psrc1_valid;
  rs.pdest_valid = dq.pdest_valid;
  rs.rob_idx = dq.rob_idx;
  rs.position_bit = dq.position_bit;
  rs.issued = dq.issued;
  rs.valid = dq.valid;
  rs.imm = dq.imm;
  rs.pc = dq.pc;
  rs.npc = dq.npc;
  return rs;
endfunction : dq2rs

typedef struct packed {
  logic [31:0] imm;
  logic [`PROC_VALEN - 1:0] pc;
  logic [`PROC_VALEN - 1:0] npc;
  logic [$clog2(`PHY_REG_NUM) - 1:0] psrc0;
  logic [$clog2(`PHY_REG_NUM) - 1:0] psrc1;
  logic [$clog2(`PHY_REG_NUM) - 1:0] pdest;
} IssueBaseSt;

typedef struct packed {
  logic valid;
  IssueBaseSt base_info;
  MiscOpCodeSt misc_oc;
} MiscIssueSt;

typedef struct packed {
  logic valid;
  IssueBaseSt base_info;
  AluOpCodeSt alu_oc;
} AluIssueSt;

typedef struct packed {
  logic valid;
  IssueBaseSt base_info;
  MduOpCodeSt mdu_oc;
} MduIssueSt;

typedef struct packed {
  logic valid;
  IssueBaseInfoSt base_info;
  MemOpCodeSt mem_oc;
} MemIssueSt;



`endif // __SCHEDULER_SVH__
