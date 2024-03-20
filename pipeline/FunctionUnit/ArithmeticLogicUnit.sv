// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : ArithmeticLogicUnit.sv
// Create  : 2024-03-18 15:21:34
// Revise  : 2024-03-20 18:40:12
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

`include "Decoder.svh"

module ArithmeticLogicUnit (
  input logic [31:0] src0_i,
  input logic [31:0] src1_i,
  input logic signed_i,
  input AluOpType alu_op_i,
  output logic [31:0] res_o
);

  // 加减和逻辑运算
  logic [31:0] alu_res;
  logic alu_valid;

  always_comb begin
    case (alu_op_i)
        `ALU_ADD  : begin
            alu_res = src0_i + src1_i;
        end
        `ALU_SUB  : begin
            alu_res = src0_i - src1_i;
        end
        `ALU_SLT  : begin
            alu_res[31:1] = 31'b0;
            if (signed_i) begin
              alu_res[0] = $signed(src0_i) < $signed(src1_i);
            end else begin
              alu_res[0] = src0_i < src1_i;
            end
        end
        `ALU_AND  : begin
            alu_res = src0_i & src1_i;
        end
        `ALU_OR   : begin
            alu_res = src0_i | src1_i;
        end
        `ALU_XOR  : begin
            alu_res = src0_i ^ src1_i;
        end
        `ALU_NOR  : begin
            alu_res = ~(src0_i | src1_i);
        end
        `ALU_SL   : begin
            alu_res = src0_i << src1_i[4:0];
        end
        `ALU_SR   : begin
            if (signed_i) begin
              alu_res = $signed($signed(src0_i) >>> $signed(src1_i[4:0]));
            end else begin
              alu_res = src0_i >> src1_i[4:0];
            end
        end
        `ALU_LUI  : begin
            alu_res = src1_i;
        end
        default : begin
            alu_res = 0;
        end
      endcase
  end


endmodule : ArithmeticLogicUnit