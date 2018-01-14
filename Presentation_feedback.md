# Presentation问题反馈
## 对(a+b)/3 优化成a/3+b/3的解释

在源码中这一句被解释为尽量填充满map操作的操作数。这里map操作指除法（/），reduce操作指加法+。可以看到，map操作从1个变成了两个，均为与常数3的除法，从而能够在一次map中填充更多操作数。

对卷积引擎的细节描述，主要参考
[Convolution Engine: Balancing Efficiency & Flexibility in
Specialized Computing]( https://github.com/Compiler-02/darkroom/blob/maste/Darkroom_Source_Code_Analysis/2013.convolution.isca_.pdf)

## TVM与Halide、Darkroom关系

NNVM的编译流程为：
```
NNVM -> TVM/TOPI -> TVM/Schedule -> TVM/HalideIR -> TVM IR -> LLVM IR 或 Source Code
```
其中TVM schedule的主要思想就来自于Halide等图像处理语言。其特点是算法与调度的分离。Halide已经提供自动调度来适应不同平台结构上的特别的优化方向，而TVM则更进一步，解决schedule空间包含手写优化的问题。这样，通过借鉴Halide等图像处理语言的思想，将图到op生成规则的这一步抽象化，把生成规则本身分成各个操作原语，在需要的时候快速组合成不同的schedule方案，从而让用户通过少量的代码获得更高的优化程度。

