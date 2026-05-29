#include <stdio.h>

__global__ void hello_kernel() {
    printf("Hello from GPU thread %d in block %d!\n",
           threadIdx.x, blockIdx.x);
}

int main(void) {
    int deviceCount = 0;
    cudaError_t err = cudaGetDeviceCount(&deviceCount);

    if (err != cudaSuccess || deviceCount == 0) {
        printf("No CUDA devices found (error: %s)\n", cudaGetErrorString(err));
        printf("This is expected on machines without NVIDIA GPUs.\n");
        printf("The build succeeded — run this on a machine with a GPU.\n");
        return 0;
    }

    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, 0);
    printf("CUDA device: %s (SM %d.%d)\n", prop.name, prop.major, prop.minor);

    hello_kernel<<<2, 4>>>();
    cudaDeviceSynchronize();

    printf("Done.\n");
    return 0;
}
