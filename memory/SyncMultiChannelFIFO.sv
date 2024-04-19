// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : SyncMultiChannelFIFO.sv
// Create  : 2024-01-16 12:01:16
// Revise  : 2024-01-16 13:54:50
// Description :
//   Sync Multi Port FIFO
//   1 clk latency
//   为了简化设计，push和pop有效位必须连续并从[0]开始
// Parameter   :
//   ...
//   ...
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// 24-01-16 |            |     0.1     |    Original Version
// ==============================================================================

`include "config.svh"
`include "common.svh"

module SyncMultiChannelFIFO #(
parameter
  int unsigned FIFO_DEPTH = 16,
  int unsigned DATA_WIDTH = 32,
  int unsigned RPORTS_NUM = 4,
  int unsigned WPORTS_NUM = 4,
  string       FIFO_MEMORY_TYPE = "auto"
)(
  input logic clk,      // Clock
  input logic a_rst_n,  // Asynchronous reset active low
  input logic flush_i,

  input logic [WPORTS_NUM - 1:0] write_valid_i,
  output logic write_ready_o,
  input logic [WPORTS_NUM - 1:0][DATA_WIDTH - 1:0] write_data_i,

  output logic [RPORTS_NUM - 1:0] read_valid_o,
  input logic [RPORTS_NUM - 1:0] read_ready_i,
  output logic [RPORTS_NUM - 1:0][DATA_WIDTH - 1:0] read_data_o
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);
  localparam BANK = RPORTS_NUM > WPORTS_NUM ? RPORTS_NUM : WPORTS_NUM;

`ifdef DEBUG
  initial begin
    assert (FIFO_DEPTH % BANK == 0) else $error("SyncMultiPortFIFO: FIFO_DEPTH %% BANK != 0");
  end
`endif

  logic [$clog2(WPORTS_NUM + 1) - 1:0] write_num;
  logic [$clog2(RPORTS_NUM + 1) - 1:0] read_num;
  typedef logic [$clog2(BANK) - 1 : 0] ptr_t;
  ptr_t [RPORTS_NUM - 1 : 0] read_index;
  ptr_t [BANK - 1 : 0] port_read_index,port_write_index;
  logic [BANK - 1 : 0] fifo_full,fifo_empty,fifo_push,fifo_pop;
  logic [BANK - 1 : 0][DATA_WIDTH - 1:0] data_in, data_out;
  logic [$clog2(BANK + 1) - 1 : 0] count_full;


  // FIFO 部分
  always_comb begin
    count_full = $countones(fifo_full);
    // write_ready = count_full + WPORTS_NUM <= BANK;
    write_ready_o = count_full <= (BANK[$clog2(BANK + 1) - 1 : 0] - WPORTS_NUM[$clog2(BANK + 1) - 1 : 0]);
    
    write_num = '0;
    for (int i = 0; i < WPORTS_NUM; i++) begin
      write_num += write_valid_i[i];
    end

    read_num = '0;
    for (int i = 0; i < RPORTS_NUM; i++) begin
      read_num += read_ready_i[i] & read_valid_o[i];
    end
  end

  generate
    for(genvar i = 0 ; i < BANK; i += 1) begin : gen_multi_fifo_ctrl
      // 指针更新策略
      always_ff @(posedge clk) begin : proc_port_read_index
        if(~rst_n || flush_i) begin
          port_read_index[i] <= i[$clog2(BANK) - 1 : 0];
        end else begin
          if(|read_ready_i)
            port_read_index[i] <= port_read_index[i] - read_num[$clog2(BANK) - 1 : 0];
        end
      end
      always_ff @(posedge clk) begin : proc_port_write_index
        if(~rst_n || flush_i) begin
          port_write_index[i] <= i[$clog2(BANK) - 1 : 0];
        end else begin
          if(|write_valid_i & write_ready_o)
            port_write_index[i] <= port_write_index[i] - write_num[$clog2(BANK) - 1 : 0];
        end
      end

      // FIFO 控制信号
      assign fifo_pop[i] = |read_ready_i & (port_read_index[i] < read_num);
      assign fifo_push[i] = |write_valid_i & write_ready_o & (port_write_index[i] < write_num);
      assign data_in[i] = write_data_i[port_write_index[i][$clog2(WPORTS_NUM) - 1: 0]];

      // FIFO 生成
      SyncFIFO #(
        .FIFO_DEPTH(FIFO_DEPTH / BANK),
        .FIFO_DATA_WIDTH(DATA_WIDTH),
        .READ_MODE("std"),
        .FIFO_MEMORY_TYPE(FIFO_MEMORY_TYPE)
      ) U_SyncFIFO (
        .clk           (clk),
        .a_rst_n       (a_rst_n),
        .flush_i       (flush_i),
        .pop_i         (fifo_pop[i]),
        .push_i        (fifo_push[i]),
        .data_i        (data_in[i]),
        .data_o        (data_out[i]),
        .empty_o       (fifo_empty[i]),
        .full_o        (fifo_full[i]),
        .usage_o       (/* not used */)
      );

    end
  endgenerate

  // 输出部分
  generate
    for(genvar i = 0 ; i < RPORTS_NUM; i+= 1) begin : gen_multi_fifo_ouput
      // 指针更新策略
      always_ff @(posedge clk) begin : proc_read_index
        if(~rst_n || flush_i) begin
          read_index[i] <= i[$clog2(BANK) - 1 : 0];
        end else begin
          if(read_ready_i) begin
            read_index[i] <= read_index[i] + read_num[$clog2(BANK) - 1 : 0];
          end
        end
      end
      assign read_data_o[i] = data_out[read_index[i]];
      assign read_valid_o[i] = ~fifo_empty[read_index[i]];
    end
  endgenerate


endmodule : SyncMultiChannelFIFO
