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
  input DCacheReqSt req,
  output DCacheRspSt rsp,
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

  /* AXI FSM */
  typedef enum logic [1:0] {
    IDEL,
    MISS,
    REPLACE,
    REFILL
  } AxiState;

  AxiState axi_state;
  logic [$clog2(`DCACHE_BLOCK_SIZE / 4) - 1:0] axi_rdata_ofs;
  logic [`DCACHE_BLOCK_SIZE / 4 - 1:0][31:0] axi_rdata_buffer;

  /* stage 1 logic */
  logic miss;
  logic [`PROC_PALEN - 1:0] paddr;
  logic [$clog2(`DCACHE_WAY_NUM) - 1:0] matched_way;
  logic [`DCACHE_WAY_NUM - 1:0] matched_way_oh;
  logic [$clog2(`DCACHE_WAY_NUM) - 1:0] repl_way;
  logic [`PROC_PALEN - 1:0] repl_paddr;

  /* stage 2 logic */
  logic [31:0] matched_word;
  typedef struct packed {
    logic valid;
    logic [`PROC_PALEN - 1:0] paddr;
    AlignOpType align_op;
    logic [31:0] wdata;
  } StoreBuffer;
  StoreBuffer store_buffer;


/*================================ Cache Stage0 ================================*/
  // 1. 从CPU读取请求
  // 2. 生成MMU请求
  // 3. 访问Tag RAM，Meta RAM，PLRU RAM

  always_comb begin
    s0_ready = s1_ready;
    rsp.ready = s0_ready;
    if (req.valid) begin
      addr_trans_req.valid = s1_ready;
      addr_trans_req.ready = 1'b1;
      addr_trans_req.vaddr = req.vaddr;
    end
  end


