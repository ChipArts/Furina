// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : MemoryBlock.sv
// Create  : 2024-03-17 22:34:12
// Revise  : 2024-03-27 20:36:24
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
`include "Cache.svh"
`include "Pipeline.svh"
`include "MemoryManagementUnit.svh"

module MemoryBlock (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input flush_i,
  /* exe */
  input MemExeSt exe_i,
  output logic exe_ready_o,
  /* other exe io */
  output MmuAddrTransReqSt addr_trans_req,
  input MmuAddrTransRspSt addr_trans_rsp,
  // to from icache
  output IcacopReqSt icacop_req,
  input IcacopRspSt icacop_rsp,
  AXI4.Master axi4_mst,
  /* wirte back */
  output MemWbSt wb_o,
  input logic wb_ready_i
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);
  logic s0_ready, s1_ready, s2_ready;

/*================================== stage0 ===================================*/
  // regfile comb输出 数据缓存一拍
  always_comb begin
    s0_ready = s1_ready;
    exe_ready_o = s0_ready;
  end


/*================================== stage1 ===================================*/
  MemExeSt s1_exe;

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n || flush_i) begin
      s1_exe <= '0;
    end else begin
      if (s1_ready) begin
        s1_exe <= exe_i;
      end
    end
  end

  DCacheReqSt dcache_req;
  DCacheRspSt dcache_rsp;


  logic dcache_busy_o;
  MmuAddrTransReqSt dcache_addr_trans_req;
  MmuAddrTransRspSt dcache_addr_trans_rsp;

  always_comb begin
    s1_ready = (dcache_req.valid & dcache_rsp.ready) | 
               (icacop_req.valid & icacop_rsp.ready) | 
               ~s1_exe.base.valid;

    dcache_req.valid = s1_exe.base.valid & 
                      ~(s1_exe.mem_oc.mem_op == `MEM_CACOP & s1_exe.code[1:0] == 2'b00) & 
                      ~icacop_rsp.valid;  // icacop_rsp.valid 相当于 icache的busy信号
    dcache_req.ready = s2_ready;  // 确保store在成为最旧指令时写回
    dcache_req.vaddr = s1_exe.base.src0 + (s1_exe.base.imm << 2);
    dcache_req.wdata = s1_exe.base.src1;
    dcache_req.rob_idx = s1_exe.base.rob_idx;
    dcache_req.align_op = s1_exe.mem_oc.align_op;
    dcache_req.mem_op = s1_exe.mem_oc.mem_op;
    dcache_req.micro = s1_exe.mem_oc.micro_op;
    dcache_req.pdest = s1_exe.base.pdest;
    dcache_req.pdest_valid = s1_exe.base.pdest_valid;
    dcache_req.llbit = s1_exe.llbit;
    dcache_req.code = s1_exe.code;

    icacop_req.valid = s1_exe.base.valid & 
                       s1_exe.mem_oc.mem_op == `MEM_CACOP & s1_exe.code[1:0] == 2'b00 & 
                       ~dcache_busy_o;
    icacop_req.ready = s2_ready;
    
    addr_trans_req = dcache_addr_trans_req;
    dcache_addr_trans_rsp = addr_trans_rsp;
  end

  // DCache视为一个多周期的模块
  DCache inst_DCache
  (
    .clk              (clk),
    .a_rst_n          (rst_n),
    .flush_i          (flush_i),
    .dcache_req       (dcache_req),
    .dcache_rsp       (dcache_rsp),
    .addr_trans_req   (dcache_addr_trans_req),
    .addr_trans_rsp   (dcache_addr_trans_rsp),
    .busy_o           (dcache_busy_o),
    .axi4_mst         (axi4_mst)
  );

/*================================== stage2 ===================================*/
  // 产生commit信息
  always_comb begin
    wb_o = '0;
    s2_ready = wb_ready_i;
    // 由于busy信号控制，icache和dcache的响应互斥
    if (icacop_rsp.valid) begin
      wb_o.base.valid = icacop_rsp.valid;
      wb_o.base.we = '0;
      wb_o.base.wdata = '0;
      wb_o.base.rob_idx = icacop_rsp.rob_idx;
      wb_o.base.pdest = '0;
      wb_o.base.excp = icacop_rsp.excp;
      wb_o.vaddr = icacop_rsp.vaddr;
      wb_o.mem_op = `MEM_CACOP;
      wb_o.micro = '0;
      wb_o.llbit = '0;
      wb_o.icacop = '1;
      wb_o.paddr = '0;
      wb_o.store_data = '0;
    end else if (dcache_rsp.valid) begin
      wb_o.base.valid = dcache_rsp.valid;
      wb_o.base.we = dcache_rsp.pdest_valid & ( dcache_rsp.mem_op == `MEM_LOAD | dcache_rsp.micro);
      wb_o.base.wdata = dcache_rsp.mem_op == `MEM_LOAD ? dcache_rsp.rdata : {31'd0, dcache_rsp.llbit};
      wb_o.base.rob_idx = dcache_rsp.rob_idx;
      wb_o.base.pdest = dcache_rsp.pdest;
      wb_o.base.excp = dcache_rsp.excp;
      wb_o.vaddr = dcache_rsp.vaddr;
      wb_o.mem_op = dcache_rsp.mem_op;
      wb_o.micro = dcache_rsp.micro;
      wb_o.llbit = dcache_rsp.llbit;
      wb_o.paddr = dcache_rsp.paddr;
      wb_o.icacop = '0;
      wb_o.store_data = dcache_rsp.store_data;
    end
  end


endmodule : MemoryBlock

