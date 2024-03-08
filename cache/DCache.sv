// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : DCache.sv
// Create  : 2024-03-03 15:28:53
// Revise  : 2024-03-03 15:29:07
// Description :
//   数据缓存
//   对核内访存组件暴露两个位宽为32的读端口和一个与一级数据缓存行宽度相同的写端口
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

module DCache (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input DCacheReadReqSt [1:0] read_req_st_i,
  input DCacheWriteReqSt write_req_st_i,
  output DcacheReadRspSt [1:0] read_rsp_st_o,
  output DcacheWriteRspSt write_rsp_st_o,
  AXI4.Master axi4_mst  // to L2 Cache
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

  //  axi4_mst.AXI_ADDR_WIDTH = `PROC_PALEN
  //  axi4_mst.AXI_DATA_WIDTH = `L2CACHE_BLOCK_SIZE
  //  axi4_mst.AXI_ID_WIDTH = 1
  //  axi4_mst.AXI_USER_WIDTH = 1


  //       Virtual Address
  // -----------------------------
  // | Tag | Index | Bank | BTYE |
  // -----------------------------
  //       |       |      |      |
  //       |       |      |      0
  //       |       |      DCacheBankOffset
  //       |       DCacheIndexOffset
  //       DCacheTagOffset



  initial begin
    assert (`BANK_BYTE_NUM > 0) else $error("DCache: BANK_BYTE_NUM <= 0");
    assert (`BANK_BYTE_NUM % 4 == 0) else $error("DCache: BANK_BYTE_NUM %% 2 != 0");  // 字节数必须是4的倍数
    assert (`DCACHE_INDEX_WIDTH <= 12) else $error("DCache: INDEX_WIDTH > 12");  // 避免产生虚拟地址重名问题
  end

  /* DCache Ctrl */
  // BANK冲突时LOAD优先

  logic [`DCACHE_BANK_NUM - 1:0][`DCACHE_INDEX_WIDTH - 1:0] data_ram_addr;
  logic [`DCACHE_ASSOCIATIVITY - 1:0][`DCACHE_BANK_NUM - 1:0][`BANK_BYTE_NUM - 1:0][7:0] data_ram_data_i;
  logic [`DCACHE_ASSOCIATIVITY - 1:0][`DCACHE_BANK_NUM - 1:0][`BANK_BYTE_NUM - 1:0][7:0] data_ram_data_o;
  logic [`DCACHE_ASSOCIATIVITY - 1:0] data_ram_we;


  always_comb begin
    for (int i = 0; i < `DCACHE_BANK_NUM; i++) begin
      if (read_req_st_i[0].valid && `BANK_OF(read_req_st_i[0].vaddr) == i) begin
          data_ram_addr[i] = `INDEX_OF(read_req_st_i[0].vaddr);
      end else begin
        if (read_req_st_i[0].valid && `BANK_OF(read_req_st_i[1].vaddr) == i) begin
          data_ram_addr[i] = `INDEX_OF(read_req_st_i[1].vaddr);
        end else begin
          data_ram_addr[i] = `INDEX_OF(write_req_st_i.vaddr);
        end
      end
    end
  end

  // Load Pipe


  // Main Pipe


  /* DCache Memory */
  // Data Memory: 每路 BANK_NUM 个单端口RAM
  for (genvar i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
    for (genvar j = 0; j < `DCACHE_BANK_NUM; j++) begin
      SinglePortRAM #(
        .DATA_DEPTH(2 ** `DCACHE_INDEX_WIDTH),  // index width
        .DATA_WIDTH(`BANK_BYTE_NUM * 8),  // BYTE_NUM * 8
        .BYTE_WRITE_WIDTH(`BANK_BYTE_NUM * 8),  // 以行为单位写
        .WRITE_MODE("write_first")
      ) U_DCacheDataRAM (
        .clk    (clk),
        .rst_n  (rst_n),
        .en_i   ('1),
        .addr_i (data_ram_addr[j]),
        .data_i (data_ram_data_i[j]),
        .we_i   (data_ram_we[i]),
        .data_o (data_ram_data_o[i][j])
      );
    end
  end
  // Tag Memory: 使用复制策略的多读单写RAM
  for (genvar i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
      for (genvar i = 0; i < 3; i++) begin
        SinglePortRAM #(
          .DATA_DEPTH(2 ** `DCACHE_INDEX_WIDTH),  // index width
          .DATA_WIDTH(`DCACHE_TAG_WIDTH),  // tag width
          .BYTE_WRITE_WIDTH(`DCACHE_TAG_WIDTH),
          .WRITE_MODE("write_first")
        ) U_DCacheTagRAM (
          .clk    (clk),
          .rst_n  (rst_n),
          .en_i   (en_i),
          .addr_i (addr_i),
          .data_i (data_i),
          .we_i   (we_i),
          .data_o (data_o)
        );
        SinglePortRAM #(
          .DATA_DEPTH(2 ** `DCACHE_INDEX_WIDTH),  // index width
          .DATA_WIDTH(1 + 1 + 2),  // VALID + DIRTY + PLV[1:0]
          .BYTE_WRITE_WIDTH(1 + 1 + 2),
          .WRITE_MODE("write_first")
        ) U_DCacheMetaRAM (
          .clk    (clk),
          .rst_n  (rst_n),
          .en_i   (en_i),
          .addr_i (addr_i),
          .data_i (data_i),
          .we_i   (we_i),
          .data_o (data_o)
        );
      end
  end





endmodule : DCache
