// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : LoadPipe.sv
// Create  : 2024-03-07 15:20:49
// Revise  : 2024-03-07 23:13:57
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
  input LoadPipeStage0InputSt stage0_input_st_i,
  input LoadPipeStage1InputSt stage1_input_st_i,
  input LoadPipeStage2InputSt stage2_input_st_i,
  output LoadPipeStage0OutputSt stage0_output_st_o,
  output LoadPipeStage1OutputSt stage1_output_st_o,
  output LoadPipeStage2OutputSt stage2_output_st_o
);

  `RESET_LOGIC(clk, a_rst_n, rst_n)
  /* stage 0 */
  // 接收 load 流水线计算出的虚拟地址
  // 使用虚拟地址查询 tag
  // 使用虚拟地址查询 meta

  always_comb begin : proc_stage0
    stage0_output_st_o.ready = '1;
    stage0_output_st_o.vidx = `DCACHE_INDEX_OF(stage0_input_st_i.vaddr);
  end

  logic [`PROC_VALEN - 1:0] s1_vaddr;
  logic [2:0] s1_load_type;
  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      s1_vaddr <= 0;
      s1_load_type <= 0;
    end else begin
      s1_vaddr <= stage0_input_st_i.vaddr;
      s1_load_type <= stage0_input_st_i.load_type;
    end
  end


  /* stage 1 */
  // 获得 tag 查询结果
  // 获得 meta 查询结果
  // 进行 tag 匹配；判断 dcache 访问是否命中
  // 使用物理地址查询 data
  // 获取 replace_way 信息, 选出替换 way
  // 检查 bank 冲突

  logic miss;
  logic [`DCACHE_ASSOCIATIVITY - 1:0] tag_matched;
  logic [$clog2(`DCACHE_ASSOCIATIVITY) - 1:0] matched_way_idx;

  always_comb begin
    matched_way_idx = '0;
    // 进行 tag 匹配；
    for (int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
      if (`DCACHE_TAG_OFFSET < 12) begin
        tag_matched[i] = stage1_input_st_i.page_size == 6'd12 ?
                          {stage1_input_st_i.ppn, s1_vaddr[11:`DCACHE_TAG_OFFSET]} == 
                          stage1_input_st_i.tag[i] :
                          {stage1_input_st_i.ppn[`PROC_PALEN - 1:21], s1_vaddr[20:`DCACHE_TAG_OFFSET]} == 
                          stage1_input_st_i.tag[i];
      end else begin  // `DCACHE_TAG_OFFSET == 12
        tag_matched[i] = stage1_input_st_i.page_size == 6'd12 ?
                          stage1_input_st_i.ppn == stage1_input_st_i.tag[i] :
                          {stage1_input_st_i.ppn[`PROC_PALEN - 1:21], s1_vaddr[20:`DCACHE_TAG_OFFSET]} == 
                          stage1_input_st_i.tag[i];
      end
      if (tag_matched[i]) begin
        matched_way_idx = i;
      end
    end

    // 判断 dcache 访问是否命中
    miss = '1;
    for (int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
      miss &= ~(tag_matched[i] & stage1_input_st_i.valid[i]);
    end
    stage1_output_st_o.miss = miss;

    // 使用物理地址查询 data
    stage1_output_st_o.pidx = `DCACHE_INDEX_OF(s1_load_req_st.vaddr);
    // 获取 replace_way 信息, 选出替换 way，判断是否更新替换 way
    stage1_output_st_o.update_replace_way = (stage1_input_st_i.replace_way == matched_way_idx) & ~miss;
    stage1_output_st_o.replace_way = stage1_input_st_i.replace_way;

    // 检查 bank 冲突: DCache 内检查
    // 生成快速重发信号
    stage1_output_st_o.fast_repeat = stage1_input_st_i.bank_conflict;
  end

  logic s2_miss;
  logic [`PROC_VALEN - 1:0] s2_vaddr;
  logic [`PROC_PALEN - 1:12] s2_pnn;
  logic [2:0] s2_load_type;
  logic [`DCACHE_ASSOCIATIVITY - 1:0] s2_tag_matched;

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      s2_miss <= '0;
      s2_vaddr <= 0;
      s2_pnn <= 0;
      s2_tag_matched = '0;
      s2_load_type <= '0;
    end else begin
      s2_miss <= miss;
      s2_vaddr <= s1_vaddr;
      s2_pnn <= stage1_input_st_i.ppn;
      s2_tag_matched = tag_matched;
      s2_load_type <= s1_load_type;
    end
  end

  /* stage 2 */
  // 更新 replace_way(DCache内完成)
  // 获得 data 查询结果
  // 如果 miss, 尝试分配 MSHR (miss queue) 项(DCache内完成)
  logic [`DCACHE_BANK_OFFSET - 1:0] btye_offset;
  logic [`BANK_BYTE_NUM / 4 - 1:0][31:0] matched_way_data;
  logic [31:0] matched_word;
  always_comb begin
    btye_offset = `DCACHE_BYTE_OF(s2_vaddr);
    matched_way_data = '0;
    for (int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
      if (tag_matched[i]) begin
        matched_way_data = stage2_input_st_i.data;
      end
    end

    if (`DCACHE_BANK_OFFSET > 2) begin
      matched_word = matched_way_data[s2_vaddr[`DCACHE_BANK_OFFSET - 1:2]];
    end else begin  // `DCACHE_BANK_OFFSET == 2
      matched_word = matched_way_data;
    end


    
    case (s2_load_type)
      `LOAD_TYPE_BYTE: begin
        case (s2_vaddr[1:0])
          2'b00: stage2_output_st_o.data = {{24{matched_word[7]}}, matched_word[7:0]};
          2'b01: stage2_output_st_o.data = {{24{matched_word[15]}}, matched_word[15:8]};
          2'b10: stage2_output_st_o.data = {{24{matched_word[23]}}, matched_word[23:16]};
          2'b11: stage2_output_st_o.data = {{24{matched_word[31]}}, matched_word[31:24]};
          default : /* default */;
        endcase
      end
      `LOAD_TYPE_HALF: begin
        case (s2_vaddr[1:0])
          2'b00: stage2_output_st_o.data = {{16{matched_word[15]}}, matched_word[15:0]};
          2'b10: stage2_output_st_o.data = {{16{matched_word[31]}}, matched_word[31:16]};
          default : /* default */;
        endcase
      end
      `LOAD_TYPE_WORD: stage2_output_st_o.data = matched_word;
      `LOAD_TYPE_UBYTE: begin
        case (s2_vaddr[1:0])
          2'b00: stage2_output_st_o.data = {{24{1'b0}}, matched_word[7:0]};
          2'b01: stage2_output_st_o.data = {{24{1'b0}}, matched_word[15:8]};
          2'b10: stage2_output_st_o.data = {{24{1'b0}}, matched_word[23:16]};
          2'b11: stage2_output_st_o.data = {{24{1'b0}}, matched_word[31:24]};
          default : /* default */;
        endcase
      end
      `LOAD_TYPE_UHALF: begin
        case (s2_vaddr[1:0])
          2'b00: stage2_output_st_o.data = {{16{1'b0}}, matched_word[15:0]};
          2'b10: stage2_output_st_o.data = {{16{1'b0}}, matched_word[31:16]};
          default : /* default */;
        endcase
      end
      default : /* default */;
    endcase
    
  end

endmodule : LoadPipe