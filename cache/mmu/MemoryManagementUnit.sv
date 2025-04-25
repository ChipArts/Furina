// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : SuYang 2506806016@qq.com
// File    : MemoryManagementUnit.sv
// Create  : 2024-03-11 19:19:09
// Revise  : 2024-03-31 19:07:47
// Description :
//   龙芯架构内存管理单元(MMU)实现
//   负责虚拟地址到物理地址的转换和内存保护
// Parameter   :
//   TLB_ENTRY_NUM - TLB条目数量
// IO Port     :
//   clk, a_rst_n - 时钟和复位信号
//   csr_* - 来自控制状态寄存器的配置信号
//   addr_trans_req/rsp - 地址转换请求/响应接口
//   tlb*_* - TLB相关操作的接口
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
// xx-xx-xx |            |     0.1     |    Original Version
// ...
// ==============================================================================

`include "../../config.svh"
`include "../../include/common.svh"
`include "../../include/MemoryManagementUnit.svh"
`include "../../include/ControlStatusRegister.svh"
`include "../../include/TranslationLookasideBuffer.svh"

module MemoryManagementUnit (
  input logic clk,    // 时钟
  input logic a_rst_n,  // 低电平有效的异步复位
  // 从CSR接收的配置信号
  input logic [9:0]  csr_asid_i,    // 地址空间标识符
  input logic [31:0] csr_dmw0_i,    // 直接映射窗口0配置
  input logic [31:0] csr_dmw1_i,    // 直接映射窗口1配置
  input logic [1:0]  csr_datf_i,    // 取指访问类型
  input logic [1:0]  csr_datm_i,    // 数据访问类型
  input logic [1:0]  csr_plv_i ,    // 当前特权级
  input logic        csr_da_i  ,    // 直接地址转换模式使能
  input logic        csr_pg_i  ,    // 分页地址转换模式使能
  // // inst addr trans - 指令地址转换接口
  // input MmuAddrTransReqSt inst_trans_req,
  // output MmuAddrTransRspSt inst_trans_rsp,
  // // data addr trans - 数据地址转换接口
  // input MmuAddrTransReqSt data_trans_req,
  // output MmuAddrTransRspSt data_trans_rsp,
  input  MmuAddrTransReqSt [1:0] addr_trans_req,   // 地址转换请求数组[0:指令,1:数据]
  output MmuAddrTransRspSt [1:0] addr_trans_rsp,   // 地址转换响应数组[0:指令,1:数据]
  // tlb search - TLB查询接口
  input logic  tlbsrch_en_i,        // TLBSRCH指令使能
  output logic tlbsrch_found_o,     // TLBSRCH查询命中标志
  output logic [$clog2(`TLB_ENTRY_NUM) - 1:0] tlbsrch_idx_o,  // TLBSRCH匹配条目索引
  // tlbfill tlbwr tlb write - TLB写入接口
  input logic        tlbfill_en_i,   // TLBFILL指令使能
  input logic        tlbwr_en_i  ,   // TLBWR指令使能
  input logic [ 4:0] rand_idx_i,     // TLBFILL使用的随机索引
  input logic [31:0] tlbehi_i ,      // TLBEHI寄存器输入(包含VPN)
  input logic [31:0] tlbelo0_i,      // TLBELO0寄存器输入(包含偶数页PPN等)
  input logic [31:0] tlbelo1_i,      // TLBELO1寄存器输入(包含奇数页PPN等)
  input logic [31:0] tlbidx_i ,      // TLBIDX寄存器输入(包含索引和页大小)
  input logic [ 5:0] ecode_i  ,      // 异常代码
  //tlbr tlb read - TLB读取接口
  input  logic tlbrd_en_i,           // TLBRD指令使能
  output logic [31:0] tlbehi_o ,     // TLBEHI寄存器输出
  output logic [31:0] tlbelo0_o,     // TLBELO0寄存器输出
  output logic [31:0] tlbelo1_o,     // TLBELO1寄存器输出
  output logic [31:0] tlbidx_o ,     // TLBIDX寄存器输出
  output logic [ 9:0] tlbasid_o,     // TLBASID寄存器输出
  // invtlb - TLB失效接口
  input logic        invtlb_en_i  ,  // INVTLB指令使能
  input logic [ 9:0] invtlb_asid_i,  // INVTLB使用的ASID
  input logic [18:0] invtlb_vpn_i,   // INVTLB使用的VPN
  input logic [ 4:0] invtlb_op_i     // INVTLB操作码
);

  // 同步复位信号生成宏
  `RESET_LOGIC(clk, a_rst_n, rst_n);

  // 地址转换模式控制信号
  logic        pg_mode;   // 页式地址转换模式标志
  logic        da_mode;   // 直接地址转换模式标志

  // 直接映射窗口使能信号
  logic [1:0] dmw0_en, dmw1_en;   // DMW0和DMW1窗口使能[0:指令,1:数据]
  logic [1:0] addr_trans_en;      // 地址转换使能[0:指令,1:数据]

  // TLB接口结构体
  TlbSearchReqSt [2:0] tlb_search_req;  // TLB查询请求[0:指令,1:数据,2:TLBSRCH]
  TlbSearchRspSt [2:0] tlb_search_rsp;  // TLB查询响应[0:指令,1:数据,2:TLBSRCH]
  // tlbrd - TLB读取接口
  TlbReadReqSt tlb_read_req;      // TLB读取请求
  TlbReadRspSt tlb_read_rsp;      // TLB读取响应
  // tlbfill tlbwr - TLB写入接口
  TlbWriteReqSt tlb_write_req;    // TLB写入请求
  TlbWriteRspSt tlb_write_rsp;    // TLB写入响应
  // invtlb - TLB失效接口
  TlbInvReqSt tlb_inv_req;        // TLB失效请求
  TlbInvRspSt tlb_inv_rsp;        // TLB失效响应

  // TLB读取结果的临时变量
  logic [18:0] r_vppn      ;  // 虚拟页号
  logic [ 9:0] r_asid      ;  // 地址空间ID
  logic        r_g         ;  // 全局标志
  logic [ 5:0] r_ps        ;  // 页大小
  logic        r_e         ;  // 条目有效标志
  logic        r_v0        ;  // 偶数页有效标志
  logic        r_d0        ;  // 偶数页脏标志
  logic [ 1:0] r_mat0      ;  // 偶数页内存属性
  logic [ 1:0] r_plv0      ;  // 偶数页特权级
  logic [19:0] r_ppn0      ;  // 偶数页物理页号
  logic        r_v1        ;  // 奇数页有效标志
  logic        r_d1        ;  // 奇数页脏标志
  logic [ 1:0] r_mat1      ;  // 奇数页内存属性
  logic [ 1:0] r_plv1      ;  // 奇数页特权级
  logic [19:0] r_ppn1      ;  // 奇数页物理页号

  // 地址转换请求缓冲，用于多周期处理
  MmuAddrTransReqSt [1:0] addr_trans_req_buffer;

  // 缓存地址转换请求，用于多周期处理
  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
      addr_trans_req_buffer <= '0;
    end else begin
      for (int i = 0; i < 2; i++) begin
        if (addr_trans_req[i].valid) begin
          addr_trans_req_buffer[i] <= addr_trans_req[i];
        end
      end
    end
  end

  // 构造TLB查询请求
  always_comb begin : proc_srch_req
    // 指令地址转换的TLB查询请求
    tlb_search_req[0].valid = addr_trans_req[0].valid;      // 请求有效位
    tlb_search_req[0].asid  = csr_asid_i;                   // 使用当前ASID
    tlb_search_req[0].vpn   = addr_trans_req[0].vaddr[`PROC_VALEN - 1:12];  // 提取虚拟页号

    // 数据地址转换的TLB查询请求
    tlb_search_req[1].valid = addr_trans_req[1].valid;      // 请求有效位
    tlb_search_req[1].asid  = csr_asid_i;                   // 使用当前ASID
    tlb_search_req[1].vpn   = addr_trans_req[1].vaddr[`PROC_VALEN - 1:12];  // 提取虚拟页号

    // TLBSRCH指令的TLB查询请求
    tlb_search_req[2].valid = tlbsrch_en_i;                 // 由TLBSRCH指令使能
    tlb_search_req[2].asid  = csr_asid_i;                   // 使用当前ASID
    tlb_search_req[2].vpn   = {tlbehi_i[`VPPN], 1'b0};      // 使用TLBEHI中的VPN
  end

  // 构造TLB写入请求(用于TLBWR和TLBFILL指令)
  always_comb begin : proc_write_req
    // TLB写入请求
    tlb_write_req.valid = tlbfill_en_i || tlbwr_en_i;   // TLBFILL或TLBWR指令使能时有效
    
    // 根据指令类型选择索引: TLBFILL使用随机索引，TLBWR使用TLBIDX寄存器中的索引
    tlb_write_req.idx = ({5{tlbfill_en_i}} & rand_idx_i) | ({5{tlbwr_en_i}} & tlbidx_i[`INDEX]);
    
    // 构造TLB条目
    tlb_write_req.tlb_entry_st = '{
        exist     : (ecode_i == 6'h3f) ? 1'b1 : !tlbidx_i[`NE],  // 条目有效位：异常为ECODE_TLBR时强制有效，否则由NE位决定
        asid      : csr_asid_i,                                   // 当前ASID
        glo       : tlbelo1_i[`TLB_G] & tlbelo0_i[`TLB_G],       // 全局位：两个页都标记为全局时才是全局
        page_size : tlbidx_i[`PS],                                // 页大小
        vppn      : tlbehi_i[`VPPN],                              // 虚拟页号
        valid     : {tlbelo1_i[`TLB_V]  , tlbelo0_i[`TLB_V]},    // 有效位：{奇数页,偶数页}
        dirty     : {tlbelo1_i[`TLB_D]  , tlbelo0_i[`TLB_D]},    // 脏位：{奇数页,偶数页}
        mat       : {tlbelo1_i[`TLB_MAT], tlbelo0_i[`TLB_MAT]},  // 内存属性：{奇数页,偶数页}
        plv       : {tlbelo1_i[`TLB_PLV], tlbelo0_i[`TLB_PLV]},  // 特权级：{奇数页,偶数页}
        ppn       : {tlbelo1_i[`TLB_PPN], tlbelo0_i[`TLB_PPN]}   // 物理页号：{奇数页,偶数页}
    };
  end

  // 构造TLB读取请求(用于TLBRD指令)
  always_comb begin : proc_read_req
    // TLB读取请求
    tlb_read_req.valid = tlbrd_en_i;           // TLBRD指令使能时有效
    tlb_read_req.idx = tlbidx_i[`INDEX];       // 使用TLBIDX寄存器中的索引
  end

  // 构造TLB失效请求(用于INVTLB指令)
  always_comb begin : proc_inv_req
    // TLB失效请求
    tlb_inv_req.valid = invtlb_en_i;       // INVTLB指令使能时有效
    tlb_inv_req.asid = invtlb_asid_i;      // 使用指定的ASID
    tlb_inv_req.vppn = invtlb_vpn_i;       // 使用指定的VPN
    tlb_inv_req.op = invtlb_op_i;          // 使用指定的操作码
  end

  // 处理TLB读取响应(TLBRD指令)
  always_comb begin : proc_read_rsp
    // 从TLB读取响应中提取各字段
    r_vppn = tlb_read_rsp.tlb_entry_st.vppn;     // 虚拟页号
    r_asid = tlb_read_rsp.tlb_entry_st.asid;     // 地址空间ID
    r_g    = tlb_read_rsp.tlb_entry_st.glo;      // 全局标志
    r_ps   = tlb_read_rsp.tlb_entry_st.page_size; // 页大小
    r_e    = tlb_read_rsp.tlb_entry_st.exist;    // 条目有效标志

    // 偶数页(0)属性
    r_v0   = tlb_read_rsp.tlb_entry_st.valid[0]; // 有效位
    r_d0   = tlb_read_rsp.tlb_entry_st.dirty[0]; // 脏位
    r_mat0 = tlb_read_rsp.tlb_entry_st.mat[0];   // 内存属性
    r_plv0 = tlb_read_rsp.tlb_entry_st.plv[0];   // 特权级
    r_ppn0 = tlb_read_rsp.tlb_entry_st.ppn[0];   // 物理页号

    // 奇数页(1)属性
    r_v1   = tlb_read_rsp.tlb_entry_st.valid[1]; // 有效位
    r_d1   = tlb_read_rsp.tlb_entry_st.dirty[1]; // 脏位
    r_mat1 = tlb_read_rsp.tlb_entry_st.mat[1];   // 内存属性
    r_plv1 = tlb_read_rsp.tlb_entry_st.plv[1];   // 特权级
    r_ppn1 = tlb_read_rsp.tlb_entry_st.ppn[1];   // 物理页号

    // 构造输出到CSR的寄存器值
    tlbehi_o   = {r_vppn, 13'b0};                // TLBEHI寄存器：虚拟页号+低13位清零
    tlbelo0_o  = {4'b0, r_ppn0, 1'b0, r_g, r_mat0, r_plv0, r_d0, r_v0}; // TLBELO0寄存器：偶数页属性
    tlbelo1_o  = {4'b0, r_ppn1, 1'b0, r_g, r_mat1, r_plv1, r_d1, r_v1}; // TLBELO1寄存器：奇数页属性
    tlbidx_o   = {!r_e, 1'b0, r_ps, 24'b0};      // TLBIDX寄存器：!有效位+保留位+页大小+低24位清零(不写回索引)
    tlbasid_o  = r_asid;                         // TLBASID寄存器：地址空间ID
  end

  // 处理TLB查询响应和地址转换
  always_comb begin : proc_srch_rsp
    // 确定当前的地址转换模式
    pg_mode = !csr_da_i &&  csr_pg_i;    // 页式地址转换模式：DA=0 & PG=1
    da_mode =  csr_da_i && !csr_pg_i;    // 直接地址转换模式：DA=1 & PG=0

    // 处理指令和数据地址转换
    for (int i = 0; i < 2; i++) begin
      // 检查DMW0窗口是否使能：当前特权级匹配且虚拟地址高3位匹配VSEG
      dmw0_en[i] = ((csr_dmw0_i[`PLV0] && csr_plv_i == 2'd0) || 
                    (csr_dmw0_i[`PLV3] && csr_plv_i == 2'd3)) && 
                   (addr_trans_req_buffer[i].vaddr[31:29] == csr_dmw0_i[`VSEG]);
      
      // 检查DMW1窗口是否使能：当前特权级匹配且虚拟地址高3位匹配VSEG
      dmw1_en[i] = ((csr_dmw1_i[`PLV0] && csr_plv_i == 2'd0) || 
                    (csr_dmw1_i[`PLV3] && csr_plv_i == 2'd3)) && 
                   (addr_trans_req_buffer[i].vaddr[31:29] == csr_dmw1_i[`VSEG]);

      // 决定是否需要TLB地址转换：页式模式且不在DMW窗口内且不是直接CACOP操作
      addr_trans_en[i] = pg_mode & ~dmw0_en[i] & ~dmw1_en[i] & ~addr_trans_req_buffer[i].cacop_direct;

      // 设置地址转换响应
      addr_trans_rsp[i].valid = addr_trans_req_buffer[i].valid;  // 响应有效位与请求一致
      addr_trans_rsp[i].ready = '1;                              // 响应就绪

      // 计算物理地址：
      // 1. DMW0窗口映射：替换高3位为PSEG
      // 2. DMW1窗口映射：替换高3位为PSEG
      // 3. TLB转换：根据页大小选择物理页号和页内偏移
      // 4. 直通模式：虚拟地址等于物理地址
      addr_trans_rsp[i].paddr = (pg_mode && dmw0_en[i] && !addr_trans_req_buffer[i].cacop_direct) ? {csr_dmw0_i[`PSEG], addr_trans_req_buffer[i].vaddr[28:0]} : 
                                (pg_mode && dmw1_en[i] && !addr_trans_req_buffer[i].cacop_direct) ? {csr_dmw1_i[`PSEG], addr_trans_req_buffer[i].vaddr[28:0]} : 
                                 addr_trans_en[i] ? 
                                ((tlb_search_rsp[i].page_size == 6'd12) ? {tlb_search_rsp[i].ppn, addr_trans_req_buffer[i].vaddr[11:0]} :  // 4KB页(12位偏移)
                                                                          {tlb_search_rsp[i].ppn[`PROC_PALEN - 1:22], addr_trans_req_buffer[i].vaddr[21:0]}) :  // 4MB页(22位偏移)
                                 addr_trans_req_buffer[i].vaddr;  // 直通模式

      // 确定是否uncache访问
      if (i == 0) begin
        // 指令获取的uncache判断
        addr_trans_rsp[i].uncache = (da_mode && (csr_datf_i == 2'b0))                    ||  // 直接地址模式且DATF=0
                                    (dmw0_en[i] && (csr_dmw0_i[`DMW_MAT] == 2'b0))       ||  // DMW0窗口且MAT=0
                                    (dmw1_en[i] && (csr_dmw1_i[`DMW_MAT] == 2'b0))       ||  // DMW1窗口且MAT=0
                                    (addr_trans_en[i] && (tlb_search_rsp[i].mat == 2'b0));   // TLB转换且MAT=0
      end else begin
        // 数据访问的uncache判断
        addr_trans_rsp[i].uncache = (da_mode && (csr_datm_i == 2'b0))                    ||  // 直接地址模式且DATM=0
                                    (dmw0_en[i] && (csr_dmw0_i[`DMW_MAT] == 2'b0))       ||  // DMW0窗口且MAT=0
                                    (dmw1_en[i] && (csr_dmw1_i[`DMW_MAT] == 2'b0))       ||  // DMW1窗口且MAT=0
                                    (addr_trans_en[i] && (tlb_search_rsp[i].mat == 2'b0));   // TLB转换且MAT=0
      end
      
      // 注释掉的TLB属性传递
      // addr_trans_rsp[i].tlb_valid = tlb_search_rsp[i].valid;
      // addr_trans_rsp[i].tlb_dirty = tlb_search_rsp[i].dirty;
      // addr_trans_rsp[i].tlb_mat   = tlb_search_rsp[i].mat;
      // addr_trans_rsp[i].tlb_plv   = tlb_search_rsp[i].plv;

      // 初始化内存访问异常标志
      addr_trans_rsp[i].pif = '0;    // 指令页无效异常
      addr_trans_rsp[i].pil = '0;    // 加载页无效异常
      addr_trans_rsp[i].pis = '0;    // 存储页无效异常
      addr_trans_rsp[i].ppi = '0;    // 页特权等级异常
      addr_trans_rsp[i].pme = '0;    // 页修改异常
      addr_trans_rsp[i].tlbr = '0;   // TLB重填异常

      // 检查并设置内存访问异常
      if (addr_trans_en[i]) begin
        addr_trans_rsp[i].tlbr = ~tlb_search_rsp[i].found;    // TLB未命中时设置TLB重填异常
        
        if (!tlb_search_rsp[i].valid) begin
          // 页无效异常：根据访问类型设置不同的异常标志
          case (addr_trans_req_buffer[i].mem_type)
            MMU_FETCH : addr_trans_rsp[i].pif = '1;    // 取指异常
            MMU_LOAD  : addr_trans_rsp[i].pil = '1;    // 加载异常
            MMU_STORE : addr_trans_rsp[i].pis = '1;    // 存储异常
            default : /* default */;
          endcase
        end else if (csr_plv_i > tlb_search_rsp[i].plv) begin
          // 当前特权级低于页所需特权级，设置页特权等级异常
          addr_trans_rsp[i].ppi = '1;
        end else if (addr_trans_req_buffer[i].mem_type == MMU_STORE && tlb_search_rsp[i].dirty == 0) begin
          // 尝试写入但页未标记为脏，设置页修改异常
          addr_trans_rsp[i].pme = '1;
        end
      end
    end

    // TLBSRCH指令的输出
    tlbsrch_found_o = tlb_search_rsp[2].found;    // 是否找到匹配条目
    tlbsrch_idx_o = tlb_search_rsp[2].idx;        // 匹配条目的索引
  end

  // 实例化TLB模块用于指令和数据地址转换
  for (genvar i = 0; i < 2; i++) begin : gen_addr_trans_tlb
    // 用于ICache和DCache的地址转换TLB
    TranslationLookasideBuffer U_TranslationLookasideBuffer (
      .clk            (clk),
      .rst_n          (rst_n),
      .tlb_search_req (tlb_search_req[i]),    // 查询请求
      .tlb_search_rsp (tlb_search_rsp[i]),    // 查询响应
      .tlb_read_req   ('0),                   // 读请求禁用
      .tlb_read_rsp   (),                     // 读响应未使用
      .tlb_write_req  (tlb_write_req),        // 写请求(共享)
      .tlb_write_rsp  (tlb_write_rsp),        // 写响应(共享)
      .tlb_inv_req    (tlb_inv_req),          // 失效请求(共享)
      .tlb_inv_rsp    (tlb_inv_rsp)           // 失效响应(共享)
    );
  end

  // 实例化TLB模块用于TLBSRCH和TLBRD指令
  TranslationLookasideBuffer U_TranslationLookasideBuffer (
    .clk            (clk),
    .rst_n          (rst_n),
    .tlb_search_req (tlb_search_req[2]),    // TLBSRCH查询请求
    .tlb_search_rsp (tlb_search_rsp[2]),    // TLBSRCH查询响应
    .tlb_read_req   (tlb_read_req),         // TLBRD读请求
    .tlb_read_rsp   (tlb_read_rsp),         // TLBRD读响应
    .tlb_write_req  (tlb_write_req),        // 写请求(共享)
    .tlb_write_rsp  (tlb_write_rsp),        // 写响应(共享)
    .tlb_inv_req    (tlb_inv_req),          // 失效请求(共享)
    .tlb_inv_rsp    (tlb_inv_rsp)           // 失效响应(共享)
  );
  
endmodule : MemoryManagementUnit
