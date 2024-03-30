// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Pipeline.svh
// Create  : 2024-03-13 22:53:51
// Revise  : 2024-03-29 17:48:33
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

`ifndef __PIPELINE_SVH__
`define __PIPELINE_SVH__

`include "config.svh"
`include "Decoder.svh"

typedef struct packed {
  logic valid;
  logic [31:0] instruction;
  logic [`PROC_VALEN - 1:0] pc;
  logic [`PROC_VALEN - 1:0] npc;
} IbufDataSt;

/*==================================== EXE ====================================*/
typedef struct packed {
  logic valid;
  logic [31:0] imm;
  logic [31:0] src0, src1;
  logic [$clog2(`PHY_REG_NUM) - 1:0] pdest;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
} ExeBaseSt;

typedef struct packed {
  ExeBaseSt base;
  AluOpCodeSt alu_oc;
} AluExeSt;

typedef struct packed {
  ExeBaseSt base;
  MduOpCodeSt mdu_oc;
} MduExeSt;

typedef struct packed {
  ExeBaseSt base;
  MiscOpCodeSt misc_oc;
  logic [`PROC_VALEN - 1:0] pc;
  logic [`PROC_VALEN - 1:0] npc;
} MiscExeSt;

typedef struct packed {
  ExeBaseSt base;
  MemOpCodeSt mem_oc;
} MemExeSt;

/*==================================== CMT ====================================*/
// commit --> cmt
typedef struct packed {
  logic valid;
  logic we;
  logic [31:0] wdata;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  logic [$clog2(`PHY_REG_NUM) - 1:0] pdest;
  logic exception;
  ExcCodeType ecode;
} CmtBaseSt;

typedef struct packed {
  CmtBaseSt base;
} AluCmtSt;

typedef struct packed {
  CmtBaseSt base;
} MduCmtSt;

typedef struct packed {
  CmtBaseSt base;
  PrivOpType priv_op;
  CacheOpType cache_op;
  // csr
  logic csr_we;
  logic [13:0] csr_waddr;
  logic [31:0] csr_wdata;
  // branch
  logic br_taken;
  logic br_redirect;
  logic [`PROC_VALEN - 1:0] br_target;
  // tlb
  logic [9:0] invtlb_asid;
  // tlb or cacop
  logic [`PROC_VALEN - 1:0] vaddr;
} MiscCmtSt;

typedef struct packed {
  CmtBaseSt base;
} MemCmtSt;


`endif