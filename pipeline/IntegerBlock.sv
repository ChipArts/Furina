// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : IntegerBlock.sv
// Create  : 2024-03-17 22:34:32
// Revise  : 2024-03-18 23:43:05
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

module IntegerBlock (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input flush_i,
  /* issue */
  // misc(BRU/Priv) * 1
  output MiscIssueInfoSt misc_issue_info_o,
  input logic misc_ready_i,
  // ALU * 2
  output AluIssueInfoSt alu_issue_info_o,
  input logic [1:0] alu_ready_i,

  /* commit */
  // MISC
  input ROB_EntrySt rob_oldest_entry_i,
  // ALU * 2
  logic [1:0] alu_commit_o,
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);


  // misc
  logic branch_taken;
  BranchUnit inst_BranchUnit
  (
    .clk         (clk),
    .a_rst_n     (rst_n),
    .flush_i     (flush_i),
    .valid_i     (valid_i),
    .unsigned_i  (unsigned_i),
    .pc_i        (pc_i),
    .npc_i       (npc_i),
    .imm_i       (imm_i),
    .src0_i      (src0_i),
    .src1_i      (src1_i),
    .indirect_i  (indirect_i),
    .branch_op_i (branch_op_i),
    .valid_o     (valid_o),
    .redirect_o  (redirect_o),
    .target_o    (target_o),
    .taken_o     (taken_o)
  );


  // alu * 2
  logic [1:0] alu_valid_o;
  logic [1:0][31:0] alu_res;

  for (genvar i = 0; i < 2; i++) begin
    ArithmeticLogicUnit U_ArithmeticLogicUnit
    (
      .clk        (clk),
      .a_rst_n    (rst_n),
      .flush_i    (flush_i),
      .valid_i    (alu_valid_i[i]),
      .src0_i     (alu_src0_i[i]),
      .src1_i     (alu_option_code_i[i].use_imm ? alu_imm_i[i] : alu_src1_i),
      .unsigned_i (alu_option_code_i[i].calc_unsigned),
      .calc_op_i  (alu_option_code_i[i].calc_op),
      .res_o      (alu_res[i]),
      .valid_o    (alu_valid_o[i]),
      .ready_o    (alu_ready_o[i])
    );
  end

endmodule : IntegerBlock

