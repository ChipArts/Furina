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
//   virtual index/physical tag
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
`include "ReorderBuffer.svh"
`include "ControlStatusRegister.svh"
`include "MemoryManagementUnit.svh"

module DCache (
  input logic clk,    // Clock
  input logic a_rst_n,  // Asynchronous reset active low
  input flush_i,
  //to from cpu
  input DCacheReqSt dcache_req,
  output DCacheRspSt dcache_rsp,
  output logic busy_o,
  // to from mmu
  output MmuAddrTransReqSt addr_trans_req,
  input MmuAddrTransRspSt addr_trans_rsp,
  // axi bus
  AXI4.Master axi4_mst
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

  //  axi4_mst.AXI_ADDR_WIDTH = `PROC_PALEN
  //  axi4_mst.AXI_DATA_WIDTH = 32
  //  axi4_mst.AXI_ID_WIDTH = 1
  //  axi4_mst.AXI_USER_WIDTH = 1

  initial begin
    assert (`DCACHE_IDX_WIDTH <= 12) else $error("DCache: INDEX_WIDTH > 12");  // 避免产生虚拟地址重名问题
    assert (`DCACHE_BLOCK_SIZE == 1 << $clog2(`DCACHE_BLOCK_SIZE)) else $error("DCache: BLOCK_SIZE is not power of 2");
  end

/*=============================== Signal Define ===============================*/
  logic s0_ready, s1_ready, s2_ready;

  /* Memory Ctrl */
  logic [`DCACHE_WAY_NUM - 1:0][`DCACHE_BLOCK_SIZE - 1:0] data_ram_we;
  logic [`DCACHE_IDX_WIDTH - 1:0] data_ram_waddr;
  logic [`DCACHE_BLOCK_SIZE / 4 - 1:0][31:0] data_ram_wdata;
  logic [`DCACHE_IDX_WIDTH - 1:0] data_ram_raddr;
  logic [`DCACHE_WAY_NUM - 1:0][`DCACHE_BLOCK_SIZE / 4 - 1:0][31:0] data_ram_rdata;

  logic [`DCACHE_WAY_NUM - 1:0] tag_ram_we;
  logic [`DCACHE_IDX_WIDTH - 1:0] tag_ram_waddr;
  logic [`DCACHE_TAG_WIDTH - 1:0] tag_ram_wdata;
  logic [`DCACHE_IDX_WIDTH - 1:0] tag_ram_raddr;
  logic [`DCACHE_WAY_NUM - 1:0][`DCACHE_TAG_WIDTH - 1:0] tag_ram_rdata;

  logic [`DCACHE_WAY_NUM - 1:0] meta_ram_we;
  logic [`DCACHE_IDX_WIDTH - 1:0] meta_ram_waddr;
  DCacheMetaSt meta_ram_wdata;
  logic [`DCACHE_IDX_WIDTH - 1:0] meta_ram_raddr;
  DCacheMetaSt [`DCACHE_WAY_NUM - 1:0] meta_ram_rdata;

  logic plru_ram_we;
  logic [`DCACHE_IDX_WIDTH - 1:0] plru_ram_waddr;
  logic [`DCACHE_WAY_NUM - 2:0] plru_ram_wdata;
  logic [`DCACHE_IDX_WIDTH - 1:0] plru_ram_raddr;
  logic [`DCACHE_WAY_NUM - 2:0] plru_ram_rdata;

  /* Cache FSM */
  typedef enum logic [1:0] {
    IDEL,  // 空闲
    MISS,  // 发生miss或cacop等需要复用处理流程，有必要则同时等待aw_ready
    WRITE_BACK,  // 写回脏数据
    LOOK_UP,     // 等待ar_ready
    REFILL       // 读取axi总线数据，更新cache状态
  } CacheState;

  CacheState cache_state;
  logic [$clog2(`DCACHE_BLOCK_SIZE / 4) - 1:0] axi_rdata_idx;
  logic [$clog2(`DCACHE_BLOCK_SIZE / 4) - 1:0] axi_wdata_idx;
  logic [`DCACHE_BLOCK_SIZE / 4 - 1:0][31:0] axi_rdata_buffer;

  /* stage 0 logic */
  logic ale;  // align error
  logic store_valid;  // 检查SC指令是否可以执行

  /* stage 1 logic */
  logic miss;
  logic [`PROC_PALEN - 1:0] paddr;
  logic [$clog2(`DCACHE_WAY_NUM) - 1:0] matched_way;
  logic [`DCACHE_WAY_NUM - 1:0] matched_way_oh;
  logic [$clog2(`DCACHE_WAY_NUM) - 1:0] repl_way;
  logic [`PROC_PALEN - 1:0] repl_paddr;
  // 异常处理相关
  logic excp_ale;
  logic excp_tlbr;
  logic excp_pil;
  logic excp_pis;
  logic excp_ppi;
  logic excp_pme;
  ExcpSt excp;

  // tag、meta在refill时需要转发，确保下一周期不会触发miss
  logic [`DCACHE_WAY_NUM - 1:0][`DCACHE_TAG_WIDTH - 1:0] tag;
  DCacheMetaSt [`DCACHE_WAY_NUM - 1:0] meta;

  // cache state 控制相关信号
  logic idel2miss;

  /* stage 2 logic */
  logic [`DCACHE_BLOCK_SIZE / 4 - 1:0][31:0] cache_line;
  logic [31:0] matched_word;
  // cache state 控制相关信号
  logic uncache_store;
  logic write_back;  // 是否需要写回
  logic cacop_mode0;
  logic cacop_mode1;
  logic cacop_mode2;
  logic cacop_mode2_hit;
  logic read_require; // 是否需要从axi读取数据
  logic refill;  // 可以修改cache状态（包装一些逻辑，简化mem控制）


/*================================ Cache Stage0 ================================*/
  // 1. 从CPU读取请求
  // 2. 生成MMU请求
  // 3. 访问Tag RAM，Meta RAM，PLRU RAM

  always_comb begin
    s0_ready = s1_ready;
    dcache_rsp.ready = s0_ready;
    if (dcache_req.valid) begin
      addr_trans_req.valid = s1_ready & dcache_req.valid;
      addr_trans_req.ready = 1'b1;
      addr_trans_req.vaddr = dcache_req.vaddr;
      case (dcache_req.mem_op)
        `MEM_LOAD : addr_trans_req.mem_op = MMU_LOAD;
        `MEM_STORE: addr_trans_req.mem_op = MMU_STORE;
        default : addr_trans_req.mem_op = MMU_LOAD;
      endcase
      addr_trans_req.cacop_direct = dcache_req.mem_op == `MEM_CACOP &
                                    dcache_req.code[4:3] < 2'b10;
    end
    case (dcache_req.align_op)
      `ALIGN_B : ale = '0;
      `ALIGN_H : ale = dcache_req.vaddr[0] != 1'b0;
      `ALIGN_W : ale = dcache_req.vaddr[1:0] != 2'b00;
      `ALIGN_BU: ale = '0;
      `ALIGN_HU: ale = dcache_req.vaddr[0] != 1'b0;
      default : /* default */;
    endcase

    // 特殊判断store指令，确保SC指令在llbit==1时才执行
    store_valid = dcache_req.mem_op == `MEM_STORE & ~(dcache_req.micro & ~dcache_req.llbit);
  end


/*================================ Cache Stage1 ================================*/
  logic s1_valid;
  logic [`PROC_VALEN - 1:0] s1_vaddr;
  MemOpType s1_mem_op;
  logic s1_micro;
  logic s1_llbit;
  logic [3:0][7:0] s1_wdata;
  AlignOpType s1_align_op;
  logic s1_pdest_valid;
  logic [$clog2(`PHY_REG_NUM) - 1:0] s1_pdest;
  logic [$clog2(`ROB_DEPTH) - 1:0] s1_rob_idx;
  logic [4:0] s1_code;
  // stage 0的控制信号缓存
  logic s1_ale;
  logic s1_store_valid;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n || flush_i) begin
      s1_valid <= '0;
      s1_vaddr <= '0;
      s1_mem_op <= '0;
      s1_micro <= '0;
      s1_llbit <= '0;
      s1_code <= '0;
      s1_wdata <= '0;
      s1_align_op <= '0;
      s1_pdest_valid <= '0;
      s1_pdest <= '0;
      s1_rob_idx <= '0;
      s1_ale <= '0;
      s1_store_valid <= '0;
    end else begin
      if (s1_ready) begin
        s1_valid <= dcache_req.valid;
        s1_vaddr <= dcache_req.vaddr;
        s1_mem_op <= dcache_req.mem_op;
        s1_micro <= dcache_req.micro;
        s1_llbit <= dcache_req.llbit;
        s1_code <= dcache_req.code;
        s1_wdata <= dcache_req.wdata;
        s1_align_op <= dcache_req.align_op;
        s1_pdest_valid <= dcache_req.pdest_valid;
        s1_pdest <= dcache_req.pdest;
        s1_rob_idx <= dcache_req.rob_idx;
        s1_ale <= ale;
        s1_store_valid <= store_valid;
      end
    end
  end

  // 1. 获得MMU读取响应
  // 2. 访问Data RAM
  // 3. 判断Cache的命中情况
  // 4. 如果hit，生成cache way选择信号
  // 5. 如果miss，选择替换的cache way
  // 6. 更新plru RAM
  // 7. 生成写入数据

  always_comb begin
    s1_ready = ~s1_valid | s2_ready;

    // 1. 获得MMU读取响应
    paddr = addr_trans_rsp.paddr;
    // 2. 访问Data RAM
    // 3. 判断Cache的命中情况
    for (int i = 0; i < `DCACHE_WAY_NUM; i++) begin
      matched_way_oh[i] = (tag[i] == `DCACHE_TAG_OF(paddr)) & meta[i].valid;
    end

    miss = 1'b1;  // 这里的miss仅检查cache查询结果的命中情况
    for (int i = 0; i < `DCACHE_WAY_NUM; i++) begin
      miss &= ~matched_way_oh[i];
    end
    // 4. 如果hit，生成cache way选择信号
    matched_way = '0;
    for (int i = 0; i < `DCACHE_WAY_NUM; i++) begin
      if (matched_way_oh[i]) begin
        matched_way = i;
      end
    end
    // 5. 如果miss，选择替换的cache way
    repl_way = s1_mem_op == `MEM_CACOP && s1_code[4:3] <  2'b10 ? s1_vaddr[$clog2(`DCACHE_WAY_NUM) - 1:0] :
               s1_mem_op == `MEM_CACOP && s1_code[4:3] == 2'b10 ? matched_way : plru_ram_rdata;
    repl_paddr = {tag[repl_way], s1_vaddr[`DCACHE_TAG_OFFSET - 1:0]};
    // 6. 更新plru RAM
    // 7. 生成写入数据

    /* excp处理 */
    // preld 不触发例外
    // cacop，preld不触发ale
    excp_ale = (s1_mem_op == `MEM_LOAD | s1_mem_op == `MEM_STORE) & s1_ale;
    // cacop(code == 0, 1 由addr_trans_req.cacop_direct保证) 不触发TLB异常，以下cacop判断针对cacop(code==2)
    excp_tlbr = (s1_mem_op == `MEM_LOAD | s1_mem_op == `MEM_STORE | s1_mem_op == `MEM_CACOP) & addr_trans_rsp.tlbr;
    // store 不触发pil
    excp_pil = (s1_mem_op == `MEM_LOAD | s1_mem_op == `MEM_CACOP) & addr_trans_rsp.pil;
    // 仅store触发pis 在addr_trans_req.mem_op已经判断
    excp_pis = addr_trans_rsp.pis;
    // 仅store、load触发ppi
    excp_ppi = (s1_mem_op == `MEM_LOAD | s1_mem_op == `MEM_STORE) & addr_trans_rsp.ppi;
    // 仅store触发pme 在addr_trans_req.mem_op已经判断
    excp_pme = addr_trans_rsp.pme;
    excp.valid = excp_ale | excp_tlbr | excp_pil | excp_pis | excp_ppi | excp_pme;
    excp.ecode = excp_ale ? `ECODE_ALE :
                 excp_tlbr ? `ECODE_TLBR :
                 excp_pil ? `ECODE_PIL :
                 excp_pis ? `ECODE_PIS :
                 excp_ppi ? `ECODE_PPI :
                 excp_pme ? `ECODE_PME :
                 '0;
    excp.sub_ecode = `ESUBCODE_ADEM;

    /* cache 状态机控制 */
    // 启动cache fsm的条件：
    // s1指令有效
    // s2可以处理请求（s2不暂停）
    // 没有例外
    // store、load、preld指令miss（cache缺失的处理流程）
    // uncache操作，uncache一定miss（cache缺失处理，但是跳过refill）
    // cacop(code==0) (复用cache refill)
    // cacop(code==1) (复用cache writeback refill)
    // cacop(code==2) (当且仅当hit时 复用cache writeback refill)
    idel2miss = s1_valid & s2_ready & ~excp.valid &
                (
                  s1_mem_op == `MEM_LOAD  ? miss :
                  s1_mem_op == `MEM_STORE ? store_valid & miss :
                  s1_mem_op == `MEM_CACOP ? ~(s1_code[4:3] == 2'b10 & miss) :
                  s1_mem_op == `MEM_PRELD ? miss & ~addr_trans_rsp.uncache :
                  '0
                );
  end
  

/*================================ Cache Stage2 ================================*/
  logic s2_valid;
  logic s2_miss;
  logic [`PROC_VALEN - 1:0] s2_vaddr;
  logic [`PROC_PALEN - 1:0] s2_paddr;
  logic [`PROC_PALEN - 1:0] s2_repl_paddr;
  logic s2_uncache;
  logic [31:0] s2_wdata;
  MemOpType s2_mem_op;
  logic s2_micro;
  logic s2_llbit;
  logic [4:0] s2_code;
  AlignOpType s2_align_op;
  logic s2_pdest_valid;
  logic [$clog2(`PHY_REG_NUM) - 1:0] s2_pdest;
  logic [$clog2(`ROB_DEPTH) - 1:0] s2_rob_idx;
  ExcpSt s2_excp;
  DCacheMetaSt s2_repl_meta;
  logic [$clog2(`DCACHE_WAY_NUM) - 1:0] s2_repl_way;
  logic [$clog2(`DCACHE_WAY_NUM) - 1:0] s2_matched_way;

  logic s2_store_valid;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n || flush_i) begin
      s2_valid <= '0;
      s2_miss <= '0;
      s2_vaddr <= '0;
      s2_paddr <= '0;
      s2_repl_paddr <= '0;
      s2_uncache <= '0;
      s2_wdata <= '0;
      s2_matched_way <= '0;
      s2_mem_op <= '0;
      s2_micro <= '0;
      s2_llbit <= '0;
      s2_code <= '0;
      s2_align_op <= '0;
      s2_pdest_valid <= '0;
      s2_pdest <= '0;
      s2_rob_idx <= '0;
      s2_excp <= '0;
      s2_repl_meta <= '0;
      s2_repl_way <= '0;
      s2_store_valid <= '0;
    end else begin
      if (s2_ready) begin
        s2_valid <= s1_valid;
        s2_miss <= miss;
        s2_vaddr <= s1_vaddr;
        s2_paddr <= paddr;
        s2_repl_paddr <= repl_paddr;
        s2_uncache <= addr_trans_rsp.uncache;
        s2_wdata <= s1_wdata;
        s2_matched_way <= matched_way;
        s2_mem_op <= s1_mem_op;
        s2_micro <= s1_micro;
        s2_llbit <= s1_llbit;
        s2_code <= s1_code;
        s2_align_op <= s1_align_op;
        s2_pdest_valid <= s1_pdest_valid;
        s2_pdest <= s1_pdest;
        s2_rob_idx <= s1_rob_idx;
        s2_excp <= excp;
        s2_repl_meta <= meta[repl_way];
        s2_repl_way <= repl_way;
        s2_store_valid <= s1_store_valid;
      end
    end
  end

  // 1. 生成响应
  // 2. 如果hit 处理store写入
  // 3. 如果miss，处理cache状态机

  always_comb begin
    s2_ready = (~s2_valid | dcache_req.ready) & cache_state == IDEL;
    // 1. 生成响应
    dcache_rsp.valid = s2_valid & cache_state == IDEL;
    dcache_rsp.mem_op = s2_mem_op;  // 用于rob判断是否可以写回
    dcache_rsp.micro = s2_micro;
    dcache_rsp.llbit = s2_llbit;
    dcache_rsp.pdest_valid = s2_pdest_valid;
    dcache_rsp.pdest = s2_pdest;
    dcache_rsp.rob_idx = s2_rob_idx;
    dcache_rsp.excp = s2_excp;
    dcache_rsp.vaddr = s2_vaddr;
    dcache_rsp.paddr = s2_paddr;
    dcache_rsp.store_data = s2_wdata;
    busy_o = ~(s1_valid | s2_valid);

    cache_line = s2_uncache ? axi_rdata_buffer : data_ram_rdata[s2_matched_way];

    matched_word = cache_line[s2_vaddr[`DCACHE_IDX_OFFSET - 1:2]];
    case (s2_align_op)
      `ALIGN_B: begin
        case (s2_vaddr[1:0])
          2'b00: dcache_rsp.rdata = {{24{matched_word[7]}},  matched_word[7:0]};
          2'b01: dcache_rsp.rdata = {{24{matched_word[15]}}, matched_word[15:8]};
          2'b10: dcache_rsp.rdata = {{24{matched_word[23]}}, matched_word[23:16]};
          2'b11: dcache_rsp.rdata = {{24{matched_word[31]}}, matched_word[31:24]};
          default : /* default */;
        endcase
      end
      `ALIGN_H: begin
        case (s2_vaddr[1:0])
          2'b00: dcache_rsp.rdata = {{16{matched_word[15]}}, matched_word[15:0]};
          2'b10: dcache_rsp.rdata = {{16{matched_word[31]}}, matched_word[31:16]};
          default : /* default */;
        endcase
      end
      `ALIGN_W: stage2_output_st_o.data = matched_word;
      `ALIGN_BU: begin
        case (s2_vaddr[1:0])
          2'b00: dcache_rsp.rdata = {{24{1'b0}}, matched_word[7:0]};
          2'b01: dcache_rsp.rdata = {{24{1'b0}}, matched_word[15:8]};
          2'b10: dcache_rsp.rdata = {{24{1'b0}}, matched_word[23:16]};
          2'b11: dcache_rsp.rdata = {{24{1'b0}}, matched_word[31:24]};
          default : /* default */;
        endcase
      end
      `ALIGN_HU: begin
        case (s2_vaddr[1:0])
          2'b00: dcache_rsp.rdata = {{16{1'b0}}, matched_word[15:0]};
          2'b10: dcache_rsp.rdata = {{16{1'b0}}, matched_word[31:16]};
          default : /* default */;
        endcase
      end
      default : dcache_rsp.rdata = '0;
    endcase

    /* cache state 控制相关信号 */
    uncache_store = s2_mem_op == `MEM_STORE & s2_uncache;
    cacop_mode2_hit = s2_mem_op == `MEM_CACOP & s2_code[4:3] == 2'b10 & ~s2_miss;
    cacop_mode0 = s2_mem_op == `MEM_CACOP & s2_code[4:3] == 2'b00;
    cacop_mode1 = s2_mem_op == `MEM_CACOP & s2_code[4:3] == 2'b01;
    cacop_mode2 = s2_mem_op == `MEM_CACOP & s2_code[4:3] == 2'b10;
    // uncache wr --> wb 1
    // uncache rd, cacop(code==0) --> wb 0
    // cacop(code==1, 2), cache st, cache ld --> wb (dirty && valid)
    write_back = uncache_store | 
                 ((s2_repl_meta.valid & s2_repl_meta.dirty) &
                  (~s2_uncache | cacop_mode2_hit) &
                  ~cacop_mode0);
                 
    read_require = ~(uncache_store | s2_mem_op == `MEM_CACOP);
    // REFILL的最后一拍进行cache内容充填（所有的Cache修改确保为rob最旧指令）
    refill = cache_state == REFILL & ((axi4_mst.r_valid & axi4_mst.r_last) | ~read_require) & dcache_req.ready;

  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      cache_state <= IDEL;
      axi_rdata_idx <= '0;
      axi_rdata_buffer <= '0;
    end else begin
      case (cache_state)
        // cache 状态机的启动信号来自stage 1
        IDEL : begin
          if (idel2miss) begin
            cache_state <= MISS;
          end
        end
        MISS : begin
          if (write_back) begin
            if (axi4_mst.aw_ready) cache_state <= WRITE_BACK;
          end else begin
            if (read_require) begin
              cache_state <= LOOK_UP;
            end else begin
              cache_state <= REFILL;
            end
          end
        end
        WRITE_BACK : begin
          if (axi4_mst.w_last) begin
            if (read_require) begin
              cache_state <= LOOK_UP;
            end else begin
              cache_state <= REFILL;
            end
          end else begin
            
          end
        end
        LOOK_UP : if(axi4_mst.ar_ready) cache_state <= REFILL;
        REFILL : if((axi4_mst.r_valid && axi4_mst.r_last) || !read_require) cache_state <= IDEL;
        default : /* default */;
      endcase
      // axi读数据缓存
      if (cache_state == REFILL) begin
        if (axi4_mst.r_valid && axi4_mst.r_ready) begin
          axi_rdata_buffer[axi_rdata_idx] <= axi4_mst.r_data;
          axi_rdata_idx <= axi_rdata_idx + 1;
        end
      end else begin
        axi_rdata_idx <= '0;
      end
      // axi写
      if (cache_state == WRITE_BACK) begin
        if (axi4_mst.aw_ready) begin
          axi_wdata_idx <= axi_wdata_idx + 1;
        end
      end else begin
        axi_wdata_idx <= '0;
      end
    end
  end

  always_comb begin
    axi4_mst.aw_id = '0;
    axi4_mst.aw_addr = s2_repl_paddr;
    axi4_mst.aw_len = `DCACHE_BLOCK_SIZE / 4;
    axi4_mst.aw_size = 3'b010;  // 4 bytes
    axi4_mst.aw_burst = 2'b01;  // Incrementing-address burst
    axi4_mst.aw_lock = '0;
    axi4_mst.aw_cache = '0;
    axi4_mst.aw_prot = '0;
    axi4_mst.aw_qos = '0;
    axi4_mst.aw_region = '0;
    axi4_mst.aw_user = '0;
    axi4_mst.aw_valid = cache_state == MISS;
    // input: axi4_mst.aw_ready

    axi4_mst.w_data = data_ram_rdata[axi_wdata_idx];
    axi4_mst.w_strb = '1;
    axi4_mst.w_last = axi_wdata_idx == `DCACHE_BLOCK_SIZE / 4 - 1;
    axi4_mst.w_user = '0;
    axi4_mst.w_valid = cache_state == WRITE_BACK &
                       meta_ram_rdata[repl_way].valid &
                       meta_ram_rdata[repl_way].dirty;
    // input: axi4_mst.w_ready

    // input: axi4_mst.b_id
    // input: axi4_mst.b_resp
    // input: axi4_mst.b_user
    // input: axi4_mst.b_valid
    axi4_mst.b_ready = '0;

    axi4_mst.ar_id = '0;
    axi4_mst.ar_addr = s2_paddr;
    axi4_mst.ar_len = `DCACHE_BLOCK_SIZE / 4;
    axi4_mst.ar_size = 3'b010;  // 4 bytes;
    axi4_mst.ar_burst = 2'b01;  // Incrementing-address burst
    axi4_mst.ar_lock = '0;
    axi4_mst.ar_cache = '0;
    axi4_mst.ar_prot = '0;
    axi4_mst.ar_qos = '0;
    axi4_mst.ar_region = '0;
    axi4_mst.ar_user = '0;
    axi4_mst.ar_valid = cache_state == LOOK_UP;
    // input: axi4_mst.ar_ready

    // input: axi4_mst.r_id
    // input: axi4_mst.r_data
    // input: axi4_mst.r_resp
    // input: axi4_mst.r_last
    // input: axi4_mst.r_user
    // input: axi4_mst.r_valid
    axi4_mst.r_ready = cache_state == REFILL;
  end



/*=============================== Cache Memory ================================*/

  /* mem ctrl */
  always_comb begin
    // data ram
    data_ram_waddr = `DCACHE_IDX_OF(s2_vaddr);
    data_ram_we = '0;
    if (cache_state == REFILL) begin
      // 触发重填时的写入：axi读有效 & axi最后一个数据 & 不是uncache操作 (不触发axi读取则一定不写入)
      data_ram_we[repl_way] = axi4_mst.r_valid & axi4_mst.r_last & ~s2_uncache;
      data_ram_wdata = {axi_rdata_buffer[`DCACHE_BLOCK_SIZE / 4 - 1:1], axi4_mst.r_data};
      data_ram_wdata[s2_vaddr[`DCACHE_IDX_OFFSET - 1:2]] = s2_wdata;
    end else begin
      // hit时的写入： 指令有效 & hit(s2_ready) & store指令有效 & store指令可以执行（rob最旧指令）
      if (s2_valid && s2_store_valid && s2_ready) begin
        case (s2_align_op)
          `ALIGN_B : 
            data_ram_we[s2_matched_way][`DCACHE_OFS_OF(s2_vaddr) + 0] = '1;
          `ALIGN_H : begin 
            data_ram_we[s2_matched_way][`DCACHE_OFS_OF(s2_vaddr) + 0] = '1;
            data_ram_we[s2_matched_way][`DCACHE_OFS_OF(s2_vaddr) + 1] = '1;
          end
          `ALIGN_W : begin
            data_ram_we[s2_matched_way][`DCACHE_OFS_OF(s2_vaddr) + 0] = '1;
            data_ram_we[s2_matched_way][`DCACHE_OFS_OF(s2_vaddr) + 1] = '1;
            data_ram_we[s2_matched_way][`DCACHE_OFS_OF(s2_vaddr) + 2] = '1;
            data_ram_we[s2_matched_way][`DCACHE_OFS_OF(s2_vaddr) + 3] = '1;
          end
          default : data_ram_we[s2_matched_way] = '0;
        endcase
      end

      data_ram_wdata = '0;
      data_ram_wdata[s2_vaddr[`DCACHE_IDX_OFFSET - 1:2]] |= s2_wdata;
    end
    data_ram_raddr = `ICACHE_IDX_OF(s1_vaddr);
    // tag ram
    tag_ram_we = '0;
    tag_ram_we[s2_repl_way] = refill;  // 事实上cacop(code == 1,2)不需要写入，但是写入也不会产生错误
    tag_ram_waddr = `DCACHE_IDX_OF(s2_vaddr);
    tag_ram_wdata = cacop_mode0 ? '0 : `DCACHE_TAG_OF(paddr);
    tag_ram_raddr = s1_ready ? `ICACHE_IDX_OF(icache_req.vaddr) :  `ICACHE_IDX_OF(s1_vaddr);
    // meta ram
    meta_ram_we = '0;
    meta_ram_waddr = `ICACHE_IDX_OF(s2_vaddr);
    if (cache_state == REFILL) begin
      meta_ram_we[s2_repl_way] = refill; // 事实上cacop(code == 0)不需要写入，但是写入也不会产生错误
      meta_ram_wdata = cacop_mode1 || cacop_mode2_hit ? '{valid: 1'b0, dirty: 1'b0} : '{valid: 1'b1, dirty: 1'b0};
    end else begin
      meta_ram_we[matched_way] = s2_valid & (s2_mem_op == `MEM_STORE) & ~s2_miss & s2_ready;
      meta_ram_wdata = '{valid: 1'b1, dirty: 1'b1};
    end
    meta_ram_raddr = s1_ready ? `ICACHE_IDX_OF(icache_req.vaddr) : `DCACHE_IDX_OF(s1_vaddr);
    // plru ram
    plru_ram_we = s1_valid;
    plru_ram_waddr = `DCACHE_IDX_OF(s1_vaddr);
    plru_ram_wdata = plru_ram_rdata == matched_way ? ~plru_ram_rdata : plru_ram_rdata;
    plru_ram_raddr = s1_ready ? `DCACHE_IDX_OF(icache_req.vaddr) : `DCACHE_IDX_OF(s1_vaddr);

    // 一点转发逻辑
    // cache refill时转发tag和meta
    tag = tag_ram_rdata;
    meta = meta_ram_rdata;
    if (refill && s2_vaddr == s1_vaddr) begin
      tag[s2_repl_way] = tag_ram_wdata;
      meta[s2_repl_way] = meta_ram_wdata;
    end
  end

  // Data Memory: 每路 1 个单端口RAM
  for (genvar i = 0; i < `DCACHE_WAY_NUM; i++) begin
    SimpleDualPortRAM #(
      .DATA_DEPTH(2 ** `DCACHE_IDX_WIDTH),
      .DATA_WIDTH(`DCACHE_BLOCK_SIZE * 8),
      .BYTE_WRITE_WIDTH(8),
      .CLOCKING_MODE("common_clock"),
      .WRITE_MODE("write_first")
    ) U_DCacheDataRAM (
      .clk_a    (clk),
      .en_a_i   ('1),
      .we_a_i   (data_ram_we[i]),
      .addr_a_i (data_ram_waddr),
      .data_a_i (data_ram_wdata),
      .clk_b    (clk),
      .rstb_n   (rst_n),
      .en_b_i   ('1),
      .addr_b_i (data_ram_raddr),
      .data_b_o (data_ram_rdata[i])
    );
  end

  for (genvar j = 0; j < `DCACHE_WAY_NUM; j++) begin
    // Tag Memory
    SimpleDualPortRAM #(
      .DATA_DEPTH(2 ** `DCACHE_IDX_WIDTH),
      .DATA_WIDTH(`DCACHE_TAG_WIDTH),
      .BYTE_WRITE_WIDTH(`DCACHE_TAG_WIDTH),
      .CLOCKING_MODE("common_clock"),
      .WRITE_MODE("write_first")
    ) U_DCacheTagRAM (
      .clk_a    (clk),
      .en_a_i   ('1),
      .we_a_i   (tag_ram_we[i]),
      .addr_a_i (tag_ram_waddr),
      .data_a_i (tag_ram_data_i),
      .clk_b    (clk),
      .rstb_n   (rst_n),
      .en_b_i   ('1),
      .addr_b_i (tag_ram_raddr[i]),
      .data_b_o (tag_ram_rdata[i])
    );

    // Meta Memory
    SimpleDualPortRAM #(
      .DATA_DEPTH(2 ** `DCACHE_IDX_WIDTH),
      .DATA_WIDTH($clog2(DCacheMetaSt)),
      .BYTE_WRITE_WIDTH($clog2(DCacheMetaSt)),
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
      .data_b_o (meta_ram_rdata[i])
    );
  end

  // PLRU RAM
  SimpleDualPortRAM #(
    .DATA_DEPTH(2 ** `DCACHE_IDX_WIDTH),
    .DATA_WIDTH(`DCACHE_WAY_NUM - 1),
    .BYTE_WRITE_WIDTH(`DCACHE_WAY_NUM - 1),
    .CLOCKING_MODE("common_clock"),
    .WRITE_MODE("write_first"),
    .MEMORY_PRIMITIVE("auto")
  ) U_DCachePlruRAM (
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

endmodule : DCache
