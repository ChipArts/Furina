// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : ICache.sv
// Create  : 2024-02-14 18:09:46
// Revise  : 2024-02-16 22:38:29
// Description :
//   指令位宽: 32bit
//   替换算法: PLRU
// Parameter   :
//   CACHE_SIZE: cache大小，单位(Byte)，必须是2的幂
//   BLOCK_SIZE: 一个cache块的大小(Byte)，必须是(2/4/8/16)Byte
//   WAY_NUM   : cache的相联度，必须是2的幂
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
`include "ControlStatusRegister.svh"
`include "BranchPredictionUnit.svh"

module ICache (
  input clk,    // Clock
  input rst_n,  // Asynchronous reset active low
  input flush_i,
  input pre_flush_i,
  // ICache Req
  input ICacheReqSt icache_req,
  output ICacheRspSt icache_rsp,
  // to from MMU
  input MmuAddrTransRspSt addr_trans_rsp,
  output MmuAddrTransReqSt addr_trans_req,

  input IcacopReqSt icacop_req,
  output IcacopRspSt icacop_rsp,
  AXI4.Master axi4_mst
);

  localparam FETCH_OFS = $clog2(`FETCH_WIDTH) + 2;

  logic s0_ready, s1_ready;
  // memory ctrl
  logic [`ICACHE_WAY_NUM - 1:0] data_ram_we;  // 控制写入哪个way
  logic [`ICACHE_IDX_WIDTH - 1:0] data_ram_waddr;  // 写入每个way的cache行地址(idx)相同
  logic [`ICACHE_BLOCK_SIZE - 1:0][7:0] data_ram_wdata;  // 要写入的cache行的数据
  logic [`ICACHE_IDX_WIDTH - 1:0] data_ram_raddr;
  logic [`ICACHE_WAY_NUM - 1:0][`ICACHE_BLOCK_SIZE - 1:0][7:0] data_ram_rdata;

  logic [`ICACHE_WAY_NUM - 1:0] tag_ram_we;
  logic [`ICACHE_IDX_WIDTH - 1:0] tag_ram_waddr;
  logic [`ICACHE_TAG_WIDTH - 1:0] tag_ram_wdata;
  logic [`ICACHE_IDX_WIDTH - 1:0] tag_ram_raddr;
  logic [`ICACHE_WAY_NUM - 1:0][`ICACHE_TAG_WIDTH - 1:0] tag_ram_rdata;

  logic [`ICACHE_WAY_NUM - 1:0] valid_ram_we;
  logic [`ICACHE_IDX_WIDTH - 1:0] valid_ram_waddr;
  logic valid_ram_wdata;
  logic [`ICACHE_IDX_WIDTH - 1:0] valid_ram_raddr;
  logic [`ICACHE_WAY_NUM - 1:0] valid_ram_rdata;

  logic  plru_ram_we;
  logic [`ICACHE_IDX_WIDTH - 1:0] plru_ram_waddr;
  logic [`ICACHE_WAY_NUM - 2:0] plru_ram_wdata;
  logic [`ICACHE_IDX_WIDTH - 1:0] plru_ram_raddr;
  logic [`ICACHE_WAY_NUM - 2:0] plru_ram_rdata;

  typedef enum logic [1:0] {
    IDEL,  // ICache正常工作
    MISS,  // ICache miss，Cache的访存请求发出，等待axi的rd_ready信号
    REFILL  // 等待axi的r_valid/r_last信号，重启流水线
    // UNCACHE  // 读出UNCACHE结果
  } CacheState;

  CacheState cache_state;
  logic [(`ICACHE_BLOCK_SIZE / 4) - 1:0][31:0] axi_rdata_buffer;
  logic [$clog2(`ICACHE_BLOCK_SIZE / 4) - 1:0] axi_rdata_idx;

  /* stage 0 */
  logic excp_adef;  // fetch address error
  logic excp_int;   // interrupt(fetch)
  /* stage 1 */
  logic miss;
  logic [`PROC_PALEN - 1:0] paddr;
  logic [$clog2(`ICACHE_WAY_NUM) - 1:0] replaced_way;
  logic [$clog2(`ICACHE_WAY_NUM) - 1:0] matched_way;
  logic [`ICACHE_WAY_NUM - 1:0] matched_way_oh;  // one hot
  // 按照取指宽度重新划分cache行
  logic [(`ICACHE_BLOCK_SIZE / 4) - 1:0][31:0] cache_line;
  logic [`ICACHE_IDX_OFFSET - 1:2] cache_line_base;
  logic uncache_hit;  // refill 之后uncache指令要标记此reg

/*=================================== Stage0 ==================================*/
  // 接收 取指令 虚拟地址
  // 检查地址是否对齐
  // 使用虚拟地址查询 tag
  // 使用虚拟地址查询 valid
  // 使用虚拟地址查询 plru
  // 使用虚拟地址查询 tlb
  // 使用虚拟地址查询 data

  assign s0_ready = s1_ready & addr_trans_rsp.ready;
  assign excp_adef = icache_req.vaddr[1:0] != '0;
  assign excp_int  = icache_req.has_int;

  assign addr_trans_req.valid        = (|icache_req.valid | icacop_req.valid) & s1_ready;
  assign addr_trans_req.ready        = '1;
  assign addr_trans_req.vaddr        = icacop_req.valid ? icacop_req.vaddr : icache_req.vaddr;
  assign addr_trans_req.mem_type     = icacop_req.valid ? MMU_LOAD : MMU_FETCH;  // icacop是load类型
  assign addr_trans_req.cacop_direct = icacop_req.valid & (icacop_req.cacop_mode == 2'b00 | icacop_req.cacop_mode == 2'b01);

  assign icacop_rsp.ready = s0_ready; // CACOP优先
  assign icache_rsp.ready = s0_ready & ~icacop_req.valid;

/*=================================== Stage1 ==================================*/
  logic [`PROC_VALEN - 1:0] s1_vaddr;
  logic [`PROC_VALEN - 1:0] s1_npc;
  BrInfoSt s1_br_info;
  logic s1_excp_adef;
  logic s1_excp_int;

  logic [`FETCH_WIDTH - 1:0] s1_fetch_en;
  logic s1_cacop_en;
  logic [4:3] s1_cacop_mode;
  logic [$clog2(`ROB_DEPTH) - 1:0] s1_rob_idx;
  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n || flush_i) begin
      s1_fetch_en <= '0;
      s1_cacop_en <= '0;
      s1_vaddr <= '0;
      s1_npc <= '0;
      s1_br_info <= '0;
      s1_excp_adef  <= '0;
      s1_excp_int  <= '0;
      s1_cacop_mode <= '0;
      s1_rob_idx <= '0;
    end else begin
      if (pre_flush_i) begin
        // 需要特殊处理pre check的flush，此时的s1_cacop_en不应该被清除
        s1_fetch_en <= '0;
      end else if (icacop_req.valid) begin
        // 当icacop到来，强制抢占
        s1_fetch_en <= '0;
      end else if (s1_ready) begin
        s1_fetch_en <= icache_req.valid;
      end


      if (s1_ready) begin
        s1_cacop_en <= icacop_req.valid;
        s1_cacop_mode <= icacop_req.cacop_mode;
        s1_rob_idx <= icacop_req.rob_idx;

        s1_vaddr <= icacop_req.valid ? icacop_req.vaddr : icache_req.vaddr;
        s1_npc <= icache_req.npc;
        s1_br_info <= icache_req.br_info;
        s1_excp_adef  <= excp_adef;
        s1_excp_int <= excp_int;
      end
    end
  end
  // 1 获得 tag 查询结果
  // 2 获得 mmu 查询结果
  // 3 获得 meta 查询结果
  // 4 进行 tag 匹配；判断 icache 访问是否命中
  // 5 获得 plru 信息, 选出替换 way
  // 6 生成新的plru信息
  // 7 生成 inst 输出

  always_ff @(posedge clk or negedge rst_n) begin : proc_uncache_hit
    if(~rst_n) begin
      uncache_hit <= 0;
    end else begin
      if (s1_ready) begin
        uncache_hit <= 0;
      end else begin
        if (cache_state == REFILL) begin
          uncache_hit <= axi4_mst.r_last && axi4_mst.r_valid && addr_trans_rsp.uncache;
        end
      end
      
    end
  end

`ifdef DEBUG
  wire [`ICACHE_TAG_WIDTH - 1:0] tag_dbug = `ICACHE_TAG_OF(paddr);
`endif

  assign s1_ready = cache_state == IDEL &                                        // 必要条件 确保flash后axi完成读操作（不进行refill）
                    (
                      !s1_fetch_en && !s1_cacop_en           ? '1 :                               // 无操作
                      |s1_fetch_en && addr_trans_rsp.uncache ? uncache_hit & icache_req.ready :   // fetch uncache ready
                      |s1_fetch_en                           ? ~miss       & icache_req.ready :   // fetch miss ready
                                                               s1_cacop_en & icacop_req.ready     // cacop ready
                    );
  assign paddr = addr_trans_rsp.paddr;

  // 进行 tag 匹配
  always_comb begin : proc_matched_way
    for (int i = 0; i < `ICACHE_WAY_NUM; i++) begin
      matched_way_oh[i] = `ICACHE_TAG_OF(paddr) == tag_ram_rdata[i] & valid_ram_rdata[i];
    end

    matched_way = '0;
    for (int i = 0; i < `ICACHE_WAY_NUM; i++) begin
      if (matched_way_oh[i]) begin
        matched_way = i;
        break;
      end
    end
  end

  // 判断 cache 访问是否命中
  assign miss = ~|matched_way_oh;

  // 获得 plru 信息, 选出替换 way
  assign replaced_way = plru_ram_rdata;  // TODO: 真正实现PLRU


  // fetch 输出
  for (genvar i = 0; i < `FETCH_WIDTH; i++) begin
    assign icache_rsp.valid[i] = s1_fetch_en[i] & (addr_trans_rsp.uncache ? uncache_hit : ~miss);
    assign icache_rsp.vaddr[i] = s1_excp_adef ? s1_vaddr : `FETCH_ALIGN(s1_vaddr) + (i << 2);  // pc异常时保留异常的pc
    assign icache_rsp.instr[i] = cache_line[cache_line_base + i];
  end
  assign cache_line = addr_trans_rsp.uncache ? axi_rdata_buffer : data_ram_rdata[matched_way];
  assign cache_line_base = `FETCH_ALIGN(s1_vaddr)[`ICACHE_IDX_OFFSET - 1:2];
  assign icache_rsp.br_info = s1_br_info;
  // 生成NPC
  for (genvar i = 0; i < `FETCH_WIDTH - 1; i++) begin
    assign icache_rsp.npc[i] = !s1_fetch_en[i + 1] ? s1_npc : `FETCH_ALIGN(s1_vaddr) + ((i + 1) << 2);
  end
  assign icache_rsp.npc[`FETCH_WIDTH - 1] = s1_npc;

  // fetch异常检查
  assign icache_rsp.excp.valid = s1_excp_int | s1_excp_adef | addr_trans_rsp.tlbr | addr_trans_rsp.pif | addr_trans_rsp.ppi;
  assign icache_rsp.excp.ecode =  s1_excp_int         ? `ECODE_INT  :
                                  s1_excp_adef        ? `ECODE_ADE  :
                                  addr_trans_rsp.tlbr ? `ECODE_TLBR : 
                                  addr_trans_rsp.pif  ? `ECODE_PIF  :
                                  addr_trans_rsp.ppi  ? `ECODE_PPI  : '0;
  assign icache_rsp.excp.sub_ecode = `ESUBCODE_ADEF;

  // cacop输出
  assign icacop_rsp.valid = s1_cacop_en;
  assign icacop_rsp.vaddr = s1_vaddr;
  assign icacop_rsp.rob_idx = s1_rob_idx;

  // cacop异常检查
  assign icacop_rsp.excp.valid = s1_cacop_mode == 2'b10 &  // 只有在示采用查询索引方式维护Cache一致性时产生mmu异常
                                 (addr_trans_rsp.tlbr |
                                  addr_trans_rsp.pil  |
                                  addr_trans_rsp.ppi);
  assign icacop_rsp.excp.ecode =  addr_trans_rsp.tlbr ? `ECODE_TLBR : 
                                  addr_trans_rsp.pil  ? `ECODE_PIL  :
                                  addr_trans_rsp.ppi  ? `ECODE_PPI  : '0;
  assign icacop_rsp.excp.sub_ecode = `ESUBCODE_ADEF;

  // AXI FSM
  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      cache_state <= IDEL;
      axi_rdata_idx <= '0;
      axi_rdata_buffer <= '0;
    end else begin
      case (cache_state)
        // cache操作不会引起重填
        IDEL : if ((miss || addr_trans_rsp.uncache) && !uncache_hit && |s1_fetch_en && !s1_cacop_en) cache_state <= MISS;
        MISS : if (axi4_mst.ar_ready) cache_state <= REFILL;
        REFILL : if (axi4_mst.r_last && axi4_mst.r_valid) cache_state <= IDEL;
        default : /* default */;
      endcase

      // axi读数据缓存
      if (cache_state == REFILL) begin
        if (axi4_mst.r_valid && axi4_mst.r_ready) begin
          axi_rdata_buffer[axi_rdata_idx] <= axi4_mst.r_data;
          axi_rdata_idx <= axi_rdata_idx + 1;
        end
      end else begin
        // axi_rdata_idx <= '0;
        axi_rdata_idx <= addr_trans_rsp.uncache ? s1_vaddr[`ICACHE_IDX_OFFSET - 1:2] : '0;
      end
    end
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

    axi4_mst.w_id = '0;
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
    axi4_mst.ar_addr = addr_trans_rsp.uncache ? paddr : `ICACHE_PADDR_ALIGN(paddr);  // 以cache行为单位
    axi4_mst.ar_len = addr_trans_rsp.uncache ? `FETCH_WIDTH - 1 : `ICACHE_BLOCK_SIZE / 4 - 1;
    axi4_mst.ar_size = 3'b010;  // 4 bytes;
    axi4_mst.ar_burst = 2'b01;  // Incrementing-address burst
    axi4_mst.ar_lock = '0;
    axi4_mst.ar_cache = '0;
    axi4_mst.ar_prot = '0;
    axi4_mst.ar_qos = '0;
    axi4_mst.ar_region = '0;
    axi4_mst.ar_user = '0;
    axi4_mst.ar_valid = cache_state == MISS;
    // input: axi4_mst.ar_ready

    // input: axi4_mst.r_id
    // input: axi4_mst.r_data
    // input: axi4_mst.r_resp
    // input: axi4_mst.r_last
    // input: axi4_mst.r_user
    // input: axi4_mst.r_valid
    axi4_mst.r_ready = cache_state == REFILL;
  end

  /* Memory Ctrl */
  always_comb begin
    // data ram
    for (int i = 0; i < `ICACHE_WAY_NUM; i++) begin
      data_ram_we[i] = cache_state == REFILL &
                      |s1_fetch_en &            // fulsh后不refill
                       replaced_way == i &
                       axi4_mst.r_valid &
                       axi4_mst.r_last &
                      ~addr_trans_rsp.uncache;  // uncache请求不refill
    end
    data_ram_waddr = `ICACHE_IDX_OF(s1_vaddr);
    data_ram_wdata = {axi4_mst.r_data, axi_rdata_buffer[(`ICACHE_BLOCK_SIZE / 4) - 2:0]};
    if (s1_ready) begin
      data_ram_raddr = `ICACHE_IDX_OF(icache_req.vaddr);
    end else begin
      data_ram_raddr = `ICACHE_IDX_OF(s1_vaddr);
    end

    // tag ram
    for (int i = 0; i < `ICACHE_WAY_NUM; i++) begin
      if (s1_cacop_en) begin
        tag_ram_we[i] = s1_cacop_mode == 2'b00 & s1_vaddr[$clog2(`ICACHE_WAY_NUM) - 1:0] == i & icacop_req.ready;
      end else begin
        tag_ram_we[i] = |s1_fetch_en & 
                         cache_state == REFILL & 
                         replaced_way == i & 
                         axi4_mst.r_last & 
                         axi4_mst.r_valid & 
                        ~addr_trans_rsp.uncache;
      end
    end
    tag_ram_waddr = `ICACHE_IDX_OF(s1_vaddr);
    if (s1_cacop_en) begin
      tag_ram_wdata = '0;
    end else begin
      tag_ram_wdata = `ICACHE_TAG_OF(paddr);
    end
    if (s1_ready) begin
      // 优先使用cacop_req.vaddr
      tag_ram_raddr = icacop_req.valid ? `ICACHE_IDX_OF(icacop_req.vaddr) : `ICACHE_IDX_OF(icache_req.vaddr);
    end else begin
      tag_ram_raddr = `ICACHE_IDX_OF(s1_vaddr);
    end

    // valid ram
    valid_ram_we = '0;
    for (int i = 0; i < `ICACHE_WAY_NUM; i++) begin
      if (s1_cacop_en) begin
        case (s1_cacop_mode)
          2'b00 : valid_ram_we[i] = '0;
          2'b01 : valid_ram_we[i] = s1_vaddr[$clog2(`ICACHE_WAY_NUM) - 1:0] == i & icacop_req.ready;
          2'b10 : valid_ram_we[i] = ~icacop_rsp.excp.valid & ~miss & matched_way == i & icacop_req.ready;
          default : valid_ram_we[i] = '0;
        endcase
      end else begin
        valid_ram_we[i] = |s1_fetch_en & 
                           cache_state == REFILL & 
                           replaced_way == i & 
                           axi4_mst.r_last & 
                           axi4_mst.r_valid & 
                          ~addr_trans_rsp.uncache;
      end
    end
    valid_ram_waddr = `ICACHE_IDX_OF(s1_vaddr);
    valid_ram_wdata = s1_cacop_en ? '0 : '1;
    if (s1_ready) begin
      // 优先使用cacop_req.vaddr
      valid_ram_raddr = icacop_req.valid ? `ICACHE_IDX_OF(icacop_req.vaddr) : `ICACHE_IDX_OF(icache_req.vaddr);
    end else begin
      valid_ram_raddr = `ICACHE_IDX_OF(s1_vaddr);
    end

    // plru ram
    plru_ram_we = |s1_fetch_en & ~miss;
    plru_ram_waddr = `ICACHE_IDX_OF(s1_vaddr);
    plru_ram_wdata = plru_ram_rdata == matched_way ? ~plru_ram_rdata : plru_ram_rdata;
    if (s1_ready) begin
      plru_ram_raddr = `ICACHE_IDX_OF(icache_req.vaddr);
    end else begin
      plru_ram_raddr = `ICACHE_IDX_OF(s1_vaddr);
    end
  end


/*================================ ICache Memory ===============================*/
  for (genvar i = 0; i < `ICACHE_WAY_NUM; i++) begin : gen_icache_memory
      SimpleDualPortRAM #(
          .DATA_DEPTH(2 ** `ICACHE_IDX_WIDTH),
          .DATA_WIDTH(`ICACHE_BLOCK_SIZE * 8),
          .BYTE_WRITE_WIDTH(`ICACHE_BLOCK_SIZE * 8),
          .CLOCKING_MODE("common_clock"),
          .WRITE_MODE("write_first")
        ) U_ICacheDataRAM (
          .clk_a    (clk),
          .en_a_i   (~flush_i & ~pre_flush_i),
          .we_a_i   (data_ram_we[i]),
          .addr_a_i (data_ram_waddr),
          .data_a_i (data_ram_wdata),
          .clk_b    (clk),
          .rstb_n   (rst_n),
          .en_b_i   (~flush_i & ~pre_flush_i),
          .addr_b_i (data_ram_raddr),
          .data_b_o (data_ram_rdata[i])
        );

        SimpleDualPortRAM #(
          .DATA_DEPTH(2 ** `ICACHE_IDX_WIDTH),
          .DATA_WIDTH(`ICACHE_TAG_WIDTH),
          .BYTE_WRITE_WIDTH(`ICACHE_TAG_WIDTH),
          .CLOCKING_MODE("common_clock"),
          .WRITE_MODE("write_first")
        ) U_ICacheTagRAM (
          .clk_a    (clk),
          .en_a_i   (~flush_i & ~pre_flush_i),
          .we_a_i   (tag_ram_we[i]),
          .addr_a_i (tag_ram_waddr),
          .data_a_i (tag_ram_wdata),
          .clk_b    (clk),
          .rstb_n   (rst_n),
          .en_b_i   (~flush_i & ~pre_flush_i),
          .addr_b_i (tag_ram_raddr),
          .data_b_o (tag_ram_rdata[i])
        );
        
        SimpleDualPortRAM #(
          .DATA_DEPTH(2 ** `ICACHE_IDX_WIDTH),
          .DATA_WIDTH(1),
          .BYTE_WRITE_WIDTH(1),
          .CLOCKING_MODE("common_clock"),
          .WRITE_MODE("write_first")
        ) U_ICacheValidRAM (
          .clk_a    (clk),
          .en_a_i   (~flush_i & ~pre_flush_i),
          .we_a_i   (valid_ram_we[i]),
          .addr_a_i (valid_ram_waddr),
          .data_a_i (valid_ram_wdata),
          .clk_b    (clk),
          .rstb_n   (rst_n),
          .en_b_i   (~flush_i & ~pre_flush_i),
          .addr_b_i (valid_ram_raddr),
          .data_b_o (valid_ram_rdata[i])
        );
    end
  

  SimpleDualPortRAM #(
    .DATA_DEPTH(2 ** `ICACHE_IDX_WIDTH),
    .DATA_WIDTH(`ICACHE_WAY_NUM - 1),
    .BYTE_WRITE_WIDTH(`ICACHE_WAY_NUM - 1),
    .CLOCKING_MODE("common_clock"),
    .WRITE_MODE("write_first"),
    .MEMORY_PRIMITIVE("auto")
  ) U_ICachePlruRAM (
    .clk_a    (clk),
    .en_a_i   ('1),
    .we_a_i   (plru_ram_we),
    .addr_a_i (plru_ram_waddr),
    .data_a_i (plru_ram_wdata),
    .clk_b    (clk),
    .rstb_n   (rst_n),
    .en_b_i   ('1),
    .addr_b_i (plru_ram_raddr),
    .data_b_o (plru_ram_rdata)
  );


  
endmodule : ICache
