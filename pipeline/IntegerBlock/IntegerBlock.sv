// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : IntegerBlock.sv
// Create  : 2024-03-17 22:34:32
// Revise  : 2024-03-30 21:32:09
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
`include "ReorderBuffer.svh"

module IntegerBlock (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input flush_i,
  /* exe */
  // MISC(BRU/Priv) * 1
  input MiscExeSt misc_exe_i,
  output logic misc_ready_o,
  // ALU * 2
  input AluExeSt [1:0] alu_exe_i,
  output logic [1:0] alu_ready_o,
  // MDU * 1
  input MduExeSt mdu_exe_i,
  output logic mdu_ready_o,
  /* other exe io */
  output logic tlbsrch_valid_o,
  input logic tlbsrch_found_i,
  input logic [$clog2(`TLB_ENTRY_NUM) - 1:0] tlbsrch_idx_i,
  input logic [31:0] tlbehi_i ,
  input logic [31:0] tlbelo0_i,
  input logic [31:0] tlbelo1_i,
  input logic [31:0] tlbidx_i ,
  input logic [ 9:0] tlbasid_i,
  input logic [63:0] timer_64,
  input logic [31:0] timer_id,
  input logic [31:0] csr_rdata_i,
  /* commit */
  // MISC
  output MiscCmtSt misc_cmt_o,
  input logic misc_cmt_ready_i,
  // ALU * 2
  output AluCmtSt [1:0] alu_cmt_o,
  input logic [1:0] alu_cmt_ready_i,
  // MDU
  output MduCmtSt mdu_cmt_o,
  input logic mdu_cmt_ready_i
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

/*=================================== MSIC ====================================*/
  MiscPipe inst_MiscPipe
  (
    .clk         (clk),
    .rst_n       (rst_n),
    .flush_i     (flush_i),
    .exe_i       (misc_exe_i),
    .ready_o     (misc_ready_o),
    .tlbsrch_valid_o(tlbsrch_valid_o),
    .tlbsrch_found_i(tlbsrch_found_i),
    .tlbsrch_idx_i  (tlbsrch_idx_i),
    .tlbrd_valid_o  (tlbrd_valid_o),
    .tlbehi_i       (tlbehi_i),
    .tlbidx_i       (tlbidx_i),
    .tlbelo0_i      (tlbelo0_i),
    .tlbelo1_i      (tlbelo1_i),
    .tlbasid_i      (tlbasid_i),
    .csr_rdata_i (csr_rdata_i),
    .cmt_o       (misc_cmt_o),
    .cmt_ready_i (misc_cmt_ready_i)
  );
/*==================================== ALU ====================================*/

  for (genvar i = 0; i < 2; i++) begin
    AluPipe inst_AluPipe
    (
      .clk         (clk),
      .a_rst_n     (rst_n),
      .exe_i       (alu_exe_i[i]),
      .ready_o     (alu_ready_o[i]),
      .cmt_o       (alu_cmt_o[i]),
      .cmt_ready_i (alu_cmt_ready_i[i])
    );
  end

/*==================================== MDU ====================================*/

  MduPipe inst_MduPipe
  (
    .clk         (clk),
    .a_rst_n     (rst_n),
    .flush_i     (flush_i),
    .exe_i       (mdu_exe_i),
    .ready_o     (mdu_ready_o),
    .cmt_o       (mdu_cmt_o),
    .cmt_ready_i (mdu_cmt_ready_i)
  );


endmodule : IntegerBlock
