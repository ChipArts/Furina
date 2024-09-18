// -*- coding: utf-8 -*-
// @Time    : 2024/5/18 17:42
// @Author  : ${AUTHOR}
// @File    : ICache
// @Software: IntelliJ IDEA 
// @Comment :

package core.cache

import core.Config
import spinal.core._
import spinal.lib._
import spinal.lib.fsm._
import core.Config._
import core.cache.intf._
import core.mmu._
import core.mmu.intf._
import spinal.lib.bus.tilelink
class ICache extends Component {
  val io = new Bundle {
    val fetchReq = slave Stream FetchReq()
    val fetchResp = master Stream FetchResp()
    val cacopReq = slave Stream CacopReq()
    val cacopResp = master Stream CacopResp()
    val addrTransReq = master Stream AddrTransReq()
    val addrTransResp = slave Stream AddrTransResp()
    val bus = master(tilelink.Bus(Config.TL_PARAM))
  }

  // 定义ready信号
  private val ready_s0, ready_s1 = Bool()

  /* stage 0 */
  // 与Master对接
  ready_s0 := io.addrTransReq.ready && ready_s1
  io.fetchReq.ready := ready_s0
  io.cacopReq.ready := ready_s0

  // 发起地址翻译请求
  io.addrTransReq.valid := io.fetchReq.valid | io.cacopReq.valid
  io.addrTransReq.payload.vaddr := io.fetchReq.payload.vaddr
  io.addrTransReq.payload.memType := io.cacopReq.valid ? MmuMemType.LOAD | MmuMemType.FETCH  // cache操作为LOAD类型


  /* stage 1 */
  // 缓存req信息
  private val fetchValid_s1 = RegNextWhen(io.fetchReq.valid, io.fetchReq.valid && ready_s1)
  private val fetchPayload_s1 = RegNextWhen(io.fetchReq.payload, io.fetchReq.valid && ready_s1)
  private val cacopValid_s1 = RegNextWhen(io.cacopReq.valid, io.cacopReq.valid && ready_s1)
  private val cacopPayload_s1 = RegNextWhen(io.cacopReq.payload, io.cacopReq.valid && ready_s1)

  // signal def
  private val miss = Bool()
  private val uncacheHit = Reg(Bool()) init False  // deal with uncache fetch

  // cache状态机
  private val fsm = new StateMachine {
    val IDLE = new State with EntryPoint
    val MISS = new State
    val REFILL = new State

    IDLE whenIsActive {
      when(fetchValid_s1 && (miss || io.addrTransResp.uncache) && !uncacheHit) {
        goto(MISS)
      }
    }

    MISS whenIsActive {
      when(io.bus.a.ready) {
        goto(REFILL)
      }
    }

    REFILL whenIsActive {
      when(io.bus.d.valid) {
        goto(IDLE)
      }
    }
  }


  // stage 1 ready信号
  when (fsm.isActive(fsm.IDLE)) {
    when(cacopValid_s1) {
      ready_s1 := io.cacopResp.ready
    }.elsewhen(fetchValid_s1) {
      ready_s1 := io.cacopResp.ready && !miss
    }.otherwise {
      ready_s1 := True
    }
  }.otherwise {
    ready_s1 := False
  }

  // 接收地址翻译结果
  io.addrTransResp.ready := ready_s1

  // REFILL之后将uncacheHit置高 当然需要是uncache fetch
  when(fsm.isActive(fsm.REFILL) && io.bus.d.valid) {
    uncacheHit := io.addrTransResp.uncache
  }.elsewhen(ready_s1) {
    uncacheHit := False
  }



  /* Memory */
  val dataRam = Mem(Bits(32 bits), ICACHE_SIZE / ICACHE_WAY_NUM)






}
