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
`include "TranslationLookasideBuffer.svh"

module DCache (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input DCacheLoadReqSt [1:0] load_req_st_i,
  input DCacheStoreReqSt store_req_st_i,
  input TLBSearchRspSt [1:0] tlb_search_rsp_st_i,
  output DCacheLoadRspSt [1:0] load_rsp_st_o,
  output DCacheStoreRspSt store_rsp_st_o,
  output TLBSearchReqSt [1:0] tlb_search_req_st_o,
  AXI4.Master axi4_mst  // to L2 Cache
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

  //  axi4_mst.AXI_ADDR_WIDTH = `PROC_PALEN
  //  axi4_mst.AXI_DATA_WIDTH = `DCACHE_BLOCK_SIZE
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
    assert (`DCACHE_BLOCK_SIZE == 1 << $clog2(`DCACHE_BLOCK_SIZE)) else $error("DCache: BLOCK_SIZE is not power of 2");
  end

  /* DCache Ctrl */
  // pipe ctrl
  logic stall;
  logic [1:0] bank_conflict;
  LoadPipeStage0InputSt [1:0] load_pipe_stage0_input_st;
  LoadPipeStage1InputSt [1:0] load_pipe_stage1_input_st;
  LoadPipeStage2InputSt [1:0] load_pipe_stage2_input_st;
  LoadPipeStage0OutputSt [1:0] load_pipe_stage0_output_st;
  LoadPipeStage1OutputSt [1:0] load_pipe_stage1_output_st;
  LoadPipeStage2OutputSt [1:0] load_pipe_stage2_output_st;

  MainPipeStage0InputSt main_pipe_stage0_input_st;
  MainPipeStage1InputSt main_pipe_stage1_input_st;
  MainPipeStage2InputSt main_pipe_stage2_input_st;
  MainPipeStage3InputSt main_pipe_stage3_input_st;
  MainPipeStage0OutputSt main_pipe_stage0_output_st;
  MainPipeStage1OutputSt main_pipe_stage1_output_st;
  MainPipeStage2OutputSt main_pipe_stage2_output_st;
  MainPipeStage3OutputSt main_pipe_stage3_output_st;

  // memory ctrl
  logic [`DCACHE_ASSOCIATIVITY - 1:0] data_ram_we;  // 控制写入哪个way，目前的架构按行写入，无需分bank
  logic [`DCACHE_INDEX_WIDTH - 1:0] data_ram_waddr;  // 写入每个way的cache行地址(idx)相同
  logic [`DCACHE_BANK_NUM - 1:0][`DCACHE_INDEX_WIDTH - 1:0] data_ram_raddr;  // 分bank读取每个way的数据
  logic [`DCACHE_BANK_NUM - 1:0][`BANK_BYTE_NUM - 1:0][7:0] data_ram_data_i;  // 要写入的cache行的数据
  logic [`DCACHE_ASSOCIATIVITY - 1:0][`DCACHE_BANK_NUM - 1:0][`BANK_BYTE_NUM - 1:0][7:0] data_ram_data_o;

  logic [`DCACHE_ASSOCIATIVITY - 1:0] tag_ram_we;
  logic [`DCACHE_INDEX_WIDTH - 1:0] tag_ram_waddr;
  logic [1:0][`DCACHE_INDEX_WIDTH - 1:0] tag_ram_raddr;
  logic [`DCACHE_TAG_WIDTH - 1:0] tag_ram_data_i;
  logic [1:0][`DCACHE_ASSOCIATIVITY - 1:0][`DCACHE_TAG_WIDTH - 1:0] tag_ram_data_o;

  logic [`DCACHE_ASSOCIATIVITY - 1:0] meta_ram_we;
  logic [`DCACHE_INDEX_WIDTH - 1:0] meta_ram_waddr;
  logic [1:0][`DCACHE_INDEX_WIDTH - 1:0] meta_ram_raddr;
  DCacheMetaInfoSt meta_ram_data_i;
  DCacheMetaInfoSt [1:0][`DCACHE_ASSOCIATIVITY - 1:0] meta_ram_data_o;

  logic [1:0] plru_ram_we;
  logic [1:0][`DCACHE_INDEX_WIDTH - 1:0] plru_ram_waddr;
  logic [1:0][`DCACHE_INDEX_WIDTH - 1:0] plru_ram_raddr;
  logic [1:0][`DCACHE_ASSOCIATIVITY - 2:0] plru_ram_data_o;
  logic [1:0][`DCACHE_ASSOCIATIVITY - 2:0] plru_ram_data_i;

  // FSM ctrl
  typedef enum logic [1:0] {
    IDEL,  // 流水线正常工作
    MISS,  // Cache缺失，等待axi的wr_ready信号
    REPLACE,  // 替换的Cache行读出，等待axi的w_ready信号
    LOOKUP,  // Cache的访存请求发出，等待axi的rd_ready信号
    REFIIL  // 等待axi的r_valid信号，重启流水线
  } DCacheState;
  DCacheState dcache_state;
  logic [2:0] dcache_miss;  // {main, load[1], load[0]}
  DCacheMetaInfoSt replaced_meta;  // 判断是否需要写回
  logic [`PROC_PALEN - 1:0] replaced_paddr;  // 被替换数据的物理地址
  logic [$clog2(`DCACHE_ASSOCIATIVITY) - 1:0] replaced_way;  // 决定那一路会被换出
  logic [`DCACHE_BLOCK_SIZE - 1:0][7:0] replaced_data;  // 写回下级存储器的数据
  logic [`DCACHE_TAG_WIDTH - 1:0] refilled_tag; // 充填的tag
  DCacheMetaInfoSt refilled_meta;  // 充填的meta信息
  logic [`DCACHE_BLOCK_SIZE - 1:0][7:0] refilled_data;  // 充填的数据

  // DCache FSM Ctrl
  always_comb begin

    dcache_miss[0] = load_pipe_stage1_output_st[0].valid & load_pipe_stage1_output_st[0].miss;
    dcache_miss[1] = load_pipe_stage1_output_st[1].valid & load_pipe_stage1_output_st[1].miss;
    dcache_miss[2] = main_pipe_stage1_output_st.valid & main_pipe_stage1_output_st.miss;


    if (dcache_miss[0]) begin
      replaced_paddr = load_pipe_stage1_output_st[0].replaced_paddr;
      replaced_meta = load_pipe_stage1_output_st[0].replaced_meta;

      refilled_meta.valid = '1;
      refilled_meta.dirty = '0;
      refilled_meta.plv = tlb_search_rsp_st_i[0].plv;
    end else begin
      if (dcache_miss[1]) begin
        replaced_paddr = load_pipe_stage1_output_st[1].replaced_paddr;
        replaced_meta = load_pipe_stage1_output_st[1].replaced_meta;

        refilled_meta.valid = '1;
        refilled_meta.dirty = '0;
        refilled_meta.plv = tlb_search_rsp_st_i[1].plv;
      end else begin
        replaced_paddr = main_pipe_stage1_output_st.replaced_paddr;
        replaced_meta = main_pipe_stage1_output_st.replaced_meta;

        refilled_meta.valid = '1;
        refilled_meta.dirty = '0;
        refilled_meta.plv = tlb_search_rsp_st_i[0].plv;
      end
    end
    replaced_data = data_ram_data_o[replaced_way];
    refilled_data = axi4_mst.r_data;
    refilled_tag = `DCACHE_TAG_OF(replaced_paddr);
    
  end
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      dcache_state <= IDEL;
      refilled_tag <= '0;
    end else begin
      case (dcache_state)
        IDEL : if (|dcache_miss) dcache_state <= MISS;
        MISS : if (axi4_mst.aw_ready || 
                   !replaced_meta.dirty ||
                   !replaced_meta.valid) dcache_state <= REFIIL;
        REPLACE : if (axi4_mst.w_ready) dcache_state <= LOOKUP;
        LOOKUP : if (axi4_mst.ar_ready) dcache_state <= REFIIL;
        REFIIL : if (axi4_mst.r_valid) dcache_state <= IDEL;
        default : /* default */;
      endcase
    end
  end

  // Memory Ctrl
  always_comb begin
    /* data ram */
    for (int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
      // DCache refill or store
      data_ram_we[i] = dcache_state == REFIIL ? 
                        replaced_way == i & axi4_mst.r_valid: 
                        main_pipe_stage2_output_st.we[i] & 
                        main_pipe_stage2_output_st.valid;
    
    end
    data_ram_waddr = `DCACHE_INDEX_OF(replaced_paddr);
    data_ram_data_i = dcache_state == REFIIL ? refilled_data :
                      main_pipe_stage2_output_st.data;
    // 利用特性replaced data和data idx相同
    for (int i = 0; i < `DCACHE_BANK_NUM; i++) begin
      data_ram_raddr[i] = load_pipe_stage1_output_st[0].valid ? 
                          `DCACHE_INDEX_OF(load_pipe_stage1_output_st[0].paddr) :
                          load_pipe_stage1_output_st[1].valid ?
                          `DCACHE_INDEX_OF(load_pipe_stage1_output_st[1].paddr) :
                          `DCACHE_INDEX_OF(main_pipe_stage1_output_st.paddr);
    end

    /* tag ram */
    for (int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
      tag_ram_we[i] = dcache_state == REFIIL & replaced_way == i;
    end
    tag_ram_waddr = `DCACHE_INDEX_OF(replaced_paddr);
    tag_ram_data_i = refilled_tag;
    tag_ram_raddr[0] = load_pipe_stage0_output_st[0].valid ? 
                       `DCACHE_INDEX_OF(load_pipe_stage0_output_st[0].vaddr) :
                       `DCACHE_INDEX_OF(main_pipe_stage0_output_st.vaddr);
    tag_ram_raddr[1] = `DCACHE_INDEX_OF(load_pipe_stage0_output_st[1].vaddr);

    /* meta ram */
    for (int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
      meta_ram_we[i] = dcache_state == REFIIL ? replaced_way == i & axi4_mst.r_valid: 
                                                main_pipe_stage2_output_st.we[i] & 
                                                main_pipe_stage2_output_st.valid ;
    end
    meta_ram_waddr = `DCACHE_INDEX_OF(replaced_paddr);
    meta_ram_data_i = dcache_state == REFIIL ? replaced_meta:
                      main_pipe_stage2_output_st.meta;
    meta_ram_raddr[0] = load_pipe_stage0_output_st[0].valid ? 
                        `DCACHE_INDEX_OF(load_pipe_stage0_output_st[0].vaddr) :
                        `DCACHE_INDEX_OF(main_pipe_stage0_output_st.vaddr);
    meta_ram_raddr[1] = `DCACHE_INDEX_OF(load_pipe_stage0_output_st[1].vaddr);

    /* plru ram */
    plru_ram_we[0] = load_pipe_stage1_output_st[0].valid | main_pipe_stage1_output_st.valid;
    plru_ram_we[1] = load_pipe_stage1_output_st[1].valid;
    plru_ram_waddr[0] = load_pipe_stage1_output_st[0].valid ? 
                        `DCACHE_INDEX_OF(load_pipe_stage1_output_st[0].paddr) :
                        `DCACHE_INDEX_OF(main_pipe_stage1_output_st.paddr);
    plru_ram_waddr[1] = `DCACHE_INDEX_OF(load_pipe_stage1_output_st[1].paddr);
    plru_ram_data_i[0] = load_pipe_stage1_output_st[0].valid ? 
                         load_pipe_stage1_output_st[0].plru :
                         main_pipe_stage1_output_st.plru;
    plru_ram_data_i[1] = load_pipe_stage1_output_st[1].plru;
    plru_ram_raddr[0] = load_pipe_stage0_output_st[0].valid ? 
                        `DCACHE_INDEX_OF(load_pipe_stage0_output_st[0].vaddr) :
                        `DCACHE_INDEX_OF(main_pipe_stage0_output_st.vaddr);
    plru_ram_raddr[1] = `DCACHE_INDEX_OF(load_pipe_stage0_output_st[1].vaddr);
  end


  // DCache Pipe
  for (genvar i = 0; i < 2; i++) begin
    LoadPipe U_LoadPipe
    (
      .clk                (clk),
      .a_rst_n            (rst_n),
      .stall              (stall),
      .stage0_input_st_i  (load_pipi_stage0_input_st),
      .stage1_input_st_i  (load_pipi_stage1_input_st),
      .stage2_input_st_i  (load_pipi_stage2_input_st),
      .stage0_output_st_o (load_pipi_stage0_output_st),
      .stage1_output_st_o (load_pipi_stage1_output_st),
      .stage2_output_st_o (load_pipi_stage2_output_st)
    );
  end

  MainPipe U_MainPipe
  (
    .clk                (clk),
    .a_rst_n            (rst_n),
    .stall              (stall),
    .stage0_input_st_i  (main_pipe_stage0_input_st),
    .stage1_input_st_i  (main_pipe_stage1_input_st),
    .stage2_input_st_i  (main_pipe_stage2_input_st),
    .stage3_input_st_i  (main_pipe_stage3_input_st),
    .stage0_output_st_o (main_pipe_stage0_output_st),
    .stage1_output_st_o (main_pipe_stage1_output_st),
    .stage2_output_st_o (main_pipe_stage2_output_st),
    .stage3_output_st_o (main_pipe_stage3_output_st)
  );

  // DCache Pipe Ctrl
  always_comb begin
    stall = dcache_state != IDEL | |dcache_miss;
    for (int i = 0; i < 2; i++) begin
      load_pipe_stage0_input_st[i].valid = load_req_st_i[i].valid & ~load_req_st_i[i].store_req;
      load_pipe_stage0_input_st[i].vaddr = load_req_st_i[i].vaddr;
      load_pipe_stage0_input_st[i].align_type = load_req_st_i[i].align_type;

      load_pipe_stage1_input_st[i].valid = tlb_search_rsp_st_i[i].valid;
      load_pipe_stage1_input_st[i].ppn = tlb_search_rsp_st_i[i].ppn;
      load_pipe_stage1_input_st[i].page_size = tlb_search_rsp_st_i[i].page_size;
      load_pipe_stage1_input_st[i].plv = tlb_search_rsp_st_i[i].plv;
      load_pipe_stage1_input_st[i].meta = meta_ram_data_o;
      load_pipe_stage1_input_st[i].tag = tag_ram_data_o[i];
      load_pipe_stage1_input_st[i].plru = plru_ram_data_i[i];
      load_pipe_stage1_input_st[i].bank_conflict = bank_conflict[i];

      load_pipe_stage2_input_st[i].valid = dcache_state == IDEL;
      load_pipe_stage2_input_st[i].data = data_ram_data_o;
    end

    main_pipe_stage0_input_st.store_valid = store_req_st_i.valid;
    main_pipe_stage0_input_st.vaddr = store_req_st_i.vaddr;
    main_pipe_stage0_input_st.data = store_req_st_i.data;
    main_pipe_stage0_input_st.align_type = store_req_st_i.align_type;

    main_pipe_stage1_input_st.valid = tlb_search_rsp_st_i[0].valid;
    main_pipe_stage1_input_st.ppn = tlb_search_rsp_st_i[0].ppn;
    main_pipe_stage1_input_st.page_size = tlb_search_rsp_st_i[0].page_size;
    main_pipe_stage1_input_st.plv = tlb_search_rsp_st_i[0].plv;
    main_pipe_stage1_input_st.meta = meta_ram_data_o[0];
    main_pipe_stage1_input_st.tag = tag_ram_data_o[0];

    main_pipe_stage2_input_st.valid = dcache_state == IDEL;
    main_pipe_stage2_input_st.data = data_ram_data_o[0];

    main_pipe_stage3_input_st.valid = '0;


    // dcache rsp
    for (int i = 0; i < 2; i++) begin
      load_rsp_st_o[i].valid = load_pipe_stage2_output_st[i].valid;
      load_rsp_st_o[i].data = load_pipe_stage2_output_st[i].data;
      load_rsp_st_o[i].ready = load_pipe_stage0_output_st[i].ready;
    end
    store_rsp_st_o.valid = main_pipe_stage2_output_st.valid;
    store_rsp_st_o.ready = main_pipe_stage0_output_st.ready;
    store_rsp_st_o.okay = main_pipe_stage2_output_st.valid;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      bank_conflict <= '0;
    end else begin
      // 简化处理，load[0]优先
      bank_conflict[0] <= '0;
      bank_conflict[1] <= `DCACHE_BANK_OF(load_pipe_stage0_input_st[0].vaddr) ==
                          `DCACHE_BANK_OF(load_pipe_stage0_input_st[0].vaddr);
    end
  end

  // TLB Ctrl
  always_comb begin
    tlb_search_req_st_o[0].valid = load_pipe_stage0_output_st[0].valid | main_pipe_stage0_output_st.valid;
    tlb_search_req_st_o[0].vpn = load_pipe_stage0_output_st[0].valid ? 
                                 load_pipe_stage0_output_st[0].vaddr[`PROC_VALEN - 1:12] :
                                 main_pipe_stage0_output_st.vaddr[`PROC_VALEN - 1:12];
    tlb_search_req_st_o[0].asid = load_pipe_stage0_output_st[0].valid ? 
                                  load_pipe_stage0_output_st[0].asid :
                                  main_pipe_stage0_output_st.asid;

    tlb_search_req_st_o[1].valid = load_pipe_stage0_output_st[1].valid;
    tlb_search_req_st_o[1].vpn = load_pipe_stage0_output_st[1].vaddr[`PROC_VALEN - 1:12];
    tlb_search_req_st_o[1].asid = load_pipe_stage0_output_st[1].asid;
  end

  // AXI trl
  always_comb begin
    // xx_burst: 只传输一个数据，这个选项不重要了
    // xx_cache: 非缓存的请求自有一套处理方式，无需关心这个值
    axi4_mst.aw_id = '0;
    axi4_mst.aw_addr = replaced_paddr;
    axi4_mst.aw_len = 4'b0000;
    axi4_mst.aw_size = $clog2(`DCACHE_BLOCK_SIZE);
    axi4_mst.aw_burst = '0;
    axi4_mst.aw_lock = '0;
    axi4_mst.aw_cache = '0;
    axi4_mst.aw_prot = '0;
    axi4_mst.aw_qos = '0;
    axi4_mst.aw_region = '0;
    axi4_mst.aw_user = '0;
    axi4_mst.aw_valid = dcache_state == MISS & 
                        replaced_meta.dirty & 
                        replaced_meta.valid;
    // input: axi4_mst.aw_ready

    axi4_mst.w_data = replaced_data;
    axi4_mst.w_strb = '0;
    axi4_mst.w_last = '0;
    axi4_mst.w_user = '0;
    axi4_mst.w_valid = dcache_state == REPLACE;
    // input: axi4_mst.w_ready

    // input: axi4_mst.b_id
    // input: axi4_mst.b_resp
    // input: axi4_mst.b_user
    // input: axi4_mst.b_valid
    axi4_mst.b_ready = '0;

    axi4_mst.ar_id = '0;
    axi4_mst.ar_addr = dcache_miss[2] ? main_pipe_stage1_output_st.paddr : 
                       dcache_miss[1] ? load_pipe_stage1_output_st[1].paddr :
                                        load_pipe_stage1_output_st[0].paddr ;
    axi4_mst.ar_len = 4'b0000;
    axi4_mst.ar_size = $clog2(`DCACHE_BLOCK_SIZE);
    axi4_mst.ar_burst = '0;
    axi4_mst.ar_lock = '0;
    axi4_mst.ar_cache = '0;
    axi4_mst.ar_prot = '0;
    axi4_mst.ar_qos = '0;
    axi4_mst.ar_region = '0;
    axi4_mst.ar_user = '0;
    axi4_mst.ar_valid = dcache_state == LOOKUP;
    // input: axi4_mst.ar_ready

    // input: axi4_mst.r_id
    // input: axi4_mst.r_data
    // input: axi4_mst.r_resp
    // input: axi4_mst.r_last
    // input: axi4_mst.r_user
    // input: axi4_mst.r_valid
    axi4_mst.r_ready = dcache_state == REFIIL;
  end

  /* DCache Memory */
  // Data Memory: 每路 BANK_NUM 个单端口RAM
  for (genvar i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
    for (genvar j = 0; j < `DCACHE_BANK_NUM; j++) begin
      SimpleDualPortRAM #(
        .DATA_DEPTH(2 ** `DCACHE_INDEX_WIDTH),
        .DATA_WIDTH(`BANK_BYTE_NUM * 8),
        .BYTE_WRITE_WIDTH(`BANK_BYTE_NUM * 8),
        .CLOCKING_MODE("common_clock"),
        .WRITE_MODE("write_first")
      ) U_DCacheDataRAM (
        .clk_a    (clk),
        .en_a_i   ('1),
        .we_a_i   (data_ram_we[i]),
        .addr_a_i (data_ram_waddr),
        .data_a_i (data_ram_data_i[j]),
        .clk_b    (clk),
        .rstb_n   (rst_n),
        .en_b_i   ('1),
        .addr_b_i (data_ram_raddr[j]),
        .data_b_o (data_ram_data_o[i][j])
      );

    end
  end
  // Tag Memory: 使用复制策略的多读单写RAM
  for (genvar i = 0; i < 2; i++) begin
    for (genvar j = 0; j < `DCACHE_ASSOCIATIVITY; j++) begin
      SimpleDualPortRAM #(
        .DATA_DEPTH(2 ** `DCACHE_INDEX_WIDTH),
        .DATA_WIDTH(`DCACHE_TAG_WIDTH),
        .BYTE_WRITE_WIDTH(`BANK_BYTE_NUM * 8),
        .CLOCKING_MODE("common_clock"),
        .WRITE_MODE("write_first")
      ) U_DCacheTagRAM (
        .clk_a    (clk),
        .en_a_i   ('1),
        .we_a_i   (tag_ram_we[j]),
        .addr_a_i (tag_ram_waddr),
        .data_a_i (tag_ram_data_i),
        .clk_b    (clk),
        .rstb_n   (rst_n),
        .en_b_i   ('1),
        .addr_b_i (tag_ram_raddr[i]),
        .data_b_o (tag_ram_data_o[i][j])
      );
      SimpleDualPortRAM #(
        .DATA_DEPTH(2 ** `DCACHE_INDEX_WIDTH),
        .DATA_WIDTH($clog2(DCacheMetaInfoSt)),
        .BYTE_WRITE_WIDTH($clog2(DCacheMetaInfoSt)),
        .CLOCKING_MODE("common_clock"),
        .WRITE_MODE("write_first")
      ) U_DCacheMetaRAM (
        .clk_a    (clk),
        .en_a_i   ('1),
        .we_a_i   (meta_ram_we[j]),
        .addr_a_i (meta_ram_waddr),
        .data_a_i (meta_ram_data_i),
        .clk_b    (clk),
        .rstb_n   (rst_n),
        .en_b_i   ('1),
        .addr_b_i (meta_ram_raddr[i]),
        .data_b_o (meta_ram_data_o[i][j])
      );
    end
  end

  TureDualPortRAM #(
    .DATA_DEPTH(2 ** `DCACHE_INDEX_WIDTH),
    .DATA_WIDTH($clog2(`DCACHE_ASSOCIATIVITY)),
    .BYTE_WRITE_WIDTH($clog2(`DCACHE_ASSOCIATIVITY)),
    .CLOCKING_MODE("common_clock"),
    .WRITE_MODE_A("write_first"),
    .WRITE_MODE_B("write_first")
  ) U_DCachePlruRAM (
    .clk_a    (clk),
    .rsta_n   (rst_n),
    .en_a_i   ('1),
    .we_a_i   (plru_ram_we[0]),
    .addr_a_i (plru_ram_raddr[0]),
    .data_a_i (plru_ram_data_i[0]),
    .data_a_o (plru_ram_data_i[0]),
    .clk_b    (clk),
    .rstb_n   (rst_n),
    .en_b_i   ('1),
    .we_b_i   (plru_ram_we[1]),
    .addr_b_i (plru_ram_raddr[1]),
    .data_b_i (plru_ram_data_i[1]),
    .data_b_o (plru_ram_data_i[1])
  );







endmodule : DCache
