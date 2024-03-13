// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Scheduler.sv
// Create  : 2024-03-12 23:16:08
// Revise  : 2024-03-13 23:32:22
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
  input rst_n,  // Asynchronous reset active low
  input ScheduleReqSt schedule_req,
  input ROB_DispatchRspSt rob_dispatch_rsp,
  output ScheduleReqSt schedule_rsp,
  output ROB_DispatchReqSt rob_dispatch_req
);

  /* stage 0 */
  // 寄存器重命名
  // 分发指令到各自的分发队列
  // 写入ROB

  always_comb begin
    schedule_req_st.valid = '1;
    schedule_req_st.ready = '1;
  end

  SyncMultiChannelFIFO #(
    .FIFO_DEPTH(FIFO_DEPTH),
    .DATA_WIDTH(DATA_WIDTH),
    .RPORTS_NUM(RPORTS_NUM),
    .WPORTS_NUM(WPORTS_NUM),
    .FIFO_MEMORY_TYPE(FIFO_MEMORY_TYPE),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) U_IntegerFreelist (
    .clk           (clk),
    .a_rst_n       (a_rst_n),
    .flush_i       (flush_i),
    .write_valid_i (write_valid_i),
    .write_ready_o (write_ready_o),
    .write_num_i   (write_num_i),
    .write_data_i  (write_data_i),
    .read_valid_o  (read_valid_o),
    .read_ready_i  (read_ready_i),
    .read_num_i    (read_num_i),
    .read_data_o   (read_data_o)
  );

  RegisterAliasTable #(
    .PHYS_REG_NUM(`PHY_REG_NUM)
  ) U_IntegerRegisterAliasTable (
    .clk         (clk),
    .a_rst_n     (rst_n),
    .restore_i   (),
    .allocaion_i ('0),
    .free_i      (),
    .arch_rat    (),
    .valid_i     (valid_i),
    .src0_i      (src0_i),
    .src1_i      (src1_i),
    .dest_i      (dest_i),
    .preg_i      (preg_i),
    .psrc0_o     (psrc0_o),
    .psrc1_o     (psrc1_o),
    .ppdst_o     (ppdst_o)
  );

  SyncMultiChannelFIFO #(
    .FIFO_DEPTH(FIFO_DEPTH),
    .DATA_WIDTH(DATA_WIDTH),
    .RPORTS_NUM(RPORTS_NUM),
    .WPORTS_NUM(WPORTS_NUM),
    .FIFO_MEMORY_TYPE(FIFO_MEMORY_TYPE),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) U_IntegerDispatchQueue (
    .clk           (clk),
    .a_rst_n       (a_rst_n),
    .flush_i       (flush_i),
    .write_valid_i (write_valid_i),
    .write_ready_o (write_ready_o),
    .write_num_i   (write_num_i),
    .write_data_i  (write_data_i),
    .read_valid_o  (read_valid_o),
    .read_ready_i  (read_ready_i),
    .read_num_i    (read_num_i),
    .read_data_o   (read_data_o)
  );

  SyncMultiChannelFIFO #(
    .FIFO_DEPTH(FIFO_DEPTH),
    .DATA_WIDTH(DATA_WIDTH),
    .RPORTS_NUM(RPORTS_NUM),
    .WPORTS_NUM(WPORTS_NUM),
    .FIFO_MEMORY_TYPE(FIFO_MEMORY_TYPE),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) U_MemoryDispatchQueue (
    .clk           (clk),
    .a_rst_n       (a_rst_n),
    .flush_i       (flush_i),
    .write_valid_i (write_valid_i),
    .write_ready_o (write_ready_o),
    .write_num_i   (write_num_i),
    .write_data_i  (write_data_i),
    .read_valid_o  (read_valid_o),
    .read_ready_i  (read_ready_i),
    .read_num_i    (read_num_i),
    .read_data_o   (read_data_o)
  );



  /* stage 0 */
  // 写入发射队列


endmodule : Scheduler

