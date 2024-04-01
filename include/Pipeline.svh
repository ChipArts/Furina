// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Pipeline.svh
// Create  : 2024-03-13 22:53:51
// Revise  : 2024-04-01 15:47:53
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
  logic [31:0] instr;
  PreOptionCodeSt pre_oc;
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
  SubEcodeType sub_ecode;
  logic [`PROC_VALEN - 1:0] error_vaddr;
} CmtBaseSt;

typedef struct packed {
  CmtBaseSt base;
} AluCmtSt;

typedef struct packed {
  CmtBaseSt base;
} MduCmtSt;

typedef struct packed {
  CmtBaseSt base;
  logic priv_inst;
  logic br_inst;
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
  logic [4:0] invtlb_op;
  logic tlbsrch_found;
  logic [`TLB_ENTRY_NUM - 1:0] tlbsrch_idx;

  logic [31:0] tlbrd_ehi;
  logic [31:0] tlbrd_elo0;
  logic [31:0] tlbrd_elo1;
  logic [31:0] tlbrd_idx;
  logic [ 9:0] tlbrd_asid;
  // tlb or cacop
  logic [`PROC_VALEN - 1:0] vaddr;
} MiscCmtSt;

typedef struct packed {
  CmtBaseSt base;
} MemCmtSt;


`endif