// -*- coding: utf-8 -*-
// @Time    : 2024/7/7 20:03
// @Author  : ${AUTHOR}
// @File    : WallaceTree
// @Software: IntelliJ IDEA
// @Comment : Wallace树

package core.pipeline.intblock.fu.mdu.multiplier

import spinal.core._
import spinal.lib._

import scala.language.postfixOps

class WallaceTree(bitNum: Int) extends Component {
  // 层 --> 华莱士树内部分层
  // 级 --> 华莱士树之间分级

  // 计算华莱士树结构
  // 计算每一层需要计算的bit个数
  private val layerBitNum = {
    var layers = Array.empty[Int]
    var currBitNum = bitNum
    while (currBitNum > 2) {
      layers = layers :+ currBitNum
      // 方便构建，上层为计算的bit直接下落到下一层
      currBitNum = (currBitNum / 3 * 2) + (currBitNum % 3)
    }
    layers
  }

  // 每一层华莱士树包含的全加器个数为⌊M/3⌋（M是当前层次要加的数字个数）
  private val layerStruct = layerBitNum.map(_ / 3)

  private val depth = layerStruct.length      // 华莱士树深度
  private val carryNum = layerStruct.sum - 1  // 进位数量

  // define io
  val io = new Bundle {
    val input = in Bits(bitNum bits)    // 部分积bit输入
    val cin = in Bits(carryNum bits)    // 来自上级的进位
    val cout = out Bits(carryNum bits)  // 给予下级的进位
    val sum = out Bool()    // 最终加和输出
    val carry = out Bool()  // 最终进位输出
  }

  // 使用CSA，根据csaStruct层结构，构建CAS树
  private val casTree = (0 until depth).map(i => (0 until layerStruct(i)).map(_ => new CarrySaveAdder)).toArray
  private val layerInput = (0 until depth).map(i => Bits(layerBitNum(i) bits)).toArray
  private val cin = {  // 重新打包上级进位的数据结构
    val cin = (0 until depth - 1).map(i => Bits(layerStruct(i) bits)).toArray
    var idx = 0
    for (i <- 0 until depth - 1) {
      for (j <- 0 until layerStruct(i)) {
        cin(i)(j) := io.cin(idx)
        idx += 1
      }
    }
    cin
  }

  // 逐层连接CSA
  for (i <- 0 until depth) {
    // 构建本层输入
    if (i > 0) {
      for (j <- 0 until layerStruct(i - 1)) {
        // 上一层结果
        layerInput(i)(j * 2) := casTree(i - 1)(j).io.sum
        // 上一级进位
        layerInput(i)(j * 2 + 1) := cin(i - 1)(j)
      }
      // 上一层剩余的bit下落到本层层尾
      for (j <- layerStruct(i - 1) * 3 until layerBitNum(i - 1)) {
        // 3->2压缩，上层剩余bit下落后ofs刚好减少上层casNum个，即减少layerStruct(i - 1)
        layerInput(i)(j - layerStruct(i - 1)) := layerInput(i - 1)(j)
      }
    } else {
      layerInput(0) := io.input
    }
    for (j <- 0 until layerStruct(i)) {
      casTree(i)(j).io.a := layerInput(i)(j * 3)
      casTree(i)(j).io.b := layerInput(i)(j * 3 + 1)
      casTree(i)(j).io.c := layerInput(i)(j * 3 + 2)
    }
  }

  // 输出
  io.cout := (0 until depth - 1).flatMap(i => (0 until layerStruct(i)).map(j => casTree(i)(j).io.carry)).asBits
  io.sum := casTree.last.last.io.sum
  io.carry := casTree.last.last.io.carry
}
