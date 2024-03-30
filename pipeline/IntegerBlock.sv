// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : IntegerBlock.sv
// Create  : 2024-03-17 22:34:32
// Revise  : 2024-03-27 20:26:39
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
  output logic [13:0] csr_raddr_o,
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
    .csr_raddr_o (csr_raddr_o),
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

