# Darkroom Research Report

## 1.相关工作
### 1.1 Halide
一种图像处理语言，把算法和调度语言分开。算法部分描述计算的内容，调度部分描述计算的次序。autotuner用来自动发现最佳的调度策略。
与Halide相比，Darkroom的描述能力较弱，窗口大小必须在编译时就知道。但在CPU上编译速度比较快，在自定义硬件上也比较高效。
Stencil computation
之前的一些物理模拟中也用到了窗口计算的方法，Darkroom借鉴了其中一些方法，但重点在调度多窗口计算。

### 1.2 OpenCV

一个C语言库，用于处理图像。有一部分已经可以通过高级综合工具在FPGA上实现。但由于是一个依赖具体语言实现的库，不能对图像处理过程中的内存使用进行优化。

### 1.3 SDF

无环数据流图，每个结点从输入中消费M个值，从输出中生产N个值。所有消费生产速率都可以在编译时得知。但在有限内存中调度是NP-完全问题。
而Darkroom则可以在多项式时间内解决，而且考虑到了图片的2D特性。

### 1.4 Systolic Arrays and DSPs

ISP和脉动阵列（systolic arrays）有相似之处。脉动阵列由多个简单处理器阵列组成，每个处理器可以和阵列中的邻居之间互联。
DSP是通用处理器，带DMA，VLIW，向量单元和专用数据通道以辅助多媒体处理。

## 2.相关概念
### 2.1 ISP

ISP,即image signal processors,  利用图片处理流水线（image processing pipelines）最小化使用line-buffering的访存带宽。带来能耗和速度上的高效。比如，智能手机上的图片处理就是由ISP执行。

ISP 处理从摄像头传感器中得到的原始数据。传感器在一个像素中记录一种颜色，可以想象，如果把像素点放大了看，就是一格一格马赛克，而且每个格子里只有一个颜色通道的颜色。但我们通常的照片都是多通道的（比如png图片通常有RGBA四个通道）。这就需要ISP来处理。通常，获取其他通道的颜色值，需要从这个像素的邻居计算得到。此外，ISP也承担了降噪等功能。

### 2.2 line-buffering

ISP由许多个固定功能的ASIC流水线组成。每个流水线执行以下两种类型的操作中的一种：输入为一个像素，在单独的一个像素上运算得到输出（pointwise）;在一个窗口（多个像素）运算得到一个像素的输出（stencil，模具之意）。后者就需要缓存之前运算的部分结果在片上存储中。我们称之为line-buffer。

### 2.3 能耗

访存能耗是计算的1000倍，因此能耗主要由访存决定。但把数据从移动设备发送到服务器上处理的能耗更是致命的——是本地计算的1000000倍。移动设备中，能耗十分关键。






## 5. Implementation

After generating an optimized line-buffered pipeline, our compiler instantiates concrete versions of the pipeline as ASIC or FPGA hardware designs, or code for CPUs. 

Darkroom programs are first **converted into an intermediate representation (IR)** that **forms a DAG of high-level stencil operations**. Then we perform standard compiler optimizations such as **common sub-expression elimination** and **constant propagation** on this IR. A program analysis is done on this IR to **generate the ILP formulation of line buffer optimization**. We solve for the optimal shifts using an off-the-shelf ILP solver (**lpsolve**), and use them to **construct the optimized pipeline**. The optimized pipeline is then fed as input to either the hardware generator, which **creates ASIC designs and FPGA code, or** the software compiler, which creates **CPU code**.

![2017-12-13_20_23_23](2017-12-13_20_23_23.jpg)

### 5.1 ASIC & FPGA synthesis

Our hardware generator implements **line buffers** as circularly addressed SRAMs or BRAMs. Each clock, a column of pixel data from the line buffer shifts into **a 2D array of registers**. The user’s image function is implemented as **combinational logic**, writing into an **output register**. 

![2017-12-13_20_26_10](2017-12-13_20_26_10.jpg)

We only support programs that are **straight pipelines** with **one input, one output, and a single consumer of each intermediate**.

Image functions have **multiple inputs and multiple outputs**. In order to support these programs, we translate the Darkroom program into an equivalent Darkroom program that is a straight pipeline. **The merging of nodes** in the programs can **create larger line buffers** than what could be achieved with a hardware implementation that supported DAG pipelines. 

![2017-12-13_20_33_15](2017-12-13_20_33_15.jpg)

###5.2 CPU compilation

Our CPU compiler implements the line-buffered pipeline as a multi-threaded function. To enable parallelism, we **tile the output image into multiple strips** and** compute each strip** on a different core. Intermediates along strip boundaries are **recomputed**.

