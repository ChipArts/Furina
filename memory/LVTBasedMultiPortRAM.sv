// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : LVTBasedMultiPortRAM.sv
// Create  : 2024-02-01 11:00:24
// Revise  : 2024-02-01 11:01:33
// Description :
//   基于LVT的多端口RAM
// Parameter   :
//   CLOCKING_MODE:
//     - "common_clock": 通用时钟，使用clk_w[i]为读写口提供统一时钟
//     - “independent_clock”: 独立时钟，带有clk_w[i]为每一个写口提供时钟， clk_r[i]分别为每一个读口提供时钟
//   WRITE_MODE: 处理读写冲突
//     - "no_change": 数据无变化
//     - "read_first": 读优先
//     - "write_first": 写优先
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

module LVTBasedMultiPortRAM #(
parameter
  DATA_DEPTH = 128,
  DATA_WIDTH = 64,
  RPORTS_NUM = 6,
  WPORTS_NUM = 6,
  BYTE_WRITE_WIDTH = 64,
  CLOCKING_MODE = "common_clock",
  WRITE_MODE = "write_first",
localparam
  ADDR_WIDTH = $clog2(DATA_DEPTH),
  BYTES_NUM  = DATA_WIDTH / BYTE_WRITE_WIDTH
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
    assert(WPORTS_NUM > 0) else $error("LVTBasedMultiPortRAM: WPORTS_NUM <= 0 !!!");
    assert(RPORTS_NUM > 0) else $error("LVTBasedMultiPortRAM: RPORTS_NUM <= 0 !!!");
  end
`endif



endmodule : LVTBasedMultiPortRAM
