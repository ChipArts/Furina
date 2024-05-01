// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : MultiReadRAM.sv
// Create  : 2024-01-24 10:42:13
// Revise  : 2024-01-24 10:42:13
// Description :
//   多读一写RAM
//   ref: https://tomverbeure.github.io/2019/08/03/Multiport-Memories.html
// Parameter   :
//   CLOCKING_MODE:
//     - "common_clock": 通用时钟，使用 clk_W 为读写口提供统一时钟
//     - “independent_clock”: 独立时钟，带有 clk_w 为写口提供时钟， clk_r[i]分别为每一个读口提供时钟
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
// 24-01-24 |            |     0.1     |    Original Version
// ==============================================================================


module MultiReadRAM #(
parameter
  int unsigned DATA_DEPTH = 128,
  int unsigned DATA_WIDTH = 64,
  int unsigned RPORTS_NUM = 6,
  int unsigned BYTE_WRITE_WIDTH = 64,
               CLOCKING_MODE = "common_clock",
               WRITE_MODE = "write_first",
localparam
  int unsigned ADDR_WIDTH = $clog2(DATA_DEPTH),
  int unsigned BYTES_NUM  = DATA_WIDTH / BYTE_WRITE_WIDTH
)(
  input clk_w,
  input [RPORTS_NUM - 1:0] clk_r,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input en_w_i,
  input [RPORTS_NUM - 1:0]en_r_i,
  input [BYTES_NUM - 1:0] we_i,
  input [ADDR_WIDTH - 1:0] waddr_i,
  input [RPORTS_NUM - 1:0][ADDR_WIDTH - 1:0] raddr_i,
  input [DATA_WIDTH - 1:0] data_i,
  output [RPORTS_NUM - 1:0][DATA_WIDTH - 1:0] data_o
);


  generate
    for (genvar i = 0; i < RPORTS_NUM; i++) begin
      SimpleDualPortRAM #(
        .DATA_DEPTH(DATA_DEPTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BYTE_WRITE_WIDTH(BYTE_WRITE_WIDTH),
        .WRITE_MODE      (WRITE_MODE),
        .CLOCKING_MODE   (CLOCKING_MODE)
      ) inst_SimpleDualPortRAM (
        .clk_a    (clk_w),
        .en_a_i   (en_w_i),
        .we_a_i   (we_i),
        .addr_a_i (waddr_i),
        .data_a_i (data_i),
        .clk_b    (clk_r[i]),
        .rstb_n   (a_rst_n),
        .en_b_i   (en_r_i[i]),
        .addr_b_i (raddr_i[i]),
        .data_b_o (data_o[i])
      );
    end
  endgenerate


endmodule : MultiReadRAM
