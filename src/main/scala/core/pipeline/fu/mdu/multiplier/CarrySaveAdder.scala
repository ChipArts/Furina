// -*- coding: utf-8 -*-
// @Time    : 2024/7/3 21:37
// @Author  : ${AUTHOR}
// @File    : CarrySaveAdder
// @Software: IntelliJ IDEA
// @Comment : 进位保存加法器

package core.pipeline.fu.mdu.multiplier

import spinal.core._

class CarrySaveAdder extends Component {
  val io = new Bundle{
    val a, b, c = in Bool()
    val sum, carry = out Bool()
  }

  io.sum := io.a ^ io.b ^ io.c
  io.carry := (io.a & io.b) | (io.b & io.c) | (io.a & io.c)

}
