// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : common.svh
// Create  : 2024-01-13 20:48:48
// Revise  : 2024-01-13 20:48:48
// Description :
//   包含一些通用的宏
// Parameter   :
//   ...
//   ...
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// 24-01-13 |            |     0.1     |    Original Version
// ==============================================================================

`ifndef _COMMON_SVH_
`define _COMMON_SVH_

/**
  * 生成标准复位逻辑（异步复位，同步释放）
  * A_RST_N: 异步复位信号名称
  * S_RST_N: 同步复位信号名称
  * tip: 注意这个宏会额外占用S_RST_N_r1, S_RST_N_r2两个名称
  */
`define RESET_LOGIC(CLK, A_RST_N, S_RST_N) \
  logic S_RST_N``_r1, S_RST_N``_r2; \
  logic S_RST_N; \
  always @(posedge CLK or negedge A_RST_N) begin \
    if (!A_RST_N) begin \
      S_RST_N``_r1 <= 1'b0; \
      S_RST_N``_r2 <= 1'b0; \
    end \
    else begin \
      S_RST_N``_r1 <= 1'b1; \
      S_RST_N``_r2 <= S_RST_N``_r1; \
    end \
  end \
  assign S_RST_N = S_RST_N``_r2;

`endif

