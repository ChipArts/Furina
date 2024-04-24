// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : your name <your email>@email.com
// File    : DispatchQueue.sv
// Create  : 2024-04-18 18:26:24
// Revise  : 2024-04-24 20:53:57
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

`include "config.svh"
`include "Scheduler.svh"

module DispatchQueue #(
parameter
	int unsigned QUEUE_DEPTH = 8  // 确保这个数是2的幂
)(
	input logic clk,    // Clock
	input logic rst_n,  // Asynchronous reset active low
	input logic flush_i,
	input logic [`DECODE_WIDTH - 1:0] write_valid_i,  // 指令有效
	input DqEntrySt [`DECODE_WIDTH - 1:0] write_data_i,
	output logic write_ready_o,

	output logic [`DISPATCH_WIDTH - 1:0] read_valid_o,
	output DqEntrySt [`DISPATCH_WIDTH - 1:0] read_data_o,
	input  logic [`DISPATCH_WIDTH - 1:0] read_ready_i,

	// wake up
	input logic [`WB_WIDTH - 1:0] wb_i,
	input logic [`WB_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] wb_pdest_i
);


	DqEntrySt [QUEUE_DEPTH - 1:0] queue_q, queue_n;
	logic [$clog2(QUEUE_DEPTH) - 1:0] head_q, tail_q, head_n, tail_n;
	logic [$clog2(QUEUE_DEPTH + 1) - 1:0] cnt_q, cnt_n;

	logic [$clog2(QUEUE_DEPTH + 1) - 1:0] write_cnt, read_cnt;
	logic [`DECODE_WIDTH - 1:0][$clog2(QUEUE_DEPTH) - 1:0] wr_ptr;
	logic [`DISPATCH_WIDTH - 1:0][$clog2(QUEUE_DEPTH) - 1:0] rd_ptr;

	always_comb begin
		// default assign
		queue_n = queue_q;
		head_n = head_q;
		tail_n = tail_q;
		cnt_n = cnt_q;

		// wake up
		// 先进行唤醒，以防写入的内容被覆盖
		for (int i = 0; i < QUEUE_DEPTH; i++) begin
			for (int j = 0; j < `WB_WIDTH; j++) begin
				if (wb_i[j]) begin
					if (queue_q[i].src0 == wb_pdest_i[j]) begin
						queue_n[i].src0_ready = '1;
					end
					if (queue_q[i].src1 == wb_pdest_i[j]) begin
						queue_n[i].src1_ready = '1;
					end
				end
			end
		end


		for (int i = 0; i < `DISPATCH_WIDTH; i++) begin
			read_valid_o[i] = cnt_q > i;
		end

		write_cnt = $countones(write_valid_i);
		read_cnt  = $countones(read_ready_i & read_valid_o);

		write_ready_o = cnt_q <= QUEUE_DEPTH - `DECODE_WIDTH;

		if (write_ready_o) begin
			cnt_n = cnt_q + write_cnt - read_cnt;
		end else begin
			cnt_n = cnt_q - read_cnt;
		end

		// 写入
		for (int i = 0; i < `DECODE_WIDTH; i++) begin
			wr_ptr[i] = {tail_q + i}[$clog2(QUEUE_DEPTH) - 1:0];
			if (write_valid_i[i] && write_ready_o) begin
				queue_n[wr_ptr[i]] = write_data_i[i];
			end
		end

		// 读出
		for (int i = 0; i < `DISPATCH_WIDTH; i++) begin
			rd_ptr[i] = {head_q + i}[$clog2(QUEUE_DEPTH) - 1:0];
			read_data_o[i] = queue_q[rd_ptr[i]];
		end

		// 更新指针
		head_n = head_q + read_cnt;
		if (write_ready_o) begin
			tail_n = tail_q + write_cnt;
		end

	end


	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n || flush_i) begin
			queue_q <= 0;
			head_q <= 0;
			tail_q <= 0;
			cnt_q <= '0;
		end else begin
			queue_q <= queue_n;
			head_q <= head_n;
			tail_q <= tail_n;
			cnt_q <= cnt_n;
		end
	end

endmodule : DispatchQueue