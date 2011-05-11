#include "gputests.h"

__global__ void
kernel_test1_write(char* _ptr, char* end_ptr, unsigned int* err)
{
	unsigned int i;
	unsigned long* ptr = (unsigned long*) (_ptr + blockIdx.x*BLOCKSIZE);

	if (ptr >= (unsigned long*) end_ptr)
	{
		return;
	}


	for (i = 0; i < BLOCKSIZE/sizeof(unsigned long); i++)
	{
		ptr[i] =(unsigned long) & ptr[i];
	}

	return;
}

__global__ void
kernel_test1_read(char* _ptr, char* end_ptr, unsigned int* err, unsigned long* err_addr,
                  unsigned long* err_expect, unsigned long* err_current, unsigned long* err_second_read)
{
	unsigned int i;
	unsigned long* ptr = (unsigned long*) (_ptr + blockIdx.x*BLOCKSIZE);

	if (ptr >= (unsigned long*) end_ptr)
	{
		return;
	}


	for (i = 0; i < BLOCKSIZE/sizeof(unsigned long); i++)
	{
		if (ptr[i] != (unsigned long)& ptr[i])
		{
			RECORD_ERR(err, &ptr[i], (unsigned long)&ptr[i], ptr[i]);
		}
	}

	return;
}



int
test1(char* ptr, unsigned int tot_num_blocks, int num_iterations, unsigned int* err_count, unsigned long* err_addr,
      unsigned long* err_expect, unsigned long* err_current, unsigned long* err_second_read, bool *term)
{


	unsigned int i;
	char* end_ptr = ptr + tot_num_blocks* BLOCKSIZE;

	for (i=0; i < tot_num_blocks; i+= GRIDSIZE)
	{
		if(*term == true) break;
		dim3 grid;
		grid.x= GRIDSIZE;
		kernel_test1_write<<<grid, 1>>>(ptr + i*BLOCKSIZE, end_ptr, err_count); SYNC_CUERR;
		//SHOW_PROGRESS("test1 on writing", i, tot_num_blocks);

	}

	for (i=0; i < tot_num_blocks; i+= GRIDSIZE)
	{
		if(*term == true) break;
		dim3 grid;
		grid.x= GRIDSIZE;
		kernel_test1_read<<<grid, 1>>>(ptr + i*BLOCKSIZE, end_ptr, err_count, err_addr, err_expect, err_current, err_second_read); SYNC_CUERR;
		//error_checking("test1 on reading",  i);
		//SHOW_PROGRESS("test1 on reading", i, tot_num_blocks);

	}


	return cudaSuccess;

}