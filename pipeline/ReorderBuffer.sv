// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : ReorderBuffer.sv
// Create  : 2024-03-13 20:18:54
// Revise  : 2024-03-31 15:18:34
// Description :
//   ...
//   ...
// Parameter   :
//   ...
//   ...
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// xx-xx-xx |            |     0.1     |    Original Version
// ...
// ==============================================================================
`include "common.svh"
`include "config.svh"
`include "Decoder.svh"
`include "ReorderBuffer.svh"

module ReorderBuffer (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input flush_i,
  input RobAllocReqSt alloc_req,
  output RobAllocRspSt alloc_rsp,
  input RobCmtReqSt [`COMMIT_WIDTH - 1:0] cmt_req,
  output RobCmtRspSt [`COMMIT_WIDTH - 1:0] cmt_rsp,
  output RobRetireSt retire_o,
  /* other exe io */
  output logic [$clog2(`ROB_DEPTH) - 1:0] oldest_rob_idx_o
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

/*=============================== Signal Define ===============================*/
  // reg
  RobEntrySt [`ROB_DEPTH - 1:0] rob, rob_n;
  logic [$clog2(`ROB_DEPTH):0] head_ptr, tail_ptr, head_ptr_n, tail_ptr_n;
  logic [$clog2(`ROB_DEPTH):0] cnt, cnt_n;
  // wire
  logic [$clog2(`ROB_DEPTH) - 1:0] head_idx, tail_idx;
  logic [$clog2(`DECODE_WIDTH):0] alloc_cnt;
  logic [`DECODE_WIDTH - 1:0][$clog2(`ROB_DEPTH):0] alloc_ptr;  // {pos, rob_idx}

  logic [$clog2(`COMMIT_WIDTH):0] cmt_cnt;
  logic [$clog2(`RETIRE_WIDTH):0] retire_cnt;
  logic [`RETIRE_WIDTH - 1:0] redirect_mask;  // 重定向后面的指令不允许退休
  logic [`RETIRE_WIDTH - 1:0] exc_mask;  // 异常后面的指令不允许退休
  logic [`RETIRE_WIDTH - 1:0] pre_exist_br;
  logic [`RETIRE_WIDTH - 1:0] br_mask;  // 仅允许一条分支指令退休
  logic [`RETIRE_WIDTH - 1:0] st_mask;  // 仅最旧的store指令可以退休
  logic [`RETIRE_WIDTH - 1:0] retire_mask;  // 屏蔽后续指令的退休
  logic [`RETIRE_WIDTH - 1:0] retire_valid;  // 本次可退休得指令

/*================================= W/R Ctrl ==================================*/
  always_comb begin
    rob_n = rob;
    head_ptr_n = head_ptr;
    tail_ptr_n = tail_ptr;
    cnt_n = cnt;
    head_idx = head_ptr[$clog2(`ROB_DEPTH) - 1:0];
    tail_idx = tail_ptr[$clog2(`ROB_DEPTH) - 1:0];
    /* alloc logic */
    alloc_cnt = $countones(alloc_req.valid);
    alloc_rsp.ready = cnt <= `ROB_DEPTH - `DECODE_WIDTH;
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      alloc_ptr[i] = tail_ptr + i;
      alloc_rsp.position_bit[i] = alloc_ptr[$clog2(`ROB_DEPTH)];
      alloc_rsp.rob_idx[i] = alloc_ptr[$clog2(`ROB_DEPTH) - 1:0];
    end
    if (alloc_rsp.ready) begin
      tail_ptr_n = tail_ptr + alloc_cnt;
      cnt_n = cnt + alloc_cnt;
    end
    /* cmt logic */
    cmt_cnt = '0;
    for (int i = 0; i < `COMMIT_WIDTH; i++) begin
      if (cmt_req[i].valid) begin
        cmt_cnt = cmt_cnt + 1'b1;
        rob_n[cmt_req[i].rob_idx].complete = 1'b1;
        rob_n[cmt_req[i].rob_idx].exception = cmt_req[i].exception;
        rob_n[cmt_req[i].rob_idx].ecode = cmt_req[i].ecode;
        rob_n[cmt_req[i].rob_idx].sub_ecode = cmt_req[i].sub_ecode;
        rob_n[cmt_req[i].rob_idx].redirect = cmt_req[i].redirect;
        rob_n[cmt_req[i].rob_idx].br_target = cmt_req[i].br_target;
        rob_n[cmt_req[i].rob_idx].error_vaddr = cmt_req[i].error_vaddr;
      end
      cmt_rsp[i].ready = '1;
    end

    /* retire logic */
    retire_cnt = '0;
    pre_exist_br[0] = '0;
    for (int i = 1; i < `RETIRE_WIDTH; i++) begin
      pre_exist_br[i] = pre_exist_br[i - 1] | (rob[i - 1].instr_type == `BR_INST);
    end
    redirect_mask[0] = '1;
    exc_mask[0] = '1;
    br_mask[0] = '1;
    st_mask[0] = '1;
    for (int i = 1; i < `RETIRE_WIDTH; i++) begin
      redirect_mask[i] = redirect_mask[i - 1] & ~rob[head_idx + i].redirect;
      exc_mask[i] = exc_mask[i - 1] & ~rob[head_idx + i].exception;
      br_mask[i] = br_mask[i - 1] & (~pre_exist_br[i] |
                  (pre_exist_br[i] & rob[head_idx + i].instr_type != `BR_INST));
      st_mask[i] = st_mask[i - 1] &
                 ~(rob[head_idx + i].instr_type == `MEM_INST &
                   rob[head_idx + i].mem_type == `MEM_STORE);
    end
    retire_mask = br_mask & redirect_mask & exc_mask;

    retire_valid[0] = rob[head_idx].complete;
    for (int i = 0; i < `RETIRE_WIDTH; i++) begin
      retire_valid[i] = retire_valid[i - 1] & redirect_mask[i];
    end

    retire_cnt = $countones(retire_valid);
    head_ptr_n = head_ptr + retire_cnt;

    retire_o.valid = retire_valid;
    for (int i = 0; i < `RETIRE_WIDTH; i++) begin
      retire_o.rob_entry[i] = rob[head_idx + i];
    end

    /* other logic */
    oldest_rob_idx_o = rob[head_idx];
  end



  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n || flush_i) begin
      head_ptr <= 0;
      tail_ptr <= 0;
      cnt <= 0;
    end else begin
      head_ptr <= head_ptr_n;
      tail_ptr <= tail_ptr_n;
      cnt <= cnt_n;
    end
  end



endmodule : ReorderBuffer
