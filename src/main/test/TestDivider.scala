// -*- coding: utf-8 -*-
// @Time    : 2024/9/27 19:56
// @Author  : ${AUTHOR}
// @File    : TestDivider
// @Software: IntelliJ IDEA 
// @Comment :

import spinal.core._
import core.pipeline.intblock.fu.mdu.Divider

object TestDivider {
  def main(args: Array[String]): Unit = {
    SpinalConfig(
      mode = Verilog,
      targetDirectory = "./test_output"
    ).generate(new Divider(32))
  }
}
