---
layout: post
title: 写简单的HTTP服务器遇到的坑
categories: 经验
tags: 编程 网络 HTTP C Linux socket
---

`listen`是用来设置标志位的, 表明一个套接字能够接受连接的状态, 本身不会阻塞.
阻塞行为由`accept`和`recv`产生.

在 C 代码里硬编码HTTP响应头时, 不要写出这样的代码:

```c
char header[] = "HTTP/1.1 200 OK\r\n\
                 Server: ServerName\r\n\
                 ...\r\n\
                 \r\n";
```

这样似乎不是合法的, 因为用`\\`转义掉源代码的换行符后, 用于缩进的空格也会被包含到字符串中,
这样似乎就不符合响应头的格式了.
如果一定要对齐, 可以这么写:

```c
char header[] = "HTTP/1.1 200 OK\r\n"
                "Server: ServerName\r\n"
                "...\r\n"
                "\r\n";
```

另外需要小心的是, 标志报文头结束是用两个`\r\n`, 但是一般都会习惯在条目后面加换行,
所以只需要单独写一个`\r\n`就够了, 也就是用额外的一个空白行来标志报头结束.

在 Linux 系统下, `\r\n`的行为似乎和`\n`是一样的, 如果按`\r`将光标移到首列,
`\n`将光标移到下一行的首列来理解的, 似乎可以说得通.
但是在写报文头时, 也可以直接使用'\n', 似乎在`write`里面会做相应的替换?

实现过程中遇到了一个比较难搞的问题. 我用`fork`将对HTTP请求的响应放入子进程中处理,
结果发现浏览器根据 html 文件的超链接发出的请求超过 5 个后就开始 pending.
但是如果我改成单进程服务器顺序处理每个请求, 就可以正常地响应, 没有 pending.
虽然查看了`chrome://net-internals`但是没有发现有价值的线索,
网上的讨论主要是针对浏览器端, 比如 AdBlock 插件会导致这个问题.
后来我对比网上
[别人的](http://blog.abhijeetr.com/2010/04/very-simple-http-server-writen-in-c.html)
能正常工作的简单 HTTP 服务器实现, 发现它在用`close`销毁连接的套接字之前,
还用了`shutdown`关闭连接, 我如法炮制后问题得以解决.
不过还是不太清楚原理, 首先需要了解下`shutdown`的原理,
然后去尝试对比下有无`shutdown`情况下`chrome://net-internals#Events`里有什么区别.

这个简单的 HTTP 服务器, 只能处理 GET 方法, 基本就是直接返回文件, 其余一概不管.
主要还是用来熟悉套接字的使用吧. 具体代码在GitHub上: https://github.com/Wonicon/MaybeServer.
