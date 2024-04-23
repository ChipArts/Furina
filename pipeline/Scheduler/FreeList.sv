// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : FreeList.sv
// Create  : 2024-01-16 11:48:43
// Revise  : 2024-01-16 11:48:43
// Description :
//   空闲列表
//   为了简化设计，alloc和free有效位必须连续并从[0]开始
// Parameter   :
//   ...
//   ...
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// 24-01-16 |            |     0.1     |    Original Version
// ==============================================================================

`include "common.svh"
`include "config.svh"


module FreeList #(
parameter
  int unsigned PHY_REG_NUM = 64
)(
  input logic clk,      // Clock
  input logic rst_n,    // Asynchronous reset active low

  input logic flush_i,
  input logic [$clog2(PHY_REG_NUM) - 1:0] arch_head,
  input logic [$clog2(PHY_REG_NUM) - 1:0] arch_tail,
  input logic [$clog2(PHY_REG_NUM + 1) - 1:0] arch_cnt,

  input logic [`DECODE_WIDTH - 1:0] alloc_valid_i,
  output logic alloc_ready_o,
  output logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] preg_o,
  input logic [`COMMIT_WIDTH - 1:0] free_valid_i,
  output logic free_ready_o,
  input logic [`COMMIT_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] free_preg_i
);

  // 要保证PHY_REG_NUM是2的幂

  logic [PHY_REG_NUM - 1:0][$clog2(PHY_REG_NUM) - 1:0] free_list_q, free_list_n;
  logic [$clog2(PHY_REG_NUM) - 1:0] tail, head, tail_n, head_n;
  logic [$clog2(PHY_REG_NUM):0] cnt_q, cnt_n;  // free list使用计数器

  // read/write logic
  logic [$clog2(`DECODE_WIDTH + 1) - 1:0] alloc_req_cnt;
  logic [$clog2(`COMMIT_WIDTH + 1) - 1:0] free_req_cnt;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] rd_idx;
  logic [`COMMIT_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] wr_idx;


  always_comb begin
    alloc_req_cnt = $countones(alloc_valid_i);
    free_req_cnt = $countones(free_valid_i);

    alloc_ready_o = cnt_q >= `DECODE_WIDTH;
    free_ready_o = '1;
    

    // 根据valid信号生成输出
    rd_idx[0] = head;
    for (int i = 1; i < `DECODE_WIDTH; i++) begin
      if (alloc_valid_i[i - 1]) begin
        rd_idx[i] = (rd_idx[i - 1] < PHY_REG_NUM - 1) ? rd_idx[i - 1] + 1 : '0;
      end else begin
        rd_idx[i] = rd_idx[i - 1];
      end
    end

    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      if (alloc_valid_i[i]) begin
        preg_o[i] = free_list_q[rd_idx[i]];
      end else begin
        preg_o[i] = '0;
      end
    end

    // 根据Free信号更新freelist
    wr_idx[0] = tail;
    for (int i = 1; i < `COMMIT_WIDTH; i++) begin
      if (free_valid_i[i - 1]) begin
        wr_idx[i] = (wr_idx[i - 1] < PHY_REG_NUM - 1) ? wr_idx[i - 1] + 1 : 0;
      end else begin
        wr_idx[i] = wr_idx[i - 1];
      end
    end

    free_list_n = free_list_q;
    for (int i = 0; i < `COMMIT_WIDTH; i++) begin
      if (free_valid_i[i]) begin
        free_list_n[wr_idx[i]] = free_preg_i[i];
      end
    end

    if (alloc_ready_o) begin
      cnt_n = cnt_q + free_req_cnt - alloc_req_cnt;
    end else begin
      cnt_n = cnt_q + free_req_cnt;
    end

    if (alloc_ready_o) begin
      head_n = head + alloc_req_cnt;
    end else begin
      head_n = head;
    end

    tail_n = tail + free_req_cnt;

    if (flush_i) begin
      head_n = arch_head;
      tail_n = arch_tail;
      cnt_n = arch_cnt;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      for (int i = 0; i < PHY_REG_NUM; i++) begin
        free_list_q[i] <= i;
      end
      cnt_q <= PHY_REG_NUM;
      tail <= '0;
      head <= '0;
    end else begin
      // 释放过程不会阻塞
      free_list_q <= free_list_n;
      cnt_q <= cnt_n;
      head <= head_n;
      tail <= tail_n;
    end
  end



endmodule : FreeList
