// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : config.svh
// Create  : 2024-01-13 21:15:57
// Revise  : 2024-01-13 21:15:57
// Description :
//   配置文件
//   此中的SRAM不一定由SRAM IP构成，也可以是寄存器堆，也可以是FPGA的BRAM
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
`define VIVADO_VCS_SIM		 // vivado vcs 联合仿真
// `define XILLINX_FPGA_SYN  // xillinx FPGA综合
// `define MSIC180_SYN       // 中芯国际180nm工艺库综合

/** debug **/
`define DEBUG


`endif // __CONFIG_SVH__

