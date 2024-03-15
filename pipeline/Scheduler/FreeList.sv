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
parameter int unsigned PHY_REG_NUM = 64
)(
  input logic clk,      // Clock
  input logic a_rst_n,  // Asynchronous reset active low
  input logic flush_i,
  input logic [`DECODE_WIDTH - 1:0] alloc_req_i,
  input logic [`COMMIT_WIDTH - 1:0] free_req_i,
  input logic [`COMMIT_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] free_preg_i,
  output logic empty_o,
  output logic full_o,  // 显然不可能满
  output logic [`DECODE_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] preg_o
);
  
  `RESET_LOGIC(clk, a_rst_n, rst_n);

  logic [PHY_REG_NUM - 1:0][$clog2(PHY_REG_NUM) - 1:0] free_list, f_free_list;
  logic [$clog2(PHY_REG_NUM) - 1:0] tail, head;
  logic [$clog2(PHY_REG_NUM + 1):0] free_list_cnt;  // free list使用计数器

  // read/write logic
  logic [$clog2(`DECODE_WIDTH + 1) - 1:0] alloc_req_cnt;
  logic [$clog2(`COMMIT_WIDTH + 1) - 1:0] free_req_cnt;
  logic [$clog2(PHY_REG_NUM) - 1:0] f_tail, f_head;
  logic [$clog2(PHY_REG_NUM + 1):0] f_free_list_cnt;

  BitCounter #(`COMMIT_WIDTH) U_WPortBitCounter (free_req_i, free_req_cnt);
  BitCounter #(`DECODE_WIDTH) U_RPortBitCounter (alloc_req_i, alloc_req_cnt);

  always_comb begin
    f_free_list_cnt = free_req_cnt + free_req_cnt - alloc_req_cnt;
    empty_o = f_free_list_cnt[$clog2(PHY_REG_NUM + 1)];  // 最高位为1则为负数，不能分配

    f_head = head + free_req_cnt;
    f_tail = tail + alloc_req_cnt;

    full_o = '0;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n || flush_i) begin
      for (int i = 0; i < PHY_REG_NUM; i++) begin
        free_list[i] <= i;
      end
      tail <= '0;
      head <= '0;
    end else begin
      for (int i = 0; i < `DECODE_WIDTH; i++) begin
        if (head + i < PHY_REG_NUM) begin
          preg_o[i] <= free_list[head + i];
        end else begin
          preg_o[i] <= free_list[head + i - PHY_REG_NUM];
        end
      end
      for (int i = 0; i < `COMMIT_WIDTH; i++) begin
        if (free_req_i[i]) begin
          if (tail + i < PHY_REG_NUM) begin
            free_list[tail + i] <= free_preg_i[i];
          end else begin
            free_list[tail + i - PHY_REG_NUM] <= free_preg_i[i];
          end
        end
      end
      head = f_head;
      tail = f_tail;
    end
  end



endmodule : FreeList