// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : XORBasedMultiPortRAM.sv
// Create  : 2024-01-27 17:29:02
// Revise  : 2024-01-27 17:29:02
// Description :
//   基于XOR的多端口RAM
//   ref: https://tomverbeure.github.io/2019/08/03/Multiport-Memories.html
// Parameter   :
//   CLOCKING_MODE:
//     - "common_clock": 通用时钟，使用clk_w[i]为读写口提供统一时钟
//     - “independent_clock”: 独立时钟，带有clk_w[i]为每一个写口提供时钟， clk_r[i]分别为每一个读口提供时钟
//   WRITE_MODE: 处理读写冲突
//     - "no_change": 数据无变化
//     - "read_first": 读优先
//     - "write_first": 写优先
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// 24-01-27 |            |     0.1     |    Original Version
// ==============================================================================

`include "config.svh"

module XORBasedMultiPortRAM #(
parameter
  int unsigned DATA_DEPTH = 128,
  int unsigned DATA_WIDTH = 64,
  int unsigned RPORTS_NUM = 6,
  int unsigned WPORTS_NUM = 6,
  int unsigned BYTE_WRITE_WIDTH = 64,
               CLOCKING_MODE = "common_clock",
               WRITE_MODE = "write_first",
localparam
  int unsigned ADDR_WIDTH = $clog2(DATA_DEPTH),
  int unsigned BYTES_NUM  = DATA_WIDTH / BYTE_WRITE_WIDTH
)(
  input logic [WPORTS_NUM - 1:0] clk_w,    // Clock
  input logic [RPORTS_NUM - 1:0] clk_r,
  input logic a_rst_n,  // Asynchronous reset active low
  input logic [WPORTS_NUM - 1:0] en_w_i,
  input logic [RPORTS_NUM - 1:0] en_r_i,
  input logic [WPORTS_NUM - 1:0][BYTES_NUM - 1:0] we_i,
  input logic [RPORTS_NUM - 1:0][ADDR_WIDTH - 1:0] raddr_i,
  input logic [WPORTS_NUM - 1:0][ADDR_WIDTH - 1:0] waddr_i,
  input logic [WPORTS_NUM - 1:0][DATA_WIDTH - 1:0] data_i,
  output logic [RPORTS_NUM - 1:0][DATA_WIDTH - 1:0] data_o
);

`ifdef DEBUG
  initial begin
    assert(WPORTS_NUM > 0) else $error("XORBasedMultiPortRAM: WPORTS_NUM <= 0 !!!");
    assert(RPORTS_NUM > 0) else $error("XORBasedMultiPortRAM: RPORTS_NUM <= 0 !!!");
  end
