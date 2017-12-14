# Darkroom Research Report





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











