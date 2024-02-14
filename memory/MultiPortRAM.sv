// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : MultiPortRAM.sv
// Create  : 2024-01-31 18:29:26
// Revise  : 2024-01-31 18:29:26
// Description :
//   多端口RAM
//   NOTE: 不处理WAW冲突，出现冲突时会产生不确定状态
// Parameter   :
//   CLOCKING_MODE:
//     - "common_clock": 通用时钟，使用clk_w[i]为读写口提供统一时钟
//     - “independent_clock”: 独立时钟，带有clk_w[i]为每一个写口提供时钟， clk_r[i]分别为每一个读口提供时钟
//   WRITE_MODE: 处理读写冲突
//     - "no_change": 数据无变化
//     - "read_first": 读优先
//     - "write_first": 写优先
//   IMPL_TYPE: 选择多端口RAM的实现方案
//     - TODO
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// 24-01-31 |            |     0.1     |    Original Version
// ==============================================================================

`include "common.svh"

module MultiPortRAM #(
parameter
  int unsigned DATA_DEPTH = 128,
  int unsigned DATA_WIDTH = 64,
  int unsigned RPORTS_NUM = 6,
  int unsigned WPORTS_NUM = 6,
  int unsigned BYTE_WRITE_WIDTH = 64,
  string       CLOCKING_MODE = "common_clock",
  string       WRITE_MODE = "write_first",
  string       IMPL_TYPE = "auto",
  string       MEMORY_PRIMITIVE = "auto",
localparam
  int unsigned ADDR_WIDTH = $clog2(DATA_DEPTH),
  int unsigned BYTES_NUM  = DATA_WIDTH / BYTE_WRITE_WIDTH
)(
  input logic [WPORTS_NUM - 1:0] clk_w,    // Clock
  input logic [RPORTS_NUM - 1:0] clk_r,
  input logic a_rst_n,  // Asynchronous reset active low
  input logic [WPORTS_NUM - 1:0] en_w_i,
  input logic [RPORTS_NUM - 1:0] en_r_i,
  input logic [WPORTS_NUM - 1:0][BYTES_NUM - 1:0] we_i,
  input logic [RPORTS_NUM - 1:0][ADDR_WIDTH - 1:0] raddr_i,
  input logic [WPORTS_NUM - 1:0][ADDR_WIDTH - 1:0] waddr_i,
  input logic [WPORTS_NUM - 1:0][DATA_WIDTH - 1:0] data_i,
  output logic [RPORTS_NUM - 1:0][DATA_WIDTH - 1:0] data_o
);

`ifdef DEBUG
  initial begin
    assert(WPORTS_NUM > 0) else $error("MultiPortRAM: WPORTS_NUM <= 0 !!!");
    assert(RPORTS_NUM > 0) else $error("MultiPortRAM: RPORTS_NUM <= 0 !!!");
  end
`endif

  // TODO: MultiPortRAM
endmodule : MultiPortRAM


