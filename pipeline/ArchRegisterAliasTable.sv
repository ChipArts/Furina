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
  input clk,      // Clock
  input a_rst_n,  // Asynchronous reset active low

  output logic [31:0][$clog2(PHY_REG_NUM) - 1:0] arch_rat_o,

  // 输入逻辑寄存器编号
  input logic [`DECODE_WIDTH - 1:0] dest_valid_i, // 标志指令使用DEST寄存器
  input logic [`DECODE_WIDTH - 1:0][4:0] dest_i,
  input logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] preg_i

);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

  // Main Bit Cell
  logic [31:0][$clog2(PHY_REG_NUM) - 1:0] register_alias_table, register_alias_table_n;  // reg
  logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] psrc0;
  logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] psrc1;
  logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] ppdst;
  logic [`DECODE_WIDTH - 1:0] wen;
  always_comb begin
    // 处理WAW相关性
    // RAT写入
    wen = dest_valid_i;
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      for (int j = i + 1; j < `DECODE_WIDTH; j++) begin
        wen[i] = wen[i] & (dest_i[i] != dest_i[j]);
      end
    end

    register_alias_table_n = register_alias_table;
    foreach (wen[i]) begin
      if (wen[i]) begin
        register_alias_table[dest_i[i]] <= preg_i;
      end
    end

    arch_rat_o = register_alias_table_n;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      register_alias_table <= '0;
    end else begin
      register_alias_table <= register_alias_table_n;
    end
  end
  

endmodule : ArchRegisterAliasTable
