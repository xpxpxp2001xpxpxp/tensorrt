#include "cuda_runtime_api.h"
#include "stdio.h"
#include <iostream>

#include "utils.hpp"


__global__ void resize_nearest_BGR2RGB_kernel(
    uint8_t* tar, uint8_t* src, 
    int tarW, int tarH, 
    int srcW, int srcH,
    float scaled_w, float scaled_h) 
{
    // nearest neighbour -- resized之后的图tar上的坐标
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    // nearest neighbour -- 计算最近坐标
    int src_y = round((float)y * scaled_h);
    int src_x = round((float)x * scaled_w);

    if (src_x < 0 || src_y < 0 || src_x > srcW || src_y > srcH) {
        // nearest neighbour -- 对于越界的部分，不进行计算
    } else {
        // nearest neighbour -- 计算tar中对应坐标的索引
        int tarIdx = (y * tarW  + x) * 3;

        // nearest neighbour -- 计算src中最近邻坐标的索引
        int srcIdx = (src_y * srcW + src_x) * 3;

        // nearest neighbour -- 实现nearest beighbour的resize + BGR2RGB
        tar[tarIdx + 0] = src[srcIdx + 2];
        tar[tarIdx + 1] = src[srcIdx + 1];
        tar[tarIdx + 2] = src[srcIdx + 0];
    }
}

__global__ void resize_bilinear_BGR2RGB_kernel(
    uint8_t* tar, uint8_t* src, 
    int tarW, int tarH, 
    int srcW, int srcH, 
    float scaled_w, float scaled_h) 
{

    // bilinear interpolation -- resized之后的图tar上的坐标
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    // bilinear interpolation -- 计算x,y映射到原图时最近的4个坐标
    int src_y1 = floor((y + 0.5) * scaled_h - 0.5);
    int src_x1 = floor((x + 0.5) * scaled_w - 0.5);
    int src_y2 = src_y1 + 1;
    int src_x2 = src_x1 + 1;

    if (src_y1 < 0 || src_x1 < 0 || src_y1 > srcH || src_x1 > srcW) {
        // bilinear interpolation -- 对于越界的坐标不进行计算
    } else {
        // bilinear interpolation -- 计算原图上的坐标(浮点类型)在0~1之间的值
        float th   = ((y + 0.5) * scaled_h - 0.5) - src_y1;
        float tw   = ((x + 0.5) * scaled_w - 0.5) - src_x1;

        // bilinear interpolation -- 计算面积(这里建议自己手画一张图来理解一下)
        float a1_1 = (1.0 - tw) * (1.0 - th);  //右下
        float a1_2 = tw * (1.0 - th);          //左下
        float a2_1 = (1.0 - tw) * th;          //右上
        float a2_2 = tw * th;                  //左上

        // bilinear interpolation -- 计算4个坐标所对应的索引
        int srcIdx1_1 = (src_y1 * srcW + src_x1) * 3;  //左上
        int srcIdx1_2 = (src_y1 * srcW + src_x2) * 3;  //右上
        int srcIdx2_1 = (src_y2 * srcW + src_x1) * 3;  //左下
        int srcIdx2_2 = (src_y2 * srcW + src_x2) * 3;  //右下

        // bilinear interpolation -- 计算resized之后的图的索引
        int tarIdx    = (y * tarW  + x) * 3;

        // bilinear interpolation -- 实现bilinear interpolation的resize + BGR2RGB
        tar[tarIdx + 0] = round(
                          a1_1 * src[srcIdx1_1 + 2] + 
                          a1_2 * src[srcIdx1_2 + 2] +
                          a2_1 * src[srcIdx2_1 + 2] +
                          a2_2 * src[srcIdx2_2 + 2]);

        tar[tarIdx + 1] = round(
                          a1_1 * src[srcIdx1_1 + 1] + 
                          a1_2 * src[srcIdx1_2 + 1] +
                          a2_1 * src[srcIdx2_1 + 1] +
                          a2_2 * src[srcIdx2_2 + 1]);

        tar[tarIdx + 2] = round(
                          a1_1 * src[srcIdx1_1 + 0] + 
                          a1_2 * src[srcIdx1_2 + 0] +
                          a2_1 * src[srcIdx2_1 + 0] +
                          a2_2 * src[srcIdx2_2 + 0]);
    }
}

