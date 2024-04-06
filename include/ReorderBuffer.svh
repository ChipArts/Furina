// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : ReorderBuffer.svh
// Create  : 2024-03-13 21:02:26
// Revise  : 2024-04-02 16:14:53
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

`ifndef _REORDER_BUFFER_SVH_
`define _REORDER_BUFFER_SVH_

`include "config.svh"
`include "Decoder.svh"

`ifdef DEBUG
  typedef struct packed {
    logic complete;
    logic [`PROC_VALEN - 1:0] pc;
    InstType instr_type;
    logic [4:0] arch_reg;
    logic [$clog2(`PHY_REG_NUM) - 1:0] phy_reg;
    logic [$clog2(`PHY_REG_NUM) - 1:0] old_phy_reg;
    // 分支预测失败处理
    logic redirect;
    logic [`PROC_VALEN - 1:0] br_target;
    // 异常/例外处理
    logic exception;
    ExcCodeType ecode;
    SubEcodeType sub_ecode;
    logic [`PROC_VALEN - 1:0] error_vaddr;
    // DEBUG
    logic is_tibfill;
    logic [$clog2(`TLB_ENTRY_NUM) - 1:0] tlbfill_idx;
    logic csr_rstat;
    logic csr_rdata;
    logic is_cnt_instr;
    logic [63:0] timer_64;
    logic [31:0] instr;
    logic [31:0] rf_wdata;
    logic eret;
    logic store_valid;
    logic load_valid;
    logic [31:0] store_data;
    logic [31:0] mem_paddr;
    logic [31:0] mem_vaddr;
  } RobEntrySt;
`else 
  typedef struct packed {
    logic complete;
    logic [`PROC_VALEN - 1:0] pc;
    InstType instr_type;
    logic [4:0] arch_reg;
    logic phy_reg_valid;
    logic [$clog2(`PHY_REG_NUM) - 1:0] phy_reg;
    logic [$clog2(`PHY_REG_NUM) - 1:0] old_phy_reg;
    // 分支预测失败处理
    logic redirect;
    logic [`PROC_VALEN - 1:0] br_target;
    // 异常/例外处理
    logic exception;
    ExcCodeType ecode;
    SubEcodeType sub_ecode;
    logic [`PROC_VALEN - 1:0] error_vaddr;
  } RobEntrySt;
`endif

typedef struct packed {
  logic [`DECODE_WIDTH - 1:0] valid;
  logic [`DECODE_WIDTH - 1:0][`PROC_VALEN - 1:0] pc;
  InstType [`DECODE_WIDTH - 1:0]instr_type;
  logic [`DECODE_WIDTH - 1:0][4:0] arch_reg;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] phy_reg;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] old_phy_reg;
} RobAllocReqSt;

typedef struct packed {
  logic ready;
  logic [`DECODE_WIDTH - 1:0] position_bit;
  logic [`DECODE_WIDTH - 1:0][$clog2(`ROB_DEPTH) - 1:0] rob_idx;
} RobAllocRspSt;


`ifdef DEBUG
typedef struct packed {
  logic valid;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  logic redirect;
  logic [`PROC_VALEN - 1:0] br_target;
  logic exception;
  ExcCodeType ecode;
  SubEcodeType sub_ecode;
  logic [`PROC_VALEN - 1:0] error_vaddr;

  // debug
  logic is_tibfill;
  logic [$clog2(`TLB_ENTRY_NUM) - 1:0] tlbfill_idx;
  logic csr_rstat;
  logic csr_rdata;
  logic is_cnt_instr;
  logic [63:0] timer_64;
  logic [31:0] instr;
  logic [31:0] rf_wdata;
  logic eret;
  logic store_valid;
  logic load_valid;
  logic [31:0] store_data;
  logic [31:0] mem_paddr;
  logic [31:0] mem_vaddr;
} RobCmtReqSt;
`else
typedef struct packed {
  logic valid;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  logic redirect;
  logic [`PROC_VALEN - 1:0] br_target;
  logic exception;
  ExcCodeType ecode;
  SubEcodeType sub_ecode;
  logic [`PROC_VALEN - 1:0] error_vaddr;
} RobCmtReqSt;
`endif


typedef struct packed {
  logic ready;
} RobCmtRspSt;

typedef struct packed {
  logic [`RETIRE_WIDTH - 1:0] valid;
  RobEntrySt [`RETIRE_WIDTH - 1:0] rob_entry;
} RobRetireSt;


`endif  // _REORDER_BUFFER_SVH_
