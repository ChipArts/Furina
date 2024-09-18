// -*- coding: utf-8 -*-
// @Time    : 2024/5/19 19:46
// @Author  : ${AUTHOR}
// @File    : CacopResp
// @Software: IntelliJ IDEA 
// @Comment :

package core.cache.intf

import spinal.core._
import spinal.lib._
import core.Config._
import core.excp._
case class CacopResp() extends Bundle with IMasterSlave {
  val excp = Exception()
  val robIdx = UInt(log2Up(ROB_DEPTH) bits)
  val vaddr = UInt(VALEN bits)  // for excp error vaddr
  override def asMaster(): Unit = {
    out(excp, robIdx, vaddr)
  }

  override type RefOwnerType = this.type
}
