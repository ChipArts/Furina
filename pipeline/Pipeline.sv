// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Pipeline.sv
// Create  : 2024-03-11 14:53:30
// Revise  : 2024-04-01 23:06:08
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
  logic faq_flush_i;

  /* ICache */
  logic icache_flush_i;
  ICacheReqSt icache_req;
  ICacheRspSt icache_rsp;
  MmuAddrTransRspSt icache_addr_trans_rsp;
  MmuAddrTransReqSt icache_addr_trans_req;
  IcacopReqSt icacop_req;
  IcacopRspSt icacop_rsp;

  /* Pre Decoder */
  PreOptionCodeSt [`FETCH_WIDTH - 1:0] pre_oc;
  

  /* Instruction Buffer */
  logic ibuf_flush_i;
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
  logic [`DECODE_WIDTH - 1:0][4:0] decoder_src0;
  logic [`DECODE_WIDTH - 1:0][4:0] decoder_src1;
  logic [`DECODE_WIDTH - 1:0][4:0] decoder_dest;

  /* Scheduler */
  logic sche_flush_i;
  ScheduleReqSt sche_req;
  ScheduleRspSt sche_rsp;
  RobAllocReqSt sche_rob_alloc_req;
  RobAllocRspSt sche_rob_alloc_rsp;
  logic [`COMMIT_WIDTH - 1:0] sche_fl_free_valid_i;
  logic [`COMMIT_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] sche_fl_free_preg_i;
  logic [31:0][$clog2(`PHY_REG_NUM) - 1:0] sche_arch_rat_i;
  logic [`WB_WIDTH - 1:0] sche_wb_pdest_valid_i;
  logic [`WB_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] sche_wb_pdest_i;
  MiscIssueSt sche_misc_issue_o;
  logic sche_misc_ready_i;
  AluIssueSt [1:0] sche_alu_issue_o;
  logic [1:0] sche_alu_ready_i;
  MduIssueSt sche_mdu_issue_o;
  logic sche_mdu_ready_i;
  MemIssueSt sche_mem_issue_o;
  logic sche_mem_ready_i;

  /* RegFile */
  // 每周期最多发射misc*1、alu*2、mdu*1、mem*1
  logic [4:0] rf_re_i;
  logic [4:0] rf_we_i;
  logic [4:0][$clog2(`PHY_REG_NUM) - 1:0] rf_waddr_i;
  logic [9:0][$clog2(`PHY_REG_NUM) - 1:0] rf_raddr_i;
  logic [4:0][31:0] rf_wdata_i;
  logic [9:0][31:0] rf_rdata_o;

  logic [31:0] misc_exe_imm;
  logic [1:0][31:0] alu_exe_imm;
  logic [31:0] mdu_exe_imm;
  logic [31:0] mem_exe_imm;

  /* Integer Block */
  // IntegerBlock --> iblk
  logic iblk_flush_i;
  MiscExeSt iblk_misc_exe_i;
  logic iblk_misc_ready_o;
  AluExeSt [1:0] iblk_alu_exe_i;
  logic [1:0] iblk_alu_ready_o;
  MduExeSt iblk_mdu_exe_i;
  logic iblk_mdu_ready_o;
  logic iblk_tlbsrch_valid_o;
  logic iblk_tlbsrch_found_i;
  logic [$clog2(`TLB_ENTRY_NUM) - 1:0] iblk_tlbsrch_idx_i;
  logic [31:0] iblk_tlbehi_i;
  logic [31:0] iblk_tlbelo0_i;
  logic [31:0] iblk_tlbelo1_i;
  logic [31:0] iblk_tlbidx_i;
  logic [ 9:0] iblk_tlbasid_i;
  logic [63:0] iblk_timer_64_i;
  logic [31:0] iblk_timer_id_i;
  logic [31:0] iblk_csr_rdata_i;
  MiscWbSt iblk_misc_wb_o;
  logic iblk_misc_wb_ready_i;
  AluWbSt [1:0] iblk_alu_wb_o;
  logic [1:0] iblk_alu_wb_ready_i;
  MduWbSt iblk_mdu_wb_o;
  logic iblk_mdu_wb_ready_i;

  /* Memory Block */
  // MemoryBlock --> mblk
  logic mblk_flush_i;
  MemExeSt mblk_exe_i;
  logic mblk_exe_ready_o;
  MmuAddrTransReqSt mblk_addr_trans_req;
  MmuAddrTransRspSt mblk_addr_trans_rsp;
  MemWbSt mblk_wb_o;
  logic mblk_wb_ready_i;

  /* Reorder Buffer */
  logic rob_flush_i;
  RobAllocReqSt rob_alloc_req;
  RobAllocRspSt rob_alloc_rsp;
  RobWbReqSt [`WB_WIDTH - 1:0] rob_wb_req;
  RobWbRspSt [`WB_WIDTH - 1:0] rob_wb_rsp;
  RobCmtSt rob_cmt_o;
  logic [$clog2(`ROB_DEPTH) - 1:0] rob_oldest_idx_o;

  /* commit */
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
  MmuAddrTransReqSt [1:0] mmu_addr_trans_req;
  MmuAddrTransRspSt [1:0] mmu_addr_trans_rsp;
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
    bpu_req_st.target = rob_cmt_o.rob_entry[0].br_target;
  end

  BranchPredictionUnit U_BranchPredictionUnit (
    .clk(clk), 
    .a_rst_n(rst_n), 
    .bpu_req(bpu_req_st), 
    .bpu_rsp(bpu_rsp_st)
  );

/*============================ Fetch Address Queue ============================*/
  always_comb begin
    faq_flush_i = glo_flush;

    faq_push_req_st.valid = bpu_rsp_st.valid;
    faq_push_req_st.vaddr = bpu_rsp_st.pc;

    faq_pop_req_st.valid = icache_fetch_rsp_st.ready;
    faq_pop_req_st.ready = icache_fetch_rsp_st.ready;
  end

  FetchAddressQueue U_FetchAddressQueue (
    .clk         (clk),
    .a_rst_n     (rst_n),
    .flush_i     (faq_flush_i),
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
    icache_addr_trans_rsp = mmu_addr_trans_rsp[0];

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
  for (genvar i = 0; i < `FETCH_WIDTH; i++) begin
    PreDecoder inst_PreDecoder (.instr(instr), .pre_oc(pre_oc));
  end


/*============================ Instruction Buffer =============================*/
  always_comb begin
    ibuf_flush_i = glo_flush;

    ibuf_write_valid = |icache_fetch_rsp_st.valid;
    ibuf_write_num = $countones(icache_rsp.valid);
    for (int i = 0; i < `FETCH_WIDTH; i++) begin
      ibuf_write_data[i].valid = icache_rsp.valid[i];
      ibuf_write_data[i].instr = icache_rsp.instr[i];
      ibuf_write_data[i].pc = icache_rsp.pc[i];
      ibuf_write_data[i].npc = icache_rsp.npc[i];
      ibuf_write_data[i].pre_oc = pre_oc[i];
      ibuf_write_data[i].excp = icache_rsp.excp;
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
    .flush_i       (ibuf_flush_i),
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
    Decoder inst_Decoder (.instr_i(ibuf_read_data[i].instr), .option_code_o(decoder_option_code[i]));
  end

  // 处理特殊的解码
  // TODO: 优化这个处理
  always_comb begin
    // 三个CSR特权指令
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      if (decoder_option_code[i].priv_op == `PRIV_CSR_XCHG) begin
        case (ibuf_read_data[i].instr[9:5])
          5'b0 : decoder_option_code[i].priv_op = `PRIV_CSR_READ;
          5'b1 : decoder_option_code[i].priv_op = `PRIV_CSR_WRITE;
          default : decoder_option_code[i].priv_op = `PRIV_CSR_XCHG;
        endcase
      end
    end
    // 两个rdtimel指令
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      if (decoder_option_code[i].priv_op == `PRIV_RDCNTVL) begin
        if (ibuf_read_data[i].instr[9:5] != 0) begin
          decoder_option_code[i].priv_op = `PRIV_RDCNTID;
        end
      end
    end
  end

  // 准备寄存器编号
  always_comb begin
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      case (ibuf_read_data[i].pre_oc.src0_type)
        `SRC_R0 : decoder_src0[i] = 5'd0;
        `SRC_RD : decoder_src0[i] = ibuf_read_data[i].instr[4:0];
        `SRC_RJ : decoder_src0[i] = ibuf_read_data[i].instr[9:5];
        `SRC_RK : decoder_src0[i] = ibuf_read_data[i].instr[14:10];
        default : /* default */;
      endcase
      case (ibuf_read_data[i].pre_oc.src1_type)
        `SRC_RD : decoder_src1[i] = ibuf_read_data[i].instr[4:0];
        `SRC_RJ : decoder_src1[i] = ibuf_read_data[i].instr[9:5];
        `SRC_RK : decoder_src1[i] = ibuf_read_data[i].instr[14:10];
        `SRC_R0 : decoder_src1[i] = 5'd0;
        default : /* default */;
      endcase
      case (ibuf_read_data[i].pre_oc.dest_type)
        `DEST_R0 : decoder_dest[i] = 5'd0;
        `DEST_RD : decoder_dest[i] = ibuf_read_data[i].instr[4:0];
        `DEST_JD : decoder_dest[i] = ibuf_read_data[i].instr[9:5] | ibuf_read_data[i].instr[4:0];
        `DEST_RA : decoder_dest[i] = 5'd1;
        default : /* default */;
      endcase
    end
  end

/*================================= Scheduler ================================*/
  /* Dispatch/Wake up/Select */
  always_comb begin
    sche_flush_i = glo_flush;

    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      sche_req.valid[i] = ibuf_read_valid[i];
      sche_req.pc[i] = ibuf_read_data[i].pc;
      sche_req.npc[i] = ibuf_read_data[i].npc;
      sche_req.arch_src0[i] = decoder_src0[i];
      sche_req.arch_src1[i] = decoder_src1[i];
      sche_req.arch_dest[i] = decoder_dest[i];
      sche_req.option_code[i] = decoder_option_code[i];
      sche_req.excp[i] = ibuf_read_data[i].excp;
    end

    sche_arch_rat_i = arch_rat_o;
    sche_rob_alloc_rsp = rob_alloc_rsp;
    sche_fl_free_valid_i = rob_cmt_o.valid;
    for (int i = 0; i < `COMMIT_WIDTH; i++) begin
      sche_fl_free_preg_i[i] = rob_cmt_o.rob_entry[i].old_phy_reg;
    end

    sche_wb_pdest_i[0] = iblk_misc_wb_o.base.pdest;
    sche_wb_pdest_i[1] = iblk_alu_wb_o[0].base.pdest;
    sche_wb_pdest_i[2] = iblk_alu_wb_o[1].base.pdest;
    sche_wb_pdest_i[3] = iblk_mdu_wb_o.base.pdest;
    sche_wb_pdest_i[4] = mblk_wb_o.base.pdest;

    sche_wb_pdest_valid_i[0] = iblk_misc_wb_o.base.valid & iblk_misc_wb_o.base.we & iblk_misc_wb_ready_i;
    sche_wb_pdest_valid_i[1] = iblk_alu_wb_o[0].base.valid & iblk_alu_wb_o[0].base.we & iblk_alu_wb_ready_i[0];
    sche_wb_pdest_valid_i[2] = iblk_alu_wb_o[1].base.valid & iblk_alu_wb_o[1].base.we & iblk_alu_wb_ready_i[1];
    sche_wb_pdest_valid_i[3] = iblk_mdu_wb_o.base.valid & iblk_mdu_wb_o.base.we & iblk_mdu_wb_ready_i;
    sche_wb_pdest_valid_i[4] = mblk_wb_o.base.valid & mblk_wb_o.base.we & mblk_wb_ready_i;

    sche_misc_ready_i = iblk_misc_wb_ready_i;
    sche_alu_ready_i = iblk_alu_wb_ready_i;
    sche_mdu_ready_i = iblk_mdu_wb_ready_i;
    sche_mem_ready_i = mblk_wb_ready_i;

  end

  Scheduler inst_Scheduler
  (
    .clk              (clk),
    .a_rst_n          (rst_n),
    .flush_i          (sche_flush_i),
    .schedule_req     (sche_req),
    .schedule_rsp     (sche_rsp),
    .rob_alloc_req    (sche_rob_alloc_req),
    .rob_alloc_rsp    (sche_rob_alloc_rsp),
    .fl_free_valid_i  (sche_fl_free_valid_i),
    .fl_free_preg_i   (sche_fl_free_preg_i),
    .arch_rat_i       (sche_arch_rat_i),
    .wb_pdest_valid_i (sche_wb_pdest_valid_i),
    .wb_pdest_i       (sche_wb_pdest_i),
    .misc_issue_o     (sche_misc_issue_o),
    .misc_ready_i     (sche_misc_ready_i),
    .alu_issue_o      (sche_alu_issue_o),
    .alu_ready_i      (sche_alu_ready_i),
    .mdu_issue_o      (sche_mdu_issue_o),
    .mdu_ready_i      (sche_mdu_ready_i),
    .mem_issue_o      (sche_mem_issue_o),
    .mem_ready_i      (sche_mem_ready_i)
  );


