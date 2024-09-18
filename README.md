# Furina

## 〇、About

## 一、编程规范

- 尽管`UInt`/`SInt`兼容`Bits` 类型的所有操作，但会对程序运行造成负担，本项目所有`BitVector`尽可能使用`Bits`，当数据被确定为可运算数据时使用`UInt`/`SInt`

  > The `UInt`/`SInt` types are vectors of bits interpreted as two’s complement unsigned/signed integers. They can do what `Bits` can do, with the addition of unsigned/signed integer arithmetic and comparisons.

- 流水线`Node` 结构中的 `Payload` 信号名大写

  > Note that I got used to name the Payload instances using uppercase. This is to make it very explicit that the thing isn’t a hardware signal, but are more like a “key/type” to access things.

- 关于注释
  - 一级注释
    
    ```scala
    /* =======================================================  ======================================================= */
    ```
    
  - 二级注释
  
    ```scala
    /* something */
    ```
  
  - 三级注释
  
    ```scala
    // something
    ```
## 二、整体架构