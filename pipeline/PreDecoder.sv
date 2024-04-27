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

// Generator : SpinalHDL v1.10.1    git head : 2527c7c6b0fb0f95e5e1a5722a0be732b364ce43
// Component : Decoder
// Git hash  : 1fd7c320186dfe928dc2ec7e5d196e8b0d36e7db

module PreDecoder (
  input  wire [31:0]   instr_i,
  output wire [6:0]    pre_option_code_o
);

  wire       [31:0]   _zz_ctrl;
  wire                _zz_ctrl_1;
  wire       [0:0]    _zz_ctrl_2;
  wire       [31:0]   _zz_ctrl_3;
  wire       [3:0]    _zz_ctrl_4;
  wire       [31:0]   _zz_ctrl_5;
  wire       [31:0]   _zz_ctrl_6;
  wire                _zz_ctrl_7;
  wire       [31:0]   _zz_ctrl_8;
  wire       [0:0]    _zz_ctrl_9;
  wire       [31:0]   _zz_ctrl_10;
  wire       [31:0]   _zz_ctrl_11;
  wire       [0:0]    _zz_ctrl_12;
  wire       [31:0]   _zz_ctrl_13;
  wire       [31:0]   _zz_ctrl_14;
  wire       [0:0]    _zz_ctrl_15;
  wire       [31:0]   _zz_ctrl_16;
  wire       [2:0]    _zz_ctrl_17;
  wire       [31:0]   _zz_ctrl_18;
  wire       [31:0]   _zz_ctrl_19;
  wire                _zz_ctrl_20;
  wire       [31:0]   _zz_ctrl_21;
  wire                _zz_ctrl_22;
  wire       [31:0]   _zz_ctrl_23;
  wire       [1:0]    _zz_ctrl_24;
  wire       [31:0]   _zz_ctrl_25;
  wire       [31:0]   _zz_ctrl_26;
  wire       [31:0]   _zz_ctrl_27;
  wire       [31:0]   _zz_ctrl_28;
  wire                _zz_ctrl_29;
  wire                _zz_ctrl_30;
  wire       [31:0]   _zz_ctrl_31;
  wire       [0:0]    _zz_ctrl_32;
  wire       [31:0]   _zz_ctrl_33;
  wire       [31:0]   _zz_ctrl_34;
  wire       [8:0]    _zz_ctrl_35;
  wire                _zz_ctrl_36;
  wire       [31:0]   _zz_ctrl_37;
  wire       [0:0]    _zz_ctrl_38;
  wire       [31:0]   _zz_ctrl_39;
  wire       [31:0]   _zz_ctrl_40;
  wire       [6:0]    _zz_ctrl_41;
  wire                _zz_ctrl_42;
  wire       [0:0]    _zz_ctrl_43;
  wire       [31:0]   _zz_ctrl_44;
  wire       [4:0]    _zz_ctrl_45;
  wire       [31:0]   _zz_ctrl_46;
  wire       [31:0]   _zz_ctrl_47;
  wire                _zz_ctrl_48;
  wire       [0:0]    _zz_ctrl_49;
  wire       [1:0]    _zz_ctrl_50;
  wire       [0:0]    _zz_ctrl_51;
  wire       [0:0]    _zz_ctrl_52;
  wire       [31:0]   _zz_ctrl_53;
  wire       [31:0]   _zz_ctrl_54;
  wire       [5:0]    _zz_ctrl_55;
  wire                _zz_ctrl_56;
  wire       [31:0]   _zz_ctrl_57;
  wire       [0:0]    _zz_ctrl_58;
  wire       [31:0]   _zz_ctrl_59;
  wire       [31:0]   _zz_ctrl_60;
  wire       [3:0]    _zz_ctrl_61;
  wire                _zz_ctrl_62;
  wire       [0:0]    _zz_ctrl_63;
  wire       [31:0]   _zz_ctrl_64;
  wire       [1:0]    _zz_ctrl_65;
  wire       [31:0]   _zz_ctrl_66;
  wire       [31:0]   _zz_ctrl_67;
  wire       [31:0]   _zz_ctrl_68;
  wire       [31:0]   _zz_ctrl_69;
  wire       [0:0]    _zz_ctrl_70;
  wire       [0:0]    _zz_ctrl_71;
  wire       [31:0]   _zz_ctrl_72;
  wire       [31:0]   _zz_ctrl_73;
  wire       [1:0]    _zz_ctrl_74;
  wire                _zz_ctrl_75;
  wire       [31:0]   _zz_ctrl_76;
  wire                _zz_ctrl_77;
  wire       [31:0]   _zz_ctrl_78;
  wire       [6:0]    ctrl;
  wire       [6:0]    fixDebug;
  wire       [6:0]    fixInvalidInst;

  assign _zz_ctrl = 32'h40000000;
  assign _zz_ctrl_1 = ((instr_i & 32'h60000000) == 32'h60000000);
  assign _zz_ctrl_2 = ((instr_i & _zz_ctrl_3) == 32'h58000000);
  assign _zz_ctrl_4 = {(_zz_ctrl_5 == _zz_ctrl_6),{_zz_ctrl_7,{_zz_ctrl_9,_zz_ctrl_12}}};
  assign _zz_ctrl_15 = ((instr_i & _zz_ctrl_16) == 32'h01000000);
  assign _zz_ctrl_17 = {(_zz_ctrl_18 == _zz_ctrl_19),{_zz_ctrl_20,_zz_ctrl_22}};
  assign _zz_ctrl_24 = {(_zz_ctrl_25 == _zz_ctrl_26),(_zz_ctrl_27 == _zz_ctrl_28)};
  assign _zz_ctrl_29 = (|{_zz_ctrl_30,{_zz_ctrl_32,_zz_ctrl_35}});
  assign _zz_ctrl_51 = (|{_zz_ctrl_52,_zz_ctrl_55});
  assign _zz_ctrl_70 = (|{_zz_ctrl_71,_zz_ctrl_74});
  assign _zz_ctrl_3 = 32'h58000000;
  assign _zz_ctrl_5 = (instr_i & 32'h56000000);
  assign _zz_ctrl_6 = 32'h04000000;
  assign _zz_ctrl_7 = ((instr_i & _zz_ctrl_8) == 32'h04410000);
  assign _zz_ctrl_9 = (_zz_ctrl_10 == _zz_ctrl_11);
  assign _zz_ctrl_12 = (_zz_ctrl_13 == _zz_ctrl_14);
  assign _zz_ctrl_16 = 32'h53000000;
  assign _zz_ctrl_18 = (instr_i & 32'h46410000);
  assign _zz_ctrl_19 = 32'h06410000;
  assign _zz_ctrl_20 = ((instr_i & _zz_ctrl_21) == 32'h00100000);
  assign _zz_ctrl_22 = ((instr_i & _zz_ctrl_23) == 32'h00200000);
  assign _zz_ctrl_25 = (instr_i & 32'h6c000000);
  assign _zz_ctrl_26 = 32'h44000000;
  assign _zz_ctrl_27 = (instr_i & 32'h66700400);
  assign _zz_ctrl_28 = 32'h00000000;
  assign _zz_ctrl_30 = ((instr_i & _zz_ctrl_31) == 32'h20000000);
  assign _zz_ctrl_32 = (_zz_ctrl_33 == _zz_ctrl_34);
  assign _zz_ctrl_35 = {_zz_ctrl_36,{_zz_ctrl_38,_zz_ctrl_41}};
  assign _zz_ctrl_52 = (_zz_ctrl_53 == _zz_ctrl_54);
  assign _zz_ctrl_55 = {_zz_ctrl_56,{_zz_ctrl_58,_zz_ctrl_61}};
  assign _zz_ctrl_71 = (_zz_ctrl_72 == _zz_ctrl_73);
  assign _zz_ctrl_74 = {_zz_ctrl_75,_zz_ctrl_77};
  assign _zz_ctrl_8 = 32'h54410000;
  assign _zz_ctrl_10 = (instr_i & 32'h72100000);
  assign _zz_ctrl_11 = 32'h00100000;
  assign _zz_ctrl_13 = (instr_i & 32'h72280000);
  assign _zz_ctrl_14 = 32'h00200000;
  assign _zz_ctrl_21 = 32'h66100000;
  assign _zz_ctrl_23 = 32'h66280000;
  assign _zz_ctrl_31 = 32'h68000000;
  assign _zz_ctrl_33 = (instr_i & 32'h70000000);
  assign _zz_ctrl_34 = 32'h40000000;
  assign _zz_ctrl_36 = ((instr_i & _zz_ctrl_37) == 32'h04000000);
  assign _zz_ctrl_38 = (_zz_ctrl_39 == _zz_ctrl_40);
  assign _zz_ctrl_41 = {_zz_ctrl_42,{_zz_ctrl_43,_zz_ctrl_45}};
  assign _zz_ctrl_53 = (instr_i & 32'h42010000);
  assign _zz_ctrl_54 = 32'h02010000;
  assign _zz_ctrl_56 = ((instr_i & _zz_ctrl_57) == 32'h40000000);
  assign _zz_ctrl_58 = (_zz_ctrl_59 == _zz_ctrl_60);
  assign _zz_ctrl_61 = {_zz_ctrl_62,{_zz_ctrl_63,_zz_ctrl_65}};
  assign _zz_ctrl_72 = (instr_i & 32'h60000000);
  assign _zz_ctrl_73 = 32'h60000000;
  assign _zz_ctrl_75 = ((instr_i & _zz_ctrl_76) == 32'h58000000);
  assign _zz_ctrl_77 = ((instr_i & _zz_ctrl_78) == 32'h04000000);
  assign _zz_ctrl_37 = 32'h46000000;
  assign _zz_ctrl_39 = (instr_i & 32'h6c000000);
  assign _zz_ctrl_40 = 32'h44000000;
  assign _zz_ctrl_42 = ((instr_i & 32'h64400000) == 32'h00400000);
  assign _zz_ctrl_43 = ((instr_i & _zz_ctrl_44) == 32'h00100000);
  assign _zz_ctrl_45 = {(_zz_ctrl_46 == _zz_ctrl_47),{_zz_ctrl_48,{_zz_ctrl_49,_zz_ctrl_50}}};
  assign _zz_ctrl_57 = 32'h70000000;
  assign _zz_ctrl_59 = (instr_i & 32'h70000000);
  assign _zz_ctrl_60 = 32'h20000000;
  assign _zz_ctrl_62 = ((instr_i & 32'h42400000) == 32'h02000000);
  assign _zz_ctrl_63 = ((instr_i & _zz_ctrl_64) == 32'h00400000);
  assign _zz_ctrl_65 = {(_zz_ctrl_66 == _zz_ctrl_67),(_zz_ctrl_68 == _zz_ctrl_69)};
  assign _zz_ctrl_76 = 32'h58000000;
  assign _zz_ctrl_78 = 32'h56000000;
  assign _zz_ctrl_44 = 32'h64100000;
  assign _zz_ctrl_46 = (instr_i & 32'h66000000);
  assign _zz_ctrl_47 = 32'h02000000;
  assign _zz_ctrl_48 = ((instr_i & 32'h73000000) == 32'h20000000);
  assign _zz_ctrl_49 = ((instr_i & 32'h64280000) == 32'h00200000);
  assign _zz_ctrl_50 = {((instr_i & 32'h71800000) == 32'h20000000),((instr_i & 32'h64200400) == 32'h00000400)};
  assign _zz_ctrl_64 = 32'h64400000;
  assign _zz_ctrl_66 = (instr_i & 32'h64100000);
  assign _zz_ctrl_67 = 32'h00100000;
  assign _zz_ctrl_68 = (instr_i & 32'h64280000);
  assign _zz_ctrl_69 = 32'h00200000;
  assign ctrl = {(|((instr_i & _zz_ctrl) == 32'h40000000)),{(|{_zz_ctrl_1,{_zz_ctrl_2,_zz_ctrl_4}}),{(|{_zz_ctrl_15,_zz_ctrl_17}),{(|_zz_ctrl_24),{_zz_ctrl_29,{_zz_ctrl_51,_zz_ctrl_70}}}}}};
  assign fixDebug = ctrl;
  assign fixInvalidInst = fixDebug;
  assign pre_option_code_o = fixInvalidInst;

endmodule
