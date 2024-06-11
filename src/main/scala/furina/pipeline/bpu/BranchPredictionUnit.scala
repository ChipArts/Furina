// -*- coding: utf-8 -*-
// @Time    : 2024/5/18 16:16
// @Author  : ${AUTHOR}
// @File    : BranchPredictionUnit
// @Software: IntelliJ IDEA 
// @Comment :

package furina.pipeline.bpu

import spinal.core._
import furina.Config._

import scala.language.postfixOps
class BranchPredictionUnit extends Component {
  val io = new Bundle {
    val valid: Bool = out Bool()
    val ready: Bool = in Bool()
    val redirect: Bool = in Bool()
    val target: UInt = in UInt(VALEN bits)
    val pc: UInt = out UInt(VALEN bits)
    val npc: UInt = out UInt(VALEN bits)
  }

  private val NPC_OFS = log2Up(FETCH_WIDTH) + 2

  // 计算npc
  when (io.redirect) {
    io.npc := io.target
  }.otherwise {
    io.npc := ((io.pc(31 downto NPC_OFS) + 1) ## U(0, NPC_OFS bits))
  }

  // pc转为reg类型
  io.pc.setAsReg() init(0x1c000000 - 0x00000004 * FETCH_WIDTH)
  when (io.ready) {
    io.pc := io.npc
  }

  // valid always true
  io.valid := true

}
