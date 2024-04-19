// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : your name <your email>@email.com
// File    : ArchFreeList.sv
// Create  : 2024-04-14 20:47:43
// Revise  : 2024-04-19 11:42:25
// Editor  : {EDITER}
// Version : {VERSION}
// Description :
//    ...
//    ...
// Parameter   :
//    ...
//    ...
// IO Port     :
//    ...
//    ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
//    ...   |            |     0.1     |    Original Version
// ==============================================================================

`include "common.svh"
`include "config.svh"


module ArchFreeList #(
parameter
  int unsigned PHY_REG_NUM = 64
)(
  input logic clk,      // Clock
  input logic rst_n,  // Asynchronous reset active low
  input logic flush_i,
  output logic [$clog2(PHY_REG_NUM) - 1:0] arch_head_o,
  output logic [$clog2(PHY_REG_NUM) - 1:0] arch_tail_o,
  output logic [$clog2(PHY_REG_NUM + 1) - 1:0] arch_cnt_o,
  input logic [`COMMIT_WIDTH - 1:0] alloc_valid_i,
  input logic [`COMMIT_WIDTH - 1:0] free_valid_i,
  input logic [`COMMIT_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] free_preg_i
);

  logic [$clog2(PHY_REG_NUM) - 1:0] tail, head, tail_n, head_n;
  logic [$clog2(PHY_REG_NUM + 1) - 1:0] cnt_q, cnt_n;  // free list使用计数器

  // read/write logic
  logic [$clog2(`COMMIT_WIDTH + 1) - 1:0] alloc_req_cnt;
  logic [$clog2(`COMMIT_WIDTH + 1) - 1:0] free_req_cnt;


  always_comb begin
    alloc_req_cnt = $countones(alloc_valid_i);
    free_req_cnt = $countones(free_valid_i);

    head_n = head + alloc_req_cnt;
    tail_n = tail + free_req_cnt;

    cnt_n = free_req_cnt + free_req_cnt - alloc_req_cnt;

    arch_head_o = head_n;
    arch_tail_o = tail_n;
    arch_cnt_o = cnt_n;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      cnt_q <= PHY_REG_NUM;
      tail <= '0;
      head <= '0;
    end else begin
      // 释放过程不会阻塞
      cnt_q <= cnt_n;
      head <= head_n;
      tail <= tail_n;
    end
  end



endmodule : ArchFreeList
