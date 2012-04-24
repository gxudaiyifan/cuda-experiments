#include "levenshtein.h"
#include <cuda.h>
#include <math.h>


__device__ int __index(int row,int col) {
    return (((row) * (ARRSIZE + 1)) + (col));
}

__device__ int __min(int a, int b) {
    return ((a)-(((a)-(b))&((b)-(a))>>31));
}

__device__ int tiledIndex(int row, int column) {
    return 0;
}


__global__ void levenshteinKernel(char* Md, char* Nd, int* Rd, int size) {
    __shared__ char Nds[ARRSIZE];   //Shared Nd character memory
    __shared__ int  Rs[ARRSIZE];    //Shared current min value memory
    int i = threadIdx.x + 1;        //column
    int j;                          //row
    char Mdt = Md[threadIdx.x];
    
    Nds[threadIdx.x]   = Nd[threadIdx.x];
    Rs[threadIdx.x]    = Rd[threadIdx.x];

    __syncthreads();

    for(int k = 2; k < (2 * size) + 1; ++k) { 
        j = k - threadIdx.x;
        if( j > 0 && j <= size)
        {
            Rs[threadIdx.x]   = __min( (Rd[__index(j-1,i)] + 1),
                                       (Rd[__index(j,i-1)] + 1 )   );
            Rd[__index(j,i)]  = __min( (Rs[threadIdx.x]),
                                       (Rd[__index(j-1,i-1)] + ((Mdt!=Nds[j-1])&1)) );
            /*
            Rs[threadIdx.x]   = __min( (Rd[__index(i,j-1)] + 1),
                                       (Rd[__index(i-1,j)] + 1 )   );
            Rd[__index(i,j)]  = __min( (Rs[threadIdx.x]),
                                       (Rd[__index(i-1,j-1)] + ((Mdt!=Nds[j-1])&1)) );*/
        }

        __syncthreads();
    }    
}

__host__ void levenshteinCuda(char* s1, char* s2, int* &result, size_t size) {
    //Assumption is made that the size is a multiple of tile size
    dim3 dimGrid(1, 1);
    dim3 dimBlock(ARRSIZE, 1);
    
    char* Sd;
    char* Td;
    int*  Rd;
    size_t arrSize = (ARRSIZE+1) * (ARRSIZE+1);
    Sd = Td = NULL;
    Rd = NULL;

    for(int i = 0; i <= ARRSIZE; ++i) //for each element in the first column
        result[getIndex(i,0)] = i;

    for (int i = 0; i <= ARRSIZE; i++)
        result[getIndex(0,i)] = i;

    cudaMalloc((void**) &Sd, (size *   sizeof(char)));
    cudaMalloc((void**) &Td, (size *   sizeof(char)));
    cudaMalloc((void**) &Rd, (arrSize *    sizeof(int)));

    cudaMemcpy(Sd, s1,     (size * sizeof(char)), cudaMemcpyHostToDevice);
    cudaMemcpy(Td, s2,     (size * sizeof(char)), cudaMemcpyHostToDevice);
    cudaMemcpy(Rd, result, (arrSize * sizeof(int)),  cudaMemcpyHostToDevice);
#ifdef TESTING
    for( int z = 0; z < TESTLENGTH; ++z) {
#endif
        levenshteinKernel<<<dimGrid, dimBlock>>>(Sd,Td,Rd,size);
#ifdef TESTING
    }
#endif

    cudaMemcpy(result, Rd, (arrSize * sizeof(int)), cudaMemcpyDeviceToHost);

    cudaFree(Sd);
    cudaFree(Td);
    cudaFree(Rd);
    return;
}

__host__ int getIndex(int row , int col)
{
    return ((row * (ARRSIZE + 1)) + col);
}

__host__ int getMin(int a, int b)
{
    return (a-((a-b)&(b-a)>>31));
}