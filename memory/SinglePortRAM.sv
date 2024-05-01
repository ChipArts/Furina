// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : SinglePortRAM.sv
// Create  : 2024-01-14 16:52:59
// Revise  : 2024-01-14 16:52:59
// Description :
//   单端口RAM
// Parameter   :
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
// 24-01-14 |            |     0.1     |    Original Version
// ==============================================================================

`include "config.svh"

module SinglePortRAM #(
parameter
  int unsigned DATA_DEPTH = 256,
  int unsigned DATA_WIDTH = 32,
  int unsigned BYTE_WRITE_WIDTH = 8,
               MEMORY_PRIMITIVE = "auto",
               WRITE_MODE       = "write_first",
localparam
  int unsigned ADDR_WIDTH = $clog2(DATA_DEPTH),
  int unsigned MEMORY_SIZE = DATA_WIDTH * DATA_DEPTH
)(
	input clk,
	input rst_n,
  input en_i,
	input [ADDR_WIDTH-1:0] addr_i,
	input [DATA_WIDTH-1:0] data_i,
	input [DATA_WIDTH / BYTE_WRITE_WIDTH - 1:0] we_i,
	output logic [DATA_WIDTH-1:0] data_o
);

initial begin
  assert (DATA_WIDTH % BYTE_WRITE_WIDTH == 0) else $fatal("DATA_WIDTH must be an integer multiple of BYTE_WRITE_WIDTH");
end

`ifdef VERILATOR_SIM
  logic [DATA_DEPTH - 1:0][DATA_WIDTH - 1:0] ram;

  logic [DATA_WIDTH - 1:0] rdata_q, rdata_n;

  always_comb begin
    if (WRITE_MODE == "write_first" &&
        en_i && we_i) begin
      rdata_n = data_i;
    end else begin
      rdata_n = ram[addr_i];
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
       rdata_q <= '0;
    end else begin
      if (en_i) begin
        rdata_q <= rdata_n;
      end

      if (en_i && we_i) begin
         ram[addr_i] <= data_i;
      end
    end
  end

  assign data_o = rdata_q;

`elsif XILLINX_FPGA
// xpm_memory_spram: Single Port RAM
// Xilinx Parameterized Macro, version 2019.2
  xpm_memory_spram #(
    .ADDR_WIDTH_A(ADDR_WIDTH),              // DECIMAL
    .AUTO_SLEEP_TIME(0),           // DECIMAL
    .BYTE_WRITE_WIDTH_A(BYTE_WRITE_WIDTH),       // DECIMAL
    .CASCADE_HEIGHT(0),            // DECIMAL
    .ECC_MODE("no_ecc"),           // String
    .MEMORY_INIT_FILE("none"),     // String
    .MEMORY_INIT_PARAM("0"),       // String
    .MEMORY_OPTIMIZATION("true"),  // String
    .MEMORY_PRIMITIVE(MEMORY_PRIMITIVE),     // String
    .MEMORY_SIZE(MEMORY_SIZE),            // DECIMAL
    .MESSAGE_CONTROL(0),           // DECIMAL
    .READ_DATA_WIDTH_A(DATA_WIDTH),        // DECIMAL
    .READ_LATENCY_A(1),            // DECIMAL
    .READ_RESET_VALUE_A("0"),      // String
    .RST_MODE_A("SYNC"),           // String
    .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .USE_MEM_INIT(1),              // DECIMAL
    .WAKEUP_TIME("disable_sleep"), // String
    .WRITE_DATA_WIDTH_A(DATA_WIDTH),       // DECIMAL
    .WRITE_MODE_A(WRITE_MODE)    // String
  )
  xpm_memory_spram_inst (
    .dbiterra(dbiterra),             // 1-bit output: Status signal to indicate double bit error occurrence
                                     // on the data output of port A.
    .douta(data_o),                  // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
    .sbiterra(sbiterra),             // 1-bit output: Status signal to indicate single bit error occurrence
                                     // on the data output of port A.
    .addra(addr_i),                  // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
    .clka(clk),                      // 1-bit input: Clock signal for port A.
    .dina(data_i),                   // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
    .ena(en_i),                      // 1-bit input: Memory enable signal for port A. Must be high on clock
                                     // cycles when read or write operations are initiated. Pipelined
                                     // internally.
    .injectdbiterra('0), // 1-bit input: Controls double bit error injection on input data when
                                     // ECC enabled (Error injection capability is not available in
                                     // "decode_only" mode).
    .injectsbiterra('0), // 1-bit input: Controls single bit error injection on input data when
                                     // ECC enabled (Error injection capability is not available in
                                     // "decode_only" mode).
    .regcea('1),                     // 1-bit input: Clock Enable for the last register stage on the output
                                     // data path.
    .rsta(~rst_n),                   // 1-bit input: Reset signal for the final port A output register stage.
                                     // Synchronously resets output port douta to the value specified by
                                     // parameter READ_RESET_VALUE_A.
    .sleep('0),                      // 1-bit input: sleep signal to enable the dynamic power saving feature.
    .wea(we_i)                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                     // for port A input data port dina. 1 bit wide when word-wide writes are
                                     // used. In byte-wide write configurations, each bit controls the
                                     // writing one byte of dina to address addra. For example, to
                                     // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                     // is 32, wea would be 4'b0010.
  );

`elsif MSIC180_SYN
// TODO: tdpram msic180 syn implementation
`else
  initial begin
    $display("Error: No ram implementation selected!");
    $finish;
  end
`endif

endmodule : SinglePortRAM
