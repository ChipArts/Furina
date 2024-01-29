// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : MultiPortFIFO.sv
// Create  : 2024-01-16 12:01:16
// Revise  : 2024-01-16 13:54:50
// Description :
//   Multi Port FIFO
//   1 clk latency
//   为了简化设计，push和pop有效位必须连续并从[0]开始
// Parameter   :
//   ...
//   ...
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// 24-01-16 |            |     0.1     |    Original Version
// ==============================================================================

`include "config.svh"
`include "common.svh"

module MultiPortFIFO #(
parameter
  int unsigned FIFO_DEPTH = 16,
  int unsigned DATA_WIDTH = 32,
  int unsigned RPORTS_NUM = 6,
  int unsigned WPORTS_NUM = 6,
localparam
  int unsigned ADDR_WIDTH = $clog2(FIFO_DEPTH)
)(
  input logic clk,      // Clock
  input logic a_rst_n,  // Asynchronous reset active low
  
  input logic flush_i,
  input logic [WPORTS_NUM - 1:0] push_i,  // 入队OH
  input logic [RPORTS_NUM - 1:0] pop_i,   // 出队OH
  input logic [WPORTS_NUM - 1:0][DATA_WIDTH - 1:0] data_i,
  output logic [RPORTS_NUM - 1:0][DATA_WIDTH - 1:0] data_o,
  output logic [ADDR_WIDTH - 1:0] usage_o,
  output logic full_o,
  output logic empty_o,
  output logic can_push,
  output logic can_pop
);


  localparam BANK_NUM = WPORTS_NUM > RPORTS_NUM ? WPORTS_NUM : RPORTS_NUM;

