// -*- coding: utf-8 -*-
// @Time    : 2024/5/18 12:27
// @Author  : ${AUTHOR}
// @File    : furina.Config
// @Software: IntelliJ IDEA 
// @Comment :

package furina

import spinal.core._
import spinal.lib.bus.amba4.axi._

import scala.language.postfixOps
object Config {
  val CORE_NUM = 1  // can not change now !!!

  val VALEN = 32
  val PALEN = 32
  val DATA_WIDTH = 32

  val FETCH_WIDTH = 2

  val DCACHE_SIZE = 8 KiB
  val DCACHE_WAY_NUM = 2
  val DCACHE_BLK_SIZE = 16 Bytes



  val ICACHE_SIZE = 8 KiB
  val ICACHE_WAY_NUM = 2
  val ICACHE_BLK_SIZE = 16 Bytes

  val ROB_DEPTH = 64
}
