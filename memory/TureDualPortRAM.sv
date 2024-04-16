// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : TureDualPortRAM.sv
// Create  : 2024-01-13 21:28:51
// Revise  : 2024-01-13 21:28:51
// Description :
//   真双端口RAM
// Parameter   :
//   CLOCKING_MODE:
//     - "common_clock": 通用时钟，使用 clka 为端口 A 和端口 B 提供时钟
//     - “independent_clock”: 独立时钟，带有 clka 的时钟端口 A 和带有 clkb 的端口 B
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
// 24-01-13 |            |     0.1     |    Original Version
// ==============================================================================

`include "config.svh"

module TureDualPortRAM #(
parameter
  int unsigned DATA_DEPTH       = 256,
  int unsigned DATA_WIDTH       = 32,
  int unsigned BYTE_WRITE_WIDTH = 32,
  string       CLOCKING_MODE    = "common_clock",
  string       WRITE_MODE_A     = "write_first",
  string       WRITE_MODE_B     = "write_first",
  string       MEMORY_PRIMITIVE = "auto",
localparam
  int unsigned ADDR_WIDTH       = $clog2(DATA_DEPTH),
  int unsigned MEMORY_SIZE      = DATA_WIDTH * DATA_DEPTH
)(
  // Port A
  input clk_a,
  input rsta_n,
  input en_a_i,
  input [DATA_WIDTH / BYTE_WRITE_WIDTH - 1:0] we_a_i,
  input [ADDR_WIDTH - 1:0] addr_a_i,
  input [DATA_WIDTH - 1:0] data_a_i,
  output [DATA_WIDTH - 1:0] data_a_o,
  // Port B
  input clk_b,
  input rstb_n,
  input en_b_i,
  input [DATA_WIDTH / BYTE_WRITE_WIDTH - 1:0] we_b_i,
  input [ADDR_WIDTH - 1:0] addr_b_i,
  input [DATA_WIDTH - 1:0] data_b_i,
  output [DATA_WIDTH - 1:0] data_b_o
);

`ifdef DEBUG
// some parameter check
initial begin
  assert (DATA_WIDTH % BYTE_WRITE_WIDTH == 0) else $fatal("WRITE_DATA_WIDTH must be an integer multiple of BYTE_WRITE_WIDTH");
end
`endif

`ifdef VERILATOR_SIM
  logic [DATA_DEPTH - 1:0][DATA_WIDTH - 1:0] ram;

  logic [DATA_WIDTH - 1:0] rdata_a_q, rdata_b_q;
  logic [DATA_WIDTH - 1:0] rdata_a_n, rdata_b_n;

  logic we_confilct;

  always_comb begin
    we_confilct = en_a_i && we_a_i &&
                  en_b_i && en_b_i &&
                  addr_a_i == addr_b_i;

    if (WRITE_MODE_A == "write_first") begin
      if (en_a_i && we_a_i) begin
        rdata_a_n = data_a_i;
      end else if (en_b_i && we_b_i && addr_a_i == addr_b_i) begin
        rdata_a_n = data_b_i;
      end else begin
        rdata_a_n = ram[addr_a_i];
      end
    end else begin
      rdata_a_n = ram[addr_a_i];
    end

    if (WRITE_MODE_B == "write_first") begin
      if (en_b_i && we_b_i) begin
        rdata_b_n = data_b_i;
      end else if (en_a_i && we_a_i && addr_a_i == addr_b_i) begin
        rdata_b_n = data_a_i;
      end else begin
        rdata_b_n = ram[addr_b_i];
      end
    end else begin
      rdata_b_n = ram[addr_b_i];
    end
  end


  always_ff @(posedge clk_a or negedge rsta_n) begin
    if(~rsta_n) begin
      rdata_a_q <= '0;
    end else begin
      if (en_a_i) begin
        raddr_a_q <= rdata_a_n;
      end

      if (en_b_i && we_b_i && !(we_confilct && WRITE_MODE_A == "no_change")) begin
        ram[addr_a_i] <= data_a_i;
      end
    end
  end

  always_ff @(posedge clk_a or negedge rstb_n) begin
    if(~rstb_n) begin
      rdata_b_q <= '0;
    end else begin
      if (en_b_i) begin
        rdata_b_q <= rdata_b_n;
      end

      if (en_b_i && we_b_i && !(we_confilct && WRITE_MODE_B == "no_change")) begin
        ram[addr_b_i] <= data_b_i;
      end
    end
  end

  assign data_a_o = rdata_a_q;
  assign data_b_o = rdata_b_q;
