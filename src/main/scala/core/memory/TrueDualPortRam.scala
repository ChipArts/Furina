// -*- coding: utf-8 -*-
// @Time    : 2024/9/19 18:22
// @Author  : ${AUTHOR}
// @File    : TrueDualPortRam
// @Software: IntelliJ IDEA 
// @Comment :

package core.memory

import spinal.core._
import core.Config.PLATFORM
import core.config.Platform._
import core.memory.xilinx.XpmMemoryTdpram

import scala.language.postfixOps

class TrueDualPortRam(byteWidth: Int,
                      dataWidth: Int,
                      dataDepth: Int,
                      readUnderWritePolicy: ReadUnderWritePolicy
                     ) extends Component {
  private val addrWidth = log2Up(dataDepth)
  assert(dataWidth % byteWidth == 0, "TrueDualPortRam: dataWidth must be a multiple of byteWidth")
  private val byteNum = dataWidth / byteWidth

  val io = new Bundle {
    // port a
    val portA = new Bundle {
      val en = in Bool()
      val we = in Bits(byteNum bits)
      val addr = in UInt(addrWidth bits)
      val wdata = in Bits(dataWidth bits)
      val rdata = out Bits(dataWidth bits)
    }
    // port b
    val portB = new Bundle {
      val en = in Bool()
      val we = in Bits(byteNum bits)
      val addr = in UInt(addrWidth bits)
      val wdata = in Bits(dataWidth bits)
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

    io.portA.rdata := mem.readSync(
      enable = io.portA.en,
      address = io.portA.addr
    )

    mem.write(
      enable = io.portB.en,
      address = io.portB.addr,
      data = io.portB.wdata,
      mask = io.portB.we
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
      val mem = new XpmMemoryTdpram(
        addrWidth = addrWidth,
        dataWidth = dataWidth,
        dataDepth = dataDepth,
        byteWidth = byteWidth,
        writeMode = if (readUnderWritePolicy == writeFirst) "write_first" else "read_first"
      )

      mem.io.addra := io.portA.addr
      mem.io.addrb := io.portB.addr
      mem.io.clka := clock
      mem.io.clkb := clock
      mem.io.dina := io.portA.wdata
      mem.io.dinb := io.portB.wdata
      mem.io.ena := io.portA.en
      mem.io.enb := io.portB.en
      mem.io.injectdbiterra := False
      mem.io.injectdbiterrb := False
      mem.io.injectsbiterra := False
      mem.io.injectsbiterrb := False
      mem.io.regcea := False
      mem.io.regceb := False
      mem.io.rsta := reset
      mem.io.rstb := reset
      mem.io.sleep := False
      mem.io.wea := io.portA.we
      mem.io.web := io.portB.we

      io.portA.rdata := mem.io.douta
      io.portB.rdata := mem.io.doutb
    } else if (PLATFORM == ASIC_SMIC180) {
      // TODO: ASIC_SMIC180
    } else {
      assert(assertion = false, "Unsupported platform")
    }
  }

}
