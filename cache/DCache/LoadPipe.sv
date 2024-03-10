// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : LoadPipe.sv
// Create  : 2024-03-07 15:20:49
// Revise  : 2024-03-10 18:32:49
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
`include "Cache.svh"
`include "Decoder.svh"

module LoadPipe (
  input logic clk,    // Clock
  input logic a_rst_n,  // Asynchronous reset active low
  input logic stall,
  input LoadPipeStage0InputSt stage0_input_st_i,
  input LoadPipeStage1InputSt stage1_input_st_i,
  input LoadPipeStage2InputSt stage2_input_st_i,
  output LoadPipeStage0OutputSt stage0_output_st_o,
  output LoadPipeStage1OutputSt stage1_output_st_o,
  output LoadPipeStage2OutputSt stage2_output_st_o
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

  /* stage 0 */
  // 接收 load 流水线计算出的虚拟地址
  // 使用虚拟地址查询 tag
  // 使用虚拟地址查询 meta

  always_comb begin : proc_stage0
    stage0_output_st_o.ready = ~stall | stage1_input_st_i.bank_conflict;
    stage0_output_st_o.valid = stage0_output_st_o.ready;
    stage0_output_st_o.vaddr = stage0_input_st_i.vaddr;
    stage0_output_st_o.asid = stage0_input_st_i.asid;
  end

  /* stage 1 */
  logic s1_valid;
  logic [`PROC_VALEN - 1:0] s1_vaddr;
  logic [2:0] s1_align_type;
  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      s1_vaddr <= 0;
      s1_align_type <= 0;
    end else begin
      if (stage0_output_st_o.valid) begin
        s1_vaddr <= stage0_input_st_i.vaddr;
        s1_align_type <= stage0_input_st_i.align_type;
      end
    end
  end
  // 获得 tag 查询结果
  // 获得 meta 查询结果
  // 进行 tag 匹配；判断 dcache 访问是否命中
  // 使用物理地址查询 data
  // 获取 replace_way 信息, 选出替换 way
  // 检查 bank 冲突
  // 生成新的plru信息
  logic miss;
  logic [`PROC_PALEN - 1:0] paddr;
  logic [$clog2(`DCACHE_ASSOCIATIVITY) - 1:0] replaced_way;
  logic [`DCACHE_ASSOCIATIVITY - 1:0] matched_way;
  logic [$clog2(`DCACHE_ASSOCIATIVITY) - 1:0] matched_way_idx;

  always_comb begin
    // 进行 tag 匹配
    matched_way_idx = '0;
    for (int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
      if (`DCACHE_TAG_OFFSET < 12) begin
        matched_way[i] = stage1_input_st_i.page_size == 6'd12 ?
                          {stage1_input_st_i.ppn, s1_vaddr[11:`DCACHE_TAG_OFFSET]} == 
                          stage1_input_st_i.tag[i] :
                          {stage1_input_st_i.ppn[`PROC_PALEN - 1:21], s1_vaddr[20:`DCACHE_TAG_OFFSET]} == 
                          stage1_input_st_i.tag[i];
      end else begin  // `DCACHE_TAG_OFFSET == 12
        matched_way[i] = stage1_input_st_i.page_size == 6'd12 ?
                          stage1_input_st_i.ppn == stage1_input_st_i.tag[i] :
                          {stage1_input_st_i.ppn[`PROC_PALEN - 1:21], s1_vaddr[20:`DCACHE_TAG_OFFSET]} == 
                          stage1_input_st_i.tag[i];
      end
      if (matched_way[i]) begin
        matched_way_idx = i;
      end
    end

    // 判断 dcache 访问是否命中
    miss = '1;
    for (int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
      miss &= ~(matched_way[i] & stage1_input_st_i.meta[i].valid);
    end
    stage1_output_st_o.miss = miss;

    // 使用物理地址查询 data
    if (stage1_input_st_i.page_size == 12) begin
      paddr = {stage1_input_st_i.ppn, s1_vaddr[11:0]};
    end else begin  //  page_size == 21
      paddr = {stage1_input_st_i.ppn[`PROC_PALEN - 1:21], s1_vaddr[20:0]};
    end
    stage1_output_st_o.paddr = paddr;

    // 检查 bank 冲突: DCache 内检查

    // 生成miss的替换信息
    // 获取 replace_way 信息, 选出替换 way
    replaced_way = stage1_input_st_i.plru;  // TODO: 真正实现PLRU
    stage1_output_st_o.replaced_way = replaced_way; 
    stage1_output_st_o.replaced_meta = stage1_input_st_i.meta[replaced_way];
    stage1_output_st_o.replaced_paddr = {stage1_input_st_i.tag[replaced_way], s1_vaddr[`DCACHE_TAG_OFFSET - 1:0]};

    // 生成新的plru信息
    stage1_output_st_o.plru = stage1_output_st_o.replaced_way == matched_way_idx ? 
                              ~stage1_input_st_i.plru : stage1_input_st_i.plru;
  end


  /* stage 2 */
  logic s2_valid;
  logic [`PROC_VALEN - 1:0] s2_paddr;
  logic [`PROC_PALEN - 1:12] s2_pnn;
  logic [2:0] s2_align_type;
  logic [`DCACHE_ASSOCIATIVITY - 1:0] s2_matched_way;

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      s2_valid <= '0;
      s2_paddr <= 0;
      s2_pnn <= 0;
      s2_matched_way = '0;
      s2_align_type <= '0;
    end else begin
      if (!stall) begin
        s2_valid <= s1_valid;
        s2_paddr <= paddr;
        s2_pnn <= stage1_input_st_i.ppn;
        s2_matched_way = matched_way;
        s2_align_type <= s1_align_type;
      end
    end
  end
  // 更新 replace_way(DCache内完成)
  // 获得 data 查询结果
  logic [`DCACHE_BANK_OFFSET - 1:0] btye_offset;
  logic [`BANK_BYTE_NUM / 4 - 1:0][31:0] matched_way_data;
  logic [31:0] matched_word;
  always_comb begin
    btye_offset = `DCACHE_BYTE_OF(s2_paddr);
    matched_way_data = '0;
    for (int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
      if (s2_matched_way[i]) begin
        matched_way_data = stage2_input_st_i.data;
      end
    end

    if (`DCACHE_BANK_OFFSET > 2) begin
      matched_word = matched_way_data[s2_paddr[`DCACHE_BANK_OFFSET - 1:2]];
    end else begin  // `DCACHE_BANK_OFFSET == 2
      matched_word = matched_way_data;
    end

    stage2_output_st_o.valid = s2_valid;
    
    case (s2_align_type)
      `ALIGN_TYPE_B: begin
        case (s2_paddr[1:0])
          2'b00: stage2_output_st_o.data = {{24{matched_word[7]}}, matched_word[7:0]};
          2'b01: stage2_output_st_o.data = {{24{matched_word[15]}}, matched_word[15:8]};
          2'b10: stage2_output_st_o.data = {{24{matched_word[23]}}, matched_word[23:16]};
          2'b11: stage2_output_st_o.data = {{24{matched_word[31]}}, matched_word[31:24]};
          default : /* default */;
        endcase
      end
      `ALIGN_TYPE_H: begin
        case (s2_paddr[1:0])
          2'b00: stage2_output_st_o.data = {{16{matched_word[15]}}, matched_word[15:0]};
          2'b10: stage2_output_st_o.data = {{16{matched_word[31]}}, matched_word[31:16]};
          default : /* default */;
        endcase
      end
      `ALIGN_TYPE_W: stage2_output_st_o.data = matched_word;
      `ALIGN_TYPE_BU: begin
        case (s2_paddr[1:0])
          2'b00: stage2_output_st_o.data = {{24{1'b0}}, matched_word[7:0]};
          2'b01: stage2_output_st_o.data = {{24{1'b0}}, matched_word[15:8]};
          2'b10: stage2_output_st_o.data = {{24{1'b0}}, matched_word[23:16]};
          2'b11: stage2_output_st_o.data = {{24{1'b0}}, matched_word[31:24]};
          default : /* default */;
        endcase
      end
      `ALIGN_TYPE_HU: begin
        case (s2_paddr[1:0])
          2'b00: stage2_output_st_o.data = {{16{1'b0}}, matched_word[15:0]};
          2'b10: stage2_output_st_o.data = {{16{1'b0}}, matched_word[31:16]};
          default : /* default */;
        endcase
      end
      default : /* default */;
    endcase
    
  end

endmodule : LoadPipe