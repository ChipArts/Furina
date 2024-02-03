// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : SyncFIFO.sv
// Create  : 2024-01-31 18:16:26
// Revise  : 2024-01-31 18:19:04
// Description :
//   同步FIFO
// Parameter   :
//   READ_MODE
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// 24-01-31 |            |     0.1     |    Original Version
// ==============================================================================

`include "config.svh"
`include "common.svh"


module SyncFIFO #(
parameter
  int unsigned FIFO_WRITE_DEPTH = 128,
  int unsigned READ_DATA_WIDTH = 32,
  int unsigned WRITE_DATA_WIDTH = 32,
  int unsigned PROG_EMPTY_THRESH = 3,
  int unsigned PROG_FULL_THRESH = 3,
  string       READ_MODE = "std",
  string       USE_ADV_FEATURES = "0707",
  string       FIFO_MEMORY_TYPE = "auto",
localparam
  int unsigned FIFO_READ_DEPTH = FIFO_WRITE_DEPTH * WRITE_DATA_WIDTH / READ_DATA_WIDTH,
  int unsigned RD_DATA_COUNT_WIDTH = $clog2(FIFO_READ_DEPTH + 1),
  int unsigned WR_DATA_COUNT_WIDTH = $clog2(FIFO_WRITE_DEPTH + 1)
)(
  input clk,      // Clock
  input a_rst_n,  // Asynchronous reset active low
  input pop_i,
  input push_i,
  input [WRITE_DATA_WIDTH - 1:0] data_i,
  output [READ_DATA_WIDTH - 1:0] data_o,
  output empty,
  output full,
  output almost_empty,
  output almost_full,
  output prog_empty,
  output prog_full,
  output data_valid,
  output overflow,
  output underflow,
  output wr_ack,
  output [RD_DATA_COUNT_WIDTH - 1:0] rd_data_count,
  output [WR_DATA_COUNT_WIDTH - 1:0] wr_data_count
);

`ifdef DEBUG
// some parameter check
initial begin
end
`endif

