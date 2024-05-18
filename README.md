# Alioth
OoOE CPU core


## 1 About
- 约定通过端口名称如果可以判断是in/out，可以不加io后缀

## 2 架构及设计介绍

### 2.1 前端架构

### 2.2 后端架构

#### 



## X 零散的记录

### X.1 DCache

-   两读一写
-   以Cache行为单位进行写操作
-   随机替换策略


本级任务未完成不应该向下级发出有效的请求信号
ready的判断条件为：(后继流水线ready & 当前流水线可以处理本级req(buffer未满或不为空，FU空闲)) | 本级pipe reg中无有效任务
s0：一般为FU的请求接收级，不可见所在级pipe_reg 仅判断FU内部状态即可，所在级的ready信号将于外部合并
如果存在buffer解耦，则判断buffer的ready状态
各个功能单元总要表明当前状态，不表明状态则默认可用


rd --> dist
rj --> src0
rk --> src1




## N 开发log

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
