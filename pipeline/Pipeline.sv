// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Pipeline.sv
// Create  : 2024-03-11 14:53:30
// Revise  : 2024-04-01 23:06:08
// Description :
//   执行单元的排序（所有的代码排序遵循此顺序）
//   [0] misc
//   [1] alu[0]
//   [2] alu[1]
//   [3] mdu
//   [4] mem
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

`include "BranchPredictionUnit.svh"
`include "Cache.svh"
`include "ControlStatusRegister.svh"
`include "Decoder.svh"
`include "MemoryManagementUnit.svh"
`include "Pipeline.svh"
`include "ReorderBuffer.svh"
`include "Scheduler.svh"


module Pipeline (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input logic [7:0] interrupt,
  AXI4.Master icache_axi4_mst,
  AXI4.Master dcache_axi4_mst
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);
/*=============================== Signal Define ===============================*/
  /* pipeline flush */
  logic global_flush;
  // commit 阶段产生
  logic excp_flush;      // 异常
  logic tlbrefill_flush; // TLB充填异常（此时excp_flush也会拉高，由于入口特殊故单独列出）
  logic redirect_flush;  // 分支预测失败
  // write back 阶段产生（但是commit阶段才真正flush）
  logic ertn_flush;      // ERET返回（返回地址为csr_era）
  logic refetch_flush;   // 重取指令（ibar、priv、icacop、idel）
  logic ibar_flush;      // IBAR指令
  logic priv_flush;      // 特权指令（csr_rd修改可撤回，不需要flush）
  logic icacop_flush;    // ICache操作
  logic idle_flush;      // IDLE指令

  /* Branch Prediction Unit */
  BpuReqSt bpu_req;
  BpuRspSt bpu_rsp;

  /* Fetch Address Queue */
  // FAQ_PushReqSt faq_push_req_st;
  // FAQ_PopReqSt faq_pop_req_st;
  // FAQ_PushRspSt faq_push_rsp_st;
  // FAQ_PopRspSt faq_pop_rsp_st;
  // logic faq_flush_i;

  /* ICache */
  logic icache_flush_i;
  ICacheReqSt icache_req;
  ICacheRspSt icache_rsp;
  MmuAddrTransRspSt icache_addr_trans_rsp;
  MmuAddrTransReqSt icache_addr_trans_req;
  IcacopReqSt icacop_req;
  IcacopRspSt icacop_rsp;

  /* Pre Decoder */
  ICacheRspSt icache_rsp_buffer;
  PreOptionCodeSt [`FETCH_WIDTH - 1:0] pre_option_code_o;

  logic pre_check_redirect_o;
  logic [31:0] pre_check_pc_o;
  logic [31:0] pre_check_target_o;
  logic [$clog2(`RAS_STACK_DEPTH) - 1:0] pre_check_ras_ptr_o;
  logic [`LPHT_ADDR_WIDTH - 1:0] pre_check_lphr_idx_o;
  logic [1:0]  pre_check_valid_o;
  

  /* Instruction Buffer */
  logic ibuf_flush_i;
  logic [`FETCH_WIDTH - 1:0] ibuf_write_valid_i;
  logic ibuf_write_ready_o;
  IbufDataSt [`FETCH_WIDTH - 1:0] ibuf_write_data_i;
  logic [`DECODE_WIDTH - 1:0] ibuf_read_valid_o;
  logic [`DECODE_WIDTH - 1:0] ibuf_read_ready_i;
  IbufDataSt [`DECODE_WIDTH - 1:0] ibuf_read_data_o;

  /* Decoder */
  OptionCodeSt [`DECODE_WIDTH - 1:0] decoder_option_code_o;
  logic [`DECODE_WIDTH - 1:0][4:0] decoder_src0;
  logic [`DECODE_WIDTH - 1:0][4:0] decoder_src1;
  logic [`DECODE_WIDTH - 1:0][4:0] decoder_dest;

  /* Scheduler */
  logic sche_flush_i;
  ScheduleReqSt sche_req;
  ScheduleRspSt sche_rsp;
  RobAllocReqSt sche_rob_alloc_req;
  RobAllocRspSt sche_rob_alloc_rsp;

  logic sche_csr_has_int_i;
  logic [1:0] sche_csr_plv_i;

  logic [$clog2(`PHY_REG_NUM) - 1:0] sche_fl_arch_heah;
  logic [$clog2(`PHY_REG_NUM) - 1:0] sche_fl_arch_tail;
  logic [$clog2(`PHY_REG_NUM + 1) - 1:0] sche_fl_arch_cnt;
  logic [`COMMIT_WIDTH - 1:0] sche_free_valid_i;
  logic [`COMMIT_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] sche_free_preg_i;
  logic [`PHY_REG_NUM - 1:0] sche_rat_arch_valid_i;

  logic [`WB_WIDTH - 1:0] sche_wb_i;
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
  logic [9:0] rf_re_i;
  logic [4:0] rf_we_i;
  logic [4:0][$clog2(`PHY_REG_NUM) - 1:0] rf_waddr_i;
  logic [9:0][$clog2(`PHY_REG_NUM) - 1:0] rf_raddr_i;
  logic [4:0][31:0] rf_wdata_i;
  logic [9:0][31:0] rf_rdata_o;

  /* Integer Block */
  // IntegerBlock --> iblk
  logic iblk_flush_i;
  MiscExeSt iblk_misc_exe_i;
  logic iblk_misc_ready_o;
  AluExeSt [1:0] iblk_alu_exe_i;
  logic [1:0] iblk_alu_ready_o;
  MduExeSt iblk_mdu_exe_i;
  logic iblk_mdu_ready_o;
  // tlb srch
  logic iblk_tlbsrch_valid_o;
  logic iblk_tlbsrch_found_i;
  logic [$clog2(`TLB_ENTRY_NUM) - 1:0] iblk_tlbsrch_idx_i;
  // tlb read
  logic iblk_tlbrd_valid_o;
  logic [31:0] iblk_tlbehi_i;
  logic [31:0] iblk_tlbelo0_i;
  logic [31:0] iblk_tlbelo1_i;
  logic [31:0] iblk_tlbidx_i;
  logic [ 9:0] iblk_tlbasid_i;
  // tlb inv
  logic [ 5:0] iblk_invtlb_op_i;
  // csr read
  logic [63:0] iblk_timer_64_i;
  logic [31:0] iblk_timer_id_i;
  logic        iblk_csr_rstat_i;
  logic [31:0] iblk_csr_rdata_i;
  // write back
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
  IcacopReqSt mblk_icacop_req;
  IcacopRspSt mblk_icacop_rsp;
  MemWbSt mblk_wb_o;
  logic mblk_wb_ready_i;

  /* Reorder Buffer (Write Back) */
  logic rob_flush_i;
  RobAllocReqSt rob_alloc_req;
  RobAllocRspSt rob_alloc_rsp;
  MiscWbSt rob_misc_wb_req;
  AluWbSt [1:0] rob_alu_wb_req;
  MduWbSt rob_mdu_wb_req;
  MemWbSt rob_mem_wb_req;
  RobWbRspSt rob_misc_wb_rsp;
  RobWbRspSt [1:0] rob_alu_wb_rsp;
  RobWbRspSt rob_mdu_wb_rsp;
  RobWbRspSt rob_mem_wb_rsp;
  RobCmtSt rob_cmt_o;

  // 写回信号
  logic [`WB_WIDTH - 1:0] write_back_valid;
  logic [`WB_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] write_back_pdest;

  /* commit */
  logic [`COMMIT_WIDTH - 1:0] free_valid;
  logic [`COMMIT_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] free_preg;

  logic [`PHY_REG_NUM - 1:0] arch_rat_valid_o;
  logic [`COMMIT_WIDTH - 1:0] arch_rat_dest_valid_i;
  logic [`COMMIT_WIDTH - 1:0][4:0] arch_rat_dest_i;
  logic [`COMMIT_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] arch_rat_preg_i;

  
  logic [$clog2(`PHY_REG_NUM) - 1:0] arch_fl_head_o;
  logic [$clog2(`PHY_REG_NUM) - 1:0] arch_fl_tail_o;
  logic [$clog2(`PHY_REG_NUM + 1) - 1:0] arch_fl_cnt_o;
  logic [`COMMIT_WIDTH - 1:0] arch_fl_alloc_valid_i;
  logic [`COMMIT_WIDTH - 1:0] arch_fl_free_valid_i;
  logic [`COMMIT_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] arch_fl_free_preg_i;

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

  logic        mmu_tlbrd_en_i;
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
  logic [31:0]  csr_ecfg_diff;
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
  logic idle_lock;
  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      idle_lock <= 0;
    end else begin
      if (idle_flush && !csr_has_int) begin
        idle_lock <= '1;
      end else if (csr_has_int) begin
        idle_lock <= '0;
      end
    end
  end

  logic br_select;
  
  always_comb begin
    br_select = '0;
    for (int i = 1; i < `COMMIT_WIDTH; i++) begin
      if (rob_cmt_o.valid[i] && rob_cmt_o.rob_entry[i].instr_type == `BR_INSTR) begin
        br_select = i;
      end
    end

    bpu_req.next = icache_rsp.ready & ~idle_lock;
    bpu_req.redirect = global_flush | pre_check_redirect_o;
    bpu_req.target = tlbrefill_flush      ? csr_tlbrentry_out :
                     excp_flush           ? csr_eentry_out :
                     ertn_flush           ? csr_era_out :  // sys 和 brk恢复时应该跳到era+4（软件控制）
                     refetch_flush        ? rob_cmt_o.rob_entry[0].pc + 4    :
                     redirect_flush       ? rob_cmt_o.rob_entry[0].br_target :
                     pre_check_redirect_o ? pre_check_target_o :
                                            32'h1c00_0000;
    // for bpu updata
    bpu_req.pc = global_flush                                   ? rob_cmt_o.rob_entry[0].pc : 
                 pre_check_redirect_o                           ? pre_check_pc_o :
                                                                  rob_cmt_o.rob_entry[br_select].pc;

    bpu_req.taken = global_flush                                   ? rob_cmt_o.rob_entry[0].br_taken :
                    pre_check_redirect_o                           ? 1'b0 :
                                                                     rob_cmt_o.rob_entry[br_select].br_taken;

    bpu_req.btb_update = global_flush | pre_check_redirect_o | |rob_cmt_o.valid;
    bpu_req.br_type    = global_flush                                   ? rob_cmt_o.rob_entry[0].br_type :
                         pre_check_redirect_o                           ? 2'b00 :
                                                                          rob_cmt_o.rob_entry[br_select].br_type;

    bpu_req.lpht_update = global_flush | pre_check_redirect_o | |rob_cmt_o.valid;
    bpu_req.lphr   = global_flush                                   ? rob_cmt_o.rob_entry[0].br_info.lphr :
                     pre_check_redirect_o                           ? 2'b00 :
                                                                      rob_cmt_o.rob_entry[br_select].br_info.lphr;

    if (rob_cmt_o.rob_entry[br_select].br_type == `CALL && 
        rob_cmt_o.rob_entry[br_select].br_info != `CALL &&
        rob_cmt_o.valid[br_select]) begin
      bpu_req.ras_redirect = 2'd2;  // 重定向并写入
    end else if (rob_cmt_o.rob_entry[br_select].br_type == `RETURN && 
                 rob_cmt_o.rob_entry[br_select].br_info != `RETURN &&
                 rob_cmt_o.valid[br_select]) begin
      bpu_req.ras_redirect = 2'd1;  // 重定向
    end else begin
      bpu_req.ras_redirect = global_flush | pre_check_redirect_o;  // 视情况重定向
    end

    if (pre_check_redirect_o && ~global_flush) begin  // 确保global flush优先
      bpu_req.ras_ptr = pre_check_ras_ptr_o;
    end else if (rob_cmt_o.rob_entry[br_select].br_type == `CALL) begin
      bpu_req.ras_ptr = rob_cmt_o.rob_entry[br_select].br_info.ras_ptr + 1;
    end else if (rob_cmt_o.rob_entry[br_select].br_type == `RETURN) begin
      bpu_req.ras_ptr = rob_cmt_o.rob_entry[br_select].br_info.ras_ptr - 1;
    end else begin
      bpu_req.ras_ptr = rob_cmt_o.rob_entry[br_select].br_info.ras_ptr;
    end

  end

  BranchPredictionUnit U_BranchPredictionUnit (
    .clk(clk), 
    .rst_n(rst_n), 
    .req(bpu_req), 
    .rsp(bpu_rsp)
  );

/*============================ Fetch Address Queue ============================*/
  // always_comb begin
  //   faq_flush_i = glo_flush;

  //   faq_push_req_st.valid = bpu_rsp_st.valid;
  //   faq_push_req_st.vaddr = bpu_rsp_st.pc;

  //   faq_pop_req_st.valid = icache_fetch_rsp_st.ready;
  //   faq_pop_req_st.ready = icache_fetch_rsp_st.ready;
  // end

  // FetchAddressQueue U_FetchAddressQueue (
  //   .clk         (clk),
  //   .a_rst_n     (rst_n),
  //   .flush_i     (faq_flush_i),
  //   .push_req_st (faq_push_req_st),
  //   .pop_req_st  (faq_pop_req_st),
  //   .push_rsp_st (faq_push_rsp_st),
  //   .pop_rsp_st  (faq_pop_rsp_st)
  // );

/*========================== Instruction Fetch Unit ===========================*/
  always_comb begin
    icache_flush_i = global_flush;

    icache_req.valid   = bpu_rsp.valid;
    icache_req.vaddr   = bpu_rsp.pc;
    icache_req.npc     = bpu_rsp.npc;
    icache_req.br_info = bpu_rsp.br_info;
    icache_req.ready   = ibuf_write_ready_o;

    icache_addr_trans_rsp = mmu_addr_trans_rsp[0];

    icacop_req = mblk_icacop_req;
  end

  ICache inst_ICache
  (
    .clk            (clk),
    .a_rst_n        (rst_n),
    .flush_i        (icache_flush_i),
    .pre_flush_i    (pre_check_redirect_o),
    .icache_req     (icache_req),
    .icache_rsp     (icache_rsp),
    .addr_trans_rsp (icache_addr_trans_rsp),
    .addr_trans_req (icache_addr_trans_req),
    .icacop_req     (icacop_req),
    .icacop_rsp     (icacop_rsp),
    .axi4_mst       (icache_axi4_mst)
  );

/*================================ Pre Decoder ================================*/
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n || global_flush) begin
      icache_rsp_buffer <= 0;
    end else begin
      if (ibuf_write_ready_o) begin
        if (pre_check_redirect_o) begin
          icache_rsp_buffer.valid <= '0;
        end else begin
          icache_rsp_buffer <= icache_rsp;
        end
      end
    end
  end

  for (genvar i = 0; i < `FETCH_WIDTH; i++) begin : gen_pre_decoder
    PreDecoder inst_PreDecoder (.instr_i(icache_rsp_buffer.instr[i]), .pre_option_code_o(pre_option_code_o[i]));
  end

  // TODO 是否需要修正NPC？？？ 似乎可以通过flush的优先级解决（ertn）
  PreChecker inst_PreChecker
  (
    .clk          (clk),
    .rst_n        (rst_n),
    .pc_i         (icache_rsp_buffer.vaddr),
    .valid_i      (icache_rsp_buffer.valid),
    .is_branch_i  ({pre_option_code_o[1].is_branch, pre_option_code_o[0].is_branch}),  // TODO 参数化
    .br_info_i    (icache_rsp_buffer.br_info),
    // output
    .redirect_o   (pre_check_redirect_o),
    .pc_o         (pre_check_pc_o),
    .target_o     (pre_check_target_o),
    .ras_ptr_o    (pre_check_ras_ptr_o),
    .lphr_idx_o   (pre_check_lphr_idx_o),
    .valid_o      (pre_check_valid_o)
  );



/*============================ Instruction Buffer =============================*/
  // 在此处进行队列压缩，剔除无效的指令，第[i]个write_data应该写入第ibuf_idx[i]个icache的数据
  logic [`FETCH_WIDTH - 1:0][$clog2(`FETCH_WIDTH) - 1:0] ibuf_idx;
  always_comb begin
    ibuf_flush_i = global_flush;

    ibuf_idx[0] = '0;
    for (int i = 1; i < `FETCH_WIDTH; i++) begin
      ibuf_idx[i] = ibuf_idx[i - 1] + icache_rsp_buffer.valid[i - 1];
    end

    ibuf_write_valid_i = '0;
    ibuf_write_data_i = '0;
    for (int i = 0; i < `FETCH_WIDTH; i++) begin
      // 指令有效时才写入
      if (pre_check_valid_o[i]) begin  // 屏蔽掉分支预测有误的指令
        ibuf_write_valid_i[ibuf_idx[i]] = 1'b1;

        ibuf_write_data_i[ibuf_idx[i]].valid = 1'b1;  // TODO 优化这个地方
        ibuf_write_data_i[ibuf_idx[i]].pc = icache_rsp_buffer.vaddr[i];
        ibuf_write_data_i[ibuf_idx[i]].npc = icache_rsp_buffer.npc[i];
        ibuf_write_data_i[ibuf_idx[i]].br_info = icache_rsp_buffer.br_info;
        ibuf_write_data_i[ibuf_idx[i]].instr = icache_rsp_buffer.instr[i];
        ibuf_write_data_i[ibuf_idx[i]].excp = icache_rsp_buffer.excp;
        ibuf_write_data_i[ibuf_idx[i]].pre_oc = pre_option_code_o[i];
      end
    end

    ibuf_read_ready_i = {`DECODE_WIDTH{sche_rsp.ready}};
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
    .write_valid_i (ibuf_write_valid_i),
    .write_ready_o (ibuf_write_ready_o),
    .write_data_i  (ibuf_write_data_i),
    .read_valid_o  (ibuf_read_valid_o),
    .read_ready_i  (ibuf_read_ready_i),
    .read_data_o   (ibuf_read_data_o)
  );

