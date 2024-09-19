// -*- coding: utf-8 -*-
// @Time    : 2024/9/19 19:35
// @Author  : ${AUTHOR}
// @File    : TestArithmeticLogicUnit
// @Software: IntelliJ IDEA 
// @Comment :

import spinal.core._
import core.pipeline.intblock.fu.ArithmeticLogicUnit

object TestArithmeticLogicUnit {
  def main(args: Array[String]): Unit = {
    SpinalConfig(targetDirectory = "./test_output").generateVerilog(new ArithmeticLogicUnit)
  }
}
