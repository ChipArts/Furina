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
`include "Cache.svh"
`include "MemoryManagementUnit.svh"

module ICache (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input ICacheFetchReqSt fetch_req_st,
  input MMU_SearchRspSt mmu_search_rsp_st,
  output ICacheFetchRspSt fetch_rsp_st,
  output MMU_SearchReqSt mmu_search_req_st,
  AXI4.Master axi4_mst
);

  `RESET_LOGIC(clk, a_rst_n, s_rst_n);

  /* ICache Ctrl */
  logic stall;
  // memory ctrl
  logic [`ICACHE_ASSOCIATIVITY - 1:0] data_ram_we;  // 控制写入哪个way，目前的架构按行写入，无需分bank
  logic [`ICACHE_INDEX_WIDTH - 1:0] data_ram_waddr;  // 写入每个way的cache行地址(idx)相同
  logic [`ICACHE_BLOCK_SIZE - 1:0] data_ram_raddr;  // 分bank读取每个way的数据
  logic [`ICACHE_BLOCK_SIZE - 1:0][7:0] data_ram_data_i;  // 要写入的cache行的数据
  logic [`ICACHE_ASSOCIATIVITY - 1:0][(`ICACHE_BLOCK_SIZE / 4) - 1:0][31:0] data_ram_data_o;

  logic [`ICACHE_ASSOCIATIVITY - 1:0] tag_ram_we;
  logic [`ICACHE_INDEX_WIDTH - 1:0] tag_ram_waddr;
  logic [`ICACHE_INDEX_WIDTH - 1:0] tag_ram_raddr;
  logic [`ICACHE_TAG_WIDTH - 1:0] tag_ram_data_i;
  logic [`ICACHE_ASSOCIATIVITY - 1:0][`ICACHE_TAG_WIDTH - 1:0] tag_ram_data_o;

  logic [`ICACHE_ASSOCIATIVITY - 1:0] valid_ram_we;
  logic [`ICACHE_INDEX_WIDTH - 1:0] valid_ram_waddr;
  logic [`ICACHE_INDEX_WIDTH - 1:0] valid_ram_raddr;
  logic valid_ram_data_i;
  logic [`ICACHE_ASSOCIATIVITY - 1:0] valid_ram_data_o;

  logic  plru_ram_we;
  logic [`ICACHE_INDEX_WIDTH - 1:0] plru_ram_waddr;
  logic [`ICACHE_INDEX_WIDTH - 1:0] plru_ram_raddr;
  logic [`ICACHE_ASSOCIATIVITY - 2:0] plru_ram_data_o;
  logic [`ICACHE_ASSOCIATIVITY - 2:0] plru_ram_data_i;

  // stage 0
  // 接收 取指令 虚拟地址
  // 使用虚拟地址查询 tag
  // 使用虚拟地址查询 valid
  // 使用虚拟地址查询 plru
  // 使用虚拟地址查询 tlb
  // 使用虚拟地址查询 data
  always_comb begin
    fetch_rsp_st.ready = ~stall;
  end

  // stage 1
  logic [`FETCH_WIDTH - 1:0] s1_valid;
  logic [`PROC_VALEN - 1:0] s1_vaddr;
  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      s1_valid <= '0;
      s1_vaddr <= 0;
    end else begin
      if (~stall) begin
        s1_valid <= fetch_req_st.valid;
        s1_vaddr <= fetch_req_st.vaddr;
      end
    end
  end
  // 获得 tag 查询结果
  // 获得 mmu 查询结果
  // 获得 meta 查询结果
  // 进行 tag 匹配；判断 icache 访问是否命中
  // 获得 plru 信息, 选出替换 way
  // 生成新的plru信息
  // 生成 inst 输出
  logic miss;
  logic [`PROC_PALEN - 1:0] paddr;
  logic [$clog2(`DCACHE_ASSOCIATIVITY) - 1:0] replaced_way;
  logic [$clog2(`DCACHE_ASSOCIATIVITY) - 1:0] matched_way;
  logic [`DCACHE_ASSOCIATIVITY - 1:0] matched_way_oh;  // one hot
  logic [`DCACHE_ASSOCIATIVITY - 2:0] new_plru;

  always_comb begin
    paddr = mmu_search_rsp_st.paddr;

    // 进行 tag 匹配
    matched_way_oh = '0;
    for (int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
      matched_way_oh[i] = `DCACHE_TAG_OF(paddr) == tag_ram_data_o[i];
      if (matched_way_oh[i]) begin
        matched_way = i;
      end
    end

    // 判断 dcache 访问是否命中
    miss = '1;
    for (int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
      miss &= ~(matched_way_oh[i] & valid_ram_data_o[i]);
    end

    // 获得 plru 信息, 选出替换 way
    replaced_way = plru_ram_data_o;  // TODO: 真正实现PLRU
    // 生成新的plru信息
    new_plru = replaced_way == matched_way | miss ? ~plru_ram_data_o : plru_ram_data_o;

    // 生成 inst 输出
    fetch_rsp_st.valid = s1_valid & ~{`FETCH_WIDTH{miss}};
    for (int i = 0; i < `FETCH_WIDTH; i++) begin
      fetch_rsp_st.vaddr[i] = s1_vaddr + 4;
      fetch_rsp_st.instructions[i] = data_ram_data_o[matched_way][`ICACHE_WORD_OF(s1_vaddr) + i];
    end
  end

  // ICache FSM
  typedef enum logic [1:0] {
    IDEL,  // ICache正常工作
    MISS,  // ICache miss，Cache的访存请求发出，等待axi的rd_ready信号
    REFIIL  // 等待axi的r_valid/r_last信号，重启流水线
  } ICacheState;

  ICacheState icache_state;

  always_comb begin
    stall = miss;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      icache_state <= IDEL;
    end else begin
      case (icache_state)
        IDEL : if (miss) icache_state <= MISS;
        MISS : if (axi4_mst.rd_ready) icache_state <= REFIIL;
        REFIIL : if (axi4_mst.r_last) icache_state <= IDEL;
        default : /* default */;
      endcase 
    end
  end

  // Memory Ctrl
  always_comb begin
    // data ram
    for (int i = 0; i < `ICACHE_ASSOCIATIVITY; i++) begin
      data_ram_we[i] = icache_state == REFIIL & replaced_way == i & axi4_mst.r_last;
    end
    data_ram_waddr = `ICACHE_INDEX_OF(s1_vaddr);
    data_ram_data_i = axi4_mst.r_data;
    data_ram_raddr = `ICACHE_INDEX_OF(fetch_req_st.vaddr);
    // tag ram
    for (int i = 0; i < `ICACHE_ASSOCIATIVITY; i++) begin
      tag_ram_we[i] = icache_state == REFIIL & replaced_way == i & axi4_mst.r_last;
    end
    tag_ram_waddr = `ICACHE_INDEX_OF(s1_vaddr);
    tag_ram_data_i = `ICACHE_TAG_OF(paddr);
    tag_ram_raddr = `ICACHE_INDEX_OF(fetch_req_st.vaddr);
    // valid ram
    for (int i = 0; i < `ICACHE_ASSOCIATIVITY; i++) begin
      valid_ram_we = icache_state == REFIIL & replaced_way == i & axi4_mst.r_last;
    end
    valid_ram_waddr = `ICACHE_INDEX_OF(s1_vaddr);
    valid_ram_data_i = '1;
    valid_ram_raddr = `ICACHE_INDEX_OF(fetch_req_st.vaddr);
    // plru ram
    plru_ram_we = '1;
    plru_ram_waddr = `ICACHE_INDEX_OF(s1_vaddr);
    plru_ram_data_i = new_plru;
    plru_ram_raddr = `ICACHE_INDEX_OF(fetch_req_st.vaddr);
  end

  // AXI Ctrl
  always_comb begin
    axi4_mst.aw_id = '0;
    axi4_mst.aw_addr = '0;
    axi4_mst.aw_len = '0;
    axi4_mst.aw_size = '0;
    axi4_mst.aw_burst = '0;
    axi4_mst.aw_lock = '0;
    axi4_mst.aw_cache = '0;
    axi4_mst.aw_prot = '0;
    axi4_mst.aw_qos = '0;
    axi4_mst.aw_region = '0;
    axi4_mst.aw_user = '0;
    axi4_mst.aw_valid = '0;
    // input: axi4_mst.aw_ready

    axi4_mst.w_data = '0;
    axi4_mst.w_strb = '0;
    axi4_mst.w_last = '0;
    axi4_mst.w_user = '0;
    axi4_mst.w_valid = '0;
    // input: axi4_mst.w_ready

    // input: axi4_mst.b_id
    // input: axi4_mst.b_resp
    // input: axi4_mst.b_user
    // input: axi4_mst.b_valid
    axi4_mst.b_ready = '0;

    axi4_mst.ar_id = '0;
    axi4_mst.ar_addr = paddr;
    axi4_mst.ar_len = 4'b0000;
    axi4_mst.ar_size = $clog2(`ICACHE_BLOCK_SIZE);
    axi4_mst.ar_burst = '0;
    axi4_mst.ar_lock = '0;
    axi4_mst.ar_cache = '0;
    axi4_mst.ar_prot = '0;
    axi4_mst.ar_qos = '0;
    axi4_mst.ar_region = '0;
    axi4_mst.ar_user = '0;
    axi4_mst.ar_valid = icache_state == MISS;
    // input: axi4_mst.ar_ready

    // input: axi4_mst.r_id
    // input: axi4_mst.r_data
    // input: axi4_mst.r_resp
    // input: axi4_mst.r_last
    // input: axi4_mst.r_user
    // input: axi4_mst.r_valid
    axi4_mst.r_ready = icache_state == REFIIL;
  end


  /* ICache Memory */
  // Data Memory: 每路 BANK_NUM 个单端口RAM
  for (genvar i = 0; i < `ICACHE_ASSOCIATIVITY; i++) begin
    SimpleDualPortRAM #(
      .DATA_DEPTH(2 ** `ICACHE_INDEX_WIDTH),
      .DATA_WIDTH(`BANK_BYTE_NUM * 8),
      .BYTE_WRITE_WIDTH(`BANK_BYTE_NUM * 8),
      .CLOCKING_MODE("common_clock"),
      .WRITE_MODE("write_first")
    ) U_ICacheDataRAM (
      .clk_a    (clk),
      .en_a_i   ('1),
      .we_a_i   (data_ram_we[i]),
      .addr_a_i (data_ram_waddr),
      .data_a_i (data_ram_data_i),
      .clk_b    (clk),
      .rstb_n   (rst_n),
      .en_b_i   ('1),
      .addr_b_i (data_ram_raddr),
      .data_b_o (data_ram_data_o[i])
    );
  end
  // Tag Memory:
  for (genvar i = 0; i < `ICACHE_ASSOCIATIVITY; i++) begin
    SimpleDualPortRAM #(
      .DATA_DEPTH(2 ** `ICACHE_INDEX_WIDTH),
      .DATA_WIDTH(`ICACHE_TAG_WIDTH),
      .BYTE_WRITE_WIDTH(`BANK_BYTE_NUM * 8),
      .CLOCKING_MODE("common_clock"),
      .WRITE_MODE("write_first")
    ) U_ICacheTagRAM (
      .clk_a    (clk),
      .en_a_i   ('1),
      .we_a_i   (tag_ram_we[i]),
      .addr_a_i (tag_ram_waddr),
      .data_a_i (tag_ram_data_i),
      .clk_b    (clk),
      .rstb_n   (rst_n),
      .en_b_i   ('1),
      .addr_b_i (tag_ram_raddr),
      .data_b_o (tag_ram_data_o[i])
    );
    SimpleDualPortRAM #(
      .DATA_DEPTH(2 ** `ICACHE_INDEX_WIDTH),
      .DATA_WIDTH(1),
      .BYTE_WRITE_WIDTH(1),
      .CLOCKING_MODE("common_clock"),
      .WRITE_MODE("write_first")
    ) U_ICacheValidRAM (
      .clk_a    (clk),
      .en_a_i   ('1),
      .we_a_i   (valid_ram_we[i]),
      .addr_a_i (valid_ram_waddr),
      .data_a_i (valid_ram_data_i),
      .clk_b    (clk),
      .rstb_n   (rst_n),
      .en_b_i   ('1),
      .addr_b_i (valid_ram_raddr),
      .data_b_o (valid_ram_data_o[i])
    );
  end

  SimpleDualPortRAM #(
    .DATA_DEPTH(2 ** `ICACHE_INDEX_WIDTH),
    .DATA_WIDTH(`ICACHE_ASSOCIATIVITY - 1),
    .BYTE_WRITE_WIDTH(`ICACHE_ASSOCIATIVITY - 1),
    .CLOCKING_MODE("common_clock"),
    .WRITE_MODE("write_first"),
    .MEMORY_PRIMITIVE("auto")
  ) U_ICachePlruRAM (
    .clk_a    (clk),
    .en_a_i   ('1),
    .we_a_i   (plru_ram_we),
    .addr_a_i (plru_ram_waddr),
    .data_a_i (plru_ram_data_i),
    .clk_b    (clk),
    .rstb_n   (rst_n),
    .en_b_i   ('1),
    .addr_b_i (plru_ram_raddr),
    .data_b_o (plru_ram_data_o)
  );


  
endmodule : ICache