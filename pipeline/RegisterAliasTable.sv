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
//   ...
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// 24-01-13 |            |     0.1     |    Original Version
// ==============================================================================

`include "common.svh"

module RegisterAliasTable #(
parameter
  RENAME_WIDTH = 6,
  PHYS_REG_NUM = 192,
  ARCH_REG_NUM = 32,
  CHECKPOINT_NUM = 4
)(
  input clk,      // Clock
  input a_rst_n,  // Asynchronous reset active low

  input [RENAME_WIDTH - 1:0] restore_i,    // 映射状态恢复
  input [RENAME_WIDTH - 1:0] allocaion_i,  // 状态保存
  input [RENAME_WIDTH - 1:0] free_i,  // 释放映射状态（指令顺利提交）

  // 输入逻辑寄存器编号
  input [RENAME_WIDTH - 1:0] valid_i,  // 标志指令有效
  input [RENAME_WIDTH - 1:0][$clog2(ARCH_REG_NUM) - 1:0] src0_i,  // inst: Dest = Src0 op Src1
  input [RENAME_WIDTH - 1:0][$clog2(ARCH_REG_NUM) - 1:0] src1_i,
  input [RENAME_WIDTH - 1:0][$clog2(ARCH_REG_NUM) - 1:0] dest_i,
  input [RENAME_WIDTH - 1:0][$clog2(ARCH_REG_NUM) - 1:0] preg_i,  // 从FreeList分配的空闲物理寄存器
  // 输出逻辑寄存器对应的物理寄存器编号
  output logic [RENAME_WIDTH - 1:0][$clog2(PHYS_REG_NUM) - 1:0] psrc0_o,
  output logic [RENAME_WIDTH - 1:0][$clog2(PHYS_REG_NUM) - 1:0] psrc1_o,
  output logic [RENAME_WIDTH - 1:0][$clog2(PHYS_REG_NUM) - 1:0] ppdst_o  // pre phy dest reg
);

  `RESET_LOGIC(clk, a_rst_n, s_rst_n);

  // Main Bit Cell
  logic [ARCH_REG_NUM - 1:0][$clog2(PHYS_REG_NUM) - 1:0] register_alias_table;  // reg
  logic [RENAME_WIDTH - 1:0][ARCH_REG_NUM - 1:0][$clog2(PHYS_REG_NUM) - 1:0] f_register_alias_table;
  logic [RENAME_WIDTH - 1:0][$clog2(PHYS_REG_NUM) - 1:0] psrc0;
  logic [RENAME_WIDTH - 1:0][$clog2(PHYS_REG_NUM) - 1:0] psrc1;
  logic [RENAME_WIDTH - 1:0][$clog2(PHYS_REG_NUM) - 1:0] ppdst;
  logic [RENAME_WIDTH - 1:0] wen;
  always_comb begin
    // 单独计算每一条指令rename后的RAT状态，为checkpoint做准备
    for (int i = 0; i < RENAME_WIDTH; i++) begin
      if (i > 0) begin
        f_register_alias_table[i] = f_register_alias_table[i - 1];
      end else begin
        f_register_alias_table[i] = register_alias_table;
      end
      f_register_alias_table[i][dest_i[i]] = preg_i[i];
    end

    // 处理RAW相关性
    for (int i = 0; i < RENAME_WIDTH; i++) begin
      psrc0[i] = register_alias_table[src0_i[i]];
      psrc1[i] = register_alias_table[src1_i[i]];
      for (int j = 0; j < i; j++) begin
        psrc0[i] = (src0_i[i] == dest_i[j]) ? preg_i[j] : psrc0[i];
        psrc1[i] = (src1_i[i] == dest_i[j]) ? preg_i[j] : psrc1[i];
      end
    end

    // 处理WAW相关性
    // RAT写入
    wen = valid_i;
    for (int i = 0; i < RENAME_WIDTH; i++) begin
      for (int j = i + 1; j < RENAME_WIDTH; j++) begin
        wen[i] = wen[i] & (dest_i[i] == dest_i[j]);
      end
    end
    // ROB写入
    for (int i = 0; i < RENAME_WIDTH; i++) begin
      ppdst[i] = register_alias_table[dest_i[i]];
      for (int j = 0; j < i; j++) begin
        ppdst[i] = (dest_i[i] == dest_i[j]) ? preg_i[j] : ppdst[i];
      end
    end
  end

  always_ff @(posedge clk or negedge s_rst_n) begin
    if(~s_rst_n) begin
      register_alias_table <= '0;
    end else begin
      for (int i = 0; i < RENAME_WIDTH; i++) begin
        psrc0_o[i] <= psrc0[i];
        psrc1_o[i] <= psrc1[i];
        ppdst_o[i] <= ppdst[i];
      end
      foreach (wen[i]) begin
        if (wen[i]) begin
          register_alias_table[dest_i[i]] <= preg_i;
        end
      end
    end
  end

  // Checkpoint Bit Cell
  // TODO: checkpoint

  

endmodule : RegisterAliasTable
