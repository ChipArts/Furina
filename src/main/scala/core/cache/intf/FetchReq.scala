// -*- coding: utf-8 -*-
// @Time    : 2024/5/19 19:25
// @Author  : ${AUTHOR}
// @File    : FetchReq
// @Software: IntelliJ IDEA 
// @Comment :

package core.cache.intf

import spinal.core._
import spinal.lib._
import core.Config._
import core.excp._

case class FetchReq() extends Bundle with IMasterSlave {
  val vaddr = Bits(VALEN bits)
  val excp = Exception()

  override def asMaster(): Unit = {
    out(vaddr, excp)
  }

  override type RefOwnerType = this.type
}

