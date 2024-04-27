// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : BranchPredictionUnit.svh
// Create  : 2024-02-12 18:06:30
// Revise  : 2024-03-13 17:57:36
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

`ifndef _BRANCH_PREDICTION_UNIT_SVH_
`define _BRANCH_PREDICTION_UNIT_SVH_

`include "config.svh"

`define STRONGLY_TAKEN 2'b11
`define WEAKLY_TAKEN 2'b10
`define WEAKLY_NOT_TAKEN 2'b01
`define STRONGLY_NOT_TAKEN 2'b00

`define STRONGLY_GLOBAL 2'b11
`define WEAKLY_GLOBAL 2'b10
`define WEAKLY_LOCAL 2'b01
`define STRONGLY_LOCAL 2'b00

// scale
`define BTB_ADDR_WIDTH 10
`define LPHT_ADDR_WIDTH 10
`define RAS_STACK_DEPTH 8
`define BHT_ADDR_WIDTH 5
`define BHT_DATA_WIDTH 3

// Br_type
`define PC_RELATIVE 2'b00
`define ABSOLUTE 2'b01
`define CALL 2'b10
`define RETURN 2'b11

typedef struct packed {
  logic next;  // 下一个pc
  logic redirect;  // 重定向请求
  logic [`PROC_VALEN - 1:0] target;

  /* for bpu updata */
  logic [31:0] pc;
  logic taken;
  // for btb
  logic btb_update;
  logic [1:0] br_type;

  // for lpht
  logic lpht_update;
  logic [1:0] lphr;

  // for ras
  logic [1:0] ras_redirect;
  logic [$clog2(`RAS_STACK_DEPTH) - 1:0] ras_ptr;
} BpuReqSt;

typedef struct packed {
  logic taken;
  logic [1:0] lphr;
  logic [1:0] br_type;
  logic [$clog2(`FETCH_WIDTH) - 1:0] br_idx;  // 标记那条指令被预测
  logic [$clog2(`RAS_STACK_DEPTH) - 1:0] ras_ptr;
} BrInfoSt;

typedef struct packed {
  logic [31:0] pc;
  logic [31:0] npc;  // 最后一条有效指令的下一个pc
  logic [`FETCH_WIDTH - 1:0] valid;  // 表明pc~pc+7中哪几个是有效的

  // 分支预测的相关信息
  BRInfoSt br_info;
} BpuRspSt;

`endif  // _BRANCH_PREDICTION_UNIT_SVH_
