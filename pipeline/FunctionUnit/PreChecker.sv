// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : your name <your email>@email.com
// File    : PreChecker.sv
// Create  : 2024-04-26 21:16:33
// Revise  : 2024-04-26 21:16:33
// Editor  : {EDITER}
// Version : {VERSION}
// Description :
//    fetch阶段的分支预测检查
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
`include "Decoder.svh"
`include "config.svh"

module PreChecker (
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	input [`FETCH_WIDTH - 1:0][31:0] pc_i,
	input [`FETCH_WIDTH - 1:0] valid_i,
	input logic [`FETCH_WIDTH - 1:0] is_branch_i,  // 标记是否是分支指令
	input BrInfoSt br_info_i,
	output logic redirect_o,  // 分支预测器重定向
	output logic [31:0] pc_o,
	output logic [31:0] target_o,
	output logic [$clog2(`RAS_STACK_DEPTH) - 1:0] ras_ptr_o,
	output logic [`FETCH_WIDTH - 1:0]  valid_o
);

	logic [`FETCH_WIDTH - 1:0] miss;
	always_comb begin
		for (int i = 0; i < `FETCH_WIDTH; i++) begin
			miss[i] = br_info_i.taken && (br_info_i.br_idx == pc_i[i][2]) && !is_branch_i[i] && valid_i[i];
		end
	end

	// debug
	// always_ff @(posedge clk or negedge rst_n) begin
	// 	if (fst_miss) begin
	// 		$display("front fst_miss: pc0_i: %x", pc0_i);
	// 		$display("predict_i: lpht: %d, npc: %x, taken: %d, br_type: %d, fsc: %d", predict0_i.lphr, {predict0_i.npc, 2'd0}, predict0_i.taken, predict0_i.br_type, predict0_i.fsc);
	// 	end
	// end

	always_comb begin : proc_output
		// defualt assign
		redirect_o = |miss;
		pc_o = '0;
		target_o = '0;
		ras_ptr_o = '0;
		valid_o = valid_i;

		for (int i = 0; i < `FETCH_WIDTH; i++) begin
			if (miss[i]) begin
				pc_o = pc_i[i];
				target_o = pc_i[i] + 'd4;
				ras_ptr_o = br_info_i.ras_ptr;
			end
		end

		for (int i = 1; i < `FETCH_WIDTH; i++) begin
			valid_o[i] = valid_i[i] & ~miss[i - 1];
		end
	end

endmodule : PreChecker