// -*- coding: utf-8 -*-
// @Time    : 2024/5/20 14:56
// @Author  : ${AUTHOR}
// @File    : AddrTransReq
// @Software: IntelliJ IDEA 
// @Comment :

package furina.mmu.intf

import furina.Config._
import furina.mmu.MmuMemType
import spinal.core._
import spinal.lib._

case class AddrTransReq() extends Bundle with IMasterSlave {
  val vaddr = UInt(VALEN bits)
  val memType = MmuMemType()
  override def asMaster(): Unit = {
    out(vaddr, memType)
  }

  override type RefOwnerType = this.type
}
