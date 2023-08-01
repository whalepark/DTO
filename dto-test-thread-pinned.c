/*******************************************************************************
 * Copyright (C) 2023 Intel Corporation
 *
 * SPDX-License-Identifier: MIT
 ******************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <threads.h>
#include <stdatomic.h>
#include <unistd.h>
#include <sched.h>

#define NUM_BUFS (4*1024UL)
#define BUF_SIZE (1*1024UL)
#define ALLOC_SIZE (NUM_BUFS * BUF_SIZE)
#define MEMSET_PATTERN 'a'

#define MAX_ITERS 100000
#define MAX_THREADS 9
#define LOG_COUNT 10000

atomic_int no_ops = 0;

int thread_func(void *thr_data)
{
	int thread_index = *((int *) thr_data);
	cpu_set_t cpuset;
	CPU_ZERO(&cpuset);
	CPU_SET(thread_index, &cpuset);

	if (sched_setaffinity(0, sizeof(cpu_set_t), &cpuset) != 0) {
		fprintf(stderr, "sched_setaffinity failed!\n");
		return -1;
	}

	// allocate memory
	void *src_addr = calloc(ALLOC_SIZE, sizeof(uint8_t));
	void *dest_addr = calloc(ALLOC_SIZE, sizeof(uint8_t));

	for (int i=0; i < MAX_ITERS; ++i) {
		int j = i % NUM_BUFS;

		uint8_t *s = src_addr + j * BUF_SIZE;
		uint8_t *d = dest_addr + j * BUF_SIZE;

		memset(s, MEMSET_PATTERN, BUF_SIZE);
		memcpy(d, s, BUF_SIZE);
		
		if (memcmp(d, s, BUF_SIZE) != 0)
			printf("memcmp failed for dsa fill\n");

		++no_ops;
		if (no_ops % LOG_COUNT == 0)
			printf("completed %d ops\n", no_ops);
	}

	free(src_addr);
	free(dest_addr);

	return 0;
}

int main(int argc, char **argv)
{
 	thrd_t threads[MAX_THREADS];
	int thr_num[MAX_THREADS];

	for(int t = 0; t < MAX_THREADS; ++t) {
		thr_num[t] = t;
		int result = thrd_create(&threads[t], thread_func, &thr_num[t]);
		if (result != thrd_success) {
			fprintf(stderr, "thrd_create failed: %dth thread\n", t);
			exit(-1);
		}
	}

	for(int t = 0; t < MAX_THREADS; ++t)
		thrd_join(threads[t], NULL);
	
	printf("all threads completed execution\n");
	return 0;
}
