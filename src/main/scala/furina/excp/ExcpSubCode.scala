// -*- coding: utf-8 -*-
// @Time    : 2024/5/19 19:21
// @Author  : ${AUTHOR}
// @File    : ExcpSubCode
// @Software: IntelliJ IDEA
// @Comment :

package furina.excp

import spinal.core._

object ExcpSubCode extends SpinalEnum {
  val ADEF, ADEM = newElement()
  defaultEncoding = SpinalEnumEncoding("staticEncoding")(
    ADEF -> 0x00,
    ADEM -> 0x01
  )
}