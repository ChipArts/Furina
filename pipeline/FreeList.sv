// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : FreeList.sv
// Create  : 2024-01-16 11:48:43
// Revise  : 2024-01-16 11:48:43
// Description :
//   空闲列表
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


module FreeList #(
parameter
  PHYS_REG_NUM = 192,
  RENAME_WIDTH = 6
)(
  input clk,      // Clock
  input a_rst_n,  // Asynchronous reset active low
  input [RENAME_WIDTH - 1:0] alloc_req_i,
  input [RENAME_WIDTH - 1:0] free_req_i,
  input [RENAME_WIDTH - 1:0][$clog2(PHYS_REG_NUM) - 1:0] free_preg_i,
  output can_alloc,
  output [RENAME_WIDTH - 1:0][$clog2(PHYS_REG_NUM) - 1:0] preg_o
);
  
  `RESET_LOGIC(clk, a_rst_n, s_rst_n)

  logic [PHYS_REG_NUM - 1:0][$clog2(PHYS_REG_NUM) - 1:0] free_list;
  logic [$clog2(PHYS_REG_NUM) - 1:0] tail, head;  // reg
  logic [$clog2(PHYS_REG_NUM) - 1:0] free_req_cnt;

  always_ff @(posedge clk or negedge s_rst_n) begin
    if(~s_rst_n) begin
      for (int i = 0; i < PHYS_REG_NUM; i++) begin
        free_list[i] <= i;
      end
      tail <= 0;
      head <= 0;
    end else begin
      
    end
  end



endmodule : FreeList
