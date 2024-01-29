// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : NPC.sv
// Create  : 2024-01-13 20:21:19
// Revise  : 2024-01-13 20:21:52
// Description :
//   朴实无华的NPC
// Parameter   :
//    ...
//    ...
// IO Port     :
//    ...
//    ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// 24-01-13 |            |     0.1     |    Original Version
// ==============================================================================

`include "common.svh"

module NPC (
  input clk,      // Clock
  input a_rst_n,  // Asynchronous reset active low
  input taken_i,
  input [63:0] target_i,
  output reg [63:0] pc_o
);

  `RESET_LOGIC(a_rst_n, s_rst_n);

  wire [63:0] npc = taken_i ? target_i : pc_o + 4;

  always @(posedge clk or negedge s_rst_n) begin
    if (!s_rst_n) begin
      pc_o <= 64'h1c00_0000;
    end
    else begin
      pc_o <= npc;
    end
  end

endmodule : NPC