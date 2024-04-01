// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Pipeline.sv
// Create  : 2024-03-11 14:53:30
// Revise  : 2024-04-01 17:37:48
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
`include "ControlStatusRegister.svh"
`include "BranchPredictionUnit.svh"


module Pipeline (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input logic [7:0] interrupt,
  AXI4.Master icache_axi4_mst,
  AXI4.Master dcache_axi4_mst
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);
/*=============================== Signal Define ===============================*/
  logic glo_flush;  // 由退休的异常指令产生
  /* Branch Prediction Unit */
  BPU_ReqSt bpu_req_st;
  BPU_RspSt bpu_rsp_st;

  /* Fetch Address Queue */
  FAQ_PushReqSt faq_push_req_st;
  FAQ_PopReqSt faq_pop_req_st;
  FAQ_PushRspSt faq_push_rsp_st;
  FAQ_PopRspSt faq_pop_rsp_st;
  logic faq_flush;

  /* ICache */
  logic icache_flush_i;
  ICacheReqSt icache_req;
  ICacheRspSt icache_rsp;
  MmuAddrTransRspSt icache_addr_trans_rsp;
  MmuAddrTransReqSt icache_addr_trans_req;
  IcacopReqSt icacop_req;
  IcacopRspSt icacop_rsp;
  

  /* Instruction Buffer */
  logic ibuf_flush;
  logic ibuf_write_valid;
  logic ibuf_write_ready;
  logic [$clog2(`FETCH_WIDTH) - 1:0] ibuf_write_num;
  IbufDataSt [`FETCH_WIDTH - 1:0] ibuf_write_data;
  logic [$clog2(`DECODE_WIDTH) - 1:0] ibuf_read_num;
  logic [`DECODE_WIDTH - 1:0]ibuf_read_valid;
  logic ibuf_read_ready;
  IbufDataSt [`DECODE_WIDTH - 1:0] ibuf_read_data;

  /* Decoder */
  OptionCodeSt [`DECODE_WIDTH - 1:0] decoder_option_code;
  logic [`DECODE_WIDTH - 1:0][31:0] decoder_imm;
  logic [`DECODE_WIDTH - 1:0][4:0] decoder_src0;
  logic [`DECODE_WIDTH - 1:0][4:0] decoder_src1;
  logic [`DECODE_WIDTH - 1:0][4:0] decoder_dest;

  /* Scheduler */
  logic sche_flush;
  ScheduleReqSt sche_schedule_req;
  ScheduleRspSt sche_schedule_rsp;
  RobAllocReqSt sche_rob_alloc_req;
  RobAllocRspSt sche_rob_alloc_rsp;
  logic [`RETIRE_WIDTH - 1:0] sche_fl_free_valid_i;
  logic [`RETIRE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] sche_fl_free_preg_i;
  logic [31:0][$clog2(`PHY_REG_NUM) - 1:0] sche_arch_rat_i;
  logic [`COMMIT_WIDTH - 1:0] sche_cmt_pdest_valid_i;
  logic [`COMMIT_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] sche_cmt_pdest_i;
  MiscIssueSt sche_misc_issue;
  logic sche_misc_ready;
  AluIssueSt [1:0] sche_alu_issue;
  logic [1:0] sche_alu_ready;
  MduIssueSt sche_mdu_issue;
  logic sche_mdu_ready;
  MemIssueSt sche_mem_issue;
  logic sche_mem_ready;

  /* RegFile */
  // 每周期最多发射misc*1、alu*2、mdu*1、mem*1
  logic [4:0] rf_we;
  logic [4:0][$clog2(`PHY_REG_NUM) - 1:0] rf_waddr;
  logic [9:0][$clog2(`PHY_REG_NUM) - 1:0] rf_raddr;
  logic [4:0][31:0] rf_wdata;
  logic [9:0][31:0] rf_rdata;

  /* Integer Block */
  logic int_blk_flush;
  MiscExeSt int_blk_misc_exe;
  logic int_blk_misc_ready;
  AluExeSt [1:0] int_blk_alu_exe;
  logic [1:0] int_blk_alu_ready;
  MduExeSt int_blk_mdu_exe;
  logic int_blk_mdu_ready;
  
  logic [13:0] int_blk_csr_raddr;
  logic [31:0] int_blk_csr_rdata;
  logic int_blk_tlbsrch_valid_o;
  logic int_blk_tlbsrch_found_i;
  logic [$clog2(`TLB_ENTRY_NUM) - 1:0] int_blk_tlbsrch_idx_i;

  MiscCmtSt int_blk_misc_cmt;
  logic int_blk_misc_cmt_ready;
  AluCmtSt [1:0] int_blk_alu_cmt;
  logic [1:0] int_blk_alu_cmt_ready;
  MduCmtSt int_blk_mdu_cmt;
  logic int_blk_mdu_cmt_ready;

  /* Memory Block */
  logic mem_blk_flush;
  MemExeSt mem_blk_exe;
  logic mem_blk_exe_ready;
  MmuAddrTransReqSt mem_blk_mmu_req;
  MmuAddrTransRspSt mem_blk_mmu_rsp;
  logic [$clog2(`ROB_DEPTH) - 1:0] mem_blk_oldest_rob_idx_i;
  AXI4.Master mem_blk_axi4_mst;
  MemCmtSt mem_blk_cmt;
  logic mem_blk_cmt_ready;

  /* Reorder Buffer */
  logic rob_flush;
  RobAllocReqSt rob_alloc_req;
  RobAllocRspSt rob_alloc_rsp;
  RobCmtReqSt [`COMMIT_WIDTH - 1:0] rob_cmt_req;
  RobCmtRspSt [`COMMIT_WIDTH - 1:0] rob_cmt_rsp;
  RobRetireSt rob_retire_o;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_oldest_rob_idx_o;

  /* retire */
  RobRetireBcstSt retire_bcst_buffer;
  logic [31:0][$clog2(`PHY_REG_NUM) - 1:0] arch_rat_o;
  logic [`DECODE_WIDTH - 1:0] arch_rat_dest_valid_i;
  logic [`DECODE_WIDTH - 1:0][4:0] arch_rat_dest_i;
  logic [`DECODE_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] arch_rat_preg_i;

  /* Memory Management Unit */
  logic [9:0]  mmu_csr_asid_i;
  logic [31:0] mmu_csr_dmw0_i;
  logic [31:0] mmu_csr_dmw1_i;
  logic [1:0]  mmu_csr_datf_i;
  logic [1:0]  mmu_csr_datm_i;
  logic [1:0]  mmu_csr_plv_i;
  logic        mmu_csr_da_i;
  logic        mmu_csr_pg_i;
  MmuAddrTransReqSt mmu_inst_trans_req;
  MmuAddrTransRspSt mmu_inst_trans_rsp;
  MmuAddrTransReqSt mmu_data_trans_req;
  MmuAddrTransRspSt mmu_data_trans_rsp;
  logic                                mmu_tlbsrch_en_i;
  logic                                mmu_tlbsrch_found_o;
  logic [$clog2(`TLB_ENTRY_NUM) - 1:0] mmu_tlbsrch_idx_o;

  logic        mmu_tlbfill_en_i;
  logic        mmu_tlbwr_en_i;
  logic [ 4:0] mmu_rand_index_i;
  logic [31:0] mmu_tlbehi_i;
  logic [31:0] mmu_tlbelo0_i;
  logic [31:0] mmu_tlbelo1_i;
  logic [31:0] mmu_tlbidx_i;
  logic [ 5:0] mmu_ecode_i;

  logic [31:0] mmu_tlbehi_o;
  logic [31:0] mmu_tlbelo0_o;
  logic [31:0] mmu_tlbelo1_o;
  logic [31:0] mmu_tlbidx_o;
  logic [ 9:0] mmu_tlbasid_o;

  logic        mmu_invtlb_en_i;
  logic [ 9:0] mmu_invtlb_asid_i;
  logic [18:0] mmu_invtlb_vpn_i;
  logic [ 4:0] mmu_invtlb_op_i;

  /* Control Status Register */
  logic [13:0]  csr_rd_addr      ;
  logic [31:0]  csr_rd_data      ;
  logic [63:0]  csr_timer_64_out ;
  logic [31:0]  csr_tid_out      ;
  logic         csr_wr_en    ;
  logic [13:0]  csr_wr_addr      ;
  logic [31:0]  csr_wr_data      ;
  logic [ 7:0]  csr_interrupt    ;
  logic         csr_has_int      ;
  logic         csr_excp_flush   ;
  logic         csr_ertn_flush   ;
  logic [31:0]  csr_era_in       ;
  logic [ 8:0]  csr_esubcode_in  ;
  logic [ 5:0]  csr_ecode_in     ;
  logic         csr_va_error_in  ;
  logic [31:0]  csr_bad_va_in    ;
  logic         csr_tlbsrch_en    ;
  logic         csr_tlbsrch_found ;
  logic [ 4:0]  csr_tlbsrch_index ;
  logic         csr_excp_tlbrefill;
  logic         csr_excp_tlb     ;
  logic [18:0]  csr_excp_tlb_vppn;
  logic         csr_llbit_in     ;
  logic         csr_llbit_set_in ;
  logic         csr_llbit_out    ;
  logic [18:0]  csr_vppn_out     ;
  logic [31:0]  csr_eentry_out   ;
  logic [31:0]  csr_era_out      ;
  logic [31:0]  csr_tlbrentry_out;
  logic         csr_disable_cache_out;
  logic [ 9:0]  csr_asid_out     ;
  logic [ 4:0]  csr_rand_index   ;
  logic [31:0]  csr_tlbehi_out   ;
  logic [31:0]  csr_tlbelo0_out  ;
  logic [31:0]  csr_tlbelo1_out  ;
  logic [31:0]  csr_tlbidx_out   ;
  logic         csr_pg_out       ;
  logic         csr_da_out       ;
  logic [31:0]  csr_dmw0_out     ;
  logic [31:0]  csr_dmw1_out     ;
  logic [ 1:0]  csr_datf_out     ;
  logic [ 1:0]  csr_datm_out     ;
  logic [ 5:0]  csr_ecode_out    ;
  logic         csr_tlbrd_en     ;
  logic [31:0]  csr_tlbehi_in    ;
  logic [31:0]  csr_tlbelo0_in   ;
  logic [31:0]  csr_tlbelo1_in   ;
  logic [31:0]  csr_tlbidx_in    ;
  logic [ 9:0]  csr_asid_in      ;
  logic [ 1:0]  csr_plv_out      ;
  logic [31:0]  csr_crmd_diff;
  logic [31:0]  csr_prmd_diff;
  logic [31:0]  csr_ectl_diff;
  logic [31:0]  csr_estat_diff;
  logic [31:0]  csr_era_diff;
  logic [31:0]  csr_badv_diff;
  logic [31:0]  csr_eentry_diff;
  logic [31:0]  csr_tlbidx_diff;
  logic [31:0]  csr_tlbehi_diff;
  logic [31:0]  csr_tlbelo0_diff;
  logic [31:0]  csr_tlbelo1_diff;
  logic [31:0]  csr_asid_diff;
  logic [31:0]  csr_save0_diff;
  logic [31:0]  csr_save1_diff;
  logic [31:0]  csr_save2_diff;
  logic [31:0]  csr_save3_diff;
  logic [31:0]  csr_tid_diff;
  logic [31:0]  csr_tcfg_diff;
  logic [31:0]  csr_tval_diff;
  logic [31:0]  csr_ticlr_diff;
  logic [31:0]  csr_llbctl_diff;
  logic [31:0]  csr_tlbrentry_diff;
  logic [31:0]  csr_dmw0_diff;
  logic [31:0]  csr_dmw1_diff;
  logic [31:0]  csr_pgdl_diff;
  logic [31:0]  csr_pgdh_diff;

/*=========================== Branch Prediction Unit ==========================*/
  always_comb begin
    bpu_req_st.next = faq_push_rsp_st.ready;
    bpu_req_st.redirect = glo_flush;
    bpu_req_st.target = rob_retire_o.rob_entry[0].br_target;
  end

  BranchPredictionUnit U_BranchPredictionUnit (
    .clk(clk), 
    .a_rst_n(rst_n), 
    .bpu_req(bpu_req_st), 
    .bpu_rsp(bpu_rsp_st)
  );

/*============================ Fetch Address Queue ============================*/
  always_comb begin
    faq_flush = glo_flush;

    faq_push_req_st.valid = bpu_rsp_st.valid;
    faq_push_req_st.vaddr = bpu_rsp_st.pc;

    faq_pop_req_st.valid = icache_fetch_rsp_st.ready;
    faq_pop_req_st.ready = icache_fetch_rsp_st.ready;
  end

  FetchAddressQueue U_FetchAddressQueue (
    .clk         (clk),
    .a_rst_n     (rst_n),
    .flush_i     (faq_flush),
    .push_req_st (faq_push_req_st),
    .pop_req_st  (faq_pop_req_st),
    .push_rsp_st (faq_push_rsp_st),
    .pop_rsp_st  (faq_pop_rsp_st)
  );

/*========================== Instruction Fetch Unit ===========================*/
  always_comb begin
    icache_flush_i = glo_flush;

    icache_req.valid = faq_pop_rsp_st.valid;
    icache_req.vaddr = faq_pop_rsp_st.vaddr;
    icache_addr_trans_rsp = mmu_inst_trans_rsp;

    icacop_req.valid = 0;
  end

  ICache inst_ICache
  (
    .clk            (clk),
    .a_rst_n        (a_rst_n),
    .flush_i        (icache_flush_i),
    .icache_req     (icache_req),
    .icache_rsp     (icache_rsp),
    .addr_trans_rsp (icache_addr_trans_rsp),
    .addr_trans_req (icache_addr_trans_req),
    .icacop_req     (icacop_req),
    .icacop_rsp     (icacop_rsp),
    .axi4_mst       (icache_axi4_mst)
  );

/*================================ Pre Decoder ================================*/
  
  // TODO: 实现分支预测的pre检查
  // 对操作数相关信息解码
  for (genvar i = 0; i < `FETCH_WIDTH; i++) begin
    PreDecoder inst_PreDecoder (.instr(instr), .pre_oc(pre_oc));
  end


/*============================ Instruction Buffer =============================*/
  always_comb begin
    ibuf_flush = glo_flush;

    ibuf_write_valid = |icache_fetch_rsp_st.valid;
    ibuf_write_num = $countones(icache_rsp.valid);
    for (int i = 0; i < `FETCH_WIDTH; i++) begin
      ibuf_write_data[i].valid = icache_rsp.valid[i];
      ibuf_write_data[i].vaddr = icache_rsp.vaddr[i];
      ibuf_write_data[i].instr = icache_rsp.instr[i];
    end

    ibuf_read_ready = sche_schedule_rsp.ready;
    ibuf_read_num = `DECODE_WIDTH;
  end

  SyncMultiChannelFIFO #(
    .FIFO_DEPTH(`IBUF_DEPTH),
    .DATA_WIDTH($bits(IbufDataSt)),
    .RPORTS_NUM(`DECODE_WIDTH),
    .WPORTS_NUM(`FETCH_WIDTH),
    .FIFO_MEMORY_TYPE("auto")
  ) U_InstructionBuffer (
    .clk           (clk),
    .a_rst_n       (rst_n),
    .flush_i       (ibuf_flush),
    .write_valid_i (ibuf_write_valid),
    .write_ready_o (ibuf_write_ready),
    .write_num_i   (ibuf_write_num),
    .write_data_i  (ibuf_write_data),
    .read_valid_o  (ibuf_read_valid),
    .read_ready_i  (ibuf_read_ready),
    .read_num_i    (ibuf_read_num),
    .read_data_o   (ibuf_read_data)
  );