**Within a thread**, the code follows **the line-buffered pipeline model**. A simple approach is to **have the thread’s main loop correspond to one clock cycle of the hardware**. However, the entire set of **line buffers will often exceed** the size of the fastest level of cache. 

We found that blocking the computation at the granularity of lines improved locality for this cache. The main loop calculates one line of each stencil operation with the line buffers expanded to the granularity of lines. In addition to keeping the line buffer values in the fastest level of the cache, this blocking reduces register spills in the inner loop by reducing the number of live induction variables. A stencil stage S2 that consumes from S1 yields the following code:

![2017-12-13_20_43_01](2017-12-13_20_43_01.jpg)

To exploit vector instructions available on modern hardware, we **vectorize the computation** within each line of each stage.
Line buffers are implemented using a small block of memory that we ensure stays in cache using the technique of Gummaraju and Rosenblum to simulate a scratchpad memory by restricting most memory access to this block and issuing non-temporal writes for our output images. We manage the modular arithmetic of the line buffers in the outer loop over the lines of an image so that each inner loop over pixels contains fewer instructions. 

## 6. Results

To evaluate Darkroom, we implemented a camera pipeline (ISP), and three possible future extensions—CORNER DETECTION, EDGE DETECTION, and DEBLUR—in hardware. 

**ISP** includes basic raw conversion operations (demosaicing, white balance, and color correction), in addition to enhancement and error correction operations (crosstalk correction, dead pixel suppression, and black level correction). Mapping ISP to Darkroom is straightforward: it is a linear pipeline of stencil operations, each of which becomes an image function.

![2017-12-13_21_19_56](2017-12-13_21_19_56.jpg)

**CORNER DETECTION** is a classic corner detection algorithm, used as an early stage in many computer vision algorithms, and implemented as a series of local stencils. 

![2017-12-13_21_22_02](2017-12-13_21_22_02.jpg)

**EDGE DETECTION** is a classic edge detection algorithm. It first takes a gradient of the image in x and y, classifies pixels as edges at local gradient maxima, and finally traces along these edge pixels sequentially. To implement this algorithm in Darkroom, we adapted the classic serial algorithm into a parallel equivalent, at the expense of some wasted computation and bounded information propagation. EDGE DETECTION traditionally requires a long sequential iteration, which does not fit within the Darkroom model. Our implementation demonstrates that it is possible to work around some restrictions in our programming model, widening the range of applications we support at the cost of efficiency. 

![2017-12-13_21_20_25](2017-12-13_21_20_25.jpg)

**DEBLUR** is an implementation of the Richardson-Lucy non-blind deconvolution algorithm. DEBLUR is computationally-intense iterative algorithm, which we use as a stress test of our system. We unrolled DEBLUR to 8 iterations, which was the maximum size our hardware synthesis tools could support.

![2017-12-13_21_22_27](2017-12-13_21_22_27.jpg)

### Throughput

In ASIC, a single pipeline achieves 940-1040 megapixels/sec, enough to process 16 megapixel images at 60 FPS. On the FPGA, a single-pixel pipeline achieves 125-145 megapixels/sec, enough to process 1080p/60 in real-time (124 megapixels/sec).

![2017-12-13_21_24_19](2017-12-13_21_24_19.jpg)

### Resource

We see that the dominant area cost is memory and logic for line buffers. The computational logic and all other overhead uses at most half the total area.

![2017-12-13_21_26_29](2017-12-13_21_26_29.jpg)

In practice, this platform provides enough resources to compile much larger pipelines, implementing multiple vision and image processing algorithms simultaneously in real-time.

![2017-12-13_21_28_03](2017-12-13_21_28_03.jpg)

###Comparison

For ISP, we compared Darkroom to our internal reference code written as **clean C**. Our reference code has **no multithreading, vectorization, or line buffering**. Enabling these optimizations by reimplementing it in Darkroom yielded a **7x speedup**, with source code of similar complexity. Of this speedup, **3.5x comes from multithreading**, and **2x comes from vectorization**.

We also compared Darkroom to **Halide**, an existing high performance image processing language and compiler, on the DEBLUR application. We see **similar performance** from both Halideand Darkroom-compiled implementations of DEBLUR, but Darkroom’s schedule optimization takes **under 1 second** and the total **compile time** takes **less than 2 minutes**, while the Halide autotuner required **8 hours** to find a comparably performing schedule.

![2017-12-13_21_40_52](2017-12-13_21_40_52.jpg)




