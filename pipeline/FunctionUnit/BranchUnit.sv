// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : BranchUnit.sv
// Create  : 2024-03-18 19:39:57
// Revise  : 2024-03-18 21:17:07
// Description :
//   分支单元
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
`include "common.svh"
`include "Decoder.svh"

module BranchUnit (
  input logic valid_i,                      // 是一条分支指令
  input logic signed_i,
  input logic [`PROC_VALEN - 1:0] pc_i, 
  input logic [`PROC_VALEN - 1:0] npc_i,    // 预测的下一条指令地址
  input logic [31:0] imm_i,
  input logic [31:0] src0_i,
  input logic [31:0] src1_i,
  input logic indirect_i,
  input BranchOpType branch_op_i,
  output logic redirect_o,
  output logic [`PROC_VALEN - 1:0] target_o,
  output logic taken_o
);

  logic [`PROC_VALEN - 1:0] target;
  logic redirect, taken;

  always_comb begin
    case (branch_op_i)
      `BRANCH_EQ  : taken = src1_i == src0_i;
      `BRANCH_NE  : taken = src1_i != src0_i;
      `BRANCH_LT  : begin
        if(signed_i) begin
          taken = $signed(src1_i) < $signed(src0_i);
        end else begin
          taken = src1_i < src0_i;
        end
      end
      `BRANCH_GE  : begin
        if(signed_i) begin
          taken = $signed(src1_i) >= $signed(src0_i);
        end else begin
          taken = src1_i >= src0_i;
        end
      end
      `BRANCH_NC  : taken = '1;
      default: taken = '0;
    endcase

    taken = taken & valid_i;

    if (taken) begin
      target = indirect_i ? src0_i + (imm_i << 2) : pc_i + (imm_i << 2);
    end else begin
      target = pc_i + 4;
    end

    redirect = target != npc_i;
  end

  always_comb begin
    taken_o = taken;
    target_o = target;
    redirect_o = redirect;
  end

endmodule : BranchUnit

