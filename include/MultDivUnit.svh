// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : MultDivUnit.svh
// Create  : 2024-03-03 20:35:16
// Revise  : 2024-03-03 21:45:06
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


`ifndef _MULT_DIV_UNIT_
`define _MULT_DIV_UNIT_

typedef struct packed {
  logic valid;
  logic ready;
  logic flush;
  logic mul_signed;
  logic [31:0] multiplicand;
  logic [31:0] multiplier;
} MDUMultReqSt;

typedef struct packed {
  logic ready;
  logic valid;
  logic [31:0] res_hi;
  logic [31:0] res_lo;
} MDUMultRspSt;

typedef struct packed {
  logic valid;
  logic ready;
  logic flush;
  logic div_signed;
  logic [31:0] dividend;
  logic [31:0] divisor;
} MDUDivReqSt;

typedef struct packed {
  logic ready;
  logic valid;
  logic [31:0] quotient;
  logic [31:0] remainder;
} MDUDivRspSt;


`endif  // _MULT_DIV_UNIT_