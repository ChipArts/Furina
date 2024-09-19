// -*- coding: utf-8 -*-
// @Time    : 2024/9/19 18:34
// @Author  : ${AUTHOR}
// @File    : TestTrueDualPortRam
// @Software: IntelliJ IDEA 
// @Comment :

import core.memory.TrueDualPortRam
import spinal.core._

object TestTrueDualPortRam {
  def main(args: Array[String]): Unit = {
    SpinalConfig(
      targetDirectory = "./test_output/" // 指定Verilog输出目录
    ).generateVerilog(new TrueDualPortRam(
      dataWidth = 32,
      dataDepth = 1024,
      byteWidth = 8,
      readUnderWritePolicy = readFirst
    )).printPruned()
  }
}
