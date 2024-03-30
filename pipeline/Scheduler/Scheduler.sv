// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Scheduler.sv
// Create  : 2024-03-12 23:16:08
// Revise  : 2024-03-29 20:48:28
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
`include "Scheduler.svh"
`include "Decoder.svh"
`include "ReorderBuffer.svh"

module Scheduler (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input logic flush_i,
  
  input ScheduleReqSt schedule_req,
  output ScheduleRspSt schedule_rsp,

  output RobAllocReqSt rob_alloc_req,
  input RobAllocRspSt rob_alloc_rsp,

  // freelist
  input [`RETIRE_WIDTH - 1:0] fl_free_valid_i,
  input [`RETIRE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] fl_free_preg_i,
  // rat
  input [31:0][$clog2(`PHY_REG_NUM) - 1:0] arch_rat_i,
  // wake up
  input logic [`COMMIT_WIDTH - 1:0] cmt_pdest_valid_i,
  input [`COMMIT_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] cmt_pdest_i,

  /* issue */
  // misc(BRU/Priv) * 1
  output MiscIssueSt misc_issue_o,
  input logic misc_ready_i,
  // ALU * 2
  output AluIssueSt [1:0] alu_issue_o,
  input logic [1:0] alu_ready_i,
  // MDU * 1
  output MduIssueSt mdu_issue_o,
  input logic mdu_ready_i,
  // memory * 1
  output MemIssueSt mem_issue_o,
  input logic mem_ready_i
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

  /* ready signal define */
  logic s0_ready, s1_ready, s2_ready;

/*================================== stage0 ===================================*/
  // 接收inst信息
  // 读取freelist

  // freelist ==> fl
  logic fl_alloc_ready;
  logic [`DECODE_WIDTH - 1:0] fl_alloc_valid;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] fl_alloc_preg;

  always_comb begin
    s0_ready = s1_ready & fl_alloc_ready;
    schedule_rsp.ready = s0_ready;

    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      fl_alloc_valid[i] = schedule_req.valid[i] &
                          schedule_req.dest_valid[i] &
                          s1_ready;
    end
  end

  // FreeList comb 输出
  FreeList #(
    .PHY_REG_NUM(`PHY_REG_NUM)
  ) inst_FreeList (
    .clk           (clk),
    .a_rst_n       (rst_n),
    .flush_i       (flush_i),
    .alloc_valid_i (fl_alloc_valid),
    .alloc_ready_o (fl_alloc_ready),
    .free_valid_i  (fl_free_valid_i),
    .free_ready_o  (/* not used */),
    .free_preg_i   (fl_free_preg_i),
    .preg_o        (fl_alloc_preg)
  );