/*================================ Cache Stage1 ================================*/
  logic s1_valid;
  logic [`PROC_VALEN - 1:0] s1_vaddr;
  MemType s1_mem_type;
  logic [3:0][7:0] s1_wdata;
  AlignOpType s1_align_op;
  logic [$clog2(`PHY_REG_NUM) - 1:0] s1_pdest;
  logic [$clog2(`ROB_DEPTH) - 1:0] s1_rob_idx;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n || flush_i) begin
      s1_valid <= '0;
      s1_vaddr <= '0;
      s1_mem_type <= '0;
      s1_wdata <= '0;
      s1_align_op <= '0;
      s1_pdest <= '0;
      s1_rob_idx <= '0;
    end else begin
      if (s1_ready) begin
        s1_valid <= req.valid;
        s1_vaddr <= req.vaddr;
        s1_mem_type <= req.mem_type;
        s1_wdata <= req.wdata;
        s1_align_op <= req.align_op;
        s1_pdest <= req.pdest;
        s1_rob_idx <= req.rob_idx;
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
  // 8. 如果miss，启动AXI/Cache状态机, 并阻塞流水线

  always_comb begin
    s1_ready = ~(s1_valid & miss);

    // 1. 获得MMU读取响应
    paddr = addr_trans_rsp.paddr;
    // 2. 访问Data RAM
    // 3. 判断Cache的命中情况
    for (int i = 0; i < `DCACHE_WAY_NUM; i++) begin
      matched_way_oh[i] = (tag_ram_rdata[i] == `DCACHE_TAG_OF(paddr)) & meta_ram_rdata[i].valid;
    end
    miss = ~|matched_way_oh;
    // 4. 如果hit，生成cache way选择信号
    matched_way = '0;
    for (int i = 0; i < `DCACHE_WAY_NUM; i++) begin
      if (matched_way_oh[i]) begin
        matched_way = i;
      end
    end
    // 5. 如果miss，选择替换的cache way
    repl_way = plru_ram_rdata;
    repl_paddr = {tag_ram_rdata[repl_way], paddr[`DCACHE_TAG_OFFSET - 1:0]};
    // 6. 更新plru RAM
    // 7. 生成写入数据(正常写入/refill)
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      axi_state <= IDEL;
      axi_rdata_ofs <= '0;
      axi_rdata_buffer <= '0;
    end else begin
      case (axi_state)
        IDEL : if(miss && s1_valid) axi_state <= MISS;
        MISS : begin
          if (meta_ram_rdata[repl_way].valid &&
              meta_ram_rdata[repl_way].dirty ) begin
            if (axi4_mst.aw_ready) axi_state <= REPLACE;
          end else begin
            axi_state <= REFILL;
          end
        end
        REPLACE : if(axi4_mst.w_last) axi_state <= REFILL;
        REFILL : if(axi4_mst.r_last) axi_state <= IDEL;
        default : /* default */;
      endcase
      // axi读数据缓存
      if (axi_state == REFILL) begin
        if (axi4_mst.r_valid && axi4_mst.r_ready) begin
          axi_rdata_buffer[axi_rdata_ofs] <= axi4_mst.r_data;
          axi_rdata_ofs <= axi_rdata_ofs + 1;
        end
      end else begin
        axi_rdata_ofs <= '0;
      end
    end
  end

  always_comb begin
    axi4_mst.aw_id = '0;
    axi4_mst.aw_addr = repl_paddr;
    axi4_mst.aw_len = `DCACHE_BLOCK_SIZE / 4;
    axi4_mst.aw_size = 3'b010;  // 4 bytes
    axi4_mst.aw_burst = 2'b01;  // Incrementing-address burst
    axi4_mst.aw_lock = '0;
    axi4_mst.aw_cache = '0;
    axi4_mst.aw_prot = '0;
    axi4_mst.aw_qos = '0;
    axi4_mst.aw_region = '0;
    axi4_mst.aw_user = '0;
    axi4_mst.aw_valid = axi_state == MISS;
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
    axi4_mst.ar_len = `DCACHE_BLOCK_SIZE / 4;
    axi4_mst.ar_size = 3'b010;  // 4 bytes;
    axi4_mst.ar_burst = 2'b01;  // Incrementing-address burst
    axi4_mst.ar_lock = '0;
    axi4_mst.ar_cache = '0;
    axi4_mst.ar_prot = '0;
    axi4_mst.ar_qos = '0;
    axi4_mst.ar_region = '0;
    axi4_mst.ar_user = '0;
    axi4_mst.ar_valid = axi_state == REFILL;
    // input: axi4_mst.ar_ready

    // input: axi4_mst.r_id
    // input: axi4_mst.r_data
    // input: axi4_mst.r_resp
    // input: axi4_mst.r_last
    // input: axi4_mst.r_user
    // input: axi4_mst.r_valid
    axi4_mst.r_ready = axi_state == REFILL;
  end
  

/*================================ Cache Stage2 ================================*/
  logic s2_valid;
  logic s2_miss;
  logic [`PROC_VALEN - 1:0] s2_vaddr;
  logic [`PROC_PALEN - 1:0] s2_paddr;
  logic [31:0] s2_wdata;
  logic [$clog2(`DCACHE_WAY_NUM) - 1:0] s2_matched_way;
  MemType s2_mem_type;
  AlignOpType s2_align_op;
  logic [$clog2(`PHY_REG_NUM) - 1:0] s2_pdest;
  logic [$clog2(`ROB_DEPTH) - 1:0] s2_rob_idx;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n || flush_i) begin
      s2_valid <= '0;
      s2_miss <= '0;
      s2_vaddr <= '0;
      s2_paddr <= '0;
      s2_wdata <= '0;
      s2_matched_way <= '0;
      s2_mem_type <= '0;
      s2_align_op <= '0;
      s2_pdest <= '0;
      s2_rob_idx <= '0;
      store_buffer <= '0;
    end else begin
      if (s2_ready) begin
        s2_valid <= s1_valid;
        s2_miss <= miss;
        s2_vaddr <= s1_vaddr;
        s2_paddr <= paddr;
        s2_wdata <= s1_wdata;
        s2_matched_way <= matched_way;
        s2_mem_type <= s1_mem_type;
        s2_align_op <= s1_align_op;
        s2_pdest <= s1_pdest;
        s2_rob_idx <= s1_rob_idx;
      end
    end
  end

  // 1. 生成CPU响应
  // 2. 处理store写入

  always_comb begin
    s2_ready = req.ready;
    // 1. 生成CPU响应
    rsp.valid = s2_valid & ~s2_miss;
    rsp.mem_type = s2_mem_type;
    rsp.pdest = s2_pdest;
    rsp.rob_idx = s2_rob_idx;

    matched_word = data_ram_rdata[s2_matched_way][s2_vaddr[`DCACHE_IDX_OFFSET - 1:2]];
    case (s2_align_op)
      `ALIGN_B: begin
        case (s2_vaddr[1:0])
          2'b00: rsp.rdata = {{24{matched_word[7]}},  matched_word[7:0]};
          2'b01: rsp.rdata = {{24{matched_word[15]}}, matched_word[15:8]};
          2'b10: rsp.rdata = {{24{matched_word[23]}}, matched_word[23:16]};
          2'b11: rsp.rdata = {{24{matched_word[31]}}, matched_word[31:24]};
          default : /* default */;
        endcase
      end
      `ALIGN_H: begin
        case (s2_vaddr[1:0])
          2'b00: rsp.rdata = {{16{matched_word[15]}}, matched_word[15:0]};
          2'b10: rsp.rdata = {{16{matched_word[31]}}, matched_word[31:16]};
          default : /* default */;
        endcase
      end
      `ALIGN_W: stage2_output_st_o.data = matched_word;
      `ALIGN_BU: begin
        case (s2_vaddr[1:0])
          2'b00: rsp.rdata = {{24{1'b0}}, matched_word[7:0]};
          2'b01: rsp.rdata = {{24{1'b0}}, matched_word[15:8]};
          2'b10: rsp.rdata = {{24{1'b0}}, matched_word[23:16]};
          2'b11: rsp.rdata = {{24{1'b0}}, matched_word[31:24]};
          default : /* default */;
        endcase
      end
      `ALIGN_HU: begin
        case (s2_vaddr[1:0])
          2'b00: rsp.rdata = {{16{1'b0}}, matched_word[15:0]};
          2'b10: rsp.rdata = {{16{1'b0}}, matched_word[31:16]};
          default : /* default */;
        endcase
      end
      default : rsp.rdata = '0;
    endcase
  end



