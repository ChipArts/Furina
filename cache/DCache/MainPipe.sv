// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : MainPipe.sv
// Create  : 2024-03-08 17:19:38
// Revise  : 2024-03-08 22:40:30
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

module MainPipe (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input MainPipeStage0InputSt stage0_input_st_i,
  input MainPipeStage1InputSt stage1_input_st_i,
  input MainPipeStage2InputSt stage2_input_st_i,
  input MainPipeStage3InputSt stage3_input_st_i,
  output MainPipeStage0OutputSt stage0_output_st_o,
  output MainPipeStage1OutputSt stage1_output_st_o,
  output MainPipeStage2OutputSt stage2_output_st_o,
  output MainPipeStage3OutputSt stage3_output_st_o
);
  `RESET_LOGIC(clk, a_rst_n, rst_n);
  logic s1_stall, s2_stall, s3_stall;
  /* Stage 0 */
  // 仲裁传入的 Main Pipeline 请求选出优先级最高者
  // 发出 tag, meta 读请求
  // Main Pipeline 的争用存在以下优先级:
  //   1. probe_req (暂时不实现)
  //   2. replace_req (暂时不实现)
  //   3. store_req
  //   4. atomic_req (暂时不实现)

  always_comb begin
    stage0_output_st_o.store_ready = stage0_input_st_i.store_valid & ~s1_stall;
    stage0_output_st_o.vaddr = stage0_input_st_i.store_vaddr;
    s1_stall = s2_stall;
  end

  typedef enum logic[1:0] {
    IDLE,
    STORE
  } MemoryAccessType;

  MemoryAccessType s1_mem_ace_type;
  logic [2:0] s1_align_type;
  logic [`PROC_VALEN - 1:0] s1_vaddr;
  logic [31:0] s1_data;

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      s1_mem_ace_type <= IDLE;
      s1_align_type <= 0;
      s1_vaddr <= 0;
      s1_data <= 0;
    end else begin
      if (!s1_stall) begin
        s1_mem_ace_type <= STORE;
        s1_align_type <= stage0_input_st_i.align_type;
        s1_vaddr <= stage0_output_st_o.vaddr;
        s1_data <= stage0_input_st_i.data;
      end
    end
  end

  /* stage 1 */
  // 获得 tag/meta 查询结果
  // 进行 tag 匹配检查, 判断是否命中
  // 如果需要替换, 替换选择结果

  logic miss;
  logic [`PROC_PALEN - 1:0] paddr;
  logic [`DCACHE_ASSOCIATIVITY - 1:0] matched_way;

  always_comb begin
    // 进行 tag 匹配
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
    end

    if (stage1_input_st_i.page_size == 12) begin
      paddr = {stage1_input_st_i.ppn, s1_vaddr[11:0]};
    end else begin  //  page_size == 21
      paddr = {stage1_input_st_i.ppn[`PROC_PALEN - 1:21], s1_vaddr[20:0]};
    end

    // 判断 dcache 访问是否命中
    miss = '1;
    for (int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
      miss &= ~(matched_way[i] & stage1_input_st_i.meta[i].valid);
    end

    // 时钟算法新的值
    stage1_output_st_o.clk_algo = stage1_input_st_i.clk_algo + 1;

    // s2暂停判断
    s2_stall = ~stage2_input_st_i.valid;
  end

  logic s2_miss;
  logic [`PROC_PALEN - 1:0] s2_paddr;
  logic [`DCACHE_ASSOCIATIVITY - 1:0] s2_matched_way;
  MemoryAccessType s2_mem_ace_type;
  logic [2:0] s2_align_type;
  logic [31:0] s2_data;

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      s2_data <= '0;
      s2_paddr <= '0;
      s2_matched_way <= '0;
      s2_mem_ace_type <= IDLE;
      s2_align_type <= 0;
    end else begin
      if (!s2_stall) begin
        s2_data <= s1_data;
        s2_paddr <= paddr;
        s2_matched_way <= matched_way;
        s2_mem_ace_type <= s1_mem_ace_type;
        s2_align_type <= s1_align_type;
      end
    end
  end

  /* stage 2 */
  // 获得 data 查询结果
  // 获得读 data 的结果, 与要写入的数据拼合
  logic [(`DCACHE_BLOCK_SIZE / 4) - 1:0][31:0] matched_data;
  always_comb begin
    matched_data = stage2_input_st_i.data[0];
    for (int i = 1; i < `DCACHE_ASSOCIATIVITY; i++) begin
      if (s2_matched_way[i]) begin
        matched_data = stage2_input_st_i.data[i];
      end
    end

    stage2_output_st_o.data = matched_data;
    case (s2_align_type)
      `ALIGN_TYPE_B: begin
        stage2_output_st_o.data[`DCACHE_BYTE_OF(s2_paddr)] = s2_data[7:0];
      end
      `ALIGN_TYPE_H: begin
        stage2_output_st_o.data[`DCACHE_BYTE_OF(s2_paddr)] = s2_data[7:0];
        stage2_output_st_o.data[`DCACHE_BYTE_OF(s2_paddr) + 1] = s2_data[15:8];
      end
      `ALIGN_TYPE_W: stage2_output_st_o.data = matched_data;
      default : /* default */;
    endcase

    stage2_output_st_o.valid = s2_mem_ace_type == STORE;
  end


  /* stage 3 */
  // TODO: 暂不需要实现




endmodule : MainPipe
