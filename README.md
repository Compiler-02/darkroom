# darkroom
Darkroom是图像处理领域的一门编程语言，其编译器提供将图像处理算法编译为高效硬件的功能。

本组主要对Darkroom的原理、实现，和其他语言的对比、应用进行调研与测试。

目录结构
```
\-- report.md 报告文件

\-- README.md 说明文件

\-- Darkroom_Examples Darkroom 测试样例

  \--stencil_test.t stencil操作测试样例

  \--compile_process.t 显示编译流程

  \--cat.bmp 测试图片

\-- Darkroom_Source_Code_Analysis Darkroom源代码分析

  \-- 2013.convolution.isca_.pdf convolution engine说明

  \-- api.t Darkroom源文件，其中包含阅读注释，其他.t文件同

  \-- conv.png      

  \-- optimizations.t

  \-- kernelgraph.t              

  \-- schedule.t
  
  \-- compile.png               
  
  \-- multi_const.png           
  
  \-- schedule_analysis.mkd Darkroom调度分析
  
  \-- const_fold.png              
  
  \-- optimization_analysis.mkd  Darkroom优化分析
  
  \-- shift.png 

\-- Halide_Darkroom_Comparison #Darkroom和该领域另一门语言Halide的比较

  \-- H_D_comparison.md #Darkroom与Halide的比较报告

  \-- filter.cpp   		#Halide滤波代码

  \-- filter.t     		#darkroom滤波代码

  \-- frame10.png    	#待处理图像png格式

  \-- frame10.bmp  		#待处理图像bmp格式

  \-- halide.png		#halide运行结果

  \-- darkroom.png		#darkroom运行结果

  \-- Image_Pyramid.mkd #图像金字塔介绍

  \-- Image_pyramid.png 

  \-- gaussian.png   	

  \-- gaussian2.png  	

  \-- gaussian3.png   

  \-- laplacian.png 	

  \-- local_laplacian.py #拉普拉斯金字塔代码

\-- NNVM_Darkroom_Analysis Darkroom与NNVM的关联分析

  \-- NNVM层次图.png   

  \-- N_D_Analysis.md  NNVM分析

  \-- 交流.txt 与NNVM组的交流结果
```