`ifdef VERILATOR_SIM
// TODO: tdpram verilator sim module
`elsif VIVADO_VCS_SIM
  // xpm_fifo_sync: Synchronous FIFO
  // Xilinx Parameterized Macro, version 2019.2
  xpm_fifo_sync #(
    .DOUT_RESET_VALUE("0"),    // String
    .ECC_MODE("no_ecc"),       // String
    .FIFO_MEMORY_TYPE(FIFO_MEMORY_TYPE), // String
    .FIFO_READ_LATENCY(1),     // DECIMAL
    .FIFO_WRITE_DEPTH(FIFO_WRITE_DEPTH),   // DECIMAL
    .FULL_RESET_VALUE(0),      // DECIMAL
    .PROG_EMPTY_THRESH(PROG_FULL_THRESH),    // DECIMAL
    .PROG_FULL_THRESH(PROG_FULL_THRESH),     // DECIMAL
    .RD_DATA_COUNT_WIDTH(RD_DATA_COUNT_WIDTH),   // DECIMAL
    .READ_DATA_WIDTH(READ_DATA_WIDTH),      // DECIMAL
    .READ_MODE(READ_MODE),         // String
    .SIM_ASSERT_CHK(`ifdef DEBUG 1 `else 0 `endif),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .USE_ADV_FEATURES(USE_ADV_FEATURES), // String
    .WAKEUP_TIME(0),           // DECIMAL
    .WRITE_DATA_WIDTH(WRITE_DATA_WIDTH),     // DECIMAL
    .WR_DATA_COUNT_WIDTH(WR_DATA_COUNT_WIDTH)    // DECIMAL
  )
  xpm_fifo_sync_inst (
    .almost_empty(almost_empty),   // 1-bit output: Almost Empty : When asserted, this signal indicates that
                                   // only one more read can be performed before the FIFO goes to empty.

    .almost_full(almost_full),     // 1-bit output: Almost Full: When asserted, this signal indicates that
                                   // only one more write can be performed before the FIFO is full.

    .data_valid(data_valid),       // 1-bit output: Read Data Valid: When asserted, this signal indicates
                                   // that valid data is available on the output bus (dout).

    .dbiterr(dbiterr),             // 1-bit output: Double Bit Error: Indicates that the ECC decoder detected
                                   // a double-bit error and data in the FIFO core is corrupted.

    .dout(data_o),                   // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
                                   // when reading the FIFO.

    .empty(empty),                 // 1-bit output: Empty Flag: When asserted, this signal indicates that the
                                   // FIFO is empty. Read requests are ignored when the FIFO is empty,
                                   // initiating a read while empty is not destructive to the FIFO.

    .full(full),                   // 1-bit output: Full Flag: When asserted, this signal indicates that the
                                   // FIFO is full. Write requests are ignored when the FIFO is full,
                                   // initiating a write when the FIFO is full is not destructive to the
                                   // contents of the FIFO.

    .overflow(overflow),           // 1-bit output: Overflow: This signal indicates that a write request
                                   // (wren) during the prior clock cycle was rejected, because the FIFO is
                                   // full. Overflowing the FIFO is not destructive to the contents of the
                                   // FIFO.

    .prog_empty(prog_empty),       // 1-bit output: Programmable Empty: This signal is asserted when the
                                   // number of words in the FIFO is less than or equal to the programmable
                                   // empty threshold value. It is de-asserted when the number of words in
                                   // the FIFO exceeds the programmable empty threshold value.

    .prog_full(prog_full),         // 1-bit output: Programmable Full: This signal is asserted when the
                                   // number of words in the FIFO is greater than or equal to the
                                   // programmable full threshold value. It is de-asserted when the number of
                                   // words in the FIFO is less than the programmable full threshold value.

    .rd_data_count(rd_data_count), // RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the
                                   // number of words read from the FIFO.

    .rd_rst_busy(rd_rst_busy),     // 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read
                                   // domain is currently in a reset state.

    .sbiterr(sbiterr),             // 1-bit output: Single Bit Error: Indicates that the ECC decoder detected
                                   // and fixed a single-bit error.

    .underflow(underflow),         // 1-bit output: Underflow: Indicates that the read request (rd_en) during
                                   // the previous clock cycle was rejected because the FIFO is empty. Under
                                   // flowing the FIFO is not destructive to the FIFO.

    .wr_ack(wr_ack),               // 1-bit output: Write Acknowledge: This signal indicates that a write
                                   // request (wr_en) during the prior clock cycle is succeeded.

    .wr_data_count(wr_data_count), // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
                                   // the number of words written into the FIFO.

    .wr_rst_busy(wr_rst_busy),     // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
                                   // write domain is currently in a reset state.

    .din(data_i),                  // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
                                   // writing the FIFO.

    .injectdbiterr('0),            // 1-bit input: Double Bit Error Injection: Injects a double bit error if
                                   // the ECC feature is used on block RAMs or UltraRAM macros.

    .injectsbiterr('0),            // 1-bit input: Single Bit Error Injection: Injects a single bit error if
                                   // the ECC feature is used on block RAMs or UltraRAM macros.

    .rd_en(pop_i),                 // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
                                   // signal causes data (on dout) to be read from the FIFO. Must be held
                                   // active-low when rd_rst_busy is active high.

    .rst(~a_rst_n),                // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
                                   // unstable at the time of applying reset, but reset must be released only
                                   // after the clock(s) is/are stable.

    .sleep('0),                    // 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo
                                   // block is in power saving mode.

    .wr_clk(clk),                  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
                                   // free running clock.

    .wr_en(push_i)                 // 1-bit input: Write Enable: If the FIFO is not full, asserting this
                                   // signal causes data (on din) to be written to the FIFO Must be held
                                   // active-low when rst or wr_rst_busy or rd_rst_busy is active high

  );

  // End of xpm_fifo_sync_inst instantiation
`elsif XILLINX_FPGA_SYN
  // xpm_fifo_sync: Synchronous FIFO
  // Xilinx Parameterized Macro, version 2019.2
  xpm_fifo_sync #(
    .DOUT_RESET_VALUE("0"),    // String
    .ECC_MODE("no_ecc"),       // String
    .FIFO_MEMORY_TYPE(FIFO_MEMORY_TYPE), // String
    .FIFO_READ_LATENCY(1),     // DECIMAL
    .FIFO_WRITE_DEPTH(FIFO_WRITE_DEPTH),   // DECIMAL
    .FULL_RESET_VALUE(0),      // DECIMAL
    .PROG_EMPTY_THRESH(PROG_FULL_THRESH),    // DECIMAL
    .PROG_FULL_THRESH(PROG_FULL_THRESH),     // DECIMAL
    .RD_DATA_COUNT_WIDTH(RD_DATA_COUNT_WIDTH),   // DECIMAL
    .READ_DATA_WIDTH(READ_DATA_WIDTH),      // DECIMAL
    .READ_MODE(READ_MODE),         // String
    .SIM_ASSERT_CHK(`ifdef DEBUG 1 `else 0 `endif),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .USE_ADV_FEATURES(USE_ADV_FEATURES), // String
    .WAKEUP_TIME(0),           // DECIMAL
    .WRITE_DATA_WIDTH(WRITE_DATA_WIDTH),     // DECIMAL
    .WR_DATA_COUNT_WIDTH(WR_DATA_COUNT_WIDTH)    // DECIMAL
  )
  xpm_fifo_sync_inst (
    .almost_empty(almost_empty),   // 1-bit output: Almost Empty : When asserted, this signal indicates that
                                   // only one more read can be performed before the FIFO goes to empty.

    .almost_full(almost_full),     // 1-bit output: Almost Full: When asserted, this signal indicates that
                                   // only one more write can be performed before the FIFO is full.

    .data_valid(data_valid),       // 1-bit output: Read Data Valid: When asserted, this signal indicates
                                   // that valid data is available on the output bus (dout).

    .dbiterr(dbiterr),             // 1-bit output: Double Bit Error: Indicates that the ECC decoder detected
                                   // a double-bit error and data in the FIFO core is corrupted.

    .dout(data_o),                   // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
                                   // when reading the FIFO.

    .empty(empty),                 // 1-bit output: Empty Flag: When asserted, this signal indicates that the
                                   // FIFO is empty. Read requests are ignored when the FIFO is empty,
                                   // initiating a read while empty is not destructive to the FIFO.

    .full(full),                   // 1-bit output: Full Flag: When asserted, this signal indicates that the
                                   // FIFO is full. Write requests are ignored when the FIFO is full,
                                   // initiating a write when the FIFO is full is not destructive to the
                                   // contents of the FIFO.

    .overflow(overflow),           // 1-bit output: Overflow: This signal indicates that a write request
                                   // (wren) during the prior clock cycle was rejected, because the FIFO is
                                   // full. Overflowing the FIFO is not destructive to the contents of the
                                   // FIFO.

    .prog_empty(prog_empty),       // 1-bit output: Programmable Empty: This signal is asserted when the
                                   // number of words in the FIFO is less than or equal to the programmable
                                   // empty threshold value. It is de-asserted when the number of words in
                                   // the FIFO exceeds the programmable empty threshold value.

    .prog_full(prog_full),         // 1-bit output: Programmable Full: This signal is asserted when the
                                   // number of words in the FIFO is greater than or equal to the
                                   // programmable full threshold value. It is de-asserted when the number of
                                   // words in the FIFO is less than the programmable full threshold value.

    .rd_data_count(rd_data_count), // RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the
                                   // number of words read from the FIFO.

    .rd_rst_busy(rd_rst_busy),     // 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read
                                   // domain is currently in a reset state.

    .sbiterr(sbiterr),             // 1-bit output: Single Bit Error: Indicates that the ECC decoder detected
                                   // and fixed a single-bit error.

    .underflow(underflow),         // 1-bit output: Underflow: Indicates that the read request (rd_en) during
                                   // the previous clock cycle was rejected because the FIFO is empty. Under
                                   // flowing the FIFO is not destructive to the FIFO.

    .wr_ack(wr_ack),               // 1-bit output: Write Acknowledge: This signal indicates that a write
                                   // request (wr_en) during the prior clock cycle is succeeded.

    .wr_data_count(wr_data_count), // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
                                   // the number of words written into the FIFO.

    .wr_rst_busy(wr_rst_busy),     // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
                                   // write domain is currently in a reset state.

    .din(data_i),                  // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
                                   // writing the FIFO.

    .injectdbiterr('0),            // 1-bit input: Double Bit Error Injection: Injects a double bit error if
                                   // the ECC feature is used on block RAMs or UltraRAM macros.

    .injectsbiterr('0),            // 1-bit input: Single Bit Error Injection: Injects a single bit error if
                                   // the ECC feature is used on block RAMs or UltraRAM macros.

    .rd_en(pop_i),                 // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
                                   // signal causes data (on dout) to be read from the FIFO. Must be held
                                   // active-low when rd_rst_busy is active high.

    .rst(~a_rst_n),                // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
                                   // unstable at the time of applying reset, but reset must be released only
                                   // after the clock(s) is/are stable.

    .sleep('0),                    // 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo
                                   // block is in power saving mode.

    .wr_clk(clk),                  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
                                   // free running clock.

    .wr_en(push_i)                 // 1-bit input: Write Enable: If the FIFO is not full, asserting this
                                   // signal causes data (on din) to be written to the FIFO Must be held
                                   // active-low when rst or wr_rst_busy or rd_rst_busy is active high

  );

  // End of xpm_fifo_sync_inst instantiation

`elsif MSIC180_SYN
// TODO: tdpram msic180 syn implementation
`else
  initial begin
    $display("Error: No ram implementation selected!");
    $finish;
  end
`endif



endmodule : SyncFIFO

