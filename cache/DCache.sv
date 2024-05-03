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
  logic [`DCACHE_WAY_NUM - 1:0] data_ram_we;
  logic [`DCACHE_IDX_WIDTH - 1:0] data_ram_waddr;
  logic [`DCACHE_BLOCK_SIZE - 1:0][7:0] data_ram_wdata;
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
  typedef enum logic [2:0] {
    IDEL,        // 空闲
    WAIT,        // 有些指令需要等待ready信号
    MISS,        // 发生miss或cacop等需要复用处理流程，有必要则同时等待aw_ready、ar_ready
    REPLACE,     // 写回脏数据，有必要则等待ar_ready
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

  // cache state 控制相关信号
  logic idle2wait;  // cache fsm的启动信号

  // tag、meta在refill时需要转发，确保下一周期不会触发miss
  logic [`DCACHE_WAY_NUM - 1:0][`DCACHE_TAG_WIDTH - 1:0] tag;
  DCacheMetaSt [`DCACHE_WAY_NUM - 1:0] meta;
  logic [3:0] w_strb;

  /* stage 2 logic */
  logic [`DCACHE_BLOCK_SIZE / 4 - 1:0][31:0] cache_line;
  logic [31:0] matched_word;
  // cache state 控制相关信号
  logic repl_complete;  // cache 的写回完成(ff)

  logic wait2miss;      // store、load产生miss
  logic wait2refill;    // caaop操作

  logic miss2repl;      // store aw_ready
  logic miss2refill;    // load ar_ready

  logic repl2refill;    // cache   store 完成写回
  logic repl2idle  ;    // uncache store 完成写回

  logic refill2idle;    // cache 重填（load、store、cacop）


  logic uncache_store;
  logic write_req;  // 是否需要写回
  logic cacop_mode0;
  logic cacop_mode1;
  logic cacop_mode2;
  logic cacop_mode2_hit;
  logic read_req; // 是否需要从axi读取数据

  logic [3:0][7:0] store_data;


/*================================ Cache Stage0 ================================*/
  // 1. 从CPU读取请求
  // 2. 生成MMU请求
  // 3. 访问Tag RAM，Meta RAM，PLRU RAM

  always_comb begin
    s0_ready = s1_ready;
    dcache_rsp.ready = s0_ready;

    addr_trans_req.valid = s1_ready & dcache_req.valid;
    addr_trans_req.ready = s1_ready;
    addr_trans_req.vaddr = dcache_req.vaddr;
    case (dcache_req.mem_op)
      `MEM_LOAD : addr_trans_req.mem_type = MMU_LOAD;
      `MEM_STORE: addr_trans_req.mem_type = MMU_STORE;
      default   : addr_trans_req.mem_type = MMU_LOAD;
    endcase
    addr_trans_req.cacop_direct = dcache_req.mem_op == `MEM_CACOP & dcache_req.code[4:3] < 2'b10;
    // excp处理
    case (dcache_req.align_op)
      `ALIGN_B : ale = '0;
      `ALIGN_H : ale = dcache_req.vaddr[0] != 1'b0;
      `ALIGN_W : ale = dcache_req.vaddr[1:0] != 2'b00;
      `ALIGN_BU: ale = '0;
      `ALIGN_HU: ale = dcache_req.vaddr[0] != 1'b0;
      default : ale = '0;
    endcase

    // 特殊判断store指令，确保SC指令在llbit==1时才执行
    store_valid = dcache_req.mem_op == `MEM_STORE & ~(dcache_req.atomic & ~dcache_req.llbit);
  end


/*================================ Cache Stage1 ================================*/
  logic s1_valid;
  logic [`PROC_VALEN - 1:0] s1_vaddr;
  MemOpType s1_mem_op;
  logic s1_atomic;
  logic s1_llbit;
  logic [31:0] s1_wdata;
  AlignOpType s1_align_op;
  logic s1_pdest_valid;
  logic [$clog2(`PHY_REG_NUM) - 1:0] s1_pdest;
  logic [$clog2(`ROB_DEPTH) - 1:0] s1_rob_idx;
  logic [4:0] s1_code;
  logic s1_preld;
  // stage 0的控制信号缓存
  logic s1_ale;
  logic s1_store_valid;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n || flush_i) begin
      s1_valid <= '0;
      s1_vaddr <= '0;
      s1_mem_op <= '0;
      s1_atomic <= '0;
      s1_llbit <= '0;
      s1_code <= '0;
      s1_wdata <= '0;
      s1_align_op <= '0;
      s1_pdest_valid <= '0;
      s1_pdest <= '0;
      s1_rob_idx <= '0;
      s1_preld <= '0;

      s1_ale <= '0;
      s1_store_valid <= '0;
    end else begin
      if (s1_ready) begin
        s1_valid <= dcache_req.valid;
        s1_vaddr <= dcache_req.vaddr;
        s1_mem_op <= dcache_req.mem_op;
        s1_atomic <= dcache_req.atomic;
        s1_llbit <= dcache_req.llbit;
        s1_code <= dcache_req.code;
        s1_wdata <= dcache_req.wdata;
        s1_align_op <= dcache_req.align_op;
        s1_pdest_valid <= dcache_req.pdest_valid;
        s1_pdest <= dcache_req.pdest;
        s1_rob_idx <= dcache_req.rob_idx;
        s1_preld <= dcache_req.preld;

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
    excp.sub_ecode = `ESUBCODE_ADEF;

    /* cache 状态机控制 */
    // 启动cache fsm的条件：
    // s1指令有效
    // s2可以处理请求（s2不暂停）
    // 没有例外
    // store、load、preld指令miss（cache缺失的处理流程）TODO 可以优化preld 在uncache时不会启动fsm
    // uncache操作，uncache不一定miss（cache缺失处理，但是跳过refill）
    // cacop(code==0) (复用cache refill)
    // cacop(code==1) (复用cache writeback refill)
    // cacop(code==2) (当且仅当hit时 复用cache writeback refill)
    idle2wait = s1_valid & ~excp.valid & s2_ready &
                (
                  s1_mem_op == `MEM_LOAD  ? miss | addr_trans_rsp.uncache:
                  s1_mem_op == `MEM_STORE ? s1_store_valid & (miss | addr_trans_rsp.uncache):
                  s1_mem_op == `MEM_CACOP & ~(s1_code[4:3] == 2'b10 & miss)
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
  logic s2_atomic;
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
  logic s2_preld;
  logic s2_store_valid;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      s2_valid <= '0;
      s2_miss <= '0;
      s2_vaddr <= '0;
      s2_paddr <= '0;
      s2_repl_paddr <= '0;
      s2_uncache <= '0;
      s2_wdata <= '0;
      s2_matched_way <= '0;
      s2_mem_op <= '0;
      s2_atomic <= '0;
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
      s2_preld <= '0;
    end else begin
      if (flush_i) begin  // 确保flush的时候其他的信息不变，否则会出现fsm控制错误
        s2_valid <= '0;
      end else if (s2_ready) begin
        s2_valid <= s1_valid;
        s2_miss <= miss;
        s2_vaddr <= s1_vaddr;
        s2_paddr <= paddr;
        s2_repl_paddr <= repl_paddr;
        s2_uncache <= addr_trans_rsp.uncache;
        s2_wdata <= s1_wdata;
        s2_matched_way <= matched_way;
        s2_mem_op <= s1_mem_op;
        s2_atomic <= s1_atomic;
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
        s2_preld <= s1_preld;
      end
    end
  end

  // 1. 生成响应
  // 2. 如果hit 处理store写入
  // 3. 如果miss，处理cache状态机

  always_comb begin
    s2_ready = (~s2_valid | dcache_req.ready) & cache_state == IDEL;

    // for uncache write
    // 当 WSTRB[n] 为 1 时，WDATA[8n+7:8n]有效。
    w_strb = '0;
    case (s2_align_op)
      `ALIGN_B : 
        w_strb[s2_vaddr[1:0] + 0] = '1;
      `ALIGN_H : begin 
        w_strb[s2_vaddr[1:0] + 0] = '1;
        w_strb[s2_vaddr[1:0] + 1] = '1;
      end
      `ALIGN_W : begin
        w_strb                    = '1;
      end
      default : w_strb = '0;
    endcase

    store_data = '0;
    case (s2_align_op)
      `ALIGN_B : 
        store_data[s2_vaddr[1:0] + 0] = s2_wdata[7:0];
      `ALIGN_H : begin 
        store_data[s2_vaddr[1:0] + 0] = s2_wdata[7:0];
        store_data[s2_vaddr[1:0] + 1] = s2_wdata[15:8];
      end
      `ALIGN_W : begin
        store_data[s2_vaddr[1:0] + 0] = s2_wdata[7:0];
        store_data[s2_vaddr[1:0] + 1] = s2_wdata[15:8];
        store_data[s2_vaddr[1:0] + 2] = s2_wdata[23:16];
        store_data[s2_vaddr[1:0] + 3] = s2_wdata[31:24];
      end
      default : store_data = '0;
    endcase

    busy_o = s1_valid | s2_valid;

    cache_line   = s2_uncache ? axi_rdata_buffer : 
                   s2_miss    ? data_ram_rdata[s2_repl_way] : 
                                data_ram_rdata[s2_matched_way];
    matched_word = cache_line[s2_vaddr[`DCACHE_IDX_OFFSET - 1:2]];


    // 1. 生成响应
    dcache_rsp.valid = s2_valid & cache_state == IDEL;
    dcache_rsp.mem_op = s2_mem_op;  // 用于rob判断是否可以写回
    dcache_rsp.atomic = s2_atomic;
    dcache_rsp.llbit = s2_llbit;
    dcache_rsp.pdest_valid = s2_pdest_valid;
    dcache_rsp.pdest = s2_pdest;
    dcache_rsp.rob_idx = s2_rob_idx;
`ifdef DEBUG
    dcache_rsp.vaddr = s2_vaddr;
    dcache_rsp.paddr = s2_paddr;
    dcache_rsp.store_data = store_data;
`endif
    

    dcache_rsp.excp = s2_excp;
    // 特殊处理preld的excp
    if (s2_preld) begin
      dcache_rsp.excp.valid = '0;
    end
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
      `ALIGN_W: dcache_rsp.rdata = matched_word;
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

    /* cache 状态机控制 */
    // MISS 阶段不是要写就是要读
    uncache_store   = s2_mem_op == `MEM_STORE & s2_uncache & s2_store_valid;
    cacop_mode0     = s2_mem_op == `MEM_CACOP & s2_code[4:3] == 2'b00;  // wr tag
    cacop_mode1     = s2_mem_op == `MEM_CACOP & s2_code[4:3] == 2'b01;  // wr valid
    cacop_mode2     = s2_mem_op == `MEM_CACOP & s2_code[4:3] == 2'b10;  // wr valid
    cacop_mode2_hit = cacop_mode2 & ~s2_miss;
    // uncache wr --> wb 1
    // uncache rd, cacop(code==0) --> wb 0
    // cacop(code==1, 2), cache st, cache ld --> wb (dirty && valid)
    write_req = uncache_store | 
                (
                  (s2_repl_meta.valid & s2_repl_meta.dirty) &
                  (~s2_uncache        | cacop_mode2_hit   ) &
                  (~cacop_mode0)
                );
    // uncache wr --> rd 0
    // cacop      --> rd 0
    // other      --> rd 1 (ibar、dbar不会启动状态机)
    read_req = ~(uncache_store | s2_mem_op == `MEM_CACOP);

    // store 和 cacop 指令需要等待ready信号
    // wait2miss;    <=> store、load产生miss，cacop(1,2) dirty
    // wait2refill;  <=> caaop ~dirty
    // miss2repl;    <=> aw_ready
    // miss2refill;  <=> ar_ready
    // repl2refill;  <=> cache 完成写回 且 ar_ready
    // repl2idle  ;  <=> uncache、cacop store 完成写回
    // refill2idle;  <=> cache 重填（load、store、cacop）
    wait2miss   = s2_mem_op == `MEM_STORE ? dcache_req.ready :  // refill时要写入更改信息 索性等待ready
                  s2_mem_op == `MEM_CACOP ? dcache_req.ready & s2_repl_meta.valid & s2_repl_meta.dirty & ~cacop_mode0 :
                  s2_mem_op == `MEM_LOAD  ;
    wait2refill = s2_mem_op == `MEM_CACOP & dcache_req.ready;  // fsm先判断wait2miss以确保此时无需写回

    miss2repl   = axi4_mst.aw_ready;
    miss2refill = axi4_mst.ar_ready;

    repl2refill = ~s2_uncache & 
                  repl_complete &                   // TODO 有优化的空间 可以提前一拍
                  (~read_req | axi4_mst.ar_ready);  // TODO 这里可能有bug 可能需要将ar_ready用寄存器保存？？？ 就目前来看wr完成前不会产生aw_ready
    repl2idle   = s2_uncache &
                  axi4_mst.w_last & axi4_mst.w_valid & axi4_mst.w_ready;

    refill2idle = s2_mem_op == `MEM_CACOP |
                  (axi4_mst.r_valid & axi4_mst.r_last & axi4_mst.r_ready);

  end

  /* cache fsm */
  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      cache_state <= IDEL;
      repl_complete <= '0;
      axi_rdata_idx <= '0;
      axi_rdata_buffer <= '0;
    end else begin
      case (cache_state)
        // cache 状态机的启动信号来自stage 1
        IDEL    : if (flush_i)           cache_state <= IDEL;
                  else if (idle2wait)    cache_state <= WAIT;
        WAIT    : if (flush_i)           cache_state <= IDEL;
                  else if (wait2miss)    cache_state <= MISS;
                  else if (wait2refill)  cache_state <= REFILL;
        MISS    : if (miss2repl)         cache_state <= REPLACE;
                  else if (miss2refill)  cache_state <= REFILL;
        REPLACE : if (repl2refill)       cache_state <= REFILL;
                  else if (repl2idle)    cache_state <= IDEL;
        REFILL  : if(refill2idle)        cache_state <= IDEL;
        default : cache_state <= IDEL;
      endcase
      // axi读数据缓存
      if (cache_state == REFILL) begin
        if (axi4_mst.r_valid && axi4_mst.r_ready) begin
          axi_rdata_buffer[axi_rdata_idx] <= axi4_mst.r_data;
          axi_rdata_idx <= (axi_rdata_idx + 1 == `DCACHE_BLOCK_SIZE / 4) ? axi_rdata_idx : axi_rdata_idx + 1;
        end 
      end else begin
        axi_rdata_idx <= s2_uncache ? s2_vaddr[`DCACHE_IDX_OFFSET - 1:2] : '0;
      end
      // axi写
      if (cache_state == REPLACE) begin
        if (axi4_mst.w_ready && axi4_mst.w_valid) begin
          axi_wdata_idx <= (axi_wdata_idx + 1 == `DCACHE_BLOCK_SIZE / 4) ? axi_wdata_idx : axi_wdata_idx + 1;
        end

        if (axi4_mst.w_ready && axi4_mst.w_valid && axi4_mst.w_last) begin
          repl_complete <= '1;
        end
      end else begin
        axi_wdata_idx <= '0;
        repl_complete <= '0;
      end
    end
  end



  always_comb begin
    axi4_mst.aw_id = '0;
    axi4_mst.aw_addr = s2_uncache ? s2_paddr : `DCACHE_PADDR_ALIGN(s2_repl_paddr);  // 以cache行为单位
    axi4_mst.aw_len =  s2_uncache ? '0 : `DCACHE_BLOCK_SIZE / 4 - 1;
    axi4_mst.aw_size = 3'b010;  // 4 bytes
    axi4_mst.aw_burst = 2'b01;  // Incrementing-address burst
    axi4_mst.aw_lock = '0;
    axi4_mst.aw_cache = '0;
    axi4_mst.aw_prot = '0;
    axi4_mst.aw_qos = '0;
    axi4_mst.aw_region = '0;
    axi4_mst.aw_user = '0;
    axi4_mst.aw_valid = cache_state == MISS & write_req;
    // input: axi4_mst.aw_ready

    axi4_mst.w_id   = '0;
    axi4_mst.w_data = s2_uncache ? store_data : cache_line[axi_wdata_idx];
    axi4_mst.w_strb = s2_uncache ? w_strb     : '1;
    axi4_mst.w_last = s2_uncache ? '1         : axi_wdata_idx == `DCACHE_BLOCK_SIZE / 4 - 1;
    axi4_mst.w_user = '0;
    axi4_mst.w_valid = cache_state == REPLACE;
    // input: axi4_mst.w_ready

    // input: axi4_mst.b_id
    // input: axi4_mst.b_resp
    // input: axi4_mst.b_user
    // input: axi4_mst.b_valid
    axi4_mst.b_ready = '1;

    axi4_mst.ar_id = '0;
    axi4_mst.ar_addr = s2_uncache  ? s2_paddr : `DCACHE_PADDR_ALIGN(s2_paddr);  // 以cache行为单位;
    axi4_mst.ar_len =  s2_uncache  ? '0 : `DCACHE_BLOCK_SIZE / 4 - 1;  // UART不支持burst ？？？
    axi4_mst.ar_size = 3'b010;  // 4 bytes;
    axi4_mst.ar_burst = 2'b01;  // Incrementing-address burst
    axi4_mst.ar_lock = '0;
    axi4_mst.ar_cache = '0;
    axi4_mst.ar_prot = '0;
    axi4_mst.ar_qos = '0;
    axi4_mst.ar_region = '0;
    axi4_mst.ar_user = '0;
    axi4_mst.ar_valid = cache_state == MISS    ? ~write_req :
                        cache_state == REPLACE ? read_req   : '0;
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
    data_ram_we = '0;
    data_ram_waddr = `DCACHE_IDX_OF(s2_vaddr);
    if (cache_state == REFILL) begin
      // 重填时的写入： 指令有效 && axi读有效 && axi最后一个数据 && 不是uncache操作 (不触发axi读取则一定不写入)
      data_ram_we[s2_repl_way] = s2_valid & axi4_mst.r_valid & axi4_mst.r_last & ~s2_uncache;
      // init wdata
      data_ram_wdata = {axi4_mst.r_data, axi_rdata_buffer[`DCACHE_BLOCK_SIZE / 4 - 2:0]};
    end else begin
      // hit时的写入： 指令有效 & hit(dcache_req.ready) & store指令有效 & store指令可以执行（rob最旧指令）& 无例外
      data_ram_we[s2_matched_way] = s2_valid & ~s2_miss & s2_store_valid & dcache_req.ready & ~s2_excp.valid ;
      // init wdata
      data_ram_wdata = cache_line;
    end
    // 添加写入的内容
    if (s2_store_valid) begin
      case (s2_align_op)
        `ALIGN_B : 
          data_ram_wdata[`DCACHE_OFS_OF(s2_vaddr) + 0] = s2_wdata[7:0];
        `ALIGN_H : begin 
          data_ram_wdata[`DCACHE_OFS_OF(s2_vaddr) + 0] = s2_wdata[7:0];
          data_ram_wdata[`DCACHE_OFS_OF(s2_vaddr) + 1] = s2_wdata[15:8];
        end
        `ALIGN_W : begin
          data_ram_wdata[`DCACHE_OFS_OF(s2_vaddr) + 0] = s2_wdata[7:0];
          data_ram_wdata[`DCACHE_OFS_OF(s2_vaddr) + 1] = s2_wdata[15:8];
          data_ram_wdata[`DCACHE_OFS_OF(s2_vaddr) + 2] = s2_wdata[23:16];
          data_ram_wdata[`DCACHE_OFS_OF(s2_vaddr) + 3] = s2_wdata[31:24];
        end
        default : data_ram_wdata = '0;
      endcase
    end

    data_ram_raddr = s2_ready ? `DCACHE_IDX_OF(s1_vaddr) : `DCACHE_IDX_OF(s2_vaddr);

    // tag ram
    tag_ram_we = '0;
    if (cache_state == REFILL) begin
      tag_ram_we[s2_repl_way] = s2_valid &                                            // 指令有效
                                (
                                  (axi4_mst.r_valid & axi4_mst.r_last & ~s2_uncache) |  // cache miss refill
                                  (cacop_mode0)                                         // cacop mode 0 fill tag
                                 );
                                
    end
    tag_ram_waddr = `DCACHE_IDX_OF(s2_vaddr);
    tag_ram_wdata = cacop_mode0 ? '0 : `DCACHE_TAG_OF(s2_paddr);
    tag_ram_raddr = s1_ready ? `DCACHE_IDX_OF(dcache_req.vaddr) :  `DCACHE_IDX_OF(s1_vaddr);

    // meta ram
    meta_ram_we = '0;
    meta_ram_waddr = `DCACHE_IDX_OF(s2_vaddr);
    if (cache_state == REFILL) begin
      meta_ram_we[s2_repl_way] = s2_valid &                                            // 指令有效
                                 (
                                   (axi4_mst.r_valid & axi4_mst.r_last & ~s2_uncache) |  // cache miss refill
                                   (cacop_mode1 | cacop_mode2)                           // cacop mode 1、2 invalid cache line
                                  );
                                 
      meta_ram_wdata = cacop_mode1 || cacop_mode2 ? '{valid: 1'b0, dirty: 1'b0} :      // cacop invalid
                       s2_store_valid             ? '{valid: 1'b1, dirty: 1'b1} :      // cache miss store refill
                                                    '{valid: 1'b1, dirty: 1'b0} ;      // cache miss load  refill
    end else begin
      // hit时的写入： 指令有效 & hit(dcache_req.ready) & store指令有效 & store指令可以执行（rob最旧指令）& 无例外
      meta_ram_we[s2_matched_way] = s2_valid & ~s2_miss & s2_store_valid & dcache_req.ready & ~s2_excp.valid;
      meta_ram_wdata = '{valid: 1'b1, dirty: 1'b1};
    end
    meta_ram_raddr = s1_ready ? `DCACHE_IDX_OF(dcache_req.vaddr) : `DCACHE_IDX_OF(s1_vaddr);

    // plru ram
    plru_ram_we = s1_valid;
    plru_ram_waddr = `DCACHE_IDX_OF(s1_vaddr);
    plru_ram_wdata = plru_ram_rdata == matched_way ? ~plru_ram_rdata : plru_ram_rdata;
    plru_ram_raddr = s1_ready ? `DCACHE_IDX_OF(dcache_req.vaddr) : `DCACHE_IDX_OF(s1_vaddr);

    // 一点转发逻辑
    // cache refill时转发tag和meta
    for (int i = 0; i < `DCACHE_WAY_NUM; i++) begin
      if (tag_ram_we[i] && tag_ram_waddr == `DCACHE_IDX_OF(s1_vaddr)) begin
        tag[i] = tag_ram_wdata;
      end else begin
        tag[i] = tag_ram_rdata[i];
      end
      
      if (meta_ram_we[i] && meta_ram_waddr == `DCACHE_IDX_OF(s1_vaddr)) begin
        meta[i] = meta_ram_wdata;
      end else begin
        meta[i] = meta_ram_rdata[i];
      end
    end
  end

  // Data Memory: 每路 1 个单端口RAM
  for (genvar i = 0; i < `DCACHE_WAY_NUM; i++) begin : gen_dcache_data_ram
    SimpleDualPortRAM #(
      .DATA_DEPTH(2 ** `DCACHE_IDX_WIDTH),
      .DATA_WIDTH(`DCACHE_BLOCK_SIZE * 8),
      .BYTE_WRITE_WIDTH(`DCACHE_BLOCK_SIZE * 8),
      .CLOCKING_MODE("common_clock"),
      .WRITE_MODE("write_first")
    ) U_DCacheDataRAM (
      .clk_a    (clk),
      .en_a_i   (~flush_i),
      .we_a_i   (data_ram_we[i]),
      .addr_a_i (data_ram_waddr),
      .data_a_i (data_ram_wdata),
      .clk_b    (clk),
      .rstb_n   (rst_n),
      .en_b_i   (~flush_i),
      .addr_b_i (data_ram_raddr),
      .data_b_o (data_ram_rdata[i])
    );
  end

  for (genvar i = 0; i < `DCACHE_WAY_NUM; i++) begin : gen_dcache_tag_meta_ram
    // Tag Memory
    SimpleDualPortRAM #(
      .DATA_DEPTH(2 ** `DCACHE_IDX_WIDTH),
      .DATA_WIDTH(`DCACHE_TAG_WIDTH),
      .BYTE_WRITE_WIDTH(`DCACHE_TAG_WIDTH),
      .CLOCKING_MODE("common_clock"),
      .WRITE_MODE("write_first")
    ) U_DCacheTagRAM (
      .clk_a    (clk),
      .en_a_i   (~flush_i),
      .we_a_i   (tag_ram_we[i]),
      .addr_a_i (tag_ram_waddr),
      .data_a_i (tag_ram_wdata),
      .clk_b    (clk),
      .rstb_n   (rst_n),
      .en_b_i   (~flush_i),
      .addr_b_i (tag_ram_raddr),
      .data_b_o (tag_ram_rdata[i])
    );

    // Meta Memory
    SimpleDualPortRAM #(
      .DATA_DEPTH(2 ** `DCACHE_IDX_WIDTH),
      .DATA_WIDTH($bits(DCacheMetaSt)),
      .BYTE_WRITE_WIDTH($bits(DCacheMetaSt)),
      .CLOCKING_MODE("common_clock"),
      .WRITE_MODE("write_first")
    ) U_DCacheMetaRAM (
      .clk_a    (clk),
      .en_a_i   (~flush_i),
      .we_a_i   (meta_ram_we[i]),
      .addr_a_i (meta_ram_waddr),
      .data_a_i (meta_ram_wdata),
      .clk_b    (clk),
      .rstb_n   (rst_n),
      .en_b_i   (~flush_i),
      .addr_b_i (meta_ram_raddr),
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
    .en_a_i   (~flush_i),
    .we_a_i   (plru_ram_we),
    .addr_a_i (plru_ram_waddr),
    .data_a_i (plru_ram_wdata),
    .clk_b    (clk),
    .rstb_n   (rst_n),
    .en_b_i   (~flush_i),
    .addr_b_i (plru_ram_raddr),
    .data_b_o (plru_ram_rdata)
  );

endmodule : DCache
