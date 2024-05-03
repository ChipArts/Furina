// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : BranchPredictionUnit.sv
// Create  : 2024-02-12 15:35:06
// Revise  : 2024-03-13 17:57:33
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

// `define NPC

module BranchPredictionUnit (
  input logic clk,    // Clock
  input logic rst_n,  // Asynchronous reset active low
  input BpuReqSt req,
  output BpuRspSt rsp
);

  localparam NPC_OFS = $clog2(`FETCH_WIDTH) + 2;

`ifdef NPC
  logic [31:0] pc, npc;

  assign npc = req.redirect ? req.target : 
               req.next     ? {pc[31:NPC_OFS] + 1, {NPC_OFS{1'b0}}} : 
                              pc;


  always_comb begin

    rsp.pc = pc;
    rsp.npc = npc;
    rsp.valid = '1 & {`FETCH_WIDTH{req.next}};
    for (int i = 0; i < `FETCH_WIDTH; i++) begin
      if (i < pc[NPC_OFS - 1:2]) begin
        rsp.valid[i] = '0;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc <= 32'h1c00_0000;
    end else begin
      pc <= npc;
    end
  end


`else
/*==============================================================================*/
/*===================================== BPU ====================================*/
/*==============================================================================*/
  
  logic [31:0] pc;
  logic [31:0] npc;
  logic [31:0] ppc;
  logic taken;
  logic br_idx;  // 标记那条指令被预测 TODO 参数化这个值

  /* for predict */
  logic taken0, taken1;


  always_ff @(posedge clk or negedge rst_n) begin : proc_pc
    if(!rst_n) begin
      pc <= 32'h1c00_0000;
    end else if (req.redirect) begin
      pc <= req.target;
    end else begin
      pc <= npc;
    end
  end

  assign npc = req.redirect ? {req.target[31:NPC_OFS] + 1, {NPC_OFS{1'b0}}} : 
               req.next     ? ppc : 
                              pc;

/*===================================== BTB ====================================*/
  wire [1:0] btb_br_type[1:0];
  wire [31:2] btb_bta[1:0];

  BranchTargetBuffer #(
    .ADDR_WIDTH(`BTB_ADDR_WIDTH)
  ) inst_btb (
    .clk       (clk),
    .rst_n     (rst_n),
    .rpc_i     (npc[31:2]),
    .update_i  (req.btb_update),
    .wpc_i     (req.pc[31:2]),
    .bta_i     (req.target[31:2]),
    .br_type_i (req.br_type),
    // output
    .bta_o     (btb_bta),
    .br_type_o (btb_br_type)
  );


/*==================================== LPHT ====================================*/
  wire [1:0] lphr [1:0];
  wire [`LPHT_ADDR_WIDTH - 2:0] lphr_windex = req.pc[`LPHT_ADDR_WIDTH + 1:3];

  PatternHistoryTable #(
    .ADDR_WIDTH(`LPHT_ADDR_WIDTH - 1)
  ) lpht_bank0 (
    .clk      (clk),
    .rst_n    (rst_n),
    .we_i     (req.lpht_update & ~req.pc[2]),
    .taken_i  (req.taken),
    .phr_i    (req.lphr),
    .rindex_i (npc[`LPHT_ADDR_WIDTH + 1:3]),
    .windex_i (lphr_windex),
    .phr_o    (lphr[0])
  );

  PatternHistoryTable #(
    .ADDR_WIDTH(`LPHT_ADDR_WIDTH - 1)
  ) lpht_bank1 (
    .clk      (clk),
    .rst_n    (rst_n),
    .we_i     (req.lpht_update & req.pc[2]),
    .taken_i  (req.taken),
    .phr_i    (req.lphr),
    .rindex_i (npc[`LPHT_ADDR_WIDTH + 1:3]),
    .windex_i (lphr_windex),
    .phr_o    (lphr[1])
  );



/*===================================== RAS ====================================*/
  wire [31:2] ras_target;
  wire [$clog2(`RAS_STACK_DEPTH) - 1:0] ras_ptr;

  ReturnAddressStack #(
    .STACK_DEPTH(`RAS_STACK_DEPTH)
  ) inst_ras (
    .clk      (clk),
    .rst_n    (rst_n),
    .pop_i    (btb_br_type[br_idx] == `RETURN & req.next),
    .push_i   (btb_br_type[br_idx] == `CALL   & req.next),
    .redirect_i (req.ras_redirect),
    .stack_ptr_i(req.ras_ptr),
    .target_i ({pc[30:3], 1'b0} + 30'd1 + br_idx),
    .redirect_target_i(req.pc[31:2] + 30'd1),
    .target_o (ras_target),
    .stack_ptr_o(ras_ptr)
  );

/*=============================== predict logic ===============================*/
  assign taken0 = ((|btb_br_type[0]) | lphr[0][1]) & ~pc[2];
  assign taken1 = (|btb_br_type[1]) | lphr[1][1];
  assign br_idx = (taken0 ? '0 : taken1) | pc[2];
  assign taken = taken0 | taken1;
  assign ppc = btb_br_type[br_idx] == `RETURN ? {ras_target, 2'b00} :
               taken                          ? {btb_bta[br_idx], 2'b00} : 
                                                {pc[31:3] + 29'd1, 3'b000};

  // output
  always_comb begin : proc_rsp
    rsp.pc = pc;
    rsp.valid[0] = ~pc[2] & req.next; // pc是2字对齐的
    rsp.valid[1] = (~taken0 | pc[2]) & req.next; // 预测第一条不跳转或第一条无效
    rsp.npc = npc;
    rsp.br_info.taken = taken;
    rsp.br_info.lphr = lphr[br_idx];
    rsp.br_info.br_type = btb_br_type[br_idx];
    rsp.br_info.ras_ptr = ras_ptr;
    rsp.br_info.br_idx = br_idx;
  end

`endif

endmodule : BranchPredictionUnit
