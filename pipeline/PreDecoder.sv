// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : PreDecoder.sv
// Create  : 2024-03-17 18:02:08
// Revise  : 2024-03-17 18:02:08
// Description :
//   
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
`include "Decoder.svh"

module PreDecoder (
  input  wire [31:0]   instr_i,
  output wire [5:0]    pre_option_code_o
);

  wire       [31:0]   _zz_ctrl;
  wire       [31:0]   _zz_ctrl_1;
  wire                _zz_ctrl_2;
  wire       [31:0]   _zz_ctrl_3;
  wire       [0:0]    _zz_ctrl_4;
  wire       [31:0]   _zz_ctrl_5;
  wire       [31:0]   _zz_ctrl_6;
  wire       [0:0]    _zz_ctrl_7;
  wire       [31:0]   _zz_ctrl_8;
  wire       [31:0]   _zz_ctrl_9;
  wire                _zz_ctrl_10;
  wire       [31:0]   _zz_ctrl_11;
  wire       [0:0]    _zz_ctrl_12;
  wire       [31:0]   _zz_ctrl_13;
  wire       [31:0]   _zz_ctrl_14;
  wire       [0:0]    _zz_ctrl_15;
  wire       [31:0]   _zz_ctrl_16;
  wire       [31:0]   _zz_ctrl_17;
  wire                _zz_ctrl_18;
  wire       [31:0]   _zz_ctrl_19;
  wire       [7:0]    _zz_ctrl_20;
  wire                _zz_ctrl_21;
  wire       [0:0]    _zz_ctrl_22;
  wire       [31:0]   _zz_ctrl_23;
  wire       [5:0]    _zz_ctrl_24;
  wire       [31:0]   _zz_ctrl_25;
  wire       [31:0]   _zz_ctrl_26;
  wire                _zz_ctrl_27;
  wire       [0:0]    _zz_ctrl_28;
  wire       [31:0]   _zz_ctrl_29;
  wire       [2:0]    _zz_ctrl_30;
  wire       [31:0]   _zz_ctrl_31;
  wire       [31:0]   _zz_ctrl_32;
  wire                _zz_ctrl_33;
  wire                _zz_ctrl_34;
  wire                _zz_ctrl_35;
  wire       [0:0]    _zz_ctrl_36;
  wire       [31:0]   _zz_ctrl_37;
  wire       [5:0]    _zz_ctrl_38;
  wire       [31:0]   _zz_ctrl_39;
  wire       [31:0]   _zz_ctrl_40;
  wire                _zz_ctrl_41;
  wire       [0:0]    _zz_ctrl_42;
  wire       [31:0]   _zz_ctrl_43;
  wire       [2:0]    _zz_ctrl_44;
  wire       [31:0]   _zz_ctrl_45;
  wire       [31:0]   _zz_ctrl_46;
  wire                _zz_ctrl_47;
  wire                _zz_ctrl_48;
  wire                _zz_ctrl_49;
  wire       [0:0]    _zz_ctrl_50;
  wire       [31:0]   _zz_ctrl_51;
  wire       [0:0]    _zz_ctrl_52;
  wire       [31:0]   _zz_ctrl_53;
  wire       [5:0]    ctrl;
  wire       [5:0]    fixDebug;
  wire       [5:0]    fixInvalidInst;

  assign _zz_ctrl = (instr_i & 32'h60000000);
  assign _zz_ctrl_1 = 32'h60000000;
  assign _zz_ctrl_2 = ((instr_i & _zz_ctrl_3) == 32'h58000000);
  assign _zz_ctrl_4 = (_zz_ctrl_5 == _zz_ctrl_6);
  assign _zz_ctrl_7 = (_zz_ctrl_8 == _zz_ctrl_9);
  assign _zz_ctrl_10 = ((instr_i & _zz_ctrl_11) == 32'h01000000);
  assign _zz_ctrl_12 = (_zz_ctrl_13 == _zz_ctrl_14);
  assign _zz_ctrl_15 = (_zz_ctrl_16 == _zz_ctrl_17);
  assign _zz_ctrl_18 = ((instr_i & _zz_ctrl_19) == 32'h00000000);
  assign _zz_ctrl_20 = {_zz_ctrl_21,{_zz_ctrl_22,_zz_ctrl_24}};
  assign _zz_ctrl_35 = (|{_zz_ctrl_36,_zz_ctrl_38});
  assign _zz_ctrl_49 = (|{_zz_ctrl_50,_zz_ctrl_52});
  assign _zz_ctrl_3 = 32'h58000000;
  assign _zz_ctrl_5 = (instr_i & 32'h66100000);
  assign _zz_ctrl_6 = 32'h00100000;
  assign _zz_ctrl_8 = (instr_i & 32'h66280000);
  assign _zz_ctrl_9 = 32'h00200000;
  assign _zz_ctrl_11 = 32'h53000000;
  assign _zz_ctrl_13 = (instr_i & 32'h66100000);
  assign _zz_ctrl_14 = 32'h00100000;
  assign _zz_ctrl_16 = (instr_i & 32'h66280000);
  assign _zz_ctrl_17 = 32'h00200000;
  assign _zz_ctrl_19 = 32'h66700400;
  assign _zz_ctrl_21 = ((instr_i & 32'h46000000) == 32'h02000000);
  assign _zz_ctrl_22 = ((instr_i & _zz_ctrl_23) == 32'h40000000);
  assign _zz_ctrl_24 = {(_zz_ctrl_25 == _zz_ctrl_26),{_zz_ctrl_27,{_zz_ctrl_28,_zz_ctrl_30}}};
  assign _zz_ctrl_36 = ((instr_i & _zz_ctrl_37) == 32'h20000000);
  assign _zz_ctrl_38 = {(_zz_ctrl_39 == _zz_ctrl_40),{_zz_ctrl_41,{_zz_ctrl_42,_zz_ctrl_44}}};
  assign _zz_ctrl_50 = ((instr_i & _zz_ctrl_51) == 32'h60000000);
  assign _zz_ctrl_52 = ((instr_i & _zz_ctrl_53) == 32'h58000000);
  assign _zz_ctrl_23 = 32'h70000000;
  assign _zz_ctrl_25 = (instr_i & 32'h61000000);
  assign _zz_ctrl_26 = 32'h20000000;
  assign _zz_ctrl_27 = ((instr_i & 32'h46000000) == 32'h04000000);
  assign _zz_ctrl_28 = ((instr_i & _zz_ctrl_29) == 32'h00400000);
  assign _zz_ctrl_30 = {(_zz_ctrl_31 == _zz_ctrl_32),{_zz_ctrl_33,_zz_ctrl_34}};
  assign _zz_ctrl_37 = 32'h60000000;
  assign _zz_ctrl_39 = (instr_i & 32'h46000000);
  assign _zz_ctrl_40 = 32'h02000000;
  assign _zz_ctrl_41 = ((instr_i & 32'h44100000) == 32'h00100000);
  assign _zz_ctrl_42 = ((instr_i & _zz_ctrl_43) == 32'h40000000);
  assign _zz_ctrl_44 = {(_zz_ctrl_45 == _zz_ctrl_46),{_zz_ctrl_47,_zz_ctrl_48}};
  assign _zz_ctrl_51 = 32'h60000000;
  assign _zz_ctrl_53 = 32'h58000000;
  assign _zz_ctrl_29 = 32'h64400000;
  assign _zz_ctrl_31 = (instr_i & 32'h64100000);
  assign _zz_ctrl_32 = 32'h00100000;
  assign _zz_ctrl_33 = ((instr_i & 32'h64280000) == 32'h00200000);
  assign _zz_ctrl_34 = ((instr_i & 32'h64200400) == 32'h00000400);
  assign _zz_ctrl_43 = 32'h70000000;
  assign _zz_ctrl_45 = (instr_i & 32'h44400000);
  assign _zz_ctrl_46 = 32'h00400000;
  assign _zz_ctrl_47 = ((instr_i & 32'h56000000) == 32'h04000000);
  assign _zz_ctrl_48 = ((instr_i & 32'h44280000) == 32'h00200000);
  assign ctrl = {(|{(_zz_ctrl == _zz_ctrl_1),{_zz_ctrl_2,{_zz_ctrl_4,_zz_ctrl_7}}}),{(|{_zz_ctrl_10,{_zz_ctrl_12,_zz_ctrl_15}}),{(|_zz_ctrl_18),{(|_zz_ctrl_20),{_zz_ctrl_35,_zz_ctrl_49}}}}};
  assign fixDebug = ctrl;
  assign fixInvalidInst = fixDebug;
  assign pre_option_code_o = fixInvalidInst;

endmodule

