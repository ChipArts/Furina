// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Scheduler.sv
// Create  : 2024-03-12 23:16:08
// Revise  : 2024-03-18 23:24:01
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
  input ROB_AllocateRspSt rob_allocate_rsp,
  input [`COMMIT_WIDTH - 1:0] freelist_free_valid_i,
  input [`COMMIT_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] released_preg_i,
  input [31:0][$clog2(`PHY_REG_NUM) - 1:0] arch_rat_i,
  input [`COMMIT_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] commited_pdest_i,
  output ScheduleRspSt schedule_rsp,
  output ROB_AllocateReqSt rob_allocate_req,

  /* issue */
  // misc(BRU/Priv) * 1
  output MiscIssueInfoSt misc_issue_info_o,
  input logic misc_ready_i,
  // ALU * 2
  output AluIssueInfoSt alu_issue_info_o,
  input logic [1:0] alu_ready_i,
  // memory * 1
  output MemoryIssueInfoSt mem_issue_info_o,
  input logic mem_ready_i
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

  /* ready signal define */
  logic s0_ready, s1_ready;

  /* stage 0 */
  // 接收inst信息

  logic freelist_alloc_ready;
  logic [`DECODE_WIDTH - 1:0] freelist_alloc_valid;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] allocated_preg;

  always_comb begin
    s0_ready = s1_ready & freelist_alloc_ready;

    schedule_rsp.ready = s0_ready;

    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      freelist_alloc_valid[i] = schedule_req.valid[i] & schedule_req.dest_valid[i] & s1_ready;
    end
  end

  // FreeList输出是一个ff
  FreeList #(
    .PHY_REG_NUM(`PHY_REG_NUM)
  ) inst_FreeList (
    .clk           (clk),
    .a_rst_n       (rst_n),
    .flush_i       (flush_i),
    .alloc_valid_i (freelist_alloc_valid),
    .alloc_ready_o (freelist_alloc_ready),
    .free_valid_i  (freelist_free_valid_i),
    .free_ready_o  (/* not used */),
    .free_preg_i   (released_preg_i),
    .preg_o        (allocated_preg)
  );

  /* stage 1 */
  // 缓存指令和解码信息
  logic [`DECODE_WIDTH - 1:0] s1_valid;
  OptionCodeSt [`DECODE_WIDTH - 1:0] s1_option_code;
  logic [`DECODE_WIDTH - 1:0][`PROC_VALEN:0] s1_vaddr;
  logic [`DECODE_WIDTH - 1:0][31:0] s1_imm;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] s1_src0, s1_src1, s1_dest;
  logic [`DECODE_WIDTH - 1:0] s1_src0_valid, s1_src1_valid, s1_dest_valid;

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
    end else begin
      if (s1_ready) begin
        s1_valid <= schedule_req.valid;
        s1_option_code <= schedule_req.option_code;
        s1_vaddr <= schedule_req.vaddr;
        s1_imm <= schedule_req.imm;
        s1_src0 <= schedule_req.src0;
        s1_src1 <= schedule_req.src1;
        s1_dest <= schedule_req.dest;
        s1_src0_valid <= schedule_req.src0_valid;
        s1_src1_valid <= schedule_req.src1_valid;
        s1_dest_valid <= schedule_req.dest_valid;
      end
    end
  end
  // 重命名
  // 分发指令到各自的分发队列
  // 写入ROB

  logic [`DECODE_WIDTH - 1:0] rat_valid;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] rat_psrc0, rat_psrc1, rat_ppdst;

  logic rs_write_ready;

  always_comb begin
    // 本级FU：ROB，RAT
    s1_ready = (rob_allocate_rsp.ready & rs_write_ready) |
                ~|s1_valid;

    // RAT ROB 控制逻辑
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      freelist_alloc_valid[i] = s1_valid[i] & s1_dest[i];
      rat_valid[i] = s1_valid[i] & s1_dest[i];
    end

    rob_allocate_req.valid = s1_valid;
    rob_allocate_req.ready = s1_ready;
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      rob_allocate_req.rob_entry[i].complete = '0;
      rob_allocate_req.rob_entry[i].arch_reg = s1_dest[i];
      rob_allocate_req.rob_entry[i].phy_reg = allocated_preg[i];
      rob_allocate_req.rob_entry[i].old_phy_reg = rat_ppdst[i];
      rob_allocate_req.rob_entry[i].pc = s1_vaddr[i];
      rob_allocate_req.rob_entry[i].exception = '0;
      rob_allocate_req.rob_entry[i].inst_type = s1_general_ctrl_signal[i].inst_type;
    end
  end

  RegisterAliasTable #(
    .PHYS_REG_NUM(`PHY_REG_NUM)
  ) U_IntegerRegisterAliasTable (
    .clk         (clk),
    .a_rst_n     (rst_n),
    .restore_i   (flush_i),
    .allocaion_i ('0),
    .free_i      (/* TODO: checkpoint */),
    .arch_rat    (arch_rat_i),
    // 查询
    .valid_i     (rat_valid),
    .src0_i      (s1_src0),
    .src1_i      (s1_src1),
    .dest_i      (s1_dest),
    .preg_i      (allocated_preg),
    // 输出
    .psrc0_o     (rat_psrc0),
    .psrc1_o     (rat_psrc1),
    .ppdst_o     (rat_ppdst)
  );

  RS_EntrySt [`DECODE_WIDTH - 1:0] rs_entry;
  always_comb begin
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      rs_entry[i].valid = s1_valid[i];
      rs_entry[i].psrc0 = rat_psrc0[i];
      rs_entry[i].psrc1 = rat_psrc1[i];
      rs_entry[i].psrc0_valid = s1_src0_valid[i];
      rs_entry[i].psrc1_valid = s1_src1_valid[i];
      rs_entry[i].psrc0_ready = '0;
      rs_entry[i].psrc1_ready = '0;
      rs_entry[i].position_bit = rob_allocate_rsp.position_bit[i];
      rs_entry[i].rob_idx = rob_allocate_rsp.rob_idx[i];
      rs_entry[i].imm = s1_imm[i];
      rs_entry[i].option_code = s1_option_code[i];
    end
  end


  // misc(BRU/Priv) * 1
  logic rs_misc_valid_o;
  logic [31:0] rs_misc_imm_o;
  logic [$clog2(`PHY_REG_NUM) - 1:0] rs_misc_psrc0_o, rs_misc_psrc1_o;
  MiscOptionCodeSt rs_misc_option_code_o;
  // ALU * 2
  logic [1:0] rs_alu_valid_o;
  logic [1:0][31:0] rs_alu_imm_o;
  logic [1:0][$clog2(`PHY_REG_NUM) - 1:0] rs_alu_psrc0_o, rs_alu_psrc1_o;
  AluOptionCodeSt [1:0] rs_alu_option_code_o;
  // memory * 1
  logic rs_mem_valid_o;
  logic [31:0] rs_mem_imm_o;
  logic [$clog2(`PHY_REG_NUM) - 1:0] rs_mem_psrc0_o, rs_mem_psrc1_o;
  MemoryOptionCodeSt rs_mem_option_code_o;

  ReservationStation U_ReservationStation
  (
    .clk                (clk),
    .a_rst_n            (rst_n),
    .flush_i            (flush_i),
    .rs_entry_i         (rs_entry),
    .write_valid_i      (s1_valid),
    .write_ready_o      (rs_write_ready),
    .commited_pdest_i   (commited_pdest_i),
    // issue comb输出
    .misc_valid_o       (rs_misc_valid_o),
    .misc_ready_i       (misc_ready_i),
    .misc_psrc0_o       (rs_misc_psrc0_o),
    .misc_psrc1_o       (rs_misc_psrc1_o),
    .misc_option_code_o (rs_misc_option_code_o),
    .alu_valid_o        (rs_alu_valid_o),
    .alu_ready_i        (alu_ready_i),
    .alu_psrc0_o        (rs_alu_psrc0_o),
    .alu_psrc1_o        (rs_alu_psrc1_o),
    .alu_option_code_o  (rs_alu_option_code_o),
    .mem_valid_o        (rs_mem_valid_o),
    .mem_ready_i        (mem_ready_i),
    .mem_psrc0_o        (rs_mem_psrc0_o),
    .mem_psrc1_o        (rs_mem_psrc1_o),
    .mem_option_code_o  (rs_mem_option_code_o)
  );

  // 保留站输出打一拍




endmodule : Scheduler

