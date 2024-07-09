// -*- coding: utf-8 -*-
// @Time    : 2024/7/3 21:13
// @Author  : ${AUTHOR}
// @File    : Booth4
// @Software: IntelliJ IDEA
// @Comment : 基4 booth 算法

package furina.pipeline.fu.mdu.multiplier

import spinal.core._

class Booth4(width: Int) extends Component {
  val io = new Bundle{
    val x = in Bits(width bits)
    val y = in Bits(3 bits)
    val res = out Bits(width bits)
    val neg = out Bool()
  }

  // prepare for select signal
  private val shift0 = io.y(1) ^ io.y(0)
  private val shift1 = (io.y(2) && !io.y(1)) && !io.y(0) || !(io.y(2) && io.y(1) && io.y(0))
  private val neg = io.y(2) && !(io.y(1) && io.y(0))

  // generate booth4 result
  when(shift0){
    io.res := io.x
  } elsewhen shift1 {
    io.res := io.x << 1
  }
  when(neg){
    // io.res equal ~io.res plus 1, but we plus 1 later
    io.res := ~io.res
  }

  io.neg := neg

}