/*=============================== Cache Memory ================================*/

  /* mem ctrl */
  always_comb begin
    // data ram
    data_ram_we = '0;
    if (axi_state == REFILL) begin
      data_ram_waddr = `DCACHE_IDX_OF(s1_vaddr);
      data_ram_we[repl_way] = axi4_mst.r_last;
      data_ram_wdata = {axi_rdata_buffer[`DCACHE_BLOCK_SIZE / 4 - 1:1], axi4_mst.r_data};
    end else begin
      // 写入条件（stage2）：有效 store hit store可以提交(是rob最后一条指令)
      if (s2_valid && s2_mem_type == `MEM_STORE && ~s2_miss && s2_ready) begin
        case (s2_align_op)
          `ALIGN_B : 
            data_ram_we[matched_way][`DCACHE_OFS_OF(s2_vaddr) + 0] = '1;
          `ALIGN_H : begin 
            data_ram_we[matched_way][`DCACHE_OFS_OF(s2_vaddr) + 0] = '1;
            data_ram_we[matched_way][`DCACHE_OFS_OF(s2_vaddr) + 1] = '1;
          end
          `ALIGN_W : begin
            data_ram_we[matched_way][`DCACHE_OFS_OF(s2_vaddr) + 0] = '1;
            data_ram_we[matched_way][`DCACHE_OFS_OF(s2_vaddr) + 1] = '1;
            data_ram_we[matched_way][`DCACHE_OFS_OF(s2_vaddr) + 2] = '1;
            data_ram_we[matched_way][`DCACHE_OFS_OF(s2_vaddr) + 3] = '1;
          end
          default : data_ram_we[matched_way] = '0;
        endcase
      end

      data_ram_wdata = '0;
      data_ram_wdata[s2_vaddr[`DCACHE_IDX_OFFSET - 1:2]] |= s2_wdata;
    end
    data_ram_raddr = `ICACHE_IDX_OF(s1_vaddr);
    // tag ram
    tag_ram_we = '0;
    tag_ram_we[repl_way] = axi_state == REFILL & axi4_mst.r_last;
    tag_ram_waddr = `DCACHE_IDX_OF(s1_vaddr);
    tag_ram_wdata = `DCACHE_TAG_OF(paddr);
    tag_ram_raddr = miss ? `ICACHE_IDX_OF(s1_vaddr) : `ICACHE_IDX_OF(icache_req.vaddr);
    // meta ram
    meta_ram_we = '0;
    meta_ram_we[repl_way] = axi_state == REFILL & axi4_mst.r_last;
    meta_ram_we[matched_way] = s2_valid & (s2_mem_type == `MEM_STORE) & ~s2_miss & s2_ready;
    meta_ram_waddr = axi_state == REFILL ? `DCACHE_IDX_OF(s1_vaddr) : `ICACHE_IDX_OF(s2_vaddr);
    meta_ram_wdata = axi_state == REFILL ? '{valid: 1'b1, dirty: 1'b0} : '{valid: 1'b1, dirty: 1'b1};
    meta_ram_raddr = miss ? `DCACHE_IDX_OF(s1_vaddr) : `ICACHE_IDX_OF(icache_req.vaddr);
    // plru ram
    plru_ram_we = s1_valid;
    plru_ram_waddr = `DCACHE_IDX_OF(s1_vaddr);
    plru_ram_wdata = plru_ram_rdata == matched_way ? ~plru_ram_rdata : plru_ram_rdata;
    plru_ram_raddr = miss ? `DCACHE_IDX_OF(s1_vaddr) : `DCACHE_IDX_OF(icache_req.vaddr);
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
