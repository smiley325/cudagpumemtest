#include "gputests.h"

/**************************************************************************************
 * Test10 [memory stress test]
 *
 * Stress memory as much as we can. A random pattern is generated and a kernel of large grid size
 * and block size is launched to set all memory to the pattern. A new read and write kernel is launched
 * immediately after the previous write kernel to check if there is any errors in memory and set the
 * memory to the compliment. This process is repeated for 1000 times for one pattern. The kernel is
 * written as to achieve the maximum bandwidth between the global memory and GPU.
 * This will increase the chance of catching software error. In practice, we found this test quite useful
 * to flush hardware errors as well.
 *
 */

#define TYPE unsigned long
__global__ void test10_kernel_write(char* ptr, int memsize, TYPE p1)
{
	int i;
	int avenumber = memsize/(gridDim.x*gridDim.y);
	TYPE* mybuf = (TYPE*)(ptr + blockIdx.x* avenumber);
	int n = avenumber/(blockDim.x*sizeof(TYPE));

	for(i=0; i < n; i++)
	{
		int index = i*blockDim.x + threadIdx.x;
		mybuf[index]= p1;
	}
	int index = n*blockDim.x + threadIdx.x;
	if (index*sizeof(TYPE) < avenumber)
	{
		mybuf[index] = p1;
	}

	return;
}

__global__ void test10_kernel_readwrite(char* ptr, int memsize, TYPE p1, TYPE p2, MemoryError *local_error, int *local_count)
{
	int i;
	int avenumber = memsize/(gridDim.x*gridDim.y);
	TYPE* mybuf = (TYPE*)(ptr + blockIdx.x* avenumber);
	int n = avenumber/(blockDim.x*sizeof(TYPE));
	TYPE localp;

	for(i=0; i < n; i++)
	{
		int index = i*blockDim.x + threadIdx.x;
		localp = mybuf[index];
		if (localp != p1)
		{
			record_error(local_error, local_count, &mybuf[index], p1);
		}
		mybuf[index] = p2;
	}
	int index = n*blockDim.x + threadIdx.x;
	if (index*sizeof(TYPE) < avenumber)
	{
		localp = mybuf[index];
		if (localp!= p1)
		{
			record_error(local_error, local_count, &mybuf[index], p1);
		}
		mybuf[index] = p2;
	}

	return;
}

int test10(TestInputParams *tip, TestOutputParams *top, bool *term)
{
	TYPE p1;
	/*if (global_pattern_long){
	p1 = global_pattern_long;
	}else{*/
	p1 = get_random_num_long();
	//}
	TYPE p2 = ~p1;
	cudaStream_t stream;
	cudaEvent_t start, stop;
	cudaStreamCreate(&stream);
	cudaEventCreate(&start);
	cudaEventCreate(&stop);

	int n = tip->num_iterations;
	float elapsedtime;
	dim3 gridDim(STRESS_GRIDSIZE);
	dim3 blockDim(STRESS_BLOCKSIZE);
	cudaEventRecord(start, stream);

	//PRINTF("Test10 with pattern=0x%lx\n", p1);
	test10_kernel_write<<<gridDim, blockDim, 0, stream>>>(tip->ptr, tip->tot_num_blocks*BLOCKSIZE, p1); SYNC_CUERR;
	for(int i =0; i < n ; i ++)
	{
		if(*term == true) break;

		test10_kernel_readwrite<<<gridDim, blockDim, 0, stream>>>(tip->ptr, tip->tot_num_blocks*BLOCKSIZE, p1, p2,
		        top->err_vector, top->err_count); SYNC_CUERR;
		p1 = ~p1;
		p2 = ~p2;

	}
	cudaEventRecord(stop, stream);
	cudaEventSynchronize(stop);
	//error_checking("test10[Memory stress test]",  0);
	cudaEventElapsedTime(&elapsedtime, start, stop);
	//DEBUG_PRINTF("test10: elapsedtime=%f, bandwidth=%f GB/s\n", elapsedtime, (2*n+1)*tot_num_blocks/elapsedtime);

	cudaEventDestroy(start);
	cudaEventDestroy(stop);

	cudaStreamDestroy(stream);

	return cudaSuccess;
}