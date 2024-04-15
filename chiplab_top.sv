// ==============================================================================
// Copyright (c) 2014-2024 All rights reserved
// ==============================================================================
// Author  : 2506806016@qq.com
// File    : chiplab_top.sv
// Create  : 2024-04-09 17:38:34
// Revise  : 2024-04-09 17:43:25
// Editor  : suyang
// Version : 0.1
// Description :
//    ...
//    ...
// Parameter   :
//    ...
//    ...
// IO Port     :
//    ...
//    ...
// Modification History:
//   Date   |   Author   |   Version   |   Change Description
// -----------------------------------------------------------------------------
//    ...   |            |     0.1     |    Original Version
// ==============================================================================

module core_top(
    input           aclk,
    input           aresetn,
    input    [ 7:0] intrpt, 
    //AXI interface 
    //read reqest
    output   [ 3:0] arid,
    output   [31:0] araddr,
    output   [ 7:0] arlen,
    output   [ 2:0] arsize,
    output   [ 1:0] arburst,
    output   [ 1:0] arlock,
    output   [ 3:0] arcache,
    output   [ 2:0] arprot,
    output          arvalid,
    input           arready,
    //read back
    input    [ 3:0] rid,
    input    [31:0] rdata,
    input    [ 1:0] rresp,
    input           rlast,
    input           rvalid,
    output          rready,
    //write request
    output   [ 3:0] awid,
    output   [31:0] awaddr,
    output   [ 7:0] awlen,
    output   [ 2:0] awsize,
    output   [ 1:0] awburst,
    output   [ 1:0] awlock,
    output   [ 3:0] awcache,
    output   [ 2:0] awprot,
    output          awvalid,
    input           awready,
    //write data
    output   [ 3:0] wid,
    output   [31:0] wdata,
    output   [ 3:0] wstrb,
    output          wlast,
    output          wvalid,
    input           wready,
    //write back
    input    [ 3:0] bid,
    input    [ 1:0] bresp,
    input           bvalid,
    output          bready,
    //debug info
    output [31:0] debug0_wb_pc,
    output [ 3:0] debug0_wb_rf_wen,
    output [ 4:0] debug0_wb_rf_wnum,
    output [31:0] debug0_wb_rf_wdata,
    output [31:0] debug1_wb_pc,
    output [ 3:0] debug1_wb_rf_wen,
    output [ 4:0] debug1_wb_rf_wnum,
    output [31:0] debug1_wb_rf_wdata
);


	AXI4 #(
	    .AXI_ADDR_WIDTH(32),
	    .AXI_DATA_WIDTH(32),
	    .AXI_ID_WIDTH  (4),
	    .AXI_USER_WIDTH(1)
  	) axi4();

	Furina inst_Furina (.clk(clk), .a_rst_n(aresetn), .interrupt(intrpt), .axi4_mst(axi4));

    assign arid    = axi4.arid;
    assign araddr  = axi4.araddr;
    assign arlen   = axi4.arlen;
    assign arsize  = axi4.arsize;
    assign arburst = axi4.arburst;
    assign arlock  = axi4.arlock;
    assign arcache = axi4.arcache;
    assign arprot  = axi4.arprot;
    assign axi4.arvalid = arvalid;

    assign axi4.r_id = rid;
    assign axi4.r_data = rdata;
    assign axi4.r_resp = rresp;
    assign axi4.r_last = rlast;
    assign axi4.r_valid = rvalid;
    assign rready = axi4.r_ready;

    assign awid    = axi4.awid;
    assign awaddr  = axi4.awaddr;
    assign awlen   = axi4.awlen;
    assign awsize  = axi4.awsize;
    assign awburst = axi4.awburst;
    assign awlock  = axi4.awlock;
    assign awcache = axi4.awcache;
    assign awprot  = axi4.awprot;
    assign awvalid = axi4.awvalid;
    assign axi4.aw_ready = awready;

    assign wid    = axi4.wid;
    assign wdata  = axi4.wdata;
    assign wstrb  = axi4.wstrb;
    assign wlast  = axi4.wlast;
    assign wvalid = axi4.wvalid;
    assign axi4.w_ready = wready;

    assign axi4.b_id = bid;
    assign axi4.b_resp = bresp;
    assign axi4.b_valid = bvalid;
    assign bready = axi4.b_ready;

    assign debug0_wb_pc = '0;
    assign debug0_wb_rf_wen = '0;
    assign debug0_wb_rf_wnum = '0;
    assign debug0_wb_rf_wdata = '0;
    assign debug1_wb_pc = '0;
    assign debug1_wb_rf_wen = '0;
    assign debug1_wb_rf_wnum = '0;
    assign debug1_wb_rf_wdata = '0;
endmodule