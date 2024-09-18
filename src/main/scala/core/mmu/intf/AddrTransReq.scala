// -*- coding: utf-8 -*-
// @Time    : 2024/5/20 14:56
// @Author  : ${AUTHOR}
// @File    : AddrTransReq
// @Software: IntelliJ IDEA 
// @Comment :

package core.mmu.intf

import core.Config._
import core.mmu.MmuMemType
import spinal.core._
import spinal.lib._

case class AddrTransReq() extends Bundle with IMasterSlave {
  val vaddr = Bits(VALEN bits)
  val memType = MmuMemType()
  override def asMaster(): Unit = {
    out(vaddr, memType)
  }

  override type RefOwnerType = this.type
}
