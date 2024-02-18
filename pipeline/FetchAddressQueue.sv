// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : FetchAddressQueue.sv
// Create  : 2024-02-12 16:37:58
// Revise  : 2024-02-14 18:08:25
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
`include "BranchPredictionUnit.svh"
`include "FetchAddressQueue.svh"
`include "InstructionFetchUnit.svh"


module FetchAddressQueue #(
parameter
  int unsigned FAQ_DEPTH = `FAQ_DEPTH,
localparam
  int unsigned FAQ_ADDR_WIDTH = $clog2(FAQ_DEPTH),
  int unsigned FAQ_CNT_WIDTH = $clog2(FAQ_DEPTH + 1)
)(
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input redirect_i,
  input [FAQ_ADDR_WIDTH - 1:0] head_target_i,
  input [FAQ_ADDR_WIDTH - 1:0] tail_target_i,
  input [FAQ_CNT_WIDTH - 1:0] cnt_target_i,
  input BPU2FAQSt bpu2faq_st_i,
  input IFU2FAQSt ifu2faq_st_i,
  output FAQ2BPUSt faq2bpu_st_o,
  output FAQ2IFUSt faq2ifu_st_o
);

  `RESET_LOGIC(clk, a_rst_n, s_rst_n);

  typedef struct packed {
    logic [`PROC_BIT_WIDTH - 1:0] pc;
    logic [`PROC_DECODE_WIDTH - 1:0] valid;
  } FAQDataSt;

  FAQDataSt faq_din_st, faq_dout_st;
  logic faq_empty, faq_full;

  always_comb begin
    faq_din_st.pc = bpu2faq_st_i.pc;
    faq_din_st.valid = bpu2faq_st_i.valid;

    faq2ifu_st_o.pc = faq_dout_st.pc;
    faq2ifu_st_o.valid = faq_dout_st.valid;

    faq2bpu_st_o.fetch_req = ~faq_full;
  end

  SyncFIFO #(
    .FIFO_DEPTH(FAQ_DEPTH),
    .FIFO_DATA_WIDTH($bits(faq_data_st)),
    .READ_MODE("std"),
    .FIFO_MEMORY_TYPE("auto")
  ) U_FetchAddressQueue (
    .clk           (clk),
    .a_rst_n       (a_rst_n),
    .redirect_i    (redirect_i),
    .head_target_i (head_target_i),
    .tail_target_i (tail_target_i),
    .cnt_target_i  (cnt_target_i),
    .pop_i         (ifu2faq_st_i.fetch_req),
    .push_i        (|bpu2faq_st_i.valid),
    .data_i        (faq_din_st),
    .data_o        (faq_dout_st),
    .empty_o       (faq_empty),
    .full_o        (faq_full),
    .cnt_o         (faq2ifu_st_o.faq_cnt),
    .head_o        (faq2ifu_st_o.faq_head),
    .tail_o        (faq2ifu_st_o.faq_tail)
  );




endmodule : FetchAddressQueue