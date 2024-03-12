// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Pipeline.sv
// Create  : 2024-03-11 14:53:30
// Revise  : 2024-03-11 19:53:52
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
`include "Decoder.svh"
`include "BranchPredictionUnit.svh"


module Pipeline (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  AXI4.Master icache_axi4_mst,
  AXI4.Master dcache_axi4_mst
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);
  /* Signal Define */
  BPU_ReqSt bpu_req;
  BPU_RspSt bpu_rsp;

  logic faq_write_ready;
  logic [`PROC_FETCH_WIDTH - 1:0] faq_write_data;
  logic [$clog2(`PROC_FETCH_WIDTH + 1) - 1:0] faq_write_num;
  logic [`PROC_FETCH_WIDTH - 1:0] faq_read_valid;
  logic [`PROC_FETCH_WIDTH - 1:0][31:0] faq_read_data;


  /* BPU */

  always_comb begin
    bpu_req.next = faq_write_ready;
  end

  BranchPredictionUnit U_BranchPredictionUnit (
    .clk(clk), 
    .a_rst_n(a_rst_n), 
    .bpu_req(bpu_req), 
    .bpu_rsp(bpu_rsp)
  );

  /* Fetch Address Queue */

  always_comb begin
    faq_write_num = '0;
    for (int i = 0; i < `PROC_FETCH_WIDTH; i++) begin
      faq_write_num += bpu_rsp.valid[i];
      faq_write_data[i] = bpu_rsp.pc + (i << 2);
    end
  end

  SyncMultiChannelFIFO #(
    .FIFO_DEPTH(32),
    .DATA_WIDTH(32),
    .RPORTS_NUM(`PROC_FETCH_WIDTH),
    .WPORTS_NUM(`PROC_FETCH_WIDTH),
    .FIFO_MEMORY_TYPE("auto")
  ) U_FetchAddressQueue (
    .clk           (clk),
    .a_rst_n       (rst_n),
    .flush_i       (flush_i),
    .write_valid_i (|bpu_rsp.valid),
    .write_ready_o (faq_write_ready),
    .write_num_i   (faq_write_num),
    .write_data_i  (faq_write_data),
    .read_valid_o  (faq_read_valid),
    .read_ready_i  (),
    .read_num_i    (),
    .read_data_o   (faq_read_data)
  );


  /* Instruction Fetch Unit */
  // ICache
  

endmodule : Pipeline



