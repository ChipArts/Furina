// -*- coding: utf-8 -*-
// @Time    : 2024/5/20 14:59
// @Author  : ${AUTHOR}
// @File    : MmuMemType
// @Software: IntelliJ IDEA 
// @Comment :

package core.mmu

import spinal.core._

object MmuMemType extends SpinalEnum {
  val FETCH, LOAD, STORE = newElement()
}
