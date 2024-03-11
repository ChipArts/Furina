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

/** 处理器规格/设计方案 **/
// RESET
`define DIST_DRIVE_RESET  // 分布式驱动复位，在每一个模块中添加异步复位同步释放逻辑
// Processor
`define PROC_FETCH_WIDTH 8
`define PROC_DECODE_WIDTH 4
`define PROC_VALEN 32
`define PROC_PALEN 32
// TLB
`define TLB_ENTRY_NUM 16
// Cache
`define ICACHE_SIZE 1024 * 4  // ICache大小(Byte)
`define ICACHE_BLOCK_SIZE 4 * 16  // ICache块大小(Byte)
`define ICACHE_ASSOCIATIVITY 2  // ICache相联度(简化实现 不要更改)

`define DCACHE_SIZE 1024 * 4  // DCache大小(Byte)
`define DCACHE_BLOCK_SIZE 4 * 16  // DCache块大小(Byte)
`define DCACHE_ASSOCIATIVITY 2  // DCache相联度(简化实现 不要更改)

`define L2CACHE_SIZE 128 * 1024  // L2Cache大小(Byte)
`define L2CACHE_BLOCK_SIZE 4 * 16  // L2Cache块大小(Byte)
`define L2CACHE_ASSOCIATIVITY 8  // L2Cache相联度

`endif // __CONFIG_SVH__

