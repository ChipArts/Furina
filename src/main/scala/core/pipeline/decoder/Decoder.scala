// -*- coding: utf-8 -*-
// @Time    : 2024/8/30 21:05
// @Author  : ${AUTHOR}
// @File    : Decoder
// @Software: IntelliJ IDEA
// @Comment :

package core.pipeline.decoder

import spinal.core._

class Decoder extends Component {
  val io = new Bundle {
    val inst = in Bits(32 bits)
  }
}
