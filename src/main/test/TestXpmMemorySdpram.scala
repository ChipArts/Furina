// -*- coding: utf-8 -*-
// @Time    : 2024/9/18 21:06
// @Author  : ${AUTHOR}
// @File    : TestXpmMemorySdpram
// @Software: IntelliJ IDEA 
// @Comment :

import core.memory.xilinx.XpmMemorySdpram
import spinal.core._

class TestXpmMemorySdpram extends Component {
  // Instantiate BlackBox module
  val memory = new XpmMemorySdpram

  // Connect input/output signals
  memory.io.addra := U(0)               // Connect addra (for example purposes)
  memory.io.addrb := U(0)               // Connect addrb (for example purposes)
  memory.io.clka := False               // Connect clka
  memory.io.clkb := False               // Connect clkb
  memory.io.dina := B(0, 32 bits)       // Connect dina
  memory.io.ena := True                 // Connect ena
  memory.io.enb := True                 // Connect enb
  memory.io.injectdbiterra := False     // Connect injectdbiterra
  memory.io.injectsbiterra := False     // Connect injectsbiterra
  memory.io.regceb := False             // Connect regceb
  memory.io.rstb := False               // Connect rstb
  memory.io.sleep := False              // Connect sleep
  memory.io.wea := B(0, 32 bits)        // Connect wea

  // Output signals can be used for further processing
  val doutb = memory.io.doutb           // Example: Use the data output
}

object TestXpmMemorySdpram {
  def main(args: Array[String]): Unit = {
    SpinalConfig(
      targetDirectory = "./test_output/" // 指定Verilog输出目录
    ).generateVerilog(new TestXpmMemorySdpram)
  }
}