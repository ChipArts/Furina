// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : config.svh
// Create  : 2024-01-13 21:15:57
// Revise  : 2024-01-13 21:15:57
// Description :
//   配置文件
//   配置代码的运行或测试环境
// Parameter   :
//   ...
//   ...
// IO Port     :
//   ...
//   ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// 24-01-13 |            |     0.1     |    Original Version
// ==============================================================================
`ifndef __CONFIG_SVH__
`define __CONFIG_SVH__

/** simulation or synthesis （确保有且仅有一个环境选项被定义）**/
// `define VERLATOR_SIM      // verilator 仿真
`define XILLINX_FPGA      // xillinx FPGA 仿真综合环境
// `define MSIC180_SYN       // 中芯国际180nm工艺库综合

/** debug **/
`define DEBUG

/** 处理器规格 **/
`define PROC_BIT_WIDTH 32
`define PROC_FETCH_WIDTH 8
`define PROC_DECODE_WIDTH 6
`define PROC_PAGE_SIZE 4096  // Byte

`endif // __CONFIG_SVH__

