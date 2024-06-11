# Furina
OoOE CPU core

## 开发log

2024.4.24 通过func_lab19 通过func_advance
2024.4.28 通过coremark等仿真测试
2024.5.03 通过Linux仿真测试
2024.5.04 通过mos、uboot仿真测试
2024.5.10 通过Linux上板测试，但是串口存在bug


## BUG可能性记录

- 原子指令现在使用状态机控制执行，原则上应该在执行后重取流水线，因为Linux在原子指令之间不会执行CSR RD/WR指令访问LLBCTL，所以该设计并未触发BUG
- DCache的MISS状态转移可能存在BUG，但是目前未发现问题
- 串口存在BUG，应该是FIFO控制问题，Uncache 写入问题导致，但并未能定位问题
- ROB对一些冲刷行（如ibar、dbar）为没有做掩码，可能导致有些指令被重复执行
- 乘法器计算可能有误，计算Booth进位有一位未加，不知是否为BUG

## 改进方向

- 添加转发
- 添加storebuffer
- 乱序访存
- 优化分支预测
