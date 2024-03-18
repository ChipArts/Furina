// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : MultDivUnit.sv
// Create  : 2024-03-03 18:20:21
// Revise  : 2024-03-18 17:42:06
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
  input MDU_MultReqSt mult_req_st_i,
  input MDU_DivReqSt div_req_st_i,
  output MDU_MultRspSt mult_rsp_st_o,
  output MDU_DivRspSt div_rsp_st_o
);

`ifdef DIST_DRIVE_RESET
  `RESET_LOGIC(clk, a_rst_n, rst_n);
`else
  wire rst_n = a_rst_n;
`endif

  Divider U_Divider
  (
    .clk          (clk),
    .a_rst_n      (a_rst_n),
    .flush_i      (div_req_st_i.flush),
    .div_valid_i  (div_req_st_i.valid),
    .div_ready_o  (div_rsp_st_o.ready),
    .res_valid_o  (div_rsp_st_o.valid),
    .res_ready_i  (div_req_st_i.ready),
    .div_signed_i (dev_req_st_i.div_signed),
    .dividend_i   (div_req_st_i.dividend),
    .divisor_i    (div_req_st_i.divisor),
    .quotient_o   (div_rsp_st_o.quotient),
    .remainder_o  (div_rsp_st_o.remainder)
  );

  Multiplier U_Multiplier
  (
    .clk          (clk),
    .a_rst_n      (a_rst_n),
    .flush_i      (mult_req_st_i.flush),
    .mul_valid_i  (mult_req_st_i.valid),
    .mul_ready_o  (mult_rsp_st_o.ready),
    .res_valid_o  (mult_rsp_st_o.valid),
    .res_ready_i  (mult_req_st_i.ready),
    .mul_signed_i (mult_req_st_i.mul_signed),
    .multiplicand_i(mult_req_st_i.multiplicand),
    .multiplier_i (mult_req_st_i.multiplier),
    .res_o        ({mult_rsp_st_o.res_hi, mult_rsp_st_o.res_lo})
  );

endmodule : MultDivUnit
