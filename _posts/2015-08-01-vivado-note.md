---
layout: post
title: Verilog和Vivado学习笔记
categories: 学习
tags: Verilog Vivado 组成原理
---

### 在Vivado中开启out-of-context(OOC)模式

方法一:
![img](http://i11.tietuku.com/f94f80472de2bfc8.png)

方法二:
![img](http://i11.tietuku.com/8a218285dd470fed.png)

### Verilog拼接宏用法

```verilog
`define concat(x, y) x``y
`define name(x) concat(inst, 1)
// name(3) => inst3
```

### 仿真中查看内部模块的信号

点击"Run simulation"后, Vivado会进入一个新的窗口布局. 在那个布局里, 默认情况下, 中间一列会显示从仿真模块开始的树形结构. 那是Scope标签页.
点击具体的Scope, 也就是模块实例名, 在Object标签页里就会显示所有的信号, 包括输入, 输出, 输入输出端口, 内部信号, 常量, 变量等.
