// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : TranslationLookasideBuffer.sv
// Create  : 2024-03-01 16:12:20
// Revise  : 2024-03-01 16:12:20
// Description :
//   TLB (Translation Lookaside Buffer) 龙芯架构的实现
//   本模块实现虚拟地址到物理地址转换的缓存
// Parameter   :
//   TLB_ENTRY_NUM - 配置中定义的TLB条目数量
// IO Port     :
//   clk, rst_n - 时钟和复位信号
//   tlb_search_req/rsp - 地址转换查询接口
//   tlb_read_req/rsp - 读取TLB条目接口（TLBRD指令）
//   tlb_write_req/rsp - 写入TLB条目接口（TLBWR/TLBFILL指令）
//   tlb_inv_req/rsp - 使TLB条目失效接口（INVTLB指令）
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// xx-xx-xx |            |     0.1     |    Original Version
// ...
// ==============================================================================

`include "../../config.svh"
`include "../../include/common.svh"
`include "../../include/Cache.svh"
`include "../../include/TranslationLookasideBuffer.svh"

module TranslationLookasideBuffer (
  input logic clk,    // 时钟
  input logic rst_n,  // 低电平有效的异步复位
  // tlb search - 地址转换接口
  input TlbSearchReqSt tlb_search_req,    // TLB查询请求结构
  output TlbSearchRspSt tlb_search_rsp,   // TLB查询响应结构
  // tlbrd - TLB读取指令接口
  input TlbReadReqSt tlb_read_req,        // TLB读取请求结构
  output TlbReadRspSt tlb_read_rsp,       // TLB读取响应结构
  // tlbfill tlbwr - TLB写入指令接口
  input TlbWriteReqSt tlb_write_req,      // TLB写入请求结构
  output TlbWriteRspSt tlb_write_rsp,     // TLB写入响应结构
  // invtlb - TLB失效指令接口
  input TlbInvReqSt tlb_inv_req,          // TLB失效请求结构
  output TlbInvRspSt tlb_inv_rsp          // TLB失效响应结构
);
  
  // 主TLB存储 - TLB条目数组
  TlbEntrySt [`TLB_ENTRY_NUM - 1:0] tlb_entries;

  /** TLB控制逻辑 **/
  // TLB操作的控制信号
  logic parity;  // 奇/偶页选择器，用于双页条目
  logic found;   // 表示是否找到匹配条目的标志
  logic [`TLB_ENTRY_NUM - 1:0] match;  // 条目匹配的位向量

  // 匹配TLB条目的结果
  TlbEntrySt matched_entry;  // 用于构造输出的匹配TLB条目
  logic [$clog2(`TLB_ENTRY_NUM) - 1:0] matched_idx;  // 匹配条目的索引

  // 操作优先级: 写 > 失效 > 读 = 查询
  // (当并发时，高优先级操作将覆盖低优先级操作)

  // 内容寻址存储器(CAM)查找实现
  // 这会为每个TLB条目并行生成匹配信号
  for (genvar i = 0; i < `TLB_ENTRY_NUM; i++) begin
    // 龙芯LA32R支持两种页面大小: 4KB (PS=12) 和 4MB (PS=21)
    assign match[i] = (tlb_entries[i].exist) &  // 条目必须有效
                      // ASID必须匹配或条目必须是全局的
                      (tlb_entries[i].asid == tlb_search_req.asid | tlb_entries[i].glo) &  
                      (
                        // 对于4KB页面(PS=12)，比较VPN[31:13]
                        tlb_entries[i].page_size == 6'd12 ? 
                          (tlb_search_req.vpn[`PROC_VALEN - 1:13] == 
                           tlb_entries[i].vppn[`PROC_VALEN - 1:13]) :
                          // 对于4MB页面(PS=21)，比较VPN[31:22]
                          (tlb_search_req.vpn[`PROC_VALEN - 1:22] == 
                           tlb_entries[i].vppn[`PROC_VALEN - 1:22])
                      );  // 虚拟页号必须根据页面大小匹配
  end
  
  // 优先编码器，选择第一个匹配的条目
  // 这在多个条目匹配时很重要（在正确设计的TLB中不应该发生）
  always_comb begin : proc_match_idx
    matched_idx = '0;
    for (int i = 0; i < `TLB_ENTRY_NUM; i++) begin
      if (match[i]) begin
        matched_idx = i;
        break;  // 取第一个匹配并退出
      end
    end
  end

  // 根据索引提取匹配的条目
  assign matched_entry = tlb_entries[matched_idx];
  
  // 如果有任何条目匹配，则设置found标志
  assign found = |match;  // 所有匹配位的归约OR
  
  // 根据页面大小确定奇/偶页
  // 对于4KB页面，使用VPN[12]；对于4MB页面，使用VPN[21]
  // 这在单个TLB条目中选择两个页面映射之一
  assign parity = matched_entry.page_size == 6'd12 ? tlb_search_req.vpn[12] : tlb_search_req.vpn[21];
  
  // 为所有响应接口设置就绪信号
  // 这表明TLB可以接受新的请求
  assign tlb_search_rsp.ready = '1;
  assign tlb_read_rsp.ready = '1;
  assign tlb_write_rsp.ready = '1;
  assign tlb_inv_rsp.ready = '1;

  // TLB写入和失效操作的时序逻辑
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // 复位时重置所有TLB条目
      tlb_entries <= '0;
    end else begin
      if (tlb_write_req.valid) begin
        // TLBWR/TLBFILL指令执行
        // 在指定索引处写入新条目
        tlb_entries[tlb_write_req.idx] <= tlb_write_req.tlb_entry_st;
      end else if(tlb_inv_req.valid) begin
        // INVTLB指令执行
        // 遍历所有TLB条目以找到需要失效的条目
        for (int i = 0; i < `TLB_ENTRY_NUM; i++) begin
          case (tlb_inv_req.op)
            // 根据龙芯规范的不同失效操作
            `TLB_INV_ALL0 : tlb_entries[i].exist <= '0;  // 使所有TLB条目失效
            `TLB_INV_ALL1 : tlb_entries[i].exist <= '0;  // 使所有TLB条目失效（别名）
            
            `TLB_INV_GLO1 : begin
              // 仅使全局TLB条目失效
              if (tlb_entries[i].glo) begin
                tlb_entries[i].exist <= '0;
              end
            end
            
            `TLB_INV_GLO0 : begin
              // 仅使非全局TLB条目失效
              if (~tlb_entries[i].glo) begin
                tlb_entries[i].exist <= '0;
              end
            end
            
            `TLB_INV_GLO0_ASID : begin
              // 使匹配ASID的非全局TLB条目失效
              if (~tlb_entries[i].glo && (tlb_entries[i].asid == tlb_inv_req.asid)) begin
                tlb_entries[i].exist <= '0;
              end
            end
            
            `TLB_INV_GLO0_ASID_VA : begin
              // 使匹配ASID和VA的非全局TLB条目失效
              if (~tlb_entries[i].glo && (tlb_entries[i].asid == tlb_inv_req.asid) &&
                   (
                     // VPN匹配取决于页面大小
                     tlb_entries[i].page_size == 6'd12 ? 
                     tlb_entries[i].vppn == tlb_inv_req.vppn :  // 4KB页面的完全匹配
                     tlb_entries[i].vppn[`PROC_VALEN - 1:22] == tlb_inv_req.vppn[`PROC_VALEN - 1:22]  // 4MB页面的部分匹配
                   )
                 ) begin
                tlb_entries[i].exist <= '0;
              end
            end
            
            `TLB_INV_GLO1_ASID_VA : begin
              // 使全局或匹配ASID的且匹配VA的条目失效
              if ((tlb_entries[i].glo || (tlb_entries[i].asid == tlb_inv_req.asid)) &&
                   (
                     // VPN匹配取决于页面大小
                     tlb_entries[i].page_size == 6'd12 ? 
                     tlb_entries[i].vppn == tlb_inv_req.vppn :  // 4KB页面的完全匹配
                     tlb_entries[i].vppn[`PROC_VALEN - 1:22] == tlb_inv_req.vppn[`PROC_VALEN - 1:22]  // 4MB页面的部分匹配
                   )
                 ) begin
                tlb_entries[i].exist <= '0;
              end
            end
            
            default : /* 无操作 */;
          endcase
        end
      end
    end
  end

  /* 输出缓冲区 - 用于改善时序的寄存输出 */
  // TLB查询响应的缓冲寄存器
  logic found_buf;                            // 查询命中指示器
  logic [$clog2(`TLB_ENTRY_NUM) - 1:0] idx_buf;  // 匹配条目的索引
  logic [5:0] page_size_buf;                  // 页面大小（12表示4KB，21表示4MB）
  logic valid_buf;                            // 所选页面的有效位
  logic dirty_buf;                            // 所选页面的脏/可写位
  logic [`PROC_PALEN - 1:12] ppn_buf;         // 所选页面的物理页号
  logic [1:0] mat_buf;                        // 所选页面的内存属性
  logic [1:0] plv_buf;                        // 所选页面的特权级
  TlbEntrySt tlb_entry_buf;                   // 用于读响应的完整TLB条目

  // 将缓冲寄存器连接到输出端口
  assign tlb_search_rsp.found     = found_buf;
  assign tlb_search_rsp.idx       = idx_buf;
  assign tlb_search_rsp.page_size = page_size_buf;
  assign tlb_search_rsp.valid     = valid_buf;
  assign tlb_search_rsp.dirty     = dirty_buf;
  assign tlb_search_rsp.ppn       = ppn_buf;
  assign tlb_search_rsp.mat       = mat_buf;
  assign tlb_search_rsp.plv       = plv_buf;

  assign tlb_read_rsp.tlb_entry_st = tlb_entry_buf;

  // 输出缓冲寄存器的时序逻辑
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      // 复位所有输出缓冲区
      found_buf <= '0;
      idx_buf <= '0;
      page_size_buf <= '0;
      valid_buf <= '0;
      dirty_buf <= '0;
      ppn_buf <= '0;
      mat_buf <= '0;
      plv_buf <= '0;
      tlb_entry_buf <= '0;
    end else begin
      if (tlb_search_req.valid) begin
        // 当查询请求有效时更新查询响应缓冲区
        found_buf <= found;
        idx_buf <= matched_idx;
        page_size_buf <= matched_entry.page_size;
        // 根据奇偶位选择奇/偶页属性
        valid_buf <= matched_entry.valid[parity];
        dirty_buf <= matched_entry.dirty[parity];
        ppn_buf <= matched_entry.ppn[parity];
        mat_buf <= matched_entry.mat[parity];
        plv_buf <= matched_entry.plv[parity];
      end
      
      if (tlb_read_req.valid) begin
        // 当读取请求有效时更新读取响应缓冲区
        tlb_entry_buf <= tlb_entries[tlb_read_req.idx];
      end
    end
  end

endmodule : TranslationLookasideBuffer
