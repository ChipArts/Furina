// -*- coding: utf-8 -*-
// @Time    : 2024/5/20 14:55
// @Author  : ${AUTHOR}
// @File    : MemoryManagementUnit
// @Software: IntelliJ IDEA 
// @Comment :


package furina.mmu

import spinal.core._
import spinal.lib._
import furina.Config._
import furina.mmu.intf._

import scala.language.postfixOps

class MemoryManagementUnit(transWidth: Int) extends Component {
  val io = new Bundle {
    val csr = in(new Bundle {
      val crmd = Bits(32 bits)
      val asid = Bits(32 bits)
      val dmw  = Vec(Bits(GRLEN bits), 4)
      val tlbidx = Bits(32 bits)
      val tlbhi = Bits(GRLEN bits)
      val tlblo0 = Bits(GRLEN bits)
      val tlblo1 = Bits(GRLEN bits)
      val estat = Bits(32 bits)
    })
    val addrTransReq = Vec(slave(AddrTransReq()), transWidth)
    val addrTransResp = Vec(master(AddrTransResp()), transWidth)
  }



}
