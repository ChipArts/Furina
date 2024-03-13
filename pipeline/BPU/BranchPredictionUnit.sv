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
  input BPU_ReqSt bpu_req,
  output BPU_RspSt bpu_rsp
);

  `RESET_LOGIC(clk,  a_rst_n, s_rst_n);

`ifdef NPC
  logic [31:0] pc;
  always @(posedge clk or negedge s_rst_n) begin
    if (!s_rst_n) begin
      pc <= 32'h1c00_0000;
    end
    else begin
      if (bpu_req_st_i.redirect) begin
        pc <= bpu_req_i.target;
      end else begin
        if (bpu_req_st_i.next) begin
          pc <= pc + (`FETCH_WIDTH << 2);
        end
      end
    end
  end

  assign bpu_rsp_st_o.valid = '1;
`else
// TODO BPU
`endif

endmodule : BranchPredictionUnit