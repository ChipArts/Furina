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
`include "ControlStatusRegister.svh"

`ifdef DEBUG
  typedef struct packed {
    // 基础信息
    logic complete;
    logic [`PROC_VALEN - 1:0] pc;
    InstType instr_type;
    logic [4:0] arch_reg;
    logic [$clog2(`PHY_REG_NUM) - 1:0] phy_reg;
    logic [$clog2(`PHY_REG_NUM) - 1:0] old_phy_reg;
    // 分支预测失败处理
    logic br_redirect;
    logic [`PROC_VALEN - 1:0] br_target;
    // 异常、例外处理
    ExcpSt excp;
    logic [`PROC_VALEN - 1:0] error_vaddr;
    // write back阶段的flush缓存
    logic ertn_flush;      // ERET返回（返回地址为csr_era）
    logic ibar_flush;      // IBAR指令
    logic priv_flush;      // 特权指令（csr_rd修改可撤回，不需要flush）
    logic icacop_flush;    // ICache操作
    logic idel_flush;      // IDLE指令
    // DEBUG
    logic is_tibfill;
    logic [$clog2(`TLB_ENTRY_NUM) - 1:0] tlbfill_idx;
    logic csr_rstat;
    logic csr_rdata;
    logic is_cnt_instr;
    logic [63:0] timer_64;
    logic [31:0] instr;
    logic rf_wen;
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
    logic [$clog2(`PHY_REG_NUM) - 1:0] phy_reg;
    logic [$clog2(`PHY_REG_NUM) - 1:0] old_phy_reg;
    // 分支预测失败处理
    logic redirect;
    logic [`PROC_VALEN - 1:0] br_target;
    // 异常/例外处理
    ExcpSt excp;
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
  ExcpSt [`DECODE_WIDTH - 1:0] excp;
  // diff DEBUG
  logic [`DECODE_WIDTH - 1:0][31:0] instr;
} RobAllocReqSt;

typedef struct packed {
  logic ready;
  logic [`DECODE_WIDTH - 1:0] position_bit;
  logic [`DECODE_WIDTH - 1:0][$clog2(`ROB_DEPTH) - 1:0] rob_idx;
} RobAllocRspSt;


typedef struct packed {
  logic ready;
} RobWbRspSt;

typedef struct packed {
  logic [`COMMIT_WIDTH - 1:0] valid;
  RobEntrySt [`COMMIT_WIDTH - 1:0] rob_entry;
} RobCmtSt;


`endif  // _REORDER_BUFFER_SVH_
