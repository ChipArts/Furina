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
  input rst_n,  // Asynchronous reset active low
  input logic [7:0] interrupt,
  AXI4.Master icache_axi4_mst,
  AXI4.Master dcache_axi4_mst
);

/*=============================== Signal Define ===============================*/
  /*
   *  我们约定：
   *  在这个地方仅定义所有模块的输出信号
   *  模块的输入信号可以不定义，直接传入其他模块的输入信号
   *  如果输入信号比较复杂，模块输入信号在模块实例化位置就近定义
   */

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
  BpuRspSt bpu_rsp;

  /* ICache */
  ICacheRspSt icache_rsp;
  MmuAddrTransReqSt icache_addr_trans_req;
  IcacopRspSt icacop_rsp;

  /* Pre Decoder */
  PreOptionCodeSt [`FETCH_WIDTH - 1:0] pre_option_code_o;

  logic pre_check_redirect_o;
  logic [31:0] pre_check_pc_o;
  logic [31:0] pre_check_target_o;
  logic [$clog2(`RAS_STACK_DEPTH) - 1:0] pre_check_ras_ptr_o;
  logic [1:0]  pre_check_valid_o;
  

  /* Instruction Buffer */
  logic ibuf_write_ready_o;
  logic [`DECODE_WIDTH - 1:0] ibuf_read_valid_o;
  IbufDataSt [`DECODE_WIDTH - 1:0] ibuf_read_data_o;

  /* Decoder */
  OptionCodeSt [`DECODE_WIDTH - 1:0] decoder_option_code_o;
  OptionCodeSt [`DECODE_WIDTH - 1:0] option_code;  // 处理特殊的解码
  logic [`DECODE_WIDTH - 1:0][4:0] decoder_src0;
  logic [`DECODE_WIDTH - 1:0][4:0] decoder_src1;
  logic [`DECODE_WIDTH - 1:0][4:0] decoder_dest;

  /* Scheduler */
  ScheduleRspSt sche_rsp;
  RobAllocReqSt sche_rob_alloc_req;

  MiscIssueSt sche_misc_issue_o;
  AluIssueSt [1:0] sche_alu_issue_o;
  MduIssueSt sche_mdu_issue_o;
  MemIssueSt sche_mem_issue_o;

  /* RegFile */
  // 每周期最多发射misc*1、alu*2、mdu*1、mem*1
  logic [9:0][31:0] rf_rdata_o;

  /* Integer Block */
  // IntegerBlock --> iblk
  logic iblk_misc_ready_o;
  logic [1:0] iblk_alu_ready_o;
  logic iblk_mdu_ready_o;
  // tlb srch
  logic iblk_tlbsrch_valid_o;
  // tlb read
  logic iblk_tlbrd_valid_o;
  // tlb inv
  // csr read
  // write back
  MiscWbSt iblk_misc_wb_o;
  AluWbSt [1:0] iblk_alu_wb_o;
  MduWbSt iblk_mdu_wb_o;

  /* Memory Block */
  // MemoryBlock --> mblk
  logic mblk_exe_ready_o;
  MmuAddrTransReqSt mblk_addr_trans_req;
  IcacopReqSt mblk_icacop_req;
  MemWbSt mblk_wb_o;

  /* Reorder Buffer (Write Back) */
  RobAllocRspSt rob_alloc_rsp;
  RobWbRspSt rob_misc_wb_rsp;
  RobWbRspSt [1:0] rob_alu_wb_rsp;
  RobWbRspSt rob_mdu_wb_rsp;
  RobWbRspSt rob_mem_wb_rsp;
  RobCmtSt rob_cmt_o;

  // 写回信号(global)
  logic [`WB_WIDTH - 1:0] write_back_valid;
  logic [`WB_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] write_back_pdest;

  /* commit */
  logic [`COMMIT_WIDTH - 1:0] free_valid;
  logic [`COMMIT_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] free_preg;

  logic [`PHY_REG_NUM - 1:0] arch_rat_valid_o;

  logic [$clog2(`PHY_REG_NUM) - 1:0] arch_fl_head_o;
  logic [$clog2(`PHY_REG_NUM) - 1:0] arch_fl_tail_o;
  logic [$clog2(`PHY_REG_NUM + 1) - 1:0] arch_fl_cnt_o;

  /* Memory Management Unit */
  MmuAddrTransRspSt [1:0] mmu_addr_trans_rsp;
  logic                                mmu_tlbsrch_found_o;
  logic [$clog2(`TLB_ENTRY_NUM) - 1:0] mmu_tlbsrch_idx_o;

  // tlbrd
  logic [31:0] mmu_tlbehi_o;
  logic [31:0] mmu_tlbelo0_o;
  logic [31:0] mmu_tlbelo1_o;
  logic [31:0] mmu_tlbidx_o;
  logic [ 9:0] mmu_tlbasid_o;


  /* Control Status Register */
  logic [31:0]  csr_rd_data      ;
  // timer 64
  logic [63:0]  csr_timer_64_out ;
  logic [31:0]  csr_tid_out      ;
  // interrupt
  logic         csr_has_int      ;
  // to atomic
  logic         csr_llbit_out    ;
  logic [18:0]  csr_vppn_out     ;  // TODO: 仿佛无用
  // to bpu/fetch
  logic [31:0]  csr_eentry_out   ;
  logic [31:0]  csr_era_out      ;
  logic [31:0]  csr_tlbrentry_out;
  // to mmu
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
  //general use
  logic [ 1:0]  csr_plv_out      ;
  // csr regs for diff
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
    if(!rst_n) begin
      idle_lock <= 0;
    end else begin
      if (idle_flush && !csr_has_int) begin
        idle_lock <= '1;
      end else if (csr_has_int) begin
        idle_lock <= '0;
      end
    end
  end

  BpuReqSt bpu_req;
  logic br_select;

  always_comb begin : proc_gen_br_select
    // 选择出提交信息中的分支指令
    br_select = '0;
    for (int i = 1; i < `COMMIT_WIDTH; i++) begin
      if (rob_cmt_o.valid[i] && rob_cmt_o.rob_entry[i].instr_type == `BR_INSTR) begin
        br_select = i;
        break;
      end
    end
  end
  
  always_comb begin : gen_bpu_req
    bpu_req.next     = icache_rsp.ready & ~idle_lock;
    bpu_req.redirect = global_flush | pre_check_redirect_o;
    bpu_req.target   = tlbrefill_flush      ? csr_tlbrentry_out :
                       excp_flush           ? csr_eentry_out :
                       ertn_flush           ? csr_era_out :  // sys 和 brk恢复时应该跳到era+4（软件控制）
                       refetch_flush        ? rob_cmt_o.rob_entry[0].pc + 4    :
                       redirect_flush       ? rob_cmt_o.rob_entry[0].br_target :
                       pre_check_redirect_o ? pre_check_target_o :
                                              32'h1c00_0000;
    // for bpu updata
    bpu_req.pc = global_flush         ? rob_cmt_o.rob_entry[0].pc : 
                 pre_check_redirect_o ? pre_check_pc_o :
                                        rob_cmt_o.rob_entry[br_select].pc;

    bpu_req.taken = global_flush         ? rob_cmt_o.rob_entry[0].br_taken :
                    pre_check_redirect_o ? 1'b0 :
                                           rob_cmt_o.rob_entry[br_select].br_taken;
    // btb 更新
    bpu_req.btb_update = global_flush | pre_check_redirect_o | (|rob_cmt_o.valid);
    bpu_req.br_type    = global_flush         ? rob_cmt_o.rob_entry[0].br_type :
                         pre_check_redirect_o ? 2'b00 :
                                                rob_cmt_o.rob_entry[br_select].br_type;
    // lpht 更新
    bpu_req.lpht_update = global_flush | pre_check_redirect_o | |rob_cmt_o.valid;
    bpu_req.lphr   = global_flush         ? rob_cmt_o.rob_entry[0].br_info.lphr :
                     pre_check_redirect_o ? 2'b00 :
                                            rob_cmt_o.rob_entry[br_select].br_info.lphr;
    // ras 更新
    // TODO: ras_redirect 参数宏定义
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