/*================================== Decoder ==================================*/
  // 对控制相关信息解码
  for (genvar i = 0; i < `DECODE_WIDTH; i++) begin
    Decoder inst_Decoder (
      .instruction(ibuf_read_data[i].instruction), 
      .option_code(decoder_option_code)
    );
  end

  // 准备寄存器编号、扩展imm
  always_comb begin
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      case (ibuf_read_data[i].pre_oc.imm_type)
        `IMM_NONE : decoder_imm[i] = 0;
        `IMM_I8   : decoder_imm[i] = ibuf_read_data[i].instruction[31:20];
        default : /* default */;
      endcase
    end
  end

/*================================= Scheduler ================================*/
  /* Dispatch/Wake up/Select */
  always_comb begin
    sche_flush = glo_flush;

    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      sche_schedule_req.valid[i] = ibuf_read_valid[i];
      sche_schedule_req.pc[i] = ibuf_read_data[i].pc;
      sche_schedule_req.npc[i] = ibuf_read_data[i].npc;
      sche_schedule_req.imm[i] = ;
      sche_schedule_req.option_code[i] = decoder_option_code[i];
    end

    sche_arch_rat_i = arch_rat_o;
    sche_rob_alloc_rsp = rob_alloc_rsp;
    sche_fl_free_valid_i = rob_retire_o.valid;
    for (int i = 0; i < `RETIRE_WIDTH; i++) begin
      sche_fl_free_preg_i[i] = rob_retire_o.rob_entry[i].old_phy_reg;
    end

    sche_cmt_pdest_i[0] = int_blk_misc_cmt.base.pdest;
    sche_cmt_pdest_i[1] = int_blk_alu_cmt[0].base.pdest;
    sche_cmt_pdest_i[2] = int_blk_alu_cmt[1].base.pdest;
    sche_cmt_pdest_i[3] = int_blk_mdu_cmt.base.pdest;
    sche_cmt_pdest_i[4] = mem_blk_cmt.base.pdest;

    sche_cmt_pdest_valid_i[0] = int_blk_misc_cmt.base.valid & int_blk_misc_cmt.base.we & int_blk_misc_cmt_ready;
    sche_cmt_pdest_valid_i[1] = int_blk_alu_cmt[0].base.valid & int_blk_alu_cmt[0].base.we & int_blk_alu_cmt_ready;
    sche_cmt_pdest_valid_i[2] = int_blk_alu_cmt[1].base.valid & int_blk_alu_cmt[1].base.we & int_blk_alu_cmt_ready;
    sche_cmt_pdest_valid_i[3] = int_blk_mdu_cmt.base.valid & int_blk_mdu_cmt.base.we & int_blk_mdu_cmt_ready;
    sche_cmt_pdest_valid_i[4] = mem_blk_cmt.base.valid & mem_blk_cmt.base.we & mem_blk_cmt_ready;

    sche_misc_ready = int_blk_misc_ready;
    sche_alu_ready = int_blk_alu_ready;
    sche_mdu_ready = int_blk_mdu_ready;
    sche_mem_ready = mem_blk_exe_ready;

  end

  Scheduler inst_Scheduler
  (
    .clk             (clk),
    .a_rst_n         (a_rst_n),
    .flush_i         (sche_flush),
    // schedule
    .schedule_req    (sche_schedule_req),
    .schedule_rsp    (sche_schedule_rsp),
    .rob_alloc_req   (sche_rob_alloc_req),
    .rob_alloc_rsp   (sche_rob_alloc_rsp),
    .fl_free_valid_i (sche_fl_free_valid_i),
    .fl_free_preg_i  (sche_fl_free_preg_i),
    .arch_rat_i      (sche_arch_rat_i),
    .cmt_pdest_valid_i(sche_cmt_pdest_valid_i),
    .cmt_pdest_i     (sche_cmt_pdest_i),
    // issue
    .misc_issue_o    (sche_misc_issue),
    .misc_ready_i    (sche_misc_ready),
    .alu_issue_o     (sche_alu_issue),
    .alu_ready_i     (sche_alu_ready),
    .mdu_issue_o     (sche_mdu_issue),
    .mdu_ready_i     (sche_mdu_ready),
    .mem_issue_o     (sche_mem_issue),
    .mem_ready_i     (sche_mem_ready)
  );

