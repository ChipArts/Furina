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

module ReservationStation #(
parameter
  int unsigned RS_SIZE = 4,
  int unsigned BANK_NUM = 2,
  type OPTION_CODE = OptionCodeSt
)(
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input logic flush_i,

  /* dispatch */
  input RsBaseSt [BANK_NUM - 1:0] rs_base_i,
  input OPTION_CODE [BANK_NUM - 1:0] option_code_i,
  input logic [BANK_NUM - 1:0] wr_valid_i,
  output logic [BANK_NUM - 1:0] wr_ready_o,

  /* wake up */
  input logic [`WB_WIDTH - 1:0] wb_i,
  input logic [`WB_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] wb_pdest_i,

  /* issue */
  input logic [BANK_NUM - 1:0] issue_ready_i,
  output logic [BANK_NUM - 1:0] issue_valid_o,
  output IssueBaseSt [BANK_NUM - 1:0] issue_base_o,
  output OPTION_CODE [BANK_NUM - 1:0] issue_oc_o
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

/*================================== Memory ===================================*/
  typedef struct packed {
    RsBaseSt base;
    OPTION_CODE oc;
  } RsEntrySt;
  localparam BANK_SIZE = RS_SIZE / BANK_NUM;
  RsEntrySt [BANK_NUM - 1:0][BANK_SIZE - 1:0] rs_q, rs_n;

/*=================================== Logic ===================================*/
  logic [BANK_NUM - 1:0][BANK_SIZE - 1:0] free;
  logic [BANK_NUM - 1:0][$clog2(BANK_SIZE) - 1:0] write_idx;

  // issue: oldest first
  logic [BANK_NUM - 1:0] position_bit;
  logic [BANK_NUM - 1:0][$clog2(`ROB_DEPTH) - 1:0] rob_idx;
  logic [BANK_NUM - 1:0][$clog2(BANK_SIZE) - 1:0] issue_idx;

  // 生成free信号
  always_comb begin : proc_free
    free = '0;
    for (int i = 0; i < BANK_NUM; i++) begin
      for (int j = 0; j < BANK_SIZE; j++) begin
        free[i][j] = ~rs_q[i][j].base.valid | rs_q[i][j].base.issued;
      end
    end
  end

  // 生成wr_ready信号
  for (genvar i = 0; i < BANK_NUM; i++) begin : gen_wr_ready_o
    assign wr_ready_o[i] = $countones(free[i]) > 0;
  end


  // select
  always_comb begin : proc_selec
    // defult assign
    issue_valid_o = '0;
    issue_base_o  = '0;
    issue_oc_o    = '0;
    // to find the oldest instruction
    position_bit  = '0;
    rob_idx       = '0;
    issue_idx     = '0;

    // 如果position bit 相同，rob_idx 更小 的更旧
    // 如果position bit 不同，rob_idx 更大 的更旧

    for (int i = 0; i < BANK_NUM; i++) begin
      // 选择每个bank最旧的指令
      // 乱序发射
      for (int j = 0; j < BANK_SIZE; j++) begin
        // 是一条可发射的指令
        if (!free[i][j] &&
            (rs_q[i][j].base.psrc0_ready || !rs_q[i][j].base.psrc0_valid) &&
            (rs_q[i][j].base.psrc1_ready || !rs_q[i][j].base.psrc1_valid)) begin
          // 是一条更旧的指令 或 暂无有效的issue
          if (issue_valid_o[i] == '0 ||
              (rs_q[i][j].base.position_bit == position_bit[i] &&
               rs_q[i][j].base.rob_idx < rob_idx[i]) || 
              (rs_q[i][j].base.position_bit != position_bit[i] &&
               rs_q[i][j].base.rob_idx > rob_idx[i])) begin
            issue_valid_o[i] = '1;
            issue_base_o[i]  = rs2is(rs_q[i][j].base);
            issue_oc_o[i]    = rs_q[i][j].oc;

            // 更新最老的指令idx
            position_bit[i]  = rs_q[i][j].base.position_bit;
            rob_idx[i]       = rs_q[i][j].base.rob_idx;
            issue_idx[i]     = j;
          end
        end
      end
    end
  end

  always_comb begin : proc_rs_update
    // defult assign
    rs_n = rs_q;
    write_idx = '0;

    // wake up logic
    // 先进行唤醒，以防写入的内容被覆盖
    for (int i = 0; i < BANK_NUM; i++) begin
      for (int j = 0; j < BANK_SIZE; j++) begin
        for (int k = 0; k < `WB_WIDTH; k++) begin
          if (wb_i[k]) begin
            if (rs_q[i][j].base.valid &&
                rs_q[i][j].base.psrc0 == wb_pdest_i[k]) begin
              rs_n[i][j].base.psrc0_ready = '1;
            end
            if (rs_q[i][j].base.valid &&
                rs_q[i][j].base.psrc1 == wb_pdest_i[k]) begin
              rs_n[i][j].base.psrc1_ready = '1;
            end
          end
        end
      end
    end

    // write logic
    for (int i = 0; i < BANK_NUM; i++) begin
      // 选择写入位置
      for (int j = 0; j < BANK_SIZE; j++) begin
        if (free[i][j]) begin
          write_idx[i] = j;
          break;
        end
      end
      
      if (wr_ready_o[i] && wr_valid_i[i]) begin
        rs_n[i][write_idx[i]].base = rs_base_i[i];
        rs_n[i][write_idx[i]].oc = option_code_i[i];
      end
    end


    for (int i = 0; i < BANK_NUM; i++) begin
      if (issue_valid_o[i] && issue_ready_i[i]) begin
        rs_n[i][issue_idx[i]].base.issued = '1;
      end
    end

  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n || flush_i) begin
      rs_q <= '0;
    end else begin
      rs_q <= rs_n;
    end
  end

endmodule : ReservationStation
