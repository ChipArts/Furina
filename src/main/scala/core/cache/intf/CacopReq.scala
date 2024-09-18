// -*- coding: utf-8 -*-
// @Time    : 2024/5/19 19:40
// @Author  : ${AUTHOR}
// @File    : CacopReq
// @Software: IntelliJ IDEA 
// @Comment :

package core.cache.intf

import spinal.core._
import spinal.lib._
import core.Config._
case class CacopReq() extends Bundle with IMasterSlave {
  val vaddr = UInt(VALEN bits)
  val robIdx = UInt(log2Up(ROB_DEPTH) bits)
  val opcode = UInt(2 bits)
  override def asMaster(): Unit = ???

  override type RefOwnerType = this.type
}