/*================================= RegFile ===================================*/
  always_comb begin
    rf_raddr[0] = sche_alu_issue[0].base_info.psrc0;
    rf_raddr[1] = sche_alu_issue[0].base_info.psrc1;
    rf_raddr[2] = sche_alu_issue[1].base_info.psrc0;
    rf_raddr[3] = sche_alu_issue[1].base_info.psrc1;
    rf_raddr[4] = sche_misc_issue.base_info.psrc0;
    rf_raddr[5] = sche_misc_issue.base_info.psrc1;
    rf_raddr[6] = sche_mdu_issue.base_info.psrc0;
    rf_raddr[7] = sche_mdu_issue.base_info.psrc1;
    rf_raddr[8] = sche_mem_issue.base_info.psrc0;
    rf_raddr[9] = sche_mem_issue.base_info.psrc1;

    rf_we[0] = int_blk_alu_cmt[0].base.valid & int_blk_alu_cmt[0].base.we;
    rf_we[1] = int_blk_alu_cmt[1].base.valid & int_blk_alu_cmt[1].base.we;
    rf_we[2] = int_blk_mdu_cmt.base.valid & int_blk_mdu_cmt.base.we;
    rf_we[3] = mem_blk_cmt.base.valid & mem_blk_cmt.base.we;
    rf_we[4] = int_blk_misc_cmt.base.valid & int_blk_misc_cmt.base.we;

    rf_waddr[0] = int_blk_alu_cmt[0].base.pdest;
    rf_waddr[1] = int_blk_alu_cmt[1].base.pdest;
    rf_waddr[2] = int_blk_mdu_cmt.base.pdest;
    rf_waddr[3] = int_blk_mem_cmt.base.pdest;
    rf_waddr[4] = int_blk_misc_cmt.base.pdest;

    rf_wdata[0] = int_blk_alu_cmt[0].base.wdata;
    rf_wdata[1] = int_blk_alu_cmt[1].base.wdata;
    rf_wdata[2] = int_blk_mdu_cmt.base.wdata;
    rf_wdata[3] = int_blk_mem_cmt.base.wdata;
    rf_wdata[4] = int_blk_misc_cmt.base.wdata;
  end

  // comb输出，需用寄存器存一拍
  PhysicalRegisterFile #(
    .READ_PORT_NUM(5),
    .WRITE_PORT_NUM(5),
    .DATA_WIDTH(32),
    .PHY_REG_NUM(64)
  ) U0_PhysicalRegisterFile (
    .clk     (clk),
    .a_rst_n (rst_n),
    .we_i    (rf_we),
    .raddr_i (rf_raddr[4:0]),
    .waddr_i (rf_waddr),
    .data_i  (rf_wdata),
    .data_o  (rf_rdata[4:0])
  );

  PhysicalRegisterFile #(
    .READ_PORT_NUM(5),
    .WRITE_PORT_NUM(5),
    .DATA_WIDTH(32),
    .PHY_REG_NUM(64)
  ) U1_PhysicalRegisterFile (
    .clk     (clk),
    .a_rst_n (rst_n),
    .we_i    (rf_we),
    .raddr_i (rf_raddr[9:5]),
    .waddr_i (rf_waddr),
    .data_i  (rf_wdata),
    .data_o  (rf_rdata[9:5])
  );


