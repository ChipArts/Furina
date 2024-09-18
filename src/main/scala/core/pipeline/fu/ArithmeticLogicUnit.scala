// -*- coding: utf-8 -*-
// @Time    : 2024/8/30 21:03
// @Author  : ${AUTHOR}
// @File    : ArithmeticLogicUnit
// @Software: IntelliJ IDEA 
// @Comment :

package core.pipeline.fu

import spinal.core._
import spinal.lib._

class ArithmeticLogicUnit extends Component {
  val io = new Bundle {
    val req = slave Stream new Bundle {
      val x = UInt(32 bits)
      val y = UInt(32 bits)
      val op = UInt(4 bits)
    }

    val resp = master Stream new Bundle {
      val result = UInt(32 bits)
    }
  }

  val result = UInt(32 bits)

}