/*================================= RegFile ===================================*/
  // 读取phy regfile
  // 默认顺序为misc、alu、mdu、mem / {mem, mdu, alu[1], alu[0], misc}
  always_comb begin : proc_read_rf
    rf_re_i[0] = sche_misc_issue_o.base_info.psrc0_valid;
    rf_re_i[1] = sche_misc_issue_o.base_info.psrc1_valid;
    rf_re_i[2] = sche_alu_issue_o[0].base_info.psrc0_valid;
    rf_re_i[3] = sche_alu_issue_o[0].base_info.psrc1_valid;
    rf_re_i[4] = sche_alu_issue_o[1].base_info.psrc0_valid;
    rf_re_i[5] = sche_alu_issue_o[1].base_info.psrc1_valid;
    rf_re_i[6] = sche_mdu_issue_o.base_info.psrc0_valid;
    rf_re_i[7] = sche_mdu_issue_o.base_info.psrc1_valid;
    rf_re_i[8] = sche_mem_issue_o.base_info.psrc0_valid;
    rf_re_i[9] = sche_mem_issue_o.base_info.psrc1_valid;

    rf_raddr_i[0] = sche_misc_issue_o.base_info.psrc0;
    rf_raddr_i[1] = sche_misc_issue_o.base_info.psrc1;
    rf_raddr_i[2] = sche_alu_issue_o[0].base_info.psrc0;
    rf_raddr_i[3] = sche_alu_issue_o[0].base_info.psrc1;
    rf_raddr_i[4] = sche_alu_issue_o[1].base_info.psrc0;
    rf_raddr_i[5] = sche_alu_issue_o[1].base_info.psrc1;
    rf_raddr_i[6] = sche_mdu_issue_o.base_info.psrc0;
    rf_raddr_i[7] = sche_mdu_issue_o.base_info.psrc1;
    rf_raddr_i[8] = sche_mem_issue_o.base_info.psrc0;
    rf_raddr_i[9] = sche_mem_issue_o.base_info.psrc1;

    rf_we_i[0] = iblk_misc_wb_o.base.valid & iblk_misc_wb_o.base.we;
    rf_we_i[1] = iblk_alu_wb_o[0].base.valid & iblk_alu_wb_o[0].base.we;
    rf_we_i[2] = iblk_alu_wb_o[1].base.valid & iblk_alu_wb_o[1].base.we;
    rf_we_i[3] = iblk_mdu_wb_o.base.valid & iblk_mdu_wb_o.base.we;
    rf_we_i[4] = mblk_wb_o.base.valid & mblk_wb_o.base.we;

    rf_waddr_i[0] = iblk_misc_wb_o.base.pdest;
    rf_waddr_i[1] = iblk_alu_wb_o[0].base.pdest;
    rf_waddr_i[2] = iblk_alu_wb_o[1].base.pdest;
    rf_waddr_i[3] = iblk_mdu_wb_o.base.pdest;
    rf_waddr_i[4] = mblk_wb_o.base.pdest;

    rf_wdata_i[0] = iblk_misc_wb_o.base.wdata;
    rf_wdata_i[1] = iblk_alu_wb_o[0].base.wdata;
    rf_wdata_i[2] = iblk_alu_wb_o[1].base.wdata;
    rf_wdata_i[3] = iblk_mdu_wb_o.base.wdata;
    rf_wdata_i[4] = mblk_wb_o.base.wdata;
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
    .re_i    (rf_re_i[4:0]),
    .we_i    (rf_we_i),
    .raddr_i (rf_raddr_i[4:0]),
    .waddr_i (rf_waddr_i),
    .data_i  (rf_wdata_i),
    .data_o  (rf_rdata_o[4:0])
  );

  PhysicalRegisterFile #(
    .READ_PORT_NUM(5),
    .WRITE_PORT_NUM(5),
    .DATA_WIDTH(32),
    .PHY_REG_NUM(64)
  ) U1_PhysicalRegisterFile (
    .clk     (clk),
    .a_rst_n (rst_n),
    .re_i    (rf_re_i[9:5]),
    .we_i    (rf_we_i),
    .raddr_i (rf_raddr_i[9:5]),
    .waddr_i (rf_waddr_i),
    .data_i  (rf_wdata_i),
    .data_o  (rf_rdata_o[9:5])
  );

  // 读取CSR寄存器
  always_comb begin : proc_read_csr
    csr_rd_addr = sche_misc_issue.base_info.src[23:10];  // 读取CSR指令的csr地址
  end

  // imm ext
  function logic[31:0] imm_ext(logic[25:0] src, ImmType imm_type, logic[31:0] pc);
    logic [31:0] imm;
    case (imm_type)
      `IMM_UI5  : imm = {27'b0 ,src[14:10]};
      `IMM_UI12 : imm = {20'b0, src[21:10]};
      `IMM_SI12 : imm = {{20{src[21]}}, src[21:10]};
      `IMM_SI14 : imm = {{18{src[23]}}, src[23:10]};
      `IMM_SI16 : imm = {{16{src[25]}}, src[25:10]};
      `IMM_SI20 : imm = {{12{src[24]}}, src[24: 5]};
      `IMM_SI26 : imm = {{ 6{src[9]}} , src[9: 0], src[25:10]};
      `IMM_PC   : imm = pc + {{12{src[24]}}, src[24: 5]};
      default : imm = '0;
    endcase
  endfunction : imm_ext

/*=============================== Integer Block ===============================*/
  always_comb begin
    iblk_flush_i = glo_flush;
    // 杂项指令在成为最旧指令时才执行
    iblk_misc_exe_i.base = '{valid: sche_misc_issue.valid, 
                           imm: imm_ext(sche_misc_issue_o.base_info.src,
                                        sche_misc_issue_o.base_info.imm_type,
                                        '0),  // 不能存在IMM_PC情况
                           src0: rf_rdata_o[0],
                           src1: rf_rdata_o[1],
                           pdest: sche_misc_issue_o.base_info.pdest, 
                           rob_idx: sche_misc_issue_o.base_info.rob_idx,
                           excp: sche_misc_issue_o.base_info.excp};
    iblk_misc_exe_i.misc_oc = sche_misc_issue.misc_oc;
    iblk_misc_exe_i.pc = sche_misc_issue.base_info.pc;
    iblk_misc_exe_i.npc = sche_misc_issue.base_info.npc;

    // 第一条ALU执行pipe
    iblk_alu_exe_i[0].base = '{valid: sche_alu_issue[0].base_info.valid, 
                                imm: imm_ext(sche_alu_issue_o[0].base_info.src,
                                             sche_alu_issue_o[0].base_info.imm_type,
                                             sche_alu_issue_o[0].base_info.pc),
                                src0: rf_rdata_o[2],
                                src1: rf_rdata_o[3],
                                pdest: sche_alu_issue_o[0].base_info.pdest, 
                                rob_idx: sche_alu_issue_o[0].base_info.rob_idx, 
                                excp: sche_alu_issue_o[0].base_info.excp};
    iblk_alu_exe_i[0].alu_oc = sche_alu_issue[0].alu_oc;

    // 第二条ALU执行pipe
    iblk_alu_exe_i[1].base = '{valid: sche_alu_issue[1].base_info.valid, 
                                imm: imm_ext(sche_alu_issue_o[1].base_info.src,
                                             sche_alu_issue_o[1].base_info.imm_type,
                                             sche_alu_issue_o[1].base_info.pc),
                                src0: rf_rdata_o[4],
                                src1: rf_rdata_o[5],
                                pdest: sche_alu_issue_o[1].base_info.pdest, 
                                rob_idx: sche_alu_issue_o[1].base_info.rob_idx, 
                                excp: sche_alu_issue_o[1].base_info.excp};
    iblk_alu_exe_i[1].alu_oc = sche_alu_issue[1].alu_oc;

    // 乘除法执行pipe   
    iblk_mdu_exe_i.base = '{valid: sche_mdu_issue.base_info.valid, 
                             imm: imm_ext(sche_mdu_issue_o.base_info.src,
                                          sche_mdu_issue_o.base_info.imm_type,
                                          sche_mdu_issue_o.base_info.pc),
                             src0: rf_rdata_o[6],
                             src1: rf_rdata_o[7],
                             pdest: sche_mdu_issue_o.base_info.pdest, 
                             rob_idx: sche_mdu_issue_o.base_info.rob_idx, 
                             excp: sche_mdu_issue_o.base_info.excp};
    iblk_mdu_exe_i.mdu_oc = sche_mdu_issue.mdu_oc;

    iblk_csr_rdata_i = csr_rd_data;
    iblk_tlbsrch_found_i = mmu_tlbsrch_found_o;
    iblk_tlbsrch_idx_i = mmu_tlbsrch_idx_o;

    // 特权指令在成为最旧指令时才执行
    iblk_misc_wb_ready_i = ~iblk_misc_wb_o.priv_instr |
                            iblk_misc_wb_o.base.rob_idx == rob_oldest_idx_o;
    iblk_alu_wb_ready_i = '1;
    iblk_mdu_wb_ready_i = '1;
  end

  IntegerBlock inst_IntegerBlock
  (
    .clk             (clk),
    .a_rst_n         (a_rst_n),
    .flush_i         (flush_i),
    /* exe */
    .misc_exe_i      (iblk_misc_exe_i),
    .misc_ready_o    (iblk_misc_ready_o),
    .alu_exe_i       (iblk_alu_exe_i),
    .alu_ready_o     (iblk_alu_ready_o),
    .mdu_exe_i       (iblk_mdu_exe_i),
    .mdu_ready_o     (iblk_mdu_ready_o),
    /* other exe info */
    .tlbsrch_valid_o (iblk_tlbsrch_valid_o),
    .tlbsrch_found_i (iblk_tlbsrch_found_i),
    .tlbsrch_idx_i   (iblk_tlbsrch_idx_i),
    .tlbehi_i        (iblk_tlbehi_i),
    .tlbelo0_i       (iblk_tlbelo0_i),
    .tlbelo1_i       (iblk_tlbelo1_i),
    .tlbidx_i        (iblk_tlbidx_i),
    .tlbasid_i       (iblk_tlbasid_i),
    .timer_64_i      (iblk_timer_64_i),
    .timer_id_i      (iblk_timer_id_i),
    .csr_rdata_i     (iblk_csr_rdata_i),
    /* write back */
    .misc_wb_o       (iblk_misc_wb_o),
    .misc_wb_ready_i (iblk_misc_wb_ready_i),
    .alu_wb_o        (iblk_alu_wb_o),
    .alu_wb_ready_i  (iblk_alu_wb_ready_i),
    .mdu_wb_o        (iblk_mdu_wb_o),
    .mdu_wb_ready_i  (iblk_mdu_wb_ready_i)
  );



