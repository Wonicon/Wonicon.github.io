---
layout: post
title: What does a scheduler mean under OoO context
categories: 学习
---

When reading papers on dynamic execution techniques, I was quite confused about what a scheduler is.
Although taught in courses on Computer Architecture, I only kept in mind those concrete concepts
like scoreboarding, reservation station and re-order buffer.

I found the definition of scheduler, or *dynamic instruction scheduler* in
*Modern Processor Design: Fundementals of Superscalar Processors* quite clear.
Therefore, pelease allow me to keep a note here:

> 5.2.7 Dynamic Instruction Scheduler
>
> ... We use the term *dynamic instruction scheduler* to include
> the instruction window and its associated instruction wake-up and select logic. ...

The instruction window is corresponding to the several buffers above.
If we want to increase the memory level parallelism, traditionally
we need to increase the size of the instruction window, resulting in
huge area consumption and long latency due to the complexity of instruction wake-up select logic.
