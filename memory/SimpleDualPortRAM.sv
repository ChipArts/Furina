// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : SimpleDualPortRAM.sv
// Create  : 2024-01-13 21:29:25
// Revise  : 2024-01-13 21:29:25
// Description :
//   伪双端口RAM
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

module SimpleDualPortRAM #(
  parameter DATA_DEPTH       = 256,
  parameter DATA_WIDTH       = 32,
  parameter BYTE_WRITE_WIDTH = 32,
  parameter CLOCKING_MODE    = "common_clock",
  parameter WRITE_MODE       = "write_first",
  parameter MEMORY_PRIMITIVE = "auto",
  localparam ADDR_WIDTH       = $clog2(DATA_DEPTH),
  localparam MEMORY_SIZE      = DATA_WIDTH * DATA_DEPTH
)(
	// Port A
  input clk_a,
  input en_a_i,
  // input [DATA_WIDTH / BYTE_WRITE_WIDTH - 1:0] we_a_i,
  input we_a_i,
  input [ADDR_WIDTH - 1:0] addr_a_i,
  input [DATA_WIDTH - 1:0] data_a_i,
  // Port B
  input clk_b,
  input rstb_n,
  input en_b_i,
  input [ADDR_WIDTH - 1:0] addr_b_i,
  output [DATA_WIDTH - 1:0] data_b_o
);

`ifdef VERILATOR_SIM
  logic [DATA_DEPTH - 1:0][DATA_WIDTH - 1:0] ram;

  logic [DATA_WIDTH - 1:0] rdata_q, rdata_n;

  always_comb begin
    if (WRITE_MODE == "write_first" &&
      en_a_i && we_a_i && addr_a_i == addr_b_i) begin
      rdata_n = data_a_i;
    end else begin
      rdata_n = ram[addr_b_i];
    end
  end

  always_ff @(posedge clk_a or negedge rstb_n) begin
    if(~rstb_n) begin
       rdata_q <= '0;
    end else begin
      if (en_a_i && we_a_i) begin
        ram[addr_a_i] <= data_a_i;
      end

      if (en_b_i) begin
        rdata_q <= rdata_n;
      end
    end
  end

  assign data_b_o = rdata_q;

`elsif XILLINX_FPGA
  // xpm_memory_sdpram: Simple Dual Port RAM
  // Xilinx Parameterized Macro, version 2019.2
  xpm_memory_sdpram #(
    .ADDR_WIDTH_A(ADDR_WIDTH),               // DECIMAL
    .ADDR_WIDTH_B(ADDR_WIDTH),               // DECIMAL
    .AUTO_SLEEP_TIME(0),            // DECIMAL
    .BYTE_WRITE_WIDTH_A(BYTE_WRITE_WIDTH),        // DECIMAL
    .CASCADE_HEIGHT(0),             // DECIMAL
    .CLOCKING_MODE(CLOCKING_MODE), // String
    .ECC_MODE("no_ecc"),            // String
    .MEMORY_INIT_FILE("none"),      // String
    .MEMORY_INIT_PARAM("0"),        // String
    .MEMORY_OPTIMIZATION("true"),   // String
    .MEMORY_PRIMITIVE("auto"),      // String
    .MEMORY_SIZE(MEMORY_SIZE),             // DECIMAL
    .MESSAGE_CONTROL(0),            // DECIMAL
    .READ_DATA_WIDTH_B(DATA_WIDTH),         // DECIMAL
    .READ_LATENCY_B(1),             // DECIMAL
    .READ_RESET_VALUE_B("0"),       // String
    .RST_MODE_A("SYNC"),            // String
    .RST_MODE_B("SYNC"),            // String
    .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
    .USE_MEM_INIT(1),               // DECIMAL
    .WAKEUP_TIME("disable_sleep"),  // String
    .WRITE_DATA_WIDTH_A(DATA_WIDTH),        // DECIMAL
    .WRITE_MODE_B(WRITE_MODE)      // String
    )
    xpm_memory_sdpram_inst (
      .dbiterrb(dbiterrb),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port B.

      .doutb(data_b_o),                // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterrb(sbiterrb),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(addr_a_i),                // ADDR_WIDTH_A-bit input: Address for port A write operations.
      .addrb(addr_b_i),                // ADDR_WIDTH_B-bit input: Address for port B read operations.
      .clka(clk_a),                    // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk_b),                    // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(data_a_i),                 // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(en_a_i),                    // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when write operations are initiated. Pipelined internally.

      .enb(en_b_i),                    // 1-bit input: Memory enable signal for port B. Must be high on clock
                                       // cycles when read operations are initiated. Pipelined internally.

      .injectdbiterra('0),             // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra('0),             // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regceb('1),                     // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rstb(~rstb_n),                  // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep('0),                      // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(we_a_i)                     // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
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

endmodule : SimpleDualPortRAM
