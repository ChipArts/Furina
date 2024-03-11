// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Pipeline.sv
// Create  : 2024-03-11 14:53:30
// Revise  : 2024-03-11 15:30:05
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


  /* BPU */

  BranchPredictionUnit U_BranchPredictionUnit (
    .clk(clk), 
    .a_rst_n(a_rst_n), 
    .bpu_req(bpu_req), 
    .bpu_rsp(bpu_rsp)
  );

  /* Fetch Address Queue */

  /* Instruction Fetch Unit */

endmodule : Pipeline