/*=============================== Integer Block ===============================*/
  always_comb begin
    int_blk_flush = glo_flush;
    int_blk_misc_exe.base = '{valid: sche_misc_issue.valid, 
                              imm: sche_misc_issue.base_info.imm, 
                              src0: rf_rdata[4],
                              src1: rf_rdata[5],
                              pdest: sche_misc_issue.base_info.pdest, 
                              rob_idx: sche_misc_issue.base_info.rob_idx};
    int_blk_misc_exe.misc_oc = sche_misc_issue.misc_oc;
    int_blk_misc_exe.pc = sche_misc_issue.base_info.pc;
    int_blk_misc_exe.npc = sche_misc_issue.base_info.npc;

    int_blk_alu_exe[0].base = '{valid: sche_alu_issue[0].base_info.valid, 
                                imm: sche_alu_issue[0].base_info.imm, 
                                src0: rf_rdata[0],
                                src1: rf_rdata[1],
                                pdest: sche_alu_issue[0].base_info.pdest, 
                                rob_idx: sche_alu_issue[0].base_info.rob_idx};
    int_blk_alu_exe[0].alu_oc = sche_alu_issue[0].alu_oc;

    int_blk_alu_exe[1].base = '{valid: sche_alu_issue[1].base_info.valid, 
                                imm: sche_alu_issue[1].base_info.imm, 
                                src0: rf_rdata[2],
                                src1: rf_rdata[3],
                                pdest: sche_alu_issue[1].base_info.pdest, 
                                rob_idx: sche_alu_issue[1].base_info.rob_idx};
    int_blk_alu_exe[1].alu_oc = sche_alu_issue[1].alu_oc;

    int_blk_mdu_exe.base = '{valid: sche_mdu_issue.base_info.valid, 
                             imm: sche_mdu_issue.base_info.imm, 
                             src0: rf_rdata[6],
                             src1: rf_rdata[7],
                             pdest: sche_mdu_issue.base_info.pdest, 
                             rob_idx: sche_mdu_issue.base_info.rob_idx};
    int_blk_mdu_exe.mdu_oc = sche_mdu_issue.mdu_oc;

    int_blk_csr_rdata = csr_rd_data;
    int_blk_tlbsrch_found_i = mmu_tlbsrch_found_o;
    int_blk_tlbsrch_idx_i = mmu_tlbsrch_idx_o;

    int_blk_alu_cmt_ready = '1;
    // 特权指令在成为最旧指令时才执行
    int_blk_misc_cmt_ready = ~int_blk_misc_cmt.priv_inst | 
                              int_blk_misc_cmt.base.rob_idx == rob_oldest_rob_idx_o;
    int_blk_mdu_cmt_ready = '1;
  end


  IntegerBlock inst_IntegerBlock
  (
    .clk              (clk),
    .a_rst_n          (rst_n),
    .flush_i          (int_blk_flush),
    /* exe */
    .misc_exe_i       (int_blk_misc_exe),
    .misc_ready_o     (int_blk_misc_ready),
    .alu_exe_i        (int_blk_alu_exe),
    .alu_ready_o      (int_blk_alu_ready),
    .mdu_exe_i        (int_blk_mdu_exe),
    .mdu_ready_o      (int_blk_mdu_ready),
    /* other exe info */
    .tlbsrch_valid_o  (int_blk_tlbsrch_valid_o),
    .tlbsrch_found_i  (int_blk_tlbsrch_found_i),
    .tlbsrch_idx_i    (int_blk_tlbsrch_idx_i),
    .csr_raddr_o      (int_blk_csr_raddr),
    .csr_rdata_i      (int_blk_csr_rdata),
    /* commit */
    .misc_cmt_o       (int_blk_misc_cmt),
    .misc_cmt_ready_i (int_blk_misc_cmt_ready),
    .alu_cmt_o        (int_blk_alu_cmt),
    .alu_cmt_ready_i  (int_blk_alu_cmt_ready),
    .mdu_cmt_o        (int_blk_mdu_cmt),
    .mdu_cmt_ready_i  (int_blk_mdu_cmt_ready)
  );


