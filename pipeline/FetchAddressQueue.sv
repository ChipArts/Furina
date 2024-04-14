// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : FetchAddressQueue.sv
// Create  : 2024-02-12 16:37:58
// Revise  : 2024-03-31 22:53:59
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
`include "Cache.svh"


module FetchAddressQueue (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input flush_i,
  input FaqPushReqSt push_req,
  input FaqPopReqSt pop_req,
  output FaqPushRspSt push_rsp,
  output FaqPopRspSt pop_rsp
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

  typedef struct packed {
    logic [`PROC_VALEN - 1:0] vaddr;
    logic [`FETCH_WIDTH - 1:0] valid;
  } FaqDataSt;

  FaqDataSt faq_wdata, faq_rdata;

  always_comb begin
    faq_wdata.vaddr = push_req.vaddr;
    faq_wdata.valid = push_req.valid;
    push_rsp.ready = ~full;
    pop_rsp.valid = faq_rdata.valid;
    pop_rsp.vaddr = faq_rdata.vaddr;
  end


  /* Memory */
  SyncFIFO #(
    .FIFO_DEPTH(`FAQ_DEPTH),
    .FIFO_DATA_WIDTH($bits(FAQ_DataSt)),
    .READ_MODE("std"),
    .FIFO_MEMORY_TYPE("auto")
  ) U_SyncFIFO (
    .clk     (clk),
    .a_rst_n (rst_n),
    .flush_i (flush_i),
    .pop_i   (pop_rsp.ready),
    .push_i  (push_rsp.ready),
    .data_i  (faq_wdata),
    .data_o  (faq_rdata),
    .empty_o (empty),
    .full_o  (full),
    .usage_o (/* not used */)
  );


endmodule : FetchAddressQueue