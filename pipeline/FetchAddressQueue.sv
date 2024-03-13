// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : FetchAddressQueue.sv
// Create  : 2024-02-12 16:37:58
// Revise  : 2024-03-13 17:57:35
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
`include "BranchPredictionUnit.svh"
`include "FetchAddressQueue.svh"
`include "Cache.svh"


module FetchAddressQueue (
  input clk,    // Clock
  input a_rst_n,  // Asynchronous reset active low
  input flush_i,
  input FAQ_PushReqSt push_req_st,
  input FAQ_PopReqSt pop_req_st,
  output FAQ_PushRspSt push_rsp_st,
  output FAQ_PopRspSt pop_rsp_st
);

  `RESET_LOGIC(clk, a_rst_n, rst_n);

  typedef struct packed {
    logic [`PROC_VALEN - 1:0] vaddr;
    logic [`FETCH_WIDTH - 1:0] valid;
  } FAQ_DataSt;

  // 配合ICache工作，每次的fetch请求都要在一个Cache Block中
  typedef enum logic {
    IDEL,  // 无需进行拆分
    SPLIT  // 进行拆分
  } FAQ_State;

  FAQ_State faq_state;
  FAQ_PushReqSt r_push_req_st;
  FAQ_DataSt faq_data_st_i, faq_data_st_o;
  logic empty, full, push, pop;  // fifo ctrl
  logic split;
  logic [$clog2(`FETCH_WIDTH) - 1:0] f_zero_idx, zero_idx;  // register zero index

  

  always_comb begin
    f_zero_idx = (`ICACHE_BLOCK_SIZE / 4) - `ICACHE_WORD_OF(push_req_st.vaddr);
    split = `ICACHE_WORD_OF(push_req_st.vaddr) > (`ICACHE_BLOCK_SIZE / 4) - `FETCH_WIDTH & 
            faq_state == IDEL;
    if (faq_state == SPLIT) begin
      faq_data_st_i.vaddr = r_push_req_st.vaddr & 
                            {{(`PROC_VALEN - `ICACHE_INDEX_OFFSET){1'b1}}, 
                            {(`ICACHE_INDEX_OFFSET - 2){1'b0}}, 2'b11};
      for (int i = 0; i < `FETCH_WIDTH; i++) begin
        if (zero_idx + i < `FETCH_WIDTH) begin
          faq_data_st_i.valid[i] = r_push_req_st.valid[zero_idx];
        end else begin
          faq_data_st_i.valid[i] = '0;
        end
      end
    end else begin
      faq_data_st_i.vaddr = push_req_st.vaddr;
      for (int i = 0; i < `FETCH_WIDTH; i++) begin
        faq_data_st_i.valid[i] = push_req_st.valid[i] & 
                                (`ICACHE_WORD_OF(push_req_st.vaddr) + i < 
                                 `ICACHE_BLOCK_SIZE - `FETCH_WIDTH);
      end
    end

    push = ~full & |faq_data_st_i.valid;
    pop = ~empty & pop_req_st.ready & pop_req_st.valid;

    push_rsp_st.ready = ~full & ~split & faq_state == IDEL;
    push_rsp_st.valid = '1;

    pop_rsp_st.ready = ~empty;
    pop_rsp_st.valid = faq_data_st_o.valid;
    pop_rsp_st.vaddr = faq_data_st_o.vaddr;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      faq_state <= IDEL;
      r_push_req_st <= 0;
      zero_idx <= '0;
    end else begin
      case (faq_state)
        IDEL : if (split) faq_state <= SPLIT;
        SPLIT : if (~full) faq_state <= IDEL;  // 保证fifo有写入空间即可
        default : /* default */;
      endcase
      if (faq_state == IDEL) begin
        r_push_req_st <= push_req_st;
        zero_idx <= f_zero_idx;
      end
    end
  end

  /* Memory */
  SyncFIFO #(
    .FIFO_DEPTH(`FAQ_DEPTH),
    .FIFO_DATA_WIDTH($bits(FAQ_DataSt)),
    .READ_MODE("std"),
    .FIFO_MEMORY_TYPE("auto")
  ) U_SyncFIFO (
    .clk     (clk),
    .a_rst_n (rst_n),
    .flush_i (flush_i),
    .pop_i   (pop_rsp_st.ready),
    .push_i  (push_rsp_st.ready),
    .data_i  (faq_data_st_i),
    .data_o  (faq_data_st_o),
    .empty_o (empty),
    .full_o  (full),
    .usage_o (/* not used */)
  );


  






endmodule : FetchAddressQueue