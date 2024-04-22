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
  input logic rst_n,    // Asynchronous reset active low
  input logic flush_i,
  /* exe */
  input MduExeSt exe_i,
  output logic ready_o,
  /* cmt */
  output MduWbSt wb_o,
  input wb_ready_i
);

  logic idle2drv;   // s0
  logic wait2idle;   // s1


  typedef enum logic[1:0] {
    IDEL,  // 计算完成 空闲
    DRIVE, // 驱动MDU开始计算
    WAIT   // 等待计算结果
  } MduState;

  MduState mdu_state;

/*================================== stage0 ===================================*/
  // regfile comb输出 数据缓存一拍
  logic s0_ready, s1_ready;

  always_comb begin
    s0_ready = s1_ready;
    ready_o = s0_ready;

    idle2drv = s1_ready & exe_i.base.valid;
  end

/*================================== stage1 ===================================*/
  MduExeSt s1_exe;
  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      s1_exe <= 0;
    end else begin
      if (s1_ready) begin
        s1_exe <= exe_i;
      end
    end
  end

  MduMultReqSt mult_req;
  MduDivReqSt div_req;
  MduMultRspSt mult_rsp;
  MduDivRspSt div_rsp;

  logic        mdu_res_valid; // ff
  logic [31:0] mdu_res;       // ff

  always_comb begin
    // 没有要处理的任务 或 信息可以向下一级流动
    // 没有需握手的FU
    s1_ready = ~s1_exe.base.valid |                // 无请求
               wb_ready_i &                        // 可以写回
               (mult_rsp.ready & div_rsp.ready) &  // mdu 空闲
               mdu_state == IDEL;                  // fsm 空闲

    // mult
    mult_req.valid = s1_exe.base.valid & mdu_state == DRIVE &
                     (s1_exe.mdu_oc.mdu_op == `MDU_MUL | 
                      s1_exe.mdu_oc.mdu_op == `MDU_MULH);
    mult_req.ready = wb_ready_i;
    mult_req.flush = flush_i;
    mult_req.mul_signed = s1_exe.mdu_oc.signed_op;
    mult_req.multiplicand = s1_exe.base.src0;
    mult_req.multiplier = s1_exe.base.src1;

    // div
    div_req.valid = s1_exe.base.valid & mdu_state == DRIVE &
                    (s1_exe.mdu_oc.mdu_op == `MDU_DIV | 
                     s1_exe.mdu_oc.mdu_op == `MDU_MOD);
    div_req.ready = wb_ready_i;
    div_req.flush = flush_i;
    div_req.div_signed = s1_exe.mdu_oc.signed_op;
    div_req.dividend = s1_exe.base.src0;
    div_req.divisor = s1_exe.base.src1;

    wait2idle = mult_rsp.valid | div_rsp.valid;

    // output
    wb_o.base.valid = mdu_res_valid & mdu_state == IDEL & s1_exe.base.valid;
    wb_o.base.we    = s1_exe.base.pdest_valid;
    wb_o.base.pdest = s1_exe.base.pdest;
    wb_o.base.wdata = mdu_res;
    wb_o.base.rob_idx = s1_exe.base.rob_idx;
  end


  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n || flush_i) begin
      mdu_state <= IDEL;
      mdu_res <= '0;
      mdu_res_valid <= '0;
    end else begin
      case (mdu_state)
        IDEL  : if (idle2drv)  mdu_state <= DRIVE;
        DRIVE :                mdu_state <= WAIT;
        WAIT  : if (wait2idle) mdu_state <= IDEL;
        default : mdu_state <= IDEL;
      endcase

      case (s1_exe.mdu_oc.mdu_op)
        `MDU_MUL  : mdu_res <= mult_rsp.res_lo;
        `MDU_MULH : mdu_res <= mult_rsp.res_hi;
        `MDU_DIV  : mdu_res <= div_rsp.quotient;
        `MDU_MOD  : mdu_res <= div_rsp.remainder;
        default : mdu_res <= '0;
      endcase

      if (s1_ready) begin
        mdu_res_valid <= '0;  // 写回后置零
      end else if (mult_rsp.valid | div_rsp.valid) begin
        mdu_res_valid <= '1;  // 写回前保持
      end
    end
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

endmodule : MduPipe
