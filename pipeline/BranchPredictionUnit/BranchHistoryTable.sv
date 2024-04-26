// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : your name <your email>@email.com
// File    : BranchHistoryTable.sv
// Create  : 2024-04-26 17:57:15
// Revise  : 2024-04-26 17:57:15
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

module BranchHistoryTable #(
	parameter ADDR_WIDTH = `BHT_ADDR_WIDTH,
    parameter DATA_WIDTH = `BHT_DATA_WIDTH
) (
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	input we,
    input [31:0] rpc,
    input [31:0] wpc,
    input br_taken,
    output [DATA_WIDTH - 1:0] bhr
);

	wire  [ADDR_WIDTH - 1:0] raddr = rpc[ADDR_WIDTH + 2:3];
    wire  [ADDR_WIDTH - 1:0] waddr = wpc[ADDR_WIDTH + 2:3];

    reg [DATA_WIDTH - 1:0] bht [1 << ADDR_WIDTH - 1:0];

    // read
    assign bhr = ~rst_n ? 32'h0000_0000 : bht[waddr];

    // write
    always @(posedge clk ) begin
        if (we) begin
            bht[waddr] <= (bht[waddr] << 1) | br_taken;
        end else begin
            bht[waddr] <= bht[waddr];
        end
    end

endmodule : BranchHistoryTable