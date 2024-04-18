// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : RegisterAliasTable.sv
// Create  : 2024-01-14 21:47:13
// Revise  : 2024-01-14 21:47:13
// Description :
//   重命名映射表(RAT)
// Parameter   :
//   ...
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// 24-01-13 |            |     0.1     |    Original Version
// ==============================================================================

`include "config.svh"
`include "common.svh"

module ArchRegisterAliasTable #(
parameter
  int unsigned PHY_REG_NUM = 64
)(
  input logic clk,      // Clock
  input logic rst_n,    // Asynchronous reset active low

  input logic [`COMMIT_WIDTH - 1:0] free_i,                                 // 释放映射状态（指令顺利提交）
  input logic [`COMMIT_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] old_preg_i,  // 释放的物理寄存器编号

  // 输入逻辑寄存器编号
  input logic [`COMMIT_WIDTH - 1:0] dest_valid_i, // 标志指令使用DEST寄存器
  input logic [`COMMIT_WIDTH - 1:0][4:0] dest_i,
  input logic [`COMMIT_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] preg_i,  // 从FreeList分配的空闲物理寄存器(已按照有效项分配)
  output logic [PHY_REG_NUM - 1:0] arch_valid_o
);

  typedef struct packed {
    logic [PHY_REG_NUM - 1:0] valid;           // 有效的映射
  } RatEntrySt;

  // Main Bit Cell
  RatEntrySt rat_q, rat_n;  // reg
  logic [`COMMIT_WIDTH - 1:0] wen;
  always_comb begin
    /* dst寄存器分配（配合freelist） */
    // RAT写入
    wen = dest_valid_i;
    for (int i = 0; i < `COMMIT_WIDTH; i++) begin
      // 处理WAW相关性
      for (int j = i + 1; j < `COMMIT_WIDTH; j++) begin
        wen[i] = wen[i] & (dest_i[i] != dest_i[j]);
      end
    end

    rat_n = rat_q;
    for (int i = 0; i < `COMMIT_WIDTH; i++) begin
      if (wen[i]) begin
        rat_n.valid[preg_i[i]] = '1;
      end

      if (free_i[i]) begin
        rat_n.valid[old_preg_i[i]] = '0;
      end
    end

    arch_valid_o = rat_n.valid;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      rat_q.valid <= '0;
    end else begin
      rat_q <= rat_n;
    end
  end
  

endmodule : ArchRegisterAliasTable
