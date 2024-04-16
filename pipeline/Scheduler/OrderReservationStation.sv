// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : OrderReservationStation.sv
// Create  : 2024-03-21 20:23:24
// Revise  : 2024-04-02 16:10:20
// Description :
//   ...
//   ...
// Parameter   :
//   ...
//   ...
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// xx-xx-xx |            |     0.1     |    Original Version
// ...
// ==============================================================================
`include "config.svh"
`include "common.svh"
`include "Scheduler.svh"
`include "Decoder.svh"


module OrderReservationStation #(
parameter
  int unsigned RS_SIZE = 4,
  type OPTION_CODE = OptionCodeSt
)(
  input clk,    // Clock
  input rst_n,  // Asynchronous reset active low
  input logic flush_i,

  /* dispatch */
  input RsBaseSt rs_base_i,
  input OPTION_CODE option_code_i,
  input logic wr_valid_i,
  output logic wr_ready_o,

  /* wake up */
  input logic [`WB_WIDTH - 1:0] wb_pdest_valid_i,
  input logic [`WB_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] wb_pdest_i,

  /* issue */
  input logic issue_ready_i,
  output logic issue_valid_o,
  output IssueBaseSt issue_base_o,
  output OPTION_CODE issue_oc_o
);

  typedef struct packed {
    RsBaseSt base;
    OPTION_CODE oc;
  } RsEntrySt;

  // clock gating control
  logic gate_clock;
  // pointer to the read and write section of the queue
  logic [$clog2(RS_SIZE) - 1:0] read_pointer_n, read_pointer_q, write_pointer_n, write_pointer_q;
  // keep a counter to keep track of the current queue status
  // this integer will be truncated by the synthesis tool
  logic [$clog2(RS_SIZE):0] status_cnt_n, status_cnt_q;
  // actual memory
  RsEntrySt [RS_SIZE - 1:0] mem_n, mem_q;

  logic full, empty;

  assign full       = (status_cnt_q == RS_SIZE);
  assign empty      = (status_cnt_q == 0);
  assign wr_ready_o = ~full;
  // status flags

  // read and write queue logic
  always_comb begin : read_write_comb
      // default assignment
      read_pointer_n  = read_pointer_q;
      write_pointer_n = write_pointer_q;
      status_cnt_n    = status_cnt_q;
      mem_n           = mem_q;
      gate_clock      = 1'b1;

      issue_base_o = rs2is(mem_q[read_pointer_q].base);
      issue_oc_o = mem_q[read_pointer_q].oc;

      // push a new element to the queue
      if (wr_valid_i && ~full) begin
          // push the data onto the queue
          mem_n[write_pointer_q] = {rs_base_i, option_code_i};
          // un-gate the clock, we want to write something
          gate_clock = 1'b0;
          // increment the write counter
          // this is dead code when DEPTH is a power of two
          if (write_pointer_q == RS_SIZE - 1)
              write_pointer_n = '0;
          else
              write_pointer_n = write_pointer_q + 1;
          // increment the overall counter
          status_cnt_n    = status_cnt_q + 1;
      end

      // wake up
      for (int i = 0; i < RS_SIZE; i++) begin
        for (int j = 0; j < `WB_WIDTH; j++) begin
          if (wb_pdest_valid_i[j]) begin
            if (mem_q[i].base.valid &&
                mem_q[i].base.psrc0 == wb_pdest_i[j]) begin
              mem_n[i].base.psrc0_ready = '1;
            end
            if (mem_q[i].base.valid &&
                mem_q[i].base.psrc1 == wb_pdest_i[j]) begin
              mem_n[i].base.psrc1_ready = '1;
            end
          end
        end
      end

      // select logic
      issue_valid_o =
              (mem_q[read_pointer_q].base.valid & ~mem_q[read_pointer_q].base.issued) &
              (mem_q[read_pointer_q].base.psrc0_ready | ~mem_q[read_pointer_q].base.psrc0_valid) &
              (mem_q[read_pointer_q].base.psrc1_ready | ~mem_q[read_pointer_q].base.psrc1_valid);

      // pop a element from the queue
      if (issue_valid_o && issue_ready_i && ~empty) begin
          // read from the queue is a default assignment
          // but increment the read pointer...
          // this is dead code when DEPTH is a power of two
          if (read_pointer_n == RS_SIZE - 1)
              read_pointer_n = '0;
          else
              read_pointer_n = read_pointer_q + 1;
          // ... and decrement the overall count
          status_cnt_n   = status_cnt_q - 1;
          // set issued tag
          mem_n[read_pointer_q].base.issued = '1;
      end

      // keep the count pointer stable if we push and pop at the same time
      if (wr_valid_i && issue_ready_i &&  ~full && ~empty) begin
        status_cnt_n   = status_cnt_q;
      end

  end

  // sequential process
  always_ff @(posedge clk or negedge rst_n) begin
      if(~rst_n || flush_i) begin
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

  always_ff @(posedge clk or negedge rst_n) begin
      if(~rst_n || flush_i) begin
          mem_q <= '0;
      end else if (!gate_clock) begin
          mem_q <= mem_n;
      end
  end

endmodule : OrderReservationStation
