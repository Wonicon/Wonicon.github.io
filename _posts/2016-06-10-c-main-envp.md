---
layout: post
title: 从 main 函数获取环境变量
categories: 经验
---

近期尝试在 gem5 上以 syscall emulation 模式模拟执行 MIPS 程序，
发现使用较新版本的工具链，符号 `_dl_random` 在执行过程中没有被初始化，最后访问地址 0 导致程序崩溃。
`_dl_random` 的初始化和访问都位于 `__blic_start_main` 中（使用 Glibc），所以先特别关注了下 C 程序的启动过程。

在 Glibc 的初始化函数 `__libc_start_main` 中，
发现了如下的获取环境变量的写法([参考代码](https://code.woboq.org/userspace/glibc/csu/libc-start.c.html#141))：

```c
char **ev = &argv[argc + 1];
```

比较扎眼的地方是 `argc + 1`.

此前在另一个[网页](http://www.tldp.org/LDP/LG/issue84/hawk.html)上看到访问环境变量的写法是这样的：

```c
int main(int argc, char** argv, char** env)
{
    int i = 0;
    while (env[i] != 0) {
       printf("%s\n", env[i++]);
    }
    return 0;
}
```

一开始我感觉上面两种写法是不一致的，但是实际测试下来发现如上计算出来的 `ev` 值和参数传递的 `env` 值是一样的。
后来发现是我对启动时的栈结构认识不足！

`argv` 和 `env` 指向的数组相邻，都是 NULL-terminated 的，但是 `argc` 不计最后的 NULL, 所以才会出现第一种那样的写法。
另外函数上加参数也不会影响到实际数组布局的，估计是 `main` 函数突然还能再加个参数，扰乱了心智。

参考资料：

1. Glibc 代码：https://code.woboq.org/userspace/glibc/
2. Linux 下 C 程序的启动过程：http://www.tldp.org/LDP/LG/issue84/hawk.html
3. C 程序启东时的栈结构：https://www.win.tue.nl/~aeb/linux/hh/stack-layout.html