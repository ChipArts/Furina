// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Multiplier.sv
// Create  : 2024-03-03 21:00:28
// Revise  : 2024-03-03 21:00:28
// Description :
//   华莱士树乘法器
//   划分了3级流水（booth部分积 | wallace树 | 68位加法器）
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

`include "common.svh"
`include "config.svh"

module Multiplier (
  input logic clk,
  input logic a_rst_n,

  input logic flush_i,
  input  logic mul_valid_i,
  output logic mul_ready_o,
  output logic res_valid_o,
  input  logic res_ready_i,

  input  logic mul_signed_i,
  input  logic [31:0] multiplicand_i,
  input  logic [31:0] multiplier_i,
  output logic [63:0] res_o
);

`ifdef DIST_DRIVE_RESET
  `RESET_LOGIC(clk, a_rst_n, rst_n);
`else
  wire rst_n = a_rst_n;
`endif


  typedef struct packed {
    logic [16:0] booth_carry;
    logic [63:0] wallace_c, wallace_s;
  } mul_flow_t;

  mul_flow_t mul_stage_2, mul_stage_3;

  /*======= fsm's state of multipiler =======*/
  typedef enum logic [1:0] {
    BOOTH,
    WALLACE,
    ADD
  } MulStatusEnum;
  
  MulStatusEnum mul_status;

  always_ff @(posedge clk or negedge rst_n) begin : proc_fsm
    if(~rst_n || flush_i) begin
      mul_status <= BOOTH;
    end else begin
      case (mul_status)
        BOOTH : if (mul_valid_i) mul_status <= WALLACE;
        WALLACE : mul_status <= ADD;
        ADD : mul_status <= BOOTH;
        default : /* default */;
      endcase
    end
  end

  // handshake signals
  assign mul_ready_o = (mul_status == BOOTH) | (res_valid_o & res_ready_i);
  assign res_valid_o = (mul_status == ADD);

  ////////////////// Stage 1 //////////////////

  /*======= deal with sign =======*/
  logic [67:0] faciend_X;
  logic [33:0] factor_Y;
  assign faciend_X = mul_signed_i ? {{36{multiplicand_i[31]}}, multiplicand_i} : {36'b0, multiplicand_i};
  assign factor_Y  = mul_signed_i ? {{ 2{multiplier_i[31]}}, multiplier_i} : { 2'b0, multiplier_i};


  /*======= generate booth part products =======*/
  logic [16:0][67:0] booth_product;   // has 17 part products
  logic [16:0] booth_carry;
  Booth #(
      .FACIEND_WIDTH(68)
  ) U0_Booth (
      .y({factor_Y[1:0], 1'b0}), 
      .X(faciend_X),
      // output
      .P(booth_product[0]), 
      .carry(booth_carry[0])
  );

  generate
      for (genvar i = 2; i < 34; i = i + 2) begin
          /* other 16 booth */
          Booth #(
              .FACIEND_WIDTH(68)
          ) U_Booth (
              .y(factor_Y[i+1 : i-1]), 
              .X(faciend_X << i),
              // output
              .P(booth_product[i >> 1]), 
              .carry(booth_carry[i >> 1])
          );     
      end
  endgenerate

  ////////////////// Stage 2 //////////////////

  /*======= switch signal, prepared to enter wallace tree =======*/
  logic [67:0][16:0] wallace_datain; // 17 numbers add together, each has 68 bits 
  // also, enter stage 2
  always_ff @(posedge clk or negedge rst_n) begin
      if (~rst_n || flush_i) begin
          wallace_datain <= 0;
          mul_stage_2 <= 0;
      end else begin
          for (int i = 0; i < 68; i = i + 1) begin
              for (int j = 0; j < 17; j = j + 1) begin
                  wallace_datain[i][j] <= booth_product[j][i];
              end
          end
          mul_stage_2.booth_carry <= booth_carry;
      end
  end

  /*======= through wallace tree =======*/
  logic [67:0][13:0] wallace_carrypath; // ...[67] is useless 
  logic [67:0] wallace_c, wallace_s;
  WallaceTree U0_WallaceTree (
      .in(wallace_datain[0]),
      .c_i(mul_stage_2.booth_carry[13:0]),
      // output
      .c_o(wallace_carrypath[0]),
      .c(wallace_c[0]),
      .s(wallace_s[0])
  );

  generate
      for (genvar i = 1; i < 68; i = i + 1) begin
          WallaceTree U_WallaceTree(
              .in(wallace_datain[i]),
              .c_i(wallace_carrypath[i-1]),
              // output
              .c_o(wallace_carrypath[i]),
              .c(wallace_c[i]),
              .s(wallace_s[i])
          );
      end
  endgenerate

  ////////////////// Stage 3 //////////////////
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n || flush_i) begin
        mul_stage_3 <= 0;
    end else begin
        mul_stage_3.booth_carry <= mul_stage_2.booth_carry;
        mul_stage_3.wallace_c <= wallace_c[63:0];
        mul_stage_3.wallace_s <= wallace_s[63:0];
    end
  end

  /*======= final 68bit add, and select [63:0] part =======*/
  assign res_o = {mul_stage_3.wallace_c[62:0], mul_stage_3.booth_carry[14]} + 
                  mul_stage_3.wallace_s + 
                 {62'b0, mul_stage_3.booth_carry[15]};
endmodule
