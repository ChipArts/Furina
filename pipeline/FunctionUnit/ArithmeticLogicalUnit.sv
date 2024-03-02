// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : ArithmeticLogicalUnit.sv
// Create  : 2024-03-02 22:26:01
// Revise  : 2024-03-02 22:26:01
// Description :
//   ALU
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

module ArithmeticLogicalUnit (
  input logic [31:0] a,
  input logic [31:0] b,
  input logic [2:0] alu_option,
  input logic unsigned_option_data,
  output logic [31:0] c
);

  always_comb begin
    case (alu_option)
        `ALU_TYPE_ADD  : begin
            c = a + b;
        end
        `ALU_TYPE_SUB  : begin
            c = a - b;
        end
        `ALU_TYPE_SLT  : begin
            c[31:1] = 31'b0;
            if (unsigned_option_data) begin
                c[0] = a < b;
            end else begin 
                c[0] = $signed(a) < $signed(b);
            end
        end
        `ALU_TYPE_AND  : begin
            c = a & b;
        end
        `ALU_TYPE_OR   : begin
            c = a | b;
        end
        `ALU_TYPE_XOR  : begin
            c = a ^ b;
        end
        `ALU_TYPE_NOR  : begin
            c = ~(a | b);
        end
        `ALU_TYPE_SL   : begin
            c = a << b[4:0];
        end
        `ALU_TYPE_SR   : begin
            if (unsigned_option_data) begin
                c = a >> b[4:0];
            end else begin
                c = $signed($signed(a) >>> $signed(b[4:0]));
            end
        end
        `ALU_TYPE_LUI  : begin
            c = b;
        end
        default : begin
            c = 0;
        end
    endcase
  end

endmodule : ArithmeticLogicalUnit

