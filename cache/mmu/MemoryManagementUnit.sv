// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : MemoryManagementUnit.sv
// Create  : 2024-03-11 19:19:09
// Revise  : 2024-03-31 19:07:47
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
  // // inst addr trans
  // input MmuAddrTransReqSt inst_trans_req,
  // output MmuAddrTransRspSt inst_trans_rsp,
  // // data addr trans
  // input MmuAddrTransReqSt data_trans_req,
  // output MmuAddrTransRspSt data_trans_rsp,
  input  MmuAddrTransReqSt [1:0] addr_trans_req,
  output MmuAddrTransRspSt [1:0] addr_trans_rsp,
  // tlb search
  input logic  tlbsrch_en_i,
  output logic tlbsrch_found_o,
  output logic [$clog2(`TLB_ENTRY_NUM) - 1:0] tlbsrch_idx_o,
  // tlbfill tlbwr tlb write
  input logic        tlbfill_en_i,
  input logic        tlbwr_en_i  ,
  input logic [ 4:0] rand_idx_i,
  input logic [31:0] tlbehi_i ,
  input logic [31:0] tlbelo0_i,
  input logic [31:0] tlbelo1_i,
  input logic [31:0] tlbidx_i , 
  input logic [ 5:0] ecode_i  ,
  //tlbr tlb read
  input  logic tlbrd_en_i,
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

  logic [1:0] dmw0_en, dmw1_en;
  logic [1:0] addr_trans_en;

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

  MmuAddrTransReqSt [1:0] addr_trans_req_buffer;


  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      addr_trans_req_buffer <= '0;
    end else begin
      addr_trans_req_buffer <= addr_trans_req;
    end
  end

  always_comb begin
    // search req
    tlb_search_req[0].valid = addr_trans_req[0].valid;
    tlb_search_req[0].asid  = csr_asid_i;
    tlb_search_req[0].vpn   = addr_trans_req[0].vaddr[`PROC_VALEN:12];

    tlb_search_req[1].valid = addr_trans_req[1].valid;
    tlb_search_req[1].asid  = csr_asid_i;
    tlb_search_req[1].vpn   = addr_trans_req[1].vaddr[`PROC_VALEN:12];

    tlb_search_req[2].valid = tlbsrch_en_i;
    tlb_search_req[2].asid  = csr_asid_i;
    tlb_search_req[2].vpn   = {tlbehi_i[`VPPN], 1'b0};

    // write req
    tlb_write_req.valid = tlbfill_en_i || tlbwr_en_i;
    tlb_write_req.idx = ({5{tlbfill_en_i}} & rand_idx_i) | ({5{tlbwr_en_i}} & tlbidx_i[`INDEX]);
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
    tlb_read_req.valid = tlbrd_en_i;
    tlb_read_req.idx = tlbidx_i[`INDEX];
    // inv req
    tlb_inv_req.valid = invtlb_en_i;
    tlb_inv_req.asid = invtlb_asid_i;
    tlb_inv_req.vppn = invtlb_vpn_i;
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
    tlbidx_o   = {!r_e, 1'b0, r_ps, 24'b0}; // note do not write index
    tlbasid_o  = r_asid;

    // search rsp
    pg_mode = !csr_da_i &&  csr_pg_i;
    da_mode =  csr_da_i && !csr_pg_i;

    for (int i = 0; i < 2; i++) begin
      dmw0_en[i] = ((csr_dmw0_i[`PLV0] && csr_plv_i == 2'd0) || 
                    (csr_dmw0_i[`PLV3] && csr_plv_i == 2'd3)) && 
                   (addr_trans_req_buffer[i].vaddr[31:29] == csr_dmw0_i[`VSEG]);
      dmw1_en[i] = ((csr_dmw1_i[`PLV0] && csr_plv_i == 2'd0) || 
                    (csr_dmw1_i[`PLV3] && csr_plv_i == 2'd3)) && 
                   (addr_trans_req_buffer[i].vaddr[31:29] == csr_dmw1_i[`VSEG]);


      addr_trans_en[i] = pg_mode & ~dmw0_en[i] & ~dmw1_en[i] & ~addr_trans_req_buffer[i].cacop_direct;

      addr_trans_rsp[i].valid = addr_trans_req[i].valid;
      addr_trans_rsp[i].ready = '1;
      addr_trans_rsp[i].paddr = (pg_mode && dmw0_en[i] && !addr_trans_req_buffer[i].cacop_direct) ? {csr_dmw0_i[`PSEG], addr_trans_req_buffer[i].vaddr[28:0]} : 
                                (pg_mode && dmw1_en[i] && !addr_trans_req_buffer[i].cacop_direct) ? {csr_dmw1_i[`PSEG], addr_trans_req_buffer[i].vaddr[28:0]} : 
                                 addr_trans_en[i] ? 
                                ((tlb_search_rsp[i].page_size == 6'd12) ? {tlb_search_rsp[i].ppn, addr_trans_req_buffer[i].vaddr[11:0]} : 
                                                                          {tlb_search_rsp[i].ppn[`PROC_PALEN - 1:22], addr_trans_req_buffer[i].vaddr[21:0]}) :
                                 addr_trans_req_buffer[i].vaddr;

      addr_trans_rsp[i].uncache = (da_mode && (csr_datm_i == 2'b0))                    ||
                                  (dmw0_en[i] && (csr_dmw0_i[`DMW_MAT] == 2'b0))       ||
                                  (dmw1_en[i] && (csr_dmw1_i[`DMW_MAT] == 2'b0))       ||
                                  (addr_trans_en[i] && (tlb_search_rsp[1].mat == 2'b0));
      // addr_trans_rsp[i].tlb_valid = tlb_search_rsp[i].valid;
      // addr_trans_rsp[i].tlb_dirty = tlb_search_rsp[i].dirty;
      // addr_trans_rsp[i].tlb_mat   = tlb_search_rsp[i].mat;
      // addr_trans_rsp[i].tlb_plv   = tlb_search_rsp[i].plv;

      // 抛出异常
      addr_trans_rsp[i].pif = '0;
      addr_trans_rsp[i].pil = '0;
      addr_trans_rsp[i].pis = '0;
      addr_trans_rsp[i].ppi = '0;
      addr_trans_rsp[i].pme = '0;
      if (addr_trans_en[i]) begin
        addr_trans_rsp[i].tlbr = ~tlb_search_rsp[i].found;
        if (!tlb_search_rsp[i].valid) begin
          case (addr_trans_req_buffer[i].mem_type)
            MMU_FETCH : addr_trans_rsp[i].pif = '1;
            MMU_LOAD  : addr_trans_rsp[i].pil = '1;
            MMU_STORE : addr_trans_rsp[i].pis = '1;
            default : /* default */;
          endcase
        end else if (csr_plv_i > tlb_search_rsp[i].plv) begin
          addr_trans_rsp[i].ppi = '1;
        end else if (addr_trans_req_buffer[i].mem_type == MMU_STORE && tlb_search_rsp[i].dirty == 0) begin
          addr_trans_rsp[i].pme = '1;
        end
      end
      
    end


    tlbsrch_found_o = tlb_search_rsp[2].valid;
    tlbsrch_idx_o = tlb_search_rsp[2].idx;
  end

  for (genvar i = 0; i < 2; i++) begin : gen_addr_trans_tlb
    // 用于ICache和DCache的地址转换
    TranslationLookasideBuffer U_TranslationLookasideBuffer (
      .clk            (clk),
      .a_rst_n        (rst_n),
      .tlb_search_req (tlb_search_req[i]),
      .tlb_search_rsp (tlb_search_rsp[i]),
      .tlb_read_req   ('0),
      .tlb_read_rsp   (),
      .tlb_write_req  (tlb_write_req),
      .tlb_write_rsp  (tlb_write_rsp),
      .tlb_inv_req    (tlb_inv_req),
      .tlb_inv_rsp    (tlb_inv_rsp)
    );
  end

  // 实现tlbsrch和tlbrd
  TranslationLookasideBuffer U_TranslationLookasideBuffer (
    .clk            (clk),
    .a_rst_n        (rst_n),
    .tlb_search_req (tlb_search_req[2]),
    .tlb_search_rsp (tlb_search_rsp[2]),
    .tlb_read_req   (tlb_read_req),
    .tlb_read_rsp   (tlb_read_rsp),
    .tlb_write_req  (tlb_write_req),
    .tlb_write_rsp  (tlb_write_rsp),
    .tlb_inv_req    (tlb_inv_req),
    .tlb_inv_rsp    (tlb_inv_rsp)
  );
  
endmodule : MemoryManagementUnit

