// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : TranslationLookasideBuffer.sv
// Create  : 2024-03-01 16:12:20
// Revise  : 2024-03-01 16:12:20
// Description :
//   TLB
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
`include "Cache.svh"
`include "TranslationLookasideBuffer.svh"

module TranslationLookasideBuffer #(
parameter
  int unsigned TLB_PORT_NUM = 4
)(
  input logic clk,    // Clock
  input logic a_rst_n,  // Asynchronous reset active low
  // tlb search
  input TlbSearchReqSt [TLB_PORT_NUM - 1:0] tlb_search_req,
  output TlbSearchRspSt [TLB_PORT_NUM - 1:0] tlb_search_rsp,
  // tlbrd 
  input TlbReadReqSt tlb_read_req,
  output TlbReadRspSt tlb_read_rsp,
  // tlbfill tlbwr
  input TlbWriteReqSt tlb_write_req,
  output TlbWriteRspSt tlb_write_rsp,
  // invtlb
  input TlbInvReqSt tlb_inv_req,
  output TlbInvRspSt tlb_inv_rsp
);
  
  `RESET_LOGIC(clk, a_rst_n, s_rst_n);

  TLBEntrySt [`TLB_ENTRY_NUM - 1:0] tlb_entries;

  /** TLB Ctrl Logic **/
  logic [TLB_PORT_NUM - 1:0] parity;  // 奇偶标识
  logic [TLB_PORT_NUM - 1:0] miss;
  logic [TLB_PORT_NUM - 1:0][`TLB_ENTRY_NUM - 1:0] match;

  TlbEntrySt [TLB_PORT_NUM - 1:0] matched_entry;  // 用于构造输出
  logic [$clog2(`TLB_ENTRY_NUM) - 1:0] matched_idx;

  // 操作优先级: write > inv > read = search
  always_comb begin
    matched_entry = '0;
    matched_idx = '0;
    // 使用CAM进行查询
    for (int i = 0; i < TLB_PORT_NUM; i++) begin
      for (int j = 0; j < `TLB_ENTRY_NUM; j++) begin
        // LA32R只支持 4KB 和 4MB 两种页大小，对应 TLB 表项中的 PS 值分别是 12 和 21
        match[i][j] = tlb_entries[j].exist &  // 有效位有效
                      (tlb_entries[j].asid == tlb_search_req[i].asid | tlb_entries[i].glo) &  // asid校验
                      (tlb_entries[j].page_size == 6'd12 ? // page size
                      (tlb_search_req[i].vpn[`PROC_VALEN - 1:13] == 
                      tlb_entries[j].vppn[`PROC_VALEN - 1:13]) :
                      (tlb_search_req[i].vpn[`PROC_VALEN - 1:22] == 
                      tlb_entries[j].vppn[`PROC_VALEN - 1:22]));  // VPPN 匹配
        if (match[i][j]) begin
          matched_entry[i] |= tlb_entries[j];
          matched_idx[i] |= j;
        end
      end
      miss[i] = ~|match[i];
      parity[i] = matched_entry[i].page_size == 6'd12 ? tlb_search_req[i].vpn[12] : tlb_search_req[i].vpn[21];
      // comb输出
      tlb_search_rsp[i].ready = ~tlb_write_req.valid & ~tlb_inv_req.valid;
    end

    // comb输出
    tlb_read_rsp.ready = ~tlb_write_req.valid & ~tlb_inv_req.valid;
    tlb_read_rsp.tlb_entry_st = tlb_entries[tlb_read_req.idx];

    tlb_write_rsp.ready = '1;
    tlb_inv_rsp.ready = ~tlb_write_req.valid;

  end

  // tlb wr/inv指令有关操作
  always_ff @(posedge clk or negedge s_rst_n) begin
    if (~s_rst_n) begin
      tlb_entries = '0;
    end else begin
      if (tlb_write_req.valid) begin
        tlb_entries[tlb_write_req.idx] <= tlb_write_req.tlb_entry_st;
      end else begin
        for (int i = 0; i < `TLB_ENTRY_NUM; i++) begin
          case (tlb_inv_req.option_t)
            TLB_INV_ALL0 : tlb_entries[i] <= '0;
            TLB_INV_ALL1 : tlb_entries[i] <= '0;
            TLB_INV_GLO1 : begin
              if (tlb_entries[i].glo) begin
                tlb_entries[i] <= '0;
              end
            end
            TLB_INV_GLO0 : begin
              if (~tlb_entries[i].glo) begin
                tlb_entries[i] <= '0;
              end
            end
            TLB_INV_GLO0_ASID : begin
              if (~tlb_entries[i].glo & (tlb_entries[i].asid == tlb_inv_req.asid)) begin
                tlb_entries[i] <= '0;
              end
            end
            TLB_INV_GLO0_ASID_VA : begin
              if (~tlb_entries[i].glo & (tlb_entries[i].asid == tlb_inv_req.asid) & 
                  (tlb_entries[i].vppn == tlb_inv_req.vppn)) begin
                tlb_entries[i] <= '0;
              end
            end
            TLB_INV_GLO1_ASID_VA : begin
              if (tlb_entries[i].glo & (tlb_entries[i].asid == tlb_inv_req.asid) & 
                  (tlb_entries[i].vppn == tlb_inv_req.vppn)) begin
                tlb_entries[i] <= '0;
              end
            end
            default : /* default */;
          endcase
        end
      end
    end
  end

  // ff输出
  always_ff @(posedge clk or negedge s_rst_n) begin
    if (~s_rst_n) begin
      for (int i = 0; i < TLB_PORT_NUM; i++) begin
        tlb_search_rsp[i].miss <= '0;
        tlb_search_rsp[i].idx <= '0;
        tlb_search_rsp[i].page_size <= '0;
        tlb_search_rsp[i].valid <= '0;
        tlb_search_rsp[i].dirty <= '0;
        tlb_search_rsp[i].ppn <= '0;
        tlb_search_rsp[i].mat <= '0;
        tlb_search_rsp[i].plv <= '0;
      end
    end else begin
      foreach (tlb_search_rsp[i]) begin
        tlb_search_rsp[i].miss <= miss[i];
        tlb_search_rsp[i].idx <= matched_idx[i];
        tlb_search_rsp[i].page_size <= matched_entry[i].page_size;
        tlb_search_rsp[i].valid <= matched_entry[i].valid[parity];
        tlb_search_rsp[i].dirty <= matched_entry[i].dirty[parity];
        tlb_search_rsp[i].ppn <= matched_entry[i].ppn[parity];
        tlb_search_rsp[i].mat <= matched_entry[i].mat[parity];
        tlb_search_rsp[i].plv <= matched_entry[i].plv[parity];
      end
    end
  end


endmodule : TranslationLookasideBuffer