/*================================== Decoder ==================================*/
  // 对控制相关信息解码
  for (genvar i = 0; i < `DECODE_WIDTH; i++) begin : gen_decoder
    Decoder inst_Decoder (.instr_i(ibuf_read_data_o[i].instr), .option_code_o(decoder_option_code_o[i]));
  end

  // 处理特殊的解码
  // TODO: 优化这个处理
  always_comb begin
    // 三个CSR特权指令
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      if (decoder_option_code_o[i].priv_op == `PRIV_CSR_XCHG) begin
        case (ibuf_read_data_o[i].instr[9:5])
          5'b0 : decoder_option_code_o[i].priv_op = `PRIV_CSR_READ;
          5'b1 : decoder_option_code_o[i].priv_op = `PRIV_CSR_WRITE;
          default : decoder_option_code_o[i].priv_op = `PRIV_CSR_XCHG;
        endcase
      end
    end
    // 两个rdtimel指令
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      if (decoder_option_code_o[i].misc_op == `MISC_RDCNTVL) begin
        if (ibuf_read_data_o[i].instr[9:5] != 0) begin
          decoder_option_code_o[i].misc_op = `MISC_RDCNTID;
        end
      end
    end
  end

  // 准备寄存器编号
  always_comb begin
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      case (ibuf_read_data_o[i].pre_oc.src0_type)
        `SRC_R0 : decoder_src0[i] = 5'd0;
        `SRC_RD : decoder_src0[i] = ibuf_read_data_o[i].instr[4:0];
        `SRC_RJ : decoder_src0[i] = ibuf_read_data_o[i].instr[9:5];
        `SRC_RK : decoder_src0[i] = ibuf_read_data_o[i].instr[14:10];
        default : /* default */;
      endcase
      case (ibuf_read_data_o[i].pre_oc.src1_type)
        `SRC_R0 : decoder_src1[i] = 5'd0;
        `SRC_RD : decoder_src1[i] = ibuf_read_data_o[i].instr[4:0];
        `SRC_RJ : decoder_src1[i] = ibuf_read_data_o[i].instr[9:5];
        `SRC_RK : decoder_src1[i] = ibuf_read_data_o[i].instr[14:10];
        default : /* default */;
      endcase
      case (ibuf_read_data_o[i].pre_oc.dest_type)
        `DEST_R0 : decoder_dest[i] = 5'd0;
        `DEST_RD : decoder_dest[i] = ibuf_read_data_o[i].instr[4:0];
        `DEST_JD : decoder_dest[i] = ibuf_read_data_o[i].instr[9:5] | ibuf_read_data_o[i].instr[4:0];
        `DEST_RA : decoder_dest[i] = 5'd1;
        default : /* default */;
      endcase
    end
  end

/*================================= Scheduler ================================*/
  /* Dispatch/Wake up/Select */
  always_comb begin
    sche_flush_i = global_flush;

    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      sche_req.valid[i] = ibuf_read_valid_o[i];
      sche_req.pc[i] = ibuf_read_data_o[i].pc;
      sche_req.npc[i] = ibuf_read_data_o[i].npc;
      sche_req.br_info[i] = ibuf_read_data_o[i].br_info;
      sche_req.src[i] = ibuf_read_data_o[i].instr[25:0];
      sche_req.arch_src0[i] = decoder_src0[i];
      sche_req.arch_src1[i] = decoder_src1[i];
      sche_req.arch_dest[i] = decoder_dest[i];
      sche_req.option_code[i] = decoder_option_code_o[i];
      sche_req.excp[i] = ibuf_read_data_o[i].excp;
    end

    sche_rob_alloc_rsp = rob_alloc_rsp;

    sche_csr_has_int_i = csr_has_int;
    sche_csr_plv_i = csr_plv_out;

    // phy reg free
    sche_free_valid_i = free_valid;
    sche_free_preg_i = free_preg;

    // free list flush
    sche_fl_arch_heah = arch_fl_head_o;
    sche_fl_arch_tail = arch_fl_tail_o;
    sche_fl_arch_cnt = arch_fl_cnt_o;

    // rat flush
    sche_rat_arch_valid_i = arch_rat_valid_o;

    // for wake up
    sche_wb_i = write_back_valid;
    sche_wb_pdest_i = write_back_pdest;

    sche_misc_ready_i = iblk_misc_ready_o;
    sche_alu_ready_i = iblk_alu_ready_o;
    sche_mdu_ready_i = iblk_mdu_ready_o;
    sche_mem_ready_i = mblk_exe_ready_o;

  end

  Scheduler U_Scheduler
  (
    .clk              (clk),
    .a_rst_n          (rst_n),
    .flush_i          (sche_flush_i),
    .schedule_req     (sche_req),
    .schedule_rsp     (sche_rsp),
    .rob_alloc_req    (sche_rob_alloc_req),
    .rob_alloc_rsp    (sche_rob_alloc_rsp),
    .csr_has_int_i    (sche_csr_has_int_i),
    .csr_plv_i        (sche_csr_plv_i),
    .fl_arch_heah     (sche_fl_arch_heah),
    .fl_arch_tail     (sche_fl_arch_tail),
    .fl_arch_cnt      (sche_fl_arch_cnt),
    .free_valid_i     (sche_free_valid_i),
    .free_preg_i      (sche_free_preg_i),
    .rat_arch_valid_i (sche_rat_arch_valid_i),
    .wb_i             (sche_wb_i),
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

    rf_we_i = write_back_valid;
    rf_waddr_i = write_back_pdest;

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
    csr_rd_addr = sche_misc_issue_o.base_info.src[23:10];  // 读取CSR指令的csr地址
  end

  // imm ext
  // 读mmu信息

/*=============================== Integer Block ===============================*/
  always_comb begin
    iblk_flush_i = global_flush;
    // 杂项指令在成为最旧指令时才执行
    iblk_misc_exe_i.base = is2exe(sche_misc_issue_o.base_info, sche_misc_issue_o.valid, rf_rdata_o[1], rf_rdata_o[0]);
    iblk_misc_exe_i.misc_oc = sche_misc_issue_o.misc_oc;
    iblk_misc_exe_i.pc = sche_misc_issue_o.base_info.pc;
    iblk_misc_exe_i.npc = sche_misc_issue_o.base_info.npc;
    iblk_misc_exe_i.arch_rd = sche_misc_issue_o.base_info.src[4:0];
    iblk_misc_exe_i.arch_rj = sche_misc_issue_o.base_info.src[9:5];

    // 第一条ALU执行pipe
    iblk_alu_exe_i[0].base = is2exe(sche_alu_issue_o[0].base_info, sche_alu_issue_o[0].valid, rf_rdata_o[3], rf_rdata_o[2]);
    iblk_alu_exe_i[0].alu_oc = sche_alu_issue_o[0].alu_oc;

    // 第二条ALU执行pipe
    iblk_alu_exe_i[1].base = is2exe(sche_alu_issue_o[1].base_info, sche_alu_issue_o[1].valid, rf_rdata_o[5], rf_rdata_o[4]);
    iblk_alu_exe_i[1].alu_oc = sche_alu_issue_o[1].alu_oc;

    // 乘除法执行pipe   
    iblk_mdu_exe_i.base = is2exe(sche_mdu_issue_o.base_info, sche_mdu_issue_o.valid, rf_rdata_o[7], rf_rdata_o[6]);
    iblk_mdu_exe_i.mdu_oc = sche_mdu_issue_o.mdu_oc;

    

    iblk_tlbsrch_found_i = mmu_tlbsrch_found_o;
    iblk_tlbsrch_idx_i = mmu_tlbsrch_idx_o;
    
    iblk_tlbehi_i = mmu_tlbehi_o;
    iblk_tlbelo0_i = mmu_tlbelo0_o;
    iblk_tlbelo1_i = mmu_tlbelo1_o;
    iblk_tlbidx_i = mmu_tlbidx_o;
    iblk_tlbasid_i = mmu_tlbasid_o;

    iblk_invtlb_op_i = sche_misc_issue_o.base_info.src[4:0];


    iblk_csr_rstat_i = sche_misc_issue_o.misc_oc.instr_type == `PRIV_INSTR &
                       (
                          sche_misc_issue_o.misc_oc.priv_op == `PRIV_CSR_READ |
                          sche_misc_issue_o.misc_oc.priv_op == `PRIV_CSR_WRITE |
                          sche_misc_issue_o.misc_oc.priv_op == `PRIV_CSR_XCHG
                        ) & sche_misc_issue_o.base_info.src[23:10] == 14'h5; // ESTAT = 14'h5;
    iblk_csr_rdata_i = csr_rd_data;
    iblk_timer_64_i = csr_timer_64_out;
    iblk_timer_id_i = csr_tid_out;


    // 特权指令在成为最旧指令时才执行
    iblk_misc_wb_ready_i = rob_misc_wb_rsp.ready;
    for (int i = 0; i < 2; i++) begin
      iblk_alu_wb_ready_i[i] = rob_alu_wb_rsp[i].ready;
    end
    iblk_mdu_wb_ready_i = rob_mdu_wb_rsp.ready;
  end

  IntegerBlock inst_IntegerBlock
  (
    .clk             (clk),
    .a_rst_n         (rst_n),
    .flush_i         (iblk_flush_i),
    /* exe */
    .misc_exe_i      (iblk_misc_exe_i),
    .misc_ready_o    (iblk_misc_ready_o),
    .alu_exe_i       (iblk_alu_exe_i),
    .alu_ready_o     (iblk_alu_ready_o),
    .mdu_exe_i       (iblk_mdu_exe_i),
    .mdu_ready_o     (iblk_mdu_ready_o),
    /* other exe info */
    // tlbsrch
    .tlbsrch_valid_o (iblk_tlbsrch_valid_o),
    .tlbsrch_found_i (iblk_tlbsrch_found_i),
    .tlbsrch_idx_i   (iblk_tlbsrch_idx_i),
    // tlbrd
    .tlbrd_valid_o   (iblk_tlbrd_valid_o),
    .tlbehi_i        (iblk_tlbehi_i),
    .tlbelo0_i       (iblk_tlbelo0_i),
    .tlbelo1_i       (iblk_tlbelo1_i),
    .tlbidx_i        (iblk_tlbidx_i),
    .tlbasid_i       (iblk_tlbasid_i),
    // inv tlb
    .invtlb_op_i     (iblk_invtlb_op_i),
    // csr data
    .timer_64_i      (iblk_timer_64_i),
    .timer_id_i      (iblk_timer_id_i),
    .csr_rdata_i     (iblk_csr_rdata_i),
    .csr_rstat_i     (iblk_csr_rstat_i),
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
    mblk_flush_i = global_flush;

    mblk_exe_i.base = is2exe(sche_mem_issue_o.base_info, sche_mem_issue_o.valid, rf_rdata_o[9], rf_rdata_o[8]);
    mblk_exe_i.mem_oc = sche_mem_issue_o.mem_oc;
    mblk_exe_i.code = sche_mem_issue_o.base_info.src[4:0];
    mblk_exe_i.llbit = csr_llbit_out;  // 决定SC.W指令是否执行

    mblk_addr_trans_rsp = mmu_addr_trans_rsp[1];

    mblk_icacop_rsp = icacop_rsp;

    mblk_wb_ready_i = rob_mem_wb_rsp.ready;
  end

  MemoryBlock inst_MemoryBlock
  (
    .clk            (clk),
    .a_rst_n        (rst_n),
    .flush_i        (mblk_flush_i),
    .exe_i          (mblk_exe_i),
    .exe_ready_o    (mblk_exe_ready_o),
    .addr_trans_req (mblk_addr_trans_req),
    .addr_trans_rsp (mblk_addr_trans_rsp),
    .icacop_req     (mblk_icacop_req),
    .icacop_rsp     (mblk_icacop_rsp),
    .axi4_mst       (dcache_axi4_mst),
    .wb_o           (mblk_wb_o),
    .wb_ready_i     (mblk_wb_ready_i)
  );


/*======================== Reorder Buffer(Write Back) =========================*/
  always_comb begin
    rob_flush_i = global_flush;
    rob_alloc_req = sche_rob_alloc_req;


    rob_misc_wb_req = iblk_misc_wb_o;
    rob_alu_wb_req = iblk_alu_wb_o;
    rob_mdu_wb_req = iblk_mdu_wb_o;
    rob_mem_wb_req = mblk_wb_o;

    write_back_valid[0] = iblk_misc_wb_o.base.valid & iblk_misc_wb_o.base.we & rob_misc_wb_rsp.ready;
    write_back_valid[1] = iblk_alu_wb_o[0].base.valid & iblk_alu_wb_o[0].base.we & rob_alu_wb_rsp[0].ready;
    write_back_valid[2] = iblk_alu_wb_o[1].base.valid & iblk_alu_wb_o[1].base.we & rob_alu_wb_rsp[0].ready;
    write_back_valid[3] = iblk_mdu_wb_o.base.valid & iblk_mdu_wb_o.base.we & rob_mdu_wb_rsp.ready;
    // 后端仅mem触发异常 异常不写回
    write_back_valid[4] = mblk_wb_o.base.valid & ~mblk_wb_o.base.excp.valid & mblk_wb_o.base.we & rob_mem_wb_rsp.ready;

    write_back_pdest[0] = iblk_misc_wb_o.base.pdest;
    write_back_pdest[1] = iblk_alu_wb_o[0].base.pdest;
    write_back_pdest[2] = iblk_alu_wb_o[1].base.pdest;
    write_back_pdest[3] = iblk_mdu_wb_o.base.pdest;
    write_back_pdest[4] = mblk_wb_o.base.pdest;

  end

  ReorderBuffer inst_ReorderBuffer
  (
    .clk         (clk),
    .a_rst_n     (rst_n),
    .flush_i     (rob_flush_i),
    .alloc_req   (rob_alloc_req),
    .alloc_rsp   (rob_alloc_rsp),
    // write back
    .misc_wb_req (rob_misc_wb_req),
    .alu_wb_req  (rob_alu_wb_req),
    .mdu_wb_req  (rob_mdu_wb_req),
    .mem_wb_req  (rob_mem_wb_req),
    .misc_wb_rsp (rob_misc_wb_rsp),
    .alu_wb_rsp  (rob_alu_wb_rsp),
    .mdu_wb_rsp  (rob_mdu_wb_rsp),
    .mem_wb_rsp  (rob_mem_wb_rsp),
    // commit
    .cmt_o       (rob_cmt_o)
  );


/*================================== Commit ===================================*/
  // 处理异常和分支预测失败

  // logic global_flush;
  // // commit 阶段产生
  // logic excp_flush;      // 异常
  // logic tlbrefill_flush; // TLB充填异常（此时excp_flush也会拉高，由于入口特殊故单独列出）
  // logic redirect_flush;  // 分支预测失败
  // // write back 阶段产生（但是commit阶段才真正flush）
  // logic ertn_flush;      // ERET返回（返回地址为csr_era）
  // logic refetch_flush;   // 重取指令（ibar、priv、icacop、idel）
  // logic ibar_flush;      // IBAR指令
  // logic priv_flush;      // 特权指令（csr_rd修改可撤回，不需要flush）
  // logic icacop_flush;    // ICache操作
  // logic idle_flush;      // IDLE指令
  always_comb begin
    excp_flush = rob_cmt_o.valid[0] & rob_cmt_o.rob_entry[0].excp.valid;
    tlbrefill_flush = rob_cmt_o.valid[0] & rob_cmt_o.rob_entry[0].excp.valid & rob_cmt_o.rob_entry[0].excp.ecode == `ECODE_TLBR;
    redirect_flush = rob_cmt_o.valid[0] & rob_cmt_o.rob_entry[0].br_redirect;
    
    ertn_flush = rob_cmt_o.valid[0] & rob_cmt_o.rob_entry[0].ertn_flush;
    ibar_flush = rob_cmt_o.valid[0] & rob_cmt_o.rob_entry[0].ibar_flush;
    priv_flush = rob_cmt_o.valid[0] & rob_cmt_o.rob_entry[0].priv_flush;
    icacop_flush = rob_cmt_o.valid[0] & rob_cmt_o.rob_entry[0].icacop_flush;
    idle_flush = rob_cmt_o.valid[0] & rob_cmt_o.rob_entry[0].idle_flush;

    refetch_flush = ibar_flush | priv_flush | icacop_flush | idle_flush;

    global_flush = excp_flush | redirect_flush | ertn_flush | refetch_flush;
  end

  always_comb begin
    for (int i = 0; i < `COMMIT_WIDTH; i++) begin
      // 异常要放弃对于重命名阶段fl和RAT的修改 ！！！ TODO 这个逻辑似乎有优化空间
      free_valid[i] = rob_cmt_o.valid[i] & rob_cmt_o.rob_entry[i].old_phy_reg_valid & ~rob_cmt_o.rob_entry[i].excp.valid;
      free_preg[i] = rob_cmt_o.rob_entry[i].old_phy_reg;

      arch_rat_dest_valid_i[i] = rob_cmt_o.valid[i] & ~rob_cmt_o.rob_entry[i].excp.valid & rob_cmt_o.rob_entry[i].arch_reg != 0;
      arch_rat_dest_i[i] = rob_cmt_o.rob_entry[i].arch_reg;
      arch_rat_preg_i[i] = rob_cmt_o.rob_entry[i].phy_reg;

      arch_fl_alloc_valid_i[i] = rob_cmt_o.valid[i] & ~rob_cmt_o.rob_entry[i].excp.valid & rob_cmt_o.rob_entry[i].arch_reg != 0;
      arch_fl_free_valid_i[i] = free_valid[i];
      arch_fl_free_preg_i[i] = free_preg[i];
    end
  end

  ArchRegisterAliasTable #(
    .PHY_REG_NUM(`PHY_REG_NUM)
  ) U_ArchRegisterAliasTable (
    .clk          (clk),
    .rst_n        (rst_n),
    .dest_valid_i (arch_rat_dest_valid_i),
    .dest_i       (arch_rat_dest_i),
    .preg_i       (arch_rat_preg_i),
    .ppdst_valid_i(free_valid),
    .ppdst_i      (free_preg),
    .arch_valid_o (arch_rat_valid_o)
  );

  ArchFreeList #(
    .PHY_REG_NUM(`PHY_REG_NUM)
  ) U_ArchFreeList (
    .clk           (clk),
    .rst_n         (rst_n),
    .flush_i       ('0),
    .arch_head_o   (arch_fl_head_o),
    .arch_tail_o   (arch_fl_tail_o),
    .arch_cnt_o    (arch_fl_cnt_o),
    .alloc_valid_i (arch_fl_alloc_valid_i),
    .free_valid_i  (arch_fl_free_valid_i),
    .free_preg_i   (arch_fl_free_preg_i)
  );



`ifdef DEBUG
  RobCmtSt rob_cmt_buffer;

  always_ff @(posedge clk or negedge rst_n) begin : proc_rob_cmt_buffer
    if(~rst_n) begin
      rob_cmt_buffer <= 0;
    end else begin
      rob_cmt_buffer <= rob_cmt_o;
    end
  end


  logic [31:0][31:0] arch_regfile_q, arch_regfile_n;

  always_comb begin
    arch_regfile_n = arch_regfile_q;
    for (int i = 0; i < `COMMIT_WIDTH; i++) begin
      if (rob_cmt_o.valid[i] && 
          rob_cmt_o.rob_entry[i].rf_wen &&
          !rob_cmt_o.rob_entry[i].excp.valid) begin
        arch_regfile_n[rob_cmt_o.rob_entry[i].arch_reg] = rob_cmt_o.rob_entry[i].rf_wdata;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      arch_regfile_q <= '0;
    end else begin
      arch_regfile_q <= arch_regfile_n;
    end
  end
`endif

/*========================== Memory Management Unit ===========================*/

  always_comb begin
    // mmu 需要的csr信息
    mmu_csr_asid_i = csr_asid_out;
    mmu_csr_dmw0_i = csr_dmw0_out;
    mmu_csr_dmw1_i = csr_dmw1_out;
    mmu_csr_datf_i = csr_datf_out;
    mmu_csr_datm_i = csr_datm_out;
    mmu_csr_plv_i  = csr_plv_out;
    mmu_csr_da_i = csr_da_out;
    mmu_csr_pg_i = csr_pg_out;

    // mmu地址翻译请求
    mmu_addr_trans_req[0] = icache_addr_trans_req;
    mmu_addr_trans_req[1] = mblk_addr_trans_req;

    // mmu tlb search
    mmu_tlbsrch_en_i = iblk_tlbsrch_valid_o;

    // mmu tlb fill and write
    mmu_tlbfill_en_i = iblk_misc_wb_o.base.valid &
                       iblk_misc_wb_ready_i &
                       iblk_misc_wb_o.tlbfill_en;
    mmu_tlbwr_en_i = iblk_misc_wb_o.base.valid &
                     iblk_misc_wb_ready_i &
                     iblk_misc_wb_o.tlbwr_en;
    mmu_rand_index_i = iblk_misc_wb_o.tlbfill_idx;
    mmu_tlbehi_i = csr_tlbehi_out;
    mmu_tlbelo0_i = csr_tlbelo0_out;
    mmu_tlbelo1_i = csr_tlbelo1_out;
    mmu_tlbidx_i = csr_tlbidx_out;
    mmu_ecode_i = csr_ecode_out;

    // mmu tlb read
    mmu_tlbrd_en_i = iblk_tlbrd_valid_o;

    // mmu invtlb
    mmu_invtlb_en_i = iblk_misc_wb_o.base.valid &
                      iblk_misc_wb_ready_i &
                      iblk_misc_wb_o.invtlb_en;
    mmu_invtlb_asid_i = iblk_misc_wb_o.invtlb_asid;
    mmu_invtlb_vpn_i = iblk_misc_wb_o.vaddr[`PROC_VALEN - 1:13];
    mmu_invtlb_op_i = iblk_misc_wb_o.invtlb_op;
  end

  MemoryManagementUnit inst_MemoryManagementUnit
  (
    .clk            (clk),
    .a_rst_n        (rst_n),
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
    .tlbrd_en_i     (mmu_tlbrd_en_i),
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
    // csr读写
    // csr_rd_addr = sche_misc_issue_o.base_info.src[23:10]; 在read rf处
    csr_wr_en = iblk_misc_wb_o.base.valid &
                iblk_misc_wb_ready_i&
                iblk_misc_wb_o.csr_we;
    csr_wr_addr = iblk_misc_wb_o.csr_waddr;
    csr_wr_data = iblk_misc_wb_o.csr_wdata;

    csr_interrupt = interrupt;

    // 异常处理
    csr_excp_flush = excp_flush;
    csr_ertn_flush = ertn_flush;
    csr_era_in   = rob_cmt_o.rob_entry[0].pc;
    csr_ecode_in = rob_cmt_o.rob_entry[0].excp.ecode;
    csr_esubcode_in = rob_cmt_o.rob_entry[0].excp.sub_ecode;
    csr_va_error_in = rob_cmt_o.valid[0] & 
                      rob_cmt_o.rob_entry[0].excp.valid &
                      rob_cmt_o.rob_entry[0].excp.ecode inside 
                      {`ECODE_ADE, `ECODE_TLBR, `ECODE_PIF, `ECODE_PPI,
                       `ECODE_ALE, `ECODE_PME,  `ECODE_PIS, `ECODE_PIL};
    csr_bad_va_in = rob_cmt_o.rob_entry[0].error_vaddr;

    csr_excp_tlbrefill = tlbrefill_flush;
    csr_excp_tlb = rob_cmt_o.valid[0] & 
                   rob_cmt_o.rob_entry[0].excp.valid &
                   rob_cmt_o.rob_entry[0].excp.ecode inside
                   {`ECODE_TLBR, `ECODE_PIF, `ECODE_PPI,
                    `ECODE_PME,  `ECODE_PIS, `ECODE_PIL};
    csr_excp_tlb_vppn = rob_cmt_o.rob_entry[0].error_vaddr[31:13];

    // 填写tlbsrch结果
    csr_tlbsrch_en = iblk_misc_wb_o.base.valid &
                     iblk_misc_wb_o.tlbsrch_en &
                     rob_misc_wb_rsp.ready;
    csr_tlbsrch_found = iblk_misc_wb_o.tlbsrch_found;
    csr_tlbsrch_index = iblk_misc_wb_o.tlbsrch_idx;

    // 填写原子指令标记
    csr_llbit_in = mblk_wb_o.mem_op == `MEM_LOAD ? '1 : '0;
    csr_llbit_set_in = mblk_wb_o.base.valid & 
                       mblk_wb_o.micro &
                       (mblk_wb_o.mem_op == `MEM_LOAD |
                       (mblk_wb_o.mem_op == `MEM_STORE & mblk_wb_o.llbit)) &
                       rob_mem_wb_rsp.ready;

    // 填写tlbrd结果
    csr_tlbrd_en = iblk_misc_wb_o.base.valid &
                   iblk_misc_wb_o.tlbrd_en &
                   rob_misc_wb_rsp.ready;
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
    .csr_ecfg_diff      (csr_ecfg_diff),
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

`ifdef DEBUG
  // 如果超过1000个周期没有指令提交则退出
  logic [31:0] commit_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      commit_cnt <= 0;
    end else begin
      if (rob_cmt_o.valid) begin
        commit_cnt <= 0;
      end else begin
        commit_cnt <= commit_cnt + 1;
      end
    end
  end

  always_comb begin
    if (commit_cnt >= 1000) begin
      $display("Pipeline stuck! over 1000 clk cycles without commit!");
      $finish;
    end
  end

`endif
  

endmodule : Pipeline



