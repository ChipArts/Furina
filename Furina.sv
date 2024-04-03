// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Furina.sv
// Create  : 2024-04-01 18:03:30
// Revise  : 2024-04-01 18:03:30
// Description :
//   top module
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

module Furina (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input logic [7:0] interrupt, 
  AXI4.Master axi4_mst
);

  AXI4 #(
    .AXI_ADDR_WIDTH(`PROC_PALEN),
    .AXI_DATA_WIDTH(32),
    .AXI_ID_WIDTH  (4),
    .AXI_USER_WIDTH(1),
  ) axi4;

  axi4.Master icache_axi4_mst;
  axi4.Master dcache_axi4_mst;

  Pipeline inst_Pipeline
  (
    .clk             (clk),
    .a_rst_n         (a_rst_n),
    .interrupt       (interrupt),
    .icache_axi4_mst (icache_axi4_mst),
    .dcache_axi4_mst (dcache_axi4_mst)
  );

  axi_interconnect_wrap_2x1 #(
    .DATA_WIDTH(32),
    .ADDR_WIDTH(`PROC_PALEN),
    .STRB_WIDTH(32 / 8),
    .ID_WIDTH (4),
    .AWUSER_ENABLE (0),
    .AWUSER_WIDTH (1),
    .WUSER_ENABLE (0),
    .WUSER_WIDTH (1),
    .BUSER_ENABLE (0),
    .BUSER_WIDTH (1),
    .ARUSER_ENABLE (0),
    .ARUSER_WIDTH (1),
    .RUSER_ENABLE (0),
    .RUSER_WIDTH (1),
    .FORWARD_ID (0),
    .M_REGIONS (1),
    .M00_BASE_ADDR (0),
    .M00_ADDR_WIDTH ({1{32'd32}}),
    .M00_CONNECT_READ (2'b11),
    .M00_CONNECT_WRITE (2'b10),  // ICache 不需要写回
    .M00_SECURE (1'b0)
  ) inst_axi_interconnect_wrap_2x1 (
    .clk              (clk),
    .rst              (a_rst_n),
    .s00_axi_awid     (icache_axi4_mst.aw_id),
    .s00_axi_awaddr   (icache_axi4_mst.aw_addr),
    .s00_axi_awlen    (icache_axi4_mst.aw_len),
    .s00_axi_awsize   (icache_axi4_mst.aw_size),
    .s00_axi_awburst  (icache_axi4_mst.aw_burst),
    .s00_axi_awlock   (icache_axi4_mst.aw_lock),
    .s00_axi_awcache  (icache_axi4_mst.aw_cache),
    .s00_axi_awprot   (icache_axi4_mst.aw_prot),
    .s00_axi_awqos    (icache_axi4_mst.aw_qos),
    .s00_axi_awuser   (icache_axi4_mst.aw_user),
    .s00_axi_awvalid  (icache_axi4_mst.aw_valid),
    .s00_axi_awready  (icache_axi4_mst.aw_ready),
    .s00_axi_wdata    (icache_axi4_mst.w_data),
    .s00_axi_wstrb    (icache_axi4_mst.w_strb),
    .s00_axi_wlast    (icache_axi4_mst.w_last),
    .s00_axi_wuser    (icache_axi4_mst.w_user),
    .s00_axi_wvalid   (icache_axi4_mst.w_valid),
    .s00_axi_wready   (icache_axi4_mst.w_ready),
    .s00_axi_bid      (icache_axi4_mst.b_id),
    .s00_axi_bresp    (icache_axi4_mst.b_resp),
    .s00_axi_buser    (icache_axi4_mst.b_user),
    .s00_axi_bvalid   (icache_axi4_mst.b_valid),
    .s00_axi_bready   (icache_axi4_mst.b_ready),
    .s00_axi_arid     (icache_axi4_mst.ar_id),
    .s00_axi_araddr   (icache_axi4_mst.ar_addr),
    .s00_axi_arlen    (icache_axi4_mst.ar_len),
    .s00_axi_arsize   (icache_axi4_mst.ar_size),
    .s00_axi_arburst  (icache_axi4_mst.ar_burst),
    .s00_axi_arlock   (icache_axi4_mst.ar_lock),
    .s00_axi_arcache  (icache_axi4_mst.ar_cache),
    .s00_axi_arprot   (icache_axi4_mst.ar_prot),
    .s00_axi_arqos    (icache_axi4_mst.ar_qos),
    .s00_axi_aruser   (icache_axi4_mst.ar_user),
    .s00_axi_arvalid  (icache_axi4_mst.ar_valid),
    .s00_axi_arready  (icache_axi4_mst.ar_ready),
    .s00_axi_rid      (icache_axi4_mst.r_id),
    .s00_axi_rdata    (icache_axi4_mst.r_data),
    .s00_axi_rresp    (icache_axi4_mst.r_resp),
    .s00_axi_rlast    (icache_axi4_mst.r_last),
    .s00_axi_ruser    (icache_axi4_mst.r_user),
    .s00_axi_rvalid   (icache_axi4_mst.r_valid),
    .s00_axi_rready   (icache_axi4_mst.r_ready),

    .s01_axi_awid     (dcache_axi4_mst.aw_id),
    .s01_axi_awaddr   (dcache_axi4_mst.aw_addr),
    .s01_axi_awlen    (dcache_axi4_mst.aw_len),
    .s01_axi_awsize   (dcache_axi4_mst.aw_size),
    .s01_axi_awburst  (dcache_axi4_mst.aw_burst),
    .s01_axi_awlock   (dcache_axi4_mst.aw_lock),
    .s01_axi_awcache  (dcache_axi4_mst.aw_cache),
    .s01_axi_awprot   (dcache_axi4_mst.aw_prot),
    .s01_axi_awqos    (dcache_axi4_mst.aw_qos),
    .s01_axi_awuser   (dcache_axi4_mst.aw_user),
    .s01_axi_awvalid  (dcache_axi4_mst.aw_valid),
    .s01_axi_awready  (dcache_axi4_mst.aw_ready),
    .s01_axi_wdata    (dcache_axi4_mst.w_data),
    .s01_axi_wstrb    (dcache_axi4_mst.w_strb),
    .s01_axi_wlast    (dcache_axi4_mst.w_last),
    .s01_axi_wuser    (dcache_axi4_mst.w_user),
    .s01_axi_wvalid   (dcache_axi4_mst.w_valid),
    .s01_axi_wready   (dcache_axi4_mst.w_ready),
    .s01_axi_bid      (dcache_axi4_mst.b_id),
    .s01_axi_bresp    (dcache_axi4_mst.b_resp),
    .s01_axi_buser    (dcache_axi4_mst.b_user),
    .s01_axi_bvalid   (dcache_axi4_mst.b_valid),
    .s01_axi_bready   (dcache_axi4_mst.b_ready),
    .s01_axi_arid     (dcache_axi4_mst.ar_id),
    .s01_axi_araddr   (dcache_axi4_mst.ar_addr),
    .s01_axi_arlen    (dcache_axi4_mst.ar_len),
    .s01_axi_arsize   (dcache_axi4_mst.ar_size),
    .s01_axi_arburst  (dcache_axi4_mst.ar_burst),
    .s01_axi_arlock   (dcache_axi4_mst.ar_lock),
    .s01_axi_arcache  (dcache_axi4_mst.ar_cache),
    .s01_axi_arprot   (dcache_axi4_mst.ar_prot),
    .s01_axi_arqos    (dcache_axi4_mst.ar_qos),
    .s01_axi_aruser   (dcache_axi4_mst.ar_user),
    .s01_axi_arvalid  (dcache_axi4_mst.ar_valid),
    .s01_axi_arready  (dcache_axi4_mst.ar_ready),
    .s01_axi_rid      (dcache_axi4_mst.r_id),
    .s01_axi_rdata    (dcache_axi4_mst.r_data),
    .s01_axi_rresp    (dcache_axi4_mst.r_resp),
    .s01_axi_rlast    (dcache_axi4_mst.r_last),
    .s01_axi_ruser    (dcache_axi4_mst.r_user),
    .s01_axi_rvalid   (dcache_axi4_mst.r_valid),
    .s01_axi_rready   (dcache_axi4_mst.r_ready),

    .m00_axi_awid     (axi4_mst.aw_id),
    .m00_axi_awaddr   (axi4_mst.aw_addr),
    .m00_axi_awlen    (axi4_mst.aw_len),
    .m00_axi_awsize   (axi4_mst.aw_size),
    .m00_axi_awburst  (axi4_mst.aw_burst),
    .m00_axi_awlock   (axi4_mst.aw_lock),
    .m00_axi_awcache  (axi4_mst.aw_cache),
    .m00_axi_awprot   (axi4_mst.aw_prot),
    .m00_axi_awqos    (axi4_mst.aw_qos),
    .m00_axi_awuser   (axi4_mst.aw_user),
    .m00_axi_awvalid  (axi4_mst.aw_valid),
    .m00_axi_awready  (axi4_mst.aw_ready),
    .m00_axi_wdata    (axi4_mst.w_data),
    .m00_axi_wstrb    (axi4_mst.w_strb),
    .m00_axi_wlast    (axi4_mst.w_last),
    .m00_axi_wuser    (axi4_mst.w_user),
    .m00_axi_wvalid   (axi4_mst.w_valid),
    .m00_axi_wready   (axi4_mst.w_ready),
    .m00_axi_bid      (axi4_mst.b_id),
    .m00_axi_bresp    (axi4_mst.b_resp),
    .m00_axi_buser    (axi4_mst.b_user),
    .m00_axi_bvalid   (axi4_mst.b_valid),
    .m00_axi_bready   (axi4_mst.b_ready),
    .m00_axi_arid     (axi4_mst.ar_id),
    .m00_axi_araddr   (axi4_mst.ar_addr),
    .m00_axi_arlen    (axi4_mst.ar_len),
    .m00_axi_arsize   (axi4_mst.ar_size),
    .m00_axi_arburst  (axi4_mst.ar_burst),
    .m00_axi_arlock   (axi4_mst.ar_lock),
    .m00_axi_arcache  (axi4_mst.ar_cache),
    .m00_axi_arprot   (axi4_mst.ar_prot),
    .m00_axi_arqos    (axi4_mst.ar_qos),
    .m00_axi_aruser   (axi4_mst.ar_user),
    .m00_axi_arvalid  (axi4_mst.ar_valid),
    .m00_axi_arready  (axi4_mst.ar_ready),
    .m00_axi_rid      (axi4_mst.r_id),
    .m00_axi_rdata    (axi4_mst.r_data),
    .m00_axi_rresp    (axi4_mst.r_resp),
    .m00_axi_rlast    (axi4_mst.r_last),
    .m00_axi_ruser    (axi4_mst.r_user),
    .m00_axi_rvalid   (axi4_mst.r_valid),
    .m00_axi_rready   (axi4_mst.r_ready)
  );

`ifdef DEBUG
  DifftestInstrCommit DifftestInstrCommit(
      .clock              (aclk           ),
      .coreid             (0              ),
      .index              (0              ),
      .valid              (cmt_valid      ),
      .pc                 (cmt_pc         ),
      .instr              (cmt_inst       ),
      .skip               (0              ),
      .is_TLBFILL         (cmt_tlbfill_en ),
      .TLBFILL_index      (cmt_rand_index ),
      .is_CNTinst         (cmt_cnt_inst   ),
      .timer_64_value     (cmt_timer_64   ),
      .wen                (cmt_wen        ),
      .wdest              (cmt_wdest      ),
      .wdata              (cmt_wdata      ),
      .csr_rstat          (cmt_csr_rstat_en),
      .csr_data           (cmt_csr_data   )
  );

  DifftestExcpEvent DifftestExcpEvent(
      .clock              (aclk           ),
      .coreid             (0              ),
      .excp_valid         (cmt_excp_flush ),
      .eret               (cmt_ertn       ),
      .intrNo             (csr_estat_diff_0[12:2]),
      .cause              (cmt_csr_ecode  ),
      .exceptionPC        (cmt_pc         ),
      .exceptionInst      (cmt_inst       )
  );

  DifftestTrapEvent DifftestTrapEvent(
      .clock              (aclk           ),
      .coreid             (0              ),
      .valid              (trap           ),
      .code               (trap_code      ),
      .pc                 (cmt_pc         ),
      .cycleCnt           (cycleCnt       ),
      .instrCnt           (instrCnt       )
  );

  DifftestStoreEvent DifftestStoreEvent(
      .clock              (aclk           ),
      .coreid             (0              ),
      .index              (0              ),
      .valid              (cmt_inst_st_en ),
      .storePAddr         (cmt_st_paddr   ),
      .storeVAddr         (cmt_st_vaddr   ),
      .storeData          (cmt_st_data    )
  );

  DifftestLoadEvent DifftestLoadEvent(
      .clock              (aclk           ),
      .coreid             (0              ),
      .index              (0              ),
      .valid              (cmt_inst_ld_en ),
      .paddr              (cmt_ld_paddr   ),
      .vaddr              (cmt_ld_vaddr   )
  );

  DifftestCSRRegState DifftestCSRRegState(
      .clock              (aclk               ),
      .coreid             (0                  ),
      .crmd               (csr_crmd_diff_0    ),
      .prmd               (csr_prmd_diff_0    ),
      .euen               (0                  ),
      .ecfg               (csr_ectl_diff_0    ),
      .estat              (csr_estat_diff_0   ),
      .era                (csr_era_diff_0     ),
      .badv               (csr_badv_diff_0    ),
      .eentry             (csr_eentry_diff_0  ),
      .tlbidx             (csr_tlbidx_diff_0  ),
      .tlbehi             (csr_tlbehi_diff_0  ),
      .tlbelo0            (csr_tlbelo0_diff_0 ),
      .tlbelo1            (csr_tlbelo1_diff_0 ),
      .asid               (csr_asid_diff_0    ),
      .pgdl               (csr_pgdl_diff_0    ),
      .pgdh               (csr_pgdh_diff_0    ),
      .save0              (csr_save0_diff_0   ),
      .save1              (csr_save1_diff_0   ),
      .save2              (csr_save2_diff_0   ),
      .save3              (csr_save3_diff_0   ),
      .tid                (csr_tid_diff_0     ),
      .tcfg               (csr_tcfg_diff_0    ),
      .tval               (csr_tval_diff_0    ),
      .ticlr              (csr_ticlr_diff_0   ),
      .llbctl             (csr_llbctl_diff_0  ),
      .tlbrentry          (csr_tlbrentry_diff_0),
      .dmw0               (csr_dmw0_diff_0    ),
      .dmw1               (csr_dmw1_diff_0    )
  );

  DifftestGRegState DifftestGRegState(
      .clock              (aclk       ),
      .coreid             (0          ),
      .gpr_0              (0          ),
      .gpr_1              (regs[1]    ),
      .gpr_2              (regs[2]    ),
      .gpr_3              (regs[3]    ),
      .gpr_4              (regs[4]    ),
      .gpr_5              (regs[5]    ),
      .gpr_6              (regs[6]    ),
      .gpr_7              (regs[7]    ),
      .gpr_8              (regs[8]    ),
      .gpr_9              (regs[9]    ),
      .gpr_10             (regs[10]   ),
      .gpr_11             (regs[11]   ),
      .gpr_12             (regs[12]   ),
      .gpr_13             (regs[13]   ),
      .gpr_14             (regs[14]   ),
      .gpr_15             (regs[15]   ),
      .gpr_16             (regs[16]   ),
      .gpr_17             (regs[17]   ),
      .gpr_18             (regs[18]   ),
      .gpr_19             (regs[19]   ),
      .gpr_20             (regs[20]   ),
      .gpr_21             (regs[21]   ),
      .gpr_22             (regs[22]   ),
      .gpr_23             (regs[23]   ),
      .gpr_24             (regs[24]   ),
      .gpr_25             (regs[25]   ),
      .gpr_26             (regs[26]   ),
      .gpr_27             (regs[27]   ),
      .gpr_28             (regs[28]   ),
      .gpr_29             (regs[29]   ),
      .gpr_30             (regs[30]   ),
      .gpr_31             (regs[31]   )
  );
`endif



endmodule : Furina
