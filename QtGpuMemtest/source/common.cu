#include "gputests.h"

unsigned int get_random_num(void)
{
#ifdef __unix__
	struct timeval t0;
	gettimeofday(&t0, NULL);

	unsigned int seed= (unsigned int)t0.tv_sec;
#else
	unsigned int seed = (unsigned int) GetTickCount();
#endif
	srand(seed);

	return rand();
}

unsigned long get_random_num_long(void)
{
#ifdef __unix__
	struct timeval t0;
	gettimeofday(&t0, NULL);

	unsigned int seed= (unsigned int)t0.tv_sec;
#else
	unsigned int seed = (unsigned int) GetTickCount();
#endif
	srand(seed);

	unsigned int a = rand();
	unsigned int b = rand();

	unsigned long ret =  ((unsigned long)a) << 32;
	ret |= ((unsigned long)b);

	return ret;
}

__global__ void kernel_move_inv_write(char* _ptr, char* end_ptr, unsigned int pattern)
{
	unsigned int i;
	unsigned int* ptr = (unsigned int*) (_ptr + blockIdx.x*BLOCKSIZE);
	if (ptr >= (unsigned int*) end_ptr)
	{
		return;
	}

	for (i = 0; i < BLOCKSIZE/sizeof(unsigned int); i++)
	{
		ptr[i] = pattern;
	}

	return;
}


__global__ void
kernel_move_inv_readwrite(char* _ptr, char* end_ptr, unsigned int p1, unsigned int p2, MemoryError* local_errors, int* local_count)
{
	unsigned int i;
	unsigned int* ptr = (unsigned int*) (_ptr + blockIdx.x*BLOCKSIZE);
	if (ptr >= (unsigned int*) end_ptr)
	{
		return;
	}

	for (i = 0; i < BLOCKSIZE/sizeof(unsigned int); i++)
	{
		if (ptr[i] != p1)
		{
			record_error(local_errors, local_count, &ptr[i], p1);
		}
		ptr[i] = p2;

	}

	return;
}


__global__ void
kernel_move_inv_read(char* _ptr, char* end_ptr,  unsigned int pattern, MemoryError* local_errors, int* local_count)
{
	unsigned int i;
	unsigned int* ptr = (unsigned int*) (_ptr + blockIdx.x*BLOCKSIZE);
	if (ptr >= (unsigned int*) end_ptr)
	{
		return;
	}

	for (i = 0; i < BLOCKSIZE/sizeof(unsigned int); i++)
	{
		if (ptr[i] != pattern)
		{
			record_error(local_errors, local_count, &ptr[i], pattern);
		}
	}

	return;
}


unsigned int
move_inv_test(char* ptr, unsigned int tot_num_blocks, unsigned int p1, unsigned p2, MemoryError* local_errors, int* local_count, bool *term)
{

	unsigned int i;
	unsigned int err = 0;
	char* end_ptr = ptr + tot_num_blocks* BLOCKSIZE;

	for (i= 0; i < tot_num_blocks; i+= GRIDSIZE)
	{
		if(*term == true) break;
		dim3 grid;
		grid.x= GRIDSIZE;
		kernel_move_inv_write<<<grid, 1>>>(ptr + i*BLOCKSIZE, end_ptr, p1); SYNC_CUERR;
		//SHOW_PROGRESS("move_inv_write", i, tot_num_blocks);
	}


	for (i=0; i < tot_num_blocks; i+= GRIDSIZE)
	{
		if(*term == true) break;
		dim3 grid;
		grid.x= GRIDSIZE;
		kernel_move_inv_readwrite<<<grid, 1>>>(ptr + i*BLOCKSIZE, end_ptr, p1, p2, local_errors, local_count); SYNC_CUERR;
		//err += error_checking("move_inv_readwrite",  i);
		//SHOW_PROGRESS("move_inv_readwrite", i, tot_num_blocks);
	}

	for (i=0; i < tot_num_blocks; i+= GRIDSIZE)
	{
		if(*term == true) break;
		dim3 grid;
		grid.x= GRIDSIZE;
		kernel_move_inv_read<<<grid, 1>>>(ptr + i*BLOCKSIZE, end_ptr, p2, local_errors, local_count); SYNC_CUERR;
		//err += error_checking("move_inv_read",  i);
		//SHOW_PROGRESS("move_inv_read", i, tot_num_blocks);
	}

	return err;

}
