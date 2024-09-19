// -*- coding: utf-8 -*-
// @Time    : 2024/9/18 19:31
// @Author  : ${AUTHOR}
// @File    : SimpleDualPortRam
// @Software: IntelliJ IDEA 
// @Comment :

package core.memory

import core.Config.PLATFORM
import core.config.Platform._
import core.memory.xilinx.XpmMemorySdpram
import spinal.core._

import scala.language.postfixOps

class SimpleDualPortRam(dataWidth: Int,
                        dataDepth: Int,
                        byteWidth: Int,
                        readUnderWritePolicy: ReadUnderWritePolicy
                       ) extends Component {
  private val addrWidth = log2Up(dataDepth)
  assert(dataWidth % byteWidth == 0, "SimpleDualPortRam: dataWidth must be a multiple of byteWidth")
  private val byteNum = dataWidth / byteWidth

  val io = new Bundle {
    // port a (write)
    val portA = new Bundle {
      val en = in Bool()
      val we = in Bits(byteNum bits)
      val addr = in UInt(addrWidth bits)
      val wdata = in Bits(dataWidth bits)
    }
    // port b (read)
    val portB = new Bundle {
      val en = in Bool()
      val addr = in UInt(addrWidth bits)
      val rdata = out Bits(dataWidth bits)
    }
  }

  if (PLATFORM == SIM_VERILATOR) {
    assert(readUnderWritePolicy == readFirst, "SimpleDualPortRam: only support readFirst in SIM_VERILATOR")

    val mem = Mem(Bits(dataWidth bits), wordCount = dataDepth)

    mem.write(
      enable = io.portA.en,
      address = io.portA.addr,
      data = io.portA.wdata,
      mask = io.portA.we
    )

    io.portB.rdata := mem.readSync(
      enable = io.portB.en,
      address = io.portB.addr
    )
  } else {
    // 以下选项的RAM均由黑盒构成
    val clockDomain = ClockDomain.current
    def clock = clockDomain.readClockWire
    def reset = clockDomain.readResetWire

    if (PLATFORM == FPGA_XILINX) {
      val xpmMemorySdpram = new XpmMemorySdpram(
        addrWidth = addrWidth,
        byteWidth = byteWidth,
        dataWidth = dataWidth,
        dataDepth = dataDepth,
        writeMode = if (readUnderWritePolicy == writeFirst) "write_first" else "read_first"
      )

      xpmMemorySdpram.io.addra := io.portA.addr
      xpmMemorySdpram.io.addrb := io.portB.addr
      xpmMemorySdpram.io.clka := clock
      xpmMemorySdpram.io.clkb := clock
      xpmMemorySdpram.io.dina := io.portA.wdata
      xpmMemorySdpram.io.ena := io.portA.en
      xpmMemorySdpram.io.enb := io.portB.en
      xpmMemorySdpram.io.injectdbiterra := False
      xpmMemorySdpram.io.injectsbiterra := False
      xpmMemorySdpram.io.regceb := False
      xpmMemorySdpram.io.rstb := reset
      xpmMemorySdpram.io.sleep := False
      xpmMemorySdpram.io.wea := io.portA.we

      io.portB.rdata := xpmMemorySdpram.io.doutb

    } else if (PLATFORM == ASIC_SMIC180) {
      // TODO: add ASIC_SMIC180 platform
    } else {
      assert(assertion = false, "SimpleDualPortRam: unsupported platform")
    }
  }
}


