// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : MultDivUnit.sv
// Create  : 2024-03-03 18:20:21
// Revise  : 2024-03-20 23:00:37
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
`include "common.svh"
`include "MultDivUnit.svh"

module MultDivUnit (
  input logic clk,    // Clock
  input logic a_rst_n,  // Asynchronous reset active low
  input MduMultReqSt mult_req,
  input MduDivReqSt div_req,
  output MduMultRspSt mult_rsp,
  output MduDivRspSt div_rsp
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);


  Divider U_Divider
  (
    .clk          (clk),
    .a_rst_n      (rst_n),
    .flush_i      (div_req.flush),
    .div_valid_i  (div_req.valid),
    .div_ready_o  (div_rsp.ready),
    .res_valid_o  (div_rsp.valid),
    .res_ready_i  (div_req.ready),
    .div_signed_i (div_req.div_signed),
    .dividend_i   (div_req.dividend),
    .divisor_i    (div_req.divisor),
    .quotient_o   (div_rsp.quotient),
    .remainder_o  (div_rsp.remainder)
  );

  Multiplier U_Multiplier
  (
    .clk          (clk),
    .a_rst_n      (rst_n),
    .flush_i      (mult_req.flush),
    .mul_valid_i  (mult_req.valid),
    .mul_ready_o  (mult_rsp.ready),
    .res_valid_o  (mult_rsp.valid),
    .res_ready_i  (mult_req.ready),
    .mul_signed_i (mult_req.mul_signed),
    .multiplicand_i(mult_req.multiplicand),
    .multiplier_i (mult_req.multiplier),
    .res_o        ({mult_rsp.res_hi, mult_rsp.res_lo})
  );

endmodule : MultDivUnit