`endif



  generate
    if (WPORTS_NUM == 1) begin
      MultiReadRAM #(
        .DATA_DEPTH(DATA_DEPTH),
        .DATA_WIDTH(DATA_WIDTH),
        .RPORTS_NUM(RPORTS_NUM),
        .BYTE_WRITE_WIDTH(BYTE_WRITE_WIDTH),
        .CLOCKING_MODE(CLOCKING_MODE),
        .WRITE_MODE(WRITE_MODE)
      ) U_MultiReadRAM (
        .clk_w   (clk_w[0]),
        .clk_r   (clk_r),
        .a_rst_n (a_rst_n),
        .en_w_i (en_w_i[0]),
        .en_r_i (en_r_i),
        .we_i    (we_i[0]),
        .waddr_i (waddr_i[0]),
        .data_i  (data_i[0]),
        .raddr_i (raddr_i),
        .data_o  (data_o)
      );
    end else begin
      // wport <==> U_WritePortColumnRAMs
      // rport <==> U_ReadPortColumnRAMs
      logic [WPORTS_NUM - 1:0][ADDR_WIDTH - 1:0] waddr_i_r;
      logic [WPORTS_NUM - 1:0][DATA_WIDTH - 1:0] data_i_r;
      logic [WPORTS_NUM - 1:0][BYTES_NUM - 1:0] we_i_r;
      logic [WPORTS_NUM - 1:0] en_w_i_r;
      // 延迟一个周期，等待WritePortColumnRAMs读出用来XOR的数据
      if (CLOCKING_MODE == "common_clock") begin
        always_ff @(posedge clk_w[0] or negedge a_rst_n) begin
          if(~a_rst_n) begin
            waddr_i_r <= '0;
            data_i_r <= '0;
            we_i_r <= '0;
            en_w_i_r <= '0;
          end else begin
            waddr_i_r <= waddr_i;
            data_i_r <= data_i;
            we_i_r <= we_i;
            en_w_i_r <= en_w_i;
          end
        end
      end else begin
        for (genvar i = 0; i < WPORTS_NUM; i++) begin
          always_ff @(posedge clk_w[i] or negedge a_rst_n) begin
            if(~a_rst_n) begin
              waddr_i_r[i] <= '0;
              data_i_r[i] <= '0;
              we_i_r[i] <= '0;
              en_w_i_r[i] <= '0;
            end else begin
              waddr_i_r[i] <= waddr_i[i];
              data_i_r[i] <= data_i[i];
              we_i_r[i] <= we_i[i];
              en_w_i_r[i] <= en_w_i[i];
            end
          end
        end
      end


      // 写入逻辑
      logic [WPORTS_NUM - 1:0][WPORTS_NUM - 2:0][ADDR_WIDTH - 1:0] wport_raddr;
      logic [WPORTS_NUM - 1:0][WPORTS_NUM - 2:0][DATA_WIDTH - 1:0] wport_rdata;
      logic [WPORTS_NUM - 1:0][BYTES_NUM - 1:0]  we;
      logic [WPORTS_NUM - 1:0][DATA_WIDTH - 1:0] wdata;  // wport和rport的写入数据，相对于we_i信号有一个周期的延迟
      always_comb begin
        // init wdata
        for (int i = 0; i < WPORTS_NUM; i++) begin
          wdata[i] = data_i_r[i];
        end
        // build xor wdata
        for (int i = 0; i < WPORTS_NUM; i++) begin
          automatic int k = 0;
          for (int j = 0; j < WPORTS_NUM - 1; j++) begin
            k = k + (j == i);  // 跳过自己
            wport_raddr[i][j] = waddr_i[k];
            wdata[k] = wdata[k] ^ wport_rdata[i][j];
            k++;
          end
        end
        // we logic
        we = we_i_r;
        if (WRITE_MODE == "no_change") begin
          for (int i = 0; i < WPORTS_NUM; i++) begin
            if (waddr_i[i] == raddr_i[i]) begin
              we[i] = '0;
            end
          end
        end
      end

      // 读取逻辑
      logic [WPORTS_NUM - 1:0][RPORTS_NUM - 1:0][DATA_WIDTH - 1:0] rport_rdata;
      if (WRITE_MODE == "write_first") begin
        always_comb begin
          for (int i = 0; i < RPORTS_NUM; i++) begin
            data_o[i] = rport_rdata[0][i];
            for (int j = 1; j < WPORTS_NUM; j++) begin
              // xor所有其他行RAM的第[i]口读出数据
              data_o[i] = data_o[i] ^ rport_rdata[j][i];
            end
            // 对读写地址相同的情况做转发
            for (int j = 0; j < WPORTS_NUM; j++) begin
              if (raddr_i[i] == waddr_i[j]) begin
                data_o[i] = data_i_r[j];
              end
            end
          end
        end
      end else if (WRITE_MODE == "read_first") begin
        always_comb begin
          for (int i = 0; i < RPORTS_NUM; i++) begin
            data_o[i] = rport_rdata[0][i];
            for (int j = 1; j < WPORTS_NUM; j++) begin
              // xor所有其他行RAM的第[i]口读出数据
              data_o[i] = data_o[i] ^ rport_rdata[j][i];
            end
          end
          // 无需多余的操作
        end
      end else if (WRITE_MODE == "no_change") begin
        always_comb begin
          for (int i = 0; i < RPORTS_NUM; i++) begin
            data_o[i] = rport_rdata[0][i];
            for (int j = 1; j < WPORTS_NUM; j++) begin
              // xor所有其他行RAM的第[i]口读出数据
              data_o[i] = data_o[i] ^ rport_rdata[j][i];
            end
          end
        end
        // 写入控制在前面写入逻辑控制
      end else begin
        $error("XORBasedMultiPortRAM: WRITE_MODE is no in {write_first, read_first, no_change}");
      end

      for (genvar i = 0; i < WPORTS_NUM; i++) begin : MultiReadRAMs
        /**
          * write_first确保在写入addr，同时连续读addr时，数据正确
          * 即存在如下情况
          * clk0 raddr == waddr == addr0
          * clk1 raddr == addr0 waddr == addr1
          */
        MultiReadRAM #(
          .DATA_DEPTH(DATA_DEPTH),
          .DATA_WIDTH(DATA_WIDTH),
          .RPORTS_NUM(WPORTS_NUM - 1),
          .BYTE_WRITE_WIDTH(BYTE_WRITE_WIDTH),
          .CLOCKING_MODE(CLOCKING_MODE),
          .WRITE_MODE("write_first")
        ) U_WritePortColumnRAMs (
          .clk_w   (clk_w[i]),
          .clk_r   (clk_r),
          .a_rst_n (a_rst_n),
          .en_w_i  (en_w_i_r[i]),
          .en_r_i  ('1),
          .we_i    (we[i]),
          .waddr_i (waddr_i_r[i]),
          .data_i  (wdata[i]),
          .raddr_i (wport_raddr[i]),
          .data_o  (wport_rdata[i])
        );
        MultiReadRAM #(
          .DATA_DEPTH(DATA_DEPTH),
          .DATA_WIDTH(DATA_WIDTH),
          .RPORTS_NUM(RPORTS_NUM),
          .BYTE_WRITE_WIDTH(BYTE_WRITE_WIDTH),
          .CLOCKING_MODE(CLOCKING_MODE),
          .WRITE_MODE("write_first")
        ) U_ReadPortColumnRAMs (
          .clk_w   (clk_w[i]),
          .clk_r   (clk_r),
          .a_rst_n (a_rst_n),
          .en_w_i  (en_w_i_r[i]),
          .en_r_i  (en_r_i),
          .we_i    (we[i]),
          .waddr_i (waddr_i_r[i]),
          .data_i  (wdata[i]),
          .raddr_i (raddr_i),
          .data_o  (rport_rdata[i])
        );
      end
    end
  endgenerate

endmodule : XORBasedMultiPortRAM

