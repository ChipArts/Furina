// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : ReorderBuffer.sv
// Create  : 2024-03-13 20:18:54
// Revise  : 2024-03-31 15:18:34
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
`include "common.svh"
`include "config.svh"
`include "Decoder.svh"
`include "Pipeline.svh"
`include "ReorderBuffer.svh"

module ReorderBuffer (
  input clk,    // Clock
  input rst_n,  // Asynchronous reset active low
  input flush_i,
  input RobAllocReqSt alloc_req,
  output RobAllocRspSt alloc_rsp,
  /* write back */
  input MiscWbSt misc_wb_req,
  input AluWbSt [1:0] alu_wb_req,
  input MduWbSt mdu_wb_req,
  input MemWbSt mem_wb_req,
  output RobWbRspSt misc_wb_rsp,
  output RobWbRspSt [1:0] alu_wb_rsp,
  output RobWbRspSt mdu_wb_rsp,
  output RobWbRspSt mem_wb_rsp,
  /* commit */
  output RobCmtSt cmt_o
);

/*=============================== Signal Define ===============================*/
  // reg
  RobEntrySt [`ROB_DEPTH - 1:0] rob, rob_n;
  logic [$clog2(`ROB_DEPTH):0] head_ptr, tail_ptr, head_ptr_n, tail_ptr_n;
  logic [$clog2(`ROB_DEPTH):0] rob_cnt_q, rob_cnt_n;
  // wire
  logic [$clog2(`DECODE_WIDTH):0] alloc_cnt;
  logic [`DECODE_WIDTH - 1:0][$clog2(`ROB_DEPTH):0] alloc_ptr;  // {pos, rob_idx}
  logic [`DECODE_WIDTH - 1:0][$clog2(`ROB_DEPTH) - 1:0] alloc_idx;

  logic [`COMMIT_WIDTH - 1:0][$clog2(`ROB_DEPTH) - 1:0] cmt_idx;

  /* write back */
  // processor state change --> psc
  // 这里的处理器状态改变指的是不可恢复的状态改变
  logic misc_psc;

  /* commit */
  logic [$clog2(`COMMIT_WIDTH):0] commit_cnt;
  logic [`COMMIT_WIDTH - 1:0] redirect_mask;  // 重定向后面的指令不允许提交
  logic [`COMMIT_WIDTH - 1:0] exc_mask;       // 异常后面的指令不允许提交
  logic [`COMMIT_WIDTH - 1:0] br_mask;        // 仅允许一条分支指令提交（BPU只有一个写口）
  logic [`COMMIT_WIDTH - 1:0] priv_mask;      // 特权指令后面的指令不允许提交（只有csrrd可以豁免，但这个优化似乎没有太大必要）
  logic [`COMMIT_WIDTH - 1:0] valid_mask;     // 是一条有效的ROB表项
  logic [`COMMIT_WIDTH - 1:0] commit_mask;    // 屏蔽后续指令的退休
  logic [`COMMIT_WIDTH - 1:0] commit_valid;   // 本次可退休得指令

/*================================= W/R Ctrl ==================================*/
  assign alloc_cnt = $countones(alloc_req.valid);
  assign alloc_rsp.ready = rob_cnt_q <= `ROB_DEPTH - `DECODE_WIDTH;
  for (genvar i = 0; i < `DECODE_WIDTH; i++) begin
    assign alloc_ptr[i] = tail_ptr + i;
    assign alloc_idx[i] = alloc_ptr[i][$clog2(`ROB_DEPTH) - 1:0];
    assign alloc_rsp.position_bit[i] = alloc_ptr[i][$clog2(`ROB_DEPTH)];
    assign alloc_rsp.rob_idx[i] = alloc_ptr[i][$clog2(`ROB_DEPTH) - 1:0];
  end
  assign tail_ptr_n = alloc_rsp.ready && alloc_req.ready ? tail_ptr + alloc_cnt : tail_ptr;

  always_comb begin
    rob_n = rob;

    /* alloc logic */
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      // 写入条件 有效 && slv可写入 && mst可接收
      if (alloc_req.valid[i] && alloc_rsp.ready && alloc_req.ready) begin
        rob_n[alloc_idx[i]] = '0;  // TODO 需要重置的字段？？？
        rob_n[alloc_idx[i]].complete = alloc_req.excp[i].valid;  // 如果有异常，视为完成执行
        rob_n[alloc_idx[i]].pc = alloc_req.pc[i];
        rob_n[alloc_idx[i]].instr_type = alloc_req.instr_type[i];
        rob_n[alloc_idx[i]].br_info = alloc_req.br_info[i];
        rob_n[alloc_idx[i]].arch_reg = alloc_req.arch_reg[i];
        rob_n[alloc_idx[i]].phy_reg = alloc_req.phy_reg[i];
        rob_n[alloc_idx[i]].old_phy_reg = alloc_req.old_phy_reg[i];
        rob_n[alloc_idx[i]].old_phy_reg_valid = alloc_req.old_phy_reg_valid[i];
        // 异常、例外处理
        rob_n[alloc_idx[i]].excp = alloc_req.excp[i];
        rob_n[alloc_idx[i]].error_vaddr = alloc_req.pc[i];
`ifdef DEBUG
        rob_n[alloc_idx[i]].instr = alloc_req.instr[i];
`endif
      end
    end

    /* write back logic */
    // misc write back
    // 除了PRIV_CSR_READ其余特权指令写回都会彻底改变处理器状态
    misc_psc = misc_wb_req.instr_type == `PRIV_INSTR & misc_wb_req.priv_op > 4'd0;  
    misc_wb_rsp.ready = ~misc_psc | misc_wb_req.base.rob_idx == cmt_idx[0];
    if (misc_wb_req.base.valid && misc_wb_rsp.ready) begin
      rob_n[misc_wb_req.base.rob_idx].complete = 1;
      // 分支预测失败处理
      rob_n[misc_wb_req.base.rob_idx].br_redirect = misc_wb_req.br_redirect;
      rob_n[misc_wb_req.base.rob_idx].br_target = misc_wb_req.br_target;
      rob_n[misc_wb_req.base.rob_idx].br_type = misc_wb_req.br_type;
      rob_n[misc_wb_req.base.rob_idx].br_taken = misc_wb_req.br_taken;
      // 异常/例外处理（misc模块执行过程中不产生例外）
      rob_n[misc_wb_req.base.rob_idx].excp = '0;
      rob_n[misc_wb_req.base.rob_idx].error_vaddr = '0;
      // write back阶段的flush缓存
      rob_n[misc_wb_req.base.rob_idx].ertn_flush = misc_wb_req.ertn_en;
      rob_n[misc_wb_req.base.rob_idx].ibar_flush = '0;
      rob_n[misc_wb_req.base.rob_idx].priv_flush = misc_wb_req.instr_type == `PRIV_INSTR & 
                                                   misc_wb_req.priv_op inside {
                                                    // `PRIV_CSR_READ,  // 无需flush
                                                    `PRIV_CSR_WRITE,
                                                    `PRIV_CSR_XCHG,
                                                    `PRIV_TLBSRCH,
                                                    `PRIV_TLBRD,
                                                    `PRIV_TLBWR,
                                                    `PRIV_TLBFILL,
                                                    `PRIV_TLBINV
                                                    // `PRIV_ERTN,  // 特殊处理
                                                    // `PRIV_IDLE   // 特殊处理
                                                   };
      rob_n[misc_wb_req.base.rob_idx].icacop_flush = '0;
      rob_n[misc_wb_req.base.rob_idx].idle_flush = misc_wb_req.idle_en;
`ifdef DEBUG
      // DEBUG
      rob_n[misc_wb_req.base.rob_idx].is_tibfill = misc_wb_req.tlbfill_en;
      rob_n[misc_wb_req.base.rob_idx].tlbfill_idx = misc_wb_req.tlbfill_idx;
      rob_n[misc_wb_req.base.rob_idx].csr_rstat = misc_wb_req.crs_rstat_diff;
      rob_n[misc_wb_req.base.rob_idx].csr_rdata = misc_wb_req.csr_rdata_diff;
      rob_n[misc_wb_req.base.rob_idx].is_cnt_instr = misc_wb_req.cnt_instr_diff;
      rob_n[misc_wb_req.base.rob_idx].timer_64 = misc_wb_req.timer_64_diff;
      // rob_n[misc_wb_req.base.rob_idx].instr = misc_wb_req.instr; alloc时设置
      rob_n[misc_wb_req.base.rob_idx].rf_wen = misc_wb_req.base.we;
      rob_n[misc_wb_req.base.rob_idx].rf_wdata = misc_wb_req.base.wdata;
      rob_n[misc_wb_req.base.rob_idx].eret = misc_wb_req.ertn_en;
      rob_n[misc_wb_req.base.rob_idx].store_valid = '0;
      rob_n[misc_wb_req.base.rob_idx].load_valid = '0;
      rob_n[misc_wb_req.base.rob_idx].store_data = '0;
      rob_n[misc_wb_req.base.rob_idx].mem_paddr = '0;
      rob_n[misc_wb_req.base.rob_idx].mem_vaddr = '0;
`endif
    end

    // alu write back
    for (int i = 0; i < 2; i++) begin
      alu_wb_rsp[i].ready = '1;  // alu计算指令可以随时写回
      if (alu_wb_req[i].base.valid && alu_wb_rsp[i].ready) begin
        rob_n[alu_wb_req[i].base.rob_idx].complete = 1;
        // 分支预测失败处理
        rob_n[alu_wb_req[i].base.rob_idx].br_redirect = '0;
        rob_n[alu_wb_req[i].base.rob_idx].br_target = '0;
        rob_n[alu_wb_req[i].base.rob_idx].br_taken = '0;
        rob_n[alu_wb_req[i].base.rob_idx].br_type = '0;
        // 异常/例外处理
        rob_n[alu_wb_req[i].base.rob_idx].excp = '0;
        rob_n[alu_wb_req[i].base.rob_idx].error_vaddr = '0;
        // write back阶段的flush缓存
        rob_n[alu_wb_req[i].base.rob_idx].ertn_flush = '0;
        rob_n[alu_wb_req[i].base.rob_idx].ibar_flush = '0;
        rob_n[alu_wb_req[i].base.rob_idx].priv_flush = '0;
        rob_n[alu_wb_req[i].base.rob_idx].icacop_flush = '0;
        rob_n[alu_wb_req[i].base.rob_idx].idle_flush = '0;
`ifdef DEBUG
        // DEBUG
        rob_n[alu_wb_req[i].base.rob_idx].is_tibfill = '0;
        rob_n[alu_wb_req[i].base.rob_idx].tlbfill_idx = '0;
        rob_n[alu_wb_req[i].base.rob_idx].csr_rstat = '0;
        rob_n[alu_wb_req[i].base.rob_idx].csr_rdata = '0;
        rob_n[alu_wb_req[i].base.rob_idx].is_cnt_instr = '0;
        rob_n[alu_wb_req[i].base.rob_idx].timer_64 = '0;
        // rob_n[alu_wb_req[i].base.rob_idx].instr = alu_wb_req[i].instr; alloc时设置
        rob_n[alu_wb_req[i].base.rob_idx].rf_wen = alu_wb_req[i].base.we;
        rob_n[alu_wb_req[i].base.rob_idx].rf_wdata = alu_wb_req[i].base.wdata;
        rob_n[alu_wb_req[i].base.rob_idx].eret = '0;
        rob_n[alu_wb_req[i].base.rob_idx].store_valid = '0;
        rob_n[alu_wb_req[i].base.rob_idx].load_valid = '0;
        rob_n[alu_wb_req[i].base.rob_idx].store_data = '0;
        rob_n[alu_wb_req[i].base.rob_idx].mem_paddr = '0;
        rob_n[alu_wb_req[i].base.rob_idx].mem_vaddr = '0;
`endif
      end
    end

    // mdu write back
    mdu_wb_rsp.ready = '1;  // mdu计算指令可以随时写回
    if (mdu_wb_req.base.valid && mdu_wb_rsp.ready) begin
      rob_n[mdu_wb_req.base.rob_idx].complete = 1;
      // 分支预测失败处理
      rob_n[mdu_wb_req.base.rob_idx].br_redirect = '0;
      rob_n[mdu_wb_req.base.rob_idx].br_target = '0;
      rob_n[mdu_wb_req.base.rob_idx].br_taken = '0;
      rob_n[mdu_wb_req.base.rob_idx].br_type = '0;
      // 异常/例外处理
      rob_n[mdu_wb_req.base.rob_idx].excp = '0;
      rob_n[mdu_wb_req.base.rob_idx].error_vaddr = '0;
      // write back阶段的flush缓存
      rob_n[mdu_wb_req.base.rob_idx].ertn_flush = '0;
      rob_n[mdu_wb_req.base.rob_idx].ibar_flush = '0;
      rob_n[mdu_wb_req.base.rob_idx].priv_flush = '0;
      rob_n[mdu_wb_req.base.rob_idx].icacop_flush = '0;
      rob_n[mdu_wb_req.base.rob_idx].idle_flush = '0;
`ifdef DEBUG
      // DEBUG
      rob_n[mdu_wb_req.base.rob_idx].is_tibfill = '0;
      rob_n[mdu_wb_req.base.rob_idx].tlbfill_idx = '0;
      rob_n[mdu_wb_req.base.rob_idx].csr_rstat = '0;
      rob_n[mdu_wb_req.base.rob_idx].csr_rdata = '0;
      rob_n[mdu_wb_req.base.rob_idx].is_cnt_instr = '0;
      rob_n[mdu_wb_req.base.rob_idx].timer_64 = '0;
      // rob_n[mdu_wb_req.base.rob_idx].instr = mdu_wb_req.instr; alloc时设置
      rob_n[mdu_wb_req.base.rob_idx].rf_wen = mdu_wb_req.base.we;
      rob_n[mdu_wb_req.base.rob_idx].rf_wdata = mdu_wb_req.base.wdata;
      rob_n[mdu_wb_req.base.rob_idx].eret = '0;
      rob_n[mdu_wb_req.base.rob_idx].store_valid = '0;
      rob_n[mdu_wb_req.base.rob_idx].load_valid = '0;
      rob_n[mdu_wb_req.base.rob_idx].store_data = '0;
      rob_n[mdu_wb_req.base.rob_idx].mem_paddr = '0;
      rob_n[mdu_wb_req.base.rob_idx].mem_vaddr = '0;
`endif
    end

    // mem write back
    // 除了load（非原子）其他mem指令都要等待成为最旧的指令
    mem_wb_rsp.ready = (mem_wb_req.mem_op == `MEM_LOAD & ~mem_wb_req.atomic) |
                       (mem_wb_req.base.rob_idx == cmt_idx[0]);
    if (mem_wb_req.base.valid && mem_wb_rsp.ready) begin
      rob_n[mem_wb_req.base.rob_idx].complete = 1;
      // 分支预测失败处理
      rob_n[mem_wb_req.base.rob_idx].br_redirect = '0;
      rob_n[mem_wb_req.base.rob_idx].br_target = '0;
      // 异常/例外处理
      rob_n[mem_wb_req.base.rob_idx].excp = mem_wb_req.base.excp;
      rob_n[mem_wb_req.base.rob_idx].error_vaddr = mem_wb_req.vaddr;
      // write back阶段的flush缓存
      rob_n[mem_wb_req.base.rob_idx].ertn_flush = '0;
      rob_n[mem_wb_req.base.rob_idx].ibar_flush = mem_wb_req.mem_op == `MEM_IBAR;
      rob_n[mem_wb_req.base.rob_idx].priv_flush = '0;
      rob_n[mem_wb_req.base.rob_idx].icacop_flush = mem_wb_req.icacop;
      rob_n[mem_wb_req.base.rob_idx].idle_flush = '0;
`ifdef DEBUG
      // DEBUG
      rob_n[mem_wb_req.base.rob_idx].is_tibfill = '0;
      rob_n[mem_wb_req.base.rob_idx].tlbfill_idx = '0;
      rob_n[mem_wb_req.base.rob_idx].csr_rstat = '0;
      rob_n[mem_wb_req.base.rob_idx].csr_rdata = '0;
      rob_n[mem_wb_req.base.rob_idx].is_cnt_instr = '0;
      rob_n[mem_wb_req.base.rob_idx].timer_64 = '0;
      // rob_n[mem_wb_req.base.rob_idx].instr = mem_wb_req.instr; alloc时设置
      rob_n[mem_wb_req.base.rob_idx].rf_wen = mem_wb_req.base.we;
      rob_n[mem_wb_req.base.rob_idx].rf_wdata = mem_wb_req.base.wdata;
      rob_n[mem_wb_req.base.rob_idx].eret = '0;
      rob_n[mem_wb_req.base.rob_idx].store_valid = mem_wb_req.mem_op == `MEM_STORE &
                                                   (~mem_wb_req.atomic | mem_wb_req.llbit);
      rob_n[mem_wb_req.base.rob_idx].load_valid = mem_wb_req.mem_op == `MEM_LOAD;
      rob_n[mem_wb_req.base.rob_idx].store_data = mem_wb_req.store_data;
      rob_n[mem_wb_req.base.rob_idx].mem_paddr = mem_wb_req.paddr;
      rob_n[mem_wb_req.base.rob_idx].mem_vaddr = mem_wb_req.vaddr;
`endif
    end
  end

  /* commit logic */
  assign head_ptr_n = head_ptr + commit_cnt;
  always_comb begin : proc_rob_commmit
    // 每个提交端口的rob read idx
    for (int i = 0; i < `COMMIT_WIDTH; i++) begin
      cmt_idx[i] = head_ptr[$clog2(`ROB_DEPTH) - 1:0] + i;
    end
    // 第一条指令一定不被屏蔽
    redirect_mask[0] = '1;
    exc_mask[0] = '1;
    br_mask[0] = '1;
    priv_mask[0] = '1;
    // 第二条指令
    // BR恢复需要抽干流水线 && 成为最后一条指令才能提交
    redirect_mask[1] = ~rob[cmt_idx[0]].br_redirect & ~rob[cmt_idx[1]].br_redirect;
    // excp恢复需要抽干流水线 && 成为最后一条指令才能提交
    exc_mask[1]      = ~rob[cmt_idx[0]].excp.valid & ~rob[cmt_idx[1]].excp.valid;
    // 仅允许一条分支指令提交（BPU更新只有一个写口）
    br_mask[1]       = rob[cmt_idx[0]].instr_type != `BR_INSTR;
    // 特权指令后面的指令不允许提交（只有csrrd可以豁免，但这个优化似乎没有太大必要）
    priv_mask[1]     = rob[cmt_idx[0]].instr_type != `PRIV_INSTR & ~rob[cmt_idx[0]].icacop_flush;

    // TODO flush 的信号设计有大量优化空间

    commit_mask = br_mask & redirect_mask & exc_mask & priv_mask;

    for (int i = 0; i < `COMMIT_WIDTH; i++) valid_mask[i] = rob_cnt_q > i;  // 有效ROB表项

    commit_valid[0] =                   rob[cmt_idx[0]].complete & commit_mask[0] & valid_mask[0];
    commit_valid[1] = commit_valid[0] & rob[cmt_idx[1]].complete & commit_mask[1] & valid_mask[1];

    commit_cnt = $countones(commit_valid);

    // output logic
    cmt_o.valid = commit_valid;
    for (int i = 0; i < `COMMIT_WIDTH; i++) begin
      cmt_o.rob_entry[i] = rob[cmt_idx[i]];
    end
  end

  /* counter updata  */
  assign rob_cnt_n = alloc_rsp.ready ? rob_cnt_q + alloc_cnt - commit_cnt : rob_cnt_q - commit_cnt;


  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n || flush_i) begin
      head_ptr <= '0;
      tail_ptr <= '0;
      rob_cnt_q <= '0;
      // rob <= '0; rob真的需要复位吗？
    end else begin
      head_ptr <= head_ptr_n;
      tail_ptr <= tail_ptr_n;
      rob_cnt_q <= rob_cnt_n;
      rob <= rob_n;
    end
  end



endmodule : ReorderBuffer
