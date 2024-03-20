// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Pipeline.sv
// Create  : 2024-03-11 14:53:30
// Revise  : 2024-03-19 17:10:20
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
`include "BranchPredictionUnit.svh"


module Pipeline (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  AXI4.Master icache_axi4_mst,
  AXI4.Master dcache_axi4_mst
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);
  /* Signal Define */
  logic flush;  // 由退休的异常指令产生
  // Branch Prediction Unit
  BPU_ReqSt bpu_req_st;
  BPU_RspSt bpu_rsp_st;

  // Fetch Address Queue
  FAQ_PushReqSt faq_push_req_st;
  FAQ_PopReqSt faq_pop_req_st;
  FAQ_PushRspSt faq_push_rsp_st;
  FAQ_PopRspSt faq_pop_rsp_st;
  logic faq_flush;

  // ICache
  ICacheFetchReqSt icache_fetch_req_st;
  ICacheFetchRspSt icache_fetch_rsp_st;
  MMU_SearchReqSt icahe_mmu_search_req_st;
  MMU_SearchRspSt icache_mmu_search_rsp_st;
  AXI4 #(
    .AXI_ADDR_WIDTH(`PROC_PALEN),
    .AXI_DATA_WIDTH(32),
  ) icache_axi4_intf;

  // Instruction Buffer
  typedef struct packed {
    logic valid;
    logic [31:0] instruction;
    logic [`PROC_VALEN - 1:0] vaddr;
  } IBUF_DataSt;
  logic ibuf_flush;
  logic ibuf_write_valid;
  logic ibuf_write_ready;
  logic [$clog2(`FETCH_WIDTH) - 1:0] ibuf_write_num;
  IBUF_DataSt [`FETCH_WIDTH - 1:0] ibuf_write_data;
  logic [$clog2(`DECODE_WIDTH) - 1:0] ibuf_read_num;
  logic [`DECODE_WIDTH - 1:0]ibuf_read_valid;
  logic ibuf_read_ready;
  IBUF_DataSt [`DECODE_WIDTH - 1:0] ibuf_read_data;

  // Decoder
  GeneralCtrlSignalSt [`DECODE_WIDTH - 1:0] general_ctrl_signal;
  logic decoder_flush;

  // Scheduler
  ScheduleReqSt schedule_req_st;
  ScheduleRspSt schedule_rsp_st;

  // misc(BRU/Priv) * 1
  logic misc_valid;
  logic misc_ready;
  logic [$clog2(`PHY_REG_NUM) - 1:0] misc_psrc0_o, misc_psrc1_o;
  MiscOptionCodeSt misc_option_code;
  // ALU * 2
  logic [1:0] alu_valid_o;
  logic [1:0] alu_ready_i;
  logic [1:0][$clog2(`PHY_REG_NUM) - 1:0] alu_psrc0_o, alu_psrc1_o;
  AluOptionCodeSt [1:0] alu_option_code;
  // memory * 1
  logic mem_valid;
  logic mem_ready;
  logic [$clog2(`PHY_REG_NUM) - 1:0] mem_psrc0_o, mem_psrc1_o;
  MemoryOptionCodeSt mem_option_code;


  // RegFile
  logic [`ISSUE_WIDTH * 2 - 1:0][31:0] rf_data_o;

  // CSR
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


  /* BPU */
  always_comb begin
    bpu_req_st.next = faq_push_rsp_st.ready;
  end

  BranchPredictionUnit U_BranchPredictionUnit (
    .clk(clk), 
    .a_rst_n(rst_n), 
    .bpu_req(bpu_req_st), 
    .bpu_rsp(bpu_rsp_st)
  );

  /* Fetch Address Queue */
  always_comb begin
    faq_flush = flush;

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

  /* Instruction Fetch Unit */
  always_comb begin
    icache_fetch_req_st.valid = faq_pop_rsp_st.valid;
    icache_fetch_req_st.vaddr = faq_pop_rsp_st.vaddr;
    icache_axi4_mst = icache_axi4_intf;
  end

  ICache U_ICache (
    .clk               (clk),
    .a_rst_n           (rst_n),
    .fetch_req_st      (icache_fetch_req_st),
    .mmu_search_rsp_st (icahe_mmu_search_req_st),
    .fetch_rsp_st      (icache_fetch_rsp_st),
    .mmu_search_req_st (icache_mmu_search_rsp_st),
    .axi4_mst          (icache_axi4_intf)
  );


  /* Instruction Buffer */
  always_comb begin
    ibuf_flush = 1'b0;  // TODO: add flush logic

    ibuf_write_valid = |icache_fetch_rsp_st.valid;
    ibuf_write_num = '0;
    for (int i = 0; i < `FETCH_WIDTH; i++) begin
      ibuf_write_num += icache_fetch_rsp_st.valid[i];

      ibuf_write_data[i].valid = icache_fetch_rsp_st.valid[i];
      ibuf_write_data[i].vaddr = icache_fetch_rsp_st.vaddr[i];
      ibuf_write_data[i].instruction = icache_fetch_rsp_st.instruction[i];
    end

    ibuf_read_ready = schedule_rsp_st.ready;
    ibuf_read_num = `DECODE_WIDTH;
  end

  SyncMultiChannelFIFO #(
    .FIFO_DEPTH(`IBUF_DEPTH),
    .DATA_WIDTH($bits(IBUF_DataSt)),
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

  /* Decoder */
  for (genvar i = 0; i < `DECODE_WIDTH; i++) begin
    Decoder U_Decoder (.instruction(ibuf_read_data[i].instruction), .general_ctrl_signal(general_ctrl_signal));
  end

  /* Dispatch/Wake up/Select */
  always_comb begin
    schedule_req_st.valid = '0;
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      schedule_req_st.valid |= schedule_req_st.inst_info[i].valid;
    end
    schedule_req_st.ready = '1;
  end

  Scheduler inst_Scheduler
  (
    .clk                   (clk),
    .a_rst_n               (a_rst_n),
    .flush_i               (flush_i),
    .schedule_req          (schedule_req),
    .rob_allocate_rsp      (rob_allocate_rsp),
    .freelist_free_valid_i (freelist_free_valid_i),
    .released_preg_i       (released_preg_i),
    .arch_rat_i            (arch_rat_i),
    .commited_pdest_i      (commited_pdest_i),
    .schedule_rsp          (schedule_rsp),
    .rob_allocate_req      (rob_allocate_req),
    // issue ff ouput
    .misc_valid_o          (misc_valid_o),
    .misc_ready_i          (misc_ready_i),
    .misc_psrc0            (misc_psrc0_o),
    .misc_psrc1            (misc_psrc1_o),
    .misc_imm_o            (misc_imm_o),
    .misc_option_code_o    (misc_option_code_o),
    .alu_valid_o           (alu_valid_o),
    .alu_ready_i           (alu_ready_i),
    .alu_psrc0             (alu_psrc0_o),
    .alu_psrc1             (alu_psrc1_o),
    .alu_imm_o             (alu_imm_o),
    .alu_option_code_o     (alu_option_code_o),
    .mem_valid_o           (mem_valid_o),
    .mem_ready_i           (mem_ready_i),
    .mem_psrc0             (mem_psrc0_o),
    .mem_psrc1             (mem_psrc1_o),
    .mem_imm_o             (mem_imm_o),
    .mem_option_code_o     (mem_option_code_o)
  );

  /* Read RegFile */
  // comb输出用寄存器存一拍
  PhysicalRegisterFile #(
    .READ_PORT_NUM(4),
    .WRITE_PORT_NUM(4),
    .DATA_WIDTH(32),
    .PHY_REG_NUM(64)
  ) U0_PhysicalRegisterFile (
    .clk     (clk),
    .a_rst_n (rst_n),
    .we_i    (),
    .raddr_i ({alu_psrc0, alu_psrc1}),
    .waddr_i (),
    .data_i  (),
    .data_o  (rf_data_o[3:0])
  );

  PhysicalRegisterFile #(
    .READ_PORT_NUM(4),
    .WRITE_PORT_NUM(4),
    .DATA_WIDTH(32),
    .PHY_REG_NUM(64)
  ) U1_PhysicalRegisterFile (
    .clk     (clk),
    .a_rst_n (rst_n),
    .we_i    (),
    .raddr_i ({mem_psrc0, mem_psrc1, mem_psrc2, mem_psrc3}),
    .waddr_i (),
    .data_i  (),
    .data_o  (rf_data_o[7:4])
  );


  /* Integer Block */
  IntegerBlock inst_IntegerBlock
  (
    .clk                (clk),
    .rst_n              (rst_n),
    .misc_valid_o       (misc_valid_o),
    .misc_ready_i       (misc_ready_i),
    .misc_imm_i         (misc_imm_i),
    .misc_src0_i        (misc_src0_i),
    .misc_src1_i        (misc_src1_i),
    .misc_option_code_o (misc_option_code_o),
    .alu_valid_o        (alu_valid_o),
    .alu_ready_i        (alu_ready_i),
    .alu_imm_i          (alu_imm_i),
    .alu_src0_i         (alu_src0_i),
    .alu_src1_i         (alu_src1_i),
    .alu_option_code_o  (alu_option_code_o)
  );


  /* Memory Block */



  /* CSR(Control/Status Register) */
  ControlStatusRegister #(
    .TLBNUM(`TLB_ENTRY_NUM)
  ) inst_ControlStatusRegister (
    .clk                (clk),
    .reset              (~rst_n),
    .rd_addr            (csr_rd_addr),
    .rd_data            (csr_rd_data),
    .timer_64_out       (csr_timer_64_out),
    .tid_out            (csr_tid_out),
    .csr_wr_en          (csr_wr_en),
    .wr_addr            (csr_wr_addr),
    .wr_data            (csr_wr_data),
    .interrupt          (csr_interrupt),
    .has_int            (csr_has_int),
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
    .llbit_in           (csr_llbit_in),
    .llbit_set_in       (csr_llbit_set_in),
    .llbit_out          (csr_llbit_out),
    .vppn_out           (csr_vppn_out),
    .eentry_out         (csr_eentry_out),
    .era_out            (csr_era_out),
    .tlbrentry_out      (csr_tlbrentry_out),
    .disable_cache_out  (csr_disable_cache_out),
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
    .tlbrd_en           (csr_tlbrd_en),
    .tlbehi_in          (csr_tlbehi_in),
    .tlbelo0_in         (csr_tlbelo0_in),
    .tlbelo1_in         (csr_tlbelo1_in),
    .tlbidx_in          (csr_tlbidx_in),
    .asid_in            (csr_asid_in),
    .plv_out            (csr_plv_out),
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



