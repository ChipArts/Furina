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
  input logic a_rst_n,  // Asynchronous reset active low
  input logic flush_i,
  input logic [PHY_REG_NUM - 1:0][$clog2(PHY_REG_NUM) - 1:0] arch_free_list_i,
  input logic [`DECODE_WIDTH - 1:0] alloc_valid_i,
  output logic alloc_ready_o,
  output logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] preg_o,
  input logic [`COMMIT_WIDTH - 1:0] free_valid_i,
  output logic free_ready_o,
  input logic [`COMMIT_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] free_preg_i
);
  
  `RESET_LOGIC(clk, a_rst_n, rst_n);

  // 要保证PHY_REG_NUM是2的幂

  logic [PHY_REG_NUM - 1:0][$clog2(PHY_REG_NUM) - 1:0] free_list_q, free_list_n;
  logic [$clog2(PHY_REG_NUM) - 1:0] tail, head, tail_n, head_n;
  logic [$clog2(PHY_REG_NUM):0] free_list_cnt, free_list_cnt_n;  // free list使用计数器

  // read/write logic
  logic [$clog2(`DECODE_WIDTH + 1) - 1:0] alloc_req_cnt;
  logic [$clog2(`COMMIT_WIDTH + 1) - 1:0] free_req_cnt;
  logic [$clog2(`PHY_REG_NUM) - 1:0] rd_preg_idx;
  logic [$clog2(`PHY_REG_NUM) - 1:0] wr_preg_idx;


  always_comb begin
    alloc_req_cnt = $countones(alloc_valid_i);
    free_req_cnt = $countones(free_valid_i);

    alloc_ready_o = free_list_cnt >= `DECODE_WIDTH;
    free_ready_o = '1;

    head_n = head + free_req_cnt;
    if (alloc_ready_o) begin
      tail_n = tail + alloc_req_cnt;
    end else begin
      tail_n = tail;
    end
    

    // 根据valid信号生成输出
    rd_preg_idx = head;
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      if (alloc_valid_i[i]) begin
        preg_o[i] = free_list_q[rd_preg_idx];
        rd_preg_idx = rd_preg_idx < PHY_REG_NUM - 1 ? rd_preg_idx + 1 : 0;
      end else begin
        preg_o[i] = '0;
      end
    end

    // 根据Free信号更新freelist
    free_list_n = free_list_q;
    wr_preg_idx = tail;
    for (int i = 0; i < `COMMIT_WIDTH; i++) begin
      if (free_valid_i[i]) begin
        free_list_n[wr_preg_idx] = free_preg_i[i];
        wr_preg_idx = wr_preg_idx < PHY_REG_NUM - 1 ? wr_preg_idx + 1 : 0;
      end
    end


    if (alloc_ready_o) begin
      free_list_cnt_n = free_list_cnt + free_req_cnt - alloc_req_cnt;
    end else begin
      free_list_cnt_n = free_list_cnt + free_req_cnt;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n || flush_i) begin
      free_list_q <= arch_free_list_i;
      free_list_cnt <= PHY_REG_NUM;
      tail <= '0;
      head <= '0;
    end else begin
      // 释放过程不会阻塞
      free_list_q <= free_list_n;
      free_list_cnt <= free_list_cnt_n;
      head <= head_n;
      tail <= tail_n;
    end
  end



endmodule : FreeList
