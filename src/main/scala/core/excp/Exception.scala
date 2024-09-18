// -*- coding: utf-8 -*-
// @Time    : 2024/5/18 18:25
// @Author  : ${AUTHOR}
// @File    : Exception
// @Software: IntelliJ IDEA
// @Comment :

package core.excp

import spinal.core._

case class Exception() extends Bundle {
  val excp = Bool()
  val excpCode = ExcpCode()
  val excpSubCode = ExcpSubCode()
}