/*=============================== Memory Block ================================*/
  always_comb begin
    mblk_flush_i = glo_flush;

    mblk_exe_i.base = '{valid: sche_mem_issue_o.base_info.valid, 
                         imm: imm_ext(sche_mem_issue_o.base_info.src,
                                      sche_mem_issue_o.base_info.imm_type,
                                      '0),
                         src0: rf_rdata_o[8],
                         src1: rf_rdata_o[9],
                         pdest: sche_mem_issue_o.base_info.pdest, 
                         rob_idx: sche_mem_issue_o.base_info.rob_idx, 
                         excp: sche_mem_issue_o.base_info.excp};
    mblk_exe_i.mem_oc = sche_mem_issue.mem_oc;

    mblk_addr_trans_rsp = mmu_addr_trans_rsp[1];

    mblk_wb_ready_i = mblk_wb_o.base.we | mblk_wb_o.base.rob_idx == rob_oldest_idx_o;
  end

  MemoryBlock inst_MemoryBlock
  (
    .clk            (clk),
    .a_rst_n        (a_rst_n),
    .flush_i        (mblk_flush_i),
    .exe_i          (mblk_exe_i),
    .exe_ready_o    (mblk_exe_ready_o),
    .addr_trans_req (mblk_addr_trans_req),
    .addr_trans_rsp (mblk_addr_trans_rsp),
    .axi4_mst       (dcache_axi4_mst),
    .wb_o           (mblk_wb_o),
    .wb_ready_i     (mblk_wb_ready_i)
  );


