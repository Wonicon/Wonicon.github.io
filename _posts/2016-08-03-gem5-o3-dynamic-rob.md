---
layout: post
title: (gem5) SMT 的 ROB 动态分配问题
category: 备忘
---

默认情况下，支持 SMT 的 O3CPU 实现的 ROB 采取按线程数平均分配的 Partitioned 策略，在
`gem5/src/cpu/o3/O3CPU.py` 中有所设置，搜索关键词 `smtROBPolicy`.
根据 `gem5/src/cpu/o3/rob_impl.hh` 里 `Rob<Impl>` 的构造函数的逻辑，目前 ROB 支持的策略有
Dynamic, Partitioned 以及 Threshold (嘛，大小写无所谓）。

虽说 ROB 支持 Dynamic 策略，即多个线程先到先得地占有 ROB 中的表项，但是如果真的如此设置，用
SE 模式同时跑两个大点的程序，应该很快就会在 `void ROB<Impl>::insertInst(DynInstPtr &inst)` 里触发断言
`assert(numInstsInROB != numEntries)`. 断言的语义是：在往 ROB 中插入新指令时，ROB 不应该是满的。~~说好的支持 Dynamic 呢？gem5 你算计我！~~造成这个问题的直接原因基本是上层代码错误地判断了 ROB 的实际空闲容量，在不恰当的场合给 ROB 提供了指令。经过一番调试，需要修改的地方主要有三处：ROB 类返回空闲表项数的方法、Rename 段获悉最新空闲表项的策略、Rename 段计算实际空闲表项的策略。


## 返回空闲项数的方法

`ROB` 类针对每个线程返回空闲表项数的方法定义在 `gem5/src/cpu/o3/rob_impl.hh`，代码如下：

```c++
template <class Impl>
int
ROB<Impl>::numFreeEntries(ThreadID tid)
{
    return maxEntries[tid] - threadEntries[tid];
}
```

`threadEntries[tid]` 即时地记录每个线程在 ROB 中占有的表项，`maxEntries[tid]` 表示每个线程最大的 ROB 表项数，
在 `ROB` 类的构造函数里，它是这么初始化的：

```c++
if (policy == "dynamic") {
    robPolicy = Dynamic;

    //Set Max Entries to Total ROB Capacity
    for (ThreadID tid = 0; tid < numThreads; tid++) {
        maxEntries[tid] = numEntries;
    }

}
```

这里的问题是，在 Dynamic 模式下，ROB 最大表项数是全局唯一的，如果依然使用这个方法，就会导致处理一个线程的重命名和分派时，会错误地得到偏多的空闲表项数，意图往 ROB 中塞过多的指令，触发断言。
当然还有一个不带参数 tid 的 `numFreeEntries` 方法，但是 O3CPU 对单线程和多线程一视同仁，都是基于 tid 去访问各类资源的。
所以这个方法里需要判断一下 ROB 的 policy 是否为 Dynamic, 如果是的话，就转去执行没有参数的同名方法。


## Rename 段获悉最新空闲表项的策略

Rename 段通过名为 `RenameQueue` 的 time buffer 与 Commit 段通信，Commit 段负责维护 ROB, 包括从这个 time buffer 取出上个周期 Rename 段送进来的指令，以及向它写入 ROB 当前的容量状态供下个周期的 Rename 段参考。用选项 `--debug-flag=Rename` 运行 gem5 可以观察到，线程 A 和 B “发射”了不同条指令后，下个周期 Rename 时，它们获悉的空闲 ROB 项数自然是相应减少的，但是数值却很可能并不相同。要知道在 Dynamic 策略下，空闲表项数应该是全局唯一的。这个不一致的空闲表项数，也可能导致 Rename 段错误地发射过多的指令。

Rename 段获取 Commit 段 ROB 的空闲表项信息的代码定义在 `gem5/src/cpu/o3/rename_impl.hh`, 如下所示：

```c++
template <class Impl>
void
DefaultRename<Impl>::readFreeEntries(ThreadID tid)
{
	// ...

    if (fromCommit->commitInfo[tid].usedROB) {
        freeEntries[tid].robEntries =
            fromCommit->commitInfo[tid].freeROBEntries;
        emptyROB[tid] = fromCommit->commitInfo[tid].emptyROB;
    }

	// ...
}
```

然后去 Commit 段的实现代码里找 `freeROBEntries` 的相关内容，文件是 `gem5/src/o3/cpu/commit_impl.hh`. 会匹配到几个位置，但是应该很容易发现感兴趣的代码片段：

```c++
template <class Impl>
void
DefaultCommit<Impl>::commit()
{
    // ...

    while (threads != end) {
        ThreadID tid = *threads++;

        if (changedROBNumEntries[tid]) {
            toIEW->commitInfo[tid].usedROB = true;
            toIEW->commitInfo[tid].freeROBEntries = rob->numFreeEntries(tid);

        // ...
	}

	// ...
}
```

如上，在一个遍历线程 id 的循环里，要先检查 `changedROBNumEntries[tid]` 才会对 time buffer 的字段进行设置。这个用于判断的变量主要在下面这个场合为 `true`:

```c++
template <class Impl>
void
DefaultCommit<Impl>::getInsts()
{
	// ...

    for (int inst_num = 0; inst_num < insts_to_process; ++inst_num) {
        DynInstPtr inst;

        inst = fromRename->insts[inst_num];
        ThreadID tid = inst->threadNumber;

        if (!inst->isSquashed() &&
            commitStatus[tid] != ROBSquashing &&
            commitStatus[tid] != TrapPending) {
            changedROBNumEntries[tid] = true;

			// ...

            rob->insertInst(inst);

			// ...
		}
    }
}
```

这里就是往 ROB 里插入指令的地方。插入指令，ROB 的使用情况肯定是变化了的，但是这里只为该指令所属的线程标记了变化的 flag, 只有也只有该线程对应的 ROB 信息会得到更新，这是基于两个线程 ROB 资源隔离的情况下实现的代码！在共享情况下是不充分的。这里的修改方法可以是识别 policy 是否为 Dynamic, 如果是的话，就额外地为所用线程进行标记。要注意的是 `changedROBNumEntries[tid] = true` 在同一模块里还有若干个，最好封装并替换。


## 计算实际的空闲表项

完成上述修改应该很容易发现一个问题：如果当前周期获知 ROB 剩余 N 个空闲项，而线程 A 有 3 条指令要发射，线程 B 有 2 条指令要发射，会不会出现总计发射 5 条指令，下个周期再次撑爆 ROB 的情况？答案是会的。原来的代码基本没有考虑线程间的资源干扰。这个问题比较容易解决，只需要在 Rename 段加个记录当前周期已经发射，预计要被 ROB 接收的指令数量即可。首先要在何时的地方进行累加，下面是推荐的位置：

```c++
// file: gem5/src/cpu/o3/rename_impl.hh
template <class Impl>
void
DefaultRename<Impl>::renameInsts(ThreadID tid)
{
	// ...

    DPRINTF(Rename, "[tid:%u]: %i available instructions to "
            "send iew.\n", tid, insts_available);
	// Right here, use insts_available!

	// ...
}
```

在同一个方法的上面，就是计算空闲 ROB 表项的位置，在那里将这个累加数考虑进去：

```c++
// file: gem5/src/cpu/o3/rename_impl.hh
template <class Impl>
void
DefaultRename<Impl>::renameInsts(ThreadID tid)
{
	// ...

    int free_rob_entries = calcFreeROBEntries(tid);  // Here!

	// ...
}
```

不过，即便是这样，还是会触发断言挂掉的……

与上述现象类似的，还有一些同周期的数据会影响 ROB 实际的空闲表项数量。Rename 和 ROB 的更新位于不同的流水段，它们的行为实质上是并行执行的。也就是说，在 Rename 这边扎堆发射指令的同时，ROB 那边也在将上个周期扎堆送进来的指令一个接一个的写进去。这个周期没有结束，所以不可能知道 ROB 插入完上个周期的指令后的空闲容量，但是可以通过连线（time buffer）知道这个周期开始（即上个周期结束）ROB 有多少空闲容量，以及 ROB 要插入的指令数。原来的代码其实已经考虑到了这个转发问题，就在 `calcFreeROBEntries` 中，如下所示：

```c++
// file: gem5/src/cpu/o3/rename_impl.hh
template <class Impl>
inline int
DefaultRename<Impl>::calcFreeROBEntries(ThreadID tid)
{
    int num_free = freeEntries[tid].robEntries -
                  (instsInProgress[tid] - fromIEW->iewInfo[tid].dispatched);

    //DPRINTF(Rename,"[tid:%i]: %i rob free\n",tid,num_free);

    return num_free;
}
```

`instsInProgress[tid]` 是该线程重命名过的，没有提交的指令数，`fromIEW->iewInfo[tid].dispatched` 则是 IEW 段的，分派到指令队列，没有提交的指令数，它们的差值就是重命名过的，但是没有写入 ROB 的指令数，这些值都是该周期起始的数据。为了适配 Dynamic 的场景，不仅需要去掉该线程的，而且要去掉所有线程的，对 tid 进行下遍历处理即可。


## 总结

虽然 ROB 支持 Dynamic 的资源分配策略，但是上层代码完全是按照各线程隔离的思路来实现的。
为了在已有的代码上适配 Dynamic 的共享策略，需要用条件判断开特例，特例里又有各种循环累加。
代码冗杂，开销也更多。感觉用多态屏蔽这些差异可能会比较好，但是非 100% 的分支预测错误和关键路径的查虚函数表表访存那个代价更大就不得而知了，不过本来只需要用一个变量维护的全局信息，最后不得不用循环计算出来，感觉还是可以优化一下的。

同为核内资源的 Load Store Queue 以及 Instruction Queue 要想共享化，也会遇到类似的问题。不过物理寄存器堆一开始就是共享的。
