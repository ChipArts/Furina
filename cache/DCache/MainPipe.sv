// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : MainPipe.sv
// Create  : 2024-03-08 17:19:38
// Revise  : 2024-03-08 19:26:48
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

`include "config.svh"
`include "common.svh"
`include "Cache.svh"

module MainPipe (
  input clk,    // Clock
  input rst_n,  // Asynchronous reset active low
  input MainPipeStage0InputSt stage0_input_st_i,
  input MainPipeStage1InputSt stage1_input_st_i,
  input MainPipeStage2InputSt stage2_input_st_i,
  input MainPipeStage3InputSt stage3_input_st_i,
  output MainPipeStage0OutputSt stage0_output_st_o,
  output MainPipeStage1OutputSt stage1_output_st_o,
  output MainPipeStage2OutputSt stage2_output_st_o,
  output MainPipeStage3OutputSt stage3_output_st_o
);

  /* Stage 0 */
  // 仲裁传入的 Main Pipeline 请求选出优先级最高者
  // 发出 tag, meta 读请求
  // Main Pipeline 的争用存在以下优先级:
  //   1. replace_req
  //   2. store_req
  //   3. atomic_req暂时不实现
  always_comb begin
    stage0_output_st_o.
  end




endmodule : MainPipe
