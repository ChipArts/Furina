// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : BitCounter.sv
// Create  : 2024-01-29 17:26:40
// Revise  : 2024-01-29 17:26:40
// Description :
//   位计数器
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


module BitCounter #(
parameter
  int unsigned DATA_WIDTH = 6
)(
  input logic [DATA_WIDTH - 1:0] bits_i,
  output logic [$clog2(DATA_WIDTH + 1) - 1:0] cnt_o
);
  
  logic [DATA_WIDTH - 1:0][$clog2(DATA_WIDTH + 1) - 1:0] bits;
  always_comb begin
    bits = '0;
    for (int i = 0; i < DATA_WIDTH; i++) begin
      bits[i] |= bits_i[i];
    end
    for (int i = 0; i < $clog2(DATA_WIDTH); i++) begin
      for (int j = 0; j < $ceil(DATA_WIDTH / (1 << i)); j++) begin
        if (((j + 1) << i) < DATA_WIDTH) begin
          bits[j << i] += bits[(j + 1) << i];
        end
      end
    end
    cnt_o = bits[0];
  end



endmodule : BitCounter