// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : BranchPredictionUnit.sv
// Create  : 2024-02-12 15:35:06
// Revise  : 2024-03-13 17:57:33
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

module BranchPredictionUnit (
  input logic clk,    // Clock
  input logic a_rst_n,  // Asynchronous reset active low
  input BpuReqSt bpu_req,
  output BpuRspSt bpu_rsp
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);
  localparam NPC_OFS = $clog2(`FETCH_WIDTH) + 2;

`ifdef NPC
  logic [31:0] pc, npc;

  assign npc = bpu_req.redirect ? bpu_req.target : 
               bpu_req.next ? {pc[31:NPC_OFS] + 1, {NPC_OFS{1'b0}}} : 
               pc;


  always_comb begin

    bpu_rsp.pc = {pc[31:NPC_OFS], {NPC_OFS{1'b0}}};
    bpu_rsp.npc = npc;
    bpu_rsp.valid = '1 & {`FETCH_WIDTH{bpu_req.next}};
    for (int i = 0; i < `FETCH_WIDTH; i++) begin
      if (i < pc[NPC_OFS - 1:2]) begin
        bpu_rsp.valid[i] = '0;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc <= 32'h1c00_0000;
    end else begin
      pc <= npc;
    end
  end
`else
// TODO BPU
`endif

endmodule : BranchPredictionUnit
