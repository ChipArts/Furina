// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : IssueQueue.sv
// Create  : 2024-03-13 23:33:22
// Revise  : 2024-03-13 23:33:35
// Description :
//   发射队列
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

module IssueQueue #(
parameter
  int unsigned QUEUE_SIZE = 8,
  int unsigned WPORTS_NUM = 2,
  int unsigned RPORTS_NUM = 2,
  type         DATA_TYPE  = logic [31:0],
  bit          ORDER_ISSUE = 0
)(
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input logic flush_i,

  input logic [WPORTS_NUM - 1:0] write_valid_i,
  output logic [WPORTS_NUM - 1:0] write_ready_o,
  input DATA_TYPE [WPORTS_NUM - 1:0] write_data_i,

  output logic [RPORTS_NUM - 1:0] read_valid_o,
  input logic [RPORTS_NUM - 1:0] read_ready_i,
  output DATA_TYPE [RPORTS_NUM - 1:0] read_data_o
);

endmodule : IssueQueue
