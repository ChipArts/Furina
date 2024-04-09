// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : PhysicalRegisterFile.sv
// Create  : 2024-01-13 21:17:02
// Revise  : 2024-01-13 21:17:02
// Description :
//   物理寄存器堆
// Parameter   :
//   ...
//   ...
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// 24-01-13 |            |     0.1     |    Original Version
// ==============================================================================
`include "common.svh"

module PhysicalRegisterFile #(
  parameter READ_PORT_NUM = 2,
  parameter WRITE_PORT_NUM = 1,
  parameter DATA_WIDTH = 32,
  parameter PHY_REG_NUM = 64
)(
	input clk,      // Clock
	input a_rst_n,   // Asynchronous reset active low
  input [READ_PORT_NUM - 1:0]  re_i,
  input [WRITE_PORT_NUM - 1:0] we_i,
  input [READ_PORT_NUM - 1:0][$clog2(PHY_REG_NUM) - 1:0] raddr_i,
  input [WRITE_PORT_NUM - 1:0][$clog2(PHY_REG_NUM) - 1:0] waddr_i,
  input [WRITE_PORT_NUM - 1:0][DATA_WIDTH - 1:0] data_i,
  output logic [READ_PORT_NUM - 1:0][DATA_WIDTH - 1:0] data_o
);

  `RESET_LOGIC(clk, a_rst_n, s_rst_n)

  logic [PHY_REG_NUM - 1:0][DATA_WIDTH - 1:0] reg_file;
  always @(posedge clk or negedge s_rst_n) begin
    if (!s_rst_n) begin
      // reg_file <= '0;  // 逻辑上可以不复位寄存器堆
      data_o <= '0;
    end
    else begin
      foreach (waddr_i[i]) begin
        if (we_i[i]) begin
          reg_file[waddr_i[i]] <= data_i[i];
        end
      end
    end
  end

  always_comb begin
    for (int i = 0; i < READ_PORT_NUM; i++) begin
      for (int j = 0; j < WRITE_PORT_NUM; j++) begin
        if (re_i[i]) begin
          if (we_i[j] && raddr_i[i] == waddr_i[j]) begin
            data_o[i] = data_i[waddr_i[j]];
          end else begin
            data_o[i] = reg_file[raddr_i[i]];
          end
        end else begin
          data_o[i] = '0;
        end
      end
    end
  end

endmodule : PhysicalRegisterFile
