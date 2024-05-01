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
//   READ_MODE:
//     - "std" : 标准FIFO
//     - "fwft": FIFO写后立即读
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
  FIFO_DEPTH = 128,
  FIFO_DATA_WIDTH = 32,
  READ_MODE = "std",
  FIFO_MEMORY_TYPE = "auto",
localparam
  FIFO_ADDR_WIDTH = $clog2(FIFO_DEPTH),
  FIFO_CNT_WIDTH = $clog2(FIFO_DEPTH + 1)
)(
  input logic clk,      // Clock
  input logic a_rst_n,  // Asynchronous reset active low
  input logic flush_i,
  input logic pop_i,
  input logic push_i,
  input logic [FIFO_DATA_WIDTH - 1:0] data_i,
  output logic [FIFO_DATA_WIDTH - 1:0] data_o,
  output logic empty_o,
  output logic full_o,
  output logic [FIFO_CNT_WIDTH-1:0] usage_o
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

`ifdef DEBUG
  // some parameter check
  initial begin
    assert(FIFO_DATA_WIDTH > 1) else $error("SyncFIFO: FIFO_DEPTH <= 1");
  end
`endif

  // pointer to the read and write section of the queue
  logic [FIFO_ADDR_WIDTH - 1:0] read_pointer_n, read_pointer_q, write_pointer_n, write_pointer_q;
  // keep a counter to keep track of the current queue status
  // this integer will be truncated by the synthesis tool
  logic [FIFO_CNT_WIDTH - 1:0] status_cnt_n, status_cnt_q;
  // actual memory
  logic ram_we;
  logic [FIFO_DATA_WIDTH - 1:0] ram_rdata, ram_wdata;
  SimpleDualPortRAM #(
    .DATA_DEPTH(FIFO_DEPTH),
    .DATA_WIDTH(FIFO_DATA_WIDTH),
    .BYTE_WRITE_WIDTH(FIFO_DATA_WIDTH),
    .CLOCKING_MODE("common_clock"),
    .WRITE_MODE("write_first"),
    .MEMORY_PRIMITIVE("auto")
  ) inst_SimpleDualPortRAM (
    .clk_a    (clk),
    .en_a_i   ('1),
    .we_a_i   (ram_we),
    .addr_a_i (write_pointer_q),
    .data_a_i (data_i),
    .clk_b    (clk),
    .rstb_n   (rst_n),
    .en_b_i   ('1),
    .addr_b_i (read_pointer_n),
    .data_b_o (ram_rdata)
  );


  assign usage_o = status_cnt_q;
  assign full_o       = (status_cnt_q == FIFO_DEPTH);
  assign empty_o      = (status_cnt_q == 0) & ~(READ_MODE == "fwft" & push_i);
  // read and write queue logic
  always_comb begin : read_write_comb
      // default assignment
      read_pointer_n  = read_pointer_q;
      write_pointer_n = write_pointer_q;
      status_cnt_n    = status_cnt_q;
      data_o          = ram_rdata;
      ram_we          = '0;

      // push a new element to the queue
      if (push_i && ~full_o) begin
          // push the data onto the queue
          ram_we = '1;
          // increment the write counter
          // this is dead code when DEPTH is a power of two
          if (write_pointer_q == FIFO_DEPTH[FIFO_ADDR_WIDTH - 1:0] - 1)
              write_pointer_n = '0;
          else
              write_pointer_n = write_pointer_q + 1;
          // increment the overall counter
          status_cnt_n    = status_cnt_q + 1;
      end

      if (pop_i && ~empty_o) begin
          // read from the queue is a default assignment
          // but increment the read pointer...
          // this is dead code when DEPTH is a power of two
          if (read_pointer_n == FIFO_DEPTH[FIFO_ADDR_WIDTH-1:0] - 1)
              read_pointer_n = '0;
          else
              read_pointer_n = read_pointer_q + 1;
          // ... and decrement the overall count
          status_cnt_n   = status_cnt_q - 1;
      end

      // keep the count pointer stable if we push and pop at the same time
      if (push_i && pop_i &&  ~full_o && ~empty_o)
          status_cnt_n   = status_cnt_q;

      // FIFO is in pass through mode -> do not change the pointers
      if (READ_MODE == "fwft" && (status_cnt_q == 0) && push_i) begin
          data_o = data_i;
          if (pop_i) begin
              status_cnt_n = status_cnt_q;
              read_pointer_n = read_pointer_q;
              write_pointer_n = write_pointer_q;
          end
      end
  end

  // sequential process
  always_ff @(posedge clk or negedge rst_n) begin
      if(~rst_n) begin
          read_pointer_q  <= '0;
          write_pointer_q <= '0;
          status_cnt_q    <= '0;
      end else begin
          if (flush_i) begin
              read_pointer_q  <= '0;
              write_pointer_q <= '0;
              status_cnt_q    <= '0;
           end else begin
              read_pointer_q  <= read_pointer_n;
              write_pointer_q <= write_pointer_n;
              status_cnt_q    <= status_cnt_n;
          end
      end
  end

endmodule : SyncFIFO

