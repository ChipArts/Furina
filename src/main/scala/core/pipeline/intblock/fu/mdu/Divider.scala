// -*- coding: utf-8 -*-
// @Time    : 2024/9/25 20:05
// @Author  : ${AUTHOR}
// @File    : Divider
// @Software: IntelliJ IDEA
// @Comment :

package core.pipeline.intblock.fu.mdu

import spinal.core._
import spinal.lib._
import spinal.lib.fsm._

import scala.language.postfixOps

class Divider(width: Int) extends Component {
  val io = new Bundle {
    val req = slave Stream new Bundle {
      val signed = Bool()
      val dividend = UInt(width bits)
      val divisor = UInt(width bits)
    }

    val resp = master Stream new Bundle {
      val quotient = UInt(width bits)
      val remainder = UInt(width bits)
    }
  }

  // 确保width是2的幂
  assert((width & (width - 1)) == 0, "Divider width must be power of 2")
  // 确保width大于等于2
  assert(width >= 2, "Divider width must be greater than or equal to 2")

  /*======= deal with operands' sign =======*/
  val dividendAbs = UInt(width bits)
  val divisorAbs = UInt(width bits)
  val quotientOpposite = Reg(Bool()) init False
  val remainderOpposite = Reg(Bool()) init False
  /* e.g.
    dividend   divisor   quotient   remainder
     5  /  3  =  1 ... 2
     5  / -3  = -1 ... 2
    -5  /  3  = -1 ...-2
    -5  / -3  =  1 ...-2
  */
  when (io.req.valid && io.req.ready) {
    quotientOpposite := (io.req.dividend.msb ^ io.req.divisor.msb) & io.req.signed
    remainderOpposite := io.req.dividend.msb & io.req.signed
  }
  // change to abs() form, change back at the end
  dividendAbs := (io.req.signed & io.req.dividend.msb) ? (~io.req.dividend + 1) | io.req.dividend
  divisorAbs := (io.req.signed & io.req.divisor.msb) ? (~io.req.divisor + 1) | io.req.divisor

  /*======= fsm's state of divider =======*/
  private val fsm = new StateMachine {
    val idle: State = new State with EntryPoint {
      whenIsActive {
        when(io.req.valid) {
          goto(busy)
        }
      }
    }

    val busy: State = new State {
      whenIsActive {
        when(~timer(0) && io.resp.ready) {
          goto(idle)
        }
      }
    }
  }

  /*======= divider's calculation =======*/
  val timer = Reg(UInt(width bits)) init 0
  val dividendPrefix = UInt(width * 2 + 3 bits)
  val divisorPrefix = UInt(width * 2 + 3 bits)
  // 位宽加3是为了防止 部分商 计算过程中产生数据溢出
  val dividendTemp = Reg(UInt(width * 2 + 3 bits)) init 0
  val divisorTemp = Vec(Reg(UInt(width * 2 + 3 bits)) init 0, 3)
  val particlQuotient = Vec(Reg(UInt(width * 2 + 3 bits)) init 0, 3)

  dividendPrefix := (U(0, 3 bits) ## U(0, width bits) ## dividendAbs).asUInt
  divisorPrefix :=  (U(0, 3 bits) ## divisorAbs ## U(0, width bits)).asUInt

  private val bitwiseSelect = Bits(log2Up(width) - 1 bits)
  bitwiseSelect.msb := timer(0)
  for (i <- 0 until log2Up(width) - 2) {
    // 从width / 2开始尝试能够进行的最大位移位宽，每次折半，例如width=32时，shift=16,8,4
    val shift = 1 << (log2Up(width) - 1 - i)
    // temp位宽 - 期望的位移位宽 - 数据位宽 → width * 2 - 1 - shift - width
    val base = width - 1 - shift
    // 判断当前位移位宽是否满足约束条件
    bitwiseSelect(i) := timer(shift - 1) & (dividendTemp(base + width - 1 downto base) < divisorTemp(0)(width * 2 - 1 downto width))
  }

  private val nextDividendTemp = MuxOH(
    oneHot = bitwiseSelect,
    inputs = (for (i <- 0 until log2Up(width) - 2) yield {
      val shift = 2 << (log2Up(width) - 1 - i)
      dividendTemp |<< shift
    }) :+ {
      val nextDividendTemp = UInt(width * 2 + 3 bits)
      when(!particlQuotient(2).msb) {
        nextDividendTemp := particlQuotient(2) + 3
      } elsewhen !particlQuotient(1).msb {
        nextDividendTemp := particlQuotient(1) + 2
      } elsewhen !particlQuotient(0).msb {
        nextDividendTemp := particlQuotient(0) + 1
      } otherwise {
        nextDividendTemp := dividendTemp |<< 2
      }
      nextDividendTemp
    }
  )

  private val nextTimer = MuxOH(
    oneHot = bitwiseSelect,
    inputs = for (i <- 0 until log2Up(width) - 1) yield {
      val shift = 1 << (log2Up(width) - 1 - i)
      timer |>> shift
    }
  )

  when (io.req.valid && io.resp.ready) {
    timer := U(width bits, default -> true)  // set all bits to 1
    dividendTemp := dividendPrefix
    divisorTemp(0) := divisorPrefix
    divisorTemp(1) := divisorPrefix |<< 1
    divisorTemp(2) := divisorPrefix + (divisorPrefix |<< 1)
  } elsewhen bitwiseSelect.orR {
    timer := nextTimer
    dividendTemp := nextDividendTemp
  }

  // 计算不同商下的部分商，基4的情况下可以商（0，1，2，3），由于商0不需要计算，这里只计算1，2，3
  for (i <- 0 until 3) {
    particlQuotient(i) := (dividendTemp |<< 2) - divisorTemp(i)
  }

  /* handshake and output */
  io.req.ready := fsm.isActive(fsm.idle)
  io.resp.valid := fsm.isActive(fsm.busy) & ~timer(0)
  io.resp.quotient := quotientOpposite ? (~dividendTemp(width - 1 downto 0) + 1) | dividendTemp(width - 1 downto 0)
  io.resp.remainder := remainderOpposite ? (~dividendTemp(width * 2 - 1 downto width) + 1) | dividendTemp(width * 2 - 1 downto width)
}
