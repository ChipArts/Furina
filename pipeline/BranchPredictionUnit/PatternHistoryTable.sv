// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : your name <your email>@email.com
// File    : PatternHistoryTable.sv
// Create  : 2024-04-26 18:07:58
// Revise  : 2024-04-26 18:10:47
// Editor  : {EDITER}
// Version : {VERSION}
// Description :
//    ...
//    ...
// Parameter   :
//    ...
//    ...
// IO Port     :
//    ...
//    ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
//    ...   |            |     0.1     |    Original Version
// ==============================================================================
`include "BranchPredictionUnit.svh"

module PatternHistoryTable #(
	parameter ADDR_WIDTH = 8
) (
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	input we_i,
    input taken_i,
    input [1:0] phr_i,
    input [ADDR_WIDTH - 1:0] rindex_i,
    input [ADDR_WIDTH - 1:0] windex_i,
    output [1:0] phr_o
);

	wire [1:0] wdata = 
            phr_i == 2'b11 ? (taken_i ? 2'b11 : 2'b10) :
            phr_i == 2'b10 ? (taken_i ? 2'b11 : 2'b01) :
            phr_i == 2'b01 ? (taken_i ? 2'b10 : 2'b00) :
                             (taken_i ? 2'b01 : 2'b00);


    SimpleDualPortRAM #(
        .DATA_DEPTH(2 ** ADDR_WIDTH),
        .DATA_WIDTH(2),
        .BYTE_WRITE_WIDTH(2),
        .CLOCKING_MODE("common_clock"),
        .WRITE_MODE("write_first"),
        .MEMORY_PRIMITIVE("auto")
    ) inst_SimpleDualPortRAM (
        .clk_a    (clk),
        .en_a_i   ('1),
        .we_a_i   (we_i),
        .addr_a_i (windex_i),
        .data_a_i (wdata),
        .clk_b    (clk),
        .rstb_n   (rst_n),
        .en_b_i   ('1),
        .addr_b_i (rindex_i),
        .data_b_o (phr_o)
    );


endmodule : PatternHistoryTable
