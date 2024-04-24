// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : ControlStatusRegister.svh
// Create  : 2024-03-19 19:21:21
// Revise  : 2024-03-30 18:27:07
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

`ifndef _CSR_SVH_
`define _CSR_SVH_

//CRMD
`define PLV       1:0
`define IE        2
`define DA        3
`define PG        4
`define DATF      6:5
`define DATM      8:7
//PRMD
`define PPLV      1:0
`define PIE       2
//ECTL
`define LIE       12:0
`define LIE_1     9:0
`define LIE_2     12:11
//ESTAT
`define IS        12:0
`define ECODE     21:16
`define ESUBCODE  30:22
//TLBIDX
`define INDEX     4:0
`define PS        29:24
`define NE        31
//TLBEHI
`define VPPN      31:13
//TLBELO
`define TLB_V      0
`define TLB_D      1
`define TLB_PLV    3:2
`define TLB_MAT    5:4
`define TLB_G      6
`define TLB_PPN    27:8  // PALEN == 32
// `define TLB_PPN_EN 27:8
//ASID
`define TLB_ASID  9:0
//CPUID
`define COREID    8:0
//LLBCTL
`define ROLLB     0
`define WCLLB     1
`define KLO       2
//TCFG
`define EN        0
`define PERIODIC  1
`define INITVAL   31:2
//TICLR
`define CLR       0
//TLBRENTRY
`define TLBRENTRY_PA 31:6
//DMW
`define PLV0      0
`define PLV3      3 
`define DMW_MAT   5:4
`define PSEG      27:25
`define VSEG      31:29
//PGDL PGDH PGD
`define BASE      31:12

`define ECODE_INT  6'h0
`define ECODE_PIL  6'h1
`define ECODE_PIS  6'h2
`define ECODE_PIF  6'h3
`define ECODE_PME  6'h4
`define ECODE_PPI  6'h7
`define ECODE_ADE  6'h8
`define ECODE_ALE  6'h9
`define ECODE_SYS  6'hb
`define ECODE_BRK  6'hc
`define ECODE_INE  6'hd
`define ECODE_IPE  6'he
`define ECODE_FPD  6'hf
`define ECODE_TLBR 6'h3f

`define ESUBCODE_ADEF  9'h0
`define ESUBCODE_ADEM  9'h1

typedef logic[5:0] ExcCodeType;
typedef logic[8:0] SubEcodeType;


typedef struct packed {
	// logic tlbrf;   // 取指TLB充填例外
	// logic tlbrm;   // 访存TLB充填例外
	// logic fpe;	   // 基础浮点指令例外
	// logic fpd;	   // 浮点指令未使能例外
	// logic ipe;     // 指令特权等级错例外
	// logic ine;     // 指令不存在例外
	// logic brk;	   // 断点例外
	// logic sys;	   // 系统调用例外
	// logic ale;     // 地址非对齐例外
	// logic adem;    // 访存指令地址错例外
	// logic adef;    // 取指地址错例外
	// logic ppif;    // 取指页特权等级不合规例外
	// logic ppim;    // 访存页特权等级不合规例外
	// logic pme;     // 页修改例外
	// logic pif;     // 取指操作页无效例外
	// logic pis;     // store 操作页无效例外
	// logic pil;     // load 操作页无效例外
	// logic intrpt;  // 中断
	logic valid;
	ExcCodeType ecode;
	SubEcodeType sub_ecode;
} ExcpSt;


`endif  // _CSR_SVH_
