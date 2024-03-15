// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Scheduler.sv
// Create  : 2024-03-12 23:16:08
// Revise  : 2024-03-15 18:28:29
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
`include "ReorderBuffer.svh"

module Scheduler (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input logic flush_i,
  input ScheduleReqSt schedule_req,
  input ROB_DispatchRspSt rob_dispatch_rsp,
  output ScheduleRspSt schedule_rsp,
  output ROB_DispatchReqSt rob_dispatch_req
);
  `RESET_LOGIC(clk, a_rst_n, rst_n);

  /* ready signal define */
  // stage 0
  logic s0_ready;
  // stage 1
  logic s1_ready;
  // stage 2

  // 计算一条指令之前的int/mem指令数量
  logic [`DECODE_WIDTH - 1:0][$clog2(`DECODE_WIDTH) - 1:0] pre_int_inst_num, pre_mem_inst_num;
  // stage 2

  /* stage 0 */
  // 接收inst信息
  always_comb begin
    s0_ready = s1_ready;

    schedule_rsp.valid = '1;
    schedule_rsp.ready = s0_ready;
  end

  /* stage 1 */
  // 缓存指令和解码信息
  logic [`DECODE_WIDTH - 1:0] s1_valid;
  GeneralCtrlSignalSt [`DECODE_WIDTH - 1:0] s1_general_ctrl_signal;
  logic [`DECODE_WIDTH - 1:0][`PROC_VALEN:0] s1_vaddr;
  logic [`DECODE_WIDTH - 1:0][25:0] s1_operand;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] s1_src0, s1_src1, s1_dest;

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n || flush_i) begin
      s1_valid <= '0;
      s1_general_ctrl_signal <= '0;
      s1_vaddr <= '0;
      s1_operand <= '0;
      s1_src0 <= '0;
      s1_src1 <= '0;
      s1_dest <= '0;
    end else begin
      if (s1_ready) begin
        s1_valid <= schedule_req.valid;
        s1_general_ctrl_signal <= schedule_req.general_ctrl_signal;
        s1_vaddr <= schedule_req.vaddr;
        s1_operand <= schedule_req.operand;
        s1_src0 <= schedule_req.src0;
        s1_src1 <= schedule_req.src1;
        s1_dest <= schedule_req.dest;
      end
    end
  end
  // 重命名
  // 分发指令到各自的分发队列
  // 写入ROB

  logic freelist_empty;
  logic [`DECODE_WIDTH - 1:0] freelist_alloc_req;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] freelist_preg;

  logic [`DECODE_WIDTH - 1:0] rat_valid;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] rat_psrc0, rat_psrc1, rat_ppdst;

  // int_dispatch_queue --> idq
  // memory_dispatch_queue --> mdq
  logic [`DECODE_WIDTH - 1:0] idq_write_valid, mdq_write_valid;
  logic [3:0] idq_read_valid, mdq_read_valid, idq_read_ready, mdq_read_ready;
  logic idq_write_ready, mdq_write_ready;
  IntegerDispatchQueueEntrySt[`DECODE_WIDTH - 1:0] idq_write_data, idq_read_data;
  MemoryDispatchQueueEntrySt[`DECODE_WIDTH - 1:0] mdq_write_data, mdq_read_data;

  always_comb begin
    // 本级FU：ROB，FreeList，RAT，DispatchQueue
    s1_ready = (rob_dispatch_rsp.ready & ~freelist_empty & 
                idq_write_ready & mdq_write_ready) | 
                ~|s1_valid;

    // FreeList RAT ROB 控制逻辑
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      freelist_alloc_req[i] = s1_valid[i];
      rat_valid[i] = s1_valid[i] & s1_general_ctrl_signal[i].reg_valid[0];
    end

    // 第一级指令分发逻辑
    pre_int_inst_num[0] = '0;
    pre_mem_inst_num[0] = '0;

    for (int i = 1; i < `DECODE_WIDTH; i++) begin
      // ALU_INST BRANCH_INST PRIV_INST
      pre_int_inst_num[i] = pre_int_inst_num[i - 1] + 
                           (s1_general_ctrl_signal[i - 1].inst_type < `MEMORY_INST);  

      pre_mem_inst_num[i] = pre_mem_inst_num[i - 1] + 
                           (s1_general_ctrl_signal[i - 1].inst_type == `MEMORY_INST);
    end

    idq_write_valid = '0;
    mdq_write_valid = '0;
    idq_write_data = '0;
    mdq_write_data = '0;
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      for (int j = i; j < `DECODE_WIDTH; j++) begin
        // 从DECODE_WIDTH个里面选第i个符合条件的项
        if (s1_general_ctrl_signal[j].inst_type  < `MEMORY_INST && pre_int_inst_num[j] == i) begin
          idq_write_valid[i] = '1;
          idq_write_data[i].vaddr = s1_vaddr[j];
          idq_write_data[i].operand = s1_operand[j];
          idq_write_data[i].psrc0 = s1_src0[j];
          idq_write_data[i].psrc1 = s1_src1[j];
          idq_write_data[i].pdest = s1_dest[j];
          idq_write_data[i].rob_idx = rob_dispatch_rsp.rob_idx[j];
          idq_write_data[i].int_ctrl_signal = s1_general_ctrl_signal[j].int_ctrl_signal;
        end
        if (s1_general_ctrl_signal[j].inst_type == `MEMORY_INST && pre_mem_inst_num[j] == i) begin
          mdq_write_valid[i] = '1;
          mdq_write_data[i].vaddr = s1_vaddr[j];
          mdq_write_data[i].operand = s1_operand[j];
          mdq_write_data[i].src0 = s1_src0[j];
          mdq_write_data[i].src1 = s1_src1[j];
          mdq_write_data[i].dest = s1_dest[j];
          mdq_write_data[i].rob_idx = rob_dispatch_rsp.rob_idx[j];
          mdq_write_data[i].mem_ctrl_signal = s1_general_ctrl_signal[j].mem_ctrl_signal;
        end
      end
    end
  end

  // TODO: 重构FreeList
  FreeList #(
    .PHY_REG_NUM(`PHY_REG_NUM)
  ) inst_FreeList (
    .clk         (clk),
    .a_rst_n     (rst_n),
    .flush_i     (flush_i),
    .alloc_req_i (freelist_alloc_req),
    .free_req_i  (/* TODO: retire */),
    .free_preg_i (free_preg_i),
    .empty_o     (int_freelist_empty),
    .full_o      (/* not used */),
    .preg_o      (int_freelist_preg)
  );


  RegisterAliasTable #(
    .PHYS_REG_NUM(`PHY_REG_NUM)
  ) U_IntegerRegisterAliasTable (
    .clk         (clk),
    .a_rst_n     (rst_n),
    .restore_i   (flush_i),
    .allocaion_i ('0),
    .free_i      (/* TODO: retire */),
    .arch_rat    (/* TODO: retire */),
    // 查询
    .valid_i     (rat_valid),
    .src0_i      (s1_src0),
    .src1_i      (s1_src1),
    .dest_i      (s1_dest),
    .preg_i      (freelist_preg),
    // 输出
    .psrc0_o     (s1_psrc0),
    .psrc1_o     (s1_psrc1),
    .ppdst_o     (s1_ppdst)
  );

  // 分为整数和访存两个队列
  // 特权、分支指令往往与整数指令紧密相关，因此也归为整数指令
  SyncMultiChannelFIFO #(
    .FIFO_DEPTH(8),
    .DATA_WIDTH($bits(IntegerDispatchQueueEntrySt)),
    .RPORTS_NUM(4),
    .WPORTS_NUM(`DECODE_WIDTH),
    .FIFO_MEMORY_TYPE("auto")
  ) U_IntegerDispatchQueue (
    .clk           (clk),
    .a_rst_n       (a_rst_n),
    .flush_i       (flush_i),
    .write_valid_i (idq_write_valid),
    .write_ready_o (idq_write_ready),
    .write_data_i  (idq_write_data),
    .read_valid_o  (idq_read_valid),
    .read_ready_i  (idq_read_ready),
    .read_data_o   (idq_read_data)
  );

  SyncMultiChannelFIFO #(
    .FIFO_DEPTH(8),
    .DATA_WIDTH($bits(MemoryDispatchQueueEntrySt)),
    .RPORTS_NUM(4),
    .WPORTS_NUM(`DECODE_WIDTH),
    .FIFO_MEMORY_TYPE("auto")
  ) U_MemoryDispatchQueue (
    .clk           (clk),
    .a_rst_n       (rst_n),
    .flush_i       (flush_i),
    .write_valid_i (mdq_write_valid),
    .write_ready_o (mdq_write_ready),
    .write_data_i  (mdq_write_data),
    .read_valid_o  (mdq_read_valid),
    .read_ready_i  (mdq_read_ready),
    .read_data_o   (mdq_read_data)
  );



  /* stage 2 */
  // 写入发射队列

  // 分发整数指令
  logic [4:0] idq_dispatched;  // idq的可被IQ接收的指令的标记
  logic [3:0][1:0] pre_alu_inst_num, pre_mdu_inst_num, pre_msic_inst_num;
  logic [3:0] alu_iq_write_valid, alu_iq_write_ready;
  logic [3:0][1:0] pre_alu_iq_ready_port_num;
  logic [1:0] mdu_iq_write_valid, mdu_iq_write_ready;
  logic msic_iq_write_valid, msic_iq_write_ready;
  ALU_IssueQueueEntrySt [3:0] alu_iq_write_data;
  MDU_IssueQueueEntrySt [1:0] mdu_iq_write_data;
  MISC_IssueQueueEntrySt msic_iq_write_data;

  always_comb begin
    pre_alu_inst_num[0] = '0;
    pre_mdu_inst_num[0] = '0;
    pre_msic_inst_num[0] = '0;

    for (int i = 1; i < 4; i++) begin
      pre_alu_inst_num[i] = pre_alu_inst_num[i - 1] + 
                           (idq_read_data[i].int_ctrl_signal.inst_type == `ALU_INST);
      pre_mdu_inst_num[i] = pre_mdu_inst_num[i - 1] + 
                           (idq_read_data[i].int_ctrl_signal.inst_type == `MDU_INST);
      pre_msic_inst_num[i] = pre_msic_inst_num[i - 1] + 
                           (idq_read_data[i].int_ctrl_signal.inst_type == `BRANCH_INST | 
                            idq_read_data[i].int_ctrl_signal.priv_ctrl_signal == `PRIV_INST);
    end

    // 判断一条指令是否会被派遣
    idq_issued[0] = 

    // alu分发
    // 尽可能的多发
    pre_alu_iq_ready_port_num = '0;
    for (int i = 1; i < 4; i++) begin
      pre_alu_iq_ready_port_num[i] = pre_alu_iq_ready_port_num[i - 1] + alu_iq_write_valid[i];
    end

    alu_iq_write_valid = '0;
    for (int i = 0; i < 4; i++) begin
      for (int j = i; j < 4; j++) begin
        if (alu_iq_write_ready[i] && 
            pre_alu_iq_ready_port_num[i] == pre_alu_inst_num[j] &&
            idq_read_data[j].inst_type == `ALU_INST) begin
          alu_iq_write_valid[i] = idq_read_valid[j] & (j == 0 | idq_issued[j - 1]);
          alu_iq_write_data[i].vaddr = idq_read_data[j].vaddr;
          alu_iq_write_data[i].operand = idq_read_data[j].operand;
          alu_iq_write_data[i].rob_idx = idq_read_data[j].rob_idx;
          alu_iq_write_data[i].psrc0 = idq_read_data[j].psrc0;
          alu_iq_write_data[i].psrc1 = idq_read_data[j].psrc1;
          alu_iq_write_data[i].pdest = idq_read_data[j].pdest;
          alu_iq_write_data[i].alu_ctrl_signal = idq_read_data[j].int_ctrl_signal.alu_ctrl_signal;
        end
      end
    end
  end

  // alu0, alu1 
  IssueQueue #(  
    .QUEUE_SIZE(8),
    .WPORTS_NUM(2),
    .RPORTS_NUM(2),
    .DATA_TYPE(ALU_IssueQueueEntrySt),
    .ORDER_ISSUE(0)
  ) U0_ALU_IssueQueue (
    .clk           (clk),
    .a_rst_n       (a_rst_n),
    .flush_i       (flush_i),
    .write_valid_i (write_valid_i),
    .write_ready_o (write_ready_o),
    .write_data_i  (write_data_i),
    .read_valid_o  (),
    .read_ready_i  (),
    .read_data_o   ()
  );

  // alu2, alu3
  IssueQueue #(
    .QUEUE_SIZE(8),
    .WPORTS_NUM(2),
    .RPORTS_NUM(2),
    .DATA_TYPE(ALU_IssueQueueEntrySt),
    .ORDER_ISSUE(0)
  ) U1_ALU_IssueQueue (
    .clk           (clk),
    .a_rst_n       (a_rst_n),
    .flush_i       (flush_i),
    .write_valid_i (write_valid_i),
    .write_ready_o (write_ready_o),
    .write_data_i  (write_data_i),
    .read_valid_o  (),
    .read_ready_i  (),
    .read_num_i    (),
    .read_data_o   ()
  );

  IssueQueue #(
    .QUEUE_SIZE(8),
    .WPORTS_NUM(2),
    .RPORTS_NUM(2),
    .DATA_TYPE(MDU_IssueQueueEntrySt),
    .ORDER_ISSUE(0)
  ) U_MDU_IssueQueue (
    .clk           (clk),
    .a_rst_n       (a_rst_n),
    .flush_i       (flush_i),
    .write_valid_i (write_valid_i),
    .write_ready_o (write_ready_o),
    .write_data_i  (write_data_i),
    .read_valid_o  (),
    .read_ready_i  (),
    .read_data_o   ()
  );

  IssueQueue #(
    .QUEUE_SIZE(8),
    .WPORTS_NUM(1),
    .RPORTS_NUM(1),
    .DATA_TYPE(MISC_IssueQueueEntrySt),
    .ORDER_ISSUE(1)  // 特权和分支指令顺序执行
  ) U_MSIC_IssueQueue (
    .clk           (clk),
    .a_rst_n       (a_rst_n),
    .flush_i       (flush_i),
    .write_valid_i (write_valid_i),
    .write_ready_o (write_ready_o),
    .write_data_i  (write_data_i),
    .read_valid_o  (),
    .read_ready_i  (),
    .read_data_o   ()
  );

  // mem


endmodule : Scheduler

