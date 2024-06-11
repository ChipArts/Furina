// -*- coding: utf-8 -*-
// @Time    : 2024/5/18 18:23
// @Author  : ${AUTHOR}
// @File    : FetchResp
// @Software: IntelliJ IDEA 
// @Comment :

package furina.cache.intf

import spinal.core._
import spinal.lib._
import furina.Config._
import furina.excp._

case class FetchResp() extends Bundle with IMasterSlave {
  val inst = Bits(VALEN bits)
  val excp = Exception()

  override def asMaster(): Unit = {
    out(inst, excp)
  }

  override type RefOwnerType = this.type
}