/*=============================== Memory Block ================================*/
  always_comb begin
    mem_blk_flush = glo_flush;

    mem_blk_exe.base = '{valid: sche_mem_issue.base_info.valid, 
                         imm: sche_mem_issue.base_info.imm, 
                         src0: rf_rdata[8],
                         src1: rf_rdata[9],
                         pdest: sche_mem_issue.base_info.pdest, 
                         rob_idx: sche_mem_issue.base_info.rob_idx};
    mem_blk_exe.mem_oc = sche_mem_issue.mem_oc;

    mem_blk_mmu_rsp = mmu_data_trans_rsp;
    mem_blk_oldest_rob_idx_i = rob_oldest_rob_idx_o;
    mem_blk_axi4_mst = dcache_axi4_mst;

    mem_blk_cmt_ready = '1;
  end


  MemoryBlock inst_MemoryBlock
  (
    .clk              (clk),
    .a_rst_n          (a_rst_n),
    .flush_i          (mem_blk_flush),
    .exe_i            (mem_blk_exe),
    .exe_ready_o      (mem_blk_exe_ready),
    .mmu_req          (mem_blk_mmu_req),
    .mmu_rsp          (mem_blk_mmu_rsp),
    .oldest_rob_idx_i (mem_blk_oldest_rob_idx_i),
    .axi4_mst         (mem_blk_axi4_mst),
    .cmt_o            (mem_blk_cmt),
    .cmt_ready_i      (mem_blk_cmt_ready)
  );

