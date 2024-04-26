// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : your name <your email>@email.com
// File    : BranchTargetBuffer.sv
// Create  : 2024-04-26 17:58:23
// Revise  : 2024-04-26 20:33:48
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

module BranchTargetBuffer #(
    parameter ADDR_WIDTH = 10
)(
    input clk,    // Clock
    input rst_n,  // Asynchronous reset active low
    input  [31:2] rpc_i,
    input         update_i,
    input  [31:2] wpc_i,
    input  [31:2] bta_i,
    input  [ 1:0] br_type_i,
    output [31:2] bta_o [1:0],
    output [ 1:0] br_type_o [1:0]
);

/*                              -btb entry-
    =======================================================
    || valid || TAG[14:0] || BTA[31：2] || br_type[1 :0] ||
    =======================================================
*/
    function logic[14:0] mktag(logic[31:2] pc);
        return pc[31:17] ^ pc[17:3];
    endfunction

    localparam BUFFER_SIZE = 1 << ADDR_WIDTH;
    localparam TAG_WIDTH   = 15;
    localparam ENTRY_WIDTH = 1 + 1 + TAG_WIDTH + 30 + 2;

    // input
    logic [TAG_WIDTH - 1:0] tag_r;
    logic [ADDR_WIDTH - 1:0] index_r;
    logic [TAG_WIDTH - 1:0] tag_w;
    logic [ADDR_WIDTH - 1:0] index_w;
    assign tag_r = mktag(rpc_i);
    assign index_r = rpc_i[ADDR_WIDTH + 2:3];
    assign tag_w = mktag(wpc_i);
    assign index_w = wpc_i[ADDR_WIDTH + 2:3];


    // ram
    logic valid [1:0];
    logic [ 1: 0] br_type [1:0];
    logic [31: 2] bta [1:0];
    logic [TAG_WIDTH - 1: 0] tag [1:0];

    SimpleDualPortRAM #(
        .DATA_DEPTH(1 << (ADDR_WIDTH - 1)),
        .DATA_WIDTH(ENTRY_WIDTH),
        .BYTE_WRITE_WIDTH(ENTRY_WIDTH),
        .CLOCKING_MODE("common_clock"),
        .WRITE_MODE("write_first"),
        .MEMORY_PRIMITIVE("auto")
    ) U0_table (
        .clk_a    (clk),
        .en_a_i   ('1),
        .we_a_i   (update_i & ~wpc_i[2]),
        .addr_a_i (index_w),
        .data_a_i ({1'b1, tag_w, bta_i, br_type_i}),
        .clk_b    (clk),
        .rstb_n   (rst_n),
        .en_b_i   ('1),
        .addr_b_i (index_r),
        .data_b_o ({valid[0], tag[0], bta[0], br_type[0]})
    );

    SimpleDualPortRAM #(
        .DATA_DEPTH(1 << (ADDR_WIDTH - 1)),
        .DATA_WIDTH(ENTRY_WIDTH),
        .BYTE_WRITE_WIDTH(ENTRY_WIDTH),
        .CLOCKING_MODE("common_clock"),
        .WRITE_MODE("write_first"),
        .MEMORY_PRIMITIVE("auto")
    ) U1_table (
        .clk_a    (clk),
        .en_a_i   ('1),
        .we_a_i   (update_i & wpc_i[2]),
        .addr_a_i (index_w),
        .data_a_i ({1'b1, tag_w, bta_i, br_type_i}),
        .clk_b    (clk),
        .rstb_n   (rst_n),
        .en_b_i   ('1),
        .addr_b_i (index_r),
        .data_b_o ({valid[1], tag[1], bta[1], br_type[1]})
    );


    // 1 clk delay for rpc
    logic [31: 2] pre_pc;
    logic [TAG_WIDTH - 1:0] pre_tag;

    always @(posedge clk ) begin
        if (~rst_n) begin
            pre_pc <= 0;
        end else begin
            pre_pc <= rpc_i;
        end
    end

    assign pre_tag = mktag(pre_pc);

    // output
    logic hit [1:0];
    assign hit[0] = valid[0] & tag[0] == pre_tag;
    assign hit[1] = valid[1] & tag[1] == pre_tag;
    assign bta_o[0] = hit[0] ? bta[0] : {pre_pc[31:3] + 29'd1, 1'b0};
    assign br_type_o[0] = hit[0] ? br_type[0] : `PC_RELATIVE;
    
    assign bta_o[1] = hit[1] ? bta[1] : {pre_pc[31:3] + 29'd1, 1'b0};
    assign br_type_o[1] = hit[1] ? br_type[1] : `PC_RELATIVE;

endmodule : BranchTargetBuffer
