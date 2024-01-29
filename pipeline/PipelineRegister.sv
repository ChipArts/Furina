// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : PipelineRegister.sv
// Create  : 2024-01-16 19:49:55
// Revise  : 2024-01-16 19:49:55
// Description :
//   流水线寄存器
// Parameter   :
//   ...
//   ...
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// 24-01-16 |            |     0.1     |    Original Version
// ==============================================================================

`include "common.svh"

module PipelineRegister #(
parameter
  type DATA_TYPE = logic [32:0]
)(
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input we_i,
  input DATA_TYPE data_i,
  output DATA_TYPE data_0
);

 `RESET_LOGIC(clk, a_rst_n, s_rst_n)

  DATA_TYPE pipeline_reg;
  always_ff @(posedge clk or negedge s_rst_n) begin
    if (~s_rst_n) begin
      pipeline_reg <= '0;
    end
    else begin
      if (we_i) begin
        pipeline_reg <= data_i;
      end
    end
  end

  assign data_0 = pipeline_reg;

endmodule : PipelineRegister
