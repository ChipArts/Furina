// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : BranchPredictionUnit.sv
// Create  : 2024-02-12 15:35:06
// Revise  : 2024-03-01 21:11:15
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

`define NPC

module BranchPredictionUnit #(
parameter
  int unsigned BHT_SIZE = 1024,
  int unsigned DECODE_WIDTH = 6
)(
  input logic clk,    // Clock
  input logic a_rst_n,  // Asynchronous reset active low
  input logic redirect_i,
  input logic [31:0] target_i,
  output BPU2FAQSt bpu2faq_st_o
);

  `RESET_LOGIC(clk,  a_rst_n, s_rst_n);

`ifdef NPC
  logic [31:0] pc;
  always @(posedge clk or negedge s_rst_n) begin
    if (!s_rst_n) begin
      pc <= 32'h1c00_0000;
    end
    else begin
      if (redirect_i) begin
        pc <= target_i;
      end else begin
        pc <= pc + DECODE_WIDTH;
      end
    end
  end

  always_comb begin
    for (int i = 0; i < DECODE_WIDTH; i++) begin
      bpu2faq_st_o.valid[i] = i > pc[2:0];
    end
  end
`else
// TODO BPU
`endif

endmodule : BranchPredictionUnit