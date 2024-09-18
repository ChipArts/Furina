// -*- coding: utf-8 -*-
// @Time    : 2024/9/18 19:35
// @Author  : ${AUTHOR}
// @File    : Platform
// @Software: IntelliJ IDEA 
// @Comment :

package core.config

object Platform extends Enumeration {
  val SIM_VERILATOR = Value
  val FPGA_XILINX = Value
  val ASIC_SMIC180 = Value
}
