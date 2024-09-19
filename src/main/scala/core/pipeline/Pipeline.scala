// -*- coding: utf-8 -*-
// @Time    : 2024/5/18 16:14
// @Author  : ${AUTHOR}
// @File    : Pipeline
// @Software: IntelliJ IDEA 
// @Comment :

package core.pipeline

import spinal.core._
import spinal.lib._
import spinal.lib.bus.tilelink
import core.Config
import core.cache._
import core.pipeline.bpu._

class Pipeline extends Component {
  val io = new Bundle {
    val ibus = master(tilelink.Bus(Config.TL_PARAM))
    val dbus = master(tilelink.Bus(Config.TL_PARAM))
  }

  val bpu = new BranchPredictionUnit()
  val icache = new InstCache()
  val dcache = new DataCache()
}
