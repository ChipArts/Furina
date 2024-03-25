// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : MemoryBlock.sv
// Create  : 2024-03-17 22:34:12
// Revise  : 2024-03-25 17:45:37
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

`include "config.svh"
`include "common.svh"
`include "Decoder.svh"
`include "Pipeline.svh"
`include "MemoryManagementUnit.svh"

module MemoryBlock (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  /* exe */
  input MemExeSt exe_i,
  output logic exe_ready_o,
  /* other exe io */
  output MmuAddrTransReqSt mmu_req,
  input MmuAddrTransRspSt mmu_rsp,
  input [$clog2(`ROB_DEPTH) - 1:0] oldest_rob_idx_i,
  AXI4.Master axi4_mst,
  /* commit */
  // MISC
  output MemCmtSt cmt_o,
  input cmt_ready_i
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);
  logic s0_ready, s1_ready;

/*================================== stage0 ===================================*/
  // regfile comb输出 数据缓存一拍
  always_comb begin
    s0_ready = s1_ready;
  end


/*================================== stage1 ===================================*/
  MemExeSt s1_exe;

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      s1_exe <= '0;
    end else begin
      if (s1_ready) begin
        s1_exe <= exe_i;
      end
    end
  end

  DCacheReqSt dcache_req;
  DCacheRspSt dcache_rsp;

  always_comb begin
    s1_ready = dcache_rsp.ready | ~s1_exe.base.valid;

    dcache_req.valid = s1_exe.base.valid;
    dcache_req.ready = '1;
    dcache_req.vaddr = s1_exe.base.src0 + s1_exe.imm;
    dcache_req.wdata = s1_exe.base.src1;
    dcache_req.rob_idx = s1_exe.base.rob_idx;
    dcache_req.align_op = s1_exe.mem_oc.align_op;
    dcache_req.mem_type = s1_exe.mem_oc.mem_type;
  end

  // DCache视为一个多周期的模块
  DCache inst_DCache
  (
    .clk              (clk),
    .a_rst_n          (rst_n),
    .flush_i          (flush_i),
    .req              (dcache_req),
    .rsp              (dcache_rsp),
    .mmu_req          (mmu_req),
    .mmu_rsp          (mmu_rsp),
    .oldest_rob_idx_i (oldest_rob_idx_i),
    .axi4_mst         (axi4_mst)
  );

/*================================== stage2 ===================================*/
  // 产生commit信息
  always_comb begin
    cmt_o.base.valid = dcache_rsp.valid;
    cmt_o.base.we = dcache_rsp.mem_type == `MEM_LOAD;
    cmt_o.base.wdata = dcache_rsp.rdata;
    cmt_o.base.rob_idx = dcache_rsp.rob_idx;
    cmt_o.base.pdest = dcache_rsp.pdest;
    cmt_o.base.exception = dcache_rsp.exception;
    cmt_o.base.ecode = dcache_rsp.ecode;
  end


endmodule : MemoryBlock

