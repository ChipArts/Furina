// -*- coding: utf-8 -*-
// @Time    : 2024/5/19 19:20
// @Author  : ${AUTHOR}
// @File    : ExcpCode
// @Software: IntelliJ IDEA
// @Comment :

package furina.excp

import spinal.core._

object ExcpCode extends SpinalEnum {
  val INT, PIL, PIS, PIF, PME, PPI, ADE, ALE, SYS, BRK, INE, IPE, FPD, TLBR = newElement()
  defaultEncoding = SpinalEnumEncoding("staticEncoding")(
    INT -> 0x00,
    PIL -> 0x01,
    PIS -> 0x02,
    PIF -> 0x03,
    PME -> 0x04,
    PPI -> 0x07,
    ADE -> 0x08,
    ALE -> 0x09,
    SYS -> 0x0B,
    BRK -> 0x0C,
    INE -> 0x0D,
    IPE -> 0x0E,
    FPD -> 0x0F,
    TLBR -> 0x3F
  )
}

