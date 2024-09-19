// -*- coding: utf-8 -*-
// @Time    : 2024/7/3 21:06
// @Author  : ${AUTHOR}
// @File    : Multiplier
// @Software: IntelliJ IDEA
// @Comment : 基4 booth 华莱士树 乘法器

package core.pipeline.intblock.fu.mdu.multiplier

import spinal.core._
import spinal.lib._
import spinal.lib.misc.pipeline._

import scala.language.postfixOps

class Multiplier(width: Int) extends Component {
  val io = new Bundle {
    val req = slave Stream new Bundle {
      val x = Bits(width bits)
      val y = Bits(width bits)
      val signed = Bool()
    }

    val resp = master Stream new Bundle {
      val result = Bits(width * 2 bits)
    }
  }

  assert(width >= 8, "Multiplier width must be greater than or equal to 8")

  // 根据signed信号对x，y进行位扩展，扩展后的位数保证为偶数
  private def bitExtend(input: Bits, signed: Bool, dataWidth: Int): Bits = {
    // Perform sign extension if signExtend is true, otherwise perform zero extension
    if (signed == True) {
      val signBit = input.msb
      B(signBit,(dataWidth - width) bits) ## input
    } else {
      B(0, (dataWidth - width) bits) ## input
    }
  }

  // 部分积数量
  private val prodNum = width / 2 + 1

  /* ================================================= build pipeline =============================================== */
  private val builder = new NodesBuilder()

  /* 扩展乘法器输入，并进行 booth4 计算 */
  private val boothNode = new builder.Node {
    arbitrateFrom(io.req)
    private val x = bitExtend(io.req.x, io.req.signed, width * 2)
    private val y = bitExtend(io.req.y, io.req.signed, if (width % 2 == 0) width + 2 else width + 1)
    // Booth4压缩
    private val booth4 = Array.fill(prodNum)(new Booth4(width * 2))
    for (i <- 0 until prodNum) {
      booth4(i).io.x := x |<< i * 2  // x需要左移i*2位
      booth4(i).io.y := (y ## B(0, 1 bits))(i * 2 + 2 downto i * 2)
    }

    // 用寄存器缓存乘法器的部分积并转置
    val PROD = Payload(Vec(Bits(prodNum bits), width * 2))

    for (i <- 0 until width * 2) {
      for (j <- 0 until prodNum) {
        PROD(i)(j) := booth4(j).io.res(i)
      }
    }
    // 缓存 booth 的 neg 输出
    val NEG = Payload(Bits(prodNum bits))
    NEG := booth4.map(_.io.neg.asBits).reduce(_ ## _)
  }

  /* Wallace树求部分积的和 */
  private val wallaceNode = new builder.Node {
    // Wallace树
    private val wallaceTree = Array.fill(width * 2)(new WallaceTree(prodNum))
    private val cinWidth = wallaceTree.head.io.cin.getWidth

    // 第一棵树特殊处理，input连接NEG，cin连接PROD[carryNum - 1:0]
    // 主要是因为boothNode.PROD(0)仅有最低为可能为1，其他位都是0，可以节省一些资源，不需单独计算neg的加法
    wallaceTree(0).io.input := boothNode.NEG
    wallaceTree(0).io.cin := boothNode.PROD(0)(cinWidth - 1 downto 0)

    // 其余树的input连接PROD，cin连接上一树的cout
    for (i <- 1 until width * 2) {
      wallaceTree(i).io.input := boothNode.PROD(i)
      wallaceTree(i).io.cin := wallaceTree(i - 1).io.cout
    }

    // 输出
    val SUM = Payload(Bits(width * 2 bits))
    val CARRY = Payload(Bits(width * 2 bits))

    SUM := wallaceTree.map(_.io.sum.asBits).reduce(_ ## _)
    CARRY := wallaceTree.map(_.io.carry.asBits).reduce(_ ## _)
  }

  /* 末级加法器 */
  private val addNode = new builder.Node {
    arbitrateTo(io.resp)
    io.resp.payload.result := (wallaceNode.SUM.asUInt + (wallaceNode.CARRY |<< 1).asUInt).asBits
  }

  builder.genStagedPipeline()
}


object Multiplier {
  def main(args: Array[String]): Unit = {
    SpinalConfig(
      defaultConfigForClockDomains = ClockDomainConfig(resetKind = SYNC, resetActiveLevel = LOW),
      targetDirectory = "output"
    ).generateVerilog(new Multiplier(32))
  }
}

