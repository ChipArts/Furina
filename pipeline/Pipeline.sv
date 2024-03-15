// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Pipeline.sv
// Create  : 2024-03-11 14:53:30
// Revise  : 2024-03-14 18:39:33
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

  InstInfoSt [`DECODE_WIDTH - 1:0] inst_info_st;

  // Scheduler
  ScheduleReqSt schedule_req_st;
  ScheduleRspSt schedule_rsp_st;


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
    faq_flush = 1'b0;  // TODO: add flush logic

    faq_push_req_st.valid = bpu_rsp_st.valid;
    faq_push_req_st.vaddr = bpu_rsp_st.pc;
    faq_push_req_st.ready = 1'b1;

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

    ibuf_read_ready = dispatch_rsp_st.ready;
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

  /* Decoder & Rename */
  for (genvar i = 0; i < `DECODE_WIDTH; i++) begin
    Decoder inst_Decoder (.instruction(ibuf_read_data[i].instruction), .general_ctrl_signal(general_ctrl_signal));
  end

  always_comb begin
    decoder_flush = 1'b0;  // TODO: add flush logic
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      inst_info_st[i].valid = ibuf_read_data[i].valid;
      inst_info_st[i].vaddr = ibuf_read_data[i].vaddr;
      inst_info_st[i].operand = ibuf_read_data[i].instruction[25:0];
      inst_info_st[i].general_ctrl_signal = general_ctrl_signal[i];
    end
  end

  RegisterAliasTable #(
    .PHYS_REG_NUM(`PHY_REG_NUM)
  ) U_IntegerRegisterAliasTable (
    .clk         (clk),
    .a_rst_n     (rst_n),
    .restore_i   (),
    .allocaion_i ('0),
    .free_i      (),
    .arch_rat    (),
    .valid_i     (valid_i),
    .src0_i      (src0_i),
    .src1_i      (src1_i),
    .dest_i      (dest_i),
    .preg_i      (preg_i),
    .psrc0_o     (psrc0_o),
    .psrc1_o     (psrc1_o),
    .ppdst_o     (ppdst_o)
  );

  /* Instruction Info Buffer */
  // 从此指令执行所需的全部信息都已经产生
  PipelineRegister #(
    .DATA_TYPE(InstInfoSt[`DECODE_WIDTH - 1:0])
  ) U_DecodeInfoBuffer (
    .clk     (clk),
    .a_rst_n (rst_n),
    .we_i    (|ibuf_read_valid & schedule_rsp_st.ready),
    .flush_i (decoder_flush),
    .data_i  (inst_info_st),
    .data_o  (schedule_req_st.inst_info)
  );


  /* Dispatch */
  always_comb begin
    schedule_req_st.valid = '0;
    for (int i = 0; i < `DECODE_WIDTH; i++) begin
      schedule_req_st.valid |= schedule_req_st.inst_info[i].valid;
    end
    schedule_req_st.ready = '1;
  end

  

endmodule : Pipeline



