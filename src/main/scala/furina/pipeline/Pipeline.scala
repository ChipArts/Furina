// -*- coding: utf-8 -*-
// @Time    : 2024/5/18 16:14
// @Author  : ${AUTHOR}
// @File    : Pipeline
// @Software: IntelliJ IDEA 
// @Comment :

package furina.pipeline

import spinal.core._
import spinal.lib._
import spinal.lib.bus.tilelink
import furina.Config
import furina.cache._
import furina.pipeline.bpu._

class Pipeline extends Component {
  val io = new Bundle {
    val ibus = master(tilelink.Bus(Config.TL_PARAM))
    val dbus = master(tilelink.Bus(Config.TL_PARAM))
  }

  val bpu = new BranchPredictionUnit()
  val icache = new ICache()
  val dcache = new DCache()
}
