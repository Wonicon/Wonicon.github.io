---
layout: post
title: fish shell使用记录
categories: 经验
tags: Linux shell fish-shell
---

### 测试环境

Ubuntu 16.04 64bit

fish shell 2.2.0

### fish的使用感受

fish的特点是其可用性，开箱即用的命令行语法高亮、自动建议、man page补全是突出特色。
输入命令的过程能感觉到语法着色和建议反应很快，不会有明显的迟钝感。
自带基于web的图形界面配置工具，不过比较花瓶。
由于默认配置就非常好用，所以不需要装很多插件（也没有很多插件），所以在达到相近的使用体验的情况下，
fish的启动速度比oh-my-zsh快一些，而装了几个插件的antigen已经能感觉到明显的延迟（或许我要试试zgen？）。

fish的配置应该是比较简单的，像我这种没有接触过shell配置的人，用了半天，也差不多能大致改改提示符了。
当然也有可能是社区不够成熟，基本的东西暴露的过多，反而易于把握。

fish让我感到不满的地方是prompt，只要增加一点花样，多一些条件判断，就有种变慢的感觉，即输完指令敲回车，能感觉到prompt从左到右打印的过程（虽然是一瞬），oh-my-zsh的robbyrussell主题并没有这种感觉。

### 一些系统命令的manpage补全更新没有效果

`ls --group-directories-first`默认没有补全，通过`fish_update_completions`更新后确实能在./local/fish/generated_completions/（这是默认目录，具体看`XDG_USER_HOME`）找到含有`--group-directories-first`补全的ls.fish，并且手动source之后确实能自动补全。但是默认依然是没有效果的。

在安装目录/usr/share/fish/completions/能找到一个ls.fish，将其删除后自己生成的ls.fish就能正常读取了。这个ls.fish文件只有一行代码：

```
__fish_complete_ls ls
```

`__fish_complete_ls`是在/usr/share/fish/functions/下定义的函数（有同名的.fish文件），里面有默认的关于ls的补全设置。这个文件在GitHub上最后的修改时间是2年前（相对于2015年9月），而我使用的ls来自GNU coreutils 8.21，man page的更新日期是2015年一月。

类似的问题还有ls的block size选项，默认的补全是`--blocksize`，而man page里则是`--block-size`，默认情况下前者能够补全但是确实不是合法的选项。

### wahoo安装主题没有效果

如果通过`fish_config`设定过prompt，那么就会在`.config/fish/functions/`里产生`fish_prompt.fish`文件。修改prompt的主题都会有这个文件，但是`.config/fish/functions/fish_prompt.fish`是优先读取的，所以要把它删掉才能读取别的目录里的`fish_prompt.fish`文件。

