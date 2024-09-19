// -*- coding: utf-8 -*-
// @Time    : 2024/9/19 17:18
// @Author  : ${AUTHOR}
// @File    : XpmMemoryTdpram
// @Software: IntelliJ IDEA 
// @Comment :

package core.memory.xilinx

import spinal.core._

class XpmMemoryTdpram(addrWidth: Int,
                      byteWidth: Int,
                      dataWidth: Int,
                      dataDepth: Int,
                      writeMode: String
                     ) extends BlackBox {
  noIoPrefix()
  setBlackBoxName("xpm_memory_tdpram")

  // Define the module parameters
  val generic = new Generic {
    val ADDR_WIDTH_A        = addrWidth
    val ADDR_WIDTH_B        = addrWidth
    val AUTO_SLEEP_TIME     = 0
    val BYTE_WRITE_WIDTH_A  = byteWidth
    val BYTE_WRITE_WIDTH_B  = byteWidth
    val CASCADE_HEIGHT      = 0
    val CLOCKING_MODE       = "common_clock"
    val ECC_BIT_RANGE       = "7:0"
    val ECC_MODE            = "no_ecc"
    val ECC_TYPE            = "none"
    val IGNORE_INIT_SYNTH   = 0
    val MEMORY_INIT_FILE    = "none"
    val MEMORY_INIT_PARAM   = "0"
    val MEMORY_OPTIMIZATION = "true"
    val MEMORY_PRIMITIVE    = "auto"
    val MEMORY_SIZE         = dataWidth * dataDepth
    val MESSAGE_CONTROL     = 0
    val RAM_DECOMP          = "auto"
    val READ_DATA_WIDTH_A   = dataWidth
    val READ_DATA_WIDTH_B   = dataWidth
    val READ_LATENCY_A      = 2
    val READ_LATENCY_B      = 2
    val READ_RESET_VALUE_A  = "0"
    val READ_RESET_VALUE_B  = "0"
    val RST_MODE_A          = "SYNC"
    val RST_MODE_B          = "SYNC"
    val SIM_ASSERT_CHK      = 0
    val USE_EMBEDDED_CONSTRAINT = 0
    val USE_MEM_INIT        = 1
    val USE_MEM_INIT_MMI    = 0
    val WAKEUP_TIME         = "disable_sleep"
    val WRITE_DATA_WIDTH_A  = dataWidth
    val WRITE_DATA_WIDTH_B  = dataWidth
    val WRITE_MODE_A        = writeMode
    val WRITE_MODE_B        = writeMode
    val WRITE_PROTECT       = 1
  }

  // Define the input/output ports
  val io = new Bundle {
    // Output ports
    val dbiterra    = out Bool()
    val dbiterrb    = out Bool()
    val douta       = out Bits(generic.READ_DATA_WIDTH_A bits)
    val doutb       = out Bits(generic.READ_DATA_WIDTH_B bits)
    val sbiterra    = out Bool()
    val sbiterrb    = out Bool()

    // Input ports
    val addra       = in  UInt(generic.ADDR_WIDTH_A bits)
    val addrb       = in  UInt(generic.ADDR_WIDTH_B bits)
    val clka        = in  Bool()
    val clkb        = in  Bool()
    val dina        = in  Bits(generic.WRITE_DATA_WIDTH_A bits)
    val dinb        = in  Bits(generic.WRITE_DATA_WIDTH_B bits)
    val ena         = in  Bool()
    val enb         = in  Bool()
    val injectdbiterra = in Bool()
    val injectdbiterrb = in Bool()
    val injectsbiterra = in Bool()
    val injectsbiterrb = in Bool()
    val regcea      = in  Bool()
    val regceb      = in  Bool()
    val rsta        = in  Bool()
    val rstb        = in  Bool()
    val sleep       = in  Bool()
    val wea         = in  Bits(generic.WRITE_DATA_WIDTH_A / generic.BYTE_WRITE_WIDTH_A bits)
    val web         = in  Bits(generic.WRITE_DATA_WIDTH_B / generic.BYTE_WRITE_WIDTH_B bits)
  }
}
