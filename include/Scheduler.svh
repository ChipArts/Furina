// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Scheduler.svh
// Create  : 2024-03-12 23:17:37
// Revise  : 2024-04-02 16:07:16
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
`include "ControlStatusRegister.svh"

typedef struct packed {
  logic [`DECODE_WIDTH - 1:0] valid;
  logic [`DECODE_WIDTH - 1:0][`PROC_VALEN - 1:0] pc;
  logic [`DECODE_WIDTH - 1:0][`PROC_VALEN - 1:0] npc;
  logic [`DECODE_WIDTH - 1:0][25:0] src;  // imm和reg的压缩信息
  logic [`DECODE_WIDTH - 1:0][4:0] arch_src0;
  logic [`DECODE_WIDTH - 1:0][4:0] arch_src1;
  logic [`DECODE_WIDTH - 1:0][4:0] arch_dest;
  OptionCodeSt [`DECODE_WIDTH - 1:0] option_code;
  ExcpSt [`DECODE_WIDTH - 1:0] excp;
} ScheduleReqSt;

typedef struct packed {
  logic ready;  // 接收req请求
} ScheduleRspSt;

typedef struct packed {
  logic valid;
  logic [`PROC_VALEN - 1:0] pc;
  logic [`PROC_VALEN - 1:0] npc;
  logic [25:0] src;
  logic src0_valid;
  logic src1_valid;
  logic dest_valid;
  logic [$clog2(`PHY_REG_NUM) - 1:0]src0;
  logic [$clog2(`PHY_REG_NUM) - 1:0]src1;
  logic [$clog2(`PHY_REG_NUM) - 1:0]dest;
  OptionCodeSt oc;
  logic position_bit;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  ExcpSt excp;
} DqEntrySt;

typedef struct packed {
  logic valid;
  logic issued;
  logic position_bit;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  logic psrc0_ready;
  logic psrc1_ready;
  logic [25:0] src;
  logic [$clog2(`PHY_REG_NUM) - 1:0] psrc0;
  logic [$clog2(`PHY_REG_NUM) - 1:0] psrc1;
  logic [$clog2(`PHY_REG_NUM) - 1:0] pdest;
  logic psrc0_valid;
  logic psrc1_valid;
  logic pdest_valid;
  logic [`PROC_VALEN - 1:0] pc;
  logic [`PROC_VALEN - 1:0] npc;
  ImmType imm_type;
  ExcpSt excp;
} RsBaseSt;

function RsBaseSt dq2rs(DqEntrySt dq);
  RsBaseSt rs;
  rs.valid = dq.valid;
  rs.issued = 0;
  rs.position_bit = dq.position_bit;
  rs.rob_idx = dq.rob_idx;
  rs.psrc0_ready = 0;
  rs.psrc1_ready = 0;
  rs.src = dq.src;
  rs.psrc0 = dq.src0;
  rs.psrc1 = dq.src1;
  rs.pdest = dq.dest;
  rs.psrc0_valid = dq.src0_valid;
  rs.psrc1_valid = dq.src1_valid;
  rs.pdest_valid = dq.dest_valid;
  rs.pc = dq.pc;
  rs.npc = dq.npc;
  rs.imm_type = dq.oc.imm_type;
  rs.excp = dq.excp;
  return rs;
endfunction : dq2rs

typedef struct packed {
  logic [`PROC_VALEN - 1:0] pc;
  logic [`PROC_VALEN - 1:0] npc;
  logic [25:0] src;
  logic psrc0_valid;
  logic psrc1_valid;
  logic pdest_valid;
  logic [$clog2(`PHY_REG_NUM) - 1:0] psrc0;
  logic [$clog2(`PHY_REG_NUM) - 1:0] psrc1;
  logic [$clog2(`PHY_REG_NUM) - 1:0] pdest;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  ImmType imm_type;
  ExcpSt excp;
} IssueBaseSt;

function IssueBaseSt rs2is(RsBaseSt rs);
  IssueBaseSt is;
  is.valid = rs.valid;
  is.pc = rs.pc;
  is.npc = rs.npc;
  is.src = rs.src;
  is.psrc0_valid = rs.psrc0_valid;
  is.psrc1_valid = rs.psrc1_valid;
  is.pdest_valid = rs.pdest_valid;
  is.psrc0 = rs.psrc0;
  is.psrc1 = rs.psrc1;
  is.pdest = rs.pdest;
  is.rob_idx = rs.rob_idx;
  is.imm_type = rs.imm_type;
  is.excp = rs.excp;
  return is;
endfunction : rs2is

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
  IssueBaseSt base_info;
  MemOpCodeSt mem_oc;
} MemIssueSt;

`endif // __SCHEDULER_SVH__