/*========================== Instruction Fetch Unit ===========================*/
  ICacheReqSt icache_req;
  IcacopReqSt icacop_req;
  MmuAddrTransRspSt icache_addr_trans_rsp;

  always_comb begin : gen_icache_req
    icache_req.valid   = bpu_rsp.valid;
    icache_req.vaddr   = bpu_rsp.pc;
    icache_req.npc     = bpu_rsp.npc;
    icache_req.br_info = bpu_rsp.br_info;
    icache_req.ready   = ibuf_write_ready_o;
    icache_req.has_int = csr_has_int;
  end

  assign icacop_req = mblk_icacop_req;
  assign icache_addr_trans_rsp = mmu_addr_trans_rsp[0];
  

  ICache U_ICache
  (
    .clk            (clk),
    .rst_n          (rst_n),
    .flush_i        (global_flush),
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
  ICacheRspSt icache_rsp_buf;
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n || global_flush) begin
      icache_rsp_buf <= 0;
    end else begin
      if (ibuf_write_ready_o) begin
        if (pre_check_redirect_o) begin
          icache_rsp_buf.valid <= '0;
        end else begin
          icache_rsp_buf <= icache_rsp;
        end
      end
    end
  end

  for (genvar i = 0; i < `FETCH_WIDTH; i++) begin : gen_pre_decoder
    PreDecoder U_PreDecoder (.instr_i(icache_rsp_buf.instr[i]), .pre_option_code_o(pre_option_code_o[i]));
  end

  logic [`FETCH_WIDTH - 1:0] pre_check_is_branch_i;
  for (genvar i = 0; i < `FETCH_WIDTH; i++) begin : gen_is_branch
    assign pre_check_is_branch_i[i] = pre_option_code_o[i].is_branch;
  end

  // 检查分支预测是否预测非分支指令跳转
  PreChecker U_PreChecker
  (
    .clk          (clk),
    .rst_n        (rst_n),
    .valid_i      (icache_rsp_buf.valid),
    .pc_i         (icache_rsp_buf.vaddr),
    .br_info_i    (icache_rsp_buf.br_info),
    .is_branch_i  (pre_check_is_branch_i),
    // output
    .redirect_o   (pre_check_redirect_o),
    .pc_o         (pre_check_pc_o),
    .target_o     (pre_check_target_o),
    .ras_ptr_o    (pre_check_ras_ptr_o),
    .valid_o      (pre_check_valid_o)
  );



/*============================ Instruction Buffer =============================*/
  logic [`FETCH_WIDTH - 1:0] ibuf_write_valid_i;
  IbufDataSt [`FETCH_WIDTH - 1:0] ibuf_write_data_i;
  // 在此处进行队列压缩，剔除无效的指令，第[i]个write_data应该写入第ibuf_idx[i]个icache的数据
  logic [`FETCH_WIDTH - 1:0][$clog2(`FETCH_WIDTH) - 1:0] ibuf_idx;
  always_comb begin : proc_ibuf_idx
    ibuf_idx[0] = '0;
    for (int i = 1; i < `FETCH_WIDTH; i++) begin
      ibuf_idx[i] = ibuf_idx[i - 1] + icache_rsp_buf.valid[i - 1];
    end
  end

  always_comb begin : proc_ibuf_write
    ibuf_write_valid_i = '0;
    ibuf_write_data_i = '0;
    for (int i = 0; i < `FETCH_WIDTH; i++) begin
      // 指令有效时才写入 屏蔽掉分支预测有误的指令
      if (pre_check_valid_o[i]) begin
        ibuf_write_valid_i[ibuf_idx[i]] = 1'b1;
      end
      // 数据准备不需要判断有效性
      ibuf_write_data_i[ibuf_idx[i]].pc = icache_rsp_buf.vaddr[i];
      ibuf_write_data_i[ibuf_idx[i]].npc = icache_rsp_buf.npc[i];
      ibuf_write_data_i[ibuf_idx[i]].br_info = icache_rsp_buf.br_info;
      ibuf_write_data_i[ibuf_idx[i]].instr = icache_rsp_buf.instr[i];
      ibuf_write_data_i[ibuf_idx[i]].excp = icache_rsp_buf.excp;
      ibuf_write_data_i[ibuf_idx[i]].pre_oc = pre_option_code_o[i];
    end
  end

  SyncMultiChannelFIFO #(
    .FIFO_DEPTH(`IBUF_DEPTH),
    .DATA_WIDTH($bits(IbufDataSt)),
    .RPORTS_NUM(`DECODE_WIDTH),
    .WPORTS_NUM(`FETCH_WIDTH),
    .FIFO_MEMORY_TYPE("auto")
  ) U_InstructionBuffer (
    .clk           (clk),
    .rst_n         (rst_n),
    .flush_i       (global_flush),
    .write_valid_i (ibuf_write_valid_i),
    .write_ready_o (ibuf_write_ready_o),
    .write_data_i  (ibuf_write_data_i),
    .read_valid_o  (ibuf_read_valid_o),
    .read_ready_i  ({`DECODE_WIDTH{sche_rsp.ready}}),
    .read_data_o   (ibuf_read_data_o)
  );

/*================================== Decoder ==================================*/
  // 对控制相关信息解码
  for (genvar i = 0; i < `DECODE_WIDTH; i++) begin : gen_decoder
    Decoder inst_Decoder (.instr_i(ibuf_read_data_o[i].instr), .option_code_o(decoder_option_code_o[i]));
  end

  // 处理特殊的解码
  // TODO: 优化这个处理
  always_comb begin : proc_decoder_special
    // default assign
    option_code = decoder_option_code_o;
    // 三个CSR特权指令
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      if (option_code[i].priv_op == `PRIV_CSR_XCHG) begin
        case (ibuf_read_data_o[i].instr[9:5])
          5'b0 : option_code[i].priv_op = `PRIV_CSR_READ;
          5'b1 : option_code[i].priv_op = `PRIV_CSR_WRITE;
          default : option_code[i].priv_op = `PRIV_CSR_XCHG;
        endcase
      end
    end
    // 两个rdtimel指令
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      if (option_code[i].misc_op == `MISC_RDCNTVL) begin
        if (ibuf_read_data_o[i].instr[9:5] != 0) begin
          option_code[i].misc_op = `MISC_RDCNTID;
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
  ScheduleReqSt sche_req;
  RobAllocRspSt sche_rob_alloc_rsp;

  logic       sche_misc_ready_i;
  logic [1:0] sche_alu_ready_i;
  logic       sche_mdu_ready_i;
  logic       sche_mem_ready_i;

  /* Dispatch/Wake up/Select */
  always_comb begin : proc_sche_req
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      sche_req.valid[i]       = ibuf_read_valid_o[i];

      sche_req.pc[i]          = ibuf_read_data_o[i].pc;
      sche_req.npc[i]         = ibuf_read_data_o[i].npc;
      sche_req.br_info[i]     = ibuf_read_data_o[i].br_info;
      sche_req.src[i]         = ibuf_read_data_o[i].instr[25:0];
      sche_req.arch_src0[i]   = decoder_src0[i];
      sche_req.arch_src1[i]   = decoder_src1[i];
      sche_req.arch_dest[i]   = decoder_dest[i];
      sche_req.option_code[i] = option_code[i];
      sche_req.excp[i]        = ibuf_read_data_o[i].excp;
    end
  end

  assign sche_rob_alloc_rsp = rob_alloc_rsp;

  assign sche_misc_ready_i = iblk_misc_ready_o;
  assign sche_alu_ready_i = iblk_alu_ready_o;
  assign sche_mdu_ready_i = iblk_mdu_ready_o;
  assign sche_mem_ready_i = mblk_exe_ready_o;

  Scheduler U_Scheduler
  (
    .clk              (clk),
    .a_rst_n          (rst_n),
    .flush_i          (global_flush),
    .schedule_req     (sche_req),
    .schedule_rsp     (sche_rsp),
    .rob_alloc_req    (sche_rob_alloc_req),
    .rob_alloc_rsp    (sche_rob_alloc_rsp),
    // for excp
    .csr_plv_i        (csr_plv_out),
    // flush restore
    .fl_arch_heah     (arch_fl_head_o),
    .fl_arch_tail     (arch_fl_tail_o),
    .fl_arch_cnt      (arch_fl_cnt_o),
    .rat_arch_valid_i (arch_rat_valid_o),
    // free phy reg
    .free_valid_i     (free_valid),
    .free_preg_i      (free_preg),
    // wake up
    .wb_i             (write_back_valid),
    .wb_pdest_i       (write_back_pdest),
    // issue
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
  logic [9:0] rf_re_i;
  logic [4:0] rf_we_i;
  logic [4:0][$clog2(`PHY_REG_NUM) - 1:0] rf_waddr_i;
  logic [9:0][$clog2(`PHY_REG_NUM) - 1:0] rf_raddr_i;
  logic [4:0][31:0]                       rf_wdata_i;
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

    rf_we_i    = write_back_valid;
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
    .rst_n   (rst_n),
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
    .rst_n   (rst_n),
    .re_i    (rf_re_i[9:5]),
    .we_i    (rf_we_i),
    .raddr_i (rf_raddr_i[9:5]),
    .waddr_i (rf_waddr_i),
    .data_i  (rf_wdata_i),
    .data_o  (rf_rdata_o[9:5])
  );

  // 读取CSR寄存器
  // 见csr模块输入

  // imm ext
  // 读mmu信息

/*=============================== Integer Block ===============================*/
  MiscExeSt iblk_misc_exe_i;
  AluExeSt [1:0] iblk_alu_exe_i;
  MduExeSt iblk_mdu_exe_i;

  logic iblk_tlbsrch_found_i;
  logic [$clog2(`TLB_ENTRY_NUM) - 1:0] iblk_tlbsrch_idx_i;
  logic [31:0] iblk_tlbehi_i;
  logic [31:0] iblk_tlbelo0_i;
  logic [31:0] iblk_tlbelo1_i;
  logic [31:0] iblk_tlbidx_i;
  logic [ 9:0] iblk_tlbasid_i;

  logic [ 5:0] iblk_invtlb_op_i;
  logic [63:0] iblk_timer_64_i;
  logic [31:0] iblk_timer_id_i;
  logic        iblk_csr_rstat_i;
  logic [31:0] iblk_csr_rdata_i;

  logic       iblk_misc_wb_ready_i;
  logic [1:0] iblk_alu_wb_ready_i;
  logic       iblk_mdu_wb_ready_i;



  always_comb begin
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
    .flush_i         (global_flush),
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
  logic mblk_flush_i;
  MemExeSt mblk_exe_i;
  MmuAddrTransRspSt mblk_addr_trans_rsp;
  IcacopRspSt mblk_icacop_rsp;
  logic mblk_wb_ready_i;

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

  logic rob_flush_i;
  RobAllocReqSt rob_alloc_req;
  MiscWbSt rob_misc_wb_req;
  AluWbSt [1:0] rob_alu_wb_req;
  MduWbSt rob_mdu_wb_req;
  MemWbSt rob_mem_wb_req;

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
    .rst_n       (rst_n),
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

  logic [`COMMIT_WIDTH - 1:0] arch_rat_dest_valid_i;
  logic [`COMMIT_WIDTH - 1:0][4:0] arch_rat_dest_i;
  logic [`COMMIT_WIDTH - 1:0][$clog2(`PHY_REG_NUM) - 1:0] arch_rat_preg_i;

  logic [`COMMIT_WIDTH - 1:0] arch_fl_alloc_valid_i;



  always_comb begin
    for (int i = 0; i < `COMMIT_WIDTH; i++) begin
      // 异常要放弃对于重命名阶段fl和RAT的修改 ！！！ TODO 这个逻辑似乎有优化空间
      free_valid[i] = rob_cmt_o.valid[i] & rob_cmt_o.rob_entry[i].old_phy_reg_valid & ~rob_cmt_o.rob_entry[i].excp.valid;
      free_preg[i] = rob_cmt_o.rob_entry[i].old_phy_reg;

      arch_rat_dest_valid_i[i] = rob_cmt_o.valid[i] & ~rob_cmt_o.rob_entry[i].excp.valid & rob_cmt_o.rob_entry[i].arch_reg != 0;
      arch_rat_dest_i[i] = rob_cmt_o.rob_entry[i].arch_reg;
      arch_rat_preg_i[i] = rob_cmt_o.rob_entry[i].phy_reg;

      arch_fl_alloc_valid_i[i] = rob_cmt_o.valid[i] & ~rob_cmt_o.rob_entry[i].excp.valid & rob_cmt_o.rob_entry[i].arch_reg != 0;
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
    .free_valid_i  (free_valid),
    .free_preg_i   (free_preg)
  );



