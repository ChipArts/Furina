// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : MemoryManagementUnit.sv
// Create  : 2024-03-11 19:19:09
// Revise  : 2024-03-22 19:19:24
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
`include "common.svh"
`include "MemoryManagementUnit.svh"
`include "TranslationLookasideBuffer.svh"

module MemoryManagementUnit (
  input logic clk,    // Clock
  input logic a_rst_n,  // Asynchronous reset active low
  input logic [9:0]  asid,
  // from csr
  input logic [31:0] csr_dmw0,
  input logic [31:0] csr_dmw1,
  input logic [1:0]  csr_datf,
  input logic [1:0]  csr_datm,
  input logic        csr_da  ,
  input logic        csr_pg  ,
  // inst addr trans
  input MmuInstTransReqSt inst_trans_req,
  output MmuInstTransRspSt inst_trans_rsp,
  // data addr trans
  input MmuDataTransReqSt data_trans_req,
  output MmuDataTransRspSt data_trans_rsp,
  // tlbfill tlbwr tlb write
  input logic        tlbfill_en,
  input logic        tlbwr_en  ,
  input logic [ 4:0] rand_index,
  input logic [31:0] tlbehi_i ,
  input logic [31:0] tlbelo0_i,
  input logic [31:0] tlbelo1_i,
  input logic [31:0] tlbidx_i , 
  input logic [ 5:0] ecode_i  ,
  //tlbr tlb read
  output logic [31:0] tlbehi_o ,
  output logic [31:0] tlbelo0_o,
  output logic [31:0] tlbelo1_o,
  output logic [31:0] tlbidx_o ,
  output logic [ 9:0] asid_o   ,
  // invtlb
  input logic        invtlb_en  ,
  input logic [ 9:0] invtlb_asid,
  input logic [18:0] invtlb_vpn ,
  input logic [ 4:0] invtlb_op
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

  TlbSearchReqSt [1:0] tlb_search_req;
  TlbSearchRspSt [1:0] tlb_search_rsp;

  TranslationLookasideBuffer #(
    .TLB_PORT_NUM(3)
  ) inst_TranslationLookasideBuffer (
    .clk            (clk),
    .a_rst_n        (a_rst_n),
    .tlb_search_req (tlb_search_req),
    .tlb_search_rsp (tlb_search_rsp),
    .tlb_read_req   (tlb_read_req),
    .tlb_read_rsp   (tlb_read_rsp),
    .tlb_write_req  (tlb_write_req),
    .tlb_write_rsp  (tlb_write_rsp),
    .tlb_inv_req    (tlb_inv_req),
    .tlb_inv_rsp    (tlb_inv_rsp)
  );



endmodule : MemoryManagementUnit

