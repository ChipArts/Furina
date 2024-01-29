// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : RegBasedMultiPortRAM.sv
// Create  : 2024-01-15 20:00:10
// Revise  : 2024-01-15 20:00:10
// Description :
//   基于Reg的多端口寄存器RAM
// Parameter   :
//   ...
//   ...
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// 24-01-15 |            |     0.1     |    Original Version
// ==============================================================================


`include "common.svh"

module RegBasedMultiPortRAM #(
parameter
  READ_PORT_NUM = 2,
  WRITE_PORT_NUM = 1,
  DATA_WIDTH = 64,
  DATA_DEPTH = 32,
localparam
  ADDR_WIDTH = $clog2(DATA_DEPTH)
)(
  input clk,       // Clock
  input a_rst_n,   // Asynchronous reset active low
  input [WRITE_PORT_NUM - 1:0] we_i,
  input [WRITE_PORT_NUM - 1:0][ADDR_WIDTH - 1:0] waddr_i,
  input [READ_PORT_NUM - 1:0][ADDR_WIDTH - 1:0] raddr_i,
  input [WRITE_PORT_NUM - 1:0][DATA_WIDTH - 1:0] data_i,
  output logic [READ_PORT_NUM - 1:0][DATA_WIDTH - 1:0] data_o
);

  `RESET_LOGIC(clk, a_rst_n, s_rst_n)

  logic [(1 << ADDR_WIDTH) - 1:0][DATA_WIDTH - 1:0] memory;
  always @(posedge clk or negedge s_rst_n) begin
    if (!s_rst_n) begin
      data_o <= '0;
    end
    else begin
      foreach (waddr_i[i]) begin
        if (we_i[i]) begin
          memory[waddr_i[i]] <= data_i[i];
        end
      end
    end
    // TODO: try output with latch
    foreach (raddr_i[i]) begin
      data_o[i] <= waddr_i[i] == raddr_i[i] && we_i[i] ? data_i[i] : memory[raddr_i[i]];
    end
  end

endmodule : RegBasedMultiPortRAM


