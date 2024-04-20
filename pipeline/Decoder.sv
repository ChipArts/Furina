// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : Decoder.sv
// Create  : 2024-03-01 16:02:44
// Revise  : 2024-03-01 16:02:44
// Description :
//   解码器
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
// ==============================================================================

// Generator : SpinalHDL v1.10.1    git head : 2527c7c6b0fb0f95e5e1a5722a0be732b364ce43
// Component : Decoder
// Git hash  : 1fd7c320186dfe928dc2ec7e5d196e8b0d36e7db

// `timescale 1ns/1ps

module Decoder (
  input  wire [31:0]   instr_i,
  output wire [65:0]   option_code_o
);

  wire       [31:0]   _zz_ctrl;
  wire       [31:0]   _zz_ctrl_1;
  wire       [31:0]   _zz_ctrl_2;
  wire       [0:0]    _zz_ctrl_3;
  wire       [31:0]   _zz_ctrl_4;
  wire       [3:0]    _zz_ctrl_5;
  wire       [31:0]   _zz_ctrl_6;
  wire       [31:0]   _zz_ctrl_7;
  wire                _zz_ctrl_8;
  wire       [0:0]    _zz_ctrl_9;
  wire       [31:0]   _zz_ctrl_10;
  wire       [0:0]    _zz_ctrl_11;
  wire       [31:0]   _zz_ctrl_12;
  wire       [1:0]    _zz_ctrl_13;
  wire       [31:0]   _zz_ctrl_14;
  wire       [31:0]   _zz_ctrl_15;
  wire       [31:0]   _zz_ctrl_16;
  wire       [31:0]   _zz_ctrl_17;
  wire                _zz_ctrl_18;
  wire       [31:0]   _zz_ctrl_19;
  wire       [31:0]   _zz_ctrl_20;
  wire       [0:0]    _zz_ctrl_21;
  wire       [0:0]    _zz_ctrl_22;
  wire       [31:0]   _zz_ctrl_23;
  wire       [0:0]    _zz_ctrl_24;
  wire       [31:0]   _zz_ctrl_25;
  wire       [25:0]   _zz_ctrl_26;
  wire       [0:0]    _zz_ctrl_27;
  wire       [31:0]   _zz_ctrl_28;
  wire                _zz_ctrl_29;
  wire                _zz_ctrl_30;
  wire       [0:0]    _zz_ctrl_31;
  wire       [31:0]   _zz_ctrl_32;
  wire       [0:0]    _zz_ctrl_33;
  wire       [31:0]   _zz_ctrl_34;
  wire       [0:0]    _zz_ctrl_35;
  wire       [22:0]   _zz_ctrl_36;
  wire       [0:0]    _zz_ctrl_37;
  wire       [31:0]   _zz_ctrl_38;
  wire                _zz_ctrl_39;
  wire                _zz_ctrl_40;
  wire                _zz_ctrl_41;
  wire       [0:0]    _zz_ctrl_42;
  wire       [0:0]    _zz_ctrl_43;
  wire       [31:0]   _zz_ctrl_44;
  wire       [2:0]    _zz_ctrl_45;
  wire       [31:0]   _zz_ctrl_46;
  wire       [31:0]   _zz_ctrl_47;
  wire                _zz_ctrl_48;
  wire       [31:0]   _zz_ctrl_49;
  wire                _zz_ctrl_50;
  wire       [31:0]   _zz_ctrl_51;
  wire       [19:0]   _zz_ctrl_52;
  wire       [3:0]    _zz_ctrl_53;
  wire       [31:0]   _zz_ctrl_54;
  wire       [31:0]   _zz_ctrl_55;
  wire                _zz_ctrl_56;
  wire       [31:0]   _zz_ctrl_57;
  wire       [0:0]    _zz_ctrl_58;
  wire       [31:0]   _zz_ctrl_59;
  wire       [31:0]   _zz_ctrl_60;
  wire       [0:0]    _zz_ctrl_61;
  wire       [31:0]   _zz_ctrl_62;
  wire       [31:0]   _zz_ctrl_63;
  wire                _zz_ctrl_64;
  wire                _zz_ctrl_65;
  wire       [31:0]   _zz_ctrl_66;
  wire       [0:0]    _zz_ctrl_67;
  wire       [31:0]   _zz_ctrl_68;
  wire       [31:0]   _zz_ctrl_69;
  wire       [2:0]    _zz_ctrl_70;
  wire                _zz_ctrl_71;
  wire       [31:0]   _zz_ctrl_72;
  wire       [0:0]    _zz_ctrl_73;
  wire       [31:0]   _zz_ctrl_74;
  wire       [31:0]   _zz_ctrl_75;
  wire       [0:0]    _zz_ctrl_76;
  wire       [31:0]   _zz_ctrl_77;
  wire       [31:0]   _zz_ctrl_78;
  wire       [0:0]    _zz_ctrl_79;
  wire       [0:0]    _zz_ctrl_80;
  wire       [31:0]   _zz_ctrl_81;
  wire       [31:0]   _zz_ctrl_82;
  wire       [4:0]    _zz_ctrl_83;
  wire                _zz_ctrl_84;
  wire       [31:0]   _zz_ctrl_85;
  wire       [0:0]    _zz_ctrl_86;
  wire       [31:0]   _zz_ctrl_87;
  wire       [31:0]   _zz_ctrl_88;
  wire       [2:0]    _zz_ctrl_89;
  wire                _zz_ctrl_90;
  wire       [31:0]   _zz_ctrl_91;
  wire       [0:0]    _zz_ctrl_92;
  wire       [31:0]   _zz_ctrl_93;
  wire       [31:0]   _zz_ctrl_94;
  wire       [0:0]    _zz_ctrl_95;
  wire       [31:0]   _zz_ctrl_96;
  wire       [31:0]   _zz_ctrl_97;
  wire       [16:0]   _zz_ctrl_98;
  wire       [2:0]    _zz_ctrl_99;
  wire                _zz_ctrl_100;
  wire       [31:0]   _zz_ctrl_101;
  wire       [0:0]    _zz_ctrl_102;
  wire       [31:0]   _zz_ctrl_103;
  wire       [31:0]   _zz_ctrl_104;
  wire       [0:0]    _zz_ctrl_105;
  wire       [31:0]   _zz_ctrl_106;
  wire       [31:0]   _zz_ctrl_107;
  wire                _zz_ctrl_108;
  wire       [0:0]    _zz_ctrl_109;
  wire       [31:0]   _zz_ctrl_110;
  wire       [31:0]   _zz_ctrl_111;
  wire       [0:0]    _zz_ctrl_112;
  wire       [31:0]   _zz_ctrl_113;
  wire       [31:0]   _zz_ctrl_114;
  wire       [0:0]    _zz_ctrl_115;
  wire       [2:0]    _zz_ctrl_116;
  wire                _zz_ctrl_117;
  wire       [31:0]   _zz_ctrl_118;
  wire       [0:0]    _zz_ctrl_119;
  wire       [31:0]   _zz_ctrl_120;
  wire       [31:0]   _zz_ctrl_121;
  wire       [0:0]    _zz_ctrl_122;
  wire       [31:0]   _zz_ctrl_123;
  wire       [31:0]   _zz_ctrl_124;
  wire       [13:0]   _zz_ctrl_125;
  wire                _zz_ctrl_126;
  wire       [0:0]    _zz_ctrl_127;
  wire       [31:0]   _zz_ctrl_128;
  wire       [31:0]   _zz_ctrl_129;
  wire       [2:0]    _zz_ctrl_130;
  wire                _zz_ctrl_131;
  wire       [31:0]   _zz_ctrl_132;
  wire       [0:0]    _zz_ctrl_133;
  wire       [31:0]   _zz_ctrl_134;
  wire       [31:0]   _zz_ctrl_135;
  wire       [0:0]    _zz_ctrl_136;
  wire       [31:0]   _zz_ctrl_137;
  wire       [31:0]   _zz_ctrl_138;
  wire       [0:0]    _zz_ctrl_139;
  wire       [2:0]    _zz_ctrl_140;
  wire                _zz_ctrl_141;
  wire       [31:0]   _zz_ctrl_142;
  wire       [0:0]    _zz_ctrl_143;
  wire       [31:0]   _zz_ctrl_144;
  wire       [31:0]   _zz_ctrl_145;
  wire       [0:0]    _zz_ctrl_146;
  wire       [31:0]   _zz_ctrl_147;
  wire       [31:0]   _zz_ctrl_148;
  wire       [11:0]   _zz_ctrl_149;
  wire                _zz_ctrl_150;
  wire       [0:0]    _zz_ctrl_151;
  wire       [31:0]   _zz_ctrl_152;
  wire       [31:0]   _zz_ctrl_153;
  wire       [2:0]    _zz_ctrl_154;
  wire                _zz_ctrl_155;
  wire       [31:0]   _zz_ctrl_156;
  wire       [0:0]    _zz_ctrl_157;
  wire       [31:0]   _zz_ctrl_158;
  wire       [31:0]   _zz_ctrl_159;
  wire       [0:0]    _zz_ctrl_160;
  wire       [31:0]   _zz_ctrl_161;
  wire       [31:0]   _zz_ctrl_162;
  wire       [0:0]    _zz_ctrl_163;
  wire       [2:0]    _zz_ctrl_164;
  wire                _zz_ctrl_165;
  wire       [31:0]   _zz_ctrl_166;
  wire       [0:0]    _zz_ctrl_167;
  wire       [31:0]   _zz_ctrl_168;
  wire       [31:0]   _zz_ctrl_169;
  wire       [0:0]    _zz_ctrl_170;
  wire       [31:0]   _zz_ctrl_171;
  wire       [31:0]   _zz_ctrl_172;
  wire       [9:0]    _zz_ctrl_173;
  wire                _zz_ctrl_174;
  wire       [0:0]    _zz_ctrl_175;
  wire       [31:0]   _zz_ctrl_176;
  wire       [31:0]   _zz_ctrl_177;
  wire       [1:0]    _zz_ctrl_178;
  wire                _zz_ctrl_179;
  wire       [31:0]   _zz_ctrl_180;
  wire                _zz_ctrl_181;
  wire       [31:0]   _zz_ctrl_182;
  wire       [0:0]    _zz_ctrl_183;
  wire       [0:0]    _zz_ctrl_184;
  wire       [31:0]   _zz_ctrl_185;
  wire       [31:0]   _zz_ctrl_186;
  wire       [7:0]    _zz_ctrl_187;
  wire                _zz_ctrl_188;
  wire       [0:0]    _zz_ctrl_189;
  wire       [31:0]   _zz_ctrl_190;
  wire       [31:0]   _zz_ctrl_191;
  wire       [0:0]    _zz_ctrl_192;
  wire       [31:0]   _zz_ctrl_193;
  wire       [31:0]   _zz_ctrl_194;
  wire       [0:0]    _zz_ctrl_195;
  wire       [1:0]    _zz_ctrl_196;
  wire                _zz_ctrl_197;
  wire                _zz_ctrl_198;
  wire       [5:0]    _zz_ctrl_199;
  wire                _zz_ctrl_200;
  wire       [0:0]    _zz_ctrl_201;
  wire       [31:0]   _zz_ctrl_202;
  wire       [0:0]    _zz_ctrl_203;
  wire       [31:0]   _zz_ctrl_204;
  wire       [0:0]    _zz_ctrl_205;
  wire       [4:0]    _zz_ctrl_206;
  wire       [31:0]   _zz_ctrl_207;
  wire       [31:0]   _zz_ctrl_208;
  wire                _zz_ctrl_209;
  wire       [31:0]   _zz_ctrl_210;
  wire       [0:0]    _zz_ctrl_211;
  wire       [31:0]   _zz_ctrl_212;
  wire       [31:0]   _zz_ctrl_213;
  wire       [1:0]    _zz_ctrl_214;
  wire                _zz_ctrl_215;
  wire                _zz_ctrl_216;
  wire       [3:0]    _zz_ctrl_217;
  wire                _zz_ctrl_218;
  wire                _zz_ctrl_219;
  wire       [31:0]   _zz_ctrl_220;
  wire       [0:0]    _zz_ctrl_221;
  wire       [31:0]   _zz_ctrl_222;
  wire       [31:0]   _zz_ctrl_223;
  wire       [2:0]    _zz_ctrl_224;
  wire                _zz_ctrl_225;
  wire       [0:0]    _zz_ctrl_226;
  wire       [0:0]    _zz_ctrl_227;
  wire       [0:0]    _zz_ctrl_228;
  wire                _zz_ctrl_229;
  wire       [31:0]   _zz_ctrl_230;
  wire       [1:0]    _zz_ctrl_231;
  wire       [0:0]    _zz_ctrl_232;
  wire       [31:0]   _zz_ctrl_233;
  wire       [31:0]   _zz_ctrl_234;
  wire       [1:0]    _zz_ctrl_235;
  wire                _zz_ctrl_236;
  wire                _zz_ctrl_237;
  wire       [31:0]   _zz_fixInvalidInst;
  wire       [31:0]   _zz_fixInvalidInst_1;
  wire       [31:0]   _zz_fixInvalidInst_2;
  wire                _zz_fixInvalidInst_3;
  wire       [0:0]    _zz_fixInvalidInst_4;
  wire       [23:0]   _zz_fixInvalidInst_5;
  wire       [31:0]   _zz_fixInvalidInst_6;
  wire       [31:0]   _zz_fixInvalidInst_7;
  wire       [31:0]   _zz_fixInvalidInst_8;
  wire                _zz_fixInvalidInst_9;
  wire       [0:0]    _zz_fixInvalidInst_10;
  wire       [17:0]   _zz_fixInvalidInst_11;
  wire       [31:0]   _zz_fixInvalidInst_12;
  wire       [31:0]   _zz_fixInvalidInst_13;
  wire       [31:0]   _zz_fixInvalidInst_14;
  wire                _zz_fixInvalidInst_15;
  wire       [0:0]    _zz_fixInvalidInst_16;
  wire       [11:0]   _zz_fixInvalidInst_17;
  wire       [31:0]   _zz_fixInvalidInst_18;
  wire       [31:0]   _zz_fixInvalidInst_19;
  wire       [31:0]   _zz_fixInvalidInst_20;
  wire                _zz_fixInvalidInst_21;
  wire       [0:0]    _zz_fixInvalidInst_22;
  wire       [5:0]    _zz_fixInvalidInst_23;
  wire       [31:0]   _zz_fixInvalidInst_24;
  wire       [31:0]   _zz_fixInvalidInst_25;
  wire       [31:0]   _zz_fixInvalidInst_26;
  wire                _zz_fixInvalidInst_27;
  wire                _zz_fixInvalidInst_28;
  wire       [32:0]   ctrl;
  wire       [64:0]   fixDebug;
  wire       [65:0]   fixInvalidInst;

  assign _zz_ctrl = 32'h70000000;
  assign _zz_ctrl_1 = (instr_i & 32'h68000000);
  assign _zz_ctrl_2 = 32'h20000000;
  assign _zz_ctrl_3 = ((instr_i & _zz_ctrl_4) == 32'h40000000);
  assign _zz_ctrl_5 = {(_zz_ctrl_6 == _zz_ctrl_7),{_zz_ctrl_8,{_zz_ctrl_9,_zz_ctrl_11}}};
  assign _zz_ctrl_13 = {(_zz_ctrl_14 == _zz_ctrl_15),(_zz_ctrl_16 == _zz_ctrl_17)};
  assign _zz_ctrl_18 = (|(_zz_ctrl_19 == _zz_ctrl_20));
  assign _zz_ctrl_21 = (|{_zz_ctrl_22,_zz_ctrl_24});
  assign _zz_ctrl_26 = {(|_zz_ctrl_27),{_zz_ctrl_29,{_zz_ctrl_35,_zz_ctrl_36}}};
  assign _zz_ctrl_4 = 32'h58000000;
  assign _zz_ctrl_6 = (instr_i & 32'h66c00000);
  assign _zz_ctrl_7 = 32'h02000000;
  assign _zz_ctrl_8 = ((instr_i & 32'h66290000) == 32'h00200000);
  assign _zz_ctrl_9 = ((instr_i & _zz_ctrl_10) == 32'h00080000);
  assign _zz_ctrl_11 = ((instr_i & _zz_ctrl_12) == 32'h00020000);
  assign _zz_ctrl_14 = (instr_i & 32'h70000000);
  assign _zz_ctrl_15 = 32'h40000000;
  assign _zz_ctrl_16 = (instr_i & 32'h68000000);
  assign _zz_ctrl_17 = 32'h40000000;
  assign _zz_ctrl_19 = (instr_i & 32'h60000000);
  assign _zz_ctrl_20 = 32'h60000000;
  assign _zz_ctrl_22 = ((instr_i & _zz_ctrl_23) == 32'h24000000);
  assign _zz_ctrl_24 = ((instr_i & _zz_ctrl_25) == 32'h5c000000);
  assign _zz_ctrl_27 = ((instr_i & _zz_ctrl_28) == 32'h00200000);
  assign _zz_ctrl_29 = (|{_zz_ctrl_30,{_zz_ctrl_31,_zz_ctrl_33}});
  assign _zz_ctrl_35 = 1'b0;
  assign _zz_ctrl_36 = {(|_zz_ctrl_37),{_zz_ctrl_39,{_zz_ctrl_42,_zz_ctrl_52}}};
  assign _zz_ctrl_10 = 32'h66290000;
  assign _zz_ctrl_12 = 32'h66268000;
  assign _zz_ctrl_23 = 32'h24000000;
  assign _zz_ctrl_25 = 32'h5c000000;
  assign _zz_ctrl_28 = 32'h66280000;
  assign _zz_ctrl_30 = ((instr_i & 32'h66290000) == 32'h00090000);
  assign _zz_ctrl_31 = ((instr_i & _zz_ctrl_32) == 32'h00088000);
  assign _zz_ctrl_33 = ((instr_i & _zz_ctrl_34) == 32'h00008000);
  assign _zz_ctrl_37 = ((instr_i & _zz_ctrl_38) == 32'h00000000);
  assign _zz_ctrl_39 = (|{_zz_ctrl_40,_zz_ctrl_41});
  assign _zz_ctrl_42 = (|{_zz_ctrl_43,_zz_ctrl_45});
  assign _zz_ctrl_52 = {(|_zz_ctrl_53),{_zz_ctrl_64,{_zz_ctrl_79,_zz_ctrl_98}}};
  assign _zz_ctrl_32 = 32'h66488000;
  assign _zz_ctrl_34 = 32'h66508000;
  assign _zz_ctrl_38 = 32'h66700000;
  assign _zz_ctrl_40 = ((instr_i & 32'h66590000) == 32'h00080000);
  assign _zz_ctrl_41 = ((instr_i & 32'h66700400) == 32'h00000400);
  assign _zz_ctrl_43 = ((instr_i & _zz_ctrl_44) == 32'h10000000);
  assign _zz_ctrl_45 = {(_zz_ctrl_46 == _zz_ctrl_47),{_zz_ctrl_48,_zz_ctrl_50}};
  assign _zz_ctrl_53 = {(_zz_ctrl_54 == _zz_ctrl_55),{_zz_ctrl_56,{_zz_ctrl_58,_zz_ctrl_61}}};
  assign _zz_ctrl_64 = (|{_zz_ctrl_65,{_zz_ctrl_67,_zz_ctrl_70}});
  assign _zz_ctrl_79 = (|{_zz_ctrl_80,_zz_ctrl_83});
  assign _zz_ctrl_98 = {(|_zz_ctrl_99),{_zz_ctrl_108,{_zz_ctrl_115,_zz_ctrl_125}}};
  assign _zz_ctrl_44 = 32'h58000000;
  assign _zz_ctrl_46 = (instr_i & 32'h66140000);
  assign _zz_ctrl_47 = 32'h00040000;
  assign _zz_ctrl_48 = ((instr_i & _zz_ctrl_49) == 32'h00068000);
  assign _zz_ctrl_50 = ((instr_i & _zz_ctrl_51) == 32'h00080000);
  assign _zz_ctrl_54 = (instr_i & 32'h71800000);
  assign _zz_ctrl_55 = 32'h01800000;
  assign _zz_ctrl_56 = ((instr_i & _zz_ctrl_57) == 32'h00400000);
  assign _zz_ctrl_58 = (_zz_ctrl_59 == _zz_ctrl_60);
  assign _zz_ctrl_61 = (_zz_ctrl_62 == _zz_ctrl_63);
  assign _zz_ctrl_65 = ((instr_i & _zz_ctrl_66) == 32'h02000000);
  assign _zz_ctrl_67 = (_zz_ctrl_68 == _zz_ctrl_69);
  assign _zz_ctrl_70 = {_zz_ctrl_71,{_zz_ctrl_73,_zz_ctrl_76}};
  assign _zz_ctrl_80 = (_zz_ctrl_81 == _zz_ctrl_82);
  assign _zz_ctrl_83 = {_zz_ctrl_84,{_zz_ctrl_86,_zz_ctrl_89}};
  assign _zz_ctrl_99 = {_zz_ctrl_100,{_zz_ctrl_102,_zz_ctrl_105}};
  assign _zz_ctrl_108 = (|{_zz_ctrl_109,_zz_ctrl_112});
  assign _zz_ctrl_115 = (|_zz_ctrl_116);
  assign _zz_ctrl_125 = {_zz_ctrl_126,{_zz_ctrl_139,_zz_ctrl_149}};
  assign _zz_ctrl_49 = 32'h66068000;
  assign _zz_ctrl_51 = 32'h662c0000;
  assign _zz_ctrl_57 = 32'h664c0000;
  assign _zz_ctrl_59 = (instr_i & 32'h660c8000);
  assign _zz_ctrl_60 = 32'h00040000;
  assign _zz_ctrl_62 = (instr_i & 32'h660f0000);
  assign _zz_ctrl_63 = 32'h00050000;
  assign _zz_ctrl_66 = 32'h66800000;
  assign _zz_ctrl_68 = (instr_i & 32'h66260000);
  assign _zz_ctrl_69 = 32'h00020000;
  assign _zz_ctrl_71 = ((instr_i & _zz_ctrl_72) == 32'h00020000);
  assign _zz_ctrl_73 = (_zz_ctrl_74 == _zz_ctrl_75);
  assign _zz_ctrl_76 = (_zz_ctrl_77 == _zz_ctrl_78);
  assign _zz_ctrl_81 = (instr_i & 32'h58000000);
  assign _zz_ctrl_82 = 32'h10000000;
  assign _zz_ctrl_84 = ((instr_i & _zz_ctrl_85) == 32'h01400000);
  assign _zz_ctrl_86 = (_zz_ctrl_87 == _zz_ctrl_88);
  assign _zz_ctrl_89 = {_zz_ctrl_90,{_zz_ctrl_92,_zz_ctrl_95}};
  assign _zz_ctrl_100 = ((instr_i & _zz_ctrl_101) == 32'h10000000);
  assign _zz_ctrl_102 = (_zz_ctrl_103 == _zz_ctrl_104);
  assign _zz_ctrl_105 = (_zz_ctrl_106 == _zz_ctrl_107);
  assign _zz_ctrl_109 = (_zz_ctrl_110 == _zz_ctrl_111);
  assign _zz_ctrl_112 = (_zz_ctrl_113 == _zz_ctrl_114);
  assign _zz_ctrl_116 = {_zz_ctrl_117,{_zz_ctrl_119,_zz_ctrl_122}};
  assign _zz_ctrl_126 = (|{_zz_ctrl_127,_zz_ctrl_130});
  assign _zz_ctrl_139 = (|_zz_ctrl_140);
  assign _zz_ctrl_149 = {_zz_ctrl_150,{_zz_ctrl_163,_zz_ctrl_173}};
  assign _zz_ctrl_72 = 32'h66228000;
  assign _zz_ctrl_74 = (instr_i & 32'h664c0000);
  assign _zz_ctrl_75 = 32'h00400000;
  assign _zz_ctrl_77 = (instr_i & 32'h664d0000);
  assign _zz_ctrl_78 = 32'h00040000;
  assign _zz_ctrl_85 = 32'h71400000;
  assign _zz_ctrl_87 = (instr_i & 32'h66068000);
  assign _zz_ctrl_88 = 32'h00060000;
  assign _zz_ctrl_90 = ((instr_i & _zz_ctrl_91) == 32'h00010000);
  assign _zz_ctrl_92 = (_zz_ctrl_93 == _zz_ctrl_94);
  assign _zz_ctrl_95 = (_zz_ctrl_96 == _zz_ctrl_97);
  assign _zz_ctrl_101 = 32'h70000000;
  assign _zz_ctrl_103 = (instr_i & 32'h64400000);
  assign _zz_ctrl_104 = 32'h00400000;
  assign _zz_ctrl_106 = (instr_i & 32'h66000000);
  assign _zz_ctrl_107 = 32'h02000000;
  assign _zz_ctrl_110 = (instr_i & 32'h46418000);
  assign _zz_ctrl_111 = 32'h06408000;
  assign _zz_ctrl_113 = (instr_i & 32'h46411800);
  assign _zz_ctrl_114 = 32'h06401800;
  assign _zz_ctrl_117 = ((instr_i & _zz_ctrl_118) == 32'h06410000);
  assign _zz_ctrl_119 = (_zz_ctrl_120 == _zz_ctrl_121);
  assign _zz_ctrl_122 = (_zz_ctrl_123 == _zz_ctrl_124);
  assign _zz_ctrl_127 = (_zz_ctrl_128 == _zz_ctrl_129);
  assign _zz_ctrl_130 = {_zz_ctrl_131,{_zz_ctrl_133,_zz_ctrl_136}};
  assign _zz_ctrl_140 = {_zz_ctrl_141,{_zz_ctrl_143,_zz_ctrl_146}};
  assign _zz_ctrl_150 = (|{_zz_ctrl_151,_zz_ctrl_154});
  assign _zz_ctrl_163 = (|_zz_ctrl_164);
  assign _zz_ctrl_173 = {_zz_ctrl_174,{_zz_ctrl_183,_zz_ctrl_187}};
  assign _zz_ctrl_91 = 32'h66250000;
  assign _zz_ctrl_93 = (instr_i & 32'h664c0000);
  assign _zz_ctrl_94 = 32'h00400000;
  assign _zz_ctrl_96 = (instr_i & 32'h666a8000);
  assign _zz_ctrl_97 = 32'h00008000;
  assign _zz_ctrl_118 = 32'h46410000;
  assign _zz_ctrl_120 = (instr_i & 32'h46408400);
  assign _zz_ctrl_121 = 32'h06400400;
  assign _zz_ctrl_123 = (instr_i & 32'h46408800);
  assign _zz_ctrl_124 = 32'h06400000;
  assign _zz_ctrl_128 = (instr_i & 32'h56000000);
  assign _zz_ctrl_129 = 32'h04000000;
  assign _zz_ctrl_131 = ((instr_i & _zz_ctrl_132) == 32'h04410000);
  assign _zz_ctrl_133 = (_zz_ctrl_134 == _zz_ctrl_135);
  assign _zz_ctrl_136 = (_zz_ctrl_137 == _zz_ctrl_138);
  assign _zz_ctrl_141 = ((instr_i & _zz_ctrl_142) == 32'h06408000);
  assign _zz_ctrl_143 = (_zz_ctrl_144 == _zz_ctrl_145);
  assign _zz_ctrl_146 = (_zz_ctrl_147 == _zz_ctrl_148);
  assign _zz_ctrl_151 = (_zz_ctrl_152 == _zz_ctrl_153);
  assign _zz_ctrl_154 = {_zz_ctrl_155,{_zz_ctrl_157,_zz_ctrl_160}};
  assign _zz_ctrl_164 = {_zz_ctrl_165,{_zz_ctrl_167,_zz_ctrl_170}};
  assign _zz_ctrl_174 = (|{_zz_ctrl_175,_zz_ctrl_178});
  assign _zz_ctrl_183 = (|_zz_ctrl_184);
  assign _zz_ctrl_187 = {_zz_ctrl_188,{_zz_ctrl_195,_zz_ctrl_199}};
  assign _zz_ctrl_132 = 32'h54410000;
  assign _zz_ctrl_134 = (instr_i & 32'h54408c00);
  assign _zz_ctrl_135 = 32'h04400400;
  assign _zz_ctrl_137 = (instr_i & 32'h54409400);
  assign _zz_ctrl_138 = 32'h04400000;
  assign _zz_ctrl_142 = 32'h46408000;
  assign _zz_ctrl_144 = (instr_i & 32'h46401400);
  assign _zz_ctrl_145 = 32'h06400000;
  assign _zz_ctrl_147 = (instr_i & 32'h46400c00);
  assign _zz_ctrl_148 = 32'h06400000;
  assign _zz_ctrl_152 = (instr_i & 32'h54400000);
  assign _zz_ctrl_153 = 32'h04400000;
  assign _zz_ctrl_155 = ((instr_i & _zz_ctrl_156) == 32'h04000000);
  assign _zz_ctrl_157 = (_zz_ctrl_158 == _zz_ctrl_159);
  assign _zz_ctrl_160 = (_zz_ctrl_161 == _zz_ctrl_162);
  assign _zz_ctrl_165 = ((instr_i & _zz_ctrl_166) == 32'h40000000);
  assign _zz_ctrl_167 = (_zz_ctrl_168 == _zz_ctrl_169);
  assign _zz_ctrl_170 = (_zz_ctrl_171 == _zz_ctrl_172);
  assign _zz_ctrl_175 = (_zz_ctrl_176 == _zz_ctrl_177);
  assign _zz_ctrl_178 = {_zz_ctrl_179,_zz_ctrl_181};
  assign _zz_ctrl_184 = (_zz_ctrl_185 == _zz_ctrl_186);
  assign _zz_ctrl_188 = (|{_zz_ctrl_189,_zz_ctrl_192});
  assign _zz_ctrl_195 = (|_zz_ctrl_196);
  assign _zz_ctrl_199 = {_zz_ctrl_200,{_zz_ctrl_205,_zz_ctrl_217}};
  assign _zz_ctrl_156 = 32'h56000000;
  assign _zz_ctrl_158 = (instr_i & 32'h72580000);
  assign _zz_ctrl_159 = 32'h00080000;
  assign _zz_ctrl_161 = (instr_i & 32'h72700000);
  assign _zz_ctrl_162 = 32'h00000000;
  assign _zz_ctrl_166 = 32'h40000000;
  assign _zz_ctrl_168 = (instr_i & 32'h20000000);
  assign _zz_ctrl_169 = 32'h20000000;
  assign _zz_ctrl_171 = (instr_i & 32'h06400000);
  assign _zz_ctrl_172 = 32'h06000000;
  assign _zz_ctrl_176 = (instr_i & 32'h40000000);
  assign _zz_ctrl_177 = 32'h40000000;
  assign _zz_ctrl_179 = ((instr_i & _zz_ctrl_180) == 32'h000c0000);
  assign _zz_ctrl_181 = ((instr_i & _zz_ctrl_182) == 32'h00200000);
  assign _zz_ctrl_185 = (instr_i & 32'h54008000);
  assign _zz_ctrl_186 = 32'h10000000;
  assign _zz_ctrl_189 = (_zz_ctrl_190 == _zz_ctrl_191);
  assign _zz_ctrl_192 = (_zz_ctrl_193 == _zz_ctrl_194);
  assign _zz_ctrl_196 = {_zz_ctrl_197,_zz_ctrl_198};
  assign _zz_ctrl_200 = (|{_zz_ctrl_201,_zz_ctrl_203});
  assign _zz_ctrl_205 = (|_zz_ctrl_206);
  assign _zz_ctrl_217 = {_zz_ctrl_218,{_zz_ctrl_228,_zz_ctrl_231}};
  assign _zz_ctrl_180 = 32'h260c0000;
  assign _zz_ctrl_182 = 32'h26280000;
  assign _zz_ctrl_190 = (instr_i & 32'h46400000);
  assign _zz_ctrl_191 = 32'h06000000;
  assign _zz_ctrl_193 = (instr_i & 32'h54008000);
  assign _zz_ctrl_194 = 32'h10008000;
  assign _zz_ctrl_197 = ((instr_i & 32'h54008000) == 32'h10008000);
  assign _zz_ctrl_198 = ((instr_i & 32'h53000000) == 32'h01000000);
  assign _zz_ctrl_201 = ((instr_i & _zz_ctrl_202) == 32'h40000000);
  assign _zz_ctrl_203 = ((instr_i & _zz_ctrl_204) == 32'h10000000);
  assign _zz_ctrl_206 = {(_zz_ctrl_207 == _zz_ctrl_208),{_zz_ctrl_209,{_zz_ctrl_211,_zz_ctrl_214}}};
  assign _zz_ctrl_218 = (|{_zz_ctrl_219,{_zz_ctrl_221,_zz_ctrl_224}});
  assign _zz_ctrl_228 = (|_zz_ctrl_229);
  assign _zz_ctrl_231 = {(|_zz_ctrl_232),(|_zz_ctrl_235)};
  assign _zz_ctrl_202 = 32'h40000000;
  assign _zz_ctrl_204 = 32'h30000000;
  assign _zz_ctrl_207 = (instr_i & 32'h70000000);
  assign _zz_ctrl_208 = 32'h20000000;
  assign _zz_ctrl_209 = ((instr_i & _zz_ctrl_210) == 32'h08000000);
  assign _zz_ctrl_211 = (_zz_ctrl_212 == _zz_ctrl_213);
  assign _zz_ctrl_214 = {_zz_ctrl_215,_zz_ctrl_216};
  assign _zz_ctrl_219 = ((instr_i & _zz_ctrl_220) == 32'h10000000);
  assign _zz_ctrl_221 = (_zz_ctrl_222 == _zz_ctrl_223);
  assign _zz_ctrl_224 = {_zz_ctrl_225,{_zz_ctrl_226,_zz_ctrl_227}};
  assign _zz_ctrl_229 = ((instr_i & _zz_ctrl_230) == 32'h22400000);
  assign _zz_ctrl_232 = (_zz_ctrl_233 == _zz_ctrl_234);
  assign _zz_ctrl_235 = {_zz_ctrl_236,_zz_ctrl_237};
  assign _zz_ctrl_210 = 32'h68000000;
  assign _zz_ctrl_212 = (instr_i & 32'h68000000);
  assign _zz_ctrl_213 = 32'h40000000;
  assign _zz_ctrl_215 = ((instr_i & 32'h43400000) == 32'h02000000);
  assign _zz_ctrl_216 = ((instr_i & 32'h47000000) == 32'h02000000);
  assign _zz_ctrl_220 = 32'h50000000;
  assign _zz_ctrl_222 = (instr_i & 32'h44400000);
  assign _zz_ctrl_223 = 32'h04400000;
  assign _zz_ctrl_225 = ((instr_i & 32'h46000000) == 32'h04000000);
  assign _zz_ctrl_226 = ((instr_i & 32'h61000000) == 32'h01000000);
  assign _zz_ctrl_227 = ((instr_i & 32'h62400000) == 32'h00000000);
  assign _zz_ctrl_230 = 32'h62c00000;
  assign _zz_ctrl_233 = (instr_i & 32'h00000000);
  assign _zz_ctrl_234 = 32'h00000000;
  assign _zz_ctrl_236 = ((instr_i & 32'h62400000) == 32'h22000000);
  assign _zz_ctrl_237 = ((instr_i & 32'h5a400000) == 32'h08400000);
  assign _zz_fixInvalidInst = 32'hdc000000;
  assign _zz_fixInvalidInst_1 = (instr_i & 32'hf6000000);
  assign _zz_fixInvalidInst_2 = 32'h14000000;
  assign _zz_fixInvalidInst_3 = ((instr_i & 32'hfe000000) == 32'h20000000);
  assign _zz_fixInvalidInst_4 = ((instr_i & 32'hfd800000) == 32'h28000000);
  assign _zz_fixInvalidInst_5 = {((instr_i & 32'hfe400000) == 32'h28000000),{((instr_i & 32'hfe800000) == 32'h28000000),{((instr_i & _zz_fixInvalidInst_6) == 32'h04000000),{(_zz_fixInvalidInst_7 == _zz_fixInvalidInst_8),{_zz_fixInvalidInst_9,{_zz_fixInvalidInst_10,_zz_fixInvalidInst_11}}}}}};
  assign _zz_fixInvalidInst_6 = 32'hff000000;
  assign _zz_fixInvalidInst_7 = (instr_i & 32'hff400000);
  assign _zz_fixInvalidInst_8 = 32'h2a400000;
  assign _zz_fixInvalidInst_9 = ((instr_i & 32'hff400000) == 32'h03400000);
  assign _zz_fixInvalidInst_10 = ((instr_i & 32'hfec00000) == 32'h02800000);
  assign _zz_fixInvalidInst_11 = {((instr_i & 32'hfec00000) == 32'h02400000),{((instr_i & 32'hfbc00000) == 32'h02000000),{((instr_i & _zz_fixInvalidInst_12) == 32'h00150000),{(_zz_fixInvalidInst_13 == _zz_fixInvalidInst_14),{_zz_fixInvalidInst_15,{_zz_fixInvalidInst_16,_zz_fixInvalidInst_17}}}}}};
  assign _zz_fixInvalidInst_12 = 32'hfffd0000;
  assign _zz_fixInvalidInst_13 = (instr_i & 32'hfff68000);
  assign _zz_fixInvalidInst_14 = 32'h00140000;
  assign _zz_fixInvalidInst_15 = ((instr_i & 32'hfff70000) == 32'h00140000);
  assign _zz_fixInvalidInst_16 = ((instr_i & 32'hfffe0000) == 32'h00200000);
  assign _zz_fixInvalidInst_17 = {((instr_i & 32'hfff38000) == 32'h00100000),{((instr_i & 32'hfffa8000) == 32'h00100000),{((instr_i & _zz_fixInvalidInst_18) == 32'h38720000),{(_zz_fixInvalidInst_19 == _zz_fixInvalidInst_20),{_zz_fixInvalidInst_21,{_zz_fixInvalidInst_22,_zz_fixInvalidInst_23}}}}}};
  assign _zz_fixInvalidInst_18 = 32'hffff0000;
  assign _zz_fixInvalidInst_19 = (instr_i & 32'hfffe8000);
  assign _zz_fixInvalidInst_20 = 32'h06488000;
  assign _zz_fixInvalidInst_21 = ((instr_i & 32'hfffe8000) == 32'h002a0000);
  assign _zz_fixInvalidInst_22 = ((instr_i & 32'hfffb8000) == 32'h00408000);
  assign _zz_fixInvalidInst_23 = {((instr_i & 32'hfff78000) == 32'h00408000),{((instr_i & 32'hffff0000) == 32'h00120000),{((instr_i & _zz_fixInvalidInst_24) == 32'h06483000),{(_zz_fixInvalidInst_25 == _zz_fixInvalidInst_26),{_zz_fixInvalidInst_27,_zz_fixInvalidInst_28}}}}};
  assign _zz_fixInvalidInst_24 = 32'hfffff800;
  assign _zz_fixInvalidInst_25 = (instr_i & 32'hfffff400);
  assign _zz_fixInvalidInst_26 = 32'h06483000;
  assign _zz_fixInvalidInst_27 = ((instr_i & 32'hfffff800) == 32'h06482800);
  assign _zz_fixInvalidInst_28 = ((instr_i & 32'hfffff800) == 32'h00006000);
  assign ctrl = {(|((instr_i & 32'h62800000) == 32'h22800000)),{(|((instr_i & _zz_ctrl) == 32'h40000000)),{(|(_zz_ctrl_1 == _zz_ctrl_2)),{(|{_zz_ctrl_3,_zz_ctrl_5}),{(|_zz_ctrl_13),{_zz_ctrl_18,{_zz_ctrl_21,_zz_ctrl_26}}}}}}};
  assign fixDebug = {instr_i,ctrl};
  assign fixInvalidInst = {fixDebug,(! (|{((instr_i & 32'hf0000000) == 32'h50000000),{((instr_i & 32'hf0000000) == 32'h60000000),{((instr_i & _zz_fixInvalidInst) == 32'h4c000000),{(_zz_fixInvalidInst_1 == _zz_fixInvalidInst_2),{_zz_fixInvalidInst_3,{_zz_fixInvalidInst_4,_zz_fixInvalidInst_5}}}}}}))};
  assign option_code_o = fixInvalidInst;

endmodule
