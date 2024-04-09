// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Scheduler.sv
// Create  : 2024-03-12 23:16:08
// Revise  : 2024-04-02 16:33:50
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
  input [`COMMIT_WIDTH - 1:0] fl_free_valid_i,
  input [`COMMIT_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] fl_free_preg_i,
  // rat
  input [31:0][$clog2(`PHY_REG_NUM) - 1:0] arch_rat_i,
  // wake up
  input logic [`WB_WIDTH - 1:0] wb_pdest_valid_i,
  input [`WB_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] wb_pdest_i,

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
      fl_alloc_valid[i] =  schedule_req.valid[i] &
                          |schedule_req.arch_dest[i] &  // dest valid
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
  ScheduleReqSt s1_sche_req;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] s1_fl_alloc_preg;

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n || flush_i) begin
      s1_sche_req <= '0;
      s1_fl_alloc_preg <= '0;
    end else begin
      if (s1_ready) begin
        s1_sche_req <= schedule_req;
        s1_fl_alloc_preg <= fl_alloc_preg;
      end
    end
  end


  // 重命名
  logic dq_write_ready;
  logic [`DECODE_WIDTH - 1:0] rat_dest_valid;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] rat_psrc0;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] rat_psrc1;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] rat_ppdst;

  logic [`DECODE_WIDTH - 1:0] dq_write_valid;
  DqEntrySt [`DECODE_WIDTH - 1:0] dq_wdata;

  logic [`DECODE_WIDTH - 1:0] dq_read_valid;
  logic [`DECODE_WIDTH - 1:0] dq_read_ready;
  DqEntrySt [`DECODE_WIDTH - 1:0] dq_rdata;

  always_comb begin
    s1_ready = (rob_alloc_rsp.ready & dq_write_ready) | ~(|s1_sche_req.valid);
    // RAT 控制逻辑
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      rat_dest_valid[i] = s1_sche_req.valid[i] & |s1_sche_req.arch_dest[i];
    end

    // 写入ROB
    rob_alloc_req.valid = s1_sche_req.valid;
    rob_alloc_req.ready = s1_ready;
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      rob_alloc_req.valid[i] = s1_sche_req.valid[i];
      rob_alloc_req.pc[i] = s1_sche_req.pc[i];
      rob_alloc_req.instr_type[i] = s1_sche_req.instr_type[i];
      rob_alloc_req.arch_reg[i] = s1_sche_req.arch_dest[i];
`ifdef DEBUG
      rob_alloc_req.rob_entry[i].instr = s1_sche_req.option_code[i].debug_inst;
`endif
    end

    // 写入分发队列
    dq_write_valid = s1_sche_req.valid;
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      dq_wdata[i].valid = s1_sche_req.valid[i];
      dq_wdata[i].pc = s1_sche_req.pc[i];
      dq_wdata[i].npc = s1_sche_req.npc[i];
      dq_wdata[i].src = s1_sche_req.src[i];
      dq_wdata[i].src0_valid = s1_sche_req.arch_src0[i] != 5'b0;
      dq_wdata[i].src1_valid = s1_sche_req.arch_src1[i] != 5'b0;
      dq_wdata[i].dest_valid = s1_sche_req.arch_dest[i] != 5'b0;
      dq_wdata[i].src0 = rat_psrc0[i];
      dq_wdata[i].src1 = rat_psrc1[i];
      dq_wdata[i].dest = s1_fl_alloc_preg[i];
      dq_wdata[i].oc = s1_sche_req.option_code[i];
      dq_wdata[i].position_bit = rob_alloc_rsp.position_bit[i];
      dq_wdata[i].rob_idx = rob_alloc_rsp.rob_idx[i];
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
    .src0_i      (s1_sche_req.arch_src0[i]),
    .src1_i      (s1_sche_req.arch_src1[i]),
    .dest_i      (s1_sche_req.arch_dest[i]),
    .preg_i      (s1_fl_alloc_preg),
    // 输出(comb)
    .psrc0_o     (rat_psrc0),
    .psrc1_o     (rat_psrc1),
    .ppdst_o     (rat_ppdst)
  );

  SyncMultiChannelFIFO #(
    .FIFO_DEPTH(16),
    .DATA_WIDTH($bits(DqEntrySt)),
    .RPORTS_NUM(`DISPATCH_WIDTH),
    .WPORTS_NUM(`DECODE_WIDTH),
    .FIFO_MEMORY_TYPE("auto")
  ) inst_DispatchQueue (
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
  // 记录[i]之前对应类型指令的数量
  logic [`DISPATCH_WIDTH - 1:0][$clog2(`DISPATCH_WIDTH) - 1:0] alu_cnt;
  logic [`DISPATCH_WIDTH - 1:0][$clog2(`DISPATCH_WIDTH) - 1:0] mdu_cnt;
  logic [`DISPATCH_WIDTH - 1:0][$clog2(`DISPATCH_WIDTH) - 1:0] misc_cnt;
  logic [`DISPATCH_WIDTH - 1:0][$clog2(`DISPATCH_WIDTH) - 1:0] mem_cnt;  
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
    alu_cnt = '0;
    misc_cnt = '0;
    mem_cnt = '0;

    for (int i = 1; i < `DISPATCH_WIDTH; i++) begin
      if (dq_rdata[i - 1].oc.instr_type == `ALU_INSTR) begin
        alu_cnt[i] = alu_cnt[i - 1] + 1;
      end
      if (dq_rdata[i - 1].oc.instr_type == `MDU_INSTR) begin
        mdu_cnt[i] = mdu_cnt[i - 1] + 1;
      end
      if (dq_rdata[i - 1].oc.instr_type == `MEM_INSTR) begin
        mem_cnt[i] = mem_cnt[i - 1] + 1;
      end
      if (dq_rdata[i - 1].oc.instr_type inside {`PRIV_INSTR, `BR_INSTR}) begin
        misc_cnt[i] = misc_cnt[i - 1] + 1;
      end
    end

    // 判断是否可以分发
    if (dq_rdata[0].valid) begin
        case (dq_rdata[0].oc.instr_type)
          `ALU_INSTR : dq_read_ready[0] = alu_cnt[0] < $countones(alu_rs_wr_ready);
          `MDU_INSTR : dq_read_ready[0] = mdu_cnt[0] < $countones(mdu_rs_wr_ready);
          `MEM_INSTR : dq_read_ready[0] = mem_cnt[0] < $countones(mem_rs_wr_ready);
          `PRIV_INSTR, `BR_INSTR : dq_read_ready[0] = misc_cnt[0] < $countones(misc_rs_wr_ready);
          default : dq_read_ready[0] = '0;
        endcase
    end
    for (int i = 1; i < `DISPATCH_WIDTH; i++) begin
      if (dq_rdata[i].valid) begin
        case (dq_rdata[i].oc.instr_type)
          `ALU_INSTR : dq_read_ready[i] = alu_cnt[i] < $countones(alu_rs_wr_ready) & dq_read_ready[i - 1];
          `MDU_INSTR : dq_read_ready[i] = mdu_cnt[i] < $countones(mdu_rs_wr_ready) & dq_read_ready[i - 1];
          `MEM_INSTR : dq_read_ready[i] = mem_cnt[i] < $countones(mem_rs_wr_ready) & dq_read_ready[i - 1];
          `PRIV_INSTR, `BR_INSTR : dq_read_ready[i] = misc_cnt[i] < $countones(misc_rs_wr_ready) & dq_read_ready[i - 1];
          default : dq_read_ready[i] = '0;
        endcase
      end
    end

    // 写入发射队列
    dispatched = '0;
    for (int i = 0; i < `DISPATCH_WIDTH; i++) begin
      if (dq_rdata[i].oc.instr_type == `ALU_INSTR && alu_cnt[i] == 0) begin
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
      if (dq_rdata[i].oc.instr_type == `ALU_INSTR && alu_cnt[i] == 1) begin
        alu_rs_wr_valid[1] = dq_read_ready[i];
        alu_rs_base[1] = dq2rs(dq_rdata[i]);
        alu_rs_oc[1] = gen2alu(dq_rdata[i].oc);
      end
      if (dq_rdata[i].oc.instr_type == `MEM_INSTR && mem_cnt[i] == 0) begin
        mem_rs_wr_valid = dq_read_ready[i];
        mem_rs_base = dq2rs(dq_rdata[i]);
        mem_rs_oc = gen2mem(dq_rdata[i].oc);
      end
      if (dq_rdata[i].oc.instr_type == `MDU_INSTR && mdu_cnt[i] == 0) begin
        mdu_rs_wr_valid = dq_read_ready[i];
        mdu_rs_base = dq2rs(dq_rdata[i]);
        mdu_rs_oc = gen2mdu(dq_rdata[i].oc);
      end
      if ((dq_rdata[i].oc.instr_type == `PRIV_INSTR || 
           dq_rdata[i].oc.instr_type == `BR_INSTR) &&
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
    .wb_pdest_i   (wb_pdest_i),
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
    .wb_pdest_i   (wb_pdest_i),
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
    .wb_pdest_i   (wb_pdest_i),
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
    .wb_pdest_i   (wb_pdest_i),
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