/*================================== stage1 ===================================*/
  // 缓存指令和解码信息
  logic [`DECODE_WIDTH - 1:0] s1_valid;
  logic [`DECODE_WIDTH - 1:0][31:0] s1_imm;
  logic [`DECODE_WIDTH - 1:0][`PROC_VALEN - 1:0] s1_vaddr;
  logic [`DECODE_WIDTH - 1:0] s1_src0_valid;
  logic [`DECODE_WIDTH - 1:0] s1_src1_valid;
  logic [`DECODE_WIDTH - 1:0] s1_dest_valid;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] s1_src0;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] s1_src1;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] s1_dest;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] s1_fl_alloc_preg;
  OptionCodeSt [`DECODE_WIDTH - 1:0] s1_option_code;

  logic dq_write_ready;

  assign s1_ready = (rob_allocate_rsp.ready & dq_write_ready) | ~(|s1_valid);

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n || flush_i) begin
      s1_valid <= '0;
      s1_option_code <= '0;
      s1_vaddr <= '0;
      s1_imm <= '0;
      s1_src0 <= '0;
      s1_src1 <= '0;
      s1_dest <= '0;
      s1_src0_valid <= '0;
      s1_src1_valid <= '0;
      s1_dest_valid <= '0;
      s1_fl_alloc_preg <= '0;
    end else begin
      if (s1_ready) begin
        s1_valid <= schedule_req.valid;
        s1_vaddr <= schedule_req.vaddr;
        s1_imm <= schedule_req.imm;
        s1_src0 <= schedule_req.src0;
        s1_src1 <= schedule_req.src1;
        s1_dest <= schedule_req.dest;
        s1_src0_valid <= schedule_req.src0_valid;
        s1_src1_valid <= schedule_req.src1_valid;
        s1_dest_valid <= schedule_req.dest_valid;
        s1_fl_alloc_preg <= fl_alloc_preg;
        s1_option_code <= schedule_req.option_code;
      end
    end
  end


  // 重命名
  logic [`DECODE_WIDTH - 1:0] rat_dest_valid;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] rat_psrc0;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] rat_psrc1;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] rat_ppdst;

  always_comb begin
    // RAT 控制逻辑
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      rat_dest_valid[i] = s1_valid[i] & s1_dest[i];
    end
  end

  RegisterAliasTable #(
    .PHYS_REG_NUM(`PHY_REG_NUM)
  ) U_IntegerRegisterAliasTable (
    .clk         (clk),
    .a_rst_n     (rst_n),
    .restore_i   (flush_i),
    .allocaion_i (/* TODO: checkpoint */),
    .free_i      (/* TODO: checkpoint */),
    .arch_rat    (arch_rat_i),
    // 查询
    .dest_valid_i(rat_dest_valid),
    .src0_i      (s1_src0),
    .src1_i      (s1_src1),
    .dest_i      (s1_dest),
    .preg_i      (s1_allocated_preg),
    // 输出
    .psrc0_o     (rat_psrc0),
    .psrc1_o     (rat_psrc1),
    .ppdst_o     (rat_ppdst)
  );

  // 写入ROB
  always_comb begin
    rob_alloc_req.valid = s1_valid;
    rob_alloc_req.ready = s1_ready;
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      rob_alloc_req.rob_entry[i].complete = '0;
      rob_alloc_req.rob_entry[i].arch_reg = s1_dest[i];
      rob_alloc_req.rob_entry[i].phy_reg = s1_fl_alloc_preg[i];
      rob_alloc_req.rob_entry[i].old_phy_reg = rat_ppdst[i];
      rob_alloc_req.rob_entry[i].pc = s1_vaddr[i];
      rob_alloc_req.rob_entry[i].exception = '0;
      rob_alloc_req.rob_entry[i].ecode = '0;
      rob_alloc_req.rob_entry[i].inst_type = s1_general_ctrl_signal[i].inst_type;
    end
  end

  // 写入分发队列
  logic [`DECODE_WIDTH - 1:0] dq_write_valid;
  DqEntrySt [`DECODE_WIDTH - 1:0] dq_wdata;

  logic [`DECODE_WIDTH - 1:0] dq_read_valid;
  logic [`DECODE_WIDTH - 1:0] dq_read_ready;
  DqEntrySt [`DECODE_WIDTH - 1:0] dq_rdata;

  always_comb begin
    dq_write_valid = s1_valid;
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      dq_wdata[i].valid = s1_valid[i];
      dq_wdata[i].pc = s1_vaddr[i];
      dq_wdata[i].imm = s1_imm[i];
      dq_wdata[i].src0_valid = s1_src0_valid[i];
      dq_wdata[i].src1_valid = s1_src1_valid[i];
      dq_wdata[i].dest_valid = s1_dest_valid[i];
      dq_wdata[i].src0 = s1_src0[i];
      dq_wdata[i].src1 = s1_src1[i];
      dq_wdata[i].dest = s1_dest[i];
      dq_wdata[i].option_code = s1_option_code[i];
      dq_wdata[i].position_bit = rob_alloc_rsp.position_bit[i];
      dq_wdata[i].rob_idx = rob_alloc_rsp.rob_idx[i];
    end
  end

  SyncMultiChannelFIFO #(
    .FIFO_DEPTH(16),
    .DATA_WIDTH($bits(DqEntrySt)),
    .RPORTS_NUM(4),
    .WPORTS_NUM(`DECODE_WIDTH),
    .FIFO_MEMORY_TYPE("auto")
  ) inst_SyncMultiChannelFIFO (
    .clk           (clk),
    .a_rst_n       (rst_n),
    .flush_i       (flush_i),
    .write_valid_i (dq_write_valid),
    .write_ready_o (dq_write_ready),
    .write_data_i  (dq_wdata),
    .read_valid_o  (dq_read_valid),
    .read_ready_i  (dq_read_ready),
    .read_data_o   (dq_rdata)
  );