/*============================== Reorder Buffer ===============================*/
  always_comb begin
    rob_flush_i = '0;
    rob_alloc_req = sche_rob_alloc_req;
    // misc
    rob_wb_req[0] = '{valid: iblk_misc_wb_o.base.valid,
                       rob_idx: iblk_misc_wb_o.base.rob_idx,
                       exception: iblk_misc_wb_o.base.exception,
                       ecode: iblk_misc_wb_o.base.ecode, 
                       sub_ecode: iblk_misc_wb_o.base.sub_ecode, 
                       error_vaddr: iblk_misc_wb_o.base.error_vaddr, 
                       redirect: iblk_misc_wb_o.br_redirect,
                       br_target: iblk_misc_wb_o.br_target};
    // alu 0
    rob_wb_req[1] = '{valid: iblk_alu_wb_o[0].base.valid,
                       rob_idx: iblk_alu_wb_o[0].base.rob_idx,
                       exception: iblk_alu_wb_o[0].base.exception,
                       ecode: iblk_alu_wb_o[0].base.ecode,
                       sub_ecode: iblk_alu_wb_o[0].base.sub_ecode,
                       error_vaddr: iblk_alu_wb_o[0].base.error_vaddr,
                       redirect: '0,
                       br_target: '0};

    // alu 1
    rob_wb_req[2] = '{valid: iblk_alu_wb_o[1].base.valid,
                       rob_idx: iblk_alu_wb_o[1].base.rob_idx,
                       exception: iblk_alu_wb_o[1].base.exception,
                       ecode: iblk_alu_wb_o[1].base.ecode,
                       sub_ecode: iblk_alu_wb_o[1].base.sub_ecode,
                       error_vaddr: iblk_alu_wb_o[1].base.error_vaddr,
                       redirect: '0,
                       br_target: '0};

    // mdu
    rob_wb_req[3] = '{valid: iblk_mdu_wb_o.base.valid,
                       rob_idx: iblk_mdu_wb_o.base.rob_idx,
                       exception: iblk_mdu_wb_o.base.exception,
                       ecode: iblk_mdu_wb_o.base.ecode,
                       sub_ecode: iblk_mdu_wb_o.base.sub_ecode,
                       error_vaddr: iblk_mdu_wb_o.base.error_vaddr,
                       redirect: '0,
                       br_target: '0};
    // mem
    rob_wb_req[4] = '{valid: mblk_wb_o.base.valid,
                       rob_idx: mblk_wb_o.base.rob_idx,
                       exception: mblk_wb_o.base.exception,
                       ecode: mblk_wb_o.base.ecode,
                       sub_ecode: mblk_wb_o.base.sub_ecode,
                       error_vaddr: mblk_wb_o.base.error_vaddr,
                       redirect: '0,
                       br_target: '0};

  end

  ReorderBuffer inst_ReorderBuffer
  (
    .clk          (clk),
    .a_rst_n      (rst_n),
    .flush_i      (rob_flush_i),
    .alloc_req    (rob_alloc_req),
    .alloc_rsp    (rob_alloc_rsp),
    .wb_req       (rob_wb_req),
    .wb_rsp       (rob_wb_rsp),
    .cmt_o        (rob_cmt_o),
    .oldest_idx_o (rob_oldest_idx_o)
  );