/*============================== Reorder Buffer ===============================*/
  always_comb begin
    rob_flush = glo_flush;

    rob_alloc_req = sche_rob_alloc_req;
    // misc
    rob_cmt_req[0] = '{valid: int_blk_misc_cmt.base.valid,
                       rob_idx: int_blk_misc_cmt.base.rob_idx,
                       exception: int_blk_misc_cmt.base.exception,
                       ecode: int_blk_misc_cmt.base.ecode, 
                       sub_ecode: int_blk_misc_cmt.base.sub_ecode, 
                       error_vaddr: int_blk_misc_cmt.base.error_vaddr, 
                       redirect: int_blk_misc_cmt.br_redirect,
                       br_target: int_blk_misc_cmt.br_target};
    // alu 0
    rob_cmt_req[1] = '{valid: int_blk_alu_cmt[0].base.valid,
                       rob_idx: int_blk_alu_cmt[0].base.rob_idx,
                       exception: int_blk_alu_cmt[0].base.exception,
                       ecode: int_blk_alu_cmt[0].base.ecode,
                       sub_ecode: int_blk_alu_cmt[0].base.sub_ecode,
                       error_vaddr: int_blk_alu_cmt[0].base.error_vaddr,
                       redirect: '0,
                       br_target: '0};

    // alu 1
    rob_cmt_req[2] = '{valid: int_blk_alu_cmt[1].base.valid,
                       rob_idx: int_blk_alu_cmt[1].base.rob_idx,
                       exception: int_blk_alu_cmt[1].base.exception,
                       ecode: int_blk_alu_cmt[1].base.ecode,
                       sub_ecode: int_blk_alu_cmt[1].base.sub_ecode,
                       error_vaddr: int_blk_alu_cmt[1].base.error_vaddr,
                       redirect: '0,
                       br_target: '0};

    // mdu
    rob_cmt_req[3] = '{valid: int_blk_mdu_cmt.base.valid,
                       rob_idx: int_blk_mdu_cmt.base.rob_idx,
                       exception: int_blk_mdu_cmt.base.exception,
                       ecode: int_blk_mdu_cmt.base.ecode,
                       sub_ecode: int_blk_mdu_cmt.base.sub_ecode,
                       error_vaddr: int_blk_mdu_cmt.base.error_vaddr,
                       redirect: '0,
                       br_target: '0};
    // mem
    rob_cmt_req[4] = '{valid: mem_blk_cmt.base.valid,
                       rob_idx: mem_blk_cmt.base.rob_idx,
                       exception: mem_blk_cmt.base.exception,
                       ecode: mem_blk_cmt.base.ecode,
                       sub_ecode: mem_blk_cmt.base.sub_ecode,
                       error_vaddr: mem_blk_cmt.base.error_vaddr,
                       redirect: '0,
                       br_target: '0};

  end

  ReorderBuffer inst_ReorderBuffer
  (
    .clk              (clk),
    .a_rst_n          (a_rst_n),
    .flush_i          (rob_flush),
    .alloc_req        (rob_alloc_req),
    .alloc_rsp        (rob_alloc_rsp),
    .cmt_req          (rob_cmt_req),
    .cmt_rsp          (rob_cmt_rsp),
    .retire_o         (rob_retire_o),
    .oldest_rob_idx_o (rob_oldest_rob_idx_o)
  );
/*================================== Retire ===================================*/
  assign glo_flush = rob_retire_o.valid[0] & (rob_retire_o.rob_entry[0].exception | rob_retire_o.rob_entry[0].redirect);

  always_comb begin
    for (int i = 0; i < `RETIRE_WIDTH; i++) begin
      arch_rat_dest_valid_i[i] = rob_retire_o.valid[i] & rob_retire_o.rob_entry[i].phy_reg_valid;
      arch_rat_dest_i[i] = rob_retire_o.rob_entry[i].arch_reg;
      arch_rat_preg_i[i] = rob_retire_o.rob_entry[i].phy_reg;
    end
  end


  ArchRegisterAliasTable #(
    .PHY_REG_NUM(`PHY_REG_NUM)
  ) inst_ArchRegisterAliasTable (
    .clk          (clk),
    .a_rst_n      (rst_n),
    .arch_rat_o   (arch_rat_o),
    .dest_valid_i (arch_rat_dest_valid_i),
    .dest_i       (arch_rat_dest_i),
    .preg_i       (arch_rat_preg_i)
  );

`ifdef DEBUG
  logic [31:0][31:0] arch_regfile;

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      arch_regfile <= 0;
    end else begin
      for (int i = 0; i < `RETIRE_WIDTH; i++) begin
        if (rob_retire_o.valid[i] && 
            rob_retire_o.rob_entry[i].phy_reg_valid && 
            rob_retire_o.rob_entry[i].arch_reg != 0) begin
          arch_regfile[rob_retire_o.rob_entry[i].arch_reg] <= rob_retire_o.rob_entry[i].rf_wdata;
        end
      end
    end
  end
