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

module TranslationLookasideBuffer (
  input logic clk,    // Clock
  input logic a_rst_n,  // Asynchronous reset active low
  // tlb search
  input TlbSearchReqSt tlb_search_req,
  output TlbSearchRspSt tlb_search_rsp,
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
  
  `RESET_LOGIC(clk, a_rst_n, rst_n);

  TlbEntrySt [`TLB_ENTRY_NUM - 1:0] tlb_entries;

  /** TLB Ctrl Logic **/
  logic parity;  // 奇偶标识
  logic found;
  logic [`TLB_ENTRY_NUM - 1:0] match;

  TlbEntrySt matched_entry;  // 用于构造输出
  logic [$clog2(`TLB_ENTRY_NUM) - 1:0] matched_idx;

  // 操作优先级: write > inv > read = search
  always_comb begin
    matched_entry = '0;
    matched_idx = '0;
    // 使用CAM进行查询
    for (int i = 0; i < `TLB_ENTRY_NUM; i++) begin
      // LA32R只支持 4KB 和 4MB 两种页大小，对应 TLB 表项中的 PS 值分别是 12 和 21
      match[i] = tlb_entries[i].exist &  // 有效位有效
                    (tlb_entries[i].asid == tlb_search_req.asid | tlb_entries[i].glo) &  // asid校验
                    (tlb_entries[i].page_size == 6'd12 ? // page size
                    (tlb_search_req.vpn[`PROC_VALEN - 1:13] == 
                    tlb_entries[i].vppn[`PROC_VALEN - 1:13]) :
                    (tlb_search_req.vpn[`PROC_VALEN - 1:22] == 
                    tlb_entries[i].vppn[`PROC_VALEN - 1:22]));  // VPPN 匹配
      if (match[i]) begin
        matched_entry |= tlb_entries[i];
        matched_idx |= i;
      end
    end
    found = |match;
    parity = matched_entry.page_size == 6'd12 ? tlb_search_req.vpn[12] : tlb_search_req.vpn[21];
    // comb输出
    tlb_search_rsp.ready = '1;
    tlb_read_rsp.ready = '1;
    tlb_write_rsp.ready = '1;
    tlb_inv_rsp.ready = '1;

  end

  // tlb wr/inv指令有关操作
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tlb_entries = '0;
    end else begin
      if (tlb_write_req.valid) begin
        tlb_entries[tlb_write_req.idx] <= tlb_write_req.tlb_entry_st;
      end else if(tlb_inv_req.valid) begin
        for (int i = 0; i < `TLB_ENTRY_NUM; i++) begin
          case (tlb_inv_req.op)
            `TLB_INV_ALL0 : tlb_entries[i] <= '0;
            `TLB_INV_ALL1 : tlb_entries[i] <= '0;
            `TLB_INV_GLO1 : begin
              if (tlb_entries[i].glo) begin
                tlb_entries[i] <= '0;
              end
            end
            `TLB_INV_GLO0 : begin
              if (~tlb_entries[i].glo) begin
                tlb_entries[i] <= '0;
              end
            end
            `TLB_INV_GLO0_ASID : begin
              if (~tlb_entries[i].glo & (tlb_entries[i].asid == tlb_inv_req.asid)) begin
                tlb_entries[i] <= '0;
              end
            end
            `TLB_INV_GLO0_ASID_VA : begin
              if (~tlb_entries[i].glo & (tlb_entries[i].asid == tlb_inv_req.asid) & 
                  (tlb_entries[i].vppn == tlb_inv_req.vppn)) begin
                tlb_entries[i] <= '0;
              end
            end
            `TLB_INV_GLO1_ASID_VA : begin
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
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      tlb_search_rsp.found <= '0;
      tlb_search_rsp.idx <= '0;
      tlb_search_rsp.page_size <= '0;
      tlb_search_rsp.valid <= '0;
      tlb_search_rsp.dirty <= '0;
      tlb_search_rsp.ppn <= '0;
      tlb_search_rsp.mat <= '0;
      tlb_search_rsp.plv <= '0;

      tlb_read_rsp.tlb_entry_st <= '0;
    end else begin
      if (tlb_search_req.valid) begin
        tlb_search_rsp.found <= found;
        tlb_search_rsp.idx <= matched_idx;
        tlb_search_rsp.page_size <= matched_entry.page_size;
        tlb_search_rsp.valid <= matched_entry.valid[parity];
        tlb_search_rsp.dirty <= matched_entry.dirty[parity];
        tlb_search_rsp.ppn <= matched_entry.ppn[parity];
        tlb_search_rsp.mat <= matched_entry.mat[parity];
        tlb_search_rsp.plv <= matched_entry.plv[parity];
      end
      
      if (tlb_read_req.valid) begin
        tlb_read_rsp.tlb_entry_st <= tlb_entries[tlb_read_req.idx];
      end
    end

  end


endmodule : TranslationLookasideBuffer


