// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : MemoryManagementUnit.sv
// Create  : 2024-03-11 19:19:09
// Revise  : 2024-03-30 15:52:35
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
`include "ControlStatusRegister.svh"
`include "TranslationLookasideBuffer.svh"

module MemoryManagementUnit (
  input logic clk,    // Clock
  input logic a_rst_n,  // Asynchronous reset active low
  // from csr
  input logic [9:0]  csr_asid_i,
  input logic [31:0] csr_dmw0_i,
  input logic [31:0] csr_dmw1_i,
  input logic [1:0]  csr_datf_i,
  input logic [1:0]  csr_datm_i,
  input logic [1:0]  csr_plv_i ,
  input logic        csr_da_i  ,
  input logic        csr_pg_i  ,
  // inst addr trans
  input MmuAddrTransReqSt inst_trans_req,
  output MmuAddrTransRspSt inst_trans_rsp,
  // data addr trans
  input MmuAddrTransReqSt data_trans_req,
  output MmuAddrTransRspSt data_trans_rsp,
  // tlb search
  input logic         tlbsearch_en_i,
  input logic [ 9:0]  tlbsearch_asid_i,
  input logic [31:13] tlbsearch_vpn_i,
  output logic tlbsearch_found_o,
  output logic [$clog2(`TLB_ENTRY_NUM) - 1:0] tlbsearch_idx_o,
  output logic [31:12] tlbsearch_ppn_o,
  // tlbfill tlbwr tlb write
  input logic        tlbfill_en_i,
  input logic        tlbwr_en_i  ,
  input logic [ 4:0] rand_idex_i,
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
  output logic [ 9:0] tlbasid_o,
  // invtlb
  input logic        invtlb_en_i  ,
  input logic [ 9:0] invtlb_asid_i,
  input logic [18:0] invtlb_vpn_i,
  input logic [ 4:0] invtlb_op_i
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

  logic        pg_mode;
  logic        da_mode;

  logic inst_dmw0_en, inst_dmw1_en;
  logic data_dmw0_en, data_dmw1_en;
  logic inst_addr_trans_en;
  logic data_addr_trans_en;

  TlbSearchReqSt [2:0] tlb_search_req;
  TlbSearchRspSt [2:0] tlb_search_rsp;
  // tlbrd 
  TlbReadReqSt tlb_read_req;
  TlbReadRspSt tlb_read_rsp;
  // tlbfill tlbwr
  TlbWriteReqSt tlb_write_req;
  TlbWriteRspSt tlb_write_rsp;
  // invtlb
  TlbInvReqSt tlb_inv_req;
  TlbInvRspSt tlb_inv_rsp;

  logic [18:0] r_vppn      ;
  logic [ 9:0] r_asid      ;
  logic        r_g         ;
  logic [ 5:0] r_ps        ;
  logic        r_e         ;
  logic        r_v0        ;
  logic        r_d0        ; 
  logic [ 1:0] r_mat0      ;
  logic [ 1:0] r_plv0      ;
  logic [19:0] r_ppn0      ;
  logic        r_v1        ;
  logic        r_d1        ;
  logic [ 1:0] r_mat1      ;
  logic [ 1:0] r_plv1      ;
  logic [19:0] r_ppn1      ;

  logic [31:0] inst_vaddr_buffer;
  logic [31:0] data_vaddr_buffer;
  logic        data_cacop_direct_buffer;

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      inst_vaddr_buffer <= 0;
      data_vaddr_buffer <= 0;
      data_cacop_direct_buffer <= '0;
    end else begin
      inst_vaddr_buffer <= inst_trans_req.vaddr;
      data_vaddr_buffer <= data_trans_req.vaddr;
      data_cacop_direct_buffer <= data_trans_req.cacop_direct;
    end
  end

  always_comb begin
    // search req
    tlb_search_req[0].valid = inst_trans_req.valid;
    tlb_search_req[0].asid  = csr_asid_i;
    tlb_search_req[0].vpn   = inst_trans_req.vaddr[`PROC_VALEN:12];

    tlb_search_req[1].valid = data_trans_req.valid;
    tlb_search_req[1].asid  = csr_asid_i;
    tlb_search_req[1].vpn   = inst_trans_req.vaddr[`PROC_VALEN:12];

    tlb_search_req[2].valid = tlbsearch_en_i;
    tlb_search_req[2].asid  = tlbsearch_asid_i;
    tlb_search_req[2].vpn   = tlbsearch_vpn_i;

    // write req
    tlb_write_req.valid = tlbfill_en_i || tlbwr_en_i;
    tlb_write_req.idx = ({5{tlbfill_en_i}} & rand_idex_i) | ({5{tlbwr_en_i}} & tlbidx_i[`INDEX]);
    tlb_write_req.tlb_entry_st = '{exist: (ecode_i == 6'h3f) ? 1'b1 : !tlbidx_i[`NE],
                                   asid: csr_asid_i,
                                   glo: tlbelo0_i[`TLB_G] && tlbelo1_i[`TLB_G],
                                   page_size: tlbidx_i[`PS],
                                   vppn: tlbehi_i[`VPPN],
                                   valid: {tlbelo0_i[`TLB_V], tlbelo1_i[`TLB_V]},
                                   dirty: {tlbelo0_i[`TLB_D], tlbelo1_i[`TLB_D]},
                                   mat: {tlbelo0_i[`TLB_MAT], tlbelo1_i[`TLB_MAT]},
                                   plv: {tlbelo0_i[`TLB_PLV], tlbelo1_i[`TLB_PLV]},
                                   ppn: {tlbelo0_i[`TLB_PPN_EN], tlbelo1_i[`TLB_PPN_EN]}};
    // read req
    tlb_read_req.valid = '1;
    tlb_read_req.idx = tlbidx_i[`INDEX];
    // inv req
    tlb_inv_req.valid = invtlb_en_i;
    tlb_inv_req.asid = invtlb_asid_i;
    tlb_inv_req.vpn = invtlb_vpn_i;
    tlb_inv_req.op = invtlb_op_i;

    // read rsp
    r_vppn = tlb_read_rsp.tlb_entry_st.vppn;
    r_asid = tlb_read_rsp.tlb_entry_st.asid;
    r_g    = tlb_read_rsp.tlb_entry_st.glo;
    r_ps   = tlb_read_rsp.tlb_entry_st.page_size;
    r_e    = tlb_read_rsp.tlb_entry_st.exist;
    r_v0   = tlb_read_rsp.tlb_entry_st.valid[0];
    r_d0   = tlb_read_rsp.tlb_entry_st.dirty[0];
    r_mat0 = tlb_read_rsp.tlb_entry_st.mat[0];
    r_plv0 = tlb_read_rsp.tlb_entry_st.plv[0];
    r_ppn0 = tlb_read_rsp.tlb_entry_st.ppn[0];
    r_v1   = tlb_read_rsp.tlb_entry_st.valid[1];
    r_d1   = tlb_read_rsp.tlb_entry_st.dirty[1];
    r_mat1 = tlb_read_rsp.tlb_entry_st.mat[1];
    r_plv1 = tlb_read_rsp.tlb_entry_st.plv[1];
    r_ppn1 = tlb_read_rsp.tlb_entry_st.ppn[1];

    tlbehi_o   = {r_vppn, 13'b0};
    tlbelo0_o  = {4'b0, r_ppn0, 1'b0, r_g, r_mat0, r_plv0, r_d0, r_v0};
    tlbelo1_o  = {4'b0, r_ppn1, 1'b0, r_g, r_mat1, r_plv1, r_d1, r_v1};
    tlbidx_o   = {!r_e, 1'b0, r_ps, 24'b0}; //note do not write index
    tlbasid_o  = r_asid;

    // search rsp
    pg_mode = !csr_da_i &&  csr_pg_i;
    da_mode =  csr_da_i && !csr_pg_i;

    inst_dmw0_en = ((csr_dmw0_i[`PLV0] && csr_plv_i == 2'd0) || 
                    (csr_dmw0_i[`PLV3] && csr_plv_i == 2'd3)) && 
                   (inst_vaddr_buffer[31:29] == csr_dmw0_i[`VSEG]);
    inst_dmw1_en = ((csr_dmw1_i[`PLV0] && csr_plv_i == 2'd0) || 
                    (csr_dmw1_i[`PLV3] && csr_plv_i == 2'd3)) && 
                   (inst_vaddr_buffer[31:29] == csr_dmw1_i[`VSEG]);

    data_dmw0_en = ((csr_dmw0_i[`PLV0] && csr_plv_i == 2'd0) || 
                    (csr_dmw0_i[`PLV3] && csr_plv_i == 2'd3)) && 
                   (data_vaddr_buffer[31:29] == csr_dmw0_i[`VSEG]);
    data_dmw1_en = ((csr_dmw1_i[`PLV0] && csr_plv_i == 2'd0) || 
                    (csr_dmw1_i[`PLV3] && csr_plv_i == 2'd3)) && 
                   (data_vaddr_buffer[31:29] == csr_dmw1_i[`VSEG]);

    inst_addr_trans_en = pg_mode && !inst_dmw0_en && !inst_dmw1_en;
    data_addr_trans_en = pg_mode && !data_dmw0_en && !data_dmw1_en && !data_cacop_direct_buffer;

    inst_trans_rsp.valid = '1;
    inst_trans_rsp.ready = '1;
    inst_trans_rsp.miss  = tlb_search_rsp[0].miss;
    inst_trans_rsp.paddr = (pg_mode && inst_dmw0_en) ? {csr_dmw0_i[`PSEG], inst_vaddr_buffer[28:0]} :
                           (pg_mode && inst_dmw1_en) ? {csr_dmw1_i[`PSEG], inst_vaddr_buffer[28:0]} : 
                            inst_addr_trans_en ? 
                           ((tlb_search_rsp[0].page_size == 6'd12) ? {tlb_search_rsp[0].ppn, inst_vaddr_buffer[11:0]} : 
                                                                     {tlb_search_rsp[0].ppn[`PROC_PALEN - 1:22], inst_vaddr_buffer[21:0]}) :
                            inst_vaddr_buffer;
    inst_trans_rsp.uncache = (da_mode && (csr_datm_i == 2'b0))                      ||
                             (inst_dmw0_en && (csr_dmw0_i[`DMW_MAT] == 2'b0))       ||
                             (inst_dmw1_en && (csr_dmw1_i[`DMW_MAT] == 2'b0))       ||
                             (inst_addr_trans_en && (tlb_search_rsp[0].mat == 2'b0));
    inst_trans_rsp.tlb_valid = tlb_search_rsp[0].valid;
    inst_trans_rsp.tlb_dirty = tlb_search_rsp[0].dirty;
    inst_trans_rsp.tlb_mat   = tlb_search_rsp[0].mat;
    inst_trans_rsp.tlb_plv   = tlb_search_rsp[0].plv;

    data_trans_rsp.valid = '1;
    data_trans_rsp.ready = '1;
    data_trans_rsp.miss  = tlb_search_rsp[1].miss;
    data_trans_rsp.paddr = (pg_mode && data_dmw0_en && !data_cacop_direct_buffer) ? {csr_dmw0_i[`PSEG], data_vaddr_buffer[28:0]} : 
                           (pg_mode && data_dmw1_en && !data_cacop_direct_buffer) ? {csr_dmw1_i[`PSEG], data_vaddr_buffer[28:0]} : 
                            data_addr_trans_en ? 
                           ((tlb_search_rsp[1].page_size == 6'd12) ? {tlb_search_rsp[1].ppn, data_vaddr_buffer[11:0]} : 
                                                                     {tlb_search_rsp[1].ppn[`PROC_PALEN - 1:22], data_vaddr_buffer[21:0]}) :
                            data_vaddr_buffer;

    data_trans_rsp.uncache = (da_mode && (csr_datm_i == 2'b0))                      ||
                             (data_dmw0_en && (csr_dmw0_i[`DMW_MAT] == 2'b0))       ||
                             (data_dmw1_en && (csr_dmw1_i[`DMW_MAT] == 2'b0))       ||
                             (data_addr_trans_en && (tlb_search_rsp[1].mat == 2'b0));
    data_trans_rsp.tlb_valid = tlb_search_rsp[1].valid;
    data_trans_rsp.tlb_dirty = tlb_search_rsp[1].dirty;
    data_trans_rsp.tlb_mat   = tlb_search_rsp[1].mat;
    data_trans_rsp.tlb_plv   = tlb_search_rsp[1].plv;

    tlbsearch_found_o = tlb_search_rsp[2].valid;
    tlbsearch_idx_o = tlb_search_rsp[2].idx;
    tlbsearch_ppn_o = tlb_search_rsp[2].ppn;
  end

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
    .tlb_iv_req    (tlb_inv_req),
    .tlb_iv_rsp    (tlb_inv_rsp)
  );
endmodule : MemoryManagementUnit

