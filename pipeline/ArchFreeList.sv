// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : your name <your email>@email.com
// File    : ArchFreeList.sv
// Create  : 2024-04-14 20:47:43
// Revise  : 2024-04-16 18:12:46
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
  input logic a_rst_n,  // Asynchronous reset active low
  input logic flush_i,
  output logic [PHY_REG_NUM - 1:0][$clog2(PHY_REG_NUM) - 1:0] arch_free_list_o,
  input logic [`COMMIT_WIDTH - 1:0] alloc_valid_i,
  input logic [`COMMIT_WIDTH - 1:0] free_valid_i,
  input logic [`COMMIT_WIDTH - 1:0][$clog2(PHY_REG_NUM) - 1:0] free_preg_i
);
  
  `RESET_LOGIC(clk, a_rst_n, rst_n);

  logic [PHY_REG_NUM - 1:0][$clog2(PHY_REG_NUM) - 1:0] free_list, free_list_n;
  logic [$clog2(PHY_REG_NUM) - 1:0] tail, head, tail_n, head_n;
  logic [$clog2(PHY_REG_NUM + 1):0] free_list_cnt, free_list_cnt_n;  // free list使用计数器

  // read/write logic
  logic [$clog2(`COMMIT_WIDTH + 1) - 1:0] alloc_req_cnt;
  logic [$clog2(`COMMIT_WIDTH + 1) - 1:0] free_req_cnt;
  logic [$clog2(`COMMIT_WIDTH) - 1:0] rd_preg_idx;
  logic [$clog2(`COMMIT_WIDTH) - 1:0] wr_preg_idx;


  always_comb begin
    alloc_req_cnt = $countones(alloc_valid_i);
    free_req_cnt = $countones(free_valid_i);

    head_n = head + free_req_cnt;
    tail_n = tail + alloc_req_cnt;

    // 根据Free信号更新freelist
    free_list_n = free_list;
    wr_preg_idx = tail;
    for (int i = 0; i < `COMMIT_WIDTH; i++) begin
      if (free_valid_i[i]) begin
        free_list_n[wr_preg_idx] = free_preg_i[i];
        wr_preg_idx = wr_preg_idx < PHY_REG_NUM - 1 ? wr_preg_idx + 1 : 0;
      end
    end


    free_list_cnt_n = free_req_cnt + free_req_cnt - alloc_req_cnt;
    arch_free_list_o = free_list_n;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n || flush_i) begin
      for (int i = 0; i < PHY_REG_NUM; i++) begin
      	free_list[i] <= i;
      end
      free_list_cnt <= PHY_REG_NUM;
      tail <= '0;
      head <= '0;
    end else begin
      // 释放过程不会阻塞
      free_list <= free_list_n;
      free_list_cnt <= free_list_cnt_n;
      head <= head_n;
      tail <= tail_n;
    end
  end



endmodule : ArchFreeList