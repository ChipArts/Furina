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

module RegisterAliasTable #(
parameter
  int unsigned PHY_REG_NUM = 64
)(
  input clk,      // Clock
  input a_rst_n,  // Asynchronous reset active low

  input [`DECODE_WIDTH - 1:0] restore_i,    // 映射状态恢复
  input [`DECODE_WIDTH - 1:0] allocaion_i,  // 状态保存(暂不实现)
  input [`DECODE_WIDTH - 1:0] free_i,  // 释放映射状态（指令顺利提交）
  input logic [31:0][$clog2(PHY_REG_NUM) - 1:0] arch_rat,

  // 输入逻辑寄存器编号
  input [`DECODE_WIDTH - 1:0] valid_i,  // 标志指令使用DEST寄存器
  input [`DECODE_WIDTH - 1:0][4:0] src0_i,  // inst: Dest = Src0 op Src1
  input [`DECODE_WIDTH - 1:0][4:0] src1_i,
  input [`DECODE_WIDTH - 1:0][4:0] dest_i,
  input [`DECODE_WIDTH - 1:0][4:0] preg_i,  // 从FreeList分配的空闲物理寄存器
  // 输出逻辑寄存器对应的物理寄存器编号
  output logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] psrc0_o,
  output logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] psrc1_o,
  output logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] ppdst_o  // pre phy dest reg
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

  // Main Bit Cell
  logic [31:0][$clog2(PHY_REG_NUM) - 1:0] register_alias_table;  // reg
  // logic [`DECODE_WIDTH - 1:0][31:0][$clog2(PHY_REG_NUM) - 1:0] f_register_alias_table;
  logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] psrc0;
  logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] psrc1;
  logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] ppdst;
  logic [`DECODE_WIDTH - 1:0] wen;
  always_comb begin
    // 单独计算每一条指令rename后的RAT状态，为checkpoint做准备(暂时无用)
    // for (int i = 0; i < `DECODE_WIDTH; i++) begin
    //   if (i > 0) begin
    //     f_register_alias_table[i] = f_register_alias_table[i - 1];
    //   end else begin
    //     f_register_alias_table[i] = register_alias_table;
    //   end
    //   f_register_alias_table[i][dest_i[i]] = preg_i[i];
    // end

    // 处理RAW相关性
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
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
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      for (int j = i + 1; j < `DECODE_WIDTH; j++) begin
        wen[i] = wen[i] & (dest_i[i] == dest_i[j]);
      end
    end
    // ROB写入
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      ppdst[i] = register_alias_table[dest_i[i]];
      for (int j = 0; j < i; j++) begin
        ppdst[i] = (dest_i[i] == dest_i[j]) ? preg_i[j] : ppdst[i];
      end
    end

    // output
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      psrc0_o[i] = psrc0[i];
      psrc1_o[i] = psrc1[i];
      ppdst_o[i] = ppdst[i];
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      register_alias_table <= '0;
    end else begin
      if (restore_i) begin
        register_alias_table <= arch_rat;
      end else begin
        foreach (wen[i]) begin
          if (wen[i]) begin
            register_alias_table[dest_i[i]] <= preg_i;
          end
        end
      end
    end
  end

  // TODO: try checkpoint

  

endmodule : RegisterAliasTable
