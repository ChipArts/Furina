// -*- coding: utf-8 -*-
// @Time    : 2024/5/18 12:27
// @Author  : ${AUTHOR}
// @File    : furina.Config
// @Software: IntelliJ IDEA 
// @Comment :

package furina

import spinal.core._
import spinal.lib.bus.tilelink

import scala.language.postfixOps
object Config {
  val CORE_NUM = 1  // can not change now !!!

  val USB_BPU = false

  val VALEN = 32  // Virtual Address Length
  val PALEN = 32  // Physical Address Length
  val GRLEN = 32  // General Register Length

  val FETCH_WIDTH = 2

  val DCACHE_SIZE = 8 KiB
  val DCACHE_WAY_NUM = 2
  val DCACHE_BLK_SIZE = 16 Bytes



  val ICACHE_SIZE = 8 KiB
  val ICACHE_WAY_NUM = 2
  val ICACHE_BLK_SIZE = 16 Bytes

  val ROB_DEPTH = 64

  val TL_PARAM = tilelink.BusParameter.simple(
    addressWidth = 32,
    dataWidth    = 64,
    sizeBytes    = 64,
    sourceWidth  = 4
  )
}