`ifdef CHIPLAB_SIM
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
  logic        mmu_tlbsrch_en_i;
  logic        mmu_tlbfill_en_i;
  logic        mmu_tlbwr_en_i;
  logic [ 4:0] mmu_rand_index_i;
  logic [31:0] mmu_tlbehi_i;
  logic [31:0] mmu_tlbelo0_i;
  logic [31:0] mmu_tlbelo1_i;
  logic [31:0] mmu_tlbidx_i;
  logic [ 5:0] mmu_ecode_i;

  logic        mmu_tlbrd_en_i;
  logic        mmu_invtlb_en_i;
  logic [ 9:0] mmu_invtlb_asid_i;
  logic [18:0] mmu_invtlb_vpn_i;
  logic [ 4:0] mmu_invtlb_op_i;

  MmuAddrTransReqSt [1:0] mmu_addr_trans_req;

  // mmu地址翻译请求
  assign mmu_addr_trans_req[0] = icache_addr_trans_req;
  assign mmu_addr_trans_req[1] = mblk_addr_trans_req;

  // mmu tlb search
  assign mmu_tlbsrch_en_i = iblk_tlbsrch_valid_o;
  // mmu tlb fill and write
  assign mmu_tlbfill_en_i = iblk_misc_wb_o.base.valid &
                            iblk_misc_wb_o.tlbfill_en &
                            rob_misc_wb_rsp.ready;
  assign mmu_tlbwr_en_i   = iblk_misc_wb_o.base.valid &
                            iblk_misc_wb_o.tlbwr_en &
                            rob_misc_wb_rsp.ready;
  assign mmu_rand_index_i = iblk_misc_wb_o.tlbfill_idx;
  assign mmu_tlbehi_i     = csr_tlbehi_out;
  assign mmu_tlbelo0_i    = csr_tlbelo0_out;
  assign mmu_tlbelo1_i    = csr_tlbelo1_out;
  assign mmu_tlbidx_i     = csr_tlbidx_out;
  assign mmu_ecode_i      = csr_ecode_out;

  // mmu tlb read
  assign mmu_tlbrd_en_i = iblk_tlbrd_valid_o;
  // mmu invtlb
  assign mmu_invtlb_en_i   = iblk_misc_wb_o.base.valid &
                             iblk_misc_wb_o.invtlb_en  &
                             rob_misc_wb_rsp.ready;
  assign mmu_invtlb_asid_i = iblk_misc_wb_o.invtlb_asid;
  assign mmu_invtlb_vpn_i  = iblk_misc_wb_o.vaddr[`PROC_VALEN - 1:13];
  assign mmu_invtlb_op_i   = iblk_misc_wb_o.invtlb_op;

  MemoryManagementUnit inst_MemoryManagementUnit
  (
    .clk            (clk),
    .a_rst_n        (rst_n),
    // from csr
    .csr_asid_i     (csr_asid_out),
    .csr_dmw0_i     (csr_dmw0_out),
    .csr_dmw1_i     (csr_dmw1_out),
    .csr_datf_i     (csr_datf_out),
    .csr_datm_i     (csr_datm_out),
    .csr_da_i       (csr_da_out),
    .csr_pg_i       (csr_pg_out),
    .csr_plv_i      (csr_plv_out),
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
    //csr rd
    logic  [13:0]                   csr_rd_addr      ;
    //csr wr
    logic                           csr_wr_en        ;
    logic  [13:0]                   csr_wr_addr      ;
    logic  [31:0]                   csr_wr_data      ;
    //interrupt
    logic  [ 7:0]                   csr_interrupt    ;
    //excp
    logic                           csr_excp_flush   ;
    logic                           csr_ertn_flush   ;
    logic  [31:0]                   csr_era_in       ;
    logic  [ 8:0]                   csr_esubcode_in  ;
    logic  [ 5:0]                   csr_ecode_in     ;
    logic                           csr_va_error_in  ;
    logic  [31:0]                   csr_bad_va_in    ;
    logic                           csr_tlbsrch_en    ;
    logic                           csr_tlbsrch_found ;
    logic  [ 4:0]                   csr_tlbsrch_index ;
    logic                           csr_excp_tlbrefill;
    logic                           csr_excp_tlb     ;
    logic  [18:0]                   csr_excp_tlb_vppn;
    //llbit
    logic                           csr_llbit_in     ;
    logic                           csr_llbit_set_in ;
    //from addr trans 
    logic                           csr_tlbrd_en     ;
    logic  [31:0]                   csr_tlbehi_in    ;
    logic  [31:0]                   csr_tlbelo0_in   ;
    logic  [31:0]                   csr_tlbelo1_in   ;
    logic  [31:0]                   csr_tlbidx_in    ;
    logic  [ 9:0]                   csr_asid_in      ;

    // csr读写
    assign csr_rd_addr = sche_misc_issue_o.base_info.src[23:10]; // 读取CSR指令的csr地址
    assign csr_wr_en   = iblk_misc_wb_o.base.valid &
                         iblk_misc_wb_o.csr_we     &
                         rob_misc_wb_rsp.ready;
    assign csr_wr_addr = iblk_misc_wb_o.csr_waddr;
    assign csr_wr_data = iblk_misc_wb_o.csr_wdata;

    assign csr_interrupt = interrupt;

    // 异常处理
    assign csr_excp_flush  = excp_flush;
    assign csr_ertn_flush  = ertn_flush;
    assign csr_era_in      = rob_cmt_o.rob_entry[0].pc;
    assign csr_ecode_in    = rob_cmt_o.rob_entry[0].excp.ecode;
    assign csr_esubcode_in = rob_cmt_o.rob_entry[0].excp.sub_ecode;
    assign csr_va_error_in = rob_cmt_o.valid[0]                & 
                             rob_cmt_o.rob_entry[0].excp.valid &
                             rob_cmt_o.rob_entry[0].excp.ecode inside {
                               `ECODE_ADE, `ECODE_TLBR, `ECODE_PIF, `ECODE_PPI,
                               `ECODE_ALE, `ECODE_PME,  `ECODE_PIS, `ECODE_PIL
                             };
    assign csr_bad_va_in = rob_cmt_o.rob_entry[0].error_vaddr;
    // tlb 异常
    assign csr_excp_tlbrefill = tlbrefill_flush;
    assign csr_excp_tlb = rob_cmt_o.valid[0]                &
                          rob_cmt_o.rob_entry[0].excp.valid &
                          rob_cmt_o.rob_entry[0].excp.ecode inside {
                            `ECODE_TLBR, `ECODE_PIF, `ECODE_PPI,
                            `ECODE_PME,  `ECODE_PIS, `ECODE_PIL
                          };
    assign csr_excp_tlb_vppn = rob_cmt_o.rob_entry[0].error_vaddr[31:13];

    // 填写tlbsrch结果
    assign csr_tlbsrch_en = iblk_misc_wb_o.base.valid &
                            iblk_misc_wb_o.tlbsrch_en &
                            rob_misc_wb_rsp.ready;
    assign csr_tlbsrch_found = iblk_misc_wb_o.tlbsrch_found;
    assign csr_tlbsrch_index = iblk_misc_wb_o.tlbsrch_idx;

    // 填写原子指令标记
    assign csr_llbit_in     = mblk_wb_o.mem_op == `MEM_LOAD ? '1 : '0;
    assign csr_llbit_set_in = mblk_wb_o.base.valid &
                              ~mblk_wb_o.base.excp.valid &  // 异常时不写入 ！！！
                              mblk_wb_o.atomic &            // 是原子指令
                              (
                                (mblk_wb_o.mem_op == `MEM_LOAD) |
                                (mblk_wb_o.mem_op == `MEM_STORE & mblk_wb_o.llbit)
                              ) &
                              rob_mem_wb_rsp.ready;

    // 填写tlbrd结果
    assign csr_tlbrd_en = iblk_misc_wb_o.base.valid &
                          iblk_misc_wb_o.tlbrd_en   &
                          rob_misc_wb_rsp.ready;
    assign csr_tlbehi_in  = iblk_misc_wb_o.tlbrd_ehi;
    assign csr_tlbelo0_in = iblk_misc_wb_o.tlbrd_elo0;
    assign csr_tlbelo1_in = iblk_misc_wb_o.tlbrd_elo1;
    assign csr_tlbidx_in  = iblk_misc_wb_o.tlbrd_idx;
    assign csr_asid_in    = iblk_misc_wb_o.tlbrd_asid;

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
  

endmodule : Pipeline



