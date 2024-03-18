// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : ReservationStation.sv
// Create  : 2024-03-13 23:33:22
// Revise  : 2024-03-13 23:33:35
// Description :
//   保留站(非压缩)
//   RS面对的FU必须相同
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
`include "Scheduler.svh"
`include "Decoder.svh"

module ReservationStation (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input logic flush_i,

  /* dispatch */
  input RS_EntrySt [`DECODE_WIDTH - 1:0] rs_entry_i,
  input logic [`DECODE_WIDTH - 1:0] write_valid_i,
  output logic write_ready_o,

  /* wake up */
  input logic [`COMMIT_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] commited_pdest_i,

  /* issue */
  // misc(BRU/Priv) * 1
  output MiscIssueInfoSt misc_issue_info_o,
  input logic misc_ready_i,
  // ALU * 2
  output AluIssueInfoSt [1:0] alu_issue_info_o,
  input logic [1:0] alu_ready_i,
  // memory * 1
  output MemoryIssueInfoSt mem_issue_info_o,
  input logic mem_ready_i
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

`ifdef DEBUG
  initial begin
    assert (`RS_SIZE % `DECODE_WIDTH == 0) else $error("RS_SIZE must be multiple of `DECODE_WIDTH");
  end
`endif

  /* Memory */
  // 分为`DECODE_WIDTH个bank，减小组合逻辑压力
  localparam BANK_SIZE = `RS_SIZE / `DECODE_WIDTH;
  RS_EntrySt [`DECODE_WIDTH - 1:0][BANK_SIZE - 1:0] rs_mem, rs_mem_n;
  logic round_robin;  // 轮转算法
  logic [`DECODE_WIDTH - 1:0][BANK_SIZE - 1:0] alu_dispatch_state, alu_dispatch_state_n;  // ALU调度状态

  /* logic */
  logic [`DECODE_WIDTH - 1:0] bank_free;
  logic [`DECODE_WIDTH - 1:0][$clog2(BANK_SIZE) - 1:0] bank_write_idx;

  // issue: oldest first
  logic [1:0] alu_position_bit;
  logic misc_position_bit, mem_position_bit;
  logic [$clog2(`ROB_DEPTH) - 1:0] misc_rob_idx, mem_rob_idx;
  logic [1:0][$clog2(`ROB_DEPTH) - 1:0] alu_rob_idx;

  logic [1:0][$clog2(`DECODE_WIDTH) - 1:0] alu_issue_i_idx;
  logic [1:0][$clog2(BANK_SIZE) - 1:0] alu_issue_j_idx;
  logic [$clog2(`DECODE_WIDTH) - 1:0] misc_issue_i_idx, mem_issue_i_idx;
  logic [$clog2(BANK_SIZE) - 1:0] misc_issue_j_idx, mem_issue_j_idx;

  always_comb begin
    bank_free = '0;
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      for (int j = 0; j < BANK_SIZE; j++) begin
        bank_free[i] |= ~rs_mem[i][j].valid | rs_mem[i][j].issued;
      end
    end

    write_ready_o = &bank_free;

    alu_dispatch_state_n = alu_dispatch_state;
    // write logic
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      // 选择bank的写入位置
      for (int j = 0; j < BANK_SIZE; j++) begin
        if (~rs_mem[i][j].valid || rs_mem[i][j].issued) begin
          bank_write_idx[i] = j;
        end
      end
      if (write_ready_o && write_valid_i[i]) begin
        rs_mem_n[i][bank_write_idx[i]] = rs_entry_i[i];
        alu_dispatch_state_n[i][bank_write_idx[i]] = round_robin;
      end
    end

    // wake up logic
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      for (int j = 0; j < BANK_SIZE; j++) begin
        for (int k = 0; k < `COMMIT_WIDTH; k++) begin
          if (rs_mem[i][j].valid &&
              rs_mem[i][j].psrc0 == commited_pdest_i[k]) begin
              rs_mem_n[i][j].psrc0_ready = '1;
          end
          if (rs_mem[i][j].valid &&
              rs_mem[i][j].psrc1 == commited_pdest_i[k]) begin
              rs_mem_n[i][j].psrc1_ready = '1;
          end
        end
      end
    end

    // select logic
    misc_issue_info_o.valid = 
                   (rs_mem[0][0].valid & ~rs_mem[0][0].issued &
                    (rs_mem[0][0].option_code.inst_type == `BRANCH_INST |
                     rs_mem[0][0].option_code.inst_type == `PRIV_INST)) &
                   (rs_mem[0][0].psrc0_ready | ~rs_mem[0][0].psrc0_valid) &
                   (rs_mem[0][0].psrc1_ready | ~rs_mem[0][0].psrc1_valid);
    misc_position_bit = rs_mem[0][0].position_bit;
    misc_rob_idx = rs_mem[0][0].rob_idx;
    for (int i = 0; i < 2; i++) begin
      alu_issue_info_o[i].valid =
              (rs_mem[0][0].valid & ~rs_mem[0][0].issued &
               rs_mem[0][0].option_code.inst_type == `ALU_INST) &
              (rs_mem[0][0].psrc0_ready | ~rs_mem[0][0].psrc0_valid) &
              (rs_mem[0][0].psrc1_ready | ~rs_mem[0][0].psrc1_valid) & 
               alu_dispatch_state[0][0] == i;
      alu_position_bit[i] = rs_mem[0][0].position_bit;
      alu_rob_idx[i] = rs_mem[0][0].rob_idx;
    end
    mem_issue_info_o.base_info.valid = 
                  (rs_mem[0][0].valid & ~rs_mem[0][0].issued &
                   rs_mem[0][0].option_code.inst_type == `MEMORY_INST) &
                  (rs_mem[0][0].psrc0_ready | ~rs_mem[0][0].psrc0_valid) &
                  (rs_mem[0][0].psrc1_ready | ~rs_mem[0][0].psrc1_valid);
    mem_position_bit = rs_mem[0][0].position_bit;
    mem_rob_idx = rs_mem[0][0].rob_idx;
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      for (int j = 0; j < BANK_SIZE; j++) begin
        // misc: 顺序执行
        // 是一条misc指令
        if (rs_mem[i][j].valid && !rs_mem[i][j].issued &&
           (rs_mem[i][j].option_code.inst_type == `BRANCH_INST ||
            rs_mem[i][j].option_code.inst_type == `PRIV_INST)) begin
          // 是一条更老的misc指令
          if ((rs_mem[i][j].position_bit == misc_position_bit &&
               rs_mem[i][j].rob_idx > misc_rob_idx) || 
              (rs_mem[i][j].position_bit != misc_position_bit &&
               rs_mem[i][j].rob_idx < misc_position_bit)) begin
            misc_issue_info_o.valid = 
                           (rs_mem[i][j].psrc0_ready | ~rs_mem[i][j].psrc0_valid) &
                           (rs_mem[i][j].psrc1_ready | ~rs_mem[i][j].psrc1_valid);
            misc_issue_info_o.option_code = gen2misc(rs_mem[i][j].option_code);
            misc_issue_info_o.base_info.psrc0 = rs_mem[i][j].psrc0;
            misc_issue_info_o.base_info.psrc1 = rs_mem[i][j].psrc1;
            misc_issue_info_o.base_info.pdest = rs_mem[i][j].pdest;
            misc_issue_info_o.base_info.imm   = rs_mem[i][j].imm;
            misc_issue_info_o.base_info.pdest_valid = rs_mem[i][j].pdest_valid;

            // 更新最老的misc指令
            misc_position_bit = rs_mem[i][j].position_bit;
            misc_rob_idx = rs_mem[i][j].rob_idx;
            misc_issue_i_idx = i;
            misc_issue_j_idx = j;
          end
        end
        // alu: 乱序执行
        for (int k = 0; k < 2; k++) begin
          // 是一条可发射的alu指令
          if (rs_mem[i][j].valid && !rs_mem[i][j].issued &&
              rs_mem[i][j].option_code.inst_type == `ALU_INST &&
             (rs_mem[i][j].psrc0_ready || ~rs_mem[i][j].psrc0_valid) &&
             (rs_mem[i][j].psrc1_ready || ~rs_mem[i][j].psrc1_valid) &&
              alu_dispatch_state[i][j] == k) begin
            // 是一条更老的alu指令
            if ((rs_mem[i][j].position_bit == alu_position_bit[k] &&
                 rs_mem[i][j].rob_idx > alu_rob_idx[k]) || 
                (rs_mem[i][j].position_bit != alu_position_bit[k] &&
                 rs_mem[i][j].rob_idx < alu_rob_idx[k])) begin
              alu_issue_info_o[k].valid = '1;
              alu_issue_info_o[k].option_code = gen2alu(rs_mem[i][j].option_code);
              alu_issue_info_o[k].base_info.psrc0 = rs_mem[i][j].psrc0;
              alu_issue_info_o[k].base_info.psrc1 = rs_mem[i][j].psrc1;
              alu_issue_info_o[k].base_info.pdest = rs_mem[i][j].pdest;
              alu_issue_info_o[k].base_info.imm = rs_mem[i][j].imm;
              alu_issue_info_o[k].base_info.pdest_valid = rs_mem[i][j].pdest_valid;


              // 更新最老的misc指令
              alu_position_bit[k] = rs_mem[i][j].position_bit;
              alu_rob_idx[k] = rs_mem[i][j].rob_idx;
              alu_issue_i_idx[k] = i;
              alu_issue_j_idx[k] = j;
            end
          end
        end
        // mem: 顺序执行
        // 是一条mem指令
        if (rs_mem[i][j].valid && !rs_mem[i][j].issued &&
            rs_mem[i][j].option_code.inst_type == `MEMORY_INST) begin
          // 是一条更老的mem指令
          if ((rs_mem[i][j].position_bit == mem_position_bit &&
               rs_mem[i][j].rob_idx > mem_rob_idx) || 
              (rs_mem[i][j].position_bit != mem_position_bit &&
               rs_mem[i][j].rob_idx < mem_rob_idx)) begin
            mem_issue_info_o.valid = 
                          (rs_mem[i][j].psrc0_ready | ~rs_mem[i][j].psrc0_valid) &
                          (rs_mem[i][j].psrc1_ready | ~rs_mem[i][j].psrc1_valid);
            mem_issue_info_o.option_code = gen2mem(rs_mem[i][j].option_code);
            mem_issue_info_o.base_info.psrc0 = rs_mem[i][j].psrc0;
            mem_issue_info_o.base_info.psrc1 = rs_mem[i][j].psrc1;
            mem_issue_info_o.base_info.pdest = rs_mem[i][j].pdest;
            mem_issue_info_o.base_info.imm = rs_mem[i][j].imm;
            mem_issue_info_o.base_info.pdest_valid = rs_mem[i][j].pdest_valid;

            // 更新最老的mem指令
            mem_position_bit = rs_mem[i][j].position_bit;
            mem_rob_idx = rs_mem[i][j].rob_idx;
            mem_issue_i_idx = i;
            mem_issue_j_idx = j;
          end
        end
      end
    end

    for (int i = 0; i < 2; i++) begin
      rs_mem_n[alu_issue_i_idx[i]][alu_issue_j_idx[i]].issued = alu_issue_info_o[i].valid & alu_ready_i[i];
    end
    rs_mem_n[misc_issue_i_idx][misc_issue_j_idx].issued = misc_issue_info_o.valid & misc_ready_i;
    rs_mem_n[mem_issue_i_idx][mem_issue_j_idx].issued = mem_issue_info_o.valid & mem_ready_i;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n || flush_i) begin
      round_robin <= '0;
      rs_mem <= '0;
    end else begin
      round_robin <= ~round_robin;
      rs_mem <= rs_mem_n;
    end
  end

endmodule : ReservationStation