`ifdef DEBUG
  initial begin
    assert (FIFO_DEPTH > BANK_NUM) else $error("FIFO: FIFO_DEPTH must bigger than max PORTS_NUM");
  end
`endif

  `RESET_LOGIC(clk, a_rst_n, s_rst_n)

  localparam RAM_DEPTH = FIFO_DEPTH % BANK_NUM == 0 ? FIFO_DEPTH / BANK_NUM : FIFO_DEPTH / BANK_NUM + 1;

  // reg
  // 队尾入队，队头出队
  logic [$clog2(FIFO_DEPTH + 1) - 1:0] fifo_usage;
  logic [$clog2(FIFO_DEPTH) - 1:0] head_ptr, tail_ptr;
  logic [BANK_NUM - 1:0][$clog2(RAM_DEPTH) - 1:0] ram_head_ptr, ram_tail_ptr;
  logic [$clog2(BANK_NUM) - 1:0] wbank_ptr, rbank_ptr, pre_rbank_ptr;  // 指向下一个要被写、读的RAM
  logic [RPORTS_NUM - 1:0] r_pop_i;
  // wire
  logic [BANK_NUM - 1:0] we;
  logic [$clog2(WPORTS_NUM + 1) - 1:0] push_num;  // push的数据个数
  logic [$clog2(RPORTS_NUM + 1) - 1:0] pop_num;  // pop的数据个数
  logic [BANK_NUM - 1:0][DATA_WIDTH - 1:0] push_data, pop_data;
  logic [$clog2(FIFO_DEPTH + 1) - 1:0] f_fifo_usage;
  logic [$clog2(FIFO_DEPTH) - 1:0] f_head_ptr, f_tail_ptr;
  logic [BANK_NUM - 1:0][$clog2(RAM_DEPTH) - 1:0] f_ram_head_ptr, f_ram_tail_ptr;
  logic [$clog2(BANK_NUM) - 1:0] f_wbank_ptr, f_rbank_ptr;


  // bit count
  BitCounter #(.DATA_WIDTH(WPORTS_NUM)) U_WPortBitCounter (.bits_i(push_i), .cnt_o(push_num));
  BitCounter #(.DATA_WIDTH(RPORTS_NUM)) U_RPortBitCounter (.bits_i(pop_i), .cnt_o(pop_num));

  always_comb begin : read_write_logic
    can_push = $signed(fifo_usage + push_num - pop_num) <= FIFO_DEPTH;
    can_pop = $signed(fifo_usage + push_num - pop_num) >= 0;
    we = '0;
    f_fifo_usage = fifo_usage;
    f_head_ptr = head_ptr;
    f_tail_ptr = tail_ptr;
    f_ram_head_ptr = ram_head_ptr;
    f_ram_tail_ptr = ram_tail_ptr;
    push_data = '0;
    pop_data = '0;
    data_o = '0;
    full_o = fifo_usage == FIFO_DEPTH;
    empty_o = fifo_usage == 0;

    // write logic
    if (|push_i && can_push) begin
      f_fifo_usage = f_fifo_usage + push_num;
      f_tail_ptr = tail_ptr + push_num;
      // 更新读端口的BANK指针 考虑到可能存在 wbank_ptr =\= 2**k 手动实现取模运算
      if (wbank_ptr + push_i > BANK_NUM) begin
        f_wbank_ptr = wbank_ptr + push_num - BANK_NUM;
      end else begin
        f_wbank_ptr = wbank_ptr + push_num;
      end

      for (int i = 0; i < WPORTS_NUM; i++) begin
        if (push_i[i]) begin
          if (wbank_ptr + i < BANK_NUM) begin
            f_tail_ptr[rbank_ptr + i] = tail_ptr[rbank_ptr + i] + 1;
            we[wbank_ptr + i] = '1;
            push_data[wbank_ptr + i] = data_i[i];
          end else begin
            f_tail_ptr[rbank_ptr + i - BANK_NUM] = tail_ptr[rbank_ptr + i - BANK_NUM] + 1;
            we[wbank_ptr + i - BANK_NUM] = '1;
            push_data[wbank_ptr + i - BANK_NUM] = data_i[i];
          end
        end
      end


    end


    // read logic
    if (|pop_i && can_pop) begin
      f_fifo_usage = f_fifo_usage - pop_i;
      f_head_ptr = head_ptr + pop_i;
      // 更新读端口的BANK指针 考虑到可能存在 rbank_ptr =\= 2**k 手动实现取模运算
      if (rbank_ptr + push_i > BANK_NUM) begin
        f_rbank_ptr = rbank_ptr + push_i - BANK_NUM;
      end else begin
        f_rbank_ptr = rbank_ptr + push_i;
      end

      for (int i = 0; i < RPORTS_NUM; i++) begin
        if (pop_i[i]) begin
          if (rbank_ptr + i < BANK_NUM) begin
            f_head_ptr[rbank_ptr + i] = head_ptr[rbank_ptr + i] + 1;
          end else begin
            f_head_ptr[rbank_ptr + i - BANK_NUM] = head_ptr[rbank_ptr + i - BANK_NUM] + 1;
          end
        end
      end

      for (int i = 0; i < RPORTS_NUM; i++) begin
        if (r_pop_i[i]) begin
          if (pre_rbank_ptr + i < BANK_NUM) begin
            data_o[i] = pop_data[pre_rbank_ptr + i];
          end else begin
            data_o[i] = pop_data[pre_rbank_ptr + i - BANK_NUM];
          end
        end
      end
    end

  end


  always_ff @(posedge clk or negedge s_rst_n) begin
    if(~s_rst_n) begin
      head_ptr <= '0;
      tail_ptr <= '0;
      fifo_usage <= '0;
      wbank_ptr <= '0;
      rbank_ptr <= '0;
      pre_rbank_ptr <= '0;
      r_pop_i <= '0;
    end else begin
      if (flush_i) begin
        head_ptr <= '0;
        tail_ptr <= '0;
        fifo_usage <= '0;
        wbank_ptr <= '0;
        rbank_ptr <= '0;
        pre_rbank_ptr <= '0;
        r_pop_i <= '0;
      end else begin
        head_ptr <= f_head_ptr;
        tail_ptr <= f_tail_ptr;
        fifo_usage <= f_fifo_usage;
        wbank_ptr <= f_wbank_ptr;
        rbank_ptr <= f_rbank_ptr;
        pre_rbank_ptr <= rbank_ptr;
        r_pop_i <= pop_i;
      end
    end
  end

  generate
    for (genvar i = 0; i < BANK_NUM; i++) begin : FifoMemory
      SimpleDualPortRAM #(
        .DATA_DEPTH(RAM_DEPTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BYTE_WRITE_WIDTH(DATA_WIDTH),
        .CLOCKING_MODE   ("common_clock"),
        .WRITE_MODE      ("write_first")
      ) inst_SimpleDualPortRAM (
        .clk_a    (clk),
        .en_a_i   (1'b1),
        .we_a_i   (we),
        .addr_a_i (ram_tail_ptr[i]),
        .data_a_i (push_data[i]),
        .clk_b    (clk),
        .rstb_n   (s_rst_n),
        .en_b_i   (1'b1),
        .addr_b_i (ram_head_ptr[i]),
        .data_b_o (pop_data[i])
      );
    end
  endgenerate

endmodule : MultiPortFIFO
