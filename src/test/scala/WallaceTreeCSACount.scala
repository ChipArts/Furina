// -*- coding: utf-8 -*-
// @Time    : 2024/7/7 19:52
// @Author  : ${AUTHOR}
// @File    : wallaceTreeCSACount
// @Software: IntelliJ IDEA 
// @Comment :

object WallaceTreeCSACount {
  def wallaceTreeCSACount(n: Int): List[(Int, Int)] = {
    var levels = List.empty[(Int, Int)]
    var currentLayer = n
    var levelIndex = 0

    while (currentLayer > 2) {
      // 计算当前层的保留进位加法器的数量
      val csaCount = currentLayer / 3
      levels = levels :+ (levelIndex, csaCount)

      // 计算下一层的部分和和进位数量
      currentLayer = csaCount * 2 + (currentLayer % 3)
      levelIndex += 1
    }

    levels
  }

  def main(args: Array[String]): Unit = {
    val n = 16  // 输入二进制数的个数
    val csaCounts = wallaceTreeCSACount(n)

    csaCounts.foreach { case (level, count) =>
      println(s"层 $level 的保留进位加法器数量: $count")
    }
  }
}