/*================================== Commit ===================================*/
  assign glo_flush = rob_cmt_o.valid[0] & (rob_cmt_o.rob_entry[0].exception | rob_cmt_o.rob_entry[0].redirect);

  always_comb begin
    for (int i = 0; i < `COMMIT_WIDTH; i++) begin
      arch_rat_dest_valid_i[i] = rob_cmt_o.valid[i] & rob_cmt_o.rob_entry[i].arch_reg != 0;
      arch_rat_dest_i[i] = rob_cmt_o.rob_entry[i].arch_reg;
      arch_rat_preg_i[i] = rob_cmt_o.rob_entry[i].phy_reg;
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
  logic [31:0][31:0] arch_regfile, arch_regfile_n;

  always_comb begin
    arch_regfile_n = arch_regfile;
    for (int i = 0; i < `COMMIT_WIDTH; i++) begin
      if (rob_cmt_o.valid[i] && 
          rob_cmt_o.rob_entry[i].arch_reg != 0) begin
        arch_regfile_n[rob_cmt_o.rob_entry[i].arch_reg] = rob_cmt_o.rob_entry[i].rf_wdata;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      arch_regfile <= '0;
    end else begin
      arch_regfile <= arch_regfile_n;
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

    mmu_addr_trans_req[0] = icache_addr_trans_req;
    mmu_addr_trans_req[1] = mblk_addr_trans_req;

    mmu_tlbsrch_en_i = iblk_tlbsrch_valid_o;

    mmu_tlbfill_en_i = iblk_misc_wb_o.base.valid &
                       iblk_misc_wb_ready_i &
                       iblk_misc_wb_o.PRIV_INSTR  &
                       iblk_misc_wb_o.priv_op == `PRIV_TLBFILL;
    mmu_tlbwr_en_i = iblk_misc_wb_o.base.valid &
                     iblk_misc_wb_ready_i &
                     iblk_misc_wb_o.PRIV_INSTR &
                     iblk_misc_wb_o.priv_op == `PRIV_TLBWR;
    mmu_rand_index_i = csr_rand_index;
    mmu_tlbehi_i = csr_tlbehi_out;
    mmu_tlbelo0_i = csr_tlbelo0_out;
    mmu_tlbelo1_i = csr_tlbelo1_out;
    mmu_tlbidx_i = csr_tlbidx_out;
    mmu_ecode_i = csr_ecode_out;

    mmu_invtlb_en_i = iblk_misc_wb_o.base.valid &
                      iblk_misc_wb_ready_i &
                      iblk_misc_wb_o.PRIV_INSTR &
                      iblk_misc_wb_o.priv_op == `PRIV_TLBINV;
    mmu_invtlb_asid_i = iblk_misc_wb_o.invtlb_asid;
    mmu_invtlb_vpn_i = iblk_misc_wb_o.vaddr[`PROC_VALEN - 1:13];
    mmu_invtlb_op_i = iblk_misc_wb_o.invtlb_op;
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
    .addr_trans_req (mmu_addr_trans_req),
    .addr_trans_rsp (mmu_addr_trans_rsp),
    // tlb search
    .tlbsrch_en_i   (mmu_tlbsrch_en_i),
    .tlbsrch_found_o(mmu_tlbsrch_found_o),
    .tlbsrch_idx_o  (mmu_tlbsrch_idx_o),
    // tlbfill tlbwr tlb write
    .tlbfill_en_i   (mmu_tlbfill_en_i),
    .tlbwr_en_i     (mmu_tlbwr_en_i),
    .rand_idx_i     (mmu_rand_index_i),
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
    csr_rd_addr = sche_misc_issue_o.base_info.src[23:10];
    csr_wr_en = iblk_misc_wb_o.base.valid &
                iblk_misc_wb_ready_i&
                iblk_misc_wb_o.csr_we;
    csr_wr_addr = iblk_misc_wb_o.csr_waddr;
    csr_wr_data = iblk_misc_wb_o.csr_wdata;

    csr_interrupt = interrupt;

    csr_excp_flush = rob_cmt_o.valid[0] & rob_cmt_o.rob_entry.exception;
    csr_ertn_flush = iblk_misc_wb_o.base.valid &
                     iblk_misc_wb_ready_i &
                     iblk_misc_wb_o.PRIV_INSTR &
                     iblk_misc_wb_o.priv_op == `PRIV_ERTN;
    csr_era_in = rob_cmt_o.rob_entry.pc;
    csr_esubcode_in = rob_cmt_o.rob_entry.sub_ecode;
    csr_ecode_in = rob_cmt_o.rob_entry.ecode;
    csr_va_error_in = rob_cmt_o.valid[0] & 
                      rob_cmt_o.rob_entry.exception &
                      rob_cmt_o.rob_entry.ecode inside 
                      {`ECODE_ADE, `ECODE_TLBR, `ECODE_PIF, `ECODE_PPI,
                       `ECODE_ALE, `ECODE_PME,  `ECODE_PIS, `ECODE_PIL};
    csr_bad_va_in = rob_cmt_o.rob_entry[0].error_vaddr;

    csr_tlbsrch_en = iblk_misc_wb_o.base.valid &
                     iblk_misc_wb_ready_i &
                     iblk_misc_wb_o.PRIV_INSTR &
                     iblk_misc_wb_o.priv_op == `PRIV_TLBSRCH;
    csr_tlbsrch_found = iblk_misc_wb_o.tlbsrch_found;
    csr_tlbsrch_index = iblk_misc_wb_o.tlbsrch_idx;

    csr_excp_tlbrefill = rob_cmt_o.valid[0] & 
                         rob_cmt_o.rob_entry.exception &
                         rob_cmt_o.rob_entry.ecode == `ECODE_TLBR;
    csr_excp_tlb = rob_cmt_o.valid[0] & 
                   rob_cmt_o.rob_entry.exception &
                   rob_cmt_o.rob_entry.ecode inside
                   {`ECODE_TLBR, `ECODE_PIF, `ECODE_PPI,
                    `ECODE_PME,  `ECODE_PIS, `ECODE_PIL};
    csr_excp_tlb_vppn = rob_cmt_o.rob_entry[0].error_vaddr;

    csr_llbit_in = '0;
    csr_llbit_set_in = '0;

    csr_tlbrd_en = iblk_misc_wb_o.base.valid &
                   iblk_misc_wb_ready_i &
                   iblk_misc_wb_o.PRIV_INSTR &
                   iblk_misc_wb_o.priv_op == `PRIV_TLBRD;
    csr_tlbehi_in = iblk_misc_wb_o.tlbrd_ehi;
    csr_tlbelo0_in = iblk_misc_wb_o.tlbrd_elo0;
    csr_tlbelo1_in = iblk_misc_wb_o.tlbrd_elo1;
    csr_tlbidx_in = iblk_misc_wb_o.tlbrd_idx;
    csr_asid_in = iblk_misc_wb_o.tlbrd_asid;
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



