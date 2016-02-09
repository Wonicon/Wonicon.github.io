---
layout: post
title: new-libc下stdout的初始化过程
categories: 学习
tags: C newlib
---

对于 newlib 而言, 首先有一个全局变量 `__impure_data` 保存了stdin, stdout 和 stderr
的文件描述符以及它们的指针. 而在对应的结构体初始化宏中, 这三个文件描述符都是初始化成空的.
在调用 printf 时, 它会获取全局变量 `__impure_data` 并取出 stdout 的指针, 接着调用
`__vfprintf_r`, 在 `__vfprintf_r` 中, 会调用 `__swsetup_r` 来设置 flag.
在 `__swsetup_r` 一开始, 会检查可重入信息结构体的初始化情况, 如果没有初始化, 比如第一
调用 printf, 则会进入 `__sinit` 进行初始化, 对标准输出等, 会进一步调用 `std` 函数进行
初始化, 则时候会赋值读写回调函数. `std` 在我们使用的链接库中似乎被内联优化了...反正这
之后 stdout 作为文件描述符才是可用的.