/*================================== stage2 ===================================*/
  // 写入发射队列
  logic [3:0][1:0] alu_cnt, mdu_cnt, misc_cnt, mem_cnt;  // 记录[i]之前某类型指令的数量
  logic [1:0] alu_rs_wr_ready;
  logic mdu_rs_wr_ready;
  logic mem_rs_wr_ready;
  logic misc_rs_wr_ready;
  logic [3:0] dispatched;

  logic [1:0] alu_rs_wr_valid;
  logic mdu_rs_wr_valid;
  logic mem_rs_wr_valid;
  logic misc_rs_wr_valid;

  RsBaseSt [1:0] alu_rs_base;
  RsBaseSt mdu_rs_base;
  RsBaseSt mem_rs_base;
  RsBaseSt misc_rs_base;

  AluOpCodeSt [1:0] alu_rs_oc;
  MduOpCodeSt mdu_rs_oc;
  MemOpCodeSt mem_rs_oc;
  MiscOpCodeSt misc_rs_oc;

  logic [1:0] alu_issue_valid;
  logic mdu_issue_valid;
  logic mem_issue_valid;
  logic misc_issue_valid;

  logic [1:0] alu_issue_ready;
  logic mdu_issue_ready;
  logic mem_issue_ready;
  logic misc_issue_ready;

  IssueBaseSt [1:0] alu_issue_base;
  IssueBaseSt mdu_issue_base;
  IssueBaseSt mem_issue_base;
  IssueBaseSt misc_issue_base;

  AluOpCodeSt [1:0] alu_issue_oc;
  MduOpCodeSt mdu_issue_oc;
  MemOpCodeSt mem_issue_oc;
  MiscOpCodeSt misc_issue_oc;

  always_comb begin
    alu_cnt = 0;
    misc_cnt = 0;
    mem_cnt = 0;

    for (int i = 1; i < 3; i++) begin
      if (dq_rdata[i - 1].oc.inst_type == `ALU_INST) begin
        alu_cnt[i] = alu_cnt[i - 1] + 1;
      end
      if (dq_rdata[i - 1].oc.inst_type == `MDU_INST) begin
        mdu_cnt[i] = mdu_cnt[i - 1] + 1;
      end
      if (dq_rdata[i - 1].oc.inst_type == `MEM_INST) begin
        mem_cnt[i] = mem_cnt[i - 1] + 1;
      end
      if (dq_rdata[i - 1].oc.inst_type == `PRIV_INST ||
          dq_rdata[i - 1].oc.inst_type == `BR_INST) begin
        misc_cnt[i] = misc_cnt[i - 1] + 1;
      end
    end

    // 判断是否可以分发
    if (dq_rdata[0].valid) begin
        case (dq_rdata[0].oc.inst_type)
          `ALU_INST : dq_read_ready[0] = alu_cnt[0] < $countones(alu_rs_wr_ready);
          `MDU_INST : dq_read_ready[0] = mdu_cnt[0] < $countones(mdu_rs_wr_ready);
          `MEM_INST : dq_read_ready[0] = mem_cnt[0] < $countones(mem_rs_wr_ready);
          `PRIV_INST, `BR_INST : dq_read_ready[0] = misc_cnt[0] < $countones(misc_rs_wr_ready);
          default : dq_read_ready[0] = '0;
        endcase
    end
    for (int i = 1; i < 3; i++) begin
      if (dq_rdata[i].valid) begin
        case (dq_rdata[i].oc.inst_type)
          `ALU_INST : dq_read_ready[i] = alu_cnt[i] < $countones(alu_rs_wr_ready) & dq_read_ready[i - 1];
          `MDU_INST : dq_read_ready[i] = mdu_cnt[i] < $countones(mdu_rs_wr_ready) & dq_read_ready[i - 1];
          `MEM_INST : dq_read_ready[i] = mem_cnt[i] < $countones(mem_rs_wr_ready) & dq_read_ready[i - 1];
          `PRIV_INST, `BR_INST : dq_read_ready[i] = misc_cnt[i] < $countones(misc_rs_wr_ready) & dq_read_ready[i - 1];
          default : dq_read_ready[i] = '0;
        endcase
      end
    end

    // 写入发射队列
    dispatched = '0;
    for (int i = 0; i < 3; i++) begin
      if (dq_rdata[i].oc.inst_type == `ALU_INST && alu_cnt[i] == 0) begin
        if (alu_rs_wr_ready[0]) begin
          alu_rs_wr_valid[0] = dq_read_ready[i];
          alu_rs_base[0] = dq2rs(dq_rdata[i]);
          alu_rs_oc[0] = gen2alu(dq_rdata[i].oc);
        end else begin
          alu_rs_wr_valid[1] = dq_read_ready[i];
          alu_rs_base[1] = dq2rs(dq_rdata[i]);
          alu_rs_oc[1] = gen2alu(dq_rdata[i].oc);
        end
      end
      if (dq_rdata[i].oc.inst_type == `ALU_INST && alu_cnt[i] == 1) begin
        alu_rs_wr_valid[1] = dq_read_ready[i];
        alu_rs_base[1] = dq2rs(dq_rdata[i]);
        alu_rs_oc[1] = gen2alu(dq_rdata[i].oc);
      end
      if (dq_rdata[i].oc.inst_type == `MEM_INST && mem_cnt[i] == 0) begin
        mem_rs_wr_valid = dq_read_ready[i];
        mem_rs_base = dq2rs(dq_rdata[i]);
        mem_rs_oc = gen2mem(dq_rdata[i].oc);
      end
      if (dq_rdata[i].oc.inst_type == `MDU_INST && mdu_cnt[i] == 0) begin
        mdu_rs_wr_valid = dq_read_ready[i];
        mdu_rs_base = dq2rs(dq_rdata[i]);
        mdu_rs_oc = gen2mdu(dq_rdata[i].oc);
      end
      if ((dq_rdata[i].oc.inst_type == `PRIV_INST || 
           dq_rdata[i].oc.inst_type == `BR_INST) &&
           misc_cnt == 0) begin
        misc_rs_wr_valid = dq_read_ready[i];
        misc_rs_base = dq2rs(dq_rdata[i]);
        misc_rs_oc = gen2misc(dq_rdata[i].oc);
      end
    end

    // issue
    alu_issue_ready = alu_ready_i;
    mdu_issue_ready = mdu_ready_i;
    mem_issue_ready = mem_ready_i;
    misc_issue_ready = misc_ready_i;
  end

  // MISC
  OrderReservationStation #(
    .RS_SIZE(4),
    .OPTION_CODE(MiscOpCodeSt)
  ) U_MiscOrderReservationStation (
    .clk           (clk),
    .rst_n         (rst_n),
    .flush_i       (flush_i),
    .rs_base_i     (misc_rs_base),
    .option_code_i (misc_rs_oc),
    .wr_valid_i    (misc_rs_wr_valid),
    .wr_ready_o    (misc_rs_wr_ready),
    .cmt_pdest_i   (cmt_pdest_i),
    .issue_ready_i (misc_issue_ready),
    .issue_valid_o (misc_issue_valid),
    .issue_base_o  (misc_issue_base),
    .issue_oc_o    (misc_issue_oc)
  );


  // ALU * 2
  ReservationStation #(
    .RS_SIZE(8),
    .BANK_NUM(2),
    .OPTION_CODE(AluOpCodeSt)
  ) U_AluReservationStation (
    .clk           (clk),
    .a_rst_n       (a_rst_n),
    .flush_i       (flush_i),
    .rs_base_i     (alu_rs_base),
    .option_code_i (alu_rs_oc),
    .wr_valid_i    (alu_rs_wr_valid),
    .wr_ready_o    (alu_rs_wr_ready),
    .cmt_pdest_i   (cmt_pdest_i),
    .issue_ready_i (alu_issue_ready),
    .issue_valid_o (alu_issue_valid),
    .issue_base_o  (alu_issue_base),
    .issue_oc_o    (alu_issue_oc)
  );


  // MDU
  ReservationStation #(
    .RS_SIZE(4),
    .BANK_NUM(1),
    .OPTION_CODE(AluOpCodeSt)
  ) U_MduReservationStation (
    .clk           (clk),
    .a_rst_n       (a_rst_n),
    .flush_i       (flush_i),
    .rs_base_i     (mdu_rs_base),
    .option_code_i (mdu_rs_oc),
    .wr_valid_i    (mdu_rs_wr_valid),
    .wr_ready_o    (mdu_rs_wr_ready),
    .cmt_pdest_i   (cmt_pdest_i),
    .issue_ready_i (issue_ready_i),
    .issue_valid_o (issue_valid_o),
    .issue_base_o  (issue_base_o),
    .issue_oc_o    (issue_oc_o)
  );

  // Memory
  OrderReservationStation #(
    .RS_SIZE(4),
    .OPTION_CODE(MemOpCodeSt)
  ) U_MemOrderReservationStation (
    .clk           (clk),
    .rst_n         (rst_n),
    .flush_i       (flush_i),
    .rs_base_i     (mem_rs_base),
    .option_code_i (mem_rs_oc),
    .wr_valid_i    (mem_rs_wr_valid),
    .wr_ready_o    (mem_rs_wr_ready),
    .cmt_pdest_i   (cmt_pdest_i),
    .issue_ready_i (mem_issue_ready),
    .issue_valid_o (mem_issue_valid),
    .issue_base_o  (mem_issue_base),
    .issue_oc_o    (mem_issue_oc)
  );

/*================================== stage3 ===================================*/
  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      misc_issue_o <= '0;
      alu_issue_o <= '0;
      mdu_issue_o <= '0;
      mem_issue_o <= '0;
    end else begin
      misc_issue_o.valid <= misc_issue_valid;
      misc_issue_o.base_info <= misc_issue_base;
      misc_issue_o.misc_oc <= misc_issue_oc;

      alu_issue_o[0].valid <= alu_issue_valid[0];
      alu_issue_o[0].base_info <= alu_issue_base[0];
      alu_issue_o[0].alu_oc <= alu_issue_oc[0];

      alu_issue_o[1].valid <= alu_issue_valid[1];
      alu_issue_o[1].base_info <= alu_issue_base[1];
      alu_issue_o[1].alu_oc <= alu_issue_oc[1];

      mdu_issue_o.valid <= mdu_issue_valid;
      mdu_issue_o.base_info <= mdu_issue_base;
      mdu_issue_o.mdu_oc <= mdu_issue_oc;

      mem_issue_o.valid <= mem_issue_valid;
      mem_issue_o.base_info <= mem_issue_base;
      mem_issue_o.mem_oc <= mem_issue_oc;
    end
  end

endmodule : Scheduler

