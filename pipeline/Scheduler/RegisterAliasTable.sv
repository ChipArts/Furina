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
  input logic clk,      // Clock
  input logic rst_n,    // Asynchronous reset active low

  input logic restore_i,                         // 映射状态恢复
  input logic [PHY_REG_NUM - 1:0] arch_valid_i,  // 映射状态恢复的valid
  // input [`DECODE_WIDTH - 1:0] allocaion_i,  // 状态保存（暂不实现checkpoint）
  // input logic [`DECODE_WIDTH - 1:0] free_i,                                 // 释放映射状态（指令顺利提交）
  // input logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] old_preg_i,  // 释放的物理寄存器编号
  input logic [`WB_WIDTH - 1:0] wb_i,           // 指令写回
  input logic [`WB_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] wb_pdest_i,  // 指令写回的目的寄存器

  // 输入逻辑寄存器编号
  input logic [`DECODE_WIDTH - 1:0] dest_valid_i, // 标志指令使用DEST寄存器
  input logic [`DECODE_WIDTH - 1:0][4:0] src0_i,  // inst: Dest = Src0 op Src1
  input logic [`DECODE_WIDTH - 1:0][4:0] src1_i,
  input logic [`DECODE_WIDTH - 1:0][4:0] dest_i,
  input logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] preg_i,  // 从FreeList分配的空闲物理寄存器(已按照有效项分配)
  // 输出逻辑寄存器对应的物理寄存器编号
  output logic [`DECODE_WIDTH - 1:0]                            psrc0_ready_o,
  output logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] psrc0_o,
  output logic [`DECODE_WIDTH - 1:0]                            psrc1_ready_o,
  output logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] psrc1_o,
  output logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] ppdst_o  // pre phy dest reg
);

  typedef struct packed {
    logic [PHY_REG_NUM - 1:0][4:0] arch_reg;   // 逻辑寄存器编号
    logic [PHY_REG_NUM - 1:0] valid;           // 有效的映射
    logic [PHY_REG_NUM - 1:0] ready;           // 被分配时标记为0，写回时标记为1
  } RatEntrySt;

  // Main Bit Cell
  RatEntrySt rat_q, rat_n;  // reg
  logic [`DECODE_WIDTH - 1:0] psrc0_ready;
  logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] psrc0;
  logic [`DECODE_WIDTH - 1:0] psrc1_ready;
  logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] psrc1;
  logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] ppdst;
  always_comb begin
    /* src寄存器重命名 */
    psrc0 = '0;
    psrc0_ready = '1;
    psrc1 = '0;
    psrc1_ready = '1;
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      // CAM 方式查找
      for (int j = 0; j < PHY_REG_NUM; j++) begin
        if (src0_i[i] == rat_q.arch_reg[j] && rat_q.valid[j]) begin
          psrc0[i] = j;
          psrc0_ready[i] = rat_q.ready[j];
        end
        
        if (src1_i[i] == rat_q.arch_reg[j] && rat_q.valid[j]) begin
          psrc1[i] = j;
          psrc1_ready[i] = rat_q.ready[j];
        end
      end
      // 处理RAW相关性（在本条指令之前有指令写入了rat）
      for (int j = 0; j < i; j++) begin
        psrc0_ready[i] = (src0_i[i] == dest_i[j]) ? '0 : psrc0_ready[i];
        psrc0[i] = (src0_i[i] == dest_i[j]) ? preg_i[j] : psrc0[i];
        psrc1_ready[i] = (src1_i[i] == dest_i[j]) ? '0 : psrc1_ready[i];
        psrc1[i] = (src1_i[i] == dest_i[j]) ? preg_i[j] : psrc1[i];
      end
    end

    /* RAT更新（配合freelist） */
    // CAM 方式查找旧的pdest映射
    ppdst = '0;
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      for (int j = 0; j < PHY_REG_NUM; j++) begin
        if (dest_i[i] == rat_q.arch_reg[j] && rat_q.valid[j]) begin
          ppdst[i] = j;
        end
      end
      // 处理WAW相关性
      for (int j = 0; j < i; j++) begin
        ppdst[i] = (dest_i[i] == dest_i[j]) ? preg_i[j] : ppdst[i];
      end
    end


    if (restore_i) begin
      rat_n.valid = arch_valid_i;
      rat_n.ready = '1;  // 此时ROB会被清空，显然所有的指令都已经写回
    end else begin
      rat_n = rat_q;
      for (int i = 0; i < `DECODE_WIDTH; i++) begin
        if (dest_valid_i[i]) begin
          rat_n.arch_reg[preg_i[i]] = dest_i[i];
          rat_n.valid[preg_i[i]] = '1;
          rat_n.ready[preg_i[i]] = '0;
          rat_n.valid[ppdst[i]] = '0;  // 释放之前的映射
        end
      end

      for (int i = 0; i < `WB_WIDTH; i++) begin
        if (wb_i[i]) begin
          rat_n.ready[wb_pdest_i[i]] = '1;
        end
      end
    end

    // output
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      psrc0_ready_o[i] = psrc0_ready[i];
      psrc0_o[i] = psrc0[i];
      psrc1_ready_o[i] = psrc1_ready[i];
      psrc1_o[i] = psrc1[i];
      ppdst_o[i] = ppdst[i];
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      rat_q.arch_reg <= '0;
      rat_q.valid <= '0;
      rat_q.ready <= '1;
    end else begin
      rat_q <= rat_n;
    end
  end
  

endmodule : RegisterAliasTable
