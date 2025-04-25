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
`define CHIPLAB_SIM          // chiplab verilator 仿真
// `define XILLINX_FPGA      // xillinx FPGA 仿真综合环境
// `define MSIC180_SYN       // 中芯国际180nm工艺库综合

/** debug **/
`define DEBUG

/** 处理器规格/设计方案(暂时不支持参数修改) **/
// RESET
// `define DIST_DRIVE_RESET  // 分布式驱动复位，在每一个模块中添加异步复位同步释放逻辑
// Processor
`define FETCH_WIDTH 2    // 取指令的宽度
`define DECODE_WIDTH 2   // 解码宽度
`define DISPATCH_WIDTH 2 // 每周期最多派遣的指令的个数
`define WB_WIDTH 5   // 每周期最多写回的指令数
`define COMMIT_WIDTH 2   // 每周期最多提交的指令数
`define PROC_VALEN 32
`define PROC_PALEN 32
`define PHY_REG_NUM 64
`define ROB_DEPTH 64  // ROB深度
// TLB
`define TLB_ENTRY_NUM 32
// Cache
`define ICACHE_SIZE (1024 * 4)  // ICache大小(Byte)
`define ICACHE_BLOCK_SIZE (4 * 8)  // ICache块大小(Byte)
`define ICACHE_WAY_NUM 2  // ICache相联度(简化实现 不要更改)

`define DCACHE_SIZE (1024 * 4)  // DCache大小(Byte)
`define DCACHE_BLOCK_SIZE (4 * 8)  // DCache块大小(Byte)
`define DCACHE_WAY_NUM 2  // DCache相联度(简化实现 不要更改)

// Instruction Buffer
`define IBUF_DEPTH 16

`endif // __CONFIG_SVH__

/*======================================  ======================================*/

