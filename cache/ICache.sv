// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : ICache.sv
// Create  : 2024-02-14 18:09:46
// Revise  : 2024-02-16 22:38:29
// Description :
//   指令位宽: 32bit
//   替换算法: 随机替换(时钟替换)
// Parameter   :
//   CACHE_SIZE: cache大小，单位(Byte)，必须是2的幂
//   BLOCK_SIZE: 一个cache块的大小(Byte)，必须是(2/4/8/16)Byte
//   ASSOCIATIVITY: cache的相联度，必须是2的幂
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// xx-xx-xx |            |     0.1     |    Original Version
// ==============================================================================

`include "config.svh"
`include "common.svh"
`include "ICache.svh"
`include "InstructionFetchUnit.svh"
`include "TranslationLookasideBuffer.svh"

module ICache #(
parameter
  int unsigned CACHE_SIZE = 1024 * 4,
  int unsigned BLOCK_SIZE = 16 * 4,
  int unsigned ASSOCIATIVITY = 4,
localparam
  int unsigned OFFSET_WIDTH = $clog2(BLOCK_SIZE),
  int unsigned INDEX_WIDTH = $clog2(CACHE_SIZE / ASSOCIATIVITY / BLOCK_SIZE),
  int unsigned TAG_WIDTH = `PROC_BIT_WIDTH - OFFSET_WIDTH - INDEX_WIDTH
)(
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input IFU2ICacheSt ifu2icache_st_i,
  input TLB2ICacheSt tlb2icache_st_i,
  output ICache2TLBSt icache2tlb_st_o,
  output ICache2IFUSt icache2ifu_st_o,
  AXI4.Master axi4_mst
);

  defparam axi4_mst.AXI_ADDR_WIDTH = `PROC_BIT_WIDTH;
  defparam axi4_mst.AXI_DATA_WIDTH = 32;

  `RESET_LOGIC(clk, a_rst_n, s_rst_n);

  /** ICache Ctrl Logic **/
  localparam IDEL = 0;    // 空闲
  localparam LOOKUP = 1;  // 查询
  localparam MISS = 2;    // 缺失
  localparam REFIIL = 3;  // 重填

  logic icache_stall;
  logic miss;
  logic [1:0] icache_state;
  logic [BLOCK_SIZE / 4 - 1:0][31:0] axi4_rdata_buffer;
  logic [$clog2(BLOCK_SIZE / 4) - 1:0] axi4_rdata_buffer_ptr;  // 字(32 bit)寻址
  logic r_axi4_r_last;
  logic [ASSOCIATIVITY - 1:0] icache_we;
  logic [INDEX_WIDTH - 1:0] icache_addr;
  logic [ASSOCIATIVITY - 1:0] icache_valid;  // icache valid 写入

  logic [`PROC_BIT_WIDTH - 1:0] r_vpc;
  logic [`PROC_BIT_WIDTH - 1:0] ppc;  // 物理pc

  // cache memory read out
  logic [ASSOCIATIVITY - 1:0] valid;
  logic [ASSOCIATIVITY - 1:0][TAG_WIDTH - 1:0] tag;
  logic [ASSOCIATIVITY - 1:0][BLOCK_SIZE * 8 - 1:0] data;
  logic [$clog2(ASSOCIATIVITY) - 1:0] replace_way_idx;

  // Stage 0: 读出Tag和Date, 查询tlb
  always_comb begin
    icache2tlb_st_i.fetch_ready = ifu2icache_st_i.fetch_valid & ~miss;
    icache2tlb_st_i.vpn = ifu2icache_st_i.vpc[`PROC_BIT_WIDTH - 1:$clog2(`PROC_PAGE_SIZE)];
  end

  always_ff @(posedge clk or negedge s_rst_n) begin
    if(~s_rst_n) begin
      r_vpc <= '0;
    end else begin
      if (~miss) begin
        r_vpc <= ifu2icache_st_i.vpc;
      end
    end
  end

  // Stage 1: 判断是否命中，命中则读出数据，否则进行充填
  always_comb begin
    ppc = {tlb2icache_st_i.ppn, r_vpc[$clog2(`PROC_PAGE_SIZE) - 1:0]};
    miss = '1;
    for (int i = 0; i < ASSOCIATIVITY; i++) begin
      miss = miss & (~valid[i] | (tag[i] != ppc[`PROC_BIT_WIDTH - 1:INDEX_WIDTH + OFFSET_WIDTH]));
    end
  end

  always_ff @(posedge clk or negedge s_rst_n) begin
    if(~s_rst_n) begin
       icache2ifu_st_o.miss <= '0;
    end else begin
       icache2ifu_st_o.miss <= miss;
    end
  end

  // ICache FSM
  always_ff @(posedge clk or negedge s_rst_n) begin : ICacheFSM
    if(~s_rst_n) begin
      icache_state <= IDEL;
    end else begin
      case (icache_state)
        IDEL : begin
          if(ifu2icache_st_i.fetch_valid) begin
            icache_state <= LOOKUP;
          end
        end
        LOOKUP : begin
          if(ifu2icache_st_i.fetch_valid) begin
            icache_state <= LOOKUP;
          end else begin
            if (miss) begin
              icache_state <= MISS;
            end else begin
              icache_state <= IDEL;
            end
          end
        end
        MISS : begin
          if (axi4_mst.ar_ready) begin
            icache_state <= REFIIL;
          end
        end
        REFIIL : begin
          if (axi4_mst.r_last) begin
            icache_state <= IDEL;
          end
        end
      endcase
    end
  end

  // ICache Refile Ctrl
  always_ff @(posedge clk or negedge s_rst_n) begin : ICacheRefileCtrl
    if(~s_rst_n) begin
      axi4_rdata_buffer <= '0;
      axi4_rdata_buffer_ptr <= r_vpc[OFFSET_WIDTH - 1:2];
    end else begin
      if (axi4_mst.r_valid) begin
        axi4_rdata_buffer[axi4_rdata_buffer_ptr] <= axi4_mst.r_data;
        axi4_rdata_buffer_ptr <= axi4_rdata_buffer_ptr + 1;
      end else begin
        axi4_rdata_buffer <= '0;
        axi4_rdata_buffer_ptr <= r_vpc[OFFSET_WIDTH - 1:2];
      end
    end
    r_axi4_r_last <= axi4_mst.r_last;
  end

  // ICache Memory Ctrl
  always_comb begin
    for (int i = 0; i < ASSOCIATIVITY; i++) begin
      icache_we[i] = i == replace_way_idx;
    end
    if (icache_state != REFIIL) begin
      icache_we = '0;
    end

    icache_addr = ifu2icache_st_i.vpc[INDEX_WIDTH + OFFSET_WIDTH - 1:OFFSET_WIDTH];
    if (icache_state == REFIIL) begin
      icache_addr = r_vpc[INDEX_WIDTH + OFFSET_WIDTH - 1:OFFSET_WIDTH];
    end

    icache_valid = valid;
    if (icache_state == REFIIL) begin
      icache_valid = icache_valid | icache_we;
    end
  end

  // AXI4 ctrl
  always_comb begin : AXICtrl
    axi.mst.aw_id = '0;
    axi.mst.aw_addr = '0;
    axi.mst.aw_len = '0;
    axi.mst.aw_size = '0;
    axi.mst.aw_burst = '0;
    axi.mst.aw_lock = '0;
    axi.mst.aw_cache = '0;
    axi.mst.aw_prot = '0;
    axi.mst.aw_qos = '0;
    axi.mst.aw_region = '0;
    axi.mst.aw_user = '0;
    axi.mst.aw_valid = '0;
    // input: axi.mst.aw_ready

    axi.mst.w_data = '0;
    axi.mst.w_strb = '0;
    axi.mst.w_last = '0;
    axi.mst.w_user = '0;
    axi.mst.w_valid = '0;
    // input: axi.mst.w_ready

    // input: axi.mst.b_id
    // input: axi.mst.b_resp
    // input: axi.mst.b_user
    // input: axi.mst.b_valid
    axi.mst.b_ready = '0;

    axi.mst.ar_id = '0;
    axi.mst.ar_addr = ppc;
    axi.mst.ar_len = (BLOCK_SIZE / 4) - 1;  // Number of data transfers
    axi.mst.ar_size = 3'b010;  // Bytes in transfer: 4
    axi.mst.ar_burst = 2'b10;  // Burst type: WRAP 回环突发
    axi.mst.ar_lock = '0;
    axi.mst.ar_cache = '0;
    axi.mst.ar_prot = '0;
    axi.mst.ar_qos = '0;
    axi.mst.ar_region = '0;
    axi.mst.ar_user = '0;
    axi.mst.ar_valid = miss;
    // input: axi.mst.ar_ready

    // input: axi.mst.r_id
    // input: axi.mst.r_data
    // input: axi.mst.r_resp
    // input: axi.mst.r_last
    // input: axi.mst.r_user
    // input: axi.mst.r_valid
    axi.mst.r_ready = icache_state == REFIIL;
  end

  /** ICache Memory **/
  for (genvar i = 0; i < ASSOCIATIVITY; i++) begin : ICacheMenory
    SinglePortRAM #(
      .DATA_DEPTH(1 << INDEX_WIDTH),
      .DATA_WIDTH(BLOCK_SIZE * 8),
      .BYTE_WRITE_WIDTH(BLOCK_SIZE * 8),
      .WRITE_MODE("write_first"),
      .MEMORY_PRIMITIVE("auto")
    ) U_ICacheData (
      .clk    (clk),
      .rst_n  (s_rst_n),
      .en_i   (ifu2icache_st_i.fetch_valid),
      .addr_i (icache_addr),
      .data_i (axi_rdata_buffer),
      .we_i   (icache_we[i]),
      .data_o (data[i])
    );
    SinglePortRAM #(
      .DATA_DEPTH(1 << INDEX_WIDTH),
      .DATA_WIDTH(TAG_WIDTH),
      .BYTE_WRITE_WIDTH(TAG_WIDTH),
      .WRITE_MODE("write_first"),
      .MEMORY_PRIMITIVE("auto")
    ) U_ICacheTag (
      .clk    (clk),
      .rst_n  (s_rst_n),
      .en_i   (ifu2icache_st_i.fetch_valid),
      .addr_i (icache_addr),
      .data_i (ppc[`PROC_BIT_WIDTH - 1:INDEX_WIDTH + OFFSET_WIDTH]),
      .we_i   (icache_we[i]),
      .data_o (tag[i])
    );
    SinglePortRAM #(
      .DATA_DEPTH(1 << INDEX_WIDTH),
      .DATA_WIDTH(1),
      .BYTE_WRITE_WIDTH(1),
      .WRITE_MODE("write_first"),
      .MEMORY_PRIMITIVE("auto")
    ) U_ICacheValid (
      .clk    (clk),
      .rst_n  (s_rst_n),
      .en_i   (ifu2icache_st_i.fetch_valid),
      .addr_i (icache_addr),
      .data_i (icache_valid[i]),
      .we_i   (icache_we[i]),
      .data_o (valid[i])
    );
  end

    // 时钟替换算法 存储
    SinglePortRAM #(
      .DATA_DEPTH(1 << INDEX_WIDTH),
      .DATA_WIDTH($clog2(ASSOCIATIVITY)),
      .BYTE_WRITE_WIDTH($clog2(ASSOCIATIVITY)),
      .WRITE_MODE("write_first"),
      .MEMORY_PRIMITIVE("auto")
    ) U_ClockAlgorithmMemory (
      .clk    (clk),
      .rst_n  (s_rst_n),
      .en_i   (ifu2icache_st_i.fetch_valid),
      .addr_i (icache_addr),
      .data_i (replace_way_idx + 1),
      .we_i   (axi4_mst.r_last),  // 充填完成后写入
      .data_o (replace_way_idx)
    );


endmodule : ICache