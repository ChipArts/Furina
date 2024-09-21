// -*- coding: utf-8 -*-
// @Time    : 2024/9/21 17:23
// @Author  : ${AUTHOR}
// @File    : TestMultiplier
// @Software: IntelliJ IDEA 
// @Comment :

import spinal.core._
import core.pipeline.intblock.fu.mdu.multiplier.Multiplier

object TestMultiplier {
  def main(args: Array[String]): Unit = {
    SpinalConfig(
      targetDirectory = "test_output"
    ).generateVerilog(new Multiplier(32)).printPruned()
  }
}
