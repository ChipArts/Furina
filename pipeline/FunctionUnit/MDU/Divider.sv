// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Divider.sv
// Create  : 2024-03-03 17:59:28
// Revise  : 2024-03-03 18:01:57
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
// 24-03-03 |            |     0.1     |    Original Version
// ==============================================================================
`include "config.svh"
`include "common.svh"

module Divider (
  input logic clk,
  input logic a_rst_n,

  input  logic div_valid_i,
  output logic div_ready_o,
  output logic res_valid_o,
  input  logic res_ready_i,

  input  logic div_signed_i,
  input  logic [31:0] dividend_i,
  input  logic [31:0] divisor_i,
  output logic [31:0] quotient_o,
  output logic [31:0] remainder_o
);


`ifdef DIST_DRIVE_RESET
  `RESET_LOGIC(clk, a_rst_n, rst_n);
`else
  wire rst_n = a_rst_n;
`endif

  /*======= deal with operands' sign =======*/
  logic [31:0] dividend_absZ, divisor_absD;
  logic opp_q, opp_s; // need opposite at last
  /* e.g.
      dividend_i   divisor_i   quotient_o   remainder_o
       5  /  3  =  1 ... 2
       5  / -3  = -1 ... 2
      -5  /  3  = -1 ...-2
      -5  / -3  =  1 ...-2
  */
  assign opp_q = (dividend_i[31] ^ divisor_i[31]) & div_signed_i;
  assign opp_s = dividend_i[31] & div_signed_i;
  // change to abs() form, change back at the end
  assign dividend_absZ = (div_signed_i & dividend_i[31]) ? ~dividend_i + 1'b1 : dividend_i;
  assign divisor_absD  = (div_signed_i & divisor_i[31]) ? ~divisor_i + 1'b1 : divisor_i;


  /*======= auxiliary signals for divider =======*/
  logic [31:0] timer;

  logic [63:0] abs_A64, abs_64B;
  assign abs_A64 = {32'b0, dividend_absZ};
  assign abs_64B = {divisor_absD,  32'b0};

  logic      [66:0] tmpA;
  logic [2:0][66:0] tmpB, partial_sub;
  for (genvar i = 0; i < 3; i += 1) begin
    assign partial_sub[i] = (tmpA << 2) - tmpB[i];
  end

  /*======= fsm's state of divider =======*/
  localparam S_DIV_IDLE = 0;
  localparam S_DIV_BUSY = 1;
  logic div_status;

  always_ff @(posedge clk or negedge rst_n) begin : div_fsm
    if (~rst_n) begin
      div_status <= S_DIV_IDLE;
    end
    else begin
      case (div_status)
        S_DIV_IDLE: begin
          if (div_valid_i & div_ready_o) begin
            div_status <= S_DIV_BUSY;
          end
        end
        S_DIV_BUSY: begin
          if (res_valid_o & res_ready_i) begin
            // slave get result and master can receive
            if (div_valid_i & div_ready_o) begin
              div_status <= S_DIV_BUSY;
            end
            else begin
              div_status <= S_DIV_IDLE;
            end
          end
          /* otherwise, status will stall at S_DIV_BUSY.
           * As timer be zero, res_valid_o should remain high,
           * then div_ready_o remains low, so timer won't regresh.
           *   ==> waiting for res_ready_i from master */
        end
        default:
          ;
      endcase
    end
  end

  /* handshake signals are all wires */
  assign div_ready_o = (div_status == S_DIV_IDLE) | (res_valid_o & res_ready_i);
  assign res_valid_o = (div_status == S_DIV_BUSY) & ~timer[0];

  /*======= divide process =======*/
  always_ff @(posedge clk or negedge rst_n) begin : div_process
    if (~rst_n) begin
      timer <= 0;
    end
    else begin
      if (div_valid_i & div_ready_o) begin
        timer <= 32'hffff_ffff;
        tmpA  <= {3'b0, abs_A64};
        tmpB[0] <= {3'b0, abs_64B};
        tmpB[1] <= {3'b0, abs_64B} << 1;
        tmpB[2] <= {3'b0, abs_64B} + ({3'b0, abs_64B} << 1);
        // priority: '+' higher than '<<'
      end
      else if (timer[15] & tmpA[47:16] < tmpB[0][63:32]) begin
        timer <= timer >> 16;
        tmpA  <= tmpA << 16;
      end
      else if (timer[7]  & tmpA[55:24] < tmpB[0][63:32]) begin
        timer <= timer >> 8;
        tmpA  <= tmpA << 8;
      end
      else if (timer[3]  & tmpA[59:28] < tmpB[0][63:32]) begin
        timer <= timer >> 4;
        tmpA  <= tmpA << 4;
      end
      else if (timer[0]) begin
        timer <= timer >> 2;
        tmpA  <= (~partial_sub[2][66]) ? partial_sub[2] + 3 :
              (~partial_sub[1][66]) ? partial_sub[1] + 2 :
              (~partial_sub[0][66]) ? partial_sub[0] + 1 :
              tmpA << 2;
      end
    end
  end

  assign quotient_o = opp_q ? ~tmpA[31: 0] + 1 : tmpA[31: 0];
  assign remainder_o = opp_s ? ~tmpA[63:32] + 1 : tmpA[63:32];

endmodule : Divider
