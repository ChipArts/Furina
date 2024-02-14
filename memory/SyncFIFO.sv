// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : SyncFIFO.sv
// Create  : 2024-01-31 18:16:26
// Revise  : 2024-01-31 18:19:04
// Description :
//   同步FIFO
//   redirect时不能进行读写操作
// Parameter   :
//   READ_MODE
//   PTR_REDIRECT: FIFO的指针重定位
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// 24-01-31 |            |     0.1     |    Original Version
// ==============================================================================

`include "config.svh"
`include "common.svh"


module SyncFIFO #(
parameter
  int unsigned FIFO_DEPTH = 128,
  int unsigned FIFO_DATA_WIDTH = 32,
  string       READ_MODE = "std",
  string       FIFO_MEMORY_TYPE = "auto",
localparam
  int unsigned FIFO_ADDR_WIDTH = $clog2(FIFO_DEPTH),
  int unsigned FIFO_CNT_WIDTH = $clog2(FIFO_DEPTH + 1)
)(
  input logic clk,      // Clock
  input logic a_rst_n,  // Asynchronous reset active low
  input logic redirect_i,
  input logic [FIFO_ADDR_WIDTH - 1:0] head_target_i,
  input logic [FIFO_ADDR_WIDTH - 1:0] tail_target_i,
  input logic [FIFO_CNT_WIDTH - 1:0] cnt_target_i,
  input logic pop_i,
  input logic push_i,
  input logic [FIFO_DATA_WIDTH - 1:0] data_i,
  output logic [FIFO_DATA_WIDTH - 1:0] data_o,
  output logic empty_o,
  output logic full_o,
  output logic [$clog2(FIFO_DEPTH + 1) -1:0] cnt_o,  // cnt how much mem are used
  output logic [FIFO_ADDR_WIDTH - 1:0] head_o,
  output logic [FIFO_ADDR_WIDTH - 1:0] tail_o
);

`ifdef DEBUG
  // some parameter check
  initial begin
    assert(FIFO_DATA_WIDTH > 1) else $error("SyncFIFO: FIFO_DEPTH <= 1");
  end
`endif
  
  `RESET_LOGIC(clk, a_rst_n, s_rst_n);

  logic [FIFO_CNT_WIDTH - 1:0] fifo_cnt, f_fifo_cnt;
  logic [FIFO_ADDR_WIDTH - 1:0] head, tail, f_tail, f_head;
  logic [FIFO_DATA_WIDTH - 1:0] sdpram_data_o;

  always_comb begin
    // default
    f_head = head;
    f_tail = tail;
    f_fifo_cnt = fifo_cnt;

    full_o = (fifo_cnt == FIFO_DEPTH);
    empty_o = (fifo_cnt == 0) & ~(READ_MODE == "fwft" & push_i);
    data_o = sdpram_data_o;
    cnt_o = fifo_cnt;
    head_o = head;
    tail_o = tail;

    // push a new element to the queue
    if (push_i && !full_o) begin
      f_fifo_cnt = fifo_cnt + 1;
      if (tail == FIFO_DEPTH - 1) begin
        f_tail = '0;
      end else begin
        f_tail = tail + 1;
      end
    end

    // pop an element from the queue
    if (pop_i && !empty_o) begin
      f_fifo_cnt = fifo_cnt - 1;
      if (head == FIFO_DEPTH - 1) begin
        f_head = '0;
      end else begin
        f_head = head + 1;
      end
    end

    // keep the count pointer stable if we push and pop at the same time
    if (push_i && pop_i && !full_o && !empty_o) begin
      f_fifo_cnt = fifo_cnt;
    end

    // FIFO is in pass through mode
    if (READ_MODE == "fwft" && (fifo_cnt == 0) && push_i) begin
      data_o = data_i;
      if (pop_i) begin
        f_fifo_cnt = fifo_cnt;
        f_head = head;
        f_tail = tail;
      end
    end

    // redirect the FIFO
    if (redirect_i) begin
      f_head = head_target_i;
      f_tail = tail_target_i;
      f_fifo_cnt = cnt_target_i;
    end
  end


  always_ff @(posedge clk or negedge rst_n) begin
    if(~s_rst_n) begin
      fifo_cnt <= '0;
      head <= '0;
      tail <= '0;
    end else begin
      fifo_cnt <= f_fifo_cnt;
      head <= f_head;
      tail <= f_tail;
    end
  end

  SimpleDualPortRAM #(
    .DATA_DEPTH(FIFO_DEPTH),
    .DATA_WIDTH(FIFO_DATA_WIDTH),
    .BYTE_WRITE_WIDTH(FIFO_DATA_WIDTH),
    .CLOCKING_MODE("common_clock"),
    .WRITE_MODE("write_first"),
    .MEMORY_PRIMITIVE(FIFO_MEMORY_TYPE)
  ) inst_SimpleDualPortRAM (
    .clk_a    (clk),
    .en_a_i   ('1),
    .we_a_i   (push_i && ~full_o),
    .addr_a_i (tail),
    .data_a_i (data_i),
    .clk_b    (clk),
    .rstb_n   (s_rst_n),
    .en_b_i   ('1),
    .addr_b_i (head),
    .data_b_o (sdpram_data_o)
  );

endmodule : SyncFIFO

