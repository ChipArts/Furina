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
`include "Scheduler.svh"
`include "ControlStatusRegister.svh"

typedef struct packed {
  logic valid;
  logic [31:0] instr;
  PreOptionCodeSt pre_oc;
  logic [`PROC_VALEN - 1:0] pc;
  logic [`PROC_VALEN - 1:0] npc;
  ExcpSt excp;
} IbufDataSt;


/*==================================== EXE ====================================*/
typedef struct packed {
  logic valid;
  logic [31:0] imm;
  logic [31:0] src0, src1;
  logic pdest_valid;   // 标记是否需要写回
  logic [$clog2(`PHY_REG_NUM) - 1:0] pdest;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  ExcpSt excp;
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
  logic [4:0] code;
  logic llbit;  // 在读寄存器堆阶段获取
} MemExeSt;

/*==================================== WB ====================================*/
// commit --> cmt
typedef struct packed {
  logic valid;
  logic we;
  logic [31:0] wdata;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  logic [$clog2(`PHY_REG_NUM) - 1:0] pdest;
  ExcpSt excp;
} WbBaseSt;

typedef struct packed {
  WbBaseSt base;
} AluWbSt;

typedef struct packed {
  WbBaseSt base;
} MduWbSt;

typedef struct packed {
  WbBaseSt base;
  InstrType instr_type;
  MiscOpType misc_op;
  // csr
  logic csr_we;
  logic [13:0] csr_waddr;
  logic [31:0] csr_wdata;
  // branch
  logic br_taken;
  logic br_redirect;
  logic [`PROC_VALEN - 1:0] br_target;
  // tlb
  logic tlbfill_en;
  logic [$clog2(`TLB_ENTRY_NUM) - 1:0] tlbfill_idx;

  logic invtlb_en;
  logic [9:0] invtlb_asid;
  logic [4:0] invtlb_op;
  logic [`PROC_VALEN - 1:0] vaddr;

  logic tlbsrch_en;
  logic tlbsrch_found;
  logic [$clog2(`TLB_ENTRY_NUM) - 1:0] tlbsrch_idx;

  logic tlbrd_en;
  logic [31:0] tlbrd_ehi;
  logic [31:0] tlbrd_elo0;
  logic [31:0] tlbrd_elo1;
  logic [31:0] tlbrd_idx;
  logic [ 9:0] tlbrd_asid;

  logic tlbwr_en;

  // for priv misc
  logic ertn_en;
  logic idle_en;

  // diff
  logic cnt_instr_diff;
  logic crs_rstat_diff;
  logic [31:0] csr_rdata_diff;
  logic [63:0] timer_64_diff;
} MiscWbSt;

typedef struct packed {
  WbBaseSt base;
  logic [31:0] vaddr;
  MemOpType mem_op;
  logic micro;
  logic llbit;
  logic icacop;
  // diff
  logic [31:0] paddr;
  logic [31:0] store_data;
} MemWbSt;


function logic[31:0] imm_ext(logic[25:0] src, ImmType imm_type, logic[31:0] pc);
  logic [31:0] imm;
  case (imm_type)
    `IMM_UI5  : imm = {27'b0 ,src[14:10]};
    `IMM_UI12 : imm = {20'b0, src[21:10]};
    `IMM_SI12 : imm = {{20{src[21]}}, src[21:10]};
    `IMM_SI14 : imm = {{18{src[23]}}, src[23:10]};
    `IMM_SI16 : imm = {{16{src[25]}}, src[25:10]};
    `IMM_SI20 : imm = {{12{src[24]}}, src[24: 5]};
    `IMM_SI26 : imm = {{ 6{src[9]}} , src[9: 0], src[25:10]};
    `IMM_PC   : imm = pc + {{12{src[24]}}, src[24: 5]};
    default : imm = '0;
  endcase
endfunction : imm_ext

function ExeBaseSt is2exe(IssueBaseSt is, logic valid, logic[31:0] src1, logic[31:0] src0);
  ExeBaseSt exe;
  exe.valid = valid;
  exe.src0 = src0;
  exe.src1 = src1;
  exe.pdest_valid = is.pdest_valid;
  exe.pdest = is.pdest;
  exe.rob_idx = is.rob_idx;
  exe.imm = imm_ext(is.src, is.imm_type, is.pc);
  exe.excp = is.excp;
  return exe;
endfunction : is2exe


`endif // __PIPELINE_SVH__
