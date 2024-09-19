// -*- coding: utf-8 -*-
// @Time    : 2024/9/19 19:06
// @Author  : ${AUTHOR}
// @File    : AluSignal
// @Software: IntelliJ IDEA 
// @Comment :

package core.pipeline.decoder.signals

import spinal.core._

object AluSignal extends SpinalEnum {
  /*
   * ADD: Addition
   * SUB: Subtraction
   * SLT: Set on Less Than
   * SLTU: Set on Less Than Unsigned
   * AND: Bitwise AND
   * OR: Bitwise OR
   * XOR: Bitwise XOR
   * SLL: Shift Left Logical
   * SRL: Shift Right Logical
   * SRA: Shift Right Arithmetic
   * LU: Load Upper
   */
  val ADD, SUB, SLT, SLTU, AND, OR, XOR, SLL, SRL, SRA, LU12 = newElement()
}
