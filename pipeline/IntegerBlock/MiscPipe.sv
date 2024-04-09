// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : MiscPipe.sv
// Create  : 2024-03-20 17:02:30
// Revise  : 2024-03-30 21:31:35
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
`include "Decoder.svh"
`include "common.svh"
`include "Pipeline.svh"

module MiscPipe (
  input clk,    // Clock
  input rst_n,  // Asynchronous reset active low
  input flush_i,
  /* exe */
  input MiscExeSt exe_i,
  output logic ready_o,
  /* other exe io */
  // tlb search
  output logic tlbsrch_valid_o,
  input logic tlbsrch_found_i,
  input logic [$clog2(`TLB_ENTRY_NUM) - 1:0] tlbsrch_idx_i,
  // tlb read
  output logic tlbrd_valid_o,
  input logic [31:0] tlbehi_i ,
  input logic [31:0] tlbelo0_i,
  input logic [31:0] tlbelo1_i,
  input logic [31:0] tlbidx_i ,
  input logic [ 9:0] tlbasid_i,
  // csr read
  input logic [31:0] csr_rdata_i,
  input logic [63:0] timer_64_i,
  input logic [31:0] timer_id_i,
  /* commit */
  output MiscWbSt wb_o,
  input wb_ready_i
);

  logic s0_ready, s1_ready, s2_ready;
/*================================== stage0 ===================================*/
  // regfile comb输出 数据缓存一拍
  // 执行tlb search
  always_comb begin
    s0_ready = s1_ready;
    ready_o = s0_ready;
    tlbsrch_valid_o = exe_i.base.valid & exe_i.misc_oc.instr_type == `PRIV_INSTR & exe_i.misc_oc.priv_op == `PRIV_TLBSRCH;
    tlbrd_valid_o = exe_i.base.valid & exe_i.misc_oc.instr_type == `PRIV_INSTR & exe_i.misc_oc.priv_op == `PRIV_TLBRD;
  end

/*================================== stage1 ===================================*/
  MiscExeSt s1_exe;
  logic [31:0] s1_csr_rdata;
  logic [63:0] s1_timer_64;
  logic [31:0] s1_timer_id;

  always_comb begin
    // 没有要处理的任务 或 信息可以向下一级流动
    // 没有需握手的FU
    s1_ready = s2_ready | ~s1_exe.base.valid;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n || flush_i) begin
      s1_exe <= '0;
      s1_csr_rdata <= '0;
      s1_timer_64 <= '0;
      s1_timer_id <= '0;
    end else begin
      if (s1_ready) begin
        s1_exe <= exe_i;
        s1_csr_rdata <= csr_rdata_i;
        s1_timer_64 <= timer_64_i;
        s1_timer_id <= timer_id_i;
      end
    end
  end

  // 处理分支或特权指令
  // 缩短一点代码长度
  InstType instr_type;
  PrivOpType priv_op;
  logic [31:0] src0, src1;
  logic [31:0] imm;
  // csr
  logic csr_we;
  logic [13:0] csr_waddr;
  logic [31:0] csr_wdata;
  // tlb
  logic [9:0] invtlb_asid;
  // branch
  logic br_taken;
  logic br_redirect;
  logic [`PROC_VALEN - 1:0] br_target;
  // cacop 或 invtlb
  logic [`PROC_VALEN - 1:0] vaddr;
  // write back
  logic cmt_we;  // 需要写回
  logic [31:0] cmt_wdata;

  always_comb begin
    instr_type = s1_exe.misc_oc.instr_type;
    priv_op = s1_exe.misc_oc.priv_op;
    src0 = s1_exe.base.src0;
    src1 = s1_exe.base.src1;
    imm = s1_exe.base.imm;

    csr_we = priv_op == `PRIV_CSR_WRITE | priv_op == `PRIV_CSR_XCHG;
    csr_waddr = imm[13:0];
    csr_wdata = priv_op == `PRIV_CSR_XCHG ? src0 & src1 : src0;

    invtlb_asid = src0[9:0];

    vaddr = priv_op == `PRIV_CACOP ? src0 + imm : src1;

    cmt_we = (instr_type == `BR_INSTR & s1_exe.misc_oc.br_link) | 
             (instr_type == `PRIV_INSTR & (priv_op == `PRIV_CSR_READ | 
                                           priv_op == `PRIV_CSR_XCHG |
                                           priv_op == `PRIV_CSR_WRITE));
    cmt_wdata = instr_type == `BR_INSTR   ? s1_exe.pc + 4 :
                instr_type == `PRIV_INSTR ? s1_csr_rdata : '0;
  end
  
  BranchUnit U_BranchUnit
  (
    .signed_i    (s1_exe.misc_oc.signed_op),
    .pc_i        (s1_exe.base.pc),
    .npc_i       (s1_exe.base.npc),
    .imm_i       (s1_exe.base.imm),
    .src0_i      (s1_exe.base.src0),
    .src1_i      (s1_exe.base.src1),
    .indirect_i  (s1_exe.misc_oc.br_indirect),
    .branch_op_i (s1_exe.misc_oc.branch_op),
    // output
    .redirect_o  (br_redirect),
    .target_o    (br_target),
    .taken_o     (br_taken)
  );

/*================================== stage2 ===================================*/
  always_comb begin
    // 没有要处理的任务 或 信息可以向下一级流动
    s2_ready = ~wb_o.base.valid | wb_ready_i;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n || flush_i) begin
      wb_o <= 0;
    end else begin
      if (s2_ready) begin
        wb_o.PRIV_INSTR <= s1_exe.misc_oc.instr_type == `PRIV_INSTR;
        wb_o.br_inst <= s1_exe.misc_oc.instr_type == `BR_INSTR;

        wb_o.base.valid <= s1_exe.base.valid;
        wb_o.base.we <= cmt_we;
        wb_o.base.wdata <= cmt_wdata;
        wb_o.base.pdest <= s1_exe.base.pdest;
        wb_o.base.rob_idx <= s1_exe.base.rob_idx;

        wb_o.priv_op <= s1_exe.misc_oc.priv_op;
        wb_o.cache_op <= s1_exe.misc_oc.cache_op;

        wb_o.csr_we <= csr_we;
        wb_o.csr_waddr <= csr_waddr;
        wb_o.csr_wdata <= csr_wdata;

        wb_o.invtlb_asid <= invtlb_asid;
        wb_o.invtlb_op <= s1_exe.base.imm[4:0];
        wb_o.tlbsrch_found <= tlbsrch_found_i;
        wb_o.tlbsrch_idx <= tlbsrch_idx_i;
        wb_o.tlbrd_ehi <= tlbehi_i;
        wb_o.tlbrd_elo0 <= tlbelo0_i;
        wb_o.tlbrd_elo1 <= tlbelo1_i;
        wb_o.tlbrd_idx <= tlbidx_i;
        wb_o.tlbrd_asid <= tlbasid_i;

        wb_o.vaddr <= vaddr;

        wb_o.br_taken <= br_taken;
        wb_o.br_redirect <= br_redirect;
        wb_o.br_target <= br_target;
`ifdef DEBUG
        wb_o.csr_rdata_diff <= s1_csr_rdata;
        wb_o.timer_64_diff <= s1_timer_64;
`endif
      end
    end
  end
  

endmodule : MiscPipe

