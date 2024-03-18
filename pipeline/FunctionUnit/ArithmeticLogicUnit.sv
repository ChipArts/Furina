// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : ArithmeticLogicUnit.sv
// Create  : 2024-03-18 15:21:34
// Revise  : 2024-03-18 17:54:44
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
`include "common.svh"

module ArithmeticLogicUnit (
  input logic clk,    // Clock
  input logic a_rst_n,  // Asynchronous reset active low
  input logic flush_i,
  input logic valid_i,
  input logic [31:0] src0_i,
  input logic [31:0] src1_i,
  input logic unsigned_i,
  input CalcOpType calc_op_i,
  output logic [31:0] res_o,
  output logic valid_o,
  output logic ready_o
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

  // 加减和逻辑运算
  logic [31:0] alu_res;
  logic alu_valid;

  always_ff @(posedge clk or negedge rst_n) begin : proc_alu_res
    if(~rst_n) begin
      alu_res <= 0;
      alu_valid <= 0;
    end else begin
      alu_valid <= valid_i;
      case (calc_op_i)
        `CALC_OP_ADD  : begin
            alu_res <= src0_i + src1_i;
        end
        `CALC_OP_SUB  : begin
            alu_res <= src0_i - src1_i;
        end
        `CALC_OP_SLT  : begin
            alu_res[31:1] = 31'b0;
            if (unsigned_i) begin
              alu_res[0] <= src0_i < src1_i;
            end else begin
              alu_res[0] <= $signed(src0_i) < $signed(src1_i);
            end
        end
        `CALC_OP_AND  : begin
            alu_res <= src0_i & src1_i;
        end
        `CALC_OP_OR   : begin
            alu_res <= src0_i | src1_i;
        end
        `CALC_OP_XOR  : begin
            alu_res <= src0_i ^ src1_i;
        end
        `CALC_OP_NOR  : begin
            alu_res <= ~(src0_i | src1_i);
        end
        `CALC_OP_SL   : begin
            alu_res <= src0_i << src1_i[4:0];
        end
        `CALC_OP_SR   : begin
            if (unsigned_i) begin
                alu_res <= src0_i >> src1_i[4:0];
            end else begin
                alu_res <= $signed($signed(src0_i) >>> $signed(src1_i[4:0]));
            end
        end
        `CALC_OP_LUI  : begin
            alu_res <= src1_i;
        end
        default : begin
            alu_res <= 0;
        end
      endcase
    end
  end



  // 乘除法运算
  MDU_MultReqSt mult_req;
  MDU_DivReqSt div_req;
  MDU_MultRspSt mult_rsp;
  MDU_DivRspSt div_rsp;

  always_comb begin
    mult_req.ready = '1;
    mult_req.valid = valid_i & 
                    (calc_op_i == `CALC_OP_MUL |
                     calc_op_i == `CALC_OP_MULH);
    mult_req.multiplicand = src0_i;
    mult_req.multiplier = src1_i;
    mult_req.mul_signed = ~unsigned_i;
    mult_req.flush = flush_i;


    div_req.ready = '1;
    div_req.valid = valid_i & 
                    (calc_op_i == `CALC_OP_DIV |
                     calc_op_i == `CALC_OP_MOD);
    div_req.dividend = src0_i;
    div_req.divisor = src1_i;
    div_req.div_signed = ~unsigned_i;
    div_req.flush = flush_i;
  end

  MultDivUnit U_MultDivUnit
  (
    .clk           (clk),
    .a_rst_n       (a_rst_n),
    .mult_req_st_i (mult_req),
    .div_req_st_i  (div_req),
    .mult_rsp_st_o (mult_rsp),
    .div_rsp_st_o  (div_rsp)
  );

  always_comb begin
    if (calc_op_i < `CALC_OP_MUL) begin
      res_o = alu_res;
    end else begin
      case (calc_op_i)
        `CALC_OP_MUL  : begin
          res_o = mult_rsp.res_lo;
        end
        `CALC_OP_MULH : begin
          res_o = mult_rsp.res_hi;
        end
        `CALC_OP_DIV  : begin
          res_o = div_rsp.quotient;
        end
        `CALC_OP_MOD  : begin
          res_o = div_rsp.remainder;
        end
        default : /* default */;
      endcase
    end
    ready_o = mult_rsp.ready & div_rsp.ready;  // add/sub/logic always ready
    valid_o = mult_rsp.valid | div_rsp.valid | alu_valid;
  end


endmodule : ArithmeticLogicUnit