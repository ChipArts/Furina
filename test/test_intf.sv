// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : test_intf.sv
// Create  : 2024-02-14 22:31:46
// Revise  : 2024-02-14 22:34:20
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

module test_intf (
  input clk,    // Clock
  input clk_en, // Clock Enable
  input rst_n,  // Asynchronous reset active low
  AXI4.Master axi_mst
);



endmodule : test_intf


module test_intf1 (
  input clk,    // Clock
  input rst_n,  // Asynchronous reset active low
  AXI4.Master axi_mst
);


  test_intf u_test_intf (
    .clk    (clk),
    .rst_n  (rst_n),
    .axi_mst(axi_mst),
    .clk_en ('1)
  );

endmodule : test_intf1
