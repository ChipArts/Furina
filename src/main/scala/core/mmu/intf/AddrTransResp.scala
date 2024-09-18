// -*- coding: utf-8 -*-
// @Time    : 2024/5/20 15:02
// @Author  : ${AUTHOR}
// @File    : AddrTransResp
// @Software: IntelliJ IDEA 
// @Comment :

package core.mmu.intf

import spinal.core._
import spinal.lib._
import core.Config._

case class AddrTransResp() extends Bundle with IMasterSlave {
  val paddr = UInt(PALEN bits)
  val uncache = Bool()
  val tlbr = Bool()
  val pif = Bool()
  val pil = Bool()
  val pis = Bool()
  val ppi = Bool()
  val pme = Bool()

  override def asMaster(): Unit = {
    out(paddr, uncache, tlbr, pif, pil, pis, ppi, pme)
  }

  override type RefOwnerType = this.type
}