__global__ void resize_bilinear_BGR2RGB_shift_kernel(
    uint8_t* tar, uint8_t* src, 
    int tarW, int tarH, 
    int srcW, int srcH, 
    float scaled_w, float scaled_h) 
{

    // resized之后的图tar上的坐标
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    // bilinear interpolation -- 计算x,y映射到原图时最近的4个坐标
    int src_y1 = floor((y + 0.5) * scaled_h - 0.5);
    int src_x1 = floor((x + 0.5) * scaled_w - 0.5);
    int src_y2 = src_y1 + 1;
    int src_x2 = src_x1 + 1;

    if (src_y1 < 0 || src_x1 < 0 || src_y1 > srcH || src_x1 > srcW) {
        // bilinear interpolation -- 对于越界的坐标不进行计算
    } else {
        // bilinear interpolation -- 计算原图上的坐标(浮点类型)在0~1之间的值
        float th   = ((y + 0.5) * scaled_h - 0.5) - src_y1;
        float tw   = ((x + 0.5) * scaled_w - 0.5) - src_x1;

        // bilinear interpolation -- 计算面积(这里建议自己手画一张图来理解一下)
        float a1_1 = (1.0 - tw) * (1.0 - th);  //右下
        float a1_2 = tw * (1.0 - th);          //左下
        float a2_1 = (1.0 - tw) * th;          //右上
        float a2_2 = tw * th;                  //左上

        // bilinear interpolation -- 计算4个坐标所对应的索引
        int srcIdx1_1 = (src_y1 * srcW + src_x1) * 3;  //左上
        int srcIdx1_2 = (src_y1 * srcW + src_x2) * 3;  //右上
        int srcIdx2_1 = (src_y2 * srcW + src_x1) * 3;  //左下
        int srcIdx2_2 = (src_y2 * srcW + src_x2) * 3;  //右下

        // bilinear interpolation -- 计算原图在目标图中的x, y方向上的偏移量
        y = y - int(srcH / (scaled_h * 2)) + int(tarH / 2);
        x = x - int(srcW / (scaled_w * 2)) + int(tarW / 2);

        // bilinear interpolation -- 计算resized之后的图的索引
        int tarIdx    = (y * tarW  + x) * 3;

        // bilinear interpolation -- 实现bilinear interpolation + BGR2RGB
        tar[tarIdx + 0] = round(
                          a1_1 * src[srcIdx1_1 + 2] + 
                          a1_2 * src[srcIdx1_2 + 2] +
                          a2_1 * src[srcIdx2_1 + 2] +
                          a2_2 * src[srcIdx2_2 + 2]);

        tar[tarIdx + 1] = round(
                          a1_1 * src[srcIdx1_1 + 1] + 
                          a1_2 * src[srcIdx1_2 + 1] +
                          a2_1 * src[srcIdx2_1 + 1] +
                          a2_2 * src[srcIdx2_2 + 1]);

        tar[tarIdx + 2] = round(
                          a1_1 * src[srcIdx1_1 + 0] + 
                          a1_2 * src[srcIdx1_2 + 0] +
                          a2_1 * src[srcIdx2_1 + 0] +
                          a2_2 * src[srcIdx2_2 + 0]);
    }
}

/*
    这里面的所有函数都实现了kernel fusion。这样可以减少kernel launch所产生的overhead
    如果使用了shared memory的话，就可以减少分配shared memory所产生的overhead以及内部线程同步的overhead。(这个案例没有使用shared memory)
    CUDA编程中有一些cuda runtime api是implicit synchronize(隐式同步)的，比如cudaMalloc, cudaMallocHost，以及shared memory的分配。
    高效的CUDA编程需要意识这些implicit synchronize以及其他会产生overhead的地方。比如使用内存复用的方法，让cuda分配完一次memory就一直使用它

    这里建议大家把我写的每一个kernel都拆开成不同的kernel来分别计算
    e.g. resize kernel + BGR2RGB kernel + shift kernel 
    之后用nsight去比较融合与不融合的差别在哪里。去体会一下fusion的好处
*/

void resize_bilinear_gpu(
    uint8_t* d_tar, uint8_t* d_src, 
    int tarW, int tarH, 
    int srcW, int srcH, 
    int tactis) 
{
    dim3 dimBlock(16, 16, 1);
    dim3 dimGrid(tarW / 16 + 1, tarH / 16 + 1, 1);
    
    //scaled resize
    float scaled_h = (float)srcH / tarH;
    float scaled_w = (float)srcW / tarW;
    float scale = (scaled_h > scaled_w ? scaled_h : scaled_w);

    if (tactis > 1) {
        scaled_h = scale;
        scaled_w = scale;
    }
    
    switch (tactis) {
    case 0:
        resize_nearest_BGR2RGB_kernel <<<dimGrid, dimBlock>>> (d_tar, d_src, tarW, tarH, srcW, srcH, scaled_w, scaled_h);
        break;
    case 1:
        resize_bilinear_BGR2RGB_kernel <<<dimGrid, dimBlock>>> (d_tar, d_src, tarW, tarH, srcW, srcH, scaled_w, scaled_h);
        break;
    case 2:
        resize_bilinear_BGR2RGB_kernel <<<dimGrid, dimBlock>>> (d_tar, d_src, tarW, tarH, srcW, srcH, scaled_w, scaled_h);
        break;
    case 3:
        resize_bilinear_BGR2RGB_shift_kernel <<<dimGrid, dimBlock>>> (d_tar, d_src, tarW, tarH, srcW, srcH, scaled_w, scaled_h);
        break;
    default:
        break;
    }
}
