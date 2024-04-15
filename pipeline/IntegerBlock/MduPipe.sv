// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : MduPipe.sv
// Create  : 2024-03-20 22:53:44
// Revise  : 2024-03-29 17:48:53
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
`include "Pipeline.svh"
`include "MultDivUnit.svh"

module MduPipe (
  input logic clk,      // Clock
  input logic a_rst_n,  // Asynchronous reset active low
  input logic flush_i,
  /* exe */
  input MduExeSt exe_i,
  output logic ready_o,
  /* cmt */
  output MduWbSt wb_o,
  input wb_ready_i
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

/*================================== stage0 ===================================*/
  // regfile comb输出 数据缓存一拍
  logic s0_ready, s1_ready, s2_ready;

  always_comb begin
    s0_ready = s1_ready;
    ready_o = s0_ready;
  end

/*================================== stage1 ===================================*/
  MduExeSt s1_exe;
  MduMultReqSt mult_req;
  MduDivReqSt div_req;
  MduMultRspSt mult_rsp;
  MduDivRspSt div_rsp;
  logic [31:0] mdu_res;

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      s1_exe <= 0;
    end else begin
      s1_exe <= exe_i;
    end
  end

  always_comb begin
    // 没有要处理的任务 或 信息可以向下一级流动
    // 没有需握手的FU
    s1_ready = s2_ready & (mult_rsp.ready & div_rsp.ready) | ~s1_exe.base.valid;

    mult_req.valid = s1_exe.base.valid;
    mult_req.ready = '1;
    mult_req.flush = flush_i;
    mult_req.mul_signed = s1_exe.mdu_oc.signed_op;
    mult_req.multiplicand = s1_exe.base.src0;
    mult_req.multiplier = s1_exe.base.src1;

    div_req.valid = s1_exe.base.valid;
    div_req.ready = '1;
    div_req.flush = flush_i;
    div_req.div_signed = s1_exe.mdu_oc.signed_op;
    div_req.dividend = s1_exe.base.src0;
    div_req.divisor = s1_exe.base.src1;

    case (s1_exe.mdu_oc.mdu_op)
      `MDU_MUL : mdu_res = mult_rsp.res_lo;
      `MDU_MULH : mdu_res = mult_rsp.res_hi;
      `MDU_DIV : mdu_res = div_rsp.quotient;
      `MDU_MOD : mdu_res = div_rsp.remainder;
      default : mdu_res = '0;
    endcase
  end

  MultDivUnit U_MultDivUnit
  (
    .clk      (clk),
    .a_rst_n  (rst_n),
    .mult_req (mult_req),
    .div_req  (div_req),
    .mult_rsp (mult_rsp),
    .div_rsp  (div_rsp)
  );

/*================================== stage2 ===================================*/
  // wait for mdu res valid
  always_comb begin
    s2_ready = wb_ready_i | ~wb_o.base.valid;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wb_o <= '0;
    end else begin
      if (wb_ready_i) begin
        wb_o.base.valid <= mult_rsp.valid | div_rsp.valid;
        wb_o.base.we <= mult_rsp.valid | div_rsp.valid & s1_exe.base.pdest_valid;
        wb_o.base.pdest <= s1_exe.base.pdest;
        wb_o.base.wdata <= mdu_res;
      end
    end
  end

endmodule : MduPipe
