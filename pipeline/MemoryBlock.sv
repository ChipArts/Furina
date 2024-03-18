// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : MemoryBlock.sv
// Create  : 2024-03-17 22:34:12
// Revise  : 2024-03-18 16:49:39
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
`include "Decoder.svh"

module MemoryBlock (
  input clk,    // Clock
  input rst_n,  // Asynchronous reset active low
  input logic mem_valid_o,
  output logic mem_ready_i,
  input logic [31:0] mem_imm_o,
  input logic [$clog2(`PHY_REG_NUM) - 1:0] mem_psrc0, mem_psrc1,
  input MemoryOptionCodeSt mem_option_code_o
);

endmodule : MemoryBlock

