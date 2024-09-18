// -*- coding: utf-8 -*-
// @Time    : 2024/7/3 21:13
// @Author  : ${AUTHOR}
// @File    : Booth4
// @Software: IntelliJ IDEA
// @Comment : 基4 booth 算法

package core.pipeline.fu.mdu.multiplier

import spinal.core._

import scala.language.postfixOps

class Booth4(width: Int) extends Component {
  val io = new Bundle{
    val x = in Bits(width bits)
    val y = in Bits(3 bits)
    val res = out Bits(width bits)
    val neg = out Bool()
  }

  private val shift1 = (io.y(2) && !io.y(1)) && !io.y(0) || !(io.y(2) && io.y(1) && io.y(0))
  private val neg = io.y(2) && !(io.y(1) && io.y(0))

  // generate booth4 result
  private val shiftRes = shift1 ? (io.x |<< 1) | io.x

  io.res := neg ? ~shiftRes | shiftRes

  io.neg := neg
}