`elsif XILLINX_FPGA
  // xpm_memory_tdpram: True Dual Port RAM
  // Xilinx Parameterized Macro, version 2019.2
  xpm_memory_tdpram #(
    .ADDR_WIDTH_A(ADDR_WIDTH),               // DECIMAL
    .ADDR_WIDTH_B(ADDR_WIDTH),               // DECIMAL
    .AUTO_SLEEP_TIME(0),            // DECIMAL
    .BYTE_WRITE_WIDTH_A(BYTE_WRITE_WIDTH),        // DECIMAL
    .BYTE_WRITE_WIDTH_B(BYTE_WRITE_WIDTH),        // DECIMAL
    .CASCADE_HEIGHT(0),             // DECIMAL
    .CLOCKING_MODE(CLOCKING_MODE), // String
    .ECC_MODE("no_ecc"),            // String
    .MEMORY_INIT_FILE("none"),      // String
    .MEMORY_INIT_PARAM("0"),        // String
    .MEMORY_OPTIMIZATION("true"),   // String
    .MEMORY_PRIMITIVE("auto"),      // String
    .MEMORY_SIZE(MEMORY_SIZE),                 // DECIMAL
    .MESSAGE_CONTROL(0),            // DECIMAL
    .READ_DATA_WIDTH_A(DATA_WIDTH),         // DECIMAL
    .READ_DATA_WIDTH_B(DATA_WIDTH),         // DECIMAL
    .READ_LATENCY_A(1),             // DECIMAL
    .READ_LATENCY_B(1),             // DECIMAL
    .READ_RESET_VALUE_A("0"),       // String
    .READ_RESET_VALUE_B("0"),       // String
    .RST_MODE_A("SYNC"),            // String
    .RST_MODE_B("SYNC"),            // String
    .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
    .USE_MEM_INIT(0),               // DECIMAL
    .WAKEUP_TIME("disable_sleep"),  // String
    .WRITE_DATA_WIDTH_A(DATA_WIDTH),        // DECIMAL
    .WRITE_DATA_WIDTH_B(DATA_WIDTH),        // DECIMAL
    .WRITE_MODE_A(WRITE_MODE_A),     // String
    .WRITE_MODE_B(WRITE_MODE_B)      // String
  )
  xpm_memory_tdpram_inst (
    .dbiterra(dbiterra),             // 1-bit output: Status signal to indicate double bit error occurrence
                                     // on the data output of port A.
    .dbiterrb(dbiterrb),             // 1-bit output: Status signal to indicate double bit error occurrence
                                     // on the data output of port A.
    .douta(data_a_o),                // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
    .doutb(data_b_o),                // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
    .sbiterra(sbiterra),             // 1-bit output: Status signal to indicate single bit error occurrence
                                     // on the data output of port A.
    .sbiterrb(sbiterrb),             // 1-bit output: Status signal to indicate single bit error occurrence
                                     // on the data output of port B.
    .addra(addr_a_i),                // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
    .addrb(addr_b_i),                // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
    .clka(clk_a),                    // 1-bit input: Clock signal for port A. Also clocks port B when
                                     // parameter CLOCKING_MODE is "common_clock".
    .clkb(clk_b),                    // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                     // "independent_clock". Unused when parameter CLOCKING_MODE is
                                     // "common_clock".
    .dina(data_a_i),                 // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
    .dinb(data_b_i),                 // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
    .ena(en_a_i),                    // 1-bit input: Memory enable signal for port A. Must be high on clock
                                     // cycles when read or write operations are initiated. Pipelined
                                     // internally.
    .enb(en_b_i),                    // 1-bit input: Memory enable signal for port B. Must be high on clock
                                     // cycles when read or write operations are initiated. Pipelined
                                     // internally.
    .injectdbiterra('0),             // 1-bit input: Controls double bit error injection on input data when
                                     // ECC enabled (Error injection capability is not available in
                                     // "decode_only" mode).
    .injectdbiterrb('0),             // 1-bit input: Controls double bit error injection on input data when
                                     // ECC enabled (Error injection capability is not available in
                                     // "decode_only" mode).
    .injectsbiterra('0),             // 1-bit input: Controls single bit error injection on input data when
                                     // ECC enabled (Error injection capability is not available in
                                     // "decode_only" mode).
    .injectsbiterrb('0),             // 1-bit input: Controls single bit error injection on input data when
                                     // ECC enabled (Error injection capability is not available in
                                     // "decode_only" mode).
    .regcea('1),                     // 1-bit input: Clock Enable for the last register stage on the output
                                     // data path.
    .regceb('1),                     // 1-bit input: Clock Enable for the last register stage on the output
                                     // data path.
    .rsta(~rsta_n),                  // 1-bit input: Reset signal for the final port A output register stage.
                                     // Synchronously resets output port douta to the value specified by
                                     // parameter READ_RESET_VALUE_A.
    .rstb(~rstb_n),                  // 1-bit input: Reset signal for the final port B output register stage.
                                     // Synchronously resets output port doutb to the value specified by
                                     // parameter READ_RESET_VALUE_B.
    .sleep('0),                      // 1-bit input: sleep signal to enable the dynamic power saving feature.
    .wea(we_a_i),                    // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                     // for port A input data port dina. 1 bit wide when word-wide writes are
                                     // used. In byte-wide write configurations, each bit controls the
                                     // writing one byte of dina to address addra. For example, to
                                     // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                     // is 32, wea would be 4'b0010.
    .web(we_b_i)                     // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
                                     // for port B input data port dinb. 1 bit wide when word-wide writes are
                                     // used. In byte-wide write configurations, each bit controls the
                                     // writing one byte of dinb to address addrb. For example, to
                                     // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
                                     // is 32, web would be 4'b0010.
  );
`elsif MSIC180_SYN
// TODO: tdpram msic180 syn implementation
`else
  initial begin
    $display("Error: No ram implementation selected!");
    $finish;
  end
`endif

endmodule : TureDualPortRAM
