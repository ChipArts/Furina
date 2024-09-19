// -*- coding: utf-8 -*-
// @Time    : 2024/8/30 21:03
// @Author  : ${AUTHOR}
// @File    : ArithmeticLogicUnit
// @Software: IntelliJ IDEA
// @Comment :

package core.pipeline.intblock.fu

import core.pipeline.decoder.signals.AluSignal
import core.pipeline.decoder.signals.AluSignal._
import spinal.core._
import core.Config.GRLEN
import core.pipeline.decoder.signals

import scala.language.postfixOps

class ArithmeticLogicUnit extends Component {
  val io = new Bundle {
    val x = in UInt(GRLEN bits)
    val y = in UInt(GRLEN bits)
    val op = in(AluSignal())
    val result = out UInt(GRLEN bits)
  }

  private val x = UInt(GRLEN bits)
  private val y = UInt(GRLEN bits)

  x := io.x
  y := io.y

  switch(io.op) {
    is(ADD) { io.result := x + y }
    is(SUB) { io.result := x - y }
    is(SLT) { io.result := (x.asSInt < y.asSInt).asUInt.resize(GRLEN) }
    is(SLTU) { io.result := (x < y).asUInt.resize(GRLEN) }
    is(AND) { io.result := x & y }
    is(OR) { io.result := x | y }
    is(XOR) { io.result := x ^ y }
    is(SLL) { io.result := x |<< y(log2Up(GRLEN) - 1 downto 0) }
    is(SRL) { io.result := x |>> y(log2Up(GRLEN) - 1 downto 0) }
    is(SRA) { io.result := x >> y(log2Up(GRLEN) - 1 downto 0) }
    is(LU12) { io.result := (x(GRLEN - 13 downto 0) ## B(0, 12 bits)).asUInt }
  }

}
