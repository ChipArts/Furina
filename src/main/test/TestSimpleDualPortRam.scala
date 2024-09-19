// -*- coding: utf-8 -*-
// @Time    : 2024/9/19 16:17
// @Author  : ${AUTHOR}
// @File    : TestSimpleDualPortRam
// @Software: IntelliJ IDEA 
// @Comment :

import spinal.core._
import core.memory.SimpleDualPortRam

object TestSimpleDualPortRam {
  def main(args: Array[String]): Unit = {
    SpinalConfig(
      targetDirectory = "./test_output/" // 指定Verilog输出目录
    ).generateVerilog(new SimpleDualPortRam(
      dataWidth = 32,
      dataDepth = 1024,
      byteWidth = 8,
      readUnderWritePolicy = readFirst
    )).printPruned()
  }
}
