// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : AluPipe.sv
// Create  : 2024-03-20 17:36:40
// Revise  : 2024-03-20 17:36:47
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
// ==============================================================================

`include "config.svh"
`include "Decoder.svh"
`include "common.svh"
`include "Pipeline.svh"

module AluPipe (
  input clk,      // Clock
  input a_rst_n,  // Asynchronous reset active low
  /* exe */
  input AluExeSt exe_i,
  output logic ready_o,
  /* commit */
  output AluWbSt wb_o,
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
  AluExeSt s1_exe;
  logic alu_res;
  always_comb begin
    // 没有要处理的任务 或 信息可以向下一级流动
    // 没有需握手的FU
    s1_ready = s2_ready | ~s1_exe.base.valid;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      s1_exe <= '0;
    end else begin
      s1_exe <= exe_i;
    end
  end

  ArithmeticLogicUnit inst_ArithmeticLogicUnit
  (
    .src0_i   (s1_exe.base.src0),
    .src1_i   (s1_exe.alu_oc.imm_valid ? s1_exe.alu_oc.imm : s1_exe.base.src1),
    .signed_i (s1_exe.alu_oc.signed_op),
    .alu_op_i (s1_exe.alu_oc.alu_op),
    .res_o    (alu_res)
  );


/*================================== stage2 ===================================*/
  
  always_comb begin
    s2_ready = wb_ready_i | ~wb_o.base.valid;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      wb_o <= '0;
    end else begin
      if(s2_ready) begin
        wb_o.base.valid <= s1_exe.base.valid;
        wb_o.base.we <= s1_exe.base.valid;
        wb_o.base.wdata <= alu_res;
        wb_o.base.pdest <= s1_exe.base.pdest;
        wb_o.base.rob_idx <= s1_exe.base.rob_idx;
      end
    end
  end

endmodule : AluPipe
