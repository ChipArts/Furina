// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : common.svh
// Create  : 2024-01-13 20:48:48
// Revise  : 2024-01-13 20:48:48
// Description :
//   包含一些通用的全局定义
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
  * RST_N: 同步释放复位信号名称
  * tip: 注意这个宏会额外占用RST_N_r1, RST_N_r2两个名称，配合DIST_DRIVE_RESET宏定义使用
  */
`define RESET_LOGIC(CLK, A_RST_N, RST_N) \
  logic RST_N``_r1, RST_N``_r2; \
  logic RST_N; \
`ifdef DIST_DRIVE_RESET \
  always @(posedge CLK or negedge A_RST_N) begin \
    if (!A_RST_N) begin \
      RST_N``_r1 <= 1'b0; \
      RST_N``_r2 <= 1'b0; \
    end \
    else begin \
      RST_N``_r1 <= 1'b1; \
      RST_N``_r2 <= RST_N``_r1; \
    end \
  end \
  assign RST_N = RST_N``_r2; \
`else \
  assign RST_N = A_RST_N; \
`endif


function logic[31:0] countones(logic[31:0] data);
  logic[31:0] count;
  count = 0;
  for (int i = 0; i < 32; i++) begin
    count += data[i];
  end
  return count;
  
endfunction : countones

`define COUNT_ONES(DATA_MT, RES_MT) \
always_comb begin \
  RES_MT = '0; \
  for (int i = 0; i < $bits(DATA_MT); i++) begin \
    RES_MT += DATA_MT[i]; \
  end \
end




`endif // _COMMON_SVH_