`endif

/*========================== Memory Management Unit ===========================*/

  always_comb begin
    mmu_csr_asid_i = csr_asid_out;
    mmu_csr_dmw0_i = csr_dmw0_out;
    mmu_csr_dmw1_i = csr_dmw1_out;
    mmu_csr_datf_i = csr_datf_out;
    mmu_csr_datm_i = csr_datm_out;
    mmu_csr_da_i = csr_da_out;
    mmu_csr_pg_i = csr_pg_out;

    mmu_inst_trans_req = icache_addr_trans_req;
    mmu_data_trans_req = mem_blk_mmu_req;

    mmu_tlbsrch_en_i = int_blk_tlbsrch_valid_o;

    mmu_tlbfill_en_i = int_blk_misc_cmt.base.valid &
                       int_blk_misc_cmt_ready &
                       int_blk_misc_cmt.priv_inst  &
                       int_blk_misc_cmt.priv_op == `PRIV_TLBFILL;
    mmu_tlbwr_en_i = int_blk_misc_cmt.base.valid &
                     int_blk_misc_cmt_ready &
                     int_blk_misc_cmt.priv_inst &
                     int_blk_misc_cmt.priv_op == `PRIV_TLBWR;
    mmu_rand_index_i = csr_rand_index;
    mmu_tlbehi_i = csr_tlbehi_out;
    mmu_tlbelo0_i = csr_tlbelo0_out;
    mmu_tlbelo1_i = csr_tlbelo1_out;
    mmu_tlbidx_i = csr_tlbidx_out;
    mmu_ecode_i = csr_ecode_out;

    mmu_invtlb_en_i = int_blk_misc_cmt.base.valid &
                      int_blk_misc_cmt_ready &
                      int_blk_misc_cmt.priv_inst &
                      int_blk_misc_cmt.priv_op == `PRIV_TLBINV;
    mmu_invtlb_asid_i = int_blk_misc_cmt.invtlb_asid;
    mmu_invtlb_vpn_i = int_blk_misc_cmt.vaddr[`PROC_VALEN - 1:13];
    mmu_invtlb_op_i = int_blk_misc_cmt.invtlb_op;
  end

  MemoryManagementUnit inst_MemoryManagementUnit
  (
    .clk            (clk),
    .a_rst_n        (a_rst_n),
    // from csr
    .csr_asid_i     (mmu_csr_asid_i),
    .csr_dmw0_i     (mmu_csr_dmw0_i),
    .csr_dmw1_i     (mmu_csr_dmw1_i),
    .csr_datf_i     (mmu_csr_datf_i),
    .csr_datm_i     (mmu_csr_datm_i),
    .csr_da_i       (mmu_csr_da_i),
    .csr_pg_i       (mmu_csr_pg_i),
    .csr_plv_i      (mmu_csr_plv_i),
    // inst addr trans
    .inst_trans_req (mmu_inst_trans_req),
    .inst_trans_rsp (mmu_inst_trans_rsp),
    // data addr trans
    .data_trans_req (mmu_data_trans_req),
    .data_trans_rsp (mmu_data_trans_rsp),
    // tlb search
    .tlbsrch_en_i   (mmu_tlbsrch_en_i),
    .tlbsrch_found_o(mmu_tlbsrch_found_o),
    .tlbsrch_idx_o  (mmu_tlbsrch_idx_o),
    // tlbfill tlbwr tlb write
    .tlbfill_en_i   (mmu_tlbfill_en_i),
    .tlbwr_en_i     (mmu_tlbwr_en_i),
    .rand_index_i   (mmu_rand_index_i),
    .tlbehi_i       (mmu_tlbehi_i),
    .tlbelo0_i      (mmu_tlbelo0_i),
    .tlbelo1_i      (mmu_tlbelo1_i),
    .tlbidx_i       (mmu_tlbidx_i),
    .ecode_i        (mmu_ecode_i),
    //tlbr tlb read
    .tlbehi_o       (mmu_tlbehi_o),
    .tlbelo0_o      (mmu_tlbelo0_o),
    .tlbelo1_o      (mmu_tlbelo1_o),
    .tlbidx_o       (mmu_tlbidx_o),
    .tlbasid_o      (mmu_tlbasid_o),
    // invtlb
    .invtlb_en_i    (mmu_invtlb_en_i),
    .invtlb_asid_i  (mmu_invtlb_asid_i),
    .invtlb_vpn_i   (mmu_invtlb_vpn_i),
    .invtlb_op_i    (mmu_invtlb_op_i)
  );

/*======================= CSR(Control/Status Register) ========================*/
  always_comb begin
    csr_rd_addr = int_blk_csr_raddr;
    csr_wr_en = int_blk_misc_cmt.base.valid &
                int_blk_misc_cmt_ready &
                int_blk_misc_cmt.csr_we;
    csr_wr_addr = int_blk_misc_cmt.csr_waddr;
    csr_wr_data = int_blk_misc_cmt.csr_wdata;

    csr_interrupt = interrupt;

    csr_excp_flush = rob_retire_o.valid[0] & rob_retire_o.rob_entry.exception;
    csr_ertn_flush = int_blk_misc_cmt.base.valid &
                     int_blk_misc_cmt_ready &
                     int_blk_misc_cmt.priv_inst &
                     int_blk_misc_cmt.priv_op == `PRIV_ERTN;
    csr_era_in = rob_retire_o.rob_entry.pc;
    csr_esubcode_in = rob_retire_o.rob_entry.sub_ecode;
    csr_ecode_in = rob_retire_o.rob_entry.ecode;
    csr_va_error_in = rob_retire_o.valid[0] & 
                      rob_retire_o.rob_entry.exception &
                      rob_retire_o.rob_entry.ecode inside 
                      {`ECODE_ADE, `ECODE_TLBR, `ECODE_PIF, `ECODE_PPI,
                       `ECODE_ALE, `ECODE_PME,  `ECODE_PIS, `ECODE_PIL};
    csr_bad_va_in = rob_retire_o.rob_entry[0].error_vaddr;

    csr_tlbsrch_en = int_blk_misc_cmt.base.valid &
                     int_blk_misc_cmt_ready &
                     int_blk_misc_cmt.priv_inst &
                     int_blk_misc_cmt.priv_op == `PRIV_TLBSRCH;
    csr_tlbsrch_found = int_blk_misc_cmt.tlbsrch_found;
    csr_tlbsrch_index = int_blk_misc_cmt.tlbsrch_idx;

    csr_excp_tlbrefill = rob_retire_o.valid[0] & 
                         rob_retire_o.rob_entry.exception &
                         rob_retire_o.rob_entry.ecode == `ECODE_TLBR;
    csr_excp_tlb = rob_retire_o.valid[0] & 
                   rob_retire_o.rob_entry.exception &
                   rob_retire_o.rob_entry.ecode inside
                   {`ECODE_TLBR, `ECODE_PIF, `ECODE_PPI,
                    `ECODE_PME,  `ECODE_PIS, `ECODE_PIL};
    csr_excp_tlb_vppn = rob_retire_o.rob_entry[0].error_vaddr;

    csr_llbit_in = '0;
    csr_llbit_set_in = '0;

    csr_tlbrd_en = int_blk_misc_cmt.base.valid &
                   int_blk_misc_cmt_ready &
                   int_blk_misc_cmt.priv_inst &
                   int_blk_misc_cmt.priv_op == `PRIV_TLBRD;
    csr_tlbehi_in = int_blk_misc_cmt.tlbrd_ehi;
    csr_tlbelo0_in = int_blk_misc_cmt.tlbrd_elo0;
    csr_tlbelo1_in = int_blk_misc_cmt.tlbrd_elo1;
    csr_tlbidx_in = int_blk_misc_cmt.tlbrd_idx;
    csr_asid_in = int_blk_misc_cmt.tlbrd_asid;
  end

  ControlStatusRegister #(
    .TLBNUM(`TLB_ENTRY_NUM)
  ) inst_ControlStatusRegister (
    .clk                (clk),
    .reset              (~rst_n),
    // csr rd
    .rd_addr            (csr_rd_addr),
    .rd_data            (csr_rd_data),
    // timer 64
    .timer_64_out       (csr_timer_64_out),
    .tid_out            (csr_tid_out),
    // csr wr
    .csr_wr_en          (csr_wr_en),
    .wr_addr            (csr_wr_addr),
    .wr_data            (csr_wr_data),
    // interrupt
    .interrupt          (csr_interrupt),
    .has_int            (csr_has_int),
    // excp
    .excp_flush         (csr_excp_flush),
    .ertn_flush         (csr_ertn_flush),
    .era_in             (csr_era_in),
    .esubcode_in        (csr_esubcode_in),
    .ecode_in           (csr_ecode_in),
    .va_error_in        (csr_va_error_in),
    .bad_va_in          (csr_bad_va_in),
    .tlbsrch_en         (csr_tlbsrch_en),
    .tlbsrch_found      (csr_tlbsrch_found),
    .tlbsrch_index      (csr_tlbsrch_index),
    .excp_tlbrefill     (csr_excp_tlbrefill),
    .excp_tlb           (csr_excp_tlb),
    .excp_tlb_vppn      (csr_excp_tlb_vppn),
    // llbit
    .llbit_in           (csr_llbit_in),
    .llbit_set_in       (csr_llbit_set_in),
    // to atomic
    .llbit_out          (csr_llbit_out),
    .vppn_out           (csr_vppn_out),
    // to fetch
    .eentry_out         (csr_eentry_out),
    .era_out            (csr_era_out),
    .tlbrentry_out      (csr_tlbrentry_out),
    .disable_cache_out  (csr_disable_cache_out),
    // to mmu
    .asid_out           (csr_asid_out),
    .rand_index         (csr_rand_index),
    .tlbehi_out         (csr_tlbehi_out),
    .tlbelo0_out        (csr_tlbelo0_out),
    .tlbelo1_out        (csr_tlbelo1_out),
    .tlbidx_out         (csr_tlbidx_out),
    .pg_out             (csr_pg_out),
    .da_out             (csr_da_out),
    .dmw0_out           (csr_dmw0_out),
    .dmw1_out           (csr_dmw1_out),
    .datf_out           (csr_datf_out),
    .datm_out           (csr_datm_out),
    .ecode_out          (csr_ecode_out),
    // from mmu
    .tlbrd_en           (csr_tlbrd_en),
    .tlbehi_in          (csr_tlbehi_in),
    .tlbelo0_in         (csr_tlbelo0_in),
    .tlbelo1_in         (csr_tlbelo1_in),
    .tlbidx_in          (csr_tlbidx_in),
    .asid_in            (csr_asid_in),
    // general use
    .plv_out            (csr_plv_out),
    // csr regs for diff
    .csr_crmd_diff      (csr_crmd_diff),
    .csr_prmd_diff      (csr_prmd_diff),
    .csr_ectl_diff      (csr_ectl_diff),
    .csr_estat_diff     (csr_estat_diff),
    .csr_era_diff       (csr_era_diff),
    .csr_badv_diff      (csr_badv_diff),
    .csr_eentry_diff    (csr_eentry_diff),
    .csr_tlbidx_diff    (csr_tlbidx_diff),
    .csr_tlbehi_diff    (csr_tlbehi_diff),
    .csr_tlbelo0_diff   (csr_tlbelo0_diff),
    .csr_tlbelo1_diff   (csr_tlbelo1_diff),
    .csr_asid_diff      (csr_asid_diff),
    .csr_save0_diff     (csr_save0_diff),
    .csr_save1_diff     (csr_save1_diff),
    .csr_save2_diff     (csr_save2_diff),
    .csr_save3_diff     (csr_save3_diff),
    .csr_tid_diff       (csr_tid_diff),
    .csr_tcfg_diff      (csr_tcfg_diff),
    .csr_tval_diff      (csr_tval_diff),
    .csr_ticlr_diff     (csr_ticlr_diff),
    .csr_llbctl_diff    (csr_llbctl_diff),
    .csr_tlbrentry_diff (csr_tlbrentry_diff),
    .csr_dmw0_diff      (csr_dmw0_diff),
    .csr_dmw1_diff      (csr_dmw1_diff),
    .csr_pgdl_diff      (csr_pgdl_diff),
    .csr_pgdh_diff      (csr_pgdh_diff)
  );
  

endmodule : Pipeline



